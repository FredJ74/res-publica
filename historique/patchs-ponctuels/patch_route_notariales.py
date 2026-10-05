#!/usr/bin/env python3
PATH = "plateau-router.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (fn === 'consulter_mandats_maires') { doConsulterResumesMandats(); return; }"""
new = """  if (fn === 'consulter_mandats_maires') { doConsulterResumesMandats(); return; }
  if (fn === 'consulter_archives_notariales') { doConsulterArchivesNotariales(); return; }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Ordre routé.")
