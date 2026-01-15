# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## This Shader is a cosmetic that you can apply to the player after completing a quest

shader_type spatial;
render_mode unshaded;

uniform float speed = 1.0;
uniform float density = 20.0;
uniform float glow_intensity = 2.0;
uniform float trail_sharpness = 2.5;
uniform vec3 rain_color : source_color = vec3(0.0, 1.0, 0.0);

void fragment() {
    // Fake UVs using vertex positions (XY in object space)
    vec2 uv = vec2(VERTEX.x, VERTEX.y) * density;

    // Scroll vertically over time
    float scroll = fract(uv.y - TIME * speed);

    // Randomize per-column based on x
    float col_hash = fract(sin(uv.x * 12.9898) * 43758.5453);

    // Brightness trail, fading smoothly downward
    float trail = pow(1.0 - scroll, trail_sharpness) * glow_intensity;

    // Mask out some columns for variety
    float visible = step(0.5, col_hash);

    // Final intensity
    float final = trail * visible;

    ALBEDO = rain_color * final;
    EMISSION = rain_color * final;
}
