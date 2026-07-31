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

listener smb:Listener remoteServer = check new ({share: "testshare"});

// A Ballerina quoted identifier carries an apostrophe, which MessageFormat also treats as
// special. Interpolating this signature into a diagnostic must not drop characters or abort.
// Expected: INVALID_CONTENT_PARAMETER_TYPE, INVALID_OPTIONAL_PARAMETER
service "QuotedIdentifierService" on remoteServer {

    remote function onFileText(record {| int 'limit; |} content) returns error? {
        return;
    }

    remote function onFileJson(json content, record {| string 'from; |} other) returns error? {
        return;
    }
}
