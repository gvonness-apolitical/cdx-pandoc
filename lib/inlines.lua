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
        local nodes = M.convert_inline(inline, marks, ctx)
        for _, node in ipairs(nodes) do
            table.insert(result, node)
        end
    end

    return result
end

-- Convert a single inline element to text nodes
-- @param inline Pandoc inline element
-- @param marks Current marks stack
-- @param ctx Optional context for state accumulation (defaults to global)
-- @return Array of text nodes
function M.convert_inline(inline, marks, ctx)
    marks = marks or {}
    ctx = ctx or M._default_context
    local tag = inline.t or inline.tag

    if tag == "Str" then
        return {M.text_node(inline.text, marks)}

    elseif tag == "Space" then
        return {M.text_node(" ", marks)}

    elseif tag == "SoftBreak" then
        return {M.text_node(" ", marks)}

    elseif tag == "LineBreak" then
        -- LineBreak becomes a space in text; could also be handled as break block
        return {M.text_node("\n", marks)}

    elseif tag == "Strong" then
        local new_marks = deep_copy(marks)
        table.insert(new_marks, "bold")
        return M.flatten(inline.content, new_marks, ctx)

    elseif tag == "Emph" then
        local new_marks = deep_copy(marks)
        table.insert(new_marks, "italic")
        return M.flatten(inline.content, new_marks, ctx)

    elseif tag == "Strikeout" then
        local new_marks = deep_copy(marks)
        table.insert(new_marks, "strikethrough")
        return M.flatten(inline.content, new_marks, ctx)

    elseif tag == "Underline" then
        local new_marks = deep_copy(marks)
        table.insert(new_marks, "underline")
        return M.flatten(inline.content, new_marks, ctx)

    elseif tag == "Superscript" then
        local new_marks = deep_copy(marks)
        table.insert(new_marks, "superscript")
        return M.flatten(inline.content, new_marks, ctx)

    elseif tag == "Subscript" then
        local new_marks = deep_copy(marks)
        table.insert(new_marks, "subscript")
        return M.flatten(inline.content, new_marks, ctx)

    elseif tag == "Code" then
        local new_marks = deep_copy(marks)
        table.insert(new_marks, "code")
        return {M.text_node(inline.text, new_marks)}

    elseif tag == "Link" then
        local new_marks = deep_copy(marks)
        local link_mark = {
            type = "link",
            href = inline.target,
        }
        -- Add title if present (Pandoc uses target as [url, title])
        if inline.title and inline.title ~= "" then
            link_mark.title = inline.title
        end
        table.insert(new_marks, link_mark)
        return M.flatten(inline.content, new_marks, ctx)

    elseif tag == "Image" then
        return {{
            type = "image_sentinel",
            src = inline.src or inline.target or "",
            alt = inline.caption and pandoc.utils.stringify(inline.caption) or "",
            title = (inline.title and inline.title ~= "") and inline.title or nil,
            value = ""
        }}

    elseif tag == "Math" then
        return {{
            type = "math_sentinel",
            mathtype = inline.mathtype,
            text = inline.text,
            value = ""
        }}

    elseif tag == "RawInline" then
        -- Raw content - just include as text
        return {M.text_node(inline.text, marks)}

    elseif tag == "Quoted" then
        -- Quoted text - add quotes
        local quote_char = inline.quotetype == "DoubleQuote" and '"' or "'"
        local nodes = {}
        table.insert(nodes, M.text_node(quote_char, marks))
        for _, node in ipairs(M.flatten(inline.content, marks, ctx)) do
            table.insert(nodes, node)
        end
        table.insert(nodes, M.text_node(quote_char, marks))
        return nodes

    elseif tag == "Cite" then
        -- Build citation mark with refs and optional metadata
        local refs = {}
        local locator = nil
        local prefix = nil
        local suffix = nil
        local suppress_author = false

        for _, c in ipairs(inline.citations) do
            table.insert(refs, c.id)
            -- Track citation refs for extension detection
            ctx.citation_refs[c.id] = true
            -- Capture metadata from first citation
            if not prefix and c.prefix then
                local p = pandoc.utils.stringify(c.prefix)
                if p ~= "" then prefix = p end
            end
            if not suffix and c.suffix then
                local s = pandoc.utils.stringify(c.suffix)
                if s ~= "" then
                    -- Check if suffix contains page numbers (common pattern)
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

        -- Create citation mark
        local citation_mark = {type = "citation", refs = refs}
        if locator then citation_mark.locator = locator end
        if prefix then citation_mark.prefix = prefix end
        if suffix then citation_mark.suffix = suffix end
        if suppress_author then citation_mark.suppressAuthor = true end

        -- Apply citation mark to the citation content
        local new_marks = deep_copy(marks)
        table.insert(new_marks, citation_mark)
        return M.flatten(inline.content, new_marks, ctx)

    elseif tag == "SmallCaps" then
        -- SmallCaps not supported in Codex, render as-is
        return M.flatten(inline.content, marks, ctx)

    elseif tag == "Span" then
        local attr = inline.attr or {}
        local identifier = attr.identifier or (attr[1] or "")
        local classes = attr.classes or (attr[2] or {})
        local attributes = attr.attributes or (attr[3] or {})

        -- Normalize classes to table
        if type(classes) == "string" then
            classes = {classes}
        end

        -- Check for semantic classes
        local new_marks = deep_copy(marks)
        local has_semantic_mark = false

        -- Check for entity class: [text]{.entity uri="..." entityType="..."}
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

        -- Check for glossary class: [text]{.glossary ref="term-id"}
        if M.has_class(classes, "glossary") then
            local glossary_mark = {type = "glossary"}
            if attributes.ref then
                glossary_mark.ref = attributes.ref
            else
                -- Auto-generate ref from content
                local text = pandoc.utils.stringify(inline.content)
                glossary_mark.ref = "term-" .. text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
            end
            table.insert(new_marks, glossary_mark)
            has_semantic_mark = true
        end

        -- Check for measurement class: [42.5 kg]{.measurement value="42.5" unit="kg"}
        if M.has_class(classes, "measurement") then
            -- Return a measurement sentinel for block-level handling
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

        -- Span with ID becomes anchor mark
        if identifier and identifier ~= "" then
            table.insert(new_marks, {type = "anchor", id = identifier})
            has_semantic_mark = true
        end

        if has_semantic_mark then
            return M.flatten(inline.content, new_marks, ctx)
        end

        -- Span without semantic info - just process content
        return M.flatten(inline.content, marks, ctx)

    elseif tag == "Note" then
        ctx.footnote_counter = ctx.footnote_counter + 1
        local fn_num = ctx.footnote_counter
        local fn_id = "fn-" .. fn_num
        table.insert(ctx.footnotes, {
            number = fn_num,
            id = fn_id,
            content = inline.content
        })
        -- Use footnote mark instead of superscript
        local new_marks = deep_copy(marks)
        table.insert(new_marks, {type = "footnote", number = fn_num, id = fn_id})
        return {M.text_node(tostring(fn_num), new_marks)}

    else
        -- Unknown inline type - try to stringify if possible
        if inline.content then
            return M.flatten(inline.content, marks, ctx)
        else
            return {}
        end
    end
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
            -- Flush current text node if any
            if current then
                if current.value ~= "" then
                    table.insert(result, current)
                end
                current = nil
            end
            -- Pass sentinel through as-is
            table.insert(result, node)
        elseif current == nil then
            current = deep_copy(node)
        else
            local current_marks = current.marks or {}
            local node_marks = node.marks or {}

            if marks_arrays_equal(current_marks, node_marks) then
                -- Same marks, merge text
                current.value = current.value .. node.value
            else
                -- Different marks, push current and start new
                if current.value ~= "" then
                    table.insert(result, current)
                end
                current = deep_copy(node)
            end
        end
    end

    -- Don't forget the last node
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
