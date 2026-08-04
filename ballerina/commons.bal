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
