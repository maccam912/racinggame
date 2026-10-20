shader_type sky;
uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
void sky() {
    vec2 uv = SKY_COORDS;
    vec3 painted = texture(panorama, uv).rgb;
    // Blend opposing edges at the wrap, keeping the generated source untouched.
    float seam = 1.0 - smoothstep(0.0, 0.025, min(uv.x, 1.0 - uv.x));
    painted = mix(painted, texture(panorama, vec2(1.0 - uv.x, uv.y)).rgb, seam * 0.5);
    // A uniform zenith/nadir avoids pinching the painted horizontal bands.
    float pole = smoothstep(0.85, 1.0, abs(EYEDIR.y));
    vec3 pole_color = texture(panorama, vec2(0.5, uv.y)).rgb;
    COLOR = mix(painted, pole_color, pole) * tint;
}
