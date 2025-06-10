shader_type spatial;

uniform bool flash_active = false;
uniform float flash_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0, 0.0, 0.0);
uniform float flash_freq : hint_range(0.0, 20.0) = 10.0;
uniform float flash_strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec3 base_col = vec3(0.2,0.1,0.1);
    if (flash_active) {
        float w = sin(TIME * flash_freq);
        float t = abs(w);
        base_col = mix(base_col, flash_color, t * flash_strength * flash_progress);
        EMISSION += flash_color * (t * flash_strength * flash_progress);
    }
    ALBEDO = base_col;
}
