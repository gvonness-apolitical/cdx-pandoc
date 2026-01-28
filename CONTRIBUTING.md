# Contributing to cdx-pandoc

Thank you for your interest in contributing to cdx-pandoc! This document provides guidelines and information for contributors.

## Code of Conduct

This project follows the [Rust Code of Conduct](https://www.rust-lang.org/policies/code-of-conduct). Please be respectful and constructive in all interactions.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/cdx-pandoc.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Run tests: `make test`
6. Commit your changes
7. Push to your fork and submit a pull request

## Development Setup

### Prerequisites

- [Pandoc](https://pandoc.org/installing.html) 3.0 or later
- Lua 5.4 (bundled with Pandoc)
- [cdx-cli](https://github.com/gvonness-apolitical/cdx-core) (optional, for validation)

### Testing

```bash
# Run all tests
make test

# Test with a specific input file
pandoc input.md -t codex.lua -o output.cdx
```

## Pull Request Guidelines

### Before Submitting

- [ ] Code follows the existing style
- [ ] All tests pass
- [ ] Documentation is updated if needed
- [ ] CHANGELOG.md is updated for user-facing changes

### PR Description

Please include:

- **What**: Brief description of the change
- **Why**: Motivation for the change
- **How**: High-level approach (if not obvious)
- **Testing**: How you tested the changes

### Commit Messages

Follow conventional commit format:

```
type(scope): short description

Longer description if needed.

Fixes #123
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## Architecture Overview

```
cdx-pandoc/
├── codex.lua           # Main Pandoc custom writer
├── lib/                # Lua helper modules
│   ├── blocks.lua      # Block type converters
│   ├── inlines.lua     # Inline/text node converters
│   ├── metadata.lua    # Dublin Core metadata extraction
│   └── json.lua        # JSON encoding utilities
├── scripts/
│   └── pandoc-to-cdx.sh  # Full pipeline wrapper
├── tests/              # Test files
│   ├── inputs/         # Test input documents
│   └── outputs/        # Generated test outputs
└── Makefile
```

## Specification Reference

This writer implements the [Codex Document Format Specification](https://github.com/gvonness-apolitical/codex-file-format-spec). When implementing new features:

- Reference the relevant spec section
- Note any deviations or extensions
- Consider edge cases mentioned in the spec

## Questions?

- Open an issue for bugs or feature requests
- Use discussions for general questions

Thank you for contributing!
