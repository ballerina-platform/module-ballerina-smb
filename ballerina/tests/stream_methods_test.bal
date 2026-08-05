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
import ballerina/io;

final Client streamTestClient = check new ({
    host: "localhost",
    port: 445,
    share: "testshare",
    auth: {
        credentials: {
            username: "testuser",
            password: "testpass"
        }
    }
});

@test:BeforeSuite
function setupStreamTestDirectory() returns error? {
    Error? mkdirResult = streamTestClient->mkdir("streamtest");
    if mkdirResult is Error {
        io:println("Directory may already exist: " + mkdirResult.message());
    }
}

@test:Config {
    groups: ["stream", "getBytesAsStream"]
}
function testGetBytesAsStreamBasic() returns error? {
    string path = "/streamtest/bytes-stream-basic.bin";
    byte[] content = "Hello SMB Stream".toBytes();
    check streamTestClient->putBytes(path, content, OVERWRITE);
    stream<byte[], error?> byteStream = check streamTestClient->getBytesAsStream(path);
    byte[] result = [];
    check from byte[] chunk in byteStream
        do {
            result.push(...chunk);
        };
    test:assertEquals(result, content);
}

@test:Config {
    groups: ["stream", "getBytesAsStream"],
    dependsOn: [testGetBytesAsStreamBasic]
}
function testGetBytesAsStreamLargeFile() returns error? {
    string path = "/streamtest/bytes-stream-large.bin";
    byte[] content = [];
    foreach int i in 0 ..< 20000 {
        content.push(<byte>(i % 256));
    }
    check streamTestClient->putBytes(path, content, OVERWRITE);
    stream<byte[], error?> byteStream = check streamTestClient->getBytesAsStream(path);

    byte[] result = [];
    check from byte[] chunk in byteStream
        do {
            result.push(...chunk);
        };

    test:assertEquals(result.length(), content.length());
    test:assertEquals(result, content);
}

@test:Config {
    groups: ["stream", "getBytesAsStream"],
    dependsOn: [testGetBytesAsStreamLargeFile]
}
function testGetBytesAsStreamEmpty() returns error? {
    string path = "/streamtest/bytes-stream-empty.bin";
    byte[] content = [];
    check streamTestClient->putBytes(path, content, OVERWRITE);
    stream<byte[], error?> byteStream = check streamTestClient->getBytesAsStream(path);

    byte[] result = [];
    check from byte[] chunk in byteStream
        do {
            result.push(...chunk);
        };

    test:assertEquals(result.length(), 0, "Empty file stream should be empty");
}

@test:Config {
    groups: ["stream", "getCsvAsStream", "getCsvAsStreamRecord"],
    dependsOn: [testGetCsvAsStreamWithSpecialChars]
}
function testGetCsvAsStreamEmptyRecords() returns error? {
    string path = "/streamtest/csv-stream-empty-records.csv";
    // Header only — no data rows. CsvIterator sees length == 0 and returns null immediately.
    string csvContent = "name,age,department";
    check streamTestClient->putText(path, csvContent, OVERWRITE);
    stream<Employee, error?> csvStream = check streamTestClient->getCsvAsStream(path);
    int rowCount = 0;
    check from Employee _ in csvStream
        do {
            rowCount += 1;
        };
    test:assertEquals(rowCount, 0, "CSV with only a header row should produce no records");
}

@test:Config {
    groups: ["stream", "getCsvAsStream", "getCsvAsStreamRecord"],
    dependsOn: [testGetCsvAsStreamEmptyRecords]
}
function testGetCsvAsStreamInvalidTypeConversion() returns error? {
    string path = "/streamtest/csv-stream-invalid-type.csv";
    // "not-a-number" cannot be converted to int for Employee.age.
    // Native.parseBytes returns a BError, covering the error-tag branch in CsvIterator.next().
    string csvContent = "name,age,department\nAlice,not-a-number,Engineering";
    check streamTestClient->putText(path, csvContent, OVERWRITE);
    stream<Employee, error?> csvStream = check streamTestClient->getCsvAsStream(path);
    record {|Employee value;|}|error? firstRow = csvStream.next();
    test:assertTrue(firstRow is error,
        "Stream should return an error when CSV value cannot be converted to the target type");
}

@test:Config {
    groups: ["stream", "getBytesAsStream"],
    dependsOn: [testGetBytesAsStreamEmpty]
}
function testGetBytesAsStreamCloseEarly() returns error? {
    string path = "/streamtest/bytes-stream-close-early.bin";
    byte[] content = "Some content to read partially".toBytes();
    check streamTestClient->putBytes(path, content, OVERWRITE);
    stream<byte[], error?> byteStream = check streamTestClient->getBytesAsStream(path);
    record {|byte[] value;|}? firstChunk = check byteStream.next();
    test:assertTrue(firstChunk is record {|byte[] value;|}, "Should get at least one chunk");
    check byteStream.close();
    test:assertTrue(true, "Stream closed successfully");
}

@test:Config {
    groups: ["stream", "getCsvAsStream"]
}
function testGetCsvAsStreamStringArray() returns error? {
    string path = "/streamtest/csv-stream-string-array.csv";
    string[][] content = [
        ["name", "age", "city"],
        ["Alice", "25", "New York"],
        ["Bob", "30", "Boston"],
        ["Charlie", "35", "Chicago"]
    ];
    check streamTestClient->putCsv(path, content, OVERWRITE);
    stream<string[], error?> csvStream = check streamTestClient->getCsvAsStream(path);
    string[][] result = [];
    check from string[] row in csvStream
        do {
            result.push(row);
        };
    test:assertEquals(result.length(), content.slice(1).length(), "CSV stream row count mismatch");
    test:assertEquals(result, content.slice(1), "CSV stream content mismatch");
}

@test:Config {
    groups: ["stream", "getCsvAsStream"],
    dependsOn: [testGetCsvAsStreamStringArray]
}
function testGetCsvAsStreamStringArrayLarge() returns error? {
    string path = "/streamtest/csv-stream-large.csv";

    // Create a larger CSV (100 rows)
    string[][] content = [["id", "name", "value"]];
    foreach int i in 1 ... 100 {
        content.push([i.toString(), "Item" + i.toString(), (i * 10).toString()]);
    }

    // Write CSV file
    check streamTestClient->putCsv(path, content, OVERWRITE);

    // Read as stream
    stream<string[], error?> csvStream = check streamTestClient->getCsvAsStream(path);

    int rowCount = 0;
    check from string[] _ in csvStream
        do {
            rowCount += 1;
        };

    test:assertEquals(rowCount, 100, "Large CSV stream row count mismatch (header + 100 rows)");
}

@test:Config {
    groups: ["stream", "getCsvAsStream"],
    dependsOn: [testGetCsvAsStreamStringArrayLarge]
}
function testGetCsvAsStreamWithSpecialChars() returns error? {
    string path = "/streamtest/csv-stream-special.csv";
    string[][] content = [
        ["name", "description"],
        ["Product A", "Contains, comma"],
        ["Product B", "Has quotes"]
    ];

    // Write CSV file
    check streamTestClient->putCsv(path, content, OVERWRITE);

    // Read as stream
    stream<string[], error?> csvStream = check streamTestClient->getCsvAsStream(path);

    string[][] result = [];
    check from string[] row in csvStream
        do {
            result.push(row);
        };

    test:assertEquals(result.length(), 2, "CSV with special chars row count mismatch");
    test:assertEquals(result[0][1], "Contains, comma", "Comma in value should be preserved");
}

type Employee record {|
    string name;
    int age;
    string department;
|};

@test:Config {
    groups: ["stream", "getCsvAsStream", "getCsvAsStreamRecord"]
}
function testGetCsvAsStreamRecord() returns error? {
    string path = "/streamtest/csv-stream-record.csv";
    string csvContent = "name,age,department\nAlice,25,Engineering\nBob,30,Marketing\nCharlie,35,Sales";

    // Write CSV file as text
    check streamTestClient->putText(path, csvContent, OVERWRITE);

    // Read as stream with record type
    stream<Employee, error?> csvStream = check streamTestClient->getCsvAsStream(path);

    Employee[] result = [];
    check from Employee emp in csvStream
        do {
            result.push(emp);
        };

    test:assertEquals(result.length(), 3, "Record stream row count mismatch");
    test:assertEquals(result[0].name, "Alice", "First employee name mismatch");
    test:assertEquals(result[0].age, 25, "First employee age mismatch");
    test:assertEquals(result[0].department, "Engineering", "First employee department mismatch");
    test:assertEquals(result[1].name, "Bob", "Second employee name mismatch");
    test:assertEquals(result[2].name, "Charlie", "Third employee name mismatch");
}

type Product record {|
    int id;
    string name;
    decimal price;
    boolean inStock;
|};

@test:Config {
    groups: ["stream", "getCsvAsStream", "getCsvAsStreamRecord"],
    dependsOn: [testGetCsvAsStreamRecord]
}
function testGetCsvAsStreamRecordWithTypes() returns error? {
    string path = "/streamtest/csv-stream-record-types.csv";
    string csvContent = "id,name,price,inStock\n1,Widget,19.99,true\n2,Gadget,29.99,false\n3,Tool,9.99,true";

    // Write CSV file
    check streamTestClient->putText(path, csvContent, OVERWRITE);

    // Read as stream with typed record
    stream<Product, error?> csvStream = check streamTestClient->getCsvAsStream(path);

    Product[] result = [];
    check from Product product in csvStream
        do {
            result.push(product);
        };

    test:assertEquals(result.length(), 3, "Product stream row count mismatch");
    test:assertEquals(result[0].id, 1, "First product id mismatch");
    test:assertEquals(result[0].name, "Widget", "First product name mismatch");
    test:assertEquals(result[0].price, 19.99d, "First product price mismatch");
    test:assertEquals(result[0].inStock, true, "First product inStock mismatch");
    test:assertEquals(result[1].inStock, false, "Second product inStock mismatch");
}

@test:Config {
    groups: ["stream", "getCsvAsStream"],
    dependsOn: [testGetCsvAsStreamRecordWithTypes]
}
function testGetCsvAsStreamCloseEarly() returns error? {
    string path = "/streamtest/csv-stream-close-early.csv";
    string[][] content = [
        ["col1", "col2"],
        ["row1", "value1"],
        ["row2", "value2"],
        ["row3", "value3"]
    ];
    check streamTestClient->putCsv(path, content, OVERWRITE);
    stream<string[], error?> csvStream = check streamTestClient->getCsvAsStream(path);
    record {|string[] value;|}? firstRow = check csvStream.next();
    test:assertTrue(firstRow is record {|string[] value;|}, "Should get at least first row");
    check csvStream.close();
    test:assertTrue(true, "CSV stream closed successfully");
}

final Client laxDataBindingClient = check new ({
    host: "localhost",
    port: 445,
    share: "testshare",
    auth: {
        credentials: {
            username: "testuser",
            password: "testpass"
        }
    },
    laxDataBinding: true
});

type PersonData record {|
    string name;
    int age;
|};

@test:Config {}
function testGetCsvAsStreamWithLaxDataBinding() returns error? {
    string path = "/streamtest/csv-stream-lax-databinding.csv";
    string csvContent = "name,age,city,country\nAlice,25,New York,USA\nBob,30,Boston,USA\nCharlie,35,Chicago,USA";
    check laxDataBindingClient->putText(path, csvContent, OVERWRITE);
    stream<PersonData, error?> csvStream = check laxDataBindingClient->getCsvAsStream(path);
    PersonData[] result = [];
    check from PersonData person in csvStream
        do {
            result.push(person);
        };

    PersonData[] expectedResult = [{
        name: "Alice",
        age: 25
    },
    {
        name: "Bob",
        age: 30
    },
    {
        name: "Charlie",
        age: 35
    }];
    test:assertEquals(result, expectedResult);
}

// ── getJson with laxDataBinding=true (covers createJsonParseOptions lax branch) ─
@test:Config {}
function testGetJsonWithLaxDataBinding() returns error? {
    string path = "/streamtest/lax-binding.json";
    // JSON has extra fields not in PersonData; lax binding ignores them
    json content = {name: "Alice", age: 25, extraField: "ignored", nested: {x: 1}};
    check laxDataBindingClient->putJson(path, content, OVERWRITE);
    PersonData|Error result = laxDataBindingClient->getJson(path);
    test:assertTrue(result is PersonData,
        "getJson with laxDataBinding=true should bind extra fields without error");
    if result is PersonData {
        test:assertEquals(result.name, "Alice");
        test:assertEquals(result.age, 25);
    }
}

// ── getCsv (non-stream) with laxDataBinding=true (covers createCsvParseOptions lax branch) ─
// getCsv constrains targetType to anydata[][], so use string[][] here.
// The laxDataBinding=true flag is still forwarded to createCsvParseOptions regardless of type,
// which exercises the `if (laxDataBinding)` true branch in Java.
@test:Config {}
function testGetCsvWithLaxDataBinding() returns error? {
    string path = "/streamtest/lax-binding.csv";
    string csvContent = "name,age\nAlice,25\nBob,30";
    check laxDataBindingClient->putText(path, csvContent, OVERWRITE);
    string[][]|Error result = laxDataBindingClient->getCsv(path);
    test:assertTrue(result is string[][],
        "getCsv with laxDataBinding=true should return string[][] successfully");
    if result is string[][] {
        test:assertEquals(result.length(), 2);
        test:assertEquals(result[0][0], "Alice");
    }
}

@test:Config {
    groups: ["stream", "integration"],
    dependsOn: [testGetCsvAsStreamCloseEarly]
}
function testStreamAndNonStreamApproaches() returns error? {
    string path = "/streamtest/stream-vs-nonstream.csv";
    string[][] content = [
        ["id", "name"],
        ["1", "Alice"],
        ["2", "Bob"]
    ];
    check streamTestClient->putCsv(path, content, OVERWRITE);
    string[][]|Error csvResult = streamTestClient->getCsv(path);
    test:assertTrue(csvResult is string[][], "getCsv should return string[][]");
    stream<string[], error?> csvStream = check streamTestClient->getCsvAsStream(path);
    string[][] streamResult = [];
    check from string[] row in csvStream
        do {
            streamResult.push(row);
        };
    if csvResult is string[][] {
        test:assertEquals(streamResult.length(), csvResult.length(), "Stream and non-stream row count should match");
        test:assertEquals(streamResult, csvResult, "Stream and non-stream content should match");
    }
}

@test:Config {
    groups: ["stream", "putBytesAsStream"]
}
function testPutBytesAsStreamOverwrite() returns error? {
    string path = "/streamtest/put-bytes-stream-overwrite.bin";
    byte[][] chunks = ["Hello ".toBytes(), "SMB ".toBytes(), "Stream".toBytes()];
    stream<byte[], error?> byteStream = chunks.toStream();
    check streamTestClient->putBytesAsStream(path, byteStream, OVERWRITE);

    byte[]|Error result = streamTestClient->getBytes(path);
    test:assertTrue(result is byte[], "Failed to read bytes written via stream");
    if result is byte[] {
        string resultStr = check string:fromBytes(result);
        test:assertEquals(resultStr, "Hello SMB Stream", "Byte stream overwrite content mismatch");
    }
}

@test:Config {
    groups: ["stream", "putBytesAsStream"],
    dependsOn: [testPutBytesAsStreamOverwrite]
}
function testPutBytesAsStreamAppend() returns error? {
    string path = "/streamtest/put-bytes-stream-append.bin";
    byte[][] initial = ["First ".toBytes()];
    stream<byte[], error?> initialStream = initial.toStream();
    check streamTestClient->putBytesAsStream(path, initialStream, OVERWRITE);

    byte[][] appended = ["Second".toBytes()];
    stream<byte[], error?> appendStream = appended.toStream();
    check streamTestClient->putBytesAsStream(path, appendStream, APPEND);

    byte[]|Error result = streamTestClient->getBytes(path);
    test:assertTrue(result is byte[], "Failed to read appended bytes");
    if result is byte[] {
        string resultStr = check string:fromBytes(result);
        test:assertEquals(resultStr, "First Second", "Byte stream append content mismatch");
    }
}

@test:Config {
    groups: ["stream", "putBytesAsStream"],
    dependsOn: [testPutBytesAsStreamAppend]
}
function testPutBytesAsStreamLargeFile() returns error? {
    string path = "/streamtest/put-bytes-stream-large.bin";
    byte[][] chunks = [];
    byte[] expectedResult = [];
    foreach int i in 0 ..< 100 {
        byte[] chunk = [];
        foreach int j in 0 ..< 200 {
            byte b = <byte>((i * 200 + j) % 256);
            chunk.push(b);
            expectedResult.push(b);
        }
        chunks.push(chunk);
    }
    stream<byte[], error?> byteStream = chunks.toStream();
    check streamTestClient->putBytesAsStream(path, byteStream, OVERWRITE);

    byte[]|Error result = streamTestClient->getBytes(path);
    test:assertTrue(result is byte[], "Failed to read large byte stream");
    if result is byte[] {
        test:assertEquals(result.length(), 20000, "Large byte stream length mismatch");
        test:assertEquals(result, expectedResult, "Large byte stream content mismatch");
    }
}

// ── putCsvAsStream tests (string[]) ─────────────────────────────────────

@test:Config {
    groups: ["stream", "putCsvAsStream"]
}
function testPutCsvAsStreamStringArrayOverwrite() returns error? {
    string path = "/streamtest/put-csv-stream-string-overwrite.csv";
    string[][] rows = [["Alice", "25", "New York"], ["Bob", "30", "Boston"]];
    stream<string[], error?> csvStream = rows.toStream();
    check streamTestClient->putCsvAsStream(path, csvStream, OVERWRITE);

    string|Error result = streamTestClient->getText(path);
    test:assertTrue(result is string, "Failed to read CSV written via stream");
    if result is string {
        test:assertTrue(result.includes("Alice"), "CSV should contain Alice");
        test:assertTrue(result.includes("Bob"), "CSV should contain Bob");
    }
}

@test:Config {
    groups: ["stream", "putCsvAsStream"],
    dependsOn: [testPutCsvAsStreamStringArrayOverwrite]
}
function testPutCsvAsStreamStringArrayAppend() returns error? {
    string path = "/streamtest/put-csv-stream-string-append.csv";
    string[][] initial = [["Alice", "25", "New York"]];
    stream<string[], error?> initialStream = initial.toStream();
    check streamTestClient->putCsvAsStream(path, initialStream, OVERWRITE);

    string[][] appended = [["Bob", "30", "Boston"]];
    stream<string[], error?> appendStream = appended.toStream();
    check streamTestClient->putCsvAsStream(path, appendStream, APPEND);

    string|Error result = streamTestClient->getText(path);
    test:assertTrue(result is string, "Failed to read appended CSV");
    if result is string {
        test:assertTrue(result.includes("Alice"), "CSV should contain Alice");
        test:assertTrue(result.includes("Bob"), "CSV should contain Bob");
    }
}

@test:Config {
    groups: ["stream", "putCsvAsStream", "putCsvAsStreamRecord"]
}
function testPutCsvAsStreamRecordOverwrite() returns error? {
    string path = "/streamtest/put-csv-stream-record-overwrite.csv";
    Employee[] records = [
        {name: "Alice", age: 25, department: "Engineering"},
        {name: "Bob", age: 30, department: "Marketing"}
    ];
    stream<Employee, error?> csvStream = records.toStream();
    check streamTestClient->putCsvAsStream(path, csvStream, OVERWRITE);

    string|Error result = streamTestClient->getText(path);
    test:assertTrue(result is string, "Failed to read record CSV written via stream");
    if result is string {
        test:assertTrue(result.includes("name"), "CSV should contain header 'name'");
        test:assertTrue(result.includes("age"), "CSV should contain header 'age'");
        test:assertTrue(result.includes("department"), "CSV should contain header 'department'");
        test:assertTrue(result.includes("Alice"), "CSV should contain Alice");
        test:assertTrue(result.includes("Bob"), "CSV should contain Bob");
    }
}

@test:Config {
    groups: ["stream", "putCsvAsStream", "putCsvAsStreamRecord"],
    dependsOn: [testPutCsvAsStreamRecordOverwrite]
}
function testPutCsvAsStreamRecordAppend() returns error? {
    string path = "/streamtest/put-csv-stream-record-append.csv";
    Employee[] initial = [{name: "Alice", age: 25, department: "Engineering"}];
    stream<Employee, error?> initialStream = initial.toStream();
    check streamTestClient->putCsvAsStream(path, initialStream, OVERWRITE);

    Employee[] appended = [{name: "Bob", age: 30, department: "Marketing"}];
    stream<Employee, error?> appendStream = appended.toStream();
    check streamTestClient->putCsvAsStream(path, appendStream, APPEND);

    string|Error result = streamTestClient->getText(path);
    test:assertTrue(result is string, "Failed to read appended record CSV");
    if result is string {
        test:assertTrue(result.includes("Alice"), "CSV should contain Alice");
        test:assertTrue(result.includes("Bob"), "CSV should contain Bob");
        // Header should appear only once (from OVERWRITE, not from APPEND)
        int nameHeaderCount = 0;
        int index = 0;
        while true {
            int? found = result.indexOf("name,age,department", index);
            if found is () {
                break;
            }
            nameHeaderCount += 1;
            index = found + 1;
        }
        test:assertEquals(nameHeaderCount, 1, "Header should appear only once");
    }
}

@test:Config {
    groups: ["stream", "putBytesAsStream", "integration"],
    dependsOn: [testPutBytesAsStreamLargeFile]
}
function testPutBytesAsStreamRoundTrip() returns error? {
    string srcPath = "/streamtest/bytes-stream-basic.bin";
    string destPath = "/streamtest/put-bytes-stream-roundtrip.bin";

    // Read as stream, then write as stream
    stream<byte[], error?> byteStream = check streamTestClient->getBytesAsStream(srcPath);
    check streamTestClient->putBytesAsStream(destPath, byteStream, OVERWRITE);

    byte[]|Error srcContent = streamTestClient->getBytes(srcPath);
    byte[]|Error destContent = streamTestClient->getBytes(destPath);
    test:assertTrue(srcContent is byte[] && destContent is byte[], "Both files should be readable");
    if srcContent is byte[] && destContent is byte[] {
        test:assertEquals(destContent, srcContent, "Round-trip byte stream content mismatch");
    }
}

@test:Config {
    groups: ["stream", "putCsvAsStream", "integration"],
    dependsOn: [testPutCsvAsStreamRecordAppend]
}
function testPutCsvAsStreamRoundTrip() returns error? {
    string srcPath = "/streamtest/csv-stream-string-array.csv";
    string destPath = "/streamtest/put-csv-stream-roundtrip.csv";

    // Read as stream, then write as stream
    stream<string[], error?> csvStream = check streamTestClient->getCsvAsStream(srcPath);
    check streamTestClient->putCsvAsStream(destPath, csvStream, OVERWRITE);

    string|Error srcContent = streamTestClient->getText(srcPath);
    string|Error destContent = streamTestClient->getText(destPath);
    test:assertTrue(srcContent is string && destContent is string, "Both files should be readable");
}

@test:Config {
    groups: ["stream", "integration"],
    dependsOn: [testStreamAndNonStreamApproaches]
}
function testBytesStreamVsNonStreamConsistency() returns error? {
    string path = "/streamtest/bytes-stream-vs-nonstream.bin";
    byte[] content = "Test bytes content for comparison".toBytes();
    check streamTestClient->putBytes(path, content, OVERWRITE);
    byte[]|Error bytesResult = streamTestClient->getBytes(path);
    test:assertTrue(bytesResult is byte[], "getBytes should return byte[]");
    stream<byte[], error?> byteStream = check streamTestClient->getBytesAsStream(path);
    byte[] streamResult = [];
    check from byte[] chunk in byteStream
        do {
            streamResult.push(...chunk);
        };
    if bytesResult is byte[] {
        test:assertEquals(streamResult.length(), bytesResult.length());
        test:assertEquals(streamResult, bytesResult);
    }
}
