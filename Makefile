REGISTRY?=ghcr.io/alexsjones
IMAGE_NAME?=kflow-daemon
IMAGE_TAG?=latest
IMAGE?=$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
DOCKERFILE?=Dockerfile.daemon
CONNTRACK_PATH?=/proc/net/nf_conntrack
PLATFORMS?=linux/amd64,linux/arm64
BUILDER_NAME?=kflow-builder

.PHONY: build docker-build docker-push k8s-apply k8s-delete clean

# Build the Rust binary (release)
build:
	cargo build --release --bin daemon

# Build docker image (will call build first to ensure binary is ready)
docker-build: build
	docker build -t $(IMAGE) -f $(DOCKERFILE) .

# Push image to registry. Provide REGISTRY variable (e.g. REGISTRY=ghcr.io/you)
docker-push:
	@if [ "$(REGISTRY)" = "" ]; then \
		echo "Set REGISTRY to push (e.g. REGISTRY=ghcr.io/you)"; exit 1; \
	fi
	docker push $(IMAGE)


# Build multi-arch image using docker buildx and push to registry.
# Requires that you've logged in to your registry (docker login) or set appropriate creds.
# Usage: make docker-buildx REGISTRY=ghcr.io/you IMAGE_TAG=1.2.3
docker-buildx: build
	@echo "Using buildx builder '$(BUILDER_NAME)' (creating if missing)"
	@docker buildx inspect $(BUILDER_NAME) >/dev/null 2>&1 || docker buildx create --name $(BUILDER_NAME) --use
	@echo "Building for: $(PLATFORMS) -> $(IMAGE)"
	@docker buildx build --platform $(PLATFORMS) -t $(IMAGE) -f $(DOCKERFILE) --push .

# Apply the DaemonSet to the cluster; this replaces the image placeholder with $(IMAGE)

k8s-apply:
	@sed "s|REPLACE_IMAGE|$(IMAGE)|g; s|REPLACE_CONNTRACK|$(CONNTRACK_PATH)|g" k8s/daemonset.yaml | kubectl apply -f -

k8s-delete:
	@sed "s|REPLACE_IMAGE|$(IMAGE)|g; s|REPLACE_CONNTRACK|$(CONNTRACK_PATH)|g" k8s/daemonset.yaml | kubectl delete -f -

clean:
	cargo clean
