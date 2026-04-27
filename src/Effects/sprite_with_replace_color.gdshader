shader_type canvas_item;

uniform float replace_amt : hint_range(0.0, 1.0, 0.02);
uniform vec4 replace_color : source_color;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, replace_color.rgb, replace_amt);
}