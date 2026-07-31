POSES_SLOTS = 16
local cur_pose_slot = 0
local show_panel = false

local CELL_SIZE = 64
local PANEL_MARGIN = 16
local BOTTOM_MARGIN = 16
local GAP = 8

hook_event(HOOK_UPDATE,
    function()
        local m = gMarioStates[0]

        if (m.controller.buttonDown & L_TRIG) ~= 0 then
            if (m.controller.buttonPressed & R_JPAD) ~= 0 then
                cur_pose_slot = (cur_pose_slot + 1) % POSES_SLOTS
                djui_chat_message_create('Selected pose -> ' .. cur_pose_slot)
            end

            if (m.controller.buttonPressed & L_JPAD) ~= 0 then
                cur_pose_slot = (cur_pose_slot - 1) % POSES_SLOTS
                djui_chat_message_create('Selected pose -> ' .. cur_pose_slot)
            end
        end

        show_panel = (m.controller.buttonDown & L_TRIG) ~= 0

        if (m.controller.buttonReleased & L_TRIG) ~= 0 then
            djui_chat_message_create('Pose: ' .. cur_pose_slot)
            _G.StrikeAPose:apply_pose(gMarioStates[0], cur_pose_slot)
        end
    end
)

hook_event(HOOK_ON_HUD_RENDER_BEHIND,
    function()
        djui_hud_set_resolution(RESOLUTION_DJUI)
        djui_hud_set_font(FONT_MENU)

        local poses_per_line = 8
        local screen_width = djui_hud_get_screen_width()
        local screen_height = djui_hud_get_screen_height()

        local total_slots_width = CELL_SIZE * poses_per_line
        local panel_width = total_slots_width + GAP * (poses_per_line + 1) + 2 * PANEL_MARGIN

        -- *** Главное изменение: панель теперь по центру ***
        local panel_x = (screen_width - panel_width) / 2

        local line_height = CELL_SIZE + 2 * PANEL_MARGIN
        local num_lines = POSES_SLOTS / poses_per_line
        local panel_top = screen_height - BOTTOM_MARGIN - line_height * num_lines

        -- Текст с названием позы
        local pose = _G.StrikeAPose:get_pose(cur_pose_slot)
        local text_scale = 0.5
        local pose_name = pose and pose.name or "Unknown"
        local text = "Current Pose: " .. pose_name
        local text_width = djui_hud_measure_text(text) * text_scale
        local text_x = (screen_width - text_width) / 2
        local text_y
        if show_panel then
            text_y = panel_top - 32
        else
            text_y = screen_height - BOTTOM_MARGIN - 32
        end

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
                end
            end
        end
    end
)