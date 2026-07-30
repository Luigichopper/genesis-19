shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Visor Lens Curvature Settings
uniform float distortion_strength : hint_range(-1.0, 1.0) = 0.25;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.6;

// Retro Effects
uniform float scanline_density : hint_range(100.0, 800.0) = 320.0;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.15;
uniform float chromatic_aberration : hint_range(0.0, 10.0) = 1.8;

vec2 distort_uv(vec2 uv) {
    vec2 cc = uv - vec2(0.5);
    float dist = dot(cc, cc);
    // Spherical bulge / barrel distortion
    return uv + cc * (dist * distortion_strength);
}

void fragment() {
    vec2 distorted_uv = distort_uv(SCREEN_UV);

    // Check if UV coordinates are outside the screen bounds
    if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 || distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {
        // Render black outside the visor lens
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        // Chromatic Aberration (RGB Split)
        vec2 offset = SCREEN_PIXEL_SIZE * chromatic_aberration;
        float r = texture(screen_texture, distorted_uv + vec2(offset.x, 0.0)).r;
        float g = texture(screen_texture, distorted_uv).g;
        float b = texture(screen_texture, distorted_uv - vec2(offset.x, 0.0)).b;
        vec3 color = vec3(r, g, b);

        // Horizontal Scanlines
        float scanline = sin(distorted_uv.y * scanline_density * 3.14159) * 0.5 + 0.5;
        color *= mix(1.0, scanline, scanline_opacity);

        // Radial Vignette (darkening near visor edges)
        float uv_dist = distance(distorted_uv, vec2(0.5));
        color *= smoothstep(0.8, 0.8 - vignette_intensity, uv_dist);

        COLOR = vec4(color, 1.0);
    }
}