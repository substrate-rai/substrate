shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// Mirror symmetry: two dual Calabi-Yau manifolds
	// Left half: CY with Hodge numbers (h11, h21)
	// Right half: mirror CY with (h21, h11) — swapped!
	float n=5.0;float psi=1.0+0.5*sin(t*0.06);
	// Left manifold
	vec2 p_left=vec2(uv.x*2.0+1.0,uv.y)*PI;
	float r1l=pow(max(abs(cos(p_left.x)),0.001),2.0/n);
	float r2l=pow(max(abs(cos(p_left.y)),0.001),2.0/n);
	float xl=r1l*cos(p_left.x+psi*0.1);float yl=r2l*cos(p_left.y);
	float manifold_l=pow(r1l,n)+pow(r2l,n);
	float on_l=exp(-abs(manifold_l-1.0)*5.0);
	if(uv.x<0.0)col+=pal(p_left.x/PI+t*0.02)*on_l*0.6;
	// Right manifold (mirror: swap theta1<->theta2, different psi coupling)
	vec2 p_right=vec2(uv.x*2.0-1.0,uv.y)*PI;
	float r1r=pow(max(abs(cos(p_right.y)),0.001),2.0/n); // SWAPPED
	float r2r=pow(max(abs(cos(p_right.x)),0.001),2.0/n);
	float xr=r1r*cos(p_right.y+psi*0.15);float yr=r2r*cos(p_right.x);
	float manifold_r=pow(r1r,n)+pow(r2r,n);
	float on_r=exp(-abs(manifold_r-1.0)*5.0);
	if(uv.x>=0.0)col+=pal(p_right.y/PI+0.5+t*0.02)*on_r*0.6;
	// Central mirror line
	float mirror_line=smoothstep(0.015,0.0,abs(uv.x));
	col+=vec3(1.0,0.85,0.3)*mirror_line*0.4;
	// Correspondence lines (connecting dual features)
	for(int i=0;i<5;i++){
		float fi=float(i);
		float y_pos=(fi-2.0)*0.3+sin(t*0.1+fi)*0.1;
		float corr_line=smoothstep(0.008,0.0,abs(uv.y-y_pos))*smoothstep(0.5,0.0,abs(uv.x));
		col+=vec3(0.5,0.3,0.8)*corr_line*0.15;
	}
	// Labels via brightness
	if(uv.x<-0.7&&uv.y>0.85)col+=vec3(0.3)*0.15; // CY
	if(uv.x>0.7&&uv.y>0.85)col+=vec3(0.3)*0.15; // Mirror
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
