#!/usr/bin/env lua
-- tests/unit/test_lib_utils.lua
-- Unit tests for lib/utils.lua

-- Add lib directory to package path
package.path = "lib/?.lua;" .. package.path

local test = dofile("tests/unit/test_utils.lua")
local utils = dofile("lib/utils.lua")

print("Running utils.lua unit tests...")
print("")

-- ============================================
-- Tests for deep_copy()
-- ============================================

print("-- deep_copy tests --")

test.test("deep_copy nil")
test.assert_eq(nil, utils.deep_copy(nil))

test.test("deep_copy number")
test.assert_eq(42, utils.deep_copy(42))

test.test("deep_copy string")
test.assert_eq("hello", utils.deep_copy("hello"))

test.test("deep_copy boolean true")
test.assert_eq(true, utils.deep_copy(true))

test.test("deep_copy boolean false")
test.assert_eq(false, utils.deep_copy(false))

test.test("deep_copy empty table")
local empty = utils.deep_copy({})
test.assert_true(type(empty) == "table", "should be table")
test.assert_eq(0, #empty)

test.test("deep_copy simple array")
local arr = {1, 2, 3}
local arr_copy = utils.deep_copy(arr)
test.assert_eq(3, #arr_copy)
test.assert_eq(1, arr_copy[1])
test.assert_eq(2, arr_copy[2])
test.assert_eq(3, arr_copy[3])

test.test("deep_copy array is independent")
local original = {1, 2, 3}
local copy = utils.deep_copy(original)
copy[1] = 99
test.assert_eq(1, original[1], "original should be unchanged")
test.assert_eq(99, copy[1], "copy should be modified")

test.test("deep_copy simple object")
local obj = {name = "test", value = 42}
local obj_copy = utils.deep_copy(obj)
test.assert_eq("test", obj_copy.name)
test.assert_eq(42, obj_copy.value)

test.test("deep_copy object is independent")
local orig_obj = {name = "test"}
local copy_obj = utils.deep_copy(orig_obj)
copy_obj.name = "modified"
test.assert_eq("test", orig_obj.name, "original should be unchanged")
test.assert_eq("modified", copy_obj.name, "copy should be modified")

test.test("deep_copy nested table")
local nested = {
    outer = {
        inner = {
            value = "deep"
        }
    }
}
local nested_copy = utils.deep_copy(nested)
test.assert_eq("deep", nested_copy.outer.inner.value)

test.test("deep_copy nested is independent")
local orig_nested = {level1 = {level2 = {val = 1}}}
local copy_nested = utils.deep_copy(orig_nested)
copy_nested.level1.level2.val = 999
test.assert_eq(1, orig_nested.level1.level2.val, "original nested should be unchanged")
test.assert_eq(999, copy_nested.level1.level2.val, "copy nested should be modified")

test.test("deep_copy mixed array and object")
local mixed = {
    items = {1, 2, 3},
    meta = {count = 3}
}
local mixed_copy = utils.deep_copy(mixed)
test.assert_eq(3, #mixed_copy.items)
test.assert_eq(3, mixed_copy.meta.count)

test.test("deep_copy array of objects")
local arr_of_obj = {
    {id = 1, name = "first"},
    {id = 2, name = "second"}
}
local arr_copy2 = utils.deep_copy(arr_of_obj)
test.assert_eq(2, #arr_copy2)
test.assert_eq(1, arr_copy2[1].id)
test.assert_eq("second", arr_copy2[2].name)

test.test("deep_copy preserves table keys")
local with_keys = {["string-key"] = "value", [1] = "one", [true] = "bool-key"}
local keys_copy = utils.deep_copy(with_keys)
test.assert_eq("value", keys_copy["string-key"])
test.assert_eq("one", keys_copy[1])
test.assert_eq("bool-key", keys_copy[true])

-- ============================================
-- Tests for meta_to_string()
-- ============================================

print("")
print("-- meta_to_string tests --")

test.test("meta_to_string nil")
test.assert_eq(nil, utils.meta_to_string(nil))

test.test("meta_to_string plain string")
test.assert_eq("hello", utils.meta_to_string("hello"))

test.test("meta_to_string empty string")
test.assert_eq("", utils.meta_to_string(""))

test.test("meta_to_string MetaString with text")
local meta_string = {t = "MetaString", text = "metadata value"}
test.assert_eq("metadata value", utils.meta_to_string(meta_string))

test.test("meta_to_string MetaString with index 1")
local meta_string2 = {t = "MetaString", [1] = "indexed value"}
test.assert_eq("indexed value", utils.meta_to_string(meta_string2))

test.test("meta_to_string MetaString prefers text over index")
local meta_string3 = {t = "MetaString", text = "text value", [1] = "index value"}
test.assert_eq("text value", utils.meta_to_string(meta_string3))

test.test("meta_to_string with tag instead of t")
local meta_with_tag = {tag = "MetaString", text = "tag style"}
test.assert_eq("tag style", utils.meta_to_string(meta_with_tag))

test.test("meta_to_string unknown type returns nil")
local unknown = {t = "UnknownType", value = "something"}
test.assert_eq(nil, utils.meta_to_string(unknown))

test.test("meta_to_string number returns nil")
test.assert_eq(nil, utils.meta_to_string(42))

test.test("meta_to_string boolean returns nil")
test.assert_eq(nil, utils.meta_to_string(true))

test.test("meta_to_string empty table without pandoc returns nil")
-- Without pandoc global, a table without t/tag returns nil
local empty_table = {}
test.assert_eq(nil, utils.meta_to_string(empty_table))

-- Note: MetaInlines and MetaBlocks tests would require pandoc.utils.stringify
-- which is only available inside the Pandoc Lua environment.
-- These are covered by integration tests.

print("")
test.summary()
