# Basic file operations via SMB server

This example demonstrates connecting to SMB server with Kerberos authentication and perform operations like listing, writing, and reading files on the server.

## Configure

Update the placeholders in `Config.toml`.

```toml
# Replace with your values
kerberosHost = "<smb-hostname-or-ip>"
kerberosUser = "<username>"
kerberosPassword = "<password>"
kerberosDomain = "<domain>"
kerberosShare = "<share-name>"
kerberosConfigFile = "path/to/krb5.conf"
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
