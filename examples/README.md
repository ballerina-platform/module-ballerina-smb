# Examples

The `ballerina/smb` connector provides practical examples illustrating usage in various scenarios.

1. [Basic File Operations](https://github.com/ballerina-platform/module-ballerina-smb/tree/main/examples/basic-file-operations) – Connects to an SMB share (Kerberos-enabled), lists the root directory, writes a test file, verifies it exists, and reads it back.

2. [Manage Sales Reports](https://github.com/ballerina-platform/module-ballerina-smb/tree/main/examples/sales-report) – Listens for JSON sales reports on an SMB share, flattens nested data into row records, appends them to a CSV data file, and moves the processed file to a designated folder.

3. [Manage time sheets](https://github.com/ballerina-platform/module-ballerina-smb/tree/main/examples/timesheets) – Validates contractor timesheet CSVs from an SMB share, moves valid files to a processed location and writes cleaned copies, or quarantines invalid files with detailed error logs.

## Prerequisites

- Ballerina Swan Lake (2201.12.0 or newer).
- An accessible SMB server with the required credentials and share.
- Config files per example in their folders (see each README for details).

## Running an example

Execute the following commands to build an example from the source:

* To build an example:

    ```bash
    bal build
    ```

* To run an example:

    ```bash
    bal run
    ```

## Building the examples with the local module

**Warning**: Due to the absence of support for reading local repositories for single Ballerina files, the Bala of the module is manually written to the central repository as a workaround. Consequently, the bash script may modify your local Ballerina repositories.

Execute the following commands to build all the examples against the changes you have made to the module locally:

* To build all the examples:

    ```bash
    ./build.sh build
    ```

* To run all the examples:

    ```bash
    ./build.sh run
    ```
