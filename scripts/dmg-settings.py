# dmgbuild settings for Glimmer's drag-to-install disk image.
# Used by scripts/make-dmg.sh:  dmgbuild -s scripts/dmg-settings.py -D app=… "Glimmer" out.dmg
#
# Lays out the Finder window without scripting Finder: custom background with an arrow,
# big icons, no toolbar/sidebar/status bar, Glimmer on the left, Applications on the right.

app = defines.get("app", "build/Glimmer.app")  # noqa: F821 (provided by dmgbuild)

format = "UDZO"
filesystem = "HFS+"
size = None

files = [app]
symlinks = {"Applications": "/Applications"}
icon = "Resources/AppIcon.icns"          # volume icon

background = "Resources/dmg-background.tiff"
window_rect = ((240, 160), (660, 428))   # 400-pt background + 28-pt title bar
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 0
show_icon_preview = False

arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
label_pos = "bottom"
text_size = 13
icon_size = 112
icon_locations = {
    "Glimmer.app": (165, 200),
    "Applications": (495, 200),
}

hide_extensions = ["Glimmer.app"]
