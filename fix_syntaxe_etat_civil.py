#!/usr/bin/env python3
PATH = "plateau-etat-civil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old_1 = """    html += '<div onclick="etatCivilAfficherFiche(\\\\'' + nomEchap + '\\\\')" style="cursor:pointer;padding:.4rem .6rem;border:1px solid #2a2010;font-size:.85rem;color:#c0b090">' + nomPersonne + '</div>';"""
new_1 = """    html += '<div onclick="etatCivilAfficherFiche(\\'' + nomEchap + '\\')" style="cursor:pointer;padding:.4rem .6rem;border:1px solid #2a2010;font-size:.85rem;color:#c0b090">' + nomPersonne + '</div>';"""
assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

old_2 = """  html += '<button class="pnj-action-btn" onclick="etatCivilImprimerFiche(\\\\'' + nomEchap + '\\\\')"><i class="ti ti-printer" style="font-size:.85rem"></i> Imprimer cette fiche</button> ';"""
new_2 = """  html += '<button class="pnj-action-btn" onclick="etatCivilImprimerFiche(\\'' + nomEchap + '\\')"><i class="ti ti-printer" style="font-size:.85rem"></i> Imprimer cette fiche</button> ';"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Erreur de syntaxe corrigée (échappement des guillemets).")
