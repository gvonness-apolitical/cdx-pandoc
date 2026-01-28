# cdx-pandoc

Pandoc custom writer for [Codex Document Format](https://github.com/gvonness-apolitical/codex-file-format-spec) (`.cdx`) files.

## Overview

This project provides a Pandoc custom writer that enables conversion from any Pandoc-supported format (Markdown, LaTeX, Word, etc.) to the Codex Document Format. This allows academics, writers, and publishers to leverage their existing workflows while gaining Codex's benefits:

- **Verifiable integrity** - Content-addressable document IDs
- **Semantic structure** - Preserved headings, lists, tables, citations
- **Machine readability** - JSON-based format with well-defined schemas
- **Provenance tracking** - Hash chains for document history

## Installation

```bash
# Clone the repository
git clone https://github.com/gvonness-apolitical/cdx-pandoc.git

# Add to Pandoc's data directory (optional)
cp cdx-pandoc/codex.lua ~/.local/share/pandoc/writers/
```

### Prerequisites

- [Pandoc](https://pandoc.org/installing.html) 3.0 or later
- Lua 5.4 (bundled with Pandoc)

## Usage

### Basic Conversion

```bash
# Convert Markdown to Codex
pandoc document.md -t codex.lua -o document.cdx

# Convert LaTeX to Codex
pandoc paper.tex -t codex.lua -o paper.cdx

# Convert Word to Codex
pandoc report.docx -t codex.lua -o report.cdx
```

### With Metadata

```bash
# Specify title and author
pandoc document.md -t codex.lua \
  --metadata title="My Document" \
  --metadata author="Jane Doe" \
  -o document.cdx
```

### From YAML Front Matter

```markdown
---
title: My Academic Paper
author:
  - Jane Doe
  - John Smith
date: 2025-01-28
abstract: This paper explores...
keywords:
  - research
  - methodology
---

# Introduction

Your content here...
```

## Supported Features

| Pandoc Element | Codex Mapping |
|---------------|---------------|
| Paragraphs | `paragraph` block |
| Headings | `heading` block (levels 1-6) |
| Bullet lists | `list` block (unordered) |
| Numbered lists | `list` block (ordered) |
| Code blocks | `code_block` block |
| Block quotes | `blockquote` block |
| Tables | `table` block |
| Images | `image` block + asset embedding |
| Math (LaTeX) | `math` block |
| Links | Inline marks |
| Bold/Italic | Inline marks |
| Citations | `citation` extension (with citeproc) |

## Metadata Mapping

Pandoc metadata is mapped to Dublin Core:

| Pandoc | Dublin Core |
|--------|-------------|
| `title` | `dc:title` |
| `author` | `dc:creator` |
| `date` | `dc:date` |
| `abstract` | `dc:description` |
| `keywords` | `dc:subject` |
| `lang` | `dc:language` |

## Examples

See the [examples/](examples/) directory for sample conversions.

## Related Projects

- [codex-file-format-spec](https://github.com/gvonness-apolitical/codex-file-format-spec) - Format specification
- [cdx-core](https://github.com/gvonness-apolitical/cdx-core) - Rust library and CLI

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting PRs.

## License

Licensed under either of:

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
