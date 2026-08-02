-- name: StrikeAPose
-- description: allows player do their favourite poses and dances
-- github: https://github.com/CrazyDany/StrikeAPose

hook_mod_menu_text("Customize your mod HUD!")

SelectedCellDisplayMode = 1
local function on_set_cell_display_mode(index, value)
    SelectedCellDisplayMode = value
end

hook_mod_menu_slider("Cells display mode", 1, 0, 1, on_set_cell_display_mode)
hook_mod_menu_text("0 - Rectangle | 1 - Circle")


SelectedTextDisplayMode = 1
local function on_set_text_display_mode(index, value)
    SelectedTextDisplayMode = value
end

hook_mod_menu_slider("Cells text mode", 1, 0, 1, on_set_text_display_mode)
hook_mod_menu_text("0 - ID | 1 - Name")