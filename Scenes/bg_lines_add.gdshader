shader_type canvas_item;
render_mode blend_add;

uniform float scroll_speed : hint_range(0.0, 4.0, 0.01) = 0.05;
uniform float scroll_angle : hint_range(0.0, 1.0, 0.01) = 0.4;

uniform sampler2D displacement_tex : repeat_enable;

uniform float displacement_strength : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float displacement_scroll_speed : hint_range(0.0, 4.0, 0.01) = 0.05;
uniform float displacement_scroll_angle : hint_range(0.0, 1.0, 0.01) = 0.03;

uniform float camera_displacement_scale : hint_range(0.0, 1.0, 0.01) = 1.0;
global uniform vec2 camera_displacement = vec2(0.0, 0.0);

const float BASE_DISPLACE = 0.1;

varying vec4 v_color;

void vertex() {
    v_color = COLOR;
}

void fragment() {
    float scroll_amt = TIME * scroll_speed;
    float ang = 2.0 * PI * scroll_angle;
    vec2 uv_offset = vec2(-sin(ang) * scroll_amt, cos(ang) * scroll_amt);
    
    vec2 camera_disp = camera_displacement * camera_displacement_scale / 1024.;
    uv_offset += camera_disp;
    
    float wave_time = TIME * displacement_scroll_speed;
    float wave_scroll_ang = 2.0 * PI * displacement_scroll_angle;
    vec2 wave_offset = vec2(-sin(wave_scroll_ang) * wave_time, cos(wave_scroll_ang) * wave_time);
    
    wave_offset += camera_disp;

    float displace_amt = texture(displacement_tex, UV + wave_offset).r * displacement_strength * BASE_DISPLACE;
    vec2 displace = vec2(displace_amt, 0);
    
    COLOR = texture(TEXTURE, UV + uv_offset - displace) * v_color;
	// Called for every pixel the material is visible on.
}
