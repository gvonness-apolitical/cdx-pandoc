#!/usr/bin/env lua
-- tests/unit/test_shared_utils.lua
-- Unit tests for shared utility functions in lib/utils.lua

local test = dofile("tests/unit/test_utils.lua")
local utils = dofile("lib/utils.lua")

print("Running shared utils unit tests...")
print("")

-- ============================================
-- Tests for has_class()
-- ============================================

print("-- has_class tests --")

test.test("has_class positive match")
test.assert_true(utils.has_class({"note", "warning"}, "note"))

test.test("has_class negative match")
test.assert_false(utils.has_class({"note", "warning"}, "tip"))

test.test("has_class nil classes")
test.assert_false(utils.has_class(nil, "note"))

test.test("has_class empty array")
test.assert_false(utils.has_class({}, "note"))

test.test("has_class single element match")
test.assert_true(utils.has_class({"exercise"}, "exercise"))

test.test("has_class single element no match")
test.assert_false(utils.has_class({"exercise"}, "hint"))

-- ============================================
-- Tests for insert_converted()
-- ============================================

print("")
print("-- insert_converted tests --")

test.test("insert_converted nil does nothing")
local target = {}
utils.insert_converted(target, nil)
test.assert_eq(0, #target)

test.test("insert_converted single block")
target = {}
utils.insert_converted(target, {type = "paragraph", children = {}})
test.assert_eq(1, #target)
test.assert_eq("paragraph", target[1].type)

test.test("insert_converted multi-block")
target = {}
utils.insert_converted(target, {
    multi = true,
    blocks = {
        {type = "paragraph", children = {}},
        {type = "heading", level = 1, children = {}}
    }
})
test.assert_eq(2, #target)
test.assert_eq("paragraph", target[1].type)
test.assert_eq("heading", target[2].type)

test.test("insert_converted multi-block empty")
target = {}
utils.insert_converted(target, {multi = true, blocks = {}})
test.assert_eq(0, #target)

test.test("insert_converted appends to existing")
target = {{type = "existing"}}
utils.insert_converted(target, {type = "new"})
test.assert_eq(2, #target)
test.assert_eq("existing", target[1].type)
test.assert_eq("new", target[2].type)

-- ============================================
-- Tests for generate_term_id()
-- ============================================

print("")
print("-- generate_term_id tests --")

test.test("generate_term_id simple text")
test.assert_eq("term-hello", utils.generate_term_id("hello"))

test.test("generate_term_id with spaces")
test.assert_eq("term-hello-world", utils.generate_term_id("hello world"))

test.test("generate_term_id with special chars")
test.assert_eq("term-dont-panic", utils.generate_term_id("Don't Panic!"))

test.test("generate_term_id mixed case")
test.assert_eq("term-camelcase", utils.generate_term_id("CamelCase"))

test.test("generate_term_id multiple spaces")
test.assert_eq("term-a-b", utils.generate_term_id("a   b"))

test.test("generate_term_id with numbers")
test.assert_eq("term-item-42", utils.generate_term_id("Item 42"))

-- ============================================
-- Tests for extract_block_attr()
-- ============================================

print("")
print("-- extract_block_attr tests --")

test.test("extract_block_attr with named fields (Pandoc 3.x)")
local block = {
    attr = {
        identifier = "my-id",
        classes = {"note", "warning"},
        attributes = {title = "Test"}
    }
}
local attr = utils.extract_block_attr(block)
test.assert_eq("my-id", attr.id)
test.assert_eq(2, #attr.classes)
test.assert_eq("note", attr.classes[1])
test.assert_eq("Test", attr.attributes.title)

test.test("extract_block_attr with indexed fields (older Pandoc)")
block = {
    attr = {"my-id", {"note"}, {title = "Test"}}
}
attr = utils.extract_block_attr(block)
test.assert_eq("my-id", attr.id)
test.assert_eq(1, #attr.classes)
test.assert_eq("note", attr.classes[1])
test.assert_eq("Test", attr.attributes.title)

test.test("extract_block_attr with nil attr")
block = {}
attr = utils.extract_block_attr(block)
test.assert_eq("", attr.id)
test.assert_eq(0, #attr.classes)

test.test("extract_block_attr with empty attr")
block = {attr = {}}
attr = utils.extract_block_attr(block)
test.assert_eq("", attr.id)

test.test("extract_block_attr with partial named fields")
block = {attr = {identifier = "test-id"}}
attr = utils.extract_block_attr(block)
test.assert_eq("test-id", attr.id)

-- ============================================
-- Tests for extension constants
-- ============================================

print("")
print("-- extension constant tests --")

test.test("EXT_SEMANTIC constant")
test.assert_eq("codex.semantic", utils.EXT_SEMANTIC)

test.test("EXT_ACADEMIC constant")
test.assert_eq("codex.academic", utils.EXT_ACADEMIC)

print("")
test.summary()
