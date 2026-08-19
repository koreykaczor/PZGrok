-- Minimal JSON for Kahlua / Lua 5.1. No deps.
PZGR = PZGR or {}
PZGR.Json = PZGR.Json or {}

local function esc(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, "\"", "\\\"")
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    return s
end

local function isarray(t)
    local n = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" then return false end
        n = n + 1
    end
    return n == #t
end

function PZGR.Json.encode(v)
    local tv = type(v)
    if v == nil then return "null" end
    if tv == "boolean" then return v and "true" or "false" end
    if tv == "number" then return tostring(v) end
    if tv == "string" then return "\"" .. esc(v) .. "\"" end
    if tv == "table" then
        if isarray(v) then
            local parts = {}
            for i = 1, #v do parts[i] = PZGR.Json.encode(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, val in pairs(v) do
                parts[#parts + 1] = "\"" .. esc(tostring(k)) .. "\":" .. PZGR.Json.encode(val)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

-- Tiny decoder: objects, arrays, strings, numbers, true/false/null.
function PZGR.Json.decode(str)
    local i = 1
    local s = str or ""
    local function peek() return string.sub(s, i, i) end
    local function skip()
        while true do
            local c = peek()
            if c == " " or c == "\n" or c == "\r" or c == "\t" then i = i + 1 else break end
        end
    end
    local parseValue
    local function parseString()
        i = i + 1
        local buf = {}
        while true do
            local c = peek()
            if c == "" then error("unterminated string") end
            if c == "\"" then i = i + 1; break end
            if c == "\\" then
                i = i + 1
                local e = peek(); i = i + 1
                if e == "n" then buf[#buf + 1] = "\n"
                elseif e == "t" then buf[#buf + 1] = "\t"
                elseif e == "r" then buf[#buf + 1] = "\r"
                else buf[#buf + 1] = e end
            else
                buf[#buf + 1] = c; i = i + 1
            end
        end
        return table.concat(buf)
    end
    local function parseNumber()
        local j = i
        while string.find(peek(), "[0-9%+%-%.eE]") do i = i + 1 end
        return tonumber(string.sub(s, j, i - 1))
    end
    local function parseObject()
        i = i + 1
        local obj = {}
        skip()
        if peek() == "}" then i = i + 1; return obj end
        while true do
            skip()
            local key = parseString()
            skip()
            i = i + 1 -- :
            skip()
            obj[key] = parseValue()
            skip()
            local c = peek()
            if c == "}" then i = i + 1; return obj end
            i = i + 1 -- ,
        end
    end
    local function parseArray()
        i = i + 1
        local arr = {}
        skip()
        if peek() == "]" then i = i + 1; return arr end
        while true do
            skip()
            arr[#arr + 1] = parseValue()
            skip()
            local c = peek()
            if c == "]" then i = i + 1; return arr end
            i = i + 1
        end
    end
    parseValue = function()
        skip()
        local c = peek()
        if c == "\"" then return parseString() end
        if c == "{" then return parseObject() end
        if c == "[" then return parseArray() end
        if c == "t" then i = i + 4; return true end
        if c == "f" then i = i + 5; return false end
        if c == "n" then i = i + 4; return nil end
        return parseNumber()
    end
    return parseValue()
end
