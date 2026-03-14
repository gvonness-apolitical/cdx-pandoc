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

-- ============================================
-- Tests for reader block handler output (Step 3a)
-- Requires Pandoc stubs for constructors
-- ============================================

print("")
print("-- reader block handler output --")

-- Additional Pandoc stubs needed for handler tests
pandoc.Header = function(level, inlines, attr)
    return {t = "Header", level = level, content = inlines, attr = attr}
end
pandoc.Attr = function(id, classes, attrs)
    return {identifier = id or "", classes = classes or {}, attributes = attrs or {}}
end
pandoc.CodeBlock = function(text, attr)
    return {t = "CodeBlock", text = text, attr = attr}
end
pandoc.BlockQuote = function(blocks)
    return {t = "BlockQuote", content = blocks}
end
pandoc.BulletList = function(items)
    return {t = "BulletList", content = items}
end
pandoc.OrderedList = function(items, attrs)
    return {t = "OrderedList", content = items, listAttributes = attrs}
end
pandoc.ListAttributes = function(start)
    return {start}
end
pandoc.Plain = function(inlines)
    return {t = "Plain", content = inlines}
end
pandoc.Math = function(mathtype, text)
    return {t = "Math", mathtype = mathtype, text = text}
end
pandoc.DisplayMath = "DisplayMath"
pandoc.InlineMath = "InlineMath"
pandoc.Image = function(alt, src, title)
    return {t = "Image", caption = alt, src = src, title = title}
end
pandoc.Figure = function(content, caption, attr)
    return {t = "Figure", content = {content}, caption = caption, attr = attr}
end
pandoc.Blocks = function(blocks)
    return blocks
end
pandoc.DefinitionList = function(items)
    return {t = "DefinitionList", content = items}
end
pandoc.Div = function(content, attr)
    return {t = "Div", content = content, attr = attr}
end
pandoc.Link = function(inlines, target, title)
    return {t = "Link", content = inlines, target = target, title = title}
end
pandoc.Span = function(inlines, attr)
    return {t = "Span", content = inlines, attr = attr}
end
pandoc.SimpleTable = function(caption, aligns, widths, header, rows)
    return {caption = caption, aligns = aligns, widths = widths, header = header, rows = rows}
end
pandoc.utils = pandoc.utils or {}
pandoc.utils.from_simple_table = function(simple)
    return {t = "Table", simple = simple}
end

-- Wire up reader_inlines stub for handler tests
local reader_inlines_stub = {
    convert = function(nodes)
        -- Return a simple stub inline for each text node
        local result = {}
        for _, node in ipairs(nodes) do
            if node.value then
                table.insert(result, {t = "Str", text = node.value})
            end
        end
        return result
    end
}
reader_blocks.set_inlines(reader_inlines_stub)

test.test("paragraph handler returns Para")
result = reader_blocks.convert_block({
    type = "paragraph",
    children = {{type = "text", value = "Hello world"}}
})
test.assert_not_nil(result)
test.assert_eq("Para", result.t)

test.test("paragraph handler with empty children returns nil")
result = reader_blocks.convert_block({
    type = "paragraph",
    children = {}
})
test.assert_nil(result)

test.test("heading handler returns Header with level")
result = reader_blocks.convert_block({
    type = "heading",
    level = 2,
    id = "sec-intro",
    children = {{type = "text", value = "Introduction"}}
})
test.assert_not_nil(result)
test.assert_eq("Header", result.t)
test.assert_eq(2, result.level)
test.assert_eq("sec-intro", result.attr.identifier)

test.test("code_block handler returns CodeBlock")
result = reader_blocks.convert_block({
    type = "codeBlock",
    language = "python",
    children = {{type = "text", value = "print('hi')"}}
})
test.assert_not_nil(result)
test.assert_eq("CodeBlock", result.t)
test.assert_eq("print('hi')", result.text)
test.assert_eq("python", result.attr.classes[1])

test.test("code_block handler without language")
result = reader_blocks.convert_block({
    type = "codeBlock",
    children = {{type = "text", value = "code"}}
})
test.assert_eq("CodeBlock", result.t)
test.assert_eq(0, #result.attr.classes)

test.test("blockquote handler returns BlockQuote")
result = reader_blocks.convert_block({
    type = "blockquote",
    children = {{type = "paragraph", children = {{type = "text", value = "quoted"}}}}
})
test.assert_not_nil(result)
test.assert_eq("BlockQuote", result.t)

test.test("list handler returns BulletList for unordered")
result = reader_blocks.convert_block({
    type = "list",
    ordered = false,
    children = {
        {type = "listItem", children = {
            {type = "paragraph", children = {{type = "text", value = "item 1"}}}
        }}
    }
})
test.assert_not_nil(result)
test.assert_eq("BulletList", result.t)

test.test("list handler returns OrderedList for ordered")
result = reader_blocks.convert_block({
    type = "list",
    ordered = true,
    children = {
        {type = "listItem", children = {
            {type = "paragraph", children = {{type = "text", value = "item 1"}}}
        }}
    }
})
test.assert_not_nil(result)
test.assert_eq("OrderedList", result.t)

test.test("table_block handler returns Table")
result = reader_blocks.convert_block({
    type = "table",
    children = {
        {type = "tableRow", header = true, children = {
            {type = "tableCell", children = {{type = "text", value = "Col1"}}}
        }},
        {type = "tableRow", children = {
            {type = "tableCell", children = {{type = "text", value = "Val1"}}}
        }}
    }
})
test.assert_not_nil(result)
test.assert_eq("Table", result.t)

test.test("math_block handler returns Para with Math")
result = reader_blocks.convert_block({
    type = "math",
    display = true,
    value = "x^2 + y^2"
})
test.assert_not_nil(result)
test.assert_eq("Para", result.t)

test.test("image_block handler returns Figure")
result = reader_blocks.convert_block({
    type = "image",
    src = "photo.png",
    alt = "A photo"
})
test.assert_not_nil(result)
test.assert_eq("Figure", result.t)

test.test("definition_list handler returns DefinitionList")
result = reader_blocks.convert_block({
    type = "definitionList",
    children = {
        {type = "definitionItem", children = {
            {type = "definitionTerm", children = {{type = "text", value = "Term"}}},
            {type = "definitionDescription", children = {
                {type = "paragraph", children = {{type = "text", value = "Def"}}}
            }}
        }}
    }
})
test.assert_not_nil(result)
test.assert_eq("DefinitionList", result.t)

test.test("admonition handler returns Div with variant class")
result = reader_blocks.convert_block({
    type = "admonition",
    variant = "warning",
    children = {{type = "paragraph", children = {{type = "text", value = "Be careful!"}}}}
})
test.assert_not_nil(result)
test.assert_eq("Div", result.t)
test.assert_eq("warning", result.attr.classes[1])

test.test("horizontalRule handler returns HorizontalRule")
result = reader_blocks.convert_block({type = "horizontalRule"})
test.assert_not_nil(result)
test.assert_eq("HorizontalRule", result.t)

print("")
test.summary()
