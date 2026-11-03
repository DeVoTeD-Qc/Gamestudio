#!/usr/bin/env python3
"""Builds timeline.json for replay.html from the real Studio Floor data and the git log.

Usage: python3 media/demo/build_timeline.py <data-dir> [game-dir]

<data-dir> is an export of the Studio Floor database (tasks/, activity/, chat/, progress/ as one
JSON file per document) plus gitlog.txt (`git log --reverse --format='%aI|%h|%s'`).
[game-dir] is the gameplay recording made by record_game.js (frames.json + marks.json + frames/);
it is optional, the game scene is left empty without it.

Everything shown in the replay comes from those files: task titles, owners, who created each task
(and from what), dependencies, progress texts (ordered by their doc-id timestamp, because many
`at` fields were guessed by agents), test counts quoted in task notes, commit subjects and times,
and the chat lines (lightly trimmed). Only captions and the pacing are authored here.
"""
import glob
import json
import os
import re
import sys
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'data')
GAME = sys.argv[2] if len(sys.argv) > 2 else None


def load(coll):
    out = {}
    for f in glob.glob(os.path.join(DATA, coll, '*.json')):
        out[os.path.basename(f)[:-5]] = json.load(open(f))
    return out


TASKS, CHAT, PROG, ACT = load('tasks'), load('chat'), load('progress'), load('activity')

# Usage-limit pause window. Source: the p18/p19 subagent transcripts (measured by the lead session):
# both agents stopped on the account's 5-hour usage limit at 06:57:01 UTC and resumed at 11:14:10 UTC.
# There was no other limit wait before the last commit (13:42). Board progress times can't be used for
# this: several were guessed by the agents.
LIMIT_PAUSE = ('06:57:01', '11:14:10')
COMMITS = []
for line in open(os.path.join(DATA, 'gitlog.txt')):
    iso, h, subj = line.rstrip('\n').split('|', 2)
    COMMITS.append({'at': iso, 'hash': h, 'subject': subj, 'wip': subj.startswith('WIP')})


def sod(s):
    """'2026-11-03T03:18:53+00:00' or '03:18:53' -> seconds of day (UTC)."""
    m = re.search(r'(\d\d):(\d\d)(?::(\d\d))?', s.split('T')[-1])
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3) or 0)


def commit_for(task_id):
    for c in COMMITS:
        if not c['wip'] and re.match(r'%s:' % re.escape(task_id), c['subject']):
            return c
    return None


def wip_first(task_id):
    for c in COMMITS:
        if c['wip'] and re.search(r'\b%s\b' % re.escape(task_id), c['subject']):
            return sod(c['at'])
    return None


def progress_of(task_id):
    rows = []
    for doc_id, p in PROG.items():
        if p.get('task') == task_id:
            rows.append((int(doc_id.rsplit('-', 1)[1]), p))
    rows.sort(key=lambda r: r[0])
    return [p for _, p in rows]


def chat_text(doc_id, keep=None):
    t = CHAT[doc_id]['text']
    if keep:
        return keep
    return t


AGENT_NAMES = {
    'master-orchestrator': 'Master Orchestrator', 'producer-agent': 'Producer', 'market-analyst': 'Market Analyst',
    'data-scientist': 'Data Scientist', 'sr-game-designer': 'Sr Game Designer', 'mid-game-designer': 'Mid Game Designer',
    'mechanics-developer': 'Mechanics Developer', 'game-feel-developer': 'Game Feel Developer',
    'sr-game-artist': 'Sr Game Artist', 'technical-artist': 'Technical Artist', 'ui-ux-agent': 'UI/UX Designer',
    'qa-agent': 'QA', 'lead': 'Lead (main session)', 'you': 'You'}

events, scenes, clock = [], [], []


def ev(t, k, **kw):
    kw.update({'t': round(t, 3), 'k': k})
    events.append(kw)


def scene(sid, start, dur, view, captions=(), title=None):
    scenes.append({'id': sid, 'start': start, 'end': start + dur, 'view': view, 'title': title,
                   'captions': [{'t': start + a, 'until': start + b, 'text': txt} for a, b, txt in captions]})
    return start


def task_def(tid, **over):
    t = TASKS[tid]
    d = {'id': tid, 'title': t['title'], 'agent': t['agent'], 'createdBy': t.get('createdBy'),
         'createdFrom': t.get('createdFrom'), 'depends': t.get('depends') or []}
    d.update(over)
    return d


def add(t, tid, status='todo', **over):
    ev(t, 'add', task=task_def(tid, **over), status=status)


def status(t, tid, st, **kw):
    ev(t, 'status', id=tid, status=st, **kw)


def agent(t, aid, st, task=None, text=None, pct=None):
    ev(t, 'agent', id=aid, status=st, task=task, text=text, pct=pct)


# --------------------------------------------------------------------------------------------
T = 0.0
# 1. Title card
scene('title', T, 4.5, 'title')
clock += [{'t': 0, 'utc': sod('02:05:00')}]
T += 4.5

# 2. The prompt
S = scene('prompt', T, 9, 'terminal', captions=[
    (0.3, 9, 'It starts with a plain request to one Claude Code session. No game code, no art.')])
ev(S + 0.4, 'term', who='you', text='Setup this AI game studio on my own repo and set it to Godot as the target engine.')
ev(S + 2.6, 'term', who='claude', text='Imported gamestudio-subagents, locked it to Godot 4.4.1, registered 12 subagents, pushed to GitHub.')
ev(S + 4.0, 'term', who='you', text='Start a new game project with the orchestrator.')
ev(S + 5.0, 'term', who='you', text='Concept: a card game with a shooter vibe. Simple for shooter players, deep for card players. Web first, design first.', note='paraphrased')
ev(S + 7.2, 'term', who='claude', text='Master Orchestrator created the Killstreak project (web, design mode).')
ev(S + 6.6, 'termnote', text='The studio kept every franchise name out: an original near-future setting (Port Vasel, HALBERD vs BLACK MERIDIAN).')
clock += [{'t': S + 2.4, 'utc': sod('02:05:31')}, {'t': S + 7.2, 'utc': sod('02:13:31')}]
T += 9

# 3. Design phase  (02:13:31 -> 02:22:20, commit 0d895d6)
S = scene('design', T, 10, 'floor', captions=[
    (0.2, 10, 'The Master Orchestrator splits the design phase into 7 tasks for specialist subagents.')])
ev(S, 'phase', phase='design')
ev(S, 'project', name='Killstreak', sub='Design · Web · Godot 4.4.1')
agent(S + 0.3, 'master-orchestrator', 'working', task='t7', text='Setting up Killstreak and planning the design phase')
design = ['t8', 't9', 't10', 't11', 't12', 't13', 't14']
for i, tid in enumerate(design):
    add(S + 0.8 + i * 0.35, tid, 'todo', fresh=True)
for i, tid in enumerate(design):
    a = TASKS[tid]['agent']
    t0 = S + 3.4 + i * 0.75
    status(t0, tid, 'doing')
    if a != 'master-orchestrator':
        agent(t0, a, 'working', task=tid)  # no live reports existed yet (added 02:44)
    status(t0 + 1.4, tid, 'review')
    if a != 'master-orchestrator':
        agent(t0 + 1.4, a, 'idle')
agent(S + 9.4, 'master-orchestrator', 'idle')
ev(S + 9.3, 'commit', hash='0d895d6', subject='Killstreak: complete design phase docs')
clock += [{'t': S, 'utc': sod('02:13:31')}, {'t': S + 9.4, 'utc': sod('02:22:20')}]
T += 10

# 4. Human review (approvals 02:30:11 .. 02:36:43, answers 02:38:26)
S = scene('review', T, 16, 'floor', captions=[
    (0.0, 7.8, 'Design deliverables wait for the studio head, who reviews them on the Studio Floor page.'),
    (7.8, 16, '10 open design questions, answered with quick picks. Title note: “Deckstreak”.')])
ev(S + 0.2, 'pulse', sel='#needsBtn')
approved = [('t8', '02:30:11'), ('t9', '02:33:54'), ('t10', '02:35:35'), ('t11', '02:36:04'), ('t12', '02:36:20'), ('t13', '02:36:30')]
add(S + 0.1, 't15', 'todo', fresh=True)
ev(S + 0.9, 'tap', sel='[data-card="t14"]')
ev(S + 1.2, 'drawer', kind='doc', task='t14', doc='design-review')
ev(S + 3.6, 'scroll', sel='#drawer .doc', to=380, dur=1.6)
for i, (tid, _) in enumerate(approved):
    status(S + 1.6 + i * 0.4, tid, 'done', review='approved')
ev(S + 5.6, 'tap', sel='#approveBtn')
status(S + 5.8, 't14', 'done', review='approved')
ev(S + 5.8, 'toast', text='Approved: 7 of 7 design deliverables')
ev(S + 6.4, 'drawer', kind=None)
ev(S + 7.0, 'tap', sel='[data-card="t15"]')
ev(S + 7.3, 'drawer', kind='questions', task='t15')
qs = TASKS['t15']['questions']
ans = TASKS['t15']['answers']
for i, q in enumerate(qs):
    a = ans[q['id']]
    t0 = S + 8.0 + i * 0.68
    if a.get('choice'):
        ev(t0, 'tap', sel='[data-opt="%s|%d"]' % (q['id'], q['options'].index(a['choice'])))
        ev(t0 + 0.12, 'answer', task='t15', q=q['id'], choice=a['choice'])
    if a.get('note'):
        ev(t0, 'tap', sel='[data-note="%s"]' % q['id'])
        ev(t0 + 0.12, 'answer', task='t15', q=q['id'], note=a['note'])
    ev(t0 - 0.3, 'scrollq', i=i)
ev(S + 15.0, 'drawer', kind=None)
status(S + 15.1, 't15', 'done')
clock += [{'t': S + 1.6, 'utc': sod('02:30:11')}, {'t': S + 5.8, 'utc': sod('02:36:43')}, {'t': S + 15.0, 'utc': sod('02:38:26')}]
T += 16

# 5. Planning (Producer 02:46 .. 02:53, 20 tasks; questions answered 03:07:04)
S = scene('plan', T, 11, 'floor', captions=[
    (0.0, 7.4, 'The Producer turns the design into a 20-task prototype plan, with dependencies.'),
    (7.4, 11, 'It needs 5 more answers first. The head picks a shorter, 5-match run.')])
ev(S, 'phase', phase='plan')
ev(S, 'project', name='Killstreak', sub='Milestones · Web · Godot 4.4.1')
ev(S, 'clearDone', ids=design + ['t15'])
add(S + 0.1, 't16', 'doing')
prod = progress_of('t16')
for i, p in enumerate(prod):
    agent(S + 0.3 + i * 0.9, 'producer-agent', 'working' if p['status'] != 'done' else 'idle', task='t16', text=p['text'], pct=p['pct'])
for i in range(1, 21):
    add(S + 2.2 + (i - 1) * 0.11, 'p%02d' % i, 'todo', fresh=True)
status(S + 4.5, 't16', 'review')
add(S + 4.6, 't16q', 'todo', fresh=True)
ev(S + 7.2, 'tap', sel='[data-card="t16q"]')
ev(S + 7.4, 'drawer', kind='questions', task='t16q')
for i, q in enumerate(TASKS['t16q']['questions']):
    a = TASKS['t16q']['answers'][q['id']]
    ev(S + 7.9 + i * 0.52, 'tap', sel='[data-opt="%s|%d"]' % (q['id'], q['options'].index(a['choice'])))
    ev(S + 8.0 + i * 0.52, 'answer', task='t16q', q=q['id'], choice=a['choice'])
ev(S + 10.7, 'drawer', kind=None)
status(S + 10.75, 't16q', 'done')
status(S + 10.75, 't16', 'done', review='approved')
clock += [{'t': S + 0.3, 'utc': sod('02:46:39')}, {'t': S + 4.5, 'utc': sod('02:53:20')}, {'t': S + 10.7, 'utc': sod('03:07:04')}]
T += 11

# 6. Human gate: safety block on the Godot download
S = scene('gate', T, 9, 'floor', captions=[
    (0.0, 4.6, 'A safety check blocked downloading Godot. The agents stopped and asked instead of working around it.'),
    (4.6, 9, 'Then one word, “go”: from here the lead dispatches every Ready task automatically.')])
ev(S + 0.1, 'drawer', kind='chat')
ev(S + 0.4, 'chat', who='claude', text='I tried to start p01. It was blocked for safety, because it meant downloading the Godot 4.4.1 program from GitHub and running it here. I didn’t work around that. Choose one:\nA) Allow the Godot download and run, so the agents can build and test the game for real.\nB) The agents write the project files without running Godot.')
ev(S + 2.6, 'chat', who='you', text=CHAT['0cawo65uswmrnxuostot']['text'])
ev(S + 3.6, 'chat', who='claude', text='Going with A. Godot 4.4.1 is installed. It’s the official build, checked against Godot’s published checksum.')
ev(S + 5.0, 'chat', who='you', text=CHAT['kkei45lzzkad44ai5ylq']['text'])
ev(S + 6.0, 'chat', who='claude', text='Got it, I’m dispatching automatically from now on. Each time a task finishes, I check it, commit it, and start every task that just became Ready.')
ev(S + 8.6, 'drawer', kind=None)
clock += [{'t': S + 0.4, 'utc': sod('02:55:00')}, {'t': S + 2.6, 'utc': sod('03:13:11')}, {'t': S + 5.0, 'utc': sod('03:14:54')}]
T += 9

# 7. Parallel work, replayed from the git log (03:14:54 -> 05:49:57)
DUR7 = 27
S = scene('parallel', T, DUR7, 'floor', captions=[
    (0.0, 9, 'Ready tasks start in parallel, each with its own subagent. Replayed from the real commit log.'),
    (9, 18, 'Finished work is checked, committed and moved to Review. Dependent tasks flip to Ready.'),
    (18, DUR7, 'The test suite grows with every task: 8 tests after p01, 287 when a whole run is playable.')])
ev(S, 'phase', phase='prototype')
ev(S, 'project', name='Killstreak', sub='Prototype · Web · Godot 4.4.1')
ev(S, 'clearDone', ids=['t16', 't16q'])
R0, R1 = sod('03:14:30'), sod('05:50:30')


def vt(real):
    return S + 0.4 + (real - R0) / (R1 - R0) * (DUR7 - 1.2)


TEST_AFTER = {'p01': 8, 'p02': 30, 'p04': 91, 'f01': 120, 'p06': 120, 'p05': 156, 'p10': 179, 'p07': 233,
              'p09': 235, 'f02': 262, 'p12': 282, 'p15': 282, 'f03': 287}
# task -> (start, done) from commits: start = first WIP commit naming it, else when its last
# dependency was committed (the lead dispatches on Ready); p01 started at 03:14:30 (activity a11).
build = ['p01', 'p02', 'p08', 'p13', 'rulings', 'p03', 'p04', 'f01', 'p17', 'rulings2', 'p05', 'p06', 'p09', 'p10',
         'p07', 'p14', 'p16', 'f02', 'p11', 'p12', 'p15', 'f03']
done_at = {}
special = {'rulings': ('7a48d05', sod('03:33:55')), 'rulings2': ('c8e4651', sod('03:55:14'))}
for tid in build:
    if tid in special:
        h = special[tid][0]
        c = next(c for c in COMMITS if c['hash'] == h)
    else:
        c = commit_for(tid)
    done_at[tid] = (sod(c['at']), c)
# Dispatch waves as the lead logged them in activity ("verified and committed X; started Y"):
# each task starts when the commit that made it Ready landed.
TRIGGER = {'p02': 'p01', 'p08': 'p01', 'p13': 'p01', 'rulings': 'p02', 'p03': 'rulings', 'p04': 'rulings',
           'f01': 'p08', 'p17': 'p08', 'p05': 'p04', 'p06': 'p04', 'rulings2': 'p04', 'p09': 'p06', 'p10': 'p06',
           'p07': 'p05', 'p14': 'p05', 'p16': 'p10', 'f02': 'p09', 'p11': 'p09', 'p12': 'f02', 'p15': 'f02',
           'f03': 'p11'}
start_at = {tid: done_at[TRIGGER[tid]][0] + 25 for tid in TRIGGER}
start_at['p01'] = sod('03:14:30')
created_mid = {'rulings': 'p02', 'f01': 'p08', 'rulings2': 'p04', 'f02': 'p09', 'f03': 'p11'}
for tid in created_mid:
    add(vt(done_at[created_mid[tid]][0]) + 0.05, tid, 'todo', fresh=True)
for tid in build:
    a = TASKS[tid]['agent']
    s, d = vt(start_at[tid]), vt(done_at[tid][0])
    status(s, tid, 'doing')
    rows = [p for p in progress_of(tid) if p.get('text')]
    rows.sort(key=lambda p: (p.get('status') == 'done', p.get('pct') or 0))
    work = [p for p in rows if p.get('status') != 'done'] or [{'text': 'Starting ' + TASKS[tid]['title'], 'pct': 5}]
    for j, p in enumerate(work):
        agent(s + (d - s) * j / max(1, len(work)) * 0.9, a, 'working', task=tid, text=p['text'], pct=p.get('pct'))
    agent(d, a, 'idle')
    st = 'done' if tid in ('p01', 'p02') else 'review'
    status(d, tid, st, review='approved' if st == 'done' else None)
    c = done_at[tid][1]
    ev(d, 'commit', hash=c['hash'], subject=c['subject'])
    if tid in TEST_AFTER:
        ev(d, 'tests', n=TEST_AFTER[tid])
clock += [{'t': vt(R0), 'utc': R0}, {'t': vt(R1), 'utc': R1}]
T += DUR7

# 8. Agents create work
S = scene('created', T, 13, 'spotlight', captions=[
    (0.0, 13, 'Work no plan foresaw: what agents found during their tasks became new board tasks.')])
spots = [
    ('rulings', 'p02 asked 13 rules questions. The Sr Game Designer ruled on all 13 before p03 and p04 started.'),
    ('f01', 'p08’s phone screenshots showed ~8 pt text and 35 pt buttons on iPhone. Fixed to 11.6 pt text, 46 pt taps.'),
    ('rulings2', 'Checked 13 calls the rules engine made: 12 confirmed, Tripwire timing overruled.'),
    ('f02', 'p09 left the enemy AI and item buttons unplugged. f02 wired them in: a real match works end to end.'),
    ('f03', 'p11 handed off the last link: connect the match to the run. After f03 a whole run is playable.')]
ev(S, 'spots', items=[{'task': task_def(tid), 'text': txt} for tid, txt in spots])
for i in range(len(spots)):
    ev(S + 0.4 + i * 2.4, 'spot', i=i)
T += 13

# 9. QA + balance, and the usage limit
S = scene('qa', T, 10, 'floor', captions=[
    (0.0, 3.6, 'QA and balance start in parallel...'),
    (3.6, 6.2, '...and the account hits its 5-hour usage limit. Work is saved; the agents resume after the reset.'),
    (6.2, 10, 'QA: 0 critical, 0 major bugs. Balance: a 150-match AI soak, and one change that needs the head’s sign-off.')])
ev(S, 'phase', phase='qa')
ev(S, 'project', name='Killstreak', sub='Test · Web · Godot 4.4.1')
for tid in ['p18', 'p19']:
    status(S + 0.4, tid, 'doing')
for tid, p in [('p18', progress_of('p18')), ('p19', progress_of('p19'))]:
    a = TASKS[tid]['agent']
    agent(S + 0.5, a, 'working', task=tid, text=p[0]['text'], pct=p[0]['pct'])
    agent(S + 2.0, a, 'working', task=tid, text=p[1]['text'], pct=p[1]['pct'])
ev(S + 3.6, 'limit', on=True)
agent(S + 3.7, 'qa-agent', 'blocked', task='p18', text='Paused: account usage limit. Work kept, saved in fcab2ea after the reset.', pct=55)
agent(S + 3.7, 'mid-game-designer', 'blocked', task='p19', text='Paused: account usage limit. Work kept, saved in fcab2ea after the reset.', pct=70)
ev(S + 5.6, 'limit', on=False)
p19r = progress_of('p19')
agent(S + 5.7, 'mid-game-designer', 'working', task='p19', text=p19r[-2]['text'], pct=p19r[-2]['pct'])
agent(S + 5.7, 'qa-agent', 'working', task='p18', text=progress_of('p18')[2]['text'], pct=55)
ev(S + 5.7, 'commit', hash='fcab2ea', subject='WIP p18/p19: QA and balance pass (paused at usage limit)')
status(S + 6.4, 'p18', 'review', note='0 critical, 0 major, 5 minor (4 fixed). 150 AI-vs-AI matches + 20 runs, no rule violations.')
agent(S + 6.4, 'qa-agent', 'idle')
ev(S + 6.4, 'commit', hash='a450e50', subject='p18: QA pass - rules soak, browser passes, IP check, 4 minor fixes')
ev(S + 6.4, 'tests', n=301)
status(S + 7.0, 'p19', 'review', note='Bracket 1 69% / Bracket 2 49% / Rival 45% wins. Anchor mode swap needs your sign-off.')
agent(S + 7.0, 'mid-game-designer', 'idle')
ev(S + 7.0, 'commit', hash='af05749', subject='p19: balance pass with simulation harness')
ev(S + 8.0, 'toast', text='Playable web build published (loads in ~4 s in Chromium)')
clock += [{'t': S + 0.4, 'utc': sod('05:50:49')}, {'t': S + 3.6, 'utc': sod(LIMIT_PAUSE[0])},
          {'t': S + 5.6, 'utc': sod(LIMIT_PAUSE[1])}, {'t': S + 8.0, 'utc': sod('11:25:00')}]
T += 10

# 10. Human feedback loop
S = scene('feedback', T, 19, 'floor', captions=[
    (0.0, 8.6, 'The head plays it and asks for better looks. The Sr Game Artist runs a visual polish pass.'),
    (8.6, 13.6, 'A bug report from play: “first strike doesn’t work”. The Mechanics Developer reproduces it...'),
    (13.6, 19, '...the rules were right; the replay was misleading. It now labels FIRST SHOT and MAIN steps.')])
ev(S, 'clearDone', ids=['p01', 'p02'])
ev(S + 0.1, 'drawer', kind='chat', clear=True)
ev(S + 0.3, 'chat', who='you', text=CHAT['f10ndn8b56hhe0rt3wt0']['text'])
add(S + 1.0, 'v01', 'todo', fresh=True)
ev(S + 1.2, 'chat', who='claude', text='Yes. The Sr Game Artist has started a visual polish pass (v01). Watch its card on the board.')
ev(S + 2.2, 'drawer', kind=None)
status(S + 2.4, 'v01', 'doing')
for i, p in enumerate([p for p in progress_of('v01') if p['status'] != 'done']):
    agent(S + 2.5 + i * 0.5, 'sr-game-artist', 'working', task='v01', text=p['text'], pct=p['pct'])
status(S + 4.6, 'v01', 'review')
agent(S + 4.6, 'sr-game-artist', 'idle')
ev(S + 4.6, 'commit', hash='0ad3afc', subject='v01: visual polish pass')
ev(S + 4.6, 'tests', n=302)
ev(S + 4.8, 'drawer', kind='wipe', before='v01-before-1-title-844x390@3x.png', after='v01-after-1-title-844x390@3x.png',
   label='v01 · Title screen, before → after (real QA screenshots)')
ev(S + 8.4, 'drawer', kind=None)
ev(S + 8.6, 'drawer', kind='chat', clear=True)
ev(S + 8.8, 'chat', who='you', text='The action feed is nice but it shouldn’t overlap the hand. Also make sure we use the icons on cards when they are small in hand… Also it feels like first strike doesn’t work: when I have a first strike unit with enough attack to eliminate target, they still get shot.')
add(S + 10.4, 'f04', 'todo', fresh=True)
add(S + 10.6, 'b01', 'todo', fresh=True)
ev(S + 11.6, 'drawer', kind=None)
status(S + 11.8, 'b01', 'doing')
status(S + 11.9, 'f04', 'doing')
for i, p in enumerate([p for p in progress_of('b01') if p['status'] != 'done']):
    agent(S + 11.9 + i * 0.6, 'mechanics-developer', 'working', task='b01', text=p['text'], pct=p['pct'])
for i, p in enumerate([p for p in progress_of('f04') if p['status'] != 'done']):
    agent(S + 12.0 + i * 0.9, 'ui-ux-agent', 'working', task='f04', text=p['text'], pct=p['pct'])
status(S + 13.8, 'b01', 'review', note=TASKS['b01']['note'].split('. 11 scripted')[0] + '.')
agent(S + 13.8, 'mechanics-developer', 'idle')
ev(S + 13.8, 'commit', hash='20ecdac', subject='b01: make First Shot readable in the fight replay')
ev(S + 14.0, 'toast', text='b01: 11 scripted boards confirm a lethal First Shot means the target never fires.')
status(S + 16.2, 'f04', 'review')
agent(S + 16.2, 'ui-ux-agent', 'idle')
ev(S + 16.2, 'commit', hash='a24076c', subject='f04: killfeed off the hand; card icons on hand chips and board slots')
ev(S + 16.2, 'tests', n=317)
clock += [{'t': S + 0.3, 'utc': sod('11:37:41')}, {'t': S + 4.6, 'utc': sod('12:16:58')},
          {'t': S + 8.8, 'utc': sod('12:25:40')}, {'t': S + 13.8, 'utc': sod('12:35:50')}, {'t': S + 16.2, 'utc': sod('12:52:36')}]
T += 19

# 11. Stats card (computed)
first, last = COMMITS[0], COMMITS[-1]
span = sod(last['at']) - sod(first['at'])
paused = sod(LIMIT_PAUSE[1]) - sod(LIMIT_PAUSE[0])
active = span - paused
hm = lambda x: '%dh %02dm' % (x // 3600, x % 3600 // 60)
shots = len(glob.glob(os.path.join(HERE, '..', '..', 'projects', 'killstreak', 'qa', 'screenshots', '*.png')))
agents_n = len(glob.glob(os.path.join(HERE, '..', '..', '.claude', 'agents', '*.md')))
stats = {
    'wall': '%dh %02dm' % (span // 3600, span % 3600 // 60), 'from': first['at'][11:16], 'to': last['at'][11:16],
    'active': hm(active), 'paused': hm(paused), 'pause_from': LIMIT_PAUSE[0][:5], 'pause_to': LIMIT_PAUSE[1][:5],
    'agents': agents_n, 'tasks': len(TASKS), 'commits': len(COMMITS),
    'commits_nonwip': sum(1 for c in COMMITS if not c['wip']),
    'tests': 317, 'screens': shots,
    'created_by': {k: sum(1 for t in TASKS.values() if t.get('createdBy') == k) for k in
                   ['lead', 'master-orchestrator', 'producer-agent', 'you']},
}
S = scene('stats', T, 7, 'stats', captions=[(0.0, 7, 'About %d hours %d minutes of active work. Another %d h %d min was spent waiting at the usage limit.' % (
    active // 3600, round(active % 3600 / 60), paused // 3600, paused % 3600 // 60))])
ev(S, 'stats', **stats)
T += 7

# 12. The real game
GAME_DUR = 0
game_clips, game_shots = [], []
if GAME and os.path.exists(os.path.join(GAME, 'trailer.json')):
    # trailer-style teaser (trailer_cut.py): fast real-footage cuts + kinetic title cards, no captions
    game_shots = json.load(open(os.path.join(GAME, 'trailer.json')))['shots']
    GAME_DUR = sum(c['dur'] for c in game_shots)
elif GAME and os.path.exists(os.path.join(GAME, 'clips.json')):
    game = json.load(open(os.path.join(GAME, 'clips.json')))
    game_clips = game['clips']
    GAME_DUR = sum(c['dur'] for c in game_clips)
S = scene('game', T, max(GAME_DUR, 1), 'game', captions=[])
tt = 0
for c in game_clips + game_shots:
    c['at'] = round(S + tt, 3)
    if c.get('caption'):
        scenes[-1]['captions'].append({'t': S + tt, 'until': S + tt + c['dur'], 'text': c['caption']})
    tt += c['dur']
T += max(GAME_DUR, 1)

# 13. End card
scene('end', T, 5.5, 'end')
T += 5.5

out = {'fps': 30, 'width': 1920, 'height': 1080, 'duration': round(T, 3), 'scenes': scenes,
       'events': sorted(events, key=lambda e: e['t']), 'clock': sorted(clock, key=lambda c: c['t']),
       'agents': [{'id': k, 'name': v} for k, v in AGENT_NAMES.items() if k not in ('lead', 'you')],
       'names': AGENT_NAMES, 'game': {'clips': game_clips, 'shots': game_shots, 'frames': 'game/frames.json'},
       'docs': {'design-review': open(os.path.join(HERE, '..', '..', 'projects', 'killstreak', 'documentation', 'DESIGN_REVIEW.md')).read()},
       'questions': {k: TASKS[k]['questions'] for k in ('t15', 't16q')},
       'commitTimes': [sod(c['at']) for c in COMMITS],
       'stats': stats, 'shots': '../../projects/killstreak/qa/screenshots', 'gameDir': 'game'}
json.dump(out, open(os.path.join(HERE, 'timeline.json'), 'w'), indent=1)
print('timeline.json: %.1f s, %d events, %d scenes' % (T, len(events), len(scenes)))
for s in scenes:
    print('  %-10s %6.1f - %6.1f' % (s['id'], s['start'], s['end']))
print('stats', stats)
