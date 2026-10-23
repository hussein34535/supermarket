shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float specular_value = 0.5;
uniform float walk_amount = 0.0;
uniform float walk_phase = 0.0;

vec3 rotate_around(vec3 p, vec3 pivot, vec3 axis, float a) {
	vec3 v = p - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void vertex() {
	vec3 op = VERTEX;
	float h = -op.z;
	float side = op.x >= 0.0 ? 1.0 : -1.0;
	float leg_phase = walk_phase + (side > 0.0 ? 0.0 : PI);

	float leg_w = 1.0 - smoothstep(0.50, 0.62, h);
	float hip_a = 0.52 * walk_amount * sin(leg_phase) * leg_w;
	vec3 hip_p = vec3(side * 0.09, 0.0, -0.54);
	VERTEX = rotate_around(VERTEX, hip_p, vec3(1.0, 0.0, 0.0), hip_a);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(1.0, 0.0, 0.0), hip_a);

	float knee_w = 1.0 - smoothstep(0.28, 0.36, h);
	float knee_a = -0.62 * walk_amount * (0.5 + 0.5 * sin(leg_phase + 1.3)) * knee_w;
	vec3 knee_p = vec3(side * 0.095, 0.0, -0.29);
	VERTEX = rotate_around(VERTEX, knee_p, vec3(1.0, 0.0, 0.0), knee_a);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(1.0, 0.0, 0.0), knee_a);

	float arm_w = smoothstep(0.20, 0.27, abs(op.x)) * smoothstep(0.50, 0.58, h) * (1.0 - smoothstep(0.92, 1.00, h));
	float arm_phase = walk_phase + (side > 0.0 ? PI : 0.0);
	float arm_a = 0.38 * walk_amount * sin(arm_phase) * arm_w;
	vec3 shoulder_p = vec3(side * 0.20, 0.0, -0.92);
	VERTEX = rotate_around(VERTEX, shoulder_p, vec3(1.0, 0.0, 0.0), arm_a);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(1.0, 0.0, 0.0), arm_a);

	float up_w = smoothstep(0.60, 0.88, h);
	float twist = 0.05 * walk_amount * sin(walk_phase) * up_w;
	VERTEX = rotate_around(VERTEX, vec3(0.0, 0.0, -0.70), vec3(0.0, 0.0, 1.0), twist);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(0.0, 0.0, 1.0), twist);
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = texture(orm_tex, UV).g;
	METALLIC = texture(orm_tex, UV).b;
	SPECULAR = specular_value;
}
