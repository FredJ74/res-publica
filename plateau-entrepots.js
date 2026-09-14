// plateau-entrepots.js
// =====================================================================
// TABLEAU DE BORD LOGISTIQUE DU DIRECTEUR D'ENTREPOT (14 septembre 2026)
// =====================================================================
// Le directeur n'avait qu'un seul ecran, « Fixer les prix de vente », qui n'affichait ni sa
// tresorerie, ni la capacite de son entrepot, ni ce qui etait en route. Ce fichier apporte le
// tableau de gestion : tresorerie, stocks et capacite, stocks cibles, marche des fournisseurs
// nationaux et etrangers, commandes fermes et registre de l'etablissement.
//
// AUCUN CALCUL ECONOMIQUE ICI. Les prix, la capacite disponible, le fret et toutes les
// conditions d'une commande sont decides par le serveur (entrepot_commander). Cet ecran ne fait
// qu'afficher ce que la base contient et transmettre une intention.
//
// I18N. Le plateau de jeu n'est pas encore internationalise (i18next n'est charge que par
// index.html). Pour ne pas rendre ce chantier plus difficile plus tard, TOUS les libelles
// visibles de cet ecran sont regroupes dans une seule table a cles pointees, lue a travers
// tEntrepot(). Le jour ou i18next sera charge par plateau.html, il suffira de deplacer cette
// table dans i18n/resources.js sous la meme cle racine `entrepots.` et de supprimer le repli --
// aucun appelant ne changera. Aucune chaine visible n'est ecrite en dur ailleurs dans ce fichier.

const I18N_ENTREPOTS_FR = {
  'entrepots.titre':              "Tableau de bord logistique",
  'entrepots.tresorerie':         "Trésorerie",
  'entrepots.onglet.stocks':      "Stocks et objectifs",
  'entrepots.onglet.marche':      "Marché fournisseurs",
  'entrepots.onglet.registre':    "Registre",
  'entrepots.col.ressource':      "Ressource",
  'entrepots.col.stock':          "Stock",
  'entrepots.col.capacite':       "Capacité restante",
  'entrepots.col.transit':        "En route",
  'entrepots.col.desiderata':     "Objectif",
  'entrepots.col.prixVente':      "Prix de vente",
  'entrepots.col.fournisseur':    "Fournisseur",
  'entrepots.col.origine':        "Origine",
  'entrepots.col.dispo':          "Disponible",
  'entrepots.col.prix':           "Prix",
  'entrepots.col.fret':           "Fret",
  'entrepots.col.rendu':          "Coût rendu",
  'entrepots.col.delai':          "Livraison",
  'entrepots.col.responsable':    "Responsable",
  'entrepots.col.quantite':       "Quantité",
  'entrepots.col.date':           "Date",
  'entrepots.col.operation':      "Opération",
  'entrepots.col.contrepartie':   "Contrepartie",
  'entrepots.col.montant':        "Montant",
  'entrepots.col.statut':         "Statut",
  'entrepots.action.enregistrer': "Enregistrer les objectifs",
  'entrepots.action.commander':   "Commander",
  'entrepots.aide.desiderata':    "Stock cible par ressource, de 0 à 5 000. L'approvisionnement automatique nocturne comble l'écart entre ce chiffre et ce que vous possédez déjà, marchandises en route comprises. 0 signifie : aucun réapprovisionnement automatique de cette ressource — le stock déjà présent n'est ni vendu ni détruit.",
  'entrepots.aide.marche':        "Prix réellement affichés par chaque fournisseur, à l'instant. Rien n'est réservé tant que vous n'avez pas validé : le premier qui commande emporte la marchandise.",
  'entrepots.aide.registre':      "Registre de l'établissement. Il ne vous appartient pas : vos successeurs le liront aussi.",
  'entrepots.blocus.infobulle':   "Commande impossible : un embargo est en vigueur contre ce pays.",
  'entrepots.delai.j1':           "J+1",
  'entrepots.delai.j2':           "J+2",
  'entrepots.origine.port':       "Port industriel",
  'entrepots.origine.national':   "Républia",
  'entrepots.dispo.illimite':     "—",
  'entrepots.vide.marche':        "Aucun fournisseur ne propose cette ressource pour le moment.",
  'entrepots.vide.registre':      "Aucune opération enregistrée pour l'instant.",
  'entrepots.vide.transit':       "—",
  'entrepots.msg.objectifsOk':    "Objectifs enregistrés.",
  'entrepots.msg.commandeOk':     "Commande ferme. Marchandise payée et en route.",
  'entrepots.msg.refus':          "Commande refusée",
  'entrepots.msg.chargement':     "Chargement…",
  'entrepots.refus.embargo':             "Un embargo interdit cette commande.",
  'entrepots.refus.stock':               "Le fournisseur n'a pas cette quantité.",
  'entrepots.refus.tresorerie':          "Trésorerie insuffisante.",
  'entrepots.refus.capacite':            "Votre entrepôt n'a pas la place.",
  'entrepots.refus.quantite':            "Quantité invalide.",
  'entrepots.refus.poste':               "Vous n'êtes pas directeur de cet entrepôt.",
  'entrepots.refus.defaut':              "Opération refusée."
};

// Accesseur unique. Delegue a i18next des qu'il sera disponible sur le plateau ; en attendant,
// sert la table francaise ci-dessus. Jamais de chaine visible ailleurs que via cette fonction.
function tEntrepot(cle, remplacements) {
  let texte;
  if (typeof i18next !== 'undefined' && i18next.isInitialized && i18next.exists(cle)) {
    texte = i18next.t(cle, remplacements);
  } else {
    texte = I18N_ENTREPOTS_FR[cle] || cle;
    if (remplacements) {
      Object.keys(remplacements).forEach(function (k) {
        texte = texte.split('{{' + k + '}}').join(remplacements[k]);
      });
    }
  }
  return texte;
}

const CAPACITE_ENTREPOT = 5000;   // miroir d'affichage de capacite_entrepot() -- le serveur decide
const FRET_UNITAIRE_INTERNATIONAL = 0.40;

// Etat de l'ecran, jamais une source de verite : tout est relu a chaque ouverture et apres
// chaque commande.
let _entrepotTableau = null;

function entrepotIdCourant() {
  const b = (typeof getBuildingIdDirecteurEntrepot === 'function') ? getBuildingIdDirecteurEntrepot() : null;
  const ville = state.poste?.city;
  return (b && ville) ? ('republic_' + ville + '_' + b) : null;
}

function fmtFR(n) {
  return (Math.round((Number(n) || 0) * 100) / 100).toLocaleString('fr-FR');
}

// =====================================================================
// LECTURE DE L'ETAT REEL
// =====================================================================
async function chargerTableauEntrepot() {
  const monId = entrepotIdCourant();
  if (!monId) return null;

  const [etatMoi, transits, journal, etrangers, tousEntrepots, port] = await Promise.all([
    sbGetBatimentEtat(state.country, state.poste.city, getBuildingIdDirecteurEntrepot()).catch(() => null),
    sbGet('entrepot_transits', 'destination_id=eq.' + encodeURIComponent(monId) + '&order=arrivee_le.asc').catch(() => []),
    sbGet('entrepot_journal', 'entrepot_id=eq.' + encodeURIComponent(monId) + '&order=horodatage.desc&limit=40').catch(() => []),
    sbRpc('fournisseurs_etrangers', {}).catch(() => []),
    sbGet('batiments_etat', 'building_id=like.entrepot-logistique-*').catch(() => []),
    sbGetBatimentEtat('republic', 'ville_a', 'port-sainte-marie').catch(() => null)
  ]);

  // Embargos en vigueur, lus une fois pour tout l'ecran.
  const embargos = {};
  for (const pays of ['narco', 'soviet', 'khalija']) {
    embargos[pays] = await sbRpc('embargo_actif', { p_pays_soi: 'republic', p_pays_cible: pays })
      .then(function (r) { return Array.isArray(r) ? r[0] === true : r === true; })
      .catch(function () { return false; });
  }

  return {
    monId: monId,
    entrepot: (etatMoi && etatMoi.entrepot) || { stock: {}, caisse: 0, prixManuel: {}, desiderata: {} },
    transits: transits || [],
    journal: journal || [],
    etrangers: etrangers || [],
    autres: (tousEntrepots || []).filter(function (r) { return r.id !== monId; }),
    port: (port && port.port) || null,
    embargos: embargos
  };
}

// =====================================================================
// OUVERTURE
// =====================================================================
async function ouvrirTableauBordEntrepot() {
  if (state.poste?.id !== 'directeur_entrepot' || state.currentBuilding !== getBuildingIdDirecteurEntrepot()) {
    showToast('Accès refusé', tEntrepot('entrepots.refus.poste'), false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = tEntrepot('entrepots.titre');
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.5rem;text-align:center;color:#8a8060">' + tEntrepot('entrepots.msg.chargement') + '</div>';
  document.getElementById('modal-postes').classList.add('open');

  _entrepotTableau = await chargerTableauEntrepot();
  if (!_entrepotTableau) {
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.5rem;color:#cc5540">' + tEntrepot('entrepots.refus.poste') + '</div>';
    return;
  }
  rendreTableauEntrepot('stocks');
}

function rendreTableauEntrepot(onglet) {
  const d = _entrepotTableau;
  if (!d) return;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  let html = '<div style="padding:1rem">';

  // --- Bandeau tresorerie : la premiere chose que le directeur doit voir ---
  html += '<div style="display:flex;align-items:baseline;justify-content:space-between;gap:1rem;'
       + 'border:1px solid #3a2a10;background:#0f0d05;padding:.7rem 1rem;margin-bottom:.9rem">'
       + '<span style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.12em;color:#8a6a20">'
       + tEntrepot('entrepots.tresorerie') + '</span>'
       + '<span style="font-family:Bebas Neue,sans-serif;font-size:1.5rem;color:#C9A84C">'
       + fmtFR(d.entrepot.caisse || 0) + ' ' + cur + '</span></div>';

  // --- Onglets ---
  const onglets = [['stocks', 'entrepots.onglet.stocks'], ['marche', 'entrepots.onglet.marche'],
                   ['registre', 'entrepots.onglet.registre']];
  html += '<div style="display:flex;gap:.4rem;margin-bottom:.8rem;flex-wrap:wrap">';
  onglets.forEach(function (o) {
    const actif = o[0] === onglet;
    html += '<button onclick="rendreTableauEntrepot(\'' + o[0] + '\')" style="font-family:Bebas Neue,sans-serif;'
         + 'font-size:.76rem;letter-spacing:.1em;padding:.45rem .9rem;cursor:pointer;'
         + 'border:1px solid ' + (actif ? '#8a6a20' : '#2a2010') + ';'
         + 'background:' + (actif ? '#1a1408' : 'transparent') + ';'
         + 'color:' + (actif ? '#C9A84C' : '#8a8060') + '">' + tEntrepot(o[1]) + '</button>';
  });
  html += '</div>';

  if (onglet === 'stocks')   html += vueStocksEntrepot(d, cur);
  if (onglet === 'marche')   html += vueMarcheEntrepot(d, cur);
  if (onglet === 'registre') html += vueRegistreEntrepot(d, cur);

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// =====================================================================
// ONGLET 1 — STOCKS, CAPACITE, TRANSIT, OBJECTIFS
// =====================================================================
function vueStocksEntrepot(d, cur) {
  const stock = d.entrepot.stock || {};
  const desiderata = d.entrepot.desiderata || {};
  const prixManuel = d.entrepot.prixManuel || {};

  // Ce qui est en route, par ressource, avec l'echeance la plus proche.
  const enRoute = {};
  d.transits.forEach(function (t) {
    if (!enRoute[t.ressource]) enRoute[t.ressource] = { qte: 0, eta: t.arrivee_le };
    enRoute[t.ressource].qte += t.quantite;
    if (t.arrivee_le < enRoute[t.ressource].eta) enRoute[t.ressource].eta = t.arrivee_le;
  });

  let html = '<div style="font-size:.84rem;color:#8a8060;font-style:italic;margin-bottom:.7rem;line-height:1.5">'
           + tEntrepot('entrepots.aide.desiderata') + '</div>';
  html += '<div style="overflow-x:auto"><table style="width:100%;font-size:.88rem;border-collapse:collapse">';
  html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.74rem;letter-spacing:.08em;text-align:left">'
       + '<th style="padding:.3rem .4rem .3rem 0">' + tEntrepot('entrepots.col.ressource') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.stock') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.capacite') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.transit') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.desiderata') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.prixVente') + '</th></tr>';

  Object.entries(RESSOURCES_ECONOMIE).forEach(function (paire) {
    const cle = paire[0], res = paire[1];
    const s = stock[cle] || 0;
    const r = enRoute[cle];
    const capacite = Math.max(0, CAPACITE_ENTREPOT - s - (r ? r.qte : 0));
    const prix = (prixManuel[cle] != null) ? prixManuel[cle]
               : (typeof getPrixRessourceEntrepot === 'function' ? getPrixRessourceEntrepot(cle) : res.prixBase);
    html += '<tr style="border-top:1px solid #2a2010">';
    html += '<td style="padding:.45rem .4rem .45rem 0;color:#c0b090"><i class="ti ' + res.icon
         + '" style="margin-right:.35rem;color:#8a6a20"></i>' + res.label + '</td>';
    html += '<td style="text-align:right;color:#f0ead6;font-variant-numeric:tabular-nums">'
         + fmtFR(s) + ' <span style="color:#5a4a30">/ ' + fmtFR(CAPACITE_ENTREPOT) + '</span></td>';
    html += '<td style="text-align:right;color:#8a8060;font-variant-numeric:tabular-nums">' + fmtFR(capacite) + '</td>';
    html += '<td style="text-align:right;font-variant-numeric:tabular-nums">'
         + (r ? '<span style="color:#6a9a4a">+' + fmtFR(r.qte) + '</span> <span style="color:#5a4a30;font-size:.82rem">('
                + r.eta + ')</span>' : '<span style="color:#5a4a30">' + tEntrepot('entrepots.vide.transit') + '</span>') + '</td>';
    html += '<td style="text-align:right"><input type="number" min="0" max="' + CAPACITE_ENTREPOT + '" step="50"'
         + ' id="desiderata-' + cle + '" value="' + (desiderata[cle] != null ? desiderata[cle] : '') + '"'
         + ' placeholder="0" style="width:82px;background:#121005;border:1px solid #2a2010;color:#f0ead6;'
         + 'padding:.3rem;font-size:.86rem;text-align:right" /></td>';
    html += '<td style="text-align:right;color:#8a8060;font-variant-numeric:tabular-nums">' + fmtFR(prix) + ' ' + cur + '</td>';
    html += '</tr>';
  });
  html += '</table></div>';
  html += '<button class="pnj-action-btn" onclick="enregistrerDesiderata()" style="margin-top:1rem">'
       + tEntrepot('entrepots.action.enregistrer') + '</button>';
  return html;
}

async function enregistrerDesiderata() {
  const desiderata = {};
  Object.keys(RESSOURCES_ECONOMIE).forEach(function (cle) {
    const v = document.getElementById('desiderata-' + cle)?.value;
    desiderata[cle] = (v === '' || v == null) ? 0 : Math.floor(Number(v));
  });
  const v = await sbRpc('entrepot_fixer_desiderata',
    { p_acteur: state.char?.name, p_desiderata: desiderata })
    .then(function (rows) { return Array.isArray(rows) ? rows[0] : rows; })
    .catch(function () { return null; });
  if (!v || v.ok !== true) {
    showToast(tEntrepot('entrepots.msg.refus'), messageRefusEntrepot(v && v.raison), false);
    return;
  }
  showToast(tEntrepot('entrepots.msg.objectifsOk'), '', true, true);
  _entrepotTableau = await chargerTableauEntrepot();
  rendreTableauEntrepot('stocks');
}

// =====================================================================
// ONGLET 2 — LE MARCHE DES FOURNISSEURS
// =====================================================================
// Le tableau melange deliberement national et etranger : c'est en les voyant cote a cote, fret
// compris, que le directeur peut arbitrer. Les stocks affiches sont ceux de la base a l'instant
// du chargement -- rien n'est reserve, le premier qui valide emporte la marchandise.
function vueMarcheEntrepot(d, cur) {
  const lignes = [];

  // --- Les autres entrepots de Republia ---
  d.autres.forEach(function (row) {
    let etat; try { etat = JSON.parse(typeof row.data === 'string' ? row.data : JSON.stringify(row.data)); }
    catch (e) { return; }
    const ent = (etat && etat.entrepot) || {};
    const stock = ent.stock || {}, pm = ent.prixManuel || {};
    Object.keys(stock).forEach(function (cle) {
      if (!RESSOURCES_ECONOMIE[cle] || (stock[cle] || 0) <= 0) return;
      lignes.push({
        type: 'entrepot', id: row.id, ressource: cle,
        libelle: nomEtablissementEntrepot(row.building_id),
        origine: tEntrepot('entrepots.origine.national'),
        dispo: stock[cle],
        prix: (pm[cle] != null) ? pm[cle] : RESSOURCES_ECONOMIE[cle].prixBase,
        fret: 0, delai: 'entrepots.delai.j1',
        posteId: 'directeur_entrepot', posteVille: villeEntrepot(row.building_id), bloque: false
      });
    });
  });

  // --- Le Port industriel ---
  if (d.port && d.port.stock) {
    Object.keys(d.port.stock).forEach(function (cle) {
      if (!RESSOURCES_ECONOMIE[cle] || (d.port.stock[cle] || 0) <= 0) return;
      lignes.push({
        type: 'port', id: 'republic_ville_a_port-sainte-marie', ressource: cle,
        libelle: tEntrepot('entrepots.origine.port'),
        origine: tEntrepot('entrepots.origine.national'),
        dispo: d.port.stock[cle],
        prix: RESSOURCES_ECONOMIE[cle].prixBase, fret: 0, delai: 'entrepots.delai.j1',
        posteId: 'commandant_port', posteVille: null, bloque: false
      });
    });
  }

  // --- Les fournisseurs etrangers ---
  (d.etrangers || []).forEach(function (f) {
    if (!RESSOURCES_ECONOMIE[f.ressource]) return;
    lignes.push({
      type: 'etranger', id: f.pays, ressource: f.ressource,
      libelle: f.libelle, origine: f.libelle,
      dispo: null, prix: Number(f.prix_unitaire),
      fret: FRET_UNITAIRE_INTERNATIONAL, delai: 'entrepots.delai.j2',
      posteId: null, posteVille: null, bloque: !!d.embargos[f.pays]
    });
  });

  lignes.sort(function (a, b) {
    return (RESSOURCES_ECONOMIE[a.ressource].label).localeCompare(RESSOURCES_ECONOMIE[b.ressource].label)
        || (a.prix + a.fret) - (b.prix + b.fret);
  });

  let html = '<div style="font-size:.84rem;color:#8a8060;font-style:italic;margin-bottom:.7rem;line-height:1.5">'
           + tEntrepot('entrepots.aide.marche') + '</div>';
  if (lignes.length === 0) return html + '<div style="color:#8a8060;font-style:italic">' + tEntrepot('entrepots.vide.marche') + '</div>';

  html += '<div style="overflow-x:auto"><table style="width:100%;font-size:.86rem;border-collapse:collapse">';
  html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;text-align:left">'
       + '<th style="padding:.3rem .4rem .3rem 0">' + tEntrepot('entrepots.col.ressource') + '</th>'
       + '<th>' + tEntrepot('entrepots.col.fournisseur') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.dispo') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.prix') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.fret') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.rendu') + '</th>'
       + '<th>' + tEntrepot('entrepots.col.delai') + '</th>'
       + '<th>' + tEntrepot('entrepots.col.responsable') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.quantite') + '</th>'
       + '<th></th></tr>';

  lignes.forEach(function (l, i) {
    const res = RESSOURCES_ECONOMIE[l.ressource];
    const rendu = Math.round((l.prix + l.fret) * 100) / 100;
    html += '<tr style="border-top:1px solid #2a2010' + (l.bloque ? ';opacity:.55' : '') + '">';
    html += '<td style="padding:.45rem .4rem .45rem 0;color:#c0b090"><i class="ti ' + res.icon
         + '" style="margin-right:.3rem;color:#8a6a20"></i>' + res.label + '</td>';
    html += '<td style="color:#c0b090">' + l.libelle + '<div style="font-size:.76rem;color:#5a4a30">' + l.origine + '</div></td>';
    html += '<td style="text-align:right;color:#8a8060;font-variant-numeric:tabular-nums">'
         + (l.dispo == null ? tEntrepot('entrepots.dispo.illimite') : fmtFR(l.dispo)) + '</td>';
    html += '<td style="text-align:right;color:#8a8060;font-variant-numeric:tabular-nums">' + fmtFR(l.prix) + '</td>';
    html += '<td style="text-align:right;color:#8a8060;font-variant-numeric:tabular-nums">'
         + (l.fret > 0 ? '+' + fmtFR(l.fret) : '—') + '</td>';
    html += '<td style="text-align:right;color:#C9A84C;font-variant-numeric:tabular-nums">' + fmtFR(rendu) + ' ' + cur + '</td>';
    html += '<td style="color:#8a8060">' + tEntrepot(l.delai) + '</td>';
    html += '<td id="resp-entrepot-' + i + '" style="color:#5a4a30;font-size:.82rem">—</td>';
    html += '<td style="text-align:right"><input type="number" min="1" step="10" id="cmd-qte-' + i + '"'
         + (l.bloque ? ' disabled' : '') + ' style="width:80px;background:#121005;border:1px solid #2a2010;'
         + 'color:#f0ead6;padding:.3rem;font-size:.84rem;text-align:right" /></td>';
    if (l.bloque) {
      html += '<td><span title="' + tEntrepot('entrepots.blocus.infobulle') + '" style="color:#8a6a30;'
           + 'font-size:.8rem;cursor:help;border-bottom:1px dotted #8a6a30">'
           + tEntrepot('entrepots.action.commander') + '</span></td>';
    } else {
      html += '<td><button onclick="commanderDepuisMarche(' + i + ')" style="font-family:Bebas Neue,sans-serif;'
           + 'font-size:.72rem;letter-spacing:.08em;padding:.35rem .7rem;border:1px solid #4a6a4a;'
           + 'background:transparent;color:#6a9a6a;cursor:pointer">' + tEntrepot('entrepots.action.commander') + '</button></td>';
    }
    html += '</tr>';
  });
  html += '</table></div>';

  window._entrepotLignesMarche = lignes;
  // Les responsables sont resolus apres le rendu : getTitulaireActuel est asynchrone et ne doit
  // jamais retarder l'affichage du marche.
  remplirResponsablesMarche(lignes);
  return html;
}

// Reutilise le lookup unique du projet (getTitulaireActuel) et les deux points d'entree deja
// existants pour joindre quelqu'un : composerMailPour() et ouvrirConversationAvec().
async function remplirResponsablesMarche(lignes) {
  for (let i = 0; i < lignes.length; i++) {
    const l = lignes[i];
    if (!l.posteId || typeof getTitulaireActuel !== 'function') continue;
    const t = await getTitulaireActuel(l.posteId, l.posteVille).catch(function () { return null; });
    const el = document.getElementById('resp-entrepot-' + i);
    if (!el || !t) continue;
    el.innerHTML = '<span style="color:#c0b090">' + t.nom + '</span>'
      + ' <button data-nom="' + t.nom + '" onclick="composerMailPour(this.dataset.nom)" title="Mail"'
      + ' style="background:none;border:none;color:#8a6a20;cursor:pointer;padding:0 .2rem"><i class="ti ti-mail"></i></button>'
      + ' <button data-nom="' + t.nom + '" onclick="ouvrirConversationAvec(this.dataset.nom)" title="Chat"'
      + ' style="background:none;border:none;color:#6a9a4a;cursor:pointer;padding:0 .2rem"><i class="ti ti-message-circle"></i></button>';
  }
}

async function commanderDepuisMarche(index) {
  const l = (window._entrepotLignesMarche || [])[index];
  if (!l) return;
  const qte = Math.floor(Number(document.getElementById('cmd-qte-' + index)?.value || 0));
  if (!(qte > 0)) { showToast(tEntrepot('entrepots.msg.refus'), tEntrepot('entrepots.refus.quantite'), false); return; }

  const v = await sbRpc('entrepot_commander', {
    p_acteur: state.char?.name, p_ressource: l.ressource, p_quantite: qte,
    p_fournisseur_type: l.type, p_fournisseur_id: l.id
  }).then(function (rows) { return Array.isArray(rows) ? rows[0] : rows; })
    .catch(function () { return null; });

  if (!v || v.ok !== true) {
    showToast(tEntrepot('entrepots.msg.refus'), messageRefusEntrepot(v && v.raison), false);
    return;
  }
  showToast(tEntrepot('entrepots.msg.commandeOk'),
            fmtFR(v.quantite) + ' × ' + RESSOURCES_ECONOMIE[l.ressource].label
            + ' — ' + fmtFR(v.montant) + ' ' + (COUNTRIES[state.country]?.cur || 'FR'), true, true);
  addJournalEntry('Commande : ' + fmtFR(v.quantite) + ' ' + RESSOURCES_ECONOMIE[l.ressource].label
                  + ' auprès de ' + v.fournisseur + '.', 'event-info');
  _entrepotTableau = await chargerTableauEntrepot();
  rendreTableauEntrepot('marche');
}

function messageRefusEntrepot(raison) {
  const table = {
    embargo: 'entrepots.refus.embargo',
    stock_fournisseur_insuffisant: 'entrepots.refus.stock',
    tresorerie_insuffisante: 'entrepots.refus.tresorerie',
    capacite_insuffisante: 'entrepots.refus.capacite',
    quantite_invalide: 'entrepots.refus.quantite',
    desiderata_invalide: 'entrepots.refus.quantite',
    poste_non_detenu: 'entrepots.refus.poste'
  };
  return tEntrepot(table[raison] || 'entrepots.refus.defaut');
}

// =====================================================================
// ONGLET 3 — LE REGISTRE DE L'ETABLISSEMENT
// =====================================================================
function vueRegistreEntrepot(d, cur) {
  let html = '<div style="font-size:.84rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">'
           + tEntrepot('entrepots.aide.registre') + '</div>';
  if (!d.journal.length) return html + '<div style="color:#8a8060;font-style:italic">' + tEntrepot('entrepots.vide.registre') + '</div>';

  html += '<div style="overflow-x:auto"><table style="width:100%;font-size:.84rem;border-collapse:collapse">';
  html += '<tr style="color:#8a6a20;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;text-align:left">'
       + '<th style="padding:.3rem .4rem .3rem 0">' + tEntrepot('entrepots.col.date') + '</th>'
       + '<th>' + tEntrepot('entrepots.col.operation') + '</th>'
       + '<th>' + tEntrepot('entrepots.col.contrepartie') + '</th>'
       + '<th>' + tEntrepot('entrepots.col.ressource') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.quantite') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.prix') + '</th>'
       + '<th style="text-align:right">' + tEntrepot('entrepots.col.montant') + '</th>'
       + '<th>' + tEntrepot('entrepots.col.statut') + '</th></tr>';

  d.journal.forEach(function (o) {
    const res = RESSOURCES_ECONOMIE[o.ressource];
    const entree = o.sens === 'entree';
    html += '<tr style="border-top:1px solid #2a2010">';
    html += '<td style="padding:.4rem .4rem .4rem 0;color:#5a4a30;white-space:nowrap">' + (o.jour || '') + '</td>';
    html += '<td style="color:' + (entree ? '#6a9a4a' : '#b08a4a') + '">' + (o.operation || '') + '</td>';
    html += '<td style="color:#8a8060">' + (o.contrepartie || '—') + '</td>';
    html += '<td style="color:#c0b090">' + (res ? res.label : (o.ressource || '—')) + '</td>';
    html += '<td style="text-align:right;font-variant-numeric:tabular-nums;color:' + (entree ? '#6a9a4a' : '#b08a4a') + '">'
         + (entree ? '+' : '−') + fmtFR(o.quantite) + '</td>';
    html += '<td style="text-align:right;color:#8a8060;font-variant-numeric:tabular-nums">' + fmtFR(o.prix_unitaire)
         + (Number(o.fret_unitaire) > 0 ? ' <span style="color:#5a4a30">+' + fmtFR(o.fret_unitaire) + '</span>' : '') + '</td>';
    html += '<td style="text-align:right;color:#C9A84C;font-variant-numeric:tabular-nums">' + fmtFR(o.montant) + '</td>';
    html += '<td style="color:#8a8060;font-size:.8rem">' + (o.statut || '')
         + (o.arrivee_le ? ' <span style="color:#5a4a30">(' + o.arrivee_le + ')</span>' : '') + '</td>';
    html += '</tr>';
  });
  html += '</table></div>';
  return html;
}

// =====================================================================
// PETITS RESOLVEURS D'AFFICHAGE
// =====================================================================
// Source unique deja utilisee par la navigation (BATIMENTS_DIRECTEUR, plateau-navigation.js) :
// on ne recopie pas une sixieme enumeration des entrepots.
const ENTREPOT_VILLE_PAR_BATIMENT = {
  'entrepot-logistique-luthecia': 'capitale',
  'entrepot-logistique-psm': 'ville_a',
  'entrepot-logistique-montrouge': 'ville_b'
};

function villeEntrepot(buildingId) { return ENTREPOT_VILLE_PAR_BATIMENT[buildingId] || null; }

function nomEtablissementEntrepot(buildingId) {
  const b = (typeof BUILDINGS !== 'undefined') ? BUILDINGS[buildingId] : null;
  if (b && b.shortName) return b.shortName;
  if (b && b.name) return b.name;
  return buildingId;
}
