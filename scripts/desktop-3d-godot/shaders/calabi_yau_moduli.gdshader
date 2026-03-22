shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// Calabi-Yau moduli space: quintic with deformation
	// z1^5+z2^5+z3^5+z4^5+z5^5 - 5*psi*z1*z2*z3*z4*z5 = 0
	// Animate psi: at psi=1, conifold singularity (topology change!)
	float psi=1.0+0.8*sin(t*0.06); // sweep through conifold
	float theta1=uv.x*PI;float theta2=uv.y*PI;
	float n=5.0;
	// Hanson's parameterization
	float r1=pow(max(abs(cos(theta1)),0.001),2.0/n);
	float r2=pow(max(abs(cos(theta2)),0.001),2.0/n);
	// Deformation from psi (coupling between coordinates)
	float coupling=psi*r1*r2*0.3;
	float phase1=theta1+coupling*sin(theta2);
	float phase2=theta2+coupling*sin(theta1);
	float x=r1*cos(phase1);float y=r2*cos(phase2);
	float z_coord=r1*r2*sin(phase1+phase2)+coupling*0.2;
	// Manifold value (how close to satisfying the equation)
	float manifold_val=pow(r1,n)+pow(r2,n)-psi*pow(r1*r2,n/2.0)*0.1;
	float on_manifold=exp(-abs(manifold_val-1.0)*5.0);
	col+=pal(theta1/PI+theta2/PI+t*0.02)*on_manifold*0.6;
	// Conifold singularity indicator
	float conifold_dist=abs(psi-1.0);
	float near_conifold=exp(-conifold_dist*5.0);
	col+=vec3(1.0,0.3,0.2)*near_conifold*on_manifold*0.3;
	// Hodge diamond structure (topological invariants)
	float hodge=sin(theta1*n)*sin(theta2*n);
	col+=vec3(0.3,0.5,0.8)*smoothstep(0.1,0.0,abs(hodge))*0.1;
	// Light
	float nx=cos(phase1)*r1;float ny=cos(phase2)*r2;
	float light=abs(nx*0.7+ny*0.7);col*=0.3+light*0.7;
	// Psi indicator
	float psi_bar=(psi-0.2)/1.6;
	if(uv.y<-0.95&&uv.x*0.5+0.5<psi_bar)col+=vec3(0.3)*0.2;
	// Cursor: control psi manually
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
