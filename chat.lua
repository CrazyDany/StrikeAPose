hook_chat_command('sap-list', 'penis',
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

hook_chat_command('sap', 'pose_idx | integer',
    function (msg)
        if (_G.StrikeAPose == nil) or (_G.strike_a_pos_loaded ~= true) then
            djui_chat_message_create('StrikeAPose System not found.')
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