// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/time;

# Configuration for SMB client.
#
# + host - Target SMB server hostname or IP address
# + share - SMB share name to connect to
# + port - Port number of the SMB service (default: 445)
# + auth - Authentication credentials for SMB connection
# + dialects - Supported SMB protocol dialects
# + signRequired - Whether SMB message signing is required (default: false)
# + encryptData - Whether to encrypt SMB data (default: false)
# + enableDfs - Whether to enable Distributed File System support (default: false)
# + bufferSize - Size of the buffer for read/write operations in bytes
# + connectTimeout - Connection timeout in seconds (default: 30.0)
# + laxDataBinding - If set to `true`, enables relaxed data binding for XML, JSON, and CSV responses (default: false)
public type ClientConfiguration record {|
    string host = "localhost";
    int port = 445;
    string share;
    AuthConfiguration auth?;
    Dialect[] dialects = [SMB_3_1_1, SMB_3_0_2, SMB_3_0, SMB_2_1, SMB_2_0_2];
    boolean signRequired = false;
    boolean encryptData = false;
    boolean enableDfs = false;
    int bufferSize = 65536;
    decimal connectTimeout = 30.0;
    boolean laxDataBinding = false;
|};

# File write options for write operations.
# OVERWRITE - Overwrite the existing file content
# APPEND - Append to the existing file content
public enum FileWriteOption {
    OVERWRITE,
    APPEND
}

# Compression type for file uploads.
# ZIP - Zip compression
# NONE - No compression
public enum Compression {
    ZIP,
    NONE
}

public enum Dialect {
    SMB_3_1_1, 
    SMB_3_0_2,
    SMB_3_0, 
    SMB_2_1, 
    SMB_2_0_2
};

# Metadata about a file or directory on the SMB server.
#
# + name - Name of the file or directory
# + path - Relative file path
# + size - Size of the file in bytes
# + modifiedAt - Last modified time of the file in UTC
# + createdAt - File creation time in UTC
# + accessedAt - Last access time of the file in UTC
# + writtenAt - Last write time of the file in UTC
# + isDirectory - `true` if the resource is a directory
# + extension - File name extension
# + isExecutable - `true` if the file has execute permissions
# + isHidden - `true` if the file is marked as hidden
# + isWritable - `true` if the file has write permissions
# + uri - Absolute URI of the file
public type FileInfo record {|
    string name;
    string path;
    int size;
    time:Utc modifiedAt;
    time:Utc createdAt;
    time:Utc accessedAt;
    time:Utc writtenAt;
    boolean isDirectory;
    string extension;
    boolean isExecutable;
    boolean isHidden;
    boolean isWritable;
    string uri;
|};

# File system changes detected by the SMB listener in a polling cycle.
#
# + addedFiles - Array of newly added files
# + deletedFiles - Array of deleted file names
public type WatchEvent record {|
    FileInfo[] addedFiles;
    string[] deletedFiles;
|};


# Configuration for the SMB listener.
#
# + host - Target SMB server hostname or IP address
# + port - Port number of the SMB service (default: 445)
# + share - SMB share name to connect to
# + auth - Authentication options for connecting to the server
# + fileNamePattern - File name pattern (regex) to filter which files trigger events (optional)
# + pollingInterval - Polling interval in seconds for checking file changes (default: 60)
# + dialects - Supported SMB protocol dialects (default: all versions from SMB 2.0.2 to 3.1.1)
# + signRequired - Whether SMB message signing is required (default: false)
# + encryptData - Whether to encrypt SMB data (default: false)
# + enableDfs - Whether to enable Distributed File System support (default: false)
# + bufferSize - Size of the buffer for read/write operations in bytes (default: 65536)
# + connectTimeout - Connection timeout in seconds (default: 30.0)
# + laxDataBinding - If set to `true`, enables relaxed data binding for XML and JSON responses (default: false)
public type ListenerConfiguration record {|
    string host = "localhost";
    int port = 445;
    string share = "";
    AuthConfiguration auth?;
    string fileNamePattern?;
    decimal pollingInterval = 60;
    Dialect[] dialects = [SMB_3_1_1, SMB_3_0_2, SMB_3_0, SMB_2_1, SMB_2_0_2];
    boolean signRequired = false;
    boolean encryptData = false;
    boolean enableDfs = false;
    int bufferSize = 65536;
    decimal connectTimeout = 30.0;
    boolean laxDataBinding = false;
|};

# Configuration annotation for SMB content handler functions.
# This annotation can be used to specify custom file name patterns for content handler methods.
#
# + fileNamePattern - Regular expression pattern to match file names (e.g., "(.*).txt", "data_(.*).json")
public type FunctionConfiguration record {|
    string fileNamePattern?;
|};

# Annotation to configure content handler function behavior.
public annotation FunctionConfiguration FunctionConfig on function;

# SMB service for handling file system change events.
#
# The listener supports the following content handler methods that automatically deserialize file content:
# - `onFileText(string content, FileInfo fileInfo, Caller caller)` - Handle text files
# - `onFileJson(json content, FileInfo fileInfo, Caller caller)` - Handle JSON files
# - `onFileXml(xml content, FileInfo fileInfo, Caller caller)` - Handle XML files
# - `onFileCsv(string[][]|record{}[]|stream<string[], error?>|stream<record{}, error?> content, FileInfo fileInfo, Caller caller)` - Handle CSV files
# - `onFile(byte[]|stream<byte[], error?> content, FileInfo fileInfo, Caller caller)` - Handle any files (fallback)
# - `onError(error err)` - Handle errors during listener operations
#
# The `fileInfo` and `caller` parameters are optional and can be omitted if not needed.
# The first row of CSV files is expected to contain column headers when using record types.
#
# File extension-based routing: `.txt` → `onFileText`, `.json` → `onFileJson`,
# `.xml` → `onFileXml`, `.csv` → `onFileCsv`, other extensions → `onFile`.
# Use `@smb:FunctionConfig` annotation to specify custom file name patterns for each handler.
public type Service distinct service object {


    // # Invoked when text files (.txt) are added to the monitored directory.
    // #
    // # + content - Text content of the file
    // # + fileInfo - Metadata about the file
    // # + return - `()` or else an `error` upon failure to process the file
    // remote function onFileText(string content, FileInfo fileInfo) returns error?;

    // # Invoked when JSON files (.json) are added to the monitored directory.
    // #
    // # + content - JSON content of the file (can be typed to a record for automatic deserialization)
    // # + fileInfo - Metadata about the file
    // # + return - `()` or else an `error` upon failure to process the file
    // remote function onFileJson(json content, FileInfo fileInfo) returns error?;

    // # Invoked when XML files (.xml) are added to the monitored directory.
    // #
    // # + content - XML content of the file (can be typed to a record for automatic deserialization)
    // # + fileInfo - Metadata about the file
    // # + return - `()` or else an `error` upon failure to process the file
    // remote function onFileXml(xml content, FileInfo fileInfo) returns error?;

    // # Invoked when CSV files (.csv) are added to the monitored directory.
    // # Supported content types:
    // # - `string[][]` - In-memory array of string arrays (all rows at once)
    // # - `record{}[]` - In-memory array of records (type-safe, auto data-bound using headers as field names)
    // # - `stream<string[], error?>` - Streaming string arrays (memory-efficient for large files)
    // # - `stream<record{}, error?>` - Streaming records (type-safe and memory-efficient)
    // #
    // # The first row of CSV files is expected to contain column headers when using record types.
    // # The `fileInfo` and `caller` parameters are optional.
    // #
    // # + content - CSV content in one of the supported types
    // # + fileInfo - Metadata about the file (optional)
    // # + caller - SMB caller for file operations (optional)
    // # + return - `()` or else an `error` upon failure to process the file
    // remote function onFileCsv(string[][]|record{}[]|stream<string[], error?>|stream<record{}, error?> content, FileInfo fileInfo, Caller caller) returns error?;

    // # Invoked for any file type as a fallback handler.
    // #
    // # + content - File content as byte array or stream
    // # + fileInfo - Metadata about the file
    // # + return - `()` or else an `error` upon failure to process the file
    // remote function onFile(byte[] content, FileInfo fileInfo) returns error?;


    // # Invoked when an error occurs during listener operations.
    // #
    // # + err - The error that occurred
    // # + return - `()` or else an `error` upon failure to handle the error
    // public isolated function onError(error err) returns error?;
};
