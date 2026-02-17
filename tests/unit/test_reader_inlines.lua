#!/usr/bin/env lua
-- tests/unit/test_reader_inlines.lua
-- Unit tests for lib/reader_inlines.lua
-- Tests pure string/table functions that don't require Pandoc runtime

PANDOC_SCRIPT_FILE = "codex.lua"

local test = dofile("tests/unit/test_utils.lua")

-- reader_inlines uses pandoc.* constructors in most functions.
-- We load the module to test get_mark_type() and base_mark_type() (via mark categorization).
-- We need a minimal pandoc stub for the module to load (it references pandoc in mark_wrappers).
pandoc = {
    Strong = function(i) return {t = "Strong", content = i} end,
    Emph = function(i) return {t = "Emph", content = i} end,
    Strikeout = function(i) return {t = "Strikeout", content = i} end,
    Underline = function(i) return {t = "Underline", content = i} end,
    Superscript = function(i) return {t = "Superscript", content = i} end,
    Subscript = function(i) return {t = "Subscript", content = i} end,
}

local reader_inlines = dofile("lib/reader_inlines.lua")

print("Running reader_inlines unit tests...")
print("")

-- ============================================
-- Tests for get_mark_type()
-- ============================================

print("-- get_mark_type tests --")

test.test("get_mark_type string mark")
test.assert_eq("bold", reader_inlines.get_mark_type("bold"))

test.test("get_mark_type table mark with type")
test.assert_eq("link", reader_inlines.get_mark_type({type = "link", href = "http://x.com"}))

test.test("get_mark_type table mark without type")
test.assert_eq("unknown", reader_inlines.get_mark_type({href = "http://x.com"}))

test.test("get_mark_type number")
test.assert_eq("unknown", reader_inlines.get_mark_type(42))

test.test("get_mark_type nil")
test.assert_eq("unknown", reader_inlines.get_mark_type(nil))

test.test("get_mark_type empty string")
test.assert_eq("", reader_inlines.get_mark_type(""))

test.test("get_mark_type namespaced string mark")
test.assert_eq("semantic:citation", reader_inlines.get_mark_type("semantic:citation"))

test.test("get_mark_type table with namespaced type")
test.assert_eq("academic:theorem-ref", reader_inlines.get_mark_type({type = "academic:theorem-ref", target = "#thm-1"}))

-- ============================================
-- Tests for base_mark_type (via mark categorization in convert_node)
-- base_mark_type is local, but we can test its behavior indirectly
-- by examining how get_mark_type + namespace stripping work.
-- We replicate the logic here for direct testing.
-- ============================================

print("")
print("-- base_mark_type behavior tests --")

-- Replicate base_mark_type locally since it's not exported
local function base_mark_type(mark_type)
    return mark_type:match("^[^:]+:(.+)$") or mark_type
end

test.test("base_mark_type plain mark unchanged")
test.assert_eq("bold", base_mark_type("bold"))
test.assert_eq("italic", base_mark_type("italic"))
test.assert_eq("code", base_mark_type("code"))
test.assert_eq("link", base_mark_type("link"))

test.test("base_mark_type strips semantic namespace")
test.assert_eq("citation", base_mark_type("semantic:citation"))
test.assert_eq("footnote", base_mark_type("semantic:footnote"))
test.assert_eq("entity", base_mark_type("semantic:entity"))
test.assert_eq("glossary", base_mark_type("semantic:glossary"))

test.test("base_mark_type strips academic namespace")
test.assert_eq("theorem-ref", base_mark_type("academic:theorem-ref"))
test.assert_eq("equation-ref", base_mark_type("academic:equation-ref"))
test.assert_eq("algorithm-ref", base_mark_type("academic:algorithm-ref"))

test.test("base_mark_type handles double-colon edge case")
-- "a:b:c" should strip "a" prefix, leaving "b:c"
test.assert_eq("b:c", base_mark_type("a:b:c"))

-- ============================================
-- Tests for set_footnotes / clear_footnotes
-- ============================================

print("")
print("-- footnote management tests --")

test.test("set_footnotes stores table")
reader_inlines.set_footnotes({[1] = "note1", [2] = "note2"})
test.assert_eq("note1", reader_inlines._footnotes[1])
test.assert_eq("note2", reader_inlines._footnotes[2])

test.test("clear_footnotes empties table")
reader_inlines.clear_footnotes()
test.assert_eq(0, #reader_inlines._footnotes)

test.test("set_footnotes nil gives empty table")
reader_inlines.set_footnotes(nil)
test.assert_not_nil(reader_inlines._footnotes)

print("")
test.summary()
