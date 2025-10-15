shader_type canvas_item;

uniform float pulse : hint_range(0.0, 1.0) = 0.0;     // driven by tween
uniform float boost = 0.35;                          // extra brightness at pulse peak
uniform float wobble_amp_px : hint_range(0.0, 1.0) = 0.6;                   // very subtle vertical wobble
uniform float wobble_freq : hint_range(0,30.)  = 18.0;                  // Hz for the wobble
uniform vec4  tint = vec4(1.2, 1.15, 1.0, 1.0);       // slightly warm “lantern” tint

void fragment() {
    vec4 c = texture(TEXTURE, UV) * COLOR;

    // Smooth decay curve, stronger near start
    float k = 1.0 - pulse;           // 1 at rest, 0 at peak
    float t = 1.0 - k * k;           // ease-out-ish intensity 0..1

    // Sample with teeny vertical wobble (only while pulsing)
    vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
    float wobble_uv = (sin(TIME * wobble_freq + UV.x * 12.0) * wobble_amp_px * t) / tex_size.y;
    vec4 w = texture(TEXTURE, vec2(UV.x, UV.y + wobble_uv));

    // Brighten + tint (subtle)
    vec4 mixed = mix(c, w * tint, t);
    mixed.rgb *= (1.0 + boost * t);

    COLOR = mixed;
}
