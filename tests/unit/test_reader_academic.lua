#!/usr/bin/env lua
-- tests/unit/test_reader_academic.lua
-- Unit tests for lib/reader_academic.lua
-- Tests type-to-class mapping and dispatch structure (no Pandoc runtime needed)

PANDOC_SCRIPT_FILE = "codex.lua"

local test = dofile("tests/unit/test_utils.lua")

-- Minimal pandoc stubs needed at load time
pandoc = {}

local reader_academic = dofile("lib/reader_academic.lua")

print("Running reader_academic unit tests...")
print("")

-- ============================================
-- Tests for convert_block() dispatch routing
-- Without reader_blocks set, methods will error on convert calls,
-- so we test the type routing and nil handling.
-- ============================================

print("-- convert_block type dispatch --")

test.test("convert_block unknown academic type returns nil")
test.assert_nil(reader_academic.convert_block({type = "academic:unknown"}))

test.test("convert_block empty type returns nil")
test.assert_nil(reader_academic.convert_block({type = ""}))

test.test("convert_block nil type returns nil")
test.assert_nil(reader_academic.convert_block({}))

-- ============================================
-- Tests for academic block type recognition
-- Verify all expected academic types are handled
-- ============================================

print("")
print("-- academic type recognition --")

-- We test that convert_block doesn't return nil for known types
-- by providing a mock reader_blocks that returns empty results
local mock_reader_blocks = {
    convert = function() return {} end,
}
reader_academic.set_reader_blocks(mock_reader_blocks)

-- Stub out the pandoc constructors needed by the handlers
pandoc.Div = function(content, attr) return {t = "Div", content = content, attr = attr} end
pandoc.Attr = function(id, classes, attrs)
    return {identifier = id or "", classes = classes or {}, attributes = attrs or {}}
end
pandoc.Header = function(level, inlines) return {t = "Header", level = level, content = inlines} end
pandoc.CodeBlock = function(text, attr) return {t = "CodeBlock", text = text, attr = attr} end
pandoc.Para = function(inlines) return {t = "Para", content = inlines} end
pandoc.Str = function(text) return {t = "Str", text = text} end
pandoc.Math = function(mathtype, text) return {t = "Math", mathtype = mathtype, text = text} end
pandoc.DisplayMath = "DisplayMath"
pandoc.Plain = function(inlines) return {t = "Plain", content = inlines} end

test.test("theorem block recognized")
local result = reader_academic.convert_block({
    type = "academic:theorem",
    variant = "theorem",
    children = {}
})
test.assert_not_nil(result)
test.assert_eq("Div", result.t)
test.assert_eq("theorem", result.attr.classes[1])

test.test("theorem block preserves id")
result = reader_academic.convert_block({
    type = "academic:theorem",
    variant = "lemma",
    id = "lem-1",
    children = {}
})
test.assert_eq("lem-1", result.attr.identifier)
test.assert_eq("lemma", result.attr.classes[1])

test.test("theorem block with title attribute")
result = reader_academic.convert_block({
    type = "academic:theorem",
    variant = "theorem",
    title = "Main Theorem",
    children = {}
})
test.assert_eq("Main Theorem", result.attr.attributes.title)

test.test("proof block recognized")
result = reader_academic.convert_block({
    type = "academic:proof",
    children = {}
})
test.assert_not_nil(result)
test.assert_eq("proof", result.attr.classes[1])

test.test("proof block with of and method")
result = reader_academic.convert_block({
    type = "academic:proof",
    of = "thm-max",
    method = "contradiction",
    children = {}
})
test.assert_eq("thm-max", result.attr.attributes.of)
test.assert_eq("contradiction", result.attr.attributes.method)

test.test("exercise block recognized")
result = reader_academic.convert_block({
    type = "academic:exercise",
    children = {}
})
test.assert_not_nil(result)
test.assert_eq("exercise", result.attr.classes[1])

test.test("exercise block with difficulty")
result = reader_academic.convert_block({
    type = "academic:exercise",
    difficulty = "hard",
    children = {}
})
test.assert_eq("hard", result.attr.attributes.difficulty)

test.test("exercise-set block recognized")
result = reader_academic.convert_block({
    type = "academic:exercise-set",
    exercises = {},
    children = {}
})
test.assert_not_nil(result)
test.assert_eq("exercise-set", result.attr.classes[1])

test.test("algorithm block recognized")
result = reader_academic.convert_block({
    type = "academic:algorithm",
    children = {}
})
test.assert_not_nil(result)
test.assert_eq("algorithm", result.attr.classes[1])

test.test("algorithm block with title and lines")
result = reader_academic.convert_block({
    type = "academic:algorithm",
    id = "alg-sort",
    title = "QuickSort",
    lines = {"function sort(A)", "  partition(A)", "end"}
})
test.assert_eq("alg-sort", result.attr.identifier)
test.assert_eq("QuickSort", result.attr.attributes.title)
-- Should have content with a CodeBlock
test.assert_true(#result.content > 0)

test.test("abstract block recognized")
result = reader_academic.convert_block({
    type = "academic:abstract",
    children = {}
})
test.assert_not_nil(result)
test.assert_eq("abstract", result.attr.classes[1])

test.test("abstract block with keywords")
result = reader_academic.convert_block({
    type = "academic:abstract",
    keywords = {"machine learning", "NLP"},
    children = {}
})
test.assert_eq("abstract", result.attr.classes[1])
-- Keywords are added as nested Div
test.assert_true(#result.content > 0)

test.test("equation-group block with value")
result = reader_academic.convert_block({
    type = "academic:equation-group",
    environment = "align",
    value = "\\begin{align}\nx = 1\n\\end{align}"
})
test.assert_not_nil(result)
test.assert_eq("Para", result.t)

test.test("equation-group block reconstructs from lines")
result = reader_academic.convert_block({
    type = "academic:equation-group",
    environment = "gather",
    lines = {"a + b", "c + d"}
})
test.assert_not_nil(result)
test.assert_eq("Para", result.t)

print("")
test.summary()
