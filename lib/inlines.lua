-- lib/inlines.lua
-- Convert Pandoc inline elements to Codex text nodes

-- Load shared utilities
local utils = dofile((PANDOC_SCRIPT_FILE and (PANDOC_SCRIPT_FILE:match("(.*/)" ) or "") or "") .. "lib/utils.lua")
local deep_copy = utils.deep_copy

local M = {}

-- Default context (global mutable state for backward compatibility)
M._default_context = {
    footnotes = {},
    footnote_counter = 0,
    citation_refs = {}
}

-- Create a new isolated context for testing
-- @return Context table with empty state
function M.new_context()
    return {
        footnotes = {},
        footnote_counter = 0,
        citation_refs = {}
    }
end

-- Reset the default context (for test isolation)
function M.reset_context()
    M._default_context = M.new_context()
end

-- Check if a class list contains a specific class
function M.has_class(classes, class_name)
    if not classes then return false end
    for _, c in ipairs(classes) do
        if c == class_name then return true end
    end
    return false
end

-- Check if two marks are equal
local function marks_equal(m1, m2)
    if type(m1) ~= type(m2) then
        return false
    end
    if type(m1) == "string" then
        return m1 == m2
    end
    if type(m1) == "table" then
        if m1.type ~= m2.type then
            return false
        end
        if m1.type == "link" then
            return m1.href == m2.href and m1.title == m2.title
        end
        if m1.type == "anchor" then
            return m1.id == m2.id
        end
        if m1.type == "footnote" then
            return m1.number == m2.number and m1.id == m2.id
        end
        if m1.type == "citation" then
            -- Citations with same refs are equal for merging purposes
            if #m1.refs ~= #m2.refs then return false end
            for i, ref in ipairs(m1.refs) do
                if ref ~= m2.refs[i] then return false end
            end
            return true
        end
        if m1.type == "entity" then
            return m1.uri == m2.uri and m1.entityType == m2.entityType
        end
        if m1.type == "glossary" then
            return m1.ref == m2.ref
        end
        if m1.type == "math" then
            return m1.format == m2.format
        end
        if m1.type == "theorem-ref" or m1.type == "equation-ref" or m1.type == "algorithm-ref" then
            return m1.target == m2.target
        end
    end
    return false
end

-- Check if two mark arrays are equal
local function marks_arrays_equal(arr1, arr2)
    if #arr1 ~= #arr2 then
        return false
    end
    for i = 1, #arr1 do
        if not marks_equal(arr1[i], arr2[i]) then
            return false
        end
    end
    return true
end

-- Sort marks for consistent output (simple string marks before objects)
local function sort_marks(marks)
    table.sort(marks, function(a, b)
        local type_a = type(a)
        local type_b = type(b)
        if type_a ~= type_b then
            return type_a == "string"
        end
        if type_a == "string" then
            return a < b
        end
        -- Both are objects (links)
        return false
    end)
    return marks
end

-- Create a text node
-- @param value Text content
-- @param marks Array of marks
-- @return Text node table
function M.text_node(value, marks)
    marks = marks or {}
    local sorted = sort_marks(deep_copy(marks))

    local node = {
        type = "text",
        value = value,
    }

    if #sorted > 0 then
        node.marks = sorted
    end

    return node
end

-- Forward declaration for mutual recursion
local convert_inline

-- Flatten nested inlines into text nodes with marks
-- @param inlines Pandoc inline list
-- @param marks Current mark stack
-- @param ctx Optional context for state accumulation (defaults to global)
-- @return Array of text nodes {type="text", value=string, marks=array}
function M.flatten(inlines, marks, ctx)
    marks = marks or {}
    ctx = ctx or M._default_context
    local result = {}

    for _, inline in ipairs(inlines) do
        local nodes = convert_inline(inline, marks, ctx)
        for _, node in ipairs(nodes) do
            table.insert(result, node)
        end
    end

    return result
end

-- Helper: create a handler that adds a mark and recurses
local function mark_handler(mark_name)
    return function(inline, marks, ctx)
        local new_marks = deep_copy(marks)
        table.insert(new_marks, mark_name)
        return M.flatten(inline.content, new_marks, ctx)
    end
end

-- Individual inline handlers
local inline_handlers = {}

inline_handlers.Str = function(inline, marks, ctx)
    return {M.text_node(inline.text, marks)}
end

inline_handlers.Space = function(inline, marks, ctx)
    return {M.text_node(" ", marks)}
end

inline_handlers.SoftBreak = function(inline, marks, ctx)
    return {M.text_node(" ", marks)}
end

inline_handlers.LineBreak = function(inline, marks, ctx)
    return {M.text_node("\n", marks)}
end

inline_handlers.Strong = mark_handler("bold")
inline_handlers.Emph = mark_handler("italic")
inline_handlers.Strikeout = mark_handler("strikethrough")
inline_handlers.Underline = mark_handler("underline")
inline_handlers.Superscript = mark_handler("superscript")
inline_handlers.Subscript = mark_handler("subscript")

inline_handlers.Code = function(inline, marks, ctx)
    local new_marks = deep_copy(marks)
    table.insert(new_marks, "code")
    return {M.text_node(inline.text, new_marks)}
end

-- Academic cross-reference prefix patterns
local theorem_ref_prefixes = {
    ["thm-"] = true, ["lem-"] = true, ["prop-"] = true, ["cor-"] = true,
    ["def-"] = true, ["conj-"] = true, ["rem-"] = true, ["ex-"] = true
}

local function detect_academic_ref(target)
    if not target or not target:match("^#") then
        return nil
    end
    local ref_id = target:sub(2) -- strip leading #
    -- Theorem-like references
    for prefix, _ in pairs(theorem_ref_prefixes) do
        if ref_id:sub(1, #prefix) == prefix then
            return {type = "theorem-ref", target = target}
        end
    end
    -- Equation references
    if ref_id:match("^eq%-") then
        return {type = "equation-ref", target = target}
    end
    -- Algorithm references
    if ref_id:match("^alg%-") then
        return {type = "algorithm-ref", target = target}
    end
    return nil
end

inline_handlers.Link = function(inline, marks, ctx)
    local new_marks = deep_copy(marks)
    local target = inline.target

    -- Check for academic cross-reference patterns
    local acad_mark = detect_academic_ref(target)
    if acad_mark then
        -- Extract format text from link content
        local format_text = pandoc.utils.stringify(inline.content)
        if format_text and format_text ~= "" then
            acad_mark.format = format_text
        end
        table.insert(new_marks, acad_mark)
        return M.flatten(inline.content, new_marks, ctx)
    end

    local link_mark = {
        type = "link",
        href = target,
    }
    if inline.title and inline.title ~= "" then
        link_mark.title = inline.title
    end
    table.insert(new_marks, link_mark)
    return M.flatten(inline.content, new_marks, ctx)
end

inline_handlers.Image = function(inline, marks, ctx)
    return {{
        type = "image_sentinel",
        src = inline.src or inline.target or "",
        alt = inline.caption and pandoc.utils.stringify(inline.caption) or "",
        title = (inline.title and inline.title ~= "") and inline.title or nil,
        value = ""
    }}
end

inline_handlers.Math = function(inline, marks, ctx)
    if inline.mathtype == "DisplayMath" then
        -- DisplayMath remains a sentinel → block-level math block
        return {{
            type = "math_sentinel",
            mathtype = inline.mathtype,
            text = inline.text,
            value = ""
        }}
    else
        -- InlineMath → text node with math mark (stays inside paragraph)
        local new_marks = deep_copy(marks)
        table.insert(new_marks, {type = "math", format = "latex"})
        return {M.text_node(inline.text, new_marks)}
    end
end

inline_handlers.RawInline = function(inline, marks, ctx)
    return {M.text_node(inline.text, marks)}
end

inline_handlers.Quoted = function(inline, marks, ctx)
    local quote_char = inline.quotetype == "DoubleQuote" and '"' or "'"
    local nodes = {}
    table.insert(nodes, M.text_node(quote_char, marks))
    for _, node in ipairs(M.flatten(inline.content, marks, ctx)) do
        table.insert(nodes, node)
    end
    table.insert(nodes, M.text_node(quote_char, marks))
    return nodes
end

inline_handlers.Cite = function(inline, marks, ctx)
    local refs = {}
    local locator = nil
    local prefix = nil
    local suffix = nil
    local suppress_author = false

    for _, c in ipairs(inline.citations) do
        table.insert(refs, c.id)
        ctx.citation_refs[c.id] = true
        if not prefix and c.prefix then
            local p = pandoc.utils.stringify(c.prefix)
            if p ~= "" then prefix = p end
        end
        if not suffix and c.suffix then
            local s = pandoc.utils.stringify(c.suffix)
            if s ~= "" then
                local page_match = s:match("^%s*p%.?%s*(%d+[%-–]?%d*)") or
                                   s:match("^%s*pp%.?%s*(%d+[%-–]?%d*)")
                if page_match then
                    locator = page_match
                else
                    suffix = s
                end
            end
        end
        if c.mode == "SuppressAuthor" then
            suppress_author = true
        end
    end

    local citation_mark = {type = "citation", refs = refs}
    if locator then citation_mark.locator = locator end
    if prefix then citation_mark.prefix = prefix end
    if suffix then citation_mark.suffix = suffix end
    if suppress_author then citation_mark.suppressAuthor = true end

    local new_marks = deep_copy(marks)
    table.insert(new_marks, citation_mark)
    return M.flatten(inline.content, new_marks, ctx)
end

inline_handlers.SmallCaps = function(inline, marks, ctx)
    return M.flatten(inline.content, marks, ctx)
end

inline_handlers.Span = function(inline, marks, ctx)
    local attr = inline.attr or {}
    local identifier = attr.identifier or (attr[1] or "")
    local classes = attr.classes or (attr[2] or {})
    local attributes = attr.attributes or (attr[3] or {})

    if type(classes) == "string" then
        classes = {classes}
    end

    local new_marks = deep_copy(marks)
    local has_semantic_mark = false

    -- Entity class
    if M.has_class(classes, "entity") then
        local entity_mark = {type = "entity"}
        if attributes.uri then
            entity_mark.uri = attributes.uri
        end
        if attributes.entityType then
            entity_mark.entityType = attributes.entityType
        elseif attributes["entity-type"] then
            entity_mark.entityType = attributes["entity-type"]
        end
        if attributes.source then
            entity_mark.source = attributes.source
        end
        table.insert(new_marks, entity_mark)
        has_semantic_mark = true
    end

    -- Glossary class
    if M.has_class(classes, "glossary") then
        local glossary_mark = {type = "glossary"}
        if attributes.ref then
            glossary_mark.ref = attributes.ref
        else
            local text = pandoc.utils.stringify(inline.content)
            glossary_mark.ref = "term-" .. text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
        end
        table.insert(new_marks, glossary_mark)
        has_semantic_mark = true
    end

    -- Measurement class
    if M.has_class(classes, "measurement") then
        local text = pandoc.utils.stringify(inline.content)
        local value = tonumber(attributes.value) or tonumber(text:match("([%d%.]+)"))
        local unit = attributes.unit or text:match("%d+%.?%d*%s*(%a+)")
        return {{
            type = "measurement_sentinel",
            value = value,
            unit = unit,
            text = text
        }}
    end

    -- Anchor (span with ID)
    if identifier and identifier ~= "" then
        table.insert(new_marks, {type = "anchor", id = identifier})
        has_semantic_mark = true
    end

    if has_semantic_mark then
        return M.flatten(inline.content, new_marks, ctx)
    end

    return M.flatten(inline.content, marks, ctx)
end

inline_handlers.Note = function(inline, marks, ctx)
    ctx.footnote_counter = ctx.footnote_counter + 1
    local fn_num = ctx.footnote_counter
    local fn_id = "fn-" .. fn_num
    table.insert(ctx.footnotes, {
        number = fn_num,
        id = fn_id,
        content = inline.content
    })
    local new_marks = deep_copy(marks)
    table.insert(new_marks, {type = "footnote", number = fn_num, id = fn_id})
    return {M.text_node(tostring(fn_num), new_marks)}
end

-- Convert a single inline element to text nodes (table-driven dispatch)
-- @param inline Pandoc inline element
-- @param marks Current marks stack
-- @param ctx Optional context for state accumulation (defaults to global)
-- @return Array of text nodes
convert_inline = function(inline, marks, ctx)
    marks = marks or {}
    ctx = ctx or M._default_context
    local tag = inline.t or inline.tag

    local handler = inline_handlers[tag]
    if handler then
        return handler(inline, marks, ctx)
    end

    -- Unknown inline type - try to recurse on content
    if inline.content then
        return M.flatten(inline.content, marks, ctx)
    end
    return {}
end

-- Export convert_inline as module function
M.convert_inline = convert_inline

-- Expose handlers table for testing
M._handlers = inline_handlers

-- Check if a node is a sentinel (non-text node that needs block-level handling)
local function is_sentinel(node)
    return node.type and node.type:match("_sentinel$")
end

-- Merge adjacent text nodes with identical marks
-- Sentinel nodes are passed through untouched
-- @param nodes Array of text nodes (and possibly sentinel nodes)
-- @return Merged array of nodes
function M.merge_adjacent(nodes)
    if #nodes == 0 then
        return {}
    end

    local result = {}
    local current = nil

    for _, node in ipairs(nodes) do
        if is_sentinel(node) then
            if current then
                if current.value ~= "" then
                    table.insert(result, current)
                end
                current = nil
            end
            table.insert(result, node)
        elseif current == nil then
            current = deep_copy(node)
        else
            local current_marks = current.marks or {}
            local node_marks = node.marks or {}

            if marks_arrays_equal(current_marks, node_marks) then
                current.value = current.value .. node.value
            else
                if current.value ~= "" then
                    table.insert(result, current)
                end
                current = deep_copy(node)
            end
        end
    end

    if current and current.value ~= "" then
        table.insert(result, current)
    end

    return result
end

-- Convert a list of Pandoc inlines to Codex text nodes
-- This is the main entry point
-- @param inlines Pandoc inline list
-- @param ctx Optional context for state accumulation (defaults to global)
-- @return Array of Codex text nodes
function M.convert(inlines, ctx)
    if not inlines then
        return {}
    end
    if type(inlines) ~= "table" then
        io.stderr:write("Warning: inlines.convert() expected table, got " .. type(inlines) .. "\n")
        return {}
    end

    ctx = ctx or M._default_context
    local flat = M.flatten(inlines, nil, ctx)
    return M.merge_adjacent(flat)
end

-- Retrieve accumulated footnotes and reset state
-- @param ctx Optional context (defaults to global)
-- @return Array of footnote objects
function M.get_footnotes(ctx)
    ctx = ctx or M._default_context
    local fns = ctx.footnotes
    ctx.footnotes = {}
    ctx.footnote_counter = 0
    return fns
end

-- Retrieve accumulated citation refs and reset state
-- @param ctx Optional context (defaults to global)
-- @return Table of citation ref IDs
function M.get_citation_refs(ctx)
    ctx = ctx or M._default_context
    local refs = ctx.citation_refs
    ctx.citation_refs = {}
    return refs
end

return M
