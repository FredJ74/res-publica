# -*- coding: utf-8 -*-
"""Controle statique : tout ordre de data.js doit produire un bouton dont le onclick est du JS valide.

Motif : le 12 septembre 2026, la desc de l'ordre `etouffer` (data.js) contenait des GUILLEMETS
DOUBLES. renderRoomActions ne neutralisait que l'apostrophe : l'attribut onclick="..." se fermait au
milieu du texte, le handler devenait invalide et le bouton « Etouffer un article » (1 PA + 1000 FR)
etait totalement inerte. Ce harnais rejoue l'echappement reel sur TOUS les libelles et descriptions
du jeu, reconstruit le bouton, le fait analyser par un vrai parseur HTML, puis verifie que le
onclick extrait est du JavaScript syntaxiquement valide.
"""
import html.parser
import json
import re
import subprocess
import sys

SRC = open('data.js', encoding='utf-8').read()
POL = open('plateau-politique.js', encoding='utf-8').read()

# L'echappement reellement applique par renderRoomActions (doit rester synchronise avec le code).
m = re.search(r"const safeLabel = o\.label([^\n]*);\n\s*const safeDesc = \(o\.desc\|\|''\)([^\n]*);", POL)
if not m:
    print("ECHEC : echappement introuvable dans renderRoomActions (le code a change)")
    sys.exit(1)
CHAINE = m.group(1)
if ".replace(/'/g, ' ')" not in CHAINE or '.replace(/"/g' not in CHAINE:
    print("ECHEC : renderRoomActions ne neutralise pas a la fois l'apostrophe et le guillemet double")
    print("        chaine trouvee :" + CHAINE)
    sys.exit(1)


def echapper(t):
    return (t or '').replace("'", ' ').replace('"', '&quot;')


class Extracteur(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.onclick = None
        self.title = None

    def handle_starttag(self, tag, attrs):
        if tag == 'button':
            d = dict(attrs)
            self.onclick = d.get('onclick')
            self.title = d.get('title')


# Tous les ordres declares dans data.js (fn + label + desc eventuelle).
ordres = []
for bloc in re.finditer(r"\{fn:'([a-z0-9_]+)'\s*,\s*label:\s*('((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\")", SRC):
    fn = bloc.group(1)
    label = (bloc.group(3) if bloc.group(3) is not None else bloc.group(4)).replace("\\'", "'").replace('\\"', '"')
    reste = SRC[bloc.end(): bloc.end() + 900]
    d = re.search(r"desc:\s*('((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\")", reste)
    desc = ''
    if d:
        desc = (d.group(2) if d.group(2) is not None else d.group(3)).replace("\\'", "'").replace('\\"', '"')
    ordres.append((fn, label, desc))

echecs = []
scripts = []
for fn, label, desc in ordres:
    markup = ('<button class="action-btn" onclick="doOrder(\'' + fn + "',1,0,'" + echapper(label)
              + "','" + echapper(desc) + "',70)\" title=\"" + echapper(desc) + '">x</button>')
    p = Extracteur()
    p.feed(markup)
    if not p.onclick or not p.onclick.startswith('doOrder(' + "'" + fn + "'"):
        echecs.append((fn, 'attribut onclick tronque ou absent : ' + str(p.onclick)[:80]))
        continue
    scripts.append((fn, p.onclick))

# Validation syntaxique reelle du JS de chaque onclick, en un seul passage.
prog = '\n'.join('(function(){ function doOrder(){}; %s })' % code for _, code in scripts)
r = subprocess.run(['/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc', '-e',
                    'try { new Function(%s); print("PARSE_OK"); } catch (e) { print("PARSE_KO " + e); }'
                    % json.dumps(prog)],
                   capture_output=True, text=True)
sortie = (r.stdout or '') + (r.stderr or '')
if 'PARSE_OK' not in sortie:
    echecs.append(('<ensemble>', 'JS invalide : ' + sortie.strip()[:200]))

for fn, motif in echecs:
    print('ECHEC ' + fn + ' : ' + motif)
print('%d ordre(s) verifie(s), %d echec(s)' % (len(ordres), len(echecs)))
sys.exit(1 if echecs else 0)
