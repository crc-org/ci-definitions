CONTAINER_MANAGER ?= podman

# Helpers
TOOLS_DIR := tools
include tools/tools.mk

## Functions
# Set image and version on the task 
# 1 image
# 2 version
# 3 context
define tkn_template
	sed -e 's%cimage%$(1)%g' -e 's%cversion%$(2)%g' $(3)/tkn/tpl/task.tpl.yaml > $(3)/tkn/task.yaml
endef

# Push task as bundle
# 1 image
# 2 version
# 3 context
define tkn_push
	$(TOOLS_BINDIR)/tkn bundle push $(1):$(2)-tkn -f $(3)/tkn/task.yaml
endef

#### snc-runner ####

.PHONY: snc-runner-oci-build snc-runner-oci-save snc-runner-oci-push

# Variables
SNC_RUNNER ?= $(shell sed -n 1p snc-runner/release-info)
SNC_RUNNER_V ?= v$(shell sed -n 2p snc-runner/release-info)
SNC_RUNNER_SAVE ?= snc-runner

snc-runner-oci-build: CONTEXT=snc-runner/oci
snc-runner-oci-build: MANIFEST=$(SNC_RUNNER):$(SNC_RUNNER_V)
snc-runner-oci-build:
	${CONTAINER_MANAGER} build -t $(MANIFEST) -f $(CONTEXT)/Containerfile $(CONTEXT)

snc-runner-oci-save:
	${CONTAINER_MANAGER} save -o $(SNC_RUNNER_SAVE).tar $(SNC_RUNNER):$(SNC_RUNNER_V)

snc-runner-oci-push:
	${CONTAINER_MANAGER} push $(SNC_RUNNER):$(SNC_RUNNER_V)

#### crc-builder ####

.PHONY: crc-builder-oci-build crc-builder-oci-save crc-builder-oci-push

# Registries and versions
CRC_BUILDER ?= $(shell sed -n 1p crc-builder/release-info)
CRC_BUILDER_V ?= v$(shell sed -n 2p crc-builder/release-info)
CRC_BUILDER_SAVE ?= crc-builder

crc-builder-oci-build: CONTEXT=crc-builder/oci
crc-builder-oci-build: MANIFEST=$(CRC_BUILDER):$(CRC_BUILDER_V)
crc-builder-oci-build:
	${CONTAINER_MANAGER} manifest create $(MANIFEST)-linux
	${CONTAINER_MANAGER} build --platform linux/arm64 --build-arg=TARGETARCH=arm64 --manifest $(MANIFEST)-linux -f $(CONTEXT)/Containerfile.linux $(CONTEXT)
	${CONTAINER_MANAGER} build --platform linux/amd64 --build-arg=TARGETARCH=amd64 --manifest $(MANIFEST)-linux -f $(CONTEXT)/Containerfile.linux $(CONTEXT)
	${CONTAINER_MANAGER} build -t $(MANIFEST)-windows -f $(CONTEXT)/Containerfile.non-linux --build-arg=OS=windows $(CONTEXT)
	${CONTAINER_MANAGER} build -t $(MANIFEST)-darwin -f $(CONTEXT)/Containerfile.non-linux --build-arg=OS=darwin $(CONTEXT)

crc-builder-oci-save: MANIFEST=$(CRC_BUILDER):$(CRC_BUILDER_V)
crc-builder-oci-save:
	${CONTAINER_MANAGER} save -o $(CRC_BUILDER_SAVE)-linux.tar $(MANIFEST)-linux
	${CONTAINER_MANAGER} save -o $(CRC_BUILDER_SAVE)-windows.tar $(MANIFEST)-windows
	${CONTAINER_MANAGER} save -o $(CRC_BUILDER_SAVE)-darwin.tar $(MANIFEST)-darwin
	

crc-builder-oci-push:
	${CONTAINER_MANAGER} manifest push $(CRC_BUILDER):$(CRC_BUILDER_V)-linux
	${CONTAINER_MANAGER} push $(CRC_BUILDER):$(CRC_BUILDER_V)-windows
	${CONTAINER_MANAGER} push $(CRC_BUILDER):$(CRC_BUILDER_V)-darwin

# tkn-create:
# 	$(call tkn_creator,$(SNC_RUNNER),$(SNC_RUNNER_V),snc-runner)

# tkn-push: install-out-of-tree-tools
# 	$(call tkn_pusher,$(SNC_RUNNER),$(SNC_RUNNER_V),snc-runner)
