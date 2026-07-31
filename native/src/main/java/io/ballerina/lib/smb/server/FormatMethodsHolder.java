/*
 * Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.lib.smb.server;

import io.ballerina.lib.smb.util.ModuleUtils;
import io.ballerina.runtime.api.types.MethodType;
import io.ballerina.runtime.api.types.ObjectType;
import io.ballerina.runtime.api.types.Parameter;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.types.TypeTags;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.utils.TypeUtils;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static io.ballerina.lib.smb.server.SmbListenerHelper.AFTER_ERROR;
import static io.ballerina.lib.smb.server.SmbListenerHelper.AFTER_PROCESS;
import static io.ballerina.lib.smb.server.SmbListenerHelper.CALLER;
import static io.ballerina.lib.smb.server.SmbListenerHelper.COLON;
import static io.ballerina.lib.smb.server.SmbListenerHelper.FILE_INFO;
import static io.ballerina.lib.smb.server.SmbListenerHelper.FILE_NAME_PATTERN;
import static io.ballerina.lib.smb.server.SmbListenerHelper.FUNCTION_CONFIG;
import static io.ballerina.lib.smb.server.SmbListenerHelper.MOVE_TO;
import static io.ballerina.lib.smb.server.SmbListenerHelper.ON_ERROR_METHOD;
import static io.ballerina.lib.smb.server.SmbListenerHelper.ON_FILE;
import static io.ballerina.lib.smb.server.SmbListenerHelper.ON_FILE_CSV;
import static io.ballerina.lib.smb.server.SmbListenerHelper.ON_FILE_DELETE;
import static io.ballerina.lib.smb.server.SmbListenerHelper.ON_FILE_JSON;
import static io.ballerina.lib.smb.server.SmbListenerHelper.ON_FILE_TEXT;
import static io.ballerina.lib.smb.server.SmbListenerHelper.ON_FILE_XML;
import static io.ballerina.lib.smb.server.SmbListenerHelper.PRESERVE_SUB_DIRS;

/**
 * Resolves the handler methods of an SMB service once, when the service is attached to the listener.
 * The method lookup, the {@code @smb:FunctionConfig} annotation, and the optional parameters a handler
 * declares are all fixed by the service type, so a dispatch only has to read them back from here.
 */
public class FormatMethodsHolder {

    private static final Set<String> CONTENT_METHODS =
            Set.of(ON_FILE_TEXT, ON_FILE_JSON, ON_FILE_XML, ON_FILE_CSV, ON_FILE);

    private final Map<String, HandlerMethod> contentMethods;
    private final HandlerMethod onFileDeleteMethod;
    private final HandlerMethod onErrorMethod;
    private final boolean needsCaller;

    public FormatMethodsHolder(BObject service, FileNamePattern listenerFileNamePattern) {
        ObjectType serviceType = (ObjectType) TypeUtils.getReferredType(TypeUtils.getType(service));
        this.contentMethods = new HashMap<>();
        for (String methodName : CONTENT_METHODS) {
            MethodType method = getMethod(serviceType, methodName);
            if (method != null) {
                contentMethods.put(methodName,
                        resolveMethod(serviceType, method, methodName, listenerFileNamePattern));
            }
        }
        MethodType onFileDelete = getMethod(serviceType, ON_FILE_DELETE);
        this.onFileDeleteMethod = onFileDelete == null
                ? null
                : resolveMethod(serviceType, onFileDelete, ON_FILE_DELETE, listenerFileNamePattern);
        // The runtime does not report every declared onError method, yet the listener can still invoke it. So a
        // placeholder is kept for the unresolved case rather than treating the handler as absent. Its isolation
        // cannot be read — ObjectType.isIsolated panics for a method it does not report — so the invocation is
        // left to run on a non-concurrent strand, and it simply fails if the service declares no onError.
        MethodType onError = getMethod(serviceType, ON_ERROR_METHOD);
        this.onErrorMethod = onError == null
                ? new HandlerMethod(ON_ERROR_METHOD, null, List.of(), null, null, null, false)
                : resolveMethod(serviceType, onError, ON_ERROR_METHOD, listenerFileNamePattern);
        this.needsCaller = contentMethods.values().stream().anyMatch(HandlerMethod::declaresCaller)
                || (onFileDeleteMethod != null && onFileDeleteMethod.declaresCaller())
                || onErrorMethod.declaresCaller();
    }

    private static HandlerMethod resolveMethod(ObjectType serviceType, MethodType method, String methodName,
                                               FileNamePattern listenerFileNamePattern) {
        Parameter[] parameters = method.getParameters();
        Type contentType = parameters.length > 0 ? parameters[0].type : null;
        List<HandlerMethod.OptionalParameter> optionalParameters = new ArrayList<>();
        for (int i = 1; i < parameters.length; i++) {
            String parameterTypeName = TypeUtils.getReferredType(parameters[i].type).getName();
            if (FILE_INFO.equals(parameterTypeName)) {
                optionalParameters.add(HandlerMethod.OptionalParameter.FILE_INFO);
            } else if (CALLER.equals(parameterTypeName)) {
                optionalParameters.add(HandlerMethod.OptionalParameter.CALLER);
            }
        }
        BMap<BString, Object> annotation = getFunctionConfigAnnotation(method);
        FileNamePattern methodPattern = parseFileNamePattern(annotation);
        return new HandlerMethod(methodName, contentType, List.copyOf(optionalParameters),
                methodPattern != null ? methodPattern : listenerFileNamePattern,
                parsePostProcessAction(annotation, AFTER_PROCESS),
                parsePostProcessAction(annotation, AFTER_ERROR), isConcurrentSafe(serviceType, methodName));
    }

    private static boolean isConcurrentSafe(ObjectType serviceType, String methodName) {
        return serviceType.isIsolated() && serviceType.isIsolated(methodName);
    }

    private static MethodType getMethod(ObjectType serviceType, String methodName) {
        for (MethodType method : serviceType.getMethods()) {
            if (method.getName().equals(methodName)) {
                return method;
            }
        }
        return null;
    }

    private static BMap<BString, Object> getFunctionConfigAnnotation(MethodType method) {
        return (BMap<BString, Object>) method.getAnnotation(
                StringUtils.fromString(ModuleUtils.getModule().toString() + COLON + FUNCTION_CONFIG));
    }

    private static FileNamePattern parseFileNamePattern(BMap<BString, Object> annotation) {
        if (annotation == null) {
            return null;
        }
        BString pattern = annotation.getStringValue(StringUtils.fromString(FILE_NAME_PATTERN));
        return pattern == null ? null : FileNamePattern.compile(pattern.getValue());
    }

    private static PostProcessAction parsePostProcessAction(BMap<BString, Object> annotation, String field) {
        if (annotation == null) {
            return null;
        }
        Object action = annotation.get(StringUtils.fromString(field));
        if (action == null) {
            return null;
        }
        if (TypeUtils.getType(action).getTag() == TypeTags.STRING_TAG) {
            return PostProcessAction.delete();
        }
        BMap<BString, Object> moveRecord = (BMap<BString, Object>) action;
        String moveTo = moveRecord.getStringValue(StringUtils.fromString(MOVE_TO)).getValue();
        boolean preserveSubDirs = moveRecord.getBooleanValue(StringUtils.fromString(PRESERVE_SUB_DIRS));
        return PostProcessAction.move(moveTo, preserveSubDirs);
    }

    /**
     * Gets the content handler method with the given name.
     *
     * @param methodName The remote method name
     * @return The resolved handler, or null when the service does not declare it
     */
    public HandlerMethod getContentMethod(String methodName) {
        return methodName == null ? null : contentMethods.get(methodName);
    }

    /**
     * Gets the {@code onFileDelete} handler method.
     *
     * @return The resolved handler, or null when the service does not declare it
     */
    public HandlerMethod getOnFileDeleteMethod() {
        return onFileDeleteMethod;
    }

    /**
     * Gets the {@code onError} handler method. Never null, so that a handler the runtime does not report is
     * still invoked with the error alone.
     *
     * @return The resolved handler
     */
    public HandlerMethod getOnErrorMethod() {
        return onErrorMethod;
    }

    /**
     * Checks whether any handler of the service declares an {@code smb:Caller} parameter.
     *
     * @return true if the service needs a caller
     */
    public boolean needsCaller() {
        return needsCaller;
    }
}
