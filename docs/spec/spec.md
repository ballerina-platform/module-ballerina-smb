# Specification: Ballerina SMB Library

_Owners_: @Nuvindu \
_Reviewers_: @Nuvindu \
_Created_: 2026/08/10 \
_Updated_: 2026/08/10 \
_Edition_: Swan Lake

## Introduction

This is the specification for the SMB standard library of the [Ballerina language](https://ballerina.io/), which provides a client and a listener for working with files on remote SMB (Server Message Block) shares — the protocol behind Windows file servers, NAS appliances, and Samba.

The SMB library specification has evolved and may continue to evolve in the future. The released versions of the specification can be found under the relevant GitHub tag.

If you have any feedback or suggestions about the library, start a discussion via a [GitHub issue](https://github.com/ballerina-platform/ballerina-library/issues) or in the [Discord server](https://discord.gg/ballerinalang). Based on the outcome of the discussion, the specification and implementation can be updated. Community feedback is always welcome.

The conforming implementation of the specification is released and included in the distribution. Any deviation from the specification is considered a bug.

## Contents

1. [Overview](#1-overview)
2. [Security](#2-security)
   * 2.1 [Authentication](#21-authentication)
   * 2.2 [Message Signing and Encryption](#22-message-signing-and-encryption)
   * 2.3 [Dialect Negotiation](#23-dialect-negotiation)
3. [Client](#3-client)
   * 3.1 [Initializing the Client](#31-initializing-the-client)
   * 3.2 [Writing Files](#32-writing-files)
   * 3.3 [Reading Files](#33-reading-files)
   * 3.4 [Data Binding](#34-data-binding)
   * 3.5 [File Management](#35-file-management)
4. [Listener](#4-listener)
   * 4.1 [Initializing the Listener](#41-initializing-the-listener)
   * 4.2 [Service](#42-service)
   * 4.3 [Content Handlers](#43-content-handlers)
   * 4.4 [Handler Selection](#44-handler-selection)
   * 4.5 [File Filtering](#45-file-filtering)
   * 4.6 [Post-Processing Actions](#46-post-processing-actions)
   * 4.7 [Error Handling](#47-error-handling)
5. [Caller](#5-caller)
6. [Errors](#6-errors)

## 1. Overview

The library exposes three components.

| Component | Purpose |
| --- | --- |
| `smb:Client` | Connect to a share and read, write, move, copy, and list files. |
| `smb:Listener` | Poll a directory on a share and dispatch each added or deleted file to a service. |
| `smb:Caller` | The share connection made available to a service, so a handler can act on the share while processing a file. |

A connection is always made to a single named share. Every path accepted or returned by the library is relative to that share, and is written with `/` as the separator regardless of the server platform.

The library supports SMB dialects 2.0.2 through 3.1.1. SMB 1.0 is not supported.

## 2. Security

### 2.1 Authentication

Authentication is configured through the `auth` field of the client and listener configuration, which takes an `smb:AuthConfiguration`.

```ballerina
public type AuthConfiguration record {|
    Credentials credentials?;
    KerberosConfig kerberosConfig?;
|};
```

`smb:Credentials` carries an NTLMv2 identity. `domain` defaults to `WORKGROUP`.

```ballerina
public type Credentials record {|
    string username;
    string password;
    string domain = "WORKGROUP";
|};
```

`smb:KerberosConfig` carries a Kerberos identity. `principal` is given in the `user@REALM` form. When `keytab` is not provided, the password from `credentials` is used to obtain the ticket. `configFile` points at a `krb5.conf` describing the realm.

```ballerina
public type KerberosConfig record {|
    string principal;
    string keytab?;
    string configFile?;
|};
```

Providing neither `credentials` nor `kerberosConfig` authenticates anonymously. When `kerberosConfig` is present, Kerberos is used.

Anonymous authentication is accepted only with the SMB 2 dialects. Because the default `dialects` list starts at SMB 3.1.1, an anonymous connection has to narrow it, and is rejected otherwise.

```ballerina
smb:Client smbClient = check new ({
    host: "smb.example.com",
    share: "public",
    dialects: [smb:SMB_2_1, smb:SMB_2_0_2]
});
```

Signing and encryption are also unavailable to an anonymous connection, and are turned off for it regardless of how they are configured.

### 2.2 Message Signing and Encryption

`signRequired` requires that every message of the session be signed, and fails the connection when the server will not sign. `encryptData` encrypts the session payload, which requires a dialect of 3.0 or above. Both default to `false` and apply to a connection opened by the `smb:Client`.

### 2.3 Dialect Negotiation

`dialects` lists the acceptable dialects in order of preference. The default is `[SMB_3_1_1, SMB_3_0_2, SMB_3_0, SMB_2_1, SMB_2_0_2]`, so the highest dialect both peers support is negotiated. Restricting the list refuses anything outside it.

```ballerina
public enum Dialect {
    SMB_3_1_1,
    SMB_3_0_2,
    SMB_3_0,
    SMB_2_1,
    SMB_2_0_2
}
```

## 3. Client

### 3.1 Initializing the Client

An `smb:Client` is created with an `smb:ClientConfiguration`. `share` is required; everything else has a default.

```ballerina
public type ClientConfiguration record {|
    string host = "localhost";
    int port = 445;
    string share;
    AuthConfiguration auth?;
    Dialect[] dialects = [SMB_3_1_1, SMB_3_0_2, SMB_3_0, SMB_2_1, SMB_2_0_2];
    boolean signRequired = false;
    boolean encryptData = false;
    boolean enableDfs = false;
    int bufferSize = 65536;
    decimal connectTimeout = 30.0;
    boolean laxDataBinding = false;
    FailSafeOptions csvFailSafe?;
|};
```

`enableDfs` resolves DFS referrals, so paths that cross namespaces are followed. `connectTimeout` is in seconds. The size of the transfer buffer is not specified, and `bufferSize` is tracked in [ballerina-library#9022](https://github.com/ballerina-platform/ballerina-library/issues/9022).

Initialization establishes the connection and the tree connect to the share, so an unreachable host, a rejected identity, or a missing share fails at construction rather than on first use.

```ballerina
smb:Client smbClient = check new ({
    host: "smb.example.com",
    share: "reports",
    auth: {
        credentials: {username: "alice", password: "***", domain: "WORKGROUP"}
    }
});
```

`close` releases the connection held by the client.

### 3.2 Writing Files

Every `put` method takes an `smb:FileWriteOption`, which defaults to `OVERWRITE`.

```ballerina
public enum FileWriteOption {
    OVERWRITE,
    APPEND
}
```

| Method | Content |
| --- | --- |
| `putBytes` | `byte[]` |
| `putText` | `string` |
| `putJson` | `json` |
| `putXml` | `xml` or a record convertible to XML |
| `putCsv` | `string[][]` or `record {}[]` |
| `putBytesAsStream` | `stream<byte[], error?>` |
| `putCsvAsStream` | `stream<string[]\|record {}, error?>` |

A write creates the file when it does not exist. It does not create the directories leading to it, so writing to a path whose parent directory is absent fails. Use `mkdir` to create the directory first.

`putCsv` emits a header row derived from the record fields when the content is a `record {}[]` and the option is not `APPEND`. Appending a record array writes data rows only, so a file built entirely by appends carries no header.

`patch` writes a `byte[]` at a given byte offset, leaving the surrounding content untouched. It takes no write option, and creates the file when it does not exist.

### 3.3 Reading Files

| Method | Returns |
| --- | --- |
| `getBytes` | `byte[]` |
| `getText` | `string` |
| `getJson` | a value of the contextually expected `json` type |
| `getXml` | `xml`, or the contextually expected record type |
| `getCsv` | `string[][]`, or the contextually expected `record {}[]` |
| `getBytesAsStream` | `stream<byte[], error?>` |
| `getCsvAsStream` | a stream of `string[]` or of the contextually expected record type |

The streaming reads hold the file open until the stream is consumed or closed, so a stream must always be closed.

### 3.4 Data Binding

`getJson`, `getXml`, `getCsv`, and `getCsvAsStream` bind the file content to the type expected at the call site, so no separate conversion step is needed.

```ballerina
type SalesReport record {|
    string storeId;
    decimal total;
|};

SalesReport report = check smbClient->getJson("/sales/latest.json");
```

Binding fails with an `smb:Error` when the content does not match the target type. `laxDataBinding` relaxes this, allowing content with absent or additional fields to bind.

`csvFailSafe` applies to `getCsv` and to an `onFileCsv` handler that binds the whole file. When present, a record that cannot be bound is skipped and recorded instead of failing the whole read. `contentType` selects what is written for each skipped record.

Skipped records are appended to `<file-name>_error.log` in the working directory of the Ballerina program, not to the share. Under `RAW` and `RAW_AND_METADATA` that file holds the raw text of the skipped records, so it inherits the sensitivity of the data being read.

Fail-safe handling of a CSV consumed as a stream is not specified, and is tracked in [ballerina-library#9023](https://github.com/ballerina-platform/ballerina-library/issues/9023).

```ballerina
public type FailSafeOptions record {|
    ErrorLogContentType contentType = METADATA;
|};

public enum ErrorLogContentType {
    METADATA,
    RAW,
    RAW_AND_METADATA
}
```

### 3.5 File Management

`list` returns an `smb:FileInfo` for every entry of a directory. The `.` and `..` entries are not included.

```ballerina
public type FileInfo record {|
    string name;
    string path;
    int size;
    time:Utc modifiedAt;
    time:Utc createdAt;
    time:Utc accessedAt;
    time:Utc writtenAt;
    boolean isDirectory;
    string extension;
    boolean isExecutable;
    boolean isHidden;
    boolean isWritable;
    string uri;
|};
```

`mkdir` and `rmdir` create and remove directories. `copy` duplicates a file and `delete` removes one. `exists`, `size`, and `isDirectory` report on a path.

`rename` and `move` are the same operation: both write the content to the destination path and then remove the source, so either can relocate a file across directories. Neither is atomic, and neither creates the directories leading to the destination.

## 4. Listener

### 4.1 Initializing the Listener

An `smb:Listener` is created with an `smb:ListenerConfiguration`, which adds polling and filtering to the client configuration.

```ballerina
public type ListenerConfiguration record {|
    string host = "localhost";
    int port = 445;
    string share = "";
    AuthConfiguration auth?;
    string fileNamePattern?;
    decimal pollingInterval = 60;
    Dialect[] dialects = [SMB_3_1_1, SMB_3_0_2, SMB_3_0, SMB_2_1, SMB_2_0_2];
    boolean signRequired = false;
    boolean encryptData = false;
    boolean enableDfs = false;
    int bufferSize = 65536;
    decimal connectTimeout = 30.0;
    boolean laxDataBinding = false;
    FailSafeOptions csvFailSafe?;
|};
```

`pollingInterval` is the number of seconds between polls, and defaults to 60. The listener polls the watched directory of every attached service on each cycle.

The polling connection negotiates the dialects given in `dialects`. The remaining transport settings of the record are not specified for the listener, and are tracked in [ballerina-library#9021](https://github.com/ballerina-platform/ballerina-library/issues/9021).

### 4.2 Service

A service attached to an `smb:Listener` watches one directory of the share. The directory is given by the `path` field of `@smb:ServiceConfig`, and defaults to the service name when the annotation is absent.

```ballerina
public type SmbServiceConfig record {|
    string path?;
|};
```

```ballerina
@smb:ServiceConfig {
    path: "/sales/new"
}
service "salesProcessor" on smbListener {
    // handlers
}
```

Several services may attach to one listener, each watching a different directory. The handler methods of a service and its `smb:Caller` are resolved when the service is attached, not per file event.

### 4.3 Content Handlers

A service declares one or more content handlers. The listener reads the file, binds its content, and passes it as the **first** parameter, so a handler never reads the file itself.

| Handler | Content parameter type |
| --- | --- |
| `onFileText` | `string` |
| `onFileJson` | a type the JSON content binds to |
| `onFileXml` | `xml`, or a record type |
| `onFileCsv` | `string[][]`, a record array type, or a stream of either |
| `onFile` | `byte[]`, or a `stream<byte[], error?>` |

Declaring a stream as the content parameter of `onFileCsv` or `onFile` streams the file instead of holding it in memory, which suits files too large to read whole.

After the content parameter, a handler may declare an `smb:FileInfo` parameter, an `smb:Caller` parameter, or both, in any order. Both are optional.

```ballerina
remote function onFileJson(SalesReport report, smb:FileInfo fileInfo, smb:Caller caller) returns error? {
}
```

`onFileDelete` is invoked with the path of a file that has disappeared from the watched directory since the previous poll. It may declare an optional `smb:Caller` parameter.

A service that declares no handler for a file leaves that file untouched.

### 4.4 Handler Selection

For each file found in the watched directory, the handler is selected by the file extension.

| Extension | Handler |
| --- | --- |
| `txt`, `log`, `md` | `onFileText` |
| `json` | `onFileJson` |
| `xml` | `onFileXml` |
| `csv` | `onFileCsv` |
| any other | `onFile` |

When the handler for an extension is not declared, the file falls through to `onFile`. A file is dispatched to at most one handler.

### 4.5 File Filtering

`fileNamePattern` restricts the files the listener picks up to those whose names match the given regular expression. It is accepted at two levels:

- on the listener configuration, applying to every service attached to it, and
- on `@smb:FunctionConfig`, applying to a single handler.

A pattern on a handler replaces the listener-level pattern for that handler rather than narrowing it further.

### 4.6 Post-Processing Actions

`@smb:FunctionConfig` declares what becomes of the file once the handler has run, so a service does not have to move or delete files itself.

```ballerina
public type FunctionConfiguration record {|
    string fileNamePattern?;
    MOVE|DELETE afterProcess?;
    MOVE|DELETE afterError?;
|};
```

`afterProcess` applies when the handler completes successfully, and `afterError` when processing the file fails. A file whose applicable action is not specified stays where it is.

`DELETE` removes the file. `MOVE` relocates it to `moveTo`, creating that directory when it is absent. `preserveSubDirs` recreates the file's subdirectory structure, relative to the watched directory, beneath the destination.

```ballerina
public type Move record {|
    string moveTo;
    boolean preserveSubDirs = true;
|};
```

```ballerina
@smb:FunctionConfig {
    afterProcess: {moveTo: "/sales/processed"},
    afterError: {moveTo: "/sales/error"}
}
remote function onFileJson(SalesReport report, smb:FileInfo fileInfo) returns error? {
}
```

At most one action applies to a file. A handler that moves the file itself and also declares `afterProcess` leaves the listener acting on a path that no longer exists.

> **Implementation note:** `afterError` is currently applied only when the handler body fails. A file whose content cannot be read or bound reaches `onError` without the action being applied, and so stays in the watched directory. This deviates from the behaviour specified above and is tracked in [ballerina-library#9018](https://github.com/ballerina-platform/ballerina-library/issues/9018).

### 4.7 Error Handling

`onError` is invoked when a file cannot be read, its content cannot be bound to the handler's content parameter, the handler itself fails, or a poll fails. It receives the error and may declare an optional `smb:Caller` parameter.

```ballerina
remote function onError(error err) returns error? {
    log:printError("Failed to process the file", err);
}
```

`onError` and the post-processing actions are independent: declaring `onError` does not suppress `afterProcess` or `afterError`. A service that declares no `onError` has its errors logged by the listener. `@smb:FunctionConfig` on `onError` has no effect.

## 5. Caller

An `smb:Caller` declared as a handler parameter lets a handler act on the share while processing a file.

The caller has its own connection to the share, opened from the listener configuration. It is created once for a listener and shared by every service attached to it, so a listener that has a caller holds two connections: the one it polls with and the one the caller uses.

The `smb:Caller` offers the write, read, and file management operations of the client: `putBytes`, `patch`, `putText`, `putJson`, `putXml`, `putCsv`, `putBytesAsStream`, `putCsvAsStream`, `getBytes`, `getText`, `getJson`, `getXml`, `getCsv`, `getBytesAsStream`, `getCsvAsStream`, `list`, `mkdir`, `rmdir`, `rename`, `move`, `copy`, `exists`, `size`, `isDirectory`, and `delete`.

The read operations of the `smb:Caller` return the plain types rather than binding to a contextually expected type, so `getJson` returns `json` and `getCsv` returns `string[][]`.

The lifetime of the caller belongs to the listener, which closes it when it stops. Closing an `smb:Caller` from a handler does not stop the listener, which keeps polling on its own connection, but it does close the connection every service on that listener shares, so subsequent caller operations fail.

## 6. Errors

The library defines a single distinct error type.

```ballerina
public type Error distinct error;
```

Every client and caller operation that can fail returns an `smb:Error`. The lifecycle methods of the listener, `attach`, `detach`, `gracefulStop`, and `immediateStop`, are declared to return a plain `error?`, because they also propagate errors raised by the task scheduler they use.

An `smb:Error` carries the reason in its message. Failures reported by the server keep the SMB status in the message, so a rejected operation can be told apart from a transport failure.

```ballerina
string|smb:Error content = smbClient->getText("/reports/missing.txt");
if content is smb:Error {
    log:printError("Read failed", content);
}
```
