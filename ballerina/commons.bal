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

import ballerina/io;

# SMB authentication credentials for connecting to SMB shares.
#
# + username - Username for SMB authentication
# + password - Password for SMB authentication
# + domain - Optional domain for domain-based authentication
public type Credentials record {|
    string username;
    string password;
    string domain = "WORKGROUP";
|};

# Kerberos authentication configuration.
#
# + principal - Kerberos principal name in user@REALM format (e.g., user@EXAMPLE.COM)
# + keytab - Path to the keytab file for authentication (optional, uses password if not provided)
# + configFile - Path to the Kerberos configuration file (krb5.conf)
public type KerberosConfig record {|
    string principal;
    string keytab?;
    string configFile?;
|};

# Specifies authentication options for SMB server connections. Supports both NTLMv2 and Kerberos authentication.
#
# + credentials - Username, password, and optional domain for authentication
# + kerberosConfig - Additional configurations for Kerberos authentication
public type AuthConfiguration record {|
    Credentials credentials?;
    KerberosConfig kerberosConfig?;
|};

# Socket timeout configurations
#
# + dataTimeout - Data transfer timeout in seconds (default: 120.0)
# + socketTimeout - Socket operation timeout in seconds (default: 60.0)
# + sessionTimeout - SMB session timeout in seconds (default: 300.0)
public type SocketConfig record {|
    decimal dataTimeout = 120.0;
    decimal socketTimeout = 60.0;
    decimal sessionTimeout = 300.0;
|};

# Internal configuration for content to be written in put and append operations.
#
# + filePath - Path of the file to be created or appended
# + isFile - `true` if the input type is a file stream
# + fileContent - The content read from the input file stream
# + textContent - The input content as text
# + compressInput - If `true`, input will be compressed before uploading
public type InputContent record {|
    string filePath;
    boolean isFile = false;
    stream<byte[] & readonly, io:Error?> fileContent?;
    string textContent?;
    boolean compressInput = false;
|};

# Determines the timestamp used when calculating file age for filtering.
#
# LAST_MODIFIED - Use file's last modified timestamp (default)
# CREATION_TIME - Use file's creation timestamp (where supported by file system)
public enum AgeCalculationMode {
    LAST_MODIFIED,
    CREATION_TIME
}

# Filters files based on their age to control which files trigger listener events.
# Useful for processing only files within a specific age range (e.g., skip very new files or very old files).
#
# + minAge - Minimum age of file in seconds since last modification/creation (inclusive).
#            Files younger than this will be skipped. If not specified, no minimum age requirement.
# + maxAge - Maximum age of file in seconds since last modification/creation (inclusive).
#            Files older than this will be skipped. If not specified, no maximum age requirement.
# + ageCalculationMode - Whether to calculate age based on last modified time or creation time
public type FileAgeFilter record {|
    decimal minAge?;
    decimal maxAge?;
    AgeCalculationMode ageCalculationMode = LAST_MODIFIED;
|};

# Determines how to match required files when evaluating file dependencies.
# Controls whether all dependencies must be present, at least one, or a specific count.
# ALL - All required file patterns must have at least one matching file (default)
# ANY - At least one required file pattern must have a matching file
# EXACT_COUNT - Exact number of required files must match (count specified in requiredFileCount)
public enum DependencyMatchingMode {
    ALL,
    ANY,
    EXACT_COUNT
}

# Defines a dependency condition where processing of target files depends on the existence of other files.
# This allows conditional file processing based on the presence of related files (e.g., processing a data file only
# when a corresponding marker file exists). Supports capture group substitution to dynamically match related files.
#
# + targetPattern - Regex pattern for files that should be processed conditionally
# + requiredFiles - Array of file patterns that must exist. Supports capture group substitution (e.g., "$1")
# + matchingMode - How to match required files (ALL, ANY, or EXACT_COUNT)
# + requiredFileCount - For EXACT_COUNT mode, specifies the exact number of required files
public type FileDependencyCondition record {|
    string targetPattern;
    string[] requiredFiles;
    DependencyMatchingMode matchingMode = ALL;
    int requiredFileCount = 1;
|};
