# ci-definitions

This repository contains several specs to define ci actions used within the building process of Openshift Local. The logic on each action is encapsulated as a container which improve their portability.

## release

The ci-definitions is a group of actions, as so the release / versioning is tied to each action on the project. Each action contains a file named `release-info` which holds the inforamtion for the release of the specific action.

The following snippet shows how to release new version for a specific ci action (i.e crc-builder v1.0.0):

```bash
# Create a branch, branch will NOT be pushed
git checkout -b b-crc-builder-v1.0.0
# Change the version on the release-info file for the ci action
sed ... (TBC)
# Generate the tasks with the new version
make crc-builder-tkn-create
# Commit the cut for the ci action
git commit -s -m "chore: cut crc-builder v1.0.0"
# Create the tag
git tag crc-builder-v1.0.0
# Here the gh builder flow for the ci action will create oci image and bundle with tekton tasks
git push upstream crc-builder-v1.0.0
# Change version on release-info to next version 
```

## testing PRs

Manually run make XXX-tkn-create, then;

Typically PRs will be composed of images, tasks and pipelines:

* Pipelines and tasks can use git resolver using the forked repo source for the PR
* Task which needs the image need to be updated with the ghcr image

A testing commit can be done at very last part of the PR to test this customizations which then can be used 
from a pipelinerun with a pipelineref to the forked repo source for the pr.

If everything works just revert and dismiss latest commit and create a tag