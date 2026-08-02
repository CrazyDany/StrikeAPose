POSES_SLOTS = 16
local cur_pose_slot = 0
local show_panel = false

local CELL_SIZE = 64
local PANEL_MARGIN = 16
local BOTTOM_MARGIN = 16
local GAP = 8

local function get_panel_type()
    return "circle"
end

local function get_cell_text_type()
    return "name"
end

local function draw_cell_text(x, y, cell_size, text, scale)
    local lines = {}
    for line in string.gmatch(text, "([^\n]+)") do
        table.insert(lines, line)
    end
    if #lines == 0 then
        lines = {""}
    end

    local line_widths = {}
    local max_width = 0
    local line_height = djui_hud_measure_text("o") * scale
    for i, line in ipairs(lines) do
        local w = djui_hud_measure_text(line) * scale
        line_widths[i] = w
        if w > max_width then max_width = w end
    end
    local total_height = #lines * line_height

    local center_x = x + cell_size / 2
    local center_y = y + cell_size / 2

    for i, line in ipairs(lines) do
        local lx = center_x - line_widths[i] / 2
        local ly = center_y - total_height / 2 + (i - 1) * line_height
        djui_hud_print_text(line, lx, ly, scale)
    end
end

hook_event(HOOK_UPDATE,
    function()
        --- @type MarioState
        local m = gMarioStates[0]

        if (m.controller.buttonDown & L_TRIG) ~= 0 then
            if (m.controller.buttonPressed & R_JPAD) ~= 0 then
                cur_pose_slot = (cur_pose_slot + 1) % POSES_SLOTS
            end

            if (m.controller.buttonPressed & L_JPAD) ~= 0 then
                cur_pose_slot = (cur_pose_slot - 1) % POSES_SLOTS
            end
        end

        show_panel = (m.controller.buttonDown & L_TRIG) ~= 0

        if (m.controller.buttonReleased & L_TRIG) ~= 0 then
            if (m.action & ACT_FLAG_AIR) ~= 0 then return end
            local pose_idx = GetPoseSlot(cur_pose_slot) or 0
            djui_chat_message_create('Pose: ' .. pose_idx)
            _G.StrikeAPose:apply_pose(gMarioStates[0], pose_idx)
        end
    end
)

hook_event(HOOK_ON_HUD_RENDER_BEHIND,
    function()
        djui_hud_set_resolution(RESOLUTION_DJUI)
        djui_hud_set_font(FONT_MENU)

        local screen_width = djui_hud_get_screen_width()
        local screen_height = djui_hud_get_screen_height()

        -- Текст с именем текущей позы
        local pose = _G.StrikeAPose:get_pose(GetPoseSlot(cur_pose_slot) or 0)
        local text_scale = 0.5
        local pose_name = pose and pose.name or "Unknown"
        local text = "Current Pose: " .. pose_name
        local text_width = djui_hud_measure_text(text) * text_scale
        local text_x = (screen_width - text_width) / 2
        local text_y

        local panel_type = get_panel_type()
        local cell_text_type = get_cell_text_type()

        if panel_type == "rect" then
            local poses_per_line = 8
            local total_slots_width = CELL_SIZE * poses_per_line
            local panel_width = total_slots_width + GAP * (poses_per_line + 1) + 2 * PANEL_MARGIN
            local panel_x = (screen_width - panel_width) / 2

            local line_height = CELL_SIZE + 2 * PANEL_MARGIN
            local num_lines = POSES_SLOTS / poses_per_line
            local panel_top = screen_height - BOTTOM_MARGIN - line_height * num_lines

            text_y = show_panel and (panel_top - 32) or (screen_height - BOTTOM_MARGIN - 32)

            djui_hud_set_color(255, 255, 255, 255)
            djui_hud_print_text(text, text_x, text_y, text_scale)

            if show_panel then
                for line = 0, num_lines - 1 do
                    local line_y = screen_height - BOTTOM_MARGIN - line_height * (line + 1)

                    djui_hud_set_color(0, 0, 0, 150)
                    djui_hud_render_rect(panel_x, line_y, panel_width, line_height)

                    for slot = 0, poses_per_line - 1 do
                        local slot_index = line * poses_per_line + slot
                        local slot_x = panel_x + PANEL_MARGIN + slot * (CELL_SIZE + GAP) + GAP
                        local slot_y = line_y + PANEL_MARGIN

                        if slot_index == cur_pose_slot then
                            djui_hud_set_color(255, 255, 0, 255)
                        else
                            djui_hud_set_color(200, 200, 200, 255)
                        end
                        djui_hud_render_rect(slot_x, slot_y, CELL_SIZE, CELL_SIZE)

                        local pose_idx = GetPoseSlot(slot_index) or 0
                        local display_text
                        if cell_text_type == "id" then
                            display_text = tostring(pose_idx)
                        elseif cell_text_type == "name" then
                            local p = _G.StrikeAPose:get_pose(pose_idx)
                            display_text = (p and p.name) or "?"
                        else
                            display_text = tostring(pose_idx)
                        end

                        djui_hud_set_color(255, 255, 255, 255)
                        local text_scale_slot = 0.4
                        draw_cell_text(slot_x, slot_y, CELL_SIZE, display_text, text_scale_slot)
                    end
                end
            end

        elseif panel_type == "circle" then
            text_y = show_panel and 32 or (screen_height - BOTTOM_MARGIN - 32)

            djui_hud_set_color(255, 255, 255, 255)
            djui_hud_print_text(text, text_x, text_y, text_scale)

            if show_panel then
                local center_x = screen_width / 2
                local center_y = screen_height / 2

                local radius = math.min(screen_width, screen_height) / 3.2

                local panel_size = 2 * radius + CELL_SIZE + 2 * PANEL_MARGIN
                local panel_x = center_x - panel_size / 2
                local panel_y = center_y - panel_size / 2

                djui_hud_set_color(0, 0, 0, 150)
                djui_hud_render_rect(panel_x, panel_y, panel_size, panel_size)

                for slot_index = 0, POSES_SLOTS - 1 do
                    local angle = (slot_index / POSES_SLOTS) * 2 * math.pi - math.pi / 2
                    local x = center_x + radius * math.cos(angle) - CELL_SIZE / 2
                    local y = center_y + radius * math.sin(angle) - CELL_SIZE / 2

                    if slot_index == cur_pose_slot then
                        djui_hud_set_color(255, 255, 0, 255)
                    else
                        djui_hud_set_color(200, 200, 200, 255)
                    end
                    djui_hud_render_rect(x, y, CELL_SIZE, CELL_SIZE)

                    local pose_idx = GetPoseSlot(slot_index) or 0
                    local display_text
                    if cell_text_type == "id" then
                        display_text = tostring(pose_idx)
                    elseif cell_text_type == "name" then
                        local p = _G.StrikeAPose:get_pose(pose_idx)
                        display_text = (p and p.name) or "?"
                    else
                        display_text = tostring(pose_idx)
                    end

                    djui_hud_set_color(255, 255, 255, 255)
                    local text_scale_slot = 0.4
                    draw_cell_text(x, y - 4, CELL_SIZE, display_text, text_scale_slot)
                end
            end
        end
    end
)