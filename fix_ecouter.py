#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif "Ecouter" (restaurant, bar, et 3e emplacement) :
- renomme fn:'ecouter' en fn:'ecouter_rumeurs' aux 3 endroits ou l'ordre etait
  casse (routait par erreur vers doSeRenseigner, une fonction de gestion de
  location de locaux, sans rapport).
- supprime la route fautive 'ecouter' -> doSeRenseigner dans plateau-router.js,
  pour eviter que ce bug ne revienne si un futur ordre reutilise fn:'ecouter'.
"""
import sys

def apply_patch(path, old, new, label):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    count = content.count(old)
    if count == 0:
        print(f"[ECHEC] {label} : ancre introuvable dans {path}")
        return False
    if count > 1:
        print(f"[ECHEC] {label} : ancre trouvee {count} fois dans {path} (doit etre unique)")
        return False
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[OK] {label}")
    return True

ok = True

# 1) Restaurant Hotel Republica
old1 = """{fn:'ecouter',      label:'Ecouter les tables',  pa:0, cost:0,   type:'grey',   icon:'ti-ear',      successRate:95,  desc:'Collecter des informations ambiantes.'},"""
new1 = """{fn:'ecouter_rumeurs', label:'Ecouter les tables',  pa:0, cost:0,   type:'grey',   icon:'ti-ear',      successRate:95,  desc:'Revele une rumeur vraie (action recente tracee) ou, a defaut, une information generee selon le contexte.'},"""
ok &= apply_patch('data.js', old1, new1, "data.js - restaurant : Ecouter les tables")

# 2) Bar Hotel Republica
old2 = """{fn:'ecouter',         label:'Ecouter le barman',     pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:90,  desc:'Le barman entend tout.'},"""
new2 = """{fn:'ecouter_rumeurs', label:'Ecouter le barman',     pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:90,  desc:'Le barman entend tout. Revele une rumeur vraie ou generee selon le contexte.'},"""
ok &= apply_patch('data.js', old2, new2, "data.js - bar : Ecouter le barman")

# 3) 3e emplacement (ligne ~2685)
old3 = """{fn:'ecouter',    label:'Ecouter',         pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:85},"""
new3 = """{fn:'ecouter_rumeurs', label:'Ecouter',    pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:85},"""
ok &= apply_patch('data.js', old3, new3, "data.js - 3e emplacement : Ecouter")

# 4) Suppression de la route fautive dans plateau-router.js
old4 = """  if (fn === 'ecouter')        { doSeRenseigner(); return; }
"""
new4 = ""
ok &= apply_patch('plateau-router.js', old4, new4, "plateau-router.js - suppression route fautive 'ecouter'")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
