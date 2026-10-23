shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float specular_value = 0.5;
uniform float walk_amount = 0.0;
uniform float walk_phase = 0.0;
uniform float stride_amount = 1.0;

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
	float w = walk_amount;

	float hip_a = 0.52 * stride_amount * w * sin(leg_phase);
	float leg_w = 1.0 - smoothstep(0.48, 0.62, h);
	vec3 hip_p = vec3(0.0, 0.0, -0.55);
	VERTEX = rotate_around(VERTEX, hip_p, vec3(1.0, 0.0, 0.0), hip_a * leg_w);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(1.0, 0.0, 0.0), hip_a * leg_w);

	float swing = max(0.0, -cos(leg_phase));
	float knee_a = (0.18 + 0.85 * swing) * stride_amount * w;
	float knee_w = 1.0 - smoothstep(0.30, 0.40, h);
	vec3 knee_p = vec3(0.0, 0.0, -0.30);
	VERTEX = rotate_around(VERTEX, knee_p, vec3(1.0, 0.0, 0.0), knee_a * knee_w);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(1.0, 0.0, 0.0), knee_a * knee_w);

	float foot_w = 1.0 - smoothstep(0.05, 0.12, h);
	float foot_a = clamp(-(hip_a + knee_a) * 0.6, -0.38, 0.30);
	vec3 ankle_p = vec3(0.0, 0.0, -0.075);
	VERTEX = rotate_around(VERTEX, ankle_p, vec3(1.0, 0.0, 0.0), foot_a * foot_w);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(1.0, 0.0, 0.0), foot_a * foot_w);

	float arm_w = smoothstep(0.20, 0.27, abs(op.x)) * smoothstep(0.40, 0.50, h) * (1.0 - smoothstep(0.90, 0.99, h));
	vec3 shoulder_joint = vec3(0.21 * side, 0.0, -0.92);
	VERTEX = rotate_around(VERTEX, shoulder_joint, vec3(0.0, 1.0, 0.0), -side * 0.26 * arm_w);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(0.0, 1.0, 0.0), -side * 0.26 * arm_w);

	float arm_phase = walk_phase + (side > 0.0 ? PI : 0.0);
	float arm_a = 0.38 * stride_amount * w * sin(arm_phase);
	vec3 shoulder_p = vec3(0.0, 0.0, -0.92);
	VERTEX = rotate_around(VERTEX, shoulder_p, vec3(1.0, 0.0, 0.0), arm_a * arm_w);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(1.0, 0.0, 0.0), arm_a * arm_w);

	float fore_w = arm_w * (1.0 - smoothstep(0.66, 0.78, h));
	float elbow_a = -(0.15 + 0.30 * max(0.0, -sin(arm_phase))) * w;
	vec3 elbow_p = vec3(0.0, 0.0, -0.76);
	VERTEX = rotate_around(VERTEX, elbow_p, vec3(1.0, 0.0, 0.0), elbow_a * fore_w);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(1.0, 0.0, 0.0), elbow_a * fore_w);

	float up_w = smoothstep(0.60, 0.86, h);
	float twist = 0.06 * w * sin(walk_phase) * up_w;
	VERTEX = rotate_around(VERTEX, vec3(0.0, 0.0, -0.70), vec3(0.0, 0.0, 1.0), twist);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(0.0, 0.0, 1.0), twist);

	float head_w = smoothstep(0.98, 1.04, h);
	VERTEX = rotate_around(VERTEX, vec3(0.0, 0.0, -0.98), vec3(0.0, 0.0, 1.0), -twist * 0.85 * head_w);
	NORMAL = rotate_around(NORMAL, vec3(0.0), vec3(0.0, 0.0, 1.0), -twist * 0.85 * head_w);
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = texture(orm_tex, UV).g;
	METALLIC = texture(orm_tex, UV).b;
	SPECULAR = specular_value;
}
