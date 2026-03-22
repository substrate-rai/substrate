shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// Wave equation on a torus: Laplace-Beltrami on T^2
	// Torus parameterized by (u,v), major radius R, minor radius r
	vec2 p=uv*PI;
	float R=2.0;float r=0.8;
	// Eigenfunctions on torus: cos(m*u)*cos(n*v) with eigenvalue (m/R)^2+(n/r)^2
	float wave=0.0;
	for(int m=-3;m<=3;m++){for(int n=-3;n<=3;n++){
		if(m==0&&n==0)continue;
		float fm=float(m);float fn=float(n);
		float freq=sqrt((fm/R)*(fm/R)+(fn/r)*(fn/r));
		float amplitude=1.0/((fm*fm+fn*fn)+1.0);
		wave+=amplitude*cos(fm*p.x)*cos(fn*p.y)*cos(freq*t*0.8);
	}}
	// Map (u,v) to 3D torus for display
	float u_param=p.x;float v_param=p.y;
	vec3 torus_pt=vec3((R+r*cos(v_param))*cos(u_param),(R+r*cos(v_param))*sin(u_param),r*sin(v_param));
	// Project with rotation
	float ca=cos(t*0.08),sa=sin(t*0.08);
	float px=torus_pt.x*ca-torus_pt.z*sa;
	float py=torus_pt.y;
	// Wave amplitude coloring on torus surface
	if(wave>0.0)col+=pal(wave*2.0+u_param/PI)*wave*0.4;
	else col+=pal(-wave*2.0+0.5+v_param/PI)*(-wave)*0.3;
	// Nodal lines (wave=0)
	float nodal=smoothstep(0.05,0.0,abs(wave));
	col+=vec3(1.0,0.95,0.85)*nodal*0.4;
	// Torus wireframe
	float grid_u=abs(fract(u_param*3.0/TAU)-0.5)*2.0;
	float grid_v=abs(fract(v_param*3.0/TAU)-0.5)*2.0;
	float grid=min(smoothstep(0.05,0.0,1.0-grid_u),1.0)+min(smoothstep(0.05,0.0,1.0-grid_v),1.0);
	col+=vec3(0.15,0.1,0.2)*grid*0.15;
	// Cursor interaction: wave source at cursor position
	vec2 cursor=cursor_world_pos.xy*0.5;
	float cursor_wave=sin(length(p-cursor)*8.0-t*4.0)*exp(-length(p-cursor)*0.5)*0.3;
	col+=pal(cursor_wave+0.5)*abs(cursor_wave)*0.3;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
