shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture, repeat_disable, filter_nearest;
uniform float fisheye_amount: hint_range(0, 10, 0.01) = 1.0;

//void vertex() {
//	// Called for every vertex the material is visible on.
//}

vec2 fisheye(vec2 screen_pixel_size, vec4 fragcoord, float amount) {
	// glsl -> godot shader
	vec2 iResolution = 1.0 / screen_pixel_size;
	vec4 fragCoord = fragcoord;
	//normalized coords 
	vec2 p = fragCoord.xy / iResolution.xy;
	vec2 center = vec2(0.5);
	vec2 d = p - center;
	float r = length(d);
	float distortion = 1.0 + amount * r * r;
	float r_edge = 0.5;
	float edge_distortion = 1.0 + amount * r_edge * r_edge;
	vec2 uv = center + (d * distortion) / edge_distortion;
	return uv;
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec2 fisheye_uv = fisheye(SCREEN_PIXEL_SIZE, FRAGCOORD, fisheye_amount);
	vec3 c = texture(screen_texture, fisheye_uv).rgb;
	COLOR.rgb = c;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
