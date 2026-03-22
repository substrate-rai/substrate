shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(0.8,1.0,0.6)*t+vec3(0.0,0.1,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// Clifford torus: (cos a, sin a, cos b, sin b)/sqrt(2) on S3
	// Stereographic projection from S3 to R3
	float min_d=1e10;
	int N=60;int M=60;
	float proj_angle=t*0.05; // animate projection point
	for(int i=0;i<N;i++){for(int j=0;j<M;j++){
		float a=float(i)/float(N)*TAU;
		float b=float(j)/float(M)*TAU;
		float s2=0.7071; // 1/sqrt(2)
		vec4 p4=vec4(cos(a),sin(a),cos(b),sin(b))*s2;
		// Rotate in 4D
		float c1=cos(proj_angle),s1=sin(proj_angle);
		vec4 rp=p4;rp.x=p4.x*c1-p4.w*s1;rp.w=p4.x*s1+p4.w*c1;p4=rp;
		float c2=cos(proj_angle*0.7),s2r=sin(proj_angle*0.7);
		rp=p4;rp.y=p4.y*c2-p4.z*s2r;rp.z=p4.y*s2r+p4.z*c2;p4=rp;
		// Stereographic projection S3->R3
		float denom=1.0/(1.0-p4.w+0.01);
		vec3 p3=p4.xyz*denom;
		// Project R3->R2 with rotation
		float cam_a=t*0.08;
		float rx=p3.x*cos(cam_a)-p3.z*sin(cam_a);
		float ry=p3.y;
		vec2 screen=vec2(rx,ry)*0.3;
		float d=length(uv-screen);
		min_d=min(min_d,d);
		// Grid lines on torus (every 6th line highlighted)
		if(i%6==0||j%6==0){
			col+=pal(a/TAU+b/TAU+t*0.01)*exp(-d*d*5000.0)*0.015;
		}
	}}
	col+=pal(min_d*10.0+t*0.02)*clamp(0.003/(min_d+0.001),0.0,1.0)*0.4;
	col+=vec3(1.0,0.85,0.3)*exp(-min_d*min_d*8000.0)*0.1;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
