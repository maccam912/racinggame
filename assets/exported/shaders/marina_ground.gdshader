shader_type spatial;
render_mode cull_back;
uniform vec4 gardens[16];
uniform vec2 garden_axes[16];
uniform int garden_count = 0;
varying vec2 world_xz;
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment() {
    float lawn = 0.0;
    float rim = 0.0;
    for (int i=0; i<16; i++) {
        if (i>=garden_count) break;
        vec2 delta = world_xz-gardens[i].xy;
        vec2 axis = garden_axes[i];
        vec2 local = vec2(dot(delta,axis),dot(delta,vec2(-axis.y,axis.x)));
        float edge = length(local/gardens[i].zw);
        float aa = max(fwidth(edge),0.001);
        lawn = max(lawn,1.0-smoothstep(0.98-aa,0.98+aa,edge));
        rim = max(rim,1.0-smoothstep(1.0-aa,1.0+aa,edge));
    }
    float detail = 1.0-smoothstep(0.4,1.5,length(fwidth(world_xz)));
    vec2 slabs = fract(world_xz/4.0);
    float edge = min(min(slabs.x,1.0-slabs.x),min(slabs.y,1.0-slabs.y));
    float seam = (1.0-smoothstep(0.008,max(fwidth(edge),0.015),edge))*detail;
    float grain = fract(sin(dot(floor(world_xz*2.0),vec2(12.13,37.71)))*43758.5453);
    vec3 pavement = vec3(0.36,0.39,0.43)*(1.0-seam*0.16);
    vec3 grass = vec3(0.24,0.40,0.26)*(0.94+grain*0.12*detail);
    vec3 ink = mix(pavement,vec3(0.57,0.56,0.51),rim);
    ALBEDO = mix(ink,grass,lawn);
    ROUGHNESS = 0.95;
}
