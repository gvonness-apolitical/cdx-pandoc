#!/usr/bin/env lua
-- tests/unit/test_metadata.lua
-- Unit tests for lib/metadata.lua
-- Tests functions that operate on plain Lua tables (no Pandoc dependency)

-- Need to provide a minimal PANDOC_SCRIPT_FILE so the module can load utils
PANDOC_SCRIPT_FILE = "codex.lua"

local test = dofile("tests/unit/test_utils.lua")
local metadata = dofile("lib/metadata.lua")

print("Running metadata unit tests...")
print("")

-- ============================================
-- Tests for default_metadata()
-- ============================================

print("-- default_metadata tests --")

test.test("default_metadata returns valid structure")
local dm = metadata.default_metadata()
test.assert_not_nil(dm)
test.assert_eq("1.1", dm.version)
test.assert_not_nil(dm.terms)
test.assert_eq("Untitled Document", dm.terms.title)
test.assert_eq("Unknown", dm.terms.creator)
test.assert_eq("Text", dm.terms.type)
test.assert_eq("application/vnd.codex+json", dm.terms.format)

-- ============================================
-- Tests for generate_jsonld()
-- ============================================

print("")
print("-- generate_jsonld tests --")

test.test("generate_jsonld nil input")
test.assert_nil(metadata.generate_jsonld(nil))

test.test("generate_jsonld no terms")
test.assert_nil(metadata.generate_jsonld({}))

test.test("generate_jsonld minimal input")
local jsonld = metadata.generate_jsonld({
    terms = {
        title = "Test Doc",
        type = "Text"
    }
})
test.assert_not_nil(jsonld)
test.assert_eq("https://schema.org/", jsonld["@context"])
test.assert_eq("Article", jsonld["@type"])
test.assert_eq("Test Doc", jsonld.name)

test.test("generate_jsonld with single creator")
jsonld = metadata.generate_jsonld({
    terms = {
        title = "Test",
        type = "Text",
        creator = "John Doe"
    }
})
test.assert_not_nil(jsonld.author)
test.assert_eq("Person", jsonld.author["@type"])
test.assert_eq("John Doe", jsonld.author.name)

test.test("generate_jsonld with multiple creators")
jsonld = metadata.generate_jsonld({
    terms = {
        title = "Test",
        type = "Text",
        creator = {"Alice", "Bob"}
    }
})
test.assert_not_nil(jsonld.author)
test.assert_eq(2, #jsonld.author)
test.assert_eq("Alice", jsonld.author[1].name)
test.assert_eq("Bob", jsonld.author[2].name)

test.test("generate_jsonld with structured creators and ORCID")
jsonld = metadata.generate_jsonld({
    terms = {
        title = "Test",
        type = "Text",
        creators = {
            {name = "Jane Doe", orcid = "0000-0001-2345-6789", affiliation = "MIT", email = "jane@mit.edu"}
        }
    }
})
test.assert_not_nil(jsonld.author)
test.assert_eq("Person", jsonld.author["@type"])
test.assert_eq("Jane Doe", jsonld.author.name)
test.assert_eq("https://orcid.org/0000-0001-2345-6789", jsonld.author["@id"])
test.assert_eq("Organization", jsonld.author.affiliation["@type"])
test.assert_eq("MIT", jsonld.author.affiliation.name)
test.assert_eq("jane@mit.edu", jsonld.author.email)

test.test("generate_jsonld with date")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "Text", date = "2024-01-15"}
})
test.assert_eq("2024-01-15", jsonld.datePublished)

test.test("generate_jsonld with description")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "Text", description = "An abstract"}
})
test.assert_eq("An abstract", jsonld.description)

test.test("generate_jsonld with keywords array")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "Text", subject = {"lua", "testing"}}
})
test.assert_eq("lua, testing", jsonld.keywords)

test.test("generate_jsonld with keywords string")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "Text", subject = "single keyword"}
})
test.assert_eq("single keyword", jsonld.keywords)

test.test("generate_jsonld with language")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "Text", language = "en"}
})
test.assert_eq("en", jsonld.inLanguage)

test.test("generate_jsonld with publisher")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "Text", publisher = "Acme Press"}
})
test.assert_not_nil(jsonld.publisher)
test.assert_eq("Organization", jsonld.publisher["@type"])
test.assert_eq("Acme Press", jsonld.publisher.name)

test.test("generate_jsonld with rights")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "Text", rights = "CC-BY-4.0"}
})
test.assert_eq("CC-BY-4.0", jsonld.license)

test.test("generate_jsonld with DOI identifier")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "Text", identifier = "10.1234/test"}
})
test.assert_not_nil(jsonld.identifier)
test.assert_eq("PropertyValue", jsonld.identifier["@type"])
test.assert_eq("DOI", jsonld.identifier.propertyID)
test.assert_eq("10.1234/test", jsonld.identifier.value)

test.test("generate_jsonld with ISBN identifier")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "Text", identifier = "978-0-123456-78-9"}
})
test.assert_eq("978-0-123456-78-9", jsonld.isbn)

test.test("generate_jsonld with plain identifier")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "Text", identifier = "custom-id-123"}
})
test.assert_eq("custom-id-123", jsonld.identifier)

test.test("generate_jsonld type mapping Book")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "Book"}
})
test.assert_eq("Book", jsonld["@type"])

test.test("generate_jsonld type mapping unknown")
jsonld = metadata.generate_jsonld({
    terms = {title = "Test", type = "UnknownType"}
})
test.assert_eq("CreativeWork", jsonld["@type"])

test.test("generate_jsonld multiple structured creators")
jsonld = metadata.generate_jsonld({
    terms = {
        title = "Test",
        type = "Text",
        creators = {
            {name = "Alice"},
            {name = "Bob"}
        }
    }
})
test.assert_eq(2, #jsonld.author)
test.assert_eq("Alice", jsonld.author[1].name)
test.assert_eq("Bob", jsonld.author[2].name)

print("")
test.summary()
