#!/usr/bin/env bash

set -euox pipefail
cd "$(git rev-parse --show-toplevel)"

# Shell
git ls-files -z -- '*.sh' '*.bash' '*.bats' | xargs -0 -t shellcheck

# Markdown
npx -y prettier -w './**/*.md'

# YAML
git ls-files -z -- '*.yml' '*.yaml' | xargs -0 -t yamllint -d '{"extends": "relaxed", "rules": {"line-length": "disable"}}'

# GitHub Actions
zizmor --fix=safe .github/workflows
git ls-files -z -- '.github/workflows/*.yml' | xargs -0 -t actionlint

# IaC
checkov --framework=all --output=github_failed_only --directory=.
trivy filesystem --scanners vuln,secret,misconfig --skip-dirs .git .
