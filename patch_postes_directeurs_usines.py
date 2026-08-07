#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  min_ae:      { label: 'Ministre des Affaires Etrangeres', nommePar: 'pm',     scope: 'pays', compatibles: ['depute'] }
};"""
new = """  min_ae:      { label: 'Ministre des Affaires Etrangeres', nommePar: 'pm',     scope: 'pays', compatibles: ['depute'] },

  // Directeurs des entreprises stategiques — nommes par le Ministre des Finances, portee
  // nationale (comme les ministres/juge), meme si physiquement rattaches a une ville precise.
  directeur_pharma:        { label: "Directeur de l'Usine Pharmaceutique", nommePar: 'min_fin', scope: 'pays', compatibles: ['depute'] },
  directeur_tabac_alcools: { label: 'Directeur du Pôle Tabac & Alcools',   nommePar: 'min_fin', scope: 'pays', compatibles: ['depute'] },
  directeur_raffinerie:    { label: 'Directeur de la Raffinerie',          nommePar: 'min_fin', scope: 'pays', compatibles: ['depute'] }
};"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ 3 postes de directeur créés dans POSTES_NOMMES_EXCLUSIFS (nommés par le Ministre des Finances).")
