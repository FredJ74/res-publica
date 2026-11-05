/* ===========================================================================
   EQUIPEMENTS DE BUREAU ET TRADING DE MATIERES PREMIERES (3 novembre 2026)
   ===========================================================================

   L'ancienne interface d'attente devient la vraie : l'ordre « Installer des
   equipements » (bureaux du centre d'affaires) ouvre cette fenetre.

   Decisions de Fred (GAME-DESIGN-TRADING.md) : un ordinateur et une box
   internet installes dans un bureau dont le PJ a la jouissance legale donnent
   une connexion ; depuis ce bureau, le PJ consulte les cours des entrepots
   (0 PA) et achete a distance pour le compte d'une organisation economique
   (1 PA, payee par la caisse de l'organisation). La marchandise part en caisse
   terrestre vers l'entrepôt logistique choisi (04/11). Le chef autorise ses traders.

   TOUT EST DECIDE PAR LE SERVEUR : emplacements (3 en gratuit, 6 avec l'option premium du bureau),
   jouissance, connexion, prix, stock, caisse, PA. Cet ecran n'affiche que ses
   reponses et n'ecrit rien lui-meme.
   =========================================================================== */

const EQUIPEMENTS_LIBELLES = { 'ordinateur-complet': 'Ordinateur', 'box-internet': 'Box internet', 'armoire_souvenirs': 'Armoire à souvenirs' };
const TRADING_VILLES = { capitale: 'Luthécia', ville_a: 'Port-Sainte-Marie', ville_b: 'Montrouge' };
// Nom d'une ville d'entrepôt, quel que soit son pays (trading international, 05/11/2026).
function tradingNomVille(pays, ville) {
  return (typeof WORLD !== 'undefined' && WORLD?.[pays || 'republic']?.[ville]?.name) || TRADING_VILLES[ville] || ville;
}
const EQUIPEMENTS_REFUS = {
  acteur_non_authentifie: 'Votre personnage n\'est pas identifié.',
  pas_dans_un_local: 'Il faut être dans un local.',
  pas_de_jouissance: 'Vous n\'avez pas la jouissance légale de ce local (bail à votre nom ou à celui de votre organisation).',
  emplacements_pleins: 'Tous les emplacements de ce bureau sont occupés.',
  option_deja_active: 'L\'option premium est déjà active pour ce bureau.',
  deja_installe: 'Cet équipement est déjà installé ici.',
  objet_absent: 'Vous n\'avez pas cet équipement sur vous.',
  equipement_inconnu: 'Cet objet ne s\'installe pas.',
  equipement_introuvable: 'Cet équipement n\'est plus là.',
  pas_proprietaire: 'Cet équipement ne vous appartient pas.',
  pas_sur_place: 'Il faut être dans le bureau où il est installé.',
  inventaire_plein: 'Votre inventaire est plein.',
  pas_de_connexion: 'Il faut être dans votre bureau, avec votre ordinateur et votre box installés.',
  pas_trader: 'Vous n\'êtes ni chef ni trader autorisé de cette organisation.',
  pa_insuffisants: 'Il vous faut 1 PA.',
  quantite_invalide: 'Quantité invalide.',
  port_indisponible: 'Aucun port industriel ne relie ces deux pays pour l\'instant.',
  stock_insuffisant: 'L\'entrepôt n\'a pas autant en stock.',
  caisse_organisation_insuffisante: 'La caisse de l\'organisation ne suffit pas.',
  entrepot_inconnu: 'Entrepôt inconnu.',
  pas_chef: 'Seul le chef de l\'organisation peut autoriser un trader.',
  pas_membre: 'Cette personne n\'est pas membre de l\'organisation.',
  // Serrures (04/11/2026, issue #434)
  armoire_fermee_a_cle: 'Cette armoire est fermée à clé : ouvrez-la d\'abord avec sa clé.',
  serrure_introuvable: 'Cette serrure est introuvable.',
  serrure_deja_posee: 'Cette serrure est déjà posée.',
  serrure_detruite: 'Cette serrure a été détruite (fin du bail) : sa clé n\'ouvre plus rien.',
  serrure_non_posee: 'Cette serrure n\'est pas encore posée.',
  deja_une_serrure: 'Il y a déjà une serrure ici.',
  cle_requise: 'Il vous faut une clé de cette serrure.',
  cle_vierge_requise: 'Il vous faut une clé vierge (vendue en armurerie).',
  cible_invalide: 'Cible invalide.',
  cible_exclue: 'On ne pose pas de serrure sur une chambre d\'hôtel ou de clinique.',
  pas_de_jouissance_integrale: 'Il faut avoir l\'intégralité de la jouissance du bâtiment (aucun lot loué à quelqu\'un d\'autre).',
  armoire_introuvable: 'Cette armoire n\'est pas installée ici.'
};

function equipementsEchapper(t) {
  return (typeof escapeHtmlText === 'function') ? escapeHtmlText(String(t == null ? '' : t)) : String(t == null ? '' : t);
}
function equipementsRefus(r) {
  return (r && EQUIPEMENTS_REFUS[r.raison]) || 'Le serveur a refusé' + (r && r.raison ? ' (' + r.raison + ')' : '') + '. Rien n\'a été modifié.';
}
function equipementsModale(titre, html) {
  const t = document.getElementById('postes-modal-title');
  const c = document.getElementById('postes-body');
  const m = document.getElementById('modal-postes');
  if (!t || !c || !m) return null;
  t.textContent = titre;
  c.innerHTML = '<div class="cpj-dialogue" style="padding:1rem">' + html + '</div>';
  m.classList.add('open');
  return c;
}
function equipementsBouton(onclick, libelle, primaire) {
  return '<button class="cpj-touche' + (primaire ? ' cpj-primaire' : '') + '" onclick="' + onclick + '">' +
    equipementsEchapper(libelle) + '</button>';
}

async function ouvrirModalEquipements() {
  equipementsModale('Équipements du local', '<p class="cpj-note">…</p>');
  const r = await sbRpc('equipements_local_lire', {}).catch(function () { return null; });
  if (!r || r.ok !== true) { equipementsModale('Équipements du local', '<p class="cpj-note">' + equipementsEchapper(equipementsRefus(r)) + '</p>'); return; }

  let h = '<p class="cpj-note">' + r.installes.length + ' / ' + r.emplacements + ' emplacements d\'équipement occupés dans ce local' +
    (r.option_premium_bureau ? ' (option premium).' : '.') +
    (r.jouissance ? '' : ' Vous n\'en avez pas la jouissance légale : vous ne pouvez rien y installer.') + '</p>';
  if (r.jouissance && !r.option_premium_bureau) {
    h += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.6rem;margin:.3rem 0">' +
      '<span class="cpj-note">Option premium : ' + r.emplacements_premium + ' emplacements au lieu de ' + r.emplacements_gratuits +
      ', pour ce bureau, tant que vous le gardez. Gratuite pendant la bêta.</span>' +
      equipementsBouton('equipementOptionPremium()', 'Activer l\'option') + '</div>';
  }

  h += '<div class="cpj-titre">Installés</div>';
  if (!r.installes.length) h += '<p class="cpj-note">Aucun équipement.</p>';
  r.installes.forEach(function (e) {
    h += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.6rem;margin:.3rem 0">' +
      '<span>' + equipementsEchapper(EQUIPEMENTS_LIBELLES[e.generique_id] || e.nom) +
      (e.a_moi ? '' : ' <span class="cpj-note">(à ' + equipementsEchapper(e.proprietaire) + ')</span>') +
      (e.a_moi && e.delai_jusqu_au ? ' <span class="cpj-note">— bail perdu : à désinstaller avant le ' +
        equipementsEchapper(new Date(e.delai_jusqu_au).toLocaleString('fr-FR', { timeZone: 'Europe/Paris', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' })) +
        ', sinon il revient au propriétaire des lieux</span>' : '') +
      (e.serrure ? ' <span class="cpj-note">— serrure n° ' + equipementsEchapper(e.serrure.numero) + (e.serrure.fermee ? ', fermée à clé' : ', ouverte') + '</span>' : '') +
      '</span><span style="display:flex;gap:.3rem">' +
      (e.serrure && e.serrure.a_cle ? equipementsBouton('serrureBasculer(\'' + e.serrure.id + '\',' + (!e.serrure.fermee) + ')', e.serrure.fermee ? 'Ouvrir' : 'Fermer à clé') : '') +
      (e.a_moi ? equipementsBouton('equipementDesinstaller(\'' + e.id + '\')', 'Désinstaller') : '') + '</span></div>';
  });

  if (r.jouissance && r.installables.length) {
    h += '<div class="cpj-titre">Dans votre inventaire</div>';
    r.installables.forEach(function (g) {
      h += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.6rem;margin:.3rem 0">' +
        '<span>' + equipementsEchapper(EQUIPEMENTS_LIBELLES[g] || g) + '</span>' +
        equipementsBouton('equipementInstaller(\'' + g + '\')', 'Installer', true) + '</div>';
    });
  }

  h += serruresBlocLocalHtml(r);
  h += '<div class="cpj-titre">Connexion internet</div>';
  h += r.connexion
    ? '<p class="cpj-note">Votre ordinateur et votre box sont installés : vous êtes connecté.</p>' +
      equipementsBouton('ouvrirTrading()', 'Trading de matières premières', true)
    : '<p class="cpj-note">Installez ici votre ordinateur et votre box internet pour vous connecter.</p>';
  equipementsModale('Équipements du local', h);
}

async function equipementInstaller(generique) {
  const r = await sbRpc('equipement_installer', { p_generique: generique }).catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  if (typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(r);
  if (typeof renderInventory === 'function') renderInventory();
  showToast('Équipement installé', EQUIPEMENTS_LIBELLES[generique] || generique, true);
  ouvrirModalEquipements();
}

async function equipementOptionPremium() {
  const r = await sbRpc('equipement_option_premium_activer', {}).catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  showToast('Option premium activée', r.emplacements + ' emplacements dans ce bureau.', true);
  ouvrirModalEquipements();
}

async function equipementDesinstaller(id) {
  const r = await sbRpc('equipement_desinstaller', { p_id: id }).catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  if (typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(r);
  if (typeof renderInventory === 'function') renderInventory();
  showToast('Équipement désinstallé', 'Il est de retour dans votre inventaire.', true);
  ouvrirModalEquipements();
}

// ---------------------------------------------------------------------------
// TRADING
// ---------------------------------------------------------------------------
async function ouvrirTrading() {
  equipementsModale('Trading de matières premières', '<p class="cpj-note">Connexion…</p>');
  const r = await sbRpc('trading_cours', {}).catch(function () { return null; });
  if (!r || r.ok !== true) { equipementsModale('Trading de matières premières', '<p class="cpj-note">' + equipementsEchapper(equipementsRefus(r)) + '</p>'); return; }
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';

  // Livraison terrestre nationale (décision de Fred, 04/11/2026) : camion ou train vers l'entrepôt
  // logistique de la ville choisie, sans douane ; retrait à la Salle des ventes.
  let h = '<p class="cpj-note">Cours des matières dans les entrepôts. À distance, on ne peut qu\'acheter : ' +
    'la marchandise est livrée par voie terrestre, en caisse, à l\'entrepôt logistique de la ville que vous choisissez. ' +
    'Six livraisons par jour (0 h, 4 h, 8 h, 12 h, 16 h, 20 h) : une commande est livrée à la fin de la tranche suivante (commandée à 7 h, livrée à 12 h). Retrait à la Salle des ventes, « Réceptionner une caisse ». ' +
    'Chaque commande coûte 1 PA et elle est payée par la caisse de l\'organisation.</p>';

  if (!r.organisations.length) {
    h += '<p class="cpj-note">Vous n\'êtes ni chef ni trader autorisé d\'une organisation économique : vous pouvez consulter les cours, pas acheter.</p>';
  } else {
    h += '<label class="cpj-note" for="trading-orga">Pour le compte de</label> ' +
      '<select id="trading-orga" class="cpj-champ">' + r.organisations.map(function (o) {
        return '<option value="' + equipementsEchapper(o.id) + '">' + equipementsEchapper(o.nom) + ' — caisse ' +
          equipementsEchapper(o.caisse) + ' ' + equipementsEchapper(cur) + '</option>';
      }).join('') + '</select>';
  }

  if (r.organisations.length && r.entrepots.length) {
    const villeIci = state.currentCity || 'capitale';
    h += ' <label class="cpj-note" for="trading-livraison">Livrer à</label> ' +
      '<select id="trading-livraison" class="cpj-champ">' + r.entrepots.filter(function (e) { return !e.international; }).map(function (e) {
        return '<option value="' + equipementsEchapper(e.id) + '"' + (e.ville === villeIci ? ' selected' : '') + '>Entrepôt de ' +
          equipementsEchapper(tradingNomVille(e.pays, e.ville)) + '</option>';
      }).join('') + '</select>';
  }

  r.entrepots.forEach(function (e) {
    const empire = e.international && typeof COUNTRIES !== 'undefined' ? (COUNTRIES[e.pays]?.n || e.pays) : '';
    h += '<div class="cpj-titre">Entrepôt — ' + equipementsEchapper(tradingNomVille(e.pays, e.ville)) +
      (empire ? ' (' + equipementsEchapper(empire) + ', international)' : '') + '</div>';
    if (e.international) {
      h += '<p class="cpj-note">Achat international : la caisse part par le port de ' + equipementsEchapper(tradingNomVille(e.pays, e.port_depart_ville)) +
        ' et arrive au port industriel de ' + equipementsEchapper(tradingNomVille(state.country, e.port_arrivee_ville)) +
        ', où vous la dédouanez (10 % de sa valeur) avant de la retirer. Fret international : ' + equipementsEchapper(e.fret_unitaire) +
        ' ' + equipementsEchapper(cur) + ' par unité, payé avec l\'achat par la caisse de l\'organisation.</p>';
    }
    h += '<table style="width:100%;border-collapse:collapse;font-size:.85rem"><tr class="cpj-note">' +
      '<th style="text-align:left">Matière</th><th>Prix</th><th>Disponible</th><th></th></tr>';
    e.cours.forEach(function (c) {
      const lib = (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[c.ressource]?.label) || c.ressource;
      const champ = 'trading-q-' + e.id + '-' + c.ressource;
      h += '<tr><td>' + equipementsEchapper(lib) + '</td><td style="text-align:center">' + equipementsEchapper(c.prix) + ' ' +
        equipementsEchapper(cur) + '</td><td style="text-align:center">' + equipementsEchapper(c.disponible) + '</td><td style="text-align:right">' +
        (r.organisations.length && c.disponible > 0
          ? '<input id="' + equipementsEchapper(champ) + '" class="cpj-champ" type="number" min="1" max="' + c.disponible +
            '" value="1" style="width:4.5rem"> ' +
            equipementsBouton('tradingAcheter(\'' + e.id + '\',\'' + c.ressource + '\')', 'Acheter', true)
          : '') + '</td></tr>';
    });
    h += '</table>';
  });

  h += '<div style="margin-top:1rem">' + equipementsBouton('ouvrirOffresAchat(\'trader\')', 'Offres d\'achat', true) + '</div>';
  if (r.organisations.some(function (o) { return o.chef; })) {
    h += '<div style="margin-top:1rem">' + equipementsBouton('ouvrirTradingTraders()', 'Gérer mes traders') + '</div>';
  }
  equipementsModale('Trading de matières premières', h);
}

async function tradingAcheter(entrepot, ressource) {
  const orga = (document.getElementById('trading-orga') || {}).value;
  const champ = document.getElementById('trading-q-' + entrepot + '-' + ressource);
  const q = parseInt(champ && champ.value, 10);
  if (!orga || !(q > 0)) { showToast('Refusé', EQUIPEMENTS_REFUS.quantite_invalide, false); return; }
  const livraison = (document.getElementById('trading-livraison') || {}).value || null;
  const r = await sbRpc('trading_acheter', { p_organisation: orga, p_entrepot: entrepot, p_ressource: ressource, p_quantite: q, p_livraison: livraison })
    .catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  if (typeof r.pa === 'number' && typeof state !== 'undefined') { state.pa = r.pa; if (typeof updateUI === 'function') updateUI(); }
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';
  const ou = r.international
    ? 'le port industriel de ' + tradingNomVille(r.pays_livraison, r.ville_livraison) + ' (dédouanement puis retrait au port)'
    : 'l\'Entrepôt Logistique de ' + tradingNomVille(r.pays_livraison, r.ville_livraison) + ' (Salle des ventes, « Réceptionner une caisse »)';
  showToast('Commande passée', r.quantite + ' × ' + r.ressource + ' pour ' + r.montant + ' ' + cur +
    (r.fret ? ' + ' + r.fret + ' ' + cur + ' de fret' : '') +
    ' (' + r.organisation + '). Caisse en route vers ' + ou + ', détails par courrier.', true, true);
  if (typeof addJournalEntry === 'function') {
    addJournalEntry('Trading : ' + r.quantite + ' ' + r.ressource + ' achetés ' + r.montant + ' ' + cur +
      ' pour ' + r.organisation + '. Caisse en route vers ' + ou + '.', 'event-good');
  }
  ouvrirTrading();
}

async function ouvrirTradingTraders() {
  const r = await sbRpc('trading_traders_lire', {}).catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  let h = '<p class="cpj-note">En tant que chef, vous autorisez les membres de votre organisation économique à trader pour son compte.</p>';
  r.organisations.forEach(function (o) {
    h += '<div class="cpj-titre">' + equipementsEchapper(o.nom) + '</div>';
    if (!o.membres.length) h += '<p class="cpj-note">Aucun autre membre.</p>';
    o.membres.forEach(function (nom) {
      const autorise = (o.traders || []).indexOf(nom) >= 0;
      h += '<div style="display:flex;justify-content:space-between;align-items:center;margin:.3rem 0"><span>' +
        equipementsEchapper(nom) + (autorise ? ' <span class="cpj-note">(trader)</span>' : '') + '</span>' +
        equipementsBouton('tradingAutoriser(\'' + equipementsEchapper(o.id) + '\',' + JSON.stringify(nom).replace(/"/g, '&quot;') + ',' + (!autorise) + ')',
          autorise ? 'Retirer' : 'Autoriser', !autorise) + '</div>';
    });
  });
  h += '<div style="margin-top:1rem">' + equipementsBouton('ouvrirTrading()', 'Retour aux cours') + '</div>';
  equipementsModale('Mes traders', h);
}

async function tradingAutoriser(orga, nom, autorise) {
  const r = await sbRpc('organisation_trader_autoriser', { p_organisation: orga, p_membre: nom, p_autorise: autorise })
    .catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  showToast('Traders', autorise ? nom + ' peut désormais trader.' : nom + ' ne trade plus.', true);
  ouvrirTradingTraders();
}

// ---------------------------------------------------------------------------
// OFFRES D'ACHAT (etape 2, 3 novembre 2026)
// ---------------------------------------------------------------------------
// Directeur d'entrepot (depuis son tableau de bord) ou trader connecte (depuis son bureau).
// Publier bloque l'argent (caisse de l'entrepot ou de l'organisation) ; la part non servie revient
// au retrait ou apres 7 jours. Servir : directeur depuis le stock de son entrepot, trader depuis ses
// matieres ou le stock d'un de ses locaux (paye a son organisation). Vente partielle admise.
Object.assign(EQUIPEMENTS_REFUS, {
  poste_non_detenu: 'Vous ne dirigez pas d\'entrepôt.',
  prix_invalide: 'Prix invalide.',
  capacite_insuffisante: 'L\'entrepôt n\'a pas la place.',
  capacite_acheteur_insuffisante: 'L\'entrepôt acheteur n\'a plus la place.',
  tresorerie_insuffisante: 'La trésorerie de l\'entrepôt ne suffit pas.',
  offre_introuvable: 'Cette offre n\'existe plus.',
  offre_close: 'Cette offre est close.',
  pas_auteur: 'Seul l\'auteur peut retirer son offre.',
  propre_offre: 'Vous ne pouvez pas servir votre propre offre.',
  matiere_insuffisante: 'Vous n\'avez pas assez de cette matière à cet endroit.',
  pas_proprietaire_local: 'Ce local ne vous appartient pas.',
  source_inconnue: 'Choisissez d\'où part la marchandise.'
});
let RP_OFFRES_MODE = 'trader';

function offresLibelleRessource(cle) {
  return (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[cle]?.label) || cle;
}

async function ouvrirOffresAchat(mode) {
  RP_OFFRES_MODE = mode || RP_OFFRES_MODE;
  equipementsModale('Offres d\'achat', '<p class="cpj-note">…</p>');
  const r = await sbRpc('offres_achat_lire', {}).catch(function () { return null; });
  if (!r || r.ok !== true) { equipementsModale('Offres d\'achat', '<p class="cpj-note">' + equipementsEchapper(equipementsRefus(r)) + '</p>'); return; }
  const directeur = RP_OFFRES_MODE === 'directeur' && !!r.directeur_de;
  let orgas = [];
  if (!directeur) {
    const c = await sbRpc('trading_cours', {}).catch(function () { return null; });
    orgas = (c && c.ok === true) ? c.organisations : [];
  }
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';
  const ressources = (typeof RESSOURCES_ECONOMIE !== 'undefined') ? Object.keys(RESSOURCES_ECONOMIE) : [];

  let h = '<p class="cpj-note">' + (directeur
    ? 'Vous agissez pour votre entrepôt : vos offres sont payées par sa trésorerie, vous servez depuis son stock.'
    : 'Vous agissez pour une organisation : ses offres sont payées par sa caisse ; quand vous servez, elle est payée.') +
    ' L\'argent d\'une offre est bloqué à la publication ; la part non servie revient au retrait ou après 7 jours.</p>';

  if (!directeur && orgas.length) {
    h += '<label class="cpj-note" for="offre-orga">Organisation</label> <select id="offre-orga" class="cpj-champ">' +
      orgas.map(function (o) { return '<option value="' + equipementsEchapper(o.id) + '">' + equipementsEchapper(o.nom) + '</option>'; }).join('') + '</select>';
  }
  if (!directeur) {
    h += ' <label class="cpj-note" for="offre-source">Marchandise prise</label> <select id="offre-source" class="cpj-champ">' +
      '<option value="inventaire|">sur moi</option>' +
      (r.locaux || []).map(function (l) { return '<option value="local|' + equipementsEchapper(l.id) + '">dans ' + equipementsEchapper(l.enseigne || 'mon local') + '</option>'; }).join('') +
      '</select>';
  }

  h += '<div class="cpj-titre">Offres ouvertes</div>';
  if (!r.offres.length) h += '<p class="cpj-note">Aucune offre en cours.</p>';
  r.offres.forEach(function (o) {
    h += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.5rem;margin:.35rem 0;flex-wrap:wrap">' +
      '<span>' + equipementsEchapper(o.acheteur) + ' achète <strong>' + o.restante + '</strong> ' + equipementsEchapper(offresLibelleRessource(o.ressource)) +
      ' à ' + equipementsEchapper(o.prix) + ' ' + equipementsEchapper(cur) + '</span><span>' +
      (o.a_moi
        ? equipementsBouton('offreRetirer(\'' + o.id + '\')', 'Retirer')
        : ((directeur || orgas.length)
            ? '<input id="offre-q-' + o.id + '" class="cpj-champ" type="number" min="1" max="' + o.restante + '" value="' + o.restante + '" style="width:4.5rem"> ' +
              equipementsBouton('offreServir(\'' + o.id + '\')', 'Vendre', true)
            : '')) + '</span></div>';
  });

  if (directeur || orgas.length) {
    h += '<div class="cpj-titre">Publier une offre</div>' +
      '<select id="offre-res" class="cpj-champ">' + ressources.map(function (k) {
        return '<option value="' + k + '">' + equipementsEchapper(offresLibelleRessource(k)) + '</option>'; }).join('') + '</select> ' +
      '<input id="offre-qte" class="cpj-champ" type="number" min="1" value="10" style="width:5rem" title="Quantité"> × ' +
      '<input id="offre-prix" class="cpj-champ" type="number" min="0.01" step="0.01" value="5" style="width:5rem" title="Prix unitaire"> ' +
      equipementsEchapper(cur) + ' ' + equipementsBouton('offrePublier()', 'Publier', true);
  }
  if (!directeur) h += '<div style="margin-top:1rem">' + equipementsBouton('ouvrirTrading()', 'Retour aux cours') + '</div>';
  else h += '<div style="margin-top:1rem">' + equipementsBouton('ouvrirTableauBordEntrepot()', 'Retour au tableau de bord') + '</div>';
  equipementsModale('Offres d\'achat', h);
}

async function offrePublier() {
  const directeur = RP_OFFRES_MODE === 'directeur';
  const params = {
    p_type: directeur ? 'entrepot' : 'organisation',
    p_organisation: directeur ? null : ((document.getElementById('offre-orga') || {}).value || null),
    p_ressource: (document.getElementById('offre-res') || {}).value,
    p_quantite: parseInt((document.getElementById('offre-qte') || {}).value, 10),
    p_prix: Number((document.getElementById('offre-prix') || {}).value)
  };
  const r = await sbRpc('offre_achat_publier', params).catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  showToast('Offre publiée', r.montant_bloque + ' bloqués (' + r.acheteur + ').', true);
  ouvrirOffresAchat();
}

async function offreRetirer(id) {
  const r = await sbRpc('offre_achat_retirer', { p_offre: id }).catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  showToast('Offre retirée', r.rembourse + ' remboursés.', true);
  ouvrirOffresAchat();
}

async function offreServir(id) {
  const directeur = RP_OFFRES_MODE === 'directeur';
  const q = parseInt((document.getElementById('offre-q-' + id) || {}).value, 10);
  const src = directeur ? ['entrepot', ''] : String((document.getElementById('offre-source') || {}).value || 'inventaire|').split('|');
  const r = await sbRpc('offre_achat_servir', {
    p_offre: id, p_quantite: q, p_source: src[0],
    p_organisation: directeur ? null : ((document.getElementById('offre-orga') || {}).value || null),
    p_fonds: src[1] || null
  }).catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  if (src[0] === 'inventaire' && typeof sbAdopterInventaireServeur === 'function') {
    sbAdopterInventaireServeur(r); if (typeof renderInventory === 'function') renderInventory();
  }
  showToast('Vente conclue', r.quantite + ' ' + offresLibelleRessource(r.ressource) + ' vendus ' + r.montant + ' (' + r.vendeur + '). Livraison au cron de minuit.', true, true);
  ouvrirOffresAchat();
}

// ---------------------------------------------------------------------------
// SERRURES (4 novembre 2026 -- issue #434, GAME-DESIGN-SERRURES.md)
// ---------------------------------------------------------------------------
// Decisions de Fred : une serrure se pose sur place, depuis l'inventaire, sur une armoire a
// souvenirs installee ou sur un local / appartement dont on a la jouissance ; une cle la ferme ou
// l'ouvre ; fermee, elle interdit d'entrer (ou d'ouvrir l'armoire) a qui n'a pas de cle ; une cle
// vierge taillee sur une cle detenue devient un double ; au depart du locataire, la serrure du lieu
// est detruite. TOUT est decide par le serveur (serrure_poser, serrure_basculer, cle_dupliquer,
// serrure_etat, equipements_local_lire) : cet ecran n'affiche que ses reponses.

function serrureIllustration(icone) {
  return '<div style="text-align:center;font-size:3rem;margin:.2rem 0 .6rem"><i class="ti ' + icone + '"></i></div>';
}
function serrureLieuLibelle(r) {
  if (r.cible === 'batiment') {
    const nomBat = (typeof BUILDINGS !== 'undefined' && BUILDINGS[r.batiment]?.name) || r.batiment || '';
    return nomBat + (TRADING_VILLES[r.ville] ? ' (' + TRADING_VILLES[r.ville] + ')' : '');
  }
  const piece = (typeof BUILDINGS !== 'undefined' && BUILDINGS[r.batiment]?.rooms?.[r.piece]?.name) || r.piece || '';
  return piece.replace(/ — Local à louer$/, '') + (TRADING_VILLES[r.ville] ? ' (' + TRADING_VILLES[r.ville] + ')' : '');
}
function serrureRefusInventaire(x) { showToast('Refusé', equipementsRefus(x), false); return true; }

// Bloc « Serrure de ce local » de la fenetre des equipements.
function serruresBlocLocalHtml(r) {
  const s = r.serrures;
  if (!s) return '';
  const ligne = function (texte, bouton) {
    return '<div style="display:flex;justify-content:space-between;align-items:center;gap:.6rem;margin:.3rem 0"><span>' + texte + '</span>' + (bouton || '') + '</div>';
  };
  let h = '<div class="cpj-titre">Serrure de ce local</div>';
  if (s.lieu) {
    h += ligne('Serrure n° ' + equipementsEchapper(s.lieu.numero) + ' — ' + (s.lieu.fermee ? 'fermée à clé' : 'ouverte'),
      s.lieu.a_cle ? equipementsBouton('serrureBasculer(\'' + s.lieu.id + '\',' + (!s.lieu.fermee) + ')', s.lieu.fermee ? 'Ouvrir au public' : 'Fermer à clé', true)
                   : '<span class="cpj-note">Vous n\'en avez pas la clé.</span>');
  } else if (s.lieu_posable && s.blocs.length) {
    s.blocs.forEach(function (b) {
      h += ligne('Aucune serrure.', equipementsBouton('serrurePoser(\'' + b.id + '\',\'lieu\',null)', 'Poser la serrure n° ' + b.numero, true));
    });
  } else {
    h += '<p class="cpj-note">Aucune serrure.' + (s.lieu_posable ? ' Les serrures à clé se vendent en armurerie.' : '') + '</p>';
  }
  if (s.batiment || s.batiment_posable) {
    h += '<div class="cpj-titre">Serrure du bâtiment</div>';
    if (s.batiment) {
      h += ligne('Entrée — serrure n° ' + equipementsEchapper(s.batiment.numero) + ' — ' + (s.batiment.fermee ? 'fermée à clé' : 'ouverte au public'),
        s.batiment.a_cle ? equipementsBouton('serrureBasculer(\'' + s.batiment.id + '\',' + (!s.batiment.fermee) + ')', s.batiment.fermee ? 'Ouvrir au public' : 'Fermer à clé', true)
                         : '<span class="cpj-note">Vous n\'en avez pas la clé.</span>');
    } else if (s.blocs.length) {
      h += ligne('Vous avez l\'intégralité de la jouissance de ce bâtiment.',
        equipementsBouton('serrurePoser(\'' + s.blocs[0].id + '\',\'batiment\',null)', 'Poser la serrure n° ' + s.blocs[0].numero + ' sur l\'entrée'));
    }
  }
  if (s.armoires_posables.length && s.blocs.length) {
    s.armoires_posables.forEach(function (id, i) {
      h += ligne('Armoire à souvenirs' + (s.armoires_posables.length > 1 ? ' ' + (i + 1) : '') + ' sans serrure',
        equipementsBouton('serrurePoser(\'' + s.blocs[0].id + '\',\'armoire\',\'' + id + '\')', 'Poser la serrure n° ' + s.blocs[0].numero));
    });
  }
  return h;
}

async function serrurePoser(serrureId, cible, equipementId) {
  const v = await executerReceptionInventaire('serrure_poser',
    { p_serrure: serrureId, p_cible: cible, p_equipement: equipementId || null }, { surRefus: serrureRefusInventaire });
  if (!v) return;
  if (typeof renderInventory === 'function') renderInventory();
  showToast('Serrure posée', 'Serrure n° ' + (v.numero || '') + (cible === 'armoire' ? ' posée sur l\'armoire.' : ' posée sur ce local.') +
    ' Elle est ouverte : fermez-la avec sa clé.', true);
  ouvrirModalEquipements();
}

async function serrureBasculer(serrureId, fermer, retourCle) {
  const r = await sbRpc('serrure_basculer', { p_serrure: serrureId, p_fermer: fermer }).catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  showToast(r.fermee ? 'Fermé à clé' : 'Ouvert', 'Serrure n° ' + r.numero + (r.fermee ? ' fermée à clé.' : (r.cible === 'lieu' ? ' : le local est ouvert au public.' : r.cible === 'batiment' ? ' : le bâtiment est ouvert au public.' : ' ouverte.')), true);
  if (state.currentBuilding) serruresPortesCharger(state.currentBuilding);
  if (r.cible === 'batiment') serruresBatimentsCharger();
  if (retourCle != null) ouvrirSerrureObjet(retourCle); else ouvrirModalEquipements();
}

// Clic sur un objet de serrurerie dans l'inventaire.
// Portes fermees a cle du batiment courant (decision de Fred du 04/11/2026, 14 h 07) : cadenas et
// infobulle « Fermé à clé » sur l'onglet du local ; clic reserve a qui detient une cle. Cache
// rempli par la lecture serveur serrures_portes_lire, a l'entree du batiment et apres chaque
// fermeture/ouverture ; les onglets sont redessines si l'etat a change.
let RP_SERRURES_PORTES = { cle: '', pieces: {} };
function serrurePorteEtat(buildingId, roomId) {
  const cle = [state.country, state.currentCity, buildingId].join('|');
  return RP_SERRURES_PORTES.cle === cle ? (RP_SERRURES_PORTES.pieces[roomId] || null) : null;
}
async function serruresPortesCharger(buildingId) {
  if (!buildingId || typeof sbRpc !== 'function') return;
  const cle = [state.country, state.currentCity, buildingId].join('|');
  const r = await sbRpc('serrures_portes_lire', { p_batiment: buildingId }).catch(function () { return null; });
  if (!r || r.ok !== true || state.currentBuilding !== buildingId) return;
  const avant = RP_SERRURES_PORTES.cle === cle ? JSON.stringify(RP_SERRURES_PORTES.pieces) : null;
  RP_SERRURES_PORTES = { cle: cle, pieces: r.pieces || {} };
  if (avant !== JSON.stringify(RP_SERRURES_PORTES.pieces) && typeof renderOngletsPieces === 'function') {
    renderOngletsPieces(buildingId, state.currentRoom);
  }
}

// Batiments fermes a cle de la ville (decision de Fred du 04/11, 14 h 27) : infobulle et cadenas
// dans la rue, entree reservee aux detenteurs d'une cle. Cache rempli par serrures_batiments_lire
// a chaque retour dans la rue et apres chaque fermeture / ouverture.
let RP_SERRURES_BATIMENTS = { cle: '', batiments: {} };
function serrureBatimentEtat(buildingId) {
  const cle = [state.country, state.currentCity].join('|');
  return RP_SERRURES_BATIMENTS.cle === cle ? (RP_SERRURES_BATIMENTS.batiments[buildingId] || null) : null;
}
async function serruresBatimentsCharger() {
  if (typeof sbRpc !== 'function' || !state.char) return;
  const cle = [state.country, state.currentCity].join('|');
  const r = await sbRpc('serrures_batiments_lire', {}).catch(function () { return null; });
  if (!r || r.ok !== true || [state.country, state.currentCity].join('|') !== cle) return;
  RP_SERRURES_BATIMENTS = { cle: cle, batiments: r.batiments || {} };
}

// Clic sur un lieu ferme a cle sans en avoir la cle (decision de Fred du 04/11) : une fenetre le dit.
function serrurePopupFermee(genre) {
  equipementsModale('Fermé à clé', serrureIllustration('ti-lock') +
    '<p style="text-align:center">Vous ne pouvez pas entrer : ' + (genre === 'batiment' ? 'ce bâtiment' : 'ce local') + ' est fermé à clé.</p>' +
    '<p class="cpj-note" style="text-align:center">Seul un détenteur de la clé peut entrer.</p>' +
    '<div style="text-align:center;margin-top:.6rem">' +
    equipementsBouton('document.getElementById(\'modal-postes\').classList.remove(\'open\')', 'Fermer', true) + '</div>');
}

function ouvrirSerrureObjet(idx) {
  const item = state.inventory[idx];
  if (!item) return;
  if (item.type === 'serrure_cle') return ouvrirPoseSerrure(idx);
  if (item.type === 'cle_serrure') return ouvrirCleSerrure(idx);
  if (item.type === 'cle_vierge') return ouvrirDoubleCle(idx);
}

async function ouvrirPoseSerrure(idx) {
  const item = state.inventory[idx];
  const titre = 'Installer la serrure n° ' + (item.numero || '');
  equipementsModale(titre, serrureIllustration('ti-lock') + '<p class="cpj-note">…</p>');
  const r = await sbRpc('equipements_local_lire', {}).catch(function () { return null; });
  const s = r && r.ok === true ? r.serrures : null;
  let h = serrureIllustration('ti-lock') + '<p class="cpj-note">Bloc serrure, vendu avec sa clé. Il se pose ici, maintenant : choisissez sur quoi.</p>';
  const cibles = [];
  if (s && s.lieu_posable) cibles.push(equipementsBouton('serrurePoser(\'' + item.serrureId + '\',\'lieu\',null)', 'Sur ce local', true));
  if (s && s.batiment_posable) cibles.push(equipementsBouton('serrurePoser(\'' + item.serrureId + '\',\'batiment\',null)', 'Sur l\'entrée du bâtiment'));
  (s ? s.armoires_posables : []).forEach(function (id, i) {
    cibles.push(equipementsBouton('serrurePoser(\'' + item.serrureId + '\',\'armoire\',\'' + id + '\')',
      'Sur l\'armoire à souvenirs' + (s.armoires_posables.length > 1 ? ' ' + (i + 1) : '')));
  });
  h += cibles.length ? '<div style="display:flex;flex-direction:column;gap:.4rem">' + cibles.join('') + '</div>'
    : '<p class="cpj-note">Rien ici ne peut recevoir cette serrure. Elle se pose sur une armoire à souvenirs installée, sur un local ou un appartement dont vous avez la jouissance, ou sur l\'entrée d\'un bâtiment dont vous avez l\'intégralité de la jouissance, en y étant.</p>';
  equipementsModale(titre, h);
}

async function ouvrirCleSerrure(idx) {
  const item = state.inventory[idx];
  const titre = 'Clé n° ' + (item.numero || '');
  equipementsModale(titre, serrureIllustration('ti-key') + '<p class="cpj-note">…</p>');
  const r = await sbRpc('serrure_etat', { p_serrure: item.serrureId }).catch(function () { return null; });
  let h = serrureIllustration('ti-key');
  if (!r || r.ok !== true) h += '<p class="cpj-note">' + equipementsEchapper(equipementsRefus(r)) + '</p>';
  else if (r.statut === 'detruite') h += '<p class="cpj-note">La serrure n° ' + equipementsEchapper(r.numero) + ' a été détruite à la fin du bail : cette clé n\'ouvre plus rien.</p>';
  else if (r.statut === 'neuve') h += '<p class="cpj-note">La serrure n° ' + equipementsEchapper(r.numero) + ' n\'est pas encore posée.</p>';
  else {
    h += '<p>Serrure n° ' + equipementsEchapper(r.numero) + ' — ' +
      (r.cible === 'lieu' ? 'porte de ' + equipementsEchapper(serrureLieuLibelle(r))
        : r.cible === 'batiment' ? 'entrée du bâtiment ' + equipementsEchapper(serrureLieuLibelle(r)) : 'armoire à souvenirs') +
      ' — <strong>' + (r.fermee ? 'fermée à clé' : 'ouverte') + '</strong></p>';
    h += r.a_portee
      ? equipementsBouton('serrureBasculer(\'' + r.serrure + '\',' + (!r.fermee) + ',' + idx + ')', r.fermee ? (r.cible !== 'armoire' ? 'Ouvrir au public' : 'Ouvrir') : 'Fermer à clé', true)
      : '<p class="cpj-note">' + (r.cible !== 'armoire' ? 'Pour la fermer ou l\'ouvrir, soyez dans le bâtiment.' : 'Pour la fermer ou l\'ouvrir, soyez dans la pièce de l\'armoire.') + '</p>';
  }
  h += '<p class="cpj-note">Une clé se donne ou s\'échange comme tout objet : elle ouvre pour qui la détient.</p>';
  equipementsModale(titre, h);
}

function ouvrirDoubleCle(idx) {
  const cles = {};
  (state.inventory || []).forEach(function (o) { if (o && o.type === 'cle_serrure' && o.serrureId) cles[o.serrureId] = o.numero; });
  let h = serrureIllustration('ti-key') + '<p class="cpj-note">Taillée sur une clé que vous détenez, une clé vierge devient un double de cette clé.</p>';
  const ids = Object.keys(cles);
  h += ids.length ? '<div style="display:flex;flex-direction:column;gap:.4rem">' + ids.map(function (id) {
      return equipementsBouton('cleDupliquer(\'' + id + '\')', 'Double de la clé n° ' + cles[id], true); }).join('') + '</div>'
    : '<p class="cpj-note">Vous ne détenez aucune clé à reproduire.</p>';
  equipementsModale('Clé vierge', h);
}

async function cleDupliquer(serrureId) {
  const v = await executerReceptionInventaire('cle_dupliquer', { p_serrure: serrureId }, { surRefus: serrureRefusInventaire });
  if (!v) return;
  if (typeof renderInventory === 'function') renderInventory();
  document.getElementById('modal-postes')?.classList.remove('open');
  showToast('Double taillé', 'Une clé n° ' + (v.numero || '') + ' de plus dans votre inventaire.', true);
}

// L'ordre « Équipements et serrure » dans tout local a louer (hors hotel et clinique), en plus
// des bureaux du centre d'affaires qui le declarent deja : meme fn, donc jamais de doublon.
function ordresSerrureDuLocal(buildingId, roomId) {
  if (!buildingId || !roomId || /hotel|clinique|hopital/i.test(buildingId)) return [];
  const room = (typeof BUILDINGS !== 'undefined' && BUILDINGS[buildingId]?.rooms?.[roomId])
    || (typeof getBuildingContext === 'function' && getBuildingContext(buildingId)?.roomsExtra?.[roomId]);
  // Les batiments construits par les PJ (terrains a batir) en font partie : leur proprietaire y pose
  // la serrure de l'entree (integralite de la jouissance, decision du 04/11).
  if (!room || !(room.isLocationRoom || /^terrain-a-batir-/.test(buildingId))) return [];
  return [{ fn: 'installer_equipements', label: 'Équipements et serrure', pa: 0, cost: 0, type: 'legal', icon: 'ti-lock',
    successRate: 100, desc: 'Installer vos équipements (ordinateur, box, armoire à souvenirs) et poser, fermer ou ouvrir une serrure.' }];
}
if (typeof window !== 'undefined') {
  window.RP_ORDRES_DYNAMIQUES = window.RP_ORDRES_DYNAMIQUES || [];
  if (!window.RP_ORDRES_DYNAMIQUES.includes(ordresSerrureDuLocal)) window.RP_ORDRES_DYNAMIQUES.push(ordresSerrureDuLocal);
}
