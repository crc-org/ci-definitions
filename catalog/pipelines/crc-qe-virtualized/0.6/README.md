# Overview

This pipeline allows to run the qe phase on externally build distribution of crc.
The target host will be self provisioned.

## Params

TBC  

## Required tasks

This pipeline relies on several tasks which should be deployed to allow deploy its spec

```yaml
oc apply -f catalog/task/gather-run-info/0.1/gather-run-info.yaml
oc apply -f catalog/task/gather-crc-info/0.1/gather-crc-info.yaml
oc apply -f catalog/task/crc-preparer/0.2/crc-preparer.yaml
oc apply -f catalog/task/crc-qe-cli/0.1/crc-qe-cli.yaml
oc apply -f catalog/task/infra-fedora-provision/0.1/infra-fedora-provision.yaml
oc apply -f catalog/task/infra-fedora-decommission/0.1/infra-fedora-decommission.yaml
oc apply -f catalog/task/infra-rhel-provision/0.1/infra-rhel-provision.yaml
oc apply -f catalog/task/infra-rhel-decommission/0.1/infra-rhel-decommission.yaml
#REVIEW
oc apply -f catalog/task/gather-run-info/0.1/gather-run-info.yaml
oc apply -f catalog/task/gather-host-info/0.1/gather-host-info.yaml
oc apply -f catalog/task/gather-crc-info/0.1/gather-crc-info.yaml
oc apply -f catalog/task/gather-s3-info/0.1/gather-s3-info.yaml
oc apply -f catalog/task/asset-checker-http/0.1/asset-checker-http.yaml
oc apply -f catalog/task/crc-preparer/0.2/crc-preparer.yaml
oc apply -f catalog/task/crc-builder-tray/0.3/crc-builder-tray-mac-universal.yaml
oc apply -f catalog/task/crc-builder-tray/0.3/crc-builder-tray-x64.yaml
oc apply -f catalog/task/crc-builder-installer/0.3/crc-builder-installer.yaml
oc apply -f orchestrator/catalog/task/crc-qe-cli/0.1/crc-qe-cli.yaml
oc apply -f catalog/task/s3-sink-workspace/0.3/s3-sink-workspace.yaml
oc apply -f catalog/task/url-generator/0.1/url-generator.yamls
```

### workspace

The task uses a workspace to copy files which are required across the pipeline. As an example
the host key is copied to the workspace and the path is exposed through `workspace-resources-path`.  

Then any other task across the pipeline which uses the workspace can access the key to use for ssh into  
the target host.
