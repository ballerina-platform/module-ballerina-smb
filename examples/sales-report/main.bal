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
configurable string smbDomain = ?;

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

@smb:ServiceConfig {
    path: "/sales/new"
}
service "salesReportProcessor" on smbListener {

    @smb:FunctionConfig {
        afterProcess: {
            moveTo: "/sales/processed"
        },
        afterError: {
            moveTo: "/sales/error"
        }
    }
    remote function onFileJson(SalesReport content, smb:FileInfo fileInfo, smb:Caller caller) returns error? {
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
        string csvPath = "/sales/data/sales_data.csv";
        check caller->putCsv(csvPath, salesRecords, smb:APPEND);
        log:printInfo(string `Added ${salesRecords.length()} sales records to ${csvPath}`);
    }

    remote function onError(error err) returns error? {
        log:printError(string `Error processing file: ${err.message()}`, err);
    }
}

