local BINARY_ANGLE_MAX = 65536
local ANGLE_TO_RAD = (2 * math.pi) / BINARY_ANGLE_MAX

local function binary_to_rad(angle) return angle * ANGLE_TO_RAD end
local function rad_to_binary(rad) return (rad / ANGLE_TO_RAD) % BINARY_ANGLE_MAX end

--- Get the camera's yaw angle in binary units (0..65535).
--- @param m MarioState
--- @return number
function mario_get_camera_yaw(m)
    return m.area.camera.yaw + 0x8000
end

--- Convert joystick input to a world-space direction vector.
--- @param m MarioState
--- @param camYaw number
--- @param deadZone number
--- @return table { x, z, mag }
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

--- Convert a world direction (x, z) to a binary yaw angle.
--- @param dirX number
--- @param dirZ number
--- @return number
function mario_direction_to_binary_yaw(dirX, dirZ)
    if dirX == 0 and dirZ == 0 then return 0 end
    return rad_to_binary(math.atan2(dirX, dirZ))
end

--- Smoothly rotate Mario's face toward a target yaw.
--- @param m MarioState
--- @param targetYaw number
--- @param lerpFactor number
--- @param clientSided boolean|nil
function mario_smooth_face_rotate(m, targetYaw, lerpFactor, clientSided)
    clientSided = clientSided or false
    if not clientSided and m.playerIndex ~= 0 then return end
    local cur = m.faceAngle.y
    local diff = ((targetYaw - cur) % BINARY_ANGLE_MAX + BINARY_ANGLE_MAX / 2) % BINARY_ANGLE_MAX - BINARY_ANGLE_MAX / 2
    m.faceAngle.y = (cur + diff * lerpFactor) % BINARY_ANGLE_MAX
end

--- Smoothly approach a target velocity vector (x, z).
--- @param m MarioState
--- @param targetVel table { x, z }
--- @param lerpFactor number
function mario_smooth_vel_approach(m, targetVel, lerpFactor)
    m.vel.x = m.vel.x + (targetVel.x - m.vel.x) * lerpFactor
    m.vel.z = m.vel.z + (targetVel.z - m.vel.z) * lerpFactor
    m.forwardVel = math.sqrt(m.vel.x * m.vel.x + m.vel.z * m.vel.z)
end

--- Update Mario's velocity based on various modes.
--- @param m MarioState
--- @param opts table
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
    local clientSided = opts.clientSided or false
    if clientSided and m.playerIndex ~= 0 then return end

    local targetX, targetZ

    if type(dir) == "table" then
        targetX, targetZ = dir.x or 0, dir.z or 0
    elseif dir == "stick" then
        local camYaw = mario_get_camera_yaw(m)
        local stick = mario_get_stick_world_direction(m, camYaw, deadZone)
        if stick.mag > deadZone then
            targetX = stick.x / stick.mag * speed
            targetZ = stick.z / stick.mag * speed
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

--- Update Mario's facing direction.
--- @param m MarioState
--- @param opts table
function mario_update_face(m, opts)
    opts = opts or {}
    local target = opts.target or "stick"
    local lerp = opts.lerp or 0.2
    local deadZone = opts.deadZone or 0.1
    local clientSided = opts.clientSided or false
    if clientSided and m.playerIndex ~= 0 then return end

    local targetYaw
    if target == "stick" then
        local camYaw = mario_get_camera_yaw(m)
        local stick = mario_get_stick_world_direction(m, camYaw, deadZone)
        if stick.mag > deadZone then
            targetYaw = mario_direction_to_binary_yaw(stick.x, stick.z)
        else
            return
        end
    elseif target == "camera" then
        targetYaw = mario_get_camera_yaw(m)
    elseif target == "none" then
        return
    elseif type(target) == "number" then
        targetYaw = target
    else
        return
    end

    mario_smooth_face_rotate(m, targetYaw, lerp, clientSided)
end

--- Handle ground step and switch to FREEFALL if Mario leaves the ground.
--- @param m MarioState
--- @return boolean
function mario_handle_ground_step(m)
    local stepResult = perform_ground_step(m)
    if stepResult == GROUND_STEP_LEFT_GROUND then
        set_mario_action(m, ACT_FREEFALL, 0)
        return false
    end
    return true
end

--- Make Mario jump (only if on ground and not already jumping).
--- @param m MarioState
--- @param jumpVel number
--- @return boolean
function mario_do_jump(m, jumpVel)
    m.vel.y = jumpVel
    set_mario_action(m, ACT_JUMP, 0)
    return true
end

--- Check if Mario is on ground (not falling or jumping).
--- @param m MarioState
--- @return boolean
function mario_is_grounded(m)
    return not ((m.action & ACT_FLAG_AIR) ~= 0)
end

--- Check if Mario is in the air.
--- @param m MarioState
--- @return boolean
function mario_is_airborne(m)
    return (m.action & ACT_FLAG_AIR) ~= 0
end

--- Get the binary yaw angle of Mario's current velocity vector.
--- @param m MarioState
--- @return number
function mario_get_velocity_yaw(m)
    if m.forwardVel < 0.1 then
        return m.faceAngle.y
    end
    return mario_direction_to_binary_yaw(m.vel.x, m.vel.z)
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
}