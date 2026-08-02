hook_chat_command('sap-list', '- Display a list of available poses and their IDs.',
    function (msg)
        if (_G.StrikeAPose == nil) or (_G.strike_a_pos_loaded ~= true) then
            djui_chat_message_create('StrikeAPose System not found.')
            return true
        end

        for _, pose in ipairs(_G.StrikeAPose:list_poses()) do
            djui_chat_message_create('[' .. _ .. ']' .. ' - ' .. pose.name)
        end

        return true
    end
)

hook_chat_command('sap', 'Play the pose at its ID [EX: /sap 1]',
    function (msg)
        if (_G.StrikeAPose == nil) or (_G.strike_a_pos_loaded ~= true) then
            djui_chat_message_create('Strike-A-Pose System not found.')
            return true
        end

        local command_idx = tonumber(msg)

        local pose = _G.StrikeAPose:get_pose(command_idx)

        if pose == nil then
            djui_chat_message_create('Invaild pose index.')
            return true
        end
        
        _G.StrikeAPose:apply_pose(gMarioStates[0], command_idx)

        return true
    end
)

hook_chat_command('sap-slot', 'Set a pose ID to a certain slot [EX: /sap-slot 1 0]',
    function(msg)
        local args = {}
        for arg in string.gmatch(msg, '%S+') do
            table.insert(args, arg)
        end
        
        if #args < 2 then
            djui_chat_message_create('Usage: /sap-slot <slot_idx> <pose_idx> (e.g., /sap-slot 0 5)')
            return true
        end
        
        local slot_idx = tonumber(args[1])
        local pose_idx = tonumber(args[2])
        
        if not slot_idx or not pose_idx then
            djui_chat_message_create('Invalid number format. Please use integers.')
            return true
        end
        
        if slot_idx < MIN_SLOT_IDX or slot_idx > MAX_SLOT_IDX then
            djui_chat_message_create('Slot index must be between ' .. MIN_SLOT_IDX .. ' and ' .. MAX_SLOT_IDX .. '.')
            return true
        end
        
        local success = SavePoseSlot(slot_idx, pose_idx)
        if success then
            djui_chat_message_create('Pose slot ' .. slot_idx .. ' set to pose ' .. pose_idx .. ' successfully.')
        else
            djui_chat_message_create('Failed to save pose slot ' .. slot_idx .. '. Check console logs.')
        end

        return true
    end
)