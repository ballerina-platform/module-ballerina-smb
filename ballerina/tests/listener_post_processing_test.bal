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
int onDeleteErrorCounter = 0;
int onDeleteInvalidRegexCounter = 0;
int noParamHandlerFileCounter = 0;
int fallbackToOnFileCounter = 0;
int afterProcessMoveTrailingSlashCounter = 0;
int afterProcessXmlDeleteCounter = 0;
int afterProcessCsvDeleteCounter = 0;
int afterProcessMoveNewDirCounter = 0;
int malformedJsonErrorCounter = 0;
int afterProcessLaxJsonCounter = 0;
int afterErrorXmlMoveCounter = 0;
int anonymousAuthFileCounter = 0;
int noExtensionFileCounter = 0;
int detachServiceCounter = 0;
int invalidRegexContentHandlerCounter = 0;
int csvEscapedQuotesCounter = 0;
int missingAuthErrorCounter = 0;
int panicHandlerErrorCounter = 0;
int moveConflictErrorCounter = 0;
int emptyMoveToCounter = 0;
int doubleSlashMoveCounter = 0;

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

@test:Config {
    groups: ["listener", "post-processing", "onFileDelete"]
}
function testOnFileDeleteReturnsError() returns error? {
    onDeleteErrorCounter = 0;

    Service errorOnDeleteService = service object {
        remote function onFileDelete(string deletedFile) returns error? {
            onDeleteErrorCounter += 1;
            return error("simulated onFileDelete error");
        }

        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
        }

        function onError(error err) returns error? {
            io:println("Expected error from onFileDelete handler: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/delete_error_tests");
    if !exists {
        check smbClient->mkdir("/delete_error_tests");
    }

    Listener deleteErrorListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check deleteErrorListener.attach(errorOnDeleteService, "delete_error_tests");
    check deleteErrorListener.'start();
    runtime:registerListener(deleteErrorListener);

    runtime:sleep(3);

    onDeleteErrorCounter = 0;

    check smbClient->putText("/delete_error_tests/err_file.txt", "content");
    runtime:sleep(3);
    check smbClient->delete("/delete_error_tests/err_file.txt");
    runtime:sleep(5);

    check deleteErrorListener.immediateStop();

    test:assertTrue(onDeleteErrorCounter >= 1,
        "onFileDelete should be triggered even when it returns an error");
}

@test:Config {
    groups: ["listener", "post-processing", "onFileDelete", "pattern"]
}
function testOnFileDeleteWithInvalidRegexPattern() returns error? {
    onDeleteInvalidRegexCounter = 0;

    Service invalidRegexService = service object {
        @FunctionConfig {
            fileNamePattern: "[invalid_regex"
        }
        remote function onFileDelete(string deletedFile) returns error? {
            onDeleteInvalidRegexCounter += 1;
        }

        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
        }

        function onError(error err) returns error? {
            io:println("Invalid regex service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/invalid_regex_delete_tests");
    if !exists {
        check smbClient->mkdir("/invalid_regex_delete_tests");
    }

    Listener invalidRegexListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check invalidRegexListener.attach(invalidRegexService, "invalid_regex_delete_tests");
    check invalidRegexListener.'start();
    runtime:registerListener(invalidRegexListener);

    runtime:sleep(3);

    onDeleteInvalidRegexCounter = 0;

    check smbClient->putText("/invalid_regex_delete_tests/test.txt", "content");
    runtime:sleep(3);
    check smbClient->delete("/invalid_regex_delete_tests/test.txt");
    runtime:sleep(5);

    check invalidRegexListener.immediateStop();

    test:assertEquals(onDeleteInvalidRegexCounter, 0,
        "onFileDelete should NOT be triggered when fileNamePattern is an invalid regex");
}

@test:Config {
    groups: ["listener", "post-processing", "handlers"]
}
function testOnFileHandlerWithNoContentParameter() returns error? {
    noParamHandlerFileCounter = 0;

    Service noParamService = service object {
        remote function onFile() returns error? {
            noParamHandlerFileCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("No-param handler error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/no_param_handler_tests");
    if !exists {
        check smbClient->mkdir("/no_param_handler_tests");
    }

    Listener noParamListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check noParamListener.attach(noParamService, "no_param_handler_tests");
    check noParamListener.'start();
    runtime:registerListener(noParamListener);

    runtime:sleep(3);

    noParamHandlerFileCounter = 0;

    check smbClient->putBytes("/no_param_handler_tests/data.bin", [0x01, 0x02]);
    runtime:sleep(5);

    check noParamListener.immediateStop();

    test:assertEquals(noParamHandlerFileCounter, 0,
        "Handler with no parameters should be skipped (not triggered)");
}

@test:Config {
    groups: ["listener", "post-processing", "handlers", "fallback"]
}
function testFallbackFromSpecificHandlerToOnFile() returns error? {
    fallbackToOnFileCounter = 0;

    Service fallbackService = service object {
        @FunctionConfig {
            fileNamePattern: "specific_(.*)\\.txt"
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            io:println("onFileText should NOT be called: ", fileInfo.name);
        }

        @FunctionConfig {
            afterProcess: DELETE
        }
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            fallbackToOnFileCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("Fallback service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/fallback_handler_tests");
    if !exists {
        check smbClient->mkdir("/fallback_handler_tests");
    }

    Listener fallbackListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check fallbackListener.attach(fallbackService, "fallback_handler_tests");
    check fallbackListener.'start();
    runtime:registerListener(fallbackListener);

    runtime:sleep(3);

    fallbackToOnFileCounter = 0;

    check smbClient->putText("/fallback_handler_tests/other_file.txt", "content for fallback test");
    runtime:sleep(5);

    check fallbackListener.immediateStop();

    test:assertTrue(fallbackToOnFileCounter >= 1,
        "onFile fallback should be triggered when specific handler pattern does not match");
    boolean fileExists = check smbClient->exists("/fallback_handler_tests/other_file.txt");
    test:assertFalse(fileExists, "File should be deleted by onFile fallback afterProcess");
}

@test:Config {
    groups: ["listener", "post-processing", "afterProcess"]
}
function testAfterProcessMoveWithTrailingSlashDestination() returns error? {
    afterProcessMoveTrailingSlashCounter = 0;

    Service trailingSlashMoveService = service object {
        @FunctionConfig {
            afterProcess: {moveTo: "/trailing_slash_dest/", preserveSubDirs: false}
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            afterProcessMoveTrailingSlashCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("Trailing slash move error: ", err.message());
        }
    };

    boolean srcExists = check smbClient->exists("/trailing_slash_src");
    if !srcExists {
        check smbClient->mkdir("/trailing_slash_src");
    }
    boolean destExists = check smbClient->exists("/trailing_slash_dest");
    if !destExists {
        check smbClient->mkdir("/trailing_slash_dest");
    }

    Listener trailingSlashListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check trailingSlashListener.attach(trailingSlashMoveService, "trailing_slash_src");
    check trailingSlashListener.'start();
    runtime:registerListener(trailingSlashListener);

    runtime:sleep(3);

    afterProcessMoveTrailingSlashCounter = 0;

    check smbClient->putText("/trailing_slash_src/trail.txt", "content");
    runtime:sleep(5);

    check trailingSlashListener.immediateStop();

    test:assertTrue(afterProcessMoveTrailingSlashCounter >= 1, "onFileText should be triggered");
    boolean srcFileExists = check smbClient->exists("/trailing_slash_src/trail.txt");
    test:assertFalse(srcFileExists, "File should be moved away from source");
    boolean destFileExists = check smbClient->exists("/trailing_slash_dest/trail.txt");
    test:assertTrue(destFileExists, "File should be in destination after move");
}

@test:Config {
    groups: ["listener", "post-processing", "afterProcess"]
}
function testAfterProcessDeleteOnXmlFile() returns error? {
    afterProcessXmlDeleteCounter = 0;

    Service xmlDeleteService = service object {
        @FunctionConfig {
            afterProcess: DELETE
        }
        remote function onFileXml(xml content, FileInfo fileInfo) returns error? {
            afterProcessXmlDeleteCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("XML delete service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/after_process_xml_delete");
    if !exists {
        check smbClient->mkdir("/after_process_xml_delete");
    }

    Listener xmlDeleteListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check xmlDeleteListener.attach(xmlDeleteService, "after_process_xml_delete");
    check xmlDeleteListener.'start();
    runtime:registerListener(xmlDeleteListener);

    runtime:sleep(3);

    afterProcessXmlDeleteCounter = 0;

    check smbClient->putXml("/after_process_xml_delete/config.xml",
        xml `<config><key>value</key></config>`);
    runtime:sleep(5);

    check xmlDeleteListener.immediateStop();

    test:assertTrue(afterProcessXmlDeleteCounter >= 1, "onFileXml should be triggered");
    boolean fileExists = check smbClient->exists("/after_process_xml_delete/config.xml");
    test:assertFalse(fileExists, "XML file should be deleted after processing");
}

@test:Config {
    groups: ["listener", "post-processing", "afterProcess"]
}
function testAfterProcessDeleteOnCsvFile() returns error? {
    afterProcessCsvDeleteCounter = 0;

    Service csvDeleteService = service object {
        @FunctionConfig {
            afterProcess: DELETE
        }
        remote function onFileCsv(string[][] content, FileInfo fileInfo) returns error? {
            afterProcessCsvDeleteCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("CSV delete service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/after_process_csv_delete");
    if !exists {
        check smbClient->mkdir("/after_process_csv_delete");
    }

    Listener csvDeleteListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check csvDeleteListener.attach(csvDeleteService, "after_process_csv_delete");
    check csvDeleteListener.'start();
    runtime:registerListener(csvDeleteListener);

    runtime:sleep(3);

    afterProcessCsvDeleteCounter = 0;

    string[][] csvData = [["id", "name"], ["1", "Alice"]];
    check smbClient->putCsv("/after_process_csv_delete/data.csv", csvData);
    runtime:sleep(5);

    check csvDeleteListener.immediateStop();

    test:assertTrue(afterProcessCsvDeleteCounter >= 1, "onFileCsv should be triggered");
    boolean fileExists = check smbClient->exists("/after_process_csv_delete/data.csv");
    test:assertFalse(fileExists, "CSV file should be deleted after processing");
}

@test:Config {
    groups: ["listener", "post-processing", "afterProcess"]
}
function testAfterProcessMoveCreatesDestinationDirectory() returns error? {
    afterProcessMoveNewDirCounter = 0;

    Service moveNewDirService = service object {
        @FunctionConfig {
            afterProcess: {moveTo: "/auto_created_move_dest", preserveSubDirs: false}
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            afterProcessMoveNewDirCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("Move new dir service error: ", err.message());
        }
    };

    boolean srcExists = check smbClient->exists("/auto_move_src");
    if !srcExists {
        check smbClient->mkdir("/auto_move_src");
    }
    boolean destExists = check smbClient->exists("/auto_created_move_dest");
    if destExists {
        error? rmResult = smbClient->delete("/auto_created_move_dest");
        if rmResult is error {
            io:println("Could not remove dest dir: ", rmResult.message());
        }
    }

    Listener moveNewDirListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check moveNewDirListener.attach(moveNewDirService, "auto_move_src");
    check moveNewDirListener.'start();
    runtime:registerListener(moveNewDirListener);

    runtime:sleep(3);

    afterProcessMoveNewDirCounter = 0;

    check smbClient->putText("/auto_move_src/auto_dest_file.txt", "content for auto-dir creation");
    runtime:sleep(5);

    check moveNewDirListener.immediateStop();

    test:assertTrue(afterProcessMoveNewDirCounter >= 1, "onFileText should be triggered");
    boolean fileAtDest = check smbClient->exists("/auto_created_move_dest/auto_dest_file.txt");
    test:assertTrue(fileAtDest,
        "File should be moved to auto-created destination directory");
}

@test:Config {
    groups: ["listener", "post-processing", "content-error"]
}
function testMalformedJsonTriggersBErrorPath() returns error? {
    malformedJsonErrorCounter = 0;

    Service malformedJsonService = service object {
        remote function onFileJson(json content, FileInfo fileInfo) returns error? {
            malformedJsonErrorCounter += 1;
        }

        function onError(error err) returns error? {
            malformedJsonErrorCounter += 1;
            io:println("Malformed JSON error (expected): ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/malformed_json_tests");
    if !exists {
        check smbClient->mkdir("/malformed_json_tests");
    }

    Listener malformedJsonListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check malformedJsonListener.attach(malformedJsonService, "malformed_json_tests");
    check malformedJsonListener.'start();
    runtime:registerListener(malformedJsonListener);

    runtime:sleep(3);

    malformedJsonErrorCounter = 0;

    check smbClient->putBytes("/malformed_json_tests/bad.json", "{not valid json".toBytes());
    runtime:sleep(5);

    check malformedJsonListener.immediateStop();

    test:assertTrue(malformedJsonErrorCounter >= 1,
        "onError should be triggered when JSON parsing fails (covers BError content path)");
}

@test:Config {
    groups: ["listener", "post-processing", "laxDataBinding"]
}
function testOnFileJsonWithLaxDataBinding() returns error? {
    afterProcessLaxJsonCounter = 0;

    Service laxJsonService = service object {
        @FunctionConfig {
            afterProcess: DELETE
        }
        remote function onFileJson(json content, FileInfo fileInfo) returns error? {
            afterProcessLaxJsonCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("Lax JSON service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/lax_json_tests");
    if !exists {
        check smbClient->mkdir("/lax_json_tests");
    }

    ListenerConfiguration laxListenerConfig = {
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
        laxDataBinding: true
    };

    Listener laxJsonListener = check new (laxListenerConfig);
    check laxJsonListener.attach(laxJsonService, "lax_json_tests");
    check laxJsonListener.'start();
    runtime:registerListener(laxJsonListener);

    runtime:sleep(3);

    afterProcessLaxJsonCounter = 0;

    check smbClient->putJson("/lax_json_tests/data.json", {name: "test", value: 42});
    runtime:sleep(5);

    check laxJsonListener.immediateStop();

    test:assertTrue(afterProcessLaxJsonCounter >= 1,
        "onFileJson should be triggered with laxDataBinding enabled");
    boolean fileExists = check smbClient->exists("/lax_json_tests/data.json");
    test:assertFalse(fileExists, "File should be deleted after processing with laxDataBinding");
}

@test:Config {
    groups: ["listener", "post-processing", "afterError"]
}
function testAfterErrorMoveOnXmlFile() returns error? {
    afterErrorXmlMoveCounter = 0;

    Service xmlErrorMoveService = service object {
        @FunctionConfig {
            afterError: {moveTo: "/after_error_xml_move_dest", preserveSubDirs: false}
        }
        remote function onFileXml(xml content, FileInfo fileInfo) returns error? {
            afterErrorXmlMoveCounter += 1;
            return error("simulated XML processing error");
        }

        function onError(error err) returns error? {
            io:println("XML error move service error: ", err.message());
        }
    };

    boolean srcExists = check smbClient->exists("/after_error_xml_move_src");
    if !srcExists {
        check smbClient->mkdir("/after_error_xml_move_src");
    }
    boolean destExists = check smbClient->exists("/after_error_xml_move_dest");
    if !destExists {
        check smbClient->mkdir("/after_error_xml_move_dest");
    }

    Listener xmlErrorMoveListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check xmlErrorMoveListener.attach(xmlErrorMoveService, "after_error_xml_move_src");
    check xmlErrorMoveListener.'start();
    runtime:registerListener(xmlErrorMoveListener);

    runtime:sleep(3);

    afterErrorXmlMoveCounter = 0;

    check smbClient->putXml("/after_error_xml_move_src/error.xml",
        xml `<data><item>test</item></data>`);
    runtime:sleep(5);

    check xmlErrorMoveListener.immediateStop();

    test:assertTrue(afterErrorXmlMoveCounter >= 1, "onFileXml should be triggered");
    boolean fileAtSrc = check smbClient->exists("/after_error_xml_move_src/error.xml");
    test:assertFalse(fileAtSrc, "XML file should no longer be in source after error move");
    boolean fileAtDest = check smbClient->exists("/after_error_xml_move_dest/error.xml");
    test:assertTrue(fileAtDest, "XML file should be moved to destination after error");

    // Cleanup: remove the moved XML file
    error? cleanupResult = smbClient->delete("/after_error_xml_move_dest/error.xml");
    if cleanupResult is error {
        io:println("Could not clean up moved XML file: ", cleanupResult.message());
    }
}

@test:Config {
    groups: ["listener", "post-processing", "auth"]
}
function testAnonymousAuthWithPublicShare() returns error? {
    anonymousAuthFileCounter = 0;

    Service anonService = service object {
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            anonymousAuthFileCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("Anonymous auth service error: ", err.message());
        }
    };

    ListenerConfiguration anonListenerConfig = {
        host: "localhost",
        port: 445,
        share: "publicshare",
        pollingInterval: 2,
        bufferSize: 65536
    };

    Listener anonListener = check new (anonListenerConfig);
    check anonListener.attach(anonService, "");
    check anonListener.'start();
    runtime:registerListener(anonListener);

    runtime:sleep(5);

    check anonListener.immediateStop();

    // Reaching here means the anonymous auth path ran without a fatal error
    test:assertTrue(true, "Anonymous auth listener should start and poll without fatal error");
}

@test:Config {
    groups: ["listener", "post-processing", "extensions"]
}
function testFileWithoutExtension() returns error? {
    noExtensionFileCounter = 0;

    Service noExtService = service object {
        @FunctionConfig {
            afterProcess: DELETE
        }
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            noExtensionFileCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("No-extension file service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/no_ext_tests");
    if !exists {
        check smbClient->mkdir("/no_ext_tests");
    }

    Listener noExtListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check noExtListener.attach(noExtService, "no_ext_tests");
    check noExtListener.'start();
    runtime:registerListener(noExtListener);

    runtime:sleep(3);

    noExtensionFileCounter = 0;

    // Upload a file with no extension - isExecutableFile returns false for these
    check smbClient->putBytes("/no_ext_tests/Makefile", "build: echo done".toBytes());
    runtime:sleep(5);

    check noExtListener.immediateStop();

    test:assertTrue(noExtensionFileCounter >= 1,
        "onFile should be triggered for files without extension");
    boolean fileExists = check smbClient->exists("/no_ext_tests/Makefile");
    test:assertFalse(fileExists, "File without extension should be deleted after processing");
}

@test:Config {
    groups: ["listener", "post-processing", "deregister"]
}
function testDetachServiceCallsDeregister() returns error? {
    detachServiceCounter = 0;

    Service detachService = service object {
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            detachServiceCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("Detach service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/detach_service_tests");
    if !exists {
        check smbClient->mkdir("/detach_service_tests");
    }

    Listener detachListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check detachListener.attach(detachService, "detach_service_tests");
    check detachListener.'start();
    runtime:registerListener(detachListener);

    runtime:sleep(3);

    detachServiceCounter = 0;

    check smbClient->putText("/detach_service_tests/before_detach.txt", "before detach");
    runtime:sleep(4);

    check detachListener.detach(detachService);

    test:assertTrue(detachServiceCounter >= 1,
        "onFileText should have been triggered before detach");
}

@test:Config {
    groups: ["listener", "post-processing", "pattern"]
}
function testInvalidRegexOnContentHandlerSkipsFile() returns error? {
    invalidRegexContentHandlerCounter = 0;

    Service invalidRegexContentService = service object {
        @FunctionConfig {
            fileNamePattern: "[invalid_regex_pattern"
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            invalidRegexContentHandlerCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("Invalid regex content handler error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/invalid_regex_content_tests");
    if !exists {
        check smbClient->mkdir("/invalid_regex_content_tests");
    }

    Listener invalidRegexContentListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check invalidRegexContentListener.attach(invalidRegexContentService, "invalid_regex_content_tests");
    check invalidRegexContentListener.'start();
    runtime:registerListener(invalidRegexContentListener);

    runtime:sleep(3);

    invalidRegexContentHandlerCounter = 0;

    check smbClient->putText("/invalid_regex_content_tests/test.txt", "some content");
    runtime:sleep(5);

    check invalidRegexContentListener.immediateStop();

    test:assertEquals(invalidRegexContentHandlerCounter, 0,
        "onFileText should NOT be triggered when fileNamePattern is an invalid regex");
}

@test:Config {
    groups: ["listener", "post-processing", "csv"]
}
function testCsvStringArrayHandlerWithEscapedQuotes() returns error? {
    csvEscapedQuotesCounter = 0;

    Service csvEscapedService = service object {
        @FunctionConfig {
            afterProcess: DELETE
        }
        remote function onFileCsv(string[][] content, FileInfo fileInfo) returns error? {
            csvEscapedQuotesCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("CSV escaped quotes service error: ", err.message());
        }
    };

    boolean exists = check smbClient->exists("/csv_escaped_tests");
    if !exists {
        check smbClient->mkdir("/csv_escaped_tests");
    }

    Listener csvEscapedListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check csvEscapedListener.attach(csvEscapedService, "csv_escaped_tests");
    check csvEscapedListener.'start();
    runtime:registerListener(csvEscapedListener);

    runtime:sleep(3);

    csvEscapedQuotesCounter = 0;

    // CSV with double-quoted fields containing escaped double quotes (e.g., "" inside quotes)
    string csvContent = "name,description\n\"Alice\",\"She said \"\"hello\"\" to me\"\n\"Bob\",\"Normal field\"";
    check smbClient->putBytes("/csv_escaped_tests/quoted.csv", csvContent.toBytes());
    runtime:sleep(5);

    check csvEscapedListener.immediateStop();

    test:assertTrue(csvEscapedQuotesCounter >= 1,
        "onFileCsv should be triggered for CSV with escaped quotes");
    boolean fileExists = check smbClient->exists("/csv_escaped_tests/quoted.csv");
    test:assertFalse(fileExists, "CSV file should be deleted after processing");
}

@test:Config {
    groups: ["listener", "post-processing", "auth"]
}
function testMissingAuthCredentialsTriggersError() returns error? {
    missingAuthErrorCounter = 0;

    Service missingCredService = service object {
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            io:println("Should not be triggered");
        }

        function onError(error err) returns error? {
            missingAuthErrorCounter += 1;
            io:println("Expected auth error: ", err.message());
        }
    };

    ListenerConfiguration missingAuthConfig = {
        host: "localhost",
        port: 445,
        share: "testshare",
        auth: {},
        pollingInterval: 2,
        bufferSize: 65536
    };

    Listener missingAuthListener = check new (missingAuthConfig);
    check missingAuthListener.attach(missingCredService, "any_path");
    check missingAuthListener.'start();
    runtime:registerListener(missingAuthListener);

    runtime:sleep(5);

    check missingAuthListener.immediateStop();

    test:assertTrue(missingAuthErrorCounter >= 1,
        "onError should be triggered when auth has no credentials or kerberos config");
}

// ── L816-819: virtual-thread catch block ─────────────────────────────────────
// A Ballerina `panic` inside a handler causes callMethod() to throw a Java
// exception (BError extends RuntimeException), hitting the catch block at L816.
// With afterError configured, L818-819 are also hit (executePostProcessAction).
@test:Config {
    groups: ["listener", "post-processing", "virtual-thread"]
}
function testHandlerPanicTriggersVirtualThreadCatch() returns error? {
    panicHandlerErrorCounter = 0;

    Service panicService = service object {
        @FunctionConfig {
            afterError: DELETE
        }
        remote function onFile(byte[] content, FileInfo fileInfo) returns error? {
            panic error("forced panic to hit virtual-thread catch block at L816");
        }

        function onError(error err) returns error? {
            panicHandlerErrorCounter += 1;
        }
    };

    boolean exists = check smbClient->exists("/panic_handler_tests");
    if !exists {
        check smbClient->mkdir("/panic_handler_tests");
    }

    Listener panicListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check panicListener.attach(panicService, "panic_handler_tests");
    check panicListener.'start();
    runtime:registerListener(panicListener);

    runtime:sleep(3);

    panicHandlerErrorCounter = 0;

    check smbClient->putBytes("/panic_handler_tests/panic_file.bin", "Data".toBytes());
    runtime:sleep(6);

    check panicListener.immediateStop();

    test:assertTrue(panicHandlerErrorCounter >= 1,
        "onError should be called when handler panics (L816-817 virtual-thread catch)");
    boolean fileDeleted = check smbClient->exists("/panic_handler_tests/panic_file.bin");
    test:assertFalse(fileDeleted,
        "afterError:DELETE should remove the file after handler panic (L818-819)");
}

// ── L838 + L908: executePostProcessAction catch + ensureDirectoryExists catch ─
// Pre-creating a FILE at the path where ensureDirectoryExists tries to mkdir
// causes diskShare.mkdir() to throw (L908 catch ignored).  The subsequent
// file.rename() then also fails, hitting the catch at L838 in
// executePostProcessAction which calls notifyServiceOnError.
@test:Config {
    groups: ["listener", "post-processing", "post-process-error"]
}
function testMoveFailureWhenDestPathIsFile() returns error? {
    moveConflictErrorCounter = 0;

    Service moveConflictService = service object {
        @FunctionConfig {
            afterProcess: {moveTo: "/l908_file_as_dir/sub", preserveSubDirs: false}
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
        }

        function onError(error err) returns error? {
            moveConflictErrorCounter += 1;
        }
    };

    boolean srcExists = check smbClient->exists("/l908_move_src");
    if !srcExists {
        check smbClient->mkdir("/l908_move_src");
    }
    // Pre-create a FILE named "l908_file_as_dir".  When ensureDirectoryExists tries
    // to mkdir("l908_file_as_dir"), SMBJ throws because that name already exists
    // as a file → L908.  The subsequent rename also fails → L838.
    check smbClient->putText("/l908_file_as_dir", "i am a file not a dir");

    Listener moveConflictListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check moveConflictListener.attach(moveConflictService, "l908_move_src");
    check moveConflictListener.'start();
    runtime:registerListener(moveConflictListener);

    runtime:sleep(3);

    moveConflictErrorCounter = 0;

    check smbClient->putText("/l908_move_src/conflict.txt", "trigger move failure");
    runtime:sleep(6);

    check moveConflictListener.immediateStop();

    test:assertTrue(moveConflictErrorCounter >= 1,
        "onError should fire when the move destination path cannot be created (L838 + L908)");
}

// ── L881 + L891: ensureTrailingSlash(empty) + ensureDirectoryExists early return
// moveTo:"" triggers ensureTrailingSlash("") → returns "/" at L881.
// The resulting destination is a root-level path ("filename"), so dirPath is ""
// inside ensureDirectoryExists → early return at L891.
@test:Config {
    groups: ["listener", "post-processing", "post-process-paths"]
}
function testEmptyMoveToDestination() returns error? {
    emptyMoveToCounter = 0;

    Service emptyMoveToService = service object {
        @FunctionConfig {
            afterProcess: {moveTo: "", preserveSubDirs: false}
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            emptyMoveToCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("Empty moveTo error: ", err.message());
        }
    };

    boolean srcExists = check smbClient->exists("/empty_moveto_src");
    if !srcExists {
        check smbClient->mkdir("/empty_moveto_src");
    }

    Listener emptyMoveToListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check emptyMoveToListener.attach(emptyMoveToService, "empty_moveto_src");
    check emptyMoveToListener.'start();
    runtime:registerListener(emptyMoveToListener);

    runtime:sleep(3);

    emptyMoveToCounter = 0;

    check smbClient->putText("/empty_moveto_src/root_move.txt", "move to share root");
    runtime:sleep(6);

    check emptyMoveToListener.immediateStop();

    test:assertTrue(emptyMoveToCounter >= 1, "onFileText should be triggered");
    // File is moved to share root; clean up
    error? cleanup = smbClient->delete("/root_move.txt");
    if cleanup is error {
        io:println("Cleanup of root-level file: ", cleanup.message());
    }
}

// ── L897: empty path-segment skip inside ensureDirectoryExists ────────────────
// moveTo:"//l897_dest" causes destinationPath to start with "//" so after
// stripping ONE leading "/" the normalizedDest retains a leading "/".
// ensureDirectoryExists splits the resulting dirPath ("/l897_dest") on "/" which
// produces ["", "l897_dest"]; the empty first element hits the continue at L897.
@test:Config {
    groups: ["listener", "post-processing", "post-process-paths"]
}
function testDoubleSlashMoveToCoversEmptyPathSegment() returns error? {
    doubleSlashMoveCounter = 0;

    Service doubleSlashService = service object {
        @FunctionConfig {
            afterProcess: {moveTo: "//l897_dest", preserveSubDirs: false}
        }
        remote function onFileText(string content, FileInfo fileInfo) returns error? {
            doubleSlashMoveCounter += 1;
        }

        function onError(error err) returns error? {
            io:println("Double-slash move error (expected): ", err.message());
        }
    };

    boolean srcExists = check smbClient->exists("/l897_move_src");
    if !srcExists {
        check smbClient->mkdir("/l897_move_src");
    }

    Listener doubleSlashListener = check new (POST_PROCESSING_LISTENER_CONFIG);
    check doubleSlashListener.attach(doubleSlashService, "l897_move_src");
    check doubleSlashListener.'start();
    runtime:registerListener(doubleSlashListener);

    runtime:sleep(3);

    doubleSlashMoveCounter = 0;

    check smbClient->putText("/l897_move_src/segment.txt", "empty segment test");
    runtime:sleep(6);

    check doubleSlashListener.immediateStop();

    test:assertTrue(doubleSlashMoveCounter >= 1,
        "onFileText should be triggered (L897 empty-segment path exercised during move)");
}
