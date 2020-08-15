#include "lib/enums/GVB.cpp"

const array<string> editor_tabs = {"Select", "Tiles", "Props", "Entities", "Triggers", "Camera", "Emitters", "Level Settings", "Scripts", "Help"};

const int BACKGROUND_COLOUR = 0x35302A;
const int MENU_ITEM_WIDTH = 60;
const float HUD_WIDTH = 1600.0;
const float HUD_HEIGHT = 900.0;
const float HUD_WIDTH_HALF = HUD_WIDTH / 2.0;
const float HUD_HEIGHT_HALF = HUD_HEIGHT / 2.0;

class script {
    Menu menu;

    void editor_step() {
        menu.editor_step();
    }

    void editor_draw(float sub_frame) {
        menu.editor_draw(sub_frame);
    }
}

class Menu : callback_base {
    scene@ g;
    editor_api@ e;

    sprites@ spr;

    array<MenuColumn@> columns;

    bool mouse_in_gui = true;
    float hud_scale;
    int selected_ix, selected_iy;
    string selected_tab_name;
    int mouse_ix, mouse_iy;
    float visibility_timer = 1.9;

    Menu() {
        @g = get_scene();
        @e = get_editor_api();
        e.hide_gui(false);

        @spr = create_sprites();

        for (int ix=0; ix<10; ++ix) {
            columns.insertLast(MenuColumn(spr, ix));
        }

        add_tab(0, "Select", "editor", "selecticon");
        add_tab(1, "Tiles", "editor", "tilesicon");
        add_tab(2, "Props", "editor", "propsicon");
        add_tab(3, "Entities", "editor", "entityicon");
        add_tab(4, "Triggers", "editor", "triggersicon");
        add_tab(5, "Camera", "editor", "cameraicon");
        add_tab(6, "Emitters", "editor", "emittericon");
        add_tab(7, "Level Settings", "editor", "settingsicon");
        add_tab(8, "Scripts", "dustmod", "scripticon");
        add_tab(9, "Help", "editor", "helpicon");

        add_broadcast_receiver("EditorMenu.RegisterTab", this, "register_tab");
    }

    void register_tab(string, message@ msg) {
        string error = "";

        string name;
        if (not msg.has_string("name") or msg.get_string("name") == "") {
            error += "\nNo tab name";
        } else {
            name = msg.get_string("name");
        }

        int ix;
        if (not msg.has_int("ix")) {
            error += "\nNo column index";
        } else {
            ix = msg.get_int("ix");
            if (ix < 0 or columns.size() <= ix) {
                error += "\nInvalid column index";
            }
        }

        string icon = msg.has_string("icon") ? msg.get_string("icon") : "";

        if (error == "") {
            add_tab(ix, name, "script", icon);
        } else {
            puts("Failed to add editor menu tab:" + error);
        }
    }

    void add_tab(int ix, string name, string sprite_set, string sprite_name) {
        spr.add_sprite_set(sprite_set);
        columns[ix].add_tab(name, sprite_name);
    }

    void editor_step() {
        hud_scale = HUD_WIDTH / g.hud_screen_width(false);
        mouse_ix = floor(g.mouse_x_hud(0, false)) / MENU_ITEM_WIDTH + 5;
        mouse_iy = floor((g.mouse_y_hud(0, true) + HUD_HEIGHT_HALF) / hud_scale) / MENU_ITEM_WIDTH;

        for (int ix=0; ix<columns.size(); ++ix) {
            columns[ix].step(mouse_ix, mouse_iy);
        }

        if (e.key_check_pressed_gvb(GVB::LeftClick)) {
            select_tab(mouse_ix, mouse_iy);
        }

        if (e.mouse_in_gui() or mouse_in_menu()) {
            if (not mouse_in_gui) {
                mouse_in_gui = true;
                if (selected_tab_name != "") disable_tab_tool(selected_tab_name);
            }
            visibility_timer = min(1.9, visibility_timer + 0.1);
            if (visibility_timer > 1) visibility_timer = 1.9;
        } else {
            if (mouse_in_gui) {
                mouse_in_gui = false;
                if (selected_tab_name != "") enable_tab_tool(selected_tab_name);
            }
            visibility_timer = max(0, visibility_timer - 0.1);
        }
    }

    void expand_columns() {
        for (int ix=0; ix<columns.size(); ++ix) {
            columns[ix].expanded = mouse_ix == ix and columns[ix].mouse_in_column(mouse_iy);
        }
    }

    bool mouse_in_menu() {
        return 0 <= mouse_ix and mouse_ix < columns.size() and columns[mouse_ix].mouse_in_column(mouse_iy);
    }

    void select_tab(int ix, int iy) {
        const string new_selected_tab_name = get_tab_name(ix, iy);
        if (new_selected_tab_name != "" and columns[ix].expanded) {
            if (selected_tab_name != "") {
                columns[selected_ix].deselect_tab(selected_iy);
            }

            e.hide_gui(iy != 0);
            e.editor_tab(editor_tabs[ix]);
            columns[ix].select_tab(iy);
            selected_ix = ix;
            selected_iy = iy;
            selected_tab_name = new_selected_tab_name;
        }
    }

    void enable_tab_tool(string tab_name) {
        message@ msg = create_message();
        broadcast_message("EditorMenu.EnableTab." + tab_name, msg);
    }

    void disable_tab_tool(string tab_name) {
        message@ msg = create_message();
        broadcast_message("EditorMenu.DisableTab." + tab_name, msg);
    }

    string get_tab_name(int ix, int iy) {
        if (ix < 0 or columns.size() <= ix) return "";
        return columns[ix].get_tab_name(iy);
    }

    void editor_draw(float sub_frame) {
        for (int ix=0; ix<columns.size(); ++ix) {
            columns[ix].draw(selected_iy != 0, min(1.0, visibility_timer), hud_scale);
        }
    }
}

class MenuColumn {
    sprites@ spr;

    int ix;
    bool expanded = false;
    bool selected = false;
    array<MenuItem@> items;

    MenuColumn(sprites@ spr, int ix) {
        @this.spr = spr;
        this.ix = ix;
    }

    void add_tab(string name, string sprite_name) {
        items.insertLast(MenuItem(spr, name, sprite_name));
    }

    bool mouse_in_column(int mouse_iy) {
        return (expanded and 0 <= mouse_iy and mouse_iy < items.size()) or mouse_iy == 0;
    }

    string get_tab_name(int iy) {
        if (iy < 0 or items.size() <= iy) return "";
        return items[iy].name;
    }

    void select_tab(int iy) {
        items[iy].selected = true;
        selected = true;
    }

    void deselect_tab(int iy) {
        items[iy].selected = false;
        selected = false;
    }

    void step(int mouse_ix, int mouse_iy) {
        expanded = mouse_ix == ix and mouse_in_column(mouse_iy);
        for (int iy=0; iy<items.size(); ++iy) {
            items[iy].draw_tooltip = mouse_ix == ix and mouse_iy == iy and (iy == 0 or expanded);
        }
    }

    void draw(bool draw_first, float visibility, float hud_scale) {
        int draw_iy = draw_first ? 0 : 1;
        for (int iy=draw_iy; iy<items.size(); ++iy) {
            if ((not selected and iy == 0) or expanded or items[iy].selected) {
                items[iy].draw(ix, draw_iy, visibility, hud_scale);
                ++draw_iy;
            }
        }
    }
}

class MenuItem {
    scene@ g;
    sprites@ spr;
    textfield@ tooltip;

    string name;
    string sprite_name;

    bool draw_tooltip = false;
    bool selected = false;

    MenuItem(sprites@ spr, string name, string sprite_name) {
        @g = get_scene();
        @this.spr = spr;
        this.name = name;
        this.sprite_name = sprite_name;

        @tooltip = @create_textfield();
        tooltip.set_font("envy_bold", 20);
        tooltip.text(name);
        tooltip.align_vertical(-1);
    }

    void draw(int ix, int iy, float visibility, float hud_scale) {
        const float w = MENU_ITEM_WIDTH * hud_scale;
        const float h = w;
        const float x = (ix-5) * w;
        const float y = iy * h - HUD_HEIGHT_HALF;

        if (selected) {
            float border = 0.1 * w;
            g.draw_rectangle_hud(
                6, 0,
                x + border, y + border,
                x + w - border, y + h - border,
                0, 0x88FFFFFF
            );
        }
        int background_opacity = floor(0xAA * visibility);
        g.draw_rectangle_hud(
            10, 0,
            x, y,
            x + w, y + h,
            0, (background_opacity << 24) + BACKGROUND_COLOUR
        );
        g.draw_glass_hud(
            8, 0,
            x, y,
            x + w, y + h,
            0, 0
        );

        float padding = 5 * hud_scale;
        int icon_opacity = selected ? 0xFF : floor(0x99 * visibility) + 0x22;
        spr.draw_hud(
            10, 0,
            sprite_name, 0, 1,
            x + padding, y + padding,
            0, hud_scale, hud_scale,
            (icon_opacity << 24) + 0xFFFFFF
        );

        if (draw_tooltip) {
            float border = 5 * hud_scale;
            float tw = tooltip.text_width() * hud_scale;
            float th = tooltip.text_height() * hud_scale;
            g.draw_glass_hud(
                10, 1,
                x + w / 2 - tw / 2 - border, y + h,
                x + w / 2 + tw / 2 + border, y + h + th + 3 * border,
                0, 0
            );
            g.draw_rectangle_hud(
                10, 1,
                x + w / 2 - tw / 2 - border, y + h,
                x + w / 2 + tw / 2 + border, y + h + th + 3 * border,
                0, 0xFF000000
            );
            tooltip.draw_hud(10, 1, x + w / 2, y + h + border, hud_scale, hud_scale, 0);
        }
    }
}