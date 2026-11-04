# Build-time: turn pnp/assets.html into faces.json (scoped CSS, icon sprite, one HTML string per printed face)
import re, json, os
D = os.path.dirname(os.path.abspath(__file__))
s = open(os.path.join(D, 'assets.html')).read()
css = s[s.index('<style>') + 7:s.index('</style>')]
css = re.sub(r'@page\s*\{[^}]*\}', '', css)
css = re.sub(r'(^|\})\s*body\s*\{', r'\1 .fw {', css)
css += '\n.fw{position:relative;overflow:hidden;background:transparent}.fw>.card,.fw>.bigloc{border:0!important}.fw .pfoot{display:none}\n'
b = s.index('<body>') + 6 if '<body>' in s else s.index('<body')
body = s[b:]
sp0 = body.index('<svg'); sp1 = body.index('</svg>', sp0) + 6
sprite = body[sp0:sp1]
faces = {}
for m in re.finditer(r'<div class="asset" data-name="([^"]+)">', body):
    start = m.end(); nxt = body.find('<div class="asset" data-name="', start)
    chunk = body[start:nxt if nxt > 0 else body.rindex('</body>')]
    chunk = chunk.strip()
    assert chunk.endswith('</div>'); chunk = chunk[:-6].strip()
    faces[m.group(1)] = chunk
json.dump({'css': css, 'sprite': sprite, 'faces': faces}, open(os.path.join(D, 'faces.json'), 'w'))
print(len(faces), len(css), len(sprite), sum(map(len, faces.values())))
