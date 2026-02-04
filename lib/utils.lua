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

    -- Handle plain strings first
    if type(value) == "string" then
        return value
    end

    -- Only tables can have Pandoc type tags
    if type(value) ~= "table" then
        return nil
    end

    local t = value.t or value.tag

    if t == "MetaString" then
        return value.text or value[1]
    elseif t == "MetaInlines" then
        return pandoc.utils.stringify(value)
    elseif t == "MetaBlocks" then
        return pandoc.utils.stringify(value)
    elseif not t then
        -- Table without type tag - try stringify if available
        if pandoc and pandoc.utils and pandoc.utils.stringify then
            return pandoc.utils.stringify(value)
        end
    end

    return nil
end

-- Extension ID constants
M.EXT_SEMANTIC = "codex.semantic"
M.EXT_ACADEMIC = "codex.academic"

-- Check if a class list contains a specific class
-- @param classes Array of CSS class strings
-- @param class_name Class to search for
-- @return boolean
function M.has_class(classes, class_name)
    if not classes then return false end
    for _, c in ipairs(classes) do
        if c == class_name then return true end
    end
    return false
end

-- Insert a converted block (or multi-block result) into a target array
-- Handles the multi-block unpacking pattern used throughout blocks and academic modules
-- @param target Array to insert into
-- @param converted Converted block (may have .multi and .blocks fields)
function M.insert_converted(target, converted)
    if not converted then return end
    if converted.multi then
        for _, b in ipairs(converted.blocks) do
            table.insert(target, b)
        end
    else
        table.insert(target, converted)
    end
end

-- Generate a term ID from text (for glossary terms)
-- @param text Term text
-- @return Normalized ID string
function M.generate_term_id(text)
    return "term-" .. text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
end

-- Extract block attributes from a Pandoc block's attr field
-- Handles both named fields (Pandoc 3.x) and indexed fields (older Pandoc)
-- @param block Pandoc block element
-- @return Table with id, classes, attributes fields
function M.extract_block_attr(block)
    local attr = block.attr or {}
    return {
        id = attr.identifier or (attr[1] or ""),
        classes = attr.classes or (attr[2] or {}),
        attributes = attr.attributes or (attr[3] or {})
    }
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
