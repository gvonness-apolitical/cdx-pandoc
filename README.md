# cdx-pandoc

[![CI](https://github.com/gvonness-apolitical/cdx-pandoc/actions/workflows/ci.yml/badge.svg)](https://github.com/gvonness-apolitical/cdx-pandoc/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT%2FApache--2.0-blue.svg)](LICENSE-MIT)

Pandoc custom writer for [Codex Document Format](https://github.com/gvonness-apolitical/codex-file-format-spec) (`.cdx`) files.

## Overview

This writer enables conversion from any Pandoc-supported format (Markdown, LaTeX, Word, etc.) to Codex Document Format. The conversion happens in two phases:

1. **Lua Writer** (`codex.lua`) - Converts Pandoc AST to Codex JSON structures
2. **Packaging** - Shell wrapper creates the final .cdx ZIP archive

## Requirements

- Pandoc 2.11+ (with Lua support)
- jq (for JSON processing)
- sha256sum or shasum (for hashing)
- zip (for archive creation)

## Usage

### Direct JSON Output

Generate the intermediate JSON structure:

```bash
pandoc input.md -t codex.lua -o output.json
```

### Full Pipeline (Recommended)

Create a complete .cdx archive:

```bash
./scripts/pandoc-to-cdx.sh input.md output.cdx
```

### Supported Input Formats

Any format Pandoc can read:
- Markdown (.md)
- LaTeX (.tex)
- Microsoft Word (.docx)
- EPUB (.epub)
- HTML (.html)
- reStructuredText (.rst)
- And many more...

## Reading Codex Documents

Convert Codex JSON back to any Pandoc-supported output format:

```bash
pandoc -f cdx-reader.lua output.json -o document.md
pandoc -f cdx-reader.lua output.json -o document.tex
pandoc -f cdx-reader.lua output.json -o document.html
```

The reader handles core block types (paragraphs, headings, lists, code blocks, blockquotes, tables, math, images, figures, definition lists, admonitions, measurements) and academic extension blocks (theorems, proofs, exercises, algorithms, abstracts, equation groups). Semantic blocks like `semantic:term` and `semantic:ref` are converted to their closest Pandoc equivalents. The reader accepts both namespaced (e.g., `semantic:citation`) and legacy non-namespaced mark formats. Footnotes are restored via inline references. Extension blocks without equivalents (e.g., `semantic:bibliography`, `semantic:glossary`) are skipped.

## Features

### Block Types Supported

| Pandoc | Codex | Notes |
|--------|-------|-------|
| Para | paragraph | Text content |
| Header | heading | Levels 1-6, preserves IDs |
| BulletList | list (ordered=false) | Nested lists supported |
| OrderedList | list (ordered=true) | Start number preserved |
| CodeBlock | codeBlock | Language preserved |
| BlockQuote | blockquote | Nested content |
| HorizontalRule | horizontalRule | Thematic break |
| Table | table | Headers and cells |
| Math (display) | math | LaTeX format, display=true |
| Math (inline) | math mark | LaTeX format on text node |
| DefinitionList | definitionList | Core block with term/description items |
| Span (.measurement) | measurement | Core block: value, unit, display |
| DefinitionList (.glossary) | semantic:term | Glossary Div context only |
| Cite | semantic:citation mark | refs, locator, prefix, suffix, suppressAuthor |
| Note | semantic:footnote | Superscript ref + block content |
| Image | image | src, alt, title, width, height |
| Figure | figure | Container with image children + figcaption |
| Div (.note/.warning/...) | admonition | variant, optional title |
| Div (.theorem/.lemma/...) | academic:theorem | variant, id, number, title |
| Div (.proof) | academic:proof | of, method |
| Div (.exercise) | academic:exercise | difficulty, hints, solution |
| Div (.exercise-set) | academic:exercise-set | title, preamble, exercises |
| Div (.algorithm) | academic:algorithm | title, pseudocode lines |
| Div (.abstract) | academic:abstract | keywords, sections |
| DisplayMath (aligned) | academic:equation-group | Auto-detected align/gather/split |
| Div#refs | semantic:bibliography | Citeproc bibliography entries |
| Div | (unwrapped) | Contents extracted |

### Inline Formatting

| Pandoc | Codex Mark |
|--------|------------|
| Strong | bold |
| Emph | italic |
| Code | code |
| Link | link (with href, title) |
| Link (#thm-*, #lem-*, ...) | academic:theorem-ref |
| Link (#eq-*) | academic:equation-ref |
| Link (#alg-*) | academic:algorithm-ref |
| Math (inline) | math (format: latex, source) |
| Strikeout | strikethrough |
| Underline | underline |
| Superscript | superscript |
| Subscript | subscript |

### Semantic Spans

Pandoc spans with special classes are converted to semantic marks:

#### Entity Linking

Link text to knowledge bases (Wikidata, DBpedia, etc.):

```markdown
[Albert Einstein]{.entity uri="https://www.wikidata.org/wiki/Q937" entityType="Person"}

[Large Hadron Collider]{.entity uri="https://www.wikidata.org/wiki/Q83492" entityType="Place" source="Wikidata"}
```

Produces a `semantic:entity` mark with `uri`, `entityType`, and optional `source` fields.

#### Glossary References

Reference terms defined in a glossary:

```markdown
We discuss [CRDT]{.glossary ref="term-crdt"} technologies.

<!-- Auto-generated ref from text: -->
[eventual consistency]{.glossary}
```

Produces a `semantic:glossary` mark with `ref` field pointing to a `semantic:term` block ID.

#### Measurements

Annotate numeric measurements with units:

```markdown
The sample weighed [42.5 kg]{.measurement value="42.5" unit="kg"}.

Temperature reached [100 °C]{.measurement value="100" unit="°C"}.
```

Produces a core `measurement` block with `value`, `unit`, and `display` (the original text).

### Academic Extension Blocks

Use Pandoc fenced Divs to produce academic block types:

```markdown
::: {.theorem #thm-max title="Maximum Principle"}
Let $u$ be harmonic on $\Omega$. Then $u$ attains its max on the boundary.
:::

::: {.proof of="thm-max" method="contradiction"}
Suppose $u$ attains maximum at interior point...
:::

::: {.exercise #ex-1 difficulty="medium"}
Find the derivative of $f(x) = x^2 + 1$.

::: {.hint}
Use the power rule.
:::

::: {.solution visibility="hidden"}
$f'(x) = 2x$
:::
:::

::: {.algorithm #alg-sort title="QuickSort"}
```algorithm
function QuickSort(A, lo, hi)
  ...
end function
```
:::

::: {.abstract}
This paper presents a novel approach.

::: {.keywords}
machine learning, document formats
:::
:::
```

Theorem variant classes: `theorem`, `lemma`, `proposition`, `corollary`, `definition`, `conjecture`, `remark`, `example`.

Admonition classes: `note`, `warning`, `tip`, `danger`, `important`, `caution`.

Aligned LaTeX environments (`\begin{align}`, `\begin{gather}`, `\begin{split}`) in display math are automatically detected and converted to `academic:equation-group` blocks.

Cross-references to academic blocks use standard Markdown links with `#`-prefixed IDs (e.g., `[Theorem 1](#thm-max)`). Links targeting `#thm-*`, `#lem-*`, `#eq-*`, `#alg-*`, etc. are converted to namespaced reference marks (`academic:theorem-ref`, `academic:equation-ref`, `academic:algorithm-ref`).

### Metadata Mapping

The writer extracts Dublin Core metadata from Pandoc YAML front matter:

| Pandoc | Dublin Core |
|--------|-------------|
| title | title |
| author | creator |
| date | date |
| abstract | description |
| keywords | subject |
| lang | language |
| publisher | publisher |
| rights | rights |

## Output Structure

The writer produces a JSON structure with three sections:

```json
{
  "manifest": {
    "codex": "0.1",
    "id": "pending",
    "state": "draft",
    "created": "2025-01-28T10:00:00Z",
    "modified": "2025-01-28T10:00:00Z",
    "content": {
      "path": "content/document.json",
      "hash": "sha256:..."
    },
    "metadata": {
      "dublinCore": "metadata/dublin-core.json"
    }
  },
  "content": {
    "version": "0.7.0",
    "blocks": [...]
  },
  "dublin_core": {
    "version": "1.1",
    "terms": {...}
  }
}
```

The packaging script extracts these into the proper Codex directory structure.

## Development

### Running Tests

```bash
make test             # Run all tests (unit + JSON output)
make test-unit        # Run Lua unit tests
make validate         # Validate JSON structure
make validate-schema  # Validate against spec schemas
make test-cdx         # Run full pipeline tests
make test-reader      # Test round-trip (JSON → markdown)
```

### Project Structure

```
cdx-pandoc/
├── codex.lua               # Main Pandoc custom writer
├── cdx-reader.lua          # Codex → Pandoc reader
├── lib/
│   ├── blocks.lua          # Writer: block type converters
│   ├── inlines.lua         # Writer: inline/text node converters
│   ├── academic.lua        # Writer: academic extension blocks
│   ├── metadata.lua        # Writer: Dublin Core extraction
│   ├── bibliography.lua    # Writer: CSL bibliography extraction
│   ├── json.lua            # JSON encoding utilities
│   ├── utils.lua           # Shared utility functions
│   ├── reader_blocks.lua   # Reader: block type reverse mapping
│   ├── reader_inlines.lua  # Reader: mark → inline wrapping
│   └── reader_academic.lua # Reader: academic block reverse mapping
├── scripts/
│   └── pandoc-to-cdx.sh    # Full pipeline wrapper
├── tests/
│   ├── inputs/             # Test input files (27 cases)
│   ├── outputs/            # Generated test outputs
│   └── unit/               # Lua unit tests
├── Makefile
└── README.md
```

## Examples

### Basic Markdown

Input (`document.md`):
```markdown
---
title: My Document
author: Jane Doe
date: 2025-01-28
---

# Introduction

This is a **simple** example with *formatting*.
```

Convert:
```bash
./scripts/pandoc-to-cdx.sh document.md document.cdx
```

### From LaTeX

```bash
./scripts/pandoc-to-cdx.sh paper.tex paper.cdx
```

### From Word

```bash
./scripts/pandoc-to-cdx.sh report.docx report.cdx
```

## Limitations

- Images are referenced by path but not embedded in the archive (future enhancement)
- Complex table formatting may be simplified
- Citations require `--citeproc` flag for bibliography generation; without it, only inline citation blocks are emitted
- Footnote content is appended as blocks at the end of the document
- SVG, barcode, and signature blocks have no natural Pandoc mapping and are not supported

## Troubleshooting

### "Cannot find library" error

Ensure you're running pandoc from the project root directory, or that the `lib/` directory is in the same location as `codex.lua`.

### Citations not appearing in bibliography

Add the `--citeproc` flag to enable Pandoc's citation processor:

```bash
pandoc input.md --citeproc -t codex.lua -o output.json
```

### Empty or missing metadata

Ensure your document has YAML frontmatter with at least a `title` field:

```markdown
---
title: My Document
---
```

### Math not rendering as expected

Display math should use double dollar signs or the equation environment:

```markdown
$$E = mc^2$$
```

Inline math uses single dollar signs: `$x = y$`. Inline math is preserved as a `math` mark on text nodes (stays inside the paragraph) with `format: "latex"` and `source` containing the LaTeX string. Display math produces a block-level `math` block. Aligned LaTeX environments (`align`, `gather`, `split`) are automatically detected and converted to `academic:equation-group` blocks.

### Reader round-trip loses semantic data

The reader converts Codex back to standard Pandoc elements. Most block types survive round-trip faithfully:

- **Core blocks**: paragraphs, headings, lists, tables, code, math, images, figures, definition lists, admonitions all round-trip cleanly.
- **Academic blocks**: theorems (variant, id, title), proofs (of, method), exercises (difficulty, hints, solutions), algorithms (title, pseudocode), abstracts (keywords), and equation groups (reconstructed LaTeX environments) all survive via Pandoc Div attributes.
- **Semantic blocks**: `semantic:term` round-trips via DefinitionList, `measurement` via Span attributes. `semantic:bibliography` and `semantic:glossary` are skipped as they have no direct Pandoc equivalent.
- **Inline marks**: formatting, links, math, `semantic:citation`, footnotes, `semantic:entity` URIs, `semantic:glossary` references, and `academic:*-ref` cross-references all survive round-trip.

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
