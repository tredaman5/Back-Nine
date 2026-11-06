shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Dashed aim line. Dashes scroll away from the ball.
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float line_length = 50.0;
uniform float dash_period = 3.0;   // yards per dash + gap
uniform float dash_fill = 0.55;    // fraction of each period that is drawn
uniform float scroll_speed = 6.0;  // yards per second

varying float dist_from_ball;

void vertex() {
	// The mesh is centred at z = -line_length / 2 from the ball, so distance from the
	// ball along the line is (line_length / 2) - local z.
	dist_from_ball = line_length * 0.5 - VERTEX.z;
}

void fragment() {
	float m = fract((dist_from_ball - TIME * scroll_speed) / dash_period);
	if (m > dash_fill) {
		discard;
	}
	float fade = 1.0 - clamp(dist_from_ball / line_length, 0.0, 1.0) * 0.5;
	ALBEDO = line_color.rgb;
	ALPHA = line_color.a * fade;
}
