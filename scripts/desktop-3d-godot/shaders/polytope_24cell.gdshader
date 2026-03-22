shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// 24-cell: 24 vertices in 4D. Coordinates are all permutations of (±1,±1,0,0)
	// Plus (±1,0,0,0) and permutations — actually the 24 vertices are:
	// 8 vertices: permutations of (±1,0,0,0) = octahedron vertices
	// 16 vertices: (±0.5,±0.5,±0.5,±0.5) = tesseract vertices scaled
	// Use the standard: all permutations of (0,0,±1,±1) = 24 vertices
	float r1=t*0.07,r2=t*0.11,r3=t*0.05,r4=t*0.09,r5=t*0.06,r6=t*0.08;
	float min_edge=1e10;float closest_vert=1e10;
	// Generate 24 vertices: all sign/permutation combos of (±1,±1,0,0)
	for(int i=0;i<24;i++){
		vec4 v;
		if(i<8){
			// (±1,0,0,0) and permutations
			int axis=i/2;float sign_v=float(i%2)*2.0-1.0;
			v=vec4(0);
			if(axis==0)v.x=sign_v;else if(axis==1)v.y=sign_v;
			else if(axis==2)v.z=sign_v;else v.w=sign_v;
		}else{
			// (±0.5,±0.5,±0.5,±0.5) — 16 vertices
			int idx=i-8;
			v=vec4(((idx&1)*2-1),((idx>>1&1)*2-1),((idx>>2&1)*2-1),((idx>>3&1)*2-1))*0.5;
		}
		// 4D rotations (6 planes)
		float c,s;
		c=cos(r1);s=sin(r1);vec4 nv=v;nv.x=v.x*c-v.y*s;nv.y=v.x*s+v.y*c;v=nv;
		c=cos(r2);s=sin(r2);nv=v;nv.z=v.z*c-v.w*s;nv.w=v.z*s+v.w*c;v=nv;
		c=cos(r3);s=sin(r3);nv=v;nv.x=v.x*c-v.z*s;nv.z=v.x*s+v.z*c;v=nv;
		c=cos(r4);s=sin(r4);nv=v;nv.y=v.y*c-v.w*s;nv.w=v.y*s+v.w*c;v=nv;
		c=cos(r5);s=sin(r5);nv=v;nv.x=v.x*c-v.w*s;nv.w=v.x*s+v.w*c;v=nv;
		c=cos(r6);s=sin(r6);nv=v;nv.y=v.y*c-v.z*s;nv.z=v.y*s+v.z*c;v=nv;
		float proj=1.0/(3.0-v.w);
		vec2 screen=v.xy*proj;
		float d=length(uv-screen);
		closest_vert=min(closest_vert,d);
		// Edges: connect to all vertices at distance sqrt(2)
		for(int j=i+1;j<24;j++){
			vec4 v2;
			if(j<8){int ax=j/2;float sv=float(j%2)*2.0-1.0;v2=vec4(0);if(ax==0)v2.x=sv;else if(ax==1)v2.y=sv;else if(ax==2)v2.z=sv;else v2.w=sv;}
			else{int idx2=j-8;v2=vec4(((idx2&1)*2-1),((idx2>>1&1)*2-1),((idx2>>2&1)*2-1),((idx2>>3&1)*2-1))*0.5;}
			// Apply same rotations
			c=cos(r1);s=sin(r1);nv=v2;nv.x=v2.x*c-v2.y*s;nv.y=v2.x*s+v2.y*c;v2=nv;
			c=cos(r2);s=sin(r2);nv=v2;nv.z=v2.z*c-v2.w*s;nv.w=v2.z*s+v2.w*c;v2=nv;
			c=cos(r3);s=sin(r3);nv=v2;nv.x=v2.x*c-v2.z*s;nv.z=v2.x*s+v2.z*c;v2=nv;
			c=cos(r4);s=sin(r4);nv=v2;nv.y=v2.y*c-v2.w*s;nv.w=v2.y*s+v2.w*c;v2=nv;
			c=cos(r5);s=sin(r5);nv=v2;nv.x=v2.x*c-v2.w*s;nv.w=v2.x*s+v2.w*c;v2=nv;
			c=cos(r6);s=sin(r6);nv=v2;nv.y=v2.y*c-v2.z*s;nv.z=v2.y*s+v2.z*c;v2=nv;
			float proj2=1.0/(3.0-v2.w);
			vec2 screen2=v2.xy*proj2;
			// Edge distance
			vec2 pa=uv-screen,ba=screen2-screen;
			float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
			float ed=length(pa-ba*h);
			min_edge=min(min_edge,ed);
		}
	}
	float edge_glow=smoothstep(0.006,0.0,min_edge);
	col+=pal(min_edge*20.0+t*0.03)*edge_glow*0.6;
	col+=pal(0.5)*clamp(0.002/(min_edge+0.001),0.0,1.0)*0.08;
	col+=vec3(1.0,0.85,0.3)*exp(-closest_vert*closest_vert*3000.0)*0.5;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
