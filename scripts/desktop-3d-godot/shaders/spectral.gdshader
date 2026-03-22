shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*PI;vec3 col=vec3(0.01,0.005,0.03);
	// Spectral geometry: eigenfunctions of the Laplacian on a domain
	// Chladni patterns: nodal lines of vibrating plates
	float vibration=0.0;
	int n_modes=6;
	for(int m=1;m<=n_modes;m++){for(int n=1;n<=n_modes;n++){
		float fm=float(m),fn=float(n);
		float freq=sqrt(fm*fm+fn*fn);
		float amplitude=1.0/(fm*fn);
		float phase=freq*t*0.3;
		// Rectangular membrane eigenfunction
		vibration+=amplitude*sin(fm*p.x)*sin(fn*p.y)*cos(phase);
	}}
	// Nodal lines (where vibration = 0) are the Chladni patterns
	float nodal=abs(vibration);
	float nodal_line=smoothstep(0.05,0.0,nodal);
	col+=vec3(1.0,0.95,0.85)*nodal_line*0.7;
	// Positive/negative regions
	if(vibration>0.0)col+=pal(vibration*2.0+0.2)*vibration*0.15;
	else col+=pal(-vibration*2.0+0.6)*(-vibration)*0.12;
	// Eigenvalue density (Weyl's law: N(lambda) ~ Area*lambda/(4*pi))
	float r=length(uv);
	float weyl=smoothstep(0.5,0.0,abs(r-sqrt(float(n_modes*n_modes)*2.0)*0.15));
	col+=vec3(0.3,0.5,0.8)*weyl*0.08;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
