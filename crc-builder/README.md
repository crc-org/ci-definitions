# CRC Builder

## Modifications to the image

Changes to `crc-builder/os/macos/builder/build.sh` require re-building and pushing the image to internal registry (ImageStream). Make sure the changes are pushed to some `mybranch` on your fork of the QE platform repo (`github.com/<your-username>/qe-platform`). Since the `crc-builder/manifests/buildconfig.yaml` will be guiding the build of the image, it needs to specify your branch on your fork as the source. 

```diff
  source:
    contextDir: support/images/crc-builder
    git:
      # dev
+     ref: 'mybranch'
+     uri: 'https://gitlab.cee.redhat.com/<your-username>/qe-platform.git'
-     ref: v2.14.0
-     uri: 'https://gitlab.cee.redhat.com/crc/qe-platform.git'
    type: Git
```

Log in to `codeready-container` project, apply the changes in `crc-builder/manifests/buildconfig.yaml` and start the build from the corresponding `BuildConfig` (depending on the platform).

```bash
oc apply -f support/images/crc-builder/manifests/buildconfig.yaml
oc start-build image-crc-builder-<platform>
```

Lastly, make sure that `imagePullPolicy` is set to `Always` in all places that use this imageStreamTag (e.g. `crc-builder:v0.0.3-macos`). In our case, we needed to change and re-apply the following YAML. 

```bash
oc apply -f orchestrator/catalog/task/crc-builder-installer/0.3/crc-builder-installer.yaml
```

Then undo changes to `crc-builder/manifests/buildconfig.yaml` so it points to the upstream repository. 

_If everything works as expected, send an MR to `gitlab.cee.redhat.com/crc/qe-platform`._

