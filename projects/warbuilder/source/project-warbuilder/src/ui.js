(function () {
'use strict';
const app = document.getElementById('app'), layer = document.getElementById('layer');
let G = null;
const ui = { overSeen: false, tab: 'hand', lastPos: null, screen: 'start', me: 0, mode: 'ai', sheet: null, moveMode: false, burnMode: false, busy: false, handoff: false, toast: null, toastT: 0, logMark: 0 };

// Operator rank (O10): saved on this device only. Every storage access is guarded; the page works without it.
const store = () => { try { return window.localStorage; } catch (e) { return null; } };
ui.prof = WD.loadProfile(store());
const today = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; };
ui.ops = (() => { try { const v = JSON.parse((store() && store().getItem('wb-ops-v1')) || '[]'); return Array.isArray(v) ? v.filter(k => WD.OPS[k]) : []; } catch (e) { return []; } })();
const saveOps = () => { try { const st = store(); if (st) st.setItem('wb-ops-v1', JSON.stringify(ui.ops)); } catch (e) { /* storage off: keep it for this visit */ } };
const ic = (n, cls = '') => `<svg class="i ${cls}"><use href="#i-${n}"/></svg>`;
const ME = () => G.players[ui.me], OP = () => G.players[1 - ui.me];
const myTurn = () => G && !G.over && G.turn === ui.me && !ui.busy && !ui.handoff;
const envName = e => WD.ENVS[e.def].name;
const wdef = iid => WD.WEAPONS[G.weapons[iid].def];
const escA = s => String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
const nameMe = () => ui.mode === 'ai' ? 'You' : ME().name;
const HPMAX = () => WD.TUNE.hp;

function hmPips(n) {
  if (!n) return `<span class="hm z" title="0 Hit Markers">${ic('hm0')}</span>`;
  return `<span class="hm" title="${n} Hit Marker${n > 1 ? 's' : ''}">${Array.from({ length: n }, () => ic('hm')).join('')}</span>`;
}
function reqLabel(type, min) {
  if (type === 'any') return `<span class="reqin" title="Boost: fuel it with any card from your hand">BOOST ${ic('hm0')}</span>`;
  return `<span class="reqin" title="Boost: fuel it with a card that has ${min} or more Hit Markers">BOOST ${Array.from({ length: min }, () => ic('hm')).join('')}<b>+</b></span>`;
}
const RES_ICON = { Movement: 'move', Precision: 'prec', Intel: 'intel', Armor: 'def' };
const STAT_ICON = { Recoil: 'rcl', Range: 'rng', Damage: 'dmg' };
const ri = (k, word) => `<span class="ri c-${k}" title="${word}" aria-label="${word}">${ic(k)}</span>`;
const TOK = { ammo: 'free bullet', mag: 'magazine', move: 'Movement', prec: 'Precision', intel: 'Intel', def: 'Armor', rcl: 'Recoil', rng: 'Range', dmg: 'Damage', hm: 'Hit Marker', cyc: 'free cycle' };
function fx(text) {
  if (!text) return '';
  const t = k => `\u0001${k}\u0002`;
  const out = String(text).split(/(?<=\.)\s+/).map(sent => {
    let s = sent; const isGain = /^Gain\b/.test(s);
    s = s.replace(/\bHit Markers?\b/g, t('hm'));
    s = s.replace(/(\+?)(\d+) (more )?free bullets?/g, (m, plus, n) => `+${n}${t('ammo')}`);
    s = s.replace(/(\+?)(\d+) free cycles?/g, (m, plus, n) => `+${n}${t('cyc')}`);
    s = s.replace(/(\+?)(\d+) magazine/g, (m, plus, n) => `+${n}${t('mag')}`);
    s = s.replace(/(\+?)(\d+) (additional |extra )?(Movement|Precision|Intel|Armor)\b/g, (m, plus, n, more, r) => `${plus || isGain || more ? '+' : ''}${n}${t(RES_ICON[r])}`);
    s = s.replace(/\b(Movement|Precision|Intel|Armor)\b/g, (m, r) => t(RES_ICON[r]));
    s = s.replace(/\b(Recoil|Range|Damage)\b/g, (m, r) => t(STAT_ICON[r]));
    if (isGain && /^Gain \+/.test(s)) s = s.replace(/^Gain /, '').replace(/,? and (?=\+)/g, ' ').replace(/, (?=\+)/g, ' ').replace(/\.$/, '');
    return s;
  }).join(' ');
  return out.replace(/\u0001(\w+)\u0002/g, (m, k) => k === 'hm' ? `<span class="ri" title="Hit Marker" aria-label="Hit Marker">${ic('hm')}</span>` : ri(k, TOK[k]));
}
const KW = { Mark: 'Mark: your next shot needs 1 fewer Hit Marker on every step.', Pierce: 'Pierce: your shots ignore cover this turn.', Steady: 'Steady: each of your shots this turn reveals 1 extra card for free.', Buy: '+1 Buy: one more purchase this turn.',
  'held angle': `Hold the Angle: at End turn up to ${WD.TUNE.overwatchCap} unspent Precision is kept. If your rival ends their next turn inside your gun's range, your gun fires once with it (no Recoil, no Mark).` };
function cardTip(def) {
  const all = `${def.text} ${def.squadText || ''}`; const kws = Object.keys(KW).filter(k => all.includes(k)).map(k => KW[k]).join(' ');
  return `${def.name} · ${def.tactic ? 'Squad Tactic · ' : ''}${def.hit_markers} Hit Marker${def.hit_markers === 1 ? '' : 's'}. ${def.text}${def.squad ? ` Squad: ${def.squadText} for each other ${ARCH_SHORT[def.archetype]} card in play this turn (Loadout counts), up to ×${WD.TUNE.squadCap}.` : ''}${def.loadout ? ' Loadout: stays on the table, fires at the start of every turn, counts for Squad.' : ''}${def.reaction ? ` Reaction: in your hand when hit, −${def.reaction} damage.` : ''}${(def.effects || []).some(x => x.op === 'scrap') ? ' Scrap: remove a card in your hand, play area or discard pile from the game.' : ''} ${kws}`; }
const GSHORT = { Pistol: '', SMG: 'SMG', Shotgun: 'Shotgun', 'Assault Rifle': 'AR', LMG: 'LMG', 'Marksman Rifle': 'DMR', Sniper: 'Sniper', 'Burst Rifle': 'Burst', Launcher: 'Launcher', Revolver: '', Melee: '' };
const wnm = d => { if (!d || !d.cls || !GSHORT[d.cls]) return d ? d.name : ''; const m = d.name.match(/^(.*?)( “.*”)?$/); return `${m[1]} ${GSHORT[d.cls]}${m[2] || ''}`; };
const SQUAD_ART = { assault: 'Breach', recon: 'Mark_Target', support: 'Ammo_Box', engineer: 'Deployable_Cover' }; // Loadout cards: squad art until their own art lands
function artURL(def) { return (typeof ART !== 'undefined' && def && def.name && (ART[def.name.replace(/ /g, '_')] || (def.loadout && ART[SQUAD_ART[def.archetype]]))) || ''; }
function cardHTML(def, o = {}) {
  const cls0 = () => ['tc', 'a-' + def.archetype, def.jam ? 'jam' : '', 'cr' + (def.tier || 0), artURL(def) ? 'has-art' : '', o.cls || ''].join(' ');
  const artSt = (artURL(def) || o.k != null) ? ` style="${artURL(def) ? `--art:url(${artURL(def)});` : ''}${o.k != null ? `--k:${o.k}` : ''}"` : '';
  const sc = (def.effects || []).filter(x => x.op === 'scrap').reduce((a, x) => a + x.n, 0);
  const nb = WD.NEIGHBOURS[def.archetype];
  const live = G && G.players && G.players.length; const inPlay = o.id && live && (ME().play.includes(o.id) || ME().loadout.includes(o.id));
  const others = live && WD.SQUADS.includes(def.archetype) ? WD.squadCounts(G, ui.me)[def.archetype] - (inPlay ? 1 : 0) : 0; const x = Math.min(WD.TUNE.squadCap, Math.max(0, others));
    const comboLine = def.squad ? `<div class="tc-combo ${x ? 'lit' : ''}">${roleB(def.archetype, !!x)} <b class="tc-sq">SQUAD</b> ${fx(def.squadText)}${live ? ` <small class="tc-x">${x ? `×${x}${inPlay ? '' : ' if played'}` : 'no partner yet'}</small>` : ''}</div>`
    : def.loadout ? `<div class="tc-combo lo ${o.id && live && ME().loadout.includes(o.id) ? 'lit' : ''}">${roleB(def.archetype)} <b class="tc-sq">LOADOUT</b> stays on the table · fires every turn</div>` : '';
  const isStation = /^K/.test(def.id);
  const cls = cls0() + (def.squad && x ? (inPlay ? ' sqfired' : ' would') : '');
  const inner = `<div class="tc-top">${nb && !isStation ? roleB(def.archetype) : ''}<span class="tc-name">${def.name}</span>${sc ? `<span class="scrapb" title="Scrap ${sc}">${ic('scrap')}${sc > 1 ? sc : ''}</span>` : ''}${hmPips(def.hit_markers)}</div>
    <div class="tc-main">${fx(def.text)}</div>${comboLine}
    ${def.reaction ? `<div class="tc-boost"><span><span class="req rx">REACTION</span></span><span>In your hand when hit: −${def.reaction} damage</span></div>` : ''}
    <div class="tc-foot"><span class="tagc">${def.archetype === 'starter' ? `${ic('para')} Starter` : /^K/.test(def.id) ? `${ic('para')} Buy Station · ${def.tags[0]}` : `${chev(def.tier)} ${def.tags[0]}`}</span>${def.intel_cost ? `<span class="cost">${ic('intel')}${def.intel_cost}</span>` : '<span></span>'}</div>`;
  if (o.act) return `<button class="${cls}" data-act="${o.act}" data-id="${o.id || ''}" ${o.dis ? 'disabled' : ''} aria-label="${escA(def.name)}" ${o.prev ? `data-prev="${o.prev}"` : `data-tip="${escA(cardTip(def))}"`}${artSt}>${inner}</button>`;
  return `<div class="${cls}" ${o.cls && /big/.test(o.cls) ? '' : `data-tip="${escA(cardTip(def))}"`}${artSt}>${inner}</div>`;
}
function ladderHTML(steps, hl = -1) {
  return `<div class="ladder" data-tip="Damage ladder: count the Hit Markers on the cards you reveal. Reach a step to deal its damage; the highest step you reach counts.">${steps.map(([h, d], i) => `<span class="lstep ${i === hl ? 'on' : ''} ${i === steps.length - 1 && steps.length > 2 ? 'top' : ''}"><span class="lh">${ic('hm')}${h}+</span><b>${d}</b></span>`).join('<span class="lar">›</span>')}</div>`;
}
function statsHTML(iid, def) {
  const e = iid ? WD.eff(G, iid) : null;
  const v = k => e ? e[k] : def[k];
  const m = k => e && e[k] !== def[k] ? ' class="mod"' : '';
  const L = def.ladder; const b = def.band;
  return `<div class="stats s4">
    <div data-tip="Damage: the lowest and highest steps of the damage ladder below."><b${m('damage')}>${L[0][1]}–${L[L.length - 1][1]}</b><span>${ic('dmg')}DMG</span></div>
    <div data-tip="Range: this gun can only fire when the distance to your rival is in this band."><b>${b[0]}–${b[1]}</b><span>${ic('rng')}RANGE</span></div>
    <div data-tip="Shots: how often this gun can fire per turn. Extra shots from cards add to it."><b${m('magazine_capacity')}>${v('magazine_capacity')}</b><span>${ic('mag')}MAG</span></div>
    <div data-tip="Recoil: every shot spends the Precision you commit to it, then this much more."><b${m('recoil')}>${v('recoil')}</b><span>${ic('rcl')}RCL</span></div></div>${ladderHTML(L)}`;
}
function shotPips(gi) {
  const me = ME(); const wid = me.guns[gi]; const cap = WD.eff(G, wid).magazine_capacity; const used = G.weapons[wid].shots;
  return `<div class="ammo" data-tip="Shots left this turn. Refills at the start of your turn.">${Array.from({ length: cap }, (_, i) => `<i class="${i < cap - used ? '' : 'e'}"></i>`).join('')}${me.shot ? `<span class="chip">+${me.shot} extra</span>` : ''}<span class="mono">${cap - used}/${cap} shots</span></div>`;
}
function weaponBody(def, iid) {
  const W = iid ? G.weapons[iid] : null; const att = W && W.att ? WD.ATTS[G.atts[W.att].def] : null;
  return `<div class="w-name">${def.name}<span class="cost"><span class="rar r${def.tier}">${def.rarityName}</span> ${ic('intel')}${def.intel_cost}</span></div>
    <div class="lbl">${def.cls} · ${def.tags[0]}</div>${statsHTML(iid, def)}
    <div class="mods">${def.mods.length ? def.modText.map(m => `<span class="mod">${m}</span>`).join('') : '<span class="mod none">No attachments (Common)</span>'}</div>
    <div class="preview"><span class="lbl">${def.slot === 1 ? 'Secondary slot' : 'Primary slot'}</span><span>Every gun can fire at distance 0 (close quarters: no cover, no Armor).</span></div>
    ${def.note ? `<div class="preview">${def.note}</div>` : ''}
    ${att ? `<div class="preview"><span class="lbl">Attachment</span><b>${att.name}</b> — ${att.text}</div>` : ''}`;
}

/* ---------- screens ---------- */
function render() {
  if (ui.screen === 'start') { app.innerHTML = startHTML(); renderLayer(); return; }
  const me = ME(), op = OP();
  if (!myTurn() || !WD.canBench(G, ui.me)) ui.burnMode = false;
  const lo = app.querySelector('.logbox ol'); const ls = lo ? lo.scrollTop : 0;
  const f0 = app.querySelector('.field'); const fs = f0 ? f0.scrollLeft : 0;
  const snap = flipSnap();
  app.innerHTML = hudHTML(me, op);
  flipPlay(snap);
  const lo2 = app.querySelector('.logbox ol'); if (lo2) lo2.scrollTop = ls;
  const f = app.querySelector('.field');
  if (f && f.scrollWidth > f.clientWidth + 4 && getComputedStyle(f).overflowX !== 'clip') {
    const target = ui.play ? 'rv' + op.pos : 'me' + me.pos;
    const here = f.querySelector(ui.play ? '.env.rival' : '.env.here');
    if (ui.lastPos !== target || ui.moveMode && !ui.wasMove) { if (here) f.scrollLeft = here.offsetLeft - f.clientWidth / 2 + here.offsetWidth / 2; }
    else f.scrollLeft = fs;
    ui.lastPos = target;
  }
  ui.wasMove = ui.moveMode;
  renderLayer();
  postFx();
  if (ui.pendPops && ui.pendPops.length) flushPops();
}


/* ---------- printed card faces (from the print-and-play generator) ---------- */
const FDIM = n => /^(gun_|back_gun)/.test(n) ? [336, 240] : /^(loc_|back_loc)/.test(n) ? [336, 489.6] : [240, 336];
const hasFace = n => typeof FACES !== 'undefined' && !!FACES[n];
function faceSrc(n) {
  const h = (typeof FACES !== 'undefined' && FACES[n]) || '';
  return h.replace(/src="art\/locs\/(\w+)\.jpg"/g, (m, k) => `src="${(typeof LOCART !== 'undefined' && LOCART[k]) || ''}"`).replace(/src="art\/guns\/([\w-]+)\.jpg"/g, (m, k) => `src="${(typeof GUNART !== 'undefined' && GUNART[k]) || ''}"`).replace(/src="art\/([\w-]+)\.jpg"/g, (m, k) => `src="${(typeof ART !== 'undefined' && ART[k]) || ''}"`);
}
const FACEHEAD = typeof FACECSS !== 'undefined' ? `<style>:host{display:block;position:relative}${FACECSS}</style>${FACESPRITE}` : '';
if (typeof customElements !== 'undefined' && !customElements.get('pnp-face')) customElements.define('pnp-face', class extends HTMLElement {
  connectedCallback() {
    const n = this.getAttribute('name'); const [w, h] = FDIM(n); this.style.aspectRatio = `${w} / ${h}`;
    const r = this.shadowRoot || this.attachShadow({ mode: 'open' });
    r.innerHTML = `${FACEHEAD}<div class="fw" style="width:${w}px;height:${h}px">${faceSrc(n)}</div>`;
    const fw = r.querySelector('.fw'); const fit = () => { const z = this.clientWidth / w; if (z > 0) fw.style.zoom = z; };
    fit(); if (!this._ro) this._ro = new ResizeObserver(fit); this._ro.observe(this);
  }
  disconnectedCallback() { if (this._ro) this._ro.disconnect(); }
});
const pf = (n, attrs = '') => `<pnp-face name="${n}" ${attrs}></pnp-face>`;
function locFaceName(e) {
  if (!WD.LOCSET) return '';
  const ph = e.phase || 'start';
  const c = WD.LOCSET.map((L, i) => ({ L, i })).filter(({ L }) => L.def === e.def && (L.ph === ph || (ph === 'start' && L.ph === 'start')));
  const best = c.find(({ L }) => !!L.centre === !!e.hot && (e.gunAt == null || L.gun === e.gunAt)) || c.find(({ L }) => !!L.centre === !!e.hot) || c[0];
  const n = best ? 'loc_L' + String(best.i + 1).padStart(2, '0') : ''; return hasFace(n) ? n : '';
}
function itemFace(it) { const def = WD.itemDef(G, it); const n = it.kind === 'card' ? 'card_' + def.id : it.kind === 'weapon' ? 'gun_' + def.id : ''; return hasFace(n) ? n : ''; }
const CARD_BY_NAME = {}; for (const k in WD.CARDS) CARD_BY_NAME[WD.CARDS[k].name] = k;
function miniFace(name, extra = '') { const id = CARD_BY_NAME[name]; return id && hasFace('card_' + id) ? `<span class="mf ${extra}">${pf('card_' + id)}</span>` : `<span class="mf txt ${extra}"><b>${escA(name)}</b></span>`; }
/* ---------- previews: hover (mouse) / long-press (touch) and the card view sheet ---------- */
function bigGun(def, iid) {
  const e = iid ? WD.eff(G, iid) : def; const L = def.ladder; const gc = def.gcombo; const a = gunArt(def);
  const m = k => iid && e[k] !== def[k] ? ` class="up r${def.tier}"` : '';
  return `<div class="gp big ${def.slot === 1 ? 'sec' : ''}"><div class="gp-band">${L.map(([h, d]) => `<span class="gl"><span class="gh">${ic('hm')}${h}</span><b>${d}</b></span>`).join('')}</div>
    <div class="gp-body"><div class="gp-head"><b class="gp-name">${def.name}</b><span class="rar r${def.tier}">${def.rarityName}</span></div>
    <div class="gp-stats"><span>${ic('rng')}<b${m('band')}>${e.band[0]}–${e.band[1]}</b></span><span>${ic('mag')}<b${m('magazine_capacity')}>${e.magazine_capacity}</b></span><span>${ic('rcl')}<b${m('recoil')}>${e.recoil}</b></span><span class="gp-cost">${ic('intel')}${def.intel_cost}</span></div>
    ${a ? `<div class="gp-art" style="background-image:url(${a})"></div>` : ''}
    <div class="gp-combo off">${def.melee ? 'Melee · distance 0 · always hits' : `Recoil ${e.recoil}: Precision spent per shot on top of the commit`}</div>
    ${def.note ? `<div class="gp-note">${def.note}</div>` : ''}</div></div>`;
}
function perkFace(pi, k) {
  const pl = G.players[pi]; const L = WD.LOADOUT[k];
  return `<div class="pcard big" style="--arch:var(${ARCH_VAR[L.arch] || '--muted'})"><span class="pc-tag">${L.arch === 'any' || !WD.ARCH_TAG[L.arch] ? 'Any build' : WD.ARCH_TAG[L.arch]}${L.trig ? ` · trigger ${perkTrig(L)}` : ' · passive'}</span><b>${L.name}</b><span>${fx(L.text)}</span><span class="pc-own">${pi === ui.me ? 'Your perk' : `${escA(pl.name)}'s perk`}</span></div>`;
}
function previewHTML(spec) {
  const [k, a, b] = spec.split(':');
  try {
    if (k === 'hc') { const d = WD.cardDef(G, a); return hasFace('card_' + d.id) ? `<div class="pv card">${pf('card_' + d.id)}</div>` : cardHTML(d, { cls: 'big' }); }
    if (k === 'cd') return hasFace('card_' + a) ? `<div class="pv card">${pf('card_' + a)}</div>` : cardHTML(WD.CARDS[a], { cls: 'big' });
    if (k === 'gun') { const d = wdef(a); return hasFace('gun_' + d.id) ? `<div class="pv gun">${pf('gun_' + d.id)}</div>` : bigGun(d, a); }
    if (k === 'perk') return hasFace('perk_' + b) ? `<div class="pv card">${pf('perk_' + b)}</div>` : perkFace(+a, b);
    if (k === 'loc') { const e = G.envs.find(x => x.w === +a); const n = e && locFaceName(e); return n ? `<div class="pv loc"><div class="envf">${pf(n)}<div class="zoneov">${stackHTML(e, false, !e.cache.searched ? WD.stackPlan(G, e) : null, true)}</div></div></div>` : ''; }
    if (k === 'it') { const env = G.envs.find(e => e.loot.some(i => i.iid === a)); const it = env && env.loot.find(i => i.iid === a); if (!it) return ''; const def = WD.itemDef(G, it);
      const fn = itemFace(it); if (fn) return `<div class="pv ${it.kind === 'weapon' ? 'gun' : 'card'}">${pf(fn)}</div>`;
      if (it.kind === 'card') return cardHTML(def, { cls: 'big' }); if (it.kind === 'weapon') return bigGun(def, a);
      return `<div class="pcard big" style="--arch:var(--c-ammo)"><span class="pc-tag">Attachment · ${ic('intel')}${def.intel_cost}</span><b>${def.name}</b><span>${fx(def.text || '')}</span></div>`; }
  } catch (err) { return ''; }
  return '';
}
const PV = { el: null, t: 0 };
function showPrev(t) {
  const html = previewHTML(t.dataset.prev); if (!html) return;
  let pop = document.getElementById('prevPop');
  if (!pop) { pop = document.createElement('div'); pop.id = 'prevPop'; pop.className = 'prev-pop'; pop.setAttribute('aria-hidden', 'true'); document.body.appendChild(pop); }
  pop.innerHTML = html; pop.hidden = false;
  const r = t.getBoundingClientRect(); const p = pop.getBoundingClientRect();
  let left = r.right + 12; if (left + p.width > innerWidth - 8) left = r.left - p.width - 12; if (left < 8) left = Math.min(Math.max(8, r.left + r.width / 2 - p.width / 2), innerWidth - p.width - 8);
  let top = r.top + r.height / 2 - p.height / 2; top = Math.min(Math.max(8, top), innerHeight - p.height - 8);
  if (left + p.width > r.left && left < r.right && top < r.bottom && top + p.height > r.top) { top = r.top - p.height - 10; if (top < 8) top = Math.min(r.bottom + 10, innerHeight - p.height - 8); }
  pop.style.left = left + 'px'; pop.style.top = top + 'px'; PV.el = t;
}
function hidePrev() { clearTimeout(PV.t); const pop = document.getElementById('prevPop'); if (pop) pop.hidden = true; PV.el = null; }
document.addEventListener('pointermove', e => {
  if (e.pointerType !== 'mouse') return;
  const t = e.target.closest('[data-prev]');
  if (t === PV.el) return;
  clearTimeout(PV.t);
  if (!t) { hidePrev(); return; }
  if (PV.el) { PV.el = null; showPrev(t); return; }
  PV.t = setTimeout(() => { if (t.isConnected && t.matches(':hover')) showPrev(t); }, 220);
}, true);
document.addEventListener('pointerdown', () => hidePrev(), true);
document.addEventListener('scroll', () => hidePrev(), true);
function cardSheet(S) {
  const me = ME(); const t = myTurn(); const inHand = me.hand.includes(S.id); const def = WD.cardDef(G, S.id);
  const can = t && inHand && !def.jam;
  return `${head(def.name)}<div class="cardview">${cardHTML(def, { cls: 'big' })}
    <div class="cv-side"><p class="cv-tip">${escA(cardTip(def))}</p>
    ${can && def.loadout && me.loadout.length >= WD.TUNE.loadoutSlots ? `<p class="lbl">Your Loadout row is full.</p>${me.loadout.map((i, k) => `<button class="btn sig cv-play" data-act="playlo" data-id="${S.id}:${k}">Replace ${escA(WD.cardDef(G, i).name)}</button>`).join('')}<button class="btn alt" data-act="playlo" data-id="${S.id}:once">Use once (discard after)</button>`
      : can ? `<button class="btn sig cv-play" data-act="playcard" data-id="${S.id}" autofocus>${def.loadout ? 'Deploy' : 'Play'} ${escA(def.name)}</button>` : `<p class="lbl">${!t ? 'Wait for your turn.' : ''}</p>`}
    ${inHand && WD.TUNE.ammo ? '<button class="btn alt" data-act="close">Keep it (bullet)</button>' : ''}</div></div>`;
}
/* ---------- B2 tactical HUD ---------- */
const SCENERY = `<div class="scenery" aria-hidden="true"><svg viewBox="0 0 1600 420" preserveAspectRatio="xMidYMax slice">
  <defs><linearGradient id="skyG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#151a14"/><stop offset=".55" stop-color="#2b2c1f"/><stop offset=".82" stop-color="#5a4626"/><stop offset="1" stop-color="#2a2417"/></linearGradient>
  <radialGradient id="sunG" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#f2b25a" stop-opacity=".55"/><stop offset="1" stop-color="#f2b25a" stop-opacity="0"/></radialGradient>
  <filter id="blurS"><feGaussianBlur stdDeviation="14"/></filter></defs>
  <rect width="1600" height="420" fill="url(#skyG)"/>
  <circle cx="420" cy="300" r="190" fill="url(#sunG)"/>
  <path d="M0 300 L120 262 L230 285 L360 238 L470 270 L600 230 L720 268 L860 242 L1000 276 L1120 236 L1260 270 L1400 246 L1600 282 L1600 420 L0 420Z" fill="#3a3524" opacity=".7"/>
  <g fill="#262618" opacity=".95">
    <path d="M60 330 h40 v-60 h14 v-20 h10 v20 h16 v60 h30 v-90 l8 -10 h22 v100 h36 v-52 h28 v-16 h6 v16 h20 v52 h44 v-120 h12 v-14 h4 v14 h12 v120 h40 v90 H60Z"/>
    <path d="M520 336 h26 v-74 h34 v30 h24 v-56 l12 -8 l12 8 v56 h40 v44 h22 v-96 h36 v18 l10 -10 v88 h50 v84 H520Z"/>
    <path d="M980 334 h30 v-60 h20 v-12 h18 v12 h18 v60 h28 v-110 h8 l2 -30 l2 30 h8 v110 h46 v-48 h40 v48 h40 v86 H980Z"/>
    <path d="M1340 330 h24 v-46 l18 -12 l18 12 v46 h30 v-80 h30 v80 h40 v90 h-160Z"/>
  </g>
  <g stroke="#262618" stroke-width="5" fill="none" opacity=".95"><path d="M830 340 V180 M830 186 H930 M830 210 L900 186 M920 186 V226"/><path d="M1250 340 L1270 170 L1290 340 M1258 260 H1282 M1263 220 H1278"/></g>
  <path d="M0 360 C200 340 320 372 520 356 S880 340 1040 360 S1400 346 1600 362 V420 H0Z" fill="#1a1c13"/>
  <g class="sc-smoke" fill="#8f8a74" filter="url(#blurS)"><ellipse class="sm1" cx="300" cy="250" rx="40" ry="70"/><ellipse class="sm2" cx="1180" cy="240" rx="46" ry="80"/><ellipse class="sm3" cx="690" cy="270" rx="30" ry="56"/></g>
  <g class="sc-heli" fill="#141610"><path d="M0 0 h34 l10 6 h-44 z M8 6 h28 v4 h-28z M44 6 h22 v2 h-22z M4 -4 h60 v1.5 h-60z"/></g>
  <g fill="#f2b25a" opacity=".7"><circle class="sc-fire f1" cx="612" cy="318" r="3"/><circle class="sc-fire f2" cx="1104" cy="322" r="2.5"/><circle class="sc-fire f3" cx="176" cy="320" r="2"/></g>
</svg></div>`;
function rivalZone() {
  if (!ui.play) return '';
  const r = OP(); const FX = ui.fx || {};
  const played = (r.play || []).map(i => { const d = WD.cardDef(G, i); const n = 'card_' + d.id; return `<span class="rz-card ${FX.played === i ? 'fresh' : ''}" data-flip="r${i}">${hasFace(n) ? pf(n) : `<b>${escA(d.name)}</b>`}</span>`; }).join('');
  const sh = FX.shot && !FX.shot.fists ? `<div class="rz-shot ${FX.shot.hit ? 'hit' : 'miss'}">${(FX.shot.revealed || []).map((c, k) => { const id = CARD_BY_NAME[c.name]; return `<span class="rz-rev" style="--i:${k}">${id && hasFace('card_' + id) ? pf('card_' + id) : ''}${c.hm ? `<i>+${c.hm}</i>` : ''}</span>`; }).join('')}<span class="rz-tot"><b>${FX.shot.total}</b>/${FX.shot.req}</span></div>` : '';
  return `<div class="rv-zone" aria-hidden="true"><span class="rz-tag">${escA(r.name)} played</span><div class="rz-row">${played}</div>${sh}</div>`;
}
/* ---------- nothing snaps: FLIP every keyed element, tween numbers and bars ---------- */
const RM = () => matchMedia('(prefers-reduced-motion: reduce)').matches;
function flipSnap() {
  const m = { rect: {}, num: {}, bar: {}, ghost: {} };
  if (!app.querySelector('.hud')) return m;
  app.querySelectorAll('[data-flip]').forEach(el => { const r = el.getBoundingClientRect(); if (r.width) { m.rect[el.dataset.flip] = r; if (/^w/.test(el.dataset.flip)) m.ghost[el.dataset.flip] = el.cloneNode(true); } });
  app.querySelectorAll('[data-num]').forEach(el => { m.num[el.dataset.num] = +el.textContent; });
  app.querySelectorAll('[data-bar] i').forEach(el => { m.bar[el.parentNode.dataset.bar] = el.style.width; });
  return m;
}
function flipPlay(m) {
  if (RM() || !m) return;
  const seen = Object.keys(m.rect).length > 0; const E = 'cubic-bezier(.22,.8,.25,1)'; const moved = new Map();
  app.querySelectorAll('[data-flip]').forEach(el => {
    const k = el.dataset.flip; const o = m.rect[k]; const n = el.getBoundingClientRect(); if (!n.width) return;
    const isCol = /^w/.test(k);
    if (o) {
      let dx = o.left - n.left, dy = o.top - n.top;
      const par = el.parentElement && el.parentElement.closest('[data-flip]'); const pd = par && moved.get(par); if (pd) { dx -= pd[0]; dy -= pd[1]; }
      const sx = o.width / n.width, sy = o.height / n.height; const resized = Math.abs(sx - 1) > .2 || Math.abs(sy - 1) > .2;
      if (isCol && resized) { el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 450, easing: 'ease-out' }); return; }
      if (Math.abs(dx) < 1 && Math.abs(dy) < 1 && Math.abs(sx - 1) < .02 && Math.abs(sy - 1) < .02) return;
      moved.set(el, [o.left - n.left, o.top - n.top]);
      const kf = isCol || resized ? [{ translate: `${dx}px ${dy}px` }, { translate: '0px 0px' }] : [{ translate: `${dx}px ${dy}px`, scale: `${sx} ${sy}`, transformOrigin: '0 0' }, { translate: '0px 0px', scale: '1 1', transformOrigin: '0 0' }];
      el.animate(kf, { duration: isCol ? 650 : k.startsWith('tok') ? 650 : 420, easing: E });
    } else if (seen && !el.closest('.hh-row.deal')) {
      if (isCol) el.animate([{ opacity: 0, translate: '-60px 0px' }, { opacity: 1, translate: '0px 0px' }], { duration: 650, delay: 120, easing: E, fill: 'backwards' });
      else el.animate([{ opacity: 0, scale: '.85' }, { opacity: 1, scale: '1' }], { duration: 360, easing: E });
    }
  });
  // columns that left the board: a ghost drifts right into the gas and fades
  const now = new Set([...app.querySelectorAll('[data-flip]')].map(e => e.dataset.flip));
  for (const k in m.ghost) { if (now.has(k)) continue; const r = m.rect[k]; const g = m.ghost[k];
    Object.assign(g.style, { position: 'fixed', left: r.left + 'px', top: r.top + 'px', width: r.width + 'px', height: r.height + 'px', margin: 0, zIndex: 5, pointerEvents: 'none', maxWidth: 'none', flex: 'none' });
    g.classList.add('ghost-out'); (app.querySelector('.h-map') || document.body).appendChild(g);
    g.animate([{ opacity: 1, translate: '0px 0px', filter: 'none' }, { opacity: 0, translate: '80px 0px', filter: 'blur(4px) sepia(1) hue-rotate(30deg) saturate(3)' }], { duration: 700, easing: 'ease-in' }).onfinish = () => g.remove(); }
  app.querySelectorAll('[data-num]').forEach(el => { const k = el.dataset.num, to = +el.textContent, from = m.num[k]; if (from == null || from === to || isNaN(from)) return;
    const t0 = performance.now(), d = 450; el.textContent = from; const step = t => { const p = Math.min(1, (t - t0) / d); el.textContent = Math.round(from + (to - from) * (1 - Math.pow(1 - p, 3))); if (p < 1 && el.isConnected) requestAnimationFrame(step); }; requestAnimationFrame(step); });
  app.querySelectorAll('[data-bar] i').forEach(el => { const w = m.bar[el.parentNode.dataset.bar]; if (!w || w === el.style.width) return; const to = el.style.width; el.style.transition = 'none'; el.style.width = w; void el.offsetWidth; el.style.transition = ''; el.style.width = to; });
}
const BONUS_IC = { move: ['move', '#2F7FD8', 'Movement'], prec: ['prec', '#C8442B', 'Precision'], intel: ['intel', '#B98A10', 'Intel'], def: ['def', '#5E7A2E', 'Armor'], shot: ['ammo', '#3F8F4A', 'extra shot'], draw: ['loot', '#5B6152', 'card'], scrap: ['scrap', '#C2531A', 'Scrap'], cycle: ['cyc', '#1C7C76', 'free cycle'] };
function bonusChip(d) { const k = Object.keys(d.bonus)[0]; const [icn, col, lab] = BONUS_IC[k] || ['loot', '#5B6152', k]; return `<span class="lp-here" style="--bc:${col}" title="Every turn you are here: +${d.bonus[k]} ${lab}">+${d.bonus[k]}${ic(icn)}</span>`; }
function hudHTML(me, op) {
  ui.arrivedAt = ui.myPosPrev != null && ui.myPosPrev !== me.pos ? me.pos : null; ui.myPosPrev = me.pos;
  const tsKey = G.turnNo + ':' + ui.me; const ts = myTurn() && ui.tsKey !== tsKey; if (ts) ui.tsKey = tsKey;
  if (ts && me.loadout.length) { ui.readyFx = performance.now() + 2200; queuePops([{ kind: 'rdy', head: 'LOADOUT READY', text: fx(me.loadout.map(i => WD.effText(WD.cardDef(G, i).loadout)).join(', ')) }], 700, 'rdy' + tsKey); }
  return `<div class="hud ${myTurn() ? 'myturn' : ''} ${ts ? 'turnstart' : ''}">${hudTop(me, op)}<section class="h-map" aria-label="The circle">${SCENERY}${rivalZone()}<div class="gaswall" aria-hidden="true"><i></i><i></i><i></i></div>${fieldHTML()}<div class="h-tacbar">${tacStrip(me)}</div></section>
    <section class="h-dock" aria-label="Your hand and guns">
      <div class="h-hand">${hudHand(me)}</div>
      ${hudRes(me)}
      <div class="h-guns" aria-label="Your gun and Loadout row">${gunPanel(me, 0)}${loadoutHTML(me)}${engineHTML(me, true)}</div>
      <div class="h-btns">${hudBtns(me)}</div>
    </section></div>`;
}
function hpBar(pl, side) {
  const pct = Math.max(0, pl.hp) / HPMAX() * 100; ui.prevHp = ui.prevHp || {}; const hit = ui.prevHp[side] != null && pl.hp < ui.prevHp[side]; ui.prevHp[side] = pl.hp;
  return `<span data-bar="${side}" class="hb ${side} ${pl.hp <= 9 ? 'low' : ''} ${hit ? 'hit' : ''}" role="img" aria-label="${escA(pl.name)} health ${Math.max(0, pl.hp)} of ${HPMAX()}"><i style="width:${pct}%"></i></span>`;
}
function perkMini(pi) {
  const pl = G.players[pi]; const own = pl.perks || [];
  return own.map(k => { const L = WD.LOADOUT[k]; return `<span class="pdot" style="--arch:var(${ARCH_VAR[L.arch] || '--muted'})" data-act="perkview" data-id="${pi}:${k}" data-prev="perk:${pi}:${k}">${L.arch && SHAPE[L.arch] ? shapeSvg(L.arch) : '★'}<span>${L.name}</span></span>`; }).join('');
}
function hudTop(me, op) {
  const mine = myTurn();
  const who = G.over ? 'Match over' : ui.busy || (ui.mode === 'ai' && G.turn !== ui.me) ? `${G.players[G.turn].name}'s turn` : G.turn === ui.me ? 'Your turn' : `${G.players[G.turn].name}'s turn`;
  const gas = gasChip();
  return `<header class="h-top">
    <span class="turnpill ${mine ? 'mine' : ''}">${who}</span>
    <span class="h-round" data-tip="${escA(`Round ${G.round} of at most ${WD.TUNE.hardEnd}. After round ${WD.TUNE.hardEnd} the match ends: the most Health wins.`)}">R${G.round}<small>/${WD.TUNE.hardEnd}</small></span>${gas}
    <span class="hint">${nextHint()}</span>
    <span class="h-myperks" aria-label="Your perks">${perkMini(ui.me)}</span><span class="h-hp me"><span class="hpface">${OPFACE.me}</span><b>${ui.mode === 'ai' ? 'YOU' : escA(me.name).toUpperCase()} <span data-num="hp-me">${Math.max(0, me.hp)}</span></b>${WD.TUNE.lowHp && me.hp > 0 && me.hp <= WD.TUNE.lowHp ? `<span class="lowhp" title="${WD.TUNE.lowHp} Health or less: draw 1 extra card each turn">+1${ic('loot')}</span>` : ''}${hpBar(me, 'me')}</span>
    ${topDist(me, op)}
    <button class="h-hp them" data-act="sheet" data-id="rival" data-tip="${escA(`${op.name}: ${Math.max(0, op.hp)}/${HPMAX()} Health, ${op.hand.length} cards in hand. Tap for their guns, perks and the combat log.`)}"><span class="hpface">${OPFACE.them}</span>${hpBar(op, 'them')}<b><span data-num="hp-them">${Math.max(0, op.hp)}</span> ${escA(op.name).toUpperCase()}</b><span class="h-rperks">${perkMini(1 - ui.me)}</span><span class="h-more">▸</span></button>
    <button class="iconbtn" data-act="sheet" data-id="rules" aria-label="Rules">?</button>
    <button class="iconbtn" data-act="sheet" data-id="menu" aria-label="Menu">☰</button></header>`;
}
// the circle's public schedule as one chip: what closes this round, or the final-circle storm
function gasChip() {
  const T = WD.TUNE; const cl = WD.closing(G); const B = WD.safeBounds(G);
  if (B.n <= 1) { const d = T.finalStorm[Math.min(G.finalN || 0, T.finalStorm.length - 1)]; return `<span class="gaschip final" data-tip="${escA(`Final circle: at the end of this round the storm hits both operators for ${d} (then ${T.finalStorm.slice((G.finalN || 0) + 1).join(', ') || d}). Hard end after round ${T.hardEnd}: the most Health wins.`)}">FINAL · STORM ${d}</span>`; }
  const sch = WD.closeSchedule(G); const next = Object.entries(sch).sort((a, b) => a[1] - b[1])[0];
  if (cl.length) return `<span class="gaschip" data-tip="${escA(`End of this round: ${envName(WD.envAt(G, cl[0]))} closes (and its loot is lost). Caught outside: ${T.gasDmg}+ damage. Schedule: rounds ${T.closeAfter.join(', ')}, alternating ends; final circle after round ${T.closeAfter[T.closeAfter.length - 1]}.`)}">GAS · ${escA(envName(WD.envAt(G, cl[0])).toUpperCase())}</span>`;
  return `<span class="gaschip calm" data-tip="${escA(next ? `No location closes this round. Next: ${envName(WD.envAt(G, +next[0]))} after round ${next[1]}.` : 'No location closes this round.')}">GAS · R${next ? next[1] : '-'}</span>`;
}
function topDist(me, op) {
  const d = WD.dist(G); const bands = WD.guns(me).map(w => WD.eff(G, w).band); const inB = bands.some(b => d >= b[0] && d <= b[1]);
  const oenv = WD.envAt(G, op.pos); const od = WD.ENVS[oenv.def];
  const cov = me.pos === op.pos ? 'close quarters' : od.cover && oenv.state === 'safe' ? `rival cover −${od.cover}` : 'rival in the open';
  return `<span class="tdist ${bands.length ? (inB ? 'ok' : 'bad') : ''}" data-tip="${escA(`Distance to ${op.name}: ${d}. ${bands.length ? (inB ? 'At least one gun is in range.' : 'Out of range for your guns.') : 'You have no gun yet.'} ${cov[0].toUpperCase() + cov.slice(1)}.`)}"><small>DIST</small><b>${d}</b><i>${bands.length ? (inB ? 'in range' : 'out of range') : 'unarmed'}</i></span>`;
}
function hudDist(me, op) {
  const d = WD.dist(G); const bands = WD.guns(me).map(w => WD.eff(G, w).band); const inB = bands.some(b => d >= b[0] && d <= b[1]);
  const oenv = WD.envAt(G, op.pos); const od = WD.ENVS[oenv.def];
  const cov = me.pos === op.pos ? 'Close quarters' : od.cover && oenv.state === 'safe' ? `Rival cover −${od.cover}` : 'Rival in the open';
  return `<div class="h-dist" data-tip="${escA(`Distance to ${op.name}: ${d}. Each gun fires only inside its range band.`)}"><span class="lbl">Distance</span><b>${d}</b><small class="${bands.length ? (inB ? 'ok' : 'bad') : ''}">${bands.length ? (inB ? 'in range' : 'out of range') : 'unarmed'}</small><small>${cov}</small></div>`;
}
function hudRes(me) {
  const tips = { move: 'Movement: 1 per space. Unused Movement becomes Armor (up to 2) at End turn.', prec: 'Precision is your aim pool for the turn. A shot reveals 1 card per Precision you commit; it spends that Precision, then the gun’s Recoil costs more.', intel: 'Intel buys loot and Buy Station cards (2 buys per turn). Unspent Intel is lost at the end of your turn.', ammo: 'Shots left this turn: your gun’s Shots plus extra shots from cards.' };
  const pv = ui.prevRes || {}; ui.prevRes = { move: me.res.move, prec: me.res.prec, intel: me.res.intel, ammo: me.guns[0] ? WD.shotsLeft(G, ui.me, 0) : 0 };
  const pill = (k, v, lab) => `<div class="rp rp-${k} ${v ? '' : 'zero'} ${pv[k] != null && v > pv[k] ? 'bump' : ''}"${pv[k] != null && v > pv[k] ? ` data-gain="+${v - pv[k]}"` : ''} data-tip="${escA(tips[k])}">${ic(k)}<b data-num="r-${k}">${v}</b><span>${lab}</span></div>`;
  const st = []; const t = myTurn();
  if (t) { const bl = WD.buysLeft(G, ui.me); st.push(`<span data-tip="${escA(`Buys left this turn: loot stacks and the Buy Station together (${WD.TUNE.buyCap} per turn, +1 per +1 Buy).`)}">${bl} buy${bl === 1 ? '' : 's'}</span>`); }
  if (me.nextFire.reqMod) st.push(`<span data-tip="${escA(KW.Mark)}">Mark ${me.nextFire.reqMod}</span>`);
  if (me.revealPlus) st.push(`<span data-tip="${escA(KW.Steady)}">Steady ${me.revealPlus}</span>`);
  if (me.dmgTurn) st.push(`<span data-tip="Your hits deal this much more damage this turn.">Hits +${me.dmgTurn} dmg</span>`);
  if (me.ignoreCover) st.push(`<span data-tip="${escA(KW.Pierce)}">Pierce</span>`);
  if (me.shot) st.push(`+${me.shot} shot${me.shot > 1 ? 's' : ''}`);
  if (me.freeCycles) st.push(`${me.freeCycles} free cycle${me.freeCycles > 1 ? 's' : ''}`);
  if (me.def) st.push(`${ic('def')} Armor ${me.def}`);
  const rx = me.hand.filter(i => WD.cardDef(G, i).reaction).map(i => WD.cardDef(G, i).reaction);
  if (rx.length) st.push(`${ic('def')} Reaction −${rx.join(' −')}`);
  const scr = t && me.scrapAvail ? `<button class="sc-chip scr" data-act="scrapsheet" data-tip="Scrap: remove a card in your hand, play area or discard pile from the game.">${ic('scrap')} Scrap ${me.scrapAvail}</button>` : '';
  return `<section class="h-res" aria-label="Resources">
    <div class="h-pills">${pill('move', me.res.move, 'Move')}${pill('prec', me.res.prec, 'Prec')}${pill('intel', me.res.intel, 'Intel')}${pill('ammo', me.guns[0] ? WD.shotsLeft(G, ui.me, 0) : 0, 'Shots')}</div>
    ${engineHTML(me)}
    <div class="h-status">${st.map(x => `<span class="sc-chip">${x}</span>`).join('')}${scr}</div>
  </section>`;
}
// Threat (O7, replaces the Firepower sum): the damage you can expect this turn if you play your hand and shoot as planned,
// with the first shot's odds. Between turns it shows the damage you dealt. Sparkline: damage per turn so far.
function threatNow(me) {
  const k = [G.turnNo, ui.me, me.hand.length, me.play.length, me.res.prec, me.revealPlus, me.deck.length, me.discard.length, me.pos, OP().pos, me.guns[0], me.shot, me.dmgTurn, me.nextFire.reqMod].join(':');
  if (ui.thK !== k) { ui.thK = k; try { ui.th = WD.threat(G, ui.me, { ifPlayAll: true }); } catch (e) { ui.th = { ev: 0, p: 0, inRange: false }; } }
  return ui.th;
}
function fpMeter(me, where) {
  const live = G.turn === ui.me && !G.over && !ui.play && !G.spoils; const hist = me.dmgHist || [];
  const th = live ? threatNow(me) : null; const last = hist.length ? hist[hist.length - 1] : null; const best = hist.length ? Math.max(...hist) : 0;
  const spark = hist.slice(-11).map(v => ({ v })).concat(live ? [{ v: th.ev, live: true }] : []); const mx = Math.max(6, ...spark.map(x => x.v));
  const big = live ? (th.inRange ? (Math.round(th.ev * 10) / 10).toFixed(1) : '–') : last != null ? last : 0;
  const sub = live ? (th.inRange ? `<span class="fpd up">${Math.round(th.p * 100)}%<small> first shot</small></span>` : `<span class="fpd to"><small>out of range</small></span>`)
    : last != null ? `<span class="fpd ${last >= best && last ? 'up' : ''}"><small>damage last turn${last >= best && last ? ' · best' : ''}</small></span>` : '<span class="fpd to"><small>no turn yet</small></span>';
  const tip = live ? (th.inRange ? `Threat: about ${th.ev} damage this turn if you play your hand and shoot as planned (${th.shots} shot${th.shots === 1 ? '' : 's'} left; the first one hits ${Math.round(th.p * 100)}% of the time). It counts your gun's ladder, cover and the cards left in your deck.` : 'Threat: your rival is out of your gun’s range. Move closer (or wait for them to come in).')
    : `Damage you dealt per turn: ${hist.join(', ') || 'none yet'}.${best ? ` Best turn: ${best}.` : ''}`;
  return `<div class="h-fp ${live ? 'live' : 'sealed-v'}" data-tip="${escA(tip)}" role="group" aria-label="${live ? `Threat ${big} damage` : `Damage last turn ${big}`}">
    <span class="fp-lbl">${live ? 'THREAT' : 'DAMAGE'}<em>${live ? 'expected this turn' : hist.length ? `turn ${hist.length}` : ''}</em></span>
    <span class="fp-main"><b data-num="th-${where}">${big}</b>${sub}</span>
    <span class="spark" aria-hidden="true">${spark.map((x, i) => `<i class="${x.live ? 'lv' : i === spark.length - 1 ? 'cur' : ''} ${!x.live && x.v === best && best ? 'best' : ''}" style="height:${Math.max(8, Math.round(x.v / mx * 100))}%"></i>`).join('')}</span></div>`;
}
// Deck bar (O7): starters against the cards you added, by squad. It fills as your deck becomes yours.
function deckBar(pi) {
  const m = WD.deckMix(G, pi); const seg = (n, cls, st = '') => n ? `<i class="${cls}" style="flex:${n};${st}"></i>` : '';
  const tip = `Your deck: ${m.total} cards. ${m.starters} starter${m.starters === 1 ? '' : 's'} and ${m.yours} card${m.yours === 1 ? '' : 's'} you added (${WD.SQUADS.filter(a => m.by[a]).map(a => `${ARCH_SHORT[a]} ${m.by[a]}`).join(', ') || 'none yet'}). Loot, Spoils and Field Promotion turn starters into your squad.`;
  return `<div class="h-deck" data-tip="${escA(tip)}"><span class="dk-lbl"><b>${m.yours}</b> yours · ${m.starters} starters</span><span class="dk-bar">${WD.SQUADS.map(a => seg(m.by[a], 'sq', `background:var(${ARCH_VAR[a]})`)).join('')}${seg(m.starters, 'st')}</span></div>`;
}
// The tactical strip: the new verbs in play (yours and your rival's). Every chip explains itself on hold, right click or hover.
function tacStrip(me) {
  const op = OP(); const t = myTurn(); const out = [];
  const chip = (cls, txt, tip, act) => out.push(act ? `<button class="tchip ${cls}" data-act="${act}" data-tip="${escA(tip)}">${txt}</button>` : `<span class="tchip ${cls}" data-tip="${escA(tip)}">${txt}</span>`);
  if (op.ow) { const b = WD.eff(G, op.guns[0]).band; chip('warn', `⚠ Rival holds an angle ${op.ow.prec}`, `${op.name} is holding an angle with ${op.ow.prec} Precision. If you end your turn at distance ${b[0]}–${b[1]} from them, their gun fires once (reveal ${op.ow.prec}). You are at distance ${WD.dist(G)}.`); }
  if (me.ow && !t) chip('me', `Angle held ${me.ow.prec}`, `You hold the angle with ${me.ow.prec} Precision: if ${op.name} ends this turn in your range, you fire.`);
  if (me.supp && (me.supp.move || me.supp.prec)) chip('warn', `Suppressed −${me.supp.move}${ic('move')} −${me.supp.prec}${ic('prec')}`, `Suppressing Barrage: the next ${me.supp.move} Movement and ${me.supp.prec} Precision you gain this turn are lost.`);
  if (op.suppNext) chip('me', `Rival suppressed next turn`, `Your Suppressing Barrage: on ${op.name}'s next turn their first ${op.suppNext.move} Movement and ${op.suppNext.prec} Precision are lost.`);
  if (op.supp && !t && (op.supp.move || op.supp.prec)) chip('me', 'Rival suppressed', `${op.name} still loses the next ${op.supp.move} Movement and ${op.supp.prec} Precision they gain this turn.`);
  if (t) {
    if (me.peek) chip('act', `Sweep: arrange ${me.peek.length}`, 'Intel Sweep: look at your top cards and put them back in any order. Tap to arrange.', 'sweepsheet');
    if (me.chargeDmg) chip('me', `Charge +${me.chargeDmg} at dist 0`, `Charge: this turn your hits at distance 0 deal +${me.chargeDmg} damage.`);
    if (me.onHitDraw) chip('me', `Next hit: draw ${me.onHitDraw}`, `Follow Through: your next hit this turn draws ${me.onHitDraw} cards; play them and keep shooting.`);
    if (me.expose) chip('me', 'Expose', 'Expose: this turn your hits ignore the rival’s Armor and Reaction cards.');
    if (me.overwatch) chip('me', 'Holding the angle', KW['held angle']);
    if (me.anyStack) chip('me', 'Contraband: any stack', 'Contraband Run: this turn you may buy the top card of any stack on the map, at its printed cost (no next-door cost).');
    if (me.fortify) chip('me', 'Fortify', `Fortify: your Armor (up to ${WD.TUNE.fortifyCap}) holds through your next Ready.`);
    const starters = me.hand.concat(me.play, me.discard).filter(i => WD.isStarter(G, i));
    if (!me.promoted && starters.length && me.res.intel >= WD.TUNE.promoteCost && WD.buysLeft(G, ui.me) > 0) chip('act', `Promote ${ic('intel')}${WD.TUNE.promoteCost}`, `Field Promotion: pay ${WD.TUNE.promoteCost} Intel and one buy to swap a starter for a squad basic. Once per turn. Tap to choose.`, 'promosheet');
  }
  if (me.drop && me.drop.length) chip('me', `Hot Drop: ${me.drop.length} next hand`, `Delivered to your next hand (on top of the 5 you draw): ${me.drop.map(i => WD.cardDef(G, i).name).join(', ')}.`);
  if (me.fortify && !t) chip('me', 'Fortified', `Your Armor holds through your next Ready (up to ${WD.TUNE.fortifyCap}).`);
  return out.length ? `<div class="h-tac" aria-label="Tactics in play">${out.join('')}</div>` : '';
}
// Squad counters: cards owned per squad (the deck taking form) + a 5-step track of cards in play this turn,
// with the Rally steps (3 and 5) marked; a step lights up when its Rally fires.
function squadHTML(me) {
  const live = G.turn === ui.me && !G.over && !ui.play;
  const own = WD.archCounts(G, ui.me); const main = WD.mainSquad(G, ui.me); const inPlay = live ? WD.squadCounts(G, ui.me) : {};
  const fresh = ui.rallyFx && ui.rallyFx.t > performance.now() ? ui.rallyFx.keys : [];
  const [r1, r2] = WD.TUNE.rally;
  return `<div class="h-squad" aria-label="Squad counters">${WD.SQUADS.map(a => {
    const n = inPlay[a] || 0; const rd = live ? me.rallyDone.filter(k => k.startsWith(a)).map(k => +k.slice(a.length)) : [];
    const trk = Array.from({ length: r2 }, (_, k) => `<i class="${k < n ? 'on' : ''} ${k + 1 === r1 || k + 1 === r2 ? 'th' : ''} ${rd.includes(k + 1) ? 'ral' : ''}"></i>`).join('');
    const tip = `${ARCH_SHORT[a]}: you own ${own[a]} card${own[a] === 1 ? '' : 's'} (deck + Loadout)${a === main ? ', your main squad' : ''}.${live ? ` In play now: ${n}.` : ''} Rally ${r1} in play: ${WD.RALLY_TEXT[a][r1]}. Rally ${r2}: ${WD.RALLY_TEXT[a][r2]}.`;
    return `<span class="sqc ${a === main ? 'main' : ''} ${n ? 'on' : ''} ${rd.length ? 'rallied' : ''} ${fresh.some(k => k.startsWith(a)) ? 'fire' : ''}" style="--arch:var(${ARCH_VAR[a]})" data-tip="${escA(tip)}"><span class="sq-top">${shapeSvg(a)}<b>${own[a]}</b></span><span class="sq-trk">${trk}</span></span>`; }).join('')}</div>`;
}
function engineHTML(me, compact) {
  return `<div class="h-engine ${compact ? 'm' : ''}">${fpMeter(me, compact ? 'm' : 'd')}${deckBar(ui.me)}${squadHTML(me)}${tacStrip(me)}</div>`;
}
// Loadout row: 2 slots beside the gun; the cards stay on the table, fire at every Ready and count for Squad
function loadoutHTML(me) {
  const slots = Array.from({ length: WD.TUNE.loadoutSlots }, (_, k) => me.loadout[k]);
  const ready = ui.readyFx && ui.readyFx > performance.now();
  return `<div class="h-lo ${ready ? 'rdy' : ''}" aria-label="Loadout row" data-tip="Loadout row: Loadout cards stay on the table. They give their effect at the start of every turn (Ready) and count as squad cards for Squad lines and Rally. Deploy one by playing it; a third one replaces a slot or is used once."><span class="lo-head">LOADOUT<small>on the table · fires every turn</small></span><span class="lo-slots">${slots.map(i => { if (!i) return `<span class="lo-slot empty"><b>+</b><span>Empty slot<small>play a Loadout card</small></span></span>`;
    const d = WD.cardDef(G, i); return `<span class="lo-slot full" data-flip="c${i}" data-prev="hc:${i}" style="--arch:var(${ARCH_VAR[d.archetype]})">${roleB(d.archetype)}<span><b>${escA(d.name)}</b><small>${fx(WD.effText(d.loadout))}</small></span></span>`; }).join('')}</span></div>`;
}
function hudPerks(pi) {
  const pl = G.players[pi]; const own = pl.perks || [];
  if (!own.length) return `<span class="pk none">${pl.perkOffer ? 'drafting…' : 'none yet'}</span>`;
  return own.map(k => { const L = WD.LOADOUT[k]; const fired = (pl.perkFired || []).includes(k); const prog = L.trig && pl.gen ? Math.min(pl.gen[L.trig.res], L.trig.n) : null;
    return `<button class="pk ${fired ? 'fired' : ''}" style="--arch:var(${ARCH_VAR[L.arch] || '--muted'})" data-act="perkview" data-id="${pi}:${k}" data-prev="perk:${pi}:${k}"><span class="pk-ic">${L.arch && SHAPE[L.arch] ? shapeSvg(L.arch) : '★'}</span><b>${L.name}</b><small>${L.trig ? (fired ? '✓ this turn' : `${ic(RES_IC[L.trig.res])}${prog}/${L.trig.n}`) : 'always on'}</small></button>`; }).join('');
}
function hudHand(me) {
  const t = myTurn();
  const cards = me.hand.slice().sort((a, b) => (ROLE_ORDER[WD.cardDef(G, a).archetype] ?? 9) - (ROLE_ORDER[WD.cardDef(G, b).archetype] ?? 9));
  const pl = t ? me.play : []; const n = cards.length + pl.length;
  const key = G.turnNo + ':' + ui.me + ':' + t; const deal = t && ui.dealKey !== key && cards.length; if (deal) ui.dealKey = key;
  const hot = ui.sqHot && ui.sqHot.t > performance.now() ? ui.sqHot.ids : [];
  const played = pl.map((iid, i) => `<span class="hslot pl ${hot.includes(iid) ? 'sqhot' : ''}" data-flip="c${iid}">${cardHTML(WD.cardDef(G, iid), { cls: 'played' + (ui.justPlayed === iid ? ' fresh' : ''), prev: 'hc:' + iid, act: 'noop', id: iid })}</span>`).join('');
  ui.justPlayed = null;
  const fn = cards.length; const hand = cards.map((iid, k) => `<span class="hslot ${ui.lift === iid ? 'lifted' : ''}" data-flip="c${iid}" style="--fo:${(k - (fn - 1) / 2).toFixed(2)}">${cardHTML(WD.cardDef(G, iid), { act: ui.burnMode ? 'burn' : 'card', id: iid, prev: 'hc:' + iid, k })}</span>`).join('');
  return `<div class="hh-row ${ui.burnMode ? 'burning' : ''} ${deal ? 'deal' : ''}" style="--n:${Math.max(1, n + (pl.length && cards.length ? 1 : 0))}">${played}${pl.length && cards.length ? '<span class="hh-gap" aria-hidden="true"></span>' : ''}${hand || (pl.length ? '' : `<span class="empty-hand">${t ? 'Hand empty.' : 'Your next hand appears here.'}</span>`)}</div>`;
}
function shortErr(e) {
  if (!e) return 'Can’t fire';
  if (/Round 1 is the drop/.test(e)) return 'No firing in round 1';
  if (/fires at distance/.test(e) || /Out of range/.test(e)) return 'Out of range';
  if (/No ammo/.test(e)) return 'No ammo · keep a card';
  if (/fired its (magazine|shots)/.test(e)) return 'No shots left';
  if (/No Precision|Nothing to reveal/.test(e)) return 'No Precision';
  return e.replace(/\.$/, '');
}
function curGun(me) {
  if (ui.gunSel != null && me.guns[ui.gunSel]) return ui.gunSel;
  const fo = myTurn() ? fireOdds() : null; if (fo && fo.pct != null) return fo.gi;
  return me.guns[0] ? 0 : me.guns[1] ? 1 : 0;
}
function gunPanel(me, gi) {
  const iid = me.guns[gi]; const cur = curGun(me) === gi;
  if (!iid) return `<div class="gslot-empty ${gi ? 'sec' : ''}"><b>${gi ? 'Secondary' : 'Primary'}</b> <span>${gi ? 'empty' : 'none yet — buy one from a loot stack'}</span></div>`;
  if (false) return `<div class="gp empty ${gi ? 'sec' : ''} ${cur ? 'cur' : ''}"><div class="gp-band"></div><div class="gp-body"><span class="lbl">${gi ? 'Secondary' : 'Primary'}</span><span class="gp-none">${gi ? 'Empty. Loot stacks hold pistols, revolvers and knives.' : 'No primary yet. Buy one from a loot stack.'}</span></div></div>`;
  const def = wdef(iid); const e = WD.eff(G, iid); const t = myTurn(); const fo = t ? fireOdds(gi) : null; const ok = fo && fo.pct != null;
  if (hasFace('gun_' + def.id)) {
    const left = WD.shotsLeft(G, ui.me, gi); const ch = [];
    if (e.magazine_capacity !== def.magazine_capacity) ch.push(`Mag ${e.magazine_capacity}`); if (e.recoil !== def.recoil) ch.push(`Recoil ${e.recoil}`); if (e.band[0] !== def.band[0] || e.band[1] !== def.band[1]) ch.push(`Range ${e.band[0]}–${e.band[1]}`);
    const lit = def.gcombo && me.gunCombo === G.turnNo;
    const ga = gunArt(def);
    const gpc = `<span class="gpc" aria-hidden="true"><span class="gpc-nm"><b>${escA(def.name)}</b><small>${escA(GSHORT[def.cls] || def.cls)}</small></span>${ga ? `<img class="gpc-art" src="${ga}" alt="">` : '<span class="gpc-art"></span>'}<span class="gpc-st"><span title="Range">${ic('rng')}${e.band[0]}–${e.band[1]}</span><span title="Recoil">${ic('rcl')}${e.recoil}</span><span class="gpc-lad" title="Damage ladder: Hit Markers needed → damage">${def.ladder.map(([h, dd]) => `<span>${h}+<b>${dd}</b></span>`).join('')}</span></span></span>`;
    return `<div data-flip="g${iid}" class="gpf ${gi ? 'sec' : ''} ${cur ? 'cur' : ''} ${t && !ok ? 'dim' : ''} ${lit ? 'lit' : ''}" data-act="pickgunb" data-id="${gi}" role="button" tabindex="0" aria-label="${escA(wnm(def))}" data-prev="gun:${iid}">${pf('gun_' + def.id)}${gpc}
      <div class="gpf-bar"><span class="gpf-shots" title="Shots left this turn">${Array.from({ length: e.magazine_capacity }, (_, i) => `<i class="${i < left ? '' : 'e'}"></i>`).join('')}</span>${ch.length ? `<span class="gpf-mod">${ch.join(' · ')}</span>` : ''}${lit ? '<span class="gpf-combo">COMBO</span>' : ''}${t ? (ok ? `<span class="gpf-odds">${fo.pct >= 1 ? fo.pct + '%' : '&lt;1%'}</span>` : `<span class="gpf-odds no">${escA(shortErr(fo && fo.err))}</span>`) : ''}</div></div>`;
  }
  const m = k => e[k] !== def[k] ? ` class="up r${def.tier}"` : '';
  const L = def.ladder; const gc = def.gcombo; const lit = gc && me.gunCombo === G.turnNo;
  const left = WD.shotsLeft(G, ui.me, gi);
  const state = !t ? '' : ok ? `<b class="odds">${fo.pct}%</b>` : `<span class="why">${fo && fo.err ? escA(fo.err.replace(/\.$/, '')) : ''}</span>`;
  return `<div class="gp ${gi ? 'sec' : ''} ${cur ? 'cur' : ''} ${t && !ok ? 'dim' : ''}" data-act="pickgunb" data-id="${gi}" role="button" tabindex="0" data-prev="gun:${iid}" data-x="${escA(`${wnm(def)} (${def.rarityName} ${def.cls}). Range ${e.band[0]}–${e.band[1]}, magazine ${e.magazine_capacity}, recoil ${e.recoil}. Damage: ${L.map(([h, d]) => `${h}+ Hit Markers → ${d}`).join(', ')}. Tap to pick it for FIRE.`)}">
    <div class="gp-band">${L.map(([h, d]) => `<span class="gl"><span class="gh">${ic('hm')}${h}</span><b>${d}</b></span>`).join('')}</div>
    <div class="gp-body"><div class="gp-head"><b class="gp-name">${def.name}</b><span class="rar r${def.tier}">${def.rarityName}</span></div>
      <div class="gp-stats"><span>${ic('rng')}<b${m('band')}>${e.band[0]}–${e.band[1]}</b></span><span>${ic('mag')}<b${m('magazine_capacity')}>${e.magazine_capacity}</b></span><span>${ic('rcl')}<b${m('recoil')}>${e.recoil}</b></span>${def.melee ? '<span class="melee">Melee</span>' : ''}</div>
      ${gunArt(def) ? `<div class="gp-art" style="background-image:url(${gunArt(def)})" role="img" aria-label="${escA(def.name)}"></div>` : ''}
      <div class="gp-combo off">${def.melee ? 'Melee · distance 0 · always hits' : `Recoil ${e.recoil} per shot`}</div>
      <div class="gp-foot"><span class="mono">${left} shot${left === 1 ? '' : 's'} left</span>${state}<button class="gp-i" data-act="wview" data-id="${iid}" aria-label="Gun details">i</button></div></div></div>`;
}
function hudBtns(me) {
  const t = myTurn(); const gi = curGun(me); const fo = t && me.guns[gi] ? fireOdds(gi) : null; const ok = fo && fo.pct != null;
  const same = me.pos === OP().pos; const canPunch = WD.TUNE.punch && t && same && !me.punched && !ok;
  const pc = WD.plateCost(G, ui.me);
  const fireBtn = canPunch ? `<button class="hb-fire" data-act="dofists" data-tip="No gun can fire: punch your rival for 1 damage.">PUNCH · 1</button>`
    : `<button class="hb-fire ${t && ok && fo.pct >= 40 ? 'ready' : ''} ${t && ok && fo.pct < 10 ? 'long' : ''}" data-act="fire" data-id="${gi}" ${t && ok ? '' : 'disabled'} data-tip="${escA(ok ? (fo.sp.melee ? `Stab with the ${wnm(wdef(me.guns[gi]))}: always hits.` : `Fire the ${wnm(wdef(me.guns[gi]))}: commit ${fo.commit} Precision${fo.sp.free ? ` (+${fo.sp.free} free, Steady)` : ''}, reveal ${fo.sp.reveal} cards, need ${fo.sp.need}+ Hit Markers for the first step. Costs ${fo.sp.cost} Precision (commit + Recoil ${fo.sp.recoil}). Tap AIM to change the commit.`) : fo && fo.err ? fo.err : 'Pick a gun that can fire.')}"><span class="hb-l">FIRE${ok ? ` <b class="hb-pct">${fo.pct >= 1 ? fo.pct + '%' : '&lt;1%'}</b>` : ''}</span>${ok ? (fo.sp.melee ? '<small class="hb-why">always hits</small>' : `<small class="hb-why">reveal ${fo.sp.reveal} · −${fo.sp.cost} Prec</small>`) : t && fo && fo.err ? `<small class="hb-why">${escA(shortErr(fo.err))}</small>` : ''}</button>${t && ok && !fo.sp.melee ? `<button class="hb-aim" data-act="aim" data-id="${gi}" data-tip="Aim: choose how much Precision this shot commits. More cards revealed = better odds, but less Precision left for your next shot.">Aim <b>${fo.commit}</b>${fo.commit === suggested(gi).commit ? '<i>★</i>' : ''}</button>` : ''}`;
  return `${fireBtn}
    <button class="hb-bs" data-act="sheet" data-id="station" ${t ? '' : 'disabled'} data-tip="${escA(`Buy Station: one basic card per squad, ${pc} Intel each (counts as a buy). Also: pay ${WD.TUNE.stationScrapCost} Intel to scrap a Sprint, once per turn.`)}">${ic('para')} Buy Station <small>${ic('intel')}${pc} · ${t ? WD.buysLeft(G, ui.me) : WD.TUNE.buyCap} buys</small></button>
    <button class="hb-move ${ui.moveMode ? 'on' : ''}" data-act="move" ${t && (ui.moveMode || ((!me.moved || WD.TUNE.multiMove) && me.res.move > 0 && WD.reachable(G, ui.me).length)) ? '' : 'disabled'} data-tip="Your one Move this turn: tap to light up the locations you can reach, then tap one. 1 Movement per space (+ cover).">${ic('move')} ${ui.moveMode ? 'Cancel move' : me.moved && !WD.TUNE.multiMove ? 'Moved' : `Move <small>${me.res.move}</small>`}</button>
    ${t && me.scrapAvail ? `<button class="hb-scrap" data-act="scrapsheet" data-tip="Remove a card from your hand or discard pile from the game.">${ic('scrap')} Scrap ${me.scrapAvail}</button>` : ''}
    <button class="hb-all" data-act="playall" ${t && me.hand.some(i => !WD.cardDef(G, i).jam) ? '' : 'disabled'} data-tip="Play every card in your hand (Malfunction stays).">Play all</button>
    ${t && WD.canBench(G, ui.me) && me.hand.length ? `<button class="hb-burn ${ui.burnMode ? 'on' : ''}" data-act="burnmode" data-tip="Workbench: once per turn, remove a card from your hand from the game. Free.">${ui.burnMode ? 'Tap a card to burn · cancel' : 'Burn 1 (Workbench)'}</button>` : ''}
    <button class="hb-end" data-act="endturn" ${t ? '' : 'disabled'} data-tip="End your turn: unspent Intel and Scrap are lost, discard your hand and played cards (the Loadout row stays), draw 5.">End turn${t && WD.TUNE.digIn && me.res.move > 0 ? `<small class="dig">+${Math.min(WD.TUNE.digIn, me.res.move)}${ic('def')}</small>` : ''}</button>
    <span class="hb-deck">Deck <b>${me.deck.length}</b> · <span class="dcount">Discard <b>${me.discard.length}</b></span></span>`;
}
const RAR_N = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary'];
function codexItems() {
  if (ui.codexCache) return ui.codexCache;
  const T = WD.TUNE; const out = [];
  const gunCount = {}; [1, 2, 3].forEach(t => (WD.GUNSET[t] || []).forEach(id => gunCount[id] = (gunCount[id] || 0) + 1)); gunCount['pistol-0'] = (gunCount['pistol-0'] || 0) + 2;
  const stCopies = { T001: T.stSprint, T002: T.stScout, T004: T.stAim, T005: 2, T006: 0 };
  for (const id in WD.CARDS) { const c = WD.CARDS[id]; const n = 'card_' + id; if (!hasFace(n)) continue;
    const station = /^K/.test(id); const starter = c.archetype === 'starter';
    const copies = starter ? (stCopies[id] || 0) * 2 : station ? T.stationCopies : c.copies; if (!copies) continue;
    out.push({ n, kind: 'card', role: starter ? 'starter' : c.archetype, src: starter ? 'starter' : station ? 'station' : 'loot', rar: starter || station || c.tier === 1 ? 0 : c.tier, copies, name: c.name, text: `${c.name} ${c.text} ${c.squadText || ''} ${c.loadout ? 'loadout' : ''}`.toLowerCase() }); }
  for (const id in gunCount) { const g = WD.WEAPONS[id]; const n = 'gun_' + id; if (!g || !hasFace(n)) continue;
    out.push({ n, kind: 'gun', role: g.archetype, src: id === 'pistol-0' ? 'starter' : 'loot', rar: g.tier, copies: gunCount[id], name: g.name, text: `${g.name} ${g.cls} ${(g.gcombo && g.gcombo.text) || ''}`.toLowerCase() }); }
  const seen = {}; WD.LOCSET.forEach((L, i) => { const n = 'loc_L' + String(i + 1).padStart(2, '0'); if (!hasFace(n)) return; const e = WD.ENVS[L.def];
    out.push({ n, kind: 'loc', role: e.affinity, src: 'start', rar: 0, copies: 1, name: e.name, text: `${e.name} ${e.text} ${e.bonusText || ''} ${e.affinity}`.toLowerCase() }); });
  return (ui.codexCache = out);
}
function codexSheet(S) {
  const f = S.f || (S.f = { kind: 'all', role: 'all', rar: 'all', q: '' });
  const items = codexItems();
  const pass = it => (f.kind === 'all' || it.kind === f.kind) && (f.role === 'all' || it.role === f.role || (f.role === 'station' && it.src === 'station')) && (f.rar === 'all' || it.rar === +f.rar) && (!f.q || it.text.includes(f.q.toLowerCase()));
  const chip = (grp, val, label, extra = '') => `<button class="cx-chip ${f[grp] === val ? 'on' : ''}" data-act="cxf" data-id="${grp}:${val}" ${extra}>${label}</button>`;
  const roleChip = r => chip('role', r, `${SHAPE[r] ? shapeSvg(r) : ''}${ARCH_SHORT[r] || r}`, ARCH_VAR[r] ? `style="--arch:var(${ARCH_VAR[r]})"` : '');
  const groups = [['card', 'Cards'], ['gun', 'Guns'], ['loc', 'Locations']];
  const shown = items.filter(pass);
  const body = groups.filter(([k]) => f.kind === 'all' || f.kind === k).map(([k, lab]) => {
    const list = items.filter(it => it.kind === k);
    return `<section class="cx-sec" data-kind="${k}"><h3>${lab} <span class="cx-n" data-n="${k}">${list.filter(pass).length}</span></h3><div class="cx-grid ${k}">${list.map(it => `<button class="cx-item ${pass(it) ? '' : 'off'}" data-act="cxview" data-id="${it.n}" data-txt="${escA(it.text)}" data-ok="${(f.kind === 'all' || it.kind === f.kind) && (f.role === 'all' || it.role === f.role || (f.role === 'station' && it.src === 'station')) && (f.rar === 'all' || it.rar === +f.rar) ? 1 : 0}" aria-label="${escA(it.name)}">${pf(it.n)}<span class="cx-meta">×${it.copies}${it.src === 'station' ? ' · Buy Station' : it.src === 'starter' ? ' · Starter' : it.kind === 'loc' ? ` · ${ARCH_SHORT[it.role] || ''} loot` : ''}</span></button>`).join('')}</div></section>`; }).join('');
  return `${head('Card codex')}
    <div class="cx-bar">
      <input class="cx-q" type="search" placeholder="Search names and effects…" value="${escA(f.q)}" aria-label="Search">
      <div class="cx-row">${chip('kind', 'all', 'All')}${chip('kind', 'card', 'Cards')}${chip('kind', 'gun', 'Guns')}${chip('kind', 'loc', 'Locations')}</div>
      <div class="cx-row">${chip('role', 'all', 'Any role')}${['assault', 'recon', 'support', 'engineer'].map(roleChip).join('')}${chip('role', 'starter', 'Starter')}${chip('role', 'station', 'Buy Station')}</div>
      <div class="cx-row">${chip('rar', 'all', 'Any rarity')}${RAR_N.map((r, i) => chip('rar', String(i), `<i class="cx-dot r${i}"></i>${r}`)).join('')}</div>
      <div class="cx-count"><b class="cx-total">${shown.length}</b> of ${items.length} components · tap one to enlarge</div>
    </div>
    <div class="cx-body">${body || ''}<p class="cx-empty" ${shown.length ? 'hidden' : ''}>No match. Clear a filter.</p></div>`;
}
function codexSearch(q) {
  const S = ui.sheet; if (!S || S.type !== 'codex') return; S.f.q = q; const t = q.toLowerCase(); let tot = 0; const per = {};
  document.querySelectorAll('.cx-item').forEach(el => { const ok = el.dataset.ok === '1' && (!t || el.dataset.txt.includes(t)); el.classList.toggle('off', !ok); if (ok) { tot++; const k = el.closest('.cx-sec').dataset.kind; per[k] = (per[k] || 0) + 1; } });
  document.querySelectorAll('.cx-n').forEach(el => el.textContent = per[el.dataset.n] || 0);
  const tt = document.querySelector('.cx-total'); if (tt) tt.textContent = tot; const em = document.querySelector('.cx-empty'); if (em) em.hidden = tot > 0;
}
document.addEventListener('input', e => { if (e.target.classList && e.target.classList.contains('cx-q')) codexSearch(e.target.value); });
function stationSheet() {
  const me = ME(); const pc = WD.plateCost(G, ui.me); const ok = me.res.intel >= pc;
  const bl = WD.buysLeft(G, ui.me); const sprints = me.hand.concat(me.play, me.discard).filter(i => WD.cardDef(G, i).id === 'T001');
  const svc = myTurn() ? `<div class="row bs-svc"><span class="lbl">Service · ${WD.TUNE.stationScrapCost} Intel, once per turn, not a buy</span><button class="btn sm alt" data-act="stscrap" data-id="${sprints[0] || ''}" ${sprints.length && !me.stationScrapped && me.res.intel >= WD.TUNE.stationScrapCost ? '' : 'disabled'}>${ic('scrap')} Scrap a Sprint${sprints.length ? '' : ' (none in hand, play or discard)'}</button></div>` : '';
  return `${headIntel('Buy Station')}<p class="ld-p">One basic per squad, always open. ${bl} buy${bl === 1 ? '' : 's'} left this turn. ${G.round <= WD.TUNE.hotDrop ? `<b>Hot Drop</b> (rounds 1–${WD.TUNE.hotDrop}): bought cards are delivered to your next hand.` : 'Bought cards go to your discard pile.'}</p>${svc}${myTurn() ? `<div class="row bs-svc"><span class="lbl">Field Promotion · ${WD.TUNE.promoteCost} Intel + 1 buy, once per turn</span><button class="btn sm alt" data-act="promosheet" ${!me.promoted && me.res.intel >= WD.TUNE.promoteCost && bl > 0 ? '' : 'disabled'}>Promote a starter</button></div>` : ''}
    <div class="bs-grid">${WD.TUNE.station.map(id => { const k = WD.CARDS[id]; const left = G.stationLeft ? G.stationLeft[id] : null; return `<div class="bs-cell">${(hasFace('card_' + id) ? `<button class="bscard bsf" data-act="supply" data-id="${id}" ${myTurn() && ok && left !== 0 ? '' : 'disabled'} aria-label="Buy ${escA(k.name)}">${pf('card_' + id)}</button>` : cardHTML(k, { act: 'supply', id, dis: !(myTurn() && ok && left !== 0), cls: 'bscard', prev: 'cd:' + id }))}<small>${left != null ? `${left} left` : ''}</small></div>`; }).join('')}</div><p class="bs-foot">${ic('intel')}${pc} Intel each</p>`;
}
// face of a card instance or card id, inspectable (hold, right click, hover)
const faceOf = (id, prev) => hasFace('card_' + id) ? pf('card_' + id) : cardHTML(WD.CARDS[id], { prev });
// Spoils (O2): 3 loot cards after a turn in which you dealt damage. Take 1 (to your discard pile) or skip; then the turn ends.
function spoilsSheet() {
  const sp = G.spoils; if (!sp) return `${head('Spoils')}<p class="ld-p">Nothing to take.</p>`;
  const me = ME(); const mf = WD.mainSquad(G, ui.me);
  return `<div class="sheet-head"><h2>Spoils</h2></div><p class="ld-p">You dealt <b>${me.stats.turnDmg}</b> damage this turn. Take one card for free (it goes to your discard pile), or skip. Hold, right click or hover a card to read it.</p>
    <div class="sp-grid">${sp.offer.map(iid => { const d = WD.cardDef(G, iid); return `<div class="sp-cell"><button class="sp-pick" data-act="spoilpick" data-id="${iid}" data-prev="cd:${d.id}" aria-label="Take ${escA(d.name)}">${faceOf(d.id, 'cd:' + d.id)}</button>
      <small>${d.tactic ? '<b class="tacb">TACTIC</b> ' : ''}${ARCH_SHORT[d.archetype] || ''}${d.archetype === mf ? ' · your main squad' : ''}</small></div>`; }).join('')}</div>
    <div class="row"><button class="btn alt" data-act="spoilskip">Skip the Spoils</button></div>`;
}
// Intel Sweep: tap the cards in the order you want them on top (first tap = the top card, revealed or drawn first)
function sweepSheet(S) {
  const pk = ME().peek; if (!pk) return `${head('Sweep')}<p class="ld-p">Nothing to arrange.</p>`;
  const rest = pk.filter(i => !S.order.includes(i)); const final = S.order.concat(rest);
  return `${head(`Intel Sweep · top ${pk.length}`)}<p class="ld-p">Tap the cards in the order you want them: the first tap goes on top (your next shot reveals it first, or your next draw takes it). Cards you don't tap stay below, in their order.</p>
    <div class="sw-grid">${pk.map(i => { const d = WD.cardDef(G, i); const k = S.order.indexOf(i); return `<button class="sw-pick ${k >= 0 ? 'on' : ''}" data-act="sweeppick" data-id="${i}" data-prev="hc:${i}" aria-label="${escA(d.name)}">${faceOf(d.id, 'hc:' + i)}<em>${k >= 0 ? k + 1 : ''}</em><small>${d.hit_markers} ${ic('hm')}</small></button>`; }).join('')}</div>
    <p class="sw-line">New top → bottom: ${final.map(i => `<b>${escA(WD.cardDef(G, i).name)}</b>`).join(' › ')}</p>
    <div class="row"><button class="btn sig" data-act="sweepok" data-id="set">Put them back in this order</button><button class="btn alt" data-act="sweepok" data-id="keep">Keep as they are</button></div>`;
}
// Field Promotion (O3): a starter becomes a Buy Station basic of the squad you choose
function promoteSheet(S) {
  const me = ME(); const zones = [['hand', me.hand], ['play area', me.play], ['discard pile', me.discard]];
  const can = !me.promoted && me.res.intel >= WD.TUNE.promoteCost && WD.buysLeft(G, ui.me) > 0;
  const basic = q => WD.CARDS[WD.BASIC[q]];
  return `${headIntel('Field Promotion')}<p class="ld-p">Pay ${WD.TUNE.promoteCost} Intel and one buy: a starter leaves the game and a squad basic takes its place (in your hand if it was there, else in your discard pile). Once per turn.</p>
    <h3>1 · Pick a starter</h3>${zones.map(([lab, z]) => { const st = z.filter(i => WD.isStarter(G, i)); return st.length ? `<p class="lbl">From your ${lab}</p><div class="pr-row">${st.map(i => { const d = WD.cardDef(G, i); return `<button class="pr-pick ${S.pick === i ? 'on' : ''}" data-act="promopick" data-id="${i}" data-prev="hc:${i}" aria-label="${escA(d.name)}">${faceOf(d.id, 'hc:' + i)}</button>`; }).join('')}</div>` : ''; }).join('') || '<p class="ld-p">No starters left: your deck is all yours.</p>'}
    <h3>2 · Pick its squad</h3><div class="pr-sq">${WD.SQUADS.map(q => { const d = basic(q); const left = G.stationLeft[d.id]; return `<button class="pr-sqb ${S.sq === q ? 'on' : ''}" data-act="promosq" data-id="${q}" ${left > 0 ? '' : 'disabled'} data-prev="cd:${d.id}" style="--arch:var(${ARCH_VAR[q]})">${faceOf(d.id, 'cd:' + d.id)}<small>${shapeSvg(q)} ${ARCH_SHORT[q]} · ${left} left</small></button>`; }).join('')}</div>
    <div class="row pr-go"><button class="btn sig" data-act="dopromote" ${can && S.pick && S.sq ? '' : 'disabled'}>${S.pick ? `Promote ${escA(WD.cardDef(G, S.pick).name)} to ${escA(basic(S.sq).name)}` : 'Pick a starter'}</button><button class="btn alt" data-act="close">Cancel</button></div>`;
}
const insignia = r => r.i >= 6 ? 'gold' : r.i >= 5 ? 'silver' : '';
function rankBadge(prof, big) {
  const r = WD.rankOf(prof.xp); const pct = r.nextXp ? Math.round((prof.xp - r.floor) / (r.nextXp - r.floor) * 100) : 100;
  return `<span class="rk ${big ? 'big' : ''} ${insignia(r)}" data-tip="${escA(`Operator rank ${r.name}: ${prof.xp} XP. ${r.next ? `${r.toNext} XP to ${r.next}.` : 'Top rank.'} Saved on this device only.`)}"><span class="rk-ins" aria-hidden="true">${'▲'.repeat(Math.min(3, r.i + 1))}</span><span class="rk-txt"><b>${r.name}</b><small>${prof.xp} XP${r.next ? ` · ${r.toNext} to ${r.next}` : ''}</small><span class="rk-bar"><i style="width:${pct}%"></i></span></span></span>`;
}
function rankSheet() {
  const prof = ui.prof; const r = WD.rankOf(prof.xp);
  return `${head('Operator rank')}<div class="rk-head">${rankBadge(prof, true)}</div>
    <p class="ld-p">XP after every match vs the AI: 40 for playing, +60 for a win (+30 for a draw), +1 per damage dealt (up to 80), +20 for reaching the final circle. Ranks unlock variety, never power. Saved on this device only (clearing site data resets it).</p>
    <ol class="rk-list">${WD.RANKS.map((x, i) => `<li class="${i <= r.i ? 'got' : ''}"><b>${x.name}</b> <small>${x.xp} XP</small>${x.unlock ? `<span data-tip="${escA(x.unlock.text)}">${i <= r.i ? '✓' : '🔒'} ${escA(x.unlock.name)}: ${escA(x.unlock.text)}</span>` : '<span>Start</span>'}</li>`).join('')}</ol>
    <p class="ld-p">Matches ${prof.matches} · wins ${prof.wins} · best damage in a match ${prof.bestDmg} · best turn ${prof.bestTurn}</p>`;
}
// After-action report (O7): the match story, then XP and rank
function overSheet() {
  const w = G.winner; const t = w === 'draw' ? 'Draw' : (ui.mode === 'ai' ? (w === ui.me ? 'Victory' : 'Eliminated') : `${G.players[w].name} wins`);
  const win = w !== 'draw' && (ui.mode !== 'ai' || w === ui.me); const me = ME(), op = OP();
  const rounds = Array.from({ length: G.round }, (_, k) => k + 1); const mx = Math.max(4, ...rounds.map(r => Math.max(me.stats.dmgRounds[r] || 0, op.stats.dmgRounds[r] || 0)));
  const bars = rounds.map(r => `<span class="aa-r" data-tip="${escA(`Round ${r}: you dealt ${me.stats.dmgRounds[r] || 0}, ${op.name} dealt ${op.stats.dmgRounds[r] || 0}.`)}"><i class="me" style="height:${Math.round((me.stats.dmgRounds[r] || 0) / mx * 100)}%"></i><i class="op" style="height:${Math.round((op.stats.dmgRounds[r] || 0) / mx * 100)}%"></i><small>${r}</small></span>`).join('');
  const mvp = Object.entries(me.stats.mvp).sort((a, b) => b[1] - a[1])[0];
  const added = me.stats.added.slice(-12);
  const M = ui.meta; const prev = M ? M.prev : ui.prof;
  const newBest = M && me.stats.damageDealt > (prev.bestDmg || 0) && prev.matches > 0;
  return `<div class="over-hero ${win ? 'win' : 'lose'}"><small>Round ${G.round} · ${G.endBy === 'hardEnd' ? 'hard end' : G.endBy === 'storm' ? 'the storm' : G.endBy === 'gas' ? 'the gas' : 'knockout'}${ui.daily ? ` · Daily Drop ${ui.daily}` : ''}${G.ops && G.ops.length ? ` · ${G.ops.map(k => WD.OPS[k].name).join(', ')}` : ''}</small><b>${t}</b></div>
    <div class="aa">
      <div class="aa-box"><h3>Damage per round <small><i class="lg me"></i>${ui.mode === 'ai' ? 'you' : escA(me.name)} <i class="lg op"></i>${escA(op.name)}</small></h3><div class="aa-bars">${bars}</div></div>
      <div class="aa-facts">
        <span data-tip="Your damage in the whole match (shots, held angles and Sentry Turret).">Damage <b>${me.stats.damageDealt}</b>${newBest ? ' <em>new best</em>' : ''}</span>
        <span data-tip="Your strongest turn and when it came.">Best turn <b>${me.stats.maxTurnDmg}</b>${me.stats.bestRound ? `<small> round ${me.stats.bestRound}</small>` : ''}</span>
        <span data-tip="Shots that hit / shots fired.">Hits <b>${me.stats.hits}/${me.stats.shots}</b></span>
        <span data-tip="Cards you gained: loot, Buy Station, Spoils and Field Promotion.">Added <b>${me.stats.added.length}</b><small>Spoils ${me.stats.spoils} · promoted ${me.stats.promoted}</small></span>
      </div>
      ${mvp ? `<div class="aa-mvp" data-prev="cd:${mvp[0]}"><span class="lbl">MVP card</span>${hasFace('card_' + mvp[0]) ? `<span class="mf">${pf('card_' + mvp[0])}</span>` : ''}<span><b>${escA(WD.CARDS[mvp[0]].name)}</b><small>${mvp[1]} Hit Markers in your hits</small></span></div>` : ''}
      ${added.length ? `<div class="aa-add"><span class="lbl">Cards you added${me.stats.added.length > 12 ? ' (last 12)' : ''}</span><div class="aa-row">${added.map(id => hasFace('card_' + id) ? `<span class="mf" data-prev="cd:${id}">${pf('card_' + id)}</span>` : `<span class="sc-chip">${escA(WD.CARDS[id].name)}</span>`).join('')}</div></div>` : ''}
      ${M ? `<div class="aa-xp"><span class="lbl">Operator XP +${M.gained.total}</span><span class="aa-parts">${M.gained.parts.map(([l, n]) => `<span>${escA(l)} <b>+${n}</b></span>`).join('')}</span>${rankBadge(ui.prof)}${M.after.i > M.before.i ? `<p class="aa-up">Promoted to <b>${M.after.name}</b>!</p>` : ''}${M.newUnlocks.map(u => `<p class="aa-unl" data-tip="${escA(u.text)}">Unlocked: <b>${escA(u.name)}</b> · ${escA(u.text)}</p>`).join('')}${M.saved ? '' : '<p class="ld-p">Your browser blocks storage here, so this rank lasts only until you close the page.</p>'}</div>` : `<p class="ld-p">Rank XP is earned in matches vs the AI.</p>`}
    </div>
    <div class="row over-btns"><button class="btn sig" data-act="new" data-id="${ui.mode}">Play again</button><button class="btn alt" data-act="close">See the board</button><button class="btn alt" data-act="home">Main menu</button></div>`;
}
function perkSheet(pi, k) {
  const pl = G.players[pi]; const L = WD.LOADOUT[k]; const fired = (pl.perkFired || []).includes(k); const prog = L.trig && pl.gen ? Math.min(pl.gen[L.trig.res], L.trig.n) : null;
  return `${head(`${pi === ui.me ? 'Your' : `${escA(pl.name)}'s`} perk`)}<div class="perkpick one"><div class="pcard" style="--arch:var(${ARCH_VAR[L.arch] || '--muted'})"><span class="pc-tag">${L.arch === 'any' || !WD.ARCH_TAG[L.arch] ? 'Any build' : WD.ARCH_TAG[L.arch]}${L.trig ? ` · trigger ${perkTrig(L)}` : ' · passive'}</span><b>${L.name}</b><span>${fx(L.text)}</span>${L.trig ? `<span class="pc-prog">${fired ? 'Triggered this turn ✓' : `This turn: ${prog}/${L.trig.n}`}</span>` : ''}</div></div>
    <p class="lbl" style="margin:12px 0 4px">All perks · ${escA(pl.name)}</p><div class="h-perks sheetp">${hudPerks(pi)}</div>`;
}
function rivalSheet() {
  const op = OP();
  return `${head(escA(op.name))}<div class="rivalbox">${oppHTML(op)}${logHTML()}</div>`;
}

// Start screen meta: rank, the Daily Drop and Operations (locked ones say which rank opens them)
function startMeta() {
  const prof = ui.prof; const r = WD.rankOf(prof.xp); const at = kind => WD.RANKS.findIndex(x => x.unlock && (x.unlock.kind === kind || x.unlock.id === kind));
  const dailyOk = r.i >= at('daily'); const done = prof.daily && prof.daily.date === today();
  const daily = `<button class="st-chip ${dailyOk ? '' : 'lock'}" ${dailyOk ? 'data-act="daily"' : 'disabled'} data-tip="${escA(dailyOk ? `Daily Drop ${today()}: one seeded match, the same drop for everyone today (no Operations).${done ? ` You played it: ${prof.daily.won ? 'won' : 'lost'}, ${prof.daily.dmg} damage. You can play it again.` : ''}` : `Unlocks at ${WD.RANKS[at('daily')].name}.`)}">${dailyOk ? '' : '🔒 '}Daily Drop${done ? ' ✓' : ''}</button>`;
  const ops = Object.keys(WD.OPS).map(k => { const ok = r.i >= at(k); const on = ok && ui.ops.includes(k);
    return `<button class="st-chip op ${on ? 'on' : ''} ${ok ? '' : 'lock'}" ${ok ? `data-act="optoggle" data-id="${k}" aria-pressed="${on}"` : 'disabled'} data-tip="${escA(`${WD.OPS[k].name}: ${WD.OPS[k].text} ${ok ? (on ? 'On for your next match vs the AI or pass & play.' : 'Tap to turn on.') : `Unlocks at ${WD.RANKS[at(k)].name}.`}`)}">${ok ? (on ? '✓ ' : '') : '🔒 '}${WD.OPS[k].name}</button>`; }).join('');
  return `<div class="st-meta"><button class="st-rank" data-act="sheet" data-id="rank" aria-label="Operator rank">${rankBadge(prof)}</button><div class="st-ops">${daily}${ops}</div></div>`;
}
function startHTML() {
  const fan = ['card_A21', 'gun_ar-3', 'card_RT3'].filter(hasFace);
  return `<div class="start2"><div class="st-bg" aria-hidden="true"></div>
    <div class="st-in">
      <div class="st-copy">
        <div class="st-kicker">Tactical deck-builder · 2 players · ~20 min</div>
        <h1>Warzone<br><span>Deckbuilder</span></h1>
        <p>Drop in with a pistol. Loot the map, build your deck, outgun your rival before the gas closes in.</p>
        <div class="st-roles">${['assault', 'recon', 'support', 'engineer'].map(r => `<span style="--arch:var(${ARCH_VAR[r]})">${shapeSvg(r)}${ARCH_SHORT[r]}</span>`).join('')}</div>
        <div class="st-cta"><button class="st-play" data-act="new" data-id="ai">Play vs AI</button><button class="st-sec" data-act="new" data-id="hotseat">Pass &amp; play</button></div>
        ${startMeta()}
        <div class="st-links"><button data-act="sheet" data-id="rules">How to play</button><span>·</span><button data-act="sheet" data-id="codex">Card codex</button><span>·</span><button data-act="sheet" data-id="rank">Rank &amp; unlocks</button></div>
      </div>
      <div class="st-fan" aria-hidden="true">${fan.map((n, i) => `<div class="st-card c${i} ${n.startsWith('gun_') ? 'g' : ''}">${pf(n)}</div>`).join('')}</div>
    </div></div>`;
}

function bestBulletHM(gi) { const me = ME(); if (!WD.TUNE.ammo) return 0; if (gi === 1 && me.perks.includes('amped')) return 0; const c = me.hand.map(i => WD.cardDef(G, i).hit_markers); if (me.freeAmmo > 0) c.push(WD.TUNE.freeBulletHM); return c.length ? Math.max(...c) : 0; }
// How much Precision the next shot commits: the player's pick (Aim sheet) or the planner's suggestion (WD.suggestCommit).
function aimKey(gi) { const me = ME(); return [G.turnNo, gi, me.res.prec, me.revealPlus, me.deck.length, me.discard.length, WD.shotsLeft(G, ui.me, gi), me.nextFire.reqMod, me.pos, OP().pos].join(':'); }
function suggested(gi) { const k = aimKey(gi); ui.sgCache = ui.sgCache || {}; if (!ui.sgCache[k]) ui.sgCache = { [k]: WD.suggestCommit(G, ui.me, gi) }; return ui.sgCache[k]; }
function commitFor(gi) { const me = ME(); if (ui.aim && ui.aim.key === aimKey(gi)) return Math.min(me.res.prec, ui.aim.c); const sg = suggested(gi); return sg.commit; }
function fireOdds(gi) {
  const me = ME(); if (gi == null) { const c = [0].filter(i => me.guns[i] && WD.shootCheck(G, ui.me, i, me.res.prec).ok).map(i => ({ i, o: fireOdds(i) }))[0]; return c ? c.o : null; }
  const c = commitFor(gi);
  const sc = WD.shootCheck(G, ui.me, gi, Math.max(c, me.revealPlus ? 0 : 1)); if (!sc.ok) return { err: sc.err, gi };
  const sp = WD.shotPreview(G, ui.me, gi, c);
  if (sp.melee) return { gi, pct: 100, ev: sp.steps[0][1], sp, commit: 0 };
  if (sp.reveal < 1) return { err: 'Nothing to reveal: commit Precision first.', gi };
  return { gi, pct: Math.round(WD.hitChance(G, ui.me, sp.reveal, sp.need, 300) * 100), ev: WD.expDmg(G, ui.me, sp), sp, commit: c };
}
function nextHint() {
  const me = ME();
  if (G.over) return 'Match over.';
  if (!myTurn()) return ui.mode === 'ai' ? `<b>${OP().name}</b> is taking their turn…` : 'Waiting…';
  if (ui.burnMode) return '<b>Workbench:</b> tap a card in your hand to burn it for good.';
  if (ui.moveMode) return '<b>Move:</b> tap a lit location (the number is its Movement cost). Tap <b>Cancel move</b> to stop.';
  const here = WD.envAt(G, me.pos);
  if (here.state === 'gas') return `<b>You are in the gas.</b> Move back in, or at round end take ${WD.TUNE.gasDmg}+ damage and get pushed back.`;
  if (WD.closing(G).includes(me.pos)) return `<b>Gas takes your location after this round</b> (it takes ${WD.closing(G).length} this round). Move left, toward new ground.`;
  if (!WD.guns(me).length) { const gun = here.loot.find(i => i.kind === 'weapon'); return gun ? `<b>Grab a gun:</b> play Recon for Intel, then Buy the ${wnm(WD.itemDef(G, gun))}. It comes loaded.` : '<b>Find a gun:</b> Search here or move to a location with one.'; }
  if (me.hand.some(i => !WD.cardDef(G, i).jam)) return '<b>Play your cards</b>, then move, buy or fire.';
  const fo = fireOdds();
  if (fo && fo.pct > 0) return `Tap <b>FIRE</b>: ${fo.pct}% with the ${wnm(wdef(me.guns[fo.gi]))}.`;

  if ((!me.moved || WD.TUNE.multiMove) && me.res.move) return WD.TUNE.digIn ? 'Tap <b>Move</b>, then a lit location. Unused Movement becomes Armor at End turn.' : 'Tap <b>Move</b>, then a lit location, or <b>End turn</b>.';
  return 'Buy what you can, then <b>End turn</b>.';
}
function topHTML() {
  const mine = myTurn();
  const who = G.over ? 'Match over' : ui.busy || (ui.mode === 'ai' && G.turn !== ui.me) ? `${G.players[G.turn].name}'s turn` : G.turn === ui.me ? 'Your turn' : `${G.players[G.turn].name}'s turn`;
  const cl = WD.closing(G);
  return `<header class="top"><span class="brand">WZ·DB</span>
    <span class="turnpill ${mine ? 'mine' : ''}">${who}</span>
    <span class="hint">${nextHint()}</span>
    <span class="roundinfo">Round <b>${G.round}</b>/${WD.TUNE.hardEnd} ${gasChip()}</span>
    <button class="iconbtn" data-act="sheet" data-id="rules" aria-label="Rules">?</button>
    <button class="iconbtn" data-act="sheet" data-id="menu" aria-label="Menu">☰</button></header>`;
}

// Operator portraits (original vector art). A = cyan helmet + goggles, B = red gas-mask hood.
const OPFACE = {
  me: `<svg viewBox="0 0 64 64" class="opface" aria-hidden="true"><defs><clipPath id="ofA"><circle cx="32" cy="32" r="30"/></clipPath></defs><g clip-path="url(#ofA)"><rect width="64" height="64" fill="#16343A"/><path d="M4 70c2-14 12-20 28-20s26 6 28 20z" fill="#2C3A2A"/><path d="M20 52l12 6 12-6 2 8H18z" fill="#3E4E36"/><path d="M22 40c0 7 4 12 10 12s10-5 10-12v-6H22z" fill="#C49A74"/><path d="M24 44c2 4 5 6 8 6s6-2 8-6c-2 2-5 3-8 3s-6-1-8-3z" fill="#9C7556"/><path d="M15 31c0-11 8-19 17-19s17 8 17 19v3H15z" fill="#4A5A3A"/><path d="M15 31h34v4H15z" fill="#3A4730"/><rect x="18" y="27" width="28" height="9" rx="4.5" fill="#101614"/><rect x="20" y="28.5" width="11" height="6" rx="3" fill="#1FB0C4"/><rect x="33" y="28.5" width="11" height="6" rx="3" fill="#1FB0C4"/><path d="M21 30h5" stroke="#B9F1F8" stroke-width="1.4" stroke-linecap="round"/><path d="M34 30h5" stroke="#B9F1F8" stroke-width="1.4" stroke-linecap="round"/><path d="M46 36c3 1 4 4 3 8l-6 3" fill="none" stroke="#101614" stroke-width="2"/><circle cx="43" cy="47" r="1.8" fill="#101614"/></g><circle cx="32" cy="32" r="30" fill="none" stroke="#1FB0C4" stroke-width="4"/></svg>`,
  them: `<svg viewBox="0 0 64 64" class="opface" aria-hidden="true"><defs><clipPath id="ofB"><circle cx="32" cy="32" r="30"/></clipPath></defs><g clip-path="url(#ofB)"><rect width="64" height="64" fill="#3A1814"/><path d="M4 70c2-14 12-20 28-20s26 6 28 20z" fill="#2A2622"/><path d="M14 36c0-13 8-23 18-23s18 10 18 23c0 9-6 16-18 16S14 45 14 36z" fill="#2B2B28"/><path d="M18 24c4-6 9-8 14-8s10 2 14 8" fill="none" stroke="#3E3D38" stroke-width="2"/><circle cx="25" cy="32" r="5.5" fill="#101010"/><circle cx="39" cy="32" r="5.5" fill="#101010"/><circle cx="25" cy="32" r="4" fill="#E0482F"/><circle cx="39" cy="32" r="4" fill="#E0482F"/><circle cx="23.6" cy="30.6" r="1.2" fill="#FFC2B4"/><circle cx="37.6" cy="30.6" r="1.2" fill="#FFC2B4"/><path d="M27 40h10l3 6c-2 3-5 4-8 4s-6-1-8-4z" fill="#3A3A36"/><circle cx="32" cy="46" r="4.5" fill="#1A1A18" stroke="#55534C" stroke-width="1.5"/><path d="M29.5 44.5l5 3M29.5 47.5l5-3" stroke="#55534C" stroke-width="1"/></g><circle cx="32" cy="32" r="30" fill="none" stroke="#C8442B" stroke-width="4"/></svg>`,
};
function tokHTML(i, pl) { const me = i === ui.me; return `<span class="tok op ${me ? 'me' : 'them'}" data-flip="tok${i}" title="${escA(me ? (ui.mode === 'ai' ? 'You' : pl.name) : pl.name)}">${OPFACE[me ? 'me' : 'them']}</span>`; }
function shownCost(it, e) {
  const me = ME(); const def = WD.itemDef(G, it);
  if (WD.lootNear(G, ui.me, it.iid)) return WD.lootCost(G, ui.me, it);
  let c = def.intel_cost; if (it.kind === 'att' && WD.ENVS[e.def].special === 'bench') c -= 1; return Math.max(0, c);
}
function gunArt(def) {
  if (typeof GUNART === 'undefined' || !def) return '';
  if (GUNART[def.id]) return GUNART[def.id];
  const pre = def.id.split('-')[0]; const t = +def.id.split('-')[1];
  const ks = Object.keys(GUNART).filter(k => k.split('-')[0] === pre).sort((a, b) => Math.abs(+a.split('-')[1] - t) - Math.abs(+b.split('-')[1] - t));
  return ks.length ? GUNART[ks[0]] : '';
}
function lootBack(kind, tier) {
  return `<span class="lb ${kind === 'weapon' ? 'lb-gun' : 'lb-card'} lt${tier}" aria-hidden="true"><span class="lb-in">${kind === 'weapon' ? `<b class="lb-big">LOOT</b><b class="lb-sub">GUN</b>` : `${ic('para')}<b>LOOT</b>`}${chev(tier)}</span></span>`;
}
const STACK_TIER = ['', 'tier I (Common guns and cards)', 'tier II (Uncommon–Rare guns, Rare cards)', 'tier III (Epic–Legendary guns, Epic cards)'];
function stackHTML(e, live, plan, printed) {
  const up = e.cache.searched; const items = up ? e.loot : (plan || []);
  const n = items.length;
  if (!n) return up ? '<span class="lstack empty"><span class="lb-ghost">Looted</span></span>' : '';
  const topKind = up ? items[0].kind : items[0];
  const shape = topKind === 'weapon' ? 'gun' : topKind === 'att' ? 'att' : 'card';
  const under = Math.min(n - 1, 3);
  const layers = Array.from({ length: under }, (_, i) => `<span class="ls-under" style="--i:${under - i}">${lootBack(up ? (items[under - i] || {}).kind : items[under - i], e.tier)}</span>`).join('');
  let top = up ? (ui.newTop === e.w ? lootFace(items[0], e, live).replace('class="lf ', 'class="lf fx-newtop ') : lootFace(items[0], e, live)) : lootBack(items[0], e.tier);
  if (printed) {
    if (up) { const fn = itemFace(items[0]); if (fn) { const cost = shownCost(items[0], e); top = `<${live ? 'button' : 'div'} data-flip="t${items[0].iid}" class="lf-p ${ui.newTop === e.w ? 'fx-newtop' : ''}" ${live ? `data-act="item" data-id="${items[0].iid}"` : ''} data-prev="it:${items[0].iid}" aria-label="${escA(WD.itemDef(G, items[0]).name)}">${pf(fn)}${cost !== WD.itemDef(G, items[0]).intel_cost ? `<span class="lf-cost now">${ic('intel')}${cost}</span>` : ''}${items[0].kind === 'weapon' ? gunCompact(WD.itemDef(G, items[0]), cost) : ''}</${live ? 'button' : 'div'}>`; } }
    else if (items[0] !== 'weapon') { const bn = 'back_loot_tier' + e.tier; if (hasFace(bn)) top = `<span class="lf-p back">${pf(bn)}</span>`; }
  }
  const tip = up ? `${n - 1} more face down under it. Cycle to dig.` : `Face-down loot stack, ${STACK_TIER[e.tier]}: ${items.map((k, i) => `${i === 0 ? 'top' : i + 1}: ${k === 'weapon' ? 'gun' : 'card'}`).join(', ')}. It flips face up when someone stands here.`;
  return `<span class="lstack s-${shape}" style="--u:${under}"><span class="ls-layers">${layers}</span><span class="ls-top">${top}</span>${n > 1 || !up ? `<span class="ls-n" data-tip="${escA(tip)}">${n}</span>` : ''}</span>`;
}
// upright, small-screen gun card for a face-up loot stack; CSS shows it instead of the printed (landscape) face when the stack is narrow
function gunCompact(def, cost) {
  const a = gunArt(def);
  return `<span class="lf-gc r${def.tier}" aria-hidden="true"><span class="gc-top"><b class="gc-nm">${def.name}</b><span class="gc-cls">${escA(GSHORT[def.cls] || def.cls)}</span></span>${a ? `<img class="gc-art" src="${a}" alt="">` : '<span class="gc-art"></span>'}<span class="gc-st"><span>${ic('rng')}${def.band[0]}–${def.band[1]}</span><span>${ic('dmg')}${def.ladder.map(([h, d]) => d).join('·')}</span></span><span class="gc-ft"><span class="gc-cost">${ic('intel')}${cost}</span><span class="rar r${def.tier}">${def.rarityName}</span></span></span>`;
}
function lootFace(it, e, live) {
  const def = WD.itemDef(G, it); const cost = shownCost(it, e);
  const kind = it.kind === 'card' ? 'tactical card' : it.kind === 'weapon' ? 'gun (comes loaded)' : 'attachment';
  const tag = live ? 'button' : 'div'; const act = (live ? `data-act="item" data-id="${it.iid}" ` : '') + `data-prev="it:${it.iid}"`;
  const tip = `data-tip="${escA(`${it.kind === 'weapon' ? wnm(def) : def.name} · ${kind} · ${cost} Intel. ${it.kind === 'card' ? def.text : it.kind === 'weapon' ? `Range ${def.band[0]}–${def.band[1]}, damage ${def.ladder.map(([h, d]) => `${h}+→${d}`).join(', ')}.` : def.text || ''} Face up: anyone standing here can buy it.`)}"`;
  const costB = `<span class="lf-cost">${ic('intel')}${cost}</span>`;
  if (it.kind === 'card') {
    const a = artURL(def);
    return `<${tag} class="lf lf-card a-${def.archetype}" style="${ARCH_VAR[def.archetype] ? `--arch:var(${ARCH_VAR[def.archetype]});` : ''}" ${act}><span class="lf-top">${ROLE_L[def.archetype] ? `<i class="lf-sh">${shapeSvg(def.archetype)}</i>` : ''}<b>${def.name}</b></span><span class="lf-txt">${fx(def.text)}</span>${a ? `<img class="lf-art" src="${a}" alt="">` : '<span class="lf-art"></span>'}<span class="lf-foot">${chev(def.tier)}${costB}</span></${tag}>`;
  }
  if (it.kind === 'weapon') {
    const a = gunArt(def);
    return `<${tag} class="lf lf-gun ${def.slot === 1 ? 'sec' : ''} r${def.tier}" ${act}><span class="lf-band">${def.ladder.map(([h, d]) => `<b>${d}</b>`).join('')}</span><span class="lf-gb"><span class="lf-top"><b>${def.name}</b></span>${a ? `<img class="lf-art" src="${a}" alt="">` : '<span class="lf-art"></span>'}<span class="lf-foot"><span class="rar r${def.tier}">${def.rarityName}</span>${costB}</span></span></${tag}>`;
  }
  return `<${tag} class="lf lf-att" ${act}><span class="lf-top"><b>${def.name}</b></span><span class="lf-txt">${def.text ? fx(def.text) : 'Attachment'}</span><span class="lf-foot">${costB}</span></${tag}>`;
}
function lootChip(it, e, live) {
  const def = WD.itemDef(G, it); const cost = shownCost(it, e);
  const kind = it.kind === 'card' ? 'tactical card' : it.kind === 'weapon' ? 'gun (comes loaded)' : 'attachment';
  const rs = it.kind === 'card' && ARCH_VAR[def.archetype] ? ` style="--arch:var(${ARCH_VAR[def.archetype]})"` : '';
  return `<${live ? 'button' : 'span'}${rs} class="loot-it ${it.kind} ${it.kind === 'weapon' ? 'lw' + def.tier : 'lrole'}" ${live ? `data-act="item" data-id="${it.iid}"` : ''} data-tip="${escA(def.name)} · ${kind} · ${cost} Intel. Face up: anyone standing here can buy it."><span>${it.kind === 'card' && ROLE_L[def.archetype] ? `<i class="lsh">${shapeSvg(def.archetype)}</i>` : ''}${it.kind === 'weapon' ? wnm(def) : def.name}</span><span class="k">${it.kind === 'card' ? chev(def.tier) : ''}${cost}</span></${live ? 'button' : 'span'}>`;
}
function fieldHTML() {
  const reach = ui.moveMode ? WD.reachable(G, ui.me) : [];
  const cl = WD.closing(G); const me = ME(); const final = WD.safeBounds(G).n <= 1; const FX = ui.fx || {}; const sched = WD.closeSchedule(G);
  const tiles = G.envs.map(e => {
    const d = WD.ENVS[e.def];
    const opt = reach.find(x => x.w === e.w);
    const toks = [ui.me, 1 - ui.me].map(i => G.players[i].pos === e.w ? tokHTML(i, G.players[i]) : '').join('');
    if (e.state === 'gas') {
      return `<div class="envw gasw" data-w="${e.w}" data-flip="w${e.w}"><div class="env-tok"></div><div class="env gas gasfx ${(FX.gassed || []).includes(e.w) ? 'fx-gassed' : ''} ${G.players.some(p => p.pos === e.w) ? 'occupied' : ''} ${opt ? 'reach' : ''}" ${opt ? `data-act="moveto" data-id="${e.w}" role="button" tabindex="0"` : ''} data-tip="Gas (was ${escA(d.name)}). In the gas at round end: ${WD.TUNE.gasDmg} damage +1 per extra space outside, then you are pushed back to the nearest safe location.">${G.players.map((pl, i) => pl.pos === e.w ? `<span class="tok ${i === ui.me ? 'me' : 'them'}" style="position:absolute;top:4px;left:2px;writing-mode:vertical-rl;padding:4px 1px">${i === ui.me ? 'YOU' : pl.name}</span>` : '').join('')}</div><div class="env-acts"></div></div>`;
    }
    const drop = (e.crate && !e.crate.searched) || (e.dropRound && e.dropRound === G.round - 1);
    const st = cl.includes(e.w) ? 'warn' : drop ? 'drop' : 'safe';
    const stLabel = cl.includes(e.w) ? 'Gas next' : drop ? 'Supply crate' : final ? 'Final circle' : e.fresh && !e.cache.searched ? 'New ground' : e.hot ? 'Centre' : 'Safe';
    const plan = !e.cache.searched ? WD.stackPlan(G, e) : null;
    const cache = plan ? `<span class="stackic ct${e.tier}" data-tip="${escA(`Face-down loot stack, ${STACK_TIER[e.tier]}: ${plan.map((k, i) => `${i === 0 ? 'top' : i + 1}: ${k === 'weapon' ? 'gun' : 'card'}`).join(', ')}. It flips face up when someone stands here. Only the top card can be bought.`)}">${plan.map(k => `<i class="${k === 'weapon' ? 'sg' : 'sc'}">${k === 'weapon' ? ic('ammo') : ''}</i>`).join('')}${chev(e.tier)}</span>` : '';
    const cacheOld = !e.cache.searched ? `<span class="cache ct${e.tier}" data-tip="Hidden cache, ${['', 'Common guns and cards', 'Uncommon–Rare guns and Rare cards', 'Epic–Legendary guns and Epic cards'][e.tier]}: Search here (once per turn) to flip ${e.cache.reveal} loot cards face up, then buy. Whatever you leave stays here for anyone.">${ic('search')} ${e.cache.reveal} · ${['', 'green', 'blue', 'purple+'][e.tier]}</span>` : '';
    const crate = drop ? `<span class="cache crate" data-tip="Supply crate: Search it to flip ${WD.TUNE.crate[0]} items (${WD.TUNE.crate[1]} guns).">Crate ${WD.TUNE.crate[0]}</span>` : '';
    const cover = d.cover ? `<span class="${d.cover > 1 ? 'cover-hard' : ''}">${d.cover > 1 ? 'Hard' : 'Cover'} −${d.cover}</span>` : '<span>No cover</span>';
    const bonusTxt = d.bonusText ? `<span class="bon">${fx(d.bonusText)}</span>` : '';
    const affTxt = d.affinity && !e.cache.searched ? `<span class="aff" style="--arch:var(${ARCH_VAR[d.affinity]})" data-tip="${escA(`This cache is mostly ${WD.ARCH_TAG[d.affinity]} cards.`)}">${ARCH_SHORT[d.affinity]}</span>` : '';
    const live = !ui.moveMode; const items = e.cache.searched ? e.loot : [];
    const lootList = items.length ? (ui.newTop === e.w ? lootFace(items[0], e, live).replace('class="lf ', 'class="lf fx-newtop ') : lootFace(items[0], e, live)) + (items.length > 1 ? `<span class="loot-more" data-tip="${items.length - 1} more card${items.length > 2 ? 's' : ''} face down under it. Cycle to dig.">+${items.length - 1} under</span>` : '') : '';
    const tip = `${d.name}. ${d.text} ${ARCH_SHORT[d.affinity]} loot: 2 in 3 fresh cards here are ${ARCH_SHORT[d.affinity]}.${cl.includes(e.w) ? ' Gas takes it at the end of this round, with any loot still here.' : sched[e.w] ? ` Closes at the end of round ${sched[e.w]}.` : ''} Tap for details.`;
    const rivalHere = OP().pos === e.w;
    const fxc = [FX.arrive === e.w ? 'fx-arrive' : '', FX.hurt === e.w ? 'fx-hurt' : '', FX.miss === e.w ? 'fx-miss' : '', FX.loot === e.w ? 'fx-loot' : '', (FX.appear || []).includes(e.w) ? 'fx-appear' : '', FX.shooter === e.w ? 'fx-shoot' : ''].join(' ');
    const cls = ['env', st, fxc, ui.moveMode ? (opt ? 'reach' : 'noreach') : '', me.pos === e.w ? 'here' : '', rivalHere ? 'rival' : '', e.hot ? 'hot' : '', e.fresh && !e.cache.searched ? 'fresh' : ''].join(' ');
    const float = FX.hurt === e.w ? `<span class="float hit">−${FX.dmg}</span>` : FX.miss === e.w ? '<span class="float miss">MISS</span>' : '';
    const bodyAct = opt ? `data-act="moveto" data-id="${e.w}"` : `data-act="loc" data-id="${e.w}"`;
    const T = myTurn(); const acts = [];
    // cycling lives in the location window
    if (false) acts.push(`<button class="tbtn search" data-act="search" data-tip="Flip the hidden loot face up (once per turn).">${ic('search')} Search · ${e.crate && !e.crate.searched ? 'crate' : e.cache.reveal}</button>`);
    if (T && rivalHere) {
      const bestGi = (fireOdds() || {}).gi; for (const gi of [0, 1]) { if (!me.guns[gi] || (bestGi != null && gi !== bestGi)) continue; const fo = fireOdds(gi); if (fo && fo.pct != null) acts.push(`<button class="tbtn fire" data-act="tfire" data-id="${gi}" data-tip="${escA(`Fire ${wnm(wdef(me.guns[gi]))}: reveal ${fo.sp.reveal}, damage ladder ${fo.sp.steps.map(([h, d]) => `${h}+→${d}`).join(', ')}. ${fo.sp.left} shot(s) left.`)}">${ic('fire')} ${escA(wdef(me.guns[gi]).cls)} ${fo.pct}%</button>`); }
      if (me.pos === e.w && !me.punched && !acts.some(a => a.includes('tfire'))) acts.push(`<button class="tbtn fire" data-act="dofists">Punch · 1</button>`);
    }
    const mc = WD.moveCost(G, ui.me, e.w);
    if (T && !me.moved && e.w !== me.pos && mc != null && mc <= me.res.move) acts.push(`<button class="tbtn move" data-act="moveto" data-id="${e.w}" data-tip="Your one Move this turn: ${Math.abs(e.w - me.pos)} space(s)${mc > Math.abs(e.w - me.pos) ? ` + ${mc - Math.abs(e.w - me.pos)} to get into cover` : ''} = ${mc} Movement.">${ic('move')} Move · ${mc}</button>`);
    acts.length = 0; // Fire / Move live in the dock now
    const lf = locFaceName(e);
    const shut = sched[e.w];
    const chips = `${opt ? `<span class="echip mv">${ic('move')} ${mc != null ? mc : opt.cost}</span>` : ''}${cl.includes(e.w) ? '<span class="echip gasn" title="Gas closes it at the end of this round">GAS NEXT</span>' : shut ? `<span class="echip shut" title="Gas closes it at the end of round ${shut}">gas R${shut}</span>` : final ? '' : '<span class="echip shut fin" title="Never closes: this is the final circle">FINAL</span>'}${drop ? '<span class="echip crate">Crate</span>' : ''}${e.hot ? '<span class="echip hot">Centre</span>' : ''}${e.phase ? `<span class="echip phasechip ph${e.phase}">P${e.phase}</span>` : ''}`;
    const covI = d.cover ? `<span class="lp-cov ${d.cover > 1 ? 'hard' : ''}" title="${d.cover > 1 ? 'Hard cover' : 'Cover'}: shots at you here deal −${d.cover}">${ic('def')}−${d.cover}</span>` : '<span class="lp-cov none" title="No cover">open</span>';
    const arr = d.bonus ? bonusChip(d) : '';
    return `<div class="envw ${cls.replace(/\benv\b/, '')} ${ui.arrivedAt === e.w && !ui.play ? 'me-arrive' : ''} ${ui.fx && ui.fx.leave === e.w ? 'fx-leave' : ''}" data-w="${e.w}" data-flip="w${e.w}"><div class="${cls} lcol ${myTurn() && !ui.moveMode && e.cache.searched && e.loot.length ? (e.w === me.pos ? 'buy-here' : Math.abs(e.w - me.pos) === 1 ? 'buy-near' : '') : ''}" data-tip="${escA(tip)}" ${typeof LOCART !== 'undefined' && LOCART[e.def] ? `style="--lart:url(${LOCART[e.def]})"` : ''}>${float}
        <div class="lc-stack" ${bodyAct}>${myTurn() && !ui.moveMode && e.cache.searched && e.loot.length && Math.abs(e.w - me.pos) === 1 ? `<span class="near-cost">+${WD.TUNE.adjCost}${ic('intel')}</span>` : ''}${crate}${stackHTML(e, live, plan, true)}</div>
        <div class="lc-plate" ${bodyAct} ${lf ? `data-prev="loc:${e.w}"` : ''}>${toks || chips ? `<span class="lp-tags">${toks}${chips}</span>` : ''}<b class="lp-name">${d.name}</b><span class="lp-row">${arr}${d.cover ? `<span class="lp-shield" title="Cover: hits on you here −${d.cover}">${ic('def')}</span>` : ''}</span></div>
      </div></div>`;
  }).join('');
  const o = OP(); const d = WD.dist(G);
  const oenv = WD.envAt(G, o.pos); const od = WD.ENVS[oenv.def];
  const covTxt = me.pos === o.pos ? ' · <b>close quarters</b>: no cover' : od.cover && oenv.state === 'safe' ? ` · ${o.name} has cover −${od.cover}` : '';
  const bands = WD.guns(me).map(w => WD.eff(G, w).band); const inB = bands.some(b => d >= b[0] && d <= b[1]); const sweet = WD.guns(me).some(w => WD.eff(G, w).max_range === d);
  const rangeTxt = bands.length ? (inB ? ` · in range` : ` · <span style="color:var(--danger)">out of range</span>`) : '';
  const mini = `<span class="mini" role="img" aria-label="You at location ${me.pos + 1}, rival at ${o.pos + 1}, distance ${d}">${G.envs.map(e => { const y = me.pos === e.w, r = o.pos === e.w; return `<i class="${e.state} ${cl.includes(e.w) ? 'ne' : ''} ${y && r ? 'yr' : y ? 'y' : r ? 'r' : ''}">${y && r ? '' : y ? 'Y' : r ? 'R' : ''}</i>`; }).join('')}</span>`;
  return `<section class="fieldwrap" aria-label="Battlefield"><div class="field-head"><span class="lbl">The circle</span>${mini}<span class="fh-note">${final ? '<b style="color:var(--danger)">Final circle</b>' : `Closes after rounds ${WD.TUNE.closeAfter.filter(r => r >= G.round).join(', ')}`}</span><span class="distchip">Distance ${d}${rangeTxt}${covTxt}</span><span class="ophp">${o.name} <b class="mono">${Math.max(0, o.hp)}</b>/${HPMAX()}</span></div>
    <div class="field" id="field">${tiles}</div></section>`;
}

function mtabsHTML(me, op) {
  const ready = me.guns.some(w => w && !G.weapons[w].used) && myTurn() && me.hand.length > 0;
  const t = (id, label, extra) => `<button class="${ui.tab === id ? 'on' : ''}" data-act="mtab" data-id="${id}">${label}${extra || ''}</button>`;
  return `<nav class="mtabs" aria-label="Panels">${t('hand', 'Hand', ` <b>${me.hand.length}</b>`)}${t('guns', 'Guns', ready ? ' <i class="dot" title="Tactical ready"></i>' : '')}${t('intel', 'Rival · Log', ` <b>${Math.max(0, op.hp)}</b>`)}</nav>`;
}
function oppHTML(op) {
  const w = id => { if (!id) return ''; return `<button class="mini-wep" data-act="wview" data-id="${id}" data-tip="Tap to see ${escA(wnm(wdef(id)))}"><b>${wnm(wdef(id))}</b><span class="mono">${WD.eff(G, id).magazine_capacity} shots</span></button>`; };
  const g = WD.guns(op);
  return `<section class="op opp" aria-label="Opponent">
    <div class="op-head"><span class="op-name">${op.name}</span><span class="op-meta"><span>Hand <b class="mono">${op.hand.length}</b></span><span>Deck <b class="mono">${op.deck.length + op.discard.length + op.hand.length + op.play.length}</b></span></span></div>
    ${hpHTML(op)}
    <div class="opp-weps">${g.length ? g.map(w).join('') : '<span class="lbl">Unarmed</span>'}</div>
    ${WD.TUNE.perks ? perksHTML(1 - ui.me, true) : ''}
  </section>`;
}
function hpHTML(pl) {
  const pct = Math.max(0, pl.hp) / HPMAX() * 100;
  return `<div class="hp"><div class="hpbar ${pl.hp <= 9 ? 'low' : ''}" role="img" aria-label="Health ${pl.hp} of ${HPMAX()}"><i style="width:${pct}%"></i></div><span class="mono hpv"><span class="c-hp">${ic('heart')}</span>${Math.max(0, pl.hp)}/${HPMAX()}</span>
    <span class="chips">${pl !== ME() ? '' : `<span class="chip" data-tip="Reaction cards in this hand: they cut damage when hit.">${ic('def', 'c-def')}${pl.hand.filter(i => WD.cardDef(G, i).reaction).length ? pl.hand.filter(i => WD.cardDef(G, i).reaction).map(i => '−' + WD.cardDef(G, i).reaction).join(' ') : '—'}</span>`}${pl.suppressed ? `<span class="chip warn">Supp +${pl.suppressed}</span>` : ''}</span></div>`;
}
const ARCH_SHORT = { assault: 'Assault', support: 'Support', recon: 'Recon', engineer: 'Engineer' };
const ROLE_L = { assault: '▲', recon: '◉', support: '■', engineer: '✚' };
const ROLE_ORDER = { assault: 0, recon: 1, engineer: 2, support: 3, supply: 4, starter: 5 };
const SHAPE = {
  assault: '<path d="M12 2.5 20.5 21 12 16.2 3.5 21z" fill="currentColor"/>',
  recon: '<path d="M12 2.6l2.75 6.1 6.65.6-5.05 4.4 1.5 6.5L12 16.8l-5.85 3.4 1.5-6.5L2.6 9.3l6.65-.6z" fill="currentColor"/>',
  support: '<path d="M12 2.2 20.5 5.4v6.1c0 5.1-3.6 8.7-8.5 10.3-4.9-1.6-8.5-5.2-8.5-10.3V5.4z" fill="currentColor"/>',
  engineer: '<path fill-rule="evenodd" d="M18.62 9.71 L18.64 9.80 L21.91 9.58 L21.91 14.42 L18.64 14.20 L18.62 14.29 L18.29 15.06 L18.26 15.14 L20.72 17.29 L17.29 20.72 L15.14 18.26 L15.06 18.29 L14.29 18.62 L14.20 18.64 L14.42 21.91 L9.58 21.91 L9.80 18.64 L9.71 18.62 L8.94 18.29 L8.86 18.26 L6.71 20.72 L3.28 17.29 L5.74 15.14 L5.71 15.06 L5.38 14.29 L5.36 14.20 L2.09 14.42 L2.09 9.58 L5.36 9.80 L5.38 9.71 L5.71 8.94 L5.74 8.86 L3.28 6.71 L6.71 3.28 L8.86 5.74 L8.94 5.71 L9.71 5.38 L9.80 5.36 L9.58 2.09 L14.42 2.09 L14.20 5.36 L14.29 5.38 L15.06 5.71 L15.14 5.74 L17.29 3.28 L20.72 6.71 L18.26 8.86 L18.29 8.94Z M12 9.2 a2.8 2.8 0 1 0 0.001 0Z" fill="currentColor"/>',
};
const shapeSvg = r => `<svg class="shp" viewBox="0 0 24 24" aria-hidden="true">${SHAPE[r] || ''}</svg>`;
const TIER_WORD = ['', 'Common', 'Rare', 'Epic']; // tier-1 loot is Common, like the tier-1 guns in it
function chev(t) { return t ? `<svg class="rank" viewBox="0 0 24 ${6 + 7 * t}" role="img" aria-label="${TIER_WORD[t] || ''}"><title>${TIER_WORD[t] || ''}</title>${Array.from({ length: t }, (_, i) => `<path d="M3 ${11 + 7 * i} 12 ${4 + 7 * i} 21 ${11 + 7 * i}" fill="none" stroke="currentColor" stroke-width="3.6"/>`).join('')}</svg>` : ''; }
function roleB(r, on) { return `<span class="roleb ${on === false ? 'dim' : ''}" style="--arch:var(${ARCH_VAR[r]})" title="${ARCH_SHORT[r]}">${shapeSvg(r)}</span>`; }
const ARCH_VAR = { assault: '--ro-a', support: '--ro-s', recon: '--ro-r', engineer: '--ro-e' };
const RES_IC = { move: 'move', prec: 'prec', intel: 'intel', def: 'def' };
function perkTrig(L) { return L.trig ? `${ic(RES_IC[L.trig.res])}${L.trig.n}+` : ''; }
function perksHTML(pi, compact) {
  const pl = G.players[pi]; const own = pl.perks || [];
  if (!own.length) return `<div class="perks none"><span class="lbl">Perks</span><span style="color:var(--muted);font-size:11.5px">${pl.perkOffer ? 'drafting…' : 'none yet'}</span></div>`;
  return `<div class="perks ${compact ? 'compact' : ''}">${own.map(k => { const L = WD.LOADOUT[k]; const fired = (pl.perkFired || []).includes(k); const prog = L.trig && pl.gen ? Math.min(pl.gen[L.trig.res], L.trig.n) : null;
    return `<span class="lperk ${fired ? 'fired' : ''}" style="--arch:var(${ARCH_VAR[L.arch] || '--muted'})" data-tip="${escA(`${L.name}: ${L.text}`)}"><b>${L.name}</b>${L.trig ? `<small>${fired ? '✓ this turn' : `${perkTrig(L).replace(/\d+\+$/, '')}${prog}/${L.trig.n}`}</small>` : '<small>always on</small>'}</span>`; }).join('')}</div>`;
}
function mePanelHTML(me) {
  const st = [];
  if (me.nextFire.reqMod) st.push(`Next shot −${me.nextFire.reqMod} Hit`);
  if (me.nextFire.bonusPrec) st.push(`Next shot +${me.nextFire.bonusPrec} Prec`);
  if (me.recoilTurn) st.push(`Ignore ${me.recoilTurn} recoil`);
  if (me.shot) st.push(`+${me.shot} extra shot${me.shot > 1 ? 's' : ''}`);
  if (me.lootDiscount) st.push(`Buy −${me.lootDiscount}`);
  if (me.suppressArm) st.push('Suppression armed');
  if (me.scrapAvail) st.push(`${ic('scrap')} Scrap ${me.scrapAvail} ready`);
  if (me.freeAmmo) st.push(`<span class="c-ammo">${ic('ammo')}</span>${me.freeAmmo} free bullet${me.freeAmmo > 1 ? 's' : ''}`);
  if (me.magBonus) st.push(`<span class="c-mag">${ic('mag')}</span>+${me.magBonus} magazine`);
  if (me.ignoreCover) st.push('Ignore cover');
  if (me.revealPlus) st.push(`Shots reveal +${me.revealPlus}`);
  if (myTurn()) { const rp = WD.rolesPlayed(G, ui.me); st.unshift(`<span data-tip="${escA(`Roles played this turn. 3 roles = SQUAD: ${WD.SQUAD_TEXT[3]}. All 4 = FULL SQUAD: ${WD.SQUAD_TEXT[4]}. Your primary gun counts as one squad member.`)}">Squad ${['assault', 'recon', 'support', 'engineer'].map(r => roleB(r, rp.has(r))).join('')}${me.squad4 ? ' <b>FULL SQUAD</b>' : me.squad3 ? ' <b>SQUAD</b>' : ''}</span>`); }
  if (me.fuelled && me.fuelled.length) st.push(`Loaded: ${me.fuelled.map(i => WD.cardDef(G, i).name).join(', ')}`);
  const tips = { move: 'Movement: 1 per space. Expires at the end of your turn.', prec: 'Precision is your aim: each shot reveals that many cards. It is not spent, but every shot lowers it by the gun’s Recoil.', intel: 'Intel buys loot. Spend it this turn — unspent Intel is lost when you end your turn.' };
  return `<section class="op mine" aria-label="Your operator">
    <div class="op-head"><span class="op-name">${nameMe()}</span><span class="op-meta"><span>Draw <b class="mono">${me.deck.length}</b></span><span class="dcount">Discard <b class="mono">${me.discard.length}</b></span><span data-tip="Every card you own.">Deck <b class="mono">${me.deck.length + me.discard.length + me.hand.length + me.play.length}</b></span></span></div>
    ${hpHTML(me)}
    <div class="res r3">${['move', 'prec', 'intel'].map(k => `<div class="${me.res[k] ? '' : 'zero'}" data-tip="${escA(tips[k])}"><b class="c-${k}">${me.res[k]}</b><span>${ic(k, 'c-' + k)}${{ move: 'Move', prec: 'Prec', intel: 'Intel' }[k]}</span></div>`).join('')}</div>
    ${perksHTML(ui.me)}
    ${st.length ? `<div class="statusline">${st.map(x => `<span class="chip warn">${x}</span>`).join('')}</div>` : ''}
  </section>`;
}
function wepsHTML(me) {
  const slot = gi => {
    const iid = me.guns[gi]; const nm = gi === 0 ? 'Primary' : 'Secondary';
    if (!iid) return `<div class="wcard"><div class="w-slot"><span>${nm}</span></div><div class="wempty">${gi === 0 ? 'No primary yet. Buy an SMG, shotgun, rifle, LMG or sniper from a loot stack.' : 'Empty. Loot stacks also hold pistols, revolvers and knives.'}</div></div>`;
    const def = wdef(iid); const t = myTurn(); const fo = t ? fireOdds(gi) : null;
    const gc = def.gcombo; const lit = gc && (me.gunCombo === G.turnNo);
    return `<div class="wcard active rr${def.tier}"><div class="w-slot"><span>${nm}<span class="wsn"> · ${wnm(def)}</span> <span class="rar r${def.tier}">${def.rarityName}</span></span><span class="ready on">${WD.shotsLeft(G, ui.me, gi)} shot${WD.shotsLeft(G, ui.me, gi) === 1 ? '' : 's'} left</span></div>
      <div class="w-body"><div class="w-name"><span data-act="wview" data-id="${iid}" style="cursor:pointer" data-tip="Tap for the full gun card.">${wnm(def)}</span></div>
      ${statsHTML(iid, def)}
      ${gc ? `<div class="tc-combo ${lit ? 'lit' : ''}" data-tip="${escA(`Gun combo: when you play a ${ARCH_SHORT[gc.role]} card this turn — ${gc.text}`)}"><span class="cmb">COMBO ${roleB(gc.role)}</span> ${fx(gc.text)}</div>` : '<div class="tc-combo" style="opacity:.6">Secondary: no combo.</div>'}
      <div class="wbtns"><button class="btn sig sm wide" data-act="fire" data-id="${gi}" ${fo && fo.pct != null ? '' : 'disabled'} data-tip="${escA(fo && fo.err ? fo.err : 'Load a card as a bullet and fire.')}">${fo && fo.pct != null ? `Fire · ${fo.pct}%` : (fo && fo.err && /ammo/.test(fo.err) ? 'No ammo' : 'Fire')}</button></div>
      </div></div>`;
  };
  return `<section class="weps" aria-label="Your guns">${slot(0)}${slot(1)}</section>`;
}
function handHTML(me) {
  const many = me.hand.length > 4; const t = myTurn();
  const bench = t && WD.canBench(G, ui.me) && me.hand.length;
  const playable = t && me.hand.some(i => !WD.cardDef(G, i).jam);
  return `<div class="hand-head"><span class="lbl" style="white-space:nowrap">${t ? 'Hand' : 'Next hand'} · ${me.hand.length}</span>${playable ? '<button class="btn sm sig burnbtn" data-act="playall" data-tip="Play every card in your hand (Malfunction stays).">Play all</button>' : ''}${bench ? `<button class="btn sm ${ui.burnMode ? 'sig' : 'alt'} burnbtn" data-act="burnmode" data-tip="Workbench: once per turn, remove a card from your hand from the game. Free.">${ui.burnMode ? 'Tap a card to burn · cancel' : '🔥 Burn 1'}</button>` : ''}<span class="note">Tap a card to play it · hold for details · keep cards as bullets</span></div>
    <div class="hand ${many ? 'many' : ''} ${ui.burnMode ? 'burning' : ''}">${me.hand.slice().sort((a, b) => (ROLE_ORDER[WD.cardDef(G, a).archetype] ?? 9) - (ROLE_ORDER[WD.cardDef(G, b).archetype] ?? 9)).map(iid => cardHTML(WD.cardDef(G, iid), { act: ui.burnMode ? 'burn' : 'cardview', id: iid, prev: 'hc:' + iid })).join('') || `<span class="empty-hand">${t ? 'Hand empty. Move, search, buy and shoot — then End turn.' : 'Your next hand appears here.'}</span>`}</div>
    ${t ? (() => { const pc = WD.plateCost(G, ui.me); const ok = me.res.intel >= pc; return `<div class="buystation"><span class="lbl">Buy Station · always open · ${ic('intel')}${pc} each</span><div class="bs-row">${WD.TUNE.station.map(id => { const k = WD.CARDS[id]; const left = G.stationLeft ? G.stationLeft[id] : null; return `<button class="bscard" style="${ARCH_VAR[k.archetype] ? `--arch:var(${ARCH_VAR[k.archetype]})` : ''}" data-act="supply" data-id="${id}" ${ok && left !== 0 ? '' : 'disabled'} data-tip="${escA(`${k.name}: ${k.text} Buy anywhere, any turn, as many as you can afford. Goes to your discard pile.`)}"><b>${k.name}</b><span>${fx(k.text)}</span><span class="bsl">${hmPips(k.hit_markers)}${left != null ? `<small>${left} left</small>` : ''}</span></button>`; }).join('')}</div></div>`; })() : ''}
    ${me.play.length ? `<div class="inplay">Played: ${me.play.map(i => WD.cardDef(G, i).name).join(', ')}</div>` : ''}`;
}
function logHTML() {
  const items = G.log.filter(l => !/:\s*\.$/.test(l.msg)).slice(-90).reverse();
  return `<section class="logbox"><div class="lh lbl">Combat log</div><ol>${items.map(l => `<li class="${l.cls}">${l.msg}</li>`).join('')}</ol></section>`;
}
function abarHTML(me) {
  const t = myTurn(); const here = WD.envAt(G, me.pos); const lootN = here.loot.length;
  const sch = WD.searchable(G, ui.me); const fo = t ? fireOdds() : null; const same = me.pos === OP().pos;
  const canPunch = t && same && !me.punched;
  const btn = (act, label, icon, sub, tip, dis, extra = '') => `<button class="abtn ${extra}" data-act="${act}" ${!t || dis ? 'disabled' : ''} data-tip="${escA(tip)}">${ic(icon)}<span>${label}</span>${sub ? `<small>${sub}</small>` : ''}</button>`;
  const fireSub = fo && fo.pct != null ? `${fo.pct}% · ${fo.sp.reveal} cards` : canPunch ? 'punch 1' : WD.guns(me).length ? 'no shot' : 'unarmed';
  const chips = t ? [`<span class="chip ${me.moved ? 'used' : ''}">${me.moved ? 'Moved' : me.res.move ? `Move ready · ${me.res.move}` : 'No Movement'}</span>`].join('') : '';
  const kit = t ? `<button class="chip cbtn kit" data-act="supply" ${me.res.intel >= WD.TUNE.supplyCost ? '' : 'disabled'} data-tip="Supply line: buy a Field Kit anywhere, any time, for ${WD.TUNE.supplyCost} Intel (Gain 1 Intel and 1 Precision; 1 Hit Marker). It goes to your discard pile.">+ Field Kit · ${ic('intel')}${WD.TUNE.supplyCost}</button>` : '';
  const scr = t && me.scrapAvail ? `<button class="chip cbtn scr" data-act="scrapsheet" data-tip="Remove a card in your discard pile from the game.">${ic('scrap')} Scrap ${me.scrapAvail}</button>` : '';
  return `<nav class="abar" aria-label="Turn">
    <div class="abar-info"><span class="abar-hint">${t ? 'Tap the map to act' : G.over ? 'Match over' : `${OP().name} is playing`}</span>${chips}${scr}</div>
    <div class="abtns two">${btn('playall', 'Play all', 'hm', me.hand.length ? `${me.hand.length} cards` : 'hand empty', 'Play every card in your hand.', !me.hand.some(i => !WD.cardDef(G, i).jam))}<button class="abtn end" data-act="endturn" ${t ? '' : 'disabled'} data-tip="End your turn: unspent Intel and Scrap are lost, discard everything (Boost fuel too), draw 5. Armor stays up until your next turn.">${ic('end')}<span>End turn</span><small>draw 5</small></button></div>
  </nav>`;
}

// ---------- sheets ----------
function renderLayer() {
  if (!ui.sheet && ui.pendingTb && !ui.tb) { const p = ui.pendingTb; ui.pendingTb = null; setTimeout(() => turnBanner(...p), 120); }
  const parts = {
    handoff: ui.handoff ? `<div class="hand-off"><div><div class="lbl">Pass &amp; play</div><h2>Pass to ${G.players[G.turn].name}</h2><p style="color:var(--muted)">Hands stay hidden until the next operator taps.</p><button class="btn sig" data-act="takeover">I'm ${G.players[G.turn].name} — show my hand</button></div></div>` : '',
    sheet: ui.sheet ? `<div class="scrim" data-act="scrim"><div class="sheet ${['codex', 'rules', 'loot', 'item', 'loc', 'scrap', 'perk', 'load'].includes(ui.sheet.type) ? 'wide' : ''}" role="dialog" aria-modal="true">${sheetHTML()}</div></div>` : '',
    banner: ui.play ? `<button class="rv-skip" data-act="skipplay" aria-label="Skip the rival's turn">▸▸</button>` : '',
    tb: ui.tb ? `<div class="turnban ${ui.tb.cls}" role="status"><b>${ui.tb.txt}</b><small>${ui.tb.sub}</small></div>` : '',
    toast: ui.toast ? `<div class="toast" role="status">${ui.toast}</div>` : '',
  };
  // patch only the slots that changed, so open sheets don't flicker or replay their entrance
  for (const k in parts) {
    let slot = layer.querySelector(`:scope > [data-slot="${k}"]`);
    if (!slot) { slot = document.createElement('div'); slot.dataset.slot = k; slot.style.display = 'contents'; layer.appendChild(slot); }
    if (slot._h !== parts[k]) {
      const sc = k === 'sheet' && slot.querySelector('.sheet'); const top = sc ? sc.scrollTop : 0; const same = sc && slot._type === (ui.sheet && ui.sheet.type);
      slot.innerHTML = parts[k]; slot._h = parts[k]; slot._type = ui.sheet && ui.sheet.type;
      if (same) { const n = slot.querySelector('.sheet'); if (n) { n.scrollTop = top; n.classList.add('still'); } }
    }
  }
}
function headIntel(title) {
  const me = ME(); const v = me.res.intel, mv = me.res.move;
  return `<div class="sheet-head"><h2>${title}</h2><span class="intel-big" title="Intel you can spend this turn">${ic('intel')}<b data-num="sheet-intel">${v}</b><small>Intel</small></span><span class="intel-big mv" title="Movement (can pay for a cycle)">${ic('move')}<b>${mv}</b></span><button class="iconbtn x" data-act="close" aria-label="Close">✕</button></div>`;
}
function head(title) { return `<div class="sheet-head"><h2>${title}</h2><button class="iconbtn x" data-act="close" aria-label="Close">✕</button></div>`; }
function preview(fn) { const clone = JSON.parse(JSON.stringify(G)); const r = fn(clone); return r.ok ? r.out.join(', ') : r.err; }

function lootSheet(S) {
  const me = ME();
  const env = S.type === 'item' ? G.envs.find(e => e.loot.some(i => i.iid === S.id)) : S.type === 'loc' ? WD.envAt(G, S.w) : WD.envAt(G, me.pos);
  if (!env) return head('Loot') + '<p>That item is gone.</p>';
  const adj = Math.abs(env.w - me.pos) === 1 && env.state === 'safe'; const here = env.w === me.pos || adj;
  if (S.type === 'item' && here && !S.converted) { S.sel = [S.id]; S.converted = true; }
  S.sel = (S.sel || []).filter(id => env.loot.some(x => x.iid === id)); S.trade = S.trade || []; S.fresh = S.fresh || [];
  const d0 = WD.ENVS[env.def]; const canBuy = myTurn() && here; const items = env.cache.searched ? env.loot.slice(0, 1) : [];
  const info = `<div class="preview"><span><b>${d0.name}</b> · ${d0.cover ? `cover −${d0.cover}` : 'no cover'}${env.hot ? ' · centre' : ''}</span><span>${fx(d0.text)}</span>${!env.cache.searched ? `<span>Hidden cache: ${env.cache.reveal} cards. Search here to flip them.</span>` : ''}${env.crate && !env.crate.searched ? `<span>Supply crate: ${WD.TUNE.crate[0]} items, ${WD.TUNE.crate[1]} of them guns.</span>` : ''}</div>`;
  const lfn = locFaceName(env);
  let h = headIntel(S.fresh.length ? `Search · ${envName(env)}` : here ? `${envName(env)} · buy${adj ? ' from next door' : ''}` : envName(env)) + (S.fresh.length ? `<p style="margin:0">Flipped face up. Buy what you want; the rest <b>stays here</b> for anyone — including your rival.</p>` : lfn ? '' : info);
  if (adj && items.length) h += `<div class="adjnote">${ic('intel')} Buying from next door: <b>+${WD.TUNE.adjCost} Intel</b> per item (already in the prices).</div>`;
  if (!here && items.length) h += `<div style="color:var(--muted);font-size:13px">Move to ${envName(env)} or next to it to buy here.</div>`;
  const total = WD.buyTotal(G, ui.me, S.sel);
  const gunSel = S.sel.some(id => (items.find(x => x.iid === id) || {}).kind === 'weapon');
  const attSel = S.sel.some(id => (items.find(x => x.iid === id) || {}).kind === 'att');
  const slide = S.slideIn; S.slideIn = false;
  h += `<div class="lootlist ${slide ? 'slidein' : ''}">${items.map(it => {
    const def = WD.itemDef(G, it); const cost = shownCost(it, env); const on = S.sel.includes(it.iid);
    let body = it.kind === 'card' ? `${hmPips(def.hit_markers)}<span>${fx(def.text)}</span>${def.reaction ? `<span style="color:var(--muted)">Reaction: −${def.reaction} damage when hit</span>` : ''}` : it.kind === 'weapon' ? `${statsHTML(null, def)}<div class="mods">${def.mods.length ? def.mods.map(m => `<span class="mod">${m}</span>`).join('') : '<span class="mod none">No attachments</span>'}</div><span>${def.slot === 1 ? 'Secondary slot.' : 'Primary slot (replaces your primary).'} ${def.gcombo ? `<b>Combo</b> ${roleB(def.gcombo.role)} ${fx(def.gcombo.text)}` : ''}</span>` : `<span>${fx(def.text)}</span>${(def.combos || []).map(c => `<span style="color:var(--muted)">${[].concat(c.role).map(r => roleB(r)).join('/')} ${fx(c.text)}</span>`).join('')}`;
    const fn = itemFace(it); if (fn) return `<div class="lootwrap pfw"><button class="lootpick pfp ${on ? 'on' : ''}" data-act="pickloot" data-id="${it.iid}" ${canBuy ? '' : 'disabled'} aria-label="${escA(def.name)}">${pf(fn)}<span class="pf-buy ${canBuy && cost > me.res.intel ? 'short' : ''}">${on ? '✓ Selected' : canBuy ? (cost > me.res.intel ? `Need ${cost - me.res.intel} more` : 'Tap to select') : ''}<span class="cost">${ic('intel')}${cost}</span></span></button></div>`;
    return `<div class="lootwrap"><button class="lootpick ${on ? 'on' : ''}" data-act="pickloot" data-id="${it.iid}" ${canBuy ? '' : 'disabled'}><span class="lk">${it.kind === 'card' ? `${WD.NEIGHBOURS[def.archetype] ? `${roleB(def.archetype)}${def.tags[0]} ${chev(def.tier)}` : 'Card'} · to discard` : it.kind === 'weapon' ? `<span class="rar r${def.tier}">${def.rarityName}</span> ` + def.cls + ' · loaded' : 'Attachment'}${S.fresh.includes(it.iid) ? ' · new' : ''}</span><span class="ln"><span>${def.name}</span><span class="cost">${ic('intel')}${cost}</span></span>${body}</button></div>`;
  }).join('') || '<p style="color:var(--muted)">No face-up loot here.</p>'}</div>`;
  if (lfn) h = h.replace('<div class="lootlist', `<div class="locsheet"><div class="ls-loc"><div class="envf">${pf(lfn)}<div class="zoneov">${stackHTML(env, false, !env.cache.searched ? WD.stackPlan(G, env) : null, true)}</div></div></div><div class="ls-right"><div class="lootlist`) + '<!--LSR-->';
  if (env.cache.searched && env.loot.length > 1) h += `<div class="stacknote">${env.loot.length - 1} more card${env.loot.length > 2 ? 's' : ''} face down underneath${env.loot.slice(1).some(x => x.seen) ? ` (seen before: ${env.loot.slice(1).filter(x => x.seen).map(x => WD.itemDef(G, x).name).join(', ')})` : ''}.</div>`;
  if (!env.cache.searched) h += `<div class="stacknote">Face-down stack: ${WD.stackPlan(G, env).map((k, i) => `${i === 0 ? 'top' : '#' + (i + 1)} ${k === 'weapon' ? 'gun' : 'card'}`).join(' · ')}. It flips when someone stands here.</div>`;
  if (myTurn() && env.w === me.pos && env.cache.searched && env.loot.length > 1) {
    const free = me.freeCycles > 0 || (me.perks.includes('spotter') && false);
    h += `<div class="row cyclerow"><span class="lbl">Cycle the top card to the bottom</span>${free ? `<button class="btn sm sig" data-act="cycle" data-id="intel">${ic('cyc')} Cycle · free</button>` : `<button class="btn sm alt" data-act="cycle" data-id="intel" ${me.res.intel >= WD.TUNE.cycleCost ? '' : 'disabled'}>${ic('cyc')} ${ic('intel')}${WD.TUNE.cycleCost} Intel</button><button class="btn sm alt" data-act="cycle" data-id="move" ${me.res.move >= WD.TUNE.cycleCost ? '' : 'disabled'}>${ic('cyc')} ${ic('move')}${WD.TUNE.cycleCost} Movement</button>`}</div>`;
  }
  if (canBuy && items.length) {
    const g = me.guns;
    if (gunSel && g[0] && g[1]) h += `<div class="row"><span>Drop:</span>${[0, 1].map(i => `<button class="btn sm ${(S.replace ?? 0) === i ? 'sig' : 'alt'}" data-act="lootopt" data-id="replace:${i}">${wnm(wdef(g[i]))}</button>`).join('')}</div>`;
    if (attSel && g[0] && g[1]) h += `<div class="row"><span>Mount on:</span>${[0, 1].map(i => `<button class="btn sm ${(S.attachTo ?? 0) === i ? 'sig' : 'alt'}" data-act="lootopt" data-id="attach:${i}">${wnm(wdef(g[i]))}</button>`).join('')}</div>`;
    const noMount = attSel && !WD.guns(me).length;
    const starters = me.hand.filter(i => WD.isStarter(G, i)); S.trade = S.trade.filter(i => starters.includes(i));
    const tv = S.trade.length * WD.TUNE.tradeIn; const short = Math.max(0, total - me.res.intel);
    if (S.sel.length && WD.TUNE.tradeIn) h += `<div class="tradein"><span class="lbl">Trade in starters from your hand · +${WD.TUNE.tradeIn} Intel each, burned for good</span><div class="row">${starters.map(i => `<button class="btn sm ${S.trade.includes(i) ? 'sig' : 'alt'}" data-act="trade" data-id="${i}">${WD.cardDef(G, i).name}</button>`).join('') || '<span style="color:var(--muted);font-size:13px">No starter cards in hand.</span>'}</div></div>`;
    const ok = S.sel.length && total <= me.res.intel + tv && tv <= total && !noMount;
    const msg = !S.sel.length ? 'Tap items to select them.' : noMount ? 'Get a gun before an attachment.' : tv > total ? 'Trade in only what you need.' : total > me.res.intel + tv ? `Short by ${short - tv} Intel.` : `You have ${me.res.intel} Intel.`;
    h += `<div class="row"><button class="btn sig" data-act="dolot" ${ok ? '' : 'disabled'}>Buy ${S.sel.length || ''} · ${total} Intel${tv ? ` (${tv} trade-in)` : ''}</button><span style="color:${S.sel.length && !ok ? 'var(--danger)' : 'var(--muted)'};font-size:13px">${msg}</span><button class="btn alt" data-act="close">Done</button></div>`;
  }
  if (h.includes('<!--LSR-->')) h = h.replace('<!--LSR-->', '') + '</div></div>';
  return h;
}

function aimSheet(S) {
  const me = ME(); const gi = S.gi; const def = wdef(me.guns[gi]); const max = me.res.prec; const sg = suggested(gi);
  const c = Math.max(me.revealPlus ? 0 : 1, Math.min(max, ui.aim && ui.aim.key === aimKey(gi) ? ui.aim.c : sg.commit));
  const sp = WD.shotPreview(G, ui.me, gi, c); const od = WD.stepOdds(G, ui.me, sp.steps, Math.max(1, max + me.revealPlus), 300);
  const row = k => od[Math.min(od.length - 1, k + me.revealPlus)] || sp.steps.map(() => 0);
  const pc = v => v >= 0.995 ? '100%' : v > 0 && v < 0.01 ? '<1%' : Math.round(v * 100) + '%';
  const opts = []; for (let k = me.revealPlus ? 0 : 1; k <= max; k++) { const o = row(k); const left = Math.max(0, max - k - sp.recoil);
    opts.push(`<button class="aim-opt ${k === c ? 'on' : ''} ${k === sg.commit ? 'sg' : ''}" data-act="aimset" data-id="${k}" aria-pressed="${k === c}" aria-label="Commit ${k}: ${pc(o[0])} to hit, ${left} Precision left"><b>${k}</b><span>${pc(o[0])}</span><small>${left} left</small></button>`); }
  const o = row(c); const sgo = row(sg.commit);
  const why = sp.left > 1 && sg.commit < max ? `★ is the plan: it saves Precision for your other shot${sp.left > 2 ? 's' : ''}.` : '★ is the best commit for this shot.';
  return `${head(`Aim · ${escA(wnm(def))}`)}
    <p class="aim-how"><b>1 Precision = 1 card revealed.</b> The shot spends what you commit, then Recoil ${sp.recoil} more.${me.revealPlus ? ` Steady: +${me.revealPlus} card free.` : ''} You have <b>${max}</b> Precision, <b>${sp.left}</b> shot${sp.left === 1 ? '' : 's'} left. ${why}</p>
    <div class="aim-row" role="group" aria-label="Precision to commit">${opts.join('')}</div>
    <div class="aim-lad">${sp.steps.map(([h, d], i) => `<span class="aim-step ${i ? 'big' : ''}"><span>${ic('hm')}${h}+</span><b>${d} dmg</b><em>${pc(o[i])}</em></span>`).join('<span class="lar">›</span>')}</div>
    <div class="row aim-btns"><button class="btn sig" data-act="aimfire" data-id="${c}">Fire · commit ${c} · ${pc(o[0])}</button>${c !== sg.commit ? `<button class="btn alt" data-act="aimfire" data-id="${sg.commit}">★ Fire ${sg.commit} · ${pc(sgo[0])}</button>` : ''}<button class="btn alt" data-act="close">Back</button></div>`;
}
function fireSheet(S) {
  const me = ME(), o = OP(); const same = me.pos === o.pos;
  let h = head('Fire');
  const avail = [0, 1].filter(i => me.guns[i]);
  if (avail.length > 1) h += `<div class="tabs">${avail.map(i => `<button class="${S.gi === i ? 'on' : ''}" data-act="pickgun" data-id="${i}">${wnm(wdef(me.guns[i]))} · ${WD.shotsLeft(G, ui.me, i)} left</button>`).join('')}</div>`;
  if (S.gi != null && me.guns[S.gi]) {
    const def = wdef(me.guns[S.gi]); const sc = WD.shootCheck(G, ui.me, S.gi);
    const sp = WD.shotPreview(G, ui.me, S.gi);
    if (sc.ok) {
      const chn = WD.hitChance(G, ui.me, sp.reveal, sp.need, 300);
      const jams = me.deck.concat(me.discard).filter(i => WD.cardDef(G, i).jam).length;
      h += `<div class="cols cols2"><div><h3>${def.name} · ${sp.left} shot${sp.left === 1 ? '' : 's'} left</h3>
        <table class="brk"><tr><td>Your Precision</td><td>${sp.prec}</td></tr>${sp.pre ? `<tr><td>Recoil (every shot)</td><td>−${sp.pre}</td></tr>` : ''}<tr><td>Distance ${sp.rawDistance} (range ${sp.band[0]}–${sp.band[1]})</td><td>in range</td></tr>${sp.bonusPrec ? `<tr><td>Bonus this shot</td><td>+${sp.bonusPrec}</td></tr>` : ''}<tr class="tot"><td>Cards revealed</td><td>${sp.reveal}</td></tr>
        ${sp.suppression ? `<tr><td>Suppressed: every step</td><td>+${sp.suppression}</td></tr>` : ''}${sp.accuracy ? `<tr><td>Target Lock: every step</td><td>−${sp.accuracy}</td></tr>` : ''}</table>
        <table class="brk"><tr><td><b>Damage ladder</b></td><td>chance</td></tr>${sp.steps.map(([h, d], i) => `<tr><td>${h}+ Hit Markers → <b>${d}</b> damage${i === sp.steps.length - 1 && sp.steps.length > 2 && def.gunClass === 'sniper' ? ' (headshot)' : ''}</td><td>${Math.round(WD.hitChance(G, ui.me, sp.reveal, h, 300) * 100)}%</td></tr>`).join('')}</table></div>
        <div style="display:grid;gap:8px;align-content:start">
        <div class="row"><span class="odds">${Math.round(chn * 100)}%</span><span style="color:var(--muted);font-size:13px">from your draw pile${jams ? ` · ${jams} Malfunction in your deck: if revealed, the gun jams` : ''}.</span></div>
        <div class="preview"><span>Damage shown after ${sp.cover ? `cover −${sp.cover}` : 'cover (none)'}${o.def ? `; then up to ${o.def} Armor soaks it` : ''}. Expected: <b>${WD.expDmg(G, ui.me, sp, 300).toFixed(1)}</b> damage.</span></div>
        <div class="preview"><span>${sp.recoilDrop ? `This shot uses your full Precision. Then Recoil ${sp.recoilDrop}: <b>${sp.prec} → ${Math.max(0, sp.prec - sp.recoilDrop)}</b> for your next shot.` : 'No recoil after this shot.'}</span></div>
        <button class="btn sig" data-act="dofire">Fire ${def.name}</button></div></div>`;
    } else h += `<div class="preview">${def.name}: ${sc.err}</div>`;
  }
  h += same && WD.TUNE.punch ? `<button class="btn ${avail.length ? 'alt' : 'sig'}" data-act="dofists" ${me.punched ? 'disabled' : ''}>${me.punched ? 'Already punched this turn' : 'Punch · auto-hit, 1 damage, ignores Armor'}</button>` : '';
  return h;
}

function sheetHTML() {
  const S = ui.sheet;
  if (S.type === 'codex') return codexSheet(S);
  if (S.type === 'rules') return `${head('How to play')}<div class="rules">${RULES}</div>`;
  if (S.type === 'rank') return rankSheet();
  const me = ME();
  if (S.type === 'weapon') {
    const gi = S.gi; const def = wdef(me.guns[gi]);
    const elig = WD.eligibleFuel(G, ui.me, gi);
    const pb = S.fuel ? preview(c => WD.activateGun(c, ui.me, gi, S.fuel)) : null;
    return `${head(`Boost ${def.name}`)}
      <div class="preview"><div><span class="req">BOOST</span> ${fx(def.boost_text)}</div><div style="color:var(--muted)">Already applied this turn, automatically: ${fx(def.main_text)}</div></div>
      <h3>Pick any card from your hand as fuel. It goes under the gun and into your discard pile at the end of your turn (it is not played).</h3>
      <div class="picker">${me.hand.map(i => cardHTML(WD.cardDef(G, i), { act: 'pickfuel', id: i, cls: i === S.fuel ? 'sel' : elig.includes(i) ? 'elig' : 'inel', dis: !elig.includes(i) })).join('') || '<span style="color:var(--muted);font-size:13px">No cards in hand.</span>'}</div>
      ${pb ? `<div class="preview"><div><span class="lbl">Boost</span>${fx(pb)}</div></div>` : ''}
      <div class="row"><button class="btn sig wide" data-act="actgunb" ${S.fuel ? '' : 'disabled'}>${S.fuel ? `Boost · spend ${escA(WD.cardDef(G, S.fuel).name)}` : 'Pick a card as fuel'}</button><button class="btn alt" data-act="close">Cancel</button></div>`;
  }
  if (S.type === 'wview') { const def = wdef(S.id); return `${head(wnm(def))}<div class="wcard"><div class="w-slot"><span>${def.cls}</span></div><div class="w-body">${weaponBody(def, S.id)}</div></div>`; }
  if (S.type === 'fire') return fireSheet(S);
  if (S.type === 'aim') return aimSheet(S);
  if (['loot', 'item', 'loc'].includes(S.type)) return lootSheet(S);
  if (S.type === 'report') {
    const f = S.f; const who = G.players[f.p].name; const me2 = ME();
    const more = f.p === ui.me && myTurn() && S.gi != null && WD.shootCheck(G, ui.me, S.gi).ok;
    if (f.fists) return `${head(`${who} · Punch`)}<div class="verdict hit">HIT</div><p>1 damage (ignores Armor).</p><button class="btn sig" data-act="close">Continue</button>`;
    const cards = [];
    if (f.bullet) cards.push((f.bullet.hm ? `<i class="hmb">+${f.bullet.hm}</i>` : '') + (/^free bullet/.test(f.bullet.name) ? `<span class="mf txt bul"><b>${ic('ammo')} Free bullet</b><small>${f.bullet.hm} Hit Marker</small></span>` : miniFace(f.bullet.name, 'bul')));
    f.revealed.forEach(r => cards.push(miniFace(r.name, r.jam ? 'jam' : '') + (r.hm ? `<i class="hmb">+${r.hm}</i>` : '')));
    const nC = cards.length;
    return `${head(`${escA(who)} fires ${escA(f.weapon)}`)}
      <div class="rp-rev" style="--n:${nC}">${cards.map((c, i) => `<span class="rv2" style="--i:${i}">${c}${i === 0 && f.bullet ? '<em>LOADED</em>' : ''}</span>`).join('')}</div>
      <div class="rp-sum" style="--d:${nC}"><span class="rp-got"><small>Hit Markers</small><b>${f.total}</b><i>/ ${f.req} needed</i></span>${f.steps ? ladderHTML(f.steps, f.level) : ''}</div>
      <div class="verdict2 ${f.hit ? 'hit' : 'miss'}" style="--d:${nC}">${f.hit ? `HIT <span>−${f.dealt}</span>` : f.jam ? 'JAMMED' : 'MISS'}</div>
      ${(f.notes && f.notes.length) || f.recoil ? `<div class="rp-notes">${(f.notes || []).concat(f.recoil ? [`−${f.recoil} Precision (commit ${f.commit || 0} + Recoil)`] : []).join(' · ')}</div>` : ''}
      <div class="row rp-btns">${more ? `<button class="btn ${fireOdds(S.gi).pct >= 10 ? 'sig' : 'alt'}" data-act="fireagain">Fire again · ${WD.shotsLeft(G, ui.me, S.gi)} left · ${fireOdds(S.gi).pct >= 1 ? fireOdds(S.gi).pct + '%' : '&lt;1%'}</button>` : ''}<button class="btn ${more && fireOdds(S.gi).pct >= 10 ? 'alt' : 'sig'}" data-act="close">Continue</button></div>`;
  }
  if (S.type === 'rivalturn') {
    const lines = S.lines;
    return `${head(`${OP().name}'s turn`)}<ol class="turnlog">${lines.map(l => `<li class="${l.cls}">${l.msg}</li>`).join('') || '<li>Nothing happened.</li>'}</ol><button class="btn sig" data-act="close">Your turn</button>`;
  }
  if (S.type === 'over') return overSheet();
  if (S.type === 'menu') return `${head('Menu')}<div class="row"><button class="btn alt" data-act="sheet" data-id="rules">How to play</button><button class="btn alt" data-act="sheet" data-id="codex">Card codex</button></div><div class="row"><button class="btn alt" data-act="new" data-id="ai">New match vs AI</button><button class="btn alt" data-act="new" data-id="hotseat">New pass &amp; play</button><button class="btn alt" data-act="home">Main menu</button></div>`;
  if (S.type === 'codex') return codexSheet(S);
  if (S.type === 'load') {
    const me = ME(); const gi = S.gi; const def = wdef(me.guns[gi]); const sp = WD.shotPreview(G, ui.me, gi);
    const pct = hm => Math.round((sp.need - hm <= 0 ? 1 : WD.hitChance(G, ui.me, sp.reveal, sp.need - hm, 300)) * 100);
    const opts = [];
    if (me.freeAmmo > 0) opts.push(`<button class="bul2 free" data-act="shoot" data-id="free"><span class="mf txt"><b>${ic('ammo')} Free bullet</b><small>×${me.freeAmmo} · ${WD.TUNE.freeBulletHM} Hit Marker</small></span><span class="bp2">${pct(WD.TUNE.freeBulletHM)}%</span></button>`);
    me.hand.slice().sort((a, b) => WD.cardDef(G, b).hit_markers - WD.cardDef(G, a).hit_markers).forEach(i => { const d = WD.cardDef(G, i); const v = pct(d.hit_markers); opts.push(`<button class="bul2 ${v >= 60 ? 'good' : v >= 30 ? 'ok' : 'low'}" data-act="shoot" data-id="${i}" aria-label="${escA(d.name)} ${v}%">${miniFace(d.name)}<span class="bp2">${v}%</span></button>`); });
    return `${head(`Load ${escA(wnm(def))}`)}<p class="ld-p">Pick a bullet from your hand. Its Hit Markers count, then you reveal <b>${sp.reveal}</b> card${sp.reveal === 1 ? '' : 's'}. The % is your chance to hit.</p>
      <div class="ld-row">${ladderHTML(sp.steps)}<span class="ld-left">${sp.left} shot${sp.left === 1 ? '' : 's'} left</span></div>
      <div class="bullets2">${opts.join('') || '<p style="color:var(--muted)">No cards in hand: no ammo.</p>'}</div>`;
  }
  if (S.type === 'station') return stationSheet();
  if (S.type === 'spoils') return spoilsSheet();
  if (S.type === 'sweep') return sweepSheet(S);
  if (S.type === 'promote') return promoteSheet(S);
  if (S.type === 'cardview') return cardSheet(S);
  if (S.type === 'perkview') { const [pi, k] = S.id.split(':'); return perkSheet(+pi, k); }
  if (S.type === 'rival') return rivalSheet();
  if (S.type === 'perk') {
    const me = ME(); const off = me.perkOffer || [];
    const ph = G.phase || 1;
    return `${head(`Phase ${ph} · draft a perk`)}<p style="margin:0">${ph === 1 ? 'Pick your first loadout perk. It stays with you all game — build your deck toward it.' : `Phase ${ph} has begun: the gas moves faster. Pick another perk.`} You have ${me.perks.length}${me.perks.length ? `: ${me.perks.map(k => WD.LOADOUT[k].name).join(', ')}` : ''}.</p>
      <div class="perkpick faces">${off.map(k => hasFace('perk_' + k) ? `<button class="pk-face" data-act="pickperk" data-id="${k}" aria-label="${escA(WD.LOADOUT[k].name)}">${pf('perk_' + k)}</button>` : '').join('')}</div>
      <div class="perkpick" hidden>${off.map(k => { const L = WD.LOADOUT[k]; return `<button class="pcard" style="--arch:var(${ARCH_VAR[L.arch] || '--muted'})" data-act="pickperk" data-id="${k}"><span class="pc-tag">${L.arch === 'any' ? 'Any build' : WD.ARCH_TAG[L.arch]}${L.trig ? ` · trigger ${perkTrig(L)}` : ' · passive'}</span><b>${L.name}</b><span>${fx(L.text)}</span></button>`; }).join('')}</div>`;
  }
  if (S.type === 'scrap') {
    const me = ME(); const at = WD.TUNE.minDeck; const own = WD.owned(me); const full = own <= at;
    const pick = (list, lab) => list.length ? `<h3>${lab}</h3><div class="sc-grid">${list.sort((a, b) => (WD.cardDef(G, a).tier || 0) - (WD.cardDef(G, b).tier || 0)).map(i => { const d = WD.cardDef(G, i); return `<button class="sc-pick" data-act="doscrap" data-id="${i}" ${full || !me.scrapAvail ? 'disabled' : ''} aria-label="Scrap ${escA(d.name)}">${hasFace('card_' + d.id) ? pf('card_' + d.id) : cardHTML(d)}</button>`; }).join('')}</div>` : '';
    return `${head(`${ic('scrap')} Scrap · ${me.scrapAvail} left`)}<p class="ld-p">Tap a card to remove it from the game for good. A thinner deck draws your best cards more often.${full ? ` <b style="color:#F06A5B">Your deck is at the ${at}-card minimum.</b>` : ''}</p>
      ${pick(me.hand.slice(), 'From your hand')}${pick(me.play.slice(), 'From your play area')}${pick(me.discard.slice(), 'From your discard pile')}${!me.hand.length && !me.discard.length ? '<p class="ld-p">No cards to scrap right now.</p>' : ''}
      <div class="row"><button class="btn alt" data-act="close">Done</button></div>`;
  }
  if (S.type === 'rules') return `${head('How to play')}<div class="rules">${RULES}</div>`;
  return '';
}

const RULES = (() => { const T = WD.TUNE; const [r1, r2] = T.rally; return `<h4>Goal</h4><ul><li>Bring your rival from ${T.hp} Health to 0. At the <b>hard end</b> (after round ${T.hardEnd}) the most Health wins.</li><li>Build a deck whose turns get stronger and stronger. <b>Threat</b> shows the damage you can expect this turn; the <b>deck bar</b> shows how much of your deck is yours.</li></ul>
<h4>Your turn</h4><ul>
<li><b>Ready</b> (automatic): your Loadout cards fire, then your location's bonus.</li>
<li><b>Play</b> cards (or <b>Play all</b>): they give ${ic('move', 'c-move')} Movement, ${ic('prec', 'c-prec')} Precision, ${ic('intel', 'c-intel')} Intel, ${ic('ammo', 'c-ammo')} extra shots and ${ic('def', 'c-def')} Armor.</li>
<li><b>Move</b> once: 1 Movement per space. Arriving gives that location's bonus.</li>
<li><b>Loot</b>: up to ${T.buyCap} buys: the top card where you stand, next door (+${T.adjCost} Intel) or the Buy Station (${T.supplyCost} Intel). Cycle a stack: 1 Intel or 1 Movement. <b>Hot Drop</b>: in rounds 1–${T.hotDrop} new cards are delivered to your next hand.</li>
<li><b>Field Promotion</b>: once per turn, ${T.promoteCost} Intel and one buy turn a starter into a squad basic of your choice (Buy Station, or the <b>Promote</b> chip).</li>
<li><b>Fire</b> (below), then <b>End turn</b>: unused Movement becomes Armor (up to ${T.digIn}), discard, draw 5 (6 at ${T.lowHp} Health or less).</li>
<li><b>Spoils</b>: if you dealt damage this turn, End turn first shows ${T.spoils} loot cards (one of your main squad when there is one): take 1 for free, or skip.</li></ul>
<h4>Squad Tactics</h4><ul>
<li>12 loot cards marked <b>TACTIC</b> add a new kind of play: <b>Charge</b> (hits at distance 0 +1), <b>Follow Through</b> (your next hit draws 2), <b>Adrenaline</b> (returns to your hand when you are hit), <b>Intel Sweep</b> (arrange your top 4), <b>Expose</b> (ignore Armor and Reactions), <b>Hold the Angle</b> (fire on your rival's turn if they end in range, with up to ${T.overwatchCap} saved Precision), <b>Fortify</b> (keep your Armor), <b>Field Medic</b> (heal 3), <b>Suppressing Barrage</b> (their next turn: −1 Movement, −2 Precision), <b>Jury-Rig</b> (repeat the card you played just before), <b>Sentry Turret</b> (Loadout: a free 2-damage shot every Ready) and <b>Contraband Run</b> (buy from any stack).</li>
<li>The chips under your Threat show the ones in play, yours and your rival's (⚠ means it can hurt you).</li></ul>
<h4>Your engine</h4><ul>
<li><b>Squads.</b> Every loot card is ${roleB('assault')} Assault (hits harder), ${roleB('recon')} Recon (aim, Mark), ${roleB('support')} Support (extra shots, Steady) or ${roleB('engineer')} Engineer (Intel, buys, Scrap). The squad counters show how many you own.</li>
<li><b>Squad</b> line: pays once <b>for each other card of its squad</b> in play this turn: ×1, ×2, at most ×${T.squadCap}. Order doesn't matter. In your hand a card shows <b>×N</b> when it would pay.</li>
<li><b>Rally</b>: ${r1} and ${r2} cards of one squad in play pay a bonus, once per turn each. ${WD.SQUADS.map(a => `${ARCH_SHORT[a]} ${r1}: ${WD.RALLY_TEXT[a][r1]}; ${r2}: ${WD.RALLY_TEXT[a][r2]}`).join('. ')}.</li>
<li><b>Loadout</b> cards stay on the table (${T.loadoutSlots} slots). They fire at the start of every turn and count for Squad and Rally. A third one replaces a slot or is used once.</li>
<li><b>Inspect anything</b>: hold it (touch), right click or hover it (mouse).</li>
<li><b>Mark</b>: next shot needs 1 fewer Hit Marker per step. <b>Pierce</b>: ignore cover. <b>Steady</b>: each shot reveals 1 more card, free. <b>Scrap</b>: remove a card from the game (deck never below ${T.minDeck}). <b>+1 Buy</b>: one more buy. <b>Reaction</b>: in your hand when hit, less damage.</li></ul>
<h4>Firing</h4><ul>
<li>One gun; buying a gun swaps it. Your rival must be in its <b>Range</b> (every gun fires at distance 0).</li>
<li><b>Commit</b> Precision: reveal 1 card per Precision and count the ${ic('hm')} Hit Markers. FIRE uses the suggested commit (★); <b>Aim</b> changes it. The % on FIRE is your chance to hit.</li>
<li><b>Recoil</b>: after the shot, the gun costs that much more Precision.</li>
<li><b>Damage ladder</b>: reach the first step to hit, the second for a big hit. Cover −1 (not at distance 0 or with Pierce). <b>Close quarters</b> (same location): no cover, no Armor. Reactions, then Armor, reduce the rest; a hit deals at least 1.</li></ul>
<h4>The circle</h4><ul>
<li>${T.zones} locations in a row, each with a 3-card loot stack; a fresh card lands on top each round (2 in 3 match the location's squad).</li>
<li>Gas closes an end location after rounds ${T.closeAfter.join(', ')} (each plate shows <b>gas R<i>n</i></b>). After round ${T.closeAfter[T.closeAfter.length - 1]} one location is left: the <b>final circle</b>, where the storm hits both for ${T.finalStorm.join(', ')}.</li>
<li>Caught outside at round end: ${T.gasDmg} damage (+1 per extra space), then you are pushed back in.</li></ul>
<h4>Operator rank</h4><ul><li>Matches vs the AI earn XP; ranks unlock the <b>Daily Drop</b> and <b>Operations</b> (match variants for both players) and insignia. Variety, never power. Saved on this device.</li></ul>`; })();

// ---------- flow ----------
function turnBanner(txt, sub, cls) { if (ui.sheet && ui.sheet.type !== 'report') { ui.pendingTb = [txt, sub, cls]; return; } ui.pendingTb = null; ui.tb = { txt, sub, cls }; clearTimeout(ui.tbT); ui.tbT = setTimeout(() => { ui.tb = null; renderLayer(); }, 1500); renderLayer(); }
// Squad / Rally / Ready callouts: short-lived chips that rise over the bottom of the map, one per trigger.
// They live outside #app so re-renders never restart them.
function queuePops(list, delay = 0, key) { if (!list.length || (key && ui.popKey === key)) return; if (key) ui.popKey = key; ui.pendPops = (ui.pendPops || []).concat(list.map(p => ({ ...p, delay }))); }
function flushPops() {
  const list = ui.pendPops || []; ui.pendPops = []; if (!list.length) return;
  const map = document.querySelector('.h-map'); if (!map) return; const r = map.getBoundingClientRect();
  let box = document.getElementById('popz'); if (!box) { box = document.createElement('div'); box.id = 'popz'; box.className = 'popz'; box.setAttribute('role', 'status'); box.setAttribute('aria-live', 'polite'); document.body.appendChild(box); }
  Object.assign(box.style, { left: r.left + r.width / 2 + 'px', bottom: Math.max(6, innerHeight - r.bottom + 10) + 'px' });
  if (list.some(p => p.kind === 'rdy')) box.querySelectorAll('.pop.rdy').forEach(e => e.remove()); // a skipped rival turn: drop the last Ready
  // Squad lines first (at most 3, same card name grouped), then every Rally
  const sq = list.filter(p => p.kind === 'sq'); const other = list.filter(p => p.kind !== 'sq');
  const grp = []; for (const p of sq) { const g = grp.find(x => x.name === p.name); if (g) { g.n++; g.text = p.text; } else grp.push({ ...p, n: 1 }); }
  grp.forEach(g => { if (g.n > 1) g.name = `${g.n} × ${g.name}`; });
  const more = Math.max(0, grp.length - 3); const shown = grp.slice(0, 3).concat(other);
  shown.forEach((p, k) => { const el = document.createElement('div'); el.className = `pop ${p.kind}`; if (ARCH_VAR[p.arch]) el.style.setProperty('--arch', `var(${ARCH_VAR[p.arch]})`);
    el.style.animationDelay = (p.delay + k * 160) + 'ms';
    el.innerHTML = `${p.arch && SHAPE[p.arch] ? `<i class="pop-sh">${shapeSvg(p.arch)}</i>` : ''}<b class="pop-h">${p.head}</b>${p.name ? `<span class="pop-n">${escA(p.name)}</span>` : ''}<span class="pop-t">${p.text}${p.kind === 'sq' && k === Math.min(grp.length, 3) - 1 && more > 0 ? ` <small>· +${more} more</small>` : ''}</span>`;
    box.appendChild(el); setTimeout(() => el.remove(), (RM() ? 1800 : 2300) + p.delay + k * 160); });
}
function sqSnap() { const me = ME(); return { n: { ...me.squadN }, r: me.rallyDone.slice() }; }
function sqDiff(b) {
  const me = ME(); const pops = []; const hot = []; const now = performance.now();
  for (const i in me.squadN) { const was = b.n[i] || 0, x = me.squadN[i]; if (x <= was) continue; const d = WD.cardDef(G, i); hot.push(i);
    pops.push({ kind: 'sq', arch: d.archetype, head: 'SQUAD', name: d.name, text: `${fx(WD.effText(d.squad))} <small>×${x}</small>` }); }
  const fresh = me.rallyDone.filter(k => !b.r.includes(k));
  for (const k of fresh) { const a = k.replace(/\d+$/, ''), n = +k.slice(a.length); pops.push({ kind: 'rally', arch: a, head: `${ARCH_SHORT[a].toUpperCase()} RALLY ${n}`, name: `${n} ${ARCH_SHORT[a]} cards in play`, text: fx(WD.RALLY_TEXT[a][n]) }); }
  if (hot.length) ui.sqHot = { ids: hot, t: now + 1700 };
  if (fresh.length) ui.rallyFx = { keys: fresh, t: now + 2000 };
  queuePops(pops.sort((x, y) => (x.kind === 'rally') - (y.kind === 'rally')));
}
// play a card / Play all, then light up whatever Squad lines and Rallies that fired
function playAct(fn) { const b = sqSnap(); const r = fn(); if (!r || !r.ok) { toast(r ? r.err : 'Not allowed.'); return r; } ui.sheet = null; ui.moveMode = false; sqDiff(b); after(); return r; }
function dmgLine(pl) { const h = pl.dmgHist || []; const n = h.length ? h[h.length - 1] : 0; return n ? `${n} damage dealt` : 'no damage'; }
function fpLine(pl) { const h = pl.fpHist; if (!h.length) return ''; const n = Math.round(h[h.length - 1]); const p = h.length > 1 ? Math.round(h[h.length - 2]) : null; return `Firepower ${n}${p == null ? '' : n > p ? ` ▲${n - p}` : n < p ? ` ▼${p - n}` : ' ='}${pl.turnSquads ? ` · Squad ×${pl.turnSquads}` : ''}`; }
function toast(msg) { ui.toast = msg; clearTimeout(ui.toastT); ui.toastT = setTimeout(() => { ui.toast = null; renderLayer(); }, 2600); renderLayer(); }
function rivalBanner() { if (ui.mode === 'ai' && !G.over) setTimeout(() => { const p = G.players[ui.me]; turnBanner('Rival’s turn', `Your turn ${p.dmgHist.length}: ${dmgLine(p)}`, 'them'); }, 0); }
function newMatch(mode, o = {}) {
  ui.mode = mode; ui.me = 0; ui.sheet = null; ui.moveMode = false; ui.burnMode = false; ui.busy = false; ui.handoff = false; ui.screen = 'game'; ui.tab = 'hand'; ui.overSeen = false; ui.meta = null; ui.daily = o.daily || null;
  const ok = WD.unlockedOps(ui.prof); const ops = o.daily ? [] : ui.ops.filter(k => ok.includes(k));
  G = WD.newGame(Object.assign({ mode, names: mode === 'ai' ? ['Alpha', 'Rival'] : ['Operator 1', 'Operator 2'], ops }, o.daily ? { seed: WD.dailySeed(o.daily) } : {}));
  if (mode === 'hotseat') ui.me = G.turn;
  render(); after(); if (G.turn === ui.me) turnBanner('Your turn', 'Round 1 · drop in', 'me');
}
const FRAME_MS = { play: 750, act: 1000, fx: 1000, hit: 1500, miss: 1300, gas: 1300, round: 700, win: 1400 };
function itemFaceS(st, it) { const def = it.kind === 'card' ? WD.CARDS[st.cards[it.iid].def] : it.kind === 'weapon' ? WD.WEAPONS[st.weapons[it.iid].def] : null; if (!def) return ''; const n = (it.kind === 'card' ? 'card_' : 'gun_') + def.id; return hasFace(n) ? n : ''; }
function fxFor(prev, cur, f) {
  const r = 1 - ui.me, m = ui.me; const fx = {};
  if (prev.players[r].pos !== cur.players[r].pos) fx.arrive = cur.players[r].pos;
  if (prev.players[m].hp > cur.players[m].hp && f.cls !== 'gas') { fx.hurt = cur.players[m].pos; fx.dmg = prev.players[m].hp - cur.players[m].hp; fx.shooter = cur.players[r].pos; }
  if (f.cls === 'miss') { fx.miss = cur.players[m].pos; fx.shooter = cur.players[r].pos; }
  if (/ searches | flips the loot /.test(f.msg)) { fx.loot = cur.players[r].pos; fx.lootTxt = 'FLIP'; }
  if (/ cycles /.test(f.msg)) { fx.loot = cur.players[r].pos; fx.lootTxt = 'CYCLE'; }
  if (/ takes /.test(f.msg)) { fx.loot = cur.players[r].pos; fx.lootTxt = 'LOOT'; }
  if (/ boosts /.test(f.msg)) { fx.loot = cur.players[r].pos; fx.lootTxt = 'BOOST'; }
  const pw = new Set(prev.envs.map(e => e.w)); fx.appear = cur.envs.filter(e => !pw.has(e.w)).map(e => e.w);
  const ps = Object.fromEntries(prev.envs.map(e => [e.w, e.state])); fx.gassed = cur.envs.filter(e => e.state === 'gas' && ps[e.w] === 'safe').map(e => e.w);
  if (f.cls === 'gas' && prev.players[m].hp > cur.players[m].hp) { fx.hurt = cur.players[m].pos; fx.dmg = prev.players[m].hp - cur.players[m].hp; }
  if (fx.arrive != null) fx.leave = prev.players[r].pos;
  // newly played rival card
  const pp = prev.players[r].play || [], cp = cur.players[r].play || []; const np = cp.filter(i => !pp.includes(i)); if (np.length) fx.played = np[np.length - 1];
  // loot taken from a stack
  for (const e of prev.envs) { const ce = cur.envs.find(x => x.w === e.w); if (!ce || !e.loot.length) continue; const gone = e.loot.filter(it => !ce.loot.some(x => x.iid === it.iid)); if (gone.length && / takes /.test(f.msg)) { fx.took = { w: e.w, face: itemFaceS(prev, gone[0]) }; break; } }
  const bs = f.msg.match(/ buys (.+) at the Buy Station/); if (bs) { const id = Object.keys(WD.CARDS).find(k => WD.CARDS[k].name === bs[1]); if (id) fx.station = 'card_' + id; }
  if (/ fires[ :]| punches /.test(f.msg) && cur.lastFire && cur.lastFire.p === r) { fx.shot = cur.lastFire; fx.shooter = cur.players[r].pos; fx.target = cur.players[m].pos; }
  return fx;
}
function playStep() {
  const P = ui.play; if (!P) return;
  // skip quiet frames quickly; stop at the end of the rival's turn
  if (P.i >= P.frames.length) return finishPlay();
  const f = P.frames[P.i++];
  if (f.cls === 'act' && / ends the turn/.test(f.msg)) { G = JSON.parse(f.state); ui.fx = null; ui.banner = f; render(); P.t = setTimeout(playStep, 500); return; }
  const prev = G; G = JSON.parse(f.state);
  ui.fx = fxFor(prev, G, f); ui.banner = f;
  render();
  P.t = setTimeout(playStep, FRAME_MS[f.cls] || 600);
}
function finishPlay() {
  const P = ui.play; if (!P) return; clearTimeout(P.t);
  G = P.real; ui.play = null; ui.fx = null; ui.banner = null; ui.busy = false;
  if (!G.over) { const th = threatNow(ME()); turnBanner('Your turn', `Round ${G.round}${th.inRange ? ` · Threat ${th.ev}` : ''}`, 'me'); }
  after();
}
function act(fn, keep) { const r = fn(); if (!r || !r.ok) { toast(r ? r.err : 'Not allowed.'); return r; } if (!keep) ui.sheet = null; ui.moveMode = false; after(); return r; }
function colRect(w) { const el = document.querySelector(`.envw[data-w="${w}"] .lc-stack, .envw[data-w="${w}"]`); return el ? el.getBoundingClientRect() : null; }
function postFx() {
  const FX = ui.fx; if (!FX || !ui.play) return;
  if (FX.done) return; FX.done = true;
  // shot tracer from the rival's column to yours
  if (FX.shot && FX.shooter != null && FX.target != null) {
    const a = colRect(FX.shooter), b = colRect(FX.target);
    if (a && b) { const ax = a.left + a.width / 2, ay = a.top + a.height * 0.45, bx = b.left + b.width / 2, by = b.top + b.height * 0.45;
      const len = Math.max(30, Math.hypot(bx - ax, by - ay)); const ang = Math.atan2(by - ay, bx - ax) * 180 / Math.PI;
      const tr = document.createElement('div'); tr.className = 'tracer ' + (FX.shot.hit ? 'hit' : 'miss'); Object.assign(tr.style, { left: ax + 'px', top: ay + 'px', width: len + 'px', transform: `rotate(${ang}deg)` });
      if (FX.shooter === FX.target) { tr.classList.add('close'); Object.assign(tr.style, { width: '0px' }); }
      document.body.appendChild(tr); setTimeout(() => tr.remove(), 900);
      const fl = document.createElement('div'); fl.className = 'muzzle'; Object.assign(fl.style, { left: ax + 'px', top: ay + 'px' }); document.body.appendChild(fl); setTimeout(() => fl.remove(), 500); }
  }
  // loot / Buy Station card flies to the rival
  const tgt = document.querySelector('.h-hp.them'); const tr2 = tgt && tgt.getBoundingClientRect();
  const fly = (face, from) => { if (!face || !from || !tr2) return; const w = Math.min(120, Math.max(70, from.width)); const fc = document.createElement('div'); fc.className = 'flyface'; fc.innerHTML = pf(face); Object.assign(fc.style, { left: (from.left + from.width / 2 - w / 2) + 'px', top: (from.top + 10) + 'px', width: w + 'px' }); document.body.appendChild(fc);
    const dx = tr2.left + tr2.width / 2 - (from.left + from.width / 2), dy = tr2.top + tr2.height / 2 - (from.top + 60);
    const an = fc.animate([{ transform: 'translate(0,0) scale(1)', opacity: 1 }, { transform: 'translate(0,-30px) scale(1.15)', opacity: 1, offset: .3 }, { transform: `translate(${dx}px, ${dy}px) scale(.25)`, opacity: .2 }], { duration: 900, easing: 'cubic-bezier(.5,0,.3,1)' }); an.onfinish = () => fc.remove(); };
  if (FX.took) fly(FX.took.face, colRect(FX.took.w));
  if (FX.station) { const r = document.querySelector('.h-map'); const rr = r && r.getBoundingClientRect(); if (rr) fly(FX.station, { left: rr.left + rr.width / 2 - 50, top: rr.top + 20, width: 100, height: 140 }); }
}
function flyLoot(info) {
  const vis = el => { if (!el) return null; const r = el.getBoundingClientRect(); return r.width && r.height ? r : null; };
  info.forEach((it, k) => {
    if (!it.rect) return;
    const target = it.kind === 'weapon' ? (vis(document.querySelector('.weps')) || vis(document.querySelector('.mtabs [data-id=guns]'))) : (vis(document.querySelector('.op.mine .dcount, .dcount')) || vis(document.querySelector('.mtabs [data-id=hand]')));
    const fc = document.createElement('div'); fc.className = 'flycard' + (it.kind === 'weapon' ? ' rr' + it.tier : '');
    if (ARCH_VAR[it.arch]) fc.style.setProperty('--arch', `var(${ARCH_VAR[it.arch]})`);
    fc.textContent = it.name; const s = it.rect;
    Object.assign(fc.style, { left: s.left + 'px', top: s.top + 'px', width: Math.max(120, Math.min(220, s.width)) + 'px' });
    document.body.appendChild(fc);
    const dx = target ? target.left + target.width / 2 - (s.left + Math.max(120, Math.min(220, s.width)) / 2) : 0, dy = target ? target.top + target.height / 2 - (s.top + 20) : 200;
    const a = fc.animate([{ transform: 'translate(0,0) scale(1)', opacity: 1 }, { transform: `translate(${dx * 0.35}px, ${dy * 0.35 - 30}px) scale(.85) rotate(-4deg)`, opacity: 1, offset: 0.35 }, { transform: `translate(${dx}px, ${dy}px) scale(.3) rotate(6deg)`, opacity: 0.2 }], { duration: 620, delay: k * 90, easing: 'cubic-bezier(.5,0,.3,1)', fill: 'forwards' });
    a.onfinish = () => { fc.remove(); const t = document.querySelector(it.kind === 'weapon' ? '.weps' : '.dcount'); if (t) { t.classList.remove('pulse'); void t.offsetWidth; t.classList.add('pulse'); } };
  });
}
function openLoad(gi) {
  const fo = fireOdds(gi); if (!fo || fo.pct == null) return toast(fo && fo.err ? fo.err : 'Can’t fire.');
  const r = WD.fire(G, ui.me, gi, fo.commit); if (!r.ok) return toast(r.err); ui.aim = null; ui.sheet = { type: 'report', f: r.result, gi }; return after();
}
function after() {
  if (G && !G.over && G.turn === ui.me && !ui.busy && !ui.handoff && !ui.play && ME().perkOffer && (!ui.sheet || ui.sheet.type !== 'perk')) ui.sheet = { type: 'perk' };
  if (G && G.spoils && G.spoils.p === ui.me && !ui.busy && !ui.handoff && !ui.play && (!ui.sheet || ui.sheet.type !== 'spoils')) ui.sheet = { type: 'spoils' };
  if (G && myTurn() && ME().peek && ui.sweepFor !== ME().peek.join() && !ui.sheet) { ui.sweepFor = ME().peek.join(); ui.sheet = { type: 'sweep', order: [] }; }
  if (G && G.over && ui.mode === 'ai' && !ui.meta) { const prev = ui.prof; ui.meta = WD.applyMatch(prev, G, ui.me, { daily: ui.daily }); ui.meta.prev = prev; ui.prof = ui.meta.profile; ui.meta.saved = WD.saveProfile(store(), ui.prof); }
  if (G.over && !ui.overSeen && (!ui.sheet || !['report', 'rivalturn'].includes(ui.sheet.type))) ui.sheet = { type: 'over' };
  if (ui.mode === 'hotseat' && !G.over && G.turn !== ui.me) ui.handoff = true;
  render();
  if (ui.mode === 'ai' && !G.over && G.turn !== ui.me && !ui.busy) {
    ui.busy = true; render();
    setTimeout(() => {
      const real = G; const frames = []; real._rec = frames;
      WD.aiTurn(real, 1 - ui.me); real._rec = null;
      ui.play = { frames, i: 0, real, t: 0 }; ui.tab = 'intel' === ui.tab ? 'intel' : ui.tab;
      playStep();
    }, 350);
  }
}

document.addEventListener('click', e => {
  if (LP.suppress) { LP.suppress = false; e.preventDefault(); e.stopPropagation(); return; }
  const el = e.target.closest('[data-act]');
  if (ui.lift && (!el || el.dataset.act !== 'card')) { ui.lift = null; if (!el) { render(); return; } }
  if (!el) return;
  const a = el.dataset.act, id = el.dataset.id;
  if (a === 'scrim') { if (e.target === el && ui.sheet) closeSheet(); return; }
  const S = ui.sheet; const me = G ? ME() : null;
  switch (a) {
    case 'skipplay': finishPlay(); break;
    case 'new': if (ui.play) { clearTimeout(ui.play.t); ui.play = null; ui.fx = null; } newMatch(id); break;
    case 'home': ui.screen = 'start'; ui.sheet = null; G = null; render(); break;
    case 'sheet': ui.sheet = { type: id, tab: 'weapons' }; renderLayer(); break;
    case 'close': closeSheet(); break;
    case 'tab': S.tab = id; renderLayer(); break;
    case 'cardview': ui.sheet = { type: 'cardview', id }; renderLayer(); break;
    case 'playcard': { ui.sheet = null; if (!myTurn()) return toast('Wait for your turn.'); playAct(() => WD.playCard(G, ui.me, id)); break; }
    case 'playlo': { const [cid, k] = id.split(':'); ui.sheet = null; if (!myTurn()) return toast('Wait for your turn.'); playAct(() => WD.playCard(G, ui.me, cid, k === 'once' ? { once: true } : { slot: +k })); break; }
    case 'noop': break;
    case 'cxf': { const [g, v] = id.split(':'); S.f[g] = S.f[g] === v && v !== 'all' ? 'all' : v; const sc = document.querySelector('.cx-body'); const top = sc ? sc.scrollTop : 0; renderLayer(); const q = document.querySelector('.cx-q'); if (q) codexSearch(q.value); const sc2 = document.querySelector('.cx-body'); if (sc2) sc2.scrollTop = top; break; }
    case 'cxview': { const z = document.getElementById('cxZoom') || Object.assign(document.createElement('div'), { id: 'cxZoom' }); z.className = 'cx-zoom ' + (id.startsWith('gun_') ? 'gun' : id.startsWith('loc_') ? 'loc' : 'card'); z.innerHTML = pf(id); z.onclick = () => z.remove(); document.body.appendChild(z); break; }
    case 'perkview': ui.sheet = { type: 'perkview', id }; renderLayer(); break;
    case 'pickgunb': ui.gunSel = +id; render(); break;
    case 'swapgun': ui.gunSel = 1 - curGun(me); render(); break;
    case 'mtab': ui.tab = id; render(); break;
    case 'takeover': ui.me = G.turn; ui.handoff = false; after(); turnBanner(`${escA(G.players[G.turn].name)}`, `Round ${G.round}`, 'me'); break;
    case 'card': { if (!myTurn()) return toast('Wait for your turn.'); if (matchMedia('(pointer: coarse) and (orientation: landscape) and (max-height: 540px)').matches && ui.lift !== id) { ui.lift = id; render(); return; } ui.lift = null; const d = WD.cardDef(G, id); if (d.loadout && me.loadout.length >= WD.TUNE.loadoutSlots) { ui.sheet = { type: 'cardview', id }; renderLayer(); break; } ui.justPlayed = id; playAct(() => WD.playCard(G, ui.me, id)); break; }
    case 'playall': playAct(() => WD.playAll(G, ui.me)); break;
    case 'cycle': { const r = WD.cycle(G, ui.me, id); if (!r.ok) return toast(r.err); S.sel = []; S.converted = false; { const e2 = WD.envAt(G, ME().pos); ui.sheet = e2 && e2.loot.length ? { type: 'item', id: e2.loot[0].iid, sel: [], trade: [], slideIn: true } : null; } render(); break; }
    case 'pickperk': { const r = WD.pickPerk(G, ui.me, id); if (!r.ok) return toast(r.err); ui.sheet = null; after(); break; }
    case 'supply': { const el = document.querySelector(`.bscard[data-id="${id}"]`); const rect = el && el.getBoundingClientRect(); const r = WD.buySupply(G, ui.me, id); if (!r.ok) return toast(r.err); render(); flyLoot([{ kind: 'card', name: WD.CARDS[id].name, arch: 'supply', rect }]); break; }
    case 'scrapsheet': ui.sheet = { type: 'scrap' }; renderLayer(); break;
    case 'stscrap': { const r = WD.stationScrap(G, ui.me, id); if (!r.ok) return toast(r.err); render(); break; }
    case 'doscrap': { const r = WD.scrap(G, ui.me, id); if (!r.ok) return toast(r.err); if (!ME().scrapAvail) ui.sheet = null; render(); break; }
    case 'burnmode': ui.burnMode = !ui.burnMode; render(); break;
    case 'burn': ui.burnMode = false; act(() => WD.burnAtBench(G, ui.me, id)); break;
    case 'activate': ui.sheet = { type: 'weapon', gi: +id, fuel: null }; renderLayer(); break;
    case 'pickfuel': S.fuel = S.fuel === id ? null : id; renderLayer(); break;
    case 'actgun': act(() => WD.activateGun(G, ui.me, S.gi, null)); break;
    case 'actgunb': act(() => WD.activateGun(G, ui.me, S.gi, S.fuel)); break;
    case 'wview': ui.sheet = { type: 'wview', id }; renderLayer(); break;
    case 'move': if (!me.res.move && !ui.moveMode) return toast('No Movement. Play a Movement card first.'); ui.moveMode = !ui.moveMode; render(); break;
    case 'moveto': act(() => WD.move(G, ui.me, +id)); break;
    case 'loc': ui.sheet = { type: 'loc', w: +id, sel: [] }; renderLayer(); break;
    case 'search': { const r = WD.search(G, ui.me); if (!r.ok) return toast(r.err); ui.sheet = { type: 'loot', sel: [], trade: [], fresh: r.ids }; render(); break; }
    case 'fire': if (id != null) { openLoad(+id); break; } { let gi = id != null ? +id : null; if (gi == null) { const fo = fireOdds(); gi = fo && fo.pct != null ? fo.gi : [0, 1].find(i => me.guns[i]); } ui.sheet = { type: 'fire', gi: gi ?? null }; renderLayer(); break; }
    case 'pickgun': S.gi = +id; renderLayer(); break;
    case 'tfire': openLoad(+id); break;
    case 'dofire': openLoad(S.gi); break;
    case 'shoot': { const gi = S.gi; const r = WD.fire(G, ui.me, gi, id); if (!r.ok) return toast(r.err); ui.sheet = { type: 'report', f: r.result, gi }; after(); break; }
    case 'fireagain': openLoad(S.gi); break;
    case 'aim': ui.sheet = { type: 'aim', gi: +id }; renderLayer(); break;
    case 'aimset': ui.aim = { key: aimKey(S.gi), c: +id }; renderLayer(); render(); break;
    case 'aimfire': { ui.aim = { key: aimKey(S.gi), c: +id }; const gi = S.gi; ui.sheet = null; openLoad(gi); break; }
    case 'dofists': { const r = WD.punch(G, ui.me); if (!r.ok) return toast(r.err); ui.sheet = { type: 'report', f: r.result }; after(); break; }
    case 'loot': ui.sheet = { type: 'loot', sel: [], trade: [] }; renderLayer(); break;
    case 'item': ui.sheet = { type: 'item', id, sel: [], trade: [] }; renderLayer(); break;
    case 'pickloot': { const i = S.sel.indexOf(id); if (i >= 0) S.sel.splice(i, 1); else S.sel.push(id); renderLayer(); break; }
    case 'lootopt': { const [k, v] = id.split(':'); if (k === 'replace') S.replace = +v; else S.attachTo = +v; renderLayer(); break; }
    case 'trade': { const i = S.trade.indexOf(id); if (i >= 0) S.trade.splice(i, 1); else S.trade.push(id); renderLayer(); break; }
    case 'dolot': {
      const ids = S.sel.slice();
      const info = ids.map(i => { const n = WD.lootNear(G, ui.me, i); if (!n) return null; const d = WD.itemDef(G, n.it); const el = document.querySelector(`.sheet .lootpick[data-id="${i}"]`) || document.querySelector(`.env [data-act=item][data-id="${i}"]`); return { kind: n.it.kind, name: d.name, arch: d.archetype, tier: d.tier, w: n.env.w, rect: el ? el.getBoundingClientRect() : null }; }).filter(Boolean);
      const r = WD.buy(G, ui.me, ids, { tradeIn: S.trade, replace: S.replace ?? 0, attachTo: S.attachTo ?? 0 }); if (!r.ok) return toast(r.err);
      const w = info[0] && info[0].w; const env = w != null ? WD.envAt(G, w) : null;
      ui.sheet = env && env.loot.length && env.cache.searched ? { type: 'item', id: env.loot[0].iid, sel: [], trade: [], slideIn: true } : null;
      ui.newTop = w; clearTimeout(ui.newTopT); ui.newTopT = setTimeout(() => { ui.newTop = null; }, 900);
      after(); flyLoot(info); break; }
    case 'endturn': { ui.gunSel = null; ui.moveMode = false; ui.burnMode = false; const r = act(() => WD.endTurn(G, ui.me)); if (r && r.ok && !G.spoils) rivalBanner(); break; }
    case 'spoilpick': case 'spoilskip': { if (!G.spoils || G.spoils.p !== ui.me) return; const r = WD.takeSpoils(G, ui.me, a === 'spoilpick' ? id : null); if (!r.ok) return toast(r.err); ui.sheet = null; after(); if (!G.over) rivalBanner(); break; }
    case 'sweepsheet': ui.sheet = { type: 'sweep', order: [] }; renderLayer(); break;
    case 'sweeppick': { const i = S.order.indexOf(id); if (i >= 0) S.order.splice(i, 1); else S.order.push(id); renderLayer(); break; }
    case 'sweepok': { const pk = ME().peek || []; const order = S.order.concat(pk.filter(i => !S.order.includes(i))); const r = WD.arrange(G, ui.me, id === 'keep' ? pk : order); if (!r.ok) return toast(r.err); ui.sheet = null; toast(id === 'keep' ? 'Deck left as it was.' : 'Top of your deck arranged.'); render(); break; }
    case 'promosheet': ui.sheet = { type: 'promote', pick: null, sq: WD.mainSquad(G, ui.me) || 'assault' }; renderLayer(); break;
    case 'promopick': S.pick = id; renderLayer(); break;
    case 'promosq': S.sq = id; renderLayer(); break;
    case 'dopromote': { const r = WD.promote(G, ui.me, S.pick, S.sq); if (!r.ok) return toast(r.err); ui.sheet = null; toast(`Promoted to ${WD.cardDef(G, r.iid).name}.`); render(); break; }
    case 'daily': newMatch('ai', { daily: today() }); break;
    case 'optoggle': { const i = ui.ops.indexOf(id); if (i >= 0) ui.ops.splice(i, 1); else ui.ops.push(id); saveOps(); render(); break; }
  }
}, true);
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') { if (ui.sheet && ui.sheet.type !== 'over') closeSheet(); else if (ui.moveMode || ui.burnMode) { ui.moveMode = false; ui.burnMode = false; render(); } }
  if ((e.key === 'Enter' || e.key === ' ') && e.target.dataset && e.target.dataset.act === 'moveto') { e.preventDefault(); e.target.click(); }
});
function closeSheet() { const cur = ui.sheet; if (cur && cur.type === 'perk' && G && ME().perkOffer && myTurn()) return; if (cur && cur.type === 'spoils' && G && G.spoils) return toast('Take one of the Spoils, or Skip.'); if (cur && cur.type === 'over') ui.overSeen = true; const then = cur && cur.then; ui.sheet = then ? { type: then } : null; if (!ui.sheet && G && G.over && !ui.overSeen) ui.sheet = { type: 'over' }; render(); }

/* ---------- hold for info (touch) / hover (mouse) ---------- */
const LP = { timer: null, x: 0, y: 0, el: null, shown: false, suppress: false };
function showTip(text, x, y) {
  let pop = document.getElementById('tipPop');
  if (!pop) { pop = document.createElement('div'); pop.id = 'tipPop'; pop.className = 'tip-pop'; pop.setAttribute('role', 'tooltip'); document.body.appendChild(pop); }
  pop.textContent = text; pop.hidden = false;
  const r = pop.getBoundingClientRect();
  const left = Math.min(Math.max(10, x - r.width / 2), innerWidth - r.width - 10);
  let top = y - r.height - 24; if (top < 8) top = Math.min(y + 24, innerHeight - r.height - 8);
  pop.style.left = left + 'px'; pop.style.top = top + 'px';
}
function hideTip() { const pop = document.getElementById('tipPop'); if (pop) pop.hidden = true; if (typeof hidePrev === 'function' && LP.shown) hidePrev(); if (LP.el) LP.el.classList.remove('holding'); LP.el = null; LP.shown = false; }
document.addEventListener('pointerdown', e => {
  if (LP.shown && e.pointerType !== 'mouse') { hideTip(); LP.suppress = true; return; }
  LP.suppress = false;
  if (e.pointerType === 'mouse') { clearTimeout(LP.timer); hideTip(); return; }
  clearTimeout(LP.timer); LP.x = e.clientX; LP.y = e.clientY;
  const t = e.target.closest('[data-tip], [data-prev]');
  if (!t) return;
  LP.timer = setTimeout(() => {
    LP.el = t; t.classList.add('holding'); LP.shown = true; LP.suppress = true;
    if (t.dataset.prev && !t.dataset.tip) showPrev(t); else showTip(t.dataset.tip, LP.x, LP.y);
  }, 430);
}, true);
document.addEventListener('pointermove', e => {
  if (e.pointerType === 'mouse') {
    const t = e.target.closest('[data-tip]');
    if (t && t !== LP.el) { if (LP.el) LP.el.classList.remove('holding'); LP.el = t; clearTimeout(LP.timer); LP.timer = setTimeout(() => { if (LP.el === t) showTip(t.dataset.tip, e.clientX, e.clientY); }, 550); }
    else if (!t && LP.el) { clearTimeout(LP.timer); hideTip(); }
    return;
  }
  if (LP.timer && !LP.shown && Math.hypot(e.clientX - LP.x, e.clientY - LP.y) > 10) clearTimeout(LP.timer);
}, true);
document.addEventListener('pointerup', e => { if (e.pointerType !== 'mouse') { clearTimeout(LP.timer); if (LP.el) LP.el.classList.remove('holding'); } }, true);
document.addEventListener('pointercancel', () => clearTimeout(LP.timer), true);
// right click (desktop) inspects like a long press on touch: the card face if there is one, else the explanation
document.addEventListener('contextmenu', e => {
  if (!e.target.closest('#app, #layer')) return; e.preventDefault();
  const t = e.target.closest('[data-prev], [data-tip]'); if (!t) return;
  hideTip(); if (t.dataset.prev && hasFace && previewHTML(t.dataset.prev)) { showPrev(t); return; }
  if (t.dataset.tip) { showTip(t.dataset.tip, e.clientX, e.clientY); LP.el = t; LP.shown = true; }
});

window.WZ = { get G() { return G; }, ui, render, renderLayer };
render();
})();
