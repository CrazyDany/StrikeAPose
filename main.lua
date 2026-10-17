-- name: \\#99BBEE\\Strike-A-Pose!
-- description: \\#99BBEE\\Strike-A-Pose!\n\n\\#FFFFFF\\Mod that allows you to use poses and dances during the game, regardless of the selected character with a user-friendly interface. \n\nPress the \\#FFC401\\L-Trig\\#FFFFFF\\ to use selected pose. \nHold the \\#FFC401\\L-Trig\\#FFFFFF\\ and press \\#FFC401\\DPAD Right/Left\\#FFFFFF\\ to select pose slot and then release \\#FFC401\\L-Trig\\#FFFFFF\\ to use it.
-- github: https://github.com/CrazyDany/StrikeAPose

if not mod_storage_exists("sap_hide_current_text") then
    mod_storage_save_bool("sap_hide_current_text", false)
end

SAP_HideCurrentText = mod_storage_load_bool("sap_hide_current_text") or false