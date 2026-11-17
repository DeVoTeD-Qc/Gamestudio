// DeadDraw dd-ios-save: crash-reload test for the mid-run save in a cross-origin iframe (how itch.io and
// claude.ai embed the game). Serves a packaged web build (package_artifact_build.sh output) on
// http://127.0.0.1:B and a parent page on http://localhost:A that embeds it in an <iframe>; plays a few
// moves, crashes the tab's renderer right after the last move (Chromium: CDP Page.crash; WebKit: kill -9
// of the WebKitWebProcess), reloads, and checks that the title offers CONTINUE RUN with the same state.
// Usage: NODE_PATH=$(npm root -g) node crash_reload_web.js <chromium|webkit> <build-dir> [--top] [--delay=ms] [--rounds=n]
// Exit code 0 = PASS, 1 = a run was lost or resumed differently, 2 = harness error.
const pw=require('playwright');const http=require('http');const fs=require('fs');const path=require('path');const {execSync}=require('child_process');
const [ENG,DIR]=process.argv.slice(2);const TOP=process.argv.includes('--top');
const arg=(k,d)=>{const a=process.argv.find(x=>x.startsWith('--'+k+'='));return a?+a.split('=')[1]:d};const DELAY=arg('delay',0),ROUNDS=arg('rounds',2);
const mime={'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm','.png':'image/png'};
const serve=(dir,host)=>new Promise(r=>{const s=http.createServer((q,res)=>{let f=path.join(dir,decodeURIComponent(q.url.split('?')[0]));if(f.endsWith('/'))f+='index.html';fs.readFile(f,(e,d)=>{if(e){res.writeHead(404);res.end();return}res.writeHead(200,{'Content-Type':mime[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'});res.end(d)})});s.listen(0,host,()=>r(s))});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{const gs=await serve(path.resolve(DIR),'127.0.0.1');const gbase=`http://127.0.0.1:${gs.address().port}/`;let url=gbase+'index.html';
 if(!TOP){const ps=await new Promise(r=>{const s=http.createServer((q,res)=>{res.writeHead(200,{'Content-Type':'text/html'});res.end(`<!doctype html><body style="margin:0"><iframe src="${gbase}index.html" style="position:fixed;inset:0;width:100%;height:100%;border:0"></iframe>`)});s.listen(0,'localhost',()=>r(s))});url=`http://localhost:${ps.address().port}/`}
 const b=await pw[ENG].launch();const ctx=await b.newContext({viewport:{width:844,height:390}});let page=await ctx.newPage();const errs=[];const fails=[];
 const hook=p=>{p.on('console',m=>{const t=m.text();if(/IndexedDB|DDRunSave|storage|SCRIPT ERROR|USER ERROR/i.test(t))console.log('  console:',t.slice(0,200));if(m.type()==='error')errs.push(t.slice(0,200))});p.on('crash',()=>console.log('  [page crash event]'))};hook(page);
 const fr=()=>TOP?page.mainFrame():page.frames().find(f=>f.url().startsWith(gbase));
 const st=async()=>{try{return await fr().evaluate(()=>window.ddState||null)}catch(e){return null}};
 const wait=async(pred,what,ms=120000)=>{const t0=Date.now();while(Date.now()-t0<ms){const s=await st();if(s&&pred(s))return s;await sleep(150)}throw new Error('timeout: '+what+' '+JSON.stringify(await st()).slice(0,300))};
 const click=async it=>{await page.mouse.click(it.x+it.w/2,it.y+it.h/2);await sleep(300)};
 const find=(s,f)=>(s.items||[]).find(f);
 // ui-pass-3: explain-once callouts (title, map, street) are dismissed with Got it before the next tap
 const clear=async()=>{for(let k=0;k<8;k++){await sleep(1100);const x=await st();const ok=x&&find(x,i=>i.type==='button'&&i.name==='HintOk');if(!ok)return;await click(ok)}};
 const pick=x=>({hp:x.hp,wave:x.wave,pile:x.pile,points:x.points,street:x.street,stacks:x.stacks,active:x.active,resolved:x.resolved,phase:x.phase});
 const crash=async()=>{
  if(ENG==='chromium'){const cs=await ctx.newCDPSession(page);cs.send('Page.crash').catch(()=>{});await sleep(1500);return 'reload'}
  // webkit: kill the web content process(es) of this browser
  const o=execSync('ps -eo pid,ppid,args',{encoding:'utf8'}).split('\n').map(l=>l.trim().match(/^(\d+)\s+(\d+)\s+(.*)$/)).filter(Boolean);const P={};o.forEach(m=>P[m[1]]={pp:m[2],a:m[3]});
  const mine=pid=>{let x=pid,d=0;while(x&&P[x]&&d<12){if(+x===process.pid)return true;x=P[x].pp;d++}return false};
  const ids=Object.keys(P).filter(p=>mine(p)&&/WebKitWebProcess/.test(P[p].a));console.log('  kill -9 WebKitWebProcess',ids.join(','));ids.forEach(p=>{try{process.kill(+p,'SIGKILL')}catch(e){}});await sleep(1500);return 'reload'};
 await page.goto(url);let s=await wait(x=>x.screen==='TITLE','title');
 for(let round=1;round<=ROUNDS;round++){
  const cont=find(s,i=>i.type==='button'&&/^CONTINUE RUN/.test(i.text));
  if(round===1||cont)await clear();
  if(cont&&round>1){await click(find(await st(),i=>i.type==='button'&&/^CONTINUE RUN/.test(i.text)));s=await wait(x=>x.screen!=='TITLE','resumed')}
  else{await click(find(await st(),i=>i.type==='button'&&i.text.startsWith('Start run')));s=await wait(x=>x.screen==='MAP','map');await clear();
   await click(find(s,i=>i.type==='button'&&i.text.startsWith('Enter')));s=await wait(x=>x.screen==='STREET','street')}
  // play: dismiss banners / hints, attack zombies
  let moves=0;for(let k=0;k<60&&moves<4+round;k++){s=await st();if(s.banner_open){await page.mouse.click(422,4);await sleep(400);continue}
   const ok=find(s,i=>i.type==='button'&&/HintOk/.test(i.name));if(ok){await click(ok);continue}if(s.inspect){await page.mouse.click(422,4);await sleep(300);continue}
   if(s.screen!=='STREET'||s.phase!=='STREET')break;
   const zs=(s.items||[]).filter(i=>i.type==='card'&&i.index>=0&&i.index<100&&i.kind!=='D');if(!zs.length){const rb=find(s,i=>i.type==='button'&&i.name==='Run'&&!i.disabled);if(rb){await click(rb);moves++;continue}break}
   const before=s.resolved;await click(zs[moves%zs.length]);try{await wait(x=>x.resolved!==before||x.phase!=='STREET'||x.hp!==s.hp,'move',4000);moves++}catch(e){}}
  await sleep(1200);s=await st();const before=pick(s);console.log(`round ${round}: ${moves} moves, state`,JSON.stringify(before),'saved',s.saved,'store',JSON.stringify(s.store||null));
  // make one more move and crash right after it (DELAY ms) -> the newest state must survive
  const zs=(s.items||[]).filter(i=>i.type==='card'&&i.index>=0&&i.index<100&&i.kind!=='D');let want=before;
  if(zs.length&&s.phase==='STREET'){const r0=s.resolved;await page.mouse.click(zs[0].x+zs[0].w/2,zs[0].y+zs[0].h/2);const t0=Date.now();
   while(Date.now()-t0<3000){const x=await st();if(x&&(x.resolved!==r0||x.hp!==s.hp)){break}await sleep(20)}
   await sleep(DELAY);const x=await st();want=pick(x);console.log('  last move ->',JSON.stringify(want))}
  await crash();
  try{await page.reload({timeout:60000})}catch(e){console.log('  reload failed ('+e.message.split('\n')[0]+'), new tab in same context');page=await ctx.newPage();hook(page);await page.goto(url)}
  s=await wait(x=>x.screen==='TITLE','title after crash');await sleep(500);s=await st();
  const c2=find(s,i=>i.type==='button'&&/^CONTINUE RUN/.test(i.text));
  if(!c2){fails.push(`round ${round}: NO CONTINUE after crash-reload`);console.log('  FAIL no Continue; title buttons:',(s.items||[]).filter(i=>i.type==='button').map(i=>i.text).join(' | '));
   s=await st();continue}
  await clear();await click(find(await st(),i=>i.type==='button'&&/^CONTINUE RUN/.test(i.text)));s=await wait(x=>x.screen==='STREET'||x.screen==='MAP'||x.screen==='SAFEHOUSE','resumed');await sleep(800);s=await st();
  const got=pick(s);const same=JSON.stringify(got)===JSON.stringify(want);console.log(`  resumed ${same?'SAME':'DIFFERENT'}:`,JSON.stringify(got));
  if(!same)fails.push(`round ${round}: resumed state differs: want ${JSON.stringify(want)} got ${JSON.stringify(got)}`);
  // back to the title for the next round: reload normally
  await page.reload();s=await wait(x=>x.screen==='TITLE','title');}
 console.log('console errors:',errs.length,JSON.stringify(errs.slice(0,5)));console.log(fails.length?'RESULT FAIL\n'+fails.join('\n'):'RESULT PASS');await b.close();process.exit(fails.length?1:0)})().catch(e=>{console.log('RESULT ERROR',e.message);process.exit(2)});
