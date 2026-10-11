local pose_id = _G.StrikeAPose:register_new_pose(_G.SAPPose.new(
    'Walking', 'SAP_NONE', 
    ACT_GROUP_MOVING | ACT_FLAG_MOVING | ACT_FLAG_CUSTOM_ACTION))

local pose = _G.StrikeAPose:get_pose(pose_id)

pose.hook_start = function(m, is_owner)
    -- if not is_owner then return end
    if not _G.sp_pose_builder.mario_handle_ground_step(m) then return end
    _G.sp_pose_builder.mario_update_velocity(m, {
        direction = "forward", speed = 13, lerp = 1, brake = false,
    })
end

pose.hook_every_tick = function(m, is_owner)
    -- визуал — на всех клиентах
    set_mario_animation(m, MARIO_ANIM_START_TIPTOE)

    -- if not is_owner then return end
    if not _G.sp_pose_builder.mario_handle_ground_step(m) then return end
    _G.sp_pose_builder.mario_update_face(m,  { target = "stick", lerp = 0.2 })
    _G.sp_pose_builder.mario_update_velocity(m, {
        direction = "stick", speed = 13, lerp = 0.2, brake = false,
    })
end