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

hook_chat_command('sap', 'Play a pose by ID or name [EX: /sap 1 or /sap "dance"]',
    function (msg)
        if (_G.StrikeAPose == nil) or (_G.strike_a_pos_loaded ~= true) then
            djui_chat_message_create('Strike-A-Pose System not found.')
            return true
        end

        local arg = msg
        if arg == nil or arg == "" then
            djui_chat_message_create('Usage: /sap <pose_id_or_name> (e.g., /sap 5 or /sap "dance")')
            return true
        end

        local pose_id = nil
        local num = tonumber(arg)
        if num ~= nil then
            local pose = _G.StrikeAPose:get_pose(num)
            if pose == nil then
                djui_chat_message_create('Pose with ID ' .. num .. ' does not exist.')
                return true
            end
            pose_id = num
        else
            local found = nil
            for id, pose in ipairs(_G.StrikeAPose:list_poses()) do
                if pose.name == arg then
                    found = id
                    break
                end
            end
            if found == nil then
                djui_chat_message_create('Pose with name "' .. arg .. '" not found.')
                return true
            end
            pose_id = found
        end

        _G.StrikeAPose:apply_pose(gMarioStates[0], pose_id)
        return true
    end
)

hook_chat_command('sap-slot', 'Set a pose to a certain slot by ID or name [EX: /sap-slot 0 5 or /sap-slot 0 "pose_name"]',
    function(msg)
        local args = {}
        for arg in string.gmatch(msg, '%S+') do
            table.insert(args, arg)
        end
        
        if #args < 2 then
            djui_chat_message_create('Usage: /sap-slot <slot_idx> <pose_id_or_name> (e.g., /sap-slot 0 5 or /sap-slot 0 "dance")')
            return true
        end
        
        local slot_idx = tonumber(args[1])
        if not slot_idx then
            djui_chat_message_create('Invalid slot index. Must be a number.')
            return true
        end
        
        if slot_idx < MIN_SLOT_IDX or slot_idx > MAX_SLOT_IDX then
            djui_chat_message_create('Slot index must be between ' .. MIN_SLOT_IDX .. ' and ' .. MAX_SLOT_IDX .. '.')
            return true
        end
        
        local pose_arg = args[2]
        local pose_id = nil
        
        local num = tonumber(pose_arg)
        if num ~= nil then
            local pose = _G.StrikeAPose:get_pose(num)
            if pose == nil then
                djui_chat_message_create('Pose with ID ' .. num .. ' does not exist.')
                return true
            end
            pose_id = num
        else
            local found = nil
            for id, pose in ipairs(_G.StrikeAPose:list_poses()) do
                if pose.name == pose_arg then
                    found = id
                    break
                end
            end
            if found == nil then
                djui_chat_message_create('Pose with name "' .. pose_arg .. '" not found.')
                return true
            end
            pose_id = found
        end
        
        local success = SavePoseSlot(slot_idx, pose_id)
        if success then
            djui_chat_message_create('Pose slot ' .. slot_idx .. ' set to pose ID ' .. pose_id .. ' successfully.')
        else
            djui_chat_message_create('Failed to save pose slot ' .. slot_idx .. '. Check console logs.')
        end

        return true
    end
)