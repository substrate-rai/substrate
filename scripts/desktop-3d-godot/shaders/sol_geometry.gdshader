shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	// Sol geometry: ds^2 = e^(2z)dx^2 + e^(-2z)dy^2 + dz^2
	// Ray march with numerical geodesic integration
	float cam_a=t*0.08;
	vec3 ro=vec3(cos(cam_a)*3.0,sin(cam_a)*3.0,sin(t*0.05)*2.0);
	vec3 rd=normalize(vec3(uv*0.8,-1.0));
	rd=vec3(rd.x*cos(cam_a)+rd.z*sin(cam_a),rd.y,rd.z*cos(cam_a)-rd.x*sin(cam_a));
	vec3 col=vec3(0.01,0.005,0.03);
	// Numerical geodesic: in Sol, geodesics curve anisotropically
	vec3 pos=ro;vec3 vel=rd*0.1;
	float min_floor=1e10;
	for(int i=0;i<200;i++){
		float ez=exp(pos.z*0.5);float emz=exp(-pos.z*0.5);
		// Sol metric acceleration
		vec3 accel=vec3(-pos.z*vel.x*vel.z*ez*ez, pos.z*vel.y*vel.z*emz*emz, 0.5*(vel.x*vel.x*ez*ez-vel.y*vel.y*emz*emz));
		accel*=0.01;
		vel+=accel*0.1;vel=normalize(vel)*0.1;
		pos+=vel;
		// Tiled floor planes
		float floor_d=abs(fract(pos.z)-0.5)*2.0;
		min_floor=min(min_floor,floor_d);
		// Detect surface hit
		float grid=min(abs(fract(pos.x*ez)-0.5),abs(fract(pos.y*emz)-0.5));
		if(grid<0.02&&abs(fract(pos.z*0.5)-0.5)<0.4){
			float fi=float(i)/200.0;
			col=pal(pos.x*0.1+pos.y*0.1+t*0.02)*(1.0-fi)*0.8;
			col+=vec3(1.0,0.85,0.3)*smoothstep(0.02,0.0,grid)*0.3;
			break;
		}
		if(length(pos)>20.0)break;
	}
	// Anisotropy visualization
	float aniso=exp(-min_floor*5.0);
	col+=pal(min_floor+0.5)*aniso*0.1;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.2;col=col/(col+vec3(1.0));ALBEDO=col;
}
