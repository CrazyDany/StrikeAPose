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

    set_mario_action(m, pose.action, pose_id)
    m.actionTimer = 0

    djui_chat_message_create('poseapply')
    return true
end

--- @class SAPPose
--- @field name string
--- @field animation_name string
--- @field action integer
--- @field _anim_status boolean | nil
--- @field hook_every_tick fun(m: MarioState, is_owner: boolean)
--- @field hook_start      fun(m: MarioState, is_owner: boolean)
--- @field hook_end        fun(m: MarioState, is_owner: boolean)
SAPPose = {}
SAPPose.__index = SAPPose

function SAPPose.new(name, animation_name, pose_action_flags)
    name = name or ('pose_' .. tostring(random_float()))
    animation_name = animation_name or NO_ANIMATION

    local self = setmetatable({}, SAPPose)
    self.name = name
    self.animation_name = animation_name
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

        if pose.hook_every_tick ~= nil then
            pose.hook_every_tick(m, is_owner)
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

    if last_id ~= nil then
        local old_pose = _G.StrikeAPose:get_pose(last_id)
        if old_pose and old_pose.hook_end ~= nil then
            old_pose.hook_end(m, is_owner)
        end
    end

    if current_pose_id ~= nil then
        local new_pose = _G.StrikeAPose:get_pose(current_pose_id)
        if new_pose then
            enter_pose_animation(m, new_pose)

            if new_pose.hook_start ~= nil then
                new_pose.hook_start(m, is_owner)
            end
        end
    end

    last_pose_state[pi] = current_pose_id
end)

local should_show_message = true
hook_event(HOOK_UPDATE, function()
    if should_show_message then
        djui_chat_message_create('\\#99BBEE\\Strike-A-Pose!\\#FFFFFF\\ loaded!\n\nNow you can Hold \\#FFC401\\L-Trig + D-Pad Left/Right\\#FFFFFF\\ to select and strike a pose, or just press \\#FFC401\\L-Trig\\#FFFFFF\\ to strike the current pose.\n\nType \\#FFFF33\\/help\\#FFFFFF\\ for more info on settings and controls.')
        should_show_message = false
    end
end)