shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.8,0.5)*t+vec3(0.0,0.1,0.25)));}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.0,a=0.5;for(int i=0;i<5;i++){v+=a*noise(p);p*=2.0;a*=0.5;}return v;}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec2 p=uv*3.0;vec3 col=vec3(0.01,0.005,0.03);
	// Ricci flow: curvature drives metric evolution
	// Visualize as a surface whose bumps smooth out over time
	// The flow parameter acts like TIME
	float flow_t=mod(t*0.1,2.0); // 0->2, then restart
	if(flow_t>1.0)flow_t=2.0-flow_t; // ping-pong
	// Initial bumpy metric (high curvature features)
	float h0=fbm(p*1.5)*0.8+sin(p.x*3.0)*cos(p.y*2.0)*0.3;
	h0+=sin(length(p-vec2(1.0,0.5))*5.0)*0.2;
	h0+=cos(length(p-vec2(-0.5,-0.8))*7.0)*0.15;
	// Under Ricci flow, curvature smooths: approximate by increasing blur
	float sigma=0.1+flow_t*2.0;
	float h=0.0;float weight=0.0;
	for(int dx=-3;dx<=3;dx++){for(int dy=-3;dy<=3;dy++){
		vec2 offset=vec2(float(dx),float(dy))*sigma*0.15;
		float w=exp(-dot(offset,offset)/(2.0*sigma*sigma*0.02));
		float sample_h=fbm((p+offset)*1.5)*0.8+sin((p.x+offset.x)*3.0)*cos((p.y+offset.y)*2.0)*0.3;
		h+=sample_h*w;weight+=w;
	}}
	h/=weight;
	// Curvature (Laplacian of height)
	float eps=0.05;
	float hx1=fbm((p+vec2(eps,0))*1.5)*0.8;
	float hx2=fbm((p-vec2(eps,0))*1.5)*0.8;
	float hy1=fbm((p+vec2(0,eps))*1.5)*0.8;
	float hy2=fbm((p-vec2(0,eps))*1.5)*0.8;
	float laplacian=(hx1+hx2+hy1+hy2-4.0*h)/(eps*eps);
	// Color: height as terrain, curvature overlay
	vec3 terrain;
	if(h<-0.1)terrain=vec3(0.1,0.2,0.5);
	else if(h<0.1)terrain=vec3(0.2,0.5,0.3);
	else if(h<0.3)terrain=vec3(0.6,0.5,0.2);
	else terrain=vec3(0.8,0.3,0.1);
	col+=terrain*0.6;
	// Curvature: positive=warm, negative=cool
	col+=vec3(0.8,0.2,0.1)*max(laplacian*0.1,0.0);
	col+=vec3(0.1,0.2,0.8)*max(-laplacian*0.1,0.0);
	// Contour lines
	float contour=abs(fract(h*5.0)-0.5)*2.0;
	col*=0.8+smoothstep(0.0,0.05,contour)*0.2;
	// Flow progress indicator
	col+=vec3(0.5)*smoothstep(0.99,0.98,abs(uv.y))*(flow_t*0.3);
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
