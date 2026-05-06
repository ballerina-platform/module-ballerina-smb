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

    check smbClient->mkdir("/log_ext_tests");

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

    check smbClient->mkdir("/md_ext_tests");

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

    check smbClient->mkdir("/func_config_tests");

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

    check smbClient->mkdir("/after_process_delete");

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

    check smbClient->mkdir("/after_process_move_src");
    check smbClient->mkdir("/after_process_move_dest");

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

    check smbClient->mkdir("/after_process_subdirs_src");
    check smbClient->mkdir("/after_process_subdirs_src/sub");
    check smbClient->mkdir("/after_process_subdirs_dest");

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

    check smbClient->mkdir("/after_error_delete");

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

    check smbClient->mkdir("/after_error_move_src");
    check smbClient->mkdir("/after_error_move_dest");

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
    groups: ["listener", "post-processing", "afterError"],
    dependsOn: [testAfterErrorMove]
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

    check smbClient->mkdir("/after_process_only_error");

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
