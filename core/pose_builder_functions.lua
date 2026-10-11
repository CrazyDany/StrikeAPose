local BINARY_ANGLE_MAX = 65536
local ANGLE_TO_RAD = (2 * math.pi) / BINARY_ANGLE_MAX

local function binary_to_rad(angle) return angle * ANGLE_TO_RAD end
local function rad_to_binary(rad) return (rad / ANGLE_TO_RAD) % BINARY_ANGLE_MAX end

function mario_get_camera_yaw(m)
    return m.area.camera.yaw + 0x8000
end

function mario_get_stick_world_direction(m, camYaw, deadZone)
    deadZone = deadZone or 0.1
    local sx, sy = -m.controller.stickX, m.controller.stickY
    local mag = math.sqrt(sx * sx + sy * sy)
    if mag < deadZone then return { x = 0, z = 0, mag = 0 } end
    local rad = binary_to_rad(camYaw)
    local x = sy * math.sin(rad) + sx * math.cos(rad)
    local z = sy * math.cos(rad) - sx * math.sin(rad)
    return { x = x, z = z, mag = mag }
end

function mario_direction_to_binary_yaw(dirX, dirZ)
    if dirX == 0 and dirZ == 0 then return 0 end
    return rad_to_binary(math.atan2(dirX, dirZ))
end

function mario_smooth_face_rotate(m, targetYaw, lerpFactor)
    local cur = m.faceAngle.y
    local diff = ((targetYaw - cur) % BINARY_ANGLE_MAX + BINARY_ANGLE_MAX / 2)
                 % BINARY_ANGLE_MAX - BINARY_ANGLE_MAX / 2
    m.faceAngle.y = (cur + diff * lerpFactor) % BINARY_ANGLE_MAX
end

function mario_smooth_vel_approach(m, targetVel, lerpFactor)
    m.vel.x = m.vel.x + (targetVel.x - m.vel.x) * lerpFactor
    m.vel.z = m.vel.z + (targetVel.z - m.vel.z) * lerpFactor
    m.forwardVel = math.sqrt(m.vel.x * m.vel.x + m.vel.z * m.vel.z)
end

function mario_update_velocity(m, opts)
    opts = opts or {}
    local dir = opts.direction or "stick"
    local speed = opts.speed or 0
    local lerp = opts.lerp or 0.2
    local accelLerp = opts.accelLerp or lerp
    local brakeLerp = opts.brakeLerp or lerp
    local brake = (opts.brake ~= false)
    local maxSpeed = opts.maxSpeed
    local deadZone = opts.deadZone or 0.1

    local targetX, targetZ

    if type(dir) == "table" then
        targetX, targetZ = dir.x or 0, dir.z or 0
    elseif dir == "stick" then
        local sx, sy = -m.controller.stickX, m.controller.stickY
        local stickMag = math.sqrt(sx * sx + sy * sy)
        if stickMag > deadZone then
            local rad = binary_to_rad(m.intendedYaw)
            targetX = math.sin(rad) * speed
            targetZ = math.cos(rad) * speed
        elseif brake then
            targetX, targetZ = 0, 0
        else
            return
        end
    elseif dir == "forward" then
        local rad = binary_to_rad(m.faceAngle.y)
        targetX = math.sin(rad) * speed
        targetZ = math.cos(rad) * speed
    elseif dir == "camera" then
        local camYaw = mario_get_camera_yaw(m)
        local rad = binary_to_rad(camYaw)
        targetX = math.sin(rad) * speed
        targetZ = math.cos(rad) * speed
    else
        return
    end

    if targetX == nil or targetZ == nil then return end

    local currentSpeed = m.forwardVel
    local targetSpeed = math.sqrt(targetX * targetX + targetZ * targetZ)
    local lerpFactor = (targetSpeed >= currentSpeed) and accelLerp or brakeLerp

    mario_smooth_vel_approach(m, { x = targetX, z = targetZ }, lerpFactor)

    if maxSpeed then
        local vx, vz = m.vel.x, m.vel.z
        local spd = math.sqrt(vx * vx + vz * vz)
        if spd > maxSpeed then
            m.vel.x = vx / spd * maxSpeed
            m.vel.z = vz / spd * maxSpeed
            m.forwardVel = maxSpeed
        end
    end
end

function mario_update_face(m, opts)
    opts = opts or {}
    local target = opts.target or "stick"
    local lerp = opts.lerp or 0.2
    local deadZone = opts.deadZone or 0.1

    local targetYaw
    if target == "stick" then
        local sx, sy = -m.controller.stickX, m.controller.stickY
        local stickMag = math.sqrt(sx * sx + sy * sy)
        if stickMag < deadZone then return end
        targetYaw = m.intendedYaw
    elseif target == "camera" then
        targetYaw = mario_get_camera_yaw(m)
    elseif target == "none" then
        return
    elseif type(target) == "number" then
        targetYaw = target
    else
        return
    end

    mario_smooth_face_rotate(m, targetYaw, lerp)
end

function mario_handle_ground_step(m)
    local stepResult = perform_ground_step(m)
    if stepResult == GROUND_STEP_LEFT_GROUND then
        set_mario_action(m, ACT_FREEFALL, 0)
        return false
    end
    return true
end

function mario_do_jump(m, jumpVel)
    m.vel.y = jumpVel
    set_mario_action(m, ACT_JUMP, 0)
    return true
end

function mario_is_grounded(m)
    return not ((m.action & ACT_FLAG_AIR) ~= 0)
end

function mario_is_airborne(m)
    return (m.action & ACT_FLAG_AIR) ~= 0
end

function mario_get_velocity_yaw(m)
    if m.forwardVel < 0.1 then
        return m.faceAngle.y
    end
    return mario_direction_to_binary_yaw(m.vel.x, m.vel.z)
end

local id_bhvPoseMesh = hook_behavior(
    nil, OBJ_LIST_GENACTOR, true,
    function(o)
        o.oFlags = OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
        o.oIntangibleTimer = -1
        o.oOpacity = 255
    end,
    function(o)
        local life = (o.oDamageOrCoinValue or 1) - 1
        if life <= 0 then
            obj_mark_for_deletion(o)
        else
            o.oDamageOrCoinValue = life
        end
    end,
    "PoseMesh"
)

--- @param m MarioState
--- @param wx number
--- @param wy number
--- @param wz number
--- @return table
local function world_to_local_offset(m, wx, wy, wz)
    local dx, dy, dz = wx - m.pos.x, wy - m.pos.y, wz - m.pos.z
    local cosA, sinA = coss(m.faceAngle.y), sins(m.faceAngle.y)
    return {
        x =  dx * cosA + dz * sinA,
        y = dy,
        z = -dx * sinA + dz * cosA,
    }
end

local HAND_LEFT, HAND_RIGHT = 0, 1
local FOOT_LEFT, FOOT_RIGHT = 2, 3

--- @type table<string, {pos?: table, pos_fn?: fun(m: MarioState): table, rot_fn?: fun(m: MarioState): table}>
local BODY_ANCHORS = {
    root = { pos = { x = 0, y = 0, z = 0 } },

    torso = {
        pos_fn = function(m)
            local tp = m.marioBodyState.torsoPos
            return world_to_local_offset(m, tp.x, tp.y, tp.z)
        end,
    },

    head = {
        pos_fn = function(m)
            local hp = m.marioBodyState.headPos
            return world_to_local_offset(m, hp.x, hp.y, hp.z)
        end,
    },

    left_hand = {
        pos_fn = function(m)
            return world_to_local_offset(m,
                get_hand_foot_pos_x(m, HAND_LEFT),
                get_hand_foot_pos_y(m, HAND_LEFT),
                get_hand_foot_pos_z(m, HAND_LEFT))
        end,
    },

    right_hand = {
        pos_fn = function(m)
            return world_to_local_offset(m,
                get_hand_foot_pos_x(m, HAND_RIGHT),
                get_hand_foot_pos_y(m, HAND_RIGHT),
                get_hand_foot_pos_z(m, HAND_RIGHT))
        end,
    },

    left_foot = {
        pos_fn = function(m)
            return world_to_local_offset(m,
                get_hand_foot_pos_x(m, FOOT_LEFT),
                get_hand_foot_pos_y(m, FOOT_LEFT),
                get_hand_foot_pos_z(m, FOOT_LEFT))
        end,
    },

    right_foot = {
        pos_fn = function(m)
            return world_to_local_offset(m,
                get_hand_foot_pos_x(m, FOOT_RIGHT),
                get_hand_foot_pos_y(m, FOOT_RIGHT),
                get_hand_foot_pos_z(m, FOOT_RIGHT))
        end,
    },

    front = { pos = { x = 0, y = 60, z = 40 } },
    back  = { pos = { x = 0, y = 60, z = -40 }, yaw = 0x8000 },
}

local ZERO_OFFSET = { x = 0, y = 0, z = 0 }

--- @param m MarioState
--- @param name string|nil
--- @return table pos, number yaw
local function resolve_anchor(m, name)
    if name == nil then return ZERO_OFFSET, 0 end
    local a = BODY_ANCHORS[name]
    if a == nil then return ZERO_OFFSET, 0 end

    local p
    if a.pos_fn ~= nil then
        p = a.pos_fn(m)
    elseif a.pos ~= nil then
        p = a.pos
    else
        p = ZERO_OFFSET
    end
    return p, a.yaw or 0
end

--- @param opts table
--- @return Object|nil
local function spawn_pose_mesh(opts)
    if not opts or opts.model == nil then return nil end
    local pos = opts.pos or { x = 0, y = 0, z = 0 }

    return spawn_non_sync_object(id_bhvPoseMesh, opts.model,
        pos.x, pos.y, pos.z,
        function(o)
            o.oFaceAnglePitch = opts.pitch or 0
            o.oFaceAngleYaw   = opts.yaw   or 0
            o.oFaceAngleRoll  = opts.roll  or 0

            local s = opts.scale or 1
            if type(s) == "number" then
                o.header.gfx.scale.x = s
                o.header.gfx.scale.y = s
                o.header.gfx.scale.z = s
            else
                o.header.gfx.scale.x = s.x or 1
                o.header.gfx.scale.y = s.y or 1
                o.header.gfx.scale.z = s.z or 1
            end

            local ai = o.header.gfx.animInfo
            if opts.animID    ~= nil then ai.animID    = opts.animID    end
            if opts.curAnim   ~= nil then ai.curAnim   = opts.curAnim   end
            if opts.animYTrans ~= nil then ai.animYTrans = opts.animYTrans end
            local frame = opts.animFrame or 0
            ai.animFrame = frame
            ai.animFrameAccelAssist = frame * 0x10000
            ai.animAccel = 0
            ai.animTimer = 0

            o.oOpacity = opts.opacity or 255
            o.oDamageOrCoinValue = opts.lifetime or 1
        end
    )
end

--- @param m MarioState
--- @return table
local function mario_capture_snapshot(m)
    local gfx = m.marioObj.header.gfx
    local ai  = gfx.animInfo
    return {
        model = obj_get_model_id_extended(m.marioObj),
        pos = { x = m.pos.x, y = m.pos.y, z = m.pos.z },
        yaw = gfx.angle.y,
        pitch = gfx.angle.x,
        roll = gfx.angle.z,
        scale = { x = gfx.scale.x, y = gfx.scale.y, z = gfx.scale.z },
        animID = ai.animID,
        curAnim = ai.curAnim,
        animYTrans = m.unkB0 or 0,
        animFrame = ai.animFrame,
        opacity = 255,
        lifetime = 1,
    }
end

--- @param snap table
--- @param overrides table|nil
--- @return Object|nil
local function spawn_snapshot_mesh(snap, overrides)
    if not snap then return nil end
    overrides = overrides or {}

    local function pick(field)
        local v = overrides[field]
        if v == nil then v = snap[field] end
        return v
    end

    return spawn_pose_mesh({
        model = pick("model"),
        pos = pick("pos"),
        yaw = pick("yaw"),
        pitch = pick("pitch"),
        roll = pick("roll"),
        scale = pick("scale"),
        animID = pick("animID"),
        curAnim = pick("curAnim"),
        animYTrans = pick("animYTrans"),
        animFrame = pick("animFrame"),
        opacity = overrides.opacity  or snap.opacity  or 255,
        lifetime = overrides.lifetime or snap.lifetime or 1,
    })
end

--- @param m MarioState
--- @param opts table
--- @return Object|nil
local function spawn_mesh_at_offset(m, opts)
    opts = opts or {}
    local off = opts.offset or { x = 0, y = 0, z = 0 }
    local anchor_off, anchor_yaw = resolve_anchor(m, opts.anchor)

    local lx = anchor_off.x + off.x
    local ly = anchor_off.y + off.y
    local lz = anchor_off.z + off.z

    local cosA, sinA = coss(m.faceAngle.y), sins(m.faceAngle.y)
    local wx = lx * cosA - lz * sinA
    local wz = lx * sinA + lz * cosA

    opts.pos = {
        x = m.pos.x + wx,
        y = m.pos.y + ly,
        z = m.pos.z + wz,
    }
    if opts.yaw == nil then
        opts.yaw = (m.faceAngle.y + anchor_yaw) % BINARY_ANGLE_MAX
    end
    return spawn_pose_mesh(opts)
end

_G.sp_pose_builder = {
    mario_get_camera_yaw = mario_get_camera_yaw,
    mario_get_stick_world_direction = mario_get_stick_world_direction,
    mario_direction_to_binary_yaw = mario_direction_to_binary_yaw,
    mario_smooth_face_rotate = mario_smooth_face_rotate,
    mario_smooth_vel_approach = mario_smooth_vel_approach,
    mario_update_velocity = mario_update_velocity,
    mario_update_face = mario_update_face,
    mario_handle_ground_step = mario_handle_ground_step,
    mario_do_jump = mario_do_jump,
    mario_is_grounded = mario_is_grounded,
    mario_is_airborne = mario_is_airborne,
    mario_get_velocity_yaw = mario_get_velocity_yaw,
    world_to_local_offset = world_to_local_offset,
    spawn_pose_mesh = spawn_pose_mesh,
    mario_capture_snapshot = mario_capture_snapshot,
    spawn_snapshot_mesh = spawn_snapshot_mesh,
    spawn_mesh_at_offset = spawn_mesh_at_offset,
    body_anchors = BODY_ANCHORS,
}