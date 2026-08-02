--- @type table<integer, integer>
local poses_slots_saved = {}

MIN_SLOT_IDX = 0
MAX_SLOT_IDX = 15

--- @param slot_idx integer
--- @return string
local function GetStorageKey(slot_idx)
    return 'pose_slot' .. slot_idx
end

--- @param slot_idx integer
--- @param pose_idx integer
--- @return boolean
function SavePoseSlot(slot_idx, pose_idx)
    if slot_idx < MIN_SLOT_IDX or slot_idx > MAX_SLOT_IDX then
        log_to_console('Invalid slot index: ' .. slot_idx)
        return false
    end
    local storage_key = GetStorageKey(slot_idx)
    poses_slots_saved[slot_idx] = pose_idx
    if mod_storage_save_number(storage_key, pose_idx) then
        log_to_console('Slot ' .. slot_idx .. ' saved to storage with pose ' .. pose_idx)
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

--- @return table<integer, integer>
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

local loaded_count = 0
for i = MIN_SLOT_IDX, MAX_SLOT_IDX do
    local storage_key = GetStorageKey(i)
    if mod_storage_exists(storage_key) then
        local value = mod_storage_load(storage_key)
        if value ~= nil then
            poses_slots_saved[i] = math.floor(value)
            loaded_count = loaded_count + 1
            log_to_console('Slot ' .. i .. ' loaded with pose ' .. value)
        else
            log_to_console('Warning: storage key ' .. storage_key .. ' exists but load returned nil. Setting default.', CONSOLE_MESSAGE_WARNING)
            SavePoseSlot(i, i)
        end
    else
        SavePoseSlot(i, i)
    end
end

log_to_console('StrikeAPose saves loaded: ' .. loaded_count .. ' slots loaded from storage, defaults set for others.')