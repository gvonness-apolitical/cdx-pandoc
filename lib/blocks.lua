-- lib/blocks.lua
-- Convert Pandoc blocks to Codex block structures

local M = {}

-- Inlines module (will be set by init)
local inlines = nil

-- Academic module (will be set by init, optional)
local academic = nil

-- Bibliography context (set by codex.lua before conversion)
local bib_context = {
    csl_entries = {},
    style = "unknown"
}

-- Set the inlines module reference
function M.set_inlines(inlines_module)
    inlines = inlines_module
end

-- Set the academic module reference (optional)
function M.set_academic(academic_module)
    academic = academic_module
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
    if not blocks then
        return {}
    end
    if type(blocks) ~= "table" then
        io.stderr:write("Warning: blocks.convert() expected table, got " .. type(blocks) .. "\n")
        return {}
    end

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
        return M.div_block(block)

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

-- Check if a class list contains a specific class
local function has_class(classes, class_name)
    if not classes then return false end
    for _, c in ipairs(classes) do
        if c == class_name then return true end
    end
    return false
end

-- Admonition variant set
local admonition_classes = {
    note = true, warning = true, tip = true,
    danger = true, important = true, caution = true
}

-- Process Div blocks with structured dispatch
-- Routes to bibliography, glossary, admonitions, or fallback unwrap
function M.div_block(block)
    local attr = block.attr or {}
    local id = attr.identifier or (attr[1] or "")
    local classes = attr.classes or (attr[2] or {})
    local attributes = attr.attributes or (attr[3] or {})

    -- Bibliography Div from citeproc
    if id == "refs" then
        return M.bibliography_from_refs(block)
    end

    -- Glossary Div containing DefinitionList → semantic:term path
    if has_class(classes, "glossary") then
        return M.glossary_div(block)
    end

    -- Admonition Divs
    for _, cls in ipairs(classes) do
        if admonition_classes[cls] then
            return M.admonition(block, cls, attributes)
        end
    end

    -- Academic extension Divs
    if academic then
        local academic_type = academic.classify_div(classes)
        if academic_type then
            return academic.convert_div(block, academic_type)
        end
    end

    -- Fallback: unwrap Div contents
    return {
        multi = true,
        blocks = M.convert(block.content)
    }
end

-- Convert an admonition Div to an admonition block
function M.admonition(block, variant, attributes)
    local content = block.content or {}
    local title = nil

    -- Extract title from first heading or title attribute
    if attributes and attributes.title then
        title = attributes.title
    end

    local body_blocks = {}
    for i, child in ipairs(content) do
        local tag = child.t or child.tag
        -- If the first block is a heading, use it as the title
        if i == 1 and tag == "Header" and not title then
            title = pandoc.utils.stringify(child.content)
        else
            local converted = M.convert_block(child)
            if converted then
                if converted.multi then
                    for _, b in ipairs(converted.blocks) do
                        table.insert(body_blocks, b)
                    end
                else
                    table.insert(body_blocks, converted)
                end
            end
        end
    end

    local result = {
        type = "admonition",
        variant = variant,
        children = body_blocks
    }

    if title then
        result.title = title
    end

    return result
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
        -- Check for aligned LaTeX environments → equation group
        if academic and node.mathtype == "DisplayMath" then
            local eq_group = academic.convert_equation_group(node.text)
            if eq_group then
                return {eq_group}
            end
        end
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

-- Convert DefinitionList to core definitionList block
-- Each entry becomes a definitionItem with definitionTerm + definitionDescription children
function M.definition_list(block)
    local items = {}

    for _, entry in ipairs(block.content) do
        local term_inlines = entry[1]
        local definitions = entry[2]

        -- Build definitionTerm with inline formatting preserved
        local term_block = {
            type = "definitionTerm",
            children = inlines.convert(term_inlines)
        }

        -- Build definitionDescription children (one per definition)
        local desc_blocks = {}
        for _, def in ipairs(definitions or {}) do
            table.insert(desc_blocks, {
                type = "definitionDescription",
                children = M.convert(def)
            })
        end

        -- Combine into definitionItem
        local item = {
            type = "definitionItem",
            children = {}
        }
        table.insert(item.children, term_block)
        for _, desc in ipairs(desc_blocks) do
            table.insert(item.children, desc)
        end

        table.insert(items, item)
    end

    return {
        type = "definitionList",
        children = items
    }
end

-- Convert a glossary Div containing DefinitionList to semantic:term blocks
-- Glossary terms get IDs and "see also" reference extraction
function M.glossary_div(block)
    local terms = {}

    for _, child in ipairs(block.content) do
        local tag = child.t or child.tag
        if tag == "DefinitionList" then
            for _, entry in ipairs(child.content) do
                local term_inlines = entry[1]
                local definitions = entry[2]

                local term_text = pandoc.utils.stringify(term_inlines)
                local term_id = "term-" .. term_text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")

                local def_parts = {}
                for _, def in ipairs(definitions or {}) do
                    table.insert(def_parts, pandoc.utils.stringify(def))
                end
                local definition = table.concat(def_parts, " ")

                -- Extract "see also" references
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
        else
            -- Non-DefinitionList content in glossary Div — convert normally
            local converted = M.convert_block(child)
            if converted then
                if converted.multi then
                    for _, b in ipairs(converted.blocks) do
                        table.insert(terms, b)
                    end
                else
                    table.insert(terms, converted)
                end
            end
        end
    end

    return {
        multi = true,
        blocks = terms
    }
end

-- Convert Figure to figure container with image child and optional figcaption
function M.figure(block)
    local attr = block.attr or {}
    local identifier = attr.identifier or (attr[1] or "")

    local result = {
        type = "figure",
        children = {}
    }

    if identifier and identifier ~= "" then
        result.id = identifier
    end

    -- Check for subfigure Divs (structured figure with subfigures)
    local has_subfigures = false
    if block.content then
        for _, child in ipairs(block.content) do
            local ctag = child.t or child.tag
            if ctag == "Div" then
                local cclasses = (child.attr and child.attr.classes) or (child.attr and child.attr[2]) or {}
                if has_class(cclasses, "subfigure") then
                    has_subfigures = true
                    break
                end
            end
        end
    end

    if has_subfigures then
        -- Process subfigures
        for _, child in ipairs(block.content) do
            local ctag = child.t or child.tag
            if ctag == "Div" then
                local cclasses = (child.attr and child.attr.classes) or (child.attr and child.attr[2]) or {}
                local cattrs = (child.attr and child.attr.attributes) or (child.attr and child.attr[3]) or {}
                if has_class(cclasses, "subfigure") then
                    local subfig = M.extract_subfigure(child, cattrs)
                    if subfig then
                        table.insert(result.children, subfig)
                    end
                end
            end
        end
    else
        -- Standard figure: extract image from content
        if block.content and #block.content > 0 then
            local first = block.content[1]
            if first.t == "Plain" or first.t == "Para" then
                local content = first.content or first.c
                if content and #content > 0 then
                    local img = content[1]
                    if img.t == "Image" then
                        local image_block = M.image(img)
                        table.insert(result.children, image_block)
                    end
                end
            end
        end
    end

    -- Extract caption from Figure container
    if block.caption and block.caption.long then
        local cap_inlines = {}
        for _, cap_block in ipairs(block.caption.long) do
            local cap_content = cap_block.content or cap_block.c
            if cap_content then
                for _, inline in ipairs(cap_content) do
                    table.insert(cap_inlines, inline)
                end
            end
        end
        if #cap_inlines > 0 then
            local figcaption = {
                type = "figcaption",
                children = inlines.convert(cap_inlines)
            }
            table.insert(result.children, figcaption)
        end
    end

    -- If we ended up with no children, fall back to converting content as blocks
    if #result.children == 0 then
        return {
            multi = true,
            blocks = M.convert(block.content or {})
        }
    end

    return result
end

-- Extract a subfigure from a Div with .subfigure class
function M.extract_subfigure(div, attrs)
    local subfig = {
        type = "figure",
        children = {}
    }

    if attrs and attrs.label then
        subfig.label = attrs.label
    end

    -- Extract image from subfigure Div content
    for _, child in ipairs(div.content or {}) do
        local ctag = child.t or child.tag
        if ctag == "Plain" or ctag == "Para" then
            local content = child.content or child.c
            if content then
                for _, inline in ipairs(content) do
                    if inline.t == "Image" then
                        table.insert(subfig.children, M.image(inline))
                    end
                end
            end
        end
    end

    if #subfig.children == 0 then
        return nil
    end

    return subfig
end

-- Convert Image inline to image block (with optional dimensions)
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

    -- Caption passed from outside (legacy path)
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
