shader_type spatial;
render_mode cull_back;
uniform vec3 ground_color : source_color = vec3(0.5, 0.6, 0.4);
uniform vec3 accent_color : source_color = vec3(0.6, 0.7, 0.5);
uniform int biome = 0;
uniform float course_seed = 0.0;
varying vec3 world_at;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
float field(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash(cell),hash(cell+vec2(1.0,0.0)),f.x),mix(hash(cell+vec2(0.0,1.0)),hash(cell+vec2(1.0)),f.x),f.y);
}
float fissures(vec2 p, float width) {
    p += vec2(sin(p.y*0.57),cos(p.x*0.63))*0.38;
    vec3 lines = abs(sin(vec3(p.x,p.y,p.x+p.y)));
    float nearest = min(lines.x,min(lines.y,lines.z));
    float aa = max(fwidth(nearest),0.015);
    return 1.0-smoothstep(width,width+aa,nearest);
}
void vertex() {
    world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec2 p = world_at.xz + vec2(course_seed*19.7,course_seed*7.3);
    float broad = field(p*0.011);
    float patches = field(p*0.037+vec2(83.2,17.8));
    float detail = 1.0-smoothstep(0.15,0.75,length(fwidth(p)));
    float grain = (hash(floor(p*3.0))-0.5)*0.045*detail;
    vec3 ink = ground_color * (0.88+broad*0.20+grain);
    float rough = 0.96;
    vec3 emitted = vec3(0.0);
    if (biome == 0) {
        // Broad meadow clearings and moss, with restrained close-range grain.
        ink = mix(ink,accent_color,smoothstep(0.49,0.78,patches)*0.42);
    } else if (biome == 1) {
        float ice = smoothstep(0.52,0.75,patches);
        ink = mix(ink,accent_color,ice*0.64);
        float crack = fissures(p*0.11,0.027)*detail*ice;
        ink *= 1.0-crack*0.26;
        rough = mix(0.96,0.62,ice);
    } else if (biome == 2) {
        float ripple = sin(p.x*0.68+p.y*0.22+broad*7.0);
        float readable = 1.0-smoothstep(0.4,1.4,length(fwidth(p)));
        ink *= 1.0+ripple*0.065*readable;
        ink = mix(ink,accent_color,smoothstep(0.55,0.82,broad)*0.35);
    } else if (biome == 3) {
        vec2 slabs = fract(p/7.0);
        float edge = min(min(slabs.x,1.0-slabs.x),min(slabs.y,1.0-slabs.y));
        float seam = 1.0-smoothstep(0.009,max(0.017,fwidth(edge)*1.5),edge);
        ink *= 1.0-seam*0.16*detail;
        ink *= 0.94+hash(floor(p/7.0))*0.12;
    } else if (biome == 4) {
        float crack = fissures(p*0.32,0.035)*detail;
        ink = mix(ink,accent_color,crack*0.38);
        ink *= 1.0+(patches-0.5)*0.045;
    } else if (biome == 5) {
        // One bounded crater per large cell, with a rim wholly inside its cell.
        vec2 cell = floor(p/105.0);
        vec2 center = vec2(hash(cell),hash(cell+vec2(73.4,11.2)))*0.30+0.35;
        float size = 0.18+hash(cell+vec2(41.2,9.7))*0.10;
        vec2 offset = fract(p/105.0)-center;
        float angle = atan(offset.y,offset.x);
        float radius = length(offset)/size*(1.0+sin(angle*5.0+hash(cell)*6.0)*0.065+sin(angle*9.0)*0.035);
        float present = step(0.19,hash(cell+vec2(29.1,85.6)));
        float bowl = 1.0-smoothstep(0.55,0.96,radius);
        float rim = smoothstep(0.78,0.94,radius)*(1.0-smoothstep(1.0,1.18,radius));
        ink *= 1.0+present*(-bowl*0.17+rim*0.12);
        ink = mix(ink,accent_color,smoothstep(0.54,0.82,patches)*0.23);
    } else if (biome == 6) {
        float veins = fissures(p*0.075,0.08);
        ink = mix(ink,accent_color,veins*0.4);
        emitted = accent_color*veins*0.09;
    } else if (biome == 7) {
        float strata = sin(world_at.y*0.17+broad*1.8);
        ink = mix(ink,accent_color,smoothstep(-0.25,0.6,strata)*0.36);
        ink *= 1.0+sin(p.x*0.32+p.y*0.12+broad*8.0)*0.05*detail;
    } else if (biome == 8) {
        float seams = fissures(p*0.065,0.035);
        ink *= 0.78+patches*0.3;
        emitted = accent_color*seams*0.19;
    } else if (biome == 9) {
        float mud = smoothstep(0.46,0.70,patches);
        ink = mix(ink,accent_color,mud*0.65);
        rough = mix(0.96,0.72,mud);
    }
    // Rock appears on steep banks without adding new geometry or collision.
    float bank = 1.0-smoothstep(0.55,0.85,abs(world_normal.y));
    ink *= 1.0-bank*0.12;
    ALBEDO = ink * COLOR.rgb;
    ROUGHNESS = rough;
    SPECULAR = 0.25;
    EMISSION = emitted;
}
