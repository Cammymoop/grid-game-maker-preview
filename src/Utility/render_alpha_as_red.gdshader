shader_type canvas_item;
render_mode unshaded;

void fragment() {
	COLOR = vec4(COLOR.a, 0., 0., 1.);
}