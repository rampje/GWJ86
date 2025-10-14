shader_type canvas_item;

// ---- Style controls ----
uniform vec3  tint_color : source_color = vec3(0.60, 0.50, 1.00); // bluish-purple
uniform float tint_strength : hint_range(0.0, 1.0) = 0.55;

// ---- Glitch/FX controls ----
uniform float glitch_amount      : hint_range(0.0, 1.0) = 0.25; // slice jump strength
uniform float glitch_frequency   : hint_range(0.0, 20.0) = 6.0; // how often slices appear
uniform float chroma_amount      : hint_range(0.0, 4.0)  = 0.6; // RGB offset scale (px)
uniform float scanline_strength  : hint_range(0.0, 1.0)  = 0.25;
uniform float flicker_strength   : hint_range(0.0, 1.0)  = 0.1;

// ---- Animation speeds ----
uniform float chroma_speed   : hint_range(0.0, 10.0) = 1.4;
uniform float slice_speed    : hint_range(0.0, 10.0) = 1.8;
uniform float flicker_speed  : hint_range(0.0, 10.0) = 2.5;

// Helpers
float hash(vec2 p) {
    // Fast hash for pseudo-noise
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise1D(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f*f*(3.0 - 2.0*f);
    return mix(hash(vec2(i, 0.0)), hash(vec2(i + 1.0, 0.0)), u);
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    float alpha = base.a;
    if (alpha <= 0.0) {
        COLOR = vec4(0.0);
    }

    // Texture pixel sizes (UV units per pixel). Use to convert "pixels" to UV offsets.
    vec2 px = TEXTURE_PIXEL_SIZE;

    // ---- Animated ingredients ----
    // Flicker in [0.9 .. 1.1] range (scaled by strength)
    float flicker = 1.0 + (noise1D(TIME * flicker_speed) - 0.5) * 2.0 * 0.1 * flicker_strength;

    // Scanlines: sine across rows; multiply by strength
    float rows = 1.0 / max(px.y, 1e-6); // approximate texture height in pixels
    float scan = 0.5 + 0.5 * sin((UV.y * rows + TIME * 0.5) * 3.14159265);
    float scan_mask = mix(1.0, scan, scanline_strength);

    // Chromatic aberration offset in "pixels" → convert to UV with px
    float wobble = sin(TIME * chroma_speed) * 0.5 + 0.5; // 0..1
    float ca_px = chroma_amount * (0.5 + 0.5 * noise1D(TIME * 0.37)); // a little randomization
    vec2 ca = vec2(ca_px * (wobble - 0.5), 0.0) * px; // horizontal split

    // ---- Horizontal glitch slice (band) ----
    // Pick a moving band; if active, offset UV.x for that band.
    float bands = 48.0; // number of potential glitch bands vertically
    float band_idx = floor(UV.y * bands);
    float band_phase = band_idx * 13.37 + floor(TIME * slice_speed);
    // Probability of a band glitching this frame:
    float band_gate = step(1.0 - glitch_amount, hash(vec2(band_phase, 0.0)));
    // Signed offset (in pixels) for the band, scaled by frequency/amount:
    float band_offset_px = (hash(vec2(band_phase, 7.1)) * 2.0 - 1.0) * 2.0 * glitch_amount;
    float active = step(0.5, noise1D(TIME * glitch_frequency + band_idx * 0.07)) * band_gate;
    vec2 slice_uv = UV + vec2(band_offset_px * px.x * active, 0.0);

    // ---- Sample with chromatic split and slice applied ----
    // Do chroma around the sliced UV to keep effects coherent
    vec4 col_r = texture(TEXTURE, slice_uv - ca);
    vec4 col_g = texture(TEXTURE, slice_uv);
    vec4 col_b = texture(TEXTURE, slice_uv + ca);

    vec3 rgb = vec3(col_r.r, col_g.g, col_b.b);

    // ---- Apply scanlines and flicker
    rgb *= scan_mask * flicker;

    // ---- Blue/Purple tint (gentle)
    // Blend towards tint_color; preserves contrast more than straight multiply.
    rgb = mix(rgb, rgb * tint_color, tint_strength);

    // Keep original alpha
    COLOR = vec4(rgb, alpha);
}
