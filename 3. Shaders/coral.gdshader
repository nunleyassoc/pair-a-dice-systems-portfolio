# © Parker Nunley - Portfolio code
# Provided for evaluation only. Not licensed for reuse.

## This Shader is applied to coral

shader_type spatial;
render_mode depth_prepass_alpha;

// Customizable sway parameters
uniform float sway_strength_x : hint_range(0.0, 2.0) = 0.2; // Strength of sway on the X-axis
uniform float sway_strength_z : hint_range(0.0, 2.0) = 0.15; // Strength of sway on the Z-axis
uniform float sway_speed_x : hint_range(0.0, 5.0) = 1.25;    // Speed of sway on the X-axis
uniform float sway_speed_z : hint_range(0.0, 5.0) = 0.45;    // Speed of sway on the Z-axis
uniform float sway_length : hint_range(0.0, 1.0) = 1.0;      // How much the sway affects the vertices

// Editor-editable colors for coral
uniform vec3 color_top : source_color = vec3(0.8, 0.4, 0.6); // Top color of the coral
uniform vec3 color_bottom : source_color = vec3(0.4, 0.8, 0.6); // Bottom color of the coral

// Function to generate random values based on position
float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void vertex() {
    // Reset the normal to point upwards
    NORMAL = vec3(0.0, 1.0, 0.0);

    // Get the vertical position of the vertex
    float height_factor = clamp(VERTEX.y, 0.0, 1.0); // Ensure the height factor is between 0 and 1

    // Sway effect based on vertex Y-position instead of UV.y
    VERTEX.x += sin(NODE_POSITION_WORLD.x + TIME * sway_speed_x) * sway_strength_x * sway_length * height_factor;
    VERTEX.z += cos(NODE_POSITION_WORLD.z + TIME * sway_speed_z) * sway_strength_z * sway_length * height_factor;
}

void fragment() {
    // Randomize color selection based on position
    float randomness = rand(NODE_POSITION_WORLD.xy); // Generate randomness based on world position

    // Mix between the top and bottom colors with some randomness
    float height_factor = clamp(VERTEX.y, 0.0, 1.0); // Ensure the height factor is between 0 and 1
    vec3 color_mix = mix(color_bottom.rgb, color_top.rgb, height_factor + randomness * 0.2); // Add slight randomness to color mixing

    ALBEDO = color_mix;
    ALPHA = 1.0; // Full opacity
}
