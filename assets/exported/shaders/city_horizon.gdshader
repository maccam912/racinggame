shader_type spatial;
render_mode unshaded, cull_back;
varying vec3 wall_normal;
void vertex() { wall_normal = NORMAL; }
void fragment() {
    vec2 grid = UV/vec2(9.0,11.0);
    vec2 cell = fract(grid);
    vec2 aa = max(fwidth(grid),vec2(0.01));
    vec2 pane = smoothstep(vec2(0.18)-aa,vec2(0.18)+aa,cell)*(1.0-smoothstep(vec2(0.72)-aa,vec2(0.72)+aa,cell));
    float mask = pane.x*pane.y*COLOR.a*(1.0-step(0.35,abs(wall_normal.y)));
    mask *= 1.0-smoothstep(0.4,0.85,max(aa.x,aa.y));
    float lit = step(0.64,fract(sin(dot(floor(grid),vec2(12.9898,78.233)))*43758.5453));
    vec3 window = mix(vec3(0.20,0.26,0.36),vec3(0.67,0.58,0.47),lit);
    ALBEDO = mix(COLOR.rgb*0.85,window,mask*0.82);
}
