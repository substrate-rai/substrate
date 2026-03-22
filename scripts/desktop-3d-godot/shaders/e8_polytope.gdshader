shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
// E8 root system: 240 vertices in 8D
// Generating the 112 roots of D8 plus 128 half-integer roots
// D8 roots: all permutations of (±1,±1,0,0,0,0,0,0) = 112 vectors
// Plus 128 vectors (±1/2)^8 with even number of minus signs
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	float min_edge=1e10;float closest=1e10;
	// 8D rotation angles (pick 4 of the 28 planes to animate)
	float r01=t*0.07,r23=t*0.11,r45=t*0.05,r67=t*0.09;
	// Generate a subset of E8 vertices (full 240 is too many nested loops)
	// Use the 112 D8 roots: ±e_i ± e_j for i<j
	for(int i=0;i<8;i++){for(int j=i+1;j<8;j++){
		for(int si=0;si<2;si++){for(int sj=0;sj<2;sj++){
			float vi=float(si)*2.0-1.0;float vj=float(sj)*2.0-1.0;
			// 8D vertex: e_i*vi + e_j*vj
			float v[8]; for(int k=0;k<8;k++)v[k]=0.0;
			v[i]=vi;v[j]=vj;
			// Apply 4 rotations in 8D
			float c,s,tmp;
			c=cos(r01);s=sin(r01);tmp=v[0]*c-v[1]*s;v[1]=v[0]*s+v[1]*c;v[0]=tmp;
			c=cos(r23);s=sin(r23);tmp=v[2]*c-v[3]*s;v[3]=v[2]*s+v[3]*c;v[2]=tmp;
			c=cos(r45);s=sin(r45);tmp=v[4]*c-v[5]*s;v[5]=v[4]*s+v[5]*c;v[4]=tmp;
			c=cos(r67);s=sin(r67);tmp=v[6]*c-v[7]*s;v[7]=v[6]*s+v[7]*c;v[6]=tmp;
			// Project 8D -> 2D (use first two components + perspective from 8D depth)
			float depth=3.0-v[2]*0.2-v[3]*0.15-v[4]*0.1-v[5]*0.08-v[6]*0.05-v[7]*0.03;
			float proj=1.0/depth;
			vec2 screen=vec2(v[0],v[1])*proj*0.7;
			float d=length(uv-screen);
			if(d<closest)closest=d;
			// Vertex glow
			col+=pal(float(i*8+j)/56.0+t*0.01)*exp(-d*d*4000.0)*0.008;
		}}
	}}
	// Edge proximity (approximate — connect vertices at distance sqrt(2) in 8D)
	col+=pal(closest*15.0+t*0.02)*clamp(0.004/(closest+0.001),0.0,1.0)*0.3;
	col+=vec3(1.0,0.85,0.3)*exp(-closest*closest*5000.0)*0.3;
	// E8 symmetry indicator
	float sym=sin(atan(uv.y,uv.x)*4.0+t*0.1)*0.5+0.5;
	col+=vec3(0.1,0.05,0.15)*sym*exp(-length(uv)*2.0)*0.1;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
