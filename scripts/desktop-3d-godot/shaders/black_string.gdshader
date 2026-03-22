shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	vec2 p=uv*4.0;
	// Black string: event horizon extended along one dimension
	// Gregory-Laflamme instability: pinches into chain of black holes
	float instability=0.5+0.5*sin(t*0.05); // 0=string, 1=pinched
	// Horizon radius varies along the string
	float horizon_r=0.4-instability*0.25*cos(p.x*PI*0.5);
	// Schwarzschild-like radial coordinate
	float r=abs(p.y);
	float horizon_d=r-horizon_r;
	// Inside horizon: black
	if(horizon_d<0.0){
		// Singularity glow at center
		float sing=exp(-r*r*50.0)*0.3;
		col+=vec3(0.5,0.1,0.0)*sing;
		ALBEDO=col/(col+vec3(1.0));return;
	}
	// Hawking radiation (thermal glow near horizon)
	float hawking=exp(-horizon_d*10.0);
	// Temperature: T ~ 1/r_h (smaller horizon = hotter = bluer)
	float temp=1.0/(horizon_r+0.1);
	vec3 thermal;
	if(temp>3.0)thermal=vec3(0.5,0.6,1.0); // hot blue
	else if(temp>2.0)thermal=vec3(1.0,0.8,0.4); // warm
	else thermal=vec3(0.8,0.2,0.1); // cool red
	col+=thermal*hawking*0.6;
	// Ergosphere (frame dragging region)
	float ergo_r=horizon_r*1.5;
	float ergo_d=abs(r-ergo_r);
	col+=vec3(0.3,0.2,0.5)*exp(-ergo_d*5.0)*0.15;
	// Gravitational lensing (distorted background)
	float lens_dist=1.0/(1.0+exp(-horizon_d*3.0));
	float bg_pattern=sin(p.x*2.0+p.y*3.0*lens_dist)*0.5+0.5;
	col+=vec3(0.05)*bg_pattern*(1.0-hawking)*0.2;
	// Instability mode visualization (perturbation wavelength)
	float mode=cos(p.x*PI*0.5)*exp(-horizon_d*2.0)*instability;
	col+=vec3(0.8,0.4,0.1)*abs(mode)*0.2;
	// Black hole chain at maximum instability
	if(instability>0.8){
		for(int i=-2;i<=2;i++){
			float fi=float(i);
			vec2 bh_center=vec2(fi*2.0,0.0);
			float bh_r=length(p-bh_center);
			float bh_glow=exp(-bh_r*3.0)*(instability-0.8)*5.0;
			col+=pal(fi*0.2+0.3)*bh_glow*0.3;
		}
	}
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
