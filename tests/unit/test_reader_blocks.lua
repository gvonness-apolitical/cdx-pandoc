#!/usr/bin/env lua
-- tests/unit/test_reader_blocks.lua
-- Unit tests for lib/reader_blocks.lua
-- Tests dispatch table structure and handler existence (no Pandoc runtime needed)

PANDOC_SCRIPT_FILE = "codex.lua"

local test = dofile("tests/unit/test_utils.lua")

-- Provide pandoc stubs needed at module load time
pandoc = {
    HorizontalRule = function() return {t = "HorizontalRule"} end,
    AlignDefault = "AlignDefault",
}

local reader_blocks = dofile("lib/reader_blocks.lua")

print("Running reader_blocks unit tests...")
print("")

-- ============================================
-- Tests for convert_block() dispatch routing
-- ============================================

print("-- convert_block dispatch routing --")

test.test("convert_block nil/empty type returns nil")
test.assert_nil(reader_blocks.convert_block({type = ""}))

test.test("convert_block unknown type returns nil")
test.assert_nil(reader_blocks.convert_block({type = "completely_unknown"}))

test.test("convert_block skips semantic:footnote")
test.assert_nil(reader_blocks.convert_block({type = "semantic:footnote", number = 1}))

test.test("convert_block skips semantic:bibliography")
test.assert_nil(reader_blocks.convert_block({type = "semantic:bibliography"}))

test.test("convert_block skips semantic:glossary")
test.assert_nil(reader_blocks.convert_block({type = "semantic:glossary"}))

test.test("convert_block skips definitionItem")
test.assert_nil(reader_blocks.convert_block({type = "definitionItem"}))

test.test("convert_block skips definitionTerm")
test.assert_nil(reader_blocks.convert_block({type = "definitionTerm"}))

test.test("convert_block skips definitionDescription")
test.assert_nil(reader_blocks.convert_block({type = "definitionDescription"}))

test.test("convert_block skips figcaption")
test.assert_nil(reader_blocks.convert_block({type = "figcaption"}))

test.test("convert_block skips listItem")
test.assert_nil(reader_blocks.convert_block({type = "listItem"}))

test.test("convert_block skips tableRow")
test.assert_nil(reader_blocks.convert_block({type = "tableRow"}))

test.test("convert_block skips tableCell")
test.assert_nil(reader_blocks.convert_block({type = "tableCell"}))

-- ============================================
-- Tests for skip_types completeness
-- All sub-block types that should be skipped
-- ============================================

print("")
print("-- skip_types coverage --")

local expected_skip = {
    "semantic:footnote", "definitionItem", "definitionTerm",
    "definitionDescription", "figcaption", "listItem",
    "tableRow", "tableCell", "semantic:glossary", "semantic:bibliography"
}

for _, skip_type in ipairs(expected_skip) do
    test.test("skip_types includes " .. skip_type)
    test.assert_nil(reader_blocks.convert_block({type = skip_type}))
end

-- ============================================
-- Tests for academic block routing
-- Without reader_academic set, academic blocks should warn and return nil
-- ============================================

print("")
print("-- academic block routing --")

test.test("academic block without reader_academic returns nil")
test.assert_nil(reader_blocks.convert_block({type = "academic:theorem", children = {}}))

test.test("academic:proof without reader_academic returns nil")
test.assert_nil(reader_blocks.convert_block({type = "academic:proof", children = {}}))

test.test("academic:equation-group without reader_academic returns nil")
test.assert_nil(reader_blocks.convert_block({type = "academic:equation-group", lines = {}}))

-- ============================================
-- Tests for extension block skipping
-- ============================================

print("")
print("-- extension block skipping --")

test.test("semantic:unknown extension skipped")
test.assert_nil(reader_blocks.convert_block({type = "semantic:unknown_ext"}))

test.test("forms:text extension skipped")
test.assert_nil(reader_blocks.convert_block({type = "forms:text"}))

test.test("collaboration:comment extension skipped")
test.assert_nil(reader_blocks.convert_block({type = "collaboration:comment"}))

-- ============================================
-- Tests for convert() with empty/nil inputs
-- ============================================

print("")
print("-- convert edge cases --")

test.test("convert empty blocks")
local result = reader_blocks.convert({})
test.assert_eq(0, #result)

-- ============================================
-- Tests for extract_footnotes()
-- Need pandoc.Para and pandoc.Str stubs
-- ============================================

print("")
print("-- extract_footnotes structure --")

pandoc.Para = function(inlines) return {t = "Para", content = inlines} end
pandoc.Str = function(text) return {t = "Str", text = text} end
pandoc.Note = function(blocks) return {t = "Note", content = blocks} end

test.test("extract_footnotes from empty list")
result = reader_blocks.extract_footnotes({})
test.assert_not_nil(result)

test.test("extract_footnotes ignores non-footnote blocks")
result = reader_blocks.extract_footnotes({
    {type = "paragraph", children = {}},
    {type = "heading", level = 1, children = {}}
})
-- Should return empty footnotes table (no numeric keys)
local count = 0
for _ in pairs(result) do count = count + 1 end
test.assert_eq(0, count)

test.test("extract_footnotes extracts simple text footnotes")
result = reader_blocks.extract_footnotes({
    {type = "semantic:footnote", number = 1, content = "A footnote."},
    {type = "semantic:footnote", number = 2, content = "Another note."}
})
test.assert_not_nil(result[1])
test.assert_not_nil(result[2])
test.assert_eq("Note", result[1].t)
test.assert_eq("Note", result[2].t)

print("")
test.summary()
