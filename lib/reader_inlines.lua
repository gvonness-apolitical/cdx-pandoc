-- Reader: Codex text nodes → Pandoc inlines
-- Converts Codex text nodes with marks to Pandoc inline elements.

local M = {}

-- Mark type to Pandoc inline constructor mapping
-- Order matters: we wrap from innermost to outermost.
local mark_wrappers = {
    bold = function(inlines) return pandoc.Strong(inlines) end,
    italic = function(inlines) return pandoc.Emph(inlines) end,
    strikethrough = function(inlines) return pandoc.Strikeout(inlines) end,
    underline = function(inlines) return pandoc.Underline(inlines) end,
    superscript = function(inlines) return pandoc.Superscript(inlines) end,
    subscript = function(inlines) return pandoc.Subscript(inlines) end,
}

-- Footnote storage (set externally by reader_blocks)
M._footnotes = {}

-- Convert an array of Codex text nodes to Pandoc inlines
function M.convert(nodes)
    local result = {}
    for _, node in ipairs(nodes) do
        local inlines = M.convert_node(node)
        for _, inline in ipairs(inlines) do
            table.insert(result, inline)
        end
    end
    return result
end

-- Convert a single text node to Pandoc inline(s)
function M.convert_node(node)
    -- Handle non-text nodes (shouldn't appear in reader input, but be safe)
    if not node.value and not node.type then
        return {}
    end

    -- Skip sentinel types that might appear
    if node.type and node.type:match("_sentinel$") then
        return {}
    end

    local text = node.value or ""
    if text == "" and not (node.marks and #node.marks > 0) then
        return {}
    end

    local marks = node.marks or {}

    -- Categorize marks by type
    local has_code = false
    local has_math = nil
    local has_link = nil
    local has_anchor = nil
    local has_footnote = nil
    local has_citation = nil
    local has_entity = nil
    local has_glossary = nil
    local other_marks = {}

    for _, mark in ipairs(marks) do
        local mark_type = M.get_mark_type(mark)
        if mark_type == "code" then
            has_code = true
        elseif mark_type == "math" then
            has_math = mark
        elseif mark_type == "link" then
            has_link = mark
        elseif mark_type == "anchor" then
            has_anchor = mark
        elseif mark_type == "footnote" then
            has_footnote = mark
        elseif mark_type == "citation" then
            has_citation = mark
        elseif mark_type == "entity" then
            has_entity = mark
        elseif mark_type == "glossary" then
            has_glossary = mark
        else
            table.insert(other_marks, mark_type)
        end
    end

    -- Handle math marks - convert to Pandoc InlineMath
    if has_math then
        return {pandoc.Math(pandoc.InlineMath, text)}
    end

    -- Handle footnote marks - convert to Pandoc Note
    if has_footnote then
        local fn_num = has_footnote.number
        if fn_num and M._footnotes and M._footnotes[fn_num] then
            return {M._footnotes[fn_num]}
        end
        -- Fallback: if no footnote content found, return as superscript
        return {pandoc.Superscript({pandoc.Str(text)})}
    end

    -- Handle citation marks - convert to Pandoc Cite
    if has_citation then
        local refs = has_citation.refs or {}
        local citations = {}
        for _, ref in ipairs(refs) do
            -- Create citation with id and mode
            local mode = "NormalCitation"
            if has_citation.suppressAuthor then
                mode = "SuppressAuthor"
            end
            local citation = pandoc.Citation(ref, mode)
            -- Set prefix if present
            if has_citation.prefix then
                citation.prefix = {pandoc.Str(has_citation.prefix)}
            end
            -- Set suffix from locator and/or suffix
            local suffix_text = ""
            if has_citation.locator then
                suffix_text = "p. " .. has_citation.locator
            end
            if has_citation.suffix then
                if suffix_text ~= "" then
                    suffix_text = suffix_text .. " " .. has_citation.suffix
                else
                    suffix_text = has_citation.suffix
                end
            end
            if suffix_text ~= "" then
                citation.suffix = {pandoc.Str(suffix_text)}
            end
            table.insert(citations, citation)
        end
        -- Create Cite element with the text content
        local content = {pandoc.Str(text)}
        return {pandoc.Cite(content, citations)}
    end

    -- Build the inline element for regular text
    local inline
    if has_code then
        inline = pandoc.Code(text)
    else
        inline = pandoc.Str(text)
    end

    -- Wrap in formatting marks (innermost first)
    for _, mark_type in ipairs(other_marks) do
        local wrapper = mark_wrappers[mark_type]
        if wrapper then
            inline = wrapper({inline})
        end
    end

    -- Wrap in link if present
    if has_link then
        local href = ""
        local title = ""
        if type(has_link) == "table" then
            href = has_link.href or ""
            title = has_link.title or ""
        end
        inline = pandoc.Link({inline}, href, title)
    end

    -- Wrap in Span with ID if anchor mark present
    if has_anchor then
        local anchor_id = ""
        if type(has_anchor) == "table" then
            anchor_id = has_anchor.id or ""
        end
        if anchor_id ~= "" then
            inline = pandoc.Span({inline}, pandoc.Attr(anchor_id))
        end
    end

    -- Wrap in Span with entity class if entity mark present
    if has_entity then
        local attrs = {}
        if type(has_entity) == "table" then
            if has_entity.uri then
                attrs.uri = has_entity.uri
            end
            if has_entity.entityType then
                attrs.entityType = has_entity.entityType
            end
            if has_entity.source then
                attrs.source = has_entity.source
            end
        end
        inline = pandoc.Span({inline}, pandoc.Attr("", {"entity"}, attrs))
    end

    -- Wrap in Span with glossary class if glossary mark present
    if has_glossary then
        local attrs = {}
        if type(has_glossary) == "table" and has_glossary.ref then
            attrs.ref = has_glossary.ref
        end
        inline = pandoc.Span({inline}, pandoc.Attr("", {"glossary"}, attrs))
    end

    return {inline}
end

-- Extract mark type from a mark (handles both string and table formats)
function M.get_mark_type(mark)
    if type(mark) == "string" then
        return mark
    elseif type(mark) == "table" then
        return mark.type or "unknown"
    end
    return "unknown"
end

-- Set footnotes for reference resolution
-- footnotes is a table: { [number] = pandoc.Note(...), ... }
function M.set_footnotes(footnotes)
    M._footnotes = footnotes or {}
end

-- Clear footnotes after processing
function M.clear_footnotes()
    M._footnotes = {}
end

return M
