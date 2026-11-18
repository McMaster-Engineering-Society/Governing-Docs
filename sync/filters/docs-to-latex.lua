-- docs-to-latex.lua
-- Pandoc Lua filter: turns a Google Docs .docx export into LaTeX that matches
-- the conventions of the MES bylaws project.
--
--   * Headings get a stable \label (same slug rules pandoc uses by default),
--     or an explicit one if the heading ends in {#my-label}
--   * {{ref:label}}, {{nameref:label}}, {{pageref:label}} become \ref etc.
--   * Lists use LaTeX's default numbering (your enumitem settings take over)
--   * Underline/strikethrough use commands that exist in your preamble

-- ---------------------------------------------------------------- helpers --
-- Keep in sync with the copy in tex-to-docx.lua
local function slugify(s)
  s = s:lower()
  s = s:gsub("[^%w%s%-_%.\128-\255]", "")
  s = s:gsub("%s+", "-")
  s = s:gsub("^[^%a\128-\255]+", "")
  if s == "" then s = "section" end
  return s
end

local used_ids = {}
local function unique(id)
  local candidate, n = id, 0
  while used_ids[candidate] do
    n = n + 1
    candidate = id .. "-" .. n
  end
  used_ids[candidate] = true
  return candidate
end

-- ---------------------------------------------------------------- headings --
function Header(h)
  -- Google Docs wraps headings in invisible bookmark spans; unwrap them so
  -- they don't turn into \hypertarget{_heading=h.xxxx}{...}
  h = h:walk({
    Span = function(s) return s.content end,
    Link = function(l) if l.target:match("^#") then return l.content end end,
  })

  -- Optional explicit label: "Ratification Process {#ratification}"
  local explicit
  local n = #h.content
  if n > 0 and h.content[n].t == "Str" then
    local id = h.content[n].text:match("^{#([%w%-_%.:]+)}$")
    if id then
      explicit = id
      h.content:remove(n)
      if n > 1 and h.content[n - 1].t == "Space" then
        h.content:remove(n - 1)
      end
    end
  end

  local id = unique(explicit or slugify(pandoc.utils.stringify(h.content)))
  h.identifier = ""   -- stops pandoc wrapping the heading in \hypertarget{...}
  h.classes = {}
  h.attributes = {}
  return { h, pandoc.RawBlock("latex", "\\label{" .. id .. "}") }
end

-- ------------------------------------------------------------ cross-refs ---
local REF_COMMANDS = { ref = true, nameref = true, pageref = true }

function Str(s)
  if not s.text:find("{{", 1, true) then return nil end
  local out = pandoc.List()
  local rest = s.text
  while true do
    local a, b, cmd, label = rest:find("{{(%a+):([^}]+)}}")
    if not a then break end
    if REF_COMMANDS[cmd] then
      if a > 1 then out:insert(pandoc.Str(rest:sub(1, a - 1))) end
      label = label:gsub("%s", "")
      out:insert(pandoc.RawInline("latex", "\\" .. cmd .. "{" .. label .. "}"))
      rest = rest:sub(b + 1)
    else
      -- unknown command: leave it alone and stop scanning this token
      break
    end
  end
  if #out == 0 then return nil end
  if rest ~= "" then out:insert(pandoc.Str(rest)) end
  return out
end

-- A paragraph made only of {{input:path/to/file}} placeholders becomes \input{...}
-- lines, so a parent section can keep pulling in its subfolder files.
function Para(p)
  local text = pandoc.utils.stringify(p)
  local lines = {}
  for path in text:gmatch("{{input:(.-)}}") do
    lines[#lines + 1] = "\\input{" .. path .. "}"
  end
  if #lines > 0 and (text:gsub("{{input:.-}}", "")):match("^%s*$") then
    return pandoc.RawBlock("latex", table.concat(lines, "\n"))
  end
end

-- Adjacent \input paragraphs are written as consecutive lines (as in the
-- hand-written files) rather than separated by blank lines.
function Blocks(blocks)
  local out = pandoc.List()
  local function is_input(b)
    return b and b.t == "RawBlock" and b.format == "latex" and b.text:match("^\\input{")
  end
  for _, b in ipairs(blocks) do
    local last = out[#out]
    if is_input(b) and is_input(last) then
      out[#out] = pandoc.RawBlock("latex", last.text .. "\n" .. b.text)
    else
      out:insert(b)
    end
  end
  return out
end

-- ------------------------------------------------------------------ lists --
-- Make every list "loose" so pandoc never emits \tightlist (which isn't
-- defined in the bylaws preamble). Spacing is controlled by enumitem instead.
local function loosen(list)
  for _, item in ipairs(list.content) do
    for j, block in ipairs(item) do
      if block.t == "Plain" then item[j] = pandoc.Para(block.content) end
    end
  end
end

function BulletList(l)
  loosen(l)
  return l
end

function OrderedList(l)
  -- Drop Google's "1)" / "a." styles so LaTeX's own numbering is used.
  l.listAttributes = pandoc.ListAttributes(l.start, "DefaultStyle", "DefaultDelim")
  loosen(l)
  return l
end

-- ------------------------------------------------------------ inline style -
function Underline(el)
  local out = pandoc.List({ pandoc.RawInline("latex", "\\underline{") })
  out:extend(el.content)
  out:insert(pandoc.RawInline("latex", "}"))
  return out
end

function Strikeout(el)
  local out = pandoc.List({ pandoc.RawInline("latex", "\\sout{") })
  out:extend(el.content)
  out:insert(pandoc.RawInline("latex", "}"))
  return out
end

-- Small caps etc. come through as plain text; images can't be converted.
function Image(img)
  io.stderr:write("WARNING: image in Google Doc was dropped (images stay in LaTeX)\n")
  return {}
end
