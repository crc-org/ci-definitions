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
	sed -e 's%cimage%$(1)%g' -e 's%cversion%$(2)%g' $(3)/tkn/tpl/$(4).tpl.yaml > $(3)/tkn/$(4).yaml
endef

#### snc-runner ####

.PHONY: snc-runner-oci-build snc-runner-oci-save snc-runner-oci-load snc-runner-oci-push snc-runner-tkn-create snc-runner-tkn-push

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

snc-runner-oci-load:
	${CONTAINER_MANAGER} load -i $(SNC_RUNNER_SAVE).tar 

snc-runner-oci-push:
ifndef IMAGE
	IMAGE = $(SNC_RUNNER):$(SNC_RUNNER_V)
endif
	${CONTAINER_MANAGER} push $(IMAGE)

snc-runner-tkn-create:
	$(call tkn_template,$(SNC_RUNNER),$(SNC_RUNNER_V),snc-runner,task)
	$(call tkn_template,$(SNC_RUNNER),$(SNC_RUNNER_V),snc-runner,pipeline)

snc-runner-tkn-push: install-out-of-tree-tools
ifndef IMAGE
	IMAGE = $(SNC_RUNNER):$(SNC_RUNNER_V)
endif
	$(TOOLS_BINDIR)/tkn bundle push $(IMAGE)-tkn \
		-f snc-runner/tkn/task.yaml \
		-f snc-runner/tkn/pipeline.yaml

#### crc-builder ####

.PHONY: crc-builder-oci-build crc-builder-oci-save crc-builder-oci-load crc-builder-oci-push crc-builder-tkn-create crc-builder-tkn-push

# Registries and versions
CRC_BUILDER ?= $(shell sed -n 1p crc-builder/release-info)
CRC_BUILDER_V ?= v$(shell sed -n 2p crc-builder/release-info)
CRC_BUILDER_SAVE ?= crc-builder

crc-builder-oci-build: CONTEXT=crc-builder/oci
crc-builder-oci-build: MANIFEST=$(CRC_BUILDER):$(CRC_BUILDER_V)
crc-builder-oci-build:
	${CONTAINER_MANAGER} build --platform linux/arm64 --manifest $(MANIFEST)-linux-arm64 -f $(CONTEXT)/Containerfile.linux $(CONTEXT)
	${CONTAINER_MANAGER} build --platform linux/amd64 --manifest $(MANIFEST)-linux-amd64 -f $(CONTEXT)/Containerfile.linux $(CONTEXT)
	${CONTAINER_MANAGER} build -t $(MANIFEST)-windows -f $(CONTEXT)/Containerfile.non-linux --build-arg=OS=windows $(CONTEXT)
	${CONTAINER_MANAGER} build -t $(MANIFEST)-darwin -f $(CONTEXT)/Containerfile.non-linux --build-arg=OS=darwin $(CONTEXT)

crc-builder-oci-save: MANIFEST=$(CRC_BUILDER):$(CRC_BUILDER_V)
crc-builder-oci-save: ARM64D=$(shell ${CONTAINER_MANAGER} manifest inspect ${MANIFEST}-linux-arm64 | jq '.manifests[0].digest')
crc-builder-oci-save:
	${CONTAINER_MANAGER} manifest annotate --arch amd64 $(MANIFEST)-linux-arm64 $(ARM64D)
	${CONTAINER_MANAGER} save -m -o $(CRC_BUILDER_SAVE)-linux-amd64.tar $(MANIFEST)-linux-amd64
	${CONTAINER_MANAGER} save -m -o $(CRC_BUILDER_SAVE)-linux-arm64.tar $(MANIFEST)-linux-arm64
	${CONTAINER_MANAGER} save -o $(CRC_BUILDER_SAVE)-windows.tar $(MANIFEST)-windows
	${CONTAINER_MANAGER} save -o $(CRC_BUILDER_SAVE)-darwin.tar $(MANIFEST)-darwin

crc-builder-oci-load:
	${CONTAINER_MANAGER} load -i $(CRC_BUILDER_SAVE)-linux-arm64.tar 
	${CONTAINER_MANAGER} load -i $(CRC_BUILDER_SAVE)-linux-amd64.tar 
	${CONTAINER_MANAGER} load -i $(CRC_BUILDER_SAVE)-windows.tar 
	${CONTAINER_MANAGER} load -i $(CRC_BUILDER_SAVE)-darwin.tar 

crc-builder-oci-push: MANIFEST=$(CRC_BUILDER):$(CRC_BUILDER_V)
crc-builder-oci-push:
	${CONTAINER_MANAGER} push $(MANIFEST)-linux-arm64
	${CONTAINER_MANAGER} push $(MANIFEST)-linux-amd64
	${CONTAINER_MANAGER} manifest create $(MANIFEST)-linux
	${CONTAINER_MANAGER} manifest add $(MANIFEST)-linux docker://$(MANIFEST)-linux-arm64
	${CONTAINER_MANAGER} manifest add $(MANIFEST)-linux docker://$(MANIFEST)-linux-amd64
	${CONTAINER_MANAGER} manifest push --all $(MANIFEST)-linux
	${CONTAINER_MANAGER} push $(MANIFEST)-windows
	${CONTAINER_MANAGER} push $(MANIFEST)-darwin

crc-builder-tkn-create:
	$(call tkn_template,$(CRC_BUILDER),$(CRC_BUILDER_V),crc-builder,crc-builder-installer)
	$(call tkn_template,$(CRC_BUILDER),$(CRC_BUILDER_V),crc-builder,crc-builder)
	$(call tkn_template,$(CRC_BUILDER),$(CRC_BUILDER_V),crc-builder,crc-builder-arm64)

crc-builder-tkn-push: install-out-of-tree-tools
ifndef IMAGE
	IMAGE = $(CRC_BUILDER):$(CRC_BUILDER_V)
endif
	$(TOOLS_BINDIR)/tkn bundle push $(IMAGE)-tkn \
		-f crc-builder/tkn/crc-builder-installer.yaml \
		-f crc-builder/tkn/crc-builder.yaml \ 
		-f crc-builder/tkn/crc-builder-arm64.yaml

#### crc-support ####

.PHONY: crc-support-oci-build crc-support-oci-save crc-support-oci-load crc-support-oci-push crc-support-tkn-create crc-support-tkn-push

# Registries and versions
CRC_SUPPORT ?= $(shell sed -n 1p crc-support/release-info)
CRC_SUPPORT_V ?= v$(shell sed -n 2p crc-support/release-info)
CRC_SUPPORT_SAVE ?= crc-support

crc-support-oci-build: CONTEXT=crc-support/oci
crc-support-oci-build: MANIFEST=$(CRC_SUPPORT):$(CRC_SUPPORT_V)
crc-support-oci-build:
	${CONTAINER_MANAGER} build -t $(MANIFEST)-linux -f $(CONTEXT)/Containerfile --build-arg=OS=linux $(CONTEXT)
	${CONTAINER_MANAGER} build -t $(MANIFEST)-windows -f $(CONTEXT)/Containerfile --build-arg=OS=windows $(CONTEXT)
	${CONTAINER_MANAGER} build -t $(MANIFEST)-darwin -f $(CONTEXT)/Containerfile --build-arg=OS=darwin $(CONTEXT)

crc-support-oci-save: MANIFEST=$(CRC_SUPPORT):$(CRC_SUPPORT_V)
crc-support-oci-save:
	${CONTAINER_MANAGER} save -o $(CRC_SUPPORT_SAVE)-linux.tar $(MANIFEST)-linux
	${CONTAINER_MANAGER} save -o $(CRC_SUPPORT_SAVE)-windows.tar $(MANIFEST)-windows
	${CONTAINER_MANAGER} save -o $(CRC_SUPPORT_SAVE)-darwin.tar $(MANIFEST)-darwin

crc-support-oci-load:
	${CONTAINER_MANAGER} load -i $(CRC_SUPPORT_SAVE)-linux.tar 
	${CONTAINER_MANAGER} load -i $(CRC_SUPPORT_SAVE)-windows.tar 
	${CONTAINER_MANAGER} load -i $(CRC_SUPPORT_SAVE)-darwin.tar 

crc-support-oci-push: MANIFEST=$(CRC_SUPPORT):$(CRC_SUPPORT_V)
crc-support-oci-push:
	${CONTAINER_MANAGER} push $(MANIFEST)-linux
	${CONTAINER_MANAGER} push $(MANIFEST)-windows
	${CONTAINER_MANAGER} push $(MANIFEST)-darwin

crc-support-tkn-create:
	$(call tkn_template,$(CRC_SUPPORT),$(CRC_SUPPORT_V),crc-support,task)

crc-support-tkn-push: install-out-of-tree-tools
ifndef IMAGE
	IMAGE = $(CRC_SUPPORT):$(CRC_SUPPORT_V)
endif
	$(TOOLS_BINDIR)/tkn bundle push $(IMAGE)-tkn \
		-f crc-support/tkn/task.yaml


#### s3-uploader ####

.PHONY: s3-uploader-oci-build s3-uploader-tkn-create

S3_IMAGE ?= $(shell sed -n 1p s3-uploader/release-info)
S3_VERSION ?= v$(shell sed -n 2p s3-uploader/release-info)
S3_SAVE ?= s3-uploader

s3-uploader-oci-build: CONTEXT=s3-uploader/oci
s3-uploader-oci-build: MANIFEST=$(S3_IMAGE):$(S3_VERSION)
s3-uploader-oci-build:
	${CONTAINER_MANAGER} build -t $(MANIFEST) -f $(CONTEXT)/Containerfile $(CONTEXT)

s3-uploader-oci-save:  MANIFEST=$(S3_IMAGE):$(S3_VERSION)
s3-uploader-oci-save:
	${CONTAINER_MANAGER} save -o $(S3_SAVE).tar $(MANIFEST)

s3-uploader-oci-push: MANIFEST=$(S3_IMAGE):$(S3_VERSION)
s3-uploader-oci-push:
	${CONTAINER_MANAGER} push $(MANIFEST)

s3-uploader-tkn-create:
	$(call tkn_template,$(S3_IMAGE),$(S3_VERSION),s3-uploader,task)