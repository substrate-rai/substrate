shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
// Quaternion multiplication
vec4 qmul(vec4 a,vec4 b){return vec4(a.x*b.x-a.y*b.y-a.z*b.z-a.w*b.w,a.x*b.y+a.y*b.x+a.z*b.w-a.w*b.z,a.x*b.z-a.y*b.w+a.z*b.x+a.w*b.y,a.x*b.w+a.y*b.z-a.z*b.y+a.w*b.x);}
// Quaternion Julia distance estimator (Keenan Crane)
float qjulia_de(vec3 p,vec4 c){
	vec4 z=vec4(p,0.0);vec4 dz=vec4(1,0,0,0);
	float r2=0.0;
	for(int i=0;i<12;i++){
		dz=2.0*qmul(z,dz);z=qmul(z,z)+c;
		r2=dot(z,z);if(r2>16.0)break;
	}
	float r=sqrt(r2);return 0.5*r*log(r)/length(dz);
}
vec3 qnormal(vec3 p,vec4 c){
	float e=0.001;
	return normalize(vec3(qjulia_de(p+vec3(e,0,0),c)-qjulia_de(p-vec3(e,0,0),c),qjulia_de(p+vec3(0,e,0),c)-qjulia_de(p-vec3(0,e,0),c),qjulia_de(p+vec3(0,0,e),c)-qjulia_de(p-vec3(0,0,e),c)));
}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	// Animated c parameter sweeping through 4D
	vec4 c=vec4(-0.2+0.3*sin(t*0.07),0.6+0.2*cos(t*0.09),0.2*sin(t*0.11),-0.4+0.3*cos(t*0.06));
	// Camera
	float ca=t*0.1;
	vec3 ro=vec3(cos(ca)*2.5,sin(t*0.07)*1.0,sin(ca)*2.5);
	vec3 target=vec3(0);
	vec3 fwd=normalize(target-ro);vec3 right=normalize(cross(fwd,vec3(0,1,0)));vec3 up=cross(right,fwd);
	vec3 rd=normalize(fwd+uv.x*right*0.7+uv.y*up*0.7);
	vec3 col=vec3(0.01,0.005,0.03);
	float td=0.0;
	for(int i=0;i<100;i++){
		vec3 p=ro+rd*td;float d=qjulia_de(p,c);
		if(d<0.0005){
			vec3 n=qnormal(p,c);
			vec3 light=normalize(vec3(1,2,3));
			float diff=max(dot(n,light),0.0);
			float spec=pow(max(dot(reflect(-light,n),-rd),0.0),32.0);
			float ao=1.0-float(i)/100.0;
			col=pal(dot(p,vec3(0.3))+t*0.02)*(0.15+diff*0.6)*ao+vec3(1.0)*spec*0.3;
			float fresnel=pow(1.0-abs(dot(n,-rd)),3.0);
			col+=pal(dot(p,vec3(0.5))+0.3)*fresnel*0.2;
			break;
		}
		td+=d;if(td>5.0)break;
	}
	col*=1.0+audio_energy*0.2;col=col/(col+vec3(1.0));ALBEDO=col;
}
