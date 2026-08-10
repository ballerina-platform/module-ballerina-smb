# Validate Contractor Timesheets on an SMB Share

This example validates contractor timesheet CSV files placed on an SMB share. It monitors the incoming directory, validates each CSV against expected counts and thresholds, then moves valid files to the processed directory while writing cleaned data to the validated directory, or quarantines invalid files with detailed error logs.

## Prerequisites

Create the following directories on the SMB share before running the example. The service does not create them.

- `/timesheets` - Root directory for timesheet operations
- `/timesheets/incoming` - Drop location for new timesheet CSV files
- `/timesheets/quarantine` - Invalid files are moved here with error details
- `/timesheets/validated` - Cleaned and validated CSV data is written here

The following is created automatically if it is absent, because a post-processing move creates its destination directory.

- `/timesheets/processed` - Successfully validated files are moved here

Valid files are moved to `/timesheets/processed` by the `afterProcess` action of the `@smb:FunctionConfig` annotation. Invalid files are moved by the handler itself, because the quarantine file name encodes why validation failed, which a fixed `moveTo` destination cannot express. A handler-issued move does not create its destination, which is why `/timesheets/quarantine` has to exist.

## Configure

Update `Config.toml` with your SMB credentials.

```toml
smbHost = "<host>"
smbPort = 445
smbShare = "<share>"
smbUsername = "<user>"
smbPassword = "<password>"
smbDomain = "WORKGROUP"

expectedRecordCount = 5
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

Copy the sample timesheet at `resources/sample-timesheet.csv` to `/timesheets/incoming` on the SMB share. You can watch the logs to see the file being validated, cleaned data written to `/timesheets/validated/`, and the original file moved to `/timesheets/processed/`.

To see the quarantine path, drop a CSV that breaks one of the rules, such as a row count other than `expectedRecordCount` or a `contractor_id` outside `CTR-001` to `CTR-005`. The file is moved to `/timesheets/quarantine/` with the failure reason and a timestamp in its name.
