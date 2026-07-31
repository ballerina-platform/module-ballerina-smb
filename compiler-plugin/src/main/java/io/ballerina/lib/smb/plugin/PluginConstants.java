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

    // Content handler function names, dispatched by file extension
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
     * All `onFile*` handler names. These handlers convert the file content to the parameter's type.
     */
    public static final Set<String> ALL_CONTENT_HANDLERS = Set.of(
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

    /**
     * Diagnostics reported by the SMB compiler plugin.
     *
     * <p>Messages follow the phrasing used by the other Ballerina listener compiler plugins: a lowercase
     * opening, no trailing period, and the offending value interpolated so the reader does not have to
     * look it up.
     *
     * <p>Identifiers and types are wrapped in backticks, never single quotes, and must never contain
     * curly braces. The rendered {@code Diagnostic.message()} goes through {@code MessageFormat}, which
     * strips single quotes and throws on a brace it cannot parse as an argument index — so {@code 'onFile'}
     * would reach the user as a bare {@code onFile}, and {@code record{}} would abort the compilation.
     * Write "a record type" rather than {@code record{}}.
     */
    public enum CompilationErrors {
        INVALID_REMOTE_FUNCTION("invalid remote method name `%s`, smb listener only supports `onFile`, " +
                "`onFileText`, `onFileJson`, `onFileXml`, `onFileCsv`, `onFileDelete` and `onError` " +
                "remote methods", "SMB_101"),
        RESOURCE_FUNCTION_NOT_ALLOWED("resource methods are not allowed in smb services", "SMB_102"),
        NO_VALID_REMOTE_METHOD("at least a single `onFile*` or `onFileDelete` remote method required in the " +
                "service", "SMB_103"),

        CONTENT_METHOD_MUST_BE_REMOTE("missing remote keyword in the `%s` method", "SMB_110"),
        MANDATORY_PARAMETER_NOT_FOUND("missing required parameter in the `%s` method, expected %s", "SMB_111"),
        INVALID_CONTENT_PARAMETER_TYPE("invalid parameter type `%s` provided for the `%s` method, expected %s",
                "SMB_112"),
        INVALID_OPTIONAL_PARAMETER("invalid parameter type `%s` provided for the `%s` method, only " +
                "`smb:FileInfo` and `smb:Caller` are allowed as optional parameters", "SMB_113"),
        DUPLICATE_OPTIONAL_PARAMETER("duplicate `%s` parameter in the `%s` method", "SMB_114"),
        TOO_MANY_PARAMETERS("too many parameters in the `%s` method, only content, `smb:FileInfo` and " +
                "`smb:Caller` parameters are allowed", "SMB_115"),
        INVALID_RETURN_TYPE_ERROR_OR_NIL("invalid return type, only `error?` and `smb:Error?` are allowed",
                "SMB_116"),

        ON_FILE_DELETE_MUST_BE_REMOTE("missing remote keyword in the `onFileDelete` method", "SMB_120"),
        INVALID_ON_FILE_DELETE_PARAMETER("invalid parameter type `%s` provided for the `onFileDelete` method, " +
                "expected `string`", "SMB_121"),
        INVALID_ON_FILE_DELETE_CALLER_PARAMETER("invalid parameter type `%s` provided for the `onFileDelete` " +
                "method, only `smb:Caller` is allowed as the optional parameter", "SMB_122"),
        TOO_MANY_PARAMETERS_ON_FILE_DELETE("too many parameters in the `onFileDelete` method, only `string` and " +
                "`smb:Caller` parameters are allowed", "SMB_123"),

        ON_ERROR_MUST_BE_REMOTE("missing remote keyword in the `onError` method", "SMB_130"),
        INVALID_ON_ERROR_FIRST_PARAMETER("invalid parameter type `%s` provided for the `onError` method, " +
                "expected `error` or `smb:Error`", "SMB_131"),
        INVALID_ON_ERROR_SECOND_PARAMETER("invalid parameter type `%s` provided for the `onError` method, only " +
                "`smb:Caller` is allowed as the optional parameter", "SMB_132"),
        TOO_MANY_PARAMETERS_ON_ERROR("too many parameters in the `onError` method, only `error` and " +
                "`smb:Caller` parameters are allowed", "SMB_133");

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
