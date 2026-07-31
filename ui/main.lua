POSES_SLOTS = 16
local cur_pose_slot = 0
local show_panel = false

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
        local panel_margin = 8
        local panel_x = panel_margin

        local panel_width = djui_hud_get_screen_width() - panel_margin * 2
        local slot_size = math.floor(panel_width * 0.05)
        local line_height = slot_size + 2 * panel_margin

        local num_lines = POSES_SLOTS / poses_per_line
        local screen_height = djui_hud_get_screen_height()
        local screen_width = djui_hud_get_screen_width()
        local bottom_margin = panel_margin

        local panel_top = screen_height - bottom_margin - line_height * num_lines

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
            text_y = screen_height - bottom_margin - 32
        end

        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_print_text(text, text_x, text_y, text_scale)

        if show_panel then
            for line = 0, num_lines - 1 do
                local line_y = screen_height - bottom_margin - line_height * (line + 1)

                djui_hud_set_color(0, 0, 0, 255)
                djui_hud_render_rect(panel_x, line_y, panel_width, line_height)

                local total_slots_width = slot_size * poses_per_line
                local gap = (panel_width - total_slots_width) / (poses_per_line + 1)

                for slot = 0, poses_per_line - 1 do
                    local slot_index = line * poses_per_line + slot
                    local slot_x = panel_x + gap + slot * (slot_size + gap)
                    local slot_y = line_y + panel_margin

                    if slot_index == cur_pose_slot then
                        djui_hud_set_color(255, 255, 0, 255)
                    else
                        djui_hud_set_color(200, 200, 200, 255)
                    end
                    djui_hud_render_rect(slot_x, slot_y, slot_size, slot_size)
                end
            end
        end
    end
)