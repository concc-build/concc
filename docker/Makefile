NAMES := tools sftp sftp-debug icecc-daemon icecc-scheduler
IMAGES := $(addprefix concc-poc/,$(NAMES))
TIMESTAMPS := $(addprefix timestamp.,$(NAMES))

.PHONY: all
all: images

.PHONY: images
images: $(TIMESTAMPS)

timestamp.sftp: Dockerfile.sftp
	docker buildx build -q -t concc-poc/sftp -f $< --build-arg BASE=atmoz/sftp .
	@touch $@

timestamp.sftp-debug: Dockerfile.sftp
	docker buildx build -q -t concc-poc/sftp-debug -f $< --build-arg BASE=corilus/sftp .
	@touch $@

timestamp.%: Dockerfile.%
	docker buildx build -q -t $(subst timestamp.,concc-poc/,$@) -f $< .
	@touch $@

.PHONY: clean
clean:
	@docker image rm -f $(IMAGES) 1>/dev/null 2>/dev/null
	@rm -f $(TIMESTAMPS)
