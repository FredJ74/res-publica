#!/usr/bin/env python3
PATH = "api/cron-minuit.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function nettoyerBlocusExpires() {"""
new = """// Table dupliquee cote serveur (voir RESSOURCES_ECONOMIE, data.js — si modifiee cote
// client, repercuter ici aussi).
const RESSOURCES_ECONOMIE_SERVEUR = {
  cereales:     { plafond: 150, prixAchatFournisseur: 1.5, source: 'livraison' },
  poisson:      { plafond: 125, prixAchatFournisseur: 2,   source: 'livraison' },
  viande:       { plafond: 125, prixAchatFournisseur: 2.5, source: 'livraison' },
  bois:         { plafond: 750, prixAchatFournisseur: 2.5, source: 'livraison' },
  petrole:      { plafond: 200, prixAchatFournisseur: 4,   source: 'livraison' },
  minerai:      { plafond: 500, prixAchatFournisseur: 5,   source: 'livraison' },
  metal:        { plafond: 200, prixAchatFournisseur: 7.5, source: 'livraison' },
  plantes:      { plafond: 300, prixAchatFournisseur: 3,   source: 'livraison' },
  medicaments:  { plafond: 100, prixAchatFournisseur: 11,  source: 'transformation' },
  alcool:       { plafond: 100, prixAchatFournisseur: 7,   source: 'transformation' },
  tabac:        { plafond: 100, prixAchatFournisseur: 9,   source: 'transformation' },
  carburant:    { plafond: 100, prixAchatFournisseur: 10,  source: 'transformation' }
};

const ENTREPOTS_VILLES = [
  { buildingId: 'entrepot-logistique-luthecia', city: 'capitale' },
  { buildingId: 'entrepot-logistique-psm',      city: 'ville_a' },
  { buildingId: 'entrepot-logistique-montrouge', city: 'ville_b' }
];

const VOLUME_TOTAL_JOUR = 800;
const NB_LIVRAISONS_JOUR = 6;

// Simule les 6 livraisons quotidiennes d'un entrepot en une seule passe (limite du plan
// Vercel Hobby : un seul cron autorise par jour, pas de vrai rythme toutes les 4h). Chaque
// livraison tire aleatoirement 3 a 8 matieres premieres parmi celles pas encore pleines,
// et repartit un volume aleatoire entre elles (le total des 6 livraisons visant ~800
// unites/jour, avec une vraie irregularite entre chaque livraison). Facilement migrable
// vers un vrai cron toutes les 4h si le plan Pro est active un jour.
async function livrerEntrepotsQuotidien() {
  const resultats = { entrepots: 0, unitesLivrees: 0, coutTotal: 0 };
  try {
    const ressourcesLivrables = Object.entries(RESSOURCES_ECONOMIE_SERVEUR).filter(([, r]) => r.source === 'livraison');

    for (const { buildingId, city } of ENTREPOTS_VILLES) {
      const etat = await sbGetBatimentEtat('republic', city, buildingId).catch(() => null);
      if (!etat) continue; // batiment pas encore accessible dans cette ville
      const entrepot = etat.entrepot || { stock: {}, caisse: 0 };
      const stock = entrepot.stock || {};
      let caisse = entrepot.caisse || 0;
      let unitesEntrepot = 0;
      let coutEntrepot = 0;

      for (let i = 0; i < NB_LIVRAISONS_JOUR; i++) {
        // Volume de cette livraison : moyenne 800/6 ~133, avec une vraie irregularite
        const moyenneParLivraison = VOLUME_TOTAL_JOUR / NB_LIVRAISONS_JOUR;
        const volumeLivraison = Math.round(moyenneParLivraison * (0.5 + Math.random()));

        // Ressources disponibles pour cette livraison (pas deja pleines)
        const disponibles = ressourcesLivrables.filter(([cle]) => (stock[cle] || 0) < RESSOURCES_ECONOMIE_SERVEUR[cle].plafond);
        if (disponibles.length === 0) continue; // tout est plein, pas de livraison possible

        const nbRessources = Math.min(disponibles.length, 3 + Math.floor(Math.random() * 6)); // 3 a 8
        const tirage = [...disponibles].sort(() => Math.random() - 0.5).slice(0, nbRessources);

        // Repartition aleatoire et inegale du volume entre les ressources tirees
        const poids = tirage.map(() => Math.random() + 0.2);
        const sommePoids = poids.reduce((s, p) => s + p, 0);

        tirage.forEach(([cle, res], idx) => {
          const qteLivree = Math.round(volumeLivraison * (poids[idx] / sommePoids));
          if (qteLivree <= 0) return;
          const placeRestante = Math.max(0, res.plafond - (stock[cle] || 0));
          const qteStockee = Math.min(qteLivree, placeRestante);

          // L'entrepot paie la totalite livree, meme ce qui depasse et se perd
          const cout = qteLivree * res.prixAchatFournisseur;
          if (caisse >= cout) {
            caisse -= cout;
            stock[cle] = (stock[cle] || 0) + qteStockee;
            unitesEntrepot += qteStockee;
            coutEntrepot += cout;
          }
          // Si la caisse ne peut pas payer, la livraison est simplement annulee (pas de dette)
        });
      }

      await sbSetBatimentEtat('republic', city, buildingId, { ...etat, entrepot: { stock, caisse } }).catch(() => {});
      resultats.entrepots++;
      resultats.unitesLivrees += unitesEntrepot;
      resultats.coutTotal += coutEntrepot;
    }
  } catch(e) { console.error('livrerEntrepotsQuotidien error', e); }
  return resultats;
}

async function nettoyerBlocusExpires() {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """    // 11. Effets quotidiens des blocus actifs (malus popularite du maire)
    const effetsBlocus = await appliquerEffetsBlocusActifs();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers, prets, blocusExpires, effetsBlocus });"""
new_2 = """    // 11. Effets quotidiens des blocus actifs (malus popularite du maire)
    const effetsBlocus = await appliquerEffetsBlocusActifs();

    // 12. Livraisons quotidiennes des entrepots logistiques (6 livraisons simulees en une
    // passe, limite du plan Vercel Hobby)
    const livraisons = await livrerEntrepotsQuotidien();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers, prets, blocusExpires, effetsBlocus, livraisons });"""
assert content.count(old_2) == 1, f"trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Cron des livraisons créé : 6 livraisons simulées/jour, ~800 unités au total, répartition inégale entre 3-8 ressources non pleines.")
