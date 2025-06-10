shader_type spatial;
render_mode unshaded,blend_add,depth_prepass_alpha,cull_disabled,specular_disabled;

// your albedo
uniform sampler2D sprite_texture : source_color, filter_linear;

// glow color exposed as “source_color”
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
// glow strength with a range slider
uniform float glow_strength : hint_range(0.0, 10.0) = 0.0;

void fragment() {
	vec4 albd = texture(sprite_texture, UV);
	ALBEDO = albd.rgb;
	ALPHA  = albd.a;
	EMISSION = glow_color.rgb * glow_strength;
}