---
name: development-workflow
description: "Development workflow and best practices for dotfiles, shell scripts, config files, and documentation. Use when: working on system setup scripts, bash/shell scripting, configuration management, or documentation writing."
applyTo:
  - "**/*.sh"
  - "**/*.zsh"
  - "**/*.csh"
  - "**/*.bash"
  - "**/*rc"
  - "**/*.conf"
  - "**/*.config"
  - "**/*.md"
  - "**/*.txt"
  - "**/*.py"
  - "**/setup*"
  - "**/install*"
---

# Development Workflow Instructions

## Shell Scripting Best Practices

### Error Handling & Safety

- Always use proper error handling in scripts: `set -euo pipefail` at the beginning of bash scripts
- Check file existence before operations: `[ -f ~/.ssh/config ] && ! grep -q ...`
- Add error redirection to prevent hanging: `2>/dev/null` when appropriate
- Use `source file 2>/dev/null || true` for safe file sourcing
- Prefer `return 1` over `exit` in functions to prevent abrupt termination

### Bash-Specific Issues

- For ARM architectures, avoid interactive bash if possible - use zsh as default shell
- Use simple interactive shell checks: `case $- in *i*) ;; *) return;; esac`
- Only set exit traps for interactive shells: `if [[ $- == *i* ]]; then trap _exit EXIT; fi`
- Handle trap errors gracefully with fallback timestamps in logging functions

### Directory Operations

- Always check directories exist before `cd` operations
- Use `pushd/popd` for directory stack management when navigating multiple locations
- Provide graceful fallbacks when directories don't exist

## Configuration Management

### File Organization

- Group related configuration by purpose (shell, editor, system, etc.)
- Use symlinks for dotfiles to maintain single source of truth
- Document any platform-specific configurations clearly

### Cross-Platform Considerations

- Separate platform-specific setup into dedicated directories (MacOS/, Windows/, etc.)
- Use conditional logic for platform differences
- Test scripts on target platforms before deployment

## Documentation Standards

### README Files

- Include clear installation/setup instructions
- Document any prerequisites or dependencies
- Provide troubleshooting section for common issues
- Keep examples practical and tested

### Code Comments

- Explain WHY not just WHAT (especially for complex shell logic)
- Document any workarounds for platform-specific issues
- Include references to related files or configurations

## Python Scripts

- Use proper error handling and logging
- Include docstrings for functions and modules
- Add shebang line for executable scripts: `#!/usr/bin/env python3`
- Use type hints where beneficial for clarity

## Version Control

- Use meaningful commit messages that explain the change
- Keep commits focused on single logical changes
- Document breaking changes in commit messages
- Use `.gitignore` to exclude generated files and local configs

## Testing & Validation

- Test setup scripts in clean environments when possible
- Use `timeout` commands for potentially hanging operations: `timeout 10 bash -l`
- Validate scripts with `bash --norc` to test without .bashrc interference
- Check for common issues: file permissions, path dependencies, environment variables
