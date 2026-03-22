shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
const int ORBIT_LEN = 500;
const int N_ORBITS = 30;
vec3 pal(float t) { return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0,0.7,0.4)*t + vec3(0.0,0.15,0.2))); }
float hash(float n) { return fract(sin(n)*43758.5453); }
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float cycle = mod(t*0.03, 3.0);
	int atype = int(cycle);
	vec3 col = vec3(0.01,0.005,0.02);
	float density = 0.0;
	float closest = 1e10;
	float cam_a = t*0.1;
	float ca = cos(cam_a), sa = sin(cam_a);
	for (int orbit = 0; orbit < N_ORBITS; orbit++) {
		float fo = float(orbit);
		vec3 p3;
		if (atype==0) p3=vec3(1.0+hash(fo)*0.1,1.0+hash(fo+10.0)*0.1,20.0);
		else if (atype==1) p3=vec3(1.0+hash(fo)*0.1,0.0,0.0);
		else p3=vec3(1.0+hash(fo)*0.1,0.0,0.0);
		float dt = 0.005;
		for (int i = 0; i < ORBIT_LEN; i++) {
			vec3 dp;
			if (atype==0) { float sigma=10.0,rho=28.0,beta=8.0/3.0; dp=vec3(sigma*(p3.y-p3.x),p3.x*(rho-p3.z)-p3.y,p3.x*p3.y-beta*p3.z); }
			else if (atype==1) { float a=0.2,b=0.2,c=5.7; dp=vec3(-p3.y-p3.z,p3.x+a*p3.y,b+p3.z*(p3.x-c)); }
			else { float a=1.89; dp=vec3(-a*p3.x-4.0*p3.y-4.0*p3.z-p3.y*p3.y,-a*p3.y-4.0*p3.z-4.0*p3.x-p3.z*p3.z,-a*p3.z-4.0*p3.x-4.0*p3.y-p3.x*p3.x); }
			p3 += dp*dt;
			float rx=p3.x*ca-p3.z*sa;
			float scale; if(atype==0)scale=0.04;else if(atype==1)scale=0.08;else scale=0.15;
			vec2 proj = vec2(rx,p3.y)*scale;
			float d = length(uv-proj);
			closest = min(closest,d);
			if(d<0.008) density+=1.0;
		}
	}
	float log_d = log(density+1.0);
	col += pal(log_d*0.15+t*0.02)*min(log_d*0.2,1.0);
	col += pal(closest*10.0+0.5)*clamp(0.005/(closest+0.001),0.0,1.0)*0.4;
	col *= 1.0+audio_energy*0.2;
	col *= 1.0-dot(uv,uv)*0.2;
	col = col/(col+vec3(1.0));
	ALBEDO = col;
}
