// Print-and-play generator: builds pnp.html from the live engine data.
const fs = require('fs');
const path = require('path');
const WD = require('../engine.js');
const T = WD.TUNE;
const SYM = fs.readFileSync(path.join(__dirname, '..', 'symbols.html'), 'utf8');

const ROLE = {
  assault: { name: 'Assault', shape: '▲', color: '#2F7FD8', best: 'Movement' },
  recon: { name: 'Recon', shape: '◉', color: '#C8442B', best: 'Precision' },
  support: { name: 'Support', shape: '■', color: '#3F8F4A', best: 'Extra shots' },
  engineer: { name: 'Engineer', shape: '✚', color: '#B98A10', best: 'Intel' },
};
const RES = { move: '#2F7FD8', prec: '#C8442B', intel: '#B98A10', ammo: '#3F8F4A', mag: '#5B6152' };
const RAR = ['#8E949A', '#3FA34D', '#2F7FD8', '#9B4DCA', '#D9A400'];
const RARN = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary'];
// card art: a file named after the card wins; otherwise the category's sample image
const ART_DIR = path.join(__dirname, 'art');
const CAT_ART = { starter: 'Sprint', assault: 'Breach', recon: 'Mark_Target', support: 'Ammo_Box', engineer: 'Deployable_Cover' };
function artFor(d) {
  const own = d.name.replace(/ /g, '_') + '.jpg';
  if (fs.existsSync(path.join(ART_DIR, own))) return 'art/' + own;
  const c = CAT_ART[d.archetype]; return c && fs.existsSync(path.join(ART_DIR, c + '.jpg')) ? `art/${c}.jpg` : null;
}
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const ic = (n, color) => `<svg class="i" data-icon="${n}" style="color:${color || 'currentColor'}"><use href="#i-${n}"/></svg>`;
const SHAPE = {
  assault: '<path d="M12 2.5 20.5 21 12 16.2 3.5 21z" fill="currentColor"/>',
  recon: '<path d="M12 2.6l2.75 6.1 6.65.6-5.05 4.4 1.5 6.5L12 16.8l-5.85 3.4 1.5-6.5L2.6 9.3l6.65-.6z" fill="currentColor"/>',
  support: '<path d="M12 2.2 20.5 5.4v6.1c0 5.1-3.6 8.7-8.5 10.3-4.9-1.6-8.5-5.2-8.5-10.3V5.4z" fill="currentColor"/>',
  engineer: '<path fill-rule="evenodd" d="M18.62 9.71 L18.64 9.80 L21.91 9.58 L21.91 14.42 L18.64 14.20 L18.62 14.29 L18.29 15.06 L18.26 15.14 L20.72 17.29 L17.29 20.72 L15.14 18.26 L15.06 18.29 L14.29 18.62 L14.20 18.64 L14.42 21.91 L9.58 21.91 L9.80 18.64 L9.71 18.62 L8.94 18.29 L8.86 18.26 L6.71 20.72 L3.28 17.29 L5.74 15.14 L5.71 15.06 L5.38 14.29 L5.36 14.20 L2.09 14.42 L2.09 9.58 L5.36 9.80 L5.38 9.71 L5.71 8.94 L5.74 8.86 L3.28 6.71 L6.71 3.28 L8.86 5.74 L8.94 5.71 L9.71 5.38 L9.80 5.36 L9.58 2.09 L14.42 2.09 L14.20 5.36 L14.29 5.38 L15.06 5.71 L15.14 5.74 L17.29 3.28 L20.72 6.71 L18.26 8.86 L18.29 8.94Z M12 9.2 a2.8 2.8 0 1 0 0.001 0Z" fill="currentColor"/>',
};
const shapeSvg = (r, cls = '') => `<svg class="shp ${cls}" data-icon="role_${r}" viewBox="0 0 24 24">${SHAPE[r]}</svg>`;
// army-style rank chevrons pointing up, stacked
const rank = (t, cls = '') => t ? `<svg class="rank ${cls}" data-icon="rank_${t}" viewBox="0 0 24 ${6 + 7 * t}">${Array.from({ length: t }, (_, i) => `<path d="M3 ${11 + 7 * i} 12 ${4 + 7 * i} 21 ${11 + 7 * i}" fill="none" stroke="currentColor" stroke-width="3.6" stroke-linejoin="miter" stroke-linecap="butt"/>`).join('')}</svg>` : '';
const chev = t => rank(t, 'inl');
const hm = n => n ? `<span class="hm">${Array.from({ length: n }, () => ic('hm')).join('')}</span>` : '';
const roleB = (r, small) => `<span class="roleb${small ? ' sm' : ''}" data-badge="${r}" style="background:${ROLE[r].color}">${shapeSvg(r)}</span>`;

// text → icons (same idea as the app)
function fx(text) {
  return String(text).split(/(?<=\.)\s+/).map(sent => {
    let s = esc(sent); const isGain = /^Gain\b/.test(s);
    s = s.replace(/\bHit Markers?\b/g, ic('hm'));
    s = s.replace(/(\d+) (more )?free bullets?/g, (m, n) => `+${n}${ic('ammo', RES.ammo)}`);
    s = s.replace(/\+?(\d+) extra shots?/g, (m, n) => `+${n}${ic('ammo', RES.ammo)}`);
    s = s.replace(/\+?(\d+) Armor\b/g, (m, n) => `+${n}${ic('def', '#475827')}`);
    s = s.replace(/\+?(\d+) free cycles?/g, (m, n) => `+${n}${ic('cyc')}`);
    s = s.replace(/\+?(\d+) magazine/g, (m, n) => `+${n}${ic('mag', RES.mag)}`);
    s = s.replace(/(\+?)(\d+) (Movement|Precision|Intel)\b/g, (m, p, n, r) => `${p || isGain ? '+' : ''}${n}${ic({ Movement: 'move', Precision: 'prec', Intel: 'intel' }[r], RES[{ Movement: 'move', Precision: 'prec', Intel: 'intel' }[r]])}`);
    s = s.replace(/\b(Movement|Precision|Intel)\b/g, (m, r) => ic({ Movement: 'move', Precision: 'prec', Intel: 'intel' }[r], RES[{ Movement: 'move', Precision: 'prec', Intel: 'intel' }[r]]));
    s = s.replace(/\bRecoil\b/g, ic('rcl'));
    s = s.replace(/Scrap (\d)/g, (m, n) => `<b class="scrap">${ic('scrap', '#C2531A')}${n}</b>`);
    if (isGain) s = s.replace(/^Gain /, '').replace(/,? and (?=\+)/g, ' ').replace(/, (?=\+)/g, ' ').replace(/\.$/, '');
    s = s.replace(/(<\/svg>|<\/b>)\s*\.(?=\s|$)/g, '$1');
    return s;
  }).join(' ');
}

// ---------- card builders ----------
// Squad line: pays once per OTHER card of the same squad in play this turn (Loadout counts), up to ×3. Loadout cards stay on the table.
function squadBox(d) {
  const r = ROLE[d.archetype]; if (!r) return '';
  if (d.loadout) return `<div class="combo lo" style="--rc:${r.color}">${roleB(d.archetype, true)} <b class="ct">LOADOUT</b> Stays on the table (2 slots). Counts for Squad every turn.</div>`;
  return d.squad ? `<div class="combo" style="--rc:${r.color}">${roleB(d.archetype, true)} <b class="ct">SQUAD</b> ${fx(d.squadText)} <small>each other ${r.name}</small></div>` : '';
}
function tacCard(d, v = (process.env.TACV || 0) * 1) {
  const r = ROLE[d.archetype]; const grey = !r;
  if (v) return tacCardV(d, v);
  const hmCol = Array.from({ length: d.hit_markers }, () => ic('hm')).join('');
  return `<div class="card tac nl ${grey ? 'grey' : ''}" style="--rc:${r ? r.color : '#B9BCAE'}">
    <div class="band"><div class="bhm" title="${d.hit_markers} Hit Marker${d.hit_markers === 1 ? '' : 's'}">${hmCol}</div>
      <div class="bid">${r && !/^K/.test(d.id) ? rank(d.tier, 'bchev') : ''}${/^K/.test(d.id) ? `<svg class="shp bshape bpara" data-icon="para" viewBox="0 0 24 24"><use href="#i-para"/></svg>` : ''}${r ? shapeSvg(d.archetype, 'bshape') : `<svg class="shp bshape" data-icon="para" viewBox="0 0 24 24"><path d="M2.5 11a9.5 8 0 0 1 19 0c-1.6-1.1-3.1-1.1-4.75 0-1.6-1.1-3.15-1.1-4.75 0-1.6-1.1-3.15-1.1-4.75 0-1.65-1.1-3.15-1.1-4.75 0z" fill="currentColor"/><path d="M3 11.4 10.6 18.5M21 11.4l-7.6 7.1M12 11.4v6.6" fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.4"/><rect x="9.6" y="17.6" width="4.8" height="4.4" rx="1.2" fill="currentColor"/></svg>`}</div></div>
    <div class="cin"><div class="txt">
      <div class="top"><span class="nm">${esc(d.name)}</span>${d.intel_cost ? `<span class="costb">${ic('intel', RES.intel)}<b>${d.intel_cost}</b></span>` : ''}</div>
      <div class="main">${d.tactic ? '<b class="tacb">TACTIC</b> ' : ''}${fx(d.text)}</div>
      ${squadBox(d)}
      ${d.reaction ? `<div class="react"><b>${ic('def')} REACTION</b> In your hand when hit: −${d.reaction} damage, then discard it.</div>` : ''}
      </div>${artFor(d) ? `<div class="art"><img src="${artFor(d)}" alt=""></div>` : ''}
    </div></div>`;
}
// header variants: title + cost + Hit Markers in one backed bar, no footer
function tacCardV(d, v) {
  const r = ROLE[d.archetype]; const grey = !r;
  const cost = d.intel_cost ? `<span class="costb">${ic('intel', v === 2 || v === 4 ? '#F2C14E' : RES.intel)}<b>${d.intel_cost}</b></span>` : '';
  const H = hm(d.hit_markers);
  const head = v === 3
    ? `<div class="hd hv3"><span class="nm">${esc(d.name)}</span>${H}</div>`
    : v === 5 ? `<div class="hd hv5">${cost}<span class="nm">${esc(d.name)}</span>${H}</div>`
    : `<div class="hd hv${v}"><span class="nm">${esc(d.name)}</span><span class="hdr">${H}${cost ? `${H ? '<i class="sep"></i>' : ''}${cost}` : ''}</span></div>`;
  return `<div class="card tac tv tv${v} ${grey ? 'grey' : ''}" style="--rc:${r ? r.color : '#B9BCAE'}">
    <div class="band">${v === 3 && d.intel_cost ? `<span class="coin">${ic('intel', RES.intel)}<b>${d.intel_cost}</b></span>` : ''}${r ? `${shapeSvg(d.archetype, 'bshape')}${/^K/.test(d.id) ? '' : rank(d.tier, 'bchev')}` : ''}</div>
    <div class="cin"><div class="txt">${head}
      <div class="main">${fx(d.text)}</div>
      ${squadBox(d)}
      ${d.reaction ? `<div class="react"><b>${ic('def')} REACTION</b> In your hand when hit: −${d.reaction} damage, then discard it.</div>` : ''}
      </div>${artFor(d) ? `<div class="art"><img src="${artFor(d)}" alt=""></div>` : ''}
    </div></div>`;
}
// gun cards: neutral slot band (gunmetal primary / sand secondary) holding the damage ladder,
// rarity colour only on the name, the tag and any number better than the Common version
const GUN_BG = ['#2E3238', '#D2BF95'];
const RTXT = ['#1C2017', '#2E8B3E', '#2569B8', '#8A3DB8', '#A87E00'];
const RLITE = ['#fff', '#7BD88A', '#7FB6F2', '#C99BEA', '#F2CC4A'];
const GUN_ART = { Pistol: 'Hip_Fire', SMG: 'Follow_Through', Shotgun: 'Breach', 'Assault Rifle': 'Suppressing_Barrage', LMG: 'Suppressing_Fire', 'Marksman Rifle': 'Steady_Breath', Sniper: 'Spotter_Scope', 'Burst Rifle': 'Rush_the_Door', Launcher: 'Breaching_Charge', Revolver: 'Snapshot', Melee: 'Breach' };
const gunBase = g => Object.values(WD.WEAPONS).find(w => w.cls === g.cls && w.tier === 0);
function gunCard(id, tierBack) {
  const g = WD.WEAPONS[id], b = gunBase(g), sec = false;
  const isTop = i => i === g.ladder.length - 1 && g.ladder.length > 2;
  const dmgUp = g.ladder[0][1] > b.ladder[0][1], hmUp = g.ladder[0][0] < b.ladder[0][0];
  const onBand = (on, top) => on ? ` style="color:${sec !== !!top ? RTXT[g.tier] : RLITE[g.tier]}"` : '';
  const onText = on => on ? ` style="color:${RTXT[g.tier]}"` : '';
  if (g.melee) { const dUp = g.ladder[0][1] > b.ladder[0][1];
    const art2 = fs.existsSync(path.join(ART_DIR, 'guns', id + '.jpg')) ? `art/guns/${id}.jpg` : GUN_ART[g.cls] && fs.existsSync(path.join(ART_DIR, GUN_ART[g.cls] + '.jpg')) ? `art/${GUN_ART[g.cls]}.jpg` : null;
    return `<div class="card gunL" style="--gb:${GUN_BG[0]}"><div class="gband"><div class="gsteps"><div class="gst1 top"><span class="auto">AUTO</span><b${dUp ? ` style="color:${RLITE[g.tier]}"` : ''}>${g.ladder[0][1]}</b></div></div><div class="gid">${tierBack ? rank(tierBack, 'bchev') : ''}</div></div>
    <div class="gmain"><div class="gtop"><div class="gtl"><span class="nm">${esc(g.name.replace(/ “.*”/, ''))}</span><div class="gsub"><span class="ttag">Melee</span><span class="rtag" style="background:${RAR[g.tier]}">${RARN[g.tier]}</span></div></div><span class="costb">${ic('intel', RES.intel)}${g.intel_cost}</span></div>
      <div class="gart">${art2 ? `<img src="${art2}" alt="">` : ''}</div>
      <div class="gbot"><div class="gstats"><div><b>0</b><span>${ic('rng')}Range</span></div><div><b>1</b><span>Per turn</span></div></div><div class="gcombo">${g.gcombo ? `${roleB(g.gcombo.role, true)}<span>${fx(g.gcombo.text)}</span>` : 'Always hits'}</div></div></div></div>`; }
  const steps = g.ladder.map(([h, d], i) => `<div class="gst1 ${isTop(i) ? 'top' : ''}"><span class="hg"${onBand(hmUp, isTop(i))}>${Array.from({ length: h }, () => ic('hm')).join('')}</span><b${onBand(dmgUp, isTop(i))}>${d}</b></div>`).join('');
  const stats = [[`${g.band[0]}–${g.band[1]}`, 'rng', 'Range', false], [g.magazine_capacity, 'ammo', 'Shots', g.magazine_capacity > b.magazine_capacity]].concat([[g.recoil, 'rcl', 'Recoil', g.recoil < b.recoil]]);
  // a file named after the exact gun (art/guns/smg-2.jpg) wins; otherwise a placeholder from a matching card
  const art = fs.existsSync(path.join(ART_DIR, 'guns', id + '.jpg')) ? `art/guns/${id}.jpg` : GUN_ART[g.cls] && fs.existsSync(path.join(ART_DIR, GUN_ART[g.cls] + '.jpg')) ? `art/${GUN_ART[g.cls]}.jpg` : null;
  return `<div class="card gunL ${sec ? 'sec' : ''}" style="--gb:${GUN_BG[sec ? 1 : 0]}">
    <div class="gband"><div class="gsteps">${steps}</div><div class="gid">${tierBack ? rank(tierBack, 'bchev') : ''}</div></div>
    <div class="gmain"><div class="gtop"><div class="gtl"><span class="nm">${esc(g.name.replace(/ “.*”/, ''))}</span><div class="gsub"><span class="ttag">${esc(g.cls === 'Marksman Rifle' ? 'Marksman' : g.cls)}</span><span class="rtag" style="background:${RAR[g.tier]}">${RARN[g.tier]}</span></div></div><span class="costb">${ic('intel', RES.intel)}${g.intel_cost}</span></div>
      <div class="gart">${art ? `<img src="${art}" alt="">` : ''}</div>
      <div class="gbot"><div class="gstats">${stats.map(([v, i, l, on]) => `<div><b${onText(on)}>${v}</b><span>${ic(i)}${l}</span></div>`).join('')}</div>
      ${g.gcombo ? `<div class="gcombo">${roleB(g.gcombo.role, true)}<span>${fx(g.gcombo.text)}</span></div>` : `<div class="gcombo none">Reveal 1 card per ${ic('prec', RES.prec)}</div>`}</div>
    </div></div>`;
}
function gunBack(label, sub, bg, dark) { return `<div class="card gunL gback" style="--gb:${bg};color:${dark ? '#1C2017' : '#fff'}"><div class="bk"><div class="bl">${label}</div><div class="bs">${sub}</div></div></div>`; }
function locCard(def, kind, tier, size, gunAt, centre) {
  const e = WD.ENVS[def];
  const ph = `${ROLE[e.affinity].name.toUpperCase()} LOOT`;
  const slots = Array.from({ length: size }, (_, i) => `<i class="${i === gunAt ? 'g' : ''}">${i === gunAt ? ic('ammo', '#fff') : ''}</i>`).join('');
  const lart = fs.existsSync(path.join(ART_DIR, 'locs', def + '.jpg')) ? `art/locs/${def}.jpg` : null;
  return `<div class="bigloc">${lart ? `<div class="lart"><img src="${lart}" alt=""></div>` : ''}
    <div class="zone"><div class="zin">LOOT STACK<br><small>${size} cards, face up · start: a Common gun on top<br>each round a fresh card lands on top<br>(over ${size}: the bottom card leaves)<br>only the top card is for sale</small></div></div>
    <div class="linfo">
      <div class="lleft"><div class="gname">${esc(e.name)}</div>
        <div class="cover">${e.cover ? `Cover −${e.cover}` : 'No cover'}<small>${e.cover ? `Hits on you here: −${e.cover} damage` : 'Open ground.'}</small></div>
        ${e.bonusText ? `<div class="arrive"><b>HERE</b> ${fx(e.bonusText.replace(/^\+?(\d+) (Movement|Precision|Intel|Armor|extra shot)/, 'Gain $1 $2'))}<small> every turn</small></div>` : '<div class="arrive dim">No bonus.</div>'}</div>
      <div class="lright"><div class="lab">STACK · top first</div><div class="stack">${slots}</div></div>
    </div>
    <div class="lhead"><span>${ph}</span><span>2 in 3 refills</span></div>
  </div>`;
}
function perkCard(k) {
  const L = WD.LOADOUT[k]; const r = ROLE[L.arch];
  return `<div class="card perk" style="--rc:${r ? r.color : '#5B6152'}">
    <div class="phead"><span>PERK</span><span>${r ? `${shapeSvg(L.arch, 'pshape')} ${r.name}` : 'Any build'}</span></div>
    <div class="cin"><div class="gname">${esc(L.name)}</div>
    ${L.trig ? `<div class="trig">TRIGGER · once per turn</div>` : '<div class="trig">ALWAYS ON</div>'}
    <div class="main big">${fx(L.text)}</div>
    <div class="foot"><span>Loadout perk</span></div></div></div>`;
}
const refTurn = () => `<div class="card ref"><div class="phead dark"><span>YOUR TURN</span><span>reference</span></div><div class="cin small2">
  <ol><li><b>Ready</b>: your Loadout cards fire, then your location's HERE bonus.</li>
  <li><b>Play</b> cards (any order). Squad lines pay for each other card of their squad in play.</li>
  <li><b>Move once</b>: 1 ${ic('move', RES.move)} per space.</li>
  <li><b>Loot</b>: up to ${T.buyCap} buys: top card here (next door +1 ${ic('intel', RES.intel)}) or the Buy Station (${T.supplyCost} ${ic('intel', RES.intel)}). Cycle: 1 ${ic('intel', RES.intel)} or 1 ${ic('move', RES.move)}.</li>
  <li><b>Fire</b>: commit ${ic('prec', RES.prec)}, reveal that many cards, count ${ic('hm')}. Spend what you committed, then Recoil more ${ic('prec', RES.prec)}.</li>
  <li><b>End</b>: unused ${ic('move', RES.move)} → ${ic('def', '#475827')} (max ${T.digIn}). Discard all but the Loadout, draw 5.</li></ol></div></div>`;
const refSquad = () => `<div class="card ref"><div class="phead dark"><span>SQUAD &amp; RALLY</span><span>reference</span></div><div class="cin small2">
  <p><b>Squad</b>: a Squad line pays once for <b>each other</b> card of its squad in play this turn, up to ×${T.squadCap}. Loadout cards count.</p>
  <p><b>Rally</b> at ${T.rally.join(' and ')} cards of one squad in play, once per turn each:</p>
  ${WD.SQUADS.map(a => `<p>${roleB(a, true)} 3: ${fx(WD.RALLY_TEXT[a][3])} · 5: ${fx(WD.RALLY_TEXT[a][5])}</p>`).join('')}
  <p><small><b>Mark</b>: next shot needs 1 fewer ${ic('hm')} per step. <b>Pierce</b>: ignore cover. <b>Steady</b>: each shot reveals 1 more card free.</small></p></div></div>`;
const hpCard = (who, col) => `<div class="card hp" style="--rc:${col}"><div class="phead" style="background:${col}"><span>${ic('heart', '#fff')} HEALTH</span><span>${who}</span></div><div class="cin"><div class="hpgrid">${Array.from({ length: T.hp }, (_, i) => `<span>${T.hp - i}</span>`).join('')}</div><div class="small">Start at ${T.hp}. Mark damage with a paperclip. Off the track = eliminated.</div></div></div>`;
const OPFACE = {
  me: `<svg viewBox="0 0 64 64" class="opface" aria-hidden="true"><defs><clipPath id="ofA"><circle cx="32" cy="32" r="30"/></clipPath></defs><g clip-path="url(#ofA)"><rect width="64" height="64" fill="#16343A"/><path d="M4 70c2-14 12-20 28-20s26 6 28 20z" fill="#2C3A2A"/><path d="M20 52l12 6 12-6 2 8H18z" fill="#3E4E36"/><path d="M22 40c0 7 4 12 10 12s10-5 10-12v-6H22z" fill="#C49A74"/><path d="M24 44c2 4 5 6 8 6s6-2 8-6c-2 2-5 3-8 3s-6-1-8-3z" fill="#9C7556"/><path d="M15 31c0-11 8-19 17-19s17 8 17 19v3H15z" fill="#4A5A3A"/><path d="M15 31h34v4H15z" fill="#3A4730"/><rect x="18" y="27" width="28" height="9" rx="4.5" fill="#101614"/><rect x="20" y="28.5" width="11" height="6" rx="3" fill="#1FB0C4"/><rect x="33" y="28.5" width="11" height="6" rx="3" fill="#1FB0C4"/><path d="M21 30h5" stroke="#B9F1F8" stroke-width="1.4" stroke-linecap="round"/><path d="M34 30h5" stroke="#B9F1F8" stroke-width="1.4" stroke-linecap="round"/><path d="M46 36c3 1 4 4 3 8l-6 3" fill="none" stroke="#101614" stroke-width="2"/><circle cx="43" cy="47" r="1.8" fill="#101614"/></g><circle cx="32" cy="32" r="30" fill="none" stroke="#1FB0C4" stroke-width="4"/></svg>`,
  them: `<svg viewBox="0 0 64 64" class="opface" aria-hidden="true"><defs><clipPath id="ofB"><circle cx="32" cy="32" r="30"/></clipPath></defs><g clip-path="url(#ofB)"><rect width="64" height="64" fill="#3A1814"/><path d="M4 70c2-14 12-20 28-20s26 6 28 20z" fill="#2A2622"/><path d="M14 36c0-13 8-23 18-23s18 10 18 23c0 9-6 16-18 16S14 45 14 36z" fill="#2B2B28"/><path d="M18 24c4-6 9-8 14-8s10 2 14 8" fill="none" stroke="#3E3D38" stroke-width="2"/><circle cx="25" cy="32" r="5.5" fill="#101010"/><circle cx="39" cy="32" r="5.5" fill="#101010"/><circle cx="25" cy="32" r="4" fill="#E0482F"/><circle cx="39" cy="32" r="4" fill="#E0482F"/><circle cx="23.6" cy="30.6" r="1.2" fill="#FFC2B4"/><circle cx="37.6" cy="30.6" r="1.2" fill="#FFC2B4"/><path d="M27 40h10l3 6c-2 3-5 4-8 4s-6-1-8-4z" fill="#3A3A36"/><circle cx="32" cy="46" r="4.5" fill="#1A1A18" stroke="#55534C" stroke-width="1.5"/><path d="M29.5 44.5l5 3M29.5 47.5l5-3" stroke="#55534C" stroke-width="1"/></g><circle cx="32" cy="32" r="30" fill="none" stroke="#C8442B" stroke-width="4"/></svg>`,
};
const tokens = () => `<div class="card toks"><div class="cin"><div class="tk face">${OPFACE.me}</div><div class="tk face">${OPFACE.them}</div><div class="tk face">${OPFACE.me}</div><div class="tk face">${OPFACE.them}</div><div class="small">Operator tokens — cut out, stand on a location card. Spares included.</div></div></div>`;
function back(label, sub, color) { return `<div class="card back" style="--rc:${color}"><div class="bk"><div class="bl">${label}</div><div class="bs">${sub}</div></div></div>`; }

// ---------- assemble the component list ----------
const cards = [];
const add = (html, n = 1) => { for (let i = 0; i < n; i++) cards.push(html); };
// starters for 2 players
for (const id of ['T001', 'T002', 'T004', 'T005']) add(tacCard(WD.CARDS[id]), 2 * ({ T001: T.stSprint, T002: T.stScout, T004: T.stAim, T005: 2 }[id]));
// Buy Station piles
for (const id of T.station) add(tacCard(WD.CARDS[id]), T.stationCopies);
// role cards
for (const role of ['assault', 'recon', 'support', 'engineer']) for (const id in WD.CARDS) { const d = WD.CARDS[id]; if (d.archetype === role) add(tacCard(d), d.copies); }
// guns: 2 starting pistols + a fixed loot set per tier
const guns = [gunCard('pistol-0', 0), gunCard('pistol-0', 0)];
// same component sets as the digital version
for (const t of [1, 2, 3]) for (const id of WD.GUNSET[t]) guns.push(gunCard(id, t));
guns.push(gunBack('LOOT GUN', 'Tier ›', GUN_BG[0]), gunBack('LOOT GUN', 'Tier ››', GUN_BG[0]), gunBack('LOOT GUN', 'Tier ›››', GUN_BG[0]), gunBack('SIDEARM', 'Starting gun', GUN_BG[0]));
const locs = WD.LOCSET.map(L => locCard(L.def, L.ph, WD.locTier(L), WD.locSize(L), L.gun, !!L.centre));
if (T.perks) for (const k in WD.LOADOUT) add(perkCard(k));
add(refTurn(), 2); add(refSquad(), 2); add(hpCard('Operator A', '#1FB0C4')); add(hpCard('Operator B', '#C8442B')); add(tokens());
const backs = [back('LOOT', 'Tier › · card', '#3FA34D'), back('LOOT', 'Tier ›› · card', '#2F7FD8'), back('LOOT', 'Tier ››› · card', '#9B4DCA')].concat(T.perks ? [back('PERK', 'Loadout', '#C2531A')] : []);

const pages = []; for (let i = 0; i < cards.length; i += 9) pages.push(cards.slice(i, i + 9));
const gunPages = []; for (let i = 0; i < guns.length; i += 8) gunPages.push(guns.slice(i, i + 8));
const locPages = []; for (let i = 0; i < locs.length; i += 4) locPages.push(locs.slice(i, i + 4));
const bigBack = (l, sub, c) => `<div class="bigloc back" style="--rc:${c}"><div class="bk"><div class="bl">${l}</div><div class="bs">${sub}</div></div></div>`;
const locBacks = [bigBack('LOCATION', 'START', '#5B6152'), bigBack('LOCATION', 'PHASE 1', '#3FA34D'), bigBack('LOCATION', 'PHASE 2', '#2F7FD8'), bigBack('LOCATION', 'PHASE 3', '#9B4DCA')];
const counts = { total: cards.length + guns.length - 4 };

// ---------- rules ----------
const RULES = `
<section class="page rules"><div class="rcol">
<h1>WARZONE DECKBUILDER <span>print &amp; play · v6 engine &amp; synergy</span></h1>
<p class="lead">Two operators drop into a shrinking battlefield. Loot squad cards, build an engine that hits harder every turn, and win the gunfight before the storm ends it.</p>
<h2>Components</h2>
<ul><li>${2 * (T.stSprint + T.stScout + T.stAim + 2)} starter cards (10 per player) · ${T.station.length * T.stationCopies} Buy Station cards (${T.stationCopies} of each squad basic)</li>
<li>${Object.values(WD.CARDS).filter(d => d.tier && d.copies).reduce((a, d) => a + d.copies, 0)} loot cards in 3 tiers, 4 squads (incl. 12 Loadout cards) · ${[1, 2, 3].reduce((a, t) => a + WD.GUNSET[t].length, 0)} loot guns + 2 starting pistols</li>
<li>${WD.LOCSET.length} location cards (${T.zones} are used each game) · references, health tracks, tokens</li></ul>
<p class="small">Print on Letter, 100% scale, cut on the lines. Sleeve loot cards with a tier back (last page).</p>
<h2>Setup</h2>
<ol><li>Sort loot into three face-down decks by tier (cards and guns together). Shuffle each. If a deck runs out, draw from the next tier.</li>
<li>Shuffle the location cards and lay ${T.zones} in a row. Put the last one back in the box.</li>
<li>Each location gets a <b>loot stack</b> of ${T.stackSize}, face up: a Common gun on top (while they last), then tier › cards. For each card roll a die: on 1–4 take the first card of the location's squad from the deck, otherwise the top card.</li>
<li>Each player: 10 starters, a Sidearm pistol, a health track at ${T.hp}, a token. Players start on the 2nd and 6th locations. Draw 5 cards. Random first player; a die decides which end of the row closes first.</li></ol>
<h2>Your turn</h2>
<ol><li><b>Ready</b>: your Loadout cards give their effect, then your location's HERE bonus.</li>
<li><b>Play cards</b> to gain ${ic('move', RES.move)} Movement, ${ic('prec', RES.prec)} Precision, ${ic('intel', RES.intel)} Intel, ${ic('ammo', RES.ammo)} extra shots and ${ic('def', '#475827')} Armor. Leave played cards in front of you.</li>
<li><b>Move once</b>: 1 Movement per space. Arriving gives that location's HERE bonus.</li>
<li><b>Loot</b> up to <b>${T.buyCap} buys</b> (+1 for each <b>+1 Buy</b>): the top card of the stack where you stand, or next door for +${T.adjCost} Intel, or a Buy Station card (${T.supplyCost} Intel). <b>Cycle</b>: pay 1 Intel or 1 Movement to put the top card under its stack. <b>Hot Drop</b>: in rounds 1–${T.hotDrop} gained cards join your next hand; later your discard. <b>Promotion</b>: page 2.</li>
<li><b>Fire</b> (see right). <b>${ic('scrap', '#C2531A')} Scrap</b>: remove a card in your hand, play area or discard from the game (never below ${T.minDeck} cards). Buy Station service: ${T.stationScrapCost} Intel scraps a Sprint (once per turn, not a buy).</li>
<li><b>End</b>: <b>Spoils</b> if you dealt damage (page 2). Unused Movement becomes ${ic('def', '#475827')} Armor (up to ${T.digIn}). Discard your hand and played cards (not the Loadout), draw 5 (6 at ${T.lowHp} Health or less). Armor lasts until your next turn.</li></ol>
</div><div class="rcol">
<h2>Firing</h2>
<ol><li>You carry <b>one gun</b>. Buying a gun replaces yours (the old one goes under that stack).</li>
<li>Your rival must be within the gun’s <b>Range</b> (spaces between you; same location = 0). Every gun can fire at 0.</li>
<li><b>Commit</b> Precision: reveal one card from your deck per Precision committed, and count the ${ic('hm')} Hit Markers. <b>Steady</b>: each shot reveals 1 more card for free.</li>
<li><b>Recoil</b>: the shot spends the Precision you committed, then the gun's Recoil costs that much more (down to 0). Plan your shots: big commits are sure, small ones leave Precision for the next shot.</li>
<li>Read the <b>damage ladder</b>: reach the first step to hit, the second for a big hit. <b>Mark</b>: your next shot needs 1 fewer ${ic('hm')} on every step. Cover at the target's location: −1 damage (<b>Pierce</b> ignores it). <b>Close quarters</b> (distance 0): ignore cover and Armor. Reaction cards in hand, then Armor, reduce damage. A hit deals at least 1.</li>
<li>Each gun fires up to its <b>Shots</b> per turn, plus any ${ic('ammo', RES.ammo)} extra shots. <b>Combat Knife</b>: distance 0 only, always hits.</li>
<li>Revealed cards go to your discard. Whenever your deck is empty, shuffle your discard to form a new deck.</li></ol>
<h2>The circle</h2>
<ul><li>At the end of rounds ${T.closeAfter.join(', ')} one end location closes (alternating ends): ${T.zones} → 1 location, the <b>final circle</b>, after round ${T.closeAfter[T.closeAfter.length - 1]}.</li>
<li>Its loot is lost. Caught outside: ${T.gasDmg} damage +1 per extra space, then move to the nearest safe location.</li>
<li>Final circle: at each round end the storm hits both for ${T.finalStorm.join(', ')}. <b>Hard end</b> after round ${T.hardEnd}: the most Health wins.</li>
<li>Every round end: each safe stack gets 1 fresh card on top (tier › rounds 1–3, ›› rounds 4–7, ››› after); a stack over ${T.stackSize} loses its bottom card. Supply crates: after rounds ${T.crateRounds.join(' and ')}, 3 tier ››› items (a gun first) go on top of the middle stack.</li>
<li>The first player alternates each round.</li></ul>
<h2>Winning</h2><p>Reduce your rival to 0 Health. If both fall at once, the higher Health wins; equal is a draw.</p>
<p class="small">Tuned by simulation (about 8–9 rounds per game). Digital version: same rules; it also shows your <b>Threat</b> (expected damage this turn), your deck mix and an after-action report.</p>
</div></section>
<section class="page rules"><div class="rcol">
<h1>WARZONE DECKBUILDER <span>print &amp; play · page 2 · loot, promotion, tactics</span></h1>
<h2>Spoils</h2>
<p>At the end of a turn in which you dealt damage (any hit, a Sentry Turret too), before you discard: draw ${T.spoils} cards from the loot deck of this phase (tier › rounds 1–3, ›› rounds 4–7, ››› after; guns go back). The first is the first card of your <b>main squad</b> (the squad you own most cards of) found in that deck, if there is one. Keep 1 in your discard pile, or none. Shuffle the rest back.</p>
<h2>Field Promotion</h2>
<p>Once per turn, pay ${T.promoteCost} ${ic('intel', RES.intel)} Intel and <b>one of your buys</b>: swap a starter (Sprint, Scout, Steady Aim, Recon Run) in your hand, play area or discard pile for a Buy Station basic of the squad you choose (from its pile, while it lasts). The starter leaves the game. The basic goes where the starter was if that was your hand; otherwise to your discard pile.</p>
<h2>Squad Tactics</h2>
<p>Cards marked <b class="tacb" style="--rc:#1C2017">TACTIC</b> add a new kind of play. Their text is the rule; a few notes:</p>
<ul><li><b>Charge</b>: the +1 damage counts only for shots at distance 0.</li>
<li><b>Follow Through</b>: the draw happens right after the hit; you may play the cards and keep shooting.</li>
<li><b>Adrenaline</b>: each time a shot hits you, one Adrenaline goes from your discard pile to your hand (you play it next turn).</li>
<li><b>Intel Sweep</b>: look at your top 4 and put them back in any order (your shots reveal from the top).</li>
<li><b>Expose</b>: Reaction cards and Armor don't reduce your hits this turn. Cover still does (Pierce ignores cover).</li>
<li><b>Hold the Angle</b>: at End, set aside up to ${T.overwatchCap} unspent Precision. If your rival ends their next turn within your gun's range, fire once with it: reveal that many cards, use your gun's ladder (no Recoil, no Mark). Otherwise it is lost at your Ready.</li>
<li><b>Fortify</b>: at your next Ready keep your Armor (up to ${T.fortifyCap}) instead of dropping it.</li>
<li><b>Suppressing Barrage</b>: on the rival's next turn the first 1 Movement and 2 Precision they gain are lost.</li>
<li><b>Jury-Rig</b>: repeats the play line (not the Squad line) of the card you played just before it this turn.</li>
<li><b>Sentry Turret</b> (Loadout): when deployed and at every Ready, if your rival is 0–${T.turretRange} away, reveal 1 card: 1 ${ic('hm')} hits for 2 (cover and Armor apply).</li>
<li><b>Contraband Run</b>: this turn your buys may take the top card of any stack on the map, for its printed cost.</li></ul>
</div><div class="rcol">
<h2>Squads &amp; Loadout</h2>
<p>${roleB('assault')} Assault: hits hit harder · ${roleB('recon')} Recon: aim and Mark · ${roleB('support')} Support: extra shots, Steady, Armor · ${roleB('engineer')} Engineer: Intel, +1 Buy, Scrap. Starters have no squad.</p>
<p><b>Squad line</b>: pays once for <b>each other card</b> of its squad in play this turn, up to ×${T.squadCap}, in any order. <b>Rally</b>: with ${T.rally.join(' and ')} cards of one squad in play you also get that squad's Rally bonus (reference card). <b>Loadout</b> cards go to your Loadout row (${T.loadoutSlots} slots), give their effect at every Ready and count for Squad every turn. To play a third, discard one from the row or use the new card once.</p>
<h2>What changed in this edition</h2>
<ul><li>Health ${T.hp} (was 40): you build more, so fights last longer.</li>
<li>Every gun's Hit Marker steps are 1 higher than the first edition's.</li>
<li>12 Squad Tactics replace 12 cards; the card count is the same.</li>
<li>Recon Rally: Mark and hits +1 damage. Dead Drop's Squad line: +1 Buy.</li>
<li>Support's extra shots were trimmed (Ammo Box, Bandolier, Resupply, Field Pack).</li></ul>
<h2>Digital only: Operator rank</h2>
<p>The web version keeps a rank on your device: XP for every match (40 to play, +60 for a win, +1 per damage up to 80, +20 for reaching the final circle). Ranks unlock variety, never power: the <b>Daily Drop</b> (the same seed for everyone that day), and three <b>Operations</b> that change the drop for both players: ${WD.RANKS.filter(r => r.unlock && r.unlock.kind === 'op').map(r => `<b>${r.unlock.name}</b> (${esc(r.unlock.text)})`).join('; ')}. At the table you can play any Operation by agreement.</p>
</div></section>`;

const html = `<!doctype html><html><head><meta charset="utf-8"><title>Warzone Deckbuilder — Print &amp; Play</title><style>
@page { size: Letter; margin: 0; }
* { box-sizing: border-box; }
body { margin: 0; font-family: Inter, 'DejaVu Sans', sans-serif; color: #1C2017; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
svg.i { width: 1.05em; height: 1.05em; vertical-align: -0.17em; margin: 0 1px; }
.page { width: 8.5in; height: 11in; page-break-after: always; position: relative; overflow: hidden; }
.sheet { display: grid; grid-template-columns: repeat(3, 2.5in); grid-template-rows: repeat(3, 3.5in); width: 7.5in; margin: 0.25in auto 0; }
.sheet .card { border: 0.5px dashed #9AA08F; }
.pfoot { position: absolute; bottom: 0.08in; left: 0; right: 0; text-align: center; font-size: 7pt; color: #8A8F80; }
.card { width: 2.5in; height: 3.5in; position: relative; overflow: hidden; background: #fff; display: flex; }
.cin { flex: 1; display: flex; flex-direction: column; padding: 0.12in 0.13in 0.1in; gap: 5px; min-width: 0; }
.foot { margin-top: auto; display: flex; justify-content: space-between; align-items: center; font-size: 9pt; color: #5B6152; } .foot svg.rank.inl { width: 12px; }
.cost { font-weight: 800; font-size: 13pt; color: #1C2017; } .cost svg.i { width: 15px; height: 15px; }
.chev { font-weight: 900; letter-spacing: -1px; }
.hm { white-space: nowrap; display: inline-flex; gap: 1px; } .hm svg { width: 17px; height: 17px; margin: 0; }
.roleb { display: inline-flex; width: 18px; height: 18px; border-radius: 4px; color: #fff; align-items: center; justify-content: center; margin: 0 2px 0 0; vertical-align: middle; position: relative; top: -1px; }
.roleb svg.shp { width: 12px; height: 12px; display: block; }
.roleb.sm { width: 16px; height: 16px; } .roleb.sm svg.shp { width: 10.5px; height: 10.5px; }
svg.rank { display: block; color: currentColor; }
svg.rank.inl { display: inline-block; width: 13px; height: auto; vertical-align: middle; position: relative; top: -1px; margin: 0 1px; }
/* tactical */
.tac .band { width: 0.3in; background: var(--rc); color: #fff; display: flex; flex-direction: column; align-items: center; padding-top: 0.12in; gap: 8px; flex-shrink: 0; }
.tac.grey .band { width: 0.3in; background: #B9BCAE; }
.band svg.bshape { width: 19px; height: 19px; } .band svg.bchev { width: 21px; height: auto; }
.top { display: flex; justify-content: space-between; gap: 4px; align-items: flex-start; }
:root { --fn: 12.5pt; --fm: 16pt; --fc: 10pt; }
.nm { font-weight: 800; font-size: var(--fn); line-height: 1.05; }
.main { font-size: var(--fm); line-height: 1.35; font-weight: 700; margin: 6px 0 4px; } .main svg.i { width: 1.05em; height: 1.05em; vertical-align: -0.18em; }
.main.big { font-size: 12.5pt; font-weight: 600; }
.combo { border: 1.4px solid var(--rc, #1C2017); border-radius: 6px; padding: 5px 7px; font-size: var(--fc); line-height: 1.32; font-weight: 600; } .tac .combo .roleb { margin-right: 4px; } .cor { margin: 0 3px 0 -1px; font-weight: 800; }
.combo svg.i { width: 1.1em; height: 1.1em; vertical-align: -0.2em; }
.gun .combo { border-color: #1C2017; }
.combo.dim { opacity: .5; }
.ct { font-weight: 800; font-size: 8pt; letter-spacing: .06em; margin-right: 4px; display: inline-flex; align-items: center; gap: 2px; vertical-align: middle; position: relative; top: -1px; }
.ct .roleb { margin: 0; top: 0; }
.react { font-size: 9pt; background: #EFF0E8; border-radius: 4px; padding: 4px 6px; line-height: 1.3; }
.tacb { display: inline-block; font-size: 6.5pt; letter-spacing: .08em; background: var(--rc, #1C2017); color: #fff; border-radius: 3px; padding: 1px 4px; vertical-align: 1px; }
.tac .main:has(.tacb) { font-size: calc(var(--fm) * 0.86); line-height: 1.28; }
.scrap { font-weight: 800; color: #C2531A; }
/* card art: full width of the text column, just above the footer */
.tac .cin { overflow: hidden; } .tac .txt { flex: 1 1 auto; min-height: 0; overflow: hidden; display: flex; flex-direction: column; gap: 5px; }
.tac .art { margin: 4px -0.13in 0 -0.13in; height: 1.2in; flex: 0 0 1.2in; display: flex; align-items: center; justify-content: center; overflow: hidden; }
.tac .art img { width: 100%; height: 100%; object-fit: contain; }
.tac .art img { width: 100%; height: 100%; object-fit: contain; object-position: center bottom; }
.tac .art + .foot { margin-top: 2px; }
/* layout: Hit Markers down the band, role + rarity at its foot, cost top right, no footer */
.tac.nl .band { justify-content: space-between; padding: 0.1in 0 0.1in; }
.tac.nl.grey .band { width: 0.3in; }
.bhm { display: flex; flex-direction: column; align-items: center; gap: 3px; color: #fff; }
.bhm svg.i { width: 20px; height: 20px; margin: 0; }
.tac.grey .bhm, .tac.grey .bid { color: #1C2017; }
.bid { display: flex; flex-direction: column; align-items: center; gap: 6px; color: #fff; }
.tac.nl .cin { padding-bottom: 0.04in; }
.tac.nl .art { height: 1.4in; flex-basis: 1.4in; margin-bottom: 0; }
.tac.nl .top { align-items: center; border-bottom: 1.5px solid var(--rc); padding-bottom: 5px; margin-bottom: 1px; } .tac.nl.grey .top { border-bottom-color: #B9BCAE; }
.tac.nl .costb { flex-shrink: 0; }
/* header variants */
.tv .cin { padding-bottom: 0; } .tv .art { margin-bottom: 0; height: 1.38in; flex-basis: 1.38in; }
.hd { display: flex; align-items: center; gap: 6px; margin: 0 -0.06in 2px; padding: 5px 7px; border-radius: 6px; min-height: 30px; }
.hd .nm { flex: 1; min-width: 0; font-size: 12.5pt; line-height: 1.05; } .hdr { display: inline-flex; align-items: center; gap: 6px; flex-shrink: 0; }
.hd .hm svg { width: 15px; height: 15px; }
.sep { width: 1.5px; height: 16px; background: currentColor; opacity: .35; display: inline-block; }
.costb { display: inline-flex; align-items: center; gap: 1px; font-weight: 900; font-size: 13pt; } .costb svg.i { width: 15px; height: 15px; }
.hv1 { background: color-mix(in srgb, var(--rc) 16%, #fff); }
.hv2 { background: #1C2017; color: #fff; } .hv2 .hm svg { color: #fff; }
.hv3 { background: color-mix(in srgb, var(--rc) 16%, #fff); }
.coin { width: 0.3in; height: 0.3in; margin: -0.06in 0 2px; background: #fff; color: #1C2017; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-direction: column; line-height: .9; box-shadow: 0 0 0 2px var(--rc), 0 0 0 3.5px #1C2017; }
.coin svg.i { width: 9px; height: 9px; margin: 0; } .coin b { font-size: 11pt; font-weight: 900; }
.tv3 .band { padding-top: 0.14in; }
.tv4 .band { padding-top: 0.42in; }
.tv4 .cin { padding-top: 0; overflow: visible; } .tv4 .txt { overflow: visible; } .tv4 .hd .nm { padding-left: 0.02in; } .hv4 { background: var(--rc); color: #fff; margin: 0 -0.13in 4px -0.13in; border-radius: 0; padding: 8px 0.13in 7px; } .hv4 .hm svg { color: #fff; }
.tac.grey .hv4 { color: #1C2017; } .tac.grey .hv4 .hm svg { color: #1C2017; }
.hv5 { background: #EFF0E8; } .hv5 .costb { background: #fff; border: 1.5px solid #B98A10; border-radius: 12px; padding: 0 6px 0 3px; } .hv5 .nm { margin-left: 2px; }

/* perk header role shape */
.phead svg.pshape { width: 11px; height: 11px; vertical-align: -1px; color: #fff; display: inline-block; }
/* gun cards: landscape 3.5 x 2.5 in */
.card.gunL { width: 3.5in; height: 2.5in; flex-direction: row; }
.gband { width: 0.56in; background: var(--gb); color: #fff; display: flex; flex-direction: column; align-items: center; justify-content: space-between; padding: 0.07in 0; flex-shrink: 0; }
.gunL.sec .gband { color: #1C2017; }
.gsteps { display: flex; flex-direction: column; align-items: center; gap: 3px; width: 100%; }
.gst1 { width: 0.47in; border-radius: 4px; background: rgba(255,255,255,.14); display: flex; flex-direction: column; align-items: center; padding: 3px 0 1px; line-height: 1; }
.gunL.sec .gst1 { background: rgba(0,0,0,.08); }
.gst1 .hg { display: grid; grid-template-columns: repeat(3, 10px); gap: 1px 2px; justify-content: center; } .gst1 .hg svg.i { width: 10px; height: 10px; margin: 0; }
.gst1 b { font-size: 15pt; font-weight: 900; margin-top: 1px; }
.gst1.top { background: #fff; color: #1C2017; } .gst1 .auto { font-size: 6.5pt; font-weight: 900; letter-spacing: .05em; } .gunL.sec .gst1.top { background: #1C2017; color: #fff; }
.gid { display: flex; flex-direction: column; align-items: center; gap: 4px; } .gid svg.bchev { width: 19px; height: auto; } .gslot { font-weight: 900; font-size: 11pt; }
.gmain { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 3px; padding: 0.08in 0.1in 0.07in; }
.gtop { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 1.5px solid var(--gb); padding-bottom: 3px; }
.gtl .nm { font-size: 13.5pt; white-space: nowrap; display: block; }
.gsub { display: flex; gap: 4px; margin-top: 2px; }
.ttag { display: inline-block; border: 1.3px solid #3B4034; color: #1C2017; font-weight: 800; font-size: 7pt; letter-spacing: .06em; text-transform: uppercase; padding: 0 5px; border-radius: 3px; white-space: nowrap; }
.rtag { display: inline-block; color: #fff; font-weight: 800; font-size: 7pt; letter-spacing: .06em; text-transform: uppercase; padding: 1.3px 6px; border-radius: 3px; white-space: nowrap; }
.gart { flex: 1; min-height: 0; display: flex; } .gart img { width: 100%; height: 100%; object-fit: contain; object-position: center; }
.gbot { display: flex; gap: 5px; align-items: stretch; }
.gstats { display: flex; gap: 3px; } .gstats div { background: #EFF0E8; border-radius: 4px; text-align: center; padding: 1px 3px; min-width: 0.36in; }
.gstats b { display: block; font-size: 11.5pt; line-height: 1.1; } .gstats span { font-size: 6pt; color: #5B6152; letter-spacing: .03em; text-transform: uppercase; } .gstats svg.i { width: 8px; height: 8px; }
.gcombo { flex: 1; display: flex; align-items: center; gap: 3px; border: 1.4px solid #1C2017; border-radius: 6px; padding: 2px 5px; font-size: 8.5pt; font-weight: 600; line-height: 1.25; white-space: nowrap; } .gcombo.none { border-style: dashed; color: #8A8F80; font-weight: 500; } .gcombo svg.i { width: 1.05em; height: 1.05em; vertical-align: -0.2em; }
.gback { background: var(--gb); align-items: center; justify-content: center; } .gback .bk { color: inherit !important; border-color: currentColor !important; } .gback .bk { text-align: center; } .gback .bl { font-weight: 900; font-size: 20pt; letter-spacing: .12em; } .gback .bs { font-size: 10pt; margin-top: 4px; opacity: .85; }
.sheet.gun8 { grid-template-columns: repeat(2, 3.5in); grid-template-rows: repeat(4, 2.5in); width: 7in; }
/* gun */
.gun { flex-direction: column; border: 3px solid var(--gc) !important; } .gun .cin { gap: 4px; padding-top: 0.09in; } .gun .combo { font-size: 9.5pt; padding: 4px 6px; }
.ghead { background: #1C2017; color: #fff; font-size: 8pt; letter-spacing: .06em; font-weight: 700; padding: 6px 9px; display: flex; justify-content: space-between; border-bottom: 4px solid var(--gc); }
.gr { color: var(--gc); }
.gname { font-weight: 800; font-size: 14pt; line-height: 1.08; }
.stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 3px; }
.stats div { background: #EFF0E8; border-radius: 4px; text-align: center; padding: 2px 0; }
.stats b { display: block; font-size: 14pt; } .stats span { font-size: 7.5pt; letter-spacing: .05em; color: #5B6152; } .stats svg.i { width: 11px; height: 11px; }
.lab { font-size: 7.5pt; font-weight: 800; letter-spacing: .08em; color: #5B6152; }
.ladder { display: flex; align-items: center; gap: 2px; flex-wrap: nowrap; } .ladder i { font-size: 8pt; }
.ls { border: 1px solid #B9BCAE; border-radius: 4px; padding: 2px 4px; font-size: 9pt; display: inline-flex; gap: 4px; align-items: center; }
.ls b { font-size: 12.5pt; } .ls svg.i { width: 11px; height: 11px; } .ls.top { border: 1.5px solid #D9A400; } .ladder i { color: #8A8F80; font-style: normal; }
.mods { display: flex; flex-wrap: wrap; gap: 3px; } .mods span { font-size: 8pt; border: 1px solid #B9BCAE; border-radius: 3px; padding: 1px 4px; } .mods .none { color: #8A8F80; }
.skin { font-size: 8pt; font-style: italic; color: #8a6d00; font-weight: 700; }
/* location */
.loc, .perk, .ref, .hp { flex-direction: column; }
.lhead, .phead { background: #5B6152; color: #fff; font-size: 8.5pt; align-items: center; letter-spacing: .08em; font-weight: 800; padding: 5px 8px; display: flex; justify-content: space-between; }
.phead { background: var(--rc); } .phead.dark { background: #1C2017; }
.cover { font-weight: 800; font-size: 13pt; } .cover small { display: block; font-weight: 500; font-size: 9pt; color: #5B6152; margin-top: 2px; }
.arrive { font-size: 12pt; font-weight: 600; } .arrive.dim { color: #8A8F80; font-size: 9pt; font-weight: 400; }
.stack { display: flex; gap: 5px; } .stack i { width: 0.32in; height: 0.44in; border: 1.5px solid #1C2017; border-radius: 4px; display: flex; align-items: center; justify-content: center; } .stack i.g { background: #1C2017; }
.small { font-size: 8.2pt; line-height: 1.3; color: #5B6152; }
.small2 { font-size: 8pt; line-height: 1.3; } .small2 ol { margin: 0; padding-left: 14px; } .small2 li { margin-bottom: 3px; } .small2 p { margin: 4px 0; }
.trig { font-size: 7pt; font-weight: 800; letter-spacing: .07em; color: var(--rc); }
.perk .gname { font-size: 15pt; }
.square { display: grid; grid-template-columns: 1fr 1fr; gap: 4px; text-align: center; font-weight: 700; font-size: 8.5pt; }
.square div { border: 1px solid #B9BCAE; border-radius: 4px; padding: 3px; } .square small { font-weight: 500; color: #5B6152; }
.hpgrid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 2px; } .hpgrid span { border: 1px solid #B9BCAE; text-align: center; font-weight: 800; font-size: 12pt; padding: 5px 0; border-radius: 3px; }
.hpgrid span:first-child { background: var(--rc); color: #fff; }
.toks .cin { display: grid; grid-template-columns: 1fr 1fr; align-content: start; gap: 8px; }
.tk { width: 0.9in; height: 0.9in; border-radius: 50%; color: #fff; font-weight: 900; font-size: 30pt; display: flex; align-items: center; justify-content: center; margin: 0 auto; border: 3px solid #1C2017; }
.toks .small { grid-column: 1 / -1; }
.back { background: var(--rc); } .bk { margin: auto; text-align: center; color: #fff; border: 2px solid rgba(255,255,255,.6); padding: 0.25in 0.15in; border-radius: 8px; width: 2in; }
.bl { font-weight: 900; font-size: 18pt; letter-spacing: .08em; } .bs { font-size: 10pt; margin-top: 4px; font-weight: 700; }
/* big location cards: 3.5 x 5.1 in, 4 per page */
.sheet.loc4 { grid-template-columns: repeat(2, 3.5in); grid-template-rows: repeat(2, 5.1in); width: 7in; margin-top: 0.35in; }
.bigloc { width: 3.5in; height: 5.1in; border: 0.5px dashed #9AA08F; background: #fff; display: flex; flex-direction: column; overflow: hidden; position: relative; }
.lart { position: absolute; left: 0; top: 0; width: 100%; height: 3.8in; overflow: hidden; }
.lart img { width: 100%; height: 100%; object-fit: cover; object-position: center top; display: block; }
.lart::after { content: ''; position: absolute; left: 0; right: 0; bottom: 0; height: 14%; background: linear-gradient(transparent, #fff); }
.bigloc .zone { position: relative; z-index: 1; }
.bigloc .lart ~ .zone { border-color: rgba(255,255,255,.75); background: rgba(18,21,15,.18); }
.bigloc .lart ~ .zone .zin { color: rgba(255,255,255,.92); text-shadow: 0 1px 3px rgba(0,0,0,.85); }
.bigloc .linfo, .bigloc .lhead { position: relative; z-index: 1; }
.bigloc .lhead { font-size: 9pt; padding: 6px 10px; margin-top: auto; }
.linfo { display: flex; gap: 8px; padding: 6px 10px 4px; height: 1.12in; }
.lleft { flex: 1; display: flex; flex-direction: column; gap: 3px; min-width: 0; }
.lright { width: 1.3in; display: flex; flex-direction: column; gap: 3px; align-items: flex-end; }
.bigloc .gname { font-size: 15pt; }
.bigloc .cover { font-size: 11.5pt; } .bigloc .cover small { font-size: 8pt; }
.bigloc .arrive { font-size: 11pt; }
.bigloc .stack { gap: 3px; flex-wrap: wrap; justify-content: flex-end; } .bigloc .stack i { width: 0.19in; height: 0.27in; border-radius: 3px; } .bigloc .stack i svg { width: 10px; height: 10px; }
.zone { margin: 0.12in auto 0.06in; width: 2.62in; height: 3.62in; border: 2px dashed #9AA08F; border-radius: 10px; display: flex; align-items: center; justify-content: center; text-align: center; color: #9AA08F; }
.zin { font-weight: 900; letter-spacing: .12em; font-size: 12pt; } .zin small { display: block; font-weight: 500; letter-spacing: 0; font-size: 8pt; line-height: 1.5; margin-top: 6px; }
.bigloc.back { background: var(--rc); }
/* rules */
.rules { display: grid; grid-template-columns: 1fr 1fr; gap: 0.3in; padding: 0.45in 0.5in; font-size: 9pt; line-height: 1.38; }
.rules h1 { font-size: 17pt; margin: 0 0 6px; letter-spacing: .02em; } .rules h1 span { display: block; font-size: 9pt; font-weight: 600; color: #5B6152; letter-spacing: .1em; text-transform: uppercase; }
.rules h2 { font-size: 10.5pt; margin: 12px 0 4px; text-transform: uppercase; letter-spacing: .06em; border-bottom: 1.5px solid #1C2017; padding-bottom: 2px; }
.rules ul, .rules ol { margin: 0; padding-left: 16px; } .rules li { margin-bottom: 3px; } .rules p { margin: 4px 0; } .lead { font-size: 10pt; font-weight: 600; }
.tk.face{background:none!important;padding:0}.tk.face svg{width:100%;height:100%;display:block}</style></head><body>${SYM}
${RULES}
${pages.map((p, i) => `<section class="page"><div class="sheet">${p.join('')}</div><div class="pfoot">Warzone Deckbuilder · print &amp; play · cards page ${i + 1}/${pages.length} · cut on the dashed lines (2.5 × 3.5 in)</div></section>`).join('\n')}
${gunPages.map((p, i) => `<section class="page"><div class="sheet gun8">${p.join('')}</div><div class="pfoot">Guns ${i + 1}/${gunPages.length} · 3.5 × 2.5 in, played sideways · the last page holds the gun backs</div></section>`).join('\n')}
${locPages.map((p, i) => `<section class="page"><div class="sheet loc4">${p.join('')}</div><div class="pfoot">Locations ${i + 1}/${locPages.length} · 3.5 × 5.1 in · the loot stack sits on the upper part; the info stays visible below</div></section>`).join('\n')}
<section class="page"><div class="sheet loc4">${locBacks.join('')}</div><div class="pfoot">Location backs (one per phase) — print and glue, or write the phase on the back</div></section>
<section class="page"><div class="sheet">${backs.join('')}</div><div class="pfoot">Card backs — print as many as you need, or slip one behind each card in a sleeve</div></section>
<script>
// shrink a card's text (never its art) until everything fits
// uniform text: no per-card shrinking
</script></body></html>`;
// ---------- asset sheet for the digital version: every unique component once, named ----------
// tools/build.js turns this sheet into the FACES table of the web build (scoped CSS, sprite, one HTML string per face).
function assetList() {
  const A = [];
  const seen = new Set();
  for (const id of ['T001', 'T002', 'T004', 'T005']) A.push(['card_' + id, tacCard(WD.CARDS[id])]);
  for (const id of T.station) A.push(['card_' + id, tacCard(WD.CARDS[id])]);
  for (const role of ['assault', 'recon', 'support', 'engineer']) for (const id in WD.CARDS) { const d = WD.CARDS[id]; if (d.archetype === role && d.copies) A.push(['card_' + id, tacCard(d)]); }
  A.push(['gun_pistol-0', gunCard('pistol-0', 0)]);
  for (const t of [1, 2, 3]) for (const id of WD.GUNSET[t]) if (!seen.has(id)) { seen.add(id); A.push(['gun_' + id, gunCard(id, t)]); }
  A.push(['back_gun_tier1', gunBack('LOOT GUN', 'Tier ›', GUN_BG[0])], ['back_gun_tier2', gunBack('LOOT GUN', 'Tier ››', GUN_BG[0])], ['back_gun_tier3', gunBack('LOOT GUN', 'Tier ›››', GUN_BG[0])], ['back_gun_sidearm', gunBack('SIDEARM', 'Starting gun', GUN_BG[1], true)]);
  WD.LOCSET.forEach((L, i) => A.push(['loc_L' + String(i + 1).padStart(2, '0'), locCard(L.def, L.ph, WD.locTier(L), WD.locSize(L), L.gun, !!L.centre)]));
  A.push(['back_loc_start', bigBack('LOCATION', 'START', '#5B6152')], ['back_loc_phase1', bigBack('LOCATION', 'PHASE 1', '#3FA34D')], ['back_loc_phase2', bigBack('LOCATION', 'PHASE 2', '#2F7FD8')], ['back_loc_phase3', bigBack('LOCATION', 'PHASE 3', '#9B4DCA')]);
  for (const k in WD.LOADOUT) A.push(['perk_' + k, perkCard(k)]);
  A.push(['back_loot_tier1', backs[0]], ['back_loot_tier2', backs[1]], ['back_loot_tier3', backs[2]], ['back_perk', backs[3]]);
  A.push(['ref_turn', refTurn()], ['ref_squad', refSquad()], ['health_A', hpCard('Operator A', '#1FB0C4')], ['health_B', hpCard('Operator B', '#C8442B')], ['tokens', tokens()]);
  return A;
}
function assetsHtml(A = assetList()) {
  const headPart = html.slice(0, html.indexOf('<body>') + 6) + SYM;
  return headPart + `<style>body{background:#fff}.asset{display:inline-block;margin:6px;vertical-align:top}</style>` + A.map(([n, h]) => `<div class="asset" data-name="${n}">${h}</div>`).join('\n') + '</body></html>';
}
function variantsHtml() {
  const headPart = html.slice(0, html.indexOf('<body>') + 6) + SYM;
  const pick = ['A21', 'S31', 'T002', 'E12'];
  const names = { 0: 'Current', 1: 'V1 · tinted bar', 2: 'V2 · dark bar', 3: 'V3 · cost coin on band', 4: 'V4 · full-bleed colour bar', 5: 'V5 · cost first, grey bar' };
  const rows = [0, 1, 2, 3, 4, 5].map(v => `<div class="vrow"><div class="vlab">${names[v]}</div>${pick.map(id => tacCard(WD.CARDS[id], v)).join('')}</div>`).join('');
  return headPart + `<style>.vrow{display:flex;gap:10px;align-items:center;margin:0 0 12px 12px}.vlab{width:1.3in;font-weight:800;font-size:11pt}.vrow .card{border:0.5px solid #9AA08F}</style><div style="padding:14px 0">${rows}</div><script>for (const t of document.querySelectorAll('.tac .txt')) { let z = 1; while (t.scrollHeight > t.clientHeight + 1 && z > 0.62) { z -= 0.03; t.style.zoom = z; } }</script></body></html>`;
}

// Used by tools/build.js, tools/pnp.js and the tests: nothing is written when this file is required.
module.exports = { html, assetList, assetsHtml, variantsHtml, counts, components: { cards: cards.length, guns: guns.length - 4, gunBacks: 4, locations: locs.length }, pages: { cards: pages.length, guns: gunPages.length, locations: locPages.length } };

// CLI (kept for compatibility): node gen.js → pnp.html next to this file; VARIANTS=1 / ASSETS=1 add the extra sheets.
if (require.main === module) {
  fs.writeFileSync(path.join(__dirname, 'pnp.html'), html);
  if (process.env.VARIANTS) fs.writeFileSync(path.join(__dirname, 'variants.html'), variantsHtml());
  console.log('cards', counts.total, 'card pages', pages.length);
  if (process.env.ASSETS) { const A = assetList(); fs.writeFileSync(path.join(__dirname, 'assets.html'), assetsHtml(A)); console.log('assets', A.length); }
}
