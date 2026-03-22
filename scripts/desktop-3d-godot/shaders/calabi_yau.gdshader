shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// Calabi-Yau manifold: 2D cross-section of quintic threefold
	// z1^n+z2^n=1 parameterized by (theta1,theta2)
	float n=5.0+sin(t*0.05)*2.0; // animate between quintic and other degrees
	float theta1=uv.x*PI;float theta2=uv.y*PI;
	float k1=cos(t*0.07)*0.3;float k2=sin(t*0.09)*0.3;
	// Parameterize surface in R^3 using Hanson's method
	// x = Re(z1), y = Re(z2), z = Im(z1*z2)
	float r1=pow(abs(cos(theta1)),2.0/n);
	float r2=pow(abs(cos(theta2)),2.0/n);
	float phase1=theta1+k1;float phase2=theta2+k2;
	float x=r1*cos(phase1);
	float y=r2*cos(phase2);
	float z_coord=r1*r2*sin(phase1+phase2);
	// Project 3D to 2D with rotation
	float ca=cos(t*0.1),sa=sin(t*0.1);
	float px=x*ca-z_coord*sa;
	float py=y;
	// Color by position on manifold
	float manifold_val=pow(r1,n)+pow(r2,n); // should be ~1 on the manifold
	float on_manifold=exp(-abs(manifold_val-1.0)*10.0);
	col+=pal(theta1/PI+theta2/PI+t*0.02)*on_manifold*0.7;
	// Surface normal shading
	float nx=cos(phase1)*pow(abs(cos(theta1)),2.0/n-1.0);
	float ny=cos(phase2)*pow(abs(cos(theta2)),2.0/n-1.0);
	float light=abs(nx*0.7+ny*0.7);
	col*=0.4+light*0.6;
	// Holomorphic structure lines
	float holo=sin(theta1*n)*sin(theta2*n);
	col+=vec3(0.3,0.5,0.8)*smoothstep(0.1,0.0,abs(holo))*0.15;
	// Ricci-flat indicator (Calabi-Yau property)
	float ricci=abs(sin(n*theta1)+sin(n*theta2));
	col+=vec3(1.0,0.85,0.3)*exp(-ricci*3.0)*0.1;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
