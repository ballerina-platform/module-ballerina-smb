## Overview

This module provides an SMB client and an SMB server listener implementation to facilitate connections to remote SMB (Server Message Block) file shares. SMB is a network file sharing protocol that allows applications to read and write to files and request services from server programs in a computer network.

The module supports SMB protocol versions `2.0.2` through `3.1.1`, with features including NTLMv2 authentication, Kerberos authentication, message signing, and data encryption.

### SMB client

The `smb:Client` connects to an SMB server and performs various operations on files and directories. It supports the following operations: `get`, `delete`, `patch`, `mkdir`, `rmdir`, `isDirectory`, `rename`, `move`, `copy`, `size`, `exists`, and `list`. The client also provides typed data operations for reading and writing files as text, JSON, XML, CSV, and binary data, with streaming support for handling large files efficiently.

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
            principal: "<user@REALM.COM>",
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
smb:Error? result = smbClient->putText("<The file path>", "Hello, World!");
```

You can use the following methods to upload files with specific types.

- `putText`
- `putJson`
- `putXml`
- `putCsv`
- `putBytes`

##### Retrieve files from remote server

The following code retrieves a file from a remote SMB share as text.

```ballerina
string|smb:Error content = smbClient->getText("<The file path>");
```

You can use the following methods to retrieve files with specific types.

- `getText`
- `getJson`
- `getXml`
- `getCsv`
- `getBytes`

##### Delete a remote file

The following code deletes a remote file in a remote SMB share.

```ballerina
smb:Error? deleteResponse = smbClient->delete("<The resource path>");
```

### SMB listener

The `smb:Listener` is used to listen to a remote SMB share location and trigger events when new files are added to or deleted from the directory. The listener supports both a generic `onFile` handler for file system events and format-specific content handlers (`onFileText`, `onFileJson`, `onFileXml`, `onFileCsv`, `onFile`) that automatically deserialize file content based on the file type.

An SMB listener is defined using the mandatory `host` and `share` parameters. The authentication configuration can be done using the `auth` parameter and the polling interval can be configured using the `pollingInterval` parameter. The default polling interval is 60 seconds.

The `fileNamePattern` parameter can be used to define the type of files the SMB listener will listen to. For instance, if the listener gets invoked for text files, the value `(.*).txt` can be given for the config.

The directory path within the SMB share is configured using the `@smb:ServiceConfig` annotation on the service.

#### Create a listener

The SMB Listener can be used to listen to a remote directory. It will keep listening to the specified directory and notify on file addition and deletion periodically.

```ballerina
listener smb:Listener remoteServer = check new({
    host: "<The SMB host>",
    port: <The SMB port>,
    share: "<The SMB share name>",
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
@smb:ServiceConfig {
    path: "<The remote SMB directory location>"
}
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
