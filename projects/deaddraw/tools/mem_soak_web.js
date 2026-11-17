// DeadDraw dd-ios-mem: long-session memory soak of a packaged web build (package_artifact_build.sh output).
// Random taps on enabled buttons / cards (no Abandon / Settings); every 15 s logs process RSS in MB
// (Chromium renderer + GPU process, or WebKit web + network process) of this browser only, the wasm heap,
// and the game's own numbers from window.ddState.mem (texture MB, objects). window.ddMemDebug = true also
// makes the game list its loaded art and font glyph caches (logged as ntex / fontMB).
// Usage: NODE_PATH=$(npm root -g) node mem_soak_web.js <chromium|webkit> <build-dir> <minutes> <out-prefix>
//          [--iframe] [--codex] [--portrait] [--dpr=3] [--tour]   (writes <out-prefix>.json and .png)
const pw=require('playwright');const http=require('http');const fs=require('fs');const path=require('path');const {execSync}=require('child_process');
const [ENG,DIR,MIN,OUT]=process.argv.slice(2);const IFR=process.argv.includes('--iframe');const CODEX=process.argv.includes('--codex');
const PORTRAIT=process.argv.includes('--portrait');
const mime={'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
function serve(dir,host){return new Promise(r=>{const s=http.createServer((q,res)=>{let f=path.join(dir,decodeURIComponent(q.url.split('?')[0]));if(f.endsWith('/'))f+='index.html';
 fs.readFile(f,(e,d)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':mime[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'});res.end(d)})});s.listen(0,host,()=>r(s))})}
function parentServer(gameUrl){return new Promise(r=>{const s=http.createServer((q,res)=>{res.writeHead(200,{'Content-Type':'text/html'});res.end(`<!doctype html><html><body style="margin:0;background:#000"><iframe id=g src="${gameUrl}" style="position:fixed;left:0;top:0;width:100%;height:100%;border:0" allow="autoplay; fullscreen"></iframe></body></html>`)});s.listen(0,'localhost',()=>r(s))})}
function rss(){try{const o=execSync("ps -eo pid,ppid,rss,args",{encoding:'utf8'}).split('\n');const P={};for(const l of o){const m=l.trim().match(/^(\d+)\s+(\d+)\s+(\d+)\s+(.*)$/);if(m)P[m[1]]={pp:m[2],rss:+m[3],a:m[4]}}
 const mine=pid=>{let x=pid,d=0;while(x&&P[x]&&d<12){if(+x===process.pid)return true;x=P[x].pp;d++}return false};let r=0,g=0,w=0,n=0;
 for(const pid in P){if(!mine(pid))continue;const k=P[pid].rss/1024,a=P[pid].a;
 if(/type=renderer/.test(a)&&/chrom/i.test(a))r+=k;else if(/type=gpu-process/.test(a))g+=k;else if(/WebKitWebProcess/.test(a))w+=k;else if(/WebKitNetworkProcess|WebKitGPUProcess/.test(a))n+=k}
 return ENG==='webkit'?{web:Math.round(w),net:Math.round(n)}:{renderer:Math.round(r),gpu:Math.round(g)}}catch(e){return{}}}
(async()=>{const gs=await serve(path.resolve(DIR),'127.0.0.1');const gameUrl=`http://127.0.0.1:${gs.address().port}/index.html`;let url=gameUrl;
 if(IFR){const ps=await parentServer(gameUrl);url=`http://localhost:${ps.address().port}/`}
 const b=await pw[ENG].launch();const vp=PORTRAIT?{width:390,height:844}:{width:844,height:390};
 const DPR=+((process.argv.find(x=>x.startsWith('--dpr='))||'--dpr=3').split('=')[1]);const ctx=await b.newContext({viewport:vp,deviceScaleFactor:DPR,hasTouch:true});
 await ctx.addInitScript(()=>{window.ddMemDebug=true;const keep=i=>{try{const m=(i.instance||i).exports.memory;if(m)window.__wasmMem=m}catch(e){}return i};
  const a=WebAssembly.instantiate,s=WebAssembly.instantiateStreaming;WebAssembly.instantiate=function(){return a.apply(this,arguments).then(keep)};
  if(s)WebAssembly.instantiateStreaming=function(){return s.apply(this,arguments).then(keep)}});
 const p=await ctx.newPage();const errs=[];p.on('console',m=>{const t=m.text();if(m.type()==='error'||/SCRIPT ERROR|^ERROR|USER ERROR/.test(t))errs.push(t.slice(0,200))});
 p.on('pageerror',e=>errs.push('pageerror '+e.message));p.on('crash',()=>console.log('PAGE CRASHED'));
 await p.goto(url);const fr=()=>IFR?p.frames().find(f=>f.url().startsWith(gameUrl.replace('index.html',''))):p.mainFrame();
 const t00=Date.now();while(Date.now()-t00<240000){const f=fr();if(f){try{if(await f.evaluate(()=>!!(window.ddState&&window.ddState.screen)))break}catch(e){}}await p.waitForTimeout(500)}
 const t0=Date.now();let taps=0,lastLog=-1e9,screens={},peak={};const rows=[];
 let rnd=12345;const r=()=>{rnd=(rnd*1103515245+12345)%2147483648;return rnd/2147483648};
 const W=vp.width,H=vp.height;
 const sample=async(st)=>{const f=fr();const wm=await f.evaluate(()=>window.__wasmMem?Math.round(window.__wasmMem.buffer.byteLength/1048576):-1).catch(()=>-2);
  const row=Object.assign({t:Math.round((Date.now()-t0)/1000),taps,screen:st.screen,wasm:wm},rss(),{tex:(st.mem||{}).tex,objs:(st.mem||{}).objects});rows.push(row);if(st.texlist)row.texlist=st.texlist;if(st.fonts){row.fonts=st.fonts;row.fontMB=Math.round(st.fonts.reduce((a,f)=>a+f.bytes,0)/1048576)}
  for(const k of ['renderer','gpu','web','wasm','tex'])if(row[k]!=null)peak[k]=Math.max(peak[k]||0,row[k]);const {texlist,fonts,...rr}=row;console.log(JSON.stringify(rr),'ntex',(texlist||[]).length)};
 if(process.argv.includes('--tour')){const f=fr();const S=()=>f.evaluate(()=>window.ddState);let st=await S();await sample(st);
  const cb=st.items.find(i=>i.name==='CodexButton');await p.mouse.click(cb.x+cb.w/2,cb.y+cb.h/2);await p.waitForTimeout(1500);st=await S();
  const chips=st.items.filter(i=>(i.name||'').startsWith('Type_'));for(const c of chips){await p.mouse.click(c.x+c.w/2,c.y+c.h/2);await p.waitForTimeout(800);
   for(let k=0;k<25;k++){await p.mouse.move(vp.width/2,vp.height/2);await p.mouse.wheel(0,400);await p.waitForTimeout(150)}await p.waitForTimeout(600);st=await S();await sample(st)}
  st=await S();const cl=st.items.find(i=>i.name==='CloseOverlay');await p.mouse.click(cl.x+cl.w/2,cl.y+cl.h/2);await p.waitForTimeout(2500);st=await S();await sample(st);
  fs.writeFileSync(OUT+'.json',JSON.stringify({rows,peak},null,1));console.log('peak',JSON.stringify(peak));await b.close();process.exit(0)}
 while(Date.now()-t0<(+MIN)*60000){const f=fr();let st;try{st=await f.evaluate(()=>window.ddState)}catch(e){console.log('eval fail',e.message);break}
  screens[st.screen]=(screens[st.screen]||0)+1;
  let it=(st.items||[]).filter(i=>!i.disabled&&i.w>4&&i.h>4&&i.x>=0&&i.y>=0&&i.x<W&&i.y<H);
  it=it.filter(i=>!new RegExp('abandon|quit|reset|delete|settings|how to'+(CODEX?'':'|codex'),'i').test((i.text||'')+(i.name||'')));
  const cl=(st.items||[]).find(i=>/^(close|back|done)$/i.test((i.text||'').trim()));if(st.inspect){await p.keyboard.press('Escape');await p.mouse.click(5,5)}else if(st.overlay&&cl&&r()<0.5){await p.mouse.click(cl.x+cl.w/2,cl.y+cl.h/2)}else if(st.banner_open){await p.mouse.click(W/2,H/2)}else if(it.length){const i=it[Math.floor(r()*it.length)];await p.mouse.click(i.x+i.w/2,i.y+i.h/2);taps++}else await p.mouse.click(W/2,H/2);
  await p.waitForTimeout(350);if(Date.now()-lastLog>15000){lastLog=Date.now();await sample(st)}}
 const f=fr();const st=await f.evaluate(()=>window.ddState).catch(()=>({}));await sample(st);
 await p.screenshot({path:OUT+'.png'});fs.writeFileSync(OUT+'.json',JSON.stringify({rows,peak,screens,errs},null,1));
 console.log('peak',JSON.stringify(peak));console.log('screens',JSON.stringify(screens));console.log('errors',errs.length,JSON.stringify(errs.slice(0,8)));await b.close();process.exit(0)})();
