# Display help by default.
.DEFAULT_GOAL := help

# Require bash to use foreach loops.
SHELL := bash

# For text display in the shell.
RESET = $(shell tput sgr0)
RED = $(shell tput setaf 9)
BLUE = $(shell tput setaf 6)
TARGET_MAX_CHAR_NUM = 30

# Some targets will only be included if the appropriate condition is met.
SSH_AGENT_RUNNING := $(shell test -S "$${SSH_AUTH_SOCK}" && echo "true")

# For some commands we must invoke a Windows executable if in the context of WSL.
IS_WSL := $(shell grep -q WSL /proc/version 2>/dev/null && echo "true")

# Display text for requirements.
README_MESSAGE = ${BLUE}Consult the README.md for how to install requirements.${RESET}\n

# Bash snippet to check for the existance an executable.
define executable-exists
	@if ! command -v $(1) >/dev/null; \
	then \
		printf "${RED}Could not find executable: %s${RESET}\n${README_MESSAGE}" $(1); \
		exit 1; \
	fi
endef

# Used to include host-platform specific docker compose files.
OS := $(shell uname -s | tr A-Z a-z)

# Used to set TAGS when no explicit value is provided and to fetch branch-specific
# remote caches. Keep it aligned with the metadata helper's Docker-tag fallback
# normalization so names such as feature/foo produce valid cache references.
# Pipe the ref directly into the normalizer so branch text is never re-evaluated
# as part of a generated shell command.
BRANCH = $(shell git -c safe.directory='$(CURDIR)' rev-parse --abbrev-ref HEAD | sed -E 's/[^A-Za-z0-9_.-]+/-/g; s/^-+//; s/-+$$//')

# The buildkit builder to use.
BUILDER ?= default

# Were to push/pull from.
REPOSITORY ?= lehighlts

PROGRESS ?= auto

# Were to push/pull cache from.
CACHE_FROM_REPOSITORY ?= $(REPOSITORY)
CACHE_TO_REPOSITORY ?= $(REPOSITORY)

# Go command used by the local metadata and test helpers.
GO ?= $(shell command -v go 2>/dev/null || { test -x /usr/local/go/bin/go && printf /usr/local/go/bin/go; })

# Tags to apply to all images loaded or pushed, space delimited.
TAGS ?= local

# Targets in `docker-bake.hcl` to build if requested.
TARGET ?= default

# Contexts can be used to override bake contexts when building
# reducing build times, etc. See the GitHub actions for an example.
CONTEXTS ?=

# CI sets this for the base image so apk repositories are consulted on every
# published rebuild instead of trusting a potentially stale registry cache.
BASE_NO_CACHE ?= false

# All images should be included in the bake files default target.
# It is the source of truth.
ALL_IMAGES = $(shell docker buildx bake --print default 2>/dev/null | jq -r '.target[].context')
TARGET_IMAGES = $(shell docker buildx bake --print $(TARGET) 2>/dev/null | jq -r '.target[].context')
TEST_IMAGE ?= $(if $(filter default,$(TARGET)),,$(TARGET))
TEST_MODE ?= fallback
TEST_ARGS ?=

build:
	mkdir -p build

# Executable prerequisites are explicit so a misspelled target retains Make's
# useful "No rule to make target" error.
.PHONY: docker jq login
docker jq login:
	$(call executable-exists,$@)

# Prior to building, all folders which might be copied into Docker images must
# have the executable bit set for all users. So that they can be read by the
# users we create like 'tomcat'. We can not insure this via Git as it does
# not track permissions for folders, so we rely on this hack.
.PHONY: folder-permissions
folder-permissions:
	find images -type d -exec chmod +x {} \;

# Prior to building, all scripts which might be copied into Docker images must
# have the executable bit set for all users. So that they can be executed by
# the users we create like 'nginx'. We can not insure this via Git as it does
# not track executable permissions for "groups" or "others".
.PHONY: executable-permissions
executable-permissions:
	find images -type f \
    \( \
      -name "*.sh" \
      -o -name "run" \
      -o -name "check" \
      -o -name "finish" \
      -o -name "bash.bashrc" \
      -o -name "drush" \
      -o -name "composer" \
    \) \
    -exec chmod +rx {} \;

# Checks for docker buildx plugin.
.PHONY: docker-buildx
docker-buildx: MISSING_DOCKER_BUILDX_PLUGIN_MESSAGE = ${RED}docker buildx plugin is not installed${RESET}\n${README_MESSAGE}
docker-buildx: | docker
  # Check for `docker buildx` as we do not support building without it.
	@if ! docker buildx version &>/dev/null; \
	then \
		printf "$(MISSING_DOCKER_BUILDX_PLUGIN_MESSAGE)"; \
		exit 1; \
	fi

# Prior to building we export the plan and then update it to include contexts,
# etc provided by the environment / user.
# Despite being a real target we make it PHONY so it is run everytime as $(TARGET) can change.
.PHONY: build/bake.json
.SILENT: build/bake.json
build/bake.json: | docker-buildx jq build folder-permissions executable-permissions
	set -x; \
		BRANCH="$(BRANCH)" \
	CACHE_FROM_REPOSITORY=$(CACHE_FROM_REPOSITORY) \
	CACHE_TO_REPOSITORY=$(CACHE_TO_REPOSITORY) \
	BASE_NO_CACHE=$(BASE_NO_CACHE) \
	REPOSITORY=$(REPOSITORY) \
	TAGS="$(TAGS)" \
	docker buildx bake --print $(TARGET) 2>/dev/null > build/bake.json; \
	for context in $(CONTEXTS); \
	do \
		echo "$${context}}"; context_image="$${context%%=*}"; \
		context_ref="$${context#*=}"; \
		if [ "$${context_image}" = "$${context_ref}" ]; then \
			context_image=$$(sed 's/^docker-image:\/\/[^\/]*\/\([^\/@:]*\).*/\1/' <<< $${context}); \
			context_ref="$${context}"; \
		fi; \
		jq --arg context_image "$${context_image}" --arg context_ref "$${context_ref}" 'walk(if type == "object" and .contexts[$$context_image] then .contexts[$$context_image] = $$context_ref else . end)' build/bake.json > build/tmp.bake.json; \
		cp build/tmp.bake.json build/bake.json; \
		rm build/tmp.bake.json; \
	done
  # Remove unreferenced targets, as they complicate generating the manifest, etc.
	docker buildx bake --print -f build/bake.json 2>/dev/null > build/tmp.bake.json
	cp build/tmp.bake.json build/bake.json
	rm build/tmp.bake.json

.SILENT: build/manifests.json
build/manifests.json: build/bake.json
	jq '[.target[].tags[]] | reduce .[] as $$i ({}; .[$$i | sub("-(arm64|amd64)$$"; "")] = ([$$i] + .[$$i | sub("-(arm64|amd64)$$"; "")] | sort))' build/bake.json > build/manifests.json

.PHONY: bake
## Builds and loads the target(s) into the local docker context.
bake: build/bake.json
	docker buildx bake --builder $(BUILDER) -f build/bake.json --progress=$(PROGRESS) --load

.PHONY: test
## Runs docker compose tests for built images. Use TARGET=<image> to narrow the run.
test:
	@if [ -z "$(GO)" ]; then printf "Go is required to run tests.\n"; exit 127; fi
	$(GO) run ./cmd/buildkit test \
		$(if $(TEST_IMAGE),--image $(TEST_IMAGE),) \
		$(if $(TEST),--test $(TEST),) \
		--repository "$(REPOSITORY)" \
		--mode "$(TEST_MODE)" \
		--tag "$(firstword $(TAGS))" \
		$(TEST_ARGS)

.PHONY: list-tests
## Lists docker compose tests selected by TARGET=<image>.
list-tests:
	@if [ -z "$(GO)" ]; then printf "Go is required to list tests.\n"; exit 127; fi
	$(GO) run ./cmd/buildkit test --list \
		$(if $(TEST_IMAGE),--image $(TEST_IMAGE),) \
		$(if $(TEST),--test $(TEST),)

.PHONY: push
## Builds and pushes the target(s) into remote repository.
push: build/bake.json login
push:
	docker buildx bake --builder $(BUILDER) -f build/bake.json --progress=$(PROGRESS) --push

.PHONY: manifest
## Creates manifest for multi-arch images.
manifest: build/manifests.json $(filter push,$(MAKECMDGOALS)) | jq
  # Since this is only really used by the Github Actions it's built to assume a single target at a time.
	MANIFESTS=(); \
	while IFS= read -r line; do \
			MANIFESTS+=( "$$line" ); \
	done < <(jq -r '. | to_entries | reduce .[] as $$i ([]; . + ["\($$i.key) \($$i.value | join(" "))"]) | .[]' build/manifests.json); \
	for args in "$${MANIFESTS[@]}"; \
	do \
		docker buildx imagetools create -t $${args}; \
	done
  # After creating the manifests we can fetch the digests to use as contexts in later builds.
	DIGESTS=(); \
	while IFS= read -r line; do \
		DIGESTS+=( "$$line" ); \
	done < <(jq -r 'keys | reduce .[] as $$i ({}; .[$$i | sub("^[^/]+/(?<x>[^@:]+).*$$"; "\(.x)")] = $$i) | to_entries[] | "\(.key) \(.value)"' build/manifests.json); \
	for digest in "$${DIGESTS[@]}"; \
	do \
		args=($${digest}); \
		context=$${args[0]}; \
		image=$${args[1]}; \
		docker buildx imagetools inspect --raw $${image} | shasum -a 256 | cut -f1 -d' ' | tr -d '\n' > build/$${context}.digest; \
	done
