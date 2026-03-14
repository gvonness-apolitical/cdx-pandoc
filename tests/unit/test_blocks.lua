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
test.assert_nil(result.language) -- no format → no language

test.test("convert_block RawBlock with format preserves language")
result = blocks.convert_block({t = "RawBlock", text = "<b>bold</b>", format = "html"})
test.assert_eq("codeBlock", result.type)
test.assert_eq("html", result.language)
test.assert_eq("<b>bold</b>", result.children[1].value)

test.test("convert_block RawBlock empty format omits language")
result = blocks.convert_block({t = "RawBlock", text = "raw", format = ""})
test.assert_nil(result.language)

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

-- ============================================
-- Tests for table_cell() complex content (Step 1a)
-- ============================================

print("")
print("-- table_cell complex content --")

test.test("table_cell with nested block content collects all children")
-- Simulate a cell containing a blockquote → paragraph → bold+text
-- After convert, blockquote has children array; all should be collected
result = blocks.table_cell({
    contents = {
        {t = "BlockQuote", content = {
            {t = "Para", content = {
                {t = "Strong", content = {
                    {t = "Str", text = "bold"}
                }},
                {t = "Space"},
                {t = "Str", text = "text"}
            }}
        }}
    }
})
test.assert_eq("tableCell", result.type)
-- Should have children from the blockquote's paragraph (bold+space+text merged)
test.assert_true(#result.children > 0, "expected non-empty children for complex cell")

-- ============================================
-- Tests for task list checkboxes (Step 2a)
-- ============================================

print("")
print("-- task list checkbox tests --")

test.test("list_item checked [x]")
result = blocks.list_item({
    {t = "Para", content = {
        {t = "Str", text = "[x] Done task"}
    }}
})
test.assert_eq("listItem", result.type)
test.assert_true(result.checked)
test.assert_eq("Done task", result.children[1].children[1].value)

test.test("list_item checked [X] uppercase")
result = blocks.list_item({
    {t = "Para", content = {
        {t = "Str", text = "[X] Also done"}
    }}
})
test.assert_true(result.checked)

test.test("list_item unchecked [ ]")
result = blocks.list_item({
    {t = "Para", content = {
        {t = "Str", text = "[ ] Not done"}
    }}
})
test.assert_false(result.checked)
test.assert_eq("Not done", result.children[1].children[1].value)

test.test("list_item unchecked []")
result = blocks.list_item({
    {t = "Para", content = {
        {t = "Str", text = "[] Empty checkbox"}
    }}
})
test.assert_false(result.checked)

test.test("list_item no checkbox omits checked field")
result = blocks.list_item({
    {t = "Para", content = {
        {t = "Str", text = "Regular item"}
    }}
})
test.assert_nil(result.checked)

-- ============================================
-- Tests for extract_subfigure() (Step 2b)
-- ============================================

print("")
print("-- extract_subfigure tests --")

-- Stub pandoc.utils.stringify for image() which calls it
pandoc = pandoc or {}
pandoc.utils = pandoc.utils or {}
pandoc.utils.stringify = pandoc.utils.stringify or function(t)
    if type(t) == "string" then return t end
    if type(t) == "table" then
        local parts = {}
        for _, item in ipairs(t) do
            if type(item) == "table" and item.text then
                table.insert(parts, item.text)
            elseif type(item) == "string" then
                table.insert(parts, item)
            end
        end
        return table.concat(parts)
    end
    return ""
end

test.test("extract_subfigure with image child")
result = blocks.extract_subfigure(
    {content = {
        {t = "Plain", content = {
            {t = "Image", src = "fig1.png", caption = {}}
        }}
    }},
    {},
    ""
)
test.assert_not_nil(result)
test.assert_eq(1, #result.children)
test.assert_eq("image", result.children[1].type)
test.assert_eq("fig1.png", result.children[1].src)

test.test("extract_subfigure with ID and label attrs")
result = blocks.extract_subfigure(
    {content = {
        {t = "Plain", content = {
            {t = "Image", src = "fig2.png", caption = {}}
        }}
    }},
    {label = "(a)"},
    "subfig-1"
)
test.assert_eq("subfig-1", result.id)
test.assert_eq("(a)", result.label)

test.test("extract_subfigure empty div returns nil")
result = blocks.extract_subfigure({content = {}}, {}, "")
test.assert_nil(result)

-- ============================================
-- Tests for LineBlock handler (Step 2c)
-- ============================================

print("")
print("-- LineBlock handler tests --")

test.test("LineBlock produces multi-block paragraphs")
result = blocks.convert_block({
    t = "LineBlock",
    content = {
        {{t = "Str", text = "Line one"}},
        {{t = "Str", text = "Line two"}}
    }
})
test.assert_true(result.multi)
test.assert_eq(2, #result.blocks)
test.assert_eq("paragraph", result.blocks[1].type)
test.assert_eq("paragraph", result.blocks[2].type)

test.test("LineBlock empty content produces empty blocks")
result = blocks.convert_block({
    t = "LineBlock",
    content = {}
})
test.assert_true(result.multi)
test.assert_eq(0, #result.blocks)

print("")
test.summary()
