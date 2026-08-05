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

// Client with anonymous authentication (no auth config).
// Anonymous auth is only compatible with SMB_2_1 and SMB_2_0_2 dialects.
final Client anonymousSmbClient = check new ({
    host: "localhost",
    port: 445,
    share: "publicshare",
    dialects: [SMB_2_1, SMB_2_0_2]
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

@test:Config {
    groups: ["client", "kerberos"]
}
function testKerberosClientWithPassword() returns error? {
    // credentials + kerberosConfig (no keytab) → loginWithPassword() in SmbClient
    Client|Error kerbClient = new ({
        host: "localhost",
        port: 445,
        share: "testshare",
        auth: {
            credentials: {
                username: "user",
                password: "kerbpass"
            },
            kerberosConfig: {
                principal: "user@EXAMPLE.COM"
            }
        }
    });
    test:assertTrue(kerbClient is Error,
        "Kerberos password-based client should fail when no KDC is available");
}

@test:Config {
    groups: ["client", "kerberos"],
    dependsOn: [testKerberosClientWithPassword]
}
function testKerberosClientWithKeytab() returns error? {
    // kerberosConfig + invalid keytab + configFile (no credentials) → loginWithKeytab()
    // Also covers the setKerberosSystemProperties configFile branch.
    Client|Error kerbClient = new ({
        host: "localhost",
        port: 445,
        share: "testshare",
        auth: {
            kerberosConfig: {
                principal: "user@EXAMPLE.COM",
                keytab: "/nonexistent/path/keytab.keytab",
                configFile: "/nonexistent/krb5.conf"
            }
        }
    });
    test:assertTrue(kerbClient is Error,
        "Kerberos keytab-based client should fail when keytab file does not exist");
}

@test:Config {
    groups: ["client", "kerberos"],
    dependsOn: [testKerberosClientWithKeytab]
}
function testKerberosClientWithTicketCache() returns error? {
    // credentials + kerberosConfig, EMPTY password, no keytab → loginWithTicketCache()
    Client|Error kerbClient = new ({
        host: "localhost",
        port: 445,
        share: "testshare",
        auth: {
            credentials: {
                username: "user",
                password: ""
            },
            kerberosConfig: {
                principal: "user@EXAMPLE.COM"
            }
        }
    });
    test:assertTrue(kerbClient is Error,
        "Kerberos ticket-cache client should fail when no TGT is available");
}


@test:Config {
    groups: ["client", "anonymous"]
}
function testAnonymousClientWithSMB3DialectsFails() {
    Client|Error result = new ({
        host: "localhost",
        port: 445,
        share: "publicshare",
        dialects: [SMB_3_1_1, SMB_3_0_2, SMB_3_0, SMB_2_1, SMB_2_0_2]
    });
    test:assertTrue(result is Error,
        "Anonymous client with SMB 3.x dialects should fail with a dialect compatibility error");
    if result is Error {
        test:assertTrue(result.message().includes("SMB_2_1") && result.message().includes("SMB_2_0_2"),
            "Error message should mention the compatible dialects");
    }
}

@test:Config {
    groups: ["client", "anonymous"]
}
function testAnonymousClientWithOnlySMB3DialectsFails() {
    Client|Error result = new ({
        host: "localhost",
        port: 445,
        share: "publicshare",
        dialects: [SMB_3_1_1]
    });
    test:assertTrue(result is Error,
        "Anonymous client with only SMB 3.x dialects should fail");
}
