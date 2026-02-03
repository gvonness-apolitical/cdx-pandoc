# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- **Academic extension** (`codex.academic`): theorems (8 variants), proofs, exercises with hints/solutions, exercise sets, algorithms, abstracts with keywords, equation groups
- Academic cross-reference marks: `theorem-ref`, `equation-ref`, `algorithm-ref` for typed internal links
- Admonition blocks from fenced Divs (note, warning, tip, danger, important, caution)
- Figure container blocks with `figcaption` children and subfigure support
- Core `definitionList` / `definitionItem` / `definitionTerm` / `definitionDescription` blocks
- Inline math as `math` mark on text nodes (no longer splits paragraphs)
- Auto-detection of aligned LaTeX environments (align, gather, split) → `academic:equation-group`
- Dynamic extension tracking in manifest `extensions` field
- `make validate-schema` target for spec schema validation
- Academic kitchen sink integration test (`tests/inputs/academic-full.md`)
- New `lib/academic.lua` and `lib/reader_academic.lua` modules

### Changed
- Refactored Div handler into structured dispatch (`div_block()`) with extension points
- Replaced if/elseif dispatch chains with handler tables in `blocks.lua` and `reader_blocks.lua`
- Definition lists outside `.glossary` Divs now produce core `definitionList` (not `semantic:term`)
- Figures produce `figure` containers instead of flattened `image` blocks
- Inline math produces `math` mark instead of `math_sentinel` paragraph splits
- Updated documentation: README, GAP_ANALYSIS, CHANGELOG

### Fixed
- Fixed README inaccuracies about reader behavior and citation output format
- Removed duplicated project structure from CONTRIBUTING.md

## [0.4.0] - 2025-01-28

### Added
- ORCID support for author identifiers in metadata
- Full CSL metadata extraction for bibliography entries
- `semantic:bibliography` block with structured entry data (title, authors, DOI, URL, etc.)
- Citation style detection from document metadata

## [0.3.0] - 2025-01-27

### Added
- Entity linking via `[text]{.entity uri="..." entityType="..."}` spans
- Glossary term definitions via definition lists (`Term\n:   Definition`)
- Glossary references via `[text]{.glossary ref="term-id"}` spans
- Measurement annotations via `[value unit]{.measurement value="..." unit="..."}`
- Schema.org `QuantitativeValue` metadata for measurements

## [0.2.0] - 2025-01-26

### Added
- JSON-LD metadata generation from Dublin Core
- Cross-reference support via anchor marks (`[text]{#id}`)
- `semantic:ref` blocks for internal document links

### Changed
- Improved footnote handling with proper `footnote` marks instead of superscript

## [0.1.0] - 2025-01-25

### Added
- Initial Pandoc custom writer for Codex format
- Block types: paragraph, heading, list, codeBlock, blockquote, table, math, image, horizontalRule
- Inline marks: bold, italic, code, link, strikethrough, underline, superscript, subscript
- Dublin Core metadata extraction from YAML frontmatter
- Pandoc reader for Codex JSON back to any output format
- Full pipeline script for creating `.cdx` archives
- Integration test suite with 12 test cases
