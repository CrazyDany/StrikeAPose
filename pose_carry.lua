local sap_pose_carry_id = _G.StrikeAPose:register_new_pose(_G.SAPPose.new(
    'Carry',
    'SAP_NONE',
    ACT_GROUP_STATIONARY | ACT_FLAG_STATIONARY | ACT_FLAG_INTANGIBLE | ACT_FLAG_INVULNERABLE,
    2
))

--- @type SAPPose
local sap_pose_carry = _G.StrikeAPose:get_pose(sap_pose_carry_id)

local WALK_DELAY_TICKS = 40
local WALK_SPEED = 4
local FACE_LERP = 0.075
local VEL_LERP = 0.1
local DEAD_ZONE = 0.1

local carry_timer = {}

sap_pose_carry.hook_every_tick = function(m, is_owner, ctx)
    local pb = _G.sp_pose_builder

    if not ctx then return end

    if ctx.is_leader then
        if ctx.count == 1 then
            carry_timer[m.playerIndex] = 0
            set_mario_animation(m, MARIO_ANIM_GRAB_HEAVY_OBJECT)
            set_anim_to_frame(m, 3)
            return
        end

        carry_timer[m.playerIndex] = (carry_timer[m.playerIndex] or 0) + 1

        if carry_timer[m.playerIndex] > WALK_DELAY_TICKS then
            if pb.mario_handle_ground_step(m) then
                pb.mario_update_face(m, {
                    target = "stick",
                    lerp = FACE_LERP,
                    deadZone = DEAD_ZONE,
                })
                pb.mario_update_velocity(m, {
                    direction = "stick",
                    speed = WALK_SPEED,
                    lerp = VEL_LERP,
                    brake = true,
                    deadZone = DEAD_ZONE,
                })

                if (m.controller.stickX == 0) and (m.controller.stickY == 0) then
                    mario_set_forward_vel(m, 0)
                    set_mario_animation(m, MARIO_ANIM_GRAB_HEAVY_OBJECT)
                    set_anim_to_frame(m, 40)
                else
                    local ai = m.marioObj.header.gfx.animInfo
                    if ai.animID ~= MARIO_ANIM_WALK_WITH_HEAVY_OBJ then
                        set_mario_animation(m, MARIO_ANIM_WALK_WITH_HEAVY_OBJ)
                    end
                end
            end
        else
            local ai = m.marioObj.header.gfx.animInfo
            if ai.animID ~= MARIO_ANIM_GRAB_HEAVY_OBJECT then
                set_mario_animation(m, MARIO_ANIM_GRAB_HEAVY_OBJECT)
                set_anim_to_frame(m, 3)
            end
        end

    elseif ctx.slot_index == 1 then
        smlua_anim_util_set_animation(m.marioObj, 'SAP_MARIO_ANIM_DEATH_POSE')
        m.marioBodyState.eyeState = MARIO_EYES_DEAD

        local leader = _G.StrikeAPose:get_session_mario(ctx.session_id, 0)
        if leader then
            pb.mario_attach_to(m, leader, {
                anchor = "left_hand",
                yaw_offset = 0x8000,
            })
        end
    end
end