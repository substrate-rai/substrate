shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(0.8,1.0,0.6)*t+vec3(0.0,0.1,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.02,0.01,0.04);
	int N=7; // number of strands
	float strand_spacing=2.0/float(N);
	// Each strand follows a path determined by braid generators
	for(int s=0;s<7;s++){
		float fs=float(s);
		float x_base=(fs-3.0)*strand_spacing;
		// Braid crossings: strands swap positions at crossing points
		float y=uv.y*4.0+t*0.5;
		float crossing_freq=1.5+fs*0.3;
		float x_offset=sin(y*crossing_freq+fs*1.2)*strand_spacing*0.8;
		// Add another crossing pattern for complex braids
		x_offset+=sin(y*crossing_freq*0.7+fs*2.5+t*0.2)*strand_spacing*0.4;
		float x_pos=x_base+x_offset;
		float d=abs(uv.x-x_pos);
		// Strand thickness varies with depth (over/under crossings)
		float depth=cos(y*crossing_freq+fs*1.2);
		float thickness=0.015+0.005*depth;
		float strand=smoothstep(thickness,thickness*0.3,d);
		// Color by strand and depth
		vec3 strand_col=pal(fs/float(N)+0.1);
		// Darker when going under
		float brightness=(depth>0.0)?1.0:0.5;
		col+=strand_col*strand*brightness*0.6;
		// Glow
		col+=strand_col*clamp(0.003/(d+0.001),0.0,1.0)*0.03;
	}
	// Crossing points glow
	float crossing_glow=0.0;
	for(int i=0;i<5;i++){
		float fi=float(i);
		vec2 cp=vec2(sin(fi*2.1+t*0.1)*0.5,sin(fi*1.7+t*0.15)*0.8);
		crossing_glow+=exp(-length(uv-cp)*length(uv-cp)*20.0)*0.1;
	}
	col+=vec3(1.0,0.85,0.3)*crossing_glow;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.2;col=col/(col+vec3(1.0));ALBEDO=col;
}
