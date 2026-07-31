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

# Configuration for the SMB client.
#
# + host - Target SMB server hostname or IP address
# + share - SMB share name to connect to
# + port - Port number of the SMB service
# + auth - Authentication credentials for the SMB connection
# + dialects - SMB protocol dialects to negotiate with, in order of preference
# + signRequired - Whether SMB message signing is required
# + encryptData - Whether to encrypt SMB data
# + enableDfs - Whether to enable Distributed File System (DFS) support
# + bufferSize - Size of the buffer for read/write operations in bytes
# + connectTimeout - Connection timeout in seconds
# + laxDataBinding - Whether to relax data binding for XML, JSON, and CSV content
# + csvFailSafe - Skips malformed CSV records and logs them to a file instead of failing the operation
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
    FailSafeOptions csvFailSafe?;
|};

# How content is written to an existing file.
#
# OVERWRITE - Replace the existing file content
# APPEND - Add to the end of the existing file content
public enum FileWriteOption {
    OVERWRITE,
    APPEND
}

# Compression applied to file uploads.
#
# ZIP - Zip compression
# NONE - No compression
public enum Compression {
    ZIP,
    NONE
}

# SMB protocol dialect used to communicate with the server.
#
# SMB_3_1_1 - SMB 3.1.1
# SMB_3_0_2 - SMB 3.0.2
# SMB_3_0 - SMB 3.0
# SMB_2_1 - SMB 2.1
# SMB_2_0_2 - SMB 2.0.2
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

# Configuration for the SMB listener.
#
# + host - Target SMB server hostname or IP address
# + port - Port number of the SMB service (default: 445)
# + share - SMB share name to connect to
# + auth - Authentication credentials for the SMB connection
# + fileNamePattern - Regular expression a file name must match to trigger a handler
# + pollingInterval - Interval in seconds between polls of the watched directory
# + dialects - SMB protocol dialects to negotiate with, in order of preference
# + signRequired - Whether SMB message signing is required
# + encryptData - Whether to encrypt SMB data
# + enableDfs - Whether to enable Distributed File System (DFS) support
# + bufferSize - Size of the buffer for read/write operations in bytes
# + connectTimeout - Connection timeout in seconds
# + laxDataBinding - Whether to relax data binding for XML, JSON, and CSV content
# + csvFailSafe - Skips malformed CSV records and logs them to a file instead of failing the operation
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
    FailSafeOptions csvFailSafe?;
|};

# Post-processing action that deletes the file.
public const DELETE = "DELETE";

# Post-processing action that moves the file to another directory.
#
# + moveTo - Destination directory path within the share
# + preserveSubDirs - Whether to recreate the file's subdirectory structure under the destination
public type Move record {|
    string moveTo;
    boolean preserveSubDirs = true;
|};

# Alias for the `Move` record, used in post-processing action unions.
public type MOVE Move;

# Configuration for a single SMB content handler method.
#
# + fileNamePattern - Regular expression a file name must match for this handler to run
# + afterProcess - Action to take once the handler completes successfully. The file stays in place if not specified
# + afterError - Action to take when the handler fails. The file stays in place if not specified
public type FunctionConfiguration record {|
    string fileNamePattern?;
    MOVE|DELETE afterProcess?;
    MOVE|DELETE afterError?;
|};

# The annotation to configure an SMB content handler method.
public annotation FunctionConfiguration FunctionConfig on service remote function;

# Configuration for an SMB service.
#
# + path - Directory within the share to watch. Defaults to the service name
public type SmbServiceConfig record {|
    string path?;
|};

# The annotation to configure an SMB service.
public annotation SmbServiceConfig ServiceConfig on service;

# Represents an SMB service that handles file events from an `smb:Listener`.
public type Service service object {
};

# Record returned from the `next` method in `ContentByteStream`.
#
# + value - The array of bytes
public type ContentStreamEntry record {|
    byte[] value;
|};

# Record returned from the `next` method in `ContentCsvStringArrayStream`.
#
# + value - The array of strings representing a CSV row
public type ContentCsvStringArrayStreamEntry record {|
    string[] value;
|};

# Record returned from the `next` method in `ContentCsvRecordStream`.
#
# + value - The record deserialized from a CSV row
public type ContentCsvRecordStreamEntry record {|
    record {} value;
|};

# Fail-safe options for CSV content processing.
#
# + contentType - What to record in the error log for each skipped record
public type FailSafeOptions record {|
    ErrorLogContentType contentType = METADATA;
|};

# What is recorded for a CSV record skipped during fail-safe processing.
#
# METADATA - The record's position and the reason it was skipped
# RAW - The raw text of the record
# RAW_AND_METADATA - Both the raw text and the metadata
public enum ErrorLogContentType {
    METADATA,
    RAW,
    RAW_AND_METADATA
}
