#!/usr/bin/env python3
PATH = "plateau-navigation.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    // Route nord-sud, strictement a l'interieur du perimetre
    svg += '<rect x="336" y="150" width="8" height="370" fill="#1e1c10"/>';
    svg += '<line x1="340" y1="150" x2="340" y2="520" stroke="#2e2a14" stroke-width="1" stroke-dasharray="16,10"/>';

    // Route est-ouest, strictement a l'interieur du perimetre
    svg += '<rect x="130" y="331" width="420" height="8" fill="#1e1c10"/>';
    svg += '<line x1="130" y1="335" x2="550" y2="335" stroke="#2e2a14" stroke-width="1" stroke-dasharray="16,10"/>';"""
new = """    // Route nord-sud, strictement a l'interieur du perimetre (coordonnees x1.4, alignees sur
    // le nouveau cadre agrandi du 5 aout 2026)
    svg += '<rect x="470" y="210" width="11" height="518" fill="#1e1c10"/>';
    svg += '<line x1="476" y1="210" x2="476" y2="728" stroke="#2e2a14" stroke-width="1" stroke-dasharray="16,10"/>';

    // Route est-ouest, strictement a l'interieur du perimetre (coordonnees x1.4)
    svg += '<rect x="182" y="463" width="588" height="11" fill="#1e1c10"/>';
    svg += '<line x1="182" y1="469" x2="770" y2="469" stroke="#2e2a14" stroke-width="1" stroke-dasharray="16,10"/>';"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Routes réalignées avec le nouveau cadre agrandi (x1.4).")
