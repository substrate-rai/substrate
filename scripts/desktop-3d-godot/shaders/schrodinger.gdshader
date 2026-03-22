shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*10.0;vec3 col=vec3(0.01,0.005,0.03);
	// Quantum wave packet in 2D: superposition of plane waves
	// Double-slit interference pattern
	float slit_sep=2.0;float slit_width=0.3;float wavelength=1.0+0.3*sin(t*0.1);
	float k=TAU/wavelength;
	// Two slit sources
	vec2 s1=vec2(-5.0,slit_sep*0.5);vec2 s2=vec2(-5.0,-slit_sep*0.5);
	float r1=length(p-s1);float r2=length(p-s2);
	// Spherical waves from each slit
	float psi_r1=cos(k*r1-t*3.0)/sqrt(r1+0.5);
	float psi_i1=sin(k*r1-t*3.0)/sqrt(r1+0.5);
	float psi_r2=cos(k*r2-t*3.0)/sqrt(r2+0.5);
	float psi_i2=sin(k*r2-t*3.0)/sqrt(r2+0.5);
	// Superposition
	float psi_r=psi_r1+psi_r2;float psi_i=psi_i1+psi_i2;
	float prob=psi_r*psi_r+psi_i*psi_i; // |psi|^2
	float phase=atan(psi_i,psi_r);
	// Probability density coloring
	col+=pal(phase/TAU+0.5)*prob*0.5;
	// Phase as hue, probability as brightness
	float brightness=sqrt(prob)*0.7;
	col+=pal(phase/TAU+t*0.01)*brightness;
	// Slit barrier
	float barrier_x=abs(p.x+5.0);
	if(barrier_x<0.15){
		float slit1=smoothstep(slit_width,0.0,abs(p.y-slit_sep*0.5));
		float slit2=smoothstep(slit_width,0.0,abs(p.y+slit_sep*0.5));
		if(slit1<0.1&&slit2<0.1)col=vec3(0.3,0.3,0.35);
	}
	// Screen on right showing interference pattern
	if(abs(p.x-8.0)<0.1)col+=vec3(0.8)*prob*0.3;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
