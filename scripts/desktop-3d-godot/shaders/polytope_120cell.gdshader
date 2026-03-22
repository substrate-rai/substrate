shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// 120-cell: 600 vertices in 4D. Use icosahedral symmetry to generate.
	// Vertices lie on S3 at distance sqrt(2+phi) from origin where phi=(1+sqrt(5))/2
	float phi=(1.0+sqrt(5.0))/2.0;
	float r1=t*0.04,r2=t*0.07,r3=t*0.03,r4=t*0.05;
	float min_d=1e10;
	// Generate vertices: 24 from permutations of (±2,0,0,0) and (±1,±1,±1,±1)
	// Plus 96 from even permutations of (±phi,±phi,±phi,±(phi-2))
	// Plus 192 from even permutations of (±phi^2,±1/phi,±1/phi,0)
	// Approximate with icosahedral orbits for visual effect
	for(int i=0;i<100;i++){
		float fi=float(i);
		// Fibonacci sphere on S3 (approximate vertex distribution)
		float golden=phi;
		float theta1=acos(1.0-2.0*(fi+0.5)/100.0);
		float theta2=TAU*fi/golden;
		float theta3=TAU*fi/(golden*golden);
		vec4 v=vec4(sin(theta1)*cos(theta2),sin(theta1)*sin(theta2),cos(theta1)*cos(theta3),cos(theta1)*sin(theta3));
		// 4D rotations
		float c,s;vec4 nv;
		c=cos(r1);s=sin(r1);nv=v;nv.x=v.x*c-v.w*s;nv.w=v.x*s+v.w*c;v=nv;
		c=cos(r2);s=sin(r2);nv=v;nv.y=v.y*c-v.z*s;nv.z=v.y*s+v.z*c;v=nv;
		c=cos(r3);s=sin(r3);nv=v;nv.x=v.x*c-v.z*s;nv.z=v.x*s+v.z*c;v=nv;
		c=cos(r4);s=sin(r4);nv=v;nv.y=v.y*c-v.w*s;nv.w=v.y*s+v.w*c;v=nv;
		// Stereographic projection from S3
		float proj=1.0/(2.0-v.w);
		vec2 screen=v.xy*proj*0.8;
		float d=length(uv-screen);
		min_d=min(min_d,d);
		// Vertex glow colored by depth (w component)
		float depth_col=(v.w+1.0)*0.5;
		col+=pal(depth_col+fi/100.0)*exp(-d*d*3000.0)*0.012;
		// Connect to nearby vertices (approximate dodecahedral edges)
		for(int j=i+1;j<min(i+5,100);j++){
			float fj=float(j);
			float t1=acos(1.0-2.0*(fj+0.5)/100.0);
			float t2b=TAU*fj/golden;float t3b=TAU*fj/(golden*golden);
			vec4 v2=vec4(sin(t1)*cos(t2b),sin(t1)*sin(t2b),cos(t1)*cos(t3b),cos(t1)*sin(t3b));
			c=cos(r1);s=sin(r1);nv=v2;nv.x=v2.x*c-v2.w*s;nv.w=v2.x*s+v2.w*c;v2=nv;
			c=cos(r2);s=sin(r2);nv=v2;nv.y=v2.y*c-v2.z*s;nv.z=v2.y*s+v2.z*c;v2=nv;
			c=cos(r3);s=sin(r3);nv=v2;nv.x=v2.x*c-v2.z*s;nv.z=v2.x*s+v2.z*c;v2=nv;
			c=cos(r4);s=sin(r4);nv=v2;nv.y=v2.y*c-v2.w*s;nv.w=v2.y*s+v2.w*c;v2=nv;
			float proj2=1.0/(2.0-v2.w);
			vec2 s2=v2.xy*proj2*0.8;
			vec2 pa=uv-screen,ba=s2-screen;
			float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
			float ed=length(pa-ba*h);
			col+=pal(depth_col+0.3)*smoothstep(0.004,0.0,ed)*0.03;
		}
	}
	col+=pal(0.5)*clamp(0.002/(min_d+0.001),0.0,1.0)*0.15;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
