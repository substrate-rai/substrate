shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
float hash(float n){return fract(sin(n)*43758.5453);}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.02);
	// Dyson Brownian motion: N eigenvalues with log repulsion
	int N=40;
	float positions[40];
	// Initialize from Wigner semicircle
	for(int i=0;i<N;i++){float fi=float(i);positions[i]=(fi/float(N)-0.5)*3.0+hash(fi)*0.1;}
	// Simulate with time
	for(int step=0;step<50;step++){
		for(int i=0;i<N;i++){
			float force=0.0;
			for(int j=0;j<N;j++){
				if(i!=j){float dx=positions[i]-positions[j];force+=1.0/(dx+sign(dx)*0.01)/float(N);}
			}
			// Brownian noise approximation
			float noise=sin(float(i)*127.1+float(step)*311.7+t*0.5)*0.02;
			positions[i]+=(force*0.001+noise-positions[i]*0.001);
		}
	}
	// Draw eigenvalues as vertical lines with glow
	for(int i=0;i<N;i++){
		float x=positions[i]/2.0;
		float d=abs(uv.x-x);
		float line=smoothstep(0.008,0.0,d);
		col+=pal(float(i)/float(N)+t*0.01)*line*0.5;
		col+=pal(float(i)/float(N)+0.3)*clamp(0.003/(d+0.001),0.0,1.0)*0.05;
	}
	// Wigner semicircle overlay
	float sc_x=uv.x*2.0;float sc_y=uv.y+0.5;
	float semicircle=sqrt(max(1.0-sc_x*sc_x,0.0))*0.6;
	float sc_d=abs(sc_y-semicircle);
	col+=vec3(0.5,0.3,0.7)*smoothstep(0.02,0.0,sc_d)*0.2;
	// Level spacing histogram at bottom
	float spacing_y=uv.y+0.8;
	if(spacing_y>0.0&&spacing_y<0.3){
		float wigner_surmise=spacing_y*3.3*PI/2.0*exp(-PI/4.0*spacing_y*spacing_y*9.0);
		col+=vec3(0.3,0.6,0.3)*wigner_surmise*0.3;
	}
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
