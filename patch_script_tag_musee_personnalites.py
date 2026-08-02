#!/usr/bin/env python3
import re
PATH = "plateau.html"
with open(PATH, "r", encoding="utf-8") as f:
    html = f.read()

pattern = re.compile(r'<script src="plateau-etat-civil\.js\?v=\d+"></script>')
matches = pattern.findall(html)
assert len(matches) == 1, f"trouvé {len(matches)} fois (attendu 1)"
old_tag = matches[0]
new_block = old_tag + '\n<script src="plateau-musee-personnalites.js?v=1"></script>'
html = html.replace(old_tag, new_block)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(html)

print("✅ Balise script ajoutée pour plateau-musee-personnalites.js.")
