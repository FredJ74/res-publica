#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function afficherPopupQueteAccueil(opts) {"""
new = """// Explique au joueur comment se separer d'un employe recupere (Jeremy ou n'importe quel
// autre plus tard), la premiere fois que ce cas se presente dans le cadre de la quete.
function queteAccueilExpliquerLicenciement() {
  afficherPopupQueteAccueil({
    image: QUETE_ACCUEIL_IMAGES.jeremy,
    titre: 'Jérémy',
    texte: "Me revoilà ! Au fait, si un jour vous voulez vous séparer de moi (ou de n'importe quel autre employé), il suffit de cliquer sur la petite croix à côté de sa carte, dans le panneau \\"Mes Employés\\", à gauche.",
    suivant: function() {
      queteAccueilSurbrillance('#panel-employes, .panel-employes', 15000);
    }
  });
}

function afficherPopupQueteAccueil(opts) {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Explication du licenciement ajoutée.")
