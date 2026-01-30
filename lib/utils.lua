-- lib/utils.lua
-- Shared utility functions for Codex Pandoc writer

local M = {}

-- Extract string value from Pandoc MetaValue
-- Handles MetaString, MetaInlines, MetaBlocks, and plain strings
-- @param value Pandoc MetaValue or string
-- @return String value or nil
function M.meta_to_string(value)
    if not value then
        return nil
    end

    local t = value.t or value.tag

    if t == "MetaString" then
        return value.text or value[1]
    elseif t == "MetaInlines" then
        return pandoc.utils.stringify(value)
    elseif t == "MetaBlocks" then
        return pandoc.utils.stringify(value)
    elseif type(value) == "string" then
        return value
    elseif type(value) == "table" and not t then
        if pandoc and pandoc.utils and pandoc.utils.stringify then
            return pandoc.utils.stringify(value)
        end
    end

    return nil
end

-- Deep copy a table
-- @param t Table to copy
-- @return Deep copy of the table
function M.deep_copy(t)
    if type(t) ~= "table" then
        return t
    end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = M.deep_copy(v)
    end
    return copy
end

return M
