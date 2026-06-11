# Makefile — reproducible contract checks + codegen for gpufleet/proto.
#
# All tooling is PROJECT-LOCAL (RULES.md §J): `source ../.envrc` first so buf /
# protoc-gen-go come from ../.tools/bin. `make gen` regenerates the committed Go
# bindings (gen/go) + Python bindings (gen/python, gitignored) from the .proto
# source of truth. `make lint` is the CI contract gate.

BUF ?= buf

.PHONY: all lint format breaking gen gen-go-build clean

all: lint gen

## lint: buf lint + format-diff (the contract gate; must be green before a tag)
lint:
	$(BUF) lint
	$(BUF) format --diff

## format: apply canonical formatting in place
format:
	$(BUF) format -w

## breaking: fail on a wire-breaking change vs. the main branch
breaking:
	$(BUF) breaking --against '.git#branch=main'

## gen: regenerate Go (gen/go, committed) + Python (gen/python) bindings
gen:
	$(BUF) generate
	$(MAKE) gen-go-build

## gen-go-build: ensure the generated Go module compiles
gen-go-build:
	cd gen/go && go mod tidy && go build ./... && go vet ./...

## clean: remove generated trees
clean:
	rm -rf gen/python
	rm -rf gen/go/gpufleet
