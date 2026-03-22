shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
vec2 cmul(vec2 a,vec2 b){return vec2(a.x*b.x-a.y*b.y,a.x*b.y+a.y*b.x);}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;vec2 p=uv*3.0;
	vec3 col=vec3(0.01,0.005,0.03);
	// Langlands: automorphic forms and L-functions
	// Visualize the Hecke eigenvalue field for GL(2)
	// Approximate via Ramanujan tau function / modular discriminant
	float tau_sum=0.0;
	for(int n=1;n<=30;n++){
		float fn=float(n);
		// Ramanujan tau approximation via q-expansion
		float q_mag=exp(-TAU*p.y/fn);
		if(p.y<0.1)q_mag=0.0;
		float phase=TAU*p.x*fn+t*0.1*fn;
		tau_sum+=q_mag*sin(phase)*pow(-1.0,float(n+1));
	}
	// Dual side: Galois representation (Frobenius eigenvalues)
	float galois=0.0;
	for(int p_prime=0;p_prime<10;p_prime++){
		float pp=float(p_prime)*2.0+3.0; // odd primes
		float eigenval=2.0*cos(TAU*p.x/pp+t*0.05);
		float weight=exp(-abs(p.y-eigenval*0.3)*3.0);
		galois+=weight*0.1;
	}
	// Automorphic side (warm colors)
	col+=pal(tau_sum*0.3+0.2)*abs(tau_sum)*0.15;
	// Galois side (cool colors)
	col+=pal(galois*2.0+0.6)*galois*0.6;
	// The Langlands correspondence: where both sides agree, bright
	float correspondence=abs(tau_sum)*galois;
	col+=vec3(1.0,0.85,0.3)*correspondence*0.3;
	// L-function zeros (vertical lines at critical points)
	for(int i=0;i<5;i++){
		float fi=float(i);
		float zero_y=14.13+fi*7.0+sin(t*0.03+fi)*2.0; // approximate zeta zeros
		float zero_d=abs(p.y*5.0-zero_y);
		col+=vec3(1.0)*exp(-zero_d*zero_d*2.0)*0.05;
	}
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
