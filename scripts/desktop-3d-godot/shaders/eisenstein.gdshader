shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
bool is_prime(int n){if(n<2)return false;if(n<4)return true;if(n%2==0||n%3==0)return false;for(int i=5;i*i<=n;i+=6){if(n%i==0||n%(i+2)==0)return false;}return true;}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*15.0;vec3 col=vec3(0.01,0.005,0.03);
	// Eisenstein integers: Z[omega] where omega=e^(2pi*i/3)
	// Lattice: a + b*omega, omega=(-1+sqrt(3)*i)/2
	vec2 omega=vec2(-0.5,0.866025);
	// Check nearby Eisenstein integers for primality
	float closest_prime=1e10;float closest_any=1e10;
	for(int a=-20;a<=20;a++){for(int b=-20;b<=20;b++){
		vec2 ei=float(a)*vec2(1.0,0.0)+float(b)*omega;
		float d=length(p-ei);
		closest_any=min(closest_any,d);
		// Eisenstein prime: norm a^2-ab+b^2 is rational prime, or associate of rational prime
		int norm=a*a-a*b+b*b;
		if(norm>1&&is_prime(norm)){
			closest_prime=min(closest_prime,d);
			if(d<0.3){
				col+=pal(float(norm)*0.02+t*0.01)*exp(-d*d*50.0)*0.6;
			}
		}
	}}
	// Lattice grid
	float grid=exp(-closest_any*closest_any*30.0);
	col+=vec3(0.15,0.1,0.2)*grid;
	// Prime proximity glow
	col+=vec3(1.0,0.85,0.3)*exp(-closest_prime*5.0)*0.1;
	// Unit group (6 units) highlight at origin
	for(int i=0;i<6;i++){
		float angle=float(i)*TAU/6.0;
		vec2 unit_pt=vec2(cos(angle),sin(angle));
		col+=vec3(0.5,0.3,0.8)*exp(-length(p-unit_pt)*length(p-unit_pt)*20.0)*0.15;
	}
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
