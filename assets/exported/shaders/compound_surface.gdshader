shader_type spatial;
render_mode cull_back;
uniform float window_glow = 0.0;
varying vec3 local_at;
void vertex() { local_at = VERTEX; }
void fragment() {
    float grain = fract(sin(dot(floor(local_at * 3.0), vec3(12.13,37.71,7.17))) * 43758.5453);
    float detail = 1.0 - smoothstep(0.2,0.7,length(fwidth(local_at)));
    vec3 ink = COLOR.rgb * (0.97 + (grain-0.5) * 0.06 * detail);
    ALBEDO = ink;
    ROUGHNESS = 0.85;
    // Alpha is an opaque per-face mask, never transparency or whole-building glow.
    float pane = 1.0 - step(0.75, COLOR.a);
    EMISSION = mix(ink, vec3(1.0,0.82,0.57),0.7) * pane * window_glow;
}
