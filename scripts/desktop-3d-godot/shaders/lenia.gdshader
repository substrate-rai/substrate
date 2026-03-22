shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*6.0;vec3 col=vec3(0.01,0.005,0.02);
	// Lenia-inspired: continuous CA with smooth kernel
	// Approximate by computing neighborhood activation
	float R=1.5; // kernel radius
	float mu=0.15;float sigma=0.017; // growth function params
	float activation=0.0;float weight_sum=0.0;
	// Sample neighborhood with kernel K(r) = exp(-(r/R)^2 * 4) * bump
	for(int dx=-3;dx<=3;dx++){for(int dy=-3;dy<=3;dy++){
		vec2 offset=vec2(float(dx),float(dy))*R*0.4;
		vec2 sp=p+offset;
		float r=length(offset)/R;
		if(r>1.0)continue;
		// Kernel: ring-shaped (Lenia's characteristic)
		float kernel=exp(-pow((r-0.5)*4.0,2.0));
		// State at sample point (procedural, animated)
		float state=0.0;
		// Multiple orbiting blobs (Lenia creatures)
		for(int c=0;c<4;c++){
			float fc=float(c);
			vec2 center=vec2(sin(fc*1.7+t*0.2)*3.0,cos(fc*2.3+t*0.15)*3.0);
			float blob_r=length(sp-center);
			float creature=exp(-blob_r*blob_r*0.5);
			// Internal structure: ring pattern
			creature*=0.5+0.5*cos(blob_r*5.0-t*2.0+fc);
			state+=creature;
		}
		activation+=state*kernel;
		weight_sum+=kernel;
	}}
	activation/=max(weight_sum,0.001);
	// Growth function G(u) = 2*exp(-(u-mu)^2/(2*sigma^2)) - 1
	float growth=2.0*exp(-pow(activation-mu,2.0)/(2.0*sigma*sigma))-1.0;
	// Growth coloring
	if(growth>0.0)col+=pal(activation*3.0+t*0.02)*growth*0.6;
	else col+=vec3(0.05,0.02,0.1)*(-growth)*0.3;
	// Cell state overlay
	float state_here=0.0;
	for(int c=0;c<4;c++){
		float fc=float(c);
		vec2 center=vec2(sin(fc*1.7+t*0.2)*3.0,cos(fc*2.3+t*0.15)*3.0);
		float blob_r=length(p-center);
		state_here+=exp(-blob_r*blob_r*0.5)*(0.5+0.5*cos(blob_r*5.0-t*2.0+fc));
	}
	col+=pal(state_here+0.3)*state_here*0.3;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
