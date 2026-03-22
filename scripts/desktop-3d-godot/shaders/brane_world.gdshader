shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// D-branes: 2D membrane in 3D bulk
	// Open strings confined to brane, closed strings (gravity) leak into bulk
	vec2 p=uv*3.0;
	// The brane (a glowing surface at y=0)
	float brane_d=abs(p.y);
	float brane_glow=exp(-brane_d*brane_d*8.0);
	// Brane surface with ripples (from string endpoints)
	float ripple=sin(p.x*3.0-t*2.0)*0.1*exp(-brane_d*brane_d*20.0);
	brane_glow+=exp(-(brane_d-ripple)*(brane_d-ripple)*15.0)*0.5;
	col+=vec3(0.2,0.5,0.8)*brane_glow*0.5;
	// Open strings (confined to brane)
	for(int i=0;i<5;i++){
		float fi=float(i);
		float x1=sin(fi*1.7+t*0.3)*2.0;
		float x2=sin(fi*2.3+t*0.25)*2.0;
		// String between two endpoints on brane
		for(int s=0;s<30;s++){
			float st=float(s)/30.0;
			float sx=mix(x1,x2,st);
			float sy=sin(st*PI)*0.3*sin(fi+t*3.0+st*5.0); // string vibration
			sy*=exp(-brane_d*5.0); // confined near brane
			float sd=length(p-vec2(sx,sy));
			col+=pal(fi/5.0+st+t*0.02)*exp(-sd*sd*500.0)*0.01;
		}
		// Endpoints on brane
		col+=vec3(1.0,0.85,0.3)*exp(-length(p-vec2(x1,0))*length(p-vec2(x1,0))*200.0)*0.1;
		col+=vec3(1.0,0.85,0.3)*exp(-length(p-vec2(x2,0))*length(p-vec2(x2,0))*200.0)*0.1;
	}
	// Closed strings (gravity, leak into bulk)
	for(int i=0;i<3;i++){
		float fi=float(i);
		float cx=sin(fi*2.1+t*0.15)*1.5;
		float cy=sin(fi*1.3+t*0.2)*1.5; // moves off brane!
		// Closed string loop
		for(int s=0;s<20;s++){
			float sa=float(s)/20.0*TAU;
			float radius=0.2+0.05*sin(sa*3.0+t*4.0);
			vec2 sp=vec2(cx+cos(sa)*radius,cy+sin(sa)*radius);
			float sd=length(p-sp);
			col+=vec3(0.8,0.3,0.6)*exp(-sd*sd*800.0)*0.008;
		}
	}
	// Bulk gradient (extra dimension depth)
	col+=vec3(0.02,0.01,0.04)*abs(p.y)*0.1;
	// Gravitational field lines (leaking off brane)
	for(int i=0;i<4;i++){
		float fi=float(i);
		float gx=sin(fi*2.5+t*0.1)*1.5;
		float field_line=abs(p.x-gx);
		float leak=exp(-field_line*5.0)*abs(p.y)*0.15;
		col+=vec3(0.3,0.15,0.4)*leak;
	}
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
