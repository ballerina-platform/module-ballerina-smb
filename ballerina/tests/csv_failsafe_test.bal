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

import ballerina/lang.runtime;
import ballerina/log;
import ballerina/test;

final ClientConfiguration csvFailSafeMetadataConfig = {
    host: "localhost",
    port: 445,
    share: "testshare",
    auth: {
        credentials: {
            username: "testuser",
            password: "testpass"
        }
    },
    csvFailSafe: {
        contentType: METADATA
    }
};

final ClientConfiguration csvFailSafeRawConfig = {
    host: "localhost",
    port: 445,
    share: "testshare",
    auth: {
        credentials: {
            username: "testuser",
            password: "testpass"
        }
    },
    csvFailSafe: {
        contentType: RAW
    }
};

final ClientConfiguration csvFailSafeRawAndMetadataConfig = {
    host: "localhost",
    port: 445,
    share: "testshare",
    auth: {
        credentials: {
            username: "testuser",
            password: "testpass"
        }
    },
    csvFailSafe: {
        contentType: RAW_AND_METADATA
    }
};

final ClientConfiguration csvFailSafeWithLaxConfig = {
    host: "localhost",
    port: 445,
    share: "testshare",
    auth: {
        credentials: {
            username: "testuser",
            password: "testpass"
        }
    },
    laxDataBinding: true,
    csvFailSafe: {
        contentType: METADATA
    }
};

type CsvRecord record {|
    string name;
    int age;
    string city;
|};

int csvStreamRowsProcessed = 0;
FileInfo? lastCsvFileInfo = ();
boolean csvContentMethodInvoked = false;

const string CSV_FAILSAFE_TEST_DIR = "/csv_failsafe_listener_test";

@test:Config {
    groups: ["csvFailSafe", "read"]
}
function testReadValidCsvWithFailSafe() returns error? {
    Client csvClient = check new (csvFailSafeMetadataConfig);
    _ = check csvClient->mkdir("csvfailsafe");

    string path = "/csvfailsafe/valid-data.csv";
    string[][] content = [
        ["name", "age", "city"],
        ["Alice", "25", "New York"],
        ["Bob", "30", "Boston"]
    ];
    check csvClient->putCsv(path, content, OVERWRITE);

    string[][]|Error result = csvClient->getCsv(path);
    test:assertTrue(result is string[][]);
    if result is string[][] {
        test:assertEquals(result.length(), 2);
        test:assertEquals(result[0], content[1]);
        test:assertEquals(result[1], content[2]);
    }
    check csvClient->close();
}

@test:Config {
    groups: ["csvFailSafe", "listener"],
    dependsOn: [testReadValidCsvWithFailSafe]
}
function testOnFileCsvStreamWithFailSafe() returns error? {
    csvStreamRowsProcessed = 0;
    lastCsvFileInfo = ();
    csvContentMethodInvoked = false;

    Service csvStreamService = service object {
        remote function onFileCsv(stream<string[], error?> content, FileInfo fileInfo, Caller caller) returns error? {
            log:printInfo(string `onFileCsv (stream) invoked for: ${fileInfo.name}`);
            lastCsvFileInfo = fileInfo;
            csvContentMethodInvoked = true;

            error? processStream = content.forEach(function(string[] row) {
                csvStreamRowsProcessed += 1;
                log:printInfo(string `Processing CSV row: ${row.length()} columns`);
            });

            if processStream is error {
                log:printError("Error processing CSV stream", processStream);
                return processStream;
            }
        }
    };

    Client smbClient = check new (csvFailSafeMetadataConfig);
    _ = check smbClient->mkdir(CSV_FAILSAFE_TEST_DIR);

    Listener csvStreamListener = check new ({
        host: "localhost",
        port: 445,
        auth: {
            credentials: {
                username: "testuser",
                password: "testpass"
            }
        },
        share: "testshare",
        pollingInterval: 4,
        fileNamePattern: "csvstream.*\\.csv",
        csvFailSafe: {}
    });

    check csvStreamListener.attach(csvStreamService);
    check csvStreamListener.'start();
    runtime:registerListener(csvStreamListener);

    string csvContent = "name,age,city\nAlice,25,New York\nBob,invalid_age,Boston\nCharlie,35,Chicago";
    error? putResult = smbClient->putBytes(CSV_FAILSAFE_TEST_DIR + "/csvstream_test.csv", csvContent.toBytes());
    test:assertEquals(putResult, ());
    runtime:sleep(15);

    runtime:deregisterListener(csvStreamListener);
    check csvStreamListener.gracefulStop();
    check smbClient->close();

    test:assertTrue(csvContentMethodInvoked);
    test:assertTrue(csvStreamRowsProcessed > 0, string `Should have processed CSV rows, got ${csvStreamRowsProcessed}`);

    FileInfo fileInfo = check lastCsvFileInfo.ensureType();
    test:assertTrue(fileInfo.name.endsWith(".csv"));
}

@test:Config {
    groups: ["csvFailSafe", "listenerConfig"]
}
function testListenerConfigWithCsvFailSafe() {
    ListenerConfiguration config = {
        host: "localhost",
        port: 445,
        share: "testshare",
        csvFailSafe: {
            contentType: RAW
        }
    };
    test:assertTrue(config.csvFailSafe is FailSafeOptions, "csvFailSafe should be set");
    FailSafeOptions? failSafe = config.csvFailSafe;
    if failSafe is FailSafeOptions {
        test:assertEquals(failSafe.contentType, RAW);
    }
}

@test:Config {
    groups: ["csvFailSafe", "clientConfig"]
}
function testClientConfigWithCsvFailSafe() {
    ClientConfiguration config = {
        host: "localhost",
        port: 445,
        share: "testshare",
        csvFailSafe: {
            contentType: RAW_AND_METADATA
        }
    };
    test:assertTrue(config.csvFailSafe is FailSafeOptions, "csvFailSafe should be set");
    FailSafeOptions? failSafe = config.csvFailSafe;
    if failSafe is FailSafeOptions {
        test:assertEquals(failSafe.contentType, RAW_AND_METADATA);
    }
}

@test:Config {
    groups: ["csvFailSafe", "combined"]
}
function testCsvFailSafeWithAllOptions() {
    ClientConfiguration config = {
        host: "localhost",
        port: 445,
        share: "testshare",
        auth: {
            credentials: {
                username: "user",
                password: "pass"
            }
        },
        laxDataBinding: true,
        csvFailSafe: {
            contentType: METADATA
        }
    };

    test:assertEquals(config.laxDataBinding, true, "laxDataBinding should be true");
    test:assertTrue(config.csvFailSafe is FailSafeOptions, "csvFailSafe should be set");
    FailSafeOptions? failSafe = config.csvFailSafe;
    if failSafe is FailSafeOptions {
        test:assertEquals(failSafe.contentType, METADATA, "Content type should be METADATA");
    }
}
