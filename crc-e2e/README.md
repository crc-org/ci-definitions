# CRC e2e

## Modifications to the image

Changes to `crc-e2e/os/macos/builder/build.sh` require re-building and pushing the image to internal registry (ImageStream). Make sure the changes are pushed to some `mybranch` on your fork of the QE platform repo (`github.com/<your-username>/qe-platform`). Since the `crc-e2e/manifests/buildconfig.yaml` will be guiding the build of the image, it needs to specify your branch on your fork as the source.

```diff
  source:
    contextDir: support/images/crc-e2e
    git:
      # dev
+     ref: 'mybranch'
+     uri: 'https://gitlab.cee.redhat.com/<your-username>/qe-platform.git'
-     ref: v2.14.0
-     uri: 'https://gitlab.cee.redhat.com/crc/qe-platform.git'
    type: Git
```

Log in to `codeready-container` project, apply the changes in `crc-e2e/manifests/buildconfig.yaml` and start the build from the corresponding `BuildConfig` (depending on the platform).

```bash
oc apply -f support/images/crc-e2e/manifests/buildconfig.yaml
oc start-build image-crc-e2e-<platform>
```

Lastly, make sure that `imagePullPolicy` is set to `Always` in all places that use this imageStreamTag (e.g. `crc-e2e:v0.0.3-macos`). In our case, we needed to change and re-apply the following YAML.

```bash
oc apply -f orchestrator/catalog/task/crc-e2e-installer/0.3/crc-e2e-installer.yaml
```

Then undo changes to `crc-e2e/manifests/buildconfig.yaml` so it points to the upstream repository.

_If everything works as expected, send an MR to `gitlab.cee.redhat.com/crc/qe-platform`._

