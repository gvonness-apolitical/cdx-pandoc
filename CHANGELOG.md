# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Unit tests for `blocks.lua`, `academic.lua`, `reader_inlines.lua`, `reader_blocks.lua`, `reader_academic.lua` (235 new assertions, 505 total across 11 test files)
- Golden baseline comparison (`make test-golden`) in CI pipeline
- `make test-all` target for single-command full validation (lint + test + golden + reader + validate)
- Wildcard test discovery in `make test-unit` (auto-discovers new test files)

### Changed
- Aligned `make lint` flags with CI (`--no-unused-args --no-max-line-length`)
- Updated CONTRIBUTING.md pre-PR command to `make test-all`

### Fixed
- README Pandoc version requirement: corrected from 2.11+ to 3.0+

## [0.6.0] - 2026-02-17

### Changed
- **Mark namespacing**: semantic marks now use `semantic:` prefix (`semantic:citation`, `semantic:entity`, `semantic:glossary`), academic marks use `academic:` prefix (`academic:theorem-ref`, `academic:equation-ref`, `academic:algorithm-ref`). Core marks (`footnote`, `anchor`, `math`, `link`, `code`) are unchanged.
- **Measurement** is now a core block type (`measurement`) with a `display` field containing the original text. Removed `semantic:measurement` type and `schema` (schema.org QuantitativeValue) field.
- **Figure subfigures** moved from `children` to a dedicated `subfigures` array. Subfigure objects have `id`, `label`, and `children` fields (no `type`).
- **Inline math** mark now includes `source` field containing the LaTeX string alongside `format: "latex"`.
- **Content version** bumped from `0.1` to `0.7.0` to align with cdx-core serialization format.
- Extension tracking now covers inline marks (semantic and academic), not just blocks.
- Reader accepts both namespaced and legacy non-namespaced mark formats for backward compatibility.

## [0.5.0] - 2026-02-04

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
- `make test-golden` target for golden output baseline comparison
- `make lint` target for local luacheck execution
- Academic kitchen sink integration test (`tests/inputs/academic-full.md`)
- Golden output baselines for all 27 integration tests
- Unit tests for bibliography, inlines, metadata, and shared utilities (270 total assertions)
- New `lib/academic.lua` and `lib/reader_academic.lua` modules

### Changed
- Refactored Div handler into structured dispatch (`div_block()`) with extension points
- Replaced if/elseif dispatch chains with handler tables in `blocks.lua` and `reader_blocks.lua`
- Definition lists outside `.glossary` Divs now produce core `definitionList` (not `semantic:term`)
- Figures produce `figure` containers instead of flattened `image` blocks
- Inline math produces `math` mark instead of `math_sentinel` paragraph splits
- Consolidated `has_class()` into shared `lib/utils.lua`; extracted `insert_converted()`, `generate_term_id()`, `extract_block_attr()` helpers
- Defined extension ID constants (`EXT_SEMANTIC`, `EXT_ACADEMIC`) in `lib/utils.lua`
- Simplified `bibliography.extract_entry()` and `metadata.generate_jsonld()` with table-driven field mappings

### Fixed
- Fixed `bibliography.extract_date()` crash on raw number date-parts (accessed `.t` on number value)
- Fixed README inaccuracies about reader behavior and citation output format
- Removed dead code: unused `set_inlines()` stubs, orphaned `detect_latex_env()` function
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
