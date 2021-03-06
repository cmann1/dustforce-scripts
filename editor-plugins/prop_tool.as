#include "editor_tool.as"

#include "../lib/props.cpp"
#include "../lib/enums/GVB.cpp"
#include "../lib/enums/VK.cpp"

const string EMBED_proptoolicon = "editor-plugins/proptoolicon.png";

enum PropToolState {
    DISABLED,
    IDLE,
    MOVE,
    ROTATE,
    DELETE
}

class script : EditorTool {
    camera@ c;
    sprites@ spr;

    PropToolState state = DISABLED;
    Prop@ selected_prop;

    float mouse_x, mouse_y;
    float mouse_x_prev, mouse_y_prev;

    script() {
        @c = get_camera(0);
        @spr = create_sprites();
    }

    void build_sprites(message@ msg) {
        msg.set_string("Toolbar.proptoolicon", "proptoolicon");
    }

    void register_tab() override {
        register_tab(2, "Prop Tool", "Toolbar.proptoolicon");
    }

    void on_select_tab() override {
        state = IDLE;
        @selected_prop = null;
    }

    void on_deselect_tab() override {
        state = DISABLED;
    }

    void toggle() {
        message@ msg = create_message();
        msg.set_string("name", state == DISABLED ? "Prop Tool" : "Props");
        broadcast_message("Toolbar.SelectTab", msg);
    }

    void editor_step() {
        EditorTool::editor_step();

        if (e.key_check_pressed_vk(VK::Q)) {
            toggle();
        }

        update_mouse_vars();

        if (state == IDLE and mouse_in_toolbar) return;

        switch (state) {
            case IDLE:
                update_selected_prop();
                if (e.key_check_gvb(GVB::Space)) break;
                if      (e.key_check_pressed_gvb(GVB::LeftClick))   { state = MOVE;   }
                else if (e.key_check_pressed_gvb(GVB::MiddleClick)) { state = ROTATE; }
                else if (e.key_check_pressed_gvb(GVB::RightClick))  { state = DELETE; }
                break;

            case MOVE:
                if (not e.key_check_gvb(GVB::LeftClick)) { state = IDLE; }
                else if (selected_prop !is null) { move_selected_prop(); }
                break;

            case ROTATE:
                if (not e.key_check_gvb(GVB::MiddleClick)) { state = IDLE; }
                else if (selected_prop !is null) { rotate_selected_prop(); }
                break;

            case DELETE:
                if (not e.key_check_gvb(GVB::RightClick)) { state = IDLE; }
                else if (selected_prop !is null) { delete_selected_prop(); }
                break;
        }
    }

    void editor_draw(float sub_frame) {
        if (state == IDLE and not mouse_in_toolbar and selected_prop !is null) {
            string sprite_set, sprite_name;
            sprite_from_prop(@selected_prop.p, sprite_set, sprite_name);
            spr.add_sprite_set(sprite_set);

            float sx, sy, scale;
            scale_from_layer(selected_prop.p.x(), selected_prop.p.y(), selected_prop.p.layer(), sx, sy, scale);

            if (selected_prop.p.layer() <= 5) {
                scale = selected_prop.p.layer() <= 5 ? 2.0 : scale;
            }

            spr.draw_world(22, 0, sprite_name, 0, selected_prop.p.palette(),
                sx + 2, sy + 2,
                selected_prop.p.rotation(),
                scale * selected_prop.prop_scale_x,
                scale * selected_prop.prop_scale_y,
                0x66000000);
            spr.draw_world(22, 0, sprite_name, 0, selected_prop.p.palette(),
                sx - 2, sy - 2,
                selected_prop.p.rotation(),
                scale * selected_prop.prop_scale_x,
                scale * selected_prop.prop_scale_y,
                0x66000000);
            spr.draw_world(22, 0, sprite_name, 0, selected_prop.p.palette(), sx, sy, selected_prop.p.rotation(),
                scale * selected_prop.prop_scale_x,
                scale * selected_prop.prop_scale_y,
                0xAAFFAAAA);
        }
    }

    void scale_to_layer(float &in x, float &in y, int &in layer, float &out sx, float &out sy, float &out scale) {
        float cx = c.x();
        float cy = c.y();
        scale = g.layer_scale(layer);
        sx = cx + (x - cx) / scale;
        sy = cy + (y - cy) / scale;
    }

    void scale_from_layer(float &in x, float &in y, int &in layer, float &out sx, float &out sy, float &out scale) {
        float cx = c.x();
        float cy = c.y();
        scale = g.layer_scale(layer);
        sx = cx + (x - cx) * scale;
        sy = cy + (y - cy) * scale;
    }

    void update_mouse_vars() {
        mouse_x_prev = mouse_x;
        mouse_y_prev = mouse_y;
        mouse_x = g.mouse_x_world(0, 22);
        mouse_y = g.mouse_y_world(0, 22);
    }

    float distance_to_prop(Prop@ p) {
        float sx, sy, scale;
        scale_from_layer(p.anchor_x, p.anchor_y, p.p.layer(), sx, sy, scale);
        return distance(mouse_x, mouse_y, sx, sy);
    }

    void update_selected_prop() {
        float selected_dist = 1e8;
        @selected_prop = null;
        int n = g.get_prop_collision(mouse_y, mouse_y, mouse_x, mouse_x);
        for (int i=0; i<n; ++i) {
            Prop p(g.get_prop_collision_index(i), 0.5, 0.5, g);
            float dist = distance_to_prop(@p);
            if (dist < selected_dist) {
                selected_dist = dist;
                @selected_prop = @p;
            }
        }
    }

    void move_selected_prop() {
        float sx, sy, sx_prev, sy_prev, scale;
        scale_to_layer(mouse_x, mouse_y, selected_prop.p.layer(), sx, sy, scale);
        scale_to_layer(mouse_x_prev, mouse_y_prev, selected_prop.p.layer(), sx_prev, sy_prev, scale);
        float dx = sx - sx_prev;
        float dy = sy - sy_prev;
        selected_prop.p.x(selected_prop.p.x() + dx);
        selected_prop.p.y(selected_prop.p.y() + dy);
        selected_prop.anchor_x += dx;
        selected_prop.anchor_y += dy;
    }

    void rotate_selected_prop() {
        float sx, sy, sx_prev, sy_prev, scale;
        scale_to_layer(mouse_x, mouse_y, selected_prop.p.layer(), sx, sy, scale);
        scale_to_layer(mouse_x_prev, mouse_y_prev, selected_prop.p.layer(), sx_prev, sy_prev, scale);
        float dx = sx - selected_prop.anchor_x;
        float dy = sy - selected_prop.anchor_y;
        float dx_prev = sx_prev - selected_prop.anchor_x;
        float dy_prev = sy_prev - selected_prop.anchor_y;
        float angle = RAD2DEG * atan2(dy*dx_prev-dx*dy_prev, dx*dx_prev+dy*dy_prev);
        selected_prop.rotation(selected_prop.p.rotation() + angle);
    }

    void delete_selected_prop() {
        g.remove_prop(selected_prop.p);
        @selected_prop = null;
    }
}

// Ctrl+C to duplicate prop (with a small offset)
