# Make targets for the pwsh-mcp PowerShell MCP module
# Default target: help (run `make` or `make help` for usage)

# The ci.ps1 script orchestrates build, test, analyze, and deploy actions used by these targets.

# ============================================================================
# Configuration Variables
# ============================================================================

PWSH ?= pwsh

# Default PowerShell flags (override: `make PWSH_FLAGS="..."`)
PWSH_FLAGS ?= -NoLogo -NoProfile

APP_NAME := pwsh-mcp

# Configuration files
CONFIG_ANALYZER := ./config.analyzer.psd1
CI_SCRIPT := ./ci.ps1

# Directories
SRC_DIR := ./src
TEST_DIR := ./tests
SCRIPTS_DIR := ./scripts
COVERAGE_DIR := ./coverage
LOG_DIR := ./logs

# ============================================================================
# PHONY Targets Declaration
# ============================================================================

.PHONY: \
	help hello \
	test \
    lint lint_severity_error lint_severity_warning format \
	ci-action-build ci-action-test ci-action-analyze \
    deploy build \
    git-push-tags \
    clean

# ============================================================================
# Help & Info
# ============================================================================

help: ## Show help
	@echo "Usage: make [target]"

hello: ## CI script hello (dry-run example)
	# With WhatIf (Dry-Run) Option
	@echo "Hello"
	$(PWSH) $(PWSH_FLAGS) -File $(CI_SCRIPT) -action hello -WhatIf

test: ## Run unit tests (alias for ci-action-test)
	@$(MAKE) ci-action-test

# ============================================================================
# CI Actions
# ============================================================================

ci-action-test: ## Run tests (via ci.ps1)
	@echo "CI: test"
	$(PWSH) $(PWSH_FLAGS) -File $(CI_SCRIPT) -action test

ci-action-analyze: ## Run code analysis (via ci.ps1)
	@echo "CI: analyze"
	$(PWSH) $(PWSH_FLAGS) -File $(CI_SCRIPT) -action analyze

ci-action-build: ## Build project (via ci.ps1)
	@echo "CI: build"
	$(PWSH) $(PWSH_FLAGS) -File $(CI_SCRIPT) -action build

ci-action-deploy: ## Deploy project (via ci.ps1) - FIXME: ci.ps1 does not support deploy
	@echo "CI: deploy"
	$(PWSH) $(PWSH_FLAGS) -File $(CI_SCRIPT) -action deploy

# ============================================================================
# Development Actions (Jarvis)
# ============================================================================

build: ## Build package (Jarvis)
	@echo "Create a new version of package..."
	$(PWSH) $(PWSH_FLAGS) -File jarvis.ps1 -action build

deploy: ## Deploy from local repository (Jarvis)
	@echo "Deploy module from local repository..."
	$(PWSH) $(PWSH_FLAGS) -File jarvis.ps1 -action deploy

git-push-tags: ## Push Git tags
	@echo "Pushing all Git tags..."
	git push --tags

# ============================================================================
# Code Quality: Linting & Formatting
# ============================================================================

lint: ## Run ScriptAnalyzer (default)
	@echo "Running ScriptAnalyzer (default)..."
	$(PWSH) $(PWSH_FLAGS) -Command "Invoke-ScriptAnalyzer -Path $(SRC_DIR) -Recurse"

lint_severity_error: ## Run ScriptAnalyzer (Severity=Error)
	@echo "Running ScriptAnalyzer (severity=Error)..."
	$(PWSH) $(PWSH_FLAGS) -Command "Invoke-ScriptAnalyzer -Path $(SRC_DIR) -Recurse -Severity Error"

lint_severity_warning: ## Run ScriptAnalyzer (Severity=Warning)
	@echo "Running ScriptAnalyzer (severity=Warning)..."
	$(PWSH) $(PWSH_FLAGS) -Command "Invoke-ScriptAnalyzer -Path $(SRC_DIR) -Recurse -Severity Warning"

format: ## Format PowerShell sources (Invoke-Formatter)
	@echo "Formatting files..."
	$(PWSH) $(PWSH_FLAGS) -Command "Invoke-Formatter -Path $(SRC_DIR) -Recurse -Settings $(CONFIG_ANALYZER)"

# ============================================================================
# Utilities
# ============================================================================

clean: ## Remove coverage/log artifacts (safe)
	@echo "Cleaning up coverage and build artifacts..."
	$(PWSH) $(PWSH_FLAGS) -Command "gci -Path $(COVERAGE_DIR) -Recurse -File | Remove-Item"
	$(PWSH) $(PWSH_FLAGS) -Command "gci -Path $(LOG_DIR) -Recurse -File | Remove-Item"

mc-inspector: ## Launch MCP Inspector (requires Node.js + npx)
	@echo "Launching Model Context Protocol Inspector..."
	npx @modelcontextprotocol/inspector pwsh -NoProfile -NoLogo -file src/server1.ps1
