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

import ballerina/log;
import ballerina/smb;

configurable string smbHost = ?;
configurable int smbPort = 445;
configurable string smbShare = ?;
configurable string smbUsername = ?;
configurable string smbPassword = ?;
configurable string smbDomain = "WORKGROUP";

type SaleItem record {|
    string itemId;
    int quantity;
    decimal totalAmount;
|};

type SalesReport record {|
    string storeId;
    string storeLocation;
    string saleDate;
    SaleItem[] items;
|};

type SalesRecord record {|
    string storeId;
    string storeLocation;
    string saleDate;
    string itemId;
    int quantity;
    decimal totalAmount;
|};

listener smb:Listener smbListener = check new ({
    host: smbHost,
    port: smbPort,
    share: smbShare,
    auth: {
        credentials: {
            username: smbUsername,
            password: smbPassword,
            domain: smbDomain
        }
    },
    pollingInterval: 10
});

final smb:Client smbClient = check new ({
    host: smbHost,
    port: smbPort,
    share: smbShare,
    auth: {
        credentials: {
            username: smbUsername,
            password: smbPassword,
            domain: smbDomain
        }
    }
});

function init() returns error? {
    check ensureDirectoryExists("/sales");
    check ensureDirectoryExists("/sales/new");
    check ensureDirectoryExists("/sales/processed");
    check ensureDirectoryExists("/sales/data");
    log:printInfo("Initialized sales directories on SMB share");
}

@smb:ServiceConfig {
    path: "/sales/new"
}
service "salesReportProcessor" on smbListener {
    remote function onFileJson(SalesReport content, smb:Caller caller, smb:FileInfo fileInfo) returns error? {
        log:printInfo(string `Processing sales report: ${fileInfo.name}`);
        log:printInfo(string `Store: ${content.storeId}, Location: ${content.storeLocation}, Date: ${content.saleDate}`);

        // Transform sales items into flat records for CSV storage
        SalesRecord[] salesRecords = from SaleItem item in content.items
            select {
                storeId: content.storeId,
                storeLocation: content.storeLocation,
                saleDate: content.saleDate,
                itemId: item.itemId,
                quantity: item.quantity,
                totalAmount: item.totalAmount
            };

        // Persist sales records to CSV file
        string csvPath = "/sales/data/sales_data.json";
        check ensureDirectoryExists("/sales/data");
        check caller->putJson(csvPath, salesRecords, smb:APPEND);
        log:printInfo(string `Added ${salesRecords.length()} sales records to ${csvPath}`);
        check ensureDirectoryExists("/sales/processed");
        string destinationPath = string `/sales/processed/${fileInfo.name}`;
        check caller->move(fileInfo.path, destinationPath);
        log:printInfo(string `File moved to processed: ${fileInfo.name}`);
    }

    function onError(error err) returns error? {
        log:printError(string `Error processing file: ${err.message()}`, err);
    }
}

function ensureDirectoryExists(string path) returns error? {
    boolean|smb:Error exists = smbClient->exists(path);
    if exists is smb:Error {
        return exists;
    }
    if !exists {
        check smbClient->mkdir(path);
    }
}
