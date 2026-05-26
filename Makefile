SHELL := /bin/bash
NAME := wpsite
VERSION := $(shell cat VERSION 2>/dev/null || echo "0.0.0")

BUILD_DIR := .
SRC_DIR := src

LIBS := \
	$(SRC_DIR)/lib/config.sh \
	$(SRC_DIR)/lib/detect_os.sh \
	$(SRC_DIR)/lib/helpers.sh \
	$(SRC_DIR)/lib/ssl.sh

COMMANDS := \
	$(SRC_DIR)/commands/cmd_create.sh \
	$(SRC_DIR)/commands/cmd_list.sh \
	$(SRC_DIR)/commands/cmd_start.sh \
	$(SRC_DIR)/commands/cmd_stop.sh \
	$(SRC_DIR)/commands/cmd_restart.sh \
	$(SRC_DIR)/commands/cmd_remove.sh \
	$(SRC_DIR)/commands/cmd_logs.sh \
	$(SRC_DIR)/commands/cmd_shell.sh \
	$(SRC_DIR)/commands/cmd_go.sh \
	$(SRC_DIR)/commands/cmd_open.sh \
	$(SRC_DIR)/cmd_dns.sh \
	$(SRC_DIR)/cmd_infra.sh

DISPATCHER := $(SRC_DIR)/dispatcher.sh
HEADER := $(SRC_DIR)/main.sh
SRC := $(LIBS) $(COMMANDS) $(DISPATCHER)
BUILD_SCRIPT := $(BUILD_DIR)/$(NAME)

.PHONY: all build install uninstall clean lint test release dev

all: build

build: $(BUILD_SCRIPT)

$(BUILD_SCRIPT): $(SRC) $(HEADER)
	@echo "Building $(NAME) v$(VERSION)..."
	@printf '#!/bin/bash\nset -e\n\n' > $(BUILD_SCRIPT)
	@printf '# =============================================\n' >> $(BUILD_SCRIPT)
	@printf '# %s - WordPress Site Manager\n' "$(NAME)" >> $(BUILD_SCRIPT)
	@printf '# Manage local Docker-based WordPress sites\n' >> $(BUILD_SCRIPT)
	@printf '# Version: %s\n' "$(VERSION)" >> $(BUILD_SCRIPT)
	@printf '# Build: concatenated from src/ modules\n' >> $(BUILD_SCRIPT)
	@printf '# =============================================\n\n' >> $(BUILD_SCRIPT)
	@for f in $(LIBS); do \
		printf '# --- %s ---\n' "$$f" >> $(BUILD_SCRIPT); \
		sed -n '/^#!/d; /^set -e/d; p' "$$f" >> $(BUILD_SCRIPT); \
		printf '\n' >> $(BUILD_SCRIPT); \
	done
	@for f in $(COMMANDS); do \
		printf '# --- %s ---\n' "$$f" >> $(BUILD_SCRIPT); \
		sed -n '/^#!/d; /^set -e/d; p' "$$f" >> $(BUILD_SCRIPT); \
		printf '\n' >> $(BUILD_SCRIPT); \
	done
	@printf '# --- %s ---\n' "$(DISPATCHER)" >> $(BUILD_SCRIPT)
	@sed -n '/^#!/d; /^set -e/d; p' $(DISPATCHER) >> $(BUILD_SCRIPT)
	@chmod +x $(BUILD_SCRIPT)
	@echo "Built $(BUILD_SCRIPT) ($$(wc -l < $(BUILD_SCRIPT)) lines)"

install: build
	@echo "Installing $(NAME)..."
	@if [ -w /usr/local/bin ]; then \
		cp $(BUILD_SCRIPT) /usr/local/bin/$(NAME); \
		echo "Installed to /usr/local/bin/$(NAME)"; \
	else \
		mkdir -p ~/.local/bin; \
		cp $(BUILD_SCRIPT) ~/.local/bin/$(NAME); \
		echo "Installed to ~/.local/bin/$(NAME)"; \
		echo "Make sure ~/.local/bin is in your PATH"; \
	fi

uninstall:
	@echo "Removing $(NAME)..."
	@rm -f /usr/local/bin/$(NAME) ~/.local/bin/$(NAME)
	@echo "Uninstalled"

clean:
	@rm -f $(BUILD_SCRIPT)
	@echo "Cleaned"

lint:
	@echo "Running ShellCheck..."
	@shellcheck $(SRC) $(HEADER) || echo "ShellCheck found issues"

test: build
	@echo "Smoke tests..."
	./$(BUILD_SCRIPT) --version | grep -q "$(VERSION)" && echo "  version matches" || echo "  version FAILED"
	./$(BUILD_SCRIPT) help | grep -q "USAGE:" && echo "  help works" || echo "  help FAILED"
	./$(BUILD_SCRIPT) nonexistent 2>&1 | grep -q "Unknown command" && echo "  unknown command handled" || echo "  unknown command FAILED"
	@echo "Smoke tests done"

dev:
	@echo "Development mode: ./src/main.sh <command>"
	@./src/main.sh --version

release: clean build test
	@echo "Ready for release: $(BUILD_SCRIPT)"
	@echo "  Tag: v$(VERSION)"
	@shasum -a 256 $(BUILD_SCRIPT)

.PHONY: set-version
set-version:
	@if [ -z "$(NEW_VERSION)" ]; then \
		echo "Usage: make set-version NEW_VERSION=1.4.0"; \
		exit 1; \
	fi
	@echo "Updating version to $(NEW_VERSION)..."
	@printf '%s' "$(NEW_VERSION)" > VERSION
	@echo "  Updated VERSION"
	@sed -i '' 's/^VERSION=".*"/VERSION="$(NEW_VERSION)"/' src/lib/config.sh
	@echo "  Updated src/lib/config.sh"
	@sed -i '' 's/^# Version: .*/# Version: $(NEW_VERSION)/' src/lib/config.sh
	@sed -i '' 's/^# Version: .*/# Version: $(NEW_VERSION)/' src/main.sh
	@echo "  Updated src/main.sh header"
	@$(MAKE) build
	@echo "Version updated to $(NEW_VERSION), rebuilt"