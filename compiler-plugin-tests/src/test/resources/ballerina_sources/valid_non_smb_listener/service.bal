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

# A listener that has nothing to do with SMB. Services attached to it must be left
# untouched by the SMB compiler plugin, even though `ballerina/smb` is a dependency
# of this package.
public type CustomService service object {
};

public class CustomListener {

    public isolated function init() returns error? {
        return;
    }

    public isolated function 'start() returns error? {
        return;
    }

    public isolated function gracefulStop() returns error? {
        return;
    }

    public isolated function immediateStop() returns error? {
        return;
    }

    public isolated function attach(CustomService s, string[]|string? name = ()) returns error? {
        return;
    }

    public isolated function detach(CustomService s) returns error? {
        return;
    }
}

listener CustomListener customListener = check new;
listener smb:Listener remoteServer = check new ({share: "testshare"});

// Violates every SMB constraint, but is not attached to an SMB listener.
service "NotAnSmbService" on customListener {

    remote function onSomethingWeird(int value) returns int {
        return value;
    }

    remote function onFileText(int content, string caller) returns int {
        return content;
    }

    resource function get files() returns string {
        return "files";
    }
}

// Present only to prove the SMB compiler plugin is actually engaged for this package.
service "SmbService" on remoteServer {

    remote function onFileText(string content) returns error? {
        return;
    }
}
