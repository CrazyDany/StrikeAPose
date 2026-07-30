--- @class StrikeAPose
--- @field version string
--- @field poses table<integer, SAPPose>
local StrikeAPose = {}
StrikeAPose.__index = StrikeAPose

StrikeAPose.version = '1.0'
StrikeAPose.poses = {}

--- @param pose SAPPose
--- @return integer
function StrikeAPose:register_new_pose(pose)
    table.insert(self.poses, pose)
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

--- @param m MarioState
--- @param pose_id integer
function StrikeAPose:apply_pose(m, pose_id)
    local command_idx = tonumber(msg)

    local pose = self:get_pose(pose_id)

    if pose == nil then
        return false
    end

    if 0 then
        -- Проверка возможности установить позу
    end
    
    set_mario_action(m, pose.action, pose_id)
    smlua_anim_util_set_animation(m.marioObj, pose.animation_name)
    set_anim_to_frame(m, 0)
end



--- @class SAPPose
--- @field name string
--- @field animation_name string
--- @field action integer
SAPPose = {}
SAPPose.__index = SAPPose

function SAPPose.new(name, animation_name, pose_action_flags)
    name = name or ('pose_' .. tostring(random_float()))
    animation_name = animation_name or name

    local self = setmetatable({}, SAPPose)
    self.name = name
    self.animation_name = animation_name

    -- создание акта
    local pose_action = allocate_mario_action(pose_action_flags)

    --- @param m MarioState
    function action_every_frame(m)
        local pose_id = m.actionArg
        local pose = _G.StrikeAPose:get_pose(pose_id)

        -- логика для различных флагов

        if (m.controller.buttonPressed & A_BUTTON) ~= 0 then
            set_mario_action(m, ACT_FREEFALL, -1)
        end
    end

    hook_mario_action(pose_action, {every_frame = action_every_frame, gravity = nil})

    self.action = pose_action

    return self
end

_G.strike_a_pos_loaded = true
_G.StrikeAPose = StrikeAPose
_G.SAPPose = SAPPose

log_to_console('StrikeAPose ' .. _G.StrikeAPose.version .. ' loaded', CONSOLE_MESSAGE_INFO)
djui_popup_create('StrikeAPose ' .. _G.StrikeAPose.version .. ' loaded', 3)