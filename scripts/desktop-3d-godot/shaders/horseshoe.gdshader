shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(0.8,1.0,0.6)*t+vec3(0.0,0.1,0.2)));}
vec2 horseshoe(vec2 p,float s){p.x*=s;p.y/=s;if(p.x>1.0){p.x=2.0*s-p.x;p.y=1.0-p.y;}return p;}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;vec2 p=uv*0.5+0.5;
	vec3 col=vec3(0.02,0.01,0.04);float stretch=2.0+sin(t*0.1)*0.5;
	vec2 fwd=p;float fe=0.0;
	for(int i=0;i<20;i++){fwd=horseshoe(fwd,stretch);if(fwd.x<0.0||fwd.x>1.0||fwd.y<0.0||fwd.y>1.0){fe=float(i)/20.0;break;}}
	vec2 bwd=p;float be=0.0;
	for(int i=0;i<20;i++){if(bwd.y>0.5){bwd.y=1.0-bwd.y;bwd.x=2.0*stretch-bwd.x;}bwd.x/=stretch;bwd.y*=stretch;if(bwd.x<0.0||bwd.x>1.0||bwd.y<0.0||bwd.y>1.0){be=float(i)/20.0;break;}}
	if(fe==0.0)col+=vec3(0.8,0.3,0.1)*0.6;else col+=pal(fe+0.3)*fe*0.3;
	if(be==0.0)col+=vec3(0.1,0.3,0.8)*0.4;else col+=pal(be+0.7)*be*0.2;
	if(fe==0.0&&be==0.0)col+=vec3(1.0,0.85,0.3)*0.5;
	col+=vec3(0.3)*smoothstep(0.01,0.0,min(min(p.x,1.0-p.x),min(p.y,1.0-p.y)))*0.2;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.2;col=col/(col+vec3(1.0));ALBEDO=col;
}
