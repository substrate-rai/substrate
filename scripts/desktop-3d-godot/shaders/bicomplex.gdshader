shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// Bicomplex Mandelbrot: z = z1 + j*z2, where i^2=j^2=-1, ij=ji=k, k^2=1
	// Bicomplex multiplication: (a+jb)(c+jd) = (ac+bd) + j(ad+bc)
	// using idempotent decomposition: e1=(1+k)/2, e2=(1-k)/2
	float slice_angle=t*0.05;
	float cr=uv.x*1.5;float ci=uv.y*1.5;
	float cj=0.3*sin(slice_angle);float ck=0.3*cos(slice_angle);
	// Idempotent decomposition: w1=z1+i*z2, w2=z1-i*z2
	// Mandelbrot in each component independently
	float w1r=cr+ck,w1i=ci+cj;
	float w2r=cr-ck,w2i=ci-cj;
	// Iterate w1 -> w1^2 + c1, w2 -> w2^2 + c2
	float z1r=0.0,z1i=0.0,z2r=0.0,z2i=0.0;
	float escape1=0.0,escape2=0.0;
	for(int i=0;i<80;i++){
		float nr1=z1r*z1r-z1i*z1i+w1r;float ni1=2.0*z1r*z1i+w1i;
		float nr2=z2r*z2r-z2i*z2i+w2r;float ni2=2.0*z2r*z2i+w2i;
		z1r=nr1;z1i=ni1;z2r=nr2;z2i=ni2;
		if(escape1==0.0&&z1r*z1r+z1i*z1i>16.0)escape1=float(i);
		if(escape2==0.0&&z2r*z2r+z2i*z2i>16.0)escape2=float(i);
		if(escape1>0.0&&escape2>0.0)break;
	}
	// Color: blend both components
	float e1=escape1/80.0;float e2=escape2/80.0;
	if(escape1>0.0)col+=pal(e1*3.0+t*0.02)*pow(e1,0.5)*0.5;
	if(escape2>0.0)col+=pal(e2*3.0+0.5+t*0.02)*pow(e2,0.5)*0.4;
	// Bicomplex-specific: the intersection of both M-sets
	if(escape1==0.0&&escape2==0.0)col+=pal(0.3+t*0.01)*0.2;
	// The 4D slice indicator
	float slice_vis=sin(slice_angle*4.0)*0.5+0.5;
	col*=0.8+slice_vis*0.2;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
