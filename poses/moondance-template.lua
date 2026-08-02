if (_G.StrikeAPose == nil) or (_G.strike_a_pos_loaded ~= true) then
    log_to_console('somehting went wrong...')
    return 0
end

local moondance_pose = _G.SAPPose.new('Moondance\nTemplate', 'MOONWALKER_DANCE', ACT_FLAG_MOVING)
local moondance_pose_id = _G.StrikeAPose:register_new_pose(moondance_pose)