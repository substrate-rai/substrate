shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(0.8,1.0,0.6)*t+vec3(0.0,0.1,0.2)));}
float sdSphere(vec3 p,float r){return length(p)-r;}
float apollonian(vec3 p){
	float scale=1.0;float d=1e10;
	for(int i=0;i<8;i++){
		// Fold into positive octant
		p=abs(p);
		// Sort coordinates (bubble sort for 3)
		if(p.x<p.y)p.xy=p.yx;if(p.y<p.z)p.yz=p.zy;if(p.x<p.y)p.xy=p.yx;
		// Scale and translate
		float s=2.0;
		p=p*s-vec3(s-1.0);
		scale*=s;
		// Sphere fold
		float r2=dot(p,p);
		if(r2<0.5){float f=1.0/0.5;p*=f;scale*=f;}
		else if(r2<1.0){float f=1.0/r2;p*=f;scale*=f;}
		d=min(d,sdSphere(p,1.0)/scale);
	}
	return d;
}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	float ca=cos(t*0.1),sa=sin(t*0.1);
	float ce=cos(t*0.07),se=sin(t*0.07);
	vec3 ro=vec3(ca*3.0,se*2.0,sa*3.0);
	vec3 target=vec3(0.0);
	vec3 fwd=normalize(target-ro);
	vec3 right=normalize(cross(fwd,vec3(0,1,0)));
	vec3 up=cross(right,fwd);
	vec3 rd=normalize(fwd+uv.x*right*0.8+uv.y*up*0.8);
	vec3 col=vec3(0.01,0.005,0.03);
	float td=0.0;
	for(int i=0;i<120;i++){
		vec3 p=ro+rd*td;
		float d=apollonian(p);
		if(d<0.001){
			// Normal
			float e=0.001;
			vec3 n=normalize(vec3(apollonian(p+vec3(e,0,0))-apollonian(p-vec3(e,0,0)),apollonian(p+vec3(0,e,0))-apollonian(p-vec3(0,e,0)),apollonian(p+vec3(0,0,e))-apollonian(p-vec3(0,0,e))));
			vec3 light=normalize(vec3(1,2,3));
			float diff=max(dot(n,light),0.0);
			float spec=pow(max(dot(reflect(-light,n),-rd),0.0),32.0);
			col=pal(dot(p,vec3(0.3))+t*0.02)*(0.2+diff*0.6)+vec3(1.0)*spec*0.3;
			float ao=1.0-float(i)/120.0;
			col*=ao;
			break;
		}
		td+=d;if(td>10.0)break;
	}
	col*=1.0+audio_energy*0.2;col=col/(col+vec3(1.0));ALBEDO=col;
}
