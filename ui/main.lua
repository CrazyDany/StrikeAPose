POSES_SLOTS = 10
POSES_PER_PAGE = 16
local cur_pose_slot = 0
local current_page = 0
local selected_all_pose_idx = 1
local show_panel = false

local l_trigger_hold_counter = 0

local CELL_SIZE = 64
local PANEL_MARGIN = 16
local BOTTOM_MARGIN = 16
local GAP = 8

local function get_panel_type()
    if (SelectedCellDisplayMode or 1) == 0 then
        return "rect"
    end
    return "circle"
end

local function get_cell_text_type()
    if (SelectedTextDisplayMode or 1) == 0 then
        return 'id'
    end
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
        if not m then return end

        if m.area.camera == nil then return end
        if (m.area.camera.cutscene ~= 0) then return end

        local total_poses = 0
        if _G.StrikeAPose and _G.StrikeAPose.poses then
            total_poses = #_G.StrikeAPose.poses
        end
        local num_all_pages = math.ceil(total_poses / POSES_PER_PAGE)
        if num_all_pages == 0 then
            num_all_pages = 1
        end

        if current_page > num_all_pages then current_page = num_all_pages end
        if current_page < 0 then current_page = 0 end

        local l_trig_pressed = (m.controller.buttonDown & L_TRIG) ~= 0
        local l_trig_released = (m.controller.buttonReleased & L_TRIG) ~= 0

        if l_trig_pressed then
            l_trigger_hold_counter = math.min(l_trigger_hold_counter + 1, 4)
        else
            l_trigger_hold_counter = 0
        end

        local is_held_long = l_trigger_hold_counter >= 4
        show_panel = is_held_long

        if is_held_long then
            if (m.controller.buttonPressed & U_JPAD) ~= 0 then
                if num_all_pages > 0 then
                    current_page = (current_page + 1) % (num_all_pages + 1)
                    if current_page > 0 then
                        local page_start = (current_page - 1) * POSES_PER_PAGE + 1
                        selected_all_pose_idx = page_start
                    end
                end
            end

            if (m.controller.buttonPressed & D_JPAD) ~= 0 then
                if num_all_pages > 0 then
                    current_page = (current_page - 1) % (num_all_pages + 1)
                    if current_page < 0 then current_page = num_all_pages end
                    if current_page > 0 then
                        local page_start = (current_page - 1) * POSES_PER_PAGE + 1
                        selected_all_pose_idx = page_start
                    end
                end
            end

            if (m.controller.buttonPressed & R_JPAD) ~= 0 then
                if current_page == 0 then
                    cur_pose_slot = (cur_pose_slot + 1) % POSES_SLOTS
                else
                    local page_start = (current_page - 1) * POSES_PER_PAGE + 1
                    local page_end = math.min(current_page * POSES_PER_PAGE, total_poses)
                    if selected_all_pose_idx < page_end then
                        selected_all_pose_idx = selected_all_pose_idx + 1
                    end
                end
            end

            if (m.controller.buttonPressed & L_JPAD) ~= 0 then
                if current_page == 0 then
                    cur_pose_slot = (cur_pose_slot - 1) % POSES_SLOTS
                else
                    local page_start = (current_page - 1) * POSES_PER_PAGE + 1
                    if selected_all_pose_idx > page_start then
                        selected_all_pose_idx = selected_all_pose_idx - 1
                    end
                end
            end
        end

        if l_trig_released then
            if (m.action & ACT_FLAG_AIR == 0) and (m.action & ACT_FLAG_WATER_OR_TEXT == 0) then
                local pose_id = 0
                if current_page == 0 then
                    pose_id = GetPoseSlot(cur_pose_slot) or 0
                else
                    if selected_all_pose_idx >= 1 and selected_all_pose_idx <= total_poses then
                        pose_id = selected_all_pose_idx
                    end
                end
                if pose_id ~= 0 and _G.StrikeAPose then
                    _G.StrikeAPose:apply_pose(m, pose_id)
                end
            end
            l_trigger_hold_counter = 0
        end
    end
)

hook_event(HOOK_ON_HUD_RENDER_BEHIND,
    function()
        djui_hud_set_resolution(RESOLUTION_DJUI)
        djui_hud_set_font(FONT_MENU)

        local screen_width = djui_hud_get_screen_width()
        local screen_height = djui_hud_get_screen_height()

        local total_poses = 0
        if _G.StrikeAPose and _G.StrikeAPose.poses then
            total_poses = #_G.StrikeAPose.poses
        end
        local num_all_pages = math.ceil(total_poses / POSES_PER_PAGE)
        if num_all_pages == 0 then num_all_pages = 1 end

        local current_pose_name = "Unknown"
        if current_page == 0 then
            local pose_idx = GetPoseSlot(cur_pose_slot) or 0
            local pose = _G.StrikeAPose and _G.StrikeAPose:get_pose(pose_idx)
            if pose then current_pose_name = pose.name:gsub("\n", "") end
        else
            local pose = _G.StrikeAPose and _G.StrikeAPose.poses[selected_all_pose_idx]
            if pose then current_pose_name = pose.name:gsub("\n", "") end
        end

        local text_scale = 0.5
        local page_indicator = ""
        if current_page > 0 then
            page_indicator = " (Page " .. current_page .. "/" .. num_all_pages .. ")"
        end
        local text = "Current Pose: " .. current_pose_name .. page_indicator
        local text_width = djui_hud_measure_text(text) * text_scale
        local text_x = (screen_width - text_width) / 2
        local text_y

        local panel_type = get_panel_type()
        local cell_text_type = get_cell_text_type()

        local page_size
        if current_page == 0 then
            page_size = POSES_SLOTS
        else
            page_size = POSES_PER_PAGE
        end

        if current_page > 0 then
            local remaining = total_poses - (current_page - 1) * POSES_PER_PAGE
            if remaining < page_size then
                page_size = remaining
            end
        end

        if panel_type == "rect" then
            local poses_per_line = 8
            local total_slots_width = CELL_SIZE * poses_per_line
            local panel_width = total_slots_width + GAP * (poses_per_line + 1) + 2 * PANEL_MARGIN
            local panel_x = (screen_width - panel_width) / 2

            local num_lines = math.ceil(page_size / poses_per_line)
            local line_height = CELL_SIZE + 2 * PANEL_MARGIN
            local panel_top = screen_height - BOTTOM_MARGIN - line_height * num_lines
            text_y = show_panel and (panel_top - 32) or (screen_height - BOTTOM_MARGIN - 32)

            djui_hud_set_color(255, 255, 255, 255)
            djui_hud_print_text(text, text_x, text_y, text_scale)

            if show_panel then
                for line = 0, num_lines - 1 do
                    local line_y = screen_height - BOTTOM_MARGIN - line_height * (line + 1)
                    djui_hud_set_color(0, 0, 0, 150)
                    djui_hud_render_rect(panel_x, line_y, panel_width, line_height)

                    for col = 0, poses_per_line - 1 do
                        local slot_index = line * poses_per_line + col
                        if slot_index >= page_size then break end

                        local slot_x = panel_x + PANEL_MARGIN + col * (CELL_SIZE + GAP) + GAP
                        local slot_y = line_y + PANEL_MARGIN

                        local is_selected = false
                        local pose_idx = 0
                        local display_text = ""

                        if current_page == 0 then
                            is_selected = (slot_index == cur_pose_slot)
                            pose_idx = GetPoseSlot(slot_index) or 0
                            if cell_text_type == "id" then
                                display_text = tostring(pose_idx)
                            else
                                local p = _G.StrikeAPose and _G.StrikeAPose:get_pose(pose_idx)
                                display_text = (p and p.name) or "?"
                            end
                        else
                            local global_idx = (current_page - 1) * POSES_PER_PAGE + slot_index + 1
                            if global_idx <= total_poses then
                                pose_idx = global_idx
                                local p = _G.StrikeAPose and _G.StrikeAPose.poses[global_idx]
                                is_selected = (global_idx == selected_all_pose_idx)
                                if cell_text_type == "id" then
                                    display_text = tostring(global_idx)
                                else
                                    display_text = (p and p.name) or "?"
                                end
                            end
                        end

                        if is_selected then
                            djui_hud_set_color(255, 255, 0, 255)
                        else
                            djui_hud_set_color(200, 200, 200, 255)
                        end
                        djui_hud_render_rect(slot_x, slot_y, CELL_SIZE, CELL_SIZE)

                        if display_text ~= "" then
                            djui_hud_set_color(255, 255, 255, 255)
                            local text_scale_slot = 0.4
                            draw_cell_text(slot_x, slot_y, CELL_SIZE, display_text, text_scale_slot)
                        end
                    end
                end
            end

        elseif panel_type == "circle" then
            text_y = screen_height - BOTTOM_MARGIN - 32
            djui_hud_set_color(255, 255, 255, 255)
            djui_hud_print_text(text, text_x, text_y, text_scale)

            if show_panel then
                local center_x = screen_width / 2
                local center_y = screen_height / 2
                local radius = math.min(screen_width, screen_height) / 3.2

                local panel_size = 2 * radius + CELL_SIZE + 2 * PANEL_MARGIN
                local panel_x = center_x - panel_size / 2
                local panel_y = center_y - panel_size / 2

                local pose_circle = get_texture_info("pose_circle")
                djui_hud_set_color(0, 0, 0, 150)
                djui_hud_render_texture(pose_circle, panel_x, panel_y, 0.7144 * panel_size/731.625, 0.7144 * panel_size/731.625)

                for i = 0, page_size - 1 do
                    local angle = (i / page_size) * 2 * math.pi - math.pi / 2
                    local x = center_x + radius * math.cos(angle) - CELL_SIZE / 2
                    local y = center_y + radius * math.sin(angle) - CELL_SIZE / 2

                    local is_selected = false
                    local pose_idx = 0
                    local display_text = ""

                    if current_page == 0 then
                        is_selected = (i == cur_pose_slot)
                        pose_idx = GetPoseSlot(i) or 0
                        if cell_text_type == "id" then
                            display_text = tostring(pose_idx)
                        else
                            local p = _G.StrikeAPose and _G.StrikeAPose:get_pose(pose_idx)
                            display_text = (p and p.name) or "?"
                        end
                    else
                        local global_idx = (current_page - 1) * POSES_PER_PAGE + i + 1
                        if global_idx <= total_poses then
                            pose_idx = global_idx
                            local p = _G.StrikeAPose and _G.StrikeAPose.poses[global_idx]
                            is_selected = (global_idx == selected_all_pose_idx)
                            if cell_text_type == "id" then
                                display_text = tostring(global_idx)
                            else
                                display_text = (p and p.name) or "?"
                            end
                        end
                    end

                    if is_selected then
                        djui_hud_set_color(255, 255, 0, 255)
                    else
                        djui_hud_set_color(200, 200, 200, 255)
                    end
                    djui_hud_render_rect(x, y, CELL_SIZE, CELL_SIZE)

                    if display_text ~= "" then
                        djui_hud_set_color(255, 255, 255, 255)
                        local text_scale_slot = 0.4
                        draw_cell_text(x, y - 4, CELL_SIZE, display_text, text_scale_slot)
                    end
                end
            end
        end
    end
)