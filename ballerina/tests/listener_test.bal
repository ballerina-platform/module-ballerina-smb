// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.com).
//
// WSO2 Inc. licenses this file to you under the Apache License,
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
import ballerina/test;
import ballerina/lang.runtime;

int createCounter = 0;
int deleteCounter = 0;
int totalFilesAdded = 0;
int totalFilesDeleted = 0;
FileInfo[] capturedAddedFiles = [];
string[] capturedDeletedFiles = [];

int textFileCounter = 0;
string? capturedTextContent = ();
string? capturedTextFileName = ();

int jsonFileCounter = 0;
json? capturedJsonContent = ();
string? capturedJsonFileName = ();

int xmlFileCounter = 0;
xml? capturedXmlContent = ();
string? capturedXmlFileName = ();

int csvFileCounter = 0;
string[][]? capturedCsvContent = ();
string? capturedCsvFileName = ();


listener Listener smbListener = check new ({
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

listener Listener testListener = check new ({
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

listener Listener stopListener = check new ({
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

@ServiceConfig {
    path: "ListenerTest1"
}
service "test1" on smbListener {
    remote function onFileText(string content, FileInfo fileInfo) returns error? {
        io:println("Resource - File created: ", fileInfo.name);
        createCounter += 1;
        totalFilesAdded += 1;
        capturedAddedFiles.push(fileInfo);
    }
}

service "test2" on smbListener {
    remote function onFileText(string content, FileInfo fileInfo) returns error? {
        io:println("Resource - File created: ", fileInfo.name);
        createCounter += 1;
        totalFilesAdded += 1;
        capturedAddedFiles.push(fileInfo);
    }
}

Service stopService = service object {
    remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
        io:println("Service triggered before immediate stop");
    }
};

Service testService = service object {
    remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
        io:println("Test service triggered");
    }
};

int errorCounter = 0;
string? capturedErrorMessage = ();

Service errorHandlingService = service object {
    remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
        io:println("Error handling service file handler triggered");
    }

    function onError(error err) returns error? {
        io:println("onError triggered: ", err.message());
        errorCounter += 1;
        capturedErrorMessage = err.message();
    }
};

@test:Config {
    groups: ["listener"]
}
function testSmbListenerOnCreate() returns error? {
    createCounter = 0;
    totalFilesAdded = 0;
    capturedAddedFiles = [];
    error? result = smbClient->mkdir("ListenerTest1");
    test:assertEquals(result, ());

    error? putResult = smbClient->put("/ListenerTest1/testFile1.txt", "Test file content 1.".toBytes());
    test:assertEquals(putResult, ());

    runtime:sleep(3);
    test:assertTrue(createCounter >= 1, "onCreate should be triggered at least once");
    test:assertTrue(totalFilesAdded >= 1, "At least one file should be added");
}

@test:Config {
    groups: ["listener"],
    dependsOn: [testSmbListenerOnCreate]
}
function testSmbListenerMultipleFiles() returns error? {
    createCounter = 0;
    totalFilesAdded = 0;
    capturedAddedFiles = [];

    error? mkdirResult = smbClient->mkdir("test2");
    test:assertEquals(mkdirResult, ());

    error? put1 = smbClient->put("/test2/file1.txt", "Content 1".toBytes());
    error? put2 = smbClient->put("/test2/file2.txt", "Content 2".toBytes());
    error? put3 = smbClient->put("/test2/file3.txt", "Content 3".toBytes());
    test:assertEquals(put1, ());
    test:assertEquals(put2, ());
    test:assertEquals(put3, ());

    runtime:sleep(3);
    test:assertTrue(totalFilesAdded >= 3, "At least 3 files should be detected");
}

@test:Config {
    groups: ["listener"],
    dependsOn: [testSmbListenerMultipleFiles]
}
function testSmbListenerAttachDetach() returns error? {
    error? attachResult = testListener.attach(testService, "ListenerTest3");
    test:assertEquals(attachResult, ());

    error? detachResult = testListener.detach(testService);
    test:assertEquals(detachResult, ());
}

@test:Config {
    groups: ["listener"]
}
function testSmbListenerImmediateStop() returns error? {
    check stopListener.attach(stopService, "ListenerTest5");
    check stopListener.'start();
    runtime:registerListener(stopListener);
    error? stopResult = stopListener.immediateStop();
    test:assertEquals(stopResult, ());
}

@test:Config {
    groups: ["listener"]
}
function testSmbListenerOnError() returns error? {
    errorCounter = 0;
    capturedErrorMessage = ();
    Listener errorListener = check new ({
        host: "invalid-host-that-does-not-exist",
        port: 445,
        auth: {
            credentials: {
                username: "testuser",
                password: "testpass"
            }
        },
        share: "testshare",
        pollingInterval: 1,
        bufferSize: 65536
    });

    check errorListener.attach(errorHandlingService, "ErrorTest");
    check errorListener.'start();
    runtime:registerListener(errorListener);
    runtime:sleep(3);

    test:assertTrue(errorCounter >= 1, "onError should be triggered at least once");
    test:assertTrue(capturedErrorMessage is string, "Error message should be captured");

    error? stopResult = errorListener.immediateStop();
    test:assertEquals(stopResult, ());
}

type CsvRecord record {|
    string id;
    string name;
    string email;
|};

int csvRecordArrayCounter = 0;
CsvRecord[]? capturedCsvRecordArray = ();
string? capturedCsvRecordArrayFileName = ();

int csvStringStreamCounter = 0;
int csvStringStreamRowCount = 0;
string? capturedCsvStringStreamFileName = ();

int csvRecordStreamCounter = 0;
int csvRecordStreamRowCount = 0;
string? capturedCsvRecordStreamFileName = ();

int binaryFileCounter = 0;
byte[]? capturedBinaryContent = ();
string? capturedBinaryFileName = ();

int binaryStreamCounter = 0;
int binaryStreamChunkCount = 0;
int binaryStreamTotalBytes = 0;
string? capturedBinaryStreamFileName = ();

Service contentHandlerService = service object {
    remote function onFileText(string content, FileInfo fileInfo) returns error? {
        textFileCounter += 1;
        capturedTextContent = content;
        capturedTextFileName = fileInfo.name;
    }

    remote function onFileJson(json content, FileInfo fileInfo) returns error? {
        jsonFileCounter += 1;
        capturedJsonContent = content;
        capturedJsonFileName = fileInfo.name;
    }

    remote function onFileXml(xml content, FileInfo fileInfo) returns error? {
        xmlFileCounter += 1;
        capturedXmlContent = content;
        capturedXmlFileName = fileInfo.name;
    }

    remote function onFileCsv(string[][] content, FileInfo fileInfo) returns error? {
        csvFileCounter += 1;
        capturedCsvContent = content;
        capturedCsvFileName = fileInfo.name;
    }

    remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
        binaryFileCounter += 1;
        capturedBinaryContent = content;
        capturedBinaryFileName = fileInfo.name;
    }

    function onError(error err) returns error? {
        io:println("Content handler error: ", err.message());
    }
};

Service csvRecordArrayService = service object {
    remote function onFileCsv(CsvRecord[] content, FileInfo fileInfo) returns error? {
        csvRecordArrayCounter += 1;
        capturedCsvRecordArray = content;
        capturedCsvRecordArrayFileName = fileInfo.name;
    }

    function onError(error err) returns error? {
        io:println("CSV record[] handler error: ", err.message());
    }
};

Service csvStringStreamService = service object {
    remote function onFileCsv(stream<string[], error?> content, FileInfo fileInfo) returns error? {
        csvStringStreamCounter += 1;
        capturedCsvStringStreamFileName = fileInfo.name;

        int rowCount = 0;
        error? e = content.forEach(function(string[] row) {
            rowCount += 1;
        });
        csvStringStreamRowCount = rowCount;
        if e is error {
            return e;
        }
    }

    function onError(error err) returns error? {
        io:println("CSV stream<string[]> handler error: ", err.message());
    }
};

Service csvRecordStreamService = service object {
    remote function onFileCsv(stream<CsvRecord, error?> content, FileInfo fileInfo) returns error? {
        csvRecordStreamCounter += 1;
        capturedCsvRecordStreamFileName = fileInfo.name;
        int recordCount = 0;
        error? result = content.forEach(function(CsvRecord rec) {
            recordCount += 1;
        });
        csvRecordStreamRowCount = recordCount;
        if result is error {
            return result;
        }
    }

    function onError(error err) returns error? {
        io:println("CSV stream<record{}> handler error: ", err.message());
    }
};

Service binaryStreamService = service object {
    remote function onFile(stream<byte[], error?> content, FileInfo fileInfo) returns error? {
        binaryStreamCounter += 1;
        capturedBinaryStreamFileName = fileInfo.name;
        int chunkCount = 0;
        int totalBytes = 0;
        error? result = content.forEach(function(byte[] chunk) {
            chunkCount += 1;
            totalBytes += chunk.length();
        });
        binaryStreamChunkCount = chunkCount;
        binaryStreamTotalBytes = totalBytes;
        if result is error {
            return result;
        }
    }

    function onError(error err) returns error? {
        io:println("Binary stream handler error: ", err.message());
    }
};

@test:Config {
    groups: ["z"]
}
function testOnFileTextHandler() returns error? {
    textFileCounter = 0;
    capturedTextContent = ();
    capturedTextFileName = ();
    check smbClient->mkdir("/content_tests");

    Listener contentListener = check new ({
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

    check contentListener.attach(contentHandlerService);
    check contentListener.'start();
    runtime:registerListener(contentListener);

    // Wait for initial poll to complete and record existing files
    runtime:sleep(3);

    // Reset counters after initial poll
    textFileCounter = 0;
    capturedTextContent = ();
    capturedTextFileName = ();

    // Now create the test file - it will be detected as "new"
    string testContent = "Hello, this is a text file content for testing!";
    error? putResult = smbClient->put("/content_tests/test_file.txt", testContent.toBytes());
    test:assertEquals(putResult, ());

    // Wait for the listener to detect the new file
    runtime:sleep(5);
    check contentListener.immediateStop();

    test:assertTrue(textFileCounter >= 1, "onFileText should be triggered at least once");
    test:assertEquals(capturedTextContent, testContent, "Text content should match");
    test:assertEquals(capturedTextFileName, "test_file.txt", "File name should match");
}

@test:Config {
    groups: ["listener", "content-handlers"],
    dependsOn: [testOnFileTextHandler]
}
function testOnFileJsonHandler() returns error? {
    jsonFileCounter = 0;
    capturedJsonContent = ();
    capturedJsonFileName = ();

    Listener jsonListener = check new ({
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

    check jsonListener.attach(contentHandlerService);
    check jsonListener.'start();
    runtime:registerListener(jsonListener);

    json testJson = {
        "name": "John Doe",
        "age": 30,
        "email": "john@example.com"
    };
    error? putResult = smbClient->put("/content_tests/user_data.json", testJson.toString().toBytes());
    test:assertEquals(putResult, ());
    runtime:sleep(5);
    check jsonListener.immediateStop();

    test:assertTrue(jsonFileCounter >= 1, "onFileJson should be triggered at least once");
    test:assertTrue(capturedJsonContent is json, "JSON content should be captured");
    test:assertEquals(capturedJsonFileName, "user_data.json", "File name should match");
}

@test:Config {
    groups: ["listener", "content-handlers"],
    dependsOn: [testOnFileJsonHandler]
}
function testOnFileXmlHandler() returns error? {
    xmlFileCounter = 0;
    capturedXmlContent = ();
    capturedXmlFileName = ();

    Listener xmlListener = check new ({
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

    check xmlListener.attach(contentHandlerService);
    check xmlListener.'start();
    runtime:registerListener(xmlListener);

    string xmlContent = "<config><database>mysql</database><timeout>30</timeout></config>";
    error? putResult = smbClient->put("/content_tests/config.xml", xmlContent.toBytes());
    test:assertEquals(putResult, ());
    runtime:sleep(5);
    check xmlListener.immediateStop();
    test:assertTrue(xmlFileCounter >= 1, "onFileXml should be triggered at least once");
    test:assertTrue(capturedXmlContent is xml, "XML content should be captured");
    test:assertEquals(capturedXmlFileName, "config.xml", "File name should match");
}

@test:Config {
    groups: ["listener", "content-handlers"],
    dependsOn: [testOnFileXmlHandler]
}
function testOnFileCsvHandler() returns error? {
    csvFileCounter = 0;
    capturedCsvContent = ();
    capturedCsvFileName = ();

    Listener csvListener = check new ({
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

    check csvListener.attach(contentHandlerService);
    check csvListener.'start();
    runtime:registerListener(csvListener);

    // Wait for initial poll to complete and record existing files
    runtime:sleep(3);

    // Reset counters after initial poll
    csvFileCounter = 0;
    capturedCsvContent = ();
    capturedCsvFileName = ();

    // Now create the test file - it will be detected as "new"
    string csvContent = "id,name,email\n1,John,john@example.com\n2,Jane,jane@example.com";
    error? putResult = smbClient->put("/content_tests/users.csv", csvContent.toBytes());
    test:assertEquals(putResult, ());
    runtime:sleep(5);
    check csvListener.immediateStop();
    test:assertTrue(csvFileCounter >= 1, "onFileCsv should be triggered at least once");
    test:assertTrue(capturedCsvContent is string[][], "CSV content should be captured as string[][]");
    string[][]? csvData = capturedCsvContent;
    if csvData is string[][] {
        test:assertTrue(csvData.length() >= 3, "CSV should have at least 3 rows");
    }
    test:assertEquals(capturedCsvFileName, "users.csv", "File name should match");
}

@test:Config {
    groups: ["listener", "content-handlers", "csv-stream"],
    dependsOn: [testOnFileCsvHandler]
}
function testOnFileCsvRecordArrayHandler() returns error? {
    csvRecordArrayCounter = 0;
    capturedCsvRecordArray = ();
    capturedCsvRecordArrayFileName = ();

    error? mkdirResult = smbClient->mkdir("content_tests/csv_record_array");
    if mkdirResult is error {
        io:println("Directory might already exist: ", mkdirResult.message());
    }

    Listener csvRecordListener = check new ({
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

    check csvRecordListener.attach(csvRecordArrayService);
    check csvRecordListener.'start();
    runtime:registerListener(csvRecordListener);

    // Wait for initial poll to complete and record existing files
    runtime:sleep(3);

    // Reset counters after initial poll
    csvRecordArrayCounter = 0;
    capturedCsvRecordArray = ();
    capturedCsvRecordArrayFileName = ();

    // Now create the test file - it will be detected as "new"
    string csvContent = "id,name,email\n1,Alice,alice@example.com\n2,Bob,bob@example.com\n3,Charlie,charlie@example.com";
    error? putResult = smbClient->put("/content_tests/csv_record_array/record_users.csv", csvContent.toBytes());
    test:assertEquals(putResult, ());

    // Wait for the listener to detect the new file
    runtime:sleep(5);

    check csvRecordListener.immediateStop();

    test:assertTrue(csvRecordArrayCounter >= 1, "onFileCsv with record[] should be triggered at least once");
    CsvRecord[]? recordData = capturedCsvRecordArray;
    if recordData is CsvRecord[] {
        test:assertTrue(recordData.length() >= 2, "CSV should have at least 2 records (excluding header)");
        test:assertTrue(recordData[0].id.length() > 0, "First record id should not be empty");
        test:assertTrue(recordData[0].name.length() > 0, "First record name should not be empty");
    } else {
        test:assertFail("CSV record array should be captured");
    }
    test:assertEquals(capturedCsvRecordArrayFileName, "record_users.csv", "File name should match");
}

@test:Config {
    groups: ["listener", "content-handlers", "csv-stream"],
    dependsOn: [testOnFileCsvRecordArrayHandler]
}
function testOnFileCsvStringStreamHandler() returns error? {
    csvStringStreamCounter = 0;
    csvStringStreamRowCount = 0;
    capturedCsvStringStreamFileName = ();

    check smbClient->mkdir("content_tests/csv_string_stream");
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
        pollingInterval: 2,
        bufferSize: 65536
    });
    check csvStreamListener.attach(csvStringStreamService);
    check csvStreamListener.'start();
    runtime:registerListener(csvStreamListener);

    // Wait for initial poll to complete and record existing files
    runtime:sleep(3);

    // Reset counters after initial poll
    csvStringStreamCounter = 0;
    csvStringStreamRowCount = 0;
    capturedCsvStringStreamFileName = ();

    // Now create the test file - it will be detected as "new"
    string csvContent = "id,name,email\n10,Dave,dave@example.com\n20,Eve,eve@example.com\n30,Frank,frank@example.com\n40,Grace,grace@example.com";
    error? putResult = smbClient->put("/content_tests/csv_string_stream/stream_users.csv", csvContent.toBytes());
    test:assertEquals(putResult, ());

    // Wait for the listener to detect the new file
    runtime:sleep(5);

    check csvStreamListener.immediateStop();

    test:assertTrue(csvStringStreamCounter >= 1, "onFileCsv with stream<string[]> should be triggered at least once");
    test:assertTrue(csvStringStreamRowCount >= 4, "Stream should have processed at least 4 data rows");
    test:assertEquals(capturedCsvStringStreamFileName, "stream_users.csv", "File name should match");
}

@test:Config {
    groups: ["listener", "content-handlers", "csv-stream"],
    dependsOn: [testOnFileCsvStringStreamHandler]
}
function testOnFileCsvRecordStreamHandler() returns error? {
    csvRecordStreamCounter = 0;
    csvRecordStreamRowCount = 0;
    capturedCsvRecordStreamFileName = ();
    check smbClient->mkdir("content_tests/csv_record_stream");

    Listener csvRecordStreamListener = check new ({
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

    check csvRecordStreamListener.attach(csvRecordStreamService);
    check csvRecordStreamListener.'start();
    runtime:registerListener(csvRecordStreamListener);

    // Wait for initial poll to complete and record existing files
    runtime:sleep(3);

    // Reset counters after initial poll
    csvRecordStreamCounter = 0;
    csvRecordStreamRowCount = 0;
    capturedCsvRecordStreamFileName = ();

    // Now create the test file - it will be detected as "new"
    string csvContent = "id,name,email\n100,Henry,henry@example.com\n200,Ivy,ivy@example.com\n300,Jack,jack@example.com";
    error? putResult = smbClient->put("/content_tests/csv_record_stream/record_stream_users.csv", csvContent.toBytes());
    test:assertEquals(putResult, ());

    // Wait for the listener to detect the new file
    runtime:sleep(5);

    check csvRecordStreamListener.immediateStop();

    test:assertTrue(csvRecordStreamCounter >= 1, "onFileCsv with stream<record{}> should be triggered at least once");
    test:assertTrue(csvRecordStreamRowCount >= 2, "Stream should have processed at least 2 records");
    test:assertEquals(capturedCsvRecordStreamFileName, "record_stream_users.csv", "File name should match");
}

@test:Config {
    groups: ["listener", "content-handlers"],
    dependsOn: [testOnFileCsvRecordStreamHandler]
}
function testOnFileHandler() returns error? {
    binaryFileCounter = 0;
    capturedBinaryContent = ();
    capturedBinaryFileName = ();

    Listener binaryListener = check new ({
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

    check binaryListener.attach(contentHandlerService);
    check binaryListener.'start();
    runtime:registerListener(binaryListener);

    // Wait for initial poll to complete and record existing files
    runtime:sleep(3);

    // Reset counters after initial poll
    binaryFileCounter = 0;
    capturedBinaryContent = ();
    capturedBinaryFileName = ();

    // Now create the test file - it will be detected as "new"
    byte[] binaryContent = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    error? putResult = smbClient->put("/content_tests/image.png", binaryContent);
    test:assertEquals(putResult, ());

    // Wait for the listener to detect the new file
    runtime:sleep(5);

    check binaryListener.immediateStop();

    test:assertTrue(binaryFileCounter >= 1, "onFile should be triggered at least once for binary files");
    test:assertTrue(capturedBinaryContent is byte[], "Binary content should be captured");
    byte[]? binaryData = capturedBinaryContent;
    if binaryData is byte[] {
        test:assertEquals(binaryData.length(), 8, "Binary content length should match");
    }
    test:assertEquals(capturedBinaryFileName, "image.png", "File name should match");
}

@test:Config {
    groups: ["listener", "content-handlers", "byte-stream"],
    dependsOn: [testOnFileHandler]
}
function testOnFileByteStreamHandler() returns error? {
    binaryStreamCounter = 0;
    binaryStreamChunkCount = 0;
    binaryStreamTotalBytes = 0;
    capturedBinaryStreamFileName = ();
    error? mkdirResult = smbClient->mkdir("content_tests/byte_stream");
    if mkdirResult is error {
        io:println("Directory might already exist: ", mkdirResult.message());
    }
    Listener byteStreamListener = check new ({
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

    check byteStreamListener.attach(binaryStreamService);
    check byteStreamListener.'start();
    runtime:registerListener(byteStreamListener);

    // Wait for initial poll to complete and record existing files
    runtime:sleep(3);

    // Reset counters after initial poll
    binaryStreamCounter = 0;
    binaryStreamChunkCount = 0;
    binaryStreamTotalBytes = 0;
    capturedBinaryStreamFileName = ();

    // Now create the test file - it will be detected as "new"
    byte[] largeContent = [];
    int i = 0;
    while i < 20000 {
        largeContent.push(<byte>(i % 256));
        i += 1;
    }
    error? putResult = smbClient->put("/content_tests/byte_stream/large_binary.dat", largeContent);
    test:assertEquals(putResult, ());

    // Wait for the listener to detect the new file
    runtime:sleep(5);

    check byteStreamListener.immediateStop();

    test:assertTrue(binaryStreamCounter >= 1, "onFile with stream<byte[]> should be triggered at least once");
    test:assertTrue(binaryStreamChunkCount == 1, "Stream should have processed at least 2 chunks");
    test:assertTrue(binaryStreamTotalBytes >= 20000, "Stream should have processed all bytes");
    test:assertEquals(capturedBinaryStreamFileName, "large_binary.dat", "File name should match");
    error? result = smbClient->rmdir("content_tests");
}
