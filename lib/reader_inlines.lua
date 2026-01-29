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

    -- Start with the text content
    -- Handle Code mark specially — it wraps text as pandoc.Code
    local has_code = false
    local has_link = nil
    local has_anchor = nil
    local other_marks = {}

    for _, mark in ipairs(marks) do
        local mark_type = M.get_mark_type(mark)
        if mark_type == "code" then
            has_code = true
        elseif mark_type == "link" then
            has_link = mark
        elseif mark_type == "anchor" then
            has_anchor = mark
        else
            table.insert(other_marks, mark_type)
        end
    end

    -- Build the inline element
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

    -- Check for footnote reference (superscript number matching a footnote)
    if M._footnotes and next(M._footnotes) then
        local is_superscript = false
        for _, mark_type in ipairs(other_marks) do
            if mark_type == "superscript" then
                is_superscript = true
                break
            end
        end
        if is_superscript then
            local num = tonumber(text)
            if num and M._footnotes[num] then
                -- Replace with Note containing footnote content
                return {M._footnotes[num]}
            end
        end
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
