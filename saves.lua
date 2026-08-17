--- @type table<integer, integer|nil>
local poses_slots_saved = {}

MIN_SLOT_IDX = 0
MAX_SLOT_IDX = 15

--- @param slot_idx integer
--- @return string
local function GetStorageKey(slot_idx)
    return 'pose_name_slot' .. slot_idx
end

--- Сохраняет позу в слот по её ID.
--- @param slot_idx integer
--- @param pose_idx integer
--- @return boolean
function SavePoseSlot(slot_idx, pose_idx)
    if slot_idx < MIN_SLOT_IDX or slot_idx > MAX_SLOT_IDX then
        log_to_console('Invalid slot index: ' .. slot_idx)
        return false
    end

    local pose = _G.StrikeAPose:get_pose(pose_idx)
    if pose == nil then
        log_to_console('Pose with ID ' .. pose_idx .. ' not found.')
        return false
    end

    local storage_key = GetStorageKey(slot_idx)
    if mod_storage_save(storage_key, pose.name) then
        poses_slots_saved[slot_idx] = pose_idx
        log_to_console('Slot ' .. slot_idx .. ' saved with pose name: ' .. pose.name)
        return true
    else
        log_to_console('Cannot save slot ' .. slot_idx .. ' to storage.', CONSOLE_MESSAGE_WARNING)
        return false
    end
end

--- @param slot_idx integer
--- @return integer|nil
function GetPoseSlot(slot_idx)
    if slot_idx < MIN_SLOT_IDX or slot_idx > MAX_SLOT_IDX then
        return nil
    end
    return poses_slots_saved[slot_idx]
end

--- @return table<integer, integer|nil>
function GetAllPoseSlots()
    local copy = {}
    for i = MIN_SLOT_IDX, MAX_SLOT_IDX do
        copy[i] = poses_slots_saved[i]
    end
    return copy
end

--- @return integer
function GetPoseSlotsCount()
    return MAX_SLOT_IDX - MIN_SLOT_IDX + 1
end

hook_event(HOOK_ON_MODS_LOADED, function()
    -- Загрузка сохранений
    local loaded_count = 0
    for i = MIN_SLOT_IDX, MAX_SLOT_IDX do
        local storage_key = GetStorageKey(i)
        if mod_storage_exists(storage_key) then
            local name = mod_storage_load(storage_key)
            if name ~= nil and name ~= "" then
                local found_id = nil
                for id, pose in ipairs(_G.StrikeAPose:list_poses()) do
                    if pose.name == name then
                        found_id = id
                        break
                    end
                end
                if found_id ~= nil then
                    poses_slots_saved[i] = found_id
                    loaded_count = loaded_count + 1
                    log_to_console('Slot ' .. i .. ' loaded with pose name: ' .. name .. ' (ID ' .. found_id .. ')')
                else
                    log_to_console('Slot ' .. i .. ' has saved pose name "' .. name .. '" but no such pose found. Slot left empty.', CONSOLE_MESSAGE_WARNING)
                    poses_slots_saved[i] = nil
                end
            else
                log_to_console('Slot ' .. i .. ' storage key exists but load returned nil/empty. Slot left empty.', CONSOLE_MESSAGE_WARNING)
                poses_slots_saved[i] = nil
            end
        else
            poses_slots_saved[i] = nil
        end
    end

    log_to_console('StrikeAPose saves loaded: ' .. loaded_count .. ' slots loaded from storage, others left empty.')
end)
