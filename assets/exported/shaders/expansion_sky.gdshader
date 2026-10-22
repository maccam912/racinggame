shader_type sky;
uniform vec3 sky_top : source_color = vec3(0.35, 0.65, 0.85);
uniform vec3 horizon : source_color = vec3(0.8, 0.85, 0.9);
uniform bool night = false;
uniform bool aurora = false;
uniform bool storm = false;
uniform bool space = false;
uniform float sky_seed = 0.0;
uniform int style = 0;

void sky() {
    float up = max(EYEDIR.y, 0.0);
    vec3 color = mix(horizon, sky_top, smoothstep(0.0, 0.8, up));
    // Static analytic cloud banks avoid animated texture/shader compilation
    // surprises along the route. These never affect visibility or physics.
    float longitude = SKY_COORDS.x * 6.2831853;
    float band = sin(longitude * 3.0 + sin(longitude * 2.0 + sky_seed) + sky_seed);
    float bank_height = 0.18 + sin(longitude * 3.0 + sky_seed) * 0.045;
    float thickness = 0.045 + (0.5 + 0.5 * sin(longitude * 7.0 + sky_seed)) * 0.025;
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
        color = mix(horizon * 0.17, sky_top * 0.09, smoothstep(-0.05, 0.35, EYEDIR.y));
        float nebula = pow(max(0.0, 1.0 - abs(EYEDIR.y - 0.25 - sin(longitude * 2.0 + sky_seed) * 0.15) * 4.0), 3.0);
        color += horizon * nebula * 0.12;
        vec3 center = normalize(vec3(cos(sky_seed), 0.5 + 0.15 * sin(sky_seed), sin(sky_seed)));
        float disc = smoothstep(0.975, 0.976, dot(EYEDIR, center));
        float bands = 0.75 + sin(EYEDIR.y * 95.0 + sky_seed) * 0.12;
        color = mix(color, mix(horizon, vec3(0.38, 0.53, 0.72), 0.4) * bands, disc);
    }
    if (night || space) {
        vec2 star_cell = floor(SKY_COORDS * vec2(850.0, 450.0));
        float star = fract(sin(dot(star_cell, vec2(12.9898, 78.233))) * 43758.5453);
        color += vec3(step(0.9992, star) * smoothstep(0.1, 0.4, up) * 0.5);
    }
    if (aurora) {
        float ribbon = 0.32 + sin(SKY_COORDS.x * 18.0) * 0.07;
        float curtain = exp(-abs(up - ribbon) * 22.0) * (0.4 + 0.6 * pow(abs(sin(SKY_COORDS.x * 130.0)), 4.0));
        color += vec3(0.12, 0.8, 0.55) * curtain * 0.55;
    }
    COLOR = color;
}
