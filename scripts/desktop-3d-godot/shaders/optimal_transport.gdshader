shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
float gauss(vec2 p,vec2 c,float s){return exp(-dot(p-c,p-c)/(2.0*s*s));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*2.0;vec3 col=vec3(0.01,0.005,0.03);
	// Optimal transport: morph between two distributions
	float phase=fract(t*0.05);
	// Source distribution: 3 Gaussians
	float src=0.0;
	src+=gauss(p,vec2(-0.8,-0.5),0.25)*0.5;
	src+=gauss(p,vec2(0.5,-0.7),0.2)*0.7;
	src+=gauss(p,vec2(0.0,0.6),0.3)*0.4;
	// Target distribution: ring
	float r=length(p)-0.7;
	float tgt=exp(-r*r*20.0)*0.6;
	tgt+=gauss(p,vec2(0.0),0.15)*0.3;
	// Interpolate (displacement interpolation approximation)
	float interp=mix(src,tgt,phase);
	// McCann interpolation: geodesic in Wasserstein space
	// Approximate by advecting along gradient of Kantorovich potential
	float phi=mix(src,tgt,0.5); // midpoint potential
	vec2 grad=vec2(dFdx(phi),dFdy(phi));
	float flow_strength=length(grad);
	// Density coloring
	col+=pal(interp*3.0+t*0.02)*interp*0.8;
	// Flow field visualization
	if(flow_strength>0.01){
		vec2 flow_dir=grad/flow_strength;
		float streamline=sin(dot(p,flow_dir)*20.0-t*3.0)*0.5+0.5;
		streamline*=smoothstep(0.0,0.1,flow_strength);
		col+=vec3(0.3,0.5,0.8)*streamline*0.15;
	}
	// Source/target indicators
	col+=vec3(0.8,0.2,0.1)*src*(1.0-phase)*0.2;
	col+=vec3(0.1,0.6,0.3)*tgt*phase*0.2;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
