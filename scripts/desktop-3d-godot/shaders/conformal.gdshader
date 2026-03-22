shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
vec2 cmul(vec2 a,vec2 b){return vec2(a.x*b.x-a.y*b.y,a.x*b.y+a.y*b.x);}
vec2 cdiv(vec2 a,vec2 b){float d=dot(b,b);return vec2(dot(a,b),a.y*b.x-a.x*b.y)/d;}
vec2 csqrt(vec2 z){float r=length(z);float a=atan(z.y,z.x)*0.5;return sqrt(r)*vec2(cos(a),sin(a));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 z=uv*3.0;vec3 col=vec3(0.02,0.01,0.04);
	// Schwarz-Christoffel: conformal map from half-plane to polygon
	// Animate between different maps
	float morph=mod(t*0.08,4.0);
	vec2 w;
	if(morph<1.0){
		// z^2: maps to double-angle
		w=cmul(z,z);
	}else if(morph<2.0){
		// 1/z: inversion
		w=cdiv(vec2(1.0,0.0),z+vec2(0.01,0.0));
	}else if(morph<3.0){
		// Joukowski: z + 1/z (airfoil)
		w=z+cdiv(vec2(1.0,0.0),z+vec2(0.01,0.0));
	}else{
		// exp(z)
		w=exp(z.x)*vec2(cos(z.y),sin(z.y));
	}
	// Domain coloring of the conformal map
	float phase=atan(w.y,w.x)/TAU+0.5;
	float mag=length(w);
	float log_mag=log(mag+0.001);
	col=pal(phase)*0.7;
	// Grid lines in w-plane (show how grid deforms)
	float grid_re=abs(fract(w.x)-0.5)*2.0;
	float grid_im=abs(fract(w.y)-0.5)*2.0;
	float grid=min(smoothstep(0.05,0.0,1.0-grid_re),1.0)+min(smoothstep(0.05,0.0,1.0-grid_im),1.0);
	col+=vec3(1.0,0.95,0.9)*grid*0.2;
	// Circles in w-plane (show angle preservation = conformality)
	float circ=abs(fract(log_mag*0.5)-0.5)*2.0;
	col+=vec3(0.5,0.6,0.8)*smoothstep(0.05,0.0,1.0-circ)*0.1;
	// Critical points (where derivative = 0)
	float deriv_mag; if(morph<1.0)deriv_mag=2.0*length(z);else deriv_mag=1.0/(dot(z,z)+0.01);
	float crit=exp(-deriv_mag*0.5)*0.3;
	col+=vec3(1.0,0.3,0.2)*crit;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
