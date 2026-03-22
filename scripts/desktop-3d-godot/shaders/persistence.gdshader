shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// Persistent homology: sublevel set filtration of a function
	// As threshold rises, topological features (components, loops) appear and die
	float threshold=fract(t*0.05)*2.0-0.5; // sweep threshold
	// Function to filter
	vec2 p=uv*4.0;
	float f=noise(p*1.5+t*0.1)*0.5+noise(p*3.0)*0.3+noise(p*6.0)*0.15;
	// Sublevel set: f < threshold
	float in_sublevel=smoothstep(threshold+0.02,threshold-0.02,f);
	// Level set (boundary)
	float level_set=smoothstep(0.03,0.0,abs(f-threshold));
	// Color sublevel set
	col+=pal(f*2.0+0.3)*in_sublevel*0.4;
	// Level set contour (bright)
	col+=vec3(1.0,0.95,0.85)*level_set*0.6;
	// Birth/death events: local minima (births) and saddle points (deaths)
	float fx=noise((p+vec2(0.01,0))*1.5+t*0.1)*0.5+noise((p+vec2(0.01,0))*3.0)*0.3;
	float fy=noise((p+vec2(0,0.01))*1.5+t*0.1)*0.5+noise((p+vec2(0,0.01))*3.0)*0.3;
	float grad_mag=length(vec2(fx-f,fy-f))/0.01;
	float critical=exp(-grad_mag*50.0);
	// Local min (birth) = warm, saddle (death) = cool
	float fxx=(fx+noise((p-vec2(0.01,0))*1.5+t*0.1)*0.5-2.0*f);
	if(fxx>0.0)col+=vec3(0.2,0.6,1.0)*critical*0.5; // minimum: birth
	else col+=vec3(1.0,0.3,0.2)*critical*0.5; // saddle: death
	// Persistence diagram in corner
	float pd_x=(uv.x+0.7)*5.0;float pd_y=(uv.y+0.7)*5.0;
	if(pd_x>0.0&&pd_x<1.0&&pd_y>0.0&&pd_y<1.0){
		// Diagonal
		float diag=smoothstep(0.02,0.0,abs(pd_x-pd_y));
		col+=vec3(0.3)*diag*0.2;
	}
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
