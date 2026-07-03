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

int copCrudCounter = 0;
boolean copExistsOk = false;
boolean copSizeOk = false;
boolean copIsDirOk = false;
boolean copGetTextOk = false;
boolean copGetBytesOk = false;
boolean copMkdirOk = false;
boolean copRmdirOk = false;
boolean copPatchOk = false;
boolean copRenameOk = false;
boolean copDeleteOk = false;
boolean copMoveOk = false;
boolean copCopyOk = false;

// ── state: format-specific reads ─────────────────────────────────────────
int copJsonGetCounter = 0;
boolean copGetJsonOk = false;
int copXmlGetCounter = 0;
boolean copGetXmlOk = false;
int copCsvGetCounter = 0;
boolean copGetCsvOk = false;
boolean copGetCsvStreamOk = false;
int copBytesStreamCounter = 0;
boolean copGetBytesStreamOk = false;
int copCloseHandlerCounter = 0;
boolean copCallerCloseOk = false;

// ── service: exercises getBytes, getText, exists, size, isDirectory,
//             mkdir, rmdir, patch, rename, move, copy, delete ─────────────
Service copCrudService = service object {
    remote function onFile(byte[] content, Caller caller, FileInfo fileInfo) returns error? {
        copCrudCounter += 1;

        boolean|Error existsR = caller->exists(fileInfo.path);
        copExistsOk = existsR is boolean;

        int|Error sizeR = caller->size(fileInfo.path);
        copSizeOk = sizeR is int;

        boolean|Error isDirR = caller->isDirectory(fileInfo.path);
        copIsDirOk = isDirR is boolean;

        string|Error textR = caller->getText(fileInfo.path);
        copGetTextOk = textR is string;

        byte[]|Error bytesR = caller->getBytes(fileInfo.path);
        copGetBytesOk = bytesR is byte[];

        Error? mkR = caller->mkdir("/cop_crud_test/tmp_dir");
        copMkdirOk = mkR is ();

        Error? rmR = caller->rmdir("/cop_crud_test/tmp_dir");
        copRmdirOk = rmR is ();

        // patch: write over a file at offset 0
        string patchPath = "/cop_crud_test/patch_file.txt";
        check caller->putText(patchPath, "original content to patch", OVERWRITE);
        Error? patchR = caller->patch(patchPath, "PATCHED!".toBytes(), 0);
        copPatchOk = patchR is ();

        // rename
        string rSrc = "/cop_crud_test/ren_src.txt";
        string rDst = "/cop_crud_test/ren_dst.txt";
        check caller->putText(rSrc, "rename content", OVERWRITE);
        Error? renR = caller->rename(rSrc, rDst);
        copRenameOk = renR is ();
        Error? delR = caller->delete(rDst);
        copDeleteOk = delR is ();

        // move
        string mSrc = "/cop_crud_test/mov_src.txt";
        string mDst = "/cop_crud_test/mov_dst.txt";
        check caller->putText(mSrc, "move content", OVERWRITE);
        Error? movR = caller->move(mSrc, mDst);
        copMoveOk = movR is ();
        check caller->delete(mDst);

        // copy
        string cSrc = "/cop_crud_test/cpy_src.txt";
        string cDst = "/cop_crud_test/cpy_dst.txt";
        check caller->putText(cSrc, "copy content", OVERWRITE);
        Error? cpyR = caller->copy(cSrc, cDst);
        copCopyOk = cpyR is ();
        check caller->delete(cSrc);
        check caller->delete(cDst);
    }

    function onError(error err) returns error? {
        io:println("copCrudService error: ", err.message());
    }
};

// ── service: exercises caller->getJson ───────────────────────────────────
Service copJsonGetService = service object {
    remote function onFileJson(json content, Caller caller, FileInfo fileInfo) returns error? {
        copJsonGetCounter += 1;
        json|Error r = caller->getJson(fileInfo.path);
        copGetJsonOk = r is json;
    }
    function onError(error err) returns error? {
        io:println("copJsonGetService error: ", err.message());
    }
};

// ── service: exercises caller->getXml ────────────────────────────────────
Service copXmlGetService = service object {
    remote function onFileXml(xml content, Caller caller, FileInfo fileInfo) returns error? {
        copXmlGetCounter += 1;
        xml|Error r = caller->getXml(fileInfo.path);
        copGetXmlOk = r is xml;
    }
    function onError(error err) returns error? {
        io:println("copXmlGetService error: ", err.message());
    }
};

// ── service: exercises caller->getCsv and caller->getCsvAsStream ─────────
Service copCsvGetService = service object {
    remote function onFileCsv(string[][] content, Caller caller, FileInfo fileInfo) returns error? {
        copCsvGetCounter += 1;
        string[][]|Error csvR = caller->getCsv(fileInfo.path);
        copGetCsvOk = csvR is string[][];
        stream<string[], error?>|Error streamR = caller->getCsvAsStream(fileInfo.path);
        copGetCsvStreamOk = streamR is stream<string[], error?>;
        if streamR is stream<string[], error?> {
            check streamR.close();
        }
    }
    function onError(error err) returns error? {
        io:println("copCsvGetService error: ", err.message());
    }
};

// ── service: exercises caller->getBytesAsStream ───────────────────────────
Service copBytesStreamGetService = service object {
    remote function onFile(stream<byte[], error?> content, Caller caller, FileInfo fileInfo) returns error? {
        copBytesStreamCounter += 1;
        stream<byte[], error?>|Error sr = caller->getBytesAsStream(fileInfo.path);
        copGetBytesStreamOk = sr is stream<byte[], error?>;
        if sr is stream<byte[], error?> {
            check sr.close();
        }
        check content.close();
    }
    function onError(error err) returns error? {
        io:println("copBytesStreamGetService error: ", err.message());
    }
};

// ── service: exercises caller->close() ───────────────────────────────────
Service copCloseCallerService = service object {
    remote function onFile(byte[] content, Caller caller, FileInfo fileInfo) returns error? {
        copCloseHandlerCounter += 1;
        Error? r = caller->close();
        copCallerCloseOk = r is ();
    }
    function onError(error err) returns error? {
        io:println("copCloseCallerService error: ", err.message());
    }
};

// ── helper: creates a standard test listener ──────────────────────────────
function newCopListener() returns Listener|error {
    return new ({
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
}

@test:Config {
    groups: ["cop", "caller-ops"],
    dependsOn: [testOnFileDeleteWithCaller]
}
function testCallerCrudAndReadOperations() returns error? {
    copCrudCounter = 0;
    copExistsOk = false;
    copSizeOk = false;
    copIsDirOk = false;
    copGetTextOk = false;
    copGetBytesOk = false;
    copMkdirOk = false;
    copRmdirOk = false;
    copPatchOk = false;
    copRenameOk = false;
    copDeleteOk = false;
    copMoveOk = false;
    copCopyOk = false;

    _ = check smbClient->mkdir("/cop_crud_test");

    Listener l = check newCopListener();
    check l.attach(copCrudService, "cop_crud_test");
    check l.'start();
    runtime:registerListener(l);
    runtime:sleep(3);

    copCrudCounter = 0;
    check smbClient->putText("/cop_crud_test/trigger.txt", "hello caller ops test", OVERWRITE);
    runtime:sleep(6);
    check l.immediateStop();

    test:assertTrue(copCrudCounter >= 1, "CRUD handler should fire at least once");
    test:assertTrue(copExistsOk, "caller->exists should succeed");
    test:assertTrue(copSizeOk, "caller->size should succeed");
    test:assertTrue(copIsDirOk, "caller->isDirectory should succeed");
    test:assertTrue(copGetTextOk, "caller->getText should succeed");
    test:assertTrue(copGetBytesOk, "caller->getBytes should succeed");
    test:assertTrue(copMkdirOk, "caller->mkdir should succeed");
    test:assertTrue(copRmdirOk, "caller->rmdir should succeed");
    test:assertTrue(copPatchOk, "caller->patch should succeed");
    test:assertTrue(copRenameOk, "caller->rename should succeed");
    test:assertTrue(copDeleteOk, "caller->delete should succeed");
    test:assertTrue(copMoveOk, "caller->move should succeed");
    test:assertTrue(copCopyOk, "caller->copy should succeed");
}

// ── Test 2: caller->getJson ──────────────────────────────────────────────
@test:Config {
    groups: ["cop", "caller-ops"],
    dependsOn: [testCallerCrudAndReadOperations]
}
function testCallerGetJsonMethod() returns error? {
    copJsonGetCounter = 0;
    copGetJsonOk = false;

    _ = check smbClient->mkdir("/cop_json_test");

    Listener l = check newCopListener();
    check l.attach(copJsonGetService, "cop_json_test");
    check l.'start();
    runtime:registerListener(l);
    runtime:sleep(3);

    copJsonGetCounter = 0;
    check smbClient->putJson("/cop_json_test/data.json", {key: "value", num: 42});
    runtime:sleep(6);
    check l.immediateStop();

    test:assertTrue(copJsonGetCounter >= 1, "JSON handler should fire");
    test:assertTrue(copGetJsonOk, "caller->getJson should succeed");
}

// ── Test 3: caller->getXml ───────────────────────────────────────────────
@test:Config {
    groups: ["cop", "caller-ops"],
    dependsOn: [testCallerGetJsonMethod]
}
function testCallerGetXmlMethod() returns error? {
    copXmlGetCounter = 0;
    copGetXmlOk = false;

    _ = check smbClient->mkdir("/cop_xml_test");

    Listener l = check newCopListener();
    check l.attach(copXmlGetService, "cop_xml_test");
    check l.'start();
    runtime:registerListener(l);
    runtime:sleep(3);

    copXmlGetCounter = 0;
    check smbClient->putXml("/cop_xml_test/data.xml",
        xml `<root><item>caller xml test</item></root>`);
    runtime:sleep(6);
    check l.immediateStop();

    test:assertTrue(copXmlGetCounter >= 1, "XML handler should fire");
    test:assertTrue(copGetXmlOk, "caller->getXml should succeed");
}

// ── Test 4: caller->getCsv and caller->getCsvAsStream ────────────────────
@test:Config {
    groups: ["cop", "caller-ops"],
    dependsOn: [testCallerGetXmlMethod]
}
function testCallerGetCsvAndCsvAsStream() returns error? {
    copCsvGetCounter = 0;
    copGetCsvOk = false;
    copGetCsvStreamOk = false;

    _ = check smbClient->mkdir("/cop_csv_test");

    Listener l = check newCopListener();
    check l.attach(copCsvGetService, "cop_csv_test");
    check l.'start();
    runtime:registerListener(l);
    runtime:sleep(3);

    copCsvGetCounter = 0;
    string[][] csvRows = [["id", "name", "score"], ["1", "Alice", "95"], ["2", "Bob", "87"]];
    check smbClient->putCsv("/cop_csv_test/data.csv", csvRows);
    runtime:sleep(6);
    check l.immediateStop();

    test:assertTrue(copCsvGetCounter >= 1, "CSV handler should fire");
    test:assertTrue(copGetCsvOk, "caller->getCsv should succeed");
    test:assertTrue(copGetCsvStreamOk, "caller->getCsvAsStream should succeed");
}

// ── Test 5: caller->getBytesAsStream ─────────────────────────────────────
@test:Config {
    groups: ["cop", "caller-ops"],
    dependsOn: [testCallerGetCsvAndCsvAsStream]
}
function testCallerGetBytesAsStream() returns error? {
    copBytesStreamCounter = 0;
    copGetBytesStreamOk = false;

    _ = check smbClient->mkdir("/cop_stream_test");

    Listener l = check newCopListener();
    check l.attach(copBytesStreamGetService, "cop_stream_test");
    check l.'start();
    runtime:registerListener(l);
    runtime:sleep(3);

    copBytesStreamCounter = 0;
    check smbClient->putBytes("/cop_stream_test/stream_data.bin", "streaming content".toBytes());
    runtime:sleep(6);
    check l.immediateStop();

    test:assertTrue(copBytesStreamCounter >= 1, "Bytes stream handler should fire");
    test:assertTrue(copGetBytesStreamOk, "caller->getBytesAsStream should succeed");
}

// ── Test 6: caller->close() ──────────────────────────────────────────────
@test:Config {
    groups: ["cop", "caller-ops"],
    dependsOn: [testCallerGetBytesAsStream]
}
function testCallerCloseMethod() returns error? {
    copCloseHandlerCounter = 0;
    copCallerCloseOk = false;

    _ = check smbClient->mkdir("/cop_close_test");

    Listener l = check newCopListener();
    check l.attach(copCloseCallerService, "cop_close_test");
    check l.'start();
    runtime:registerListener(l);
    runtime:sleep(3);

    copCloseHandlerCounter = 0;
    check smbClient->putBytes("/cop_close_test/close_trigger.bin", "close test".toBytes());
    runtime:sleep(6);
    check l.immediateStop();

    test:assertTrue(copCloseHandlerCounter >= 1, "Close handler should fire");
    test:assertTrue(copCallerCloseOk, "caller->close should succeed");
}
