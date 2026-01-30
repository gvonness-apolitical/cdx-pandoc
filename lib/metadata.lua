-- lib/metadata.lua
-- Extract and convert Pandoc metadata to Dublin Core format

-- Load shared utilities
local utils = dofile((PANDOC_SCRIPT_FILE and (PANDOC_SCRIPT_FILE:match("(.*/)" ) or "") or "") .. "lib/utils.lua")
local meta_to_string = utils.meta_to_string

local M = {}

-- Extract an array of strings from a MetaList
local function meta_to_array(value)
    if not value then
        return nil
    end

    local t = value.t or value.tag

    if t == "MetaList" then
        local result = {}
        for _, item in ipairs(value) do
            local str = meta_to_string(item)
            if str then
                table.insert(result, str)
            end
        end
        return #result > 0 and result or nil
    elseif t == "MetaInlines" or t == "MetaString" then
        local str = meta_to_string(value)
        return str and {str} or nil
    elseif type(value) == "table" and #value > 0 then
        -- Pandoc 3.x uses plain Lua tables for MetaList
        local result = {}
        for _, item in ipairs(value) do
            local str = meta_to_string(item)
            if str then
                table.insert(result, str)
            end
        end
        return #result > 0 and result or nil
    end

    return nil
end

-- Extract a single author object (handles both simple strings and structured metadata)
-- Returns { name = "...", orcid = "..." } or just { name = "..." }
local function extract_single_author(author_meta)
    if not author_meta then
        return nil
    end

    local t = author_meta.t or author_meta.tag

    -- Check if it's a structured author (MetaMap with name/orcid fields)
    if t == "MetaMap" or (type(author_meta) == "table" and author_meta.name) then
        local author_obj = {}

        -- Extract name
        local name = author_meta.name
        if name then
            author_obj.name = meta_to_string(name)
        end

        -- Extract ORCID
        local orcid = author_meta.orcid or author_meta.ORCID
        if orcid then
            local orcid_str = meta_to_string(orcid)
            if orcid_str then
                -- Normalize ORCID: remove URL prefix if present
                orcid_str = orcid_str:gsub("^https?://orcid%.org/", "")
                author_obj.orcid = orcid_str
            end
        end

        -- Extract affiliation if present
        local affiliation = author_meta.affiliation
        if affiliation then
            author_obj.affiliation = meta_to_string(affiliation)
        end

        -- Extract email if present
        local email = author_meta.email
        if email then
            author_obj.email = meta_to_string(email)
        end

        if author_obj.name then
            return author_obj
        end
    end

    -- Fall back to simple string extraction
    local name_str = meta_to_string(author_meta)
    if name_str then
        return { name = name_str }
    end

    return nil
end

-- Extract author(s) - can be string, array, or structured objects with ORCID
-- Returns array of author objects: [{ name: "...", orcid?: "..." }, ...]
local function extract_authors(meta)
    local author = meta.author

    if not author then
        return nil
    end

    local t = author.t or author.tag

    if t == "MetaList" or (type(author) == "table" and #author > 0) then
        local authors = {}
        for _, a in ipairs(author) do
            local author_obj = extract_single_author(a)
            if author_obj then
                table.insert(authors, author_obj)
            end
        end
        if #authors > 0 then
            return authors
        end
    else
        -- Single author
        local author_obj = extract_single_author(author)
        if author_obj then
            return { author_obj }
        end
    end

    return nil
end

-- Get simple creator names for Dublin Core (backwards compatible)
local function get_creator_names(authors)
    if not authors then
        return nil
    end

    local names = {}
    for _, a in ipairs(authors) do
        if a.name then
            table.insert(names, a.name)
        end
    end

    if #names == 1 then
        return names[1]
    elseif #names > 1 then
        return names
    end

    return nil
end

-- Extract keywords/subject
local function extract_keywords(meta)
    -- Try various metadata fields
    local keywords = meta.keywords or meta.tags or meta.subject

    if not keywords then
        return nil
    end

    return meta_to_array(keywords)
end

-- Format date to ISO 8601
local function format_date(date_str)
    if not date_str then
        return nil
    end

    -- If already ISO format, return as-is
    if date_str:match("^%d%d%d%d%-%d%d%-%d%d") then
        return date_str
    end

    -- Try to parse common date formats
    local year, month, day = date_str:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if year then
        return string.format("%s-%s-%s", year, month, day)
    end

    -- Try month/day/year format
    month, day, year = date_str:match("(%d%d?)/(%d%d?)/(%d%d%d%d)")
    if year then
        return string.format("%s-%02d-%02d", year, tonumber(month), tonumber(day))
    end

    -- Return as-is if can't parse
    return date_str
end

-- Extract Dublin Core metadata from Pandoc document metadata
-- @param meta Pandoc document metadata
-- @return Dublin Core metadata table
function M.extract(meta)
    if not meta then
        return nil
    end

    local terms = {}

    -- Title (required)
    local title = meta_to_string(meta.title)
    if title then
        terms.title = title
    end

    -- Creator/Author (required)
    -- Extract structured author data (with ORCID support)
    local authors = extract_authors(meta)
    if authors then
        -- Store simple names in creator for DC compatibility
        terms.creator = get_creator_names(authors)
        -- Store full structured data in creators for extended metadata
        terms.creators = authors
    end

    -- Date
    local date = meta_to_string(meta.date)
    if date then
        terms.date = format_date(date)
    end

    -- Description/Abstract
    local description = meta_to_string(meta.abstract) or meta_to_string(meta.description)
    if description then
        terms.description = description
    end

    -- Subject/Keywords
    local subject = extract_keywords(meta)
    if subject then
        terms.subject = subject
    end

    -- Language
    local lang = meta_to_string(meta.lang) or meta_to_string(meta.language)
    if lang then
        terms.language = lang
    end

    -- Publisher
    local publisher = meta_to_string(meta.publisher)
    if publisher then
        terms.publisher = publisher
    end

    -- Rights
    local rights = meta_to_string(meta.rights) or meta_to_string(meta.license)
    if rights then
        terms.rights = rights
    end

    -- Identifier (ISBN, DOI, etc.)
    local identifier = meta_to_string(meta.identifier) or meta_to_string(meta.isbn) or meta_to_string(meta.doi)
    if identifier then
        terms.identifier = identifier
    end

    -- Source
    local source = meta_to_string(meta.source)
    if source then
        terms.source = source
    end

    -- Type (default to Text for documents)
    local doc_type = meta_to_string(meta["type"]) or meta_to_string(meta.documentType)
    terms.type = doc_type or "Text"

    -- Format (always Codex JSON)
    terms.format = "application/vnd.codex+json"

    -- If we have no title or creator, return nil
    if not terms.title then
        terms.title = "Untitled Document"
    end
    if not terms.creator then
        terms.creator = "Unknown"
    end

    return {
        version = "1.1",
        terms = terms
    }
end

-- Create default Dublin Core metadata
function M.default_metadata()
    return {
        version = "1.1",
        terms = {
            title = "Untitled Document",
            creator = "Unknown",
            type = "Text",
            format = "application/vnd.codex+json"
        }
    }
end

-- Map Dublin Core type to schema.org type
local function dc_type_to_schema_type(dc_type)
    local mapping = {
        Text = "Article",
        Article = "Article",
        Book = "Book",
        Report = "Report",
        Thesis = "Thesis",
        Dataset = "Dataset",
        Software = "SoftwareSourceCode",
        Image = "ImageObject",
        Sound = "AudioObject",
        MovingImage = "VideoObject",
        Collection = "Collection",
    }
    return mapping[dc_type] or "CreativeWork"
end

-- Generate JSON-LD metadata from Dublin Core
-- @param dublin_core Dublin Core metadata table
-- @return JSON-LD metadata table or nil
function M.generate_jsonld(dublin_core)
    if not dublin_core or not dublin_core.terms then
        return nil
    end

    local terms = dublin_core.terms

    -- Build the JSON-LD object
    local jsonld = {
        ["@context"] = "https://schema.org/",
        ["@type"] = dc_type_to_schema_type(terms.type),
        name = terms.title
    }

    -- Add author(s) with ORCID support
    if terms.creators then
        -- Use structured author data with ORCID
        local authors = {}
        for _, author in ipairs(terms.creators) do
            local author_obj = {
                ["@type"] = "Person",
                name = author.name
            }
            -- Add ORCID as @id (schema.org standard for person identifiers)
            if author.orcid then
                author_obj["@id"] = "https://orcid.org/" .. author.orcid
            end
            -- Add affiliation if present
            if author.affiliation then
                author_obj.affiliation = {
                    ["@type"] = "Organization",
                    name = author.affiliation
                }
            end
            -- Add email if present
            if author.email then
                author_obj.email = author.email
            end
            table.insert(authors, author_obj)
        end
        if #authors == 1 then
            jsonld.author = authors[1]
        else
            jsonld.author = authors
        end
    elseif terms.creator then
        -- Fallback to simple creator names
        if type(terms.creator) == "table" then
            -- Multiple authors
            local authors = {}
            for _, name in ipairs(terms.creator) do
                table.insert(authors, {
                    ["@type"] = "Person",
                    name = name
                })
            end
            jsonld.author = authors
        else
            -- Single author
            jsonld.author = {
                ["@type"] = "Person",
                name = terms.creator
            }
        end
    end

    -- Add date published
    if terms.date then
        jsonld.datePublished = terms.date
    end

    -- Add description/abstract
    if terms.description then
        jsonld.description = terms.description
    end

    -- Add keywords
    if terms.subject then
        if type(terms.subject) == "table" then
            jsonld.keywords = table.concat(terms.subject, ", ")
        else
            jsonld.keywords = terms.subject
        end
    end

    -- Add language
    if terms.language then
        jsonld.inLanguage = terms.language
    end

    -- Add publisher
    if terms.publisher then
        jsonld.publisher = {
            ["@type"] = "Organization",
            name = terms.publisher
        }
    end

    -- Add license/rights
    if terms.rights then
        jsonld.license = terms.rights
    end

    -- Add identifier (DOI, ISBN, etc.)
    if terms.identifier then
        -- Check if it's a DOI
        if terms.identifier:match("^10%.") or terms.identifier:match("doi:") then
            local doi = terms.identifier:gsub("^doi:", ""):gsub("^https?://doi%.org/", "")
            jsonld.identifier = {
                ["@type"] = "PropertyValue",
                propertyID = "DOI",
                value = doi
            }
        elseif terms.identifier:match("^%d%d%d%-%d") or terms.identifier:match("^ISBN") then
            -- ISBN
            local isbn = terms.identifier:gsub("^ISBN[:%s]*", "")
            jsonld.isbn = isbn
        else
            jsonld.identifier = terms.identifier
        end
    end

    return jsonld
end

return M
