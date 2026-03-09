/** NovelEngine - Ren'Py-inspired VN engine. Pure JS. */
(function(W){
'use strict';
var D=document,M=Math,PI=M.PI*2,R=M.random,S=M.sin,Co=M.cos,F=M.floor;
function mk(t,s,p){var e=D.createElement(t);if(s)e.style.cssText=s;if(p)p.appendChild(e);return e}
function bt(t,s,p,f){var b=mk('button',s,p);b.textContent=t;if(f)b.addEventListener('click',f);return b}
function scan(c,w,h){c.fillStyle='rgba(0,0,0,.03)';for(var y=0;y<h;y+=3)c.fillRect(0,y,w,1)}
function stars(c,w,h,t,n){for(var i=0;i<(n||20);i++){c.fillStyle='rgba(255,255,255,'+(0.1+S(t*.8+i*1.5)*.08)+')';c.beginPath();c.arc((i*137.5)%w,(i*73.7)%(h*.6),1,0,PI);c.fill()}}
function grid(c,w,h,col,sp){c.strokeStyle=col;c.lineWidth=.5;for(var x=0;x<w;x+=sp){c.beginPath();c.moveTo(x,0);c.lineTo(x,h);c.stroke()}}
function dots(c,w,h,t,n,col){for(var i=0;i<n;i++){c.fillStyle=col(t,i);c.beginPath();c.arc((S(t*.2+i*2.3)*.5+.5)*w,(Co(t*.15+i*1.7)*.5+.5)*h,2+S(t*.5+i),0,PI);c.fill()}}
function lgr(c,w,h,st){var g=c.createLinearGradient(0,0,0,h);for(var i=0;i<st.length;i++)g.addColorStop(st[i][0],st[i][1]);c.fillStyle=g;c.fillRect(0,0,w,h)}
var BG={
black:function(c,w,h){c.fillStyle='#08080d';c.fillRect(0,0,w,h)},
'server-room':function(c,w,h,t){c.fillStyle='#0a0d14';c.fillRect(0,0,w,h);grid(c,w,h,'rgba(0,224,154,.04)',40);
 for(var i=0;i<20;i++)if(S(t*2+i*1.7)>.3){c.fillStyle=i%2?'rgba(0,255,100,.4)':'rgba(0,180,255,.3)';c.fillRect((i*137)%w,(i*97)%h,3,2)}scan(c,w,h)},
terminal:function(c,w,h,t){c.fillStyle='rgba(8,13,20,.92)';c.fillRect(0,0,w,h);c.font='10px monospace';
 for(var i=0,n=F(w/14);i<n;i++){var y=((t*30+i*47)%(h+100))-50;c.fillStyle='rgba(0,224,154,'+(0.05+R()*.1)+')';c.fillText('01>_'[i%4],i*14,y)}scan(c,w,h)},
void:function(c,w,h,t){c.fillStyle='#000';c.fillRect(0,0,w,h);dots(c,w,h,t,40,function(t,i){return'rgba(255,255,255,'+M.max(0,.03+S(t*.5+i)*.02)+')'})},
city:function(c,w,h,t){lgr(c,w,h,[[0,'#05050f'],[.6,'#0a0818'],[1,'#100820']]);stars(c,w,h,t,25);
 c.fillStyle='#08080d';for(var b=0;b<w;b+=30+(b*7%20)){var bw=15+(b*13%20),bt=h*.6-30-(b*17%100);c.fillRect(b,bt,bw,h-bt)}},
nature:function(c,w,h,t){lgr(c,w,h,[[0,'#0a1a0d'],[.5,'#0d200f'],[1,'#081008']]);
 for(var i=0;i<6;i++){var tx=(i*160+50)%w,ty=h*.75;c.fillStyle='rgba(20,80,30,.25)';c.beginPath();c.arc(tx+S(t*.3+i)*3,ty-30,20,0,PI);c.fill()}},
office:function(c,w,h,t){c.fillStyle='#12100e';c.fillRect(0,0,w,h);
 c.strokeStyle='rgba(255,220,150,.1)';c.lineWidth=2;c.strokeRect(w*.6,h*.1,w*.3,h*.4)},
space:function(c,w,h,t){c.fillStyle='#020208';c.fillRect(0,0,w,h);stars(c,w,h,t,50)},
boot:function(c,w,h,t){c.fillStyle='#050a05';c.fillRect(0,0,w,h);c.font='11px monospace';c.fillStyle='rgba(0,180,100,.3)';var l='> initializing...',sl=F(t*3)%(l.length+20);c.fillText(l.substring(0,M.min(sl,l.length)),20,h*.4);if(sl>l.length+5)c.fillText('> ready',20,h*.4+16)},
gpu:function(c,w,h,t){c.fillStyle='#0d0808';c.fillRect(0,0,w,h);for(var i=0;i<6;i++){var px=w*.2+S(t*.5+i)*w*.3,py=h*.3+Co(t*.3+i*.7)*h*.2,g=c.createRadialGradient(px,py,0,px,py,80);g.addColorStop(0,'rgba(228,119,255,.06)');g.addColorStop(1,'rgba(228,119,255,0)');c.fillStyle=g;c.fillRect(0,0,w,h)}grid(c,w,h,'rgba(228,119,255,.04)',20)},
shelf:function(c,w,h,t){c.fillStyle='#0d0d14';c.fillRect(0,0,w,h);dots(c,w,h,t,15,function(t,i){return'rgba(100,120,180,'+(.03+S(t+i)*.02)+')'})},
dawn:function(c,w,h,t){var hu=270+S(t*.1)*15;lgr(c,w,h,[[0,'hsl('+hu+',30%,8%)'],[.5,'hsl('+(hu-20)+',25%,7%)'],[1,'hsl('+(hu-40)+',20%,5%)']]);stars(c,w,h,t)},
crisis:function(c,w,h,t){c.fillStyle='#0d0505';c.fillRect(0,0,w,h);c.fillStyle='rgba(255,30,30,'+((S(t*2)*.5+.5)*.08)+')';c.fillRect(0,0,w,h)}
};
// FX
var FX={
shake:function(el,s,d){s=s||5;d=d||400;var st=Date.now(),o=el.style.transform;(function f(){var e=Date.now()-st;if(e>d){el.style.transform=o||'';return}var k=1-e/d;el.style.transform='translate('+((R()-.5)*s*2*k)+'px,'+((R()-.5)*s*2*k)+'px)';requestAnimationFrame(f)})()},
flash:function(el,c,d){d=d||300;var o=mk('div',TO+'z-index:100;background:'+(c||'#fff')+';opacity:.7;transition:opacity '+(d/1e3)+'s ease',el);requestAnimationFrame(function(){o.style.opacity='0'});setTimeout(function(){rm(o)},d+50)},
particles:function(c,w,h,t,ty){for(var i=0;i<50;i++){var s=i*137.5;if(ty==='rain'){c.strokeStyle='rgba(150,180,220,.15)';c.lineWidth=1;c.beginPath();var ry=((t*200+s*3)%(h+20))-10;c.moveTo(s%w,ry);c.lineTo(s%w-1,ry+8);c.stroke()}else{c.fillStyle='rgba(220,230,255,.1)';c.beginPath();c.arc((s%w)+S(t*.5+i)*20,((t*20+s*2)%(h+10))-5,2,0,PI);c.fill()}}},
crt:function(c,w,h){scan(c,w,h)},
vignette:function(c,w,h){var v=c.createRadialGradient(w/2,h/2,w*.25,w/2,h/2,w*.7);v.addColorStop(0,'rgba(0,0,0,0)');v.addColorStop(1,'rgba(0,0,0,.4)');c.fillStyle=v;c.fillRect(0,0,w,h)}
};
var TO='position:absolute;top:0;left:0;right:0;bottom:0;z-index:90;pointer-events:none;background:#000;';
function rm(e){if(e&&e.parentNode)e.parentNode.removeChild(e)}
function trans(el,ty,d,cb){d=d||600;if(!ty){if(cb)cb();return}var hd=d/2,hs=(d/2e3)+'s ease';
 if(ty==='fade'||ty==='dissolve'){var o=mk('div',TO+'opacity:0;transition:opacity '+hs,el);requestAnimationFrame(function(){o.style.opacity=ty==='fade'?'1':'.6'});setTimeout(function(){if(cb)cb();requestAnimationFrame(function(){o.style.opacity='0'});setTimeout(function(){rm(o)},hd+50)},hd)}
 else if(ty==='slide-left'||ty==='slide-right'){var dr=ty[6]==='l'?-1:1,o=mk('div',TO+'transform:translateX('+(dr*100)+'%);transition:transform '+hs,el);requestAnimationFrame(function(){o.style.transform='translateX(0)'});setTimeout(function(){if(cb)cb();o.style.transform='translateX('+(-dr*100)+'%)';setTimeout(function(){rm(o)},hd+50)},hd)}
 else if(ty==='curtain'){var cs='position:absolute;top:0;bottom:0;width:50%;z-index:90;pointer-events:none;background:#000;transition:transform '+hs+';',l=mk('div',cs+'left:0;transform:translateX(-100%)',el),r=mk('div',cs+'right:0;transform:translateX(100%)',el);requestAnimationFrame(function(){l.style.transform=r.style.transform='translateX(0)'});setTimeout(function(){if(cb)cb();l.style.transform='translateX(-100%)';r.style.transform='translateX(100%)';setTimeout(function(){rm(l);rm(r)},hd+50)},hd)}
 else{if(cb)cb()}}
// Audio
var Aud={_c:null,_m:null,
 ctx:function(){if(!this._c){this._c=new(W.AudioContext||W.webkitAudioContext)();this._m=this._c.createGain();this._m.gain.value=.3;this._m.connect(this._c.destination)}if(this._c.state==='suspended')this._c.resume();return this._c},
 blip:function(p){try{var c=this.ctx(),t=c.currentTime,o=c.createOscillator(),g=c.createGain();o.type='sine';o.frequency.setValueAtTime(p||440,t);g.gain.setValueAtTime(.08,t);g.gain.exponentialRampToValueAtTime(.001,t+.06);o.connect(g);g.connect(this._m);o.start(t);o.stop(t+.06)}catch(e){}},
 sfx:function(ty){try{var c=this.ctx(),t=c.currentTime,o=c.createOscillator(),g=c.createGain();o.connect(g);g.connect(this._m);if(ty==='door'){o.type='triangle';o.frequency.setValueAtTime(200,t);o.frequency.linearRampToValueAtTime(80,t+.2);g.gain.setValueAtTime(.15,t);g.gain.exponentialRampToValueAtTime(.001,t+.25);o.start(t);o.stop(t+.25)}else if(ty==='alert'){o.type='square';o.frequency.setValueAtTime(880,t);o.frequency.setValueAtTime(660,t+.1);g.gain.setValueAtTime(.1,t);g.gain.exponentialRampToValueAtTime(.001,t+.3);o.start(t);o.stop(t+.3)}else{o.type='sine';o.frequency.setValueAtTime(120,t);g.gain.setValueAtTime(.03,t);g.gain.exponentialRampToValueAtTime(.001,t+2);o.start(t);o.stop(t+2)}}catch(e){}},
 vol:function(v){if(this._m)this._m.gain.value=M.max(0,M.min(1,v))}};
// Shared styles
var MF='font-family:monospace;',SB=MF+'font-size:.8rem;padding:10px 32px;background:0;border:2px solid rgba(255,255,255,.1);color:#aaa;cursor:pointer;border-radius:0;width:220px;text-align:center',
 OV='position:absolute;top:0;left:0;right:0;bottom:0;z-index:',DB=MF+'font-size:.6rem;padding:2px 8px;background:0;border:1px solid rgba(255,255,255,.1);color:rgba(255,255,255,.25);cursor:pointer;border-radius:0';
// === Engine ===
function NE(box,o){o=o||{};var T=this;T.C=box;T.id=o.gameId||'nv';T.chars={};T.script=[];T.labels={};T.vars={};
 T.s={pc:0,ty:false,tm:null,tx:'',ci:0,on:false,end:false,h:[],ch:[],vis:{},bg:'',auto:false,skip:false};
 T.seen={};T.SPD=o.typeSpeed||25;T.SK='nv_'+T.id;T.bgs={};T.fx={p:null,crt:false,vig:false};
 T.onEnd=o.onEnd||null;T.aud=o.audio!==false;for(var k in BG)T.bgs[k]=BG[k];T._dom();T._ev();T._af=null;T._at=0}
var P=NE.prototype;
P._dom=function(){
 var T=this,B=T.C,PA='position:absolute;',FC='display:flex;flex-direction:column;align-items:center;justify-content:center;';
 B.style.cssText+='position:relative;overflow:hidden;background:#08080d;';B.innerHTML='';
 T.cv=mk('canvas',PA+'top:0;left:0;width:100%;height:100%;z-index:0;pointer-events:none;image-rendering:pixelated',B);T.cx=T.cv.getContext('2d');
 T.$ch=mk('div',PA+'bottom:200px;left:0;right:0;display:flex;justify-content:center;gap:40px;z-index:2',B);
 T.$cp=mk('div',PA+'top:16px;left:20px;'+MF+'font-size:.65rem;color:rgba(255,255,255,.2);z-index:5;letter-spacing:2px;text-transform:uppercase',B);
 T.$sv=mk('div',PA+'top:16px;right:60px;'+MF+'font-size:.6rem;color:rgba(0,224,154,.4);z-index:5;opacity:0;transition:opacity .3s',B);T.$sv.textContent='saved';
 bt('\u2630',PA+'top:12px;right:16px;z-index:60;background:rgba(0,0,0,.4);border:2px solid rgba(255,255,255,.15);color:#aaa;padding:4px 8px;cursor:pointer;'+MF+'font-size:1rem;border-radius:0',B,function(){if(T.s.on)T.$mn.style.display=T.$mn.style.display==='flex'?'none':'flex'});
 T.$mn=mk('div',OV+'55;background:rgba(0,0,0,.85);display:none;'+FC+'gap:12px',B);
 mk('div',MF+'font-size:1rem;color:#888;margin-bottom:16px;letter-spacing:3px',T.$mn).textContent='MENU';
 'resume:RESUME,save1:SAVE 1,save2:SAVE 2,save3:SAVE 3,load1:LOAD 1,load2:LOAD 2,load3:LOAD 3,hist:HISTORY,set:SETTINGS'.split(',').forEach(function(s){var p=s.split(':');bt(p[1],SB,T.$mn,function(){T._mc(p[0])})});
 T.$ho=mk('div',OV+'56;background:rgba(0,0,0,.92);display:none;flex-direction:column;overflow-y:auto;padding:40px 24px 24px',B);
 bt('CLOSE',MF+'font-size:.75rem;padding:6px 16px;background:rgba(0,0,0,.8);border:2px solid rgba(255,255,255,.15);color:#aaa;cursor:pointer;border-radius:0;margin-bottom:16px;position:sticky;top:0;align-self:flex-end;z-index:1',T.$ho,function(){T.$ho.style.display='none'});
 T.$hc=mk('div','',T.$ho);
 T.$so=mk('div',OV+'56;background:rgba(0,0,0,.92);display:none;'+FC+'gap:16px',B);
 mk('div',MF+'font-size:.9rem;color:#888;letter-spacing:2px;margin-bottom:8px',T.$so).textContent='SETTINGS';
 var is='width:140px;accent-color:#0fa';
 function sr(l){var r=mk('div','display:flex;align-items:center;gap:12px',T.$so);mk('span',MF+'font-size:.75rem;color:#888;width:90px',r).textContent=l;return r}
 var sl=mk('input',is,sr('SPEED'));sl.type='range';sl.min='5';sl.max='60';sl.value=String(T.SPD);sl.addEventListener('input',function(){T.SPD=65-parseInt(sl.value)});
 var vs=mk('input',is,sr('VOLUME'));vs.type='range';vs.min='0';vs.max='100';vs.value='30';vs.addEventListener('input',function(){Aud.vol(parseInt(vs.value)/100)});
 bt('CLOSE',SB+';width:auto;margin-top:16px',T.$so,function(){T.$so.style.display='none'});
 T.$cl=mk('div',PA+'bottom:200px;left:50%;transform:translateX(-50%);z-index:20;display:flex;flex-direction:column;gap:8px;width:90%;max-width:480px',B);
 T.$dl=mk('div',PA+'bottom:0;left:0;right:0;background:linear-gradient(to top,rgba(8,8,13,.98) 70%,rgba(8,8,13,.85));backdrop-filter:blur(8px);padding:24px 32px 28px;z-index:10;min-height:180px;cursor:pointer;border-top:2px solid rgba(255,255,255,.06);display:none;border-radius:0',B);T.$dl.tabIndex=0;
 var inn=mk('div','display:flex;gap:14px;align-items:flex-start',T.$dl);
 T.$sp=mk('img','width:64px;height:64px;border:2px solid rgba(255,255,255,.1);object-fit:cover;flex-shrink:0;display:none;border-radius:0;image-rendering:pixelated',inn);
 var cnt=mk('div','flex:1;min-width:0',inn);
 T.$sn=mk('div',MF+'font-size:.8rem;font-weight:600;margin-bottom:8px;letter-spacing:1px',cnt);
 T.$tx=mk('div',MF+'font-size:.95rem;line-height:1.8;color:#c8c8d0;min-height:3.6em',cnt);
 T.$ad=mk('div',PA+'bottom:8px;right:16px;'+MF+'font-size:.65rem;color:rgba(255,255,255,.25)',T.$dl);
 var dbb=mk('div',PA+'bottom:8px;left:16px;display:flex;gap:8px',T.$dl);
 T.$skb=bt('SKIP',DB,dbb,function(e){e.stopPropagation();T.s.skip=!T.s.skip;T.$skb.style.color=T.s.skip?'#0fa':'rgba(255,255,255,.25)';if(T.s.skip&&!T.s.ty)T._adv()});
 bt('AUTO',DB,dbb,function(e){e.stopPropagation();T.s.auto=!T.s.auto});
 T.$tl=mk('div',OV+'50;'+FC+'background:radial-gradient(ellipse at center,#0d0d18,#08080d 70%);transition:opacity 1s ease',B);
};
P._ev=function(){var T=this;T.$dl.addEventListener('click',function(){T._adv()});D.addEventListener('keydown',function(e){if(!T.s.on||T.$mn.style.display==='flex'||T.$ho.style.display==='flex'||T.$so.style.display==='flex')return;if(e.key===' '||e.key==='Enter'){e.preventDefault();if(!T.$cl.children.length)T._adv()}})};
P._mc=function(id){this.$mn.style.display='none';if(id==='resume')return;if(id[0]==='s'&&id[1]==='a')this._ss(+id[4]);else if(id[0]==='l')this._ls(+id[4]);else if(id==='hist')this._sh();else if(id==='set')this.$so.style.display='flex'};
// Public
P.defineCharacter=function(id,o){this.chars[id]={name:o.name||id,color:o.color||'#fff',tc:o.textColor||'#c8c8d0',portrait:o.portrait||null,sprite:o.sprite||'',blip:o.blipPitch||(300+id.charCodeAt(0)*3),role:o.role||''}};
P.defineBackground=function(n,fn){this.bgs[n]=fn};
P.loadScript=function(sc){this.script=sc;this.labels={};for(var i=0;i<sc.length;i++)if(sc[i].type==='label')this.labels[sc[i].name]=i};
P.setTitle=function(t,s){this._gt=t;this._gs=s};
P.setVar=function(n,v){this.vars[n]=v};P.getVar=function(n){return this.vars[n]};
P.ifVar=function(n,op,v,tl,el){if(this._cd({var:n,op:op,val:v})){if(tl){var t=this.labels[tl];if(t!=null)this._run(t)}}else if(el){var e=this.labels[el];if(e!=null)this._run(e)}};
P.start=function(){
 var T=this,h='<h1 style="'+MF+'font-size:3rem;font-weight:600;letter-spacing:.3em;color:#e8e8ef;margin:0 0 8px;border:none;padding:0">'+(T._gt||'NOVEL')+'</h1><div style="'+MF+'font-size:.9rem;color:#6a6a78;margin-bottom:48px">'+(T._gs||'')+'</div><button id="ne-s" style="'+SB+'">BEGIN</button>';
 if(T._hs())h+='<button id="ne-c" style="'+SB+';margin-top:12px;border-color:rgba(255,255,255,.08);color:#6a6a78">CONTINUE</button>';
 T.$tl.innerHTML=h;
 function go(sv){T.s.on=true;if(sv){T.vars=sv.vars||{};T.s.ch=sv.ch||[];T.s.h=sv.h||[];T.seen=sv.seen||{}}else{T.vars={};T.s.ch=[];T.s.h=[];T.seen={}}T.$tl.style.opacity='0';T.$tl.style.pointerEvents='none';setTimeout(function(){T.$tl.style.display='none';sv?T._rest(sv):T._run(0)},500)}
 T.$tl.querySelector('#ne-s').addEventListener('click',function(){go()});
 var cb=T.$tl.querySelector('#ne-c');if(cb)cb.addEventListener('click',function(){var sv=T._la();if(sv)go(sv)})};
// Exec
P._run=function(pc){
 if(pc<0||pc>=this.script.length){this._end();return}this.s.pc=pc;var c=this.script[pc],T=this;if(!c){this._end();return}
 switch(c.type){
  case'label':T._run(pc+1);break;
  case'scene':T._as();if(c.chapter)T.$cp.textContent=c.chapter;T.fx={p:c.particles||null,crt:!!c.crt,vig:!!c.vignette};
   if(c.transition){trans(T.C,c.transition,c.duration||600,function(){T._bg(c.bg||'black')});setTimeout(function(){T._run(pc+1)},(c.duration||600)+50)}else{T._bg(c.bg||'black');T._run(pc+1)}break;
  case'chapter':T.$cp.textContent=c.text||'';T._run(pc+1);break;
  case'show':T._sch(c.char,c.position||'center');T._run(pc+1);break;
  case'hide':T._hch(c.char);T._run(pc+1);break;
  case'hideall':T.$ch.innerHTML='';T.s.vis={};T._run(pc+1);break;
  case'say':T._dlg(c.char,c.text,0,0);break;case'narrate':T._dlg(null,c.text,0,0);break;
  case'think':T._dlg(c.char,c.text,1,0);break;case'shout':T._dlg(c.char,c.text,0,1);break;
  case'choice':T._cho(c.prompt,c.choices);break;
  case'set':T.vars[c.var]=c.value;T._run(pc+1);break;
  case'add':T.vars[c.var]=(T.vars[c.var]||0)+(c.value||1);T._run(pc+1);break;
  case'jump':var t=T.labels[c.to];T._run(t!=null?t:pc+1);break;
  case'if':if(T._cd(c.condition||c)){var jt=T.labels[c.then];T._run(jt!=null?jt:pc+1)}else if(c.else){var je=T.labels[c.else];T._run(je!=null?je:pc+1)}else T._run(pc+1);break;
  case'sfx':if(T.aud)Aud.sfx(c.sound);T._run(pc+1);break;
  case'effect':if(c.effect==='shake')FX.shake(T.C,c.intensity,c.duration);else if(c.effect==='flash')FX.flash(T.C,c.color,c.duration);T._run(pc+1);break;
  case'wait':setTimeout(function(){T._run(pc+1)},c.duration||1e3);break;
  case'end':T._end();break;default:T._run(pc+1)}};
P._cd=function(c){if(!c)return false;var v=this.vars[c.var],x=c.val;if(v==null)v=0;switch(c.op){case'==':case'===':return v==x;case'!=':case'!==':return v!=x;case'>':return v>x;case'<':return v<x;case'>=':return v>=x;case'<=':return v<=x;case'is':return!!v;case'not':return!v;default:return!!v}};
P._bg=function(k){this.s.bg=k;var T=this;if(T._af)cancelAnimationFrame(T._af);T._at=performance.now();var fn=T.bgs[k]||BG.black;
 (function f(){var cv=T.cv,cx=T.cx;if(!cv)return;var r=cv.parentElement.getBoundingClientRect();if(cv.width!==r.width||cv.height!==r.height){cv.width=r.width;cv.height=r.height}
 var t=(performance.now()-T._at)/1e3,w=cv.width,h=cv.height;fn(cx,w,h,t);if(T.fx.p)FX.particles(cx,w,h,t,T.fx.p);if(T.fx.crt)FX.crt(cx,w,h);if(T.fx.vig)FX.vignette(cx,w,h);T._af=requestAnimationFrame(f)})()};
// Chars
P._sch=function(id,pos){var ch=this.chars[id];if(!ch)return;this._hch(id);
 var e=mk('div','text-align:center;transition:transform .5s steps(8),opacity .5s steps(8),filter .5s ease;filter:brightness(.5);opacity:0');e.setAttribute('data-char',id);
 if(ch.portrait){var i=mk('img','width:100px;height:100px;border:2px solid '+ch.color+';object-fit:cover;border-radius:0;image-rendering:pixelated',e);i.src=ch.portrait;i.alt=ch.name}
 else if(ch.sprite)mk('div',MF+'font-size:4rem;line-height:1;color:'+ch.color,e).textContent=ch.sprite;
 mk('div',MF+'font-size:.65rem;margin-top:4px;opacity:.6;letter-spacing:1px;text-transform:uppercase;color:'+ch.color,e).textContent=ch.name;
 this.s.vis[id]=pos;this.$ch.appendChild(e);requestAnimationFrame(function(){e.style.opacity='1'})};
P._hch=function(id){delete this.s.vis[id];var e=this.$ch.querySelector('[data-char="'+id+'"]');if(e){e.style.opacity='0';setTimeout(function(){if(e.parentNode)e.parentNode.removeChild(e)},500)}};
P._hl=function(id){var els=this.$ch.querySelectorAll('[data-char]');for(var i=0;i<els.length;i++){var e=els[i],m=e.getAttribute('data-char')===id;e.style.filter='brightness('+(m?1:.5)+')';e.style.transform=m?'scale(1.05)':''}};
// Dlg
P._dlg=function(cid,tx,th,sh){
 var ch=cid?this.chars[cid]:null,T=this;T.$dl.style.display='block';T.$cl.innerHTML='';
 T.$sn.textContent=ch&&ch.name?ch.name:'';if(ch)T.$sn.style.color=ch.color;
 if(ch&&ch.portrait){T.$sp.src=ch.portrait;T.$sp.alt=ch.name;T.$sp.style.display='block';T.$sp.style.borderColor=ch.color}else T.$sp.style.display='none';
 if(cid)T._hl(cid);
 T.$tx.style.fontSize=sh?'1.2rem':'.95rem';T.$tx.style.fontWeight=sh?'700':'400';
 T.$tx.style.fontStyle=th?'italic':'normal';T.$tx.style.color=th?'rgba(200,200,210,.7)':(ch&&ch.tc)||'#c8c8d0';
 if(sh)FX.shake(T.C,4,300);
 T.s.h.push({name:ch?ch.name:'',color:ch?ch.color:'#888',text:tx,th:th});
 var tk=T.s.pc+':'+tx.substring(0,20),seen=!!T.seen[tk];T.seen[tk]=true;T._tp(tx,ch,seen&&T.s.skip)};
P._tp=function(tx,ch,inst){
 var T=this;T.s.ty=true;T.s.ci=0;T.s.tx=tx;T.$tx.textContent='';T.$ad.textContent='';if(T.s.tm)clearInterval(T.s.tm);
 if(inst){T.$tx.textContent=tx;T.s.ty=false;T.$ad.textContent='\u25bc';setTimeout(function(){T._adv()},50);return}
 var bc=0;T.s.tm=setInterval(function(){if(T.s.ci<tx.length){T.s.ci++;T.$tx.textContent=tx.substring(0,T.s.ci);if(T.aud&&bc%3===0&&ch)Aud.blip(ch.blip);bc++}
  else{clearInterval(T.s.tm);T.s.tm=null;T.s.ty=false;T.$ad.textContent='\u25bc';if(T.s.auto)setTimeout(function(){if(T.s.auto&&!T.s.ty)T._adv()},1500)}},T.SPD)};
P._st=function(){if(this.s.ty){if(this.s.tm)clearInterval(this.s.tm);this.s.tm=null;this.$tx.textContent=this.s.tx;this.s.ty=false;this.$ad.textContent='\u25bc'}};
P._adv=function(){if(this.s.end){this._rst();return}if(this.s.ty){this._st();return}this._run(this.s.pc+1)};
// Choices
P._cho=function(pr,choices){
 var T=this;T.$dl.style.display='none';T.$cl.innerHTML='';
 if(pr)mk('div',MF+'font-size:.8rem;color:rgba(255,255,255,.4);text-align:center;margin-bottom:8px',T.$cl).textContent=pr;
 var fc=[];for(var i=0;i<choices.length;i++)if(!choices[i].condition||T._cd(choices[i].condition))fc.push(choices[i]);
 fc.forEach(function(c,idx){
  var b=bt(c.text,MF+'font-size:.9rem;padding:14px 20px;background:rgba(20,20,30,.9);border:2px solid rgba(255,255,255,.1);color:#c8c8d0;cursor:pointer;text-align:left;min-height:48px;border-radius:0;transition:all .2s',T.$cl,function(){
   T.s.ch.push({pc:T.s.pc,i:idx,text:c.text});T.$cl.innerHTML='';if(c.set)for(var k in c.set)T.vars[k]=c.set[k];T._as();
   var t=c.next?T.labels[c.next]:null;T._run(t!=null?t:T.s.pc+1)});
  b.onmouseenter=function(){b.style.borderColor='rgba(255,255,255,.25)';b.style.color='#fff';b.style.transform='translateX(4px)'};
  b.onmouseleave=function(){b.style.borderColor='rgba(255,255,255,.1)';b.style.color='#c8c8d0';b.style.transform=''}})};
// History
P._sh=function(){this.$hc.innerHTML='';for(var i=0;i<this.s.h.length;i++){var h=this.s.h[i],l=mk('div','margin-bottom:12px;'+MF+'font-size:.85rem;line-height:1.6',this.$hc);
 if(h.name)mk('span','font-weight:600;color:'+h.color,l).textContent=h.name+'  ';
 mk('span','color:#c8c8d0;'+(h.th?'font-style:italic;opacity:.7':''),l).textContent=h.text}
 this.$ho.style.display='flex';this.$ho.scrollTop=this.$ho.scrollHeight};
// Save/Load
P._sd=function(){return{pc:this.s.pc,vars:JSON.parse(JSON.stringify(this.vars)),ch:this.s.ch.slice(),h:this.s.h.slice(-100),seen:this.seen,vis:JSON.parse(JSON.stringify(this.s.vis)),bg:this.s.bg,cp:this.$cp.textContent,ts:Date.now()}};
P._as=function(){try{localStorage.setItem(this.SK+'_a',JSON.stringify(this._sd()))}catch(e){}this.$sv.style.opacity='1';var T=this;setTimeout(function(){T.$sv.style.opacity='0'},1500)};
P._ss=function(n){try{localStorage.setItem(this.SK+'_'+n,JSON.stringify(this._sd()))}catch(e){}this.$sv.textContent='slot '+n;this.$sv.style.opacity='1';var T=this;setTimeout(function(){T.$sv.style.opacity='0';T.$sv.textContent='saved'},1500)};
P._ls=function(n){try{var d=JSON.parse(localStorage.getItem(this.SK+'_'+n));if(d&&d.pc!=null)this._rest(d)}catch(e){}};
P._la=function(){try{return JSON.parse(localStorage.getItem(this.SK+'_a'))}catch(e){}return null};
P._hs=function(){try{return!!localStorage.getItem(this.SK+'_a')}catch(e){}return false};
P._rest=function(d){this.vars=d.vars||{};this.s.ch=d.ch||[];this.s.h=d.h||[];this.seen=d.seen||{};this.s.vis={};this.$ch.innerHTML='';
 if(d.bg)this._bg(d.bg);if(d.cp)this.$cp.textContent=d.cp;if(d.vis)for(var id in d.vis)this._sch(id,d.vis[id]);
 this.s.on=true;this.s.end=false;this.$tl.style.display='none';this.$tl.style.opacity='0';this.$tl.style.pointerEvents='none';this._run(d.pc)};
P._end=function(){this.s.end=true;this.$ad.textContent='click to restart';this._as();if(this.onEnd)this.onEnd()};
P._rst=function(){var T=this;T.s={pc:0,ty:false,tm:null,tx:'',ci:0,on:false,end:false,h:[],ch:[],vis:{},bg:'',auto:false,skip:false};T.vars={};T.seen={};
 T.$dl.style.display='none';T.$ch.innerHTML='';T.$cl.innerHTML='';T.$cp.textContent='';T.$tl.style.display='flex';T.$tl.style.opacity='1';T.$tl.style.pointerEvents='auto';
 try{localStorage.removeItem(T.SK+'_a')}catch(e){}T.start()};
W.NovelEngine=NE;NE.BACKGROUNDS=BG;NE.FX=FX;NE.Audio=Aud;
})(window);
