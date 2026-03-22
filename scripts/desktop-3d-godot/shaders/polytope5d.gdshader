shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(0.8,1.0,0.6)*t+vec3(0.0,0.1,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// 5D hypercube (penteract): 32 vertices, 80 edges
	// Vertices: all combinations of (+/-1, +/-1, +/-1, +/-1, +/-1)
	// Project 5D -> 2D via rotation + perspective
	float r1=t*0.07,r2=t*0.11,r3=t*0.05,r4=t*0.09;
	float min_edge_d=1e10;float closest_vert=1e10;
	for(int v=0;v<32;v++){
		// 5D vertex from bit pattern
		float x=float((v&1)*2-1);float y=float(((v>>1)&1)*2-1);
		float z=float(((v>>2)&1)*2-1);float w=float(((v>>3)&1)*2-1);
		float u5=float(((v>>4)&1)*2-1);
		// Rotate in 5D (4 rotation planes)
		float c1=cos(r1),s1=sin(r1);float nx=x*c1-w*s1;float nw=x*s1+w*c1;x=nx;w=nw;
		float c2=cos(r2),s2=sin(r2);float ny=y*c2-u5*s2;float nu=y*s2+u5*c2;y=ny;u5=nu;
		float c3=cos(r3),s3=sin(r3);float nz=z*c3-w*s3;nw=z*s3+w*c3;z=nz;w=nw;
		float c4=cos(r4),s4=sin(r4);nx=x*c4-u5*s4;nu=x*s4+u5*c4;x=nx;u5=nu;
		// Perspective projection 5D->2D
		float proj=1.0/(4.0-w-u5*0.5);
		vec2 screen=vec2(x,y)*proj;
		float d=length(uv-screen);
		closest_vert=min(closest_vert,d);
		// Draw edges to neighbors (differ in exactly 1 bit)
		for(int bit=0;bit<5;bit++){
			int neighbor=v^(1<<bit);
			if(neighbor<=v)continue; // avoid duplicates
			float ex=float((neighbor&1)*2-1);float ey=float(((neighbor>>1)&1)*2-1);
			float ez=float(((neighbor>>2)&1)*2-1);float ew=float(((neighbor>>3)&1)*2-1);
			float eu=float(((neighbor>>4)&1)*2-1);
			float tnx=ex*c1-ew*s1;float tnw=ex*s1+ew*c1;ex=tnx;ew=tnw;
			float tny=ey*c2-eu*s2;float tnu=ey*s2+eu*c2;ey=tny;eu=tnu;
			float tnz=ez*c3-ew*s3;tnw=ez*s3+ew*c3;ez=tnz;ew=tnw;
			tnx=ex*c4-eu*s4;tnu=ex*s4+eu*c4;ex=tnx;eu=tnu;
			float proj2=1.0/(4.0-ew-eu*0.5);
			vec2 screen2=vec2(ex,ey)*proj2;
			// Distance to edge
			vec2 pa=uv-screen,ba=screen2-screen;
			float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
			float ed=length(pa-ba*h);
			min_edge_d=min(min_edge_d,ed);
		}
	}
	// Edges
	float edge_glow=smoothstep(0.008,0.0,min_edge_d);
	col+=pal(min_edge_d*20.0+t*0.03)*edge_glow*0.6;
	col+=pal(0.5)*clamp(0.003/(min_edge_d+0.001),0.0,1.0)*0.1;
	// Vertices
	col+=vec3(1.0,0.85,0.3)*exp(-closest_vert*closest_vert*2000.0)*0.5;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
