#!/usr/bin/env lua
-- tests/unit/test_academic.lua
-- Unit tests for lib/academic.lua
-- Tests pure-table helper functions that don't require Pandoc runtime

PANDOC_SCRIPT_FILE = "codex.lua"

local test = dofile("tests/unit/test_utils.lua")
local academic = dofile("lib/academic.lua")

print("Running academic unit tests...")
print("")

-- ============================================
-- Tests for classify_div()
-- ============================================

print("-- classify_div tests --")

test.test("classify_div theorem variants")
test.assert_eq("theorem", academic.classify_div({"theorem"}))
test.assert_eq("lemma", academic.classify_div({"lemma"}))
test.assert_eq("proposition", academic.classify_div({"proposition"}))
test.assert_eq("corollary", academic.classify_div({"corollary"}))
test.assert_eq("definition", academic.classify_div({"definition"}))
test.assert_eq("conjecture", academic.classify_div({"conjecture"}))
test.assert_eq("remark", academic.classify_div({"remark"}))
test.assert_eq("example", academic.classify_div({"example"}))

test.test("classify_div other academic types")
test.assert_eq("proof", academic.classify_div({"proof"}))
test.assert_eq("exercise", academic.classify_div({"exercise"}))
test.assert_eq("exercise-set", academic.classify_div({"exercise-set"}))
test.assert_eq("algorithm", academic.classify_div({"algorithm"}))
test.assert_eq("abstract", academic.classify_div({"abstract"}))
test.assert_eq("equation-group", academic.classify_div({"equation-group"}))

test.test("classify_div non-academic class")
test.assert_nil(academic.classify_div({"note"}))
test.assert_nil(academic.classify_div({"warning"}))
test.assert_nil(academic.classify_div({"custom-class"}))

test.test("classify_div empty classes")
test.assert_nil(academic.classify_div({}))

test.test("classify_div nil classes")
test.assert_nil(academic.classify_div(nil))

test.test("classify_div first match wins with multiple classes")
local result = academic.classify_div({"some-class", "theorem", "proof"})
test.assert_eq("theorem", result)

test.test("classify_div academic class not first")
result = academic.classify_div({"irrelevant", "lemma"})
test.assert_eq("lemma", result)

-- ============================================
-- Tests for detect_equation_group()
-- ============================================

print("")
print("-- detect_equation_group tests --")

test.test("detect_equation_group align")
test.assert_eq("align", academic.detect_equation_group("\\begin{align} x = 1 \\\\ y = 2 \\end{align}"))

test.test("detect_equation_group align*")
test.assert_eq("align*", academic.detect_equation_group("\\begin{align*} x = 1 \\end{align*}"))

test.test("detect_equation_group gather")
test.assert_eq("gather", academic.detect_equation_group("\\begin{gather} x = 1 \\end{gather}"))

test.test("detect_equation_group gather*")
test.assert_eq("gather*", academic.detect_equation_group("\\begin{gather*} x \\end{gather*}"))

test.test("detect_equation_group split")
test.assert_eq("split", academic.detect_equation_group("\\begin{split} x = 1 \\end{split}"))

test.test("detect_equation_group alignat")
test.assert_eq("alignat", academic.detect_equation_group("\\begin{alignat}{2} x = 1 \\end{alignat}"))

test.test("detect_equation_group alignat*")
test.assert_eq("alignat*", academic.detect_equation_group("\\begin{alignat*}{2} x \\end{alignat*}"))

test.test("detect_equation_group flalign")
test.assert_eq("flalign", academic.detect_equation_group("\\begin{flalign} x \\end{flalign}"))

test.test("detect_equation_group flalign*")
test.assert_eq("flalign*", academic.detect_equation_group("\\begin{flalign*} x \\end{flalign*}"))

test.test("detect_equation_group multline")
test.assert_eq("multline", academic.detect_equation_group("\\begin{multline} x \\end{multline}"))

test.test("detect_equation_group multline*")
test.assert_eq("multline*", academic.detect_equation_group("\\begin{multline*} x \\end{multline*}"))

test.test("detect_equation_group non-aligned environment returns nil")
test.assert_nil(academic.detect_equation_group("\\begin{equation} x = 1 \\end{equation}"))

test.test("detect_equation_group plain math returns nil")
test.assert_nil(academic.detect_equation_group("x^2 + y^2 = z^2"))

test.test("detect_equation_group nil returns nil")
test.assert_nil(academic.detect_equation_group(nil))

test.test("detect_equation_group empty string returns nil")
test.assert_nil(academic.detect_equation_group(""))

-- ============================================
-- Tests for equation_group()
-- ============================================

print("")
print("-- equation_group tests --")

test.test("equation_group basic align")
result = academic.equation_group("\\begin{align}\nx = 1 \\\\\ny = 2\n\\end{align}")
test.assert_not_nil(result)
test.assert_eq("academic:equation-group", result.type)
test.assert_eq("align", result.environment)
test.assert_not_nil(result.lines)
test.assert_eq(2, #result.lines)
test.assert_eq("x = 1", result.lines[1])
test.assert_eq("y = 2", result.lines[2])
test.assert_contains(result.value, "\\begin{align}")

test.test("equation_group gather*")
result = academic.equation_group("\\begin{gather*}\na + b \\\\\nc + d\n\\end{gather*}")
test.assert_not_nil(result)
test.assert_eq("academic:equation-group", result.type)
test.assert_eq("gather*", result.environment)
test.assert_eq(2, #result.lines)

test.test("equation_group single line")
result = academic.equation_group("\\begin{align}\nx = 1\n\\end{align}")
test.assert_not_nil(result)
test.assert_eq(1, #result.lines)
test.assert_eq("x = 1", result.lines[1])

test.test("equation_group preserves original value")
local original = "\\begin{split}\na \\\\\nb\n\\end{split}"
result = academic.equation_group(original)
test.assert_not_nil(result)
test.assert_eq(original, result.value)

test.test("equation_group non-aligned returns nil")
result = academic.equation_group("x^2 + y^2 = z^2")
test.assert_nil(result)

test.test("equation_group nil returns nil")
result = academic.equation_group(nil)
test.assert_nil(result)

-- ============================================
-- Tests for convert_div() dispatch (without Pandoc)
-- We test that the function dispatches correctly by verifying
-- it calls the right method. Since most methods need blocks module,
-- we test the dispatch boundary and error handling.
-- ============================================

print("")
print("-- convert_div dispatch --")

test.test("convert_div unknown type warns")
-- academic_type that isn't in the dispatch table
result = academic.convert_div({content = {}}, "nonexistent")
test.assert_nil(result)

print("")
test.summary()
