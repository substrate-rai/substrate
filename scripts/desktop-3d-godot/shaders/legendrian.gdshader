shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(0.8,1.0,0.6)*t+vec3(0.1,0.2,0.0)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// Contact geometry: standard contact structure on R^3
	// xi = ker(dz - y*dx) — a plane field that twists along y
	// Project the plane field to 2D and show its structure
	vec2 p=uv*4.0;
	// At each point, the contact plane has normal (y,0,1) (from dz-y*dx=0)
	// Project: show the angle of the contact plane
	float y_coord=p.y+sin(t*0.1)*0.5;
	float plane_angle=atan(1.0,y_coord); // angle of contact plane
	// Visualize as a vector field (Reeb vector field direction)
	vec2 reeb=normalize(vec2(cos(plane_angle),sin(plane_angle)));
	// LIC-like streamlines
	vec2 trace=p;float stream=0.0;
	for(int i=0;i<30;i++){
		float y_t=trace.y+sin(t*0.1)*0.5;
		float angle_t=atan(1.0,y_t);
		vec2 dir=vec2(cos(angle_t),sin(angle_t));
		trace+=dir*0.05;
		stream+=sin(length(trace)*8.0+float(i)*0.5)*0.03;
	}
	col+=pal(plane_angle/PI+t*0.02)*abs(stream)*0.5;
	// Legendrian trefoil knot: curve tangent to contact planes everywhere
	float knot_dist=1e10;
	for(int i=0;i<200;i++){
		float s=float(i)/200.0*TAU*2.0;
		// Legendrian trefoil parameterization
		float kx=sin(s)+2.0*sin(2.0*s);
		float ky=cos(s)-2.0*cos(2.0*s);
		// Animate
		kx=kx*0.4+sin(t*0.05)*0.2;ky=ky*0.4+cos(t*0.04)*0.2;
		knot_dist=min(knot_dist,length(p-vec2(kx,ky)));
	}
	col+=pal(knot_dist*3.0+0.5)*smoothstep(0.1,0.0,knot_dist)*0.6;
	col+=vec3(1.0,0.85,0.3)*exp(-knot_dist*20.0)*0.2;
	// Twisting indicator (how fast contact planes rotate)
	float twist_rate=1.0/(1.0+y_coord*y_coord);
	col+=vec3(0.3,0.5,0.8)*twist_rate*0.05;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
