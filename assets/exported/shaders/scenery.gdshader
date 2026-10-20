shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform float window_glow = 0.0;
uniform bool city_facade = false;
varying vec3 authored_normal;
void vertex() { authored_normal = NORMAL; }
float facade_dither(vec2 p) {
 ivec2 cell = ivec2(mod(floor(p),4.0));
 const mat4 threshold = mat4(vec4(0.0,12.0,3.0,15.0),vec4(8.0,4.0,11.0,7.0),vec4(2.0,14.0,1.0,13.0),vec4(10.0,6.0,9.0,5.0));
 return (threshold[cell.x][cell.y]+0.5)/16.0;
}
void fragment() {
 if (city_facade) {
  // City UVs are facade metres, aligned to the topmost floor's sill.
  // Vertex alpha is an opaque facade mask, never material transparency.
  vec2 grid = (UV+vec2(.35,0.0))/vec2(3.0,3.7);
  vec2 cell = fract(grid);
  float pane = step(.16,cell.x)*step(cell.x,.82)*step(.38,cell.y)*step(cell.y,.95);
  pane *= (1.0-step(.35,abs(authored_normal.y)))*step(.5,COLOR.a);
  pane *= 1.0-smoothstep(.20,.75,max(fwidth(grid.x),fwidth(grid.y)));
  pane *= 1.0-step(.47,cell.x)*step(cell.x,.51);
  vec2 tile = floor(grid);
  float lit = step(.76,fract(sin(dot(tile,vec2(12.9898,78.233)))*43758.5453));
  float diagonal = fract(cell.x+cell.y*.42);
  float reflection = smoothstep(.10,.20,diagonal)*(1.0-smoothstep(.28,.36,diagonal));
  vec3 glass = mix(vec3(.075,.22,.34),vec3(.28,.46,.58),reflection);
  glass = mix(glass,vec3(.72,.50,.22),lit*.42);
  vec3 color = mix(COLOR.rgb,glass,pane);
  float dither = facade_dither(FRAGCOORD.xy);
  ALBEDO = floor(color*24.0+dither)/24.0;
  ROUGHNESS = mix(.94,.46,pane);
  SPECULAR = .35;
  EMISSION = glass*pane*(.06+lit*(.08+.12*window_glow));
 } else {
  vec3 base = texture(atlas, UV).rgb;
  ALBEDO = base;
  ROUGHNESS = 0.9;
  vec2 tile = floor(UV * 4.0);
  float window_mask = step(2.5, tile.x) * step(1.5, tile.y) * (1.0-step(2.5,tile.y)) * step(0.65,base.r);
  EMISSION = base * window_glow * window_mask;
 }
}
