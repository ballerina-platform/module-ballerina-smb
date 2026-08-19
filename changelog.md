# Change Log
This file contains all the notable changes done to the Ballerina SMB package through the releases.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [2.0.1] - 2026-08-06

### Changed

- Update the package icon

## [2.0.0] - 2026-08-05

### Added

- [Add a compiler plugin that validates the remote methods, parameters, and return types of an SMB service](https://github.com/ballerina-platform/ballerina-library/issues/8611)
- [Add post-processing support to the `@smb:FunctionConfig` annotation — `afterProcess` and `afterError` can move or delete the file once the handler completes](https://github.com/ballerina-platform/ballerina-library/issues/8845)
- Add the `onFileDelete` remote method, which is invoked with the path of a file removed from the watched directory
- Support an optional `smb:Caller` parameter in the `onFileDelete` and `onError` remote methods

### Changed

- [Review the API documentation and restructure the READMEs around the listener and the SMB service contract](https://github.com/ballerina-platform/ballerina-library/issues/8608)

### Fixed

- [Resolve the service handler methods and the `smb:Caller` when the service is attached, instead of once per file event, so that the listener no longer leaks an SMB connection per dispatch](https://github.com/ballerina-platform/ballerina-library/issues/8966)

### Removed

- Remove the unused public types `SocketConfig`, `InputContent`, `FileAgeFilter`, `AgeCalculationMode`, `FileDependencyCondition`, `DependencyMatchingMode`, and `Compression`, which described behaviour the module does not implement

## [1.0.2] - 2026-03-17

### Fixed

- Fix errors surfacing when a service does not implement the `onError` method
- Downgrade `ballerina/data.csv` to a compatible version to resolve the dependency conflict

## [1.0.1] - 2026-02-26

### Changed

- Update the `smbj` dependency version

## [1.0.0] - 2026-02-02

### Added

- [Implement the Ballerina SMB library with the `smb:Client`, `smb:Listener`, and `smb:Caller`](https://github.com/ballerina-platform/ballerina-library/issues/8539)
