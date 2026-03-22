shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(0.8,1.0,0.6)*t+vec3(0.0,0.1,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.02);
	// Lorenz attractor rendered as density with periodic orbit highlighting
	float cam_a=t*0.08;float ca=cos(cam_a),sa=sin(cam_a);
	float closest=1e10;float orbit_dist=1e10;
	// Main attractor trajectory
	vec3 p3=vec3(1.0,1.0,20.0);float dt=0.005;
	for(int i=0;i<2000;i++){
		float sigma=10.0,rho=28.0,beta=8.0/3.0;
		vec3 dp=vec3(sigma*(p3.y-p3.x),p3.x*(rho-p3.z)-p3.y,p3.x*p3.y-beta*p3.z);
		p3+=dp*dt;
		float rx=p3.x*ca-p3.z*sa;
		vec2 proj=vec2(rx,p3.y)*0.04;
		float d=length(uv-proj);
		closest=min(closest,d);
		// Highlight periodic orbit (approximate period-1 orbit)
		float orbit_r=sqrt(beta*(rho-1.0));
		float orb_d=length(p3.xy-vec2(orbit_r,orbit_r));
		if(orb_d<2.0)orbit_dist=min(orbit_dist,d);
	}
	// Attractor density
	float glow=clamp(0.003/(closest+0.001),0.0,1.0);
	col+=pal(closest*20.0+t*0.02)*glow*0.6;
	// Periodic orbit (the knot) highlighted
	float knot_glow=clamp(0.005/(orbit_dist+0.001),0.0,1.0);
	col+=vec3(1.0,0.85,0.3)*knot_glow*0.4;
	// Background: butterfly wing regions
	float wing_l=exp(-length(uv-vec2(-0.3,0.0))*3.0)*0.03;
	float wing_r=exp(-length(uv-vec2(0.3,0.0))*3.0)*0.03;
	col+=vec3(0.2,0.1,0.3)*(wing_l+wing_r);
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
