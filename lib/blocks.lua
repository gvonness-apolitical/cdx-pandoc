-- lib/blocks.lua
-- Convert Pandoc blocks to Codex block structures

local M = {}

-- Inlines module (will be set by init)
local inlines = nil

-- Bibliography context (set by codex.lua before conversion)
local bib_context = {
    csl_entries = {},
    style = "unknown"
}

-- Set the inlines module reference
function M.set_inlines(inlines_module)
    inlines = inlines_module
end

-- Set bibliography context (CSL entries and style)
function M.set_bibliography_context(csl_entries, style)
    bib_context.csl_entries = csl_entries or {}
    bib_context.style = style or "unknown"
end

-- Convert a list of Pandoc blocks to Codex blocks
-- @param blocks Pandoc block list
-- @return Array of Codex blocks
function M.convert(blocks)
    local result = {}

    for _, block in ipairs(blocks) do
        local converted = M.convert_block(block)
        if converted then
            if converted.multi then
                -- Some conversions return multiple blocks
                for _, b in ipairs(converted.blocks) do
                    table.insert(result, b)
                end
            else
                table.insert(result, converted)
            end
        end
    end

    return result
end

-- Convert a single Pandoc block to a Codex block
-- @param block Pandoc block element
-- @return Codex block table or nil
function M.convert_block(block)
    local tag = block.t or block.tag

    if tag == "Para" then
        return M.paragraph(block)

    elseif tag == "Plain" then
        -- Plain is like Para but without surrounding paragraph tags
        return M.paragraph(block)

    elseif tag == "Header" then
        return M.heading(block)

    elseif tag == "BulletList" then
        return M.bullet_list(block)

    elseif tag == "OrderedList" then
        return M.ordered_list(block)

    elseif tag == "CodeBlock" then
        return M.code_block(block)

    elseif tag == "BlockQuote" then
        return M.blockquote(block)

    elseif tag == "HorizontalRule" then
        return M.horizontal_rule(block)

    elseif tag == "Table" then
        return M.table_block(block)

    elseif tag == "Div" then
        local attr = block.attr or {}
        local id = attr.identifier or (attr[1] or "")
        if id == "refs" then
            -- Citeproc bibliography Div — extract structured entries
            return M.bibliography_from_refs(block)
        end
        -- Normal Div — unwrap contents
        return {
            multi = true,
            blocks = M.convert(block.content)
        }

    elseif tag == "RawBlock" then
        -- Raw block - treat as code block with no language
        return {
            type = "codeBlock",
            children = {
                {type = "text", value = block.text}
            }
        }

    elseif tag == "LineBlock" then
        -- Line block - convert each line to paragraph
        local paragraphs = {}
        for _, line in ipairs(block.content) do
            table.insert(paragraphs, {
                type = "paragraph",
                children = inlines.convert(line)
            })
        end
        return {
            multi = true,
            blocks = paragraphs
        }

    elseif tag == "DefinitionList" then
        -- Definition list - convert to regular list with term+definition
        return M.definition_list(block)

    elseif tag == "Figure" then
        -- Figure - extract image and caption
        return M.figure(block)

    else
        -- Unknown block type - skip with warning
        io.stderr:write("Warning: Unknown block type: " .. (tag or "nil") .. "\n")
        return nil
    end
end

-- Convert Para/Plain to paragraph (sentinel-aware)
function M.paragraph(block)
    local content = block.content or block.c
    if not content then return nil end

    local flat = inlines.flatten(content)

    -- Check for any sentinels
    local has_sentinel = false
    for _, node in ipairs(flat) do
        if node.type and node.type:match("_sentinel$") then
            has_sentinel = true
            break
        end
    end

    if not has_sentinel then
        return {type = "paragraph", children = inlines.merge_adjacent(flat)}
    end

    -- Split around sentinels
    local result_blocks = {}
    local current_text = {}

    for _, node in ipairs(flat) do
        if node.type and node.type:match("_sentinel$") then
            -- Flush accumulated text as paragraph
            if #current_text > 0 then
                local merged = inlines.merge_adjacent(current_text)
                if #merged > 0 then
                    table.insert(result_blocks, {type = "paragraph", children = merged})
                end
                current_text = {}
            end
            -- Convert sentinel to its target block(s)
            local sentinel_blocks = M.convert_sentinel(node)
            for _, sb in ipairs(sentinel_blocks) do
                table.insert(result_blocks, sb)
            end
        else
            table.insert(current_text, node)
        end
    end

    -- Flush remaining text
    if #current_text > 0 then
        local merged = inlines.merge_adjacent(current_text)
        if #merged > 0 then
            table.insert(result_blocks, {type = "paragraph", children = merged})
        end
    end

    if #result_blocks == 1 then
        return result_blocks[1]
    else
        return {multi = true, blocks = result_blocks}
    end
end

-- Convert a sentinel node to its target block(s)
function M.convert_sentinel(node)
    if node.type == "math_sentinel" then
        return {{
            type = "math",
            display = (node.mathtype == "DisplayMath"),
            format = "latex",
            value = node.text
        }}
    elseif node.type == "image_sentinel" then
        return {{type = "image", src = node.src, alt = node.alt, title = node.title}}
    elseif node.type == "measurement_sentinel" then
        local measurement = {
            type = "semantic:measurement",
            value = node.value,
            unit = node.unit
        }
        -- Add schema.org QuantitativeValue if we have valid data
        if node.value and node.unit then
            measurement.schema = {
                ["@type"] = "QuantitativeValue",
                value = node.value,
                unitText = node.unit
            }
        end
        return {measurement}
    else
        return {}
    end
end

-- Convert Header to heading
function M.heading(block)
    local level = block.level
    local attr = block.attr or {}
    local identifier = attr.identifier or (attr[1] or "")
    local content = block.content

    local result = {
        type = "heading",
        level = level,
        children = inlines.convert(content)
    }

    -- Add ID if present
    if identifier and identifier ~= "" then
        result.id = identifier
    end

    return result
end

-- Convert BulletList to list (ordered=false)
function M.bullet_list(block)
    local items = {}

    for _, item in ipairs(block.content) do
        table.insert(items, M.list_item(item))
    end

    return {
        type = "list",
        ordered = false,
        children = items
    }
end

-- Convert OrderedList to list (ordered=true)
function M.ordered_list(block)
    local items = {}
    local start_num = nil

    -- Pandoc OrderedList has listAttributes with start number
    if block.listAttributes then
        local attrs = block.listAttributes
        if type(attrs) == "table" and attrs[1] and attrs[1] > 1 then
            start_num = attrs[1]
        end
    end

    for _, item in ipairs(block.content) do
        table.insert(items, M.list_item(item))
    end

    local result = {
        type = "list",
        ordered = true,
        children = items
    }

    if start_num then
        result.start = start_num
    end

    return result
end

-- Convert a list item (array of blocks)
function M.list_item(blocks)
    local children = M.convert(blocks)

    -- Check for task list item (checkbox)
    local checked = nil
    if #children > 0 and children[1].type == "paragraph" then
        local para = children[1]
        if #para.children > 0 then
            local first_text = para.children[1].value or ""
            -- Check for checkbox patterns
            if first_text:match("^%[x%]%s*") or first_text:match("^%[X%]%s*") then
                checked = true
                para.children[1].value = first_text:gsub("^%[x%]%s*", ""):gsub("^%[X%]%s*", "")
            elseif first_text:match("^%[ %]%s*") or first_text:match("^%[%]%s*") then
                checked = false
                para.children[1].value = first_text:gsub("^%[ %]%s*", ""):gsub("^%[%]%s*", "")
            end
        end
    end

    local result = {
        type = "listItem",
        children = children
    }

    if checked ~= nil then
        result.checked = checked
    end

    return result
end

-- Convert CodeBlock
function M.code_block(block)
    local attr = block.attr or {}
    local classes = attr.classes or (attr[2] or {})
    local language = nil

    -- First class is typically the language
    if type(classes) == "table" and #classes > 0 then
        language = classes[1]
    elseif type(classes) == "string" and classes ~= "" then
        language = classes
    end

    local result = {
        type = "codeBlock",
        children = {
            {type = "text", value = block.text}
        }
    }

    if language and language ~= "" then
        result.language = language
    end

    return result
end

-- Convert BlockQuote
function M.blockquote(block)
    return {
        type = "blockquote",
        children = M.convert(block.content)
    }
end

-- Convert HorizontalRule
function M.horizontal_rule(block)
    return {
        type = "horizontalRule"
    }
end

-- Convert Table (Pandoc's complex table structure)
function M.table_block(block)
    local rows = {}

    -- Handle Pandoc table structure
    -- Pandoc 2.17+ has different table structure
    local _caption = block.caption   -- luacheck: ignore 211
    local _colspecs = block.colspecs -- luacheck: ignore 211
    local thead = block.head
    local tbody = block.bodies
    local tfoot = block.foot

    -- Process header rows
    if thead and thead.rows then
        for _, row in ipairs(thead.rows) do
            table.insert(rows, M.table_row(row, true))
        end
    elseif thead and type(thead) == "table" then
        -- Older Pandoc format
        for _, row in ipairs(thead) do
            if type(row) == "table" and row.cells then
                table.insert(rows, M.table_row(row, true))
            end
        end
    end

    -- Process body rows
    if tbody then
        for _, body in ipairs(tbody) do
            if body.body then
                for _, row in ipairs(body.body) do
                    table.insert(rows, M.table_row(row, false))
                end
            elseif type(body) == "table" then
                for _, row in ipairs(body) do
                    if type(row) == "table" and row.cells then
                        table.insert(rows, M.table_row(row, false))
                    end
                end
            end
        end
    end

    -- Process footer rows
    if tfoot and tfoot.rows then
        for _, row in ipairs(tfoot.rows) do
            table.insert(rows, M.table_row(row, false))
        end
    end

    return {
        type = "table",
        children = rows
    }
end

-- Convert a table row
function M.table_row(row, is_header)
    local cells = {}

    local row_cells = row.cells or row

    for _, cell in ipairs(row_cells) do
        table.insert(cells, M.table_cell(cell))
    end

    local result = {
        type = "tableRow",
        children = cells
    }

    if is_header then
        result.header = true
    end

    return result
end

-- Convert a table cell
function M.table_cell(cell)
    local content = cell.contents or cell.content or cell

    -- Get cell text content
    local children = {}
    if type(content) == "table" then
        -- Content is blocks - convert and flatten to text nodes
        local blocks = M.convert(content)
        -- For simple cells, extract text from first paragraph
        if #blocks > 0 and blocks[1].type == "paragraph" then
            children = blocks[1].children
        else
            -- Complex cell content - just use first text we find
            for _, b in ipairs(blocks) do
                if b.children then
                    for _, c in ipairs(b.children) do
                        if c.type == "text" then
                            table.insert(children, c)
                        end
                    end
                end
            end
        end
    end

    local result = {
        type = "tableCell",
        children = children
    }

    -- Handle colspan/rowspan if present
    if cell.col_span and cell.col_span > 1 then
        result.colspan = cell.col_span
    end
    if cell.row_span and cell.row_span > 1 then
        result.rowspan = cell.row_span
    end

    -- Handle alignment
    if cell.alignment then
        local align = tostring(cell.alignment):lower()
        if align == "alignleft" or align == "left" then
            result.align = "left"
        elseif align == "aligncenter" or align == "center" then
            result.align = "center"
        elseif align == "alignright" or align == "right" then
            result.align = "right"
        end
    end

    return result
end

-- Convert DefinitionList to semantic:term blocks (glossary terms)
function M.definition_list(block)
    local terms = {}

    for _, entry in ipairs(block.content) do
        local term_inlines = entry[1]
        local definitions = entry[2]

        -- Extract term text
        local term_text = pandoc.utils.stringify(term_inlines)
        local term_id = "term-" .. term_text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")

        -- Extract definition text (combine all definitions)
        local def_parts = {}
        for _, def in ipairs(definitions or {}) do
            table.insert(def_parts, pandoc.utils.stringify(def))
        end
        local definition = table.concat(def_parts, " ")

        -- Check for "see also" references in the definition
        local see_refs = {}
        local see_pattern = "[Ss]ee%s+also:?%s*([^%.]+)"
        local see_match = definition:match(see_pattern)
        if see_match then
            for ref in see_match:gmatch("([^,;]+)") do
                local ref_trimmed = ref:match("^%s*(.-)%s*$")
                if ref_trimmed and ref_trimmed ~= "" then
                    local ref_id = "term-" .. ref_trimmed:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
                    table.insert(see_refs, ref_id)
                end
            end
            -- Remove the "see also" part from definition
            definition = definition:gsub(see_pattern .. "%.?%s*", "")
        end

        local term_block = {
            type = "semantic:term",
            id = term_id,
            term = term_text,
            definition = definition
        }

        if #see_refs > 0 then
            term_block.see = see_refs
        end

        table.insert(terms, term_block)
    end

    return {
        multi = true,
        blocks = terms
    }
end

-- Convert Figure
function M.figure(block)
    -- Extract image from figure content
    if block.content and #block.content > 0 then
        local first = block.content[1]
        if first.t == "Plain" or first.t == "Para" then
            local content = first.content or first.c
            if content and #content > 0 then
                local img = content[1]
                if img.t == "Image" then
                    return M.image(img, block.caption)
                end
            end
        end
    end

    -- Fallback: convert content as regular blocks
    return {
        multi = true,
        blocks = M.convert(block.content or {})
    }
end

-- Convert Image to image block (with optional dimensions)
function M.image(img, caption)
    local src = img.src or img.target or ""
    local alt = ""

    if img.caption then
        alt = pandoc.utils.stringify(img.caption)
    elseif img.attr and img.attr[1] then
        alt = img.attr[1]
    end

    local result = {
        type = "image",
        src = src,
        alt = alt or ""
    }

    if img.title and img.title ~= "" then
        result.title = img.title
    end

    -- Extract dimensions from Pandoc attributes
    if img.attr and img.attr.attributes then
        local attrs = img.attr.attributes
        if attrs.width then
            local w = tonumber(attrs.width:match("(%d+)"))
            if w then result.width = w end
        end
        if attrs.height then
            local h = tonumber(attrs.height:match("(%d+)"))
            if h then result.height = h end
        end
    end

    -- Caption from Figure container
    if caption and caption.long then
        local cap_text = pandoc.utils.stringify(caption.long)
        if cap_text and cap_text ~= "" then
            result.title = cap_text
        end
    end

    return result
end

-- Check if footnote content is simple (single paragraph with plain text only)
local function is_simple_footnote(blocks)
    if #blocks ~= 1 then return false end
    local block = blocks[1]
    local tag = block.t or block.tag
    if tag ~= "Para" and tag ~= "Plain" then return false end

    local content = block.content or block.c
    if not content then return false end

    for _, inline in ipairs(content) do
        local inline_tag = inline.t or inline.tag
        if inline_tag ~= "Str" and inline_tag ~= "Space" and inline_tag ~= "SoftBreak" then
            return false
        end
    end
    return true
end

-- Extract plain text from simple footnote content
local function extract_plain_text(blocks)
    local block = blocks[1]
    local content = block.content or block.c
    local parts = {}
    for _, inline in ipairs(content) do
        local tag = inline.t or inline.tag
        if tag == "Str" then
            table.insert(parts, inline.text)
        elseif tag == "Space" or tag == "SoftBreak" then
            table.insert(parts, " ")
        end
    end
    return table.concat(parts)
end

-- Convert accumulated footnotes to semantic:footnote blocks
function M.convert_footnotes(footnotes)
    local result = {}
    for _, fn in ipairs(footnotes) do
        local footnote_block = {
            type = "semantic:footnote",
            number = fn.number,
            id = "fn-" .. fn.number
        }

        -- Use 'content' for simple text footnotes, 'children' for complex ones
        if is_simple_footnote(fn.content) then
            footnote_block.content = extract_plain_text(fn.content)
        else
            footnote_block.children = M.convert(fn.content)
        end

        table.insert(result, footnote_block)
    end
    return result
end

-- Convert citeproc #refs Div to a bibliography block
-- Uses CSL entries from bib_context when available, falls back to rendered text
function M.bibliography_from_refs(block)
    local entries = {}
    for _, child in ipairs(block.content) do
        if child.t == "Div" then
            local entry_id = child.attr and (child.attr.identifier or child.attr[1]) or ""
            local rendered_text = pandoc.utils.stringify(child)
            if entry_id ~= "" then
                local clean_id = entry_id:gsub("^ref%-", "")

                -- Check if we have CSL metadata for this entry
                local csl_entry = bib_context.csl_entries[clean_id]

                if csl_entry then
                    -- Use full CSL metadata, add rendered text
                    local entry = {}
                    for k, v in pairs(csl_entry) do
                        entry[k] = v
                    end
                    entry.renderedText = rendered_text
                    table.insert(entries, entry)
                else
                    -- Fallback to rendered text only
                    table.insert(entries, {
                        id = clean_id,
                        type = "other",
                        renderedText = rendered_text,
                    })
                end
            end
        end
    end
    if #entries > 0 then
        return {
            type = "semantic:bibliography",
            style = bib_context.style ~= "unknown" and bib_context.style or "apa",
            entries = entries,
        }
    end
    return {multi = true, blocks = {}}
end

return M
