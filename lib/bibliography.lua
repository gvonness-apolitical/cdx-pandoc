-- lib/bibliography.lua
-- Extract CSL JSON metadata from Pandoc document references

-- Load shared utilities
local utils = dofile((PANDOC_SCRIPT_FILE and (PANDOC_SCRIPT_FILE:match("(.*/)" ) or "") or "") .. "lib/utils.lua")
local meta_to_string = utils.meta_to_string

local M = {}

-- Map CSL types to Codex entry types
M.TYPE_MAP = {
    ["article-journal"] = "article-journal",
    ["article-magazine"] = "article-magazine",
    ["article-newspaper"] = "article-newspaper",
    ["book"] = "book",
    ["chapter"] = "chapter",
    ["paper-conference"] = "paper-conference",
    ["thesis"] = "thesis",
    ["report"] = "report",
    ["webpage"] = "webpage",
    ["dataset"] = "dataset",
    ["software"] = "software",
    ["entry-encyclopedia"] = "entry-encyclopedia",
    ["motion_picture"] = "motion_picture",
    ["speech"] = "speech",
    ["interview"] = "interview",
    ["personal_communication"] = "personal_communication",
}

-- Extract author list from CSL author format
-- CSL uses: { family: "Smith", given: "John" } or { literal: "Organization" }
-- @param author_list MetaList of authors
-- @return Array of author objects
function M.extract_authors(author_list)
    if not author_list then
        return nil
    end

    local authors = {}

    -- Handle MetaList or plain table
    local items = author_list
    if author_list.t == "MetaList" then
        items = author_list
    end

    for _, author in ipairs(items) do
        local author_obj = {}

        -- Always use meta_to_string to ensure we get plain strings
        local family = nil
        local given = nil
        local literal = nil

        if author.family then
            family = meta_to_string(author.family)
        end
        if author.given then
            given = meta_to_string(author.given)
        end
        if author.literal then
            literal = meta_to_string(author.literal)
        end

        if family then
            author_obj.family = family
            if given then
                author_obj.given = given
            end
            table.insert(authors, author_obj)
        elseif literal then
            author_obj.literal = literal
            table.insert(authors, author_obj)
        end
    end

    return #authors > 0 and authors or nil
end

-- Extract date from CSL date-parts format
-- CSL uses: { date-parts: [[2024, 3, 15]] } for year, month, day
-- @param date_val CSL date value
-- @return Date object { year, month?, day? }
function M.extract_date(date_val)
    if not date_val then
        return nil
    end

    local result = {}

    -- Handle MetaMap
    local date_parts = date_val["date-parts"]
    if date_val.t == "MetaMap" then
        date_parts = date_val["date-parts"]
    end

    if date_parts then
        -- date-parts is an array of arrays: [[2024, 3, 15]]
        local parts = date_parts
        if date_parts.t == "MetaList" then
            parts = date_parts
        end

        if #parts > 0 then
            local first_date = parts[1]
            if first_date.t == "MetaList" then
                first_date = first_date
            end

            if #first_date >= 1 then
                local year = first_date[1]
                if year.t == "MetaString" then
                    result.year = tonumber(year.text)
                elseif type(year) == "number" then
                    result.year = year
                elseif type(year) == "table" and year[1] then
                    result.year = tonumber(meta_to_string(year))
                else
                    result.year = tonumber(meta_to_string(year))
                end
            end
            if #first_date >= 2 then
                local month = first_date[2]
                if type(month) == "number" then
                    result.month = month
                else
                    result.month = tonumber(meta_to_string(month))
                end
            end
            if #first_date >= 3 then
                local day = first_date[3]
                if type(day) == "number" then
                    result.day = day
                else
                    result.day = tonumber(meta_to_string(day))
                end
            end
        end
    end

    -- Also check for year directly (some CSL uses "year" instead of date-parts)
    if not result.year then
        local year = date_val.year
        if year then
            result.year = tonumber(meta_to_string(year))
        end
    end

    return result.year and result or nil
end

-- Extract a single CSL reference entry to Codex format
-- @param ref CSL reference (MetaMap or table)
-- @return Codex bibliography entry
function M.extract_entry(ref)
    if not ref then
        return nil
    end

    local entry = {}

    -- Helper to get field value
    local function get_field(name)
        local val = ref[name]
        if val then
            return meta_to_string(val)
        end
        return nil
    end

    -- Required: id
    entry.id = get_field("id")
    if not entry.id then
        return nil
    end

    -- Type (map to Codex types or keep as-is)
    local ref_type = get_field("type")
    entry.type = M.TYPE_MAP[ref_type] or ref_type or "other"

    -- Title
    local title = get_field("title")
    if title then
        entry.title = title
    end

    -- Authors
    local authors = M.extract_authors(ref.author)
    if authors then
        entry.author = authors
    end

    -- Editor
    local editors = M.extract_authors(ref.editor)
    if editors then
        entry.editor = editors
    end

    -- Issued date
    local issued = M.extract_date(ref.issued)
    if issued then
        entry.issued = issued
    end

    -- Container title (journal, book title, etc.)
    local container = get_field("container-title")
    if container then
        entry["container-title"] = container
    end

    -- Volume
    local volume = get_field("volume")
    if volume then
        entry.volume = volume
    end

    -- Issue
    local issue = get_field("issue")
    if issue then
        entry.issue = issue
    end

    -- Page
    local page = get_field("page")
    if page then
        entry.page = page
    end

    -- DOI
    local doi = get_field("DOI")
    if doi then
        entry.DOI = doi
    end

    -- URL
    local url = get_field("URL")
    if url then
        entry.URL = url
    end

    -- ISBN
    local isbn = get_field("ISBN")
    if isbn then
        entry.ISBN = isbn
    end

    -- Publisher
    local publisher = get_field("publisher")
    if publisher then
        entry.publisher = publisher
    end

    -- Publisher place
    local place = get_field("publisher-place")
    if place then
        entry["publisher-place"] = place
    end

    -- Abstract
    local abstract = get_field("abstract")
    if abstract then
        entry.abstract = abstract
    end

    return entry
end

-- Extract all CSL references from document metadata
-- @param meta Pandoc document metadata
-- @return Table keyed by reference ID, or empty table
function M.extract_from_meta(meta)
    if not meta then
        return {}
    end

    local references = meta.references
    if not references then
        return {}
    end

    local result = {}

    -- Handle MetaList or plain table
    local items = references
    if references.t == "MetaList" then
        items = references
    end

    for _, ref in ipairs(items) do
        local entry = M.extract_entry(ref)
        if entry and entry.id then
            result[entry.id] = entry
        end
    end

    return result
end

-- Detect citation style from metadata
-- Looks at doc.meta.csl or doc.meta.citation-style
-- @param meta Pandoc document metadata
-- @return Style name string (e.g., "apa", "chicago", "ieee") or "unknown"
function M.detect_style(meta)
    if not meta then
        return "unknown"
    end

    -- Check csl field (path to .csl file)
    local csl = meta.csl
    if csl then
        local csl_str = meta_to_string(csl)
        if csl_str then
            -- Extract style name from path: /path/to/apa.csl -> apa
            local style = csl_str:match("([^/\\]+)%.csl$")
            if style then
                return style:lower()
            end
        end
    end

    -- Check citation-style field
    local citation_style = meta["citation-style"]
    if citation_style then
        local style_str = meta_to_string(citation_style)
        if style_str then
            return style_str:lower()
        end
    end

    return "unknown"
end

return M
