# Overview

crc-support component allows to manage remote operations to setup a environment for testing Openshift Local, it contains the scripts based on each target platform, and it basically manages:

* Cleanup environments to ensure fresh installations
* Validate bundle url download (fallback as internal url might be purged)
* Download bundles 
* Download and install Openshift Local

## About bundle url validation

[`tkn/check-bundle-url.yaml`](tkn/check-bundle-url.yaml) checks
`bundle-base-url` first, then the optional `bundle-base-url-fallbacks` array
(default empty `[]`). Each candidate must serve both `bundle-name` and
`bundle-shasumfile` (default `sha256sum.txt`).
