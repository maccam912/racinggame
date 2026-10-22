shader_type spatial;
render_mode cull_back;
uniform int motion = 0;
uniform vec3 pivot = vec3(0.0);
uniform vec3 orbit_center = vec3(0.0);
uniform float motion_speed = 1.0;
uniform float animation_enabled = 1.0;
uniform float glow = 0.0;
uniform bool water_flow = false;
varying vec3 local_at;
void vertex() {
    float angle = TIME * motion_speed * animation_enabled;
    vec3 p = VERTEX - pivot;
    float c = cos(angle);
    float s = sin(angle);
    if (motion == 1) {
        p.xy = mat2(vec2(c,s),vec2(-s,c)) * p.xy;
        NORMAL.xy = mat2(vec2(c,s),vec2(-s,c)) * NORMAL.xy;
    } else if (motion == 2) {
        p.xz = mat2(vec2(c,s),vec2(-s,c)) * p.xz;
        NORMAL.xz = mat2(vec2(c,s),vec2(-s,c)) * NORMAL.xz;
    } else if (motion == 3) {
        // Gondolas travel around the wheel while their floors stay level.
        vec2 offset = orbit_center.xy - pivot.xy;
        p.xy += mat2(vec2(c,s),vec2(-s,c)) * offset - offset;
    }
    VERTEX = p + pivot;
    local_at = VERTEX;
}
void fragment() {
    float grain = fract(sin(dot(floor(local_at * 3.0), vec3(12.13,37.71,7.17))) * 43758.5453);
    float detail = 1.0 - smoothstep(0.2,0.7,length(fwidth(local_at)));
    vec3 ink = COLOR.rgb * (0.97 + (grain-0.5) * 0.06 * detail);
    if (water_flow) {
        float stream = sin(local_at.y * 0.8 + TIME * 3.0 * animation_enabled + sin(local_at.x * 1.7) * 0.4);
        ink *= 0.92 + smoothstep(0.5,0.95,stream) * 0.18;
    }
    ALBEDO = ink;
    ROUGHNESS = 0.85;
    EMISSION = ink * glow;
}
