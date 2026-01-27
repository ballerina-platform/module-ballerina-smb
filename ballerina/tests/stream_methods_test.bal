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

@test:Config {
    groups: ["stream", "integration"],
    dependsOn: [testGetCsvAsStreamCloseEarly]
}
function testStreamVsNonStreamConsistency() returns error? {
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
        test:assertEquals(streamResult.length(), csvResult.slice(1).length(), "Stream and non-stream row count should match");
        test:assertEquals(streamResult, csvResult.slice(1), "Stream and non-stream content should match");
    }
}

@test:Config {
    groups: ["stream", "integration"],
    dependsOn: [testStreamVsNonStreamConsistency]
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
