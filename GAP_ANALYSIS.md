# cdx-pandoc Gap Analysis for Academic Workflows

**Date**: 2026-01-29
**Comparison**: cdx-core (Rust) vs cdx-pandoc (Lua)

## Executive Summary

cdx-pandoc provides solid coverage of core document elements. Phase 1 and Phase 2 improvements have been completed, addressing footnote marks, citation marks, JSON-LD metadata, and cross-reference support. Remaining work focuses on bibliography metadata preservation and advanced semantic features.

**Completed (Phase 1-2)**:
- ✅ Footnote marks with number/id fields
- ✅ Citation marks on text nodes (not separate blocks)
- ✅ Reader support for footnotes and citations
- ✅ JSON-LD metadata generation from Dublin Core
- ✅ Cross-reference support (semantic:ref reader, link marks for internal refs)

**Completed (Phase 3)**:
- ✅ Glossary support (semantic:term blocks, glossary marks)
- ✅ Entity linking (entity marks with Wikidata URIs)
- ✅ Measurements (semantic:measurement blocks)

**Remaining (Phase 4+)**:
- Bibliography CSL metadata preservation (requires citeproc integration)

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

## 2. Block Types - Gaps

### 2.1 semantic:ref (Cross-References) ✅ COMPLETED

**cdx-core spec**:
```json
{
  "type": "semantic:ref",
  "target": "#section-3",
  "format": "Section {number}",
  "children": [{ "type": "text", "value": "Section 3" }]
}
```

**cdx-pandoc implementation**:
- **Inline cross-references**: Use link marks with `href: "#section-3"` (standard approach)
- **Block-level cross-references**: Reader supports `semantic:ref` blocks, converting them to Pandoc Links

**Status**: ✅ Internal links work via link marks. Reader support for `semantic:ref` blocks added in `lib/reader_blocks.lua`. Note: `semantic:ref` is primarily for block-level standalone references; inline refs use standard link marks.

---

### 2.2 semantic:term (Glossary Definition) ✅ COMPLETED

**cdx-core spec**:
```json
{
  "type": "semantic:term",
  "id": "term-crdt",
  "term": "CRDT",
  "definition": "Conflict-free Replicated Data Type",
  "see": ["term-eventual-consistency"]
}
```

**cdx-pandoc implementation**:
```json
{
  "type": "semantic:term",
  "id": "term-crdt",
  "term": "CRDT",
  "definition": "Conflict-free Replicated Data Type - a data structure...",
  "see": ["term-eventual-consistency"]
}
```

**Status**: ✅ Implemented in `lib/blocks.lua`. Pandoc DefinitionList is converted to semantic:term blocks:
- Auto-generates `id` from term text (e.g., "term-crdt")
- Extracts "See also:" references into `see` array
- Reader converts back to DefinitionList with "See also:" appended

---

### 2.3 semantic:glossary (Glossary Block) (DEFERRED)

**cdx-core spec**:
```json
{
  "type": "semantic:glossary",
  "title": "Glossary of Terms",
  "sort": "alphabetical"
}
```

**cdx-pandoc current**: Not implemented (placeholder block, reader skips)

**Note**: This is an auto-generated container block that collects semantic:term entries. Not typically needed for Pandoc round-trip.

---

### 2.4 semantic:measurement ✅ COMPLETED

**cdx-core spec**:
```json
{
  "type": "semantic:measurement",
  "value": 42.5,
  "unit": "kg",
  "schema": { "@type": "QuantitativeValue", "unitCode": "KGM" }
}
```

**cdx-pandoc implementation**:
```json
{
  "type": "semantic:measurement",
  "value": 42.5,
  "unit": "kg",
  "schema": { "@type": "QuantitativeValue", "value": 42.5, "unitText": "kg" }
}
```

**Status**: ✅ Implemented in `lib/inlines.lua` and `lib/blocks.lua`. Measurements are generated from Pandoc Spans with `.measurement` class:
- `[42.5 kg]{.measurement value="42.5" unit="kg"}`
- Auto-extracts value/unit from text if attributes not provided
- Generates schema.org QuantitativeValue metadata
- Reader converts back to Span with measurement class and attributes

---

## 3. Bibliography - Gaps

### 3.1 Full CSL JSON Structure (HIGH PRIORITY)

**cdx-core spec** (bibliography.json):
```json
{
  "version": "0.1",
  "style": "apa",
  "entries": [
    {
      "id": "smith2024",
      "type": "article-journal",
      "title": "Advances in Document Processing",
      "author": [{ "family": "Smith", "given": "John" }],
      "issued": { "year": 2024 },
      "container-title": "Journal of Digital Documents",
      "volume": 15,
      "DOI": "10.1234/jdd.2024.001"
    }
  ]
}
```

**cdx-pandoc current** (from citeproc #refs div):
```json
{
  "type": "semantic:bibliography",
  "style": "apa",
  "entries": [
    {
      "id": "smith2024",
      "entryType": "other",
      "title": "Smith, J. (2024). Advances in..."  // Rendered text only
    }
  ]
}
```

**Gap**: Only captures rendered bibliography text, not structured metadata. Loses all author, date, DOI, volume data.

**Fix needed**: Parse Pandoc's internal citation data (available via `--citeproc` references) to extract full CSL metadata.

---

## 4. Metadata - Gaps

### 4.1 JSON-LD Metadata ✅ COMPLETED

**cdx-core spec** (metadata/jsonld.json):
```json
{
  "@context": "https://schema.org/",
  "@type": "ScholarlyArticle",
  "name": "A Study on Document Formats",
  "author": { "@type": "Person", "name": "Jane Doe" },
  "datePublished": "2025-01-15"
}
```

**cdx-pandoc implementation**:
```json
{
  "@context": "https://schema.org/",
  "@type": "Article",
  "name": "Document Title",
  "author": { "@type": "Person", "name": "Author Name" },
  "datePublished": "2025-01-15",
  "description": "Abstract text",
  "keywords": "keyword1, keyword2",
  "inLanguage": "en"
}
```

**Status**: ✅ Implemented in `lib/metadata.lua`. JSON-LD is generated from Dublin Core metadata with:
- `@type` mapped from DC type (Text → Article, Book, Report, etc.)
- `name`, `author`, `datePublished`, `description`, `keywords`, `inLanguage`, `publisher`, `license`
- DOI/ISBN identifier support
- Manifest updated to reference `metadata/jsonld.json`

---

### 4.2 ORCID Support (LOW PRIORITY)

**cdx-core**: Authors can have ORCID identifiers
**cdx-pandoc**: Not extracted from Pandoc metadata

---

## 5. Reader - Gaps

### 5.1 Citation Marks ✅ COMPLETED

**Status**: ✅ Implemented in `lib/reader_inlines.lua`. Citation marks are converted to Pandoc `Cite` elements with proper mode (NormalCitation/SuppressAuthor), prefix, and suffix.

### 5.2 Footnote Marks ✅ COMPLETED

**Status**: ✅ Implemented in `lib/reader_inlines.lua`. Footnote marks are converted to Pandoc `Note` elements by resolving against pre-processed footnote blocks.

### 5.3 Cross-References ✅ COMPLETED

**Status**: ✅ Implemented in `lib/reader_blocks.lua`. `semantic:ref` blocks are converted to Pandoc Link elements with the target URL.

### 5.4 Glossary Terms ✅ COMPLETED

**Status**: ✅ Implemented in `lib/reader_blocks.lua`. `semantic:term` blocks are converted to Pandoc DefinitionList elements with "See also:" references appended to definitions.

---

## 6. Priority Implementation Roadmap

### Phase 1: Core Academic Features ✅ COMPLETED

1. ✅ **Footnote marks** - Generate `Mark::Footnote` with number/id instead of superscript
2. ✅ **Citation marks** - Convert Pandoc Cite to citation marks on text (not blocks)
3. ⏳ **Bibliography preservation** - Extract full CSL metadata from Pandoc (requires --citeproc integration)
4. ✅ **Reader: citations** - Restore citation marks to Pandoc Cite elements

### Phase 2: Cross-References & Metadata ✅ COMPLETED

5. ✅ **Cross-references** - Internal links use link marks; reader supports semantic:ref blocks
6. ✅ **Reader: cross-refs** - Convert semantic:ref back to Pandoc links
7. ✅ **JSON-LD metadata** - Generate schema.org metadata from Dublin Core

### Phase 3: Advanced Semantic Features ✅ COMPLETED

8. ✅ **Glossary support** - Definition lists → semantic:term; Span .glossary → glossary marks
9. ✅ **Entity linking** - Span .entity attributes → entity marks with Wikidata URIs
10. ✅ **Measurements** - Span .measurement → semantic:measurement with schema.org metadata

---

## 7. Test Coverage Gaps

Current tests cover:
- Basic formatting, lists, tables, code blocks
- Simple citations and footnotes
- Math (inline/display)
- Images

Missing test coverage:
- [ ] Complex nested citations with locators
- [ ] Multi-paragraph footnotes with citations inside
- [ ] Cross-references to figures/tables/equations
- [ ] Bibliography round-trip with full metadata
- [ ] Definition lists as glossary terms
- [ ] Mixed inline citations on same text span

---

## 8. Compatibility Notes

### Pandoc Extensions Required
- `--citeproc` for bibliography processing
- `+footnotes` for footnote syntax
- `+definition_lists` for glossary terms

### cdx-core Version Alignment
- Current cdx-pandoc targets cdx-core spec v0.1
- Footnote mark format aligned as of 2026-01-29
- Citation mark format NOT yet aligned (blocks vs marks)

---

## Summary Table

| Feature | cdx-core | cdx-pandoc | Status |
|---------|----------|------------|--------|
| Basic formatting | Full | Full | ✅ Done |
| Lists/tables | Full | Full | ✅ Done |
| Code blocks | Full | Full | ✅ Done |
| Math | Full | Full | ✅ Done |
| Images | Full | Full | ✅ Done |
| Footnote marks | Mark::Footnote | Mark::Footnote | ✅ Done |
| Footnote blocks | Full | Full | ✅ Done |
| Citation marks | mark on text | mark on text | ✅ Done |
| Bibliography | Full CSL JSON | rendered text only | ⏳ Pending |
| Cross-references | semantic:ref | link marks + reader | ✅ Done |
| JSON-LD | Full | Generated from DC | ✅ Done |
| Glossary | Full | semantic:term + marks | ✅ Done |
| Entity linking | Full | entity marks | ✅ Done |
| Measurements | Full | semantic:measurement | ✅ Done |
