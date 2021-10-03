IMAGE := masnagam/concc-tools

.PHONY: all
all: image

.PHONY: image
image:
	docker buildx build -t $(IMAGE) .
