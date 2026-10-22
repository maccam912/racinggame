shader_type sky;
uniform vec3 sky_top : source_color = vec3(0.35, 0.65, 0.85);
uniform vec3 horizon : source_color = vec3(0.8, 0.85, 0.9);
uniform bool night = false;
uniform bool aurora = false;
uniform bool storm = false;

void sky() {
    float up = max(EYEDIR.y, 0.0);
    vec3 color = mix(horizon, sky_top, smoothstep(0.0, 0.8, up));
    // Static analytic cloud banks avoid animated texture/shader compilation
    // surprises along the route. These never affect visibility or physics.
    float band = sin(SKY_COORDS.x * 31.0 + sin(SKY_COORDS.x * 13.0) * 2.0);
    float cloud = smoothstep(0.3, 0.85, band) * smoothstep(0.02, 0.16, up) * (1.0 - smoothstep(0.22, 0.42, up));
    color = mix(color, storm ? sky_top * 0.6 : horizon, cloud * (storm ? 0.8 : 0.22));
    if (night) {
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
