#!/usr/bin/env lua
-- tests/unit/test_utils.lua
-- Simple test framework for Codex Pandoc writer

local M = {}

-- Test counters
local passed = 0
local failed = 0
local test_name = ""

-- Set current test name for error reporting
function M.test(name)
    test_name = name
end

-- Assert that a value is truthy
function M.assert_true(value, message)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("FAIL: " .. test_name .. ": " .. (message or "expected true") .. "\n")
    end
end

-- Assert that a value is falsy
function M.assert_false(value, message)
    if not value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("FAIL: " .. test_name .. ": " .. (message or "expected false") .. "\n")
    end
end

-- Assert equality
function M.assert_eq(expected, actual, message)
    if expected == actual then
        passed = passed + 1
    else
        failed = failed + 1
        local msg = message or "expected equality"
        io.stderr:write("FAIL: " .. test_name .. ": " .. msg .. "\n")
        io.stderr:write("  expected: " .. tostring(expected) .. "\n")
        io.stderr:write("  actual:   " .. tostring(actual) .. "\n")
    end
end

-- Assert not equal
function M.assert_neq(not_expected, actual, message)
    if not_expected ~= actual then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("FAIL: " .. test_name .. ": " .. (message or "expected not equal") .. "\n")
    end
end

-- Assert nil
function M.assert_nil(value, message)
    if value == nil then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("FAIL: " .. test_name .. ": " .. (message or "expected nil") .. "\n")
    end
end

-- Assert not nil
function M.assert_not_nil(value, message)
    if value ~= nil then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("FAIL: " .. test_name .. ": " .. (message or "expected not nil") .. "\n")
    end
end

-- Assert table length
function M.assert_len(expected, tbl, message)
    local actual = tbl and #tbl or 0
    if expected == actual then
        passed = passed + 1
    else
        failed = failed + 1
        local msg = message or "expected length " .. expected
        io.stderr:write("FAIL: " .. test_name .. ": " .. msg .. " (got " .. actual .. ")\n")
    end
end

-- Assert that a string contains a substring
function M.assert_contains(haystack, needle, message)
    if haystack and haystack:find(needle, 1, true) then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("FAIL: " .. test_name .. ": " .. (message or "expected to contain: " .. needle) .. "\n")
    end
end

-- Deep equality check for tables
local function deep_equal(t1, t2)
    if type(t1) ~= type(t2) then
        return false
    end
    if type(t1) ~= "table" then
        return t1 == t2
    end
    for k, v in pairs(t1) do
        if not deep_equal(v, t2[k]) then
            return false
        end
    end
    for k, v in pairs(t2) do
        if t1[k] == nil then
            return false
        end
    end
    return true
end

-- Assert deep equality for tables
function M.assert_deep_eq(expected, actual, message)
    if deep_equal(expected, actual) then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("FAIL: " .. test_name .. ": " .. (message or "expected deep equality") .. "\n")
    end
end

-- Print test summary and exit with appropriate code
function M.summary()
    print("")
    print("Test Summary:")
    print("  Passed: " .. passed)
    print("  Failed: " .. failed)
    print("")
    if failed > 0 then
        os.exit(1)
    else
        print("All tests passed!")
        os.exit(0)
    end
end

return M
