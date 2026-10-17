local BCC = require('libs/better-commands-lib')

local function sap_available()
    return (_G.StrikeAPose ~= nil) and (_G.strike_a_pos_loaded == true)
end

--- Resolve a pose identifier (numeric ID or exact name) into a pose ID.
--- @param arg string|nil
--- @return integer|nil pose_id
--- @return string|nil err
local function resolve_pose(arg)
    if arg == nil or arg == "" then
        return nil, "Pose ID or name is required."
    end

    local num = tonumber(arg)
    if num ~= nil then
        local pose = _G.StrikeAPose:get_pose(num)
        if pose == nil then
            return nil, 'Pose with ID ' .. num .. ' does not exist.'
        end
        return num
    end

    for id, pose in ipairs(_G.StrikeAPose:list_poses()) do
        if pose.name == arg then
            return id
        end
    end

    return nil, 'Pose with name "' .. arg .. '" not found.'
end

BCC.hook_better_chat_command('sap-list',
    'Display a list of available poses and their IDs.',
    {},
    function()
        if not sap_available() then
            BCC.chat_create_error('Strike-A-Pose system not found.')
            return
        end

        local poses = _G.StrikeAPose:list_poses()
        if #poses == 0 then
            BCC.chat_create_warning('No poses registered yet.')
            return
        end

        for id, pose in ipairs(poses) do
            djui_chat_message_create('[' .. id .. '] - ' .. pose.name)
        end
    end
)

BCC.hook_better_chat_command('sap',
    'Play a pose by ID or name. Example: /sap 5  |  /sap, Walking',
    {
        { "pose", BCC.CMD_ARG_STRING_REST },
    },
    function(args)
        if not sap_available() then
            BCC.chat_create_error('Strike-A-Pose system not found.')
            return
        end

        local pose_id, err = resolve_pose(args.pose)
        if not pose_id then
            BCC.chat_create_error(err)
            return
        end

        _G.StrikeAPose:apply_pose(gMarioStates[0], pose_id)
    end
)

BCC.hook_better_chat_command('sap-slot',
    'Bind a pose to a quick slot. Example: /sap-slot 0,5  |  /sap-slot 0, Walking',
    {
        { "slot", BCC.CMD_ARG_INTEGER, min = MIN_SLOT_IDX, max = MAX_SLOT_IDX },
        { "pose", BCC.CMD_ARG_STRING_REST },
    },
    function(args)
        if not sap_available() then
            BCC.chat_create_error('Strike-A-Pose system not found.')
            return
        end

        local pose_id, err = resolve_pose(args.pose)
        if not pose_id then
            BCC.chat_create_error(err)
            return
        end

        local success = SavePoseSlot(args.slot, pose_id)
        if success then
            BCC.chat_create_success('Pose slot ' .. args.slot ..
                ' set to pose ID ' .. pose_id .. '.')
        else
            BCC.chat_create_error('Failed to save pose slot ' ..
                args.slot .. '. Check console logs.')
        end
    end
)

BCC.hook_better_chat_command('sap-hidecurrent',
    'Toggle "Current Pose" text on HUD.',
    {},
    function()
        SAP_HideCurrentText = not (SAP_HideCurrentText or false)
        mod_storage_save_bool("sap_hide_current_text", SAP_HideCurrentText)
        BCC.chat_create_success("Current pose text " ..
            (SAP_HideCurrentText and "hidden" or "shown"))
    end
)