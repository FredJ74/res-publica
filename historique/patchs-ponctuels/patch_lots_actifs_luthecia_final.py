#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """      buildings: ['palais-presidentiel','hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','mairie-capitale','tabernacle-impots','centre-multinodal-luthecia','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-1','terrain-a-batir-4','terrain-a-batir-5','terrain-a-batir-6','terrain-a-batir-7','office-notarial','stade','quartier-ambassades','place-formulaire-liberte','musee-ville-luthecia','musee-national-republia','parc-botanique-national'],"""

new = """      buildings: ['palais-presidentiel','hotel-republica','palais-gouvernement','assemblee','tribunal','banque-nationale','banque-privee','clinique-privee','dispensaire-public','commissariat','la-tribune','loge-maconnique','universite','armurerie','marche','mairie-capitale','tabernacle-impots','centre-multinodal-luthecia','centre-commercial','centre-artisanal','centre-affaires','terrain-a-batir-1','terrain-a-batir-2','terrain-a-batir-3','terrain-a-batir-4','terrain-a-batir-5','office-notarial','stade','quartier-ambassades','place-formulaire-liberte','musee-ville-luthecia','musee-national-republia','parc-botanique-national'],"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Liste active de Luthécia corrigée : les 5 lots de la Châtaigneraie (1,2,3,4,5), lots 6/7 retirés.")
