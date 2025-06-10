shader_type spatial;
// Unshaded additive glow
render_mode unshaded, blend_add, depth_prepass_alpha, cull_disabled, specular_disabled;

// Scroll speed/direction for noise
uniform vec2 dir = vec2(0.0, 1.0);
uniform float speed : hint_range(0.0, 10.0) = 1.0;

// Base tire color (albedo). Use vec4 with source_color so Inspector shows a color picker.
uniform vec4 base_color : source_color = vec4(0.4, 0.3, 0.2, 1.0);

// Glow color for emission
uniform vec3 glow_color : source_color = vec3(0.0, 0.5, 1.0);

// Pulse parameters
uniform float freq : hint_range(0.0, 5.0) = 1.0;
uniform float amp  : hint_range(0.0, 5.0) = 0.5;
uniform float offset : hint_range(0.0, 5.0) = 0.5;

// Optional alpha multiplier (for transparency).
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // 1. Compute scrolling UV for noise
    vec2 uv = UV + dir * TIME * speed;

    // 2. Base albedo: combine base_color with noise
    ALBEDO = base_color.rgb;

    // 3. Alpha: use base_color alpha and multiplier
    ALPHA = base_color.a * alpha_mult;

    // 4. Compute pulse and emission
    float pulse = sin(TIME * freq) * amp + offset;
    // Prevent negative emission
    pulse = max(pulse, 0.0);
    EMISSION = glow_color * pulse;
}
