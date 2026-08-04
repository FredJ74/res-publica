#!/usr/bin/env python3
PATH = "api/cron-minuit.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function nettoyerAchatsDirectsManques() {"""
new = """// Table dupliquee cote serveur (les niveaux de construction ne changent que rarement — si
// modifies un jour cote client, penser a repercuter ici aussi).
const NIVEAUX_CONSTRUCTION_SERVEUR = {
  hangar:            { label: 'Hangar',             cout: 30000 },
  commerce_standard: { label: 'Commerce standard',  cout: 50000 },
  commerce_premium:  { label: 'Commerce premium',   cout: 70000 },
  building:          { label: 'Building',           cout: 100000 }
};

const ALEAS_CHANTIER = [
  { cle: 'intemperies', texte: "Intempéries : le chantier a pris du retard à cause de la pluie." },
  { cle: 'canicule',    texte: "Canicule : les travaux ont été suspendus par forte chaleur, pour la sécurité des ouvriers." }
];

// Progression quotidienne de tous les chantiers en cours : verifie les versements dus,
// gere les impayes (relance J+2, perte de l'acompte + recul d'un palier a J+3), tire les
// aleas (intemperies/canicule pour l'instant), et livre le batiment quand tout est paye et
// la date de fin prevue atteinte.
async function avancerChantiersQuotidien() {
  const resultats = { livraisons: 0, impayes: 0, expulsions_palier: 0, aleas: 0 };
  try {
    const terrains = await sbGet('terrains_etat', '');
    if (!terrains) return resultats;

    for (const row of terrains) {
      let etat;
      try { etat = JSON.parse(row.data); } catch(e) { continue; }
      const ch = etat.chantier;
      if (!ch) continue;

      const maintenant = Date.now();
      const cur = 'FR';
      let modifie = true;

      if (ch.enAttentePaiement) {
        ch.joursImpayes = (ch.joursImpayes || 0) + 1;

        if (ch.joursImpayes === 2) {
          const montantDu = ch.palierPaye === 1 ? ch.montant35 : ch.montant30;
          await sbInsert('mails', {
            destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
            sujet: 'Relance — versement impayé',
            corps: 'Dernier rappel : le versement de ' + montantDu + ' ' + cur + ' n\\'est toujours pas réglé. Sans paiement demain, le chantier régressera et l\\'acompte déjà versé pour ce palier sera perdu.',
            archived: false
          }).catch(() => {});
        } else if (ch.joursImpayes >= 3) {
          ch.palierPaye = Math.max(1, ch.palierPaye - 1);
          ch.dateFinPrevue += 3 * 86400000;
          ch.enAttentePaiement = false;
          ch.joursImpayes = 0;
          resultats.expulsions_palier++;
          await sbInsert('mails', {
            destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
            sujet: 'Chantier régressé — acompte perdu',
            corps: 'Faute de paiement, le chantier a régressé d\\'un palier. L\\'acompte déjà versé pour ce palier est perdu. Il faudra le repayer pour reprendre les travaux.',
            archived: false
          }).catch(() => {});
        }
      } else if (ch.palierPaye === 1 && maintenant >= ch.dateDebut + Math.floor(ch.dureeJours / 2) * 86400000) {
        ch.enAttentePaiement = true;
        ch.joursImpayes = 0;
        await sbInsert('mails', {
          destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
          sujet: 'Versement de mi-chantier dû',
          corps: 'Le chantier a atteint la moitié de son avancement. Un versement de ' + ch.montant35 + ' ' + cur + ' est attendu pour continuer.',
          archived: false
        }).catch(() => {});
      } else if (ch.palierPaye === 2 && maintenant >= ch.dateFinPrevue) {
        ch.enAttentePaiement = true;
        ch.joursImpayes = 0;
        await sbInsert('mails', {
          destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
          sujet: 'Solde du chantier dû',
          corps: 'Le chantier est prêt à être livré. Le solde de ' + ch.montant30 + ' ' + cur + ' est attendu pour la remise des clés.',
          archived: false
        }).catch(() => {});
      } else if (ch.palierPaye >= 3 && maintenant >= ch.dateFinPrevue) {
        // Livraison
        const niveau = NIVEAUX_CONSTRUCTION_SERVEUR[ch.niveau];
        etat.niveau_construction = ch.niveau;
        etat.constructionAutorisee = true;
        delete etat.chantier;
        resultats.livraisons++;
        await sbInsert('mails', {
          destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
          sujet: 'Chantier livré !',
          corps: 'Le chantier est terminé : ' + (niveau ? niveau.label : ch.niveau) + ' livré. Les clés vous attendent sur place.',
          archived: false
        }).catch(() => {});
      } else if (Math.random() < 0.08) {
        const alea = ALEAS_CHANTIER[Math.floor(Math.random() * ALEAS_CHANTIER.length)];
        const joursAjoutes = 1 + Math.floor(Math.random() * 2);
        ch.dateFinPrevue += joursAjoutes * 86400000;
        ch.evenements = ch.evenements || [];
        ch.evenements.push({ cle: alea.cle, date: maintenant, joursAjoutes });
        resultats.aleas++;
        await sbInsert('mails', {
          destinataire: etat.proprietaire, expediteur: 'Chef de Chantier',
          sujet: 'Retard de chantier',
          corps: alea.texte + ' Retard : +' + joursAjoutes + ' jour(s).',
          archived: false
        }).catch(() => {});
      } else {
        modifie = false;
      }

      if (modifie) {
        etat.chantier = ch.niveau ? ch : undefined; // si livre, chantier a deja ete supprime plus haut
        if (etat.chantier === undefined) delete etat.chantier;
        else etat.chantier = ch;
        await sbUpdate('terrains_etat', `id=eq.${encodeURIComponent(row.id)}`, { data: JSON.stringify(etat), updated_at: new Date().toISOString() }).catch(() => {});
      }
    }
  } catch(e) { console.error('avancerChantiersQuotidien error', e); }
  return resultats;
}

async function nettoyerAchatsDirectsManques() {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

old_2 = """    // 7. Rendez-vous d'achat direct manques (depot perdu, terrain libere)
    const achatsDirectsManques = await nettoyerAchatsDirectsManques();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques });"""
new_2 = """    // 7. Rendez-vous d'achat direct manques (depot perdu, terrain libere)
    const achatsDirectsManques = await nettoyerAchatsDirectsManques();

    // 8. Progression quotidienne des chantiers (versements, alea, livraison)
    const chantiers = await avancerChantiersQuotidien();

    return res.status(200).json({ ok: true, traites: results.length, details: results, mailsSupprimes: mailsSuppres, fuites, taxeFonciere, loyersLots, compromisResolus, achatsDirectsManques, chantiers });"""
assert content.count(old_2) == 1, f"trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Progression quotidienne des chantiers créée : versements, impayés, aléas, livraison.")
