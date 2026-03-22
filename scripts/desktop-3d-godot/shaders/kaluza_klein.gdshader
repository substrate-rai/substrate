shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	vec2 p=uv*4.0;
	// Kaluza-Klein: 5D = 4D gravity + electromagnetism
	// The 5th dimension is a tiny circle at each point
	// Visualize: 2D space + circle fiber at each point
	// EM field emerges from curvature of the circle bundle
	// Simulate an EM wave propagating through the fiber bundle
	float em_phase=p.x*2.0-t*3.0; // propagating wave
	float em_amplitude=0.5*sin(em_phase)*exp(-p.y*p.y*0.1);
	// The extra dimension circle radius varies = EM field strength
	float base_radius=0.15;
	float fiber_radius=base_radius+em_amplitude*0.1;
	// Draw fiber circles at grid points
	for(int i=-5;i<=5;i++){for(int j=-3;j<=3;j++){
		vec2 base=vec2(float(i)*0.8,float(j)*0.8);
		float local_em=0.5*sin(base.x*2.0-t*3.0)*exp(-base.y*base.y*0.1);
		float local_r=base_radius+local_em*0.1;
		// Draw circle
		float cd=abs(length(p-base)-local_r);
		float ring=smoothstep(0.015,0.0,cd);
		// Color by EM field value
		vec3 ring_col;
		if(local_em>0.0)ring_col=mix(vec3(0.2,0.1,0.4),vec3(0.8,0.2,0.1),local_em*2.0);
		else ring_col=mix(vec3(0.2,0.1,0.4),vec3(0.1,0.3,0.8),-local_em*2.0);
		col+=ring_col*ring*0.6;
		col+=ring_col*clamp(0.003/(cd+0.001),0.0,1.0)*0.04;
		// Momentum mode arrows (particle moving around circle)
		float momentum_phase=local_em*TAU+t*2.0;
		vec2 arrow_pos=base+vec2(cos(momentum_phase),sin(momentum_phase))*local_r;
		float arrow_d=length(p-arrow_pos);
		col+=vec3(1.0,0.85,0.3)*exp(-arrow_d*arrow_d*200.0)*0.2;
	}}
	// Gravitational field lines (vertical)
	float grav=abs(sin(p.x*PI)*0.5);
	col+=vec3(0.1,0.15,0.2)*smoothstep(0.03,0.0,grav)*0.1;
	// EM wave visualization overlay
	float wave=sin(p.x*4.0-t*6.0)*exp(-p.y*p.y*0.2)*0.5;
	col+=pal(wave+0.5)*abs(wave)*0.08;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
