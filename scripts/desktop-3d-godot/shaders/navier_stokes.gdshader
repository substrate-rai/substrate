shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*4.0;vec3 col=vec3(0.01,0.005,0.03);
	// Navier-Stokes: approximate vorticity field
	// Multiple vortices interacting
	vec2 velocity=vec2(0.0);float vorticity=0.0;
	for(int i=0;i<8;i++){
		float fi=float(i);
		float sign_v=(mod(fi,2.0)<1.0)?1.0:-1.0;
		vec2 center=vec2(sin(fi*1.7+t*0.15+sign_v*t*0.05)*2.0,cos(fi*2.3+t*0.12)*2.0);
		float strength=sign_v*(1.0+0.5*sin(fi*3.1+t*0.1));
		vec2 dp=p-center;float r2=dot(dp,dp)+0.1;
		// Lamb-Oseen vortex: v_theta = Gamma/(2*pi*r) * (1-exp(-r^2/4*nu*t))
		float r=sqrt(r2);float decay=1.0-exp(-r2*2.0);
		vec2 v_tangent=vec2(-dp.y,dp.x)/(r2)*strength*decay;
		velocity+=v_tangent;
		// Vorticity: curl of velocity
		vorticity+=strength*exp(-r2*1.0)*2.0;
	}
	float speed=length(velocity);
	// Vorticity coloring (red=clockwise, blue=counter-clockwise)
	if(vorticity>0.0)col+=vec3(0.8,0.2,0.1)*min(vorticity*0.3,1.0);
	else col+=vec3(0.1,0.3,0.8)*min(-vorticity*0.3,1.0);
	// Streamlines
	vec2 trace=p;float stream=0.0;
	for(int s=0;s<40;s++){
		vec2 tv=vec2(0.0);
		for(int i=0;i<8;i++){
			float fi=float(i);float sv=(mod(fi,2.0)<1.0)?1.0:-1.0;
			vec2 c=vec2(sin(fi*1.7+t*0.15+sv*t*0.05)*2.0,cos(fi*2.3+t*0.12)*2.0);
			float st=sv*(1.0+0.5*sin(fi*3.1+t*0.1));
			vec2 d=trace-c;float r2d=dot(d,d)+0.1;
			tv+=vec2(-d.y,d.x)/r2d*st*(1.0-exp(-r2d*2.0));
		}
		trace+=tv*0.03;
		stream+=sin(length(trace)*8.0+float(s)*0.3)*0.02;
	}
	col+=pal(stream*2.0+speed*0.3+t*0.01)*abs(stream)*0.4;
	// Velocity magnitude overlay
	col+=vec3(0.3)*speed*0.05;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
