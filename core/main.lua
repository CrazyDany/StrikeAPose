--- @class StrikeAPose
--- @field version string
--- @field poses table<integer, SAPPose>
local StrikeAPose = {}
StrikeAPose.__index = StrikeAPose

StrikeAPose.version = '1.0'
StrikeAPose.poses = {}
StrikeAPose.actions = {}

local last_pose_state = {}
local NO_ANIMATION = 'SAP_NONE'

local JOIN_RADIUS = 200

local function key_L(gpi) return "SAP_coop_L_" .. gpi end
local function key_M(gpi) return "SAP_coop_M_" .. gpi end
local function key_S(gpi) return "SAP_coop_S_" .. gpi end

local function get_leader_pose(gpi)
    local v = gGlobalSyncTable[key_L(gpi)]
    if type(v) == "number" and v > 0 then return v end
    return nil
end

local function get_member_leader(gpi)
    local v = gGlobalSyncTable[key_M(gpi)]
    if type(v) == "number" and v >= 0 then return v end
    return nil
end

local function get_member_slot(gpi)
    local v = gGlobalSyncTable[key_S(gpi)]
    if type(v) == "number" and v >= 0 then return v end
    return nil
end

local function set_leader(gpi, pose_id)
    gGlobalSyncTable[key_L(gpi)] = pose_id or 0
end

local function set_member(gpi, leader_gpi, slot)
    if leader_gpi == nil then
        gGlobalSyncTable[key_M(gpi)] = -1
        gGlobalSyncTable[key_S(gpi)] = -1
    else
        gGlobalSyncTable[key_M(gpi)] = leader_gpi
        gGlobalSyncTable[key_S(gpi)] = slot
    end
end

local function local_gpi()
    if gNetworkPlayers and gNetworkPlayers[0] then
        return gNetworkPlayers[0].globalIndex
    end
    return 0
end

--- @param m MarioState
--- @return integer|nil
local function gpi_of(m)
    if gNetworkPlayers and gNetworkPlayers[m.playerIndex] then
        return gNetworkPlayers[m.playerIndex].globalIndex
    end
    return nil
end

--- @param gpi integer
--- @return MarioState|nil
local function find_mario_by_gpi(gpi)
    for i = 0, MAX_PLAYERS - 1 do
        local m = gMarioStates[i]
        if m and gNetworkPlayers[i] and gNetworkPlayers[i].globalIndex == gpi then
            return m
        end
    end
    return nil
end

--- @return integer[]
local function iter_active_gpis()
    local list = {}
    for i = 0, MAX_PLAYERS - 1 do
        local p = gNetworkPlayers[i]
        if p then
            table.insert(list, p.globalIndex)
        end
    end
    return list
end

--- @param leader_gpi integer
--- @return table|nil
local function get_session(leader_gpi)
    local pose_id = get_leader_pose(leader_gpi)
    if not pose_id then return nil end

    local pose = _G.StrikeAPose:get_pose(pose_id)
    if not pose then return nil end

    local leader_m = find_mario_by_gpi(leader_gpi)
    if not leader_m then return nil end

    local slots = { [leader_gpi] = 0 }
    local count = 1

    for _, gpi in ipairs(iter_active_gpis()) do
        if gpi ~= leader_gpi and get_member_leader(gpi) == leader_gpi then
            local slot = get_member_slot(gpi)
            if slot and slot >= 0 then
                slots[gpi] = slot
                count = count + 1
            end
        end
    end

    return {
        pose_id = pose_id,
        max_slots = pose.max_slots,
        slots = slots,
        count = count,
    }
end

--- @param session table
--- @return integer|nil
local function find_free_slot(session)
    local occupied = {}
    for _, s in pairs(session.slots) do occupied[s] = true end

    if session.max_slots == -1 then
        local i = 1
        while occupied[i] do i = i + 1 end
        return i
    end
    for i = 1, session.max_slots - 1 do
        if not occupied[i] then return i end
    end
    return nil
end

--- @param m MarioState
--- @return table|nil
function StrikeAPose:get_coop_ctx(m)
    if not gGlobalSyncTable then return nil end

    local gpi = gpi_of(m)
    if not gpi then return nil end

    -- Leader?
    local my_pose = get_leader_pose(gpi)
    if my_pose then
        local session = get_session(gpi)
        if session then
            return {
                is_coop = true,
                is_leader = true,
                slot_index = 0,
                session_id = gpi,
                session = session,
                count = session.count,
                max_slots = session.max_slots,
                pose_id = session.pose_id,
            }
        end
    end

    local leader_gpi = get_member_leader(gpi)
    if leader_gpi then
        local session = get_session(leader_gpi)
        if session then
            local my_slot = session.slots[gpi]
            if my_slot then
                return {
                    is_coop = true,
                    is_leader = false,
                    slot_index = my_slot,
                    session_id = leader_gpi,
                    session = session,
                    count = session.count,
                    max_slots = session.max_slots,
                    pose_id = session.pose_id,
                }
            end
        end
    end

    return nil
end

--- @param m MarioState
--- @param pose_id integer
--- @return boolean
function StrikeAPose:start_coop_session(m, pose_id)
    if not gGlobalSyncTable then return false end
    local pose = self:get_pose(pose_id)
    if not pose then return false end
    local gpi = gpi_of(m)
    if not gpi then return false end

    set_leader(gpi, pose_id)
    return true
end

--- @param leader_gpi integer
--- @param m MarioState
--- @return boolean
function StrikeAPose:join_coop_session(leader_gpi, m)
    if not gGlobalSyncTable then return false end

    local session = get_session(leader_gpi)
    if not session then return false end

    local pose = self:get_pose(session.pose_id)
    if not pose then return false end

    local gpi = gpi_of(m)
    if not gpi then return false end

    if session.slots[gpi] ~= nil then return false end

    local slot = find_free_slot(session)
    if slot == nil then return false end

    set_member(gpi, leader_gpi, slot)
    set_mario_action(m, pose.action, session.pose_id)
    m.actionTimer = 0
    return true
end

--- @param m MarioState
function StrikeAPose:leave_coop_session(m)
    local gpi = gpi_of(m)
    if not gpi then return end

    if get_member_leader(gpi) then
        set_member(gpi, nil, nil)
    end
    if get_leader_pose(gpi) then
        set_leader(gpi, 0)
    end
end

local function cleanup_local()
    if not gGlobalSyncTable then return end

    local my_gpi = local_gpi()
    local m = gMarioStates[0]
    if not m then return end

    local l_pose_id = get_leader_pose(my_gpi)
    if l_pose_id then
        local pose = _G.StrikeAPose:get_pose(l_pose_id)
        if not pose or m.action ~= pose.action then
            set_leader(my_gpi, 0)
        end
    end

    local leader_gpi = get_member_leader(my_gpi)
    if leader_gpi then
        local leader_m = find_mario_by_gpi(leader_gpi)
        local leader_pose = get_leader_pose(leader_gpi)
        local still_valid = false

        if leader_m and leader_pose then
            local pose = _G.StrikeAPose:get_pose(leader_pose)
            if pose and m.action == pose.action and m.actionArg == leader_pose then
                still_valid = true
            end
        end

        if not still_valid then
            set_member(my_gpi, nil, nil)

            local my_pose_id = _G.StrikeAPose.actions[m.action]
            if my_pose_id then
                local p = _G.StrikeAPose:get_pose(my_pose_id)
                if p and p.is_coop then
                    set_mario_action(m, ACT_FREEFALL, 0)
                end
            end
        end
    end
end

--- @param pose SAPPose
--- @return integer
function StrikeAPose:register_new_pose(pose)
    table.insert(self.poses, pose)
    self.actions[pose.action] = #self.poses
    log_to_console('SAP: ' .. pose.name .. ' loaded')
    return #self.poses
end

--- @param id integer
--- @return SAPPose
function StrikeAPose:get_pose(id)
    return self.poses[id]
end

--- @return table<integer, SAPPose>
function StrikeAPose:list_poses()
    return self.poses
end

local function is_no_animation(name)
    return name == nil or name == '' or name == NO_ANIMATION
end

--- @param m MarioState
--- @param pose SAPPose
local function enter_pose_animation(m, pose)
    local anim_name = pose.animation_name
    if is_no_animation(anim_name) then return end
    if pose._anim_status == false then return end

    smlua_anim_util_set_animation(m.marioObj, anim_name)
    set_anim_to_frame(m, 0)

    if pose._anim_status == nil then
        local applied = smlua_anim_util_get_current_animation_name(m.marioObj)
        if applied == anim_name then
            pose._anim_status = true
        else
            pose._anim_status = false
            log_to_console('SAP: animation "' .. tostring(anim_name) ..
                '" for pose "' .. tostring(pose.name) .. '" not found; skipping.')
        end
    end
end

--- @param m MarioState
--- @param pose_id integer
function StrikeAPose:apply_pose(m, pose_id)
    local pose = self:get_pose(pose_id)
    if pose == nil then return false end

    if pose.is_coop then
        self:start_coop_session(m, pose_id)
    end

    set_mario_action(m, pose.action, pose_id)
    m.actionTimer = 0

    djui_chat_message_create('poseapply')
    return true
end

--- @class SAPPose
--- @field name string
--- @field animation_name string
--- @field action integer
--- @field max_slots integer
--- @field is_coop boolean
--- @field _anim_status boolean | nil
--- @field hook_every_tick fun(m: MarioState, is_owner: boolean, ctx: table|nil)
--- @field hook_start fun(m: MarioState, is_owner: boolean, ctx: table|nil)
--- @field hook_end fun(m: MarioState, is_owner: boolean, ctx: table|nil)
SAPPose = {}
SAPPose.__index = SAPPose

--- @param name string|nil
--- @param animation_name string|nil
--- @param pose_action_flags integer
--- @param max_slots integer|nil
--- @return SAPPose
function SAPPose.new(name, animation_name, pose_action_flags, max_slots)
    name = name or ('pose_' .. tostring(random_float()))
    animation_name = animation_name or NO_ANIMATION
    max_slots = max_slots or 1

    local self = setmetatable({}, SAPPose)
    self.name = name
    self.animation_name = animation_name
    self.max_slots = max_slots
    self.is_coop = (max_slots ~= 1)
    self._anim_status = nil

    local pose_action = allocate_mario_action(pose_action_flags)

    --- @param m MarioState
    function action_every_frame(m)
        local pose_id = m.actionArg
        local pose = _G.StrikeAPose:get_pose(pose_id)
        if pose == nil then return end

        local is_owner = (m.playerIndex == 0)

        if is_owner and (m.controller.buttonPressed & A_BUTTON) ~= 0 then
            set_mario_action(m, ACT_FREEFALL, 0)
            return
        end

        m.actionTimer = m.actionTimer + 1

        local ctx = _G.StrikeAPose:get_coop_ctx(m)

        if pose.hook_every_tick ~= nil then
            pose.hook_every_tick(m, is_owner, ctx)
        end
    end

    hook_mario_action(pose_action, { every_frame = action_every_frame, gravity = nil })

    self.action = pose_action
    return self
end

_G.strike_a_pos_loaded = true
_G.StrikeAPose = StrikeAPose
_G.SAPPose = SAPPose

log_to_console('Strike-A-Pose! ' .. _G.StrikeAPose.version .. ' loaded', CONSOLE_MESSAGE_INFO)
djui_popup_create('Strike-A-Pose! ' .. _G.StrikeAPose.version .. ' loaded', 3)

hook_event(HOOK_MARIO_UPDATE, function(m)
    if m == nil then return end
    if _G.StrikeAPose == nil then return end

    local pi = m.playerIndex
    local current_pose_id = _G.StrikeAPose.actions[m.action]
    local last_id = last_pose_state[pi]

    if current_pose_id == last_id then return end

    local is_owner = (pi == 0)
    local ctx = _G.StrikeAPose:get_coop_ctx(m)

    if last_id ~= nil then
        local old_pose = _G.StrikeAPose:get_pose(last_id)
        if old_pose and old_pose.hook_end ~= nil then
            old_pose.hook_end(m, is_owner, ctx)
        end
    end

    if current_pose_id ~= nil then
        local new_pose = _G.StrikeAPose:get_pose(current_pose_id)
        if new_pose then
            enter_pose_animation(m, new_pose)
            if new_pose.hook_start ~= nil then
                new_pose.hook_start(m, is_owner, ctx)
            end
        end
    end

    last_pose_state[pi] = current_pose_id
end)

--- @param local_m MarioState
--- @return table|nil
local function find_joinable_session(local_m)
    if _G.StrikeAPose.actions[local_m.action] ~= nil then return nil end

    local my_gpi = local_gpi()

    local best, best_dist = nil, JOIN_RADIUS

    for _, leader_gpi in ipairs(iter_active_gpis()) do
        if leader_gpi ~= my_gpi then
            local session = get_session(leader_gpi)
            if session and session.slots[my_gpi] == nil then
                local pose = _G.StrikeAPose:get_pose(session.pose_id)
                if pose and pose.is_coop and find_free_slot(session) ~= nil then
                    local leader_m = find_mario_by_gpi(leader_gpi)
                    if leader_m then
                        local d = vec3f_dist(local_m.pos, leader_m.pos)
                        if d < best_dist then
                            best_dist = d
                            best = {
                                session = session,
                                leader_m = leader_m,
                                leader_gpi = leader_gpi,
                            }
                        end
                    end
                end
            end
        end
    end
    return best
end

local cached_join = nil

hook_event(HOOK_UPDATE, function()
    if _G.StrikeAPose == nil then return end
    if not gGlobalSyncTable then return end

    cleanup_local()

    local local_m = gMarioStates[0]
    if not local_m then
        cached_join = nil
        return
    end

    cached_join = find_joinable_session(local_m)

    if cached_join and (local_m.controller.buttonPressed & B_BUTTON) ~= 0 then
        if _G.StrikeAPose:join_coop_session(cached_join.leader_gpi, local_m) then
            djui_chat_message_create('Joined coop pose!')
            cached_join = nil
        end
    end
end)

hook_event(HOOK_ON_HUD_RENDER_BEHIND, function()
    if not cached_join then return end

    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_font(FONT_ALIASED)

    local leader_m = cached_join.leader_m
    local session = cached_join.session

    local yaw = leader_m.faceAngle.y
    local fwdX = sins(yaw)
    local fwdZ = coss(yaw)
    local FORWARD_OFFSET = 55
    local HEAD_OFFSET = 10

    local world = {
        x = leader_m.pos.x + fwdX * FORWARD_OFFSET,
        y = leader_m.marioBodyState.headPos.y + HEAD_OFFSET,
        z = leader_m.pos.z + fwdZ * FORWARD_OFFSET,
    }
    local screen = { x = 0, y = 0, z = 0 }
    djui_hud_world_pos_to_screen_pos(world, screen)

    local scale = 0.35

    local text1 = "Coop Pose"
    local b_str = "[B]"
    local join_str = " Join"
    local count_str = ""
    if session.max_slots ~= -1 then
        count_str = " " .. session.count .. "/" .. session.max_slots
    end

    local w1 = select(1, djui_hud_measure_text(text1)) * scale
    local _, th = djui_hud_measure_text("X")
    local line_h = th * scale

    local w_b = select(1, djui_hud_measure_text(b_str))     * scale
    local w_join = select(1, djui_hud_measure_text(join_str))  * scale
    local w_count = (count_str ~= "") and (select(1, djui_hud_measure_text(count_str)) * scale) or 0
    local w2 = w_b + w_join + w_count

    local max_w = math.max(w1, w2)
    local pad_x = 6
    local pad_y = 3
    local line_gap = 1

    local box_w = max_w + pad_x * 2
    local box_h = line_h * 2 + line_gap + pad_y * 2

    local bx = screen.x - box_w / 2
    local by = screen.y - box_h / 2

    djui_hud_set_color(15, 15, 22, 165)
    djui_hud_render_rect(bx, by, box_w, box_h)

    djui_hud_set_color(200, 200, 220, 80)
    djui_hud_render_rect(bx, by, box_w, 1)
    djui_hud_render_rect(bx, by + box_h - 1, box_w, 1)
    djui_hud_render_rect(bx, by, 1, box_h)
    djui_hud_render_rect(bx + box_w - 1, by, 1, box_h)

    djui_hud_set_color(255, 220, 120, 235)
    djui_hud_print_text(text1, screen.x - w1 / 2, by + pad_y, scale)

    local cx = screen.x - w2 / 2
    local cy = by + pad_y + line_h + line_gap

    djui_hud_set_color(255, 200, 60, 245)
    djui_hud_print_text(b_str, cx, cy, scale)
    cx = cx + w_b

    djui_hud_set_color(230, 230, 240, 220)
    djui_hud_print_text(join_str, cx, cy, scale)
    cx = cx + w_join

    if count_str ~= "" then
        djui_hud_set_color(230, 230, 240, 220)
        djui_hud_print_text(count_str, cx, cy, scale)
    end
end)

local should_show_message = true
hook_event(HOOK_UPDATE, function()
    if should_show_message then
        djui_chat_message_create('\\#99BBEE\\Strike-A-Pose!\\#FFFFFF\\ loaded!\n\nNow you can Hold \\#FFC401\\L-Trig + D-Pad Left/Right\\#FFFFFF\\ to select and strike a pose, or just press \\#FFC401\\L-Trig\\#FFFFFF\\ to strike the current pose.\n\nType \\#FFFF33\\/help\\#FFFFFF\\ for more info on settings and controls.')
        should_show_message = false
    end
end)