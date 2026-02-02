## Sales report via SMB server

This example processes JSON sales reports placed on an SMB share. It listens for JSON sales reports on an SMB share, flattens nested data into row records, appends them to a CSV data file, and moves the processed file to a designated folder.

### Prerequisites

You will need to have the following directories added to the SMB share first.

- `/sales` - Root directory for sales operations
- `/sales/new` - Directory monitored for incoming JSON sales reports
- `/sales/processed` - Directory for successfully processed sales reports
- `/sales/data` - Directory where sales data is persisted

### Configure

Update `Config.toml` with your SMB credentials.

```toml
smbHost = "<host>"
smbPort = "<port>"
smbShare = "<share>"
smbUsername = "<user>"
smbPassword = "<password>"
smbDomain = "WORKGROUP"
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
