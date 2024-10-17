VERSION ?= 1.0.0
CONTAINER_MANAGER ?= podman

# Image URL to use all building/pushing image targets
IMG ?= quay.io/rhqp/crc-e2e-tkn:v${VERSION}

# Helpers
TOOLS_DIR := ./../tools
include ./../tools/tools.mk

# Create tekton task bundle
.PHONY: tkn-push
tkn-push: install-out-of-tree-tools
	$(TOOLS_BINDIR)/tkn bundle push $(IMG) \
	-f crc-e2e.yaml
