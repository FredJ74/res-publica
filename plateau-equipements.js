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
   de fret vers le port industriel de PSM. Le chef autorise ses traders.

   TOUT EST DECIDE PAR LE SERVEUR : emplacements (2 en version gratuite),
   jouissance, connexion, prix, stock, caisse, PA. Cet ecran n'affiche que ses
   reponses et n'ecrit rien lui-meme.
   =========================================================================== */

const EQUIPEMENTS_LIBELLES = { 'ordinateur-complet': 'Ordinateur', 'box-internet': 'Box internet' };
const TRADING_VILLES = { capitale: 'Luthécia', ville_a: 'Port-Sainte-Marie', ville_b: 'Montrouge' };
const EQUIPEMENTS_REFUS = {
  acteur_non_authentifie: 'Votre personnage n\'est pas identifié.',
  pas_dans_un_local: 'Il faut être dans un local.',
  pas_de_jouissance: 'Vous n\'avez pas la jouissance légale de ce local (bail à votre nom ou à celui de votre organisation).',
  emplacements_pleins: 'Les deux emplacements de ce bureau sont occupés.',
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
  stock_insuffisant: 'L\'entrepôt n\'a pas autant en stock.',
  caisse_organisation_insuffisante: 'La caisse de l\'organisation ne suffit pas.',
  entrepot_inconnu: 'Entrepôt inconnu.',
  pas_chef: 'Seul le chef de l\'organisation peut autoriser un trader.',
  pas_membre: 'Cette personne n\'est pas membre de l\'organisation.'
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
  equipementsModale('Équipements du bureau', '<p class="cpj-note">…</p>');
  const r = await sbRpc('equipements_local_lire', {}).catch(function () { return null; });
  if (!r || r.ok !== true) { equipementsModale('Équipements du bureau', '<p class="cpj-note">' + equipementsEchapper(equipementsRefus(r)) + '</p>'); return; }

  let h = '<p class="cpj-note">' + r.emplacements + ' emplacements d\'équipement dans ce bureau.' +
    (r.jouissance ? '' : ' Vous n\'en avez pas la jouissance légale : vous ne pouvez rien y installer.') + '</p>';

  h += '<div class="cpj-titre">Installés</div>';
  if (!r.installes.length) h += '<p class="cpj-note">Aucun équipement.</p>';
  r.installes.forEach(function (e) {
    h += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.6rem;margin:.3rem 0">' +
      '<span>' + equipementsEchapper(EQUIPEMENTS_LIBELLES[e.generique_id] || e.nom) +
      (e.a_moi ? '' : ' <span class="cpj-note">(à ' + equipementsEchapper(e.proprietaire) + ')</span>') + '</span>' +
      (e.a_moi ? equipementsBouton('equipementDesinstaller(\'' + e.id + '\')', 'Désinstaller') : '') + '</div>';
  });

  if (r.jouissance && r.installables.length) {
    h += '<div class="cpj-titre">Dans votre inventaire</div>';
    r.installables.forEach(function (g) {
      h += '<div style="display:flex;justify-content:space-between;align-items:center;gap:.6rem;margin:.3rem 0">' +
        '<span>' + equipementsEchapper(EQUIPEMENTS_LIBELLES[g] || g) + '</span>' +
        equipementsBouton('equipementInstaller(\'' + g + '\')', 'Installer', true) + '</div>';
    });
  }

  h += '<div class="cpj-titre">Connexion internet</div>';
  h += r.connexion
    ? '<p class="cpj-note">Votre ordinateur et votre box sont installés : vous êtes connecté.</p>' +
      equipementsBouton('ouvrirTrading()', 'Trading de matières premières', true)
    : '<p class="cpj-note">Installez ici votre ordinateur et votre box internet pour vous connecter.</p>';
  equipementsModale('Équipements du bureau', h);
}

async function equipementInstaller(generique) {
  const r = await sbRpc('equipement_installer', { p_generique: generique }).catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  if (typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(r);
  if (typeof renderInventory === 'function') renderInventory();
  showToast('Équipement installé', EQUIPEMENTS_LIBELLES[generique] || generique, true);
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

  let h = '<p class="cpj-note">Cours des matières dans les entrepôts. À distance, on ne peut qu\'acheter : ' +
    'la marchandise part en caisse de fret vers le port industriel de Port-Sainte-Marie, où vous la retirerez. ' +
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

  r.entrepots.forEach(function (e) {
    h += '<div class="cpj-titre">Entrepôt — ' + equipementsEchapper(TRADING_VILLES[e.ville] || e.ville) + '</div>';
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
  const r = await sbRpc('trading_acheter', { p_organisation: orga, p_entrepot: entrepot, p_ressource: ressource, p_quantite: q })
    .catch(function () { return null; });
  if (!r || r.ok !== true) { showToast('Refusé', equipementsRefus(r), false); return; }
  if (typeof r.pa === 'number' && typeof state !== 'undefined') { state.pa = r.pa; if (typeof updateUI === 'function') updateUI(); }
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';
  showToast('Commande passée', r.quantite + ' × ' + r.ressource + ' pour ' + r.montant + ' ' + cur +
    ' (' + r.organisation + '). Caisse de fret en route vers le port de Port-Sainte-Marie.', true, true);
  if (typeof addJournalEntry === 'function') {
    addJournalEntry('Trading : ' + r.quantite + ' ' + r.ressource + ' achetés ' + r.montant + ' ' + cur +
      ' pour ' + r.organisation + '. Caisse de fret en route vers le port industriel de Port-Sainte-Marie.', 'event-good');
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
