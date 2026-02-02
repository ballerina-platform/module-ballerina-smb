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
import ballerina/time;

configurable string smbHost = ?;
configurable int smbPort = ?;
configurable string smbShare = ?;
configurable string smbUsername = ?;
configurable string smbPassword = ?;
configurable string smbDomain = ?;

configurable int expectedRecordCount = 5;

final string[] validContractorIds = ["CTR-001", "CTR-002", "CTR-003", "CTR-004", "CTR-005"];

type TimesheetRecord record {|
    string contractor_id;
    string date;
    string hours_worked;
    string site_code;
|};

type ValidationResult record {|
    boolean isValid;
    int totalRecords;
    int invalidContractorIds;
    string[] validationErrors;
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

@smb:ServiceConfig {
    path: "/timesheets/incoming"
}
service "timesheetValidator" on smbListener {
    remote function onFileCsv(TimesheetRecord[] content, smb:FileInfo fileInfo, smb:Caller caller) returns error? {
        log:printInfo(string `Processing timesheet file: ${fileInfo.name} with ${content.length()} records`);
        
        // Perform comprehensive validation
        ValidationResult validationResult = validateTimesheetData(content);
        
        if !validationResult.isValid {
            // Log all validation errors
            foreach string validationError in validationResult.validationErrors {
                log:printError(validationError);
            }
            
            // Determine quarantine reason
            string quarantineReason = "validation_failed";
            if validationResult.totalRecords != expectedRecordCount {
                quarantineReason = "record_count_mismatch";
            }
            
            check quarantineFile(caller, fileInfo, quarantineReason);
            return;
        }
        
        log:printInfo(string `All validations passed for ${fileInfo.name}`);
        
        // Save validated records to SMB
        string validatedPath = string `/timesheets/validated/${fileInfo.name}`;
        check smbClient->putCsv(validatedPath, <record{}[][]>[content], smb:OVERWRITE);
        log:printInfo(string `Validated ${content.length()} records saved to ${validatedPath}`);
        
        // Move original file to processed folder
        string processedPath = string `/timesheets/processed/${fileInfo.name}`;
        check caller->move(fileInfo.path, processedPath);
        log:printInfo(string `Successfully processed file: ${fileInfo.name}`);
    }

    function onError(error err) returns error? {
        log:printError(string `Error processing timesheet file: ${err.message()}`, err);
    }
}

function validateTimesheetData(TimesheetRecord[] content) returns ValidationResult {
    string[] validationErrors = [];
    int totalRecords = content.length();
    
    // Validation 1: Check record count matches expected contractor headcount
    if totalRecords != expectedRecordCount {
        validationErrors.push(string `Invalid record count. Expected ${expectedRecordCount}, got ${totalRecords}`);
    }
    
    // Validation 2: Check contractor IDs and count invalid entries
    int invalidContractorIds = 0;
    foreach TimesheetRecord rec in content {
        if validContractorIds.indexOf(rec.contractor_id) == () {
            invalidContractorIds += 1;
            validationErrors.push(string `Invalid contractor ID found: ${rec.contractor_id}`);
        }
        
        // Additional validation: Check hours_worked is a valid number
        var hoursResult = float:fromString(rec.hours_worked);
        if hoursResult is error {
            validationErrors.push(string `Invalid hours_worked value: ${rec.hours_worked} for contractor ${rec.contractor_id}`);
        } else {
            float hours = hoursResult;
            if hours < 0.0 || hours > 24.0 {
                validationErrors.push(string `Invalid hours_worked range: ${hours} for contractor ${rec.contractor_id}`);
            }
        }
    }
    
    return {
        isValid: validationErrors.length() == 0,
        totalRecords,
        invalidContractorIds,
        validationErrors
    };
}

function quarantineFile(smb:Caller caller, smb:FileInfo fileInfo, string reason) returns error? {
    time:Utc now = time:utcNow();
    string timestamp = now[0].toString();
    string quarantinePath = string `/timesheets/quarantine/${reason}_${timestamp}_${fileInfo.name}`;
    check caller->move(fileInfo.path, quarantinePath);
    log:printWarn(string `File quarantined: ${fileInfo.name} (reason: ${reason})`);
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
