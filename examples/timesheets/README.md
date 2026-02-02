## Timesheets validation via SMB server

This example validates contractor timesheet CSV files placed on an SMB share. It monitors the incoming directory, validates each CSV against expected counts and thresholds, then moves valid files to the processed directory while writing cleaned data to the validated directory, or quarantines invalid files with detailed error logs.

### Prerequisites

You will need to have the following directories added to the SMB share first.

- `/timesheets` - Root directory for timesheet operations
- `/timesheets/incoming` - Drop location for new timesheet CSV files
- `/timesheets/processed` - Successfully validated files are moved here
- `/timesheets/quarantine` - Invalid files are moved here with error details
- `/timesheets/validated` - Cleaned and validated CSV data is written here

### Configure

Update `Config.toml` with your SMB credentials.

```toml
smbHost = "<host>"
smbPort = "<port>"
smbShare = "<share>"
smbUsername = "<user>"
smbPassword = "<password>"
smbDomain = "<domain>"

expectedRecordCount = 5
invalidThreshold = 0.05
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

Place a CSV timesheet file at `/timesheets/incoming` on the SMB share with columns `contractor_id`, `date`, `hours_worked`, `site_code`. You can watch the logs to see the file being validated, cleaned data written to `/timesheets/validated/`, and the original file moved to `/timesheets/processed/` if valid, or `/timesheets/quarantine/` if validation fails.
