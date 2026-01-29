# cdx-pandoc Gap Analysis for Academic Workflows

**Date**: 2026-01-29
**Comparison**: cdx-core (Rust) vs cdx-pandoc (Lua)

## Executive Summary

cdx-pandoc provides solid coverage of core document elements but has significant gaps in semantic extension support that are critical for academic workflows. Priority improvements should focus on: (1) proper footnote/citation mark formatting, (2) bibliography preservation, and (3) cross-reference support.

---

## 1. Inline Marks - Gaps

### 1.1 Footnote Mark (HIGH PRIORITY)

**cdx-core spec**:
```json
{
  "type": "text",
  "value": "important claim",
  "marks": [{ "type": "footnote", "number": 1, "id": "fn1" }]
}
```

**cdx-pandoc current**: Uses superscript numbers without footnote mark structure
```json
{
  "type": "text",
  "value": "1",
  "marks": ["superscript"]
}
```

**Gap**: The semantic footnote mark with `number` and `id` fields is not generated. This breaks the explicit link between reference and footnote block.

**Fix needed**: Generate `Mark::Footnote` instead of plain superscript for footnote references.

---

### 1.2 Citation Mark (HIGH PRIORITY)

**cdx-core spec** (mark on text):
```json
{
  "type": "text",
  "value": "according to recent research",
  "marks": [{ "type": "citation", "refs": ["smith2024"], "pages": "42-45" }]
}
```

**cdx-pandoc current**: Creates `semantic:citation` blocks (separated from text):
```json
{
  "type": "semantic:citation",
  "ref": "smith2024",
  "prefix": "see",
  "suffix": "p. 42"
}
```

**Gap**: Citations should be marks on text nodes, not standalone blocks. The current approach loses the inline context.

**Fix needed**: Convert Pandoc `Cite` to citation marks on the citation text, not separate blocks.

---

### 1.3 Entity Mark (MEDIUM PRIORITY)

**cdx-core spec**:
```json
{
  "type": "text",
  "value": "Albert Einstein",
  "marks": [{ "type": "entity", "uri": "https://www.wikidata.org/wiki/Q937", "entityType": "Person" }]
}
```

**cdx-pandoc current**: Not supported

**Gap**: No mechanism to annotate named entities with knowledge base links. Academic documents often need entity disambiguation.

**Pandoc source**: Could potentially use `Span` with custom attributes like `[Albert Einstein]{.entity uri="..."}`

---

### 1.4 Glossary Mark (MEDIUM PRIORITY)

**cdx-core spec**:
```json
{
  "type": "text",
  "value": "CRDT",
  "marks": [{ "type": "glossary", "ref": "term-crdt" }]
}
```

**cdx-pandoc current**: Not supported

**Gap**: No support for glossary term references within text.

---

## 2. Block Types - Gaps

### 2.1 semantic:ref (Cross-References) (HIGH PRIORITY)

**cdx-core spec**:
```json
{
  "type": "semantic:ref",
  "target": "#section-3",
  "format": "Section {number}",
  "children": [{ "type": "text", "value": "Section 3" }]
}
```

**cdx-pandoc current**: Internal links are just `link` marks with `href: "#id"`

**Gap**: No dedicated cross-reference block type. Academic documents need numbered references to figures, tables, equations, and sections.

**Pandoc source**: `pandoc-crossref` filter generates these; could detect Link elements with `#` prefixes.

---

### 2.2 semantic:term (Glossary Definition) (MEDIUM PRIORITY)

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

**cdx-pandoc current**: Not supported

**Gap**: Definition lists are converted to regular lists with bold terms, losing the semantic structure needed for glossary generation.

---

### 2.3 semantic:glossary (Glossary Block) (LOW PRIORITY)

**cdx-core spec**:
```json
{
  "type": "semantic:glossary",
  "title": "Glossary of Terms",
  "sort": "alphabetical"
}
```

**cdx-pandoc current**: Not supported

---

### 2.4 semantic:measurement (LOW PRIORITY)

**cdx-core spec**:
```json
{
  "type": "semantic:measurement",
  "value": 42.5,
  "unit": "kg",
  "schema": { "@type": "QuantitativeValue", "unitCode": "KGM" }
}
```

**cdx-pandoc current**: Not supported

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

### 4.1 JSON-LD Metadata (MEDIUM PRIORITY)

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

**cdx-pandoc current**: Not supported

**Gap**: No schema.org/JSON-LD metadata generation. Important for academic document discovery and indexing.

**Pandoc source**: Could generate from Dublin Core + document type inference.

---

### 4.2 ORCID Support (LOW PRIORITY)

**cdx-core**: Authors can have ORCID identifiers
**cdx-pandoc**: Not extracted from Pandoc metadata

---

## 5. Reader - Gaps

### 5.1 Citation Marks (HIGH PRIORITY)

**Current**: `semantic:citation` blocks are skipped
**Needed**: Convert citation marks back to Pandoc `Cite` elements

### 5.2 Footnote Marks (HIGH PRIORITY)

**Current**: Footnote blocks restored, but footnote marks would need handling
**Needed**: If footnote marks are generated, reader should convert them to Pandoc `Note`

### 5.3 Cross-References (MEDIUM PRIORITY)

**Current**: `semantic:ref` blocks are skipped
**Needed**: Convert to Pandoc Link elements with appropriate text

### 5.4 Glossary Terms (LOW PRIORITY)

**Current**: `semantic:term` blocks are skipped
**Needed**: Convert to definition lists or custom Pandoc elements

---

## 6. Priority Implementation Roadmap

### Phase 1: Core Academic Features (HIGH PRIORITY)

1. **Footnote marks** - Generate `Mark::Footnote` with number/id instead of superscript
2. **Citation marks** - Convert Pandoc Cite to citation marks on text (not blocks)
3. **Bibliography preservation** - Extract full CSL metadata from Pandoc
4. **Reader: citations** - Restore citation marks to Pandoc Cite elements

### Phase 2: Cross-References (MEDIUM PRIORITY)

5. **semantic:ref blocks** - Detect internal links and wrap in semantic:ref
6. **Reader: cross-refs** - Convert semantic:ref back to Pandoc links
7. **JSON-LD metadata** - Generate ScholarlyArticle from Dublin Core

### Phase 3: Advanced Semantic Features (LOWER PRIORITY)

8. **Glossary support** - Definition lists → semantic:term
9. **Entity linking** - Custom Span attributes → entity marks
10. **Measurements** - Custom notation → semantic:measurement

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

| Feature | cdx-core | cdx-pandoc | Gap Level |
|---------|----------|------------|-----------|
| Basic formatting | Full | Full | None |
| Lists/tables | Full | Full | None |
| Code blocks | Full | Full | None |
| Math | Full | Full | None |
| Images | Full | Full | None |
| Footnote marks | Mark::Footnote | superscript | HIGH |
| Footnote blocks | Full | Full | None |
| Citation marks | mark on text | separate block | HIGH |
| Bibliography | Full CSL JSON | rendered text only | HIGH |
| Cross-references | semantic:ref | link mark only | MEDIUM |
| JSON-LD | Full | None | MEDIUM |
| Glossary | Full | None | MEDIUM |
| Entity linking | Full | None | LOW |
| Measurements | Full | None | LOW |
