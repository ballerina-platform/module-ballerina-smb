# Connect to a Kerberos SMB Share and Transfer Files

This example demonstrates connecting to an SMB server with Kerberos authentication and performing operations like listing, writing, and reading files on the server.

## Prerequisites

- An SMB server. It is reached on port `445` unless `smbPort` is set.
- A Kerberos realm that the SMB server trusts, and a principal in the `user@REALM` format.
- A `krb5.conf` describing that realm, readable by the process running the example.

The example lists the root of the share, writes `/kerberos_file.txt`, verifies that it exists, and reads it back.

## Configure

Update the placeholders in `Config.toml`.

```toml
# Replace with your values
kerberosHost = "<smb-hostname-or-ip>"
smbPort = 445
kerberosUser = "<username>"
kerberosPassword = "<password>"
kerberosDomain = "<domain>"
kerberosPrincipal = "<username@REALM>"
kerberosShare = "<share-name>"
kerberosConfigFile = "<path/to/krb5.conf>"
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
