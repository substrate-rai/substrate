shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	vec2 p=uv*5.0;
	// Lattice Boltzmann: D2Q9 model approximation
	// 9 velocity directions, particle distributions stream and collide
	// Approximate by computing local equilibrium and perturbation
	// Velocity field from multiple vortex sources
	vec2 velocity=vec2(0.0);float density=1.0;
	for(int i=0;i<6;i++){
		float fi=float(i);float sign_v=(mod(fi,2.0)<1.0)?1.0:-1.0;
		vec2 center=vec2(sin(fi*1.7+t*0.12)*3.0,cos(fi*2.3+t*0.1)*3.0);
		float strength=sign_v*(0.8+0.3*sin(fi*3.1+t*0.08));
		vec2 dp=p-center;float r2=dot(dp,dp)+0.2;
		vec2 v_tang=vec2(-dp.y,dp.x)/(r2)*strength*(1.0-exp(-r2));
		velocity+=v_tang;
		density+=strength*exp(-r2*0.5)*0.1;
	}
	// Cursor as obstacle/force source
	vec2 cursor=cursor_world_pos.xy*2.5;
	float cursor_d=length(p-cursor);
	if(cursor_d<0.8){
		velocity+=normalize(p-cursor)*2.0/(cursor_d+0.1);
		density+=exp(-cursor_d*cursor_d*3.0)*0.3;
	}
	float speed=length(velocity);
	// D2Q9 distribution visualization
	// Show the 9 distribution values as a mini lattice pattern
	float lattice_scale=0.5;
	vec2 lattice_p=fract(p*lattice_scale+0.5)-0.5;
	float lattice_r=length(lattice_p);
	// Density field
	col+=pal(density*0.5+t*0.02)*max(density-0.8,0.0)*0.3;
	// Velocity field (direction as hue, speed as brightness)
	float vel_angle=atan(velocity.y,velocity.x);
	col+=pal(vel_angle/TAU+0.5)*speed*0.15;
	// Streamlines
	vec2 trace=p;float stream=0.0;
	for(int s=0;s<30;s++){
		vec2 tv=vec2(0.0);
		for(int i=0;i<6;i++){
			float fi=float(i);float sv=(mod(fi,2.0)<1.0)?1.0:-1.0;
			vec2 c=vec2(sin(fi*1.7+t*0.12)*3.0,cos(fi*2.3+t*0.1)*3.0);
			float st=sv*(0.8+0.3*sin(fi*3.1+t*0.08));
			vec2 d=trace-c;float r2d=dot(d,d)+0.2;
			tv+=vec2(-d.y,d.x)/r2d*st*(1.0-exp(-r2d));
		}
		trace+=tv*0.04;
		stream+=sin(length(trace)*6.0+float(s)*0.3)*0.02;
	}
	col+=pal(stream*3.0+speed*0.2)*abs(stream)*0.4;
	// Lattice structure overlay (D2Q9 grid)
	float lg=smoothstep(0.02,0.0,min(abs(lattice_p.x),abs(lattice_p.y)));
	col+=vec3(0.1)*lg*0.05;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
