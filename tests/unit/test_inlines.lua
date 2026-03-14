#!/usr/bin/env lua
-- tests/unit/test_inlines.lua
-- Unit tests for lib/inlines.lua
-- Tests functions that operate on plain Lua tables (no Pandoc dependency)

-- Need to provide a minimal PANDOC_SCRIPT_FILE so the module can load utils
PANDOC_SCRIPT_FILE = "codex.lua"

local test = dofile("tests/unit/test_utils.lua")
local inlines = dofile("lib/inlines.lua")

print("Running inlines unit tests...")
print("")

-- ============================================
-- Tests for text_node()
-- ============================================

print("-- text_node tests --")

test.test("text_node simple text")
local node = inlines.text_node("hello")
test.assert_eq("text", node.type)
test.assert_eq("hello", node.value)
test.assert_nil(node.marks)

test.test("text_node with empty marks")
node = inlines.text_node("hello", {})
test.assert_eq("hello", node.value)
test.assert_nil(node.marks)

test.test("text_node with bold mark")
node = inlines.text_node("bold", {"bold"})
test.assert_eq("bold", node.value)
test.assert_not_nil(node.marks)
test.assert_eq(1, #node.marks)
test.assert_eq("bold", node.marks[1])

test.test("text_node with multiple marks sorted")
node = inlines.text_node("text", {"italic", "bold"})
test.assert_eq(2, #node.marks)
test.assert_eq("bold", node.marks[1])
test.assert_eq("italic", node.marks[2])

test.test("text_node with object mark")
node = inlines.text_node("link", {{type = "link", href = "http://example.com"}})
test.assert_eq(1, #node.marks)
test.assert_eq("link", node.marks[1].type)
test.assert_eq("http://example.com", node.marks[1].href)

-- ============================================
-- Tests for merge_adjacent()
-- ============================================

print("")
print("-- merge_adjacent tests --")

test.test("merge_adjacent empty input")
local result = inlines.merge_adjacent({})
test.assert_eq(0, #result)

test.test("merge_adjacent single node")
result = inlines.merge_adjacent({
    {type = "text", value = "hello"}
})
test.assert_eq(1, #result)
test.assert_eq("hello", result[1].value)

test.test("merge_adjacent same marks merge")
result = inlines.merge_adjacent({
    {type = "text", value = "hello"},
    {type = "text", value = " world"}
})
test.assert_eq(1, #result)
test.assert_eq("hello world", result[1].value)

test.test("merge_adjacent different marks no merge")
result = inlines.merge_adjacent({
    {type = "text", value = "plain"},
    {type = "text", value = "bold", marks = {"bold"}}
})
test.assert_eq(2, #result)
test.assert_eq("plain", result[1].value)
test.assert_eq("bold", result[2].value)

test.test("merge_adjacent sentinel breaks merging")
result = inlines.merge_adjacent({
    {type = "text", value = "before"},
    {type = "math_sentinel", mathtype = "DisplayMath", text = "x^2", value = ""},
    {type = "text", value = "after"}
})
test.assert_eq(3, #result)
test.assert_eq("before", result[1].value)
test.assert_eq("math_sentinel", result[2].type)
test.assert_eq("after", result[3].value)

test.test("merge_adjacent empty value nodes filtered")
result = inlines.merge_adjacent({
    {type = "text", value = ""},
    {type = "text", value = "visible"}
})
test.assert_eq(1, #result)
test.assert_eq("visible", result[1].value)

test.test("merge_adjacent complex marks array equal")
result = inlines.merge_adjacent({
    {type = "text", value = "a", marks = {"bold", "italic"}},
    {type = "text", value = "b", marks = {"bold", "italic"}}
})
test.assert_eq(1, #result)
test.assert_eq("ab", result[1].value)

test.test("merge_adjacent complex marks array not equal")
result = inlines.merge_adjacent({
    {type = "text", value = "a", marks = {"bold", "italic"}},
    {type = "text", value = "b", marks = {"bold"}}
})
test.assert_eq(2, #result)
test.assert_eq("a", result[1].value)
test.assert_eq("b", result[2].value)

test.test("merge_adjacent link marks equal")
result = inlines.merge_adjacent({
    {type = "text", value = "click ", marks = {{type = "link", href = "http://x.com"}}},
    {type = "text", value = "here", marks = {{type = "link", href = "http://x.com"}}}
})
test.assert_eq(1, #result)
test.assert_eq("click here", result[1].value)

test.test("merge_adjacent link marks different href")
result = inlines.merge_adjacent({
    {type = "text", value = "a", marks = {{type = "link", href = "http://a.com"}}},
    {type = "text", value = "b", marks = {{type = "link", href = "http://b.com"}}}
})
test.assert_eq(2, #result)

test.test("merge_adjacent all empty values")
result = inlines.merge_adjacent({
    {type = "text", value = ""},
    {type = "text", value = ""}
})
test.assert_eq(0, #result)

-- ============================================
-- Tests for new_context() and reset_context()
-- ============================================

print("")
print("-- context tests --")

test.test("new_context returns clean state")
local ctx = inlines.new_context()
test.assert_not_nil(ctx)
test.assert_eq(0, #ctx.footnotes)
test.assert_eq(0, ctx.footnote_counter)

test.test("reset_context clears default context")
inlines._default_context.footnote_counter = 5
inlines.reset_context()
test.assert_eq(0, inlines._default_context.footnote_counter)

-- ============================================
-- Tests for Quoted handler (Step 2d)
-- ============================================

print("")
print("-- Quoted handler tests --")

-- Provide pandoc.utils.stringify stub for the Span handler
pandoc = pandoc or {}
pandoc.utils = pandoc.utils or {}
pandoc.utils.stringify = pandoc.utils.stringify or function(t)
    if type(t) == "string" then return t end
    if type(t) == "table" then
        local parts = {}
        for _, item in ipairs(t) do
            if type(item) == "table" and item.text then
                table.insert(parts, item.text)
            end
        end
        return table.concat(parts)
    end
    return ""
end

test.test("Quoted DoubleQuote wraps content in double quotes")
local ctx = inlines.new_context()
local result = inlines.flatten(
    {{t = "Quoted", quotetype = "DoubleQuote", content = {
        {t = "Str", text = "hello"}
    }}},
    nil,
    ctx
)
-- Should produce: " hello "
test.assert_eq(3, #result)
test.assert_eq('"', result[1].value)
test.assert_eq("hello", result[2].value)
test.assert_eq('"', result[3].value)

test.test("Quoted SingleQuote wraps content in single quotes")
ctx = inlines.new_context()
result = inlines.flatten(
    {{t = "Quoted", quotetype = "SingleQuote", content = {
        {t = "Str", text = "word"}
    }}},
    nil,
    ctx
)
test.assert_eq(3, #result)
test.assert_eq("'", result[1].value)
test.assert_eq("word", result[2].value)
test.assert_eq("'", result[3].value)

-- ============================================
-- Tests for SmallCaps handler (Step 2d)
-- ============================================

print("")
print("-- SmallCaps handler tests --")

test.test("SmallCaps passes through content unchanged")
ctx = inlines.new_context()
result = inlines.flatten(
    {{t = "SmallCaps", content = {
        {t = "Str", text = "SMALL CAPS"}
    }}},
    nil,
    ctx
)
test.assert_eq(1, #result)
test.assert_eq("SMALL CAPS", result[1].value)
test.assert_nil(result[1].marks) -- no marks added

-- ============================================
-- Tests for Span with anchor-only ID (Step 2d)
-- ============================================

print("")
print("-- Span anchor tests --")

test.test("Span with ID produces anchor mark")
ctx = inlines.new_context()
result = inlines.flatten(
    {{t = "Span", attr = {identifier = "my-anchor", classes = {}, attributes = {}},
      content = {{t = "Str", text = "target"}}}},
    nil,
    ctx
)
test.assert_eq(1, #result)
test.assert_eq("target", result[1].value)
test.assert_not_nil(result[1].marks)
test.assert_eq("anchor", result[1].marks[1].type)
test.assert_eq("my-anchor", result[1].marks[1].id)

test.test("Span with empty ID and no classes passes through")
ctx = inlines.new_context()
result = inlines.flatten(
    {{t = "Span", attr = {identifier = "", classes = {}, attributes = {}},
      content = {{t = "Str", text = "plain"}}}},
    nil,
    ctx
)
test.assert_eq(1, #result)
test.assert_eq("plain", result[1].value)
test.assert_nil(result[1].marks) -- no marks

print("")
test.summary()
