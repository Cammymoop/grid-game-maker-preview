shader_type canvas_item;

uniform float replace_amt : hint_range(0.0, 1.0, 0.02);
uniform vec4 replace_color : source_color;

uniform vec2 patch_size = vec2(0.5, 0.5);
uniform vec2 cur_scale_for_patch = vec2(1.0, 1.0);
uniform float patch_sides_repeat = 0.0;
uniform float patch_center_repeat = 0.0;

uniform float check_slider : hint_range(0.0, 1.0, 0.02);

varying vec4 vert_color;

void vertex() {
	vert_color = COLOR;
}

void fragment() {
	vec2 reverse_region_uv = (UV - REGION_RECT.xy) / REGION_RECT.zw;
	
    vec2 orig_corner_size = (vec2(1) - patch_size) * 0.5;
    vec2 new_corner_size = orig_corner_size / cur_scale_for_patch;
    vec2 new_patch_size = patch_size + ((orig_corner_size - new_corner_size) * 2.0);

    vec2 patch_adj_uv = reverse_region_uv;
    vec2 inside_corner = step(reverse_region_uv, new_corner_size) + step(vec2(1) - new_corner_size, reverse_region_uv);

    patch_adj_uv *= vec2(1) + ((cur_scale_for_patch - vec2(1)) * inside_corner);
    patch_adj_uv += (vec2(1) - cur_scale_for_patch) * step(vec2(1) - new_corner_size, reverse_region_uv);
    
    vec2 inside_inner = (vec2(1) - inside_corner);
    float inside_center = inside_inner.x * inside_inner.y;
    float inside_edge = inside_inner.x + inside_inner.y - inside_center * 2.0;
    
    float edge_repeat = inside_edge * patch_sides_repeat;
    float center_repeat = inside_center * patch_center_repeat;

    vec2 inner_repeat = inside_inner * (edge_repeat + center_repeat);
    vec2 inner_stretch = inside_inner * (vec2(1) - (edge_repeat + center_repeat));
    
    patch_adj_uv -= new_corner_size * inner_stretch;
    patch_adj_uv *= vec2(1) + ((patch_size / new_patch_size) - vec2(1)) * inner_stretch;
    patch_adj_uv += orig_corner_size * inner_stretch;
    
    patch_adj_uv -= patch_adj_uv * inner_repeat;
    vec2 repeat_offset = (vec2(1) - (patch_size / cur_scale_for_patch)) * 0.5;
    patch_adj_uv += (mod(reverse_region_uv - repeat_offset, patch_size / cur_scale_for_patch) * cur_scale_for_patch + orig_corner_size) * inner_repeat;
    
    vec2 region_adjusted_uv = patch_adj_uv * REGION_RECT.zw + REGION_RECT.xy;

    vec4 tex_color = texture(TEXTURE, region_adjusted_uv) * vert_color;
	COLOR.rgb = mix(tex_color.rgb, replace_color.rgb, replace_amt);
    COLOR.a = tex_color.a;
	
	//COLOR.r = COLOR.r + step(check_slider, patch_adj_uv.x);
	//COLOR.gb = COLOR.gb + step(check_slider, reverse_region_uv.x);
}