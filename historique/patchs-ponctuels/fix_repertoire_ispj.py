#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif repertoire de contacts (plateau-pnj.js) :
- le bouton "Ajouter au repertoire" pour un vrai PJ connaissait isPJ mais ne le
  transmettait jamais a addContactByName -> addContact ne stockait donc jamais
  ce flag -> le filtre "PJ uniquement" (lancer une rumeur, piege escort) ne
  trouvait jamais personne, meme avec des PJ dans le repertoire.
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

# 1) Le bouton du PJ passe maintenant isPJ=true
old1 = """    actionBtns += '<button class="pnj-action-btn" onclick="addContactByName(\\'' + pnjSafeName + '\\',\\'' + pnjSafeRole + '\\',\\'' + pnjRel + '\\')"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Ajouter au repertoire</button>';
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\\'modal-pnj\\').classList.remove(\\'open\\');composerMailPour(\\'' + pnjSafeName + '\\')"><i class="ti ti-mail" style="font-size:.85rem"></i> Envoyer un mail</button>';"""

new1 = """    actionBtns += '<button class="pnj-action-btn" onclick="addContactByName(\\'' + pnjSafeName + '\\',\\'' + pnjSafeRole + '\\',\\'' + pnjRel + '\\',true)"><i class="ti ti-user-plus" style="font-size:.85rem"></i> Ajouter au repertoire</button>';
    actionBtns += '<button class="pnj-action-btn" onclick="document.getElementById(\\'modal-pnj\\').classList.remove(\\'open\\');composerMailPour(\\'' + pnjSafeName + '\\')"><i class="ti ti-mail" style="font-size:.85rem"></i> Envoyer un mail</button>';"""

ok &= apply_patch('plateau-pnj.js', old1, new1, "plateau-pnj.js - bouton PJ passe isPJ=true")

# 2) addContactByName accepte et transmet isPJ
old2 = """function addContactByName(name, role, rel) {
  addContact({ name: name, role: role, rel: rel });
}"""
new2 = """function addContactByName(name, role, rel, isPJ) {
  addContact({ name: name, role: role, rel: rel, isPJ: !!isPJ });
}"""
ok &= apply_patch('plateau-pnj.js', old2, new2, "plateau-pnj.js - addContactByName transmet isPJ")

# 3) addContact stocke isPJ
old3 = """  state.contacts.push({ name: pnj.name, role: pnj.role, rel: pnj.rel });"""
new3 = """  state.contacts.push({ name: pnj.name, role: pnj.role, rel: pnj.rel, isPJ: !!pnj.isPJ });"""
ok &= apply_patch('plateau-pnj.js', old3, new3, "plateau-pnj.js - addContact stocke isPJ")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
