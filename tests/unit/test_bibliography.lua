#!/usr/bin/env lua
-- tests/unit/test_bibliography.lua
-- Unit tests for lib/bibliography.lua
-- Tests functions that operate on plain Lua tables (no Pandoc dependency)

local test = dofile("tests/unit/test_utils.lua")
local bibliography = dofile("lib/bibliography.lua")

print("Running bibliography unit tests...")
print("")

-- ============================================
-- Tests for extract_authors()
-- ============================================

print("-- extract_authors tests --")

test.test("extract_authors nil")
test.assert_nil(bibliography.extract_authors(nil))

test.test("extract_authors empty list")
test.assert_nil(bibliography.extract_authors({}))

test.test("extract_authors single family/given")
local authors = bibliography.extract_authors({
    {family = "Smith", given = "John"}
})
test.assert_not_nil(authors)
test.assert_eq(1, #authors)
test.assert_eq("Smith", authors[1].family)
test.assert_eq("John", authors[1].given)

test.test("extract_authors multiple authors")
authors = bibliography.extract_authors({
    {family = "Smith", given = "John"},
    {family = "Doe", given = "Jane"}
})
test.assert_eq(2, #authors)
test.assert_eq("Smith", authors[1].family)
test.assert_eq("Doe", authors[2].family)

test.test("extract_authors literal name")
authors = bibliography.extract_authors({
    {literal = "World Health Organization"}
})
test.assert_eq(1, #authors)
test.assert_eq("World Health Organization", authors[1].literal)

test.test("extract_authors family only")
authors = bibliography.extract_authors({
    {family = "Aristotle"}
})
test.assert_eq(1, #authors)
test.assert_eq("Aristotle", authors[1].family)
test.assert_nil(authors[1].given)

test.test("extract_authors skips entries without family or literal")
authors = bibliography.extract_authors({
    {given = "NoFamily"},
    {family = "Valid", given = "Author"}
})
test.assert_eq(1, #authors)
test.assert_eq("Valid", authors[1].family)

-- ============================================
-- Tests for extract_date()
-- ============================================

print("")
print("-- extract_date tests --")

test.test("extract_date nil")
test.assert_nil(bibliography.extract_date(nil))

test.test("extract_date full date-parts with raw numbers")
local date = bibliography.extract_date({
    ["date-parts"] = {{2024, 3, 15}}
})
test.assert_not_nil(date)
test.assert_eq(2024, date.year)
test.assert_eq(3, date.month)
test.assert_eq(15, date.day)

test.test("extract_date full date-parts with MetaString values")
date = bibliography.extract_date({
    ["date-parts"] = {{{t = "MetaString", text = "2024"}, {t = "MetaString", text = "3"}, {t = "MetaString", text = "15"}}}
})
test.assert_not_nil(date)
test.assert_eq(2024, date.year)
test.assert_eq(3, date.month)
test.assert_eq(15, date.day)

test.test("extract_date year only")
date = bibliography.extract_date({
    ["date-parts"] = {{2024}}
})
test.assert_not_nil(date)
test.assert_eq(2024, date.year)
test.assert_nil(date.month)
test.assert_nil(date.day)

test.test("extract_date year and month")
date = bibliography.extract_date({
    ["date-parts"] = {{2024, 6}}
})
test.assert_eq(2024, date.year)
test.assert_eq(6, date.month)
test.assert_nil(date.day)

test.test("extract_date from year field")
date = bibliography.extract_date({year = 2020})
test.assert_not_nil(date)
test.assert_eq(2020, date.year)

test.test("extract_date from year field as string")
date = bibliography.extract_date({year = "2020"})
test.assert_not_nil(date)
test.assert_eq(2020, date.year)

test.test("extract_date empty date-parts")
date = bibliography.extract_date({["date-parts"] = {}})
test.assert_nil(date)

-- ============================================
-- Tests for extract_entry()
-- ============================================

print("")
print("-- extract_entry tests --")

test.test("extract_entry nil")
test.assert_nil(bibliography.extract_entry(nil))

test.test("extract_entry missing id")
test.assert_nil(bibliography.extract_entry({type = "book"}))

test.test("extract_entry minimal entry")
local entry = bibliography.extract_entry({
    id = "smith2024",
    type = "article-journal"
})
test.assert_not_nil(entry)
test.assert_eq("smith2024", entry.id)
test.assert_eq("article-journal", entry.type)

test.test("extract_entry complete entry")
entry = bibliography.extract_entry({
    id = "doe2023",
    type = "book",
    title = "A Great Book",
    author = {{family = "Doe", given = "Jane"}},
    issued = {["date-parts"] = {{2023}}},
    publisher = "Academic Press",
    ["publisher-place"] = "New York",
    DOI = "10.1234/test",
    URL = "https://example.com",
    ISBN = "978-0-123456-78-9",
    volume = "3",
    issue = "2",
    page = "100-200",
    ["container-title"] = "Test Journal",
    abstract = "A test abstract"
})
test.assert_eq("doe2023", entry.id)
test.assert_eq("book", entry.type)
test.assert_eq("A Great Book", entry.title)
test.assert_not_nil(entry.author)
test.assert_eq("Doe", entry.author[1].family)
test.assert_not_nil(entry.issued)
test.assert_eq(2023, entry.issued.year)
test.assert_eq("Academic Press", entry.publisher)
test.assert_eq("New York", entry["publisher-place"])
test.assert_eq("10.1234/test", entry.DOI)
test.assert_eq("https://example.com", entry.URL)
test.assert_eq("978-0-123456-78-9", entry.ISBN)
test.assert_eq("3", entry.volume)
test.assert_eq("2", entry.issue)
test.assert_eq("100-200", entry.page)
test.assert_eq("Test Journal", entry["container-title"])
test.assert_eq("A test abstract", entry.abstract)

test.test("extract_entry unknown type")
entry = bibliography.extract_entry({
    id = "test1",
    type = "unknown-type"
})
test.assert_eq("unknown-type", entry.type)

test.test("extract_entry nil type defaults to other")
entry = bibliography.extract_entry({id = "test2"})
test.assert_eq("other", entry.type)

-- ============================================
-- Tests for detect_style()
-- ============================================

print("")
print("-- detect_style tests --")

test.test("detect_style nil meta")
test.assert_eq("unknown", bibliography.detect_style(nil))

test.test("detect_style no csl")
test.assert_eq("unknown", bibliography.detect_style({}))

test.test("detect_style from csl path")
test.assert_eq("apa", bibliography.detect_style({csl = "/path/to/apa.csl"}))

test.test("detect_style from csl path with uppercase")
test.assert_eq("chicago-author-date", bibliography.detect_style({csl = "chicago-author-date.csl"}))

test.test("detect_style from citation-style field")
test.assert_eq("ieee", bibliography.detect_style({["citation-style"] = "IEEE"}))

test.test("detect_style non-table meta")
test.assert_eq("unknown", bibliography.detect_style("not a table"))

-- ============================================
-- Tests for TYPE_MAP
-- ============================================

print("")
print("-- TYPE_MAP tests --")

test.test("TYPE_MAP has article-journal")
test.assert_eq("article-journal", bibliography.TYPE_MAP["article-journal"])

test.test("TYPE_MAP has book")
test.assert_eq("book", bibliography.TYPE_MAP["book"])

test.test("TYPE_MAP unknown type returns nil")
test.assert_nil(bibliography.TYPE_MAP["nonexistent"])

print("")
test.summary()
