shader_type canvas_item;
// The set's light (docs/02 "lighting"): one warm fluorescent pool over the counter and the customer,
// cool night at the fridge and the door. Posterised into STEPS bands so the tint is stepped like the
// rest of the art (the SubViewport is 480x270; the bands land on game pixels). All four colours are
// Palette tokens set from scene_layers.gd — nothing here is a value of its own.
uniform vec4 warm : source_color = vec4(1.0, 0.82, 0.58, 0.10);
uniform vec4 cool : source_color = vec4(0.10, 0.16, 0.32, 0.20);
uniform vec2 centre = vec2(0.52, 0.62);
uniform float radius = 0.62;
uniform int steps = 4;

void fragment() {
	vec2 d = (UV - centre) * vec2(1.7778, 1.0);
	float t = clamp(length(d) / radius, 0.0, 1.0);
	t = floor(t * float(steps) + 0.5) / float(steps);
	COLOR = mix(warm, cool, t);
}
