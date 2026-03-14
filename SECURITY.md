# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 0.7.x   | :white_check_mark: |
| < 0.7.0 | :x:                |

Only the latest patch release of the current minor version receives security updates.

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public issue.
2. Email the maintainers or use [GitHub Security Advisories](https://github.com/Entrolution/cdx-pandoc/security/advisories/new) to report privately.
3. Include a description of the vulnerability, steps to reproduce, and any potential impact.

We will acknowledge receipt within 48 hours and aim to provide a fix or mitigation plan within 7 days.

## Scope

cdx-pandoc is a document conversion tool that processes untrusted input (Markdown, LaTeX, Word, etc.) via Pandoc. Security considerations include:

- **Input handling**: The Lua writer processes Pandoc AST structures. Malformed input is handled by Pandoc's parser before reaching this code.
- **Shell script**: `scripts/pandoc-to-cdx.sh` invokes external tools (`pandoc`, `jq`, `sha256sum`, `zip`). File paths are quoted to prevent injection.
- **No network access**: The writer and reader operate entirely offline with no network calls.
- **No code execution**: The writer produces static JSON output. No user-supplied code is evaluated.
