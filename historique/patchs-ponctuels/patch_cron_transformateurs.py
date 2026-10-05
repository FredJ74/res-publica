#!/usr/bin/env python3
PATH = "api/cron-minuit.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function livrerEntrepotsQuotidien() {"""

new = """// Simplification actee (note pour Fred) : le prix de la vente directe du transformateur
// utilise la MEME formule dynamique que l'entrepot (stock eleve = prix bas), plutot qu'un
// calcul separe "cout + 10% de marge" — evite un systeme de prix parallele, reste coherent
// avec tout ce qu'on a deja construit. Mode PNJ uniquement pour l'instant ; le mode "PJ
// directeur" (liberte totale sur prix et repartition 60/40) reste a construire, une fois
// tranchee la question de savoir comment un PJ devient directeur.
const TRANSFORMATEURS = [
  { buildingId: 'usine-pharmaceutique-luthecia', city: 'capitale', chaines: [{ matiere: 'plantes', produit: 'medicaments' }] },
  { buildingId: 'pole-tabac-alcools-psm',        city: 'ville_a',  chaines: [{ matiere: 'cereales', produit: 'alcool' }, { matiere: 'plantes', produit: 'tabac' }] },
  { buildingId: 'raffinerie-montrouge',          city: 'ville_b',  chaines: [{ matiere: 'petrole', produit: 'carburant' }] }
];

const VOLUME_MATIERE_PAR_CHAINE_JOUR = 80; // -> 40 unites produites (ratio 2:1)
const RATIO_TRANSFORMATION = 2;
const PART_REDISTRIBUTION_ENTREPOTS = 0.6; // 20% a chacun des 3 entrepots
const PLAFOND_VENTE_DIRECTE = 50;

// Production quotidienne automatique (mode PNJ) de chaque transformateur : consomme sa
// matiere premiere, produit le bien fini au ratio 2:1, redistribue 60% aux 3 entrepots
// (20% chacun, perdu si un entrepot est deja plein sur ce produit), garde 40% en vente
// directe sur place (mini-stock propre, plafonne, prix dynamique comme un entrepot).
async function produireTransformateursQuotidien() {
  const resultats = { transformateurs: 0, uniteesProduites: 0 };
  try {
    for (const transfo of TRANSFORMATEURS) {
      const etat = await sbGetBatimentEtat('republic', transfo.city, transfo.buildingId).catch(() => null);
      if (!etat) continue; // batiment pas encore accessible dans cette ville

      // Dotation de depart, meme logique que l'entrepot
      const usine = etat.usine || { caisse: 3000, venteDirecte: {} };
      let caisse = usine.caisse ?? 3000;
      const venteDirecte = usine.venteDirecte || {};

      for (const chaine of transfo.chaines) {
        const matiereCfg = RESSOURCES_ECONOMIE_SERVEUR[chaine.matiere];
        if (!matiereCfg) continue;

        const coutMatiere = VOLUME_MATIERE_PAR_CHAINE_JOUR * matiereCfg.prixAchatFournisseur;
        if (caisse < coutMatiere) continue; // pas assez de tresorerie pour produire aujourd'hui
        caisse -= coutMatiere;

        const uniteesProduites = Math.floor(VOLUME_MATIERE_PAR_CHAINE_JOUR / RATIO_TRANSFORMATION);
        const versEntrepots = Math.round(uniteesProduites * PART_REDISTRIBUTION_ENTREPOTS);
        const venteDirecteQte = uniteesProduites - versEntrepots;
        const parEntrepot = Math.floor(versEntrepots / ENTREPOTS_VILLES.length);

        // Redistribution 20% a chaque entrepot, perdu si deja plein sur ce produit
        for (const cible of ENTREPOTS_VILLES) {
          const etatCible = await sbGetBatimentEtat('republic', cible.city, cible.buildingId).catch(() => null);
          if (!etatCible) continue;
          const entrepotCible = etatCible.entrepot || { stock: {}, caisse: 8500 };
          const stockCible = entrepotCible.stock || {};
          const plafondProduit = RESSOURCES_ECONOMIE_SERVEUR[chaine.produit].plafond;
          const placeRestante = Math.max(0, plafondProduit - (stockCible[chaine.produit] || 0));
          const qteStockee = Math.min(parEntrepot, placeRestante);
          stockCible[chaine.produit] = (stockCible[chaine.produit] || 0) + qteStockee;
          await sbSetBatimentEtat('republic', cible.city, cible.buildingId, { ...etatCible, entrepot: { ...entrepotCible, stock: stockCible } }).catch(() => {});
        }

        // Le reste part en vente directe, plafonne sur place
        const plafondLocal = PLAFOND_VENTE_DIRECTE;
        const placeRestanteLocal = Math.max(0, plafondLocal - (venteDirecte[chaine.produit] || 0));
        venteDirecte[chaine.produit] = (venteDirecte[chaine.produit] || 0) + Math.min(venteDirecteQte, placeRestanteLocal);

        resultats.uniteesProduites += uniteesProduites;
      }

      await sbSetBatimentEtat('republic', transfo.city, transfo.buildingId, { ...etat, usine: { caisse, venteDirecte } }).catch(() => {});
      resultats.transformateurs++;
    }
  } catch(e) { console.error('produireTransformateursQuotidien error', e); }
  return resultats;
}

async function livrerEntrepotsQuotidien() {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """    // 12. Livraisons quotidiennes des entrepots logistiques (6 livraisons simulees en une
    // passe, limite du plan Vercel Hobby)
    const livraisons = await livrerEntrepotsQuotidien();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers, prets, blocusExpires, effetsBlocus, livraisons });"""
new_2 = """    // 12. Livraisons quotidiennes des entrepots logistiques (6 livraisons simulees en une
    // passe, limite du plan Vercel Hobby)
    const livraisons = await livrerEntrepotsQuotidien();

    // 13. Production quotidienne des transformateurs (mode PNJ), redistribution 60/40
    const production = await produireTransformateursQuotidien();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers, prets, blocusExpires, effetsBlocus, livraisons, production });"""
assert content.count(old_2) == 1, f"trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Production quotidienne des 3 transformateurs créée (ratio 2:1, redistribution 60/40, mode PNJ).")
