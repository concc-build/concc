IMAGE := masnagam/concc-tools
BUILD_OPTIONS ?=

.PHONY: all
all: image

.PHONY: image
image:
	docker buildx build -t $(IMAGE) $(BUILD_OPTIONS) .
