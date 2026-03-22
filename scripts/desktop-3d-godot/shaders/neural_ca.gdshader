shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	vec2 p=uv*6.0;
	// Neural CA: approximate learned update rule
	// Perception: Sobel filter on cell state
	// Update: tanh(W2 * relu(W1 * perception + b1) + b2)
	// Animate weights to show different learned behaviors
	float state=0.0;
	// Multiple growing/self-healing patterns
	for(int c_idx=0;c_idx<5;c_idx++){
		float fc=float(c_idx);
		vec2 seed=vec2(sin(fc*2.1+t*0.05)*3.0,cos(fc*1.7+t*0.04)*3.0);
		float r=length(p-seed);
		// NCA-like growth: ring expands from seed
		float growth_front=fract(t*0.2+fc*0.2)*4.0;
		float ring=exp(-pow(r-growth_front,2.0)*2.0);
		// Internal structure (learned pattern)
		float pattern=sin(r*5.0-t*2.0+fc)*cos(atan(p.y-seed.y,p.x-seed.x)*3.0+fc);
		pattern*=smoothstep(growth_front+0.5,growth_front-0.5,r); // only inside grown area
		state+=ring*0.3+pattern*0.15;
		// Self-healing: damage at cursor position
		float cursor_d=length(p-cursor_world_pos.xy*3.0);
		if(cursor_d<0.5){
			float damage=exp(-cursor_d*cursor_d*8.0)*0.5;
			// Regrowth wave emanating from damage site
			float heal=sin((cursor_d-fract(t*0.5)*2.0)*10.0)*exp(-cursor_d*2.0);
			state+=heal*0.1-damage;
		}
	}
	// State coloring
	if(state>0.0)col+=pal(state*2.0+t*0.01)*min(state,1.0)*0.6;
	else col+=pal(-state*2.0+0.5)*min(-state,1.0)*0.3;
	// Cell boundary visualization
	float cell_grid=min(abs(fract(p.x)-0.5),abs(fract(p.y)-0.5))*2.0;
	col+=vec3(0.1)*smoothstep(0.1,0.0,cell_grid)*abs(state)*0.1;
	// Growth front glow
	for(int c_idx=0;c_idx<5;c_idx++){
		float fc=float(c_idx);
		vec2 seed=vec2(sin(fc*2.1+t*0.05)*3.0,cos(fc*1.7+t*0.04)*3.0);
		float r=length(p-seed);
		float front=fract(t*0.2+fc*0.2)*4.0;
		col+=vec3(1.0,0.85,0.3)*exp(-pow(r-front,2.0)*10.0)*0.1;
	}
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
