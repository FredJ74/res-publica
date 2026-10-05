#!/usr/bin/env python3
PATH = "data.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// =====================
// ORDER EFFECTS
// ====================="""

new = """// =====================
// ECONOMIE — ENTREPOTS LOGISTIQUES ET TRANSFORMATEURS (modele economique V1, theorie
// validee avec Fred le 6-7 aout 2026, calibree pour ~20 PJ actifs a Luthecia en beta)
// =====================
// - prixBase : prix de vente aux joueurs, au taux de remplissage "moyen" (50%)
// - prixAchatFournisseur : prix paye par l'entrepot a la livraison (moitie du prix de vente)
// - plafond : capacite maximale de stockage de cette categorie, par entrepot
// - source : 'livraison' (tiree aleatoirement aux 6 livraisons/jour) ou 'transformation'
//   (n'arrive dans l'entrepot que via la redistribution 20% d'un transformateur — jamais
//   tiree directement lors d'une livraison de matieres premieres)
const RESSOURCES_ECONOMIE = {
  // --- Matieres premieres (livrees) ---
  cereales:     { label: 'Céréales',     icon: 'ti-wheat',       prixBase: 3,  prixAchatFournisseur: 1.5, plafond: 150, source: 'livraison' },
  poisson:      { label: 'Poisson',      icon: 'ti-fish',        prixBase: 4,  prixAchatFournisseur: 2,   plafond: 125, source: 'livraison' },
  viande:       { label: 'Viande',       icon: 'ti-meat',        prixBase: 5,  prixAchatFournisseur: 2.5, plafond: 125, source: 'livraison' },
  bois:         { label: 'Bois',         icon: 'ti-trees',       prixBase: 5,  prixAchatFournisseur: 2.5, plafond: 750, source: 'livraison' },
  petrole:      { label: 'Pétrole',      icon: 'ti-droplet',     prixBase: 8,  prixAchatFournisseur: 4,   plafond: 200, source: 'livraison' },
  minerai:      { label: 'Minerai',      icon: 'ti-mountain',    prixBase: 10, prixAchatFournisseur: 5,   plafond: 500, source: 'livraison' },
  metal:        { label: 'Métal',        icon: 'ti-bolt',        prixBase: 15, prixAchatFournisseur: 7.5, plafond: 200, source: 'livraison' },
  plantes:      { label: 'Plantes',      icon: 'ti-leaf',        prixBase: 6,  prixAchatFournisseur: 3,   plafond: 300, source: 'livraison' },

  // --- Produits transformes (redistribution 20% des transformateurs, jamais livres directement) ---
  medicaments:  { label: 'Médicaments',  icon: 'ti-pill',        prixBase: 22, prixAchatFournisseur: 11,  plafond: 100, source: 'transformation' },
  alcool:       { label: 'Alcool',       icon: 'ti-glass-full',  prixBase: 14, prixAchatFournisseur: 7,   plafond: 100, source: 'transformation' },
  tabac:        { label: 'Tabac',        icon: 'ti-cigarette',   prixBase: 18, prixAchatFournisseur: 9,   plafond: 100, source: 'transformation' },
  carburant:    { label: 'Carburant',    icon: 'ti-gas-station', prixBase: 20, prixAchatFournisseur: 10,  plafond: 100, source: 'transformation' }
};

// Prix effectif d'une ressource selon le taux de remplissage du stock (stock eleve = prix
// bas, stock faible = prix haut), variation +/-40% autour du prix de base a 50% de
// remplissage. tauxRemplissage attendu entre 0 (vide) et 1 (plein).
function getPrixRessource(cle, quantiteEnStock) {
  const res = RESSOURCES_ECONOMIE[cle];
  if (!res) return 0;
  const tauxRemplissage = Math.max(0, Math.min(1, quantiteEnStock / res.plafond));
  // 0% rempli -> +40% ; 50% rempli -> prix de base ; 100% rempli -> -40%
  const variation = (0.5 - tauxRemplissage) * 0.8;
  return Math.round(res.prixBase * (1 + variation) * 100) / 100;
}

// Quantite maximale livrable pour combler un entrepot vide a son plafond (dotation de
// depart en debut de partie, ou reference pour le calcul des livraisons).
function getPlafondTotalEntrepot() {
  return Object.values(RESSOURCES_ECONOMIE).reduce((s, r) => s + r.plafond, 0);
}

// =====================
// ORDER EFFECTS
// ====================="""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ RESSOURCES_ECONOMIE créée : 12 ressources (8 livrées + 4 transformées), prix/plafonds calibrés, fonction de prix dynamique.")
