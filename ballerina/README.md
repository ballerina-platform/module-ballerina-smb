## Overview

This module provides an SMB client and an SMB listener for working with files on remote SMB (Server Message Block) file shares — the protocol behind Windows file servers, NAS appliances, and Samba.

The module supports SMB dialects `2.0.2` through `3.1.1`, NTLMv2 and Kerberos authentication, message signing, and data encryption.

| Component | Purpose |
| --- | --- |
| `smb:Client` | Connect to a share and read, write, move, copy, and list files. |
| `smb:Listener` | Poll a directory on a share and dispatch each added or deleted file to a service. |
| `smb:Caller` | The share connection made available to a service, so a handler can act on the share while processing a file. |

All paths are relative to the configured share.

## Quickstart

To use the `smb` module in your Ballerina application, follow the steps below.

### Step 1: Import the module

```ballerina
import ballerina/smb;
```

### Step 2: Read and write files with a client

```ballerina
import ballerina/io;
import ballerina/smb;

smb:Client smbClient = check new ({
    host: "smb.example.com",
    share: "reports",
    auth: {
        credentials: {
            username: "alice",
            password: "***",
            domain: "WORKGROUP"
        }
    }
});

public function main() returns error? {
    check smbClient->putText("/daily/summary.txt", "All systems nominal");

    string content = check smbClient->getText("/daily/summary.txt");
    io:println(content);

    smb:FileInfo[] files = check smbClient->list("/daily");
    io:println(string `${files.length()} entries in /daily`);
}
```

### Step 3: Handle incoming files with a listener

The listener polls a directory and calls a handler for every file it finds. The handler that runs, and the type the content is bound to, depend on the file extension.

```ballerina
import ballerina/log;
import ballerina/smb;

listener smb:Listener smbListener = check new ({
    host: "smb.example.com",
    share: "reports",
    pollingInterval: 10,
    auth: {
        credentials: {
            username: "alice",
            password: "***"
        }
    }
});

type SalesReport record {|
    string storeId;
    decimal total;
|};

@smb:ServiceConfig {
    path: "/sales/new"
}
service "salesProcessor" on smbListener {

    @smb:FunctionConfig {
        afterProcess: {moveTo: "/sales/processed"}
    }
    remote function onFileJson(SalesReport report, smb:FileInfo fileInfo) returns error? {
        log:printInfo(string `Store ${report.storeId} reported ${report.total}`);
    }

    remote function onError(error err) returns error? {
        log:printError("Failed to process the file", err);
    }
}
```

### Step 4: Run the service

```bash
bal run
```

## SMB client

An `smb:Client` is created with an `smb:ClientConfiguration` record. `host` and `share` identify the target; everything else has a default.

```ballerina
smb:Client smbClient = check new ({
    host: "smb.example.com",
    port: 445,
    share: "reports",
    auth: {
        credentials: {username: "alice", password: "***", domain: "WORKGROUP"}
    },
    dialects: [smb:SMB_3_1_1, smb:SMB_3_0_2],
    signRequired: true,
    encryptData: true,
    enableDfs: false,
    bufferSize: 65536,
    connectTimeout: 30.0
});
```

To authenticate with Kerberos, provide `kerberosConfig` instead of `credentials`:

```ballerina
smb:Client smbClient = check new ({
    host: "smb.example.com",
    share: "reports",
    auth: {
        kerberosConfig: {
            principal: "alice@EXAMPLE.COM",
            keytab: "/path/to/alice.keytab",
            configFile: "/etc/krb5.conf"
        }
    }
});
```

The client exposes one operation per content type, so no manual parsing is needed:

| Operation | Reads/writes |
| --- | --- |
| `getText` / `putText` | `string` |
| `getJson` / `putJson` | `json` or a record type |
| `getXml` / `putXml` | `xml` or a record type |
| `getCsv` / `putCsv` | `string[][]` or a record array |
| `getBytes` / `putBytes` | `byte[]` |
| `getBytesAsStream` | `stream<byte[], error?>` — for files too large to hold in memory |
| `getCsvAsStream` | `stream<string[], error?>` or a stream of records |
| `patch` | `byte[]` written at a byte offset, without rewriting the whole file |

Every `put*` operation takes an optional `smb:OVERWRITE` (default) or `smb:APPEND` write option.

The file and directory management operations, and the signatures and return types of everything above, are in the [`smb:Client` API documentation](https://central.ballerina.io/ballerina/smb/latest#Client).

## SMB listener

The `smb:Listener` polls a directory on a share and invokes a service for each file that appears or disappears. It is configured with an `smb:ListenerConfiguration`, which takes the same connection fields as the client plus:

| Field | Description |
| --- | --- |
| `pollingInterval` | Seconds between polls. Default is `60`. |
| `fileNamePattern` | Regular expression the file name must match, for example `(.*)\.txt`. Applies to every handler unless a handler overrides it. |

### The SMB service

A service attached to the listener watches one directory. The directory is taken from the `path` field of `@smb:ServiceConfig`. The listener descends into subdirectories of that path.

```ballerina
@smb:ServiceConfig {
    path: "/sales/new"
}
service "salesProcessor" on smbListener {
    // remote methods
}
```

A service must declare at least one `onFile*` or `onFileDelete` method.

### Content handlers

When a file appears, the listener picks the handler that matches its extension, reads the file, and binds the content to the type of the first parameter. If that handler is not declared — or its `fileNamePattern` does not match — the file falls through to `onFile`.

| Handler | File extensions | Accepted content types |
| --- | --- | --- |
| `onFileText` | `.txt`, `.log`, `.md` | `string` |
| `onFileJson` | `.json` | `json`, a record type |
| `onFileXml` | `.xml` | `xml`, a record type |
| `onFileCsv` | `.csv` | `string[][]`, a record array, `stream<string[], error?>`, a stream of records |
| `onFile` | Everything else, and the fallback for the above | `byte[]`, `stream<byte[], error?>` |

Declaring a `stream` parameter reads the file in chunks instead of loading it into memory, which is the right choice for large files. A query expression consumes the stream to completion; call `close()` yourself only if you stop reading early.

```ballerina
service "reportProcessor" on smbListener {

    remote function onFileText(string content, smb:FileInfo fileInfo) returns error? {
        log:printInfo(string `${fileInfo.name} has ${content.length()} characters`);
    }

    remote function onFile(stream<byte[], error?> content, smb:FileInfo fileInfo) returns error? {
        int total = 0;
        check from byte[] chunk in content
            do {
                total += chunk.length();
            };
        log:printInfo(string `${fileInfo.name} is ${total} bytes`);
    }
}
```

A handler may take up to two more parameters after the content, in either order:

- `smb:FileInfo` — the file's name, path, size, timestamps, and attributes.
- `smb:Caller` — the share connection, for reading or writing other files while this one is being processed.

### Handling deletions

`onFileDelete` is invoked when a file disappears from the watched directory. It receives the path as a `string`; there is no content or `smb:FileInfo`, because the file is already gone. An optional `smb:Caller` may follow.

```ballerina
service "auditService" on smbListener {

    remote function onFileDelete(string path, smb:Caller caller) returns error? {
        check caller->putText("/audit/deletions.log", path + "\n", smb:APPEND);
    }
}
```

### Handling errors

`onError` is invoked when the listener fails to poll, read, or bind a file, and when a handler returns an error. It takes an `error` or `smb:Error`, optionally followed by an `smb:Caller`. Declaring it is optional; without it, failures are logged and processing continues.

```ballerina
remote function onError(smb:Error err, smb:Caller caller) returns error? {
    log:printError("SMB listener failure", err);
}
```

### Filtering and post-processing

`@smb:FunctionConfig` configures an individual handler.

| Field | Description |
| --- | --- |
| `fileNamePattern` | Regular expression for the file names this handler accepts. Overrides the listener's `fileNamePattern`. |
| `afterProcess` | What to do once the handler returns successfully: `smb:DELETE`, or a `moveTo` destination. |
| `afterError` | What to do when the handler fails: `smb:DELETE`, or a `moveTo` destination. |

With a `moveTo` destination, `preserveSubDirs` (default `true`) recreates the file's subdirectory structure, relative to the service path, under the destination.

```ballerina
service "invoiceProcessor" on smbListener {

    @smb:FunctionConfig {
        fileNamePattern: "invoice_(.*)\\.csv",
        afterProcess: {moveTo: "/invoices/processed"},
        afterError: {moveTo: "/invoices/failed", preserveSubDirs: false}
    }
    remote function onFileCsv(Invoice[] invoices, smb:FileInfo fileInfo) returns error? {
        // ...
    }
}
```

### Recovering from malformed CSV rows

By default, one malformed row fails the whole file. Setting `csvFailSafe` on the listener or the client skips the bad rows and delivers the rest. Each skipped row is appended to a `<file-name>_error.log` file in the working directory of the Ballerina program. Use `contentType` to choose what is recorded for each skipped row: `smb:METADATA` (default), `smb:RAW`, or `smb:RAW_AND_METADATA`.

```ballerina
listener smb:Listener smbListener = check new ({
    host: "smb.example.com",
    share: "reports",
    csvFailSafe: {contentType: smb:RAW_AND_METADATA}
});
```

## Examples

The `smb` module provides practical examples illustrating usage in various scenarios.

1. [Basic file operations](https://github.com/ballerina-platform/module-ballerina-smb/tree/main/examples/basic-file-operations) – Connects to a Kerberos-enabled SMB share, lists the root directory, writes a test file, verifies it exists, and reads it back.

2. [Manage sales reports](https://github.com/ballerina-platform/module-ballerina-smb/tree/main/examples/sales-report) – Listens for JSON sales reports on an SMB share, flattens nested data into row records, appends them to a CSV data file, and moves the processed file to a designated folder.

3. [Manage timesheets](https://github.com/ballerina-platform/module-ballerina-smb/tree/main/examples/timesheets) – Validates contractor timesheet CSVs from an SMB share, moves valid files to a processed location and writes cleaned copies, or quarantines invalid files with detailed error logs.
