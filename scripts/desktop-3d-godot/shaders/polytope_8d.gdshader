shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(0.8,1.0,0.6)*t+vec3(0.0,0.1,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// 8D hypercube: 256 vertices, 1024 edges
	// Vertex i: 8-bit pattern, each bit = ±1
	float r01=t*0.05,r23=t*0.08,r45=t*0.03,r67=t*0.06;
	float min_d=1e10;float closest=1e10;
	for(int i=0;i<256;i++){
		float v[8];
		for(int b=0;b<8;b++)v[b]=float((i>>b)&1)*2.0-1.0;
		// 4 rotations in 8D
		float c,s,tmp;
		c=cos(r01);s=sin(r01);tmp=v[0]*c-v[1]*s;v[1]=v[0]*s+v[1]*c;v[0]=tmp;
		c=cos(r23);s=sin(r23);tmp=v[2]*c-v[3]*s;v[3]=v[2]*s+v[3]*c;v[2]=tmp;
		c=cos(r45);s=sin(r45);tmp=v[4]*c-v[5]*s;v[5]=v[4]*s+v[5]*c;v[4]=tmp;
		c=cos(r67);s=sin(r67);tmp=v[6]*c-v[7]*s;v[7]=v[6]*s+v[7]*c;v[6]=tmp;
		float depth=4.0-v[2]*0.15-v[3]*0.12-v[4]*0.1-v[5]*0.08-v[6]*0.06-v[7]*0.04;
		float proj=1.0/depth;
		vec2 screen=vec2(v[0],v[1])*proj*0.4;
		float d=length(uv-screen);
		closest=min(closest,d);
		col+=pal(float(i)/256.0+t*0.01)*exp(-d*d*5000.0)*0.005;
		// Edges: differ in exactly 1 bit
		for(int bit=0;bit<8;bit++){
			int nb=i^(1<<bit);
			if(nb<=i)continue;
			float v2[8];for(int b2=0;b2<8;b2++)v2[b2]=float((nb>>b2)&1)*2.0-1.0;
			c=cos(r01);s=sin(r01);tmp=v2[0]*c-v2[1]*s;v2[1]=v2[0]*s+v2[1]*c;v2[0]=tmp;
			c=cos(r23);s=sin(r23);tmp=v2[2]*c-v2[3]*s;v2[3]=v2[2]*s+v2[3]*c;v2[2]=tmp;
			c=cos(r45);s=sin(r45);tmp=v2[4]*c-v2[5]*s;v2[5]=v2[4]*s+v2[5]*c;v2[4]=tmp;
			c=cos(r67);s=sin(r67);tmp=v2[6]*c-v2[7]*s;v2[7]=v2[6]*s+v2[7]*c;v2[6]=tmp;
			float d2=4.0-v2[2]*0.15-v2[3]*0.12-v2[4]*0.1-v2[5]*0.08-v2[6]*0.06-v2[7]*0.04;
			float p2=1.0/d2;
			vec2 s2=vec2(v2[0],v2[1])*p2*0.4;
			vec2 pa=uv-screen,ba=s2-screen;
			float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
			float ed=length(pa-ba*h);
			min_d=min(min_d,ed);
		}
	}
	col+=pal(min_d*30.0+t*0.02)*smoothstep(0.003,0.0,min_d)*0.4;
	col+=pal(0.5)*clamp(0.001/(min_d+0.001),0.0,1.0)*0.06;
	col+=vec3(1.0,0.85,0.3)*exp(-closest*closest*8000.0)*0.2;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
