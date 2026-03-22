shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t) { return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25))); }
void fragment() {
	vec2 uv = UV*2.0-1.0;
	float t = TIME;
	vec2 p = uv*8.0+vec2(t*0.1,t*0.07);
	vec3 col = vec3(0.02,0.01,0.04);
	float vals[5];
	for(int j=0;j<5;j++) { float a=float(j)*TAU/5.0; vals[j]=dot(p,vec2(cos(a),sin(a))); }
	float min_frac=1.0; int min_idx=0; float second_frac=1.0; int second_idx=0;
	for(int j=0;j<5;j++) {
		float f=abs(fract(vals[j])-0.5)*2.0;
		if(f<min_frac){second_frac=min_frac;second_idx=min_idx;min_frac=f;min_idx=j;}
		else if(f<second_frac){second_frac=f;second_idx=j;}
	}
	col += pal(float(min_idx*5+second_idx)/25.0+t*0.01)*0.4;
	for(int j=0;j<5;j++) {
		float f=abs(fract(vals[j])-0.5)*2.0;
		col += pal(float(j)*0.2+0.5)*smoothstep(0.05,0.0,f)*0.4;
		col += pal(float(j)*0.2+0.7)*clamp(0.01/(f+0.01),0.0,1.0)*0.02;
	}
	float vs=0.0; for(int j=0;j<5;j++){float f=abs(fract(vals[j])-0.5)*2.0;vs+=smoothstep(0.1,0.0,f);}
	if(vs>3.5) col+=vec3(1.0,0.85,0.3)*(vs-3.5)*0.5;
	col*=1.0+audio_energy*0.2;
	col*=1.0-dot(uv,uv)*0.15;
	col=col/(col+vec3(1.0));
	ALBEDO=col;
}
