# Sales report processing via an SMB share

This example processes JSON sales reports placed on an SMB share. It listens for JSON sales reports on an SMB share, flattens nested data into row records, appends them to a CSV data file, and moves the processed file to a designated folder.

## Prerequisites

Create the following directories on the SMB share before running the example. The service does not create them.

- `/sales` - Root directory for sales operations
- `/sales/new` - Directory monitored for incoming JSON sales reports
- `/sales/processed` - Reports are moved here once the handler completes successfully
- `/sales/data` - Directory where sales data is persisted
- `/sales/error` - Reports that fail while being processed are moved here

The moves into `/sales/processed` and `/sales/error` are declared with the `@smb:FunctionConfig` annotation on the handler, so the handler itself contains no file-movement code.

## Configure

Update `Config.toml` with your SMB credentials.

```toml
smbHost = "<host>"
smbPort = 445
smbShare = "<share>"
smbUsername = "<user>"
smbPassword = "<password>"
smbDomain = "WORKGROUP"
```

## Running the example

Execute the following commands to build an example from the source:

* To build an example:

    ```bash
    bal build
    ```

* To run an example:

    ```bash
    bal run
    ```

## Testing the example

Copy the sample report at `resources/sample-report.json` to `/sales/new` on the SMB share. You can watch the logs to see the file being processed, records appended to `/sales/data/sales_data.csv`, and the file moved to `/sales/processed/`.
