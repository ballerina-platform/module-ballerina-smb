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
import ballerina/lang.runtime;
import ballerina/test;

// These tests cover the Kerberos authentication paths in SmbListenerHelper.java:
//  - kerberosConfig with no keytab and no credentials  → MISSING_CREDENTIALS_FOR_KERBEROS_ERROR
//  - kerberosConfig with invalid keytab path           → loginWithKeytab fails
//  - kerberosConfig with credentials, no keytab        → loginWithPassword fails
//  - kerberosConfig with empty password, no keytab     → loginWithTicketCache fails
//
// All of these cause poll() to call notifyServicesOnError() → onError().

int kerbNoKeytabNoCredsCounter = 0;
int kerbInvalidKeytabCounter = 0;
int kerbPasswordBasedCounter = 0;
int kerbTicketCacheCounter = 0;
int listenerStringArrayAttachCounter = 0;

// Test 1: kerberosConfig with principal only (no keytab, no credentials).
// Covers the `credentials == null && !hasKeytab` branch in createAuthContext that throws
// MISSING_CREDENTIALS_FOR_KERBEROS_ERROR.
@test:Config {
    groups: ["listener", "kerberos"]
}
function testKerberosListenerNoKeytabNoCredentials() returns error? {
    kerbNoKeytabNoCredsCounter = 0;

    Service kerbNoCredService = service object {
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            io:println("should not be reached");
        }

        function onError(error err) returns error? {
            kerbNoKeytabNoCredsCounter += 1;
            io:println("Expected kerberos error (no keytab, no creds): ", err.message());
        }
    };

    ListenerConfiguration kerbNoCredConfig = {
        host: "localhost",
        port: 445,
        share: "testshare",
        auth: {
            kerberosConfig: {
                principal: "user@EXAMPLE.COM"
            }
        },
        pollingInterval: 1,
        bufferSize: 65536
    };

    Listener kerbNoCredListener = check new (kerbNoCredConfig);
    check kerbNoCredListener.attach(kerbNoCredService, "any_path");
    check kerbNoCredListener.'start();
    runtime:registerListener(kerbNoCredListener);

    runtime:sleep(4);

    check kerbNoCredListener.immediateStop();

    test:assertTrue(kerbNoKeytabNoCredsCounter >= 1,
        "onError should fire when kerberosConfig has no keytab and no credentials");
}

// Test 2: kerberosConfig with a non-existent keytab path and a configFile (no credentials).
// Covers:
//   - the `credentials == null && hasKeytab` path that skips the early throw
//   - setKerberosSystemProperties with a non-empty configFile (System.setProperty branch)
//   - loginWithKeytab() which fails because the keytab file does not exist
@test:Config {
    groups: ["listener", "kerberos"],
    dependsOn: [testKerberosListenerNoKeytabNoCredentials]
}
function testKerberosListenerWithInvalidKeytab() returns error? {
    kerbInvalidKeytabCounter = 0;

    Service kerbKeytabService = service object {
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            io:println("should not be reached");
        }

        function onError(error err) returns error? {
            kerbInvalidKeytabCounter += 1;
            io:println("Expected kerberos error (invalid keytab): ", err.message());
        }
    };

    ListenerConfiguration kerbKeytabConfig = {
        host: "localhost",
        port: 445,
        share: "testshare",
        auth: {
            kerberosConfig: {
                principal: "user@EXAMPLE.COM",
                keytab: "/nonexistent/path/keytab.keytab",
                configFile: "/nonexistent/krb5.conf"
            }
        },
        pollingInterval: 1,
        bufferSize: 65536
    };

    Listener kerbKeytabListener = check new (kerbKeytabConfig);
    check kerbKeytabListener.attach(kerbKeytabService, "any_path");
    check kerbKeytabListener.'start();
    runtime:registerListener(kerbKeytabListener);

    runtime:sleep(4);

    check kerbKeytabListener.immediateStop();

    test:assertTrue(kerbInvalidKeytabCounter >= 1,
        "onError should fire when keytab file does not exist");
}

// Test 3: kerberosConfig + credentials but no keytab.
// Covers the `credentials != null && kerberosConfig != null && !hasKeytab` path that calls
// createKerberosAuthContext(kerberosConfig, password, domain) → loginWithPassword(), which fails
// because there is no real Kerberos KDC in the test environment.
@test:Config {
    groups: ["listener", "kerberos"],
    dependsOn: [testKerberosListenerWithInvalidKeytab]
}
function testKerberosListenerWithPasswordCredentials() returns error? {
    kerbPasswordBasedCounter = 0;

    Service kerbPasswordService = service object {
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            io:println("should not be reached");
        }

        function onError(error err) returns error? {
            kerbPasswordBasedCounter += 1;
            io:println("Expected kerberos error (password-based): ", err.message());
        }
    };

    ListenerConfiguration kerbPasswordConfig = {
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
        },
        pollingInterval: 1,
        bufferSize: 65536
    };

    Listener kerbPasswordListener = check new (kerbPasswordConfig);
    check kerbPasswordListener.attach(kerbPasswordService, "any_path");
    check kerbPasswordListener.'start();
    runtime:registerListener(kerbPasswordListener);

    runtime:sleep(4);

    check kerbPasswordListener.immediateStop();

    test:assertTrue(kerbPasswordBasedCounter >= 1,
        "onError should fire when Kerberos password-based login fails (no KDC available)");
}

// Test 4: kerberosConfig + credentials with EMPTY password, no keytab.
// An empty password causes createKerberosAuthContext to fall through to loginWithTicketCache()
// because `!password.isEmpty()` is false. loginWithTicketCache fails (no Kerberos TGT available).
@test:Config {
    groups: ["listener", "kerberos"],
    dependsOn: [testKerberosListenerWithPasswordCredentials]
}
function testKerberosListenerTicketCacheFallback() returns error? {
    kerbTicketCacheCounter = 0;

    Service kerbTicketCacheService = service object {
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            io:println("should not be reached");
        }

        function onError(error err) returns error? {
            kerbTicketCacheCounter += 1;
            io:println("Expected kerberos error (ticket-cache fallback): ", err.message());
        }
    };

    // Providing an empty password causes loginWithTicketCache() to be invoked
    ListenerConfiguration kerbTicketConfig = {
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
        },
        pollingInterval: 1,
        bufferSize: 65536
    };

    Listener kerbTicketListener = check new (kerbTicketConfig);
    check kerbTicketListener.attach(kerbTicketCacheService, "any_path");
    check kerbTicketListener.'start();
    runtime:registerListener(kerbTicketListener);

    runtime:sleep(4);

    check kerbTicketListener.immediateStop();

    test:assertTrue(kerbTicketCacheCounter >= 1,
        "onError should fire when ticket-cache Kerberos login fails (no TGT available)");
}

// Test 5: attach() with string[] name.
// The Listener.attach() signature is `string[]|string?`. When a string[] is passed, the
// `if name is string?` guard is false and the service is not registered (silent no-op).
// This covers the implicit else-branch in attach().
@test:Config {
    groups: ["listener", "attach"],
    dependsOn: [testKerberosListenerTicketCacheFallback]
}
function testAttachWithStringArrayNameIsNoOp() returns error? {
    listenerStringArrayAttachCounter = 0;

    Service stringArrayAttachService = service object {
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            listenerStringArrayAttachCounter += 1;
        }
    };

    Listener stringArrayListener = check new ({
        host: "localhost",
        port: 445,
        auth: {
            credentials: {
                username: "testuser",
                password: "testpass"
            }
        },
        share: "testshare",
        pollingInterval: 2,
        bufferSize: 65536
    });

    // Passing a string[] as name: the service is silently not registered
    error? result = stringArrayListener.attach(stringArrayAttachService, ["path1", "path2"]);
    test:assertEquals(result, (), "attach with string[] should return () without error");

    check stringArrayListener.'start();
    check stringArrayListener.immediateStop();

    // The service was never registered so no files are processed
    test:assertEquals(listenerStringArrayAttachCounter, 0,
        "No files should be processed when service is attached with a string[] name");
}

int kerbOnErrorReturnsErrCounter = 0;
boolean kerbNotifyServicesOnErrorCovered = false;

@test:Config {
    groups: ["listener", "kerberos"],
    dependsOn: [testAttachWithStringArrayNameIsNoOp]
}
function testNotifyServicesOnErrorWhenOnErrorReturnsError() returns error? {
    kerbOnErrorReturnsErrCounter = 0;

    Service onErrorReturnsErrService = service object {
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            io:println("should not be reached");
        }

        function onError(error err) returns error? {
            kerbOnErrorReturnsErrCounter += 1;
            // Returning an error from onError exercises the
            // `if (result instanceof BError)` branch inside notifyServicesOnError.
            return error("intentional error returned from onError");
        }
    };

    Listener kerbErrListener = check new ({
        host: "localhost",
        port: 445,
        share: "testshare",
        auth: {
            kerberosConfig: {
                principal: "user@EXAMPLE.COM"
            }
        },
        pollingInterval: 1,
        bufferSize: 65536
    });

    check kerbErrListener.attach(onErrorReturnsErrService, "any_path");
    check kerbErrListener.'start();
    runtime:registerListener(kerbErrListener);
    runtime:sleep(4);
    check kerbErrListener.immediateStop();

    test:assertTrue(kerbOnErrorReturnsErrCounter >= 1,
        "onError should be invoked when Kerberos poll fails");
}

int handlerRetErrCounter = 0;
int handlerOnErrorRetErrCounter = 0;

@test:Config {
    groups: ["listener", "on-error"],
    dependsOn: [testNotifyServicesOnErrorWhenOnErrorReturnsError]
}
function testNotifyServiceOnErrorWhenOnErrorReturnsError() returns error? {
    handlerRetErrCounter = 0;
    handlerOnErrorRetErrCounter = 0;

    Service handlerReturnsErrService = service object {
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            handlerRetErrCounter += 1;
            // Returning an error causes notifyServiceOnError to be invoked.
            return error("intentional handler error");
        }

        function onError(error err) returns error? {
            handlerOnErrorRetErrCounter += 1;
            // Returning an error from onError covers the
            // `if (result instanceof BError)` branch inside notifyServiceOnError.
            return error("intentional error returned from onError");
        }
    };

    _ = check smbClient->mkdir("/handler_err_test");

    Listener l = check new ({
        host: "localhost",
        port: 445,
        auth: {
            credentials: {
                username: "testuser",
                password: "testpass"
            }
        },
        share: "testshare",
        pollingInterval: 2,
        bufferSize: 65536
    });

    check l.attach(handlerReturnsErrService, "handler_err_test");
    check l.'start();
    runtime:registerListener(l);
    runtime:sleep(3);

    handlerRetErrCounter = 0;
    handlerOnErrorRetErrCounter = 0;
    check smbClient->putBytes("/handler_err_test/trigger.bin", "test".toBytes());
    runtime:sleep(6);
    check l.immediateStop();

    test:assertTrue(handlerRetErrCounter >= 1,
        "onFile handler should fire and return an error");
    test:assertTrue(handlerOnErrorRetErrCounter >= 1,
        "onError should be invoked when onFile returns an error");
}
