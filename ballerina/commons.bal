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

# NTLMv2 credentials for connecting to an SMB share.
#
# + username - Username for SMB authentication
# + password - Password for SMB authentication
# + domain - Domain for domain-based authentication
public type Credentials record {|
    string username;
    string password;
    string domain = "WORKGROUP";
|};

# Kerberos authentication configuration.
#
# + principal - Kerberos principal name in the `user@REALM` format
# + keytab - Path to the keytab file. The password is used when this is not provided
# + configFile - Path to the Kerberos configuration file (`krb5.conf`)
public type KerberosConfig record {|
    string principal;
    string keytab?;
    string configFile?;
|};

# Authentication options for an SMB connection. Provide either NTLMv2 credentials or a Kerberos configuration.
#
# + credentials - NTLMv2 credentials
# + kerberosConfig - Kerberos configuration
public type AuthConfiguration record {|
    Credentials credentials?;
    KerberosConfig kerberosConfig?;
|};

# Socket timeout configurations.
#
# + dataTimeout - Data transfer timeout in seconds
# + socketTimeout - Socket operation timeout in seconds
# + sessionTimeout - SMB session timeout in seconds
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

# Timestamp used when calculating the age of a file.
#
# LAST_MODIFIED - The file's last modified timestamp
# CREATION_TIME - The file's creation timestamp, where the file system supports it
public enum AgeCalculationMode {
    LAST_MODIFIED,
    CREATION_TIME
}

# Restricts file events to files within a given age range.
#
# + minAge - Minimum age of the file in seconds, inclusive. Younger files are skipped
# + maxAge - Maximum age of the file in seconds, inclusive. Older files are skipped
# + ageCalculationMode - Timestamp to measure the file's age from
public type FileAgeFilter record {|
    decimal minAge?;
    decimal maxAge?;
    AgeCalculationMode ageCalculationMode = LAST_MODIFIED;
|};

# How many of the required files must be present for a dependency to be satisfied.
#
# ALL - Every required file pattern must have at least one match
# ANY - At least one required file pattern must have a match
# EXACT_COUNT - The number of matches must equal `requiredFileCount`
public enum DependencyMatchingMode {
    ALL,
    ANY,
    EXACT_COUNT
}

# Delays processing of a file until the files it depends on are present on the share.
#
# + targetPattern - Regular expression for the files processed conditionally
# + requiredFiles - File patterns that must exist. Capture groups from `targetPattern` can be referenced as `$1`
# + matchingMode - How many of the required files must be present
# + requiredFileCount - Number of matches expected in the `EXACT_COUNT` mode
public type FileDependencyCondition record {|
    string targetPattern;
    string[] requiredFiles;
    DependencyMatchingMode matchingMode = ALL;
    int requiredFileCount = 1;
|};
