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

final ClientConfiguration testConfig = {
    host: "localhost",
    port: 445,
    share: "testshare",
    auth: {
        credentials: {
            username: "testuser",
            password: "testpass"
        }
    }
};

Client testClient = check new (testConfig);

type Person record {|
    string name;
    int age;
    string city;
|};


type Book record {|
    string title;
    string author;
|};

@test:BeforeSuite
function setupTestDirectory() returns error? {
    _ = check testClient->mkdir("test");
}

@test:Config {
    groups: ["put", "putBytes"]
}
function testPutBytesOverwrite() returns error? {
    string path = "/test/put-bytes-overwrite.bin";
    byte[] content = "Data in bytes".toBytes();
    check testClient->putBytes(path, content, OVERWRITE);
    byte[]|error result = testClient->getBytes(path);
    test:assertTrue(result is byte[]);
    if result is byte[] {
        test:assertEquals(result, content, "Byte content mismatch");
    }
}

@test:Config {
    groups: ["put", "putBytes"],
    dependsOn: [testPutBytesOverwrite]
}
function testPutBytesAppend() returns error? {
    string path = "/test/put-bytes-append.bin";
    byte[] content1 = "First ".toBytes();
    byte[] content2 = "Second".toBytes();
    check testClient->putBytes(path, content1, OVERWRITE);
    check testClient->putBytes(path, content2, APPEND);
    byte[]|Error result = testClient->getBytes(path);
    test:assertTrue(result is byte[], "Failed to read appended bytes");
    if result is byte[] {
        string expected = "First Second";
        test:assertEquals(result, expected.toBytes(), "Appended bytes mismatch");
    }
}

@test:Config {
    groups: ["put", "putBytes"],
    dependsOn: [testPutBytesAppend]
}
function testPutBytesEmpty() returns error? {
    string path = "/test/put-bytes-empty.bin";
    byte[] content = [];
    check testClient->putBytes(path, content, OVERWRITE);
    byte[]|Error result = testClient->getBytes(path);
    test:assertTrue(result is byte[], "Failed to read empty bytes");
    if result is byte[] {
        test:assertEquals(result.length(), 0, "Empty byte array expected");
    }
}

@test:Config {
    groups: ["put", "patch"],
    dependsOn: [testPutBytesEmpty]
}
function testPatchBytesAtOffset() returns error? {
    string path = "/test/patch-bytes-offset.bin";
    byte[] initialContent = "Hello World!".toBytes();
    check testClient->putBytes(path, initialContent, OVERWRITE);

    byte[] patchContent = "Ballerina".toBytes();
    check testClient->patch(path, patchContent, 6);

    byte[]|Error result = testClient->getBytes(path);
    test:assertTrue(result is byte[], "Failed to read patched bytes");
    if result is byte[] {
        string resultStr = check string:fromBytes(result);
        test:assertEquals(resultStr, "Hello Ballerina", "Patched content mismatch");
    }
}

@test:Config {
    groups: ["put", "patch"],
    dependsOn: [testPatchBytesAtOffset]
}
function testPatchBytesAtStart() returns error? {
    string path = "/test/patch-bytes-start.bin";
    byte[] initialContent = "_____ World".toBytes();
    check testClient->putBytes(path, initialContent, OVERWRITE);

    byte[] patchContent = "Hello".toBytes();
    check testClient->patch(path, patchContent, 0);

    byte[]|Error result = testClient->getBytes(path);
    test:assertTrue(result is byte[], "Failed to read patched bytes at start");
    if result is byte[] {
        string resultStr = check string:fromBytes(result);
        test:assertEquals(resultStr, "Hello World", "Patched content at start mismatch");
    }
}

@test:Config {
    groups: ["put", "patch"],
    dependsOn: [testPatchBytesAtStart]
}
function testPatchBytesExtendFile() returns error? {
    string path = "/test/patch-bytes-extend.bin";
    byte[] initialContent = "Hello".toBytes();
    check testClient->putBytes(path, initialContent, OVERWRITE);

    byte[] patchContent = " World".toBytes();
    check testClient->patch(path, patchContent, 5);

    byte[]|Error result = testClient->getBytes(path);
    test:assertTrue(result is byte[], "Failed to read extended patched bytes");
    if result is byte[] {
        string resultStr = check string:fromBytes(result);
        test:assertEquals(resultStr, "Hello World", "Extended patched content mismatch");
    }
}

@test:Config {
    groups: ["put", "putText"]
}
function testPutTextOverwrite() returns error? {
    string path = "/test/put-text-overwrite.txt";
    string content = "Hello SMB Text";
    check testClient->putText(path, content, OVERWRITE);
    string|Error result = testClient->getText(path);
    test:assertTrue(result is string, "Failed to read text");
    if result is string {
        test:assertEquals(result, content, "Text content mismatch");
    }
}

@test:Config {
    groups: ["put", "putText"],
    dependsOn: [testPutTextOverwrite]
}
function testPutTextAppend() returns error? {
    string path = "/test/put-text-append.txt";
    string content1 = "Hello ";
    string content2 = "World";

    check testClient->putText(path, content1, OVERWRITE);
    check testClient->putText(path, content2, APPEND);

    string|Error result = testClient->getText(path);
    test:assertTrue(result is string, "Failed to read appended text");
    if result is string {
        test:assertEquals(result, "Hello World", "Appended text mismatch");
    }
}

@test:Config {
    groups: ["put", "putText"],
    dependsOn: [testPutTextAppend]
}
function testPutTextMultiline() returns error? {
    string path = "/test/put-text-multiline.txt";
    string content = "Line 1\nLine 2\nLine 3";

    check testClient->putText(path, content, OVERWRITE);

    string|Error result = testClient->getText(path);
    test:assertTrue(result is string, "Failed to read multiline text");
    if result is string {
        test:assertEquals(result, content, "Multiline text mismatch");
    }
}

@test:Config {
    groups: ["put", "putText"],
    dependsOn: [testPutTextMultiline]
}
function testPutTextUnicode() returns error? {
    string path = "/test/put-text-unicode.txt";
    string content = "Hello";

    check testClient->putText(path, content, OVERWRITE);

    string|Error result = testClient->getText(path);
    test:assertTrue(result is string, "Failed to read unicode text");
    if result is string {
        test:assertEquals(result, content, "Unicode text mismatch");
    }
}

@test:Config {
    groups: ["put", "putJson"]
}
function testPutJsonSimple() returns error? {
    string path = "/test/put-json-simple.json";
    json content = {name: "John", age: 30, active: true};

    check testClient->putJson(path, content, OVERWRITE);

    json|Error result = testClient->getJson(path);
    test:assertTrue(result is json, "Failed to read JSON");
    if result is json {
        test:assertEquals(result, content, "JSON content mismatch");
    }
}

@test:Config {
    groups: ["put", "putJson"],
    dependsOn: [testPutJsonSimple]
}
function testPutJsonArray() returns error? {
    string path = "/test/put-json-array.json";
    json content = [
        {id: 1, name: "Alice"},
        {id: 2, name: "Bob"},
        {id: 3, name: "Charlie"}
    ];
    check testClient->putJson(path, content, OVERWRITE);
    json|Error result = testClient->getJson(path);
    test:assertTrue(result is json, "Failed to read JSON array");
    if result is json {
        test:assertEquals(result, content, "JSON array content mismatch");
    }
}

@test:Config {
    groups: ["put", "putJson"],
    dependsOn: [testPutJsonArray]
}
function testPutJsonNested() returns error? {
    string path = "/test/put-json-nested.json";
    json content = {
        user: {
            name: "Jane",
            address: {
                city: "New York",
                zip: "10001"
            }
        }
    };
    check testClient->putJson(path, content, OVERWRITE);
    json|Error result = testClient->getJson(path);
    test:assertTrue(result is json, "Failed to read nested JSON");
    if result is json {
        test:assertEquals(result, content, "Nested JSON content mismatch");
    }
}

@test:Config {
    groups: ["put", "putJson"],
    dependsOn: [testPutJsonNested]
}
function testPutJsonRecord() returns error? {
    string path = "/test/put-json-record.json";
    Person personRecord = {name: "Alice", age: 28, city: "Seattle"};
    check testClient->putJson(path, personRecord, OVERWRITE);
    json|Error result = testClient->getJson(path);
    test:assertTrue(result is json, "Failed to read JSON from record");
    if result is json {
        test:assertEquals(result.name, "Alice", "JSON name mismatch");
        test:assertEquals(result.age, 28, "JSON age mismatch");
        test:assertEquals(result.city, "Seattle", "JSON city mismatch");
    }
}

@test:Config {
    groups: ["put", "getJson", "getJsonAsRecord"],
    dependsOn: [testPutJsonRecord]
}
function testGetJsonAsRecord() returns error? {
    string path = "/test/get-json-as-record.json";
    json content = {name: "John Doe", age: 35, city: "San Francisco"};
    check testClient->putJson(path, content, OVERWRITE);
    Person|Error result = testClient->getJson(path);
    test:assertTrue(result is Person, "Failed to read JSON as record type");
    if result is Person {
        test:assertEquals(result.name, "John Doe", "Name mismatch");
        test:assertEquals(result.age, 35, "Age mismatch");
        test:assertEquals(result.city, "San Francisco", "City mismatch");
    }
}

@test:Config {
    groups: ["put", "getJson", "getJsonAsRecord"],
    dependsOn: [testGetJsonAsRecord]
}
function testGetJsonAsNestedRecord() returns error? {
    string path = "/test/get-json-as-nested-record.json";
    json content = {
        name: "Jane Smith",
        department: "Marketing",
        address: {
            city: "Austin",
            zip: "78701"
        }
    };
    check testClient->putJson(path, content, OVERWRITE);
    EmployeeRecord|Error result = testClient->getJson(path);
    test:assertTrue(result is EmployeeRecord, "Failed to read JSON as nested record type");
    if result is EmployeeRecord {
        test:assertEquals(result.name, "Jane Smith", "Name mismatch");
        test:assertEquals(result.department, "Marketing", "Department mismatch");
        test:assertEquals(result.address.city, "Austin", "City mismatch");
        test:assertEquals(result.address.zip, "78701", "Zip mismatch");
    }
}

@test:Config {
    groups: ["put", "putXml"]
}
function testPutXmlSimple() returns error? {
    string path = "/test/put-xml-simple.xml";
    xml content = xml `<person><name>John</name><age>30</age></person>`;
    check testClient->putXml(path, content, OVERWRITE);
    xml|Error result = testClient->getXml(path);
    test:assertTrue(result is xml, "Failed to read XML");
    if result is xml {
        test:assertEquals(result.toString(), content.toString(), "XML content mismatch");
    }
}

@test:Config {
    groups: ["put", "putXml"],
    dependsOn: [testPutXmlSimple]
}
function testPutXmlNested() returns error? {
    string path = "/test/put-xml-nested.xml";
    xml content = xml `<root>
        <person>
            <name>Alice</name>
            <address>
                <city>Boston</city>
                <zip>02101</zip>
            </address>
        </person>
    </root>`;
    check testClient->putXml(path, content, OVERWRITE);
    xml|Error result = testClient->getXml(path);
    test:assertTrue(result is xml);
    if result is xml {
        string resultStr = result.toString();
        test:assertTrue(resultStr.includes("<name>Alice</name>"), "XML should contain Alice");
        test:assertTrue(resultStr.includes("<city>Boston</city>"), "XML should contain Boston");
    }
}

@test:Config {
    groups: ["put", "putXml"],
    dependsOn: [testPutXmlNested]
}
function testPutXmlWithAttributes() returns error? {
    string path = "/test/put-xml-attributes.xml";
    xml content = xml `<book id="123" category="fiction"><title>Sample Book</title></book>`;
    check testClient->putXml(path, content, OVERWRITE);
    xml|Error result = testClient->getXml(path);
    test:assertTrue(result is xml, "Failed to read XML with attributes");
    if result is xml {
        string resultStr = result.toString();
        test:assertTrue(resultStr.includes("id="));
        test:assertTrue(resultStr.includes("Sample Book"));
    }
}

@test:Config {
    groups: ["put", "putXml"],
    dependsOn: [testPutXmlWithAttributes]
}
function testPutXmlRecord() returns error? {
    string path = "/test/put-xml-record.xml";
    Person personRecord = {name: "Bob", age: 35, city: "Chicago"};
    check testClient->putXml(path, personRecord, OVERWRITE);
    string|Error result = testClient->getText(path);
    test:assertTrue(result is string, "Failed to read XML from record");
    if result is string {
        test:assertTrue(result.includes("<name>Bob</name>"));
        test:assertTrue(result.includes("<age>35</age>"));
        test:assertTrue(result.includes("<city>Chicago</city>"));
    }
}

@test:Config {
    groups: ["put", "getXml", "getXmlAsRecord"],
    dependsOn: [testPutXmlRecord]
}
function testGetXmlAsRecord() returns error? {
    string path = "/test/get-xml-as-record.xml";
    xml content = xml `<Book><title>The Great Gatsby</title><author>F. Scott Fitzgerald</author></Book>`;
    check testClient->putXml(path, content, OVERWRITE);
    Book|Error result = testClient->getXml(path);
    test:assertTrue(result is Book, "Failed to read XML as record type");
    if result is Book {
        test:assertEquals(result.title, "The Great Gatsby", "Title mismatch");
        test:assertEquals(result.author, "F. Scott Fitzgerald", "Author mismatch");
    }
}

@test:Config {
    groups: ["put", "getXml", "getXmlAsRecord"],
    dependsOn: [testGetXmlAsRecord]
}
function testGetXmlAsNestedRecord() returns error? {
    string path = "/test/get-xml-as-nested-record.xml";
    xml content = xml `<Employee><name>Jane Doe</name><department>Engineering</department><address><city>Seattle</city><zip>98101</zip></address></Employee>`;
    check testClient->putXml(path, content, OVERWRITE);
    EmployeeRecord|Error result = testClient->getXml(path);
    test:assertTrue(result is EmployeeRecord, "Failed to read XML as nested record type");
    if result is EmployeeRecord {
        test:assertEquals(result.name, "Jane Doe", "Name mismatch");
        test:assertEquals(result.department, "Engineering", "Department mismatch");
        test:assertEquals(result.address.city, "Seattle", "City mismatch");
        test:assertEquals(result.address.zip, "98101", "Zip mismatch");
    }
}

type Address record {|
    string city;
    string zip;
|};

type EmployeeRecord record {|
    string name;
    string department;
    Address address;
|};

@test:Config {
    groups: ["put", "putCsv"]
}
function testPutCsvStringArrays() returns error? {
    string path = "/test/put-csv-string-arrays.csv";
    string[][] content = [
        ["name", "age", "city"],
        ["Alice", "25", "New York"],
        ["Bob", "30", "Boston"],
        ["Charlie", "35", "Chicago"]
    ];
    check testClient->putCsv(path, content, OVERWRITE);
    string[][]|Error result = testClient->getCsv(path);
    test:assertTrue(result is string[][], "Failed to read CSV");
    if result is string[][] {
        test:assertEquals(result, content.slice(1));
    }
}

@test:Config {
    groups: ["put", "putCsv"],
    dependsOn: [testPutCsvStringArrays]
}
function testPutCsvAppend() returns error? {
    string path = "/test/put-csv-append.csv";
    string[][] header = [
        ["id", "name", "score"]
    ];
    string[][] data1 = [
        ["1", "Alice", "95"]
    ];
    string[][] data2 = [
        ["2", "Bob", "87"],
        ["3", "Charlie", "92"]
    ];
    check testClient->putCsv(path, header, OVERWRITE);
    check testClient->putCsv(path, data1, APPEND);
    check testClient->putCsv(path, data2, APPEND);
    string|Error result = testClient->getText(path);
    test:assertTrue(result is string, "Failed to read appended CSV");
    if result is string {
        test:assertTrue(result.includes("id,name,score"));
        test:assertTrue(result.includes("Alice"));
        test:assertTrue(result.includes("Bob"));
        test:assertTrue(result.includes("Charlie"));
    }
}

@test:Config {
    groups: ["put", "putCsv"],
    dependsOn: [testPutCsvAppend]
}
function testPutCsvWithSpecialCharacters() returns error? {
    string path = "/test/put-csv-special-chars.csv";
    string[][] content = [
        ["name", "description"],
        ["Product A", "Contains, comma"],
        ["Product B", "Has \"quotes\""],
        ["Product C", "Line\nbreak"]
    ];
    check testClient->putCsv(path, content, OVERWRITE);
    string|Error result = testClient->getText(path);
    test:assertTrue(result is string, "Failed to read CSV with special chars");
    if result is string {
        test:assertTrue(result.includes("\"Contains, comma\""));
        test:assertTrue(result.includes("\"\""));
    }
}

@test:Config {
    groups: ["put", "putCsv"],
    dependsOn: [testPutCsvWithSpecialCharacters]
}
function testPutCsvEmptyValues() returns error? {
    string path = "/test/put-csv-empty.csv";
    string[][] content = [
        ["col1", "col2", "col3"],
        ["value1", "", "value3"],
        ["", "value2", ""],
        ["", "", ""]
    ];
    check testClient->putCsv(path, content, OVERWRITE);
    string|Error result = testClient->getText(path);
    test:assertTrue(result is string, "Failed to read CSV with empty values");
    if result is string {
        test:assertTrue(result.includes("value1,,value3"));
        test:assertTrue(result.includes(",value2,"));
    }
}

@test:Config {
    groups: ["put", "putCsv", "putCsvRecords"]
}
function testPutCsvRecordsAppendNoHeader() returns error? {
    string path = "/test/put-csv-records-append.csv";
    Person[][] initial = [[
        {name: "Alice", age: 25, city: "New York"}
    ]];
    Person[][] additional = [[
        {name: "Bob", age: 30, city: "Boston"}
    ]];
    check testClient->putCsv(path, initial, OVERWRITE);
    check testClient->putCsv(path, additional, APPEND);
    string|Error result = testClient->getText(path);
    test:assertTrue(result is string, "Failed to read appended CSV records");
    if result is string {
        int nameCount = 0;
        int index = 0;
        while true {
            int? found = result.indexOf("name", index);
            if found is () {
                break;
            }
            nameCount += 1;
            index = found + 1;
        }
        test:assertTrue(nameCount <= 2, "Header 'name' should appear only once or twice (once in header)");
        test:assertTrue(result.includes("Alice"));
        test:assertTrue(result.includes("Bob"));
    }
}

@test:Config {
    groups: ["put", "integration"],
    dependsOn: [testPutCsvRecordsAppendNoHeader]
}
function testPutTextThenOverwrite() returns error? {
    string path = "/test/put-overwrite-test.txt";
    check testClient->putText(path, "Initial content", OVERWRITE);

    string|Error result1 = testClient->getText(path);
    test:assertTrue(result1 is string, "Failed to read initial text");
    if result1 is string {
        test:assertEquals(result1, "Initial content", "Initial content mismatch");
    }
    check testClient->putText(path, "New content", OVERWRITE);
    string|Error result2 = testClient->getText(path);
    test:assertTrue(result2 is string, "Failed to read overwritten text");
    if result2 is string {
        test:assertEquals(result2, "New content");
    }
}

@test:Config {
    groups: ["put", "integration"],
    dependsOn: [testPutTextThenOverwrite]
}
function testPutDifferentFormatsToSameFile() returns error? {
    string path = "/test/put-different-formats.txt";
    check testClient->putText(path, "Text content", OVERWRITE);
    json jsonContent = {message: "JSON content"};
    check testClient->putJson(path, jsonContent, OVERWRITE);
    string|Error result = testClient->getText(path);
    test:assertTrue(result is string, "Failed to read content");
    if result is string {
        test:assertTrue(result.includes("JSON content"));
    }
}
