old=open('index_v21.html').read()
headend=old.index('<style>')
head=old[:headend]
import base64,glob,os,json
ART={os.path.basename(f)[:-5]:'data:image/webp;base64,'+base64.b64encode(open(f,'rb').read()).decode() for f in sorted(glob.glob('webart/*.webp'))}
GUNART={os.path.basename(f)[:-5]:'data:image/webp;base64,'+base64.b64encode(open(f,'rb').read()).decode() for f in sorted(glob.glob('webart/guns/*.webp'))}
FACES=json.load(open('pnp/faces.json'))
LOCART={os.path.basename(f)[:-5]:'data:image/webp;base64,'+base64.b64encode(open(f,'rb').read()).decode() for f in sorted(glob.glob('webart/locs/*.webp'))}
css=open('style.css').read(); sym=open('symbols.html').read(); eng=open('engine.js').read(); ui=open('ui.js').read()
eng=eng[:eng.index('if (typeof module')]+"root.WD = API;\n})(typeof window !== 'undefined' ? window : globalThis);\n"
head=head.replace('<title>Warzone Deckbuilder</title>','<title>Warzone Deckbuilder</title>').replace('family=Saira+Stencil+One&','family=Saira+Stencil+One&family=Inter:wght@400;500;600;700;800;900&')
html=f"""{head}<style>
{css}
</style>
{sym}
<div id="app"></div>
<div id="layer" class="layer-ui"></div>
<script>
const ART={json.dumps(ART)};
const GUNART={json.dumps(GUNART)};
const FACES={json.dumps(FACES['faces'])};
const LOCART={json.dumps(LOCART)};
const FACECSS={json.dumps(FACES['css'])};
const FACESPRITE={json.dumps(FACES['sprite'])};
</script>
<script>
{eng}
</script>
<script>
{ui}
</script>
"""
open('index.html','w').write(html)
print(len(html))
