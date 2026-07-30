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

package io.ballerina.lib.smb.plugin;

import java.util.Set;

/**
 * SMB compiler plugin constants.
 */
public final class PluginConstants {

    private PluginConstants() {}

    public static final String PACKAGE_PREFIX = "smb";
    public static final String PACKAGE_ORG = "ballerina";

    // Format-specific handler function names
    public static final String ON_FILE_FUNC = "onFile";
    public static final String ON_FILE_TEXT_FUNC = "onFileText";
    public static final String ON_FILE_JSON_FUNC = "onFileJson";
    public static final String ON_FILE_XML_FUNC = "onFileXml";
    public static final String ON_FILE_CSV_FUNC = "onFileCsv";

    // Event-based handler function name
    public static final String ON_FILE_DELETE_FUNC = "onFileDelete";

    // Error handler function name
    public static final String ON_ERROR_FUNC = "onError";

    /**
     * All format-specific handler names. These handlers automatically convert file content to typed data.
     */
    public static final Set<String> ALL_FORMAT_HANDLERS = Set.of(
            ON_FILE_FUNC,
            ON_FILE_TEXT_FUNC,
            ON_FILE_JSON_FUNC,
            ON_FILE_XML_FUNC,
            ON_FILE_CSV_FUNC
    );

    // parameter types
    public static final String CALLER = "Caller";
    public static final String FILE_INFO = "FileInfo";

    // error type names
    public static final String ERROR_PARAM = "Error";

    public enum CompilationErrors {
        INVALID_REMOTE_FUNCTION("Invalid remote method. Allowed handlers: onFile, onFileText, onFileJson, " +
                "onFileXml, onFileCsv (format-specific), onFileDelete or onError.", "SMB_101"),
        RESOURCE_FUNCTION_NOT_ALLOWED("Resource functions are not allowed for smb services.", "SMB_102"),
        NO_VALID_REMOTE_METHOD("Service must define at least one handler method: onFile, onFileText, onFileJson, " +
                "onFileXml, onFileCsv (format-specific) or onFileDelete.", "SMB_103"),

        CONTENT_METHOD_MUST_BE_REMOTE("'%s' handler must be declared as remote.", "SMB_110"),
        MANDATORY_PARAMETER_NOT_FOUND("Mandatory parameter missing for '%s'. Expected '%s'.", "SMB_111"),
        INVALID_CONTENT_PARAMETER_TYPE("Invalid parameter type for handler '%s'. Expected '%s', found '%s'.",
                "SMB_112"),
        INVALID_OPTIONAL_PARAMETER("Invalid parameter for '%s'. Optional parameters must be 'smb:FileInfo' " +
                "or 'smb:Caller'.", "SMB_113"),
        DUPLICATE_OPTIONAL_PARAMETER("Duplicate parameter for '%s'. '%s' is specified more than once.", "SMB_114"),
        TOO_MANY_PARAMETERS("Too many parameters for '%s'. Format-specific handlers accept at most 3 parameters: " +
                "(content, fileInfo?, caller?).", "SMB_115"),
        INVALID_RETURN_TYPE_ERROR_OR_NIL("Invalid return type. Expected 'error?' or 'smb:Error?'.", "SMB_116"),

        ON_FILE_DELETE_MUST_BE_REMOTE("onFileDelete method must be remote.", "SMB_120"),
        INVALID_ON_FILE_DELETE_PARAMETER("Invalid parameter for onFileDelete. First parameter must be " +
                "'string' (deleted file path).", "SMB_121"),
        INVALID_ON_FILE_DELETE_CALLER_PARAMETER("Invalid second parameter for onFileDelete. " +
                "Optional second parameter must be 'Caller'.", "SMB_122"),
        TOO_MANY_PARAMETERS_ON_FILE_DELETE("Too many parameters for onFileDelete. Accepts at most 2 parameters: " +
                "(deletedFile, caller?).", "SMB_123"),

        ON_ERROR_MUST_BE_REMOTE("onError method must be remote.", "SMB_130"),
        INVALID_ON_ERROR_FIRST_PARAMETER("Invalid first parameter for onError. First parameter must be " +
                "'smb:Error' or 'error'.", "SMB_131"),
        TOO_MANY_PARAMETERS_ON_ERROR("Too many parameters for onError. Accepts exactly 1 parameter: (error).",
                "SMB_132");

        private final String error;
        private final String errorCode;

        CompilationErrors(String error, String errorCode) {
            this.error = error;
            this.errorCode = errorCode;
        }

        public String getError() {
            return error;
        }

        public String getErrorCode() {
            return errorCode;
        }
    }
}
