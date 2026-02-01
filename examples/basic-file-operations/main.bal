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
import ballerina/log;
import ballerina/smb;

configurable string kerberosHost = ?;
configurable string kerberosUser = ?;
configurable string kerberosPassword = ?;
configurable string kerberosDomain = ?;
configurable string kerberosShare = ?;
configurable string kerberosConfigFile = ?;

public function main() returns error? {
    smb:Client|error kerberosClient = check new ({
        host: kerberosHost,
        port: 445,
        auth: {
            credentials: {
                username: kerberosUser,
                password: kerberosPassword,
                domain: kerberosDomain
            }
        },
        share: kerberosShare
    });


    if kerberosClient is error {
        log:printError(kerberosClient.message(), kerberosClient);
        io:println("Error occurred while creating the Kerberos authenticated SMB client: " +
            kerberosClient.message());
        return error (kerberosClient.message());
    }

    smb:FileInfo[]|error listResult = kerberosClient->list("/");
    io:println(listResult);
 
    string testFileName = "/kerberos_file.txt";
    string testContent = "Hello from NTLM authenticated client!";
    _ = check kerberosClient->putText(testFileName, testContent);
    boolean existsResult = check kerberosClient->exists(testFileName);
    if !existsResult {
        io:println("File creation failed.");
        return;
    }
    string readResult = check kerberosClient->getText(testFileName);
    io:println(readResult);
}
