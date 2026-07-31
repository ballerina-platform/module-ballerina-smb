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


import ballerina/smb;

type Employee record {|
    string name;
    int id;
|};

listener smb:Listener remoteServer = check new ({share: "testshare"});

// The listener always produces streams with an `error?` completion type, so a narrower
// completion type would fail when the stream is passed to the handler.
// Expected: INVALID_CONTENT_PARAMETER_TYPE x 2
service "ByteStreamCompletionService" on remoteServer {

    remote function onFile(stream<byte[], int> content) returns error? {
        return;
    }

    remote function onFileCsv(stream<string[], string> content) returns error? {
        return;
    }
}

// Expected: INVALID_CONTENT_PARAMETER_TYPE x 1
service "RecordStreamCompletionService" on remoteServer {

    remote function onFileCsv(stream<Employee, int> content) returns error? {
        return;
    }
}
