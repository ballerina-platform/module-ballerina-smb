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

int logFileCounter = 0;
string? capturedLogContent = ();
string? capturedLogFileName = ();

int mdFileCounter = 0;
string? capturedMdContent = ();
string? capturedMdFileName = ();
int funcConfigCounter = 0;
string? capturedFuncConfigContent = ();
int noAfterErrorCounter = 0;
int afterProcessDeleteCounter = 0;
int afterProcessMoveCounter = 0;
int afterErrorDeleteCounter = 0;
int afterErrorMoveCounter = 0;
int afterProcessMoveSubDirsCounter = 0;
int afterProcessBinaryDeleteCounter = 0;
int onDeleteMatchingPatternCounter = 0;
int onDeleteNonMatchingPatternCounter = 0;
int onDeleteListenerPatternCounter = 0;
int afterProcessJsonDeleteCounter = 0;
int afterErrorMoveOnFileCounter = 0;

final ListenerConfiguration POST_PROCESSING_LISTENER_CONFIG = {
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
};

@test:Config {
    groups: ["listener", "post-processing", "extensions"]
}
function testOnFileTextWithLogExtension() returns error? {
    logFileCounter = 0;
    capturedLogContent = ();
    capturedLogFileName = ();

    Service logTextService = service object {
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            logFileCounter += 1;
            capturedLogContent = content;
            capturedLogFileName = fileInfo.name;
        }
    };

    boolean logExtExists = check smbClient->exists("/log_ext_tests");
    if !logExtExists {
        check smbClient->mkdir("/log_ext_tests");
    }

    Listener logListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check logListener.attach(logTextService, "log_ext_tests");
    check logListener.'start();
    runtime:registerListener(logListener);

    runtime:sleep(3);

    logFileCounter = 0;
    capturedLogContent = ();
    capturedLogFileName = ();

    string logContent = "2026-03-30 INFO Application started successfully";
    check smbClient->putText("/log_ext_tests/app.log", logContent);
    runtime:sleep(5);

    check logListener.immediateStop();

    test:assertTrue(logFileCounter >= 1, "onFileText should be triggered for .log files");
    test:assertEquals(capturedLogContent, logContent, ".log file content should match");
    test:assertEquals(capturedLogFileName, "app.log", ".log file name should match");
}

@test:Config {
    groups: ["listener", "post-processing", "extensions"],
    dependsOn: [testOnFileTextWithLogExtension]
}
function testOnFileTextWithMdExtension() returns error? {
    mdFileCounter = 0;
    capturedMdContent = ();
    capturedMdFileName = ();

    Service mdTextService = service object {
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            mdFileCounter += 1;
            capturedMdContent = content;
            capturedMdFileName = fileInfo.name;
        }
    };

    boolean mdExtExists = check smbClient->exists("/md_ext_tests");
    if !mdExtExists {
        check smbClient->mkdir("/md_ext_tests");
    }

    Listener mdListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check mdListener.attach(mdTextService, "md_ext_tests");
    check mdListener.'start();
    runtime:registerListener(mdListener);

    runtime:sleep(3);

    mdFileCounter = 0;
    capturedMdContent = ();
    capturedMdFileName = ();

    string mdContent = "# README\nThis is a markdown file.";
    check smbClient->putText("/md_ext_tests/README.md", mdContent);
    runtime:sleep(5);

    check mdListener.immediateStop();

    test:assertTrue(mdFileCounter >= 1, "onFileText should be triggered for .md files");
    test:assertEquals(capturedMdContent, mdContent, ".md file content should match");
    test:assertEquals(capturedMdFileName, "README.md", ".md file name should match");
}

@test:Config {
    groups: ["listener", "post-processing", "annotations"]
}
function testFunctionConfigAnnotationOnServiceRemoteFunction() returns error? {
    funcConfigCounter = 0;
    capturedFuncConfigContent = ();

    Service funcConfigService = service object {
        @FunctionConfig {
            fileNamePattern: "report_(.*)\\.txt"
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            funcConfigCounter += 1;
            capturedFuncConfigContent = content;
            io:println("FunctionConfig matched file: ", fileInfo.name);
        }
    };

    boolean funcConfigExists = check smbClient->exists("/func_config_tests");
    if !funcConfigExists {
        check smbClient->mkdir("/func_config_tests");
    }

    Listener funcConfigListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check funcConfigListener.attach(funcConfigService, "func_config_tests");
    check funcConfigListener.'start();
    runtime:registerListener(funcConfigListener);

    runtime:sleep(3);

    funcConfigCounter = 0;
    capturedFuncConfigContent = ();

    string reportContent = "Monthly report data";
    check smbClient->putText("/func_config_tests/report_2026_03.txt", reportContent);
    check smbClient->putText("/func_config_tests/notes.txt", "should not match");
    runtime:sleep(5);

    check funcConfigListener.immediateStop();

    test:assertTrue(funcConfigCounter >= 1,
        "@FunctionConfig should allow onFileText to trigger for files matching the pattern");
    test:assertEquals(capturedFuncConfigContent, reportContent,
        "Content should be from the matching file");
}

@test:Config {
    groups: ["listener", "post-processing", "afterProcess"]
}
function testAfterProcessDelete() returns error? {
    afterProcessDeleteCounter = 0;

    Service deleteService = service object {
        @FunctionConfig {
            afterProcess: DELETE
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            afterProcessDeleteCounter += 1;
        }
    };

    boolean afterProcessDeleteExists = check smbClient->exists("/after_process_delete");
    if !afterProcessDeleteExists {
        check smbClient->mkdir("/after_process_delete");
    }

    Listener deleteListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check deleteListener.attach(deleteService, "after_process_delete");
    check deleteListener.'start();
    runtime:registerListener(deleteListener);

    runtime:sleep(3);

    afterProcessDeleteCounter = 0;

    check smbClient->putText("/after_process_delete/delete_me.txt", "content to delete");
    runtime:sleep(5);

    check deleteListener.immediateStop();

    test:assertTrue(afterProcessDeleteCounter >= 1, "onFileText should be triggered");
    boolean fileStillExists = check smbClient->exists("/after_process_delete/delete_me.txt");
    test:assertFalse(fileStillExists, "File should be deleted after successful processing");
}

@test:Config {
    groups: ["listener", "post-processing", "afterProcess"],
    dependsOn: [testAfterProcessDelete]
}
function testAfterProcessMove() returns error? {
    afterProcessMoveCounter = 0;

    Service moveService = service object {
        @FunctionConfig {
            afterProcess: {moveTo: "/after_process_move_dest", preserveSubDirs: false}
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            afterProcessMoveCounter += 1;
        }
    };

    boolean afterProcessMoveSrcExists = check smbClient->exists("/after_process_move_src");
    if !afterProcessMoveSrcExists {
        check smbClient->mkdir("/after_process_move_src");
    }
    boolean afterProcessMoveDestExists = check smbClient->exists("/after_process_move_dest");
    if !afterProcessMoveDestExists {
        check smbClient->mkdir("/after_process_move_dest");
    }

    Listener moveListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check moveListener.attach(moveService, "after_process_move_src");
    check moveListener.'start();
    runtime:registerListener(moveListener);

    runtime:sleep(3);

    afterProcessMoveCounter = 0;

    check smbClient->putText("/after_process_move_src/move_me.txt", "content to move");
    runtime:sleep(5);

    check moveListener.immediateStop();

    test:assertTrue(afterProcessMoveCounter >= 1, "onFileText should be triggered");
    boolean srcExists = check smbClient->exists("/after_process_move_src/move_me.txt");
    test:assertFalse(srcExists, "File should no longer exist in the source directory");
    boolean destExists = check smbClient->exists("/after_process_move_dest/move_me.txt");
    test:assertTrue(destExists, "File should exist in the destination directory after move");
}

@test:Config {
    groups: ["listener", "post-processing", "afterProcess"],
    dependsOn: [testAfterProcessMove]
}
function testAfterProcessMovePreserveSubDirs() returns error? {
    afterProcessMoveSubDirsCounter = 0;

    Service moveSubDirsService = service object {
        @FunctionConfig {
            afterProcess: {moveTo: "/after_process_subdirs_dest", preserveSubDirs: true}
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            afterProcessMoveSubDirsCounter += 1;
        }
    };

    boolean afterProcessSubdirsSrcExists = check smbClient->exists("/after_process_subdirs_src");
    if !afterProcessSubdirsSrcExists {
        check smbClient->mkdir("/after_process_subdirs_src");
    }
    boolean afterProcessSubdirsSrcSubExists = check smbClient->exists("/after_process_subdirs_src/sub");
    if !afterProcessSubdirsSrcSubExists {
        check smbClient->mkdir("/after_process_subdirs_src/sub");
    }
    boolean afterProcessSubdirsDestExists = check smbClient->exists("/after_process_subdirs_dest");
    if !afterProcessSubdirsDestExists {
        check smbClient->mkdir("/after_process_subdirs_dest");
    }

    Listener subDirsListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check subDirsListener.attach(moveSubDirsService, "after_process_subdirs_src");
    check subDirsListener.'start();
    runtime:registerListener(subDirsListener);

    runtime:sleep(3);

    afterProcessMoveSubDirsCounter = 0;

    check smbClient->putText("/after_process_subdirs_src/sub/nested.txt", "nested content");
    runtime:sleep(5);

    check subDirsListener.immediateStop();

    test:assertTrue(afterProcessMoveSubDirsCounter >= 1, "onFileText should be triggered");
    boolean srcExists = check smbClient->exists("/after_process_subdirs_src/sub/nested.txt");
    test:assertFalse(srcExists, "File should no longer exist at source");
    boolean destExists = check smbClient->exists("/after_process_subdirs_dest/sub/nested.txt");
    test:assertTrue(destExists, "File should be moved preserving subdirectory structure");
}

@test:Config {
    groups: ["listener", "post-processing", "afterError"],
    dependsOn: [testAfterProcessMovePreserveSubDirs]
}
function testAfterErrorDelete() returns error? {
    afterErrorDeleteCounter = 0;

    Service errorDeleteService = service object {
        @FunctionConfig {
            afterError: DELETE
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            afterErrorDeleteCounter += 1;
            return error("simulated processing error");
        }
    };

    boolean afterErrorDeleteExists = check smbClient->exists("/after_error_delete");
    if !afterErrorDeleteExists {
        check smbClient->mkdir("/after_error_delete");
    }

    Listener errorDeleteListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check errorDeleteListener.attach(errorDeleteService, "after_error_delete");
    check errorDeleteListener.'start();
    runtime:registerListener(errorDeleteListener);

    runtime:sleep(3);

    afterErrorDeleteCounter = 0;

    check smbClient->putText("/after_error_delete/error_file.txt", "this will cause an error");
    runtime:sleep(5);

    check errorDeleteListener.immediateStop();

    test:assertTrue(afterErrorDeleteCounter >= 1, "onFileText should be triggered");
    boolean fileStillExists = check smbClient->exists("/after_error_delete/error_file.txt");
    test:assertFalse(fileStillExists, "File should be deleted after processing error");
}

@test:Config {
    groups: ["listener", "post-processing", "afterError"],
    dependsOn: [testAfterErrorDelete]
}
function testAfterErrorMove() returns error? {
    afterErrorMoveCounter = 0;

    Service errorMoveService = service object {
        @FunctionConfig {
            afterError: {moveTo: "/after_error_move_dest", preserveSubDirs: false}
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            afterErrorMoveCounter += 1;
            return error("simulated processing error");
        }
    };

    boolean afterErrorMoveSrcExists = check smbClient->exists("/after_error_move_src");
    if !afterErrorMoveSrcExists {
        check smbClient->mkdir("/after_error_move_src");
    }
    boolean afterErrorMoveDestExists = check smbClient->exists("/after_error_move_dest");
    if !afterErrorMoveDestExists {
        check smbClient->mkdir("/after_error_move_dest");
    }

    Listener errorMoveListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check errorMoveListener.attach(errorMoveService, "after_error_move_src");
    check errorMoveListener.'start();
    runtime:registerListener(errorMoveListener);

    runtime:sleep(3);

    afterErrorMoveCounter = 0;

    check smbClient->putText("/after_error_move_src/error_move_me.txt", "this will error and be moved");
    runtime:sleep(5);

    check errorMoveListener.immediateStop();

    test:assertTrue(afterErrorMoveCounter >= 1, "onFileText should be triggered");
    boolean srcExists = check smbClient->exists("/after_error_move_src/error_move_me.txt");
    test:assertFalse(srcExists, "File should no longer exist in source directory");
    boolean destExists = check smbClient->exists("/after_error_move_dest/error_move_me.txt");
    test:assertTrue(destExists, "File should be moved to error destination");
}

@test:Config {
    groups: ["listener", "post-processing", "afterProcess", "onFile"],
    dependsOn: [testAfterErrorMove]
}
function testAfterProcessDeleteOnBinaryFile() returns error? {
    afterProcessBinaryDeleteCounter = 0;

    Service binaryDeleteService = service object {
        @FunctionConfig {
            afterProcess: DELETE
        }
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            afterProcessBinaryDeleteCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("Binary delete service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/after_process_binary_delete");
    if !exists {
        check smbClient->mkdir("/after_process_binary_delete");
    }

    Listener binaryDeleteListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check binaryDeleteListener.attach(binaryDeleteService, "after_process_binary_delete");
    check binaryDeleteListener.'start();
    runtime:registerListener(binaryDeleteListener);

    runtime:sleep(3);

    afterProcessBinaryDeleteCounter = 0;

    check smbClient->putBytes("/after_process_binary_delete/data.bin", [0x01, 0x02, 0x03]);
    runtime:sleep(5);

    check binaryDeleteListener.immediateStop();

    test:assertTrue(afterProcessBinaryDeleteCounter >= 1, "onFile should be triggered for binary files");
    boolean fileExists = check smbClient->exists("/after_process_binary_delete/data.bin");
    test:assertFalse(fileExists, "Binary file should be deleted after processing via onFile handler");
}

@test:Config {
    groups: ["listener", "post-processing", "afterProcess", "onFileJson"],
    dependsOn: [testAfterProcessDeleteOnBinaryFile]
}
function testAfterProcessDeleteOnJsonFile() returns error? {
    afterProcessJsonDeleteCounter = 0;

    Service jsonDeleteService = service object {
        @FunctionConfig {
            afterProcess: DELETE
        }
        remote function onFileJson(json content, FileInfo fileInfo) returns error? {
            afterProcessJsonDeleteCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("JSON delete service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/after_process_json_delete");
    if !exists {
        check smbClient->mkdir("/after_process_json_delete");
    }

    Listener jsonDeleteListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check jsonDeleteListener.attach(jsonDeleteService, "after_process_json_delete");
    check jsonDeleteListener.'start();
    runtime:registerListener(jsonDeleteListener);

    runtime:sleep(3);

    afterProcessJsonDeleteCounter = 0;

    json testData = {id: 1, name: "test"};
    check smbClient->putJson("/after_process_json_delete/data.json", testData);
    runtime:sleep(5);

    check jsonDeleteListener.immediateStop();

    test:assertTrue(afterProcessJsonDeleteCounter >= 1, "onFileJson should be triggered");
    boolean fileExists = check smbClient->exists("/after_process_json_delete/data.json");
    test:assertFalse(fileExists, "JSON file should be deleted after processing");
}

@test:Config {
    groups: ["listener", "post-processing", "afterError", "onFile"],
    dependsOn: [testAfterProcessDeleteOnJsonFile]
}
function testAfterErrorMoveOnBinaryFile() returns error? {
    afterErrorMoveOnFileCounter = 0;

    Service binaryErrorMoveService = service object {
        @FunctionConfig {
            afterError: {moveTo: "/after_error_move_binary_dest", preserveSubDirs: false}
        }
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            afterErrorMoveOnFileCounter += 1;
            return error("simulated binary processing error");
        }

        function onError(error err) returns error? {
            io:println("Binary error move service error: ", err.message());
        }
    };

    boolean srcExists = check smbClient->exists("/after_error_move_binary_src");
    if !srcExists {
        check smbClient->mkdir("/after_error_move_binary_src");
    }
    boolean destExists = check smbClient->exists("/after_error_move_binary_dest");
    if !destExists {
        check smbClient->mkdir("/after_error_move_binary_dest");
    }

    Listener binaryErrorMoveListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check binaryErrorMoveListener.attach(binaryErrorMoveService, "after_error_move_binary_src");
    check binaryErrorMoveListener.'start();
    runtime:registerListener(binaryErrorMoveListener);

    runtime:sleep(3);

    afterErrorMoveOnFileCounter = 0;

    check smbClient->putBytes("/after_error_move_binary_src/error.bin", [0xDE, 0xAD, 0xBE, 0xEF]);
    runtime:sleep(5);

    check binaryErrorMoveListener.immediateStop();

    test:assertTrue(afterErrorMoveOnFileCounter >= 1, "onFile should be triggered for binary error test");
    boolean fileAtSrc = check smbClient->exists("/after_error_move_binary_src/error.bin");
    test:assertFalse(fileAtSrc, "Binary file should no longer be in source after error move");
    boolean fileAtDest = check smbClient->exists("/after_error_move_binary_dest/error.bin");
    test:assertTrue(fileAtDest, "Binary file should be moved to destination after error");
}

@test:Config {
    groups: ["listener", "post-processing", "onFileDelete", "pattern"],
    dependsOn: [testAfterErrorMoveOnBinaryFile]
}
function testOnFileDeleteWithMatchingFunctionConfigPattern() returns error? {
    onDeleteMatchingPatternCounter = 0;

    Service patternDeleteService = service object {
        @FunctionConfig {
            fileNamePattern: "(.*)\\.log"
        }
        remote function onFileDelete(string deletedFile) returns error? {
            onDeleteMatchingPatternCounter += 1;
        }

        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
        }

        function onError(error err) returns error? {
            io:println("Pattern delete service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/pattern_delete_tests");
    if !exists {
        check smbClient->mkdir("/pattern_delete_tests");
    }

    Listener patternDeleteListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check patternDeleteListener.attach(patternDeleteService, "pattern_delete_tests");
    check patternDeleteListener.'start();
    runtime:registerListener(patternDeleteListener);

    runtime:sleep(3);

    onDeleteMatchingPatternCounter = 0;

    check smbClient->putText("/pattern_delete_tests/app.log", "log content");
    runtime:sleep(3);
    check smbClient->delete("/pattern_delete_tests/app.log");
    runtime:sleep(5);

    check patternDeleteListener.immediateStop();

    test:assertTrue(onDeleteMatchingPatternCounter >= 1,
        "onFileDelete should be triggered for file matching @FunctionConfig pattern");
}

@test:Config {
    groups: ["listener", "post-processing", "onFileDelete", "pattern"],
    dependsOn: [testOnFileDeleteWithMatchingFunctionConfigPattern]
}
function testOnFileDeleteWithNonMatchingFunctionConfigPattern() returns error? {
    onDeleteNonMatchingPatternCounter = 0;

    Service noMatchPatternDeleteService = service object {
        @FunctionConfig {
            fileNamePattern: "(.*)\\.csv"
        }
        remote function onFileDelete(string deletedFile) returns error? {
            onDeleteNonMatchingPatternCounter += 1;
        }

        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
        }

        function onError(error err) returns error? {
            io:println("No-match pattern service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/no_match_delete_tests");
    if !exists {
        check smbClient->mkdir("/no_match_delete_tests");
    }

    Listener noMatchListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check noMatchListener.attach(noMatchPatternDeleteService, "no_match_delete_tests");
    check noMatchListener.'start();
    runtime:registerListener(noMatchListener);

    runtime:sleep(3);

    onDeleteNonMatchingPatternCounter = 0;

    check smbClient->putText("/no_match_delete_tests/noMatch.txt", "content");
    runtime:sleep(3);
    check smbClient->delete("/no_match_delete_tests/noMatch.txt");
    runtime:sleep(5);

    check noMatchListener.immediateStop();

    test:assertEquals(onDeleteNonMatchingPatternCounter, 0,
        "onFileDelete should NOT be triggered when filename does not match the @FunctionConfig pattern");
}

@test:Config {
    groups: ["listener", "post-processing", "onFileDelete", "pattern"],
    dependsOn: [testOnFileDeleteWithNonMatchingFunctionConfigPattern]
}
function testOnFileDeleteWithListenerLevelFileNamePattern() returns error? {
    onDeleteListenerPatternCounter = 0;

    Service listenerPatternDeleteService = service object {
        remote function onFileDelete(string deletedFile) returns error? {
            onDeleteListenerPatternCounter += 1;
        }

        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
        }

        function onError(error err) returns error? {
            io:println("Listener pattern delete service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/listener_pattern_delete_tests");
    if !exists {
        check smbClient->mkdir("/listener_pattern_delete_tests");
    }

    ListenerConfiguration patternListenerConfig = {
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
        bufferSize: 65536,
        fileNamePattern: "(.*)\\.log"
    };

    Listener listenerPatternListener = check new (patternListenerConfig);
    check listenerPatternListener.attach(listenerPatternDeleteService, "listener_pattern_delete_tests");
    check listenerPatternListener.'start();
    runtime:registerListener(listenerPatternListener);

    runtime:sleep(3);

    onDeleteListenerPatternCounter = 0;

    check smbClient->putText("/listener_pattern_delete_tests/system.log", "log content");
    runtime:sleep(3);
    check smbClient->delete("/listener_pattern_delete_tests/system.log");
    runtime:sleep(5);

    check listenerPatternListener.immediateStop();

    test:assertTrue(onDeleteListenerPatternCounter >= 1,
        "onFileDelete should be triggered for file matching listener-level fileNamePattern");
}

@test:Config {
    groups: ["listener", "post-processing", "afterError"],
    dependsOn: [testOnFileDeleteWithListenerLevelFileNamePattern]
}
function testAfterProcessOnlyLeavesFileOnError() returns error? {
    noAfterErrorCounter = 0;

    Service processOnlyService = service object {
        @FunctionConfig {
            afterProcess: DELETE
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            noAfterErrorCounter += 1;
            return error("simulated error, no afterError configured");
        }
    };

    boolean afterProcessOnlyErrorExists = check smbClient->exists("/after_process_only_error");
    if !afterProcessOnlyErrorExists {
        check smbClient->mkdir("/after_process_only_error");
    }

    Listener processOnlyListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check processOnlyListener.attach(processOnlyService, "after_process_only_error");
    check processOnlyListener.'start();
    runtime:registerListener(processOnlyListener);

    runtime:sleep(3);

    noAfterErrorCounter = 0;

    check smbClient->putText("/after_process_only_error/stays.txt", "should remain after error");
    runtime:sleep(5);

    check processOnlyListener.immediateStop();

    test:assertTrue(noAfterErrorCounter >= 1, "onFileText should be triggered");
    boolean fileStillExists = check smbClient->exists("/after_process_only_error/stays.txt");
    test:assertTrue(fileStillExists, "File should remain when error occurs and no afterError is configured");
}
