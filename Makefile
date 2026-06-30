.DEFAULT_GOAL := help
.PHONY: help get format analyze test check publish-dry publish version

VERSION := $(shell grep '^version:' pubspec.yaml | awk '{print $$2}')

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

version: ## Print the current package version
	@echo "$(VERSION)"

get: ## Install dependencies
	flutter pub get

format: ## Format code
	dart format lib/

analyze: ## Run the linter
	flutter analyze

test: ## Run tests (skipped if no test/ directory)
	@if [ -d test ]; then flutter test; else echo "No test/ directory — skipping."; fi

check: get analyze ## Run all pre-publish checks (deps, lint)

publish-dry: check ## Validate the package without publishing (dry run)
	flutter pub publish --dry-run

publish: check ## Publish $(VERSION) to pub.dev
	@echo "Publishing hyperpay_sdk $(VERSION) to pub.dev..."
	flutter pub publish
