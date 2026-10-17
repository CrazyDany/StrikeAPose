--- BetterChatCommands API

---@alias CommandArgTypes integer
--- | `CMD_ARG_BOOLEAN`
--- | `CMD_ARG_INTEGER`
--- | `CMD_ARG_NUMBER`
--- | `CMD_ARG_STRING`
--- | `CMD_ARG_PLAYER`
--- | `CMD_ARG_DURATION`
--- | `CMD_ARG_COLOR`
--- | `CMD_ARG_STRING_REST`
--- | `CMD_ARG_PLAYER_LIST`

--- Describes a single command argument (array form).
--- @class CommandArgEntry
--- @field [1] string         Argument name as it appears in usage / args table.
--- @field [2] CommandArgTypes Argument type constant.
--- @field optional? boolean  If true, argument may be omitted or replaced with "...".
--- @field default? any       Value substituted when the argument is skipped.
--- @field min? number        Inclusive minimum for numeric types.
--- @field max? number        Inclusive maximum for numeric types.
--- @field choices? string[]  Allowed values (case-insensitive); returned normalized.
--- @field selectors? boolean Enable @s/@p/@r selectors for player/players types.

--- Map form of arguments. Order is not guaranteed; sorted by name internally.
--- @alias CommandArgsMap table<string, CommandArgTypes>

--- Either an ordered array of CommandArgEntry or an unordered map.
--- @alias CommandArgs CommandArgsMap|CommandArgEntry[]

--- Parsed color value, components in 0..255.
--- @class ColorValue
--- @field r integer Red component.
--- @field g integer Green component.
--- @field b integer Blue component.
--- @field hex string Normalized hex string, e.g. "#ff0000".

--- Options controlling command registration.
--- @class CommandOptions
--- @field permission? "anyone"|"user"|"moderator"|"mod"|"host"|"server"|"admin"

--- Public API surface returned by this module.
--- @class BetterCommandsAPI
--- @field CMD_ARG_BOOLEAN integer
--- @field CMD_ARG_INTEGER integer
--- @field CMD_ARG_NUMBER integer
--- @field CMD_ARG_STRING integer
--- @field CMD_ARG_PLAYER integer
--- @field CMD_ARG_DURATION integer
--- @field CMD_ARG_COLOR integer
--- @field CMD_ARG_STRING_REST integer
--- @field CMD_ARG_PLAYER_LIST integer
--- @field chat_create_error fun(msg: string)
--- @field chat_create_success fun(msg: string)
--- @field chat_create_warning fun(msg: string)
--- @field chat_create_log fun(msg: string)
--- @field hook_better_chat_command fun(command: string, description: string, args: CommandArgs, func: fun(args: table<string, any>), options?: CommandOptions)

--- Color constants
local COLOR_SUCCESS = "\\#a0ffa0\\"
local COLOR_WARNING = "\\#fff982\\"
local COLOR_ERROR   = "\\#ffa0a0\\"
local COLOR_LOG     = "\\#91a9b3\\"

---@type BetterCommandsAPI
local M = {}

M.CMD_ARG_BOOLEAN     = 0
M.CMD_ARG_INTEGER     = 1
M.CMD_ARG_NUMBER      = 2
M.CMD_ARG_STRING      = 3
M.CMD_ARG_PLAYER      = 4
M.CMD_ARG_DURATION    = 5
M.CMD_ARG_COLOR       = 6
M.CMD_ARG_STRING_REST = 7
M.CMD_ARG_PLAYER_LIST = 8

-- Local aliases for internal use (faster and immune to later _G tampering).
local CMD_ARG_BOOLEAN     = M.CMD_ARG_BOOLEAN
local CMD_ARG_INTEGER     = M.CMD_ARG_INTEGER
local CMD_ARG_NUMBER      = M.CMD_ARG_NUMBER
local CMD_ARG_STRING      = M.CMD_ARG_STRING
local CMD_ARG_PLAYER      = M.CMD_ARG_PLAYER
local CMD_ARG_DURATION    = M.CMD_ARG_DURATION
local CMD_ARG_COLOR       = M.CMD_ARG_COLOR
local CMD_ARG_STRING_REST = M.CMD_ARG_STRING_REST
local CMD_ARG_PLAYER_LIST = M.CMD_ARG_PLAYER_LIST

--- Returns a human-readable name for an argument type constant.
--- @param arg_type CommandArgTypes
--- @return string
local function cmd_arg_type_name(arg_type)
    local names = {
        [CMD_ARG_BOOLEAN]     = 'bool',
        [CMD_ARG_INTEGER]     = 'int',
        [CMD_ARG_NUMBER]      = 'number',
        [CMD_ARG_STRING]      = 'string',
        [CMD_ARG_PLAYER]      = 'player',
        [CMD_ARG_DURATION]    = 'duration',
        [CMD_ARG_COLOR]       = 'color',
        [CMD_ARG_STRING_REST] = 'text...',
        [CMD_ARG_PLAYER_LIST] = 'players',
    }
    return names[arg_type] or 'undefined'
end

--- Prints a red error message to chat and plays the error sound.
--- @param msg string
function M.chat_create_error(msg)
    djui_chat_message_create(COLOR_ERROR .. msg)
    play_sound(SOUND_MENU_CAMERA_BUZZ, gGlobalSoundSource)
end

--- Prints a green success message to chat and plays the warp sound.
--- @param msg string
function M.chat_create_success(msg)
    djui_chat_message_create(COLOR_SUCCESS .. msg)
    play_sound(SOUND_MENU_MARIO_CASTLE_WARP2, gGlobalSoundSource)
end

--- Prints an orange warning message to chat (no sound).
--- @param msg string
function M.chat_create_warning(msg)
    djui_chat_message_create(COLOR_WARNING .. msg)
end

--- Prints a grey informational message to chat (no sound).
--- @param msg string
function M.chat_create_log(msg)
    djui_chat_message_create(COLOR_LOG .. msg)
end

local chat_create_error   = M.chat_create_error
local chat_create_success = M.chat_create_success
local chat_create_warning = M.chat_create_warning
local chat_create_log     = M.chat_create_log

--- Logs a red error message to the developer console.
--- @param msg string
local function log_error_console(msg)
    log_to_console(COLOR_ERROR .. "[BetterCommands] " .. msg)
end

--- Logs a yellow warning message to the developer console.
--- @param msg string
local function log_warn_console(msg)
    log_to_console(COLOR_WARNING .. "[BetterCommands] " .. msg)
end

--- Numeric hierarchy for permission levels. Higher value = more privileged.
--- @type table<string, integer>
local PERMISSION_LEVELS = {
    anyone = 0, user = 0,
    moderator = 1, mod = 1,
    host = 2, server = 2, admin = 2,
}

--- Returns the permission level of the local player.
--- 2 = host/server, 1 = moderator, 0 = regular user.
--- @return integer
local function current_permission_level()
    if network_is_server() then return 2 end
    if network_is_moderator() then return 1 end
    return 0
end

--- Checks if the local player satisfies the required permission level.
--- Unknown permission names are treated as "anyone" and always pass.
--- @param required string|nil
--- @return boolean
local function check_permission(required)
    local req = PERMISSION_LEVELS[required or "anyone"]
    if req == nil then return true end
    return current_permission_level() >= req
end

--- Validates and normalizes a raw argument entry table.
--- @param pair table Raw entry in { name, type, ... } form.
--- @return table|nil norm Normalized entry, or nil on error.
--- @return string|nil err Error description when norm is nil.
local function normalize_arg_entry(pair)
    if type(pair) ~= "table" then
        return nil, "each arg entry must be a table"
    end
    local name = pair[1]
    local typ = pair[2]
    if type(name) ~= "string" or name == "" then
        return nil, "arg name must be a non-empty string"
    end
    if typ == nil then
        return nil, "arg '" .. name .. "' is missing a type"
    end
    return {
        name = name,
        type = typ,
        optional = pair.optional == true,
        default = pair.default,
        min = pair.min,
        max = pair.max,
        choices = pair.choices,
        selectors = pair.selectors == true,
    }
end

--- Frames-per-unit table. SM64 runs at 30 FPS internally.
--- @type table<string, number>
local DURATION_UNIT_FRAMES = {
    ms = 30 / 1000,
    s  = 30,
    m  = 30 * 60,
    h  = 30 * 60 * 60,
    d  = 30 * 60 * 60 * 24,
}

--- Parses a duration string into frames.
--- Accepts plain numbers (interpreted as seconds) or composed units: 5s, 500ms, 2m, 1h30m.
--- @param token string
--- @return integer|nil frames Frames if parsed successfully.
local function parse_duration(token)
    local lower = token:lower()
    if lower:match("^%d+%.?%d*$") then
        return math.floor(tonumber(lower) * 30 + 0.5)
    end
    local total = 0
    local pos = 1
    local any = false
    while pos <= #lower do
        local num_str, unit = lower:match("^(%d+%.?%d*)([a-z]+)", pos)
        if not num_str then return nil end
        local num = tonumber(num_str)
        if not num then return nil end
        local mult = DURATION_UNIT_FRAMES[unit]
        if not mult then return nil end
        total = total + num * mult
        pos = pos + #num_str + #unit
        any = true
    end
    if not any then return nil end
    return math.floor(total + 0.5)
end

--- Named colors accepted by the color parser.
--- @type table<string, string>
local NAMED_COLORS = {
    red = "#ff0000", green = "#00ff00", blue = "#0000ff",
    yellow = "#ffff00", cyan = "#00ffff", magenta = "#ff00ff",
    white = "#ffffff", black = "#000000", orange = "#ff8800",
    purple = "#8800ff", gray = "#808080", grey = "#808080",
    pink = "#ff88cc",
}

--- Parses a color token into a ColorValue.
--- Accepts #rrggbb, rrggbb, or a named color.
--- @param token string
--- @return ColorValue|nil
local function parse_color(token)
    local lower = token:lower()
    local hex = NAMED_COLORS[lower]
    if not hex then
        local stripped = lower:gsub("^#", "")
        if stripped:match("^%x%x%x%x%x%x$") then
            hex = "#" .. stripped
        else
            return nil
        end
    end
    return {
        r = tonumber(hex:sub(2, 3), 16),
        g = tonumber(hex:sub(4, 5), 16),
        b = tonumber(hex:sub(6, 7), 16),
        hex = hex,
    }
end

--- Resolves a single player from an index, name, or selector.
--- @param token string Player index, name, or @s/@p/@r.
--- @param allow_selectors boolean Whether selector tokens are honored.
--- @return MarioState|nil player
--- @return string|nil err
local function find_single_player(token, allow_selectors)
    local lower = token:lower()
    if allow_selectors then
        if lower == "@s" then
            if not gMarioStates[0] then return nil, "local player not available" end
            return gMarioStates[0]
        elseif lower == "@r" then
            local list = {}
            for j = 0, MAX_PLAYERS - 1 do
                if gNetworkPlayers[j] and gNetworkPlayers[j].connected and gMarioStates[j] then
                    table.insert(list, j)
                end
            end
            if #list == 0 then return nil, "no players online" end
            return gMarioStates[list[math.random(#list)]]
        elseif lower == "@p" then
            local me = gMarioStates[0]
            if not me or not me.pos then return nil, "'@p' unavailable" end
            local my_pos = me.pos
            local best_j, best_dist = nil, math.huge
            for j = 1, MAX_PLAYERS - 1 do
                if gNetworkPlayers[j] and gNetworkPlayers[j].connected and gMarioStates[j] then
                    local p = gMarioStates[j].pos
                    if p then
                        local dx, dy, dz = p.x - my_pos.x, p.y - my_pos.y, p.z - my_pos.z
                        local d = dx * dx + dy * dy + dz * dz
                        if d < best_dist then
                            best_dist = d
                            best_j = j
                        end
                    end
                end
            end
            if not best_j then return nil, "no other players online" end
            return gMarioStates[best_j]
        end
    end

    local index = tonumber(token)
    if index and math.floor(index) == index then
        if index >= 0 and index < MAX_PLAYERS and gMarioStates[index] and gNetworkPlayers[index].connected then
            return gMarioStates[index]
        end
        return nil, "player not found (by index or name)"
    end

    for j = 0, MAX_PLAYERS - 1 do
        if gNetworkPlayers[j] and gNetworkPlayers[j].name and gNetworkPlayers[j].connected then
            if string.lower(gNetworkPlayers[j].name) == lower then
                if gMarioStates[j] then
                    return gMarioStates[j]
                end
            end
        end
    end
    return nil, "player not found (by index or name)"
end

--- Parses a single-player token. Rejects @a (use CMD_ARG_PLAYER_LIST for that).
--- @param token string
--- @param arg_info table Normalized arg entry.
--- @return MarioState|nil
--- @return string|nil
local function parse_player(token, arg_info)
    if token:lower() == "@a" then
        return nil, "'@a' is not valid for player (use players / CMD_ARG_PLAYER_LIST)"
    end
    return find_single_player(token, arg_info.selectors)
end

--- Parses a player-list token. @a returns all connected players.
--- @param token string
--- @param arg_info table Normalized arg entry.
--- @return MarioState[]|nil
--- @return string|nil
local function parse_player_list(token, arg_info)
    if token:lower() == "@a" then
        local list = {}
        for j = 0, MAX_PLAYERS - 1 do
            if gNetworkPlayers[j] and gNetworkPlayers[j].connected and gMarioStates[j] then
                table.insert(list, gMarioStates[j])
            end
        end
        if #list == 0 then return nil, "no players online" end
        return list
    end
    local p, err = find_single_player(token, arg_info.selectors)
    if err then return nil, err end
    return { p }
end

--- Formats a numeric range for error messages.
--- @param min number|nil
--- @param max number|nil
--- @return string
local function range_str(min, max)
    return "[" .. tostring(min or "-inf") .. ", " .. tostring(max or "inf") .. "]"
end

--- Parses a token according to the argument type and constraints.
--- @param token string
--- @param arg_info table Normalized arg entry.
--- @return any value Parsed value on success.
--- @return string|nil err Error description on failure.
local function parse_arg_value(token, arg_info)
    if arg_info.choices then
        local lower = token:lower()
        for _, choice in ipairs(arg_info.choices) do
            if choice:lower() == lower then return choice end
        end
        return nil, "expected one of: " .. table.concat(arg_info.choices, ", ")
    end

    local typ = arg_info.type

    if typ == CMD_ARG_BOOLEAN then
        local lower = token:lower()
        if lower == "true"  or lower == "1" then return true  end
        if lower == "false" or lower == "0" then return false end
        return nil, "expected bool (true/false, 1/0)"
    elseif typ == CMD_ARG_INTEGER then
        if not token:match("^%-?%d+$") then return nil, "expected int" end
        local num = tonumber(token)
        if arg_info.min and num < arg_info.min then
            return nil, "value out of range " .. range_str(arg_info.min, arg_info.max)
        end
        if arg_info.max and num > arg_info.max then
            return nil, "value out of range " .. range_str(arg_info.min, arg_info.max)
        end
        return num
    elseif typ == CMD_ARG_NUMBER then
        local num = tonumber(token)
        if not num then return nil, "expected number" end
        if arg_info.min and num < arg_info.min then
            return nil, "value out of range " .. range_str(arg_info.min, arg_info.max)
        end
        if arg_info.max and num > arg_info.max then
            return nil, "value out of range " .. range_str(arg_info.min, arg_info.max)
        end
        return num
    elseif typ == CMD_ARG_STRING then
        return token
    elseif typ == CMD_ARG_PLAYER then
        return parse_player(token, arg_info)
    elseif typ == CMD_ARG_PLAYER_LIST then
        return parse_player_list(token, arg_info)
    elseif typ == CMD_ARG_DURATION then
        local frames = parse_duration(token)
        if not frames then return nil, "expected duration (e.g. 5s, 500ms, 2m, 1h30m)" end
        return frames
    elseif typ == CMD_ARG_COLOR then
        local color = parse_color(token)
        if not color then return nil, "expected color (#rrggbb or a name)" end
        return color
    end
    return nil, "unknown argument type"
end

--- Formats a single value for logging. Tables become <table:N>, MarioState
--- values become <player#N>, strings are quoted.
--- @param v any
--- @return string
local function dump_value(v)
    local t = type(v)
    if t == "nil" then return "nil" end
    if t == "boolean" or t == "number" then return tostring(v) end
    if t == "string" then return string.format("%q", v) end
    if t == "table" then
        if v.playerIndex ~= nil then
            return "<player#" .. tostring(v.playerIndex) .. ">"
        end
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return "<table:" .. n .. ">"
    end
    return "<" .. t .. ">"
end

--- Formats an arguments table as a sorted "k=v, k=v" string.
--- @param result table
--- @return string
local function dump_args(result)
    local parts = {}
    for k, v in pairs(result) do
        parts[#parts + 1] = tostring(k) .. "=" .. dump_value(v)
    end
    table.sort(parts)
    return table.concat(parts, ", ")
end

--- Set of command names registered through this API.
--- @type table<string, boolean>
local registered_commands = {}

--- Registers a chat command with typed arguments and optional permission gating.
---
--- On invalid arguments the command prints an error plus a usage line built
--- from the declared signature. Errors raised inside `func` are caught and
--- logged with a dump of parsed arguments.
---
--- @param command string Command name without leading slash.
--- @param description string Human-readable description shown in help.
--- @param args CommandArgs Argument definitions (array form recommended).
--- @param func fun(args: table<string, any>) Command body.
--- @param options? CommandOptions Optional registration flags (permission).
function M.hook_better_chat_command(command, description, args, func, options)
    if type(command) ~= "string" or command == "" then
        chat_create_error("hook_better_chat_command: command must be a non-empty string")
        return
    end
    if type(description) ~= "string" then description = "" end
    if args == nil then args = {}
    elseif type(args) ~= "table" then
        chat_create_error("hook_better_chat_command: args must be a table")
        return
    end
    if type(func) ~= "function" then
        chat_create_error("hook_better_chat_command: func must be a function")
        return
    end
    options = options or {}
    local permission = options.permission or "anyone"

    if registered_commands[command] then
        log_warn_console("Warning: command '" .. command .. "' already registered through this API")
    end
    registered_commands[command] = true

    -- Normalize to an ordered array.
    local arg_list = {}
    if args[1] ~= nil then
        for i, pair in ipairs(args) do
            local norm, err = normalize_arg_entry(pair)
            if not norm then
                chat_create_error("hook_better_chat_command: " .. err)
                return
            end
            arg_list[i] = norm
        end
    else
        local tmp = {}
        for name, typ in pairs(args) do
            table.insert(tmp, { name = name, type = typ })
        end
        table.sort(tmp, function(a, b) return a.name < b.name end)
        for _, p in ipairs(tmp) do
            arg_list[#arg_list + 1] = { name = p.name, type = p.type, optional = false }
        end
    end

    -- Validate STRING_REST placement.
    local rest_pos = nil
    for i, arg in ipairs(arg_list) do
        if arg.type == CMD_ARG_STRING_REST then
            if rest_pos then
                chat_create_error("hook_better_chat_command: only one CMD_ARG_STRING_REST allowed")
                return
            end
            rest_pos = i
            if i ~= #arg_list then
                chat_create_error("hook_better_chat_command: CMD_ARG_STRING_REST must be the last argument")
                return
            end
        end
    end

    -- Validate optional/mandatory ordering and count mandatory args.
    local seen_optional = false
    local mandatory_count = 0
    local pre_rest_mandatory = 0
    for i, arg in ipairs(arg_list) do
        if arg.optional then
            seen_optional = true
        else
            if seen_optional then
                chat_create_error("hook_better_chat_command: mandatory arg '" .. arg.name .. "' after an optional arg")
                return
            end
            mandatory_count = mandatory_count + 1
            if not rest_pos or i < rest_pos then
                pre_rest_mandatory = pre_rest_mandatory + 1
            end
        end
    end

    -- Build description and usage strings from the declared signature.
    local arg_parts = {}
    for _, arg in ipairs(arg_list) do
        local type_str = arg.choices and table.concat(arg.choices, "|") or cmd_arg_type_name(arg.type)
        table.insert(arg_parts, string.format("%s: %s", arg.name, type_str))
    end
    local args_str = table.concat(arg_parts, ", ")

    local full_desc
    if #arg_parts > 0 then
        full_desc = string.format(" - <%s> - %s", args_str, description)
    else
        full_desc = string.format(" - %s", description)
    end

    local usage = "Usage: /" .. command
    if #arg_list > 0 then
        local parts = {}
        for _, arg in ipairs(arg_list) do
            local type_str = arg.choices and table.concat(arg.choices, "|") or cmd_arg_type_name(arg.type)
            local inner = arg.name .. ": " .. type_str
            table.insert(parts, arg.optional and ("[" .. inner .. "]") or ("<" .. inner .. ">"))
        end
        usage = usage .. " " .. table.concat(parts, " ")
    end

    --- Emits an error plus the usage string.
    --- @param msg string
    local function fail(msg)
        chat_create_error(msg .. "\n" .. usage)
    end

    --- Chat command handler installed via hook_chat_command.
    --- @param msg string|nil Raw arguments portion of the chat message.
    --- @return boolean Always true to consume the message.
    local function process_command(msg)
        chat_create_log('/' .. command .. ' ' .. (msg or ''))

        if not check_permission(permission) then
            chat_create_error("Permission required: " .. permission)
            return true
        end

        if #arg_list == 0 then
            if msg and msg:match("%S") then
                fail("Command takes no arguments.")
                return true
            end
            local ok, err = pcall(func, {})
            if not ok then
                log_error_console("Error in '/" .. command .. "': " .. tostring(err))
                log_error_console("  args: (none)")
                chat_create_error("Command '/" .. command .. "' failed. See console.")
            end
            return true
        end

        local tokens = {}
        if msg and msg:match("%S") then
            for token in (msg .. ","):gmatch("([^,]*),") do
                table.insert(tokens, token)
            end
        end

        local min_required = rest_pos and pre_rest_mandatory or mandatory_count

        if #tokens < min_required then
            fail(string.format("Not enough arguments. Expected at least %d, got %d.", min_required, #tokens))
            return true
        end
        if not rest_pos and #tokens > #arg_list then
            fail(string.format("Too many arguments. Expected at most %d, got %d.", #arg_list, #tokens))
            return true
        end

        local result = {}
        for i, arg_info in ipairs(arg_list) do
            local name = arg_info.name

            if arg_info.type == CMD_ARG_STRING_REST then
                if i <= #tokens then
                    local parts = {}
                    for j = i, #tokens do
                        table.insert(parts, tokens[j])
                    end
                    local text = table.concat(parts, ",")
                    text = text:gsub("^%s+", "")
                    result[name] = text
                else
                    if arg_info.default ~= nil then
                        result[name] = arg_info.default
                    else
                        result[name] = ""
                    end
                end
            else
                local token = tokens[i]

                if token == nil then
                    if arg_info.default ~= nil then
                        result[name] = arg_info.default
                    end
                elseif token:match("^%s*%.%.%.%s*$") then
                    if arg_info.default ~= nil then
                        result[name] = arg_info.default
                    elseif not arg_info.optional then
                        fail(string.format("Argument '%s' is mandatory and cannot be skipped with '...'", name))
                        return true
                    end
                else
                    token = token:match("^%s*(.-)%s*$") or ""
                    local value, err = parse_arg_value(token, arg_info)
                    if err then
                        fail(string.format("Invalid argument '%s': %s (got '%s')", name, err, token))
                        return true
                    end
                    result[name] = value
                end
            end
        end

        local ok, err = pcall(func, result)
        if not ok then
            log_error_console("Error in '/" .. command .. "': " .. tostring(err))
            log_error_console("  args: " .. dump_args(result))
            chat_create_error("Command '/" .. command .. "' failed. See console.")
        end
        return true
    end

    hook_chat_command(command, full_desc, process_command)
end

hook_chat_command('bc-help', '- Show help for using BetterCommands',
    function(msg)
        djui_chat_message_create(
            COLOR_SUCCESS .. "BetterCommands Help\\#ffffff\\\n" ..
            "Args separated by \\#fff982\\commas (,)\\#ffffff\\\n" ..
            "Use \\#fff982\\...\\#ffffff\\ to skip an optional arg\n" ..
            "Types:\n" ..
            "  \\#fff982\\bool\\#ffffff\\ - true/false or 1/0\n" ..
            "  \\#fff982\\int\\#ffffff\\ - integer number\n" ..
            "  \\#fff982\\number\\#ffffff\\ - any number\n" ..
            "  \\#fff982\\string\\#ffffff\\ - text (no commas)\n" ..
            "  \\#fff982\\player\\#ffffff\\ - local index, name or selector"
        )
        djui_chat_message_create(
            "  \\#fff982\\players\\#ffffff\\ - single player or @a (list)\n" ..
            "  \\#fff982\\text...\\#ffffff\\ - rest of line (keeps commas)\n" ..
            "  \\#fff982\\duration\\#ffffff\\ - 5s, 500ms, 2m, 1h30m\n" ..
            "  \\#fff982\\color\\#ffffff\\ - #rrggbb or name\n" ..
            "Player selectors:\n" ..
            "  \\#fff982\\@s\\#ffffff\\ - yourself\n" ..
            "  \\#fff982\\@p\\#ffffff\\ - nearest player\n" ..
            "  \\#fff982\\@r\\#ffffff\\ - random player\n" ..
            "  \\#fff982\\@a\\#ffffff\\ - all players"
        )
        djui_chat_message_create(
            "Permissions:\n" ..
            "  \\#fff982\\anyone\\#ffffff\\ - no restriction\n" ..
            "  \\#fff982\\moderator\\#ffffff\\ - mod and host only\n" ..
            "  \\#fff982\\host\\#ffffff\\ - host only\n" ..
            "Invalid args show error"
        )
        return true
    end
)

--- @return BetterCommandsAPI
return M