#!/usr/bin/env lua
-- Convert pdftotext output to structured Markdown

local input_file = "c64ref/c64ref_pdftotext.txt"
local output_file = "c64ref/c64ref_improved.md"

local file = io.open(input_file, "r")
if not file then
  print("Error: Could not open " .. input_file)
  os.exit(1)
end

local content = file:read("*all")
file:close()

local output = {}

-- Add title
table.insert(output, "# COMMODORE 64 PROGRAMMER'S REFERENCE GUIDE")
table.insert(output, "")
table.insert(output, "REPRODUCED - 2024 BASED ON ORIGINAL DOCUMENTATION: FIRST PUBLISHED - 1982")
table.insert(output, "THIS REVISION: R240328-01")
table.insert(output, "")

-- Split into lines
local lines = {}
for line in content:gmatch("[^\r\n]+") do
  table.insert(lines, line)
end

-- Define known chapter titles from TOC
local main_chapters = {
  "INTRODUCTION",
  "1. BASIC PROGRAMMING RULES",
  "2. BASIC LANGUAGE VOCABULARY",
  "3. PROGRAMMING GRAPHICS ON THE COMMODORE 64",
  "4. PROGRAMMING SOUND AND MUSIC ON YOUR COMMODORE 64",
  "5. BASIC TO MACHINE LANGUAGE",
  "6. INPUT/OUTPUT GUIDE",
  "APPENDICES",
  "INDEX"
}

-- Track if we're in TOC and which chapters we've seen
local in_toc = false
local chapters_seen = {}

-- Process lines
for i, line in ipairs(lines) do
  local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")

  -- Detect TABLE OF CONTENTS
  if trimmed == "TABLE OF CONTENTS" then
    in_toc = true
    if not chapters_seen["TABLE OF CONTENTS"] then
      table.insert(output, "## TABLE OF CONTENTS")
      table.insert(output, "")
      chapters_seen["TABLE OF CONTENTS"] = true
    end

  -- End of TOC when we hit numbered chapter or INTRODUCTION after seeing TOC
  elseif in_toc and (trimmed:match("^INTRODUCTION%.") or trimmed:match("^1%. BASIC")) then
    in_toc = false
  end

  -- Check if this line is a main chapter header
  local is_chapter = false
  for _, chapter in ipairs(main_chapters) do
    -- Match chapter name (with or without trailing dots/numbers)
    local chapter_pattern = "^" .. chapter:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    if (trimmed:match(chapter_pattern) or trimmed:match(chapter_pattern .. "%.")) and not chapters_seen[chapter] then
      is_chapter = true
      chapters_seen[chapter] = true
      table.insert(output, "")
      table.insert(output, "## " .. chapter)
      table.insert(output, "")
      break
    end
  end

  -- If not a chapter header, add the content
  if not is_chapter and not (in_toc and i > 10) then
    -- Skip page markers (just roman numerals or numbers alone)
    if not trimmed:match("^[ivxlcdm]+$") and not trimmed:match("^%d+$") and trimmed ~= "" then
      table.insert(output, line)
    end
  end
end

-- Write output
local out = io.open(output_file, "w")
if not out then
  print("Error: Could not write to " .. output_file)
  os.exit(1)
end

out:write(table.concat(output, "\n"))
out:close()

print("Conversion complete!")
print("Input:  " .. input_file)
print("Output: " .. output_file)
print("Lines:  " .. #output)
