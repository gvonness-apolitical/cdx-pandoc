-- lib/reader_academic.lua
-- Reader-side academic extension block conversion
-- Converts academic:* Codex blocks back to Pandoc AST

local M = {}

-- Module references (set by init)
local reader_blocks = nil
local reader_inlines = nil

function M.set_reader_blocks(mod)
    reader_blocks = mod
end

function M.set_reader_inlines(mod)
    reader_inlines = mod
end

-- Convert an academic:* block to Pandoc block(s)
function M.convert_block(block)
    local btype = block.type or ""

    if btype == "academic:theorem" then
        return M.theorem(block)
    elseif btype == "academic:proof" then
        return M.proof(block)
    elseif btype == "academic:exercise" then
        return M.exercise(block)
    elseif btype == "academic:exercise-set" then
        return M.exercise_set(block)
    elseif btype == "academic:algorithm" then
        return M.algorithm(block)
    elseif btype == "academic:abstract" then
        return M.abstract(block)
    elseif btype == "academic:equation-group" then
        return M.equation_group(block)
    end

    return nil
end

-- academic:theorem → Div with variant class and attributes
function M.theorem(block)
    local variant = block.variant or "theorem"
    local id = block.id or ""
    local attrs = {}

    if block.title then
        attrs.title = block.title
    end
    if block.number then
        attrs.number = block.number
    end
    if block.uses then
        attrs.uses = block.uses
    end

    local content = reader_blocks.convert(block.children or {})
    return pandoc.Div(content, pandoc.Attr(id, {variant}, attrs))
end

-- academic:proof → Div with proof class and attributes
function M.proof(block)
    local attrs = {}

    if block.of then
        attrs.of = block.of
    end
    if block.method then
        attrs.method = block.method
    end

    local content = reader_blocks.convert(block.children or {})
    return pandoc.Div(content, pandoc.Attr("", {"proof"}, attrs))
end

-- academic:exercise → Div with exercise class, nested hint/solution Divs
function M.exercise(block)
    local id = block.id or ""
    local attrs = {}

    if block.difficulty then
        attrs.difficulty = block.difficulty
    end

    local content = reader_blocks.convert(block.children or {})

    -- Add hints as nested Divs
    if block.hints then
        for _, hint in ipairs(block.hints) do
            local hint_blocks = reader_blocks.convert(hint.children or {})
            table.insert(content, pandoc.Div(hint_blocks, pandoc.Attr("", {"hint"})))
        end
    end

    -- Add solution as nested Div
    if block.solution then
        local sol_blocks = reader_blocks.convert(block.solution.children or {})
        local sol_attrs = {}
        if block.solution.visibility then
            sol_attrs.visibility = block.solution.visibility
        end
        table.insert(content, pandoc.Div(sol_blocks, pandoc.Attr("", {"solution"}, sol_attrs)))
    end

    return pandoc.Div(content, pandoc.Attr(id, {"exercise"}, attrs))
end

-- academic:exercise-set → Div with exercise-set class containing exercises
function M.exercise_set(block)
    local id = block.id or ""
    local attrs = {}

    if block.title then
        attrs.title = block.title
    end

    local content = {}

    -- Add preamble blocks
    if block.preamble then
        local pre = reader_blocks.convert(block.preamble)
        for _, b in ipairs(pre) do
            table.insert(content, b)
        end
    end

    -- Add exercises
    for _, ex in ipairs(block.exercises or {}) do
        local ex_block = M.exercise(ex)
        if ex_block then
            table.insert(content, ex_block)
        end
    end

    return pandoc.Div(content, pandoc.Attr(id, {"exercise-set"}, attrs))
end

-- academic:algorithm → Div with algorithm class, CodeBlock for pseudocode
function M.algorithm(block)
    local id = block.id or ""
    local attrs = {}

    if block.title then
        attrs.title = block.title
    end
    if block.inputs then
        attrs.inputs = block.inputs
    end
    if block.outputs then
        attrs.outputs = block.outputs
    end
    if block.lineNumbering then
        attrs.lineNumbering = tostring(block.lineNumbering)
    end

    local content = {}

    -- Pseudocode lines → CodeBlock with algorithm class
    if block.lines and #block.lines > 0 then
        local code_text = table.concat(block.lines, "\n")
        table.insert(content, pandoc.CodeBlock(code_text, pandoc.Attr("", {"algorithm"})))
    end

    -- Additional children
    if block.children then
        local child_blocks = reader_blocks.convert(block.children)
        for _, b in ipairs(child_blocks) do
            table.insert(content, b)
        end
    end

    return pandoc.Div(content, pandoc.Attr(id, {"algorithm"}, attrs))
end

-- academic:abstract → Div with abstract class, keywords as nested Div
function M.abstract(block)
    local content = reader_blocks.convert(block.children or {})

    -- Add keywords as nested Div
    if block.keywords and #block.keywords > 0 then
        local kw_text = table.concat(block.keywords, ", ")
        local kw_div = pandoc.Div(
            {pandoc.Para({pandoc.Str(kw_text)})},
            pandoc.Attr("", {"keywords"})
        )
        table.insert(content, kw_div)
    end

    return pandoc.Div(content, pandoc.Attr("", {"abstract"}))
end

-- academic:equation-group → DisplayMath with reconstructed aligned LaTeX
function M.equation_group(block)
    local env = block.environment or "align"

    if block.value then
        -- If original LaTeX preserved, use it directly
        local math_el = pandoc.Math(pandoc.DisplayMath, block.value)
        return pandoc.Para({math_el})
    end

    -- Reconstruct from lines
    local lines = block.lines or {}
    local inner = table.concat(lines, " \\\\\n")
    local latex = "\\begin{" .. env .. "}\n" .. inner .. "\n\\end{" .. env .. "}"

    local math_el = pandoc.Math(pandoc.DisplayMath, latex)
    return pandoc.Para({math_el})
end

return M
