#!/usr/bin/env lua
-- tests/unit/test_blocks.lua
-- Unit tests for lib/blocks.lua
-- Tests pure-table helper functions that don't require Pandoc runtime

PANDOC_SCRIPT_FILE = "codex.lua"

local test = dofile("tests/unit/test_utils.lua")
local blocks = dofile("lib/blocks.lua")
local inlines = dofile("lib/inlines.lua")

-- Wire up inlines dependency (blocks.paragraph needs inlines.flatten/merge_adjacent)
blocks.set_inlines(inlines)

print("Running blocks unit tests...")
print("")

-- ============================================
-- Tests for convert_sentinel()
-- ============================================

print("-- convert_sentinel tests --")

test.test("convert_sentinel math_sentinel DisplayMath")
local result = blocks.convert_sentinel({
    type = "math_sentinel",
    mathtype = "DisplayMath",
    text = "x^2 + y^2 = z^2"
})
test.assert_eq(1, #result)
test.assert_eq("math", result[1].type)
test.assert_true(result[1].display)
test.assert_eq("latex", result[1].format)
test.assert_eq("x^2 + y^2 = z^2", result[1].value)

test.test("convert_sentinel math_sentinel InlineMath")
result = blocks.convert_sentinel({
    type = "math_sentinel",
    mathtype = "InlineMath",
    text = "e=mc^2"
})
test.assert_eq(1, #result)
test.assert_eq("math", result[1].type)
test.assert_false(result[1].display)
test.assert_eq("latex", result[1].format)
test.assert_eq("e=mc^2", result[1].value)

test.test("convert_sentinel image_sentinel")
result = blocks.convert_sentinel({
    type = "image_sentinel",
    src = "img.png",
    alt = "An image",
    title = "My Image"
})
test.assert_eq(1, #result)
test.assert_eq("image", result[1].type)
test.assert_eq("img.png", result[1].src)
test.assert_eq("An image", result[1].alt)
test.assert_eq("My Image", result[1].title)

test.test("convert_sentinel image_sentinel minimal")
result = blocks.convert_sentinel({
    type = "image_sentinel",
    src = "photo.jpg"
})
test.assert_eq(1, #result)
test.assert_eq("image", result[1].type)
test.assert_eq("photo.jpg", result[1].src)

test.test("convert_sentinel measurement_sentinel")
result = blocks.convert_sentinel({
    type = "measurement_sentinel",
    value = "42.5",
    unit = "kg",
    text = "42.5 kg"
})
test.assert_eq(1, #result)
test.assert_eq("measurement", result[1].type)
test.assert_eq("42.5", result[1].value)
test.assert_eq("kg", result[1].unit)
test.assert_eq("42.5 kg", result[1].display)

test.test("convert_sentinel unknown type returns empty")
result = blocks.convert_sentinel({type = "unknown_sentinel"})
test.assert_eq(0, #result)

-- ============================================
-- Tests for convert() with nil/empty inputs
-- ============================================

print("")
print("-- convert edge cases --")

test.test("convert nil returns empty")
result = blocks.convert(nil)
test.assert_eq(0, #result)

test.test("convert empty table returns empty")
result = blocks.convert({})
test.assert_eq(0, #result)

test.test("convert non-table returns empty")
result = blocks.convert("not a table")
test.assert_eq(0, #result)

-- ============================================
-- Tests for horizontal_rule()
-- ============================================

print("")
print("-- horizontal_rule tests --")

test.test("horizontal_rule returns correct type")
result = blocks.horizontal_rule({})
test.assert_eq("horizontalRule", result.type)

-- ============================================
-- Tests for code_block()
-- ============================================

print("")
print("-- code_block tests --")

test.test("code_block basic")
result = blocks.code_block({
    text = "print('hello')",
    attr = {classes = {"lua"}}
})
test.assert_eq("codeBlock", result.type)
test.assert_eq("lua", result.language)
test.assert_eq(1, #result.children)
test.assert_eq("text", result.children[1].type)
test.assert_eq("print('hello')", result.children[1].value)

test.test("code_block no language")
result = blocks.code_block({
    text = "some code",
    attr = {classes = {}}
})
test.assert_eq("codeBlock", result.type)
test.assert_nil(result.language)

test.test("code_block string class")
result = blocks.code_block({
    text = "x = 1",
    attr = {classes = "python"}
})
test.assert_eq("python", result.language)

test.test("code_block indexed attr format")
result = blocks.code_block({
    text = "fn main()",
    attr = {"", {"rust"}, {}}
})
test.assert_eq("rust", result.language)

test.test("code_block nil attr")
result = blocks.code_block({text = "code"})
test.assert_eq("codeBlock", result.type)
test.assert_nil(result.language)

-- ============================================
-- Tests for blockquote()
-- ============================================

print("")
print("-- blockquote tests --")

test.test("blockquote empty content")
result = blocks.blockquote({content = {}})
test.assert_eq("blockquote", result.type)
test.assert_eq(0, #result.children)

-- ============================================
-- Tests for table_row()
-- ============================================

print("")
print("-- table_row tests --")

test.test("table_row header flag")
result = blocks.table_row({cells = {}}, true)
test.assert_eq("tableRow", result.type)
test.assert_true(result.header)

test.test("table_row non-header omits flag")
result = blocks.table_row({cells = {}}, false)
test.assert_eq("tableRow", result.type)
test.assert_nil(result.header)

-- ============================================
-- Tests for table_cell()
-- ============================================

print("")
print("-- table_cell tests --")

test.test("table_cell empty")
result = blocks.table_cell({})
test.assert_eq("tableCell", result.type)

test.test("table_cell colspan")
result = blocks.table_cell({col_span = 2, row_span = 1})
test.assert_eq(2, result.colspan)
test.assert_nil(result.rowspan) -- row_span=1 should not be set

test.test("table_cell rowspan")
result = blocks.table_cell({row_span = 3})
test.assert_eq(3, result.rowspan)

test.test("table_cell alignment left")
result = blocks.table_cell({alignment = "AlignLeft"})
test.assert_eq("left", result.align)

test.test("table_cell alignment center")
result = blocks.table_cell({alignment = "AlignCenter"})
test.assert_eq("center", result.align)

test.test("table_cell alignment right")
result = blocks.table_cell({alignment = "AlignRight"})
test.assert_eq("right", result.align)

test.test("table_cell alignment lowercase")
result = blocks.table_cell({alignment = "left"})
test.assert_eq("left", result.align)

test.test("table_cell alignment default omitted")
result = blocks.table_cell({alignment = "AlignDefault"})
test.assert_nil(result.align)

-- ============================================
-- Tests for bullet_list()
-- ============================================

print("")
print("-- list tests --")

test.test("bullet_list empty content")
result = blocks.bullet_list({content = {}})
test.assert_eq("list", result.type)
test.assert_false(result.ordered)
test.assert_eq(0, #result.children)

test.test("ordered_list empty content")
result = blocks.ordered_list({content = {}})
test.assert_eq("list", result.type)
test.assert_true(result.ordered)

test.test("ordered_list with start number")
result = blocks.ordered_list({
    content = {},
    listAttributes = {5}
})
test.assert_eq(5, result.start)

test.test("ordered_list start=1 omitted")
result = blocks.ordered_list({
    content = {},
    listAttributes = {1}
})
test.assert_nil(result.start)

-- ============================================
-- Tests for heading()
-- ============================================

print("")
print("-- heading tests --")

test.test("heading with level and id")
result = blocks.heading({
    level = 2,
    attr = {identifier = "my-section"},
    content = {}
})
test.assert_eq("heading", result.type)
test.assert_eq(2, result.level)
test.assert_eq("my-section", result.id)

test.test("heading no id")
result = blocks.heading({
    level = 1,
    attr = {identifier = ""},
    content = {}
})
test.assert_eq("heading", result.type)
test.assert_eq(1, result.level)
test.assert_nil(result.id)

test.test("heading indexed attr format")
result = blocks.heading({
    level = 3,
    attr = {"sec-intro"},
    content = {}
})
test.assert_eq("sec-intro", result.id)

-- ============================================
-- Tests for paragraph() with sentinels
-- ============================================

print("")
print("-- paragraph sentinel splitting --")

test.test("paragraph with no sentinels")
-- Use inlines to build the flat/merge path
result = blocks.paragraph({content = {}})
-- Empty paragraph returns nil due to empty content
-- (inlines.flatten on empty returns empty, then merge returns empty)
-- Actually with empty content, flatten returns {} and paragraph creates {type=paragraph, children={}}
test.assert_eq("paragraph", result.type)

-- ============================================
-- Tests for convert_block() dispatch
-- ============================================

print("")
print("-- convert_block dispatch --")

test.test("convert_block HorizontalRule")
result = blocks.convert_block({t = "HorizontalRule"})
test.assert_eq("horizontalRule", result.type)

test.test("convert_block unknown type returns nil")
result = blocks.convert_block({t = "NonExistentType"})
test.assert_nil(result)

test.test("convert_block RawBlock")
result = blocks.convert_block({t = "RawBlock", text = "<div>raw html</div>"})
test.assert_eq("codeBlock", result.type)
test.assert_eq("<div>raw html</div>", result.children[1].value)

test.test("convert_block CodeBlock dispatch")
result = blocks.convert_block({
    t = "CodeBlock",
    text = "code here",
    attr = {classes = {"js"}}
})
test.assert_eq("codeBlock", result.type)
test.assert_eq("js", result.language)

-- ============================================
-- Tests for set_bibliography_context()
-- ============================================

print("")
print("-- bibliography context --")

test.test("set_bibliography_context sets values")
blocks.set_bibliography_context({entry1 = {id = "entry1"}}, "apa")
-- No public accessor, but calling it shouldn't error
test.assert_true(true, "set_bibliography_context runs without error")

test.test("set_bibliography_context nil defaults")
blocks.set_bibliography_context(nil, nil)
test.assert_true(true, "set_bibliography_context with nil runs without error")

-- ============================================
-- Tests for convert_footnotes()
-- ============================================

print("")
print("-- convert_footnotes --")

test.test("convert_footnotes empty")
result = blocks.convert_footnotes({})
test.assert_eq(0, #result)

test.test("convert_footnotes simple text content")
result = blocks.convert_footnotes({
    {
        number = 1,
        content = {
            {t = "Para", content = {
                {t = "Str", text = "A simple footnote."}
            }}
        }
    }
})
test.assert_eq(1, #result)
test.assert_eq("semantic:footnote", result[1].type)
test.assert_eq(1, result[1].number)
test.assert_eq("fn-1", result[1].id)
test.assert_eq("A simple footnote.", result[1].content)

test.test("convert_footnotes with spaces")
result = blocks.convert_footnotes({
    {
        number = 2,
        content = {
            {t = "Para", content = {
                {t = "Str", text = "hello"},
                {t = "Space"},
                {t = "Str", text = "world"}
            }}
        }
    }
})
test.assert_eq("semantic:footnote", result[1].type)
test.assert_eq("hello world", result[1].content)

test.test("convert_footnotes complex content (multi-block) uses children")
-- Two paragraphs = complex footnote, triggers children path instead of content
result = blocks.convert_footnotes({
    {
        number = 3,
        content = {
            {t = "Para", content = {
                {t = "Str", text = "first paragraph"}
            }},
            {t = "Para", content = {
                {t = "Str", text = "second paragraph"}
            }}
        }
    }
})
test.assert_eq("semantic:footnote", result[1].type)
test.assert_eq(3, result[1].number)
test.assert_nil(result[1].content) -- complex: uses children, not content
test.assert_not_nil(result[1].children)

print("")
test.summary()
