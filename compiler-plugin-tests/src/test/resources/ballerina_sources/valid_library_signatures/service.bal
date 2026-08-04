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
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

// Every handler signature used by the SMB package's own tests and examples. This guards
// against the compiler plugin rejecting shapes the listener actually supports.

import ballerina/smb;

type Person record {|
    string name;
    int age;
|};

listener smb:Listener remoteServer = check new ({share: "testshare"});

// Caller before FileInfo.
service "callerFirst" on remoteServer {

    remote function onFile(byte[] content, smb:Caller caller, smb:FileInfo fileInfo) returns error? {
        return;
    }

    remote function onFileText(string content, smb:Caller caller, smb:FileInfo fileInfo) returns error? {
        return;
    }

    remote function onFileJson(Person content, smb:Caller caller, smb:FileInfo fileInfo) returns error? {
        return;
    }

    remote function onFileXml(xml content, smb:Caller caller, smb:FileInfo fileInfo) returns error? {
        return;
    }

    remote function onFileCsv(string[][] content, smb:Caller caller, smb:FileInfo fileInfo) returns error? {
        return;
    }

    remote function onFileDelete(string deletedFile, smb:Caller caller) returns error? {
        return;
    }

    remote function onError(error err) returns error? {
        return;
    }
}

// FileInfo only, plus stream content types.
service "fileInfoOnly" on remoteServer {

    remote function onFile(stream<byte[], error?> content, smb:FileInfo fileInfo) returns error? {
        return;
    }

    remote function onFileText(string content, smb:FileInfo fileInfo) returns error? {
        return;
    }

    remote function onFileJson(json content, smb:FileInfo fileInfo) returns error? {
        return;
    }

    remote function onFileXml(Person content, smb:FileInfo fileInfo) returns error? {
        return;
    }

    remote function onFileCsv(stream<string[], error?> content, smb:FileInfo fileInfo,
            smb:Caller caller) returns error? {
        return;
    }

    remote function onFileDelete(string deletedFile) returns error? {
        return;
    }
}

// Record-typed CSV content, as an array and as a stream.
service "recordCsvArray" on remoteServer {

    remote function onFileCsv(Person[] content, smb:FileInfo fileInfo) returns error? {
        return;
    }
}

service "recordCsvStream" on remoteServer {

    remote function onFileCsv(stream<Person, error?> content, smb:FileInfo fileInfo) returns error? {
        return;
    }
}
