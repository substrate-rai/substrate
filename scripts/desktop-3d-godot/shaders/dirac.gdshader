shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
vec2 cmul(vec2 a,vec2 b){return vec2(a.x*b.x-a.y*b.y,a.x*b.y+a.y*b.x);}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*5.0;float r=length(p);float theta=atan(p.y,p.x);
	vec3 col=vec3(0.01,0.005,0.03);
	// Hydrogen-like spinor wavefunctions: psi = R(r)*Y(theta,phi)*spinor
	for(int n=1;n<=4;n++){
		float fn=float(n);
		for(int l=0;l<n;l++){
			float fl=float(l);
			// Radial part (simplified Laguerre)
			float rho=2.0*r/fn;
			float R=exp(-rho*0.5)*pow(rho,fl);
			// Angular part (spherical harmonic magnitude)
			float Y;
			if(l==0) Y=0.28;
			else if(l==1) Y=0.49*abs(cos(theta));
			else if(l==2) Y=0.63*abs(3.0*cos(theta)*cos(theta)-1.0);
			else Y=0.75*abs(cos(theta)*sin(theta)*sin(theta));
			float psi2=R*R*Y*Y;
			// Spinor phase (spin-1/2 rotation)
			float spin_phase=theta*0.5+t*0.3*fn;
			vec2 spinor=vec2(cos(spin_phase),sin(spin_phase));
			// Up/down component coloring
			float up=spinor.x*spinor.x*psi2;
			float down=spinor.y*spinor.y*psi2;
			col+=pal(fn*0.2+fl*0.1)*up*0.4;
			col+=pal(fn*0.2+fl*0.1+0.5)*down*0.3;
		}
	}
	// Probability current visualization
	float current=sin(theta*2.0-t*1.5)*exp(-r*0.3)*0.1;
	col+=vec3(0.3,0.5,0.8)*max(current,0.0);
	col+=vec3(0.8,0.3,0.3)*max(-current,0.0);
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.2;col=col/(col+vec3(1.0));ALBEDO=col;
}
