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

/**
 * The SMB service contract the listener dispatches against: the handler method names it looks for, the
 * {@code @smb:FunctionConfig} fields it reads, and the module types it hands to a handler.
 */
public final class ListenerConstants {

    private ListenerConstants() {}

    // Content handler method names, dispatched by file extension
    public static final String ON_FILE = "onFile";
    public static final String ON_FILE_TEXT = "onFileText";
    public static final String ON_FILE_JSON = "onFileJson";
    public static final String ON_FILE_XML = "onFileXml";
    public static final String ON_FILE_CSV = "onFileCsv";

    // Event handler method names
    public static final String ON_FILE_DELETE = "onFileDelete";
    public static final String ON_ERROR_METHOD = "onError";

    // The @smb:FunctionConfig annotation and its fields
    public static final String FUNCTION_CONFIG = "FunctionConfig";
    public static final String FILE_NAME_PATTERN = "fileNamePattern";
    public static final String AFTER_PROCESS = "afterProcess";
    public static final String AFTER_ERROR = "afterError";
    public static final String MOVE_TO = "moveTo";
    public static final String PRESERVE_SUB_DIRS = "preserveSubDirs";

    // Module types a handler may be given
    public static final String FILE_INFO = "FileInfo";
    public static final String CALLER = "Caller";
    public static final String CLIENT = "Client";

    public static final String COLON = ":";
}
