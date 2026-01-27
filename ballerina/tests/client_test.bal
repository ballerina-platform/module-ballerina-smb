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

import ballerina/test;

final Client smbClient = check new ({
    host: "localhost",
    port: 445,
    auth: {
        credentials: {
            username: "testuser",
            password: "testpass"
        }
    },
    share: "testshare"
});

// Client with anonymous authentication (no auth config)
final Client anonymousSmbClient = check new ({
    host: "localhost",
    port: 445,
    share: "publicshare"
});

@test:Config {
    groups: ["client", "put"],
    dependsOn: [testCreateFile]
}
function testListFiles() returns error? {
    FileInfo[]|error listResult = smbClient->list("/shared");
    test:assertTrue(listResult !is error);
}

@test:Config {
    groups: ["client", "put"],
    dependsOn: [testCreateDirectory]
}
function testCreateFile() returns error? {
    error? putResult = smbClient->putBytes("/testFile.txt", "This is a test file.".toBytes());
    test:assertEquals(putResult, ());
}

@test:Config {
    groups: ["client", "put"]
}
function testCreateDirectory() returns error? {
    error? result = smbClient->mkdir("shared");
    test:assertEquals(result, ());
}

@test:Config {
    groups: ["client", "anonymous"],
    dependsOn: [testCreateDirectory]
}
function testAnonymousClientListFiles() returns error? {
    _ = check anonymousSmbClient->mkdir("test");
    string path = "/test/put-text-append.txt";
    string content1 = "Hello ";
    check anonymousSmbClient->putText(path, content1, OVERWRITE);
    FileInfo[]|error listResult = anonymousSmbClient->list("test");
    test:assertTrue(listResult !is error, "Anonymous client should be able to list files");
}
