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

local ui_time = 0
local panel_alpha = 0
local panel_slide = 0
local page_slide_y = 0
local open_t = 0
local selection_anim = 0
local SELECTION_ANIM_MAX = 15
local last_selection_key = nil
local was_show_panel = false

local RIPPLE_DELAY_PER_CELL = 0.6
local RIPPLE_FADE_FRAMES = 5
local PAGE_SLIDE_AMOUNT = 40

local CIRCLE_HOP_HEIGHT = 12
local CIRCLE_HOP_FRAMES = 14

local COL_PANEL_BG = { 22, 24, 32, 210 }
local COL_PANEL_BORDER = { 120, 130, 160, 180 }
local COL_CELL_NORMAL = { 90, 100, 125, 245 }
local COL_CELL_SELECTED = { 255, 165, 30, 255 }
local COL_CELL_EMPTY = { 30, 30, 38, 180 }
local COL_CELL_BORDER = { 12, 12, 16, 160 }
local COL_TEXT_WHITE = { 255, 255, 255, 255 }

local function set_color(c, alpha_mul, rgb_mul)
    alpha_mul = alpha_mul or 1
    rgb_mul = rgb_mul or 1
    local r = math.min(255, math.floor(c[1] * rgb_mul))
    local g = math.min(255, math.floor(c[2] * rgb_mul))
    local b = math.min(255, math.floor(c[3] * rgb_mul))
    local a = math.max(0, math.min(255, math.floor(c[4] * alpha_mul)))
    djui_hud_set_color(r, g, b, a)
end

local function is_slot_set(i)
    local id = GetPoseSlot(i)
    return id ~= nil and id ~= 0
end

local function find_next_set_slot(from)
    for step = 1, POSES_SLOTS do
        local i = (from + step) % POSES_SLOTS
        if is_slot_set(i) then return i end
    end
    return nil
end

local function find_prev_set_slot(from)
    for step = 1, POSES_SLOTS do
        local i = (from - step) % POSES_SLOTS
        if is_slot_set(i) then return i end
    end
    return nil
end

local function draw_text(text, x, y, scale, c, alpha_mul)
    set_color(c or COL_TEXT_WHITE, alpha_mul)
    djui_hud_print_text(text, x, y, scale)
end

local function draw_text_centered(text, center_x, y, scale, c, alpha_mul)
    local w = djui_hud_measure_text(text) * scale
    draw_text(text, center_x - w / 2, y, scale, c or COL_TEXT_WHITE, alpha_mul)
end

local function draw_cell_text(x, y, cell_size, text, scale, c, alpha_mul)
    local lines = {}
    for line in string.gmatch(text, "([^\n]+)") do
        table.insert(lines, line)
    end
    if #lines == 0 then lines = {""} end

    local line_widths = {}
    local line_height = djui_hud_measure_text("o") * scale
    for i, line in ipairs(lines) do
        line_widths[i] = djui_hud_measure_text(line) * scale
    end
    local total_height = #lines * line_height

    local center_x = x + cell_size / 2
    local center_y = y + cell_size / 2

    set_color(c or COL_TEXT_WHITE, alpha_mul)
    for i, line in ipairs(lines) do
        local lx = center_x - line_widths[i] / 2
        local ly = center_y - total_height / 2 + (i - 1) * line_height
        djui_hud_print_text(line, lx, ly, scale)
    end
end

local function draw_cell(x, y, size, state, display_text, text_scale, alpha_mul, sel_pop)
    alpha_mul = alpha_mul or 1
    sel_pop = sel_pop or 0

    if state == "selected" then
        local pulse = 0.5 + 0.5 * math.sin(ui_time * 0.12)

        if sel_pop > 0.01 then
            local expand = 4 + sel_pop * 22
            local a = math.floor(160 * sel_pop * alpha_mul)
            djui_hud_set_color(255, 200, 80, a)
            djui_hud_render_rect(x - expand, y - expand,
                size + expand * 2, size + expand * 2)
        end

        local brightness = 0.90 + pulse * 0.14 + sel_pop * 0.15
        set_color(COL_CELL_SELECTED, alpha_mul, brightness)
        djui_hud_render_rect(x, y, size, size)

        local border_a = math.floor((0.75 + pulse * 0.25) * 255 * alpha_mul)
        djui_hud_set_color(255, 255, 255, border_a)
        djui_hud_render_rect(x, y, size, 2)
        djui_hud_render_rect(x, y + size - 2, size, 2)
        djui_hud_render_rect(x, y, 2, size)
        djui_hud_render_rect(x + size - 2, y, 2, size)

    elseif state == "empty" then
        set_color(COL_CELL_EMPTY, alpha_mul)
        djui_hud_render_rect(x, y, size, size)

        set_color(COL_CELL_BORDER, alpha_mul)
        djui_hud_render_rect(x, y, size, 1)
        djui_hud_render_rect(x, y + size - 1, size, 1)
        djui_hud_render_rect(x, y, 1, size)
        djui_hud_render_rect(x + size - 1, y, 1, size)

    else
        set_color(COL_CELL_NORMAL, alpha_mul)
        djui_hud_render_rect(x, y, size, size)

        set_color(COL_CELL_BORDER, alpha_mul)
        djui_hud_render_rect(x, y, size, 1)
        djui_hud_render_rect(x, y + size - 1, size, 1)
        djui_hud_render_rect(x, y, 1, size)
        djui_hud_render_rect(x + size - 1, y, 1, size)
    end

    if state == "empty" then return end
    if display_text == nil or display_text == "" then return end

    draw_cell_text(x, y, size, display_text, text_scale, COL_TEXT_WHITE, alpha_mul)
end

local function cell_display_name(pose_idx)
    local p = _G.StrikeAPose and _G.StrikeAPose:get_pose(pose_idx)
    return (p and p.name) or "?"
end

local function page_bounds(page, total)
    local start_i = (page - 1) * POSES_PER_PAGE + 1
    local end_i   = math.min(page * POSES_PER_PAGE, total)
    return start_i, end_i
end

local function selection_key()
    if current_page == 0 then
        return "0:" .. cur_pose_slot
    end
    return current_page .. ":" .. selected_all_pose_idx
end

local function ripple_alpha(i)
    local a = (open_t - i * RIPPLE_DELAY_PER_CELL) / RIPPLE_FADE_FRAMES
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    return a
end

local function circle_hop(i)
    local t = (open_t - i * RIPPLE_DELAY_PER_CELL) / CIRCLE_HOP_FRAMES
    if t <= 0 or t >= 1 then return 0 end
    return math.sin(t * math.pi) * CIRCLE_HOP_HEIGHT
end

hook_event(HOOK_UPDATE, function()
    ui_time = ui_time + 1

    --- @type MarioState
    local m = gMarioStates[0]
    if not m then return end
    if m.area.camera == nil then return end
    if m.area.camera.cutscene ~= 0 then return end
    if m.action == ACT_IN_CANNON then return end

    local total_poses = 0
    if _G.StrikeAPose and _G.StrikeAPose.poses then
        total_poses = #_G.StrikeAPose.poses
    end
    local num_all_pages = math.ceil(total_poses / POSES_PER_PAGE)
    if num_all_pages == 0 then num_all_pages = 1 end

    if current_page > num_all_pages then current_page = num_all_pages end
    if current_page < 0 then current_page = 0 end

    if current_page == 0 and not is_slot_set(cur_pose_slot) then
        local found = find_next_set_slot(cur_pose_slot)
        if found then cur_pose_slot = found end
    end

    local l_trig_pressed  = (m.controller.buttonDown & L_TRIG) ~= 0
    local l_trig_released = (m.controller.buttonReleased & L_TRIG) ~= 0

    if l_trig_pressed then
        l_trigger_hold_counter = math.min(l_trigger_hold_counter + 1, 4)
    else
        l_trigger_hold_counter = 0
    end

    local is_held_long = l_trigger_hold_counter >= 4
    show_panel = is_held_long

    if show_panel then
        panel_alpha = math.min(1, panel_alpha + 0.18)
    else
        panel_alpha = math.max(0, panel_alpha - 0.18)
    end
    panel_slide = (1 - panel_alpha) * 24

    if show_panel and not was_show_panel then
        open_t = 0
        selection_anim = SELECTION_ANIM_MAX
    end
    if show_panel then
        open_t = open_t + 1
    end
    was_show_panel = show_panel

    if math.abs(page_slide_y) < 0.5 then
        page_slide_y = 0
    else
        page_slide_y = page_slide_y * 0.78
    end

    local page_before = current_page

    if is_held_long then
        if (m.controller.buttonPressed & U_JPAD) ~= 0 then
            current_page = (current_page + 1) % (num_all_pages + 1)
            if current_page > 0 then
                local ps = (current_page - 1) * POSES_PER_PAGE + 1
                if ps > total_poses then ps = math.max(1, total_poses) end
                selected_all_pose_idx = ps
            end
        end

        if (m.controller.buttonPressed & D_JPAD) ~= 0 then
            current_page = (current_page - 1) % (num_all_pages + 1)
            if current_page < 0 then current_page = num_all_pages end
            if current_page > 0 then
                local ps = (current_page - 1) * POSES_PER_PAGE + 1
                if ps > total_poses then ps = math.max(1, total_poses) end
                selected_all_pose_idx = ps
            end
        end

        if (m.controller.buttonPressed & R_JPAD) ~= 0 then
            if current_page == 0 then
                local nxt = find_next_set_slot(cur_pose_slot)
                if nxt then cur_pose_slot = nxt end
            else
                local ps, pe = page_bounds(current_page, total_poses)
                local len = pe - ps + 1
                if len > 0 then
                    local local_idx = selected_all_pose_idx - ps
                    if local_idx < 0 or local_idx >= len then local_idx = 0 end
                    local_idx = (local_idx + 1) % len
                    selected_all_pose_idx = ps + local_idx
                end
            end
        end

        if (m.controller.buttonPressed & L_JPAD) ~= 0 then
            if current_page == 0 then
                local prv = find_prev_set_slot(cur_pose_slot)
                if prv then cur_pose_slot = prv end
            else
                local ps, pe = page_bounds(current_page, total_poses)
                local len = pe - ps + 1
                if len > 0 then
                    local local_idx = selected_all_pose_idx - ps
                    if local_idx < 0 or local_idx >= len then local_idx = 0 end
                    local_idx = (local_idx - 1 + len) % len
                    selected_all_pose_idx = ps + local_idx
                end
            end
        end
    end

    if current_page ~= page_before then
        if current_page > page_before then
            page_slide_y = PAGE_SLIDE_AMOUNT
        else
            page_slide_y = -PAGE_SLIDE_AMOUNT
        end
    end

    local sk = selection_key()
    if sk ~= last_selection_key then
        last_selection_key = sk
        selection_anim = SELECTION_ANIM_MAX
    end
    if selection_anim > 0 then
        selection_anim = selection_anim - 1
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
end)

hook_event(HOOK_ON_HUD_RENDER_BEHIND, function()
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_MENU)

    local screen_width  = djui_hud_get_screen_width()
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

    local page_size
    if current_page == 0 then
        page_size = POSES_SLOTS
    else
        page_size = POSES_PER_PAGE
        local remaining = total_poses - (current_page - 1) * POSES_PER_PAGE
        if remaining < page_size then page_size = remaining end
        if page_size < 0 then page_size = 0 end
    end

    if not SAP_HideCurrentText then
        local text_scale = 0.5
        local text = "Current Pose: " .. current_pose_name
        local text_y = screen_height - BOTTOM_MARGIN - 32
        draw_text_centered(text, screen_width / 2, text_y, text_scale, COL_TEXT_WHITE, 1)
    end

    if panel_alpha <= 0.01 then return end

    local sel_pop = 0
    if selection_anim > 0 then
        sel_pop = math.sin((1 - selection_anim / SELECTION_ANIM_MAX) * math.pi)
    end

    do
        local ind_text
        if current_page == 0 then
            ind_text = string.format("Slot %d / %d", cur_pose_slot + 1, POSES_SLOTS)
        else
            local ps, pe = page_bounds(current_page, total_poses)
            local local_idx = selected_all_pose_idx - ps + 1
            local len = pe - ps + 1
            if len < 0 then len = 0 end
            ind_text = string.format("Pose %d/%d  |  Page %d/%d",
                local_idx, len, current_page, num_all_pages)
        end
        local ind_scale = 0.4
        local ind_w = djui_hud_measure_text(ind_text) * ind_scale
        draw_text(ind_text, screen_width - ind_w - 16, 16, ind_scale,
            COL_TEXT_WHITE, panel_alpha)
    end

    local center_x = screen_width / 2
    local center_y = screen_height / 2 + page_slide_y

    if page_size > 0 then
        local radius = math.min(screen_width, screen_height) / 3.2
        local panel_size = 2 * radius + CELL_SIZE + 2 * PANEL_MARGIN
        local panel_x = center_x - panel_size / 2
        local panel_y = center_y - panel_size / 2

        local pose_circle = get_texture_info("pose_circle")
        set_color(COL_PANEL_BG, panel_alpha)
        djui_hud_render_texture(pose_circle,
            panel_x, panel_y,
            0.7144 * panel_size / 731.625,
            0.7144 * panel_size / 731.625)

        for i = 0, page_size - 1 do
            local angle  = (i / page_size) * 2 * math.pi - math.pi / 2
            local cell_x = center_x + radius * math.cos(angle) - CELL_SIZE / 2
            local cell_y = center_y + radius * math.sin(angle) - CELL_SIZE / 2

            local hop = circle_hop(i)
            cell_y = cell_y - hop

            local state = "normal"
            local display_text = ""

            if current_page == 0 then
                local pose_idx = GetPoseSlot(i) or 0
                if pose_idx == 0 then
                    state = "empty"
                else
                    if i == cur_pose_slot then state = "selected" end
                    display_text = cell_display_name(pose_idx)
                end
            else
                local global_idx = (current_page - 1) * POSES_PER_PAGE + i + 1
                if global_idx <= total_poses then
                    if global_idx == selected_all_pose_idx then state = "selected" end
                    display_text = cell_display_name(global_idx)
                end
            end

            local cell_alpha = panel_alpha * ripple_alpha(i)
            if cell_alpha > 0.01 then
                draw_cell(cell_x, cell_y, CELL_SIZE, state, display_text,
                    0.4, cell_alpha, sel_pop)
            end
        end
    end
end)