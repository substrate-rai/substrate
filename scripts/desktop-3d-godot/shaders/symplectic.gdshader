shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	// Symplectic billiards: particle bouncing inside shapes
	// Phase space (position along boundary, momentum angle)
	vec2 p=uv*PI;
	vec3 col=vec3(0.01,0.005,0.02);
	// Multiple initial conditions
	for(int orbit=0;orbit<40;orbit++){
		float fo=float(orbit);
		float theta=fo*TAU/40.0; // position on boundary
		float phi=0.3+fo*0.02; // launch angle
		float density=0.0;
		for(int bounce=0;bounce<100;bounce++){
			// Billiard map for stadium shape
			float shape_param=0.5+0.3*sin(t*0.05); // animate shape
			// Reflect: new angle based on curvature
			float curvature=1.0+shape_param*cos(2.0*theta);
			phi=mod(phi+PI-2.0*atan(sin(phi)*curvature),TAU);
			theta=mod(theta+phi*0.5,TAU);
			// Map to pixel
			vec2 phase=vec2(theta/PI-1.0,phi/PI-1.0);
			float d=length(uv-phase);
			if(d<0.015) density+=1.0;
		}
		float log_d=log(density+1.0);
		col+=pal(fo/40.0+t*0.01)*min(log_d*0.3,0.5)*0.1;
	}
	// KAM curves (invariant tori appear as smooth curves)
	// Caustic lines
	float caustic=abs(sin(p.x*3.0+p.y*2.0+t*0.2));
	col+=vec3(0.3,0.5,0.8)*smoothstep(0.05,0.0,caustic)*0.08;
	// Axes
	col+=vec3(0.2)*smoothstep(0.01,0.0,abs(uv.x))*0.1;
	col+=vec3(0.2)*smoothstep(0.01,0.0,abs(uv.y))*0.1;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.2;col=col/(col+vec3(1.0));ALBEDO=col;
}
