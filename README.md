# Ballerina Smb connector

[![Build](https://github.com/ballerina-platform/module-ballerina-smb/actions/workflows/ci.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-smb/actions/workflows/ci.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerina-smb.svg)](https://github.com/ballerina-platform/module-ballerina-smb/commits/master)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/smb.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module%smb)

## Overview

This module provides an SMB client and an SMB server listener implementation to facilitate connections to remote SMB (Server Message Block) file shares. SMB is a network file sharing protocol that allows applications to read and write to files and request services from server programs in a computer network.

The module supports SMB protocol versions `2.0.2` through `3.1.1`, with features including NTLMv2 authentication, Kerberos authentication, message signing, and data encryption.

### SMB client

The `smb:Client` connects to an SMB server and performs various operations on files and directories. It supports the following operations: `get`, `delete`, `put`, `patch`, `mkdir`, `rmdir`, `isDirectory`, `rename`, `move`, `copy`, `size`, `exists`, and `list`. The client also provides typed data operations for reading and writing files as text, JSON, XML, CSV, and binary data, with streaming support for handling large files efficiently.

An SMB client is defined using the `host` and `share` parameters and optionally, the `port` and `auth`. Authentication configuration can be configured using the `auth` parameter for NTLM credentials or Kerberos authentication.

#### Create a client

The following code creates an SMB client and performs I/O operations, connecting to the SMB server with NTLM authentication.

```ballerina
smb:ClientConfiguration smbConfig = {
    host: "<The SMB host>",
    port: <The SMB port>,
    share: "<The SMB share name>",
    auth: {
        credentials: {
            username: "<The SMB username>",
            password: "<The SMB password>",
            domain: "<The SMB domain>"
        }
    }
};

// Create the SMB client.
smb:Client|smb:Error smbClient = new(smbConfig);
```

##### Create a client with Kerberos authentication

The following code creates an SMB client using Kerberos authentication.

```ballerina
smb:ClientConfiguration smbConfig = {
    host: "<The SMB host>",
    share: "<The SMB share name>",
    auth: {
        kerberosConfig: {
            principal: "user@REALM.COM",
            realm: "REALM.COM",
            keytab: "/path/to/user.keytab",
            configFile: "/path/to/krb5.conf"
        }
    }
};

smb:Client smbClient = check new(smbConfig);
```

##### Create a directory

The following code creates a directory in the remote SMB share.

```ballerina
smb:Error? mkdirResponse = smbClient->mkdir("<The directory path>");
```

##### Upload a file to a remote server

The following code uploads a file to a remote SMB share.

```ballerina
byte[] fileContent = check io:fileReadBytes(putFilePath);
smb:Error? putResponse = smbClient->put("<The resource path>", fileContent);
```

You can also upload files as specific types:

**Upload as text:**

```ballerina
smb:Error? result = smbClient->putText("<The file path>", "Hello, World!");
```

**Upload as JSON or record:**

```ballerina
json jsonData = {name: "John", age: 30};
smb:Error? result = smbClient->putJson("<The file path>", jsonData);

type User record {
    string name;
    int age;
};

User user = {name: "Jane", age: 25};
smb:Error? result = smbClient->putJson("<The file path>", user);
```

**Upload as XML:**

```ballerina
xml xmlData = xml `<config><database>mydb</database></config>`;
smb:Error? result = smbClient->putXml("<The file path>", xmlData);
```

**Upload as CSV (string arrays or typed records):**

```ballerina
string[][] csvData = [["Name", "Age"], ["John", "30"], ["Jane", "25"]];
smb:Error? result = smbClient->putCsv("<The file path>", csvData);

type Person record {
    string name;
    int age;
};

Person[] people = [{name: "John", age: 30}, {name: "Jane", age: 25}];
smb:Error? result = smbClient->putCsv("<The file path>", people);
```

**Upload as bytes:**

```ballerina
byte[] binaryData = [0x48, 0x65, 0x6C, 0x6C, 0x6F]; // "Hello"
smb:Error? result = smbClient->putBytes("<The file path>", binaryData);
```

##### Write at a specific offset

The following code writes content at a specific offset in a file without overwriting the entire file.

```ballerina
byte[] patchContent = "patched content".toBytes();
smb:Error? patchResponse = smbClient->patch("<The file path>", patchContent, <offset>);
```

##### Get the size of a remote file

The following code gets the size of a file in a remote SMB share.

```ballerina
int|smb:Error sizeResponse = smbClient->size("<The resource path>");
```

##### Check if a file exists

The following code checks if a file or directory exists in the remote SMB share.

```ballerina
boolean|smb:Error existsResponse = smbClient->exists("<The resource path>");
```

##### Read the content of a remote file

The following code reads the content of a file in a remote SMB share. The SMB client supports various data types including text, JSON, XML, CSV, and binary data through typed get operations.

```ballerina
string fileContent = check smbClient->getText("<The file path>");
```

**Read as JSON or typed record:**

```ballerina
// Read as JSON
json jsonData = check smbClient->getJson("<The file path>");

// Read as a specific record type
type User record {
    string name;
    int age;
};

User userData = check smbClient->getJson("<The file path>");
```

**Read as XML or typed record:**

```ballerina
xml xmlData = check smbClient->getXml("<The file path>");

type Config record {
    string database;
    int timeout;
};

Config config = check smbClient->getXml("<The file path>");
```

**Read as CSV (string arrays or typed records):**

```ballerina
string[][] csvData = check smbClient->getCsv("<The file path>");

type CsvRecord record {
    string id;
    string name;
    string email;
};

CsvRecord[] records = check smbClient->getCsv("<The file path>");
```

**Read as bytes:**

```ballerina
byte[] fileBytes = check smbClient->getBytes("<The file path>");

stream<byte[], error?> byteStream = check smbClient->getBytesAsStream("<The file path>");
record {|byte[] value;|}? nextBytes = check byteStream.next();
check byteStream.close();
```

##### Rename/move a remote file

The following code renames or moves a file to another location in the same remote SMB share.

```ballerina
smb:Error? renameResponse = smbClient->rename("<The source file path>",
    "<The destination file path>");
```

##### Copy a remote file

The following code copies a file to another location in the same remote SMB share.

```ballerina
smb:Error? copyResponse = smbClient->copy("<The source file path>",
    "<The destination file path>");
```

##### Delete a remote file

The following code deletes a remote file in a remote SMB share.

```ballerina
smb:Error? deleteResponse = smbClient->delete("<The resource path>");
```

##### Remove a directory from a remote server

The following code removes a directory in a remote SMB share.

```ballerina
smb:Error? rmdirResponse = smbClient->rmdir("<The directory path>");
```

##### List files in a directory

The following code lists files and directories in a remote SMB share.

```ballerina
smb:FileInfo[]|smb:Error listResponse = smbClient->list("<The directory path>");
```

### SMB listener

The `smb:Listener` is used to listen to a remote SMB share location and trigger events when new files are added to or deleted from the directory. The listener supports both a generic `onFileChange` handler for file system events and format-specific content handlers (`onFileText`, `onFileJson`, `onFileXml`, `onFileCsv`, `onFile`) that automatically deserialize file content based on the file type.

An SMB listener is defined using the mandatory `host`, `share`, and `path` parameters. The authentication configuration can be done using the `auth` parameter and the polling interval can be configured using the `pollingInterval` parameter. The default polling interval is 60 seconds.

The `fileNamePattern` parameter can be used to define the type of files the SMB listener will listen to. For instance, if the listener gets invoked for text files, the value `(.*).txt` can be given for the config.

#### Create a listener

The SMB Listener can be used to listen to a remote directory. It will keep listening to the specified directory and notify on file addition and deletion periodically.

```ballerina
listener smb:Listener remoteServer = check new({
    host: "<The SMB host>",
    port: <The SMB port>,
    share: "<The SMB share name>",
    path: "<The remote SMB directory location>",
    pollingInterval: <Polling interval>,
    auth: {
        credentials: {
            username: "<The SMB username>",
            password: "<The SMB password>",
            domain: "<The SMB domain>"
        }
    }
});
```

The SMB listener supports content handler methods that automatically deserialize file content based on the file type. The listener supports text, JSON, XML, CSV, and binary data types with automatic extension-based routing.

**Handle text files:**

```ballerina
service on remoteServer {
    remote function onFileText(string content, smb:FileInfo fileInfo) returns error? {
        log:printInfo("Text file: " + fileInfo.path);
        log:printInfo("Content: " + content);
    }
}
```

**Handle JSON files (as generic JSON or typed record):**

```ballerina
type User record {
    string name;
    int age;
    string email;
};

service on remoteServer {
    remote function onFileJson(User content, smb:FileInfo fileInfo) returns error? {
        log:printInfo("User file: " + fileInfo.path);
        log:printInfo("User name: " + content.name);
    }
}
```

**Handle XML files (as generic XML or typed record):**

```ballerina
type Config record {
    string database;
    int timeout;
    boolean debug;
};

service on remoteServer {
    remote function onFileXml(Config content, smb:FileInfo fileInfo) returns error? {
        log:printInfo("Config file: " + fileInfo.path);
        log:printInfo("Database: " + content.database);
    }
}
```

**Handle CSV files (as string arrays or typed record arrays):**

```ballerina
type CsvRecord record {
    string id;
    string name;
    string email;
};

service on remoteServer {
    remote function onFileCsv(CsvRecord[] content, smb:FileInfo fileInfo) returns error? {
        log:printInfo("CSV file: " + fileInfo.path);
        foreach CsvRecord rec in content {
            log:printInfo("Record: " + rec.id + ", " + rec.name);
        }
    }
}
```

**Handle binary files:**

```ballerina
service on remoteServer {
    remote function onFile(byte[] content, smb:FileInfo fileInfo) returns error? {
        log:printInfo("Binary file: " + fileInfo.path);
        log:printInfo("File size: " + content.length().toString());
    }
}
```

**Stream large files:**

```ballerina
service on remoteServer {
    remote function onFile(stream<byte[], error?> content, smb:FileInfo fileInfo) returns error? {
        log:printInfo("Streaming file: " + fileInfo.path);
        record {|byte[] value;|}? nextBytes = check content.next();
        while nextBytes is record {|byte[] value;|} {
            log:printInfo("Received chunk: " + nextBytes.value.length().toString() + " bytes");
            nextBytes = check content.next();
        }
        check content.close();
    }
}
```

**Stream CSV data as typed records:**

```ballerina
type DataRow record {
    string timestamp;
    string value;
};

service on remoteServer {
    remote function onFileCsv(stream<DataRow, error?> content, smb:FileInfo fileInfo) returns error? {
        log:printInfo("Streaming CSV file: " + fileInfo.path);
        record {|DataRow value;|}|error? nextRow = content.next();
        while nextRow is record {|DataRow value;|} {
            log:printInfo("Row: " + nextRow.value.timestamp + " = " + nextRow.value.value);
            nextRow = content.next();
        }
        check content.close();
    }
}
```

The SMB listener automatically routes files to the appropriate content handler based on file extension: `.txt` -> `onFileText()`, `.json` -> `onFileJson()`, `.xml` -> `onFileXml()`, `.csv` -> `onFileCsv()`, and other extensions -> `onFile()` (fallback handler). You can override the default routing using the `@smb:FunctionConfig` annotation to specify a custom file name pattern for each handler method.

### Advanced configuration options

The SMB client and listener support several advanced configuration options:

#### SMB protocol dialects

You can specify which SMB protocol versions to use:

```ballerina
smb:ClientConfiguration smbConfig = {
    host: "<The SMB host>",
    share: "<The SMB share name>",
    dialects: [smb:SMB_3_1_1, smb:SMB_3_0_2, smb:SMB_3_0]
};
```

Supported dialects: `SMB_3_1_1`, `SMB_3_0_2`, `SMB_3_0`, `SMB_2_1`, `SMB_2_0_2`

#### Message signing and encryption

Enable SMB message signing and data encryption for enhanced security:

```ballerina
smb:ClientConfiguration smbConfig = {
    host: "<The SMB host>",
    share: "<The SMB share name>",
    signRequired: true,
    encryptData: true,
    auth: {
        credentials: {
            username: "<The SMB username>",
            password: "<The SMB password>"
        }
    }
};
```

##### Distributed File System (DFS) support

Enable DFS support for accessing files across multiple servers:

```ballerina
smb:ClientConfiguration smbConfig = {
    host: "<The SMB host>",
    share: "<The SMB share name>",
    enableDfs: true
};
```

##### Buffer size and timeout configuration

Configure buffer size and connection timeout:

```ballerina
smb:ClientConfiguration smbConfig = {
    host: "<The SMB host>",
    share: "<The SMB share name>",
    bufferSize: 131072,
    connectTimeout: 60.0
};
```

## Build from the source

### Setting up the prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:

    * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
    * [OpenJDK](https://adoptium.net/)

   > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Download and install [Docker](https://www.docker.com/get-started).

   > **Note**: Ensure that the Docker daemon is running before executing any tests.

4. Export Github Personal access token with read package permissions as follows,

    ```bash
    export packageUser=<Username>
    export packagePAT=<Personal access token>
    ```

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To build the without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

4. To run tests against different environments:

   ```bash
   ./gradlew clean test -Pgroups=<Comma separated groups/test cases>
   ```

5. To debug the package with a remote debugger:

   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

6. To debug with the Ballerina language:

   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

7. Publish the generated artifacts to the local Ballerina Central repository:

    ```bash
    ./gradlew clean build -PpublishToLocalCentral=true
    ```

8. Publish the generated artifacts to the Ballerina Central repository:

   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [`smb` package](https://central.ballerina.io/ballerina/smb/latest).
* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
