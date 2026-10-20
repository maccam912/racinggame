shader_type spatial;
varying vec3 world_at;
uniform bool lava = false;
void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
float bayer(vec2 p) {
    ivec2 q = ivec2(mod(floor(p),4.0));
    int x=q.x; int y=q.y;
    return float(((x&1)*2+(y&1))*4+((x>>1)&1)*2+((y>>1)&1))/16.0;
}
void fragment() {
    float layers = sin(world_at.y*0.65+sin(world_at.x*0.04+world_at.z*0.03)*0.8);
    float grain = sin(dot(floor(world_at*5.0),vec3(12.13,37.71,7.17)))*0.5+0.5;
    float fade = 1.0-smoothstep(0.15,0.6,length(fwidth(world_at)));
    vec3 ink = COLOR.rgb*(0.9+layers*0.06+(grain-0.5)*0.08*fade);
    ink = floor(clamp(ink,vec3(0.0),vec3(1.0))*24.0+bayer(FRAGCOORD.xy)*fade)/24.0;
    ALBEDO = ink;
    ROUGHNESS = 0.93;
    if (lava) {
        float pulse = 0.85+0.15*sin(world_at.x*0.04+world_at.z*0.03+TIME*0.5);
        EMISSION = ink*pulse*1.2;
        ROUGHNESS = 0.55;
    }
}
