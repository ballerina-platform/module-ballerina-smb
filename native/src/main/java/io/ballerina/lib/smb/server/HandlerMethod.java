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

import io.ballerina.runtime.api.types.Type;

import java.util.List;

/**
 * A service handler method resolved once, when the service is attached to the listener. Everything a dispatch
 * needs about the method is a function of the service type, so none of it is recomputed per file event.
 *
 * @param name The remote method name
 * @param contentType The declared type of the first parameter, or {@code null} when the method declares none
 * @param optionalParameters The {@code FileInfo}/{@code Caller} parameters the method declares, in order
 * @param fileNamePattern The effective {@code fileNamePattern} — the method level one when annotated, the
 *                        listener level one otherwise, and {@code null} when neither is configured
 * @param afterProcess The {@code afterProcess} action, or {@code null} when it is not annotated
 * @param afterError The {@code afterError} action, or {@code null} when it is not annotated
 * @param isConcurrentSafe Whether both the service and the method are isolated
 */
public record HandlerMethod(String name, Type contentType, List<OptionalParameter> optionalParameters,
                            FileNamePattern fileNamePattern, PostProcessAction afterProcess,
                            PostProcessAction afterError, boolean isConcurrentSafe) {

    /**
     * A parameter a handler may declare in addition to its first, content parameter.
     */
    public enum OptionalParameter {
        FILE_INFO,
        CALLER
    }

    /**
     * Checks whether the method declares an {@code smb:Caller} parameter.
     *
     * @return true if the method takes a caller
     */
    public boolean declaresCaller() {
        return optionalParameters.contains(OptionalParameter.CALLER);
    }

    /**
     * Checks whether the given file name is one this handler is configured to receive.
     *
     * @param fileName The file name to match
     * @return true when no pattern is configured, or the file name matches it
     */
    public boolean matchesFileName(String fileName) {
        return fileNamePattern == null || fileNamePattern.matches(fileName);
    }
}
