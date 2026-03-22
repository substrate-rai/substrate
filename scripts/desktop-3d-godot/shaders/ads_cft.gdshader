shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
global uniform float audio_energy;
global uniform float beat_intensity;
vec3 pal(float t){return vec3(0.5)+vec3(0.5)*cos(TAU*(vec3(0.8,1.0,0.6)*t+vec3(0.0,0.1,0.2)));}
void fragment(){
	vec2 uv=UV*2.0-1.0;float t=TIME;
	vec3 col=vec3(0.01,0.005,0.03);
	// AdS/CFT: Poincare disk (AdS3 time-slice) with boundary CFT
	float r=length(uv);
	if(r>0.99){col=vec3(0.02);ALBEDO=col;return;}
	// Hyperbolic distance from center
	float hyp_r=2.0*atanh(r);
	// Poincare disk: hyperbolic tiling (order-7 triangular)
	float angle=atan(uv.y,uv.x);
	// Tiling pattern via repeated inversion
	vec2 z=uv;float scale=1.0;
	for(int i=0;i<8;i++){
		// Invert in circles to create hyperbolic tiling
		float zr=length(z);
		if(zr>0.5){z=z/(zr*zr)*0.25;}
		z=abs(z);
		if(z.x<z.y)z=z.yx;
		z-=vec2(0.3,0.0);
		scale*=2.0;
	}
	float tile=length(z)*scale;
	float tile_edge=abs(fract(tile*0.5)-0.5)*2.0;
	// Boundary CFT (conformal field theory on the circle)
	float boundary_d=abs(r-0.98);
	float cft_energy=0.0;
	for(int n=1;n<=8;n++){
		float fn=float(n);
		cft_energy+=sin(angle*fn-t*fn*0.3)/(fn*fn)*exp(-boundary_d*50.0*fn);
	}
	// Bulk geometry (hyperbolic grid)
	col+=pal(tile_edge+hyp_r*0.1+t*0.02)*smoothstep(0.05,0.0,1.0-tile_edge)*0.4;
	// Radial depth gradient
	col+=pal(hyp_r*0.2+0.3)*0.1/(1.0+hyp_r);
	// Boundary CFT excitations
	col+=pal(cft_energy*2.0+0.5)*abs(cft_energy)*0.5;
	// Bulk-boundary geodesics (minimal surfaces)
	for(int i=0;i<6;i++){
		float fi=float(i);
		float geodesic_angle=fi*TAU/6.0+t*0.05;
		// Geodesic in Poincare disk = circular arc perpendicular to boundary
		vec2 geo_center=vec2(cos(geodesic_angle),sin(geodesic_angle))*1.3;
		float geo_r=sqrt(1.3*1.3-1.0);
		float geo_d=abs(length(uv-geo_center)-geo_r);
		col+=vec3(1.0,0.85,0.3)*smoothstep(0.01,0.0,geo_d)*0.1;
	}
	// Boundary ring
	col+=vec3(0.8,0.6,1.0)*exp(-boundary_d*100.0)*0.3;
	// Particles falling into bulk
	for(int p_idx=0;p_idx<4;p_idx++){
		float fp=float(p_idx);
		float fall_phase=fract(t*0.1+fp*0.25);
		float fall_r=0.98*(1.0-fall_phase);
		float fall_angle=fp*TAU/4.0+t*0.03;
		vec2 particle=vec2(cos(fall_angle),sin(fall_angle))*fall_r;
		float pd=length(uv-particle);
		col+=vec3(1.0)*exp(-pd*pd*500.0)*(1.0-fall_phase)*0.15;
	}
	col*=1.0+audio_energy*0.2;col=col/(col+vec3(1.0));ALBEDO=col;
}
