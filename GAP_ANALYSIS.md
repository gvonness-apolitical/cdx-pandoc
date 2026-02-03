# cdx-pandoc Gap Analysis

**Date**: 2026-02-03
**Comparison**: cdx-core (Rust) vs cdx-pandoc (Lua)

## Executive Summary

cdx-pandoc provides comprehensive coverage of core document elements, semantic extensions, and the academic extension (`codex.academic`). All planned phases have been completed.

**Core blocks**: paragraph, heading, list, codeBlock, blockquote, horizontalRule, table, math, image, figure, definitionList, admonition.

**Semantic extension** (`codex.semantic`): footnotes, citations, bibliography, glossary terms, entity linking, measurements, cross-references.

**Academic extension** (`codex.academic`): theorems (8 variants), proofs, exercises with hints/solutions, exercise sets, algorithms, abstracts with keywords, equation groups, academic cross-references (theorem-ref, equation-ref, algorithm-ref).

**Inline marks**: bold, italic, code, link, strikethrough, underline, superscript, subscript, math, footnote, citation, entity, glossary, theorem-ref, equation-ref, algorithm-ref.

**Metadata**: Dublin Core extraction, JSON-LD generation, ORCID support, CSL bibliography preservation.

**Dynamic extension tracking**: manifest `extensions` field automatically populated based on block types used.

---

## 1. Inline Marks - Gaps

### 1.1 Footnote Mark ✅ COMPLETED

**cdx-core spec**:
```json
{
  "type": "text",
  "value": "important claim",
  "marks": [{ "type": "footnote", "number": 1, "id": "fn1" }]
}
```

**cdx-pandoc implementation**:
```json
{
  "type": "text",
  "value": "1",
  "marks": [{ "type": "footnote", "number": 1, "id": "fn-1" }]
}
```

**Status**: ✅ Implemented in `lib/inlines.lua`. Footnote marks are generated with `number` and `id` fields. Reader converts them back to Pandoc `Note` elements.

---

### 1.2 Citation Mark ✅ COMPLETED

**cdx-core spec** (mark on text):
```json
{
  "type": "text",
  "value": "according to recent research",
  "marks": [{ "type": "citation", "refs": ["smith2024"], "locator": "42-45" }]
}
```

**cdx-pandoc implementation**:
```json
{
  "type": "text",
  "value": "@smith2024",
  "marks": [{ "type": "citation", "refs": ["smith2024"], "locator": "42-45" }]
}
```

**Status**: ✅ Implemented in `lib/inlines.lua`. Citations are now marks on text nodes with:
- `refs`: Array of citation keys
- `locator`: Page numbers (extracted from suffix)
- `prefix`/`suffix`: Optional text
- `suppressAuthor`: Boolean for author-suppressed citations

Reader converts citation marks back to Pandoc `Cite` elements.

---

### 1.3 Entity Mark ✅ COMPLETED

**cdx-core spec**:
```json
{
  "type": "text",
  "value": "Albert Einstein",
  "marks": [{ "type": "entity", "uri": "https://www.wikidata.org/wiki/Q937", "entityType": "Person" }]
}
```

**cdx-pandoc implementation**:
```json
{
  "type": "text",
  "value": "Albert Einstein",
  "marks": [{ "type": "entity", "uri": "https://www.wikidata.org/wiki/Q937", "entityType": "Person" }]
}
```

**Status**: ✅ Implemented in `lib/inlines.lua`. Entity marks are generated from Pandoc Spans with `.entity` class:
- `[text]{.entity uri="..." entityType="..." source="..."}`
- Supports `uri`, `entityType`, and optional `source` attributes
- Reader converts back to Span with entity class and attributes

---

### 1.4 Glossary Mark ✅ COMPLETED

**cdx-core spec**:
```json
{
  "type": "text",
  "value": "CRDT",
  "marks": [{ "type": "glossary", "ref": "term-crdt" }]
}
```

**cdx-pandoc implementation**:
```json
{
  "type": "text",
  "value": "CRDT",
  "marks": [{ "type": "glossary", "ref": "term-crdt" }]
}
```

**Status**: ✅ Implemented in `lib/inlines.lua`. Glossary marks are generated from Pandoc Spans with `.glossary` class:
- `[text]{.glossary ref="term-id"}` - explicit reference
- `[text]{.glossary}` - auto-generates ref from text content
- Reader converts back to Span with glossary class and ref attribute

---

## 2. Block Types

### 2.1 Core Block Types ✅ ALL COMPLETED

| Block Type | Pandoc Source | Status |
|-----------|--------------|--------|
| paragraph | Para, Plain | ✅ |
| heading | Header | ✅ |
| list | BulletList, OrderedList | ✅ |
| codeBlock | CodeBlock | ✅ |
| blockquote | BlockQuote | ✅ |
| horizontalRule | HorizontalRule | ✅ |
| table | Table | ✅ |
| math | DisplayMath | ✅ |
| image | Image | ✅ |
| figure | Figure | ✅ Container with image children + figcaption |
| definitionList | DefinitionList | ✅ Core definitionItem/definitionTerm/definitionDescription |
| admonition | Div (.note/.warning/...) | ✅ variant + optional title |

### 2.2 Semantic Extension Blocks ✅ ALL COMPLETED

| Block Type | Pandoc Source | Status |
|-----------|--------------|--------|
| semantic:term | DefinitionList inside .glossary Div | ✅ |
| semantic:measurement | Span .measurement (sentinel) | ✅ |
| semantic:footnote | Note | ✅ |
| semantic:bibliography | Div#refs (citeproc) | ✅ |
| semantic:ref | Link (internal) | ✅ Reader-side |
| semantic:glossary | — | Deferred (auto-generated container) |

### 2.3 Academic Extension Blocks ✅ ALL COMPLETED

| Block Type | Pandoc Source | Status |
|-----------|--------------|--------|
| academic:theorem | Div (.theorem/.lemma/.proposition/.corollary/.definition/.conjecture/.remark/.example) | ✅ |
| academic:proof | Div (.proof) | ✅ of, method attributes |
| academic:exercise | Div (.exercise) | ✅ difficulty, nested .hint/.solution |
| academic:exercise-set | Div (.exercise-set) | ✅ title, preamble, exercises |
| academic:algorithm | Div (.algorithm) | ✅ title, pseudocode lines |
| academic:abstract | Div (.abstract) | ✅ keywords from nested .keywords Div |
| academic:equation-group | DisplayMath with aligned LaTeX | ✅ Auto-detected align/gather/split |

---

## 3. Round-Trip Fidelity

The reader (`cdx-reader.lua`) converts Codex JSON back to Pandoc AST. The following documents what survives round-trip for each block/mark type.

### 3.1 Core Blocks

| Block Type | Write → Read Fidelity | Notes |
|-----------|----------------------|-------|
| paragraph | Lossless | Text nodes with marks fully preserved |
| heading | Lossless | Level, ID, and inline content preserved |
| list | Lossless | Ordered/unordered, start number, nesting |
| codeBlock | Lossless | Language attribute preserved |
| blockquote | Lossless | Nested content preserved |
| horizontalRule | Lossless | |
| table | Near-lossless | Column alignment defaults to AlignDefault |
| math (display) | Lossless | LaTeX content preserved |
| image | Lossless | src, alt, title preserved |
| figure | Near-lossless | Image + caption survive; subfigure labels lost |
| definitionList | Lossless | Term/description structure preserved |
| admonition | Near-lossless | variant → Div class; title → inserted Header |

### 3.2 Academic Extension Blocks

| Block Type | Write → Read Fidelity | Notes |
|-----------|----------------------|-------|
| academic:theorem | Lossless | variant, id, number, title → Div attributes |
| academic:proof | Lossless | of, method → Div attributes |
| academic:exercise | Lossless | difficulty → attribute; hints, solutions → nested Divs with visibility |
| academic:exercise-set | Lossless | title → attribute; preamble + exercises → nested Divs |
| academic:algorithm | Lossless | title → attribute; pseudocode → CodeBlock with `algorithm` class |
| academic:abstract | Lossless | Content + keywords → nested .keywords Div |
| academic:equation-group | Near-lossless | Reconstructed `\begin{align}...\end{align}` environment; line labels not preserved |

### 3.3 Inline Marks

| Mark Type | Write → Read Fidelity | Notes |
|----------|----------------------|-------|
| bold, italic, code, strikethrough, underline, superscript, subscript | Lossless | |
| link | Lossless | href and title preserved |
| math (inline) | Lossless | LaTeX content preserved as InlineMath |
| footnote | Lossless | Resolved against semantic:footnote blocks |
| citation | Lossless | refs, locator, prefix, suffix, suppressAuthor |
| entity | Lossless | uri, entityType, source → Span attributes |
| glossary | Lossless | ref → Span attribute |
| theorem-ref | Near-lossless | target preserved as Link; format string lost |
| equation-ref | Near-lossless | target preserved as Link; format string lost |
| algorithm-ref | Near-lossless | target preserved as Link; line ref and format lost |

### 3.4 Known Losses

- **`semantic:bibliography`**: Skipped on read (no Pandoc equivalent for CSL entry blocks)
- **`semantic:glossary`**: Skipped on read (auto-generated container)
- **Academic ref format strings**: `"Theorem {number}"` → plain Link text (format not round-tripped)
- **Equation group line labels**: Individual equation labels within aligned environments not preserved
- **Subfigure labels**: `label="a"` on subfigures not preserved through round-trip
- **Schema.org metadata on measurements**: `schema` field on `semantic:measurement` lost on read

---

## 4. Compatibility Notes

### Pandoc Extensions Required
- `--citeproc` for bibliography processing
- `+footnotes` for footnote syntax
- `+definition_lists` for definition list / glossary terms
- `+fenced_divs` for academic blocks, admonitions, glossary containers

### cdx-core Version Alignment
- Current cdx-pandoc targets cdx-core spec v0.1
- Footnote mark format aligned as of 2026-01-29
- Citation mark format aligned as of 2026-01-29 (marks on text nodes)
- Bibliography CSL format aligned as of 2026-01-30
- ORCID support added as of 2026-01-30
- Definition lists, figures, inline math marks aligned as of 2026-02-01
- Academic extension (codex.academic) aligned as of 2026-02-02
- Dynamic extension tracking added as of 2026-02-02

---

## 5. Test Coverage

27 integration test inputs covering:
- Basic formatting, lists, tables, code blocks, nested structures
- Citations, footnotes, bibliography with CSL metadata
- Math (inline marks + display blocks + equation groups)
- Images, figures with captions and subfigures
- Definition lists (core) and glossary terms (semantic)
- Entity linking, measurements, cross-references
- Admonitions (note, warning, tip, danger, important, caution)
- Theorems (8 variants), proofs, exercises, algorithms, abstracts
- Academic cross-references
- Academic kitchen sink (all types combined)
- Edge cases: empty documents, no metadata, ORCID, state handling

Unit tests: 73 tests across JSON encoding and utility functions.

---

## 6. Summary Table

| Feature | cdx-core | cdx-pandoc | Status |
|---------|----------|------------|--------|
| Basic formatting | Full | Full | ✅ Done |
| Lists/tables | Full | Full | ✅ Done |
| Code blocks | Full | Full | ✅ Done |
| Math (inline marks) | Full | Full | ✅ Done |
| Math (display blocks) | Full | Full | ✅ Done |
| Images | Full | Full | ✅ Done |
| Figures + captions | Full | Full | ✅ Done |
| Definition lists | Full | Full | ✅ Done |
| Admonitions | Full | Full | ✅ Done |
| Footnote marks | Mark::Footnote | Mark::Footnote | ✅ Done |
| Footnote blocks | Full | Full | ✅ Done |
| Citation marks | mark on text | mark on text | ✅ Done |
| Bibliography | Full CSL JSON | Full CSL + rendered | ✅ Done |
| Cross-references | semantic:ref | link marks + reader | ✅ Done |
| JSON-LD | Full | Generated from DC | ✅ Done |
| Glossary | Full | semantic:term + marks | ✅ Done |
| Entity linking | Full | entity marks | ✅ Done |
| Measurements | Full | semantic:measurement | ✅ Done |
| ORCID | Author identifiers | @id in JSON-LD | ✅ Done |
| Theorems (8 variants) | Full | academic:theorem | ✅ Done |
| Proofs | Full | academic:proof | ✅ Done |
| Exercises | Full | academic:exercise | ✅ Done |
| Exercise sets | Full | academic:exercise-set | ✅ Done |
| Algorithms | Full | academic:algorithm | ✅ Done |
| Abstracts | Full | academic:abstract | ✅ Done |
| Equation groups | Full | academic:equation-group | ✅ Done |
| Academic cross-refs | Full | theorem-ref/equation-ref/algorithm-ref | ✅ Done |
| Extension tracking | Full | Dynamic manifest.extensions | ✅ Done |

### Not Supported

| Feature | Reason |
|---------|--------|
| SVG blocks | No natural Pandoc mapping |
| Barcode blocks | No natural Pandoc mapping |
| Signature blocks | No natural Pandoc mapping |
| Symbol footnotes | Pandoc doesn't distinguish footnote styles |
| semantic:glossary container | Auto-generated; not needed for round-trip |
