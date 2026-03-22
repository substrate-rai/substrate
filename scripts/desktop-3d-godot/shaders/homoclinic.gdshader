shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(0.8,1.0,0.6)*t+vec3(0.1,0.2,0.0)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*3.0;vec3 col=vec3(0.01,0.005,0.02);
	// Duffing oscillator: x''=-x+x^3+eps*cos(t)
	// Homoclinic tangle: iterate Poincare map forward and backward
	float eps=0.3+0.1*sin(t*0.05);
	float stable_density=0.0;float unstable_density=0.0;
	// Forward manifold (stable)
	for(int orbit=0;orbit<30;orbit++){
		float fo=float(orbit);
		float x=1.0+fo*0.002-0.03;float v=fo*0.004-0.06;
		for(int i=0;i<300;i++){
			float fi=float(i);
			float ax=-x+x*x*x+eps*cos(fi*0.5+t*0.1);
			v+=ax*0.01;x+=v*0.01;
			v*=0.999; // slight damping for visualization
			float d=length(p-vec2(x,v));
			if(d<0.02)stable_density+=1.0;
		}
	}
	// Backward manifold (unstable)
	for(int orbit=0;orbit<30;orbit++){
		float fo=float(orbit);
		float x=-1.0+fo*0.002-0.03;float v=fo*0.004-0.06;
		for(int i=0;i<300;i++){
			float fi=float(i);
			float ax=-x+x*x*x-eps*cos(fi*0.5-t*0.1);
			v-=ax*0.01;x-=v*0.01;
			v*=0.999;
			float d=length(p-vec2(x,v));
			if(d<0.02)unstable_density+=1.0;
		}
	}
	float sl=log(stable_density+1.0);float ul=log(unstable_density+1.0);
	col+=vec3(0.8,0.3,0.1)*min(sl*0.15,1.0);
	col+=vec3(0.1,0.3,0.8)*min(ul*0.15,1.0);
	// Intersection = homoclinic points
	if(sl>0.5&&ul>0.5)col+=vec3(1.0,0.85,0.3)*min(sl*ul*0.02,0.5);
	// Saddle point markers
	col+=vec3(1.0)*exp(-length(p-vec2(1.0,0.0))*10.0)*0.1;
	col+=vec3(1.0)*exp(-length(p-vec2(-1.0,0.0))*10.0)*0.1;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.2;col=col/(col+vec3(1.0));ALBEDO=col;
}
