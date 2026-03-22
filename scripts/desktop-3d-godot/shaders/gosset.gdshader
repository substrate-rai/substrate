shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// Gosset polytopes: E6 (27 verts/6D) morphing to E7 (56 verts/7D)
	float morph=sin(t*0.04)*0.5+0.5; // 0=E6, 1=E7
	int N=int(mix(27.0,56.0,morph));
	float r01=t*0.06,r23=t*0.09,r45=t*0.04;
	float min_d=1e10;float closest=1e10;
	for(int i=0;i<56;i++){
		if(i>=N)break;
		float fi=float(i);
		// Generate vertices on unit sphere in 6D/7D via golden angle
		float golden=(1.0+sqrt(5.0))/2.0;
		float theta=acos(1.0-2.0*(fi+0.5)/float(N));
		float phi1=TAU*fi/golden;
		float phi2=TAU*fi/(golden*golden);
		float phi3=TAU*fi/(golden*golden*golden);
		// 6D/7D vertex
		float v0=sin(theta)*cos(phi1);
		float v1=sin(theta)*sin(phi1);
		float v2=cos(theta)*cos(phi2);
		float v3=cos(theta)*sin(phi2);
		float v4=sin(phi3)*sin(theta)*0.5;
		float v5=cos(phi3)*cos(theta)*0.5;
		float v6=sin(fi*0.7)*morph*0.3; // 7th dimension fades in
		// Rotations
		float c,s,tmp;
		c=cos(r01);s=sin(r01);tmp=v0*c-v1*s;v1=v0*s+v1*c;v0=tmp;
		c=cos(r23);s=sin(r23);tmp=v2*c-v3*s;v3=v2*s+v3*c;v2=tmp;
		c=cos(r45);s=sin(r45);tmp=v4*c-v5*s;v5=v4*s+v5*c;v4=tmp;
		float depth=3.0-v2*0.2-v3*0.15-v4*0.1-v5*0.08-v6*0.05;
		float proj=1.0/depth;
		vec2 screen=vec2(v0,v1)*proj*0.8;
		float d=length(uv-screen);
		closest=min(closest,d);
		col+=pal(fi/float(N)+morph*0.3+t*0.01)*exp(-d*d*4000.0)*0.02;
		// Connect nearby vertices
		for(int j=i+1;j<min(i+4,N);j++){
			float fj=float(j);
			float t2=acos(1.0-2.0*(fj+0.5)/float(N));
			float p1=TAU*fj/golden;float p2b=TAU*fj/(golden*golden);
			float w0=sin(t2)*cos(p1),w1=sin(t2)*sin(p1);
			c=cos(r01);s=sin(r01);tmp=w0*c-w1*s;w1=w0*s+w1*c;w0=tmp;
			float w2=cos(t2)*cos(p2b);float w3=cos(t2)*sin(p2b);
			c=cos(r23);s=sin(r23);tmp=w2*c-w3*s;w3=w2*s+w3*c;w2=tmp;
			float d2b=3.0-w2*0.2-w3*0.15;
			float p2c=1.0/d2b;
			vec2 s2=vec2(w0,w1)*p2c*0.8;
			vec2 pa=uv-screen,ba=s2-screen;
			float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
			float ed=length(pa-ba*h);
			min_d=min(min_d,ed);
		}
	}
	col+=pal(min_d*20.0+t*0.02)*smoothstep(0.004,0.0,min_d)*0.3;
	col+=vec3(1.0,0.85,0.3)*exp(-closest*closest*5000.0)*0.3;
	// Morph indicator
	if(uv.y<-0.95)col+=vec3(0.3)*morph*smoothstep(-1.0,-0.98,uv.x)*0.2;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
