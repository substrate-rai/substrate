shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*3.0;vec3 col=vec3(0.01,0.005,0.03);
	// Neural ODE: dx/dt = f_theta(x,t) where f is a neural network
	// Visualize the learned vector field and flow map
	// Approximate a 2-layer neural net: f(x) = W2*tanh(W1*x+b1)+b2
	// Animate weights slowly
	float w11=sin(t*0.07)*1.5,w12=cos(t*0.09)*1.2;
	float w21=cos(t*0.06)*1.3,w22=sin(t*0.08)*1.4;
	float b1=sin(t*0.1)*0.5,b2=cos(t*0.11)*0.5;
	float w31=sin(t*0.05)*1.1,w32=cos(t*0.07)*0.9;
	float w41=cos(t*0.08)*1.0,w42=sin(t*0.06)*1.2;
	// Hidden layer (2 neurons)
	float h1=tanh(w11*p.x+w12*p.y+b1);
	float h2=tanh(w21*p.x+w22*p.y+b2);
	// Output layer
	vec2 vel=vec2(w31*h1+w32*h2,w41*h1+w42*h2);
	// Vector field magnitude and direction
	float mag=length(vel);
	float angle=atan(vel.y,vel.x);
	// Streamlines via LIC-like approach
	vec2 trace=p;float stream=0.0;
	for(int i=0;i<30;i++){
		float th1=tanh(w11*trace.x+w12*trace.y+b1);
		float th2=tanh(w21*trace.x+w22*trace.y+b2);
		vec2 tv=vec2(w31*th1+w32*th2,w41*th1+w42*th2);
		trace+=tv*0.05;
		stream+=sin(length(trace)*10.0+float(i)*0.5)*0.03;
	}
	// Color by velocity magnitude
	col+=pal(mag*0.3+angle/TAU+t*0.01)*mag*0.3;
	// Streamlines
	col+=pal(stream+0.5)*abs(stream)*0.5;
	// Fixed points (where velocity is zero)
	float fp_glow=exp(-mag*mag*10.0)*0.5;
	// Classify: stable (converging) vs unstable (diverging)
	float div=dFdx(vel.x)+dFdy(vel.y); // divergence
	vec3 fp_col=(div<0.0)?vec3(0.2,0.6,1.0):vec3(1.0,0.3,0.2);
	col+=fp_col*fp_glow;
	// Velocity arrows (periodic grid)
	vec2 grid_id=floor(p*2.0);
	vec2 grid_p=fract(p*2.0)-0.5;
	float arrow=smoothstep(0.03,0.0,abs(dot(grid_p,normalize(vel))-length(grid_p)));
	arrow*=smoothstep(0.3,0.0,length(grid_p));
	col+=vec3(0.8)*arrow*0.1;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
