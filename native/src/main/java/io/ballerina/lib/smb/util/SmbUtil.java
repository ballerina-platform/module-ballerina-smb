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

package io.ballerina.lib.smb.util;

import io.ballerina.runtime.api.Module;
import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BString;

import static io.ballerina.lib.smb.util.ModuleUtils.getModule;

/**
 * Utils class for SMB client operations.
 */
public class SmbUtil {
    private SmbUtil() {
    }

    public static BError createError(String message, String type) {
        return createError(message, null, type);
    }

    public static BError createError(String message, Throwable cause, String type) {
        Module module = getModule();
        BString errorMessage = StringUtils.fromString(message);
        if (cause != null) {
            BError causeError = createErrorCause(cause);
            return ErrorCreator.createError(module, type, errorMessage, causeError, null);
        } else {
            return ErrorCreator.createError(module, type, errorMessage, null, null);
        }
    }

    private static BError createErrorCause(Throwable throwable) {
        String message = throwable.getMessage();
        if (message == null) {
            message = throwable.getClass().getName();
        }
        return ErrorCreator.createError(StringUtils.fromString(message));
    }
}

