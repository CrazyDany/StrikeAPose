local pose_id = _G.StrikeAPose:register_new_pose(_G.SAPPose.new(
    'Walking', 'SAP_NONE', 
    ACT_GROUP_MOVING | ACT_FLAG_MOVING | ACT_FLAG_CUSTOM_ACTION))

local pose = _G.StrikeAPose:get_pose(pose_id)

local CLONE_START_TIMER   = 30
local CLONE_EMERGE_FRAMES = 60
local CLONE_FRONT_OFFSET  = 100
local CLONE_BACK_OFFSET   = -100
local CLONE_BELOW_Y       = -300

--- @param m MarioState
--- @param lz number
--- @param yOff number
--- @return table
local function clone_world_pos(m, lz, yOff)
    local cosA, sinA = coss(m.faceAngle.y), sins(m.faceAngle.y)
    return {
        x = m.pos.x - lz * sinA,
        y = m.pos.y + yOff,
        z = m.pos.z + lz * cosA,
    }
end

pose.hook_start = function(m, is_owner)
    if not _G.sp_pose_builder.mario_handle_ground_step(m) then return end
    _G.sp_pose_builder.mario_update_velocity(m, {
        direction = "forward", speed = 13, lerp = 1, brake = false,
    })
end

pose.hook_every_tick = function(m, is_owner)
    local pb = _G.sp_pose_builder

    set_mario_animation(m, MARIO_ANIM_START_TIPTOE)

    if not pb.mario_handle_ground_step(m) then return end
    pb.mario_update_face(m, { target = "stick", lerp = 0.2 })
    pb.mario_update_velocity(m, {
        direction = "stick", speed = 13, lerp = 0.2, brake = false,
    })

    if m.actionTimer > CLONE_START_TIMER then
        local t = math.min(1, (m.actionTimer - CLONE_START_TIMER) / CLONE_EMERGE_FRAMES)
        local smooth = t * t * (3 - 2 * t)

        local yOff  = CLONE_BELOW_Y * (1 - smooth)
        local alpha = math.floor(255 * smooth)

        local snapFront = pb.mario_capture_snapshot(m)
        snapFront.pos = clone_world_pos(m, CLONE_FRONT_OFFSET, yOff)
        pb.spawn_snapshot_mesh(snapFront, { opacity = alpha, lifetime = 1 })

        local snapBack = pb.mario_capture_snapshot(m)
        snapBack.pos = clone_world_pos(m, CLONE_BACK_OFFSET, yOff)
        pb.spawn_snapshot_mesh(snapBack, { opacity = alpha, lifetime = 1 })
    end
end