shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
bool is_prime(int n){if(n<2)return false;if(n<4)return true;if(n%2==0||n%3==0)return false;for(int i=5;i*i<=n;i+=6){if(n%i==0||n%(i+2)==0)return false;}return true;}
// Mobius function
int mobius(int n){
	if(n==1)return 1;int factors=0;int temp=n;
	for(int p=2;p*p<=temp;p++){if(temp%p==0){factors++;temp/=p;if(temp%p==0)return 0;}}
	if(temp>1)factors++;
	return(factors%2==0)?1:-1;
}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	float scroll=t*5.0;float x_range=500.0;
	float n_f=(uv.x*0.5+0.5)*x_range+scroll;
	int n=int(n_f);
	// Compute Mertens function M(n) = sum mu(k) for k=1..n
	int M=0;for(int k=1;k<=min(n,1000);k++){M+=mobius(k);}
	float M_f=float(M);
	float y_range=60.0;float target_y=M_f/y_range;
	float pixel_y=uv.y;
	float dist=abs(pixel_y-target_y);
	vec3 col=vec3(0.01,0.005,0.02);
	// Function curve
	float curve=exp(-dist*dist*2000.0);
	vec3 curve_col=(M_f>0.0)?vec3(0.2,0.6,1.0):vec3(1.0,0.3,0.2);
	col+=curve_col*curve*0.8;
	// sqrt(n) bounds (Mertens conjecture was DISPROVED)
	float sqrt_bound=sqrt(abs(n_f))/y_range;
	float upper=smoothstep(0.01,0.0,abs(pixel_y-sqrt_bound));
	float lower=smoothstep(0.01,0.0,abs(pixel_y+sqrt_bound));
	col+=vec3(0.5,0.5,0.2)*(upper+lower)*0.15;
	// Zero line
	col+=vec3(0.2)*smoothstep(0.005,0.0,abs(pixel_y))*0.1;
	// Scatter glow
	col+=pal(M_f*0.02+0.3)*exp(-dist*5.0)*0.05;
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
