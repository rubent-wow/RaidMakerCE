-- RaidMakerCEJSON.lua
-- Minimal recursive-descent JSON parser for Lua 5.0 (Classic WoW)

local function skipWhitespace(str, pos)
    while pos <= string.len(str) do
        local c = string.sub(str, pos, pos)
        if c == " " or c == "\t" or c == "\n" or c == "\r" then
            pos = pos + 1
        else
            break
        end
    end
    return pos
end

local parseValue -- forward declaration

local function parseString(str, pos)
    -- pos should be at the opening "
    if string.sub(str, pos, pos) ~= "\"" then
        return nil, "Expected '\"' at position " .. pos
    end
    pos = pos + 1
    local parts = {}
    while pos <= string.len(str) do
        local c = string.sub(str, pos, pos)
        if c == "\\" then
            pos = pos + 1
            local esc = string.sub(str, pos, pos)
            if esc == "\"" then
                table.insert(parts, "\"")
            elseif esc == "\\" then
                table.insert(parts, "\\")
            elseif esc == "/" then
                table.insert(parts, "/")
            elseif esc == "n" then
                table.insert(parts, "\n")
            elseif esc == "t" then
                table.insert(parts, "\t")
            elseif esc == "r" then
                table.insert(parts, "\r")
            elseif esc == "b" then
                table.insert(parts, "\b")
            elseif esc == "f" then
                table.insert(parts, "\f")
            elseif esc == "u" then
                -- Skip unicode escapes, replace with ?
                pos = pos + 4
                table.insert(parts, "?")
            else
                table.insert(parts, esc)
            end
            pos = pos + 1
        elseif c == "\"" then
            return table.concat(parts), pos + 1
        else
            table.insert(parts, c)
            pos = pos + 1
        end
    end
    return nil, "Unterminated string"
end

local function parseNumber(str, pos)
    local startPos = pos
    local c = string.sub(str, pos, pos)
    if c == "-" then
        pos = pos + 1
    end
    while pos <= string.len(str) do
        c = string.sub(str, pos, pos)
        if c == "." or c == "e" or c == "E" or c == "+" or c == "-" or (c >= "0" and c <= "9") then
            pos = pos + 1
        else
            break
        end
    end
    local numStr = string.sub(str, startPos, pos - 1)
    local num = tonumber(numStr)
    if num then
        return num, pos
    else
        return nil, "Invalid number at position " .. startPos
    end
end

local function parseObject(str, pos)
    -- pos should be at {
    pos = pos + 1
    local obj = {}
    pos = skipWhitespace(str, pos)
    if string.sub(str, pos, pos) == "}" then
        return obj, pos + 1
    end
    while pos <= string.len(str) do
        pos = skipWhitespace(str, pos)
        -- Parse key
        local key, err
        key, pos = parseString(str, pos)
        if not key then return nil, pos end -- pos is error msg
        pos = skipWhitespace(str, pos)
        -- Expect colon
        if string.sub(str, pos, pos) ~= ":" then
            return nil, "Expected ':' at position " .. pos
        end
        pos = pos + 1
        pos = skipWhitespace(str, pos)
        -- Parse value
        local val
        val, pos = parseValue(str, pos)
        if val == nil and type(pos) == "string" then return nil, pos end
        obj[key] = val
        pos = skipWhitespace(str, pos)
        local c = string.sub(str, pos, pos)
        if c == "}" then
            return obj, pos + 1
        elseif c == "," then
            pos = pos + 1
        else
            return nil, "Expected ',' or '}' at position " .. pos
        end
    end
    return nil, "Unterminated object"
end

local function parseArray(str, pos)
    -- pos should be at [
    pos = pos + 1
    local arr = {}
    pos = skipWhitespace(str, pos)
    if string.sub(str, pos, pos) == "]" then
        return arr, pos + 1
    end
    while pos <= string.len(str) do
        pos = skipWhitespace(str, pos)
        local val
        val, pos = parseValue(str, pos)
        if val == nil and type(pos) == "string" then return nil, pos end
        table.insert(arr, val)
        pos = skipWhitespace(str, pos)
        local c = string.sub(str, pos, pos)
        if c == "]" then
            return arr, pos + 1
        elseif c == "," then
            pos = pos + 1
        else
            return nil, "Expected ',' or ']' at position " .. pos
        end
    end
    return nil, "Unterminated array"
end

local function parseLiteral(str, pos)
    if string.sub(str, pos, pos + 3) == "true" then
        return true, pos + 4
    elseif string.sub(str, pos, pos + 4) == "false" then
        return false, pos + 5
    elseif string.sub(str, pos, pos + 3) == "null" then
        return nil, pos + 4
    else
        return nil, "Unexpected token at position " .. pos
    end
end

parseValue = function(str, pos)
    pos = skipWhitespace(str, pos)
    if pos > string.len(str) then
        return nil, "Unexpected end of input"
    end
    local c = string.sub(str, pos, pos)
    if c == "\"" then
        return parseString(str, pos)
    elseif c == "{" then
        return parseObject(str, pos)
    elseif c == "[" then
        return parseArray(str, pos)
    elseif c == "-" or (c >= "0" and c <= "9") then
        return parseNumber(str, pos)
    else
        return parseLiteral(str, pos)
    end
end

function RaidMakerCEParseJSON(jsonString)
    if not jsonString or jsonString == "" then
        return nil, "Empty input"
    end
    local val, pos = parseValue(jsonString, 1)
    if val == nil and type(pos) == "string" then
        return nil, pos
    end
    return val
end
