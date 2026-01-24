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

# SMB caller for interacting with SMB servers from within file handlers.
# Provides the same file operations as the Client class.
public isolated client class Caller {
    private final Client 'client;

    # Gets invoked during object initialization.
    #
    # + 'client - The `smb:Client` which is used to interact with the SMB server
    isolated function init(Client 'client) {
        self.'client = 'client;
    }

    # Adds a file to an SMB share.
    # ```ballerina
    # smb:Error? response = caller->put(path, content);
    # ```
    #
    # + path - The resource path
    # + content - Content to be written to the file in server
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function put(string path, byte[] content) returns Error? {
        return self.'client->put(path, content);
    }

    # Writes byte array content to a file on an SMB share.
    # ```ballerina
    # smb:Error? response = caller->putBytes(path, content, smb:OVERWRITE);
    # ```
    #
    # + path - The resource path
    # + content - Byte array content to write
    # + option - File write option (OVERWRITE or APPEND)
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function putBytes(string path, byte[] content, FileWriteOption option = OVERWRITE)
            returns Error? {
        return self.'client->putBytes(path, content, option);
    }

    # Patches a file by writing byte array content at a specified offset on an SMB share.
    # This allows writing to an arbitrary position in a file without overwriting
    # the entire file or appending to the end.
    # ```ballerina
    # smb:Error? response = caller->patch(path, content, 100);
    # ```
    #
    # + path - The resource path
    # + content - Byte array content to write
    # + offset - The byte offset position in the file where writing should start
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function patch(string path, byte[] content, int offset) returns Error? {
        return self.'client->patch(path, content, offset);
    }

    # Writes text content to a file on an SMB share.
    # ```ballerina
    # smb:Error? response = caller->putText(path, "Hello World", smb:OVERWRITE);
    # ```
    #
    # + path - The resource path
    # + content - Text content to write
    # + option - File write option (OVERWRITE or APPEND)
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function putText(string path, string content, FileWriteOption option = OVERWRITE)
            returns Error? {
        return self.'client->putText(path, content, option);
    }

    # Writes JSON content to a file on an SMB share.
    # ```ballerina
    # json data = {name: "John", age: 30};
    # smb:Error? response = caller->putJson(path, data, smb:OVERWRITE);
    # ```
    #
    # + path - The resource path
    # + content - JSON content to write
    # + option - File write option (OVERWRITE or APPEND)
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function putJson(string path, json content, FileWriteOption option = OVERWRITE)
            returns Error? {
        return self.'client->putJson(path, content, option);
    }

    # Writes XML content to a file on an SMB share.
    # ```ballerina
    # xml data = xml `<person><name>John</name></person>`;
    # smb:Error? response = caller->putXml(path, data, smb:OVERWRITE);
    # ```
    #
    # + path - The resource path
    # + content - XML content to write
    # + option - File write option (OVERWRITE or APPEND)
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function putXml(string path, xml content, FileWriteOption option = OVERWRITE)
            returns Error? {
        return self.'client->putXml(path, content, option);
    }

    # Writes CSV content to a file on an SMB share.
    # Supports both array-of-arrays (string[][]) and array-of-records formats.
    # When not appending, automatically adds headers for record arrays.
    # ```ballerina
    # string[][] csvData = [["name", "age"], ["John", "30"], ["Jane", "25"]];
    # smb:Error? response = caller->putCsv(path, csvData, smb:OVERWRITE);
    # ```
    #
    # + path - The resource path
    # + content - CSV content as array of arrays or array of records
    # + option - File write option (OVERWRITE or APPEND)
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function putCsv(string path, string[][]|record {}[][] content,
            FileWriteOption option = OVERWRITE) returns Error? {
        return self.'client->putCsv(path, content, option);
    }

    # Reads a file from an SMB share as a byte array.
    # ```ballerina
    # byte[]|smb:Error content = caller->getBytes(path);
    # ```
    #
    # + path - The resource path
    # + return - File content as byte array or an `smb:Error` if the operation fails
    remote isolated function getBytes(string path) returns byte[]|Error {
        return self.'client->getBytes(path);
    }

    # Reads a file from an SMB share as text.
    # ```ballerina
    # string|smb:Error content = caller->getText(path);
    # ```
    #
    # + path - The resource path
    # + return - File content as string or an `smb:Error` if the operation fails
    remote isolated function getText(string path) returns string|Error {
        return self.'client->getText(path);
    }

    # Reads a file from an SMB share and parses it as JSON.
    # ```ballerina
    # json|smb:Error content = caller->getJson(path);
    # ```
    #
    # + path - The resource path
    # + return - JSON content or an `smb:Error` if the operation fails
    remote isolated function getJson(string path) returns json|Error {
        return self.'client->getJson(path);
    }

    # Reads a file from an SMB share and parses it as XML.
    # ```ballerina
    # xml|smb:Error content = caller->getXml(path);
    # ```
    #
    # + path - The resource path
    # + return - XML content or an `smb:Error` if the operation fails
    remote isolated function getXml(string path) returns xml|Error {
        return self.'client->getXml(path);
    }

    # Reads a file from an SMB share and parses it as CSV.
    # ```ballerina
    # string[][]|smb:Error content = caller->getCsv(path);
    # ```
    #
    # + path - The resource path
    # + return - CSV content as string[][] or an `smb:Error` if the operation fails
    remote isolated function getCsv(string path) returns string[][]|Error {
        return self.'client->getCsv(path);
    }

    # Retrieves the file content as a byte stream from an SMB share.
    # ```ballerina
    # stream<byte[], error?> response = check caller->getBytesAsStream(path);
    # ```
    #
    # + path - The path to the file on the SMB server
    # + return - A stream of byte arrays from which the file can be read or `smb:Error` in case of errors
    remote isolated function getBytesAsStream(string path) returns stream<byte[], error?>|Error {
        return self.'client->getBytesAsStream(path);
    }

    # Retrieves the file content as a CSV stream from an SMB share.
    # ```ballerina
    # stream<string[], error?> response = check caller->getCsvAsStream(path);
    # ```
    #
    # + path - The path to the file on the SMB server
    # + return - A stream of string arrays from which the file can be read or `smb:Error` in case of errors
    remote isolated function getCsvAsStream(string path) returns stream<string[], error?>|Error {
        return self.'client->getCsvAsStream(path);
    }

    # Lists files and directories in a folder on an SMB share.
    # ```ballerina
    # smb:FileInfo[]|smb:Error response = caller->list(path);
    # ```
    #
    # + path - The directory path
    # + return - An array of FileInfo records or an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function list(string path) returns FileInfo[]|Error {
        return self.'client->list(path);
    }

    # Creates a new directory on an SMB share.
    # ```ballerina
    # smb:Error? response = caller->mkdir(path);
    # ```
    #
    # + path - The directory path
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function mkdir(string path) returns Error? {
        return self.'client->mkdir(path);
    }

    # Deletes an empty directory on an SMB share.
    # ```ballerina
    # smb:Error? response = caller->rmdir(path);
    # ```
    #
    # + path - The directory path
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function rmdir(string path) returns Error? {
        return self.'client->rmdir(path);
    }

    # Renames a file or directory on an SMB share or moves it to a new location.
    # ```ballerina
    # smb:Error? response = caller->rename(origin, destination);
    # ```
    #
    # + origin - The source file location
    # + destination - The destination file location
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function rename(string origin, string destination) returns Error? {
        return self.'client->rename(origin, destination);
    }

    # Moves a file from one location to another on an SMB share.
    # ```ballerina
    # smb:Error? response = caller->move(sourcePath, destinationPath);
    # ```
    #
    # + sourcePath - The source file location
    # + destinationPath - The destination file location
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function move(string sourcePath, string destinationPath) returns Error? {
        return self.'client->move(sourcePath, destinationPath);
    }

    # Copies a file from one location to another on an SMB share.
    # ```ballerina
    # smb:Error? response = caller->copy(sourcePath, destinationPath);
    # ```
    #
    # + sourcePath - The source file location
    # + destinationPath - The destination file location
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function copy(string sourcePath, string destinationPath) returns Error? {
        return self.'client->copy(sourcePath, destinationPath);
    }

    # Checks if a file or directory exists on an SMB share.
    # ```ballerina
    # boolean|smb:Error response = caller->exists(path);
    # ```
    #
    # + path - The resource path
    # + return - `true` if the file or directory exists, `false` otherwise, or an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function exists(string path) returns boolean|Error {
        return self.'client->exists(path);
    }

    # Gets the size of a file on an SMB share.
    # ```ballerina
    # int|smb:Error response = caller->size(path);
    # ```
    #
    # + path - The resource path
    # + return - The file size in bytes or an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function size(string path) returns int|Error {
        return self.'client->size(path);
    }

    # Checks if a given resource is a directory on an SMB share.
    # ```ballerina
    # boolean|smb:Error response = caller->isDirectory(path);
    # ```
    #
    # + path - The resource path
    # + return - `true` if the resource is a directory, `false` otherwise, or an `smb:Error` if the check fails
    remote isolated function isDirectory(string path) returns boolean|Error {
        return self.'client->isDirectory(path);
    }

    # Deletes a file from an SMB share.
    # ```ballerina
    # smb:Error? response = caller->delete(path);
    # ```
    #
    # + path - The resource path
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function delete(string path) returns Error? {
        return self.'client->delete(path);
    }

    # Closes the SMB client connection.
    # ```ballerina
    # smb:Error? response = caller->close();
    # ```
    #
    # + return - `()` or else an `smb:Error` if failed to close the connection
    remote isolated function close() returns Error? {
        return self.'client->close();
    }
}
