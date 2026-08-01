#!/usr/bin/env python3
PATH = "plateau.html"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """<script src="plateau-enigme-portrait.js?v=1"></script>
<script src="plateau-enigme-portrait.js?v=1"></script>"""
new = """<script src="plateau-enigme-portrait.js?v=1"></script>"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Doublon de balise script retiré.")
