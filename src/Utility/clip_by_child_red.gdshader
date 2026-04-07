shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	vec4 col = textureLod(screen_texture, SCREEN_UV, 0.);
	COLOR.a *= col.r;
}