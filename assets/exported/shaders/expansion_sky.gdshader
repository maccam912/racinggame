shader_type sky;
uniform vec3 sky_top : source_color = vec3(0.35, 0.65, 0.85);
uniform vec3 horizon : source_color = vec3(0.8, 0.85, 0.9);
uniform bool night = false;
uniform bool aurora = false;
uniform bool storm = false;
uniform bool space = false;
uniform float sky_seed = 0.0;
uniform int style = 0;
uniform int space_view = 0;

float sky_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
float sky_field(vec2 p) {
    vec2 at = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(sky_hash(at),sky_hash(at+vec2(1.0,0.0)),f.x),mix(sky_hash(at+vec2(0.0,1.0)),sky_hash(at+vec2(1.0)),f.x),f.y);
}


void sky() {
    float up = max(EYEDIR.y, 0.0);
    float obscured = 0.0;
    vec3 color = mix(horizon, sky_top, smoothstep(0.0, 0.8, up));
    // Static analytic cloud banks avoid animated texture/shader compilation
    // surprises along the route. These never affect visibility or physics.
    float longitude = SKY_COORDS.x * 6.2831853;
    float band = sin(longitude * 3.0 + sin(longitude * 2.0 + sky_seed) + sky_seed);
    float bank_height = 0.18 + sin(longitude * 3.0 + sky_seed) * 0.045;
    float thickness = 0.045 + (0.5 + 0.5 * sin(longitude * 7.0 + sky_seed)) * 0.025;
    if (style == 0) { bank_height += 0.10; thickness *= 0.52; }
    if (style == 1) { thickness *= 1.6; band += sin(longitude*11.0+sky_seed)*0.35; }
    if (style == 2) { thickness *= 0.40; bank_height += sin(longitude*5.0)*0.035; }
    if (style == 3) { bank_height += 0.12; thickness *= 0.3; }
    float cloud = exp(-pow((EYEDIR.y - bank_height) / thickness, 2.0)) * smoothstep(-0.6, 0.7, band);
    if (storm) {
        float shelf = smoothstep(0.01, 0.10, EYEDIR.y) * (1.0 - smoothstep(0.28, 0.56, EYEDIR.y));
        color = mix(color, sky_top * 0.55, shelf * (0.65 + band * 0.15));
    } else {
        color = mix(color, mix(horizon, vec3(1.0), 0.5), cloud * (night ? 0.12 : 0.60));
    }
    vec3 sun_direction = normalize(vec3(cos(sky_seed) * 0.8, 0.22 + 0.15 * sin(sky_seed), sin(sky_seed) * 0.8));
    float sun_disc = smoothstep(0.9990, 0.9995, dot(EYEDIR, sun_direction));
    color = mix(color, night ? vec3(0.8, 0.87, 1.0) : vec3(1.0, 0.91, 0.65), sun_disc);
    if (space) {
        color = mix(horizon*0.12,sky_top*0.045,smoothstep(-0.05,0.35,EYEDIR.y));
        vec3 center = normalize(vec3(cos(sky_seed),0.55,sin(sky_seed)));
        vec3 right = normalize(cross(vec3(0.0,1.0,0.0),center));
        vec3 above = cross(center,right);
        vec2 q = vec2(dot(EYEDIR,right),dot(EYEDIR,above))/max(0.01,dot(EYEDIR,center));
        float facing = step(0.0,dot(EYEDIR,center));
        float radius = length(q);
        float disc = (1.0-smoothstep(0.215,0.22,radius))*facing;
        obscured = disc;
        float sphere = sqrt(max(0.0,1.0-pow(radius/0.22,2.0)));
        float sunlight = clamp(0.35+q.x*1.5+sphere*0.65,0.12,1.0);
        if (space_view == 1) {
            // Blue homeworld above the quiet, airless freight valley.
            float continent = sky_field(q*17.0+vec2(4.8,sky_seed))*0.65+sky_field(q*36.0)*0.35;
            vec3 globe = mix(vec3(0.09,0.28,0.55),vec3(0.34,0.48,0.27),smoothstep(0.49,0.58,continent));
            float clouds = smoothstep(0.57,0.73,sky_field(q*41.0+vec2(11.6,27.8)));
            globe = mix(globe,vec3(0.81,0.86,0.88),clouds*0.75);
            color = mix(color,globe*sunlight,disc);
        } else if (space_view == 2) {
            // The rings project into the sky plane and pass behind the globe.
            vec2 tilted = mat2(vec2(0.96,0.28),vec2(-0.28,0.96))*q;
            float ring_radius = length(vec2(tilted.x,tilted.y/0.28));
            float rings = smoothstep(0.255,0.27,ring_radius)*(1.0-smoothstep(0.42,0.435,ring_radius))*facing;
            float gap = 1.0-smoothstep(0.004,0.009,abs(ring_radius-0.35));
            vec3 ring_ink = vec3(0.63,0.70,0.51)*(0.67+sin(ring_radius*480.0)*0.13);
            color = mix(color,ring_ink,rings*(1.0-gap*0.8)*0.7);
            float bands = sin(q.y*94.0+sin(q.x*15.0)*0.45)*0.08;
            color = mix(color,(vec3(0.50,0.65,0.50)+bands)*sunlight,disc);
        } else if (space_view == 3) {
            float nebula = pow(max(0.0,1.0-abs(EYEDIR.y-0.25-sin(longitude*2.0+sky_seed)*0.15)*4.0),3.0);
            color += vec3(0.19,0.08,0.30)*nebula*0.5;
            float ice_bands = 0.9+sky_field(q*32.0)*0.2;
            color = mix(color,vec3(0.42,0.57,0.75)*sunlight*ice_bands,disc);
            float second = (1.0-smoothstep(0.065,0.069,length(q-vec2(0.38,0.10))))*facing;
            float second_radius = length(q-vec2(0.38,0.10))/0.069;
            float second_light = 0.22+sqrt(max(0.0,1.0-second_radius*second_radius))*0.7;
            color = mix(color,vec3(0.79,0.48,0.63)*second_light,second);
            obscured = max(disc,second);
        } else if (space_view == 4) {
            // Mars retains a dusty atmosphere, small moons and a distant sun.
            color = mix(vec3(0.57,0.31,0.23),vec3(0.16,0.12,0.16),smoothstep(-0.04,0.9,EYEDIR.y));
            float haze = exp(-pow((EYEDIR.y-0.12)/0.16,2.0));
            color += vec3(0.10,0.06,0.035)*haze;
            float sun = smoothstep(0.9994,0.9997,dot(EYEDIR,sun_direction));
            color = mix(color,vec3(1.0,0.88,0.69),sun);
            float moon_a = (1.0-smoothstep(0.018,0.020,length(q-vec2(0.0,0.0))))*facing;
            float moon_b = (1.0-smoothstep(0.011,0.013,length(q-vec2(0.24,0.18))))*facing;
            color = mix(color,vec3(0.62,0.50,0.41),max(moon_a,moon_b)*0.8);
            obscured = max(sun,max(moon_a,moon_b));
        } else if (space_view == 5) {
            // Static eclipse and cold corona; no flashing lightning or pulses.
            float halo = exp(-abs(radius-0.223)*45.0)*facing;
            float streamers = 0.75+0.25*pow(abs(sin(atan(q.y,q.x)*11.0)),3.0);
            color += vec3(0.25,0.64,0.49)*halo*streamers*0.85;
            color = mix(color,vec3(0.012,0.018,0.025),disc);
        }
    }
    if (night || space) {
        vec2 star_cell = floor(SKY_COORDS * vec2(850.0, 450.0));
        float star = fract(sin(dot(star_cell, vec2(12.9898, 78.233))) * 43758.5453);
        float star_visibility = space_view == 4 ? smoothstep(0.65,0.95,up)*0.13 : smoothstep(0.1,0.4,up)*0.5;
        color += vec3(step(0.9992,star)*star_visibility*(1.0-obscured));
    }
    if (aurora) {
        float ribbon = 0.32 + sin(SKY_COORDS.x * 18.0) * 0.07;
        float curtain = exp(-abs(up - ribbon) * 22.0) * (0.4 + 0.6 * pow(abs(sin(SKY_COORDS.x * 130.0)), 4.0));
        color += vec3(0.12, 0.8, 0.55) * curtain * 0.55;
    }
    COLOR = color;
}
