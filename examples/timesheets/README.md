## Timesheets validation via SMB server

This example validates contractor timesheet CSV files placed on an SMB share. It watches a share on the SMB share, validates each CSV against expected counts and thresholds, and either moves the file to directory while writing a cleaned copy to another, or saves it with detailed errors logged.

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

On first run, the service ensures these SMB directories exist: `/sales`, `/sales/new`, `/sales/data`, `/sales/processed`. Then place a JSON sales report at `/sales/new` on the SMB share (e.g., with fields such as `storeId`, `storeLocation`, `saleDate`, and an `items` array). You can watch the logs to see the file being processed, records appended to `/sales/data/sales_data.csv`, and the file moved to `/sales/processed/`.

Execute the following commands to build an example from the source:

* To build an example:

    ```bash
    bal build
    ```

* To run an example:

    ```bash
    bal run
    ```
