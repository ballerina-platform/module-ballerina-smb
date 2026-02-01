## Sales report via SMB server

This example processes JSON sales reports placed on an SMB share. Files dropped into `/sales/new` are flattened into per-line records, appended to `/sales/data/sales_data.csv`, and the original file is moved to `/sales/processed/`.

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
