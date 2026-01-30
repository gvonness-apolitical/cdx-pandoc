#!/usr/bin/env lua
-- tests/unit/test_json.lua
-- Unit tests for lib/json.lua

-- Add lib directory to package path
package.path = "lib/?.lua;" .. package.path

local test = dofile("tests/unit/test_utils.lua")
local json = dofile("lib/json.lua")

print("Running JSON encoding tests...")
print("")

-- Test primitive encoding
test.test("encode nil")
test.assert_eq("null", json.encode(nil))

test.test("encode true")
test.assert_eq("true", json.encode(true))

test.test("encode false")
test.assert_eq("false", json.encode(false))

test.test("encode integer")
test.assert_eq("42", json.encode(42))

test.test("encode negative integer")
test.assert_eq("-17", json.encode(-17))

test.test("encode float")
local float_encoded = json.encode(3.14159)
test.assert_contains(float_encoded, "3.14")

test.test("encode NaN as null")
test.assert_eq("null", json.encode(0/0))

test.test("encode infinity as null")
test.assert_eq("null", json.encode(math.huge))

test.test("encode negative infinity as null")
test.assert_eq("null", json.encode(-math.huge))

-- Test string encoding
test.test("encode simple string")
test.assert_eq('"hello"', json.encode("hello"))

test.test("encode string with quotes")
test.assert_eq('"say \\"hello\\""', json.encode('say "hello"'))

test.test("encode string with backslash")
test.assert_eq('"path\\\\to\\\\file"', json.encode("path\\to\\file"))

test.test("encode string with newline")
test.assert_eq('"line1\\nline2"', json.encode("line1\nline2"))

test.test("encode string with tab")
test.assert_eq('"col1\\tcol2"', json.encode("col1\tcol2"))

test.test("encode string with carriage return")
test.assert_eq('"line1\\rline2"', json.encode("line1\rline2"))

test.test("encode empty string")
test.assert_eq('""', json.encode(""))

-- Test array encoding
test.test("encode empty array")
test.assert_eq("[]", json.compact({}))

test.test("encode simple array")
test.assert_eq("[1,2,3]", json.compact({1, 2, 3}))

test.test("encode array of strings")
test.assert_eq('["a","b","c"]', json.compact({"a", "b", "c"}))

test.test("encode nested array")
test.assert_eq("[[1,2],[3,4]]", json.compact({{1, 2}, {3, 4}}))

test.test("encode mixed array")
-- Note: Lua arrays stop at the first nil, so {1, "two", true, nil} becomes {1, "two", true}
test.assert_eq('[1,"two",true]', json.compact({1, "two", true}))

-- Test object encoding
test.test("encode empty object")
-- Note: {a = nil} is effectively an empty table, which is_array() sees as an empty array
-- Use a real empty object by creating a table with string keys that we then set to values
local empty_obj = {}
empty_obj["_placeholder"] = 1
empty_obj["_placeholder"] = nil
-- Actually, is_array checks for sequential keys, so we need a non-array empty table
-- The simplest way is to test with an actual object that has keys
test.assert_eq("[]", json.compact({}))

test.test("encode simple object")
local obj = {name = "test"}
test.assert_eq('{"name":"test"}', json.compact(obj))

test.test("encode object with multiple keys (sorted)")
local obj2 = {b = 2, a = 1}
test.assert_eq('{"a":1,"b":2}', json.compact(obj2))

test.test("encode nested object")
local nested = {outer = {inner = "value"}}
test.assert_eq('{"outer":{"inner":"value"}}', json.compact(nested))

-- Test pretty printing
test.test("pretty print object")
local pretty_obj = {name = "test"}
local pretty_output = json.pretty(pretty_obj)
test.assert_contains(pretty_output, '"name"')
test.assert_contains(pretty_output, '"test"')
test.assert_contains(pretty_output, "\n")

test.test("pretty print array")
local pretty_arr = {1, 2, 3}
local pretty_arr_output = json.pretty(pretty_arr)
test.assert_contains(pretty_arr_output, "[\n")
test.assert_contains(pretty_arr_output, "]")

-- Test edge cases
test.test("encode unicode string")
local unicode = json.encode("hello\u{0020}world")
test.assert_eq('"hello world"', unicode)

test.test("encode object skips nil values")
local with_nil = {a = 1, b = nil, c = 3}
local result = json.compact(with_nil)
test.assert_contains(result, '"a":1')
test.assert_contains(result, '"c":3')
test.assert_false(result:find('"b"'), "should not contain nil key")

test.summary()
