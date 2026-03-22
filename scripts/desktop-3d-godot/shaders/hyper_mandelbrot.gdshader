shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
vec2 cmul(vec2 a,vec2 b){return vec2(a.x*b.x-a.y*b.y,a.x*b.y+a.y*b.x);}
// Hyperbolic distance in Poincare disk
float hyp_dist(vec2 a,vec2 b){
	vec2 d=a-b;float num=dot(d,d);
	float denom=(1.0-dot(a,a))*(1.0-dot(b,b));
	return acosh(1.0+2.0*num/max(denom,0.001));
}
// Mobius transform in Poincare disk
vec2 hyp_translate(vec2 z,vec2 a){
	vec2 num=z+a;vec2 den=vec2(1.0,0.0)+cmul(vec2(a.x,-a.y),z);
	return cmul(num,vec2(den.x,-den.y)/dot(den,den));
}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*0.95; // inside unit disk
	if(length(p)>=0.99){ALBEDO=vec3(0.02);return;}
	vec3 col=vec3(0.01,0.005,0.03);
	// Mandelbrot in hyperbolic space
	vec2 c=p;vec2 z=vec2(0.0);
	float escape=0.0;int max_iter=80;
	for(int i=0;i<80;i++){
		// z^2 + c, but addition is hyperbolic translation
		z=cmul(z,z);
		z=hyp_translate(z,c*0.3);
		if(length(z)>0.98){escape=float(i);break;}
	}
	if(escape>0.0){
		float t_col=escape/float(max_iter);
		col+=pal(t_col*4.0+t*0.02)*pow(t_col,0.6)*0.8;
	}else{
		col+=pal(length(z)*2.0+0.5)*0.2;
	}
	// Poincare disk boundary
	float boundary=abs(length(p)-0.99);
	col+=vec3(0.5)*exp(-boundary*200.0)*0.3;
	// Hyperbolic geodesics (circles orthogonal to boundary)
	for(int i=0;i<6;i++){
		float fi=float(i);
		float angle=fi*TAU/6.0+t*0.03;
		vec2 a=vec2(cos(angle),sin(angle))*0.5;
		float d=hyp_dist(p,a);
		float geodesic=abs(fract(d*0.5)-0.5)*2.0;
		col+=pal(fi/6.0+0.3)*smoothstep(0.05,0.0,1.0-geodesic)*0.05;
	}
	col*=1.0+audio_energy*0.2;col=col/(col+vec3(1.0));ALBEDO=col;
}
