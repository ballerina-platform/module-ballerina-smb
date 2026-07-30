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

import ballerina/smb as smbLib;

type Employee record {|
    string name;
    int id;
|};

listener smbLib:Listener remoteServer = check new ({share: "testshare"});

isolated service "StreamService" on remoteServer {

    isolated remote function onFile(stream<byte[], error?> content, smbLib:FileInfo fileInfo) returns error? {
        return;
    }

    isolated remote function onFileJson(Employee content) returns error? {
        return;
    }

    isolated remote function onFileXml(Employee content) returns smbLib:Error? {
        return;
    }

    isolated remote function onFileCsv(stream<Employee, error?> content) returns error? {
        return;
    }

    isolated remote function onFileText(string content) {
        return;
    }

    isolated remote function onError(error err) {
        return;
    }
}
