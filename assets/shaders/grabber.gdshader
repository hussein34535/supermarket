shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float specular_value : hint_range(0.0, 1.0) = 0.5;
uniform float close : hint_range(0.0, 1.0) = 0.0;


vec2 rotate_xy(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}


void vertex() {
	vec3 rp = vec3(VERTEX.x, -VERTEX.z, VERTEX.y);
	vec3 rn = vec3(NORMAL.x, -NORMAL.z, NORMAL.y);
	vec3 rt = vec3(TANGENT.x, -TANGENT.z, TANGENT.y);

	float jaw_x = smoothstep(0.515, 0.528, rp.x);
	float upper = jaw_x * smoothstep(0.225, 0.245, rp.y);
	float lower = jaw_x * (1.0 - smoothstep(0.195, 0.215, rp.y));
	float jaw_angle = close * 0.48 * (lower - upper);
	vec2 jaw_pivot = vec2(0.515, 0.22);
	rp.xy = jaw_pivot + rotate_xy(rp.xy - jaw_pivot, jaw_angle);
	rn.xy = rotate_xy(rn.xy, jaw_angle);
	rt.xy = rotate_xy(rt.xy, jaw_angle);

	float trigger = step(-0.335, rp.x) * step(rp.x, -0.272) * step(0.085, rp.y) * step(rp.y, 0.215);
	rp.x -= trigger * close * 0.024;
	rp.y -= trigger * close * 0.004;

	VERTEX = vec3(rp.x, rp.z, -rp.y);
	NORMAL = vec3(rn.x, rn.z, -rn.y);
	TANGENT = vec3(rt.x, rt.z, -rt.y);
}


void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	METALLIC = texture(orm_tex, UV).b;
	ROUGHNESS = texture(orm_tex, UV).g;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 1.0;
	SPECULAR = specular_value;
}
