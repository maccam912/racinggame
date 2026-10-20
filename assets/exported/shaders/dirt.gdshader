shader_type spatial;
render_mode cull_back, diffuse_burley;
uniform vec4 soil_color : source_color = vec4(0.57,0.32,0.15,1.0);
varying vec3 soil_position;
void vertex() { soil_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float grain(vec2 p) {
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
void fragment() {
    vec2 p = soil_position.xz;
    float detail = 1.0-smoothstep(0.7,2.0,length(fwidth(p*18.0)));
    float gravel = grain(floor(p*18.0));
    float broad = sin(p.x*0.21+sin(p.y*0.13))*sin(p.y*0.18);
    float side = abs(UV.y);
    float ruts = 1.0-smoothstep(0.035,0.13,min(abs(side-0.26),abs(side-0.61)));
    float grooves = sin(UV.x*2.2+sin(UV.x*0.13)*2.0)*0.025;
    ALBEDO = soil_color.rgb*(0.92+broad*0.065-ruts*0.21+grooves)+(gravel-0.5)*0.11*detail;
    ROUGHNESS = 1.0;
    SPECULAR = 0.08;
}
