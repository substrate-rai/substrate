shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.6)*t+vec3(0.0,0.1,0.3)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*4.0;vec3 col=vec3(0.01,0.005,0.03);
	// Yang-Mills: SU(2) gauge field visualization
	// Instanton-like configuration: self-dual gauge field
	// A_mu = f(r) * sigma_mu_nu * x_nu / r^2
	float r=length(p);float theta=atan(p.y,p.x);
	// Instanton profile function
	float rho=1.0+0.3*sin(t*0.1); // instanton size
	float f=r*r/(r*r+rho*rho);
	// Field strength F = dA + A^A
	// |F|^2 = instanton density
	float F2=48.0*rho*rho*rho*rho/pow(r*r+rho*rho,4.0);
	// Action density (topological charge density)
	float Q=F2*0.5;
	// Three SU(2) components (Pauli matrices)
	float A1=f*sin(theta+t*0.2);
	float A2=f*cos(theta+t*0.2);
	float A3=f*sin(2.0*theta+t*0.15);
	// Color: each SU(2) component maps to RGB
	col.r+=abs(A1)*0.5;
	col.g+=abs(A2)*0.5;
	col.b+=abs(A3)*0.5;
	// Instanton core glow (topological charge)
	col+=vec3(1.0,0.85,0.3)*Q*5.0;
	// Field lines (gauge potential streamlines)
	float field_line=sin(theta*3.0+f*10.0-t*0.5)*0.5+0.5;
	field_line*=smoothstep(0.0,0.5,f)*smoothstep(2.0,0.5,r);
	col+=pal(field_line+theta/TAU)*field_line*0.2;
	// Topological winding number visualization (concentric)
	float winding=abs(fract(theta*3.0/TAU+f*2.0)-0.5)*2.0;
	col+=vec3(0.3,0.5,0.8)*smoothstep(0.05,0.0,1.0-winding)*0.1;
	// Anti-instanton (second center)
	vec2 p2=p-vec2(2.0*sin(t*0.08),2.0*cos(t*0.07));
	float r2=length(p2);float f2=r2*r2/(r2*r2+rho*rho);
	float F2_2=48.0*rho*rho*rho*rho/pow(r2*r2+rho*rho,4.0);
	col+=vec3(0.3,0.1,0.8)*F2_2*3.0;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
