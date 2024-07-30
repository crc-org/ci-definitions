CONTAINER_MANAGER ?= podman

# Helpers
TOOLS_DIR := tools
include tools/tools.mk

# Registries and versions
SNC_RUNNER ?= $(shell sed -n 1p snc-runner/release-info)
SNC_RUNNER_V ?= $(shell sed -n 2p snc-runner/release-info)

.PHONY: oci-build oci-push tkn-create tkn-push

## Functions
oci_builder = ${CONTAINER_MANAGER} build -t $(1):$(2) -f $(3)/oci/Containerfile $(3)/oci
oci_pusher = ${CONTAINER_MANAGER} push $(1):$(2)
tkn_creator = sed -e 's%cimage%$(1)%g' -e 's%cversion%$(2)%g' $(3)/tkn/tpl/task.tpl.yaml > $(3)/tkn/task.yaml
tkn_pusher = $(TOOLS_BINDIR)/tkn bundle push $(1):$(2)-tkn -f $(3)/tkn/task.yaml

oci-build: 
	$(call oci_builder,$(SNC_RUNNER),$(SNC_RUNNER_V),snc-runner)

oci-push: 
	$(call oci_pusher,$(SNC_RUNNER),$(SNC_RUNNER_V))

tkn-create: 
	$(call tkn_creator,$(SNC_RUNNER),$(SNC_RUNNER_V),snc-runner)

tkn-push: install-out-of-tree-tools
	$(call tkn_pusher,$(SNC_RUNNER),$(SNC_RUNNER_V),snc-runner)