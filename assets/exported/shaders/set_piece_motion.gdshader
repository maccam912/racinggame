shader_type spatial;
render_mode cull_back;
uniform int motion = 0;
uniform vec3 pivot = vec3(0.0);
uniform vec3 orbit_center = vec3(0.0);
uniform float motion_speed = 1.0;
uniform float animation_enabled = 1.0;
uniform float glow = 0.0;
uniform bool water_flow = false;
uniform vec2 travel_extent = vec2(38.0,6.0);
uniform float travel_phase = 0.0;
uniform float travel_distance = 0.0;

vec2 cable_position(float distance) {
    float span = travel_extent.x;
    float radius = travel_extent.y;
    float at = mod(distance,4.0*span+6.2831853*radius);
    if (at<2.0*span) return vec2(-span+at,-radius);
    at -= 2.0*span;
    if (at<3.14159265*radius) {
        float angle = -1.5707963+at/radius;
        return vec2(span+cos(angle)*radius,sin(angle)*radius);
    }
    at -= 3.14159265*radius;
    if (at<2.0*span) return vec2(span-at,radius);
    at -= 2.0*span;
    float angle = 1.5707963+at/radius;
    return vec2(-span+cos(angle)*radius,sin(angle)*radius);
}

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
    if (motion == 4) {
        // Level cabin floors follow a closed two-lane cable circuit.
        p.xz += cable_position(angle+travel_phase)-cable_position(travel_phase);
    } else if (motion == 5) {
        // The bounded city shuttle reverses at the ends of its viaduct.
        p.x += sin(angle)*travel_distance;
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
