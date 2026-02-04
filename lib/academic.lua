-- lib/academic.lua
-- Writer-side academic extension block conversion
-- Converts Pandoc Divs/RawBlocks to academic:* Codex blocks

local M = {}

-- Module references (set by init)
local blocks = nil

-- Extension tracker function (set by codex.lua)
local track_extension = function() end

-- Helper: check if class list contains a class
local function has_class_in(classes, class_name)
    if not classes then return false end
    for _, c in ipairs(classes) do
        if c == class_name then return true end
    end
    return false
end

function M.set_blocks(mod)
    blocks = mod
end

function M.set_extension_tracker(tracker)
    track_extension = tracker or function() end
end

-- Theorem variant set
local theorem_variants = {
    theorem = true, lemma = true, proposition = true, corollary = true,
    definition = true, conjecture = true, remark = true, example = true
}

-- Academic class set (all classes handled by this module)
local academic_classes = {
    theorem = true, lemma = true, proposition = true, corollary = true,
    definition = true, conjecture = true, remark = true, example = true,
    proof = true, exercise = true, ["exercise-set"] = true,
    algorithm = true, abstract = true, ["equation-group"] = true
}

-- Classify a Div as an academic block type or nil
-- @param classes Array of CSS classes
-- @return academic block type string or nil
function M.classify_div(classes)
    if not classes then return nil end
    for _, cls in ipairs(classes) do
        if academic_classes[cls] then
            return cls
        end
    end
    return nil
end

-- Convert a theorem Div to academic:theorem block
-- Input: ::: {.theorem #thm-1 title="Maximum Principle"} ... :::
function M.convert_theorem(block, variant)
    local attr = block.attr or {}
    local id = attr.identifier or (attr[1] or "")
    local attributes = attr.attributes or (attr[3] or {})

    local result = {
        type = "academic:theorem",
        variant = variant,
        children = blocks.convert(block.content)
    }

    if id and id ~= "" then
        result.id = id
    end

    if attributes.title then
        result.title = attributes.title
    end

    if attributes.number then
        result.number = attributes.number
    end

    if attributes.uses then
        result.uses = attributes.uses
    end

    return result
end

-- Convert a proof Div to academic:proof block
-- Input: ::: {.proof of="thm-max" method="contradiction"} ... :::
function M.convert_proof(block)
    local attr = block.attr or {}
    local attributes = attr.attributes or (attr[3] or {})

    local result = {
        type = "academic:proof",
        children = blocks.convert(block.content)
    }

    if attributes.of then
        result.of = attributes.of
    end

    if attributes.method then
        result.method = attributes.method
    end

    return result
end

-- Convert an exercise Div to academic:exercise block
-- Input: ::: {.exercise #ex-1 difficulty="medium"} ... :::
-- Nested Divs: .hint, .solution
function M.convert_exercise(block)
    local attr = block.attr or {}
    local id = attr.identifier or (attr[1] or "")
    local attributes = attr.attributes or (attr[3] or {})

    local body_blocks = {}
    local hints = {}
    local solution = nil

    for _, child in ipairs(block.content or {}) do
        local tag = child.t or child.tag
        if tag == "Div" then
            local cclasses = (child.attr and child.attr.classes) or (child.attr and child.attr[2]) or {}
            local cattrs = (child.attr and child.attr.attributes) or (child.attr and child.attr[3]) or {}
            if has_class_in(cclasses, "hint") then
                table.insert(hints, {
                    children = blocks.convert(child.content)
                })
            elseif has_class_in(cclasses, "solution") then
                solution = {
                    children = blocks.convert(child.content)
                }
                if cattrs.visibility then
                    solution.visibility = cattrs.visibility
                end
            else
                -- Other Div inside exercise — convert normally
                local converted = blocks.convert_block(child)
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
        else
            local converted = blocks.convert_block(child)
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
        type = "academic:exercise",
        children = body_blocks
    }

    if id and id ~= "" then
        result.id = id
    end

    if attributes.difficulty then
        result.difficulty = attributes.difficulty
    end

    if #hints > 0 then
        result.hints = hints
    end

    if solution then
        result.solution = solution
    end

    return result
end

-- Convert an exercise-set Div to academic:exercise-set block
-- Input: ::: {.exercise-set #exercises-ch2 title="Chapter 2 Exercises"} ... :::
function M.convert_exercise_set(block)
    local attr = block.attr or {}
    local id = attr.identifier or (attr[1] or "")
    local attributes = attr.attributes or (attr[3] or {})

    local exercises = {}
    local preamble = {}

    for _, child in ipairs(block.content or {}) do
        local tag = child.t or child.tag
        if tag == "Div" then
            local cclasses = (child.attr and child.attr.classes) or (child.attr and child.attr[2]) or {}
            if has_class_in(cclasses, "exercise") then
                table.insert(exercises, M.convert_exercise(child))
            else
                -- Non-exercise Div → preamble content
                local converted = blocks.convert_block(child)
                if converted then
                    if converted.multi then
                        for _, b in ipairs(converted.blocks) do
                            table.insert(preamble, b)
                        end
                    else
                        table.insert(preamble, converted)
                    end
                end
            end
        else
            -- Non-Div content → preamble
            local converted = blocks.convert_block(child)
            if converted then
                if converted.multi then
                    for _, b in ipairs(converted.blocks) do
                        table.insert(preamble, b)
                    end
                else
                    table.insert(preamble, converted)
                end
            end
        end
    end

    local result = {
        type = "academic:exercise-set",
        exercises = exercises
    }

    if id and id ~= "" then
        result.id = id
    end

    if attributes.title then
        result.title = attributes.title
    end

    if #preamble > 0 then
        result.preamble = preamble
    end

    return result
end

-- Convert an algorithm Div to academic:algorithm block
-- Input: ::: {.algorithm #alg-sort title="QuickSort"} ... :::
-- The Div may contain a CodeBlock with class "algorithm" for pseudocode
function M.convert_algorithm(block)
    local attr = block.attr or {}
    local id = attr.identifier or (attr[1] or "")
    local attributes = attr.attributes or (attr[3] or {})

    local lines = {}
    local body_blocks = {}
    local inputs = nil
    local outputs = nil

    for _, child in ipairs(block.content or {}) do
        local tag = child.t or child.tag
        if tag == "CodeBlock" then
            local cclasses = (child.attr and child.attr.classes) or (child.attr and child.attr[2]) or {}
            if has_class_in(cclasses, "algorithm") then
                -- Parse pseudocode lines
                for line in child.text:gmatch("[^\n]+") do
                    table.insert(lines, line)
                end
            else
                table.insert(body_blocks, blocks.convert_block(child))
            end
        else
            local converted = blocks.convert_block(child)
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

    if attributes.inputs then
        inputs = attributes.inputs
    end
    if attributes.outputs then
        outputs = attributes.outputs
    end

    local result = {
        type = "academic:algorithm",
    }

    if id and id ~= "" then
        result.id = id
    end

    if attributes.title then
        result.title = attributes.title
    end

    if #lines > 0 then
        result.lines = lines
    end

    if inputs then
        result.inputs = inputs
    end

    if outputs then
        result.outputs = outputs
    end

    if attributes.lineNumbering then
        result.lineNumbering = attributes.lineNumbering == "true"
    end

    if #body_blocks > 0 then
        result.children = body_blocks
    end

    return result
end

-- Convert an abstract Div to academic:abstract block
-- Input: ::: {.abstract} ... ::: with optional ::: {.keywords} ... ::: inside
function M.convert_abstract(block)
    local body_blocks = {}
    local keywords = nil

    for _, child in ipairs(block.content or {}) do
        local tag = child.t or child.tag
        if tag == "Div" then
            local cclasses = (child.attr and child.attr.classes) or (child.attr and child.attr[2]) or {}
            if has_class_in(cclasses, "keywords") then
                -- Extract keywords from paragraph text
                local kw_text = pandoc.utils.stringify(child)
                keywords = {}
                for kw in kw_text:gmatch("[^,]+") do
                    local trimmed = kw:match("^%s*(.-)%s*$")
                    if trimmed and trimmed ~= "" then
                        table.insert(keywords, trimmed)
                    end
                end
            else
                local converted = blocks.convert_block(child)
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
        else
            local converted = blocks.convert_block(child)
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
        type = "academic:abstract",
        children = body_blocks
    }

    if keywords and #keywords > 0 then
        result.keywords = keywords
    end

    return result
end

-- Aligned LaTeX environment patterns for equation group detection
local aligned_environments = {
    "align", "align%*", "gather", "gather%*",
    "split", "alignat", "alignat%*",
    "flalign", "flalign%*", "multline", "multline%*"
}

-- Check if LaTeX text contains an aligned environment
-- @param text LaTeX source
-- @return environment name (without *) or nil
function M.detect_equation_group(text)
    if not text then return nil end
    for _, env in ipairs(aligned_environments) do
        if text:match("\\begin{" .. env .. "}") then
            -- Return clean environment name (strip pattern escapes)
            local clean = env:gsub("%%(%*)", "%1")
            return clean
        end
    end
    return nil
end

-- Convert a DisplayMath with aligned environment to academic:equation-group
-- @param text LaTeX source
-- @return equation-group block or nil
function M.convert_equation_group(text)
    local env = M.detect_equation_group(text)
    if not env then return nil end
    track_extension("codex.academic")

    -- Extract lines from the environment (split on \\)
    -- First, extract the content between \begin{env} and \end{env}
    local env_pattern = env:gsub("%*", "%%*")
    local inner = text:match("\\begin{" .. env_pattern .. "}(.-)\\end{" .. env_pattern .. "}")
    if not inner then
        return nil
    end

    local lines = {}
    for line in inner:gmatch("[^\\\\]+") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(lines, trimmed)
        end
    end

    return {
        type = "academic:equation-group",
        environment = env,
        lines = lines,
        value = text
    }
end

-- Convert a Div block to its academic type
-- @param block Pandoc Div element
-- @param academic_type The classified type string
-- @return Codex block
function M.convert_div(block, academic_type)
    track_extension("codex.academic")
    if theorem_variants[academic_type] then
        return M.convert_theorem(block, academic_type)
    elseif academic_type == "proof" then
        return M.convert_proof(block)
    elseif academic_type == "exercise" then
        return M.convert_exercise(block)
    elseif academic_type == "exercise-set" then
        return M.convert_exercise_set(block)
    elseif academic_type == "algorithm" then
        return M.convert_algorithm(block)
    elseif academic_type == "abstract" then
        return M.convert_abstract(block)
    elseif academic_type == "equation-group" then
        -- Explicit equation-group Div wrapper
        local body = blocks.convert(block.content)
        return {
            type = "academic:equation-group",
            children = body
        }
    end
    return nil
end

return M
