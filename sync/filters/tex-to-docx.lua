-- tex-to-docx.lua
-- One-time "seed" filter: converts your existing .tex into a .docx that you
-- upload to Google Docs. It writes cross-references in the {{ref:label}} form
-- that docs-to-latex.lua reads back, and keeps any hand-written \label that
-- differs from the automatic one as a trailing {#label} on the heading.

-- Keep in sync with the copy in docs-to-latex.lua
local function slugify(s)
  s = s:lower()
  s = s:gsub("[^%w%s%-_%.\128-\255]", "")
  s = s:gsub("%s+", "-")
  s = s:gsub("^[^%a\128-\255]+", "")
  if s == "" then s = "section" end
  return s
end

function Header(h)
  local auto = slugify(pandoc.utils.stringify(h.content))
  if h.identifier ~= "" and h.identifier ~= auto then
    h.content:insert(pandoc.Space())
    h.content:insert(pandoc.Str("{#" .. h.identifier .. "}"))
  end
  h.identifier = ""
  return h
end

-- \ref{x} (pandoc parses it into a Link carrying reference-type)
function Link(l)
  local kind = l.attributes["reference-type"]
  if kind then
    local label = l.attributes["reference"] or l.target:gsub("^#", "")
    if kind == "pageref" then kind = "pageref" else kind = "ref" end
    return pandoc.Str("{{" .. kind .. ":" .. label .. "}}")
  end
end

-- bylaws_sync.py rewrites \nameref{x} / \pageref{x} to @@nameref:x@@ before
-- pandoc reads the file (pandoc's LaTeX reader silently discards them).
-- Turn those markers into the {{nameref:x}} form used in the Google Doc.
function Str(s)
  if not s.text:find("@@", 1, true) then return nil end
  local out = pandoc.List()
  local rest = s.text
  while true do
    local a, b, cmd, label = rest:find("@@(%a+):([^@]+)@@")
    if not a then break end
    if a > 1 then out:insert(pandoc.Str(rest:sub(1, a - 1))) end
    out:insert(pandoc.Str("{{" .. cmd .. ":" .. label .. "}}"))
    rest = rest:sub(b + 1)
  end
  if #out == 0 then return nil end
  if rest ~= "" then out:insert(pandoc.Str(rest)) end
  return out
end

-- A paragraph that is just a protected \input{path} line becomes {{input:path}}
-- (the path may contain spaces, which is why this is done per paragraph).
function Para(p)
  local path = pandoc.utils.stringify(p):match("^@@input:(.-)@@$")
  if path then
    return pandoc.Para({ pandoc.Str("{{input:" .. path .. "}}") })
  end
end

-- Drop other raw LaTeX (\label, \hypertarget, \newpage...) rather than
-- letting it appear as stray text in the doc.
function RawInline(r)
  return {}
end

function RawBlock(r)
  return {}
end
