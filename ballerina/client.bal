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

import ballerina/data.csv as _;
import ballerina/data.jsondata as _;
import ballerina/data.xmldata;

import ballerina/jballerina.java;

# SMB client for connecting to and managing SMB servers.
# Supports reading files in various formats (text, JSON, XML, CSV, bytes) and writing files with overwrite or append options.
public isolated client class Client {
    private final readonly & ClientConfiguration config;

    # Gets invoked during object initialization.
    #
    # + clientConfig - Configurations for SMB client
    # + return - `smb:Error` in case of errors or `()` otherwise
    public isolated function init(ClientConfiguration clientConfig) returns Error? {
        self.config = clientConfig.cloneReadOnly();
        Error? response = initEndpoint(self, self.config);
        if response is Error {
            return response;
        }
    }

    # Adds a file to an SMB share.
    # ```ballerina
    # smb:Error? response = client->put(path, channel);
    # ```
    #
    # + path - The resource path
    # + content - Content to be written to the file in server
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function put(string path, byte[] content) returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Writes byte array content to a file on an SMB share.
    # ```ballerina
    # smb:Error? response = client->putBytes(path, content, smb:OVERWRITE);
    # ```
    #
    # + path - The resource path
    # + content - Byte array content to write
    # + option - File write option (OVERWRITE or APPEND)
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function putBytes(string path, byte[] content, FileWriteOption option = OVERWRITE)
            returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Patches a file by writing byte array content at a specified offset on an SMB share.
    # This allows writing to an arbitrary position in a file without overwriting
    # the entire file or appending to the end.
    # ```ballerina
    # smb:Error? response = client->patch(path, content, 100);
    # ```
    #
    # + path - The resource path
    # + content - Byte array content to write
    # + offset - The byte offset position in the file where writing should start
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function patch(string path, byte[] content, int offset)
            returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Writes text content to a file on an SMB share.
    # ```ballerina
    # smb:Error? response = client->putText(path, "Hello World", smb:OVERWRITE);
    # ```
    #
    # + path - The resource path
    # + content - Text content to write
    # + option - File write option (OVERWRITE or APPEND)
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function putText(string path, string content, FileWriteOption option = OVERWRITE)
            returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Writes JSON content to a file on an SMB share.
    # ```ballerina
    # json data = {name: "John", age: 30};
    # smb:Error? response = client->putJson(path, data, smb:OVERWRITE);
    # ```
    #
    # + path - The resource path
    # + content - JSON content to write
    # + option - File write option (OVERWRITE or APPEND)
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function putJson(string path, json|record {} content, FileWriteOption option = OVERWRITE)
            returns Error? {
        return self->putText(path, content.toString(), option);
    }

    # Writes XML content to a file on an SMB share.
    # ```ballerina
    # xml data = xml `<person><name>John</name></person>`;
    # smb:Error? response = client->putXml(path, data, smb:OVERWRITE);
    # ```
    #
    # + path - The resource path
    # + content - XML content to write
    # + option - File write option (OVERWRITE or APPEND)
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function putXml(string path, xml|record {} content, FileWriteOption option = OVERWRITE)
            returns Error? {
        string xmlString;
        if content is xml {
            xmlString = content.toString();
        } else {
            xml|error xmlContent = xmldata:toXml(content);
            if xmlContent is error {
                return error Error(xmlContent.message());
            }
            xmlString = xmlContent.toString();
        }
        return self.putXmlNative(path, xmlString, option);
    }

    private isolated function putXmlNative(string path, string content, FileWriteOption option = OVERWRITE)
            returns Error? = @java:Method {
        name: "putXml",
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Writes CSV content to a file on an SMB share.
    # Supports both array-of-arrays (string[][]) and array-of-records formats.
    # When not appending, automatically adds headers for record arrays.
    # ```ballerina
    # string[][] csvData = [["name", "age"], ["John", "30"], ["Jane", "25"]];
    # smb:Error? response = client->putCsv(path, csvData, smb:OVERWRITE);
    # ```
    #
    # + path - The resource path
    # + content - CSV content as array of arrays or array of records
    # + option - File write option (OVERWRITE or APPEND)
    # + return - `()` or else an `smb:Error` if the operation fails
    remote isolated function putCsv(string path, string[][]|record {}[][] content,
            FileWriteOption option = OVERWRITE) returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Reads a file from an SMB share as a byte array.
    # ```ballerina
    # byte[]|smb:Error content = client->getBytes(path);
    # ```
    #
    # + path - The resource path
    # + return - File content as byte array or an `smb:Error` if the operation fails
    remote isolated function getBytes(string path) returns byte[]|Error = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Reads a file from an SMB share as text.
    # ```ballerina
    # string|smb:Error content = client->getText(path);
    # ```
    #
    # + path - The resource path
    # + return - File content as string or an `smb:Error` if the operation fails
    remote isolated function getText(string path) returns string|Error = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Reads a file from an SMB share and parses it as JSON.
    # Supports type binding to records and other Ballerina types.
    # ```ballerina
    # json|smb:Error content = client->getJson(path);
    # type Person record {| string name; int age; |};
    # Person|smb:Error person = client->getJson(path);
    # ```
    #
    # + path - The resource path
    # + targetType - The type descriptor of the target type (default: json)
    # + return - JSON content as the target type or an `smb:Error` if the operation fails
    remote isolated function getJson(string path, typedesc<json> targetType = <>)
            returns targetType|Error = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Reads a file from an SMB share and parses it as XML.
    # Supports type binding to records and other Ballerina types.
    # ```ballerina
    # xml|smb:Error content = client->getXml(path);
    # type Book record {| string title; string author; |};
    # Book|smb:Error book = client->getXml(path);
    # ```
    #
    # + path - The resource path
    # + targetType - The type descriptor of the target type (default: xml)
    # + return - XML content as the target type or an `smb:Error` if the operation fails
    remote isolated function getXml(string path, typedesc<xml> targetType = <>)
            returns targetType|Error = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Reads a file from an SMB share and parses it as CSV.
    # Supports parsing to string arrays or record arrays with type binding.
    # ```ballerina
    # string[][]|smb:Error content = client->getCsv(path);
    # type Person record {| string name; int age; string city; |};
    # Person[]|smb:Error people = client->getCsv(path);
    # ```
    #
    # + path - The resource path
    # + targetType - The type descriptor of the target type (default: string[][])
    # + return - CSV content as the target type or an `smb:Error` if the operation fails
    remote isolated function getCsv(string path, typedesc<anydata[][]> targetType = <>)
            returns targetType|Error = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Retrieves the file content as a byte stream from an SMB share.
    # ```ballerina
    # stream<byte[], error?> response = check client->getBytesAsStream(path);
    # ```
    #
    # + path - The path to the file on the SMB server
    # + return - A stream of byte arrays from which the file can be read or `smb:Error` in case of errors
    remote isolated function getBytesAsStream(string path) returns stream<byte[], error?>|Error = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Retrieves the file content as a CSV stream from an SMB share.
    # ```ballerina
    # stream<string[], error?> response = check client->getCsvAsStream(path);
    # ```
    #
    # + path - The path to the file on the SMB server
    # + targetType - Expected element type (to be used for automatic data binding).
    #                Supported types:
    #                - Built-in types: `string[]` - Array of strings representing CSV columns
    #                - Custom types: (e.g., `User`, `Student?`, `Person[]`, etc.)
    # + return - A stream from which the file can be read or `smb:Error` in case of errors
    remote isolated function getCsvAsStream(string path, typedesc<string[]|record {}> targetType = <>)
            returns stream<targetType, error?>|Error = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Lists files and directories in a folder on an SMB share.
    # ```ballerina
    # smb:FileInfo[]|smb:Error response = client->list(path);
    # ```
    #
    # + path - The directory path
    # + return - An array of FileInfo records or an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function list(string path) returns FileInfo[]|Error = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;


    # Creates a new directory on an SMB share.
    # ```ballerina
    # smb:Error? response = client->mkdir(path);
    # ```
    #
    # + path - The directory path
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function mkdir(string path) returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Deletes an empty directory on an SMB share.
    # ```ballerina
    # smb:Error? response = client->rmdir(path);
    # ```
    #
    # + path - The directory path
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function rmdir(string path) returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Renames a file or directory on an SMB share or moves it to a new location.
    # ```ballerina
    # smb:Error? response = client->rename(origin, destination);
    # ```
    #
    # + origin - The source file location
    # + destination - The destination file location
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function rename(string origin, string destination) returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Moves a file from one location to another on an SMB share.
    # ```ballerina
    # smb:Error? response = client->move(sourcePath, destinationPath);
    # ```
    #
    # + sourcePath - The source file location
    # + destinationPath - The destination file location
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function move(string sourcePath, string destinationPath) returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Copies a file from one location to another on an SMB share.
    # ```ballerina
    # smb:Error? response = client->copy(sourcePath, destinationPath);
    # ```
    #
    # + sourcePath - The source file location
    # + destinationPath - The destination file location
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function copy(string sourcePath, string destinationPath) returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Checks if a file or directory exists on an SMB share.
    # ```ballerina
    # boolean|smb:Error response = client->exists(path);
    # ```
    #
    # + path - The resource path
    # + return - `true` if the file or directory exists, `false` otherwise, or an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function exists(string path) returns boolean|Error = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Gets the size of a file on an SMB share.
    # ```ballerina
    # int|smb:Error response = client->size(path);
    # ```
    #
    # + path - The resource path
    # + return - The file size in bytes or an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function size(string path) returns int|Error = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Checks if a given resource is a directory on an SMB share.
    # ```ballerina
    # boolean|smb:Error response = client->isDirectory(path);
    # ```
    #
    # + path - The resource path
    # + return - `true` if the resource is a directory, `false` otherwise, or an `smb:Error` if the check fails
    remote isolated function isDirectory(string path) returns boolean|Error = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Deletes a file from an SMB share.
    # ```ballerina
    # smb:Error? response = client->delete(path);
    # ```
    #
    # + path - The resource path
    # + return - `()` or else an `smb:Error` if failed to establish the communication with the SMB server
    remote isolated function delete(string path) returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;

    # Closes the SMB client connection.
    # ```ballerina
    # smb:Error? response = client->close();
    # ```
    #
    # + return - `()` or else an `smb:Error` if failed to close the connection
    remote isolated function close() returns Error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.client.SmbClient"
    } external;
}

isolated function initEndpoint(Client clientEndpoint, map<anydata> config) returns Error? = @java:Method {
    name: "initClientEndpoint",
    'class: "io.ballerina.stdlib.smb.client.SmbClient"
} external;
