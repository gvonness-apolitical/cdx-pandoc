# Makefile for Codex Pandoc Writer

PANDOC := pandoc
WRITER := codex.lua
JQ := jq

# Test input files
TEST_INPUTS := $(wildcard tests/inputs/*.md)
TEST_OUTPUTS := $(patsubst tests/inputs/%.md,tests/outputs/%.json,$(TEST_INPUTS))
TEST_CDX := $(patsubst tests/inputs/%.md,tests/outputs/%.cdx,$(TEST_INPUTS))

.PHONY: all test clean test-json test-cdx test-reader test-unit test-golden help check-deps validate-schema lint

all: test

help:
	@echo "Codex Pandoc Writer"
	@echo ""
	@echo "Targets:"
	@echo "  test         Run all tests (unit + JSON output)"
	@echo "  test-unit    Run Lua unit tests"
	@echo "  test-cdx     Run full pipeline tests (creates .cdx files)"
	@echo "  test-reader  Test round-trip (JSON → Pandoc → markdown)"
	@echo "  test-golden  Compare outputs against golden baselines"
	@echo "  lint         Run luacheck linter"
	@echo "  validate-schema Validate against spec schemas"
	@echo "  clean        Remove generated files"
	@echo "  check-deps   Check for required dependencies"
	@echo ""
	@echo "Examples:"
	@echo "  make test"
	@echo "  make test-cdx"
	@echo "  $(PANDOC) input.md -t $(WRITER) -o output.json"

check-deps:
	@command -v $(PANDOC) >/dev/null 2>&1 || { echo "Error: pandoc not found"; exit 1; }
	@command -v $(JQ) >/dev/null 2>&1 || { echo "Error: jq not found"; exit 1; }
	@echo "All dependencies found."

# Create outputs directory
tests/outputs:
	mkdir -p tests/outputs

# Test JSON output from writer
test-json: check-deps tests/outputs $(TEST_OUTPUTS)
	@echo "JSON tests complete."

tests/outputs/%.json: tests/inputs/%.md $(WRITER) lib/*.lua
	@echo "Converting $< -> $@"
	@$(PANDOC) $< -t $(WRITER) -o $@
	@$(JQ) '.content.blocks | length' $@ > /dev/null && echo "  Valid JSON with $$($(JQ) '.content.blocks | length' $@) blocks"

# Test full pipeline
test-cdx: check-deps tests/outputs $(TEST_CDX)
	@echo "CDX pipeline tests complete."

tests/outputs/%.cdx: tests/inputs/%.md $(WRITER) lib/*.lua scripts/pandoc-to-cdx.sh
	@echo "Creating CDX: $< -> $@"
	@./scripts/pandoc-to-cdx.sh $< $@

# Run unit tests
# Use lua5.4 on Linux (CI), lua on macOS
LUA := $(shell command -v lua5.4 2>/dev/null || command -v lua 2>/dev/null || echo lua)

test-unit:
	@echo "Running unit tests..."
	@$(LUA) tests/unit/test_json.lua
	@$(LUA) tests/unit/test_lib_utils.lua

# Run all tests
test: test-unit test-json
	@echo ""
	@echo "All tests passed!"

# Validate JSON structure
validate: test-json
	@echo "Validating JSON structure..."
	@for f in tests/outputs/*.json; do \
		echo "Checking $$f..."; \
		$(JQ) -e '.manifest and .content and .dublin_core' $$f > /dev/null || { echo "FAIL: $$f missing required sections"; exit 1; }; \
		$(JQ) -e '.content.version and .content.blocks' $$f > /dev/null || { echo "FAIL: $$f invalid content structure"; exit 1; }; \
		$(JQ) -e '.dublin_core.version and .dublin_core.terms' $$f > /dev/null || { echo "FAIL: $$f invalid dublin_core structure"; exit 1; }; \
		echo "  OK"; \
	done
	@echo "Validation complete."

# Test reader round-trip: JSON → Pandoc → markdown
test-reader: test-json
	@echo "Testing round-trip..."
	@for f in tests/outputs/*.json; do \
		base=$$(basename $$f .json); \
		echo "Round-trip: $$base"; \
		$(PANDOC) -f cdx-reader.lua $$f -t markdown > tests/outputs/$$base.roundtrip.md 2>/dev/null && echo "  OK" || echo "  FAIL"; \
	done
	@echo "Reader tests complete."

# Validate against spec schemas (requires ../codex-file-format-spec/schemas/)
SCHEMA_DIR := ../codex-file-format-spec/schemas

validate-schema: test-json
	@if [ ! -d "$(SCHEMA_DIR)" ]; then \
		echo "Schema directory not found: $(SCHEMA_DIR)"; \
		echo "Skipping schema validation (clone codex-file-format-spec alongside this repo)"; \
		exit 0; \
	fi
	@echo "Validating against spec schemas..."
	@for f in tests/outputs/*.json; do \
		echo "Checking $$f..."; \
		$(JQ) -e '.manifest.codex' $$f > /dev/null || { echo "  WARN: no manifest.codex version"; continue; }; \
		$(JQ) -e '.content.blocks | type == "array"' $$f > /dev/null || { echo "  FAIL: content.blocks is not an array"; exit 1; }; \
		$(JQ) -e '.dublin_core.terms | type == "object"' $$f > /dev/null || { echo "  FAIL: dublin_core.terms is not an object"; exit 1; }; \
		$(JQ) -e '[.content.blocks[] | .type] | all(. != null and . != "")' $$f > /dev/null || { echo "  FAIL: block missing type field"; exit 1; }; \
		echo "  OK"; \
	done
	@echo "Schema validation complete."

# Compare outputs against golden baselines (strips non-deterministic fields before diff)
test-golden: test-json
	@echo "Comparing against golden outputs..."
	@fail=0; for f in tests/outputs/*.json; do \
		base=$$(basename $$f); \
		if [ -f tests/expected/$$base ]; then \
			$(JQ) -S 'del(.manifest.created, .manifest.modified)' $$f > $$f.sorted; \
			diff -q $$f.sorted tests/expected/$$base > /dev/null 2>&1 || { echo "DIFF: $$base"; diff tests/expected/$$base $$f.sorted | head -20; fail=1; }; \
			rm -f $$f.sorted; \
		fi; \
	done; \
	[ $$fail -eq 0 ] && echo "All golden tests passed." || { echo "Golden test failures detected."; exit 1; }

# Regenerate golden baselines from current outputs
update-golden: test-json
	@echo "Updating golden baselines..."
	@mkdir -p tests/expected
	@for f in tests/outputs/*.json; do \
		base=$$(basename $$f); \
		$(JQ) -S 'del(.manifest.created, .manifest.modified)' $$f > tests/expected/$$base; \
	done
	@echo "Golden baselines updated."

# Lint Lua files
lint:
	luacheck codex.lua cdx-reader.lua lib/

# Clean generated files
clean:
	rm -rf tests/outputs

# Development: watch for changes and run tests
watch:
	@echo "Watching for changes... (Ctrl+C to stop)"
	@while true; do \
		$(MAKE) test-json 2>&1 || true; \
		sleep 2; \
	done

# Print a sample conversion
sample:
	@echo "Sample conversion of tests/inputs/basic.md:"
	@echo ""
	@$(PANDOC) tests/inputs/basic.md -t $(WRITER) | $(JQ) '.'
