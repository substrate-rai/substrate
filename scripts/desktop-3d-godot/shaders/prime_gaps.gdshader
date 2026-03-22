shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
bool is_prime(int n){if(n<2)return false;if(n<4)return true;if(n%2==0||n%3==0)return false;for(int i=5;i*i<=n;i+=6){if(n%i==0||n%(i+2)==0)return false;}return true;}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.02);
	float scroll=t*10.0;
	// X: prime index, Y: gap to next prime
	float x_range=500.0;float x_f=(uv.x*0.5+0.5)*x_range+scroll;
	int target_n=int(x_f);
	// Find primes near target_n
	int prev_p=2;int gap=0;int prime_count=0;
	for(int k=3;k<min(target_n+50,3000);k++){
		if(is_prime(k)){
			gap=k-prev_p;prime_count++;prev_p=k;
			if(prime_count>=target_n-5&&prime_count<=target_n+5){
				float px=float(prime_count-target_n+int(x_range/2.0))/x_range*2.0-1.0;
				float py=float(gap)/40.0-0.5;
				float d=length(uv-vec2(px,py));
				// Point glow
				col+=pal(float(gap)*0.05+t*0.01)*exp(-d*d*3000.0)*0.5;
				// Twin primes (gap=2) extra bright
				if(gap==2)col+=vec3(1.0,0.85,0.3)*exp(-d*d*5000.0)*0.3;
				// Cousin primes (gap=4)
				if(gap==4)col+=vec3(0.3,0.8,0.5)*exp(-d*d*4000.0)*0.2;
				// Sexy primes (gap=6)
				if(gap==6)col+=vec3(0.5,0.3,0.8)*exp(-d*d*3500.0)*0.15;
			}
		}
	}
	// Horizontal lines at common gaps
	for(int g=0;g<10;g++){
		float gy=float(g*2)/40.0-0.5;
		col+=vec3(0.15)*smoothstep(0.005,0.0,abs(uv.y-gy))*0.3;
	}
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
