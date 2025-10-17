shader_type canvas_item;
render_mode unshaded;

uniform bool outline_mode = false;           // false = draw normally
uniform float outline_px = 1.0;              // edge kernel radius in texels
uniform float fill_alpha = 0.08;             // opacity of interior when faint
uniform vec4 outline_color = vec4(1.0,1.0,1.0,0.7); // color/alpha of edge

void fragment() {
    vec4 c = texture(TEXTURE, UV);

    if (!outline_mode) {
        COLOR = c; // fully normal
    }

    // Detect opaque→transparent boundary in the *tile texture*
    vec2 texel = 1.0 / vec2(textureSize(TEXTURE, 0));
    float a = c.a;
    float t = 0.1; // edge threshold

    float aL = texture(TEXTURE, UV + vec2(-outline_px, 0.0) * texel).a;
    float aR = texture(TEXTURE, UV + vec2( outline_px, 0.0) * texel).a;
    float aU = texture(TEXTURE, UV + vec2( 0.0,  outline_px) * texel).a;
    float aD = texture(TEXTURE, UV + vec2( 0.0, -outline_px) * texel).a;

    // Edge when current pixel is mostly filled and at least one neighbor is mostly empty
    float neighbor_min = min(min(aL, aR), min(aU, aD));
    float is_edge = step(t, a) * (1.0 - step(t, neighbor_min));

    // Faint interior + stronger edge
    vec4 interior = vec4(c.rgb, a * fill_alpha);
    vec4 edge = vec4(outline_color.rgb, outline_color.a);

    COLOR = mix(interior, edge, is_edge);
}
