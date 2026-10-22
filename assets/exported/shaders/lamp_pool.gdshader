shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 light_color : source_color = vec3(1.0, 0.70, 0.35);
uniform float strength = 0.25;
void fragment() {
    // A ground-conforming pool, without an extra dynamic light or shadow map.
    float radius = length((UV - vec2(0.5)) * 2.0);
    float pool = pow(1.0 - smoothstep(0.1, 1.0, radius), 2.0);
    float fade = 1.0 - smoothstep(70.0, 115.0, length(VERTEX));
    ALBEDO = light_color;
    ALPHA = pool * strength * fade;
}
