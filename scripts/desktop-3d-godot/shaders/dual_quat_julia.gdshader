shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(1.0,0.7,0.4)*t+vec3(0.0,0.15,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// Dual quaternion: q = a + epsilon*b where epsilon^2 = 0
	// Julia set: z -> z^2 + c in dual-quaternion space
	// Slice: real part = (uv.x, uv.y, 0, 0), dual part = (0, 0, 0, 0)
	float cx=0.3*sin(t*0.07);float cy=0.3*cos(t*0.09);
	float cz=0.2*sin(t*0.06);float cw=0.2*cos(t*0.08);
	// Dual part of c
	float cdx=0.1*sin(t*0.05);float cdy=0.1*cos(t*0.04);
	// Iterate z^2+c in quaternion space (slice to 2D)
	float zr=uv.x*1.5,zi=uv.y*1.5,zj=0.0,zk=0.0;
	// Dual part tracks derivative (automatic differentiation for free)
	float dr=1.0,di=0.0,dj=0.0,dk=0.0;
	float escape=0.0;int max_iter=60;
	for(int i=0;i<60;i++){
		// z^2 in quaternion: (r^2-i^2-j^2-k^2, 2ri, 2rj, 2rk) approximately
		float nr=zr*zr-zi*zi-zj*zj-zk*zk+cx;
		float ni=2.0*zr*zi+cy;
		float nj=2.0*zr*zj+cz;
		float nk=2.0*zr*zk+cw;
		// Dual part (derivative chain rule)
		float ndr=2.0*(zr*dr-zi*di-zj*dj-zk*dk)+cdx;
		float ndi=2.0*(zr*di+zi*dr)+cdy;
		zr=nr;zi=ni;zj=nj;zk=nk;dr=ndr;di=ndi;
		float r2=zr*zr+zi*zi+zj*zj+zk*zk;
		if(r2>16.0){escape=float(i)-log(log(r2)/log(16.0))/log(2.0);break;}
	}
	if(escape>0.0){
		float t_col=escape/float(max_iter);
		col+=pal(t_col*3.0+t*0.02)*pow(t_col,0.5)*0.8;
		// Dual part gives distance estimate for glow
		float dual_mag=sqrt(dr*dr+di*di+dj*dj+dk*dk);
		col+=vec3(1.0,0.85,0.3)*exp(-dual_mag*0.01)*0.1;
	}else{
		// Interior: color by final dual part
		float interior=sqrt(dr*dr+di*di);
		col+=pal(interior*0.5+0.5)*0.15;
	}
	col*=1.0+audio_energy*0.2;col*=1.0-dot(uv,uv)*0.15;col=col/(col+vec3(1.0));ALBEDO=col;
}
