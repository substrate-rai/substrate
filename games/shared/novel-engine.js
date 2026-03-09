/**
 * NovelEngine - Ren'Py-inspired visual novel engine in pure JS.
 * Substrate games. Static HTML, no deps, <20KB.
 */
(function(W) {
'use strict';
var D = document, M = Math, RAF = requestAnimationFrame, CAF = cancelAnimationFrame;

// Backgrounds (canvas-drawn)
var BG = {
  'black': function(c,w,h){c.fillStyle='#08080d';c.fillRect(0,0,w,h)},
  'server-room': function(c,w,h,t){
    c.fillStyle='#0a0d14';c.fillRect(0,0,w,h);
    c.strokeStyle='rgba(0,224,154,0.04)';c.lineWidth=1;
    for(var x=0;x<w;x+=40){c.beginPath();c.moveTo(x,0);c.lineTo(x,h);c.stroke()}
    for(var i=0;i<30;i++){var lx=(i*137)%w,ly=(i*97)%h;
      if(M.sin(t*2+i*1.7)>0.3){c.fillStyle=['rgba(0,255,100,0.4)','rgba(255,160,0,0.3)','rgba(0,180,255,0.3)'][i%3];c.fillRect(lx,ly,3,2)}}
    c.fillStyle='rgba(0,0,0,0.03)';for(var y=0;y<h;y+=3)c.fillRect(0,y,w,1)
  },
  'terminal': function(c,w,h,t){
    c.fillStyle='rgba(8,13,20,0.92)';c.fillRect(0,0,w,h);c.font='10px monospace';
    var ch='01>_{}[];=+-*/<>&|~^%$#@!',n=M.floor(w/12);
    for(var i=0;i<n;i++){var s=ch[M.floor(M.random()*ch.length)],y=((t*30+i*47)%(h+100))-50;
      c.fillStyle='rgba(0,224,154,'+(0.05+M.random()*0.12)+')';c.fillText(s,i*12,y);
      if(M.random()<0.03){c.fillStyle='rgba(0,224,154,0.4)';c.fillText(s,i*12,y)}}
    c.fillStyle='rgba(0,0,0,0.04)';for(var y=0;y<h;y+=3)c.fillRect(0,y,w,1)
  },
  'void': function(c,w,h,t){
    c.fillStyle='#000';c.fillRect(0,0,w,h);
    for(var i=0;i<40;i++){var px=(M.sin(t*0.1+i*2.5)*0.5+0.5)*w,py=(M.cos(t*0.08+i*1.9)*0.5+0.5)*h;
      c.fillStyle='rgba(255,255,255,'+M.max(0,0.03+M.sin(t*0.5+i)*0.02)+')';c.beginPath();c.arc(px,py,1.5,0,6.28);c.fill()}
  },
  'city': function(c,w,h,t){
    var g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,'#05050f');g.addColorStop(0.6,'#0a0818');g.addColorStop(1,'#100820');
    c.fillStyle=g;c.fillRect(0,0,w,h);
    for(var i=0;i<25;i++){c.fillStyle='rgba(255,255,255,'+(0.1+M.sin(t*0.8+i)*0.08)+')';c.beginPath();c.arc((i*137.5)%w,(i*73.7)%(h*0.4),0.8,0,6.28);c.fill()}
    var bh=h*0.6;c.fillStyle='#08080d';
    for(var b=0;b<w;b+=30+(b*7%20)){var bw=15+(b*13%25),bt=bh-40-(b*17%120);c.fillRect(b,bt,bw,h-bt);
      for(var wy=bt+5;wy<h-10;wy+=8)for(var wx=b+3;wx<b+bw-3;wx+=6)if(M.sin(wx*3+wy*7+t*0.2)>0.4){
        c.fillStyle=['rgba(255,0,100,0.3)','rgba(0,200,255,0.3)','rgba(255,200,0,0.2)','rgba(150,0,255,0.25)'][(wx+wy)%4];c.fillRect(wx,wy,3,4)}}
  },
  'nature': function(c,w,h,t){
    var g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,'#0a1a0d');g.addColorStop(0.5,'#0d200f');g.addColorStop(1,'#081008');
    c.fillStyle=g;c.fillRect(0,0,w,h);c.fillStyle='#0a150a';c.fillRect(0,h*0.75,w,h*0.25);
    for(var i=0;i<8;i++){var tx=(i*137+50)%w,ty=h*0.75,th=40+(i*23%40),sw=M.sin(t*0.3+i)*3;
      c.fillStyle='rgba(60,40,20,0.4)';c.fillRect(tx-2,ty-th,4,th);
      c.fillStyle='rgba(20,80,30,'+(0.25+M.sin(t*0.2+i)*0.05)+')';c.beginPath();c.arc(tx+sw,ty-th-10,18+(i%3)*5,0,6.28);c.fill()}
    for(var f=0;f<10;f++){var fx=(M.sin(t*0.15+f*3.1)*0.4+0.5)*w,fy=(M.cos(t*0.12+f*2.7)*0.3+0.4)*h;
      c.fillStyle='rgba(200,255,100,'+(M.sin(t*1.5+f*2)>0.5?0.4:0.05)+')';c.beginPath();c.arc(fx,fy,2,0,6.28);c.fill()}
  },
  'office': function(c,w,h,t){
    c.fillStyle='#12100e';c.fillRect(0,0,w,h);
    var wl=w*0.6,wt=h*0.1,ww=w*0.3,wh=h*0.4;
    var g=c.createRadialGradient(wl+ww/2,wt+wh/2,0,wl+ww/2,wt+wh/2,ww);
    g.addColorStop(0,'rgba(255,220,150,0.08)');g.addColorStop(1,'rgba(255,220,150,0)');c.fillStyle=g;c.fillRect(0,0,w,h);
    c.strokeStyle='rgba(255,220,150,0.1)';c.lineWidth=2;c.strokeRect(wl,wt,ww,wh);
    c.beginPath();c.moveTo(wl+ww/2,wt);c.lineTo(wl+ww/2,wt+wh);c.stroke();
    c.beginPath();c.moveTo(wl,wt+wh/2);c.lineTo(wl+ww,wt+wh/2);c.stroke()
  },
  'space': function(c,w,h,t){
    c.fillStyle='#020208';c.fillRect(0,0,w,h);
    for(var l=0;l<3;l++){var n=20+l*15,sp=(l+1)*0.02,sz=0.5+l*0.3,br=0.15+l*0.1;
      for(var i=0;i<n;i++){var sx=(i*137.5+l*50)%w,sy=(i*97.3+l*30+t*sp*10)%h;
        c.fillStyle='rgba(255,255,255,'+M.max(0.02,br+M.sin(t*(0.5+l*0.3)+i*1.3)*0.08)+')';c.beginPath();c.arc(sx,sy,sz,0,6.28);c.fill()}}
    var ng=c.createRadialGradient(w*0.7,h*0.3,0,w*0.7,h*0.3,w*0.3);
    ng.addColorStop(0,'rgba(80,20,120,'+(0.04+M.sin(t*0.1)*0.02)+')');ng.addColorStop(1,'rgba(80,20,120,0)');c.fillStyle=ng;c.fillRect(0,0,w,h)
  },
  'boot': function(c,w,h,t){
    c.fillStyle='#050a05';c.fillRect(0,0,w,h);c.font='11px monospace';c.fillStyle='rgba(0,180,100,0.3)';
    var l='> initializing...',sl=M.floor(t*3)%(l.length+20);
    c.fillText(l.substring(0,M.min(sl,l.length)),20,h*0.4);if(sl>l.length+5)c.fillText('> ready',20,h*0.4+16)
  },
  'gpu': function(c,w,h,t){
    c.fillStyle='#0d0808';c.fillRect(0,0,w,h);
    for(var i=0;i<8;i++){var px=w*0.2+M.sin(t*0.5+i)*w*0.3,py=h*0.3+M.cos(t*0.3+i*0.7)*h*0.2;
      var g=c.createRadialGradient(px,py,0,px,py,80+M.sin(t+i)*20);g.addColorStop(0,'rgba(228,119,255,0.06)');g.addColorStop(1,'rgba(228,119,255,0)');c.fillStyle=g;c.fillRect(0,0,w,h)}
    c.strokeStyle='rgba(228,119,255,0.04)';c.lineWidth=0.5;
    for(var x=0;x<w;x+=20){c.beginPath();c.moveTo(x,0);c.lineTo(x,h);c.stroke()}
    for(var y=0;y<h;y+=20){c.beginPath();c.moveTo(0,y);c.lineTo(w,y);c.stroke()}
  },
  'shelf': function(c,w,h,t){
    c.fillStyle='#0d0d14';c.fillRect(0,0,w,h);
    for(var i=0;i<15;i++){var px=(M.sin(t*0.2+i*2.3)*0.5+0.5)*w,py=(M.cos(t*0.15+i*1.7)*0.5+0.5)*h;
      c.fillStyle='rgba(100,120,180,'+(0.03+M.sin(t+i)*0.02)+')';c.beginPath();c.arc(px,py,2+M.sin(t*0.5+i),0,6.28);c.fill()}
  },
  'dawn': function(c,w,h,t){
    var hu=270+M.sin(t*0.1)*15,g=c.createLinearGradient(0,0,0,h);
    g.addColorStop(0,'hsl('+hu+',30%,8%)');g.addColorStop(0.5,'hsl('+(hu-20)+',25%,7%)');g.addColorStop(1,'hsl('+(hu-40)+',20%,5%)');
    c.fillStyle=g;c.fillRect(0,0,w,h);
    for(var i=0;i<20;i++){c.fillStyle='rgba(255,255,255,'+(0.1+M.sin(t*0.8+i*1.5)*0.08)+')';c.beginPath();c.arc((i*137.5)%w,(i*73.7)%(h*0.6),1,0,6.28);c.fill()}
  },
  'crisis': function(c,w,h,t){
    c.fillStyle='#0d0505';c.fillRect(0,0,w,h);c.fillStyle='rgba(255,30,30,'+((M.sin(t*2)*0.5+0.5)*0.08)+')';c.fillRect(0,0,w,h);
    c.strokeStyle='rgba(255,50,50,0.06)';c.lineWidth=2;
    for(var x=-h;x<w+h;x+=30){c.beginPath();c.moveTo(x,0);c.lineTo(x+h,h);c.stroke()}
  }
};

// Visual FX
var FX = {
  shake: function(el,str,dur){
    str=str||5;dur=dur||400;var s=Date.now(),o=el.style.transform;
    (function f(){var e=Date.now()-s;if(e>dur){el.style.transform=o||'';return}
      var d=1-e/dur,x=(M.random()-0.5)*str*2*d,y=(M.random()-0.5)*str*2*d;
      el.style.transform='translate('+x+'px,'+y+'px)';RAF(f)})()
  },
  flash: function(el,col,dur){
    dur=dur||300;var o=D.createElement('div');
    o.style.cssText='position:absolute;top:0;left:0;right:0;bottom:0;z-index:100;pointer-events:none;background:'+(col||'#fff')+';opacity:0.7;transition:opacity '+(dur/1000)+'s ease';
    el.appendChild(o);RAF(function(){o.style.opacity='0'});setTimeout(function(){if(o.parentNode)o.parentNode.removeChild(o)},dur+50)
  },
  particles: function(c,w,h,t,ty){
    for(var i=0;i<60;i++){var s=i*137.508;
      if(ty==='rain'){var rx=s%w,ry=((t*200+s*3)%(h+20))-10;c.strokeStyle='rgba(150,180,220,0.15)';c.lineWidth=1;c.beginPath();c.moveTo(rx,ry);c.lineTo(rx-1,ry+8);c.stroke()}
      else if(ty==='snow'){var sx=(s%w)+M.sin(t*0.5+i)*20,sy=((t*20+s*2)%(h+10))-5;c.fillStyle='rgba(220,230,255,'+(0.1+M.sin(i)*0.05)+')';c.beginPath();c.arc(sx,sy,1.5+(i%3)*0.5,0,6.28);c.fill()}}
  },
  crt: function(c,w,h){c.fillStyle='rgba(0,0,0,0.03)';for(var y=0;y<h;y+=2)c.fillRect(0,y,w,1);
    var v=c.createRadialGradient(w/2,h/2,w*0.3,w/2,h/2,w*0.7);v.addColorStop(0,'rgba(0,0,0,0)');v.addColorStop(1,'rgba(0,0,0,0.3)');c.fillStyle=v;c.fillRect(0,0,w,h)},
  vignette: function(c,w,h){var v=c.createRadialGradient(w/2,h/2,w*0.25,w/2,h/2,w*0.7);v.addColorStop(0,'rgba(0,0,0,0)');v.addColorStop(1,'rgba(0,0,0,0.5)');c.fillStyle=v;c.fillRect(0,0,w,h)}
};

// Transitions
function transition(el,type,dur,cb){
  dur=dur||600;
  if(!type||type==='none'){if(cb)cb();return}
  var o=D.createElement('div');o.style.cssText='position:absolute;top:0;left:0;right:0;bottom:0;z-index:90;pointer-events:none;background:#000;';
  if(type==='fade'||type==='dissolve'){
    o.style.opacity='0';o.style.transition='opacity '+(dur/2000)+'s ease';el.appendChild(o);
    RAF(function(){o.style.opacity=type==='fade'?'1':'0.6'});
    setTimeout(function(){if(cb)cb();RAF(function(){o.style.opacity='0'});setTimeout(function(){if(o.parentNode)o.parentNode.removeChild(o)},dur/2+50)},dur/2)
  } else if(type==='slide-left'||type==='slide-right'){
    var d=type==='slide-left'?'-100%':'100%';o.style.transform='translateX('+d+')';o.style.transition='transform '+(dur/2000)+'s ease';
    el.appendChild(o);RAF(function(){o.style.transform='translateX(0)'});
    setTimeout(function(){if(cb)cb();o.style.transform='translateX('+(type==='slide-left'?'100%':'-100%')+')';setTimeout(function(){if(o.parentNode)o.parentNode.removeChild(o)},dur/2+50)},dur/2)
  } else if(type==='curtain'){
    var bs='position:absolute;top:0;bottom:0;width:50%;z-index:90;pointer-events:none;background:#000;transition:transform '+(dur/2000)+'s ease;';
    var l=D.createElement('div'),r=D.createElement('div');
    l.style.cssText=bs+'left:0;transform:translateX(-100%)';r.style.cssText=bs+'right:0;transform:translateX(100%)';
    el.appendChild(l);el.appendChild(r);if(o.parentNode)o.parentNode.removeChild(o);
    RAF(function(){l.style.transform='translateX(0)';r.style.transform='translateX(0)'});
    setTimeout(function(){if(cb)cb();l.style.transform='translateX(-100%)';r.style.transform='translateX(100%)';
      setTimeout(function(){if(l.parentNode)l.parentNode.removeChild(l);if(r.parentNode)r.parentNode.removeChild(r)},dur/2+50)},dur/2)
  } else {if(cb)cb()}
}

// Audio
var Snd = {
  _c:null,_m:null,
  ctx: function(){if(!this._c){this._c=new(W.AudioContext||W.webkitAudioContext)();this._m=this._c.createGain();this._m.gain.value=0.3;this._m.connect(this._c.destination)}if(this._c.state==='suspended')this._c.resume();return this._c},
  blip: function(p){try{var c=this.ctx(),t=c.currentTime,o=c.createOscillator(),g=c.createGain();o.type='sine';o.frequency.setValueAtTime(p||440,t);g.gain.setValueAtTime(0.08,t);g.gain.exponentialRampToValueAtTime(0.001,t+0.06);o.connect(g);g.connect(this._m);o.start(t);o.stop(t+0.06)}catch(e){}},
  sfx: function(ty){try{var c=this.ctx(),t=c.currentTime,o=c.createOscillator(),g=c.createGain();o.connect(g);g.connect(this._m);
    if(ty==='door'){o.type='triangle';o.frequency.setValueAtTime(200,t);o.frequency.linearRampToValueAtTime(80,t+0.2);g.gain.setValueAtTime(0.15,t);g.gain.exponentialRampToValueAtTime(0.001,t+0.25);o.start(t);o.stop(t+0.25)}
    else if(ty==='alert'){o.type='square';o.frequency.setValueAtTime(880,t);o.frequency.setValueAtTime(660,t+0.1);o.frequency.setValueAtTime(880,t+0.2);g.gain.setValueAtTime(0.1,t);g.gain.exponentialRampToValueAtTime(0.001,t+0.3);o.start(t);o.stop(t+0.3)}
    else if(ty==='ambient'){o.type='sine';o.frequency.setValueAtTime(120,t);g.gain.setValueAtTime(0.03,t);g.gain.exponentialRampToValueAtTime(0.001,t+2);o.start(t);o.stop(t+2)}}catch(e){}},
  vol: function(v){if(this._m)this._m.gain.value=M.max(0,M.min(1,v))}
};

function el(tag,css,par){var e=D.createElement(tag);if(css)e.style.cssText=css;if(par)par.appendChild(e);return e}
function btn(text,css,par,fn){var b=el('button',css,par);b.textContent=text;if(fn)b.addEventListener('click',fn);return b}

// ============================================================
// ENGINE
// ============================================================
function NE(container,opts){
  opts=opts||{};var S=this;
  S.C=container;S.id=opts.gameId||'nv_'+M.random().toString(36).slice(2,8);
  S.chars={};S.script=[];S.labels={};S.vars={};
  S.s={pc:0,typing:false,timer:null,txt:'',ci:0,started:false,ended:false,hist:[],chist:[],vis:{},bg:'',auto:false,skip:false};
  S.seen={};S.SPD=opts.typeSpeed||25;S.SK='nv_'+S.id;S.bgs={};S.fx={p:null,crt:false,vig:false};
  S.onEnd=opts.onEnd||null;S.audio=opts.audio!==false;
  for(var k in BG)S.bgs[k]=BG[k];
  S._build();S._bind();S._af=null;S._at=0;
}
var P=NE.prototype;

P._build=function(){
  var S=this,C=S.C;C.style.cssText+='position:relative;overflow:hidden;background:#08080d;';C.innerHTML='';
  S._cv=el('canvas','position:absolute;top:0;left:0;width:100%;height:100%;z-index:0;pointer-events:none;image-rendering:pixelated',C);
  S._cx=S._cv.getContext('2d');
  S._sc=el('div','position:absolute;top:0;left:0;right:0;bottom:0;z-index:1;transition:background 1s ease',C);
  S._ch=el('div','position:absolute;bottom:200px;left:0;right:0;display:flex;justify-content:center;gap:40px;z-index:2;transition:opacity 0.5s ease',C);
  S._cp=el('div','position:absolute;top:16px;left:20px;font-family:monospace;font-size:0.65rem;color:rgba(255,255,255,0.2);z-index:5;letter-spacing:2px;text-transform:uppercase',C);
  S._si=el('div','position:absolute;top:16px;right:60px;font-family:monospace;font-size:0.6rem;color:rgba(0,224,154,0.4);z-index:5;opacity:0;transition:opacity 0.3s',C);S._si.textContent='saved';
  // Menu btn
  S._mb=btn('\u2630','position:absolute;top:12px;right:16px;z-index:60;background:rgba(0,0,0,0.4);border:2px solid rgba(255,255,255,0.15);color:#aaa;padding:4px 8px;cursor:pointer;font-family:monospace;font-size:1rem;border-radius:0',C,function(){if(!S.s.started)return;S._mn.style.display=S._mn.style.display==='flex'?'none':'flex'});
  // Menu overlay
  S._mn=el('div','position:absolute;top:0;left:0;right:0;bottom:0;z-index:55;background:rgba(0,0,0,0.85);display:none;flex-direction:column;align-items:center;justify-content:center;gap:12px',C);
  el('div','font-family:monospace;font-size:1rem;color:#888;margin-bottom:16px;letter-spacing:3px',S._mn).textContent='MENU';
  var mbs='font-family:monospace;font-size:0.8rem;padding:10px 32px;background:transparent;border:2px solid rgba(255,255,255,0.1);color:#aaa;cursor:pointer;border-radius:0;width:220px;text-align:center';
  [['resume','BACK TO GAME'],['save1','SAVE SLOT 1'],['save2','SAVE SLOT 2'],['save3','SAVE SLOT 3'],['load1','LOAD SLOT 1'],['load2','LOAD SLOT 2'],['load3','LOAD SLOT 3'],['history','HISTORY'],['settings','SETTINGS']].forEach(function(b){
    var bt=btn(b[1],mbs,S._mn,function(){S._menu(b[0])});
    bt.addEventListener('mouseenter',function(){bt.style.borderColor='rgba(255,255,255,0.3)';bt.style.color='#fff'});
    bt.addEventListener('mouseleave',function(){bt.style.borderColor='rgba(255,255,255,0.1)';bt.style.color='#aaa'})
  });
  // History overlay
  S._ho=el('div','position:absolute;top:0;left:0;right:0;bottom:0;z-index:56;background:rgba(0,0,0,0.92);display:none;flex-direction:column;overflow-y:auto;padding:40px 24px 24px',C);
  btn('CLOSE','position:sticky;top:0;align-self:flex-end;font-family:monospace;font-size:0.75rem;padding:6px 16px;background:rgba(0,0,0,0.8);border:2px solid rgba(255,255,255,0.15);color:#aaa;cursor:pointer;border-radius:0;margin-bottom:16px;z-index:1',S._ho,function(){S._ho.style.display='none'});
  S._hc=el('div','',S._ho);
  // Settings overlay
  S._so=el('div','position:absolute;top:0;left:0;right:0;bottom:0;z-index:56;background:rgba(0,0,0,0.92);display:none;flex-direction:column;align-items:center;justify-content:center;gap:16px',C);
  el('div','font-family:monospace;font-size:0.9rem;color:#888;letter-spacing:2px;margin-bottom:8px',S._so).textContent='SETTINGS';
  // Speed
  var sr=el('div','display:flex;align-items:center;gap:12px',S._so);
  el('span','font-family:monospace;font-size:0.75rem;color:#888;width:100px',sr).textContent='TEXT SPEED';
  var ss=el('input','width:150px;accent-color:#00ffaa',sr);ss.type='range';ss.min='5';ss.max='60';ss.value=String(S.SPD);
  ss.addEventListener('input',function(){S.SPD=65-parseInt(ss.value)});
  // Auto
  var ar=el('div','display:flex;align-items:center;gap:12px',S._so);
  el('span','font-family:monospace;font-size:0.75rem;color:#888;width:100px',ar).textContent='AUTO ADVANCE';
  S._ab=btn('OFF','font-family:monospace;font-size:0.75rem;padding:4px 16px;background:transparent;border:2px solid rgba(255,255,255,0.15);color:#888;cursor:pointer;border-radius:0',ar,function(){
    S.s.auto=!S.s.auto;S._ab.textContent=S.s.auto?'ON':'OFF';S._ab.style.color=S.s.auto?'#00ffaa':'#888'});
  // Volume
  var vr=el('div','display:flex;align-items:center;gap:12px',S._so);
  el('span','font-family:monospace;font-size:0.75rem;color:#888;width:100px',vr).textContent='VOLUME';
  var vs=el('input','width:150px;accent-color:#00ffaa',vr);vs.type='range';vs.min='0';vs.max='100';vs.value='30';
  vs.addEventListener('input',function(){Snd.vol(parseInt(vs.value)/100)});
  btn('CLOSE','font-family:monospace;font-size:0.75rem;padding:8px 24px;background:transparent;border:2px solid rgba(255,255,255,0.15);color:#aaa;cursor:pointer;border-radius:0;margin-top:16px',S._so,function(){S._so.style.display='none'});
  // Choices
  S._cl=el('div','position:absolute;bottom:200px;left:50%;transform:translateX(-50%);z-index:20;display:flex;flex-direction:column;gap:8px;width:90%;max-width:480px',C);
  // Dialogue
  S._dl=el('div','position:absolute;bottom:0;left:0;right:0;background:linear-gradient(to top,rgba(8,8,13,0.98) 70%,rgba(8,8,13,0.85));backdrop-filter:blur(8px);padding:24px 32px 28px;z-index:10;min-height:180px;cursor:pointer;border-top:2px solid rgba(255,255,255,0.06);display:none;-webkit-tap-highlight-color:transparent;touch-action:manipulation;border-radius:0',C);
  S._dl.tabIndex=0;
  var inn=el('div','display:flex;gap:14px;align-items:flex-start',S._dl);
  S._sp=el('img','width:64px;height:64px;border:2px solid rgba(255,255,255,0.1);object-fit:cover;flex-shrink:0;display:none;border-radius:0;image-rendering:pixelated',inn);
  var cnt=el('div','flex:1;min-width:0',inn);
  S._sn=el('div','font-family:monospace;font-size:0.8rem;font-weight:600;margin-bottom:8px;letter-spacing:1px',cnt);
  S._tx=el('div','font-family:monospace;font-size:0.95rem;line-height:1.8;color:#c8c8d0;min-height:3.6em',cnt);
  S._ad=el('div','position:absolute;bottom:8px;right:16px;font-family:monospace;font-size:0.65rem;color:rgba(255,255,255,0.25)',S._dl);
  // Skip/Auto btns
  var db=el('div','position:absolute;bottom:8px;left:16px;display:flex;gap:8px',S._dl);
  var sbs='font-family:monospace;font-size:0.6rem;padding:2px 8px;background:transparent;border:1px solid rgba(255,255,255,0.1);color:rgba(255,255,255,0.25);cursor:pointer;border-radius:0';
  S._skb=btn('SKIP',sbs,db,function(e){e.stopPropagation();S.s.skip=!S.s.skip;S._skb.style.color=S.s.skip?'#00ffaa':'rgba(255,255,255,0.25)';if(S.s.skip&&!S.s.typing)S._adv()});
  S._aab=btn('AUTO',sbs,db,function(e){e.stopPropagation();S.s.auto=!S.s.auto;S._aab.style.color=S.s.auto?'#00ffaa':'rgba(255,255,255,0.25)'});
  // Title
  S._tl=el('div','position:absolute;top:0;left:0;right:0;bottom:0;display:flex;flex-direction:column;align-items:center;justify-content:center;z-index:50;background:radial-gradient(ellipse at center,#0d0d18 0%,#08080d 70%);transition:opacity 1s ease',C);
};

P._bind=function(){
  var S=this;
  S._dl.addEventListener('click',function(){S._adv()});
  D.addEventListener('keydown',function(e){
    if(!S.s.started||S._mn.style.display==='flex'||S._ho.style.display==='flex'||S._so.style.display==='flex')return;
    if(e.key===' '||e.key==='Enter'){e.preventDefault();if(S._cl.children.length>0)return;S._adv()}
  });
};

P._menu=function(id){
  this._mn.style.display='none';
  if(id==='resume')return;
  if(id[0]==='s'&&id[1]==='a'){this._saveSlot(parseInt(id[4]))}
  else if(id[0]==='l'){this._loadSlot(parseInt(id[4]))}
  else if(id==='history')this._showHist();
  else if(id==='settings')this._so.style.display='flex';
};

// Characters
P.defineCharacter=function(id,o){this.chars[id]={name:o.name||id,color:o.color||'#fff',textColor:o.textColor||'#c8c8d0',portrait:o.portrait||null,sprite:o.sprite||'',blip:o.blipPitch||300+id.charCodeAt(0)*3,role:o.role||''}};
P.defineBackground=function(n,fn){this.bgs[n]=fn};

// Script
P.loadScript=function(sc){this.script=sc;this.labels={};for(var i=0;i<sc.length;i++)if(sc[i].type==='label')this.labels[sc[i].name]=i};
P.setTitle=function(t,st){this._gt=t;this._gs=st};

P.start=function(){
  var S=this,h='<h1 style="font-family:monospace;font-size:3rem;font-weight:600;letter-spacing:0.3em;color:#e8e8ef;margin:0 0 8px;border:none;padding:0">'+(S._gt||'VISUAL NOVEL')+'</h1>';
  if(S._gs)h+='<div style="font-family:monospace;font-size:0.9rem;color:#6a6a78;margin-bottom:48px;letter-spacing:0.1em">'+S._gs+'</div>';
  else h+='<div style="margin-bottom:48px"></div>';
  h+='<button id="ne-s" style="font-family:monospace;font-size:0.85rem;padding:12px 40px;background:transparent;border:2px solid rgba(255,255,255,0.15);color:#c8c8d0;cursor:pointer;letter-spacing:2px;margin-bottom:12px;border-radius:0">BEGIN</button>';
  if(S._hasSave())h+='<button id="ne-c" style="font-family:monospace;font-size:0.75rem;padding:8px 24px;background:transparent;border:2px solid rgba(255,255,255,0.08);color:#6a6a78;cursor:pointer;border-radius:0">CONTINUE</button>';
  S._tl.innerHTML=h;
  S._tl.querySelector('#ne-s').addEventListener('click',function(){
    S.s.started=true;S._tl.style.opacity='0';S._tl.style.pointerEvents='none';
    S.vars={};S.s.chist=[];S.s.hist=[];S.seen={};
    setTimeout(function(){S._tl.style.display='none';S._exec(0)},500)});
  var cb=S._tl.querySelector('#ne-c');
  if(cb)cb.addEventListener('click',function(){
    var sv=S._loadAuto();if(!sv)return;
    S.s.started=true;S.vars=sv.vars||{};S.s.chist=sv.chist||[];S.s.hist=sv.hist||[];S.seen=sv.seen||{};
    S._tl.style.opacity='0';S._tl.style.pointerEvents='none';
    setTimeout(function(){S._tl.style.display='none';S._restore(sv)},500)});
};

// Execution
P._exec=function(pc){
  if(pc<0||pc>=this.script.length){this._end();return}
  this.s.pc=pc;var cmd=this.script[pc],S=this;
  if(!cmd){this._end();return}
  switch(cmd.type){
    case'label':S._exec(pc+1);break;
    case'scene':
      S._autoSave();var bg=cmd.bg||'black';
      if(cmd.chapter)S._cp.textContent=cmd.chapter;
      S.fx.p=cmd.particles||null;S.fx.crt=!!cmd.crt;S.fx.vig=!!cmd.vignette;
      if(cmd.transition){transition(S.C,cmd.transition,cmd.duration||600,function(){S._setBg(bg)});
        setTimeout(function(){S._exec(pc+1)},(cmd.duration||600)+50)}
      else{S._setBg(bg);S._exec(pc+1)}break;
    case'chapter':S._cp.textContent=cmd.text||'';S._exec(pc+1);break;
    case'show':S._showCh(cmd.char,cmd.position||'center');S._exec(pc+1);break;
    case'hide':S._hideCh(cmd.char);S._exec(pc+1);break;
    case'hideall':S._ch.innerHTML='';S.s.vis={};S._exec(pc+1);break;
    case'say':S._dlg(cmd.char,cmd.text,false,false);break;
    case'narrate':S._dlg(null,cmd.text,false,false);break;
    case'think':S._dlg(cmd.char,cmd.text,true,false);break;
    case'shout':S._dlg(cmd.char,cmd.text,false,true);break;
    case'choice':S._choices(cmd.prompt||null,cmd.choices);break;
    case'set':S.vars[cmd.var]=cmd.value;S._exec(pc+1);break;
    case'add':S.vars[cmd.var]=(S.vars[cmd.var]||0)+(cmd.value||1);S._exec(pc+1);break;
    case'jump':var t=S.labels[cmd.to];S._exec(t!==undefined?t:pc+1);break;
    case'if':
      if(S._cond(cmd.condition||cmd)){var jt=S.labels[cmd.then];S._exec(jt!==undefined?jt:pc+1)}
      else{if(cmd.else){var je=S.labels[cmd.else];S._exec(je!==undefined?je:pc+1)}else S._exec(pc+1)}break;
    case'sfx':if(S.audio)Snd.sfx(cmd.sound);S._exec(pc+1);break;
    case'effect':
      if(cmd.effect==='shake')FX.shake(S.C,cmd.intensity,cmd.duration);
      else if(cmd.effect==='flash')FX.flash(S.C,cmd.color,cmd.duration);
      S._exec(pc+1);break;
    case'wait':setTimeout(function(){S._exec(pc+1)},cmd.duration||1000);break;
    case'end':S._end();break;
    default:S._exec(pc+1);break;
  }
};

P._cond=function(c){if(!c)return false;var v=this.vars[c.var];if(v===undefined)v=0;var val=c.val;
  switch(c.op){case'==':case'===':return v==val;case'!=':case'!==':return v!=val;case'>':return v>val;case'<':return v<val;case'>=':return v>=val;case'<=':return v<=val;case'is':return!!v;case'not':return!v;default:return!!v}};

// Background
P._setBg=function(k){this.s.bg=k;var S=this;if(S._af)CAF(S._af);S._at=performance.now();
  var fn=S.bgs[k]||BG['black'];
  (function f(){var cv=S._cv,cx=S._cx;if(!cv)return;var r=cv.parentElement.getBoundingClientRect();
    if(cv.width!==r.width||cv.height!==r.height){cv.width=r.width;cv.height=r.height}
    var t=(performance.now()-S._at)/1000,w=cv.width,h=cv.height;
    fn(cx,w,h,t);if(S.fx.p)FX.particles(cx,w,h,t,S.fx.p);if(S.fx.crt)FX.crt(cx,w,h);if(S.fx.vig)FX.vignette(cx,w,h);
    S._af=RAF(f)})()};

// Characters
P._showCh=function(id,pos){
  var ch=this.chars[id];if(!ch)return;this._hideCh(id);
  var e=el('div','text-align:center;transition:transform 0.5s steps(8),opacity 0.5s steps(8),filter 0.5s ease;filter:brightness(0.5);opacity:0');
  e.setAttribute('data-char',id);
  if(ch.portrait){var img=el('img','width:100px;height:100px;border:2px solid '+ch.color+';object-fit:cover;border-radius:0;image-rendering:pixelated',e);img.src=ch.portrait;img.alt=ch.name}
  else if(ch.sprite){el('div','font-family:monospace;font-size:4rem;line-height:1;user-select:none;color:'+ch.color,e).textContent=ch.sprite}
  el('div','font-family:monospace;font-size:0.65rem;margin-top:4px;opacity:0.6;letter-spacing:1px;text-transform:uppercase;color:'+ch.color,e).textContent=ch.name;
  this.s.vis[id]=pos;this._ch.appendChild(e);RAF(function(){e.style.opacity='1'})};

P._hideCh=function(id){delete this.s.vis[id];var e=this._ch.querySelector('[data-char="'+id+'"]');
  if(e){e.style.opacity='0';setTimeout(function(){if(e.parentNode)e.parentNode.removeChild(e)},500)}};

P._hiSpeaker=function(id){var els=this._ch.querySelectorAll('[data-char]');
  for(var i=0;i<els.length;i++){var e=els[i];if(e.getAttribute('data-char')===id){e.style.filter='brightness(1)';e.style.transform='scale(1.05)'}else{e.style.filter='brightness(0.5)';e.style.transform='scale(1)'}}};

// Dialogue
P._dlg=function(cid,text,thought,shout){
  var ch=cid?this.chars[cid]:null,S=this;
  S._dl.style.display='block';S._cl.innerHTML='';
  if(ch&&ch.name){S._sn.textContent=ch.name;S._sn.style.color=ch.color}else S._sn.textContent='';
  if(ch&&ch.portrait){S._sp.src=ch.portrait;S._sp.alt=ch.name;S._sp.style.display='block';S._sp.style.borderColor=ch.color}else S._sp.style.display='none';
  if(cid)S._hiSpeaker(cid);
  S._tx.style.fontSize=shout?'1.2rem':'0.95rem';S._tx.style.fontWeight=shout?'700':'400';
  S._tx.style.fontStyle=thought?'italic':'normal';S._tx.style.color=thought?'rgba(200,200,210,0.7)':(ch&&ch.textColor)||'#c8c8d0';
  if(shout)FX.shake(S.C,4,300);
  S.s.hist.push({char:cid,name:ch?ch.name:'',color:ch?ch.color:'#888',text:text,thought:thought});
  var tk=S.s.pc+':'+text.substring(0,20),seen=!!S.seen[tk];S.seen[tk]=true;
  S._type(text,ch,seen&&S.s.skip)};

P._type=function(text,ch,inst){
  var S=this;S.s.typing=true;S.s.ci=0;S.s.txt=text;S._tx.textContent='';S._ad.textContent='';
  if(S.s.timer)clearInterval(S.s.timer);
  if(inst){S._tx.textContent=text;S.s.typing=false;S._ad.textContent='click to continue';setTimeout(function(){S._adv()},50);return}
  var bc=0;S.s.timer=setInterval(function(){
    if(S.s.ci<text.length){S.s.ci++;S._tx.textContent=text.substring(0,S.s.ci);
      if(S.audio&&bc%3===0&&ch)Snd.blip(ch.blip||440);bc++}
    else{clearInterval(S.s.timer);S.s.timer=null;S.s.typing=false;S._ad.textContent='click to continue';
      if(S.s.auto)setTimeout(function(){if(S.s.auto&&!S.s.typing)S._adv()},1500)}
  },S.SPD)};

P._skipType=function(){if(this.s.typing){if(this.s.timer)clearInterval(this.s.timer);this.s.timer=null;this._tx.textContent=this.s.txt;this.s.typing=false;this.s.ci=this.s.txt.length;this._ad.textContent='click to continue'}};
P._adv=function(){if(this.s.ended){this._restart();return}if(this.s.typing){this._skipType();return}this._exec(this.s.pc+1)};

// Choices
P._choices=function(prompt,choices){
  var S=this;S._dl.style.display='none';S._cl.innerHTML='';
  if(prompt){var p=el('div','font-family:monospace;font-size:0.8rem;color:rgba(255,255,255,0.4);text-align:center;margin-bottom:8px;letter-spacing:1px',S._cl);p.textContent=prompt}
  var fc=[];for(var i=0;i<choices.length;i++){var c=choices[i];if(c.condition&&!S._cond(c.condition))continue;fc.push(c)}
  fc.forEach(function(c,idx){
    var b=btn(c.text,'font-family:monospace;font-size:0.9rem;padding:14px 20px;background:rgba(20,20,30,0.9);border:2px solid rgba(255,255,255,0.1);color:#c8c8d0;cursor:pointer;text-align:left;backdrop-filter:blur(4px);min-height:48px;border-radius:0;transition:border-color 0.2s,color 0.2s,transform 0.2s',S._cl,function(){
      S.s.chist.push({pc:S.s.pc,ci:idx,text:c.text});S._cl.innerHTML='';
      if(c.set)for(var k in c.set)S.vars[k]=c.set[k];
      S._autoSave();
      if(c.next){var t=S.labels[c.next];S._exec(t!==undefined?t:S.s.pc+1)}else S._exec(S.s.pc+1)});
    b.addEventListener('mouseenter',function(){b.style.borderColor='rgba(255,255,255,0.25)';b.style.color='#fff';b.style.transform='translateX(4px)'});
    b.addEventListener('mouseleave',function(){b.style.borderColor='rgba(255,255,255,0.1)';b.style.color='#c8c8d0';b.style.transform='translateX(0)'})
  })};

// Variable API
P.setVar=function(n,v){this.vars[n]=v};
P.getVar=function(n){return this.vars[n]};
P.ifVar=function(n,op,val,tl,el){if(this._cond({var:n,op:op,val:val})){if(tl){var t=this.labels[tl];if(t!==undefined)this._exec(t)}}else{if(el){var e=this.labels[el];if(e!==undefined)this._exec(e)}}};

// History
P._showHist=function(){
  this._hc.innerHTML='';var h=this.s.hist;
  for(var i=0;i<h.length;i++){var l=el('div','margin-bottom:12px;font-family:monospace;font-size:0.85rem;line-height:1.6',this._hc);
    if(h[i].name){var ns=el('span','font-weight:600;letter-spacing:1px;color:'+h[i].color,l);ns.textContent=h[i].name+'  '}
    var ts=el('span','color:#c8c8d0;'+(h[i].thought?'font-style:italic;opacity:0.7':''),l);ts.textContent=h[i].text}
  this._ho.style.display='flex';this._ho.scrollTop=this._ho.scrollHeight};

// Save/Load
P._sdata=function(){return{pc:this.s.pc,vars:JSON.parse(JSON.stringify(this.vars)),chist:this.s.chist.slice(),hist:this.s.hist.slice(-100),seen:this.seen,vis:JSON.parse(JSON.stringify(this.s.vis)),bg:this.s.bg,ch:this._cp.textContent,ts:Date.now()}};
P._autoSave=function(){try{localStorage.setItem(this.SK+'_a',JSON.stringify(this._sdata()))}catch(e){}this._si.style.opacity='1';var S=this;setTimeout(function(){S._si.style.opacity='0'},1500)};
P._saveSlot=function(n){try{localStorage.setItem(this.SK+'_'+n,JSON.stringify(this._sdata()))}catch(e){}this._si.style.opacity='1';this._si.textContent='saved slot '+n;var S=this;setTimeout(function(){S._si.style.opacity='0';S._si.textContent='saved'},1500)};
P._loadSlot=function(n){try{var d=JSON.parse(localStorage.getItem(this.SK+'_'+n));if(d&&d.pc!==undefined)this._restore(d)}catch(e){}};
P._loadAuto=function(){try{return JSON.parse(localStorage.getItem(this.SK+'_a'))}catch(e){}return null};
P._hasSave=function(){try{return!!localStorage.getItem(this.SK+'_a')}catch(e){}return false};
P._restore=function(d){
  this.vars=d.vars||{};this.s.chist=d.chist||[];this.s.hist=d.hist||[];this.seen=d.seen||{};
  this.s.vis={};this._ch.innerHTML='';
  if(d.bg)this._setBg(d.bg);if(d.ch)this._cp.textContent=d.ch;
  if(d.vis)for(var id in d.vis)this._showCh(id,d.vis[id]);
  this.s.started=true;this.s.ended=false;this._tl.style.display='none';this._tl.style.opacity='0';this._tl.style.pointerEvents='none';
  this._exec(d.pc)};

// End/Restart
P._end=function(){this.s.ended=true;this._ad.textContent='click to restart';this._autoSave();if(this.onEnd)this.onEnd()};
P._restart=function(){
  var S=this;S.s.ended=false;S.s.started=false;S.s.hist=[];S.s.chist=[];S.s.vis={};S.vars={};S.seen={};
  if(S.s.timer)clearInterval(S.s.timer);S._dl.style.display='none';S._ch.innerHTML='';S._cl.innerHTML='';S._cp.textContent='';
  S._tl.style.display='flex';S._tl.style.opacity='1';S._tl.style.pointerEvents='auto';
  try{localStorage.removeItem(S.SK+'_a')}catch(e){}S.start()};

W.NovelEngine=NE;NE.BACKGROUNDS=BG;NE.FX=FX;NE.Audio=Snd;
})(window);
