// =====================
// PLATEAU-COMMUNICATION.JS
// Mail, notifications, repertoire, tracts, forum, finances
// =====================

// =====================
// NOTIFICATIONS MAILS
// =====================
async function verifierNouveauxMails() {
  if (typeof sbGetMailsFor !== 'function') return;
  const nom = state.char?.name;
  if (!nom) return;
  // AUDIENCES D'AMBASSADE (24 octobre 2026) : tant qu'une demande attend sa reponse, la
  // verification des mails demande d'abord au serveur de constater les echeances -- c'est ce
  // constat qui depose le mail « audience accordee ». Aucun appel de plus sans demande en cours.
  if (state.audiencesEnAttente && typeof rafraichirAudiencesAmbassade === 'function') {
    await rafraichirAudiencesAmbassade().catch(() => null);
  }
  const personnage = state.char;
  try {
    const mails = await sbGetMailsFor(nom);
    if (state.char !== personnage || state.char?.name !== nom) return;
    // Lecture refusee ou en panne : les voyants gardent leur etat, jamais un faux « 0 ».
    if (!Array.isArray(mails)) return;
    // UNE SEULE SOURCE POUR TOUS LES VOYANTS (25 octobre 2026). Ce que le serveur vient de rendre
    // est d'abord recopie dans le cache local, celui que lisent la barre laterale et les
    // rubriques de la messagerie. Le voyant du bouton, celui de « Boite Mail » et celui de
    // « Mails recus » comptent alors la meme chose, au meme instant, avec la meme definition
    // (mailsRecusVisibles : recus, non archives). Avant, le bouton comptait cote serveur, archives
    // comprises, et les rubriques attendaient l'ouverture de la messagerie pour se mettre a jour.
    const cacheEcrit = (mails && typeof fusionnerMailsServeur === 'function') ? fusionnerMailsServeur(mails) : false;
    if (cacheEcrit && typeof rafraichirVoyantMailLocal === 'function') {
      rafraichirVoyantMailLocal();
      if (typeof rafraichirVoyantsEtCompteursForum === 'function') rafraichirVoyantsEtCompteursForum();
      return;
    }
    // Repli si le cache local ne peut pas etre ecrit (quota du navigateur) : le bouton garde au
    // moins le compte du serveur, avec la meme definition que les rubriques.
    const nonLus = (mails || []).filter(m => !m.read && !m.archived && m.to_player === nom).length;
    const badge = document.getElementById('mail-badge');
    if (badge) {
      if (nonLus > 0) {
        badge.textContent = nonLus;
        badge.style.display = 'inline';
      } else {
        badge.style.display = 'none';
      }
    }
    document.title = nonLus > 0 ? '(' + nonLus + ') Res Publica' : 'Res Publica';
  } catch(e) {}
}


// RÉPERTOIRE PJ
// =====================
async function ouvrirRepertoirePJ() {
  document.getElementById('postes-modal-title').textContent = 'Répertoire des Joueurs';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const myName = state.char?.name || '';
  const empireColors = { republic:'#C9A84C', narco:'#d4862a', soviet:'#9a2020', khalija:'#20a090' };
  const empireNames  = { republic:'Républia', narco:'El Estado', soviet:'Sovarka', khalija:'Al-Khalija' };

  // Charger depuis Supabase
  let joueurs = [];
  if (typeof sbListPersonnages === 'function') {
    try { joueurs = await sbListPersonnages() || []; } catch(e) {}
  }

  // Ajouter soi-même si pas dans la liste
  if (myName && !joueurs.find(j => j.name === myName)) {
    joueurs.unshift({ name: myName, country: state.country, current_city: state.currentCity, poste: state.poste, domicile: state.domicile });
  }

  if (joueurs.length === 0) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#9a8a68;font-style:italic">Aucun joueur enregistre pour l\'instant.</div>';
    return;
  }

  // Grouper par empire
  const byEmpire = {};
  joueurs.forEach(j => {
    if (!byEmpire[j.country]) byEmpire[j.country] = [];
    byEmpire[j.country].push(j);
  });

  const html = Object.entries(byEmpire).map(([country, pjs]) => {
    const col = empireColors[country] || '#C9A84C';
    const empName = empireNames[country] || country;
    return `
      <div style="padding:.4rem 1rem;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:${col};border-bottom:1px solid #2a2010;margin-top:.3rem">
        ${empName} — ${pjs.length} joueur(s)
      </div>
      ${pjs.map(j => {
        const isMe = j.name === myName;
        const posteLabel = j.poste?.name || '';
        const villeDomicileId = j.domicile?.city;
        const villeDomicileNom = villeDomicileId ? (WORLD[j.country]?.[villeDomicileId]?.name || villeDomicileId) : null;
        return `
          <div style="display:flex;align-items:center;gap:.8rem;padding:.5rem 1rem;border-bottom:1px solid #1a1810;${isMe ? 'background:rgba(201,168,76,0.05)' : ''}">
            <div style="width:32px;height:32px;border-radius:50%;border:1px solid ${isMe ? col : '#2a2010'};background:#0a0a07;display:flex;align-items:center;justify-content:center;flex-shrink:0">
              <i class="ti ti-user" style="font-size:.75rem;color:${isMe ? col : '#4a4030'}"></i>
            </div>
            <div style="flex:1">
              <div style="font-size:.82rem;color:${isMe ? col : '#f0ead6'};font-weight:${isMe ? 'bold' : 'normal'}">
                ${j.name}${isMe ? ' ✦' : ''}
              </div>
              <div style="font-size:.68rem;color:#6a5a30">
                ${posteLabel ? posteLabel + ' · ' : ''}${empName}${villeDomicileNom ? ' · Domicile : ' + villeDomicileNom : ''}
              </div>
            </div>
            ${!isMe ? `<button onclick="composerMailPour(this.dataset.name)" data-name="${j.name}" style="font-family:Bebas Neue,sans-serif;font-size:.82rem;letter-spacing:.06em;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">
              <i class="ti ti-mail" style="font-size:.85rem"></i>
            </button>` : ''}
          </div>`;
      }).join('')}
    `;
  }).join('');

  document.getElementById('postes-body').innerHTML = html;
}

function composerMailPour(destinataire) {
  // Fermer les autres modaux
  document.getElementById('modal-postes').classList.remove('open');
  // Ouvrir le modal de composition indépendant
  document.getElementById('compose-mail-to').value = destinataire || '';
  document.getElementById('compose-mail-subject').value = '';
  document.getElementById('compose-mail-body').value = '';
  document.getElementById('modal-compose-mail').classList.add('open');
}

function fermerComposeMail() {
  document.getElementById('modal-compose-mail').classList.remove('open');
}

async function envoyerComposeMail() {
  // AUCUN COURRIER SOUS UNE IDENTITE DE REPLI (24 septembre 2026). Le repli « Anonyme » quelques
  // lignes plus bas a deja produit, en production, un message recu par un ministre et signe d'un
  // expediteur qui n'existe pas. Un courrier engage son expediteur : sans personnage charge, il
  // n'y a personne pour l'engager.
  if (!state.char?.name) {
    showToast('Personnage non chargé',
      "Votre personnage n'est pas chargé : rechargez la page avant d'envoyer un message.", false);
    return;
  }
  const to = document.getElementById('compose-mail-to').value.trim();
  const subject = document.getElementById('compose-mail-subject').value.trim();
  const body = document.getElementById('compose-mail-body').value.trim();
  if (!to || !subject || !body) {
    showToast('Champs requis', 'Remplissez tous les champs.', false);
    return;
  }
  if (typeof sendMail === 'function') {
    await sendMail(to, subject, body);
  } else {
    // Fallback direct Supabase
    const from = state.char?.name || 'Anonyme';
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1);
    if (typeof sbSendMail === 'function') await sbSendMail(from, to, subject, body, time);
    addJournalEntry('Mail envoyé à ' + to + ' : "' + subject + '".', 'event-info');
    showToast('Mail envoyé', 'À ' + to + ' — "' + subject + '"', true);
  }
  fermerComposeMail();
}

// =====================
// TRACTS
// =====================
// A La Tribune (Luthecia), Gustave Rotative a son propre stock de bois (9 aout 2026) : imprimer
// des tracts y consomme du bois en plus de l'argent du joueur, avec une recette dynamique qui
// preserve toujours 50% de marge sur le prix du lot (voir confirmerImpression). A PSM (Gutenberg,
// imprimerie-librairie), l'ordre reste inchange : argent uniquement, pas de bois.

// Responsable de l'atelier reellement present dans la piece courante (11 septembre 2026). Meme
// resolution que l'affichage des personnages (plateau-navigation.js) : personnages du roomOverride,
// sinon ceux du buildingContext pour la premiere piece, sinon ceux du gabarit. Le gabarit
// 'la-tribune' est partage par 15 journaux des 4 pays : « Gustave » n'est cite que la ou un
// imprimeur de ce nom figure vraiment. null si aucun imprimeur n'est present -- texte neutre alors,
// jamais un PNJ invente.
function nomImprimeurLocal() {
  const b = typeof BUILDINGS !== 'undefined' ? BUILDINGS[state.currentBuilding] : null;
  if (!b) return null;
  const roomId = state.currentRoom;
  const ctx = typeof getBuildingContext === 'function' ? getBuildingContext(state.currentBuilding) : null;
  const premiere = Object.keys(b.rooms || {})[0] === roomId;
  const surcharge = ctx?.roomOverrides?.[roomId]?.persons;
  const persons = surcharge?.length > 0 ? surcharge
    : ((premiere && ctx?.persons?.length > 0) ? ctx.persons : (b.rooms?.[roomId]?.persons || []));
  const p = persons.find(x => x && (x.job === 'imprimeur' || /imprim/i.test(x.role || '')));
  return p ? String(p.name).replace(/\s*\(PNJ\)\s*$/, '') : null;
}

// Entree unique « Imprimer des tracts » (fusion ergonomique du 11 septembre 2026, L'Autruche
// Entravee). Aucune mecanique propre : chaque type relance doOrder avec l'ordre D'ORIGINE -- meme
// fn, memes PA/cout/type/taux que son ancien bouton -- donc memes gardes (PA, fonds, blocus,
// quetes) et meme handler. Tracts ordinaires (confirmerImpression) et calomnieux
// (confirmerImprimerTractsCalomnieux) gardent chacun leurs couts, stocks et risques.
// Les choix sont declares sur l'ordre dans data.js : {fn} seul = definition du gabarit du batiment.
function ouvrirChoixImprimerTracts() {
  const b = BUILDINGS[state.currentBuilding];
  const ctx = typeof getBuildingContext === 'function' ? getBuildingContext(state.currentBuilding) : null;
  const entree = (ctx?.roomOverrides?.[state.currentRoom]?.orders || []).find(o => o.fn === 'imprimer_tracts_choix');
  const gabarit = b?.rooms?.[state.currentRoom]?.orders || [];
  const choix = (entree?.choix || [])
    .map(c => (c.label ? c : gabarit.find(o => o.fn === c.fn)))
    .filter(Boolean);
  window._choixImprimerTracts = choix;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  document.getElementById('postes-modal-title').textContent = 'Imprimer des tracts';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Quel type de tracts voulez-vous produire ?</div>';
  choix.forEach((o, i) => {
    const illegal = o.type === 'illegal';
    const cout = [o.pa ? o.pa + ' PA' : '', o.cost ? o.cost.toLocaleString('fr-FR') + ' ' + cur + ' par lot de 10' : ''].filter(Boolean).join(' + ');
    html += '<div onclick="choisirTypeImprimerTracts(' + i + ')" style="padding:.6rem .8rem;border:1px solid ' + (illegal ? '#5a2020' : '#2a2010') + ';background:#0f0d05;margin-bottom:.5rem;cursor:pointer" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">'
      + '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.08em;color:' + (illegal ? '#cc4444' : '#C9A84C') + '"><i class="ti ' + o.icon + '"></i> ' + o.label + (illegal ? ' — illégal' : '') + '</div>'
      + (cout ? '<div style="font-size:.74rem;color:#a89870;margin-top:.2rem">' + cout + '</div>' : '')
      + (o.desc ? '<div style="font-size:.72rem;color:#8a8060;font-style:italic;margin-top:.2rem">' + o.desc + '</div>' : '')
      + '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function choisirTypeImprimerTracts(i) {
  const o = (window._choixImprimerTracts || [])[i];
  if (!o) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  // Exactement l'appel que produisait le bouton d'origine (plateau-politique.js, rendu des ordres).
  doOrder(o.fn, o.pa, o.cost, o.label.replace(/'/g, ' '), (o.desc || '').replace(/'/g, ' '), o.successRate || 70);
}

// Prix d'un lot de 10 tracts, identique pour les tracts ordinaires et calomnieux (arbitrage du 11
// septembre 2026). Seule source du tarif cote code ; data.js l'affiche (cost:150).
const PRIX_LOT_TRACTS = 150;

// MOTEUR UNIQUE D'IMPRESSION DE TRACTS ELECTORAUX (12 septembre 2026, harmonisation des trois
// imprimeries de Republia). Il remplace l'ancien couple ouvrirModalImprimerTracts/confirmerImpression
// propre a la-tribune (Luthecia, Montrouge) : les deux services etaient le MEME service, avec deux
// moteurs, deux libelles, deux couts en PA et deux sources de matiere. Socle commun desormais
// applique a L'Autruche Entravee (Luthecia), au Cheminot Informe (Montrouge) et a l'Imprimerie-
// Librairie Gutenberg (Port-Sainte-Marie) :
//   - POUR ou CONTRE n'importe quel personnage (depuis le 16 septembre 2026 : voir
//     listerCiblesTractsElectoraux, la candidature n'est plus exigee a l'impression) ;
//   - lots de 10 ; 1 PA par commande ; prixLotTractsAtelier() par lot (tarif public : 150 FR) ;
//   - BOIS_PAR_LOT_TRACTS par lot, pris dans le stock PERSONNEL du joueur ;
//   - fonds ordinaires reels (liquide puis Banque nationale) verifies AVANT toute production ;
//   - la caisse de l'imprimerie OU L'ON SE TROUVE recoit exactement la somme debitee.
// selectTractType (ci-dessous) est conserve tel quel : c'est le meme selecteur POUR/CONTRE.
function selectTractType(type) {
  window._tractType = type;
  const btnPour = document.getElementById('tract-type-pour');
  const btnContre = document.getElementById('tract-type-contre');
  if (!btnPour || !btnContre) return;
  if (type === 'pour') {
    btnPour.style.cssText = 'flex:1;padding:.4rem;border:1px solid #4a8a4a;background:#0a1808;color:#6a9a6a;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
    btnContre.style.cssText = 'flex:1;padding:.4rem;border:1px solid #2a2010;background:#0f0d05;color:#5a5040;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
  } else {
    btnPour.style.cssText = 'flex:1;padding:.4rem;border:1px solid #2a2010;background:#0f0d05;color:#5a5040;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
    btnContre.style.cssText = 'flex:1;padding:.4rem;border:1px solid #8a2020;background:#1a0808;color:#9a4a4a;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
  }
}

// MATIERE PREMIERE DES IMPRIMERIES (regle validee le 12 septembre 2026) : un lot de 10 tracts
// consomme 1 unite de bois pris dans le STOCK INSTITUTIONNEL de l'imprimerie ou l'on imprime
// (batiments_etat, imprimerie.stockBois), jamais dans l'inventaire personnel du joueur. La boucle
// est fermee : un PJ vend son bois a l'imprimerie (« Vendre des matieres premieres »), ce bois entre
// dans le stock de l'atelier, et l'impression le consomme. Les tracts electoraux et les tracts
// calomnieux partagent exactement la meme matiere.
const BOIS_PAR_LOT_TRACTS = 1;
const TRACTS_PAR_LOT = 10;

// Capacite de stockage d'une imprimerie tenue par un PNJ. Ce n'est PAS une constante de game design
// definitive : quand les imprimeries appartiendront a des PJ, cette limite sera reglee par la future
// interface commune de gestion des commerces.
const STOCK_BOIS_MAX_IMPRIMERIE_PNJ = 10;

// MAIN-D'OEUVRE (regle validee le 12 septembre 2026) : chaque tranche de 10 tracts coute 1 PA au
// personnage qui produit, et l'imprimerie le remunere 50 FR pour ce PA de travail. La caisse
// encaisse donc 150 FR de recette et verse 50 FR de salaire par lot, soit +100 FR net.
const SALAIRE_LOT_TRACTS = 50;

// L'atelier ou l'on se trouve. Le meme buildingId ('la-tribune') existe dans plusieurs villes : la
// cle est donc toujours pays + ville + batiment, jamais le seul batiment.
function atelierImprimerieCourant() {
  return {
    pays: state.country,
    ville: state.currentCity || 'capitale',
    building: state.currentBuilding || 'la-tribune'
  };
}

async function stockBoisAtelier() {
  if (typeof sbGetBatimentEtat !== 'function') return 0;
  const a = atelierImprimerieCourant();
  const etat = await sbGetBatimentEtat(a.pays, a.ville, a.building).catch(() => null);
  return etat?.imprimerie?.stockBois || 0;
}

// Reserve (nbLots < 0) ou rend (nbLots > 0) du bois de l'atelier, de facon atomique : la lecture, le
// controle et l'ecriture ont lieu dans une seule instruction SQL sous verrou de ligne. Deux
// commandes simultanees ne peuvent donc pas consommer le meme bois.
async function mouvementBoisAtelier(deltaBois) {
  if (typeof sbBatimentMouvementCaisse !== 'function') return null;
  const a = atelierImprimerieCourant();
  return await sbBatimentMouvementCaisse(a.pays, a.ville, a.building, 'imprimerie', 0, 'stockBois', deltaBois)
    .catch(() => null);
}

// Nombre de lots de 10 tracts realisables ici, et ce qui l'y limite. Trois bornes, exactement
// celles que imprimerie_produire_tracts revalidera cote serveur : le bois du stock de l'atelier
// (1 par lot), les PA du producteur (1 par lot) et ses fonds ordinaires (prixLotTractsAtelier()
// par lot). Le detail sert a dire au joueur POURQUOI il ne peut pas commander davantage, plutot
// que de lui proposer une quantite que le serveur refusera.
function capaciteImpressionTracts(stockBois) {
  const prixLot = prixLotTractsAtelier();
  const enTest = (typeof TEST_MODE !== 'undefined' && TEST_MODE);
  const parBois = Math.floor((stockBois || 0) / BOIS_PAR_LOT_TRACTS);
  const parPa = enTest ? parBois : Math.floor(state.pa || 0);
  const fonds = (typeof getFondsDisponiblesOrdinaires === 'function')
    ? getFondsDisponiblesOrdinaires() : (state.arg || 0);
  const parFonds = enTest ? parBois : Math.floor(fonds / prixLot);
  return { lots: Math.max(0, Math.min(parBois, parPa, parFonds)), parBois, parPa, parFonds, fonds, prixLot };
}

// Production d'un ou plusieurs lots, commune aux tracts electoraux et calomnieux. Chaque lot de 10 :
// 150 FR payes par le client, 1 bois pris au stock de l'imprimerie, 1 PA de travail du producteur,
// 50 FR de salaire verses a ce producteur. La caisse de l'imprimerie encaisse la recette et verse le
// salaire dans UN SEUL mouvement atomique (+100 FR net par lot), qui porte aussi la sortie de bois.
// Ordre strict : controles -> reservation du bois -> debit client -> mouvement de caisse -> salaire.
// Renvoie null (et n'a rien consomme) si la commande est refusee ; le message a deja ete affiche.
// TRACTS PRODUITS ET DEPOSES PAR LE SERVEUR (27 octobre 2026, chantier inventaire) :
// tracts_imprimer encaisse la production (comme imprimerie_produire_tracts) et depose le lot dans
// l'inventaire avec les regles d'empilement de l'ecran ; pour un tract calomnieux, il tire aussi la
// detection. Rend le resultat de production enrichi, ou null apres avoir prevenu le joueur.
async function imprimerTractsServeur(nbLots, cible, sens, calomnieux) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const a = atelierImprimerieCourant();
  const r = await sbRpc('tracts_imprimer', {
    p_pays: a.pays, p_ville: a.ville, p_batiment: a.building, p_lots: nbLots,
    p_cible: cible, p_sens: sens, p_calomnieux: !!calomnieux
  }).then(function (rows) { return Array.isArray(rows) ? rows[0] : rows; }).catch(function () { return null; });
  if (!r || r.ok !== true) {
    const raison = (r && r.raison) || 'indisponible';
    if (raison === 'bois_insuffisant') {
      showToast('Stock de bois insuffisant', messageStockBoisInsuffisant(nbLots * BOIS_PAR_LOT_TRACTS, Number(r.stock || 0)), false);
    } else if (raison === 'pa_insuffisants') {
      showToast('PA insuffisants', 'Il faut ' + (r.requis || nbLots) + ' PA pour produire ' + (nbLots * 10) + ' tracts (1 PA par lot de 10).', false);
    } else if (raison === 'fonds_insuffisants') {
      showToast('Fonds insuffisants', 'Il vous faut ' + (r.cout || '') + ' ' + cur, false);
    } else if (raison === 'atelier_introuvable') {
      showToast('Atelier introuvable', 'Ces tracts ne s\'impriment que dans un atelier d\'imprimerie.', false);
    } else {
      showToast('Commande impossible', '', false);
    }
    return null;
  }
  state.pa = r.pa; state.arg = r.arg; state.liquide = r.liquide;
  if (state.char) state.char.arg = state.arg;
  if (Array.isArray(r.inventory) && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(r);
  if (typeof adopterDetectionServeur === 'function') adopterDetectionServeur(r, 'imprimer_tracts_calomnieux');
  if (typeof updateUI === 'function') updateUI();
  return { cout: Number(r.cout), montantDebite: Number(r.cout), salaire: Number(r.salaire),
           paConsommes: r.paConsommes, bois: Number(r.bois), quantite: r.quantite };
}

// produireLotsTracts SUPPRIMEE (27/10/2026) : remplacee par imprimerTractsServeur ci-dessus.

function messageStockBoisInsuffisant(nbLots, dispo) {
  return 'L\'imprimerie n\'a que ' + dispo + ' bois en stock, il en faut ' + nbLots
    + ' pour ' + (nbLots * 10) + ' tracts. Vendez-lui des matières premières.';
}

// --- Tracts electoraux : moteur unique des trois imprimeries ---
// CIBLE (regle du 16 septembre 2026) : N'IMPORTE QUEL PERSONNAGE -- candidat ou non, campagne
// ouverte ou non, SOI-MEME COMPRIS. L'ancienne restriction aux candidats « reellement en
// campagne » (listerCandidatsElectorauxActifs) fermait l'imprimerie hors des phases de campagne :
// un joueur ayant depose sa candidature pendant la phase « candidatures » ne pouvait imprimer
// aucun tract, pas meme pour lui-meme, et lisait « Aucun candidat en campagne actuellement ».
// La contrainte electorale n'est pas supprimee, elle reste LA OU ELLE A TOUJOURS ETE UTILE, a la
// DISTRIBUTION : scrutinsDistribuablesPourTract (plateau-politique.js) n'ouvre un scrutin que si
// la cible y est inscrite, et le serveur refuse 'candidat_hors_scrutin'. Un tract imprime trop tot
// n'est donc jamais perdu ni distribuable a tort : il devient utilisable des que sa cible se
// presente. Corollaire assume : le lot n'est plus epingle a un scrutin (electionPosteId /
// electionCity), puisqu'a l'impression ce scrutin peut ne pas exister -- ces deux champs restent
// lus pour les lots HISTORIQUES, qui gardent leur restriction (test conditionnel deja en place).
// POUR (+1 voix) ou CONTRE (-1 voix, plancher 0) : inchange, les deux sens sont traites par le
// moteur serveur des tracts (migration_tracts_electoraux_pnj.sql), qui les accepte tous deux.
//
// Source des cibles : l'annuaire des joueurs (sbListPersonnages, exactement la meme source que les
// tracts calomnieux et ouvrirAnnuaireJoueurs), UNION les candidats deja declares dans les cycles.
// Cette union n'est pas decorative : elle preserve les cibles PNJ, qui ne figurent dans aucun
// annuaire de PJ et etaient ciblables avant ce lot -- sans elle, ce chantier supprimerait une
// possibilite existante.
async function listerCiblesTractsElectoraux() {
  const parNom = new Map();
  const ajouter = (nom, extra) => {
    if (!nom) return;
    const cle = String(nom);
    const e = parNom.get(cle) || { nom: cle, country: null, enCampagne: false };
    if (extra && extra.country && !e.country) e.country = extra.country;
    if (extra && extra.enCampagne) e.enCampagne = true;
    parNom.set(cle, e);
  };
  if (typeof sbListPersonnages === 'function') {
    try { ((await sbListPersonnages()) || []).forEach(j => ajouter(j.name, { country: j.country || null })); }
    catch (e) { /* annuaire injoignable : repli sur le repertoire, ci-dessous */ }
  }
  if (parNom.size === 0) (state.contacts || []).forEach(c => ajouter(c && c.name));
  // Soi-meme : explicitement ciblable (on imprime d'abord pour sa propre campagne). Ajoute meme si
  // l'annuaire l'omet ou est injoignable.
  ajouter(state.char && state.char.name, { country: state.country });
  // Candidats declares, TOUTES PHASES CONFONDUES (y compris « candidatures ») et PJ comme PNJ.
  const cycles = (typeof CYCLES_ELECTORAUX !== 'undefined' && CYCLES_ELECTORAUX[state.country]) || {};
  Object.keys(cycles).forEach(cle => {
    ((cycles[cle] && cycles[cle].candidats) || []).forEach(c => ajouter(c && c.nom, { country: state.country }));
  });
  // Mention « en campagne » purement informative : listerCandidatsElectorauxActifs reste la
  // definition unique de cette notion (plateau-politique.js), elle ne filtre simplement plus rien.
  const actifs = (typeof listerCandidatsElectorauxActifs === 'function') ? listerCandidatsElectorauxActifs() : [];
  actifs.forEach(c => ajouter(c && c.nom, { enCampagne: true }));
  return Array.from(parNom.values()).sort((a, b) => a.nom.localeCompare(b.nom, 'fr'));
}

function echapperTexteTract(s) {
  if (typeof escapeHtmlText === 'function') return escapeHtmlText(s);
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

async function ouvrirModalImprimerTractsElectoraux(pa, cost) {
  const cibles = await listerCiblesTractsElectoraux();
  const stockBois = await stockBoisAtelier();
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cap = capaciteImpressionTracts(stockBois);
  const prixLot = cap.prixLot;
  const imprimeur = (typeof nomImprimeurLocal === 'function' && nomImprimeurLocal()) || null;
  const empireNoms = { republic: 'Républia', narco: 'El Estado', soviet: 'Sovarka', khalija: 'Al-Khalija' };
  const moi = (state.char && state.char.name) || '';
  document.getElementById('postes-modal-title').textContent = 'Imprimer des tracts électoraux';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Par lot de ' + TRACTS_PAR_LOT + ' tracts : ' + prixLot + ' ' + cur + ', ' + BOIS_PAR_LOT_TRACTS + ' bois du stock de l\'imprimerie et 1 PA de travail, rémunéré ' + SALAIRE_LOT_TRACTS + ' ' + cur + '.</div>';
  html += '<div style="font-size:.76rem;color:' + (cap.parBois >= 1 ? '#8a8060' : '#cc5540') + ';margin-bottom:.4rem"><i class="ti ti-trees" style="font-size:.75rem"></i> Bois en stock ' + (imprimeur ? 'de ' + echapperTexteTract(imprimeur) : 'de l\'imprimerie') + ' : ' + stockBois + ' (soit ' + (cap.parBois * TRACTS_PAR_LOT) + ' tracts imprimables)</div>';
  html += '<div style="font-size:.76rem;color:#8a8060;margin-bottom:.8rem">Vos PA : ' + (state.pa || 0) + ' — vos fonds ordinaires : ' + cap.fonds.toLocaleString('fr-FR') + ' ' + cur + '</div>';
  if (cibles.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Aucun personnage à viser n\'est accessible pour l\'instant.</div>';
  } else if (cap.parBois < 1) {
    html += '<div style="font-size:.85rem;color:#cc5540">L\'imprimerie n\'a plus de bois. Vendez-lui des matières premières avant de commander.</div>';
  } else if (cap.parPa < 1) {
    html += '<div style="font-size:.85rem;color:#cc5540">Il faut au moins 1 PA pour produire un lot de ' + TRACTS_PAR_LOT + ' tracts.</div>';
  } else if (cap.parFonds < 1) {
    html += '<div style="font-size:.85rem;color:#cc5540">Il vous faut ' + prixLot + ' ' + cur + ' disponibles pour un lot de ' + TRACTS_PAR_LOT + ' tracts.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">ORIENTATION DU TRACT</div>';
    html += '<div style="display:flex;gap:.5rem;margin-bottom:.7rem">';
    html += '<button id="tract-type-pour" onclick="selectTractType(\'pour\')" style="flex:1;padding:.4rem;border:1px solid #4a8a4a;background:#0a1808;color:#6a9a6a;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em">POUR</button>';
    html += '<button id="tract-type-contre" onclick="selectTractType(\'contre\')" style="flex:1;padding:.4rem;border:1px solid #2a2010;background:#0f0d05;color:#5a5040;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em">CONTRE</button>';
    html += '</div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">PERSONNE VISÉE</div>';
    html += '<select id="tract-electoral-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.4rem">';
    cibles.forEach(c => {
      const n = echapperTexteTract(c.nom);
      let suffixe = '';
      if (c.nom === moi) suffixe += ' — vous';
      else if (c.country && empireNoms[c.country] && c.country !== state.country) suffixe += ' — ' + empireNoms[c.country];
      if (c.enCampagne) suffixe += ' — en campagne';
      html += '<option value="' + n + '"' + (c.nom === moi ? ' selected' : '') + '>' + n + suffixe + '</option>';
    });
    html += '</select>';
    html += '<div style="font-size:.72rem;color:#7a7050;font-style:italic;margin-bottom:.8rem">Un tract se distribue le dimanche d\'un scrutin où la personne visée est candidate.</div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">NOMBRE DE LOTS</div>';
    html += '<select id="tract-electoral-lots" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.4rem">';
    // Aucune quantite pre-remplie au maximum : la liste commence a 1 lot, qui reste selectionne
    // par defaut. Le plafond est la plus contraignante des trois bornes (bois, PA, fonds).
    for (let n = 1; n <= cap.lots; n++) {
      html += '<option value="' + n + '">' + n + ' lot' + (n > 1 ? 's' : '') + ' — ' + (n * TRACTS_PAR_LOT) + ' tracts, ' + (n * prixLot) + ' ' + cur + ', ' + (n * BOIS_PAR_LOT_TRACTS) + ' bois, ' + n + ' PA (salaire ' + (n * SALAIRE_LOT_TRACTS) + ' ' + cur + ')</option>';
    }
    html += '</select>';
    let limite = 'le stock de bois de l\'imprimerie';
    if (cap.parPa <= cap.parBois && cap.parPa <= cap.parFonds) limite = 'vos PA';
    else if (cap.parFonds <= cap.parBois) limite = 'vos fonds';
    html += '<div style="font-size:.72rem;color:#7a7050;font-style:italic;margin-bottom:.8rem">Maximum ici : ' + cap.lots + ' lot' + (cap.lots > 1 ? 's' : '') + ', limité par ' + limite + '.</div>';
    html += '<button onclick="confirmerImprimerTractsElectoraux(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Commander</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  window._tractType = 'pour';
}

async function confirmerImprimerTractsElectoraux(pa, cost) {
  const cible = document.getElementById('tract-electoral-cible')?.value;
  if (!cible) { showToast('Aucune cible', 'Choisissez la personne visée par les tracts.', false); return; }
  const sens = window._tractType === 'contre' ? 'contre' : 'pour';
  const nbLots = Math.max(1, parseInt(document.getElementById('tract-electoral-lots')?.value || '1', 10) || 1);
  const quantite = nbLots * TRACTS_PAR_LOT;
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  // Production : 1 PA, 150 FR, 1 bois de l'imprimerie et 50 FR de salaire PAR LOT de 10. Tout ou
  // rien : imprimerie_produire_tracts relit le tarif, le bois, les PA et les fonds sous verrou et
  // ne renvoie ok qu'apres avoir tout ecrit. Un refus n'a rien consomme -- l'inventaire ci-dessous
  // n'est donc alimente qu'apres confirmation serveur.
  // Production et depot par le serveur (tracts_imprimer) : meme empilement que l'ecran (meme cible
  // et meme orientation, hors lots epingles a un scrutin et tracts de quete).
  const prod = await imprimerTractsServeur(nbLots, cible, sens, false);
  if (!prod) return;
  const montantDebite = prod.montantDebite;

  document.getElementById('modal-postes')?.classList.remove('open');
  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  updateUI();
  showToast('Tracts imprimés !', quantite + ' tracts ' + (sens === 'contre' ? 'contre ' : 'en faveur de ') + cible + ' ajoutés à votre inventaire. -' + montantDebite + ' ' + cur + ', -' + prod.paConsommes + ' PA, +' + prod.salaire + ' ' + cur + ' de main-d\'œuvre.', true, true);
  addJournalEntry('Impression de ' + quantite + ' tracts électoraux ' + (sens === 'contre' ? 'contre ' : 'en faveur de ') + cible + ' (' + prod.paConsommes + ' PA, salaire ' + prod.salaire + ' ' + cur + ').', 'event-info');
}

// --- Tract calomnieux (atelier) ---
// Cible libre dans le repertoire (comme l'ancien imprimer_tracts) : contrairement au tract
// electoral, il n'y a pas de notion de "candidat en campagne" a respecter, la calomnie visant a
// nuire a la POP d'une cible quelconque, pas a fausser un vote. Reutilise checkDetection/
// ACTES_ILLEGAUX['imprimer_tracts_calomnieux'] (plateau-core.js, cle renommee a l'identique
// depuis l'ancienne imprimer_clandestin) -- meme mecanisme de detection qu'ailleurs, aucun
// systeme parallele.
// Ateliers ou s'impriment les tracts calomnieux, chacun avec sa caisse d'imprimerie dans
// batiments_etat (sous-objet 'imprimerie', systeme commun) : La Tribune (Luthecia, Montrouge) et
// l'Imprimerie-Librairie Gutenberg (Port-Sainte-Marie, caisse creee et amorcee le 11 septembre 2026,
// migration_autruche_tracts_securisation.sql). Meme prix partout : PRIX_LOT_TRACTS par lot de 10.
const ATELIERS_TRACTS_CALOMNIEUX = ['la-tribune', 'imprimerie-librairie'];

function prixLotTractsCalomnieux() {
  return prixLotTractsAtelier();
}

// Tarif d'un lot de 10 tracts dans l'atelier ou se trouve le joueur -- POINT D'ACCROCHE UNIQUE du
// prix (tracts ordinaires, electoraux et calomnieux). Tarif public/PNJ de Republia : 150 FR. Aucune
// imprimerie n'est aujourd'hui possedable par un PJ : le jour ou elle le sera, c'est ici que le
// prix fixe par son proprietaire sera lu (voir rapport du 12 septembre 2026).
function prixLotTractsAtelier() {
  return PRIX_LOT_TRACTS;
}

// CIBLE (regle fixee le 12 septembre 2026) : un tract calomnieux peut viser N'IMPORTE QUEL PJ --
// pas besoin qu'il soit candidat, present, dans la meme ville ni dans le meme empire. La liste
// n'est donc plus le repertoire personnel mais l'annuaire des joueurs (meme source que
// ouvrirAnnuaireJoueurs), le repertoire servant seulement de repli si l'annuaire est injoignable.
async function ouvrirModalImprimerTractsCalomnieux(pa, cost) {
  const moi = state.char?.name || '';
  let cibles = [];
  if (typeof sbListPersonnages === 'function') {
    try { cibles = ((await sbListPersonnages()) || []).map(j => ({ name: j.name, country: j.country })); } catch (e) { cibles = []; }
  }
  if (cibles.length === 0) cibles = (state.contacts || []).map(c => ({ name: c.name, country: null }));
  cibles = cibles.filter(c => c && c.name && c.name !== moi)
                 .sort((a, b) => a.name.localeCompare(b.name, 'fr'));
  const stockBois = await stockBoisAtelier();
  document.getElementById('postes-modal-title').textContent = 'Imprimer des tracts calomnieux';
  let html = '<div style="padding:1rem">';
  const prixLot = prixLotTractsCalomnieux();
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const imprimeur = (typeof nomImprimeurLocal === 'function' && nomImprimeurLocal()) || null;
  const empireNoms = { republic: 'Républia', narco: 'El Estado', soviet: 'Sovarka', khalija: 'Al-Khalija' };
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Un lot de 10 tracts calomnieux (illégal) : ' + prixLot + ' ' + cur + ', ' + BOIS_PAR_LOT_TRACTS + ' bois du stock de l\'imprimerie et 1 PA de travail, rémunéré ' + SALAIRE_LOT_TRACTS + ' ' + cur + '.</div>';
  html += '<div style="font-size:.76rem;color:' + (stockBois >= BOIS_PAR_LOT_TRACTS ? '#8a8060' : '#cc5540') + ';margin-bottom:.8rem"><i class="ti ti-trees" style="font-size:.75rem"></i> Bois en stock ' + (imprimeur ? 'de ' + imprimeur : 'de l\'imprimerie') + ' : ' + stockBois + '</div>';
  if (cibles.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Aucun autre joueur enregistré à viser pour l\'instant.</div>';
  } else if (stockBois < BOIS_PAR_LOT_TRACTS) {
    html += '<div style="font-size:.85rem;color:#cc5540">L\'imprimerie n\'a plus de bois. Vendez-lui des matières premières avant de commander.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
    html += '<select id="tract-calomnieux-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    cibles.forEach(c => {
      const suffixe = c.country && empireNoms[c.country] ? ' — ' + empireNoms[c.country] : '';
      html += '<option value="' + c.name + '">' + c.name + suffixe + '</option>';
    });
    html += '</select>';
    html += '<button onclick="confirmerImprimerTractsCalomnieux(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Imprimer 10 tracts</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerImprimerTractsCalomnieux(pa, cost) {
  const cible = document.getElementById('tract-calomnieux-cible')?.value;
  if (!cible) { showToast('Aucune cible', '', false); return; }

  // Paiement du lot (arbitrage du 11 septembre 2026 : meme prix que les tracts ordinaires) par le
  // mecanisme standard : fonds reels (liquide puis Banque nationale) verifies avant toute
  // production, puis PA + debit en un seul appel. Aucun paiement la ou l'atelier n'a pas de caisse.
  // Jamais d'impression gratuite hors d'un atelier connu : l'argent n'aurait aucune caisse ou aller.
  if (ATELIERS_TRACTS_CALOMNIEUX.indexOf(state.currentBuilding) < 0) {
    showToast('Atelier introuvable', 'Ces tracts ne s\'impriment que dans un atelier d\'imprimerie.', false);
    return;
  }
  // Meme production que les tracts electoraux : 1 lot de 10 = 1 PA, 150 FR, 1 bois de l'imprimerie
  // et 50 FR de salaire verses au producteur. Controles, reservation atomique de la matiere et
  // mouvements de caisse sont mutualises dans produireLotsTracts.
  // Production, depot et detection par le serveur (tracts_imprimer, 27/10/2026).
  const prod = await imprimerTractsServeur(1, cible, 'pour', true);
  if (!prod) return;
  const montantDebite = prod.montantDebite;

  document.getElementById('modal-postes')?.classList.remove('open');
  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  updateUI();
  showToast('Tracts imprimés !', '10 tracts calomnieux contre ' + cible + ' ajoutés à votre inventaire (illégal). -' + montantDebite + ' ' + (COUNTRIES[state.country]?.cur || 'FR') + ', -' + prod.paConsommes + ' PA, +' + prod.salaire + ' ' + (COUNTRIES[state.country]?.cur || 'FR') + ' de main-d\'œuvre.', true, true);
  addJournalEntry('Impression clandestine de 10 tracts calomnieux contre ' + cible + '.', 'event-info');
}

// Verifie les objets recus : la base ajoute l'objet ET supprime la livraison atomiquement.
// Aucun repli vers DELETE + ajout local si la migration n'est pas deployee.
const RP_OBJETS_RECUS_EN_COURS = new Set();
async function verifierObjetsRecus() {
  if (!state.char?.name || state.personnageChargeDepuisServeur === false
      || typeof sbInventaireReceptionEtat !== 'function') return;
  const personnage = state.char, nom = personnage.name, pays = state.country;
  const uid = typeof rpAuthUid === 'function' ? rpAuthUid() : null;
  const jeton = typeof rpAuthJeton === 'function' ? rpAuthJeton() : null;
  const actif = () => state.char === personnage && state.country === pays
    && (typeof rpAuthUid !== 'function' || rpAuthUid() === uid)
    && (typeof rpAuthJeton !== 'function' || rpAuthJeton() === jeton);
  const cle = JSON.stringify([uid, nom, pays]);
  if (RP_OBJETS_RECUS_EN_COURS.has(cle)) return;
  RP_OBJETS_RECUS_EN_COURS.add(cle);
  const empreinte = typeof sbEmpreinteInventaire === 'function' ? sbEmpreinteInventaire : JSON.stringify;
  const valide = v => v?.ok === true && v.contrat === 1 && Array.isArray(v.inventory)
    && Number.isSafeInteger(v.revision) && v.revision >= 0;
  const conflit = () => {
    state._inventaireConflit = true;
    if (typeof showToast === 'function') showToast('Inventaire à synchroniser',
      'Des modifications concurrentes empêchent la synchronisation. Les livraisons restent protégées côté serveur.', false);
  };
  const adopter = v => {
    if (typeof sbAdopterInventaireServeur === 'function') {
      if (!sbAdopterInventaireServeur(v)) return false;
    } else state.inventory = v.inventory;
    state._inventaireVersionne = true;
    state._inventaireRevision = v.revision;
    state._inventaireBase = empreinte(v.inventory);
    state._inventaireConflit = false;
    if (typeof renderInventory === 'function') renderInventory();
    return true;
  };
  try {
    const avant = empreinte(state.inventory || []), base = state._inventaireBase;
    const etat = await sbInventaireReceptionEtat(nom);
    if (!actif()) return;
    if (!valide(etat)) {
      // Service de reception indisponible : ce poll automatique n'est pas une
      // action demandee par le joueur. Ne jamais l'assaillir d'une erreur
      // recurrente ; conserver toutes les livraisons en file cote serveur.
      // Les erreurs restent visibles en console pour le diagnostic technique.
      console.warn('[reception] contrat serveur absent ou invalide : aucun objet reclame', etat?.raison || 'RPC indisponible');
      return;
    }
    if (empreinte(state.inventory || []) !== avant) return;
    if (Number.isSafeInteger(state._inventaireRevision) && etat.revision < state._inventaireRevision) return;
    const serveur = empreinte(etat.inventory);
    if (avant === serveur || avant === base) {
      if (!adopter(etat)) return; // aucun ajout local non sauvegarde n'est ecrase
    } else if (serveur === base) {
      // Ajouts legacy locaux : sauvegarde CAS AVANT de reclamer, jamais de fusion devinee.
      state._inventaireRevision = etat.revision;
      const sauve = await sbSavePersonnage(state);
      if (!actif()) return;
      if (!sauve || state._inventaireConflit) { conflit(); return; }
      if (empreinte(state.inventory || []) !== avant) return;
    } else { conflit(); return; }
    const objets = await sbGetLivraisonsEnAttente(nom);
    if (!actif()) return;
    for (const {id, reception_token} of objets) {
      if (!actif()) return;
      const snapshot = empreinte(state.inventory), revision = state._inventaireRevision;
      const recu = await sbInventaireReclamerLivraison(nom, id, reception_token, revision);
      if (!actif()) return;
      if (empreinte(state.inventory) !== snapshot) { conflit(); return; }
      if (!valide(recu)) {
        // Une reponse perdue ne vaut pas un echec : le prochain poll relit le registre.
        if (recu?.raison === 'inventaire_perime') conflit();
        return;
      }
      if (recu.revision < state._inventaireRevision) return;
      if (!adopter(recu)) return;
      if (recu.rejeu || !recu.objet) continue;
      const objet = recu.objet, expediteur = recu.expediteur;
      if (objet.familleProduitMarche === 'carte_postale') {
        if (typeof showToast === 'function') showToast('Courrier reçu', 'Une carte postale est arrivée dans votre inventaire.', true, true);
        if (typeof addJournalEntry === 'function') addJournalEntry('Vous avez reçu une carte postale. Elle a été placée dans votre inventaire.', 'event-good');
      } else {
        const tracts = typeof id === 'string' && id.startsWith('don-tracts-');
        const message = expediteur + ' vous a donné ' + (tracts ? objet.quantite + ' × ' : '') + '"' + objet.name + '".';
        if (typeof showToast === 'function') showToast(tracts ? 'Tracts reçus !' : 'Objet reçu !', message, true, true);
        if (typeof addJournalEntry === 'function') addJournalEntry(message, 'event-good');
      }
    }
  } catch(e) {
    console.warn('Réception interrompue ; le prochain passage relira l’inventaire serveur.');
  } finally {
    RP_OBJETS_RECUS_EN_COURS.delete(cle);
  }
}

// Lots de tracts transmissibles a un PJ : ordinaires ET calomnieux (11 septembre 2026). Les tracts
// de la mission Jean-Lou (origineQuete) restent exclus : objets de quete, circuit dedie.
function lotsTractsDonnables() {
  return (state.inventory || []).filter(i => (i.type === 'tract' || i.type === 'tract_calomnieux')
    && i.origineQuete !== 'jean_lou' && (i.quantite || 0) > 0);
}

function donnerTracts(pjName) {
  const tracts = lotsTractsDonnables();
  if (tracts.length === 0) {
    showToast('Aucun tract', 'Vous n\'avez pas de tracts en inventaire.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Donner des tracts a ' + pjName;
  let html = '<div style="padding:1rem">';
  tracts.forEach((t, idx) => {
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
    html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.4rem">' + t.name + (t.legal === false ? ' <span style="color:#cc4444">(illégal)</span>' : '') + ' <span style="color:#C9A84C">(' + t.quantite + ' restants)</span></div>';
    html += '<div style="display:flex;align-items:center;gap:.5rem">';
    html += '<input id="don-tract-' + idx + '" type="number" min="1" max="' + t.quantite + '" value="1" style="width:60px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.82rem;outline:none">';
    html += '<button onclick="confirmerDonTracts(' + idx + ',\'' + pjName + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Donner</button>';
    html += '</div></div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Don de tracts (correctif du 11 septembre 2026). Un vrai PJ ne recevait RIEN : seuls les PJ
// simules etaient credites, les tracts disparaissaient de l'inventaire du donneur. Transfert reel
// desormais, par le meme canal que les autres dons entre joueurs (objets_recus), dans cet ordre :
//   1. retrait local PUIS sauvegarde confirmee du donneur -- le destinataire ne peut rien recevoir
//      tant que le retrait n'est pas ecrit : jamais de doublon ;
//   2. envoi par tracts_donner_joueur (destinataire verifie en base, id de requete idempotent :
//      une relance ne cree jamais un second don) ;
//   3. en cas d'echec, restitution exacte et nouvelle sauvegarde : jamais de perte.
// Toutes les donnees du lot voyagent telles quelles (type, cible, POUR/CONTRE, legal...).
async function confirmerDonTracts(tractIdx, pjName) {
  const tract = lotsTractsDonnables()[tractIdx]; if (!tract) return;
  const index = state.inventory.indexOf(tract);
  const quantite = Number(document.getElementById('don-tract-' + tractIdx)?.value || 1);
  if (!Number.isInteger(quantite) || quantite < 1) { showToast('Quantité invalide', '', false); return; }
  const v = await executerReceptionInventaire('tracts_donner_joueur', { p_index: index, p_revision: state._inventaireRevision ?? null,
    p_destinataire: pjName, p_quantite: quantite });
  if (!v) return;
  document.getElementById('modal-postes').classList.remove('open'); updateUI();
  showToast('Tracts donnés', v.quantite + ' tracts remis à ' + v.destinataire + '.', true);
  addJournalEntry('Don de ' + v.quantite + ' tracts à ' + v.destinataire, 'event-info');
}

// Reception d'un lot de tracts : fusionne avec un lot identique (meme type, cible, sens, legalite)
// plutot que d'empiler un second lot ; sinon entre comme tout objet recu automatiquement.
// recevoirLotTracts retiree : aucun appelant, reception versionnee existante dans verifierObjetsRecus.

// =====================
// DISTRIBUTION DE TRACTS A UN PNJ PRESENT (lot du 24 aout 2026)
// =====================
// Remplace l'ancien distribuerTractPNJ, explicitement documente comme "systeme factice
// identifie par l'audit du 17 aout 2026" (state.electionsEnCours, jamais le vrai systeme
// electoral). Deux circuits desormais distincts : electoral (vrai vote PNJ, CYCLES_ELECTORAUX/
// enregistrerVotePNJ) et calomnieux (POP + risque penal, aucun lien avec le vote). Le don
// generique (plateau-justice-economie.js, "Donner un objet") et le transfert a un vrai PJ
// (donnerTracts/confirmerDonTracts ci-dessus) restent inchanges -- usages distincts et
// deliberement non touches. La quete Jean-Lou (distribuerTractJeanLou, plateau-pnj.js) continue
// d'utiliser son propre circuit, deja branche sur le vrai systeme, non modifie.

// --- Electoral : 1 tract -> 1 tentative aupres d'un PNJ electeur (11 septembre 2026) ---
// Regles fixees : POUR reussi = +1 voix au candidat ; CONTRE reussi = -1 voix, score jamais negatif ;
// chaque tentative consomme 1 tract ; un echec n'engage pas le PNJ (nouvelle tentative possible) ;
// une reussite l'engage pour le tour. Uniquement le dimanche d'un scrutin ouvert, dans la ville du
// scrutin local (presidentielle : une ville du pays, la caserne ou le QHS). Jet :
// 45 + CHA + floor(INF/4) - 2 x max(0, VOL_PNJ - 10), plafond 85 %.
// TOUT est decide par le serveur (RPC tracts_electoraux_distribuer) : le client ne fait qu'afficher
// les tracts utilisables et appliquer la consommation que le serveur confirme. Refus = rien consomme.
// La quete Jean-Lou (distribuerTractJeanLou, plateau-pnj.js) garde son propre circuit.

// Volonte du PNJ : utilisee des qu'elle existera dans ses donnees (chantier PNJ ulterieur), 10 sinon.
function volontePnjElectorale(encodedPnj) {
  try {
    const pnj = JSON.parse(decodeURIComponent(encodedPnj || ''));
    const vol = pnj?.stats?.VOL ?? pnj?.VOL;
    return (typeof vol === 'number' && isFinite(vol)) ? vol : 10;
  } catch (e) { return 10; }
}

const MOTIFS_REFUS_TRACT_ELECTORAL = {
  pas_dimanche: 'Les tracts électoraux ne se distribuent que le dimanche.',
  hors_phase_vote: 'Aucun vote n\'est ouvert pour ce scrutin.',
  hors_ville: 'Ce tract ne peut être distribué que dans la ville du scrutin.',
  hors_territoire: 'Ce tract ne peut être distribué qu\'à l\'intérieur du pays du scrutin.',
  hors_pays: 'Ce scrutin n\'est pas celui du pays où vous êtes.',
  candidat_hors_scrutin: 'Ce candidat ne participe pas à ce scrutin.',
  deja_vote: 'Ce PNJ a déjà participé à ce tour du scrutin.',
  tract_absent: 'Ce tract ne figure pas dans votre inventaire enregistré.',
  scrutin_non_concerne: 'Les tracts ne concernent que la présidentielle, les municipales et les législatives.',
  pa_insuffisants: 'Il faut 1 PA pour distribuer un tract.',
  pnj_absent_ou_non_verifiable: 'La présence de ce PNJ ne peut pas être vérifiée dans cette pièce. Aucun tract ni PA dépensé.'
};

async function distribuerTractElectoralPNJ(pnjName, encodedPnj) {
  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase().catch(() => {});
  const options = typeof tractsElectorauxDistribuablesIci === 'function' ? tractsElectorauxDistribuablesIci() : [];
  if (options.length === 0) {
    const dimanche = typeof estDimancheParis === 'function' && estDimancheParis();
    showToast('Aucun tract utilisable ici', dimanche
      ? 'Aucun de vos tracts ne concerne un scrutin dont le vote est ouvert dans ce lieu.'
      : 'Les tracts électoraux ne se distribuent que le dimanche, pendant un scrutin ouvert.', false);
    return;
  }
  const entrees = [];
  options.forEach(o => o.scrutins.forEach(sc => entrees.push({ tract: o.tract, scrutin: sc })));
  window._tractsElectorauxChoix = { pnjName, encodedPnj, entrees };
  if (entrees.length === 1) { await confirmerDistribuerTractElectoral(0); return; }

  document.getElementById('postes-modal-title').textContent = 'Distribuer un tract électoral à ' + pnjName;
  let html = '<div style="padding:.8rem 1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Choisissez le tract et le scrutin.</div>';
  html += entrees.map((e, i) => {
    const contre = (e.tract.tractType || 'pour') === 'contre';
    return '<div onclick="confirmerDistribuerTractElectoral(' + i + ')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
      '<i class="ti ti-file-description" style="font-size:.9rem;color:' + (contre ? '#9a4a4a' : '#6a9a6a') + '"></i>' +
      '<div><div style="font-size:.82rem;color:#c0b090">' + (contre ? 'Contre ' : 'Pour ') + e.tract.cible + ' — ' + e.scrutin.libelle + '</div>' +
      '<div style="font-size:.85rem;color:#9a8a68">' + e.tract.quantite + ' restants</div></div>' +
    '</div>';
  }).join('');
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Action collective : les quantites et la liste de PNJ sont determinees par Supabase.
let tractCollectifEnCours = false;
async function ouvrirTractageCollectifStade() {
  if (state.currentBuilding !== 'stade') return;
  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase().catch(() => {});
  const choix = typeof tractsElectorauxDistribuablesIci === 'function' ? tractsElectorauxDistribuablesIci() : [];
  const entrees = choix.flatMap(o => o.scrutins.map(sc => ({tract:o.tract,scrutin:sc})));
  if (!entrees.length) {
    showToast('Aucun scrutin ouvert', 'Aucun tract electoral utilisable ici actuellement.', false);
    return;
  }
  window._tractageCollectifChoix = entrees;
  document.getElementById('postes-modal-title').textContent = 'Tractage collectif au stade';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem"><p>Une tentative par PNJ eligible, dans la limite des tracts et PA disponibles. Chaque tentative coute 1 tract et 1 PA, reussie ou non.</p>'
    + entrees.map((e,i) => '<button type="button" onclick="confirmerTractageCollectifStade('+i+')" style="display:block;width:100%;padding:.65rem;margin:.4rem 0;background:#151107;border:1px solid #6a5a20;color:#e0d8c0;cursor:pointer">'
      + (e.tract.tractType==='contre'?'Contre ':'Pour ') + (typeof escapeHtml==='function'?escapeHtml(e.tract.cible):e.tract.cible)
      + ' — ' + e.scrutin.libelle + ' (' + e.tract.quantite + ' tracts)</button>').join('') + '</div>';
  document.getElementById('modal-postes').classList.add('open');
}
async function confirmerTractageCollectifStade(index) {
  if (tractCollectifEnCours) return;
  const e = window._tractageCollectifChoix?.[index];
  if (!e || state.currentBuilding !== 'stade') return;
  if (typeof sbTractsElectorauxDistribuerCollectif !== 'function') return;
  tractCollectifEnCours = true;
  document.getElementById('modal-postes')?.classList.remove('open');
  try {
    const req='tract-groupe-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2,10);
    const sens=e.tract.tractType==='contre'?'contre':'pour';
    let res=await sbTractsElectorauxDistribuerCollectif(req,state.char.name,e.scrutin.cycleId,e.tract.cible,sens).catch(()=>null);
    if (!res) res=await sbTractsElectorauxDistribuerCollectif(req,state.char.name,e.scrutin.cycleId,e.tract.cible,sens).catch(()=>null);
    if (!res?.ok) {
      showToast('Distribution impossible',MOTIFS_REFUS_TRACT_ELECTORAL[res?.raison] || res?.raison || 'Le serveur ne confirme pas la distribution.',false);
      return;
    }
    if (Array.isArray(res.inventory)) { if (typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(res); else state.inventory=res.inventory; }
    if (typeof res.pa==='number') state.pa=res.pa;
    if (typeof chargerEffetsTractsPNJ==='function') await chargerEffetsTractsPNJ(state.country);
    showToast('Tractage collectif termine',res.essais+' tentatives, '+res.reussites+' reussites. '+res.essais+' tracts et PA consommes.',true);
    updateUI();
  } finally { tractCollectifEnCours=false; }
}

let tractElectoralEnCours = false;
async function confirmerDistribuerTractElectoral(indexEntree) {
  if (tractElectoralEnCours) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  const ctx = window._tractsElectorauxChoix;
  const e = ctx?.entrees?.[indexEntree];
  if (!e) return;
  const tract = e.tract;
  if ((state.inventory || []).indexOf(tract) < 0 || (tract.quantite || 0) < 1) {
    showToast('Lot épuisé', 'Ce lot de tracts n\'est plus disponible.', false);
    return;
  }
  if (typeof sbTractsElectorauxDistribuer !== 'function' || !state.char?.name) {
    showToast('Action impossible', 'La distribution ne peut pas être effectuée pour le moment.', false);
    return;
  }
  // 1 PA par tentative individuelle (regle validee) : verifie avant tout envoi.
  if (typeof TEST_MODE !== 'undefined' && !TEST_MODE && (state.pa || 0) < 1) {
    showToast('PA insuffisants', MOTIFS_REFUS_TRACT_ELECTORAL.pa_insuffisants, false);
    return;
  }
  // La base est la source de verite pour les ressources et la position.
  tractElectoralEnCours = true;
  try {
  const sens = tract.tractType === 'contre' ? 'contre' : 'pour';
  const requete = 'tract-el-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
  const vol = volontePnjElectorale(ctx.encodedPnj);
  let res = await sbTractsElectorauxDistribuer(requete, state.char.name, e.scrutin.cycleId, tract.cible, sens, ctx.pnjName, vol).catch(() => null);
  if (!res) res = await sbTractsElectorauxDistribuer(requete, state.char.name, e.scrutin.cycleId, tract.cible, sens, ctx.pnjName, vol).catch(() => null);
  if (!res) {
    showToast('Réseau indisponible', 'La distribution n\'a pas pu être vérifiée. Aucun tract n\'a été utilisé.', false);
    return;
  }
  if (!res.ok) {
    showToast('Distribution impossible', MOTIFS_REFUS_TRACT_ELECTORAL[res.raison] || 'La distribution a été refusée.', false);
    return;
  }

  // Tentative reellement effectuee (reussite ou echec) : 1 PA et 1 tract consommes, jamais plus
  // (un rejeu renvoie le meme resultat et n'est traite qu'une fois ici).
  // Le serveur a deja debite le PA et l'unite de tract atomiquement avec le resultat.
  // Ne jamais redebiter localement ni sauvegarder un ancien inventaire par-dessus.
  if (Array.isArray(res.inventory)) { if (typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(res); else state.inventory = res.inventory; }
  if (typeof res.pa === 'number') state.pa = res.pa;

  const pnjName = ctx.pnjName;
  if (res.reussi) {
    const cycle = CYCLES_ELECTORAUX[state.country]?.[e.scrutin.cle];
    if (typeof ajouterEffetTractLocal === 'function') ajouterEffetTractLocal(cycle, tract.cible, res.effet, res.tour);
    let msg;
    if (sens === 'pour') msg = pnjName + ' votera pour ' + tract.cible + '. +1 voix.';
    else if (res.effet === -1) msg = pnjName + ' est convaincu(e) : ' + tract.cible + ' perd une voix.';
    else msg = pnjName + ' est convaincu(e), mais ' + tract.cible + ' n\'avait plus de voix à perdre.';
    showToast('Tract distribué !', msg + ' (' + e.scrutin.libelle + ')', true, true);
    addJournalEntry('Tract ' + sens + ' ' + tract.cible + ' distribué à ' + pnjName + ' — ' + msg, 'event-good');
  } else {
    showToast('Sans effet', pnjName + ' n\'a pas été convaincu(e). Tract consommé. (' + res.jet + ' pour ' + res.taux + ' %)', false);
    addJournalEntry('Distribution de tract ' + sens + ' ' + tract.cible + ' à ' + pnjName + ' — sans effet.', '');
  }
  if (typeof verifierProgressionCarriere === 'function') verifierProgressionCarriere('politique', !!res.reussi);
  updateUI();
  } finally { tractElectoralEnCours = false; }
}

function distribuerTractCalomnieuxPNJ(pnjName, encodedPnj) {
  const tracts = (state.inventory || []).filter(i => i.type === 'tract_calomnieux' && (i.quantite || 0) > 0);
  if (tracts.length === 0) {
    showToast('Aucun tract', 'Vous n\'avez pas de tract calomnieux en inventaire.', false);
    return;
  }
  window._calomnieEncodedPnj = encodedPnj || null;
  if (tracts.length === 1) {
    confirmerDistribuerTractCalomnieux(tracts[0].cible, pnjName, encodedPnj);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Distribuer un tract calomnieux à ' + pnjName;
  let html = '<div style="padding:.8rem 1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Choisissez la cible de la campagne mensongère.</div>';
  html += tracts.map(t =>
    '<div onclick="confirmerDistribuerTractCalomnieux(\'' + t.cible.replace(/'/g, '') + '\',\'' + pnjName + '\')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
      '<i class="ti ti-alert-triangle" style="font-size:.9rem;color:#cc4444"></i>' +
      '<div><div style="font-size:.82rem;color:#c0b090">Contre ' + t.cible + '</div>' +
      '<div style="font-size:.85rem;color:#9a8a68">' + t.quantite + ' restants</div></div>' +
    '</div>'
  ).join('');
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

const MOTIFS_REFUS_TRACT_CALOMNIEUX = {
  tract_absent: 'Ce lot ne figure pas dans votre inventaire enregistré.',
  deja_convaincu: 'Cette personne a déjà relayé une calomnie contre cette cible aujourd\'hui.',
  pa_insuffisants: 'Il faut 1 PA pour distribuer un tract calomnieux.',
  cible_introuvable: 'La cible de ce tract n\'existe plus.',
  cible_invalide: 'Cette cible n\'est pas valable.',
  juridiction_indeterminee: 'Impossible de déterminer le pays de résidence de la cible.',
  pnj_invalide: 'Cet interlocuteur n\'est pas identifiable.'
};

// MECANIQUE SERVEUR (12 septembre 2026, migration_tracts_calomnieux.sql). Regles fixees :
//   - 1 tract + 1 PA + 1 PNJ precis par tentative ; jet serveur ;
//   - taux = 45 + CHA + floor(INF/4) - 2 x max(0, VOL_PNJ - 10), borne [0, 85], VOL 10 par defaut,
//     soit exactement la formule des tracts electoraux (meme fonction SQL, aucune duplication) ;
//   - reussite : POP -5 ET INF -2 sur le PJ cible, en une seule ecriture atomique, bornes [0,100] ;
//     elle verrouille le triplet PNJ x cible x jour (Paris) -- pas le PNJ, pas la cible seuls ;
//   - echec normal : aucun effet, meme PNJ retentable immediatement ;
//   - echec critique = 10 % des ECHECS : le calomnieur est identifie.
// Juridiction (regle fixee) : le pays competent est celui de RESIDENCE DE LA VICTIME AU MOMENT DES
// FAITS, gele dans l'acte. Le serveur tranche et renvoie 'poursuite' :
//   - 'flagrant_delit' (faits commis dans ce pays) : circuit preexistant, inchange -- destruction
//     des lots detenus et 1 jour de detention, applique ici parce que la peine se compte en jours
//     de jeu, propres a ce joueur ;
//   - 'mandat' (faits commis ailleurs) : aucune arrestation sur place, le serveur a inscrit une
//     entree de recherche portant country = pays competent. Les mecanismes ordinaires
//     (verifierArrestationRecherchePolice, chasse a l'homme) filtrent deja sur ce champ : pas
//     d'extradition, mais une arrestation possible si le calomnieur entre dans ce pays.
async function confirmerDistribuerTractCalomnieux(cible, pnjName, encodedPnj) {
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!encodedPnj) encodedPnj = window._calomnieEncodedPnj || null;
  const tract = (state.inventory || []).find(i => i.type === 'tract_calomnieux' && i.cible === cible && (i.quantite || 0) > 0);
  if (!tract) { showToast('Lot épuisé', 'Ce lot de tracts n\'est plus disponible.', false); return; }
  if (typeof sbRpc !== 'function' || !state.char?.name) {
    showToast('Action impossible', 'La distribution ne peut pas être effectuée pour le moment.', false);
    return;
  }
  if (typeof TEST_MODE !== 'undefined' && !TEST_MODE && (state.pa || 0) < 1) {
    showToast('PA insuffisants', MOTIFS_REFUS_TRACT_CALOMNIEUX.pa_insuffisants, false);
    return;
  }
  // PAR LE SERVEUR (28/10/2026, chantier inventaire) : calomnie_distribuer_consommer tranche le jet
  // ET retire, dans la meme transaction, 1 PA et 1 tract (tous les tracts calomnieux sur un
  // flagrant delit). L'ecran adopte l'inventaire rendu ; il ne retire plus rien lui-meme. La meme
  // requete rejouee apres une reponse perdue rend le meme resultat, sans second retrait.
  const requete = 'tract-cal-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
  const vol = typeof volontePnjElectorale === 'function' ? volontePnjElectorale(encodedPnj) : 10;
  const appeler = async () => { const b = await sbRpc('calomnie_distribuer_consommer',
    { p_requete: requete, p_cible: cible, p_pnj_nom: pnjName, p_vol_pnj: vol }).catch(() => null); return Array.isArray(b) ? b[0] : b; };
  let res = await appeler();
  if (!res) res = await appeler();
  if (!res) {
    showToast('Réseau indisponible', 'La distribution n\'a pas pu être vérifiée. Réessayez : aucun tract ne sera retiré deux fois.', false);
    return;
  }
  if (!res.ok) {
    showToast('Distribution impossible', MOTIFS_REFUS_TRACT_CALOMNIEUX[res.raison] || 'La distribution a été refusée.', false);
    return;
  }
  if (Array.isArray(res.inventory) && typeof sbAdopterInventaireServeur === 'function') sbAdopterInventaireServeur(res);
  if (typeof res.pa_restants === 'number' && typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: res.pa_restants });

  if (res.reussi) {
    showToast('Tract distribué !', pnjName + ' relaie la calomnie. -5 POP et -2 INF pour ' + cible + '.', true, true);
    addJournalEntry('Tract calomnieux distribué à ' + pnjName + ' — succès. -5 POP et -2 INF pour ' + cible + '.', 'event-good');
    if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
    if (typeof updateUI === 'function') updateUI();
    return;
  }
  {
    const critique = !!res.critique;
    if (critique && res.poursuite === 'mandat') {
      // Faits commis hors du pays competent : aucune poursuite ici, aucun lot detruit. Le mandat a
      // ete inscrit par le serveur (calomnie_inscrire_mandat).
      //
      // LE REFLET LOCAL ETAIT UNE RUSTINE (chantier 5, chaine 14, 10 octobre 2026) : il existait
      // « pour que la prochaine sauvegarde de CE client n'efface pas » le mandat, ce qui disait
      // exactement le defaut. Depuis que `recherche` est serveur-autoritaire, aucune sauvegarde
      // ne peut plus l'effacer. On RECOPIE donc l'etat reel au lieu de pousser dans le sien --
      // `recherche_inscrire` est idempotente par identifiant, l'appeler ici ne cree aucun doublon.
      if (res.mandat && typeof res.mandat === 'object' && typeof inscrireRecherche === 'function') {
        await inscrireRecherche(res.mandat);
      }
      showToast('Vous êtes démasqué(e)', pnjName + ' vous dénonce. La plainte est instruite dans le pays de résidence de ' + cible + ' : vous y êtes désormais recherché(e).', false, true);
      addJournalEntry('Distribution de tract calomnieux à ' + pnjName + ' — échec critique. Mandat d\'arrêt dans le pays de résidence de ' + cible + '.', 'event-bad');
      if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
      if (typeof updateUI === 'function') updateUI();
      return;
    }
    if (critique) {
      // Echec critique : destruction de TOUS les tracts calomnieux detenus + 1 jour de
      // detention. Reutilise directement l'architecture existante (state.estEmprisonne, meme
      // forme que procederArrestation) plutot que cette derniere : celle-ci calculerait 2 jours
      // via PEINES.delit_mineur (pas 1) et ouvrirait un choix corruption/fuite/resistance non
      // souhaite ici (flagrant delit, sanction immediate et non negociable).
      // Tous les tracts calomnieux ont ete detruits par le serveur (inventaire deja adopte).
      if (state.immuniteMilitaireActuelle) {
        showToast('Immunité militaire', 'Flagrant délit, mais votre immunité militaire vous protège de toute poursuite.', true);
        addJournalEntry('Distribution de tract calomnieux — flagrant délit, immunité militaire invoquée.', 'event-info');
      } else {
        // Registre carcerale (26 aout 2026) : toute incarcération réelle doit apparaître au
        // registre du commissariat -- ce flux positionnait state.estEmprisonne directement,
        // contournant enregistrerDetention (donc la ligne detentions correspondante n'était
        // jamais créée). On garde l'assignation synchrone immediate (navigation/UI ne doivent
        // pas attendre l'aller-retour reseau pour refleter la contrainte), enregistrerDetention
        // vient ensuite fusionner le detentionId et persister est_emprisonne cote serveur.
        const motifsTracts = [{ type: 'Distribution de tracts calomnieux', jour_fait: state.day, city: state.currentCity, jours: 1, source: 'flagrant_delit' }];
        state.estEmprisonne = { jours: 1, jourFin: (state.day || 1) + 1, raison: 'Distribution de tracts calomnieux' };
        if (typeof enregistrerDetention === 'function') {
          // L'assignation synchrone ci-dessus est un PARI : si le serveur n'ouvre pas la peine,
          // il est defait (9 octobre 2026). Sans cela le joueur restait enferme par la navigation
          // alors qu'aucune detention n'existait en base -- et aucune liberation ne viendrait
          // jamais, le filet nocturne n'ayant aucune ligne a liberer.
          enregistrerDetention(state.char?.name, 'Distribution de tracts calomnieux', (state.day || 1) + 1, undefined, state.currentCity, {
            country: state.country,
            motifs: motifsTracts
          }).then(id => { if (!id) state.estEmprisonne = null; }).catch(() => { state.estEmprisonne = null; });
        }
        showToast('Flagrant délit !', pnjName + ' alerte immédiatement la police. Tous vos tracts calomnieux sont détruits. 1 jour de détention.', false, true);
        addJournalEntry('Distribution de tract calomnieux à ' + pnjName + ' — échec critique. Tracts calomnieux détruits, 1 jour de détention.', 'event-bad');

        // Resolution spectaculaire (chantier "animations de resolution d'ordres", 26 aout 2026) :
        // ce flagrant delit precis n'a jamais teleporte le joueur (comportement preexistant,
        // inchange ici -- §8 interdit d'ajouter une dependance de navigation a l'animation).
        if (typeof ouvrirResolutionSpectaculaire === 'function' && typeof construireResultatArrestationHtml === 'function') {
          ouvrirResolutionSpectaculaire({
            type: 'arrestation',
            succes: true,
            titre: 'VOUS ÊTES EN ÉTAT D\'ARRESTATION',
            resultatHtml: construireResultatArrestationHtml(motifsTracts, state.currentCity, state.country)
          });
        }
      }
    } else {
      showToast('Sans effet', pnjName + ' n\'a pas été convaincu(e). Tract consommé. (' + res.jet + ' pour ' + res.taux + ' %)', false);
      addJournalEntry('Distribution de tract calomnieux à ' + pnjName + ' — sans effet.', '');
    }
  }
  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  updateUI();
}

async function doLogePortail(pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 95) {
    // Trouver le portier de la loge
    const portier = { name: 'Le Portier', role: 'PNJ - Gardien de la Loge', rel: 'neutral', job: 'portier' };
    openPnjModal(encodePnjSafe(portier));
    addJournalEntry('Le portier de la Loge repond a votre appel.', '');
  } else {
    showToast('Pas de reponse', 'Personne ne repond a votre frappe. Reessayez plus tard.', false);
    addJournalEntry('Vous avez frappe a la porte de la Loge mais personne n\'a repondu.', '');
  }
}

function openNominerModal() {
  const contacts = state.contacts || [];
  const ministeres = ['min_int','min_fin','min_just','min_def','min_info','min_ae'];
  const noms = { min_int:"Ministre de l'Interieur", min_fin:'Ministre des Finances', min_just:'Ministre de la Justice', min_def:'Ministre de la Defense', min_info:"Ministre de l'Information", min_ae:'Ministre des AE' };

  document.getElementById('postes-modal-title').textContent = 'Nommer un ministre';
  let html = '<div style="padding:1rem">';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Votre repertoire est vide. Enregistrez d\'abord des contacts.</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Le PJ selectionne recevra un mail de nomination.</div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">POSTE</div>';
    html += '<select id="nommer-poste" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
    ministeres.forEach(m => { html += '<option value="' + m + '">' + noms[m] + '</option>'; });
    if (state.postesCustom?.ministre) html += '<option value="custom_ministre">' + state.postesCustom.ministre.nom + '</option>';
    if (state.postesCustom?.comite) html += '<option value="custom_comite">' + state.postesCustom.comite.nom + '</option>';
    html += '</select>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">NOMME</div>';
    html += '<select id="nommer-contact" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
    html += '</select>';
    html += '<button onclick="validerNomination()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function validerNomination() {
  const poste = document.getElementById('nommer-poste')?.value;
  const contact = document.getElementById('nommer-contact')?.value;
  if (!poste || !contact) return;
  const noms = { min_int:"Ministre de l'Interieur", min_fin:'Ministre des Finances', min_just:'Ministre de la Justice', min_def:'Ministre de la Defense', min_info:"Ministre de l'Information", min_ae:'Ministre des AE' };
  const posteNom = noms[poste] || (state.postesCustom?.ministre?.nom) || (state.postesCustom?.comite?.nom) || poste;
  document.getElementById('modal-postes').classList.remove('open');
  await envoyerNotificationVraiJoueur(contact, 'Nomination ministerielle', 'Par decision presidentielle, vous etes nomme(e) au poste de ' + posteNom + '. Prenez vos fonctions immediatement.');
  showToast('Nomination envoyee', contact + ' nomme(e) ' + posteNom, true, true);
  addJournalEntry('Nomination de ' + contact + ' au poste de ' + posteNom, 'event-good');
  addExternalEvent('Nomination officielle : ' + contact + ' est nomme(e) ' + posteNom + ' par le President.');
}

function openCandidatureModal() {
  // Verifier que les elections sont en phase candidatures
  const elections = state.electionsEnCours || [];
  const electionsOuvertes = elections.filter(e => e.phase === 'candidatures');
  if (elections.length > 0 && electionsOuvertes.length === 0) {
    showToast('Candidatures fermees', 'La periode de candidature est terminee. Les campagnes sont en cours.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Deposer une candidature';
  document.getElementById('postes-body').innerHTML = `
    <div style="padding:1rem">
      ${elections.length === 0
        ? `<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune election n'est actuellement en cours. Revenez lorsqu'une election sera declaree.</div>`
        : elections.map(e => `
            <div style="padding:.7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">
              <div style="font-family:'Playfair Display',serif;font-size:.9rem;color:#E8C97A;margin-bottom:.2rem">${e.nom}</div>
              <div style="font-size:.72rem;color:#6a5a30">Date : ${e.date} · Candidats : ${e.candidats?.length || 0}</div>
              <button onclick="confirmerCandidature('${e.id}')" style="margin-top:.5rem;font-family:'Bebas Neue',sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.3rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">
                Me declarer candidat
              </button>
            </div>`).join('')}
      <div style="margin-top:.8rem;font-size:.72rem;color:#9a8a68;font-style:italic">
        Pour lancer une election, contactez le Maire ou le Responsable electoral.
      </div>
    </div>`;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerCandidatureLegacy_MORT(electionId) {
  document.getElementById('modal-postes').classList.remove('open');
  if (!state.electionsEnCours) return;
  const election = state.electionsEnCours.find(e => e.id === electionId);
  if (!election) return;
  if (!election.candidats) election.candidats = [];
  const nom = state.char?.name || 'Anonyme';
  if (election.candidats.find(c => c.nom === nom)) {
    showToast('Deja candidat', 'Vous etes deja candidat a cette election.', false);
    return;
  }
  election.candidats.push({ nom, voix: 0, isPJ: true });
  showToast('Candidature enregistree !', 'Vous etes officiellement candidat a ' + election.nom, true, true);
  addJournalEntry('Candidature deposee pour : ' + election.nom, 'event-good');
  addMailNotification('Commission Electorale', 'Confirmation de candidature', 'Votre candidature pour le poste de ' + election.nom + ' a bien ete enregistree. La campagne electorale debute dans ' + (election.joursAvantCampagne || 0) + ' jour(s).');
}

function openElectionsModal() {
  document.getElementById('postes-modal-title').textContent = 'Elections en cours';

  // Initialiser des elections de demo si aucune
  if (!state.electionsEnCours || state.electionsEnCours.length === 0) {
    state.electionsEnCours = [
      {
        id: 'election-president-1',
        nom: 'President de la Republique',
        type: 'president',
        phase: 'campagne', // candidatures | campagne | depouillement | termine
        jourDebut: 1,
        jourCampagne: 4,
        jourResultat: 7,
        joursAvantCampagne: 0,
        candidats: [
          { nom: 'Bertrand (PNJ)', voix: 0, isPJ: false },
          { nom: 'Leroux (PNJ)', voix: 0, isPJ: false }
        ],
        tour: 1,
        resultat: null
      }
    ];
  }

  const elections = state.electionsEnCours;
  let html = '<div style="padding:1rem">';

  elections.forEach(e => {
    const phaseLabel = { candidatures: 'Depot des candidatures', campagne: 'Campagne electorale', depouillement: 'Depouillement', termine: 'Termine' }[e.phase] || e.phase;
    const phaseColor = { candidatures: '#6a9a5a', campagne: '#C9A84C', depouillement: '#aa6a4a', termine: '#4a4030' }[e.phase] || '#8a8060';

    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.8rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.4rem">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.9rem;color:#E8C97A">' + e.nom + '</div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.1em;color:' + phaseColor + ';border:1px solid;padding:.1rem .4rem">' + phaseLabel + '</div>';
    html += '</div>';
    html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.5rem">Tour ' + (e.tour||1) + ' · Resultats a venir</div>';

    // Candidats et voix
    if (e.candidats && e.candidats.length > 0) {
      const totalVoix = e.candidats.reduce((s, c) => s + (c.voix||0), 0) || 1;
      html += '<div style="margin-bottom:.5rem">';
      e.candidats.forEach(c => {
        const pct = Math.round((c.voix||0) / totalVoix * 100);
        const isMoi = c.nom === (state.char?.name);
        html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.2rem">';
        html += '<div style="font-size:.75rem;color:' + (isMoi ? '#C9A84C' : '#c0b090') + ';width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + c.nom + (isMoi ? ' (Vous)' : '') + '</div>';
        html += '<div style="flex:1;height:6px;background:#1a1810;border-radius:3px"><div style="height:100%;background:' + (isMoi ? '#C9A84C' : '#4a6a4a') + ';width:' + pct + '%;border-radius:3px"></div></div>';
        html += '<div style="font-size:.7rem;color:#6a5a30;width:30px;text-align:right">' + pct + '%</div>';
        html += '</div>';
      });
      html += '</div>';
    }

    // Boutons selon phase
    const dejaCandidatObj = e.candidats && e.candidats.find(c => c.nom === (state.char?.name));
    if (e.phase === 'candidatures' && !dejaCandidatObj) {
      html += '<button onclick="confirmerCandidature(\'' + e.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.3rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;margin-right:.4rem">Me declarer candidat</button>';
    }
    if (e.phase === 'campagne') {
      html += '<button onclick="voterElection(\'' + e.id + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.3rem .7rem;border:1px solid #4a8a4a;background:transparent;color:#6a9a6a;cursor:pointer;margin-right:.4rem">' + (state.aVote?.[e.id] ? 'Vote deja exprime' : 'Voter') + '</button>';
    }
    html += '</div>';
  });

  html += '<div style="font-size:.72rem;color:#9a8a68;font-style:italic;margin-top:.5rem">Calendrier : candidatures semaine 1-3 · campagne semaine 4-5 · resultats dimanche soir.</div>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function voterElection(electionId) {
  if (state.aVote?.[electionId]) {
    showToast('Vote deja exprime', 'Vous avez deja vote pour cette election.', false);
    return;
  }
  const election = (state.electionsEnCours||[]).find(e => e.id === electionId);
  if (!election || !election.candidats || election.candidats.length === 0) return;

  // Afficher la liste des candidats pour voter
  document.getElementById('modal-postes').classList.remove('open');
  document.getElementById('postes-modal-title').textContent = 'Voter — ' + election.nom;
  let html = '<div style="padding:1rem"><div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Vous ne pouvez voter qu\'une seule fois.</div>';
  election.candidats.forEach((c, i) => {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer;transition:background .2s" onclick="confirmerVote(\'' + electionId + '\',' + i + ')" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#c0b090">' + c.nom + '</div>';
    html += '<div style="font-size:.7rem;color:#5a5040">' + (c.isPJ ? 'Joueur' : 'PNJ') + '</div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerVote(electionId, candidatIdx) {
  document.getElementById('modal-postes').classList.remove('open');
  const election = (state.electionsEnCours||[]).find(e => e.id === electionId);
  if (!election) return;
  if (!state.aVote) state.aVote = {};
  state.aVote[electionId] = true;
  election.candidats[candidatIdx].voix = (election.candidats[candidatIdx].voix||0) + 1;
  // Ajouter voix aleatoires PNJ pour simulation
  election.candidats.forEach((c, i) => {
    if (i !== candidatIdx) c.voix = (c.voix||0) + Math.floor(Math.random() * 5);
  });
  showToast('Vote enregistre !', 'Vous avez vote pour ' + election.candidats[candidatIdx].nom, true, true);
  addJournalEntry('Vote exprime pour ' + election.candidats[candidatIdx].nom + ' (' + election.nom + ')', 'event-info');
}

// calculerResultatElection SUPPRIMEE le 27/10/2026 : aucun appelant (audit « une seule verite », §5).

// =====================
// BOITE MAIL
// =====================
function openMailbox() {
  // Unifie avec le module forum — une seule vraie implementation de la messagerie
  if (typeof switchToMail === 'function') {
    switchToMail();
    document.getElementById('modal-forum').classList.add('open');
  } else {
    showToast('Erreur', 'Messagerie indisponible.', false);
  }
}

// =====================
// FORUM EN VUE CENTRALE
// =====================
function openForumView(forumId) {
  if (state.hospitalisation && joursEcoulesHospitalisation() === 0) {
    showToast('Inconscient(e)', 'Vous venez d\'être agressé(e) et n\'êtes pas en état d\'accéder au forum.', false);
    return;
  }
  // Le vrai systeme de forum (sujets, editeur riche, mail) vit dans forum.js (openForum_module).
  // L'ancien systeme local base sur FORUM_TOPICS/buildForumHTML a ete retire d'ici (code mort, jamais utilise).
  openForum_module(forumId);
}

function closeForumView() {
  document.getElementById('vue-forum').classList.remove('active');
  if (state.currentBuilding) {
    document.getElementById('vue-batiment').classList.add('active');
  } else {
    document.getElementById('vue-rue').classList.add('active');
  }
}

function closeMailView() {
  document.getElementById('vue-mail').classList.remove('active');
  // Retourner a la vue precedente
  if (state.currentBuilding) {
    document.getElementById('vue-batiment').classList.add('active');
  } else {
    document.getElementById('vue-rue').classList.add('active');
  }
}


function addExternalEvent(text, scope) {
  const j = document.getElementById('journal');
  const ts = new Date().toISOString();
  const div = document.createElement('div');
  div.className = 'journal-entry journal-external';
  div.innerHTML = `
    <span class="journal-time">${formaterHorodatageJournal(ts)}</span>
    <span class="journal-alert" onclick="this.style.display='none'" title="Cliquer pour marquer comme lu">●</span>
    <span class="journal-text event-external"><strong>${text}</strong></span>
  `;
  j.insertBefore(div, j.firstChild);

  // Partager via Supabase — scope 'local' = visible uniquement dans la ville courante, 'mondial' =
  // visible dans les 4 empires (sentinelle country:'global', voir sbGetEvenementsRecents), sinon national
  if (typeof sbAddEvenementGlobal === 'function') {
    let country = state.country || 'republic';
    let city = null;
    if (scope === 'local') city = state.currentCity || null;
    else if (scope === 'mondial') country = 'global';
    sbAddEvenementGlobal(country, city, text, state.day || 1).catch(() => {});
  }
}

// Charger les événements partagés depuis Supabase et les insérer dans le journal local
// Cache persistant (localStorage) des IDs d'evenements deja affiches, propre a chaque personnage
function _getEvenementsChargesKey() {
  return 'respublica_evtvus_' + (state.char?.name || 'default');
}
function _getEvenementsCharges() {
  try {
    const raw = localStorage.getItem(_getEvenementsChargesKey());
    return raw ? new Set(JSON.parse(raw)) : new Set();
  } catch(e) { return new Set(); }
}
function _saveEvenementsCharges(set) {
  try {
    // Garder seulement les 300 derniers IDs pour ne pas grossir indefiniment
    const arr = Array.from(set).slice(-300);
    localStorage.setItem(_getEvenementsChargesKey(), JSON.stringify(arr));
  } catch(e) {}
}

async function chargerEvenementsPartages() {
  if (typeof sbGetEvenementsRecents !== 'function') return;
  try {
    const rows = await sbGetEvenementsRecents(state.country || 'republic', state.currentCity || 'capitale');
    if (!rows || rows.length === 0) return;
    const j = document.getElementById('journal');
    if (!j) return;
    const dejaVus = _getEvenementsCharges();
    // Trier du plus ancien au plus récent pour insertion cohérente
    const nouveaux = rows.filter(r => !dejaVus.has(r.id)).sort((a,b) => a.id - b.id);
    nouveaux.forEach(r => {
      dejaVus.add(r.id);
      // r.created_at est l'horodatage serveur reel (colonne Supabase deja existante, jamais
      // selectionnee explicitement mais toujours renvoyee par sbGet faute de filtre "select=").
      // Repli honnete sur "Jour X" si absent, sans jamais inventer d'heure.
      const horodatage = formaterHorodatageJournal(r.created_at) || `Jour ${r.jour || '?'}`;
      const div = document.createElement('div');
      div.className = 'journal-entry journal-external';
      div.innerHTML = `
        <span class="journal-time">${horodatage}</span>
        <span class="journal-alert" onclick="this.style.display='none'" title="Cliquer pour marquer comme lu">●</span>
        <span class="journal-text event-external"><strong>${r.texte}</strong></span>
      `;
      j.insertBefore(div, j.firstChild);
    });
    if (nouveaux.length > 0) _saveEvenementsCharges(dejaVus);
  } catch(e) { console.warn('chargerEvenementsPartages error', e); }
}

// Récupère et crédite les dons d'argent reçus de la part d'autres joueurs (depuis Supabase)
async function recupererDonsEnAttente() {
  if (typeof sbRecupererDonsEnAttente !== 'function') return;
  const moi = state.char?.name;
  if (!moi) return;
  try {
    const dons = await sbRecupererDonsEnAttente(moi);
    if (!dons || dons.length === 0) return;
    const cur = COUNTRIES[state.country]?.cur || 'FR';
    // DUPLICATION D'ARGENT CORRIGEE (17 septembre 2026, audit des frontieres d'autorite).
    // Avant : le montant etait additionne au total PUIS sbMarquerDonTraite etait appele avec un
    // .catch(() => {}) decoratif -- or sbUpdate ne leve jamais, il rend null. Si le marquage
    // echouait, le don restait traite=false en base ET l'argent etait quand meme credite : la
    // session suivante le recreditait, et ainsi de suite a chaque connexion. Monnaie dupliquee
    // sans limite, sans que rien ne le signale.
    // Desormais : un don n'est credite QUE si sa consommation est confirmee en base. Un don non
    // marque n'est pas credite et reste en file pour la prochaine tentative -- jamais perdu,
    // jamais double.
    let total = 0;
    let nonConsommes = 0;
    for (const don of dons) {
      const marque = (typeof sbMarquerDonTraite === 'function') ? await sbMarquerDonTraite(don.id) : null;
      if (marque) total += don.montant;
      else nonConsommes++;
    }
    if (total > 0) {
      state.arg = (state.arg || 0) + total;
      if (state.char) state.char.arg = state.arg;
      if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
      updateUI();
      addJournalEntry('💰 Vous avez reçu ' + total + ' ' + cur + ' en dons.', 'event-good');
      showToast('Dons reçus !', '+' + total + ' ' + cur + ' crédité(s) sur votre compte.', true, true);
    }
    if (nonConsommes > 0) {
      console.warn('[dons] ' + nonConsommes + ' don(s) non consommes en base : non credites, reessai a la prochaine connexion.');
    }
  } catch(e) { console.warn('recupererDonsEnAttente error', e); }
}

// Recupere et applique les vols subis (et les credits differes, ex. succession) par le joueur
// depuis sa derniere connexion. Correctif du 20 aout 2026 (chantier testament/succession) :
// vols_en_attente sert aussi a crediter (montant negatif, ex. heritage via traiterSuccession/
// executerSuccession, plateau-personnage.js) -- avant ce correctif, seul totalPerdu (somme des
// montants positifs) declenchait une notification, donc un credit pur (total toujours <=0)
// n'affichait jamais rien au joueur alors que state.arg etait bien crediee en silence. Un seul
// consommateur de recupererVolsEnAttente() existe dans tout le jeu (plateau-core.js, appel unique
// au demarrage de session) : verifie avant modification, comportement des vols (totalPerdu)
// entierement inchange, seul un second cas (totalRecu) est ajoute.
// Objets/matieres (correctif ordre Voler, 22 aout 2026, revise pour eliminer tout risque de
// duplication) : la mutation reelle (retrait chez la victime) est TOUJOURS appliquee ici, quel
// que soit le palier de connaissance decide au moment du vol (confirmerVol,
// plateau-actions-illegales-rumeurs.js).
//
// Visibilite (correctif bloquant, revue du 22 aout 2026) : vols_en_attente n'a PAS de colonne
// revele (verifie en direct : "column vols_en_attente.revele does not exist") -- ce champ,
// introduit a un tour precedent, faisait echouer silencieusement CHAQUE INSERT de vol.js (voir
// confirmerVol, desormais corrige pour ne plus l'envoyer). La visibilite de la victime est
// entierement geree AU MOMENT DU VOL (mail immediat identifie/anonyme/absent selon le palier,
// confirmerVol) -- ce traitement differe n'a donc plus besoin de savoir quoi que ce soit sur le
// palier : il applique simplement la perte reelle, sans jamais reafficher de toast/journal a ce
// sujet (le palier >=75 resterait sinon revele indirectement par un toast generique ici).
//
// Anti-duplication (objet/matiere UNIQUEMENT -- l'argent reste credite immediatement au voleur
// dans confirmerVol, fongible, aucun risque de duplication d'un objet unique) : le voleur n'a
// RIEN recu au moment du vol. C'est CE traitement, ici, sur l'etat reellement a jour de LA
// VICTIME ELLE-MEME, qui retire l'objet SEULEMENT s'il est encore reellement present, ET
// seulement dans ce cas, le met en file pour le voleur via objets_recus (sbDonnerObjetJoueur,
// mecanisme deja existant et deja sur pour les dons entre joueurs, recupere par le voleur via
// verifierObjetsRecus() -- aucune seconde architecture de transfert). Si la victime a deja
// vendu/donne/consomme l'objet avant sa propre reconnexion, rien n'est retire ET rien n'est
// jamais credite au voleur : aucune duplication possible dans aucun des deux cas.
//
// Atomicite retrait/sauvegarde/marquage (revue du 22 aout 2026) : un simple reordonnancement
// (transfert avant mutation) ne suffisait PAS -- entre la mutation de state.inventory et sa
// sauvegarde reelle, sbMarquerVolTraite() pouvait reussir alors que la sauvegarde personnage
// echouait ou n'avait pas encore eu lieu (le debounce 3s d'updateUI()/sbAutoSave() ne garantit
// aucun ordre avec une ecriture immediate et attendue). En cas de crash/fermeture avant que ce
// debounce ne parte, le retrait etait perdu au prochain chargement (rechargement de
// personnages.inventory encore intact) alors que objets_recus, LUI, avait deja durablement recu
// le butin -- duplication definitive. Correctif : sbSavePersonnage() est desormais attendue
// EXPLICITEMENT ici (jamais via le debounce) avant tout marquage.
//
// Confirmation du don (revue du 22 aout 2026, correctif du marqueur) : verifier objets_recus pour
// detecter un don deja confirme lors d'un retry (via un ancien marqueur __volId) s'est revele
// PEU FIABLE -- verifierObjetsRecus() SUPPRIME la ligne objets_recus des que le voleur l'a
// effectivement recuperee (sbSupprimerObjetRecu). Si le voleur recupere son butin (jusqu'a 2 min
// apres, ou au demarrage de sa session) AVANT que la victime ne retente le meme vol.id, la ligne
// n'existe plus -- le retry ne verrait plus aucune trace du don deja effectue et rappellerait
// sbDonnerObjetJoueur(), doublant le butin. Corrige en marquant la confirmation du don
// DIRECTEMENT sur la ligne vols_en_attente elle-meme (jamais supprimee par un tiers) : la colonne
// EXISTANTE type_butin (deja une colonne texte libre, aucune migration) prend la valeur
// 'matiere_confirmee'/'objet_confirme' juste apres le succes de sbDonnerObjetJoueur, AVANT toute
// mutation locale. Un retry reconnait cette valeur et ne rappelle plus jamais
// sbDonnerObjetJoueur() pour ce vol.id, meme si objets_recus a deja ete vide entre-temps -- seuls
// le retrait et la sauvegarde restent a retenter. Risque residuel assume et documente : si cette
// ecriture de confirmation echoue elle-meme juste apres le succes de sbDonnerObjetJoueur (deux
// echecs reseau consecutifs sur le meme vol), le retry ne verrait pas la confirmation et
// pourrait redonner une copie -- fenetre desormais bornee a un echec propre a nos deux ecritures,
// independante du delai de recuperation du voleur.
async function recupererVolsEnAttente() {
  if (typeof sbRecupererVolsEnAttente !== 'function') return;
  const moi = state.char?.name;
  if (!moi) return;
  try {
    const vols = await sbRecupererVolsEnAttente(moi);
    if (!vols || vols.length === 0) return;
    const cur = COUNTRIES[state.country]?.cur || 'FR';
    let totalRecu = 0;
    let mutationAppliquee = false;
    let inventaireModifie = false;
    const volsAMarquer = [];

    for (const vol of vols) {
      let resoluCeVol = true; // false uniquement si un transfert objet/matiere reste a confirmer
      if (vol.type_butin === 'argent') {
        const montant = vol.montant || 0;
        if (montant !== 0) mutationAppliquee = true;
        if (montant < 0) totalRecu += -montant; // credit pur : toujours notifie (jamais issu du vol, cas hors perimetre de ce lot)
        state.arg = Math.max(0, (state.arg || 0) - montant);
      } else if ((vol.type_butin === 'matiere' || vol.type_butin === 'matiere_confirmee') && vol.objet_id) {
        const stack = (state.inventory || []).find(i => i.stackable && i.stackKey === vol.objet_id);
        if (stack) {
          const perte = Math.min(vol.montant || 0, stack.qty || 0);
          if (perte > 0) {
            let transfereOk = vol.type_butin === 'matiere_confirmee';
            if (!transfereOk) {
              // DEPOT ATTESTE (17 septembre 2026, fermeture du P0 objets_recus). Le serveur relit
              // la ligne de vol, exige que l'acteur en soit la victime et le destinataire le
              // voleur, puis depose le butin ET bascule type_butin dans la MEME transaction --
              // le marquage etait auparavant une seconde requete qui pouvait rester en arriere.
              // On lit desormais r.ok : l'ancien `.then(() => true)` comptait comme un succes un
              // sbInsert qui avait renvoye null, et la victime perdait alors son bien pour rien.
              const rDepot = vol.voleur && typeof sbObjetSasDeposer === 'function'
                ? await sbObjetSasDeposer('butin_vol', vol.voleur,
                    { name: stack.name, icon: stack.icon, stackable: true, stackKey: vol.objet_id, qty: perte },
                    vol.id).catch(() => null)
                : null;
              transfereOk = !!(rDepot && rDepot.ok === true);
            }
            if (transfereOk) {
              stack.qty = (stack.qty || 0) - perte;
              if (stack.qty <= 0) state.inventory = state.inventory.filter(i => i !== stack);
              mutationAppliquee = true;
              inventaireModifie = true;
            } else {
              resoluCeVol = false; // transfert non confirme : le bien reste chez la victime, rien perdu
            }
          }
        }
      } else if ((vol.type_butin === 'objet' || vol.type_butin === 'objet_confirme') && vol.objet_id) {
        const idx = (state.inventory || []).findIndex(i => i.id === vol.objet_id);
        if (idx !== -1) {
          let transfereOk = vol.type_butin === 'objet_confirme';
          if (!transfereOk) {
            // Meme depot atteste que pour la matiere ci-dessus : la ligne de vol fait foi, et le
            // marquage objet_confirme se fait dans la meme transaction que le depot.
            const rDepotObjet = vol.voleur && typeof sbObjetSasDeposer === 'function'
              ? await sbObjetSasDeposer('butin_vol', vol.voleur,
                  { ...state.inventory[idx] }, vol.id).catch(() => null)
              : null;
            transfereOk = !!(rDepotObjet && rDepotObjet.ok === true);
          }
          if (transfereOk) {
            state.inventory.splice(idx, 1);
            mutationAppliquee = true;
            inventaireModifie = true;
          } else {
            resoluCeVol = false; // transfert non confirme : l'objet reste chez la victime, rien perdu
          }
        }
      }
      if (resoluCeVol) volsAMarquer.push(vol.id);
    }

    // Sauvegarde durable AVANT tout marquage (correctif atomicite ci-dessus) : une seule fois
    // pour toute la serie, explicitement attendue -- jamais le debounce de sbAutoSave().
    let sauvegardeOk = true;
    if (mutationAppliquee) {
      sauvegardeOk = typeof sbSavePersonnage === 'function'
        ? await sbSavePersonnage(state).then(() => true).catch(() => false)
        : false;
    }

    if (!sauvegardeOk) return; // rien de marque, rien de notifie -- tout sera retente au prochain passage

    for (const id of volsAMarquer) {
      if (typeof sbMarquerVolTraite === 'function') await sbMarquerVolTraite(id).catch(() => {});
    }
    if (mutationAppliquee) {
      updateUI();
      if (inventaireModifie && typeof renderInventory === 'function') renderInventory();
    }
    // Aucun toast/journal ici pour une perte issue d'un vol (correctif visibilite ci-dessus) : la
    // victime a deja ete informee au moment du vol si son palier le prevoyait (mail immediat,
    // confirmerVol) ; reafficher quoi que ce soit ici reviendrait a reveler indirectement les
    // vols du palier >=75, qui ne doivent jamais etre notifies.
    if (totalRecu > 0) {
      addJournalEntry('💰 Une somme de ' + totalRecu + ' ' + cur + ' a été créditée sur votre compte.', 'event-good');
      showToast('Somme créditée', '+' + totalRecu + ' ' + cur + ' crédité(s) sur votre compte.', true, true);
    }
  } catch(e) { console.warn('recupererVolsEnAttente error', e); }
}

// Recupere et applique les impacts d'indices en attente (ex: consequence d'une fausse rumeur)
async function recupererImpactsEnAttente() {
  if (typeof sbRecupererImpactsEnAttente !== 'function') return;
  const moi = state.char?.name;
  if (!moi) return;
  try {
    const impacts = await sbRecupererImpactsEnAttente(moi);
    if (!impacts || impacts.length === 0) return;
    let resume = [];
    for (const imp of impacts) {
      if (imp.indice === 'pop') { state.pop = Math.max(0, Math.min(100, (state.pop || 0) + imp.delta)); resume.push(imp.delta + ' POP'); }
      if (imp.indice === 'inf') { state.inf = Math.max(0, Math.min(100, (state.inf || 0) + imp.delta)); resume.push(imp.delta + ' INF'); }
      if (imp.indice === 'dis') { state.dis = Math.max(0, Math.min(100, (state.dis || 50) + imp.delta)); resume.push(imp.delta + ' DIS'); }
      // Bonus Moral expediteur d'une carte postale lue pour la premiere fois (Lot 4, 23 aout
      // 2026) : mecanisme deja generique reutilise tel quel (aucune deuxieme file d'attente).
      // Plafond quotidien EXPEDITEUR (regle definitive de Fred) : au plus une seule occurrence de
      // ce bonus par jour reel (Europe/Paris), tous destinataires/cartes confondus, meme si
      // plusieurs cartes ont ete lues le meme jour -- verifie ICI, au moment ou l'expediteur
      // recupere effectivement le credit (jamais au moment de la lecture par le destinataire, qui
      // ignore tout de l'etat/l'horloge de l'expediteur, potentiellement hors-ligne). Une carte
      // au-dela du plafond du jour est simplement consommee sans credit -- jamais retentee, la
      // ligne est marquee traitee comme les autres ci-dessous.
      if (imp.indice === 'moral_carte_postale') {
        // cartePostaleMoralJour : colonne PERSISTEE (personnages.carte_postale_moral_jour,
        // supabase.js), jamais un state.* suppose sauvegarde implicitement -- meme champ partage
        // avec le plafond LECTEUR (lireCartePostale, plateau-personnage.js), sous-cles distinctes.
        const jourDuJour = typeof dateReelleParisStr === 'function' ? dateReelleParisStr() : null;
        if (!state.cartePostaleMoralJour) state.cartePostaleMoralJour = { lecteur: null, expediteur: null };
        if (jourDuJour && state.cartePostaleMoralJour.expediteur !== jourDuJour) {
          state.moral = Math.min(100, Math.max(0, (state.moral || 0) + imp.delta));
          state.cartePostaleMoralJour.expediteur = jourDuJour;
          resume.push(imp.delta + ' Moral (carte postale)');
        }
        // Que le plafond du jour soit deja atteint ou non, sbMarquerImpactTraite(imp.id) est
        // TOUJOURS appele plus bas (hors de ce bloc, comme pour tous les indices) : une carte
        // au-dela du plafond est consommee definitivement, jamais retentee un jour suivant.
      }
      if (imp.indice === 'hp_set') {
        state.hp = Math.max(0, imp.delta);
        state.regenJour = state.day;
        resume.push('⚔️ Agression ! PV tombés à ' + imp.delta);

        if (!state.statsAffaiblies) state.statsAffaiblies = {};
        const STATS_POSSIBLES = ['INT','CHA','VOL','PER','DUP','ENT'];
        const statsTouchees = STATS_POSSIBLES.slice().sort(() => Math.random() - 0.5).slice(0, 2);
        statsTouchees.forEach(s => { state.statsAffaiblies[s] = true; });

        if (typeof declencherHospitalisation === 'function') declencherHospitalisation(imp.palier);
        // §19 : declencherHospitalisation sauvegarde deja, mais hp/statsAffaiblies/regenJour sont
        // poses juste au-dessus, AVANT son appel -- ce filet garantit qu'ils partent en base meme
        // si la fonction venait a manquer.
        else if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
      }
      if (imp.indice === 'poison_start') {
        // Depose par crime_empoisonner (27/10/2026) : type de poison et statistiques touchees dans details.
        const det = imp.details || {};
        state.empoisonnement = { actif: true, palier: imp.palier, poisonType: det.poisonType || null };
        if (!state.statsAffaiblies) state.statsAffaiblies = {};
        (det.statsTouchees || []).forEach(s => { state.statsAffaiblies[s] = true; });
        if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
        resume.push('☠️ Empoisonnement en cours...');
      }
      if (typeof sbMarquerImpactTraite === 'function') await sbMarquerImpactTraite(imp.id).catch(() => {});
    }
    if (resume.length > 0) {
      updateUI();
      const agrappe = resume.some(r => r.includes('Agression'));
      const empoisonne = resume.some(r => r.includes('Empoisonnement'));
      if (agrappe) {
        showToast('Agression !', 'Vous avez été attaqué(e). PV : ' + state.hp + '. Récupération : +10/jour.', false, true);
        addJournalEntry('Vous avez été victime d\'une agression. Vos PV sont tombés à ' + state.hp + '.', 'event-bad');
      } else if (empoisonne) {
        showToast('Malaise suspect', 'Vous ne vous sentez pas bien... quelque chose ne va pas. Soignez-vous avant votre prochain sommeil.', false, true);
        addJournalEntry('Un malaise suspect vous gagne. Vous pourriez avoir été empoisonné(e).', 'event-bad');
      } else if (resume.some(r => r.includes('carte postale'))) {
        // Branche dediee (Lot 4, 23 aout 2026) : une correspondance recue par un autre joueur,
        // jamais un evenement negatif -- evite le libelle generique "affecte vos indices"/le
        // toast "bad" ci-dessous, inadapte a un gain de Moral.
        showToast('Correspondance lue', 'Une carte postale que vous avez envoyée a été lue. +10 Moral.', true, true);
        addJournalEntry('Une carte postale que vous avez envoyée a été lue. +10 Moral.', 'event-good');
      } else {
        addJournalEntry('Des événements ont affecté vos indices : ' + resume.join(', ') + '.', 'event-bad');
        showToast('Indices modifiés', resume.join(', '), false, true);
      }
    }
  } catch(e) { console.warn('recupererImpactsEnAttente error', e); }
}

// Regeneration naturelle des PV (+10/jour) apres une agression — appelee a minuit dans runMidnightUpdate
// appliquerRegenerationNaturelle SUPPRIMEE le 8 septembre 2026. Elle etait morte : aucun appelant
// dans aucun .js, .html ni api/. Son unique appel avait ete retire du passage de minuit
// INTENTIONNELLEMENT (« regeneration retiree du cron », 18 juillet 2026), et la mecanique vit
// depuis dans doDormir (plateau-personnage.js) -- meme garde state.regenJour, meme +10 PV, meme
// libelle de journal. On supprimait donc un doublon exact d'une logique vivante ailleurs.

// Archives police — liste des prisonniers
// Registre unique des archives de police : fusionne les vraies detentions de PJ (en direct,
// depuis Supabase) et les affaires historiques anterieures au lancement du jeu (definies en
// code, extensibles). Recherche par nom (les deux sources) ou par decennie (les deux sources,
// grace au champ created_at desormais fiable sur les vraies detentions).
const ENIGME1_ARCHIVES_HISTORIQUES = [
  {
    nom: 'Maurice Caillon',
    anneeDebut: 1948,
    anneeFin: 1949,
    motif: "Assassinat de Gaston Blanaz, conseiller municipal et opposant déclaré au projet industriel sur la parcelle B-127. Le corps de la victime a été découvert enterré sur le site, alors en construction pour le compte de l'entrepreneur Jacques Moulin. Caillon résidait sur place, dans la maison de gardien du site industriel.",
    issue: 'Acquitté en appel en 1949.'
  }
];

async function doArchivesPolice(pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  document.getElementById('postes-modal-title').textContent = 'Archives de Police';
  document.getElementById('postes-body').innerHTML = enigme1HtmlRechercheArchivesPolice();
  document.getElementById('modal-postes').classList.add('open');

  // Registre carcerale local (26 aout 2026) : le registre d'un commissariat ne doit montrer que
  // les incarcerations reellement executees dans SA ville -- jamais tout le pays.
  if (typeof sbLoadDetentions === 'function') {
    try {
      state._detentionsReelles = await sbLoadDetentions(state.country, state.currentCity) || [];
    } catch(e) { state._detentionsReelles = []; }
  } else {
    state._detentionsReelles = [];
  }
  state._archivesUiCache = null;
}

function enigme1HtmlRechercheArchivesPolice() {
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">Recherchez par nom ou par décennie (arrestations passées, en cours, et affaires historiques).</div>';
  html += '<div style="display:flex;gap:.4rem;margin-bottom:.4rem">';
  html += '<input id="archives-police-nom" type="text" placeholder="Nom..." style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '<input id="archives-police-decennie" type="text" placeholder="Décennie (ex: 1940)" style="width:150px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="enigme1LancerRechercheArchivesPolice()"><i class="ti ti-search" style="font-size:.85rem"></i> Rechercher</button>';
  html += '<div id="archives-police-resultats" style="margin-top:.9rem"></div>';
  html += '</div>';
  return html;
}

function enigme1LancerRechercheArchivesPolice() {
  const nomInput = document.getElementById('archives-police-nom');
  const decennieInput = document.getElementById('archives-police-decennie');
  const nom = nomInput ? nomInput.value : '';
  const decennie = decennieInput ? decennieInput.value : '';
  const resultatsEl = document.getElementById('archives-police-resultats');
  if (!resultatsEl) return;

  if (!nom.trim() && !decennie.trim()) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Indiquez au moins un nom ou une décennie.</div>';
    return;
  }

  const nomLower = nom.trim().toLowerCase();
  const decDebut = decennie.trim() ? parseInt(decennie.trim(), 10) : null;
  const decFin = decDebut !== null ? decDebut + 9 : null;

  const historiques = ENIGME1_ARCHIVES_HISTORIQUES.filter(function(a) {
    if (nomLower && a.nom.toLowerCase().indexOf(nomLower) === -1) return false;
    if (decDebut !== null) {
      const chevauche = a.anneeFin >= decDebut && a.anneeDebut <= decFin;
      if (!chevauche) return false;
    }
    return true;
  });

  const reels = (state._detentionsReelles || []).filter(function(d) {
    if (nomLower && d.nom.toLowerCase().indexOf(nomLower) === -1) return false;
    if (decDebut !== null) {
      if (!d.created_at) return false;
      const annee = new Date(d.created_at).getFullYear();
      if (annee < decDebut || annee > decFin) return false;
    }
    return true;
  });

  if (historiques.length === 0 && reels.length === 0) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Aucun résultat.</div>';
    return;
  }

  let html = '<div style="display:flex;flex-direction:column;gap:.4rem">';
  historiques.forEach(function(a) {
    const nomEchap = a.nom.replace(/'/g, "\'");
    html += '<div onclick="enigme1AfficherArchiveHistorique(\'' + nomEchap + '\')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<div style="display:flex;justify-content:space-between"><span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + a.nom + '</span><span style="font-size:.7rem;color:#5a4030">' + a.anneeDebut + '–' + a.anneeFin + '</span></div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">Affaire historique</div>';
    html += '</div>';
  });
  reels.forEach(function(d, i) {
    const annee = d.created_at ? new Date(d.created_at).getFullYear() : '?';
    const duree = (d.jour_fin && d.jour_debut) ? (d.jour_fin - d.jour_debut) + ' jour(s)' : 'en cours';
    html += '<div onclick="ouvrirDetailDetention(' + i + ')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<div style="display:flex;justify-content:space-between"><span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + d.nom + '</span><span style="font-size:.7rem;color:#5a4030">' + annee + ' · ' + duree + '</span></div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">' + d.raison + '</div>';
    html += '</div>';
  });
  html += '</div>';
  resultatsEl.innerHTML = html;

  // Correction du bug _detentionsAffichees (jamais alimente auparavant -- ouvrirDetailDetention
  // lisait un tableau toujours vide) + cache de la recherche pour permettre un retour naturel
  // vers ces memes resultats depuis la fiche detaillee, sans relancer la recherche.
  state._detentionsAffichees = reels;
  state._archivesUiCache = { nom, decennie, html: resultatsEl.innerHTML };
}

// Reaffiche le formulaire de recherche des archives avec les resultats precedents (nom/decennie
// saisis + liste), sans nouvel appel Supabase -- permet de revenir depuis une fiche detaillee
// sans perdre la recherche en cours.
function enigme1RevenirResultatsArchives() {
  document.getElementById('postes-modal-title').textContent = 'Archives de Police';
  document.getElementById('postes-body').innerHTML = enigme1HtmlRechercheArchivesPolice();
  const cache = state._archivesUiCache;
  if (!cache) return;
  const nomInput = document.getElementById('archives-police-nom');
  const decennieInput = document.getElementById('archives-police-decennie');
  const resultatsEl = document.getElementById('archives-police-resultats');
  if (nomInput) nomInput.value = cache.nom || '';
  if (decennieInput) decennieInput.value = cache.decennie || '';
  if (resultatsEl) resultatsEl.innerHTML = cache.html || '';
}

function enigme1AfficherArchiveHistorique(nom) {
  const a = ENIGME1_ARCHIVES_HISTORIQUES.find(function(x) { return x.nom === nom; });
  if (!a) return;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.2rem">' + a.nom + '</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">Arrêté en ' + a.anneeDebut + '</div>';
  html += '<div style="font-size:.85rem;color:#e0d8c0;line-height:1.5;margin-bottom:.6rem">' + a.motif + '</div>';
  html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">' + a.issue + '</div>';
  html += '<button class="pnj-action-btn" onclick="doArchivesPolice()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Nouvelle recherche</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;

  if (a.nom === 'Maurice Caillon' && typeof enigme1DossierCocherCase === 'function') {
    enigme1DossierCocherCase('commissariat');
  }
}

// Formate un timestamp reel (colonne Postgres ou new Date().toISOString()) en date calendaire
// francaise longue ("26 aout 2026"), calee sur Europe/Paris -- meme conversion que
// dateReelleParisStr()/formatDateHeureJeu() (plateau-core.js), format long car destine a un
// affichage narratif plutot qu'a une horloge. Retourne null si aucune date reelle n'est
// disponible : jamais de date inventee ni deduite d'un jour de jeu (lot "dates reelles",
// 26 aout 2026).
function formatDateRegistre(iso) {
  if (!iso) return null;
  const d = new Date(iso);
  if (isNaN(d.getTime())) return null;
  const frDate = new Date(d.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  return frDate.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
}

// Libelle honnete a associer a motifs[].date_evenement selon sa source (lot "dates reelles",
// precise le 26 aout 2026) : ce timestamp n'est la date du FAIT lui-meme que pour les sources ou
// le fait et sa constatation sont simultanes (flagrant delit, evasion, evenement en detention).
// Pour un demasquage differe (enquete) ou un jugement, il ne represente QUE cet evenement-la --
// jamais le fait d'origine, dont la date reelle n'est de toute facon pas connue (voir jour_fait,
// jamais affiche). 'jugement' n'apparait pas ici : ces motifs sont regroupes dans la ligne
// "Condamnation" separee ci-dessous, jamais redates inline pour eviter la redondance.
const LIBELLE_DATE_MOTIF = {
  flagrant_delit: 'constaté le',
  flagrant_delit_recherche: 'arrestation le',
  garde_a_vue: 'démasquage le',
  evasion: 'évasion le',
  evenement_detention: 'survenu le',
  legacy: 'enregistré le'
};

// Fiche detaillee d'une incarceration (registre carcerale, 26 aout 2026 ; dates reelles,
// 26 aout 2026). Doit supporter sans erreur les anciennes lignes (pauvres : nom/raison/ville/
// dates internes/qhs seulement, tous les nouveaux champs a null/absents) et les nouvelles
// (motifs structures + informations judiciaires + continuite + dates reelles). N'invente jamais
// une donnee absente : chaque rubrique enrichie n'est affichee que si elle existe reellement sur
// la ligne. Plus aucun "jour X" affiche au joueur : les jours de jeu (jour_debut, jour_fin,
// jour_fait, jour_affaire...) restent des compteurs internes, jamais exposes tels quels ici --
// seules les vraies dates (created_at, motifs[].date_evenement, date_fin_effective) et les DUREES
// en jours (jamais des points dans le temps) sont affichees. Chaque date affichee porte un
// libelle qui reflete honnetement ce qu'elle mesure (LIBELLE_DATE_MOTIF ci-dessus) : jamais
// presentee comme "date des faits" quand ce n'est pas le cas.
function ouvrirDetailDetention(idx) {
  const d = (state._detentionsAffichees || [])[idx];
  if (!d) return;
  document.getElementById('postes-modal-title').textContent = 'Détention — ' + d.nom;

  const motifs = Array.isArray(d.motifs) ? d.motifs : null;
  const dureeInitiale = (d.jour_fin != null && d.jour_debut != null) ? (d.jour_fin - d.jour_debut) : null;
  // created_at est un timestamp Postgres natif, present sur TOUTES les lignes (anciennes et
  // nouvelles) puisqu'il est fixe automatiquement a l'insertion -- reutilise directement comme
  // date reelle d'incarceration, sans duplication ni nouvelle colonne (audit dedie).
  const dateIncarceration = formatDateRegistre(d.created_at);

  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Playfair Display,serif;font-size:.95rem;color:#E8C97A;margin-bottom:.2rem">' + d.nom + '</div>';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">' + (d.city || '?') + (d.country ? ' · ' + d.country : '') + '</div>';

  // dateCondamnation = date reelle du JUGEMENT (motif source:'jugement'), jamais celle des faits
  // d'origine -- voir le commentaire de factCommun dans appliquerSentence (plateau-justice-
  // economie.js).
  let dateCondamnation = null;
  if (motifs && motifs.length) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.3rem">MOTIFS</div>';
    let total = 0;
    motifs.forEach(function(m) {
      if (m.jours != null) total += m.jours;
      if (!dateCondamnation && m.source === 'jugement' && m.date_evenement) dateCondamnation = formatDateRegistre(m.date_evenement);
      html += '<div style="font-size:.8rem;color:#c0b090;margin-bottom:.1rem">— ' + (m.type || 'Motif') + (m.jours != null ? ' : ' + m.jours + ' jour(s)' : '') + '</div>';
      const details = [];
      if (m.cible) details.push('victime/cible : ' + m.cible);
      // 'jugement' est deja restitue separement (ligne "Condamnation" ci-dessous) -- jamais
      // redate ici pour eviter une redondance ou, pire, une lecture "date des faits".
      if (m.source !== 'jugement') {
        const dateMotif = formatDateRegistre(m.date_evenement);
        if (dateMotif) details.push((LIBELLE_DATE_MOTIF[m.source] || 'daté le') + ' ' + dateMotif);
      }
      if (m.city) details.push(m.city);
      if (m.detail) details.push(m.detail);
      if (details.length) html += '<div style="font-size:.7rem;color:#6a5a30;margin:0 0 .3rem .8rem;font-style:italic">' + details.join(' · ') + '</div>';
    });
    if (motifs.length > 1) html += '<div style="font-size:.76rem;color:#9a8a4a;margin-top:.2rem">Total des motifs : ' + total + ' jour(s)</div>';
  } else {
    html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">Motif : ' + d.raison + '</div>';
  }

  if (d.ville_condamnation && d.ville_condamnation !== d.city) {
    html += '<div style="font-size:.72rem;color:#6a5a30;margin-top:.4rem">Condamné(e) à ' + d.ville_condamnation + ', incarcéré(e) à ' + d.city + '</div>';
  }
  if (dateCondamnation) html += '<div style="font-size:.72rem;color:#6a5a30">Condamnation : ' + dateCondamnation + '</div>';
  if (d.issue_judiciaire) html += '<div style="font-size:.72rem;color:#6a5a30">Issue judiciaire : ' + d.issue_judiciaire + '</div>';
  if (d.autorite) html += '<div style="font-size:.72rem;color:#6a5a30">Autorité : ' + d.autorite + '</div>';

  html += '<div style="margin-top:.6rem;border-top:1px solid #2a2010;padding-top:.5rem">';
  if (dateIncarceration) html += '<div style="font-size:.78rem;color:#c0b090">Incarcération : ' + dateIncarceration + '</div>';
  if (dureeInitiale != null) html += '<div style="font-size:.78rem;color:#c0b090">Peine initiale : ' + dureeInitiale + ' jour(s)</div>';
  // Temps restant : uniquement calcule quand la fiche consultee est celle du personnage qui la
  // consulte lui-meme (meme personnage => meme compteur state.day, comparaison interne valide),
  // et seulement pour une ligne du nouveau systeme encore active (motifs present, pas de
  // mode_fin) -- jamais pour la detention d'un tiers (deux compteurs de jours de personnages
  // differents, sans correspondance fiable, voir audit dedie), et jamais pour une ancienne ligne
  // dont le statut reel n'est de toute facon pas connu.
  if (!d.mode_fin && motifs && d.jour_fin != null && d.nom === state.char?.name && typeof state.day === 'number') {
    html += '<div style="font-size:.78rem;color:#c0b090">Temps restant : ' + Math.max(0, d.jour_fin - state.day) + ' jour(s)</div>';
  }
  if (d.reduction_jours) html += '<div style="font-size:.78rem;color:#6a9a6a">Réduction de peine : ' + d.reduction_jours + ' jour(s)</div>';
  if (d.reliquat_jours != null) html += '<div style="font-size:.78rem;color:#9a8a4a">Reliquat lors de la reprise : ' + d.reliquat_jours + ' jour(s)</div>';

  // mode_fin indique la NATURE de la fin ; date_fin_effective (timestamp reel, capture a
  // l'instant meme de l'evenement) indique QUAND -- jour_fin_effective (jour de jeu interne)
  // n'est plus affiche. Le libelle ne parle de "Libération" que pour les deux modes qui en sont
  // reellement une ; les autres parlent de "Fin effective", pour ne pas laisser croire a une
  // sortie de detention qui n'a pas eu lieu (evasion, transfert QHS).
  // SEPT MODES, ET IL EN MANQUAIT TROIS (10 octobre 2026). `grace_presidentielle` existait en base
  // depuis le chantier de la grâce, et les deux modes de la désertion viennent d'être ajoutés :
  // aucun des trois n'était ici. Or le code tombe sur « En cours » quand le mode est inconnu de
  // cette table — **le registre carcéral affichait donc « En cours » pour un gracié**. Le défaut
  // était bien « le registre déclare détenu un personnage libre », et il avait deux moitiés : la
  // ligne jamais close, et le libellé jamais écrit. Celle-ci est l'autre moitié.
  // `anticipee_avocat` RETIRE le 13 octobre 2026 : la requete d'avocat tiree au hasard
  // n'existe plus, aucune porte ne produit plus ce mode, et `detentions` n'en porte aucune
  // ligne. Un libelle sans producteur est un faux document.
  const modeFinLabels = { purgee: 'Peine purgée',
    evasion: 'Évasion', transfert_qhs: 'Transfert au QHS',
    grace_presidentielle: 'Grâce présidentielle',
    poursuites_eteintes: 'Poursuites éteintes (démobilisation)',
    incorporation: 'Incorporation (transfert à la caserne)' };
  // « Libération » ou « Fin effective » : seuls les modes qui rendent réellement la liberté de
  // circuler sont une libération. L'incorporation n'en est pas une — l'intéressé part à la
  // caserne, il ne rentre pas chez lui — pas plus que l'évasion ou le transfert au QHS.
  const estUneLiberation = { purgee: true, evasion: false,
    transfert_qhs: false, grace_presidentielle: true, poursuites_eteintes: true,
    incorporation: false };
  let statutTexte, statutCouleur;
  if (d.mode_fin && modeFinLabels[d.mode_fin]) {
    statutTexte = modeFinLabels[d.mode_fin];
    // Rouge pour l'evasion, ambre pour les deux TRANSFERTS -- QHS et caserne : l'interesse n'est
    // pas libre. Vert pour tout ce qui rend reellement la liberte de circuler.
    statutCouleur = d.mode_fin === 'evasion' ? '#cc4444'
      : ((d.mode_fin === 'transfert_qhs' || d.mode_fin === 'incorporation') ? '#9a8a4a' : '#6a9a6a');
  } else if (!motifs) {
    // Ancienne ligne (anterieure au lot registre carceral) : l'absence de mode_fin signifie
    // seulement que l'ancien systeme n'enregistrait jamais la sortie reelle -- PAS que la
    // detention est toujours active aujourd'hui.
    statutTexte = 'Statut historique incomplet — fin non constatée';
    statutCouleur = '#8a8060';
  } else {
    statutTexte = 'En cours';
    statutCouleur = '#8a8060';
  }
  html += '<div style="font-size:.78rem;color:' + statutCouleur + '">Statut : ' + statutTexte + '</div>';

  const dateFinEffective = formatDateRegistre(d.date_fin_effective);
  if (dateFinEffective) {
    const libelleFin = estUneLiberation[d.mode_fin] ? 'Libération' : 'Fin effective';
    html += '<div style="font-size:.78rem;color:' + statutCouleur + '">' + libelleFin + ' : ' + dateFinEffective + '</div>';
  }

  // SECRET DU QHS (25 septembre 2026, arbitrage GD) : ces archives sont publiques -- l'ordre
  // archives_police se decrit comme « consultables par tous » -- et le placement au QHS ne doit
  // jamais y figurer. La colonne `qhs` n'est d'ailleurs plus lisible par le role du joueur.
  html += '</div>';

  if (d.detention_precedente_id) {
    html += '<div style="font-size:.7rem;color:#6a5a30;margin-top:.5rem;font-style:italic">Fait suite à une détention antérieure interrompue.</div>';
  }

  html += '<button class="pnj-action-btn" onclick="enigme1RevenirResultatsArchives()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Retour aux résultats</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Notification mail simple.
//
// CORRECTIF DU 8 SEPTEMBRE 2026 -- LE MAIL PART MAINTENANT POUR DE BON.
// state.mails vit sur la racine de state : il n'est ni serialise en localStorage (seul state.char
// l'est), ni inclus dans le payload de sbSavePersonnage, et surtout AUCUN ECRAN NE LE RESTITUE --
// la boite aux lettres (forum.js) lit exclusivement la table Supabase via sbGetMailsFor(). Les
// vingt et un avis systeme qui passent par ici (liberation de prison, convocation douaniere,
// resultat d'election, expulsion d'un local, reduction de peine plaidee par l'avocat, caisse de
// fret en route...) incrementaient donc le badge « nouveau mail » sans que le joueur puisse jamais
// en ouvrir un seul : il voyait un compteur, jamais un texte.
// On conserve integralement le comportement local (file + badge + evenement) et on ajoute l'envoi
// reel sur le canal qui, lui, est lu. Le destinataire est toujours le joueur lui-meme : ces avis
// s'adressent sans exception a celui qui les declenche.
function addMailNotification(from, subject, body) {
  if (!state.mails) state.mails = [];
  state.mails.push({ from, subject, body, day: state.day, time: formatDateHeureJeu(), read: false });
  if (state.char?.name && typeof sbSendMail === 'function') {
    sbSendMail(from, state.char.name, subject, body,
      typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }
  addExternalEvent(`Nouveau mail de ${from} : "${subject}"`);
  // Mettre a jour le badge immediatement
  const unread = state.mails.filter(m => !m.read).length;
  const badge = document.getElementById('mail-badge');
  if (badge) { badge.textContent = unread; badge.style.display = unread > 0 ? 'inline' : 'none'; }
}

// =====================
// PORTRAIT DE JODIE MOITOUT ("Un jour, un portrait", lot du 21 aout 2026) -- remplace
// INTEGRALEMENT l'ancien mecanisme d'accueil de Jodie (invitation a se presenter sur le Forum
// Local). Cet ancien mecanisme n'a jamais tourne en production (son flag JODIE_MAIL_ACCUEIL_ACTIVE
// valait false depuis sa creation le 20 aout 2026, aucun mail de ce type n'a donc jamais ete
// envoye a un vrai joueur) -- son code est retire ici plutot que laisse en dormance, pour qu'il
// ne puisse plus jamais etre reactive par erreur (plus de flag a repasser a true). Nouveau
// concept : Jodie, journaliste a L'Autruche Entravee (groupe La Tribune), propose un petit
// portrait/interview publie dans Presse & Medias -- jamais une auto-presentation joueur.
//
// Point d'entree unique jodiePortraitVerifierProposition(), appelee une fois par session au MEME
// ancrage que l'ancien mecanisme (plateau-core.js, callback post-synchronisation Supabase de
// loadCharacter()) : jamais le jour meme de la creation du personnage (personnages.created_at,
// colonne Postgres native jamais reecrite -- meme source que l'ancien mecanisme), et jamais deux
// fois -- couvre aussi bien un personnage tout juste cree qu'un personnage ancien jamais encore
// contacte (la verification ne depend que de l'ABSENCE du mail en base, jamais d'une date de
// deploiement).
//
// Idempotence SANS nouvelle table/colonne (revision du 21 aout 2026, apres verification precise
// du comportement UI reel) : le mail de PROPOSITION n'est PLUS archive a l'envoi -- il doit
// apparaitre normalement dans Messages Recus, garder son etat non lu standard et declencher le
// voyant Mail comme n'importe quel autre mail (un archivage immediat le sortait silencieusement
// de "Messages Recus", visible seulement dans une section "Archives" sans aucun indice de
// nouveaute -- comportement incorrect, corrige ici). Consequence acceptee explicitement : si ce
// mail n'est ensuite ni lu/archive ni refuse, purgerVieuxMails() (cron, 14 jours) peut le
// supprimer, et un PJ qui n'a jamais repondu peut alors recevoir une nouvelle proposition plus
// tard -- CE N'EST PAS UN REFUS, ce comportement est voulu.
//
// Le mail de REFUS, en revanche, reste archive immediatement a l'envoi (sbSetMailArchived,
// primitive deja existante, forum.js/toggleArchiveMail) : c'est desormais L'AUTORITE PERSISTANTE
// unique de l'etat "refuse" (section 2 du lot), qui doit survivre indefiniment a la purge des 14
// jours -- "des qu'un refus explicite existe, aucune relance n'est autorisee" ne tolere aucune
// fenetre de disparition. Cette autorite est verifiee a DEUX niveaux independants (aucun des deux
// seul ne suffit) : jodiePortraitADejaRefuse() interroge Supabase directement (jamais un simple
// cache local potentiellement perime) et est appelee a la fois par le HANDLER
// jodiePortraitOuvrirInterview() (le vrai point de blocage, imperatif) et par l'affichage de
// renderMailRead() (masquage des boutons, purement indicatif -- ne remplace jamais le controle du
// handler). Limite assumee et documentee (pas de SQL pour la fermer) : un joueur qui SUPPRIME
// explicitement (deleteMail -> sbDeleteMail, une vraie suppression Supabase) le mail de refus
// perdrait ce marqueur -- action deliberee et rare du joueur sur SON propre mail, pas une
// decheance automatique du systeme.
const JODIE_PORTRAIT_SUJET_PROPOSITION = "Un portrait pour L'Autruche Entravée ?";
const JODIE_PORTRAIT_SUJET_REFUS = "Un portrait pour L'Autruche Entravée ? (classé)";
const JODIE_PORTRAIT_TITRE_PREFIXE = 'Un jour, un portrait : ';
const JODIE_QUESTIONS_INTERVIEW = [
  'Qui êtes-vous ?',
  "Qu'est-ce qui vous a amené ici ?",
  'Qu\'aimeriez-vous accomplir ?',
  'Quel regard portez-vous sur votre ville ou sur le pays ?',
  'Y a-t-il quelque chose que les habitants devraient savoir sur vous ?'
];

async function jodiePortraitVerifierProposition() {
  if (typeof state === 'undefined' || !state.char?.name) return;
  if (typeof sbGet !== 'function' || typeof sbGetMailsFor !== 'function' || typeof sbSendMail !== 'function') return;

  const rowsPerso = await sbGet('personnages', 'name=eq.' + encodeURIComponent(state.char.name) + '&select=created_at').catch(() => null);
  const createdAt = rowsPerso?.[0]?.created_at;
  if (!createdAt) return;
  const joursEcoulesReels = (Date.now() - new Date(createdAt).getTime()) / 86400000;
  if (joursEcoulesReels < 1) return; // Jamais le jour meme de la creation

  const mails = await sbGetMailsFor(state.char.name).catch(() => null);
  if (!mails) return; // Echec reseau : retente a la prochaine synchronisation, jamais de doublon force
  const dejaContacte = mails.some(m => m.from_player === 'Jodie Moitout' &&
    (m.subject === JODIE_PORTRAIT_SUJET_PROPOSITION || m.subject === JODIE_PORTRAIT_SUJET_REFUS));
  if (dejaContacte) return;

  const corps = "Bonjour,<br><br>" +
    "Jodie Moitout, journaliste à <em>L'Autruche Entravée</em> — le petit dernier du groupe La Tribune, celui qui pose les questions que les autres n'osent pas.<br><br>" +
    "Un nouveau visage en ville, ça ne m'échappe jamais très longtemps. Ça vous dirait de répondre à quelques questions pour un petit portrait ? Rien de formel — juste de quoi donner un visage à votre nom, pour la rubrique Presse &amp; Médias.<br><br>" +
    "Libre à vous d'accepter ou de décliner, bien sûr.<br><br>" +
    "Jodie Moitout<br><br>" +
    "<em>« Tout le monde a une histoire. La mienne, c'est de la trouver. »</em>";

  await sbSendMail('Jodie Moitout', state.char.name, JODIE_PORTRAIT_SUJET_PROPOSITION, corps, formatDateHeureJeu());
}

// Interroge Supabase DIRECTEMENT (jamais un simple cache local potentiellement perime -- voir
// commentaire d'en-tete) : existe-t-il un mail-marqueur de refus pour ce PJ ? Autorite unique de
// l'etat "refuse", appelee a la fois par le handler jodiePortraitOuvrirInterview() (blocage reel)
// et par renderMailRead() (masquage indicatif des boutons) -- jamais l'un sans l'autre.
async function jodiePortraitADejaRefuse(nom) {
  if (!nom || typeof sbGetMailsFor !== 'function') return false;
  const mails = await sbGetMailsFor(nom).catch(() => null);
  if (!mails) return false; // echec reseau : ne bloque jamais artificiellement une action reelle
  return mails.some(m => m.from_player === 'Jodie Moitout' && m.subject === JODIE_PORTRAIT_SUJET_REFUS);
}

// Meme doctrine que ci-dessus, pour l'etat "publie" (marqueur = ligne forum_topics, jamais purgee).
async function jodiePortraitDejaPublie(nom) {
  if (!nom || typeof sbGet !== 'function') return false;
  const titre = JODIE_PORTRAIT_TITRE_PREFIXE + nom;
  const existant = await sbGet('forum_topics', `forum_id=eq.presse&author=eq.${encodeURIComponent('Jodie Moitout')}&title=eq.${encodeURIComponent(titre)}`).catch(() => null);
  return !!(existant && existant.length > 0);
}

// Refus -- appelable aussi bien depuis le mail de proposition (renderMailRead(), forum.js) que
// depuis l'apercu final du portrait (renderJodiePortraitPreview() ci-dessous) : dans les deux cas
// le resultat est identique et definitif (section 6/2 du lot) -- envoi du mail-marqueur de refus
// (archive immediatement, meme raison que ci-dessus), jamais de republication ni de relance.
async function jodiePortraitRefuser() {
  const nom = state.char?.name;
  if (!nom || typeof sbSendMail !== 'function') return;
  const corps = "Compris, on n'en parle plus. Si jamais vous changez d'avis, vous savez où me trouver.<br><br>Jodie Moitout";
  const idMail = await sbSendMail('Jodie Moitout', nom, JODIE_PORTRAIT_SUJET_REFUS, corps, formatDateHeureJeu()).catch(() => null);
  if (idMail && typeof sbSetMailArchived === 'function') await sbSetMailArchived(idMail, true).catch(() => {});
  window._jodieInterviewReponses = null;
  window._jodiePortraitTexte = null;
  showToast('Proposition déclinée', "Vous avez décliné l'interview de Jodie Moitout.", true);
  if (typeof renderForumContent === 'function') {
    mailView = 'inbox';
    document.getElementById('forum-main').innerHTML = renderForumContent();
  }
}

// Accepter -- HANDLER, le vrai point de blocage (section 2 du lot : "masquer le bouton seul ne
// suffit pas"). Verifie D'ABORD le marqueur de refus (un refus explicite, quelle que soit son
// origine -- mail initial ou apercu final -- interdit definitivement toute reprise), PUIS le
// marqueur de publication (aucun second portrait) -- les deux via Supabase frais, jamais un
// simple etat client. Reouvrir l'ancien mail de proposition et cliquer "Accepter" APRES un refus
// ou une publication ne peut donc plus jamais relancer l'interview, meme si l'affichage des
// boutons (renderMailRead()) etait par extraordinaire reste perime.
async function jodiePortraitOuvrirInterview() {
  const nom = state.char?.name;
  if (!nom) return;
  if (await jodiePortraitADejaRefuse(nom)) {
    showToast('Proposition déclinée', 'Vous avez déjà décliné cette proposition — Jodie ne relance pas.', false);
    return;
  }
  if (await jodiePortraitDejaPublie(nom)) {
    showToast('Déjà publié', 'Jodie a déjà publié votre portrait dans Presse & Médias.', false);
    return;
  }
  window._jodieInterviewReponses = ['', '', '', '', ''];
  window._jodieInterviewPage = 0;
  mailView = 'jodie-interview';
  document.getElementById('forum-main').innerHTML = renderForumContent();
}

// Remplit #jodie-portrait-etat (place par renderMailRead(), forum.js) une fois la reponse
// Supabase arrivee -- boutons Accepter/Refuser si rien n'est encore tranche, message informatif
// sinon. Purement indicatif (section 2 du lot) : la protection reelle contre une reprise est le
// controle refait par jodiePortraitOuvrirInterview() elle-meme, jamais ce seul affichage -- si cet
// element n'existe plus au moment ou la reponse arrive (le joueur a change d'ecran entre-temps),
// on ne fait simplement rien.
async function jodiePortraitRafraichirEtatMail() {
  const nom = state.char?.name;
  if (!nom) return;

  const dejaRefuse = await jodiePortraitADejaRefuse(nom);
  const el = document.getElementById('jodie-portrait-etat');
  if (!el) return; // ecran deja quitte entre-temps
  if (dejaRefuse) {
    el.innerHTML = '<div style="font-size:.8rem;color:#8a8060;font-style:italic">Vous avez décliné cette proposition.</div>';
    return;
  }

  const dejaPublie = await jodiePortraitDejaPublie(nom);
  const el2 = document.getElementById('jodie-portrait-etat');
  if (!el2) return;
  if (dejaPublie) {
    el2.innerHTML = '<div style="font-size:.8rem;color:#8a8060;font-style:italic">Vous avez déjà publié votre portrait dans Presse &amp; Médias.</div>';
    return;
  }

  el2.innerHTML =
    '<div style="display:flex;gap:.5rem;flex-wrap:wrap">' +
    '<button onclick="jodiePortraitOuvrirInterview()" class="forum-new-btn" style="font-size:.72rem"><i class="ti ti-microphone"></i> Accepter l\'interview</button>' +
    '<button onclick="jodiePortraitRefuser()" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.5rem 1rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer">Refuser</button>' +
    '</div>';
}

// Formulaire d'interview -- 5 questions, reponses libres, memes classes CSS forum-field/
// forum-field-label deja utilisees ailleurs dans ce fichier (renderEnvoyerMailEnTantQue) : aucun
// nouvel editeur, un simple formulaire dans la vue mail deja existante (meme pattern que
// mailView 'inbox'/'read'/'compose', voir renderMailView(), forum.js).
function jodieInterviewAllerPage(page) {
  const actuelle = Math.max(0, Math.min(4, Number(window._jodieInterviewPage) || 0));
  const champ = document.getElementById('jodie-reponse-' + actuelle);
  if (!Array.isArray(window._jodieInterviewReponses)) window._jodieInterviewReponses = ['', '', '', '', ''];
  if (champ) window._jodieInterviewReponses[actuelle] = champ.value;
  window._jodieInterviewPage = Math.max(0, Math.min(4, Number(page) || 0));
  mailView = 'jodie-interview';
  document.getElementById('forum-main').innerHTML = renderForumContent();
}
function renderJodieInterviewForm() {
  if (!window._jodieInterviewReponses) window._jodieInterviewReponses = ['', '', '', '', ''];
  const page = Math.max(0, Math.min(4, Number(window._jodieInterviewPage) || 0));
  let html = `<div class="forum-header-bar"><button class="forum-back-btn" onclick="mailView='inbox';document.getElementById('forum-main').innerHTML=renderForumContent()">Retour au courrier</button><div class="forum-title-main" style="flex:1">Interview avec Jodie Moitout</div></div>`;
  html += '<div style="padding:.8rem"><p>Question ' + (page + 1) + ' sur 5 — Les réponses sont conservées entre les pages.</p>';
  html += '<div class="forum-field"><label class="forum-field-label">' + (page + 1) + '. ' + escapeHtmlText(JODIE_QUESTIONS_INTERVIEW[page]) + '</label>';
  html += '<textarea id="jodie-reponse-' + page + '" rows="5" maxlength="500" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem .6rem;box-sizing:border-box" oninput="window._jodieInterviewReponses[' + page + ']=this.value">' + escapeHtmlText(window._jodieInterviewReponses[page] || '') + '</textarea></div>';
  html += '<div style="display:flex;flex-wrap:wrap;gap:.5rem;margin-top:1rem">';
  if (page > 0) html += '<button class="forum-back-btn" onclick="jodieInterviewAllerPage(' + (page - 1) + ')">Précédent</button>';
  if (page < 4) html += '<button class="forum-new-btn" onclick="jodieInterviewAllerPage(' + (page + 1) + ')">Suivant</button>';
  else html += '<button class="forum-new-btn" onclick="jodieInterviewAllerPage(4);jodiePortraitGenererApercu()">Envoyer mes réponses à Jodie</button>';
  return html + '</div></div>';
}

// Validation (aucun envoi vide, section 4 du lot) puis generation IA du portrait -- reutilise
// TEL QUEL le mecanisme deja en production pour Jeremy (queteAccueilGenererReponseMailJeremy(),
// plateau-quete-accueil.js : meme endpoint /api/chat, meme construction de prompt en texte libre
// avec echappement des guillemets du joueur, meme lecture data.content[0].text, meme reponse de
// repli en cas d'echec) -- aucun second moteur IA construit ici. On ne fournit au modele QUE les
// 5 reponses et le nom du PJ, jamais d'autre donnee de personnage (aucun fait invente en dehors
// des reponses fournies).
async function jodiePortraitAppelApi(payload) {
  try {
    if (typeof rpAuthAssurerSession === 'function') await rpAuthAssurerSession();
    const jeton = typeof rpAuthJeton === 'function' ? rpAuthJeton() : null;
    if (!jeton) return {ok:false,error:'Connexion requise.'};
    const resp = await fetch('/api/jodie-portrait', {
      method:'POST',
      headers:{'Content-Type':'application/json','Authorization':'Bearer '+jeton},
      body:JSON.stringify(payload)
    });
    const data = await resp.json().catch(() => null);
    return data || {ok:false,error:'Réponse serveur indisponible.'};
  } catch (e) {
    return {ok:false,error:'Connexion au serveur indisponible.'};
  }
}
async function jodiePortraitGenererApercu() {
  const reponses = (window._jodieInterviewReponses || []).map(r => (r || '').trim());
  if (reponses.length !== 5 || reponses.some(r => !r)) {
    showToast('Réponses incomplètes', 'Merci de répondre à chacune des 5 questions.', false);
    return;
  }
  const nom = state.char?.name || '';
  document.getElementById('forum-main').innerHTML = '<div style="padding:2rem;text-align:center;color:#8a8060">Jodie rédige...</div>';
  // L'IA et la preuve de publication sont générées par le serveur authentifié.
  const resultat = await jodiePortraitAppelApi({action:'apercu',personnage:nom,reponses});
  if (!resultat.ok || !resultat.texte || !resultat.jeton) {
    showToast('Indisponible', resultat.error || "Jodie n'arrive pas à rédiger.", false);
    mailView = 'jodie-interview';
    document.getElementById('forum-main').innerHTML = renderForumContent();
    return;
  }
  window._jodiePortraitTexte = resultat.texte;
  window._jodiePortraitJeton = resultat.jeton;
  mailView = 'jodie-preview';
  document.getElementById('forum-main').innerHTML = renderForumContent();
}

// Filet de securite minimal (pas un moteur Markdown general) : retire uniquement les marqueurs
// de mise en forme Markdown les plus probables malgre la consigne du prompt ci-dessus (observe en
// test reel : "il le *sait*, il le *sent*" affiche tel quel, l'interface ne rend aucun Markdown).
// Ne touche jamais a la ponctuation francaise normale (guillemets « », tirets, apostrophes,
// points de suspension) -- uniquement *Viande*/**Viande**, les # de titre en debut de ligne, les
// puces de liste en debut de ligne, et un ultime nettoyage des etoiles/dieses isoles residuels.
function jodieNettoyerMarkdown(texte) {
  if (!texte) return texte;
  return texte
    .replace(/\*\*(.+?)\*\*/g, '$1')
    .replace(/\*(.+?)\*/g, '$1')
    .replace(/^#{1,6}\s+/gm, '')
    .replace(/^[-*+]\s+/gm, '')
    .replace(/[*#]/g, '')
    .trim();
}

// Apercu obligatoire avant publication (section 6 du lot) -- aucune publication automatique.
function renderJodiePortraitPreview() {
  const nom = state.char?.name || '';
  const titre = JODIE_PORTRAIT_TITRE_PREFIXE + nom;
  let html = '<div class="forum-header-bar"><div class="forum-title-main" style="flex:1">Aperçu du portrait</div></div>';
  html += '<div style="padding:.8rem">';
  html += '<div style="font-size:.7rem;color:#6a5a30;text-transform:uppercase;letter-spacing:.08em;margin-bottom:.3rem">Presse &amp; Médias — L\'Autruche Entravée</div>';
  html += '<div style="font-family:Playfair Display,serif;font-size:1.05rem;color:#E8D880;margin-bottom:.6rem">' + escapeHtmlText(titre) + '</div>';
  html += '<div class="lecture-longue lecture-longue-page" style="color:#f0ead6;margin-bottom:1rem">' + escapeHtmlText(window._jodiePortraitTexte || '').replace(/\n/g, '<br>') + '</div>';
  html += '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Ce texte ne sera publié qu\'avec votre accord.</div>';
  html += '<div style="display:flex;gap:.5rem;flex-wrap:wrap">';
  html += '<button class="forum-new-btn" onclick="jodiePortraitPublier()"><i class="ti ti-send"></i> Publier dans Presse &amp; Médias</button>';
  html += '<button onclick="jodiePortraitRefuser()" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.5rem 1rem;border:1px solid #6a2a20;background:transparent;color:#cc4444;cursor:pointer">Ne pas publier</button>';
  html += '</div></div>';
  return html;
}

// Publication via l'API protegee : le navigateur ne peut pas ecrire au nom de Jodie.
// Le serveur verifie le proprietaire, l'invitation, le refus, la signature de
// l'apercu et l'unicite du portrait avant toute ecriture avec son compte de service.
async function jodiePortraitPublier() {
  const nom = state.char?.name || '';
  if (!window._jodiePortraitTexte || !window._jodiePortraitJeton) {
    showToast('Aperçu expiré', 'Veuillez régénérer le portrait avant de publier.', false); return;
  }
  if (window._jodiePublicationEnCours) return;
  window._jodiePublicationEnCours = true;
  try {
    const r = await jodiePortraitAppelApi({action:'publier',personnage:nom,jeton:window._jodiePortraitJeton});
    if (!r.ok) {
      showToast('Échec', r.error || "La publication n'a pas été enregistrée.", false);
      return;
    }
    window._jodiePortraitTexte = null;
    window._jodiePortraitJeton = null;
    window._jodieInterviewReponses = null;
    showToast('Portrait publié !', 'Jodie a publié votre portrait dans Presse & Médias.', true, true);
    mailView = 'inbox';
    document.getElementById('forum-main').innerHTML = renderForumContent();
  } finally {
    window._jodiePublicationEnCours = false;
  }
}

// =====================
// DONNER UNE INTERVIEW — ordre reel du PJ (chantier du 3 septembre 2026, reparation de l'ordre
// 'interview' de La Tribune de Republia, jusqu'ici routé vers doInterview(), fonction inexistante ;
// REVISE le meme jour suite a un audit dedie identite/falsification)
// =====================
// Pendant VOLONTAIRE du systeme "Un jour, un portrait" ci-dessus : ici c'est le joueur qui
// sollicite Jodie (jamais l'inverse). Systemes INDEPENDANTS -- aucune donnee/etat partage.
//
// SECURISE DE BOUT EN BOUT (revision du 3 septembre 2026) : ce client ne construit plus JAMAIS le
// dossier public, le prompt, ni l'appel IA lui-meme -- tout le dialogue (questions ET
// enregistrement des reponses) passe desormais par api/journal-interview.js (actions 'cooldown',
// 'lancer', 'question', 'publier'), qui est seul a connaitre interviews_jodie (RLS verrouillee,
// voir migration_interviews_jodie.sql) et a construire le transcript qui fait foi. Ce client
// n'envoie jamais plus qu'un nom de personnage, un identifiant d'interview, et le texte brut de
// LA reponse qu'il vient de donner -- jamais un entretien entier reconstitue a posteriori (c'est
// precisement la faille corrigee par cette revision : un client ne peut plus remplacer le contenu
// reel de l'entretien par des Q/R inventees, le serveur etant desormais temoin de chaque tour).
//
// Cooldown 10 JOURS REELS persistant, cote serveur uniquement desormais. Arme DES le vrai
// lancement (action 'lancer', PA deja consomme juste avant cote client) -- un entretien abandonne
// en cours de route consomme quand meme son PA et son cooldown, comme n'importe quel autre ordre
// du jeu. Fermer la pop-up ou perdre la connexion en plein entretien ne cree jamais d'article
// orphelin ni de double publication : l'article n'existe qu'a la toute derniere action
// ('publier'), qui relit le transcript accumule cote serveur, jamais un etat client.
//
// Publication : alimente le VRAI Journal du jour (journal_editions.double_page_centrale), jamais
// Presse & Medias (reserve au portrait ci-dessus) ni un journal personnel ou evenementiel seul.

let _jodieInterview = null;

// Point d'entree, appele par le router (fn === 'interview'). Verifie le cooldown AVANT toute
// consommation de PA (cahier des charges §2), puis deduit le PA et arme le cooldown (action
// 'lancer') au meme instant.
async function ouvrirInterviewJodie(pa, cost) {
  const nom = state.char?.name;
  if (!nom) return;

  const cooldown = await jodieAppelApi({ action: 'cooldown', personnage: nom });
  if (!cooldown || !cooldown.ok) {
    showToast('Jodie est indisponible', "Impossible de vérifier la disponibilité de Jodie pour le moment. Réessayez plus tard.", false);
    return;
  }
  if (cooldown.joursRestants > 0) {
    showToast('Jodie est déjà passée', 'Vous l\'avez sollicitée récemment. Revenez dans ' + cooldown.joursRestants + ' jour(s).', false);
    return;
  }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  document.getElementById('postes-modal-title').textContent = '🎙 Interview avec Jodie Moitout';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">Jodie s\'installe...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const lancement = await jodieAppelApi({ action: 'lancer', personnage: nom });
  if (!lancement || !lancement.ok) {
    // PA deja engage (comme documente ci-dessus) : l'echec ici est rarissime (le cooldown vient
    // d'etre confirme OK a l'instant) -- on ne rembourse pas, coherent avec la doctrine du jeu,
    // mais on informe clairement le joueur plutot que de laisser une modale muette.
    document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#cc6a5a">Jodie n\'a pas pu commencer l\'entretien pour le moment. Réessayez plus tard.</div>';
    return;
  }

  _jodieInterview = {
    pa, cost, nom, interviewId: lancement.interviewId,
    questions: [], reponses: [],
    soumission: false, chargement: false, enAttenteReponse: false,
    termine: false, clotureTexte: null, erreur: null, etapeErreur: null,
    articlePublie: false, articleTitre: null, articleTexte: null
  };

  await jodieGenererProchaineQuestion();
}

// Appel generique vers l'endpoint securise -- centralise ici pour que toutes les actions
// partagent le meme comportement reseau (jamais de logique dupliquee par action).
async function jodieAppelApi(payload) {
  try {
    if (typeof rpAuthAssurerSession === 'function') await rpAuthAssurerSession();
    const jeton = typeof rpAuthJeton === 'function' ? rpAuthJeton() : null;
    if (!jeton) return {ok:false,status:401,error:'Connexion requise.'};
    const resp = await fetch('/api/journal-interview', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization':'Bearer '+jeton },
      body: JSON.stringify(payload)
    });
    const data = await resp.json().catch(() => null);
    if (!resp.ok) return { ok: false, status: resp.status, error: (data && data.error) || ('HTTP ' + resp.status) };
    return data;
  } catch (e) {
    return null;
  }
}

function jodieRenderInterviewModal() {
  const it = _jodieInterview;
  if (!it) return;
  let html = '<div style="padding:1rem;max-height:65vh;overflow-y:auto" id="jodie-interview-scroll">';
  html += '<div style="font-size:.72rem;color:#8a8060;font-style:italic;margin-bottom:.9rem">Jodie Moitout, journaliste à L\'Autruche Entravée, vous interviewe pour La Tribune de Républia.</div>';

  it.questions.forEach((q, i) => {
    html += '<div style="margin-bottom:.8rem"><div style="font-size:.65rem;color:#8a6a20;text-transform:uppercase;letter-spacing:.06em;margin-bottom:.15rem">Jodie</div>';
    html += '<div style="font-size:.85rem;color:#e0d8c0;font-style:italic">« ' + escapeHtmlText(q) + ' »</div></div>';
    if (it.reponses[i] !== undefined) {
      html += '<div style="margin-bottom:.8rem;padding-left:.8rem;border-left:2px solid #3a2a10"><div style="font-size:.65rem;color:#6a8aaa;text-transform:uppercase;letter-spacing:.06em;margin-bottom:.15rem">Vous</div>';
      html += '<div style="font-size:.85rem;color:#c0b090">' + escapeHtmlText(it.reponses[i]) + '</div></div>';
    }
  });

  if (it.clotureTexte) {
    html += '<div style="margin-bottom:.8rem"><div style="font-size:.65rem;color:#8a6a20;text-transform:uppercase;letter-spacing:.06em;margin-bottom:.15rem">Jodie</div>';
    html += '<div style="font-size:.85rem;color:#e0d8c0;font-style:italic">« ' + escapeHtmlText(it.clotureTexte) + ' »</div></div>';
  }

  if (it.erreur) {
    html += '<div style="margin:.8rem 0;padding:.6rem;border:1px solid #6a2a20;background:#1a0d08;color:#cc6a5a;font-size:.8rem">' + escapeHtmlText(it.erreur) + '</div>';
    html += '<button class="pnj-action-btn" onclick="jodieReessayerEtape()"><i class="ti ti-refresh"></i> Réessayer</button>';
  } else if (it.chargement) {
    html += '<div style="font-style:italic;color:#8a8060;padding:.6rem 0">' + (it.articlePublie === false && it.termine ? 'Jodie rédige son article…' : 'Jodie réfléchit…') + '</div>';
  } else if (it.enAttenteReponse && !it.termine) {
    html += '<div style="margin-top:.8rem">';
    html += '<textarea id="jodie-reponse-input" rows="3" maxlength="600" placeholder="Votre réponse..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem .6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:vertical;box-sizing:border-box"></textarea>';
    html += '<button id="jodie-envoyer-btn" class="pnj-action-btn" style="margin-top:.5rem" onclick="jodieEnvoyerReponse()"><i class="ti ti-send"></i> Répondre</button>';
    html += '</div>';
  } else if (it.articlePublie) {
    html += '<div style="margin-top:1rem;padding:.8rem;border:1px solid #3a2a10;background:#0f0d05">';
    html += '<div style="font-size:.65rem;color:#8a6a20;text-transform:uppercase;letter-spacing:.06em;margin-bottom:.3rem">Publié dans La Tribune de Républia</div>';
    html += '<div style="font-family:Playfair Display,serif;font-size:1rem;color:#E8D880;margin-bottom:.4rem">' + escapeHtmlText(it.articleTitre || '') + '</div>';
    html += '<div style="font-size:.82rem;color:#c0b090;white-space:pre-wrap">' + escapeHtmlText(it.articleTexte || '') + '</div>';
    html += '</div>';
    html += '<button class="pnj-action-btn" style="margin-top:.8rem" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')"><i class="ti ti-check"></i> Fermer</button>';
  }

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  const scrollEl = document.getElementById('jodie-interview-scroll');
  if (scrollEl) scrollEl.scrollTop = scrollEl.scrollHeight;
}

// Enregistre la reponse au tour precedent (le cas echeant) et obtient la prochaine question OU
// la cloture -- entierement decide cote serveur (action 'question', transcript accumule dans
// interviews_jodie, jamais reconstruit a partir d'un etat client). Garde anti double-soumission
// via it.soumission, verifiee AVANT tout appel reseau.
async function jodieGenererProchaineQuestion(reponseATransmettre) {
  const it = _jodieInterview;
  if (!it || it.soumission) return;

  it.soumission = true;
  it.chargement = true;
  it.erreur = null;
  it.enAttenteReponse = false;
  jodieRenderInterviewModal();

  const payload = { action: 'question', personnage: it.nom, interviewId: it.interviewId };
  if (reponseATransmettre !== undefined) payload.reponse = reponseATransmettre;
  const data = await jodieAppelApi(payload);

  it.chargement = false;
  it.soumission = false;

  if (!data || !data.ok) {
    it.erreur = "Jodie n'arrive pas à mettre ses idées en ordre pour le moment (problème réseau). Vous pouvez réessayer.";
    it.etapeErreur = 'question';
    jodieRenderInterviewModal();
    return;
  }

  if (data.termine) {
    it.clotureTexte = data.clotureTexte;
    it.termine = true;
    jodieRenderInterviewModal();
    await jodieTerminerEtPublier();
    return;
  }

  it.questions.push(data.question);
  it.enAttenteReponse = true;
  jodieRenderInterviewModal();
}

function jodieEnvoyerReponse() {
  const it = _jodieInterview;
  if (!it || it.soumission || !it.enAttenteReponse) return;
  const input = document.getElementById('jodie-reponse-input');
  const texte = (input?.value || '').trim();
  if (!texte) { showToast('Réponse requise', 'Écrivez une réponse avant de continuer.', false); return; }
  it.reponses[it.questions.length - 1] = texte;
  it.enAttenteReponse = false;
  jodieGenererProchaineQuestion(texte);
}

function jodieReessayerEtape() {
  const it = _jodieInterview;
  if (!it) return;
  it.erreur = null;
  if (it.etapeErreur === 'article') jodieTerminerEtPublier();
  // Reessai d'une question : ne retransmet PAS la derniere reponse (deja enregistree cote
  // serveur au premier essai reussi le cas echeant, ou jamais envoyee si c'est l'appel lui-meme
  // qui a echoue -- dans les deux cas, rejouer sans "reponse" est sans danger : le serveur
  // renvoie simplement la meme question si aucune n'etait en attente de reponse chez lui).
  else jodieGenererProchaineQuestion();
}

// Publication finale -- SECURISE (3 septembre 2026) : le client n'envoie plus ni pays, ni
// dossier, ni Q/R -- uniquement le nom du PJ et l'identifiant d'interview. Le serveur relit LUI-
// MEME le transcript qu'il a accumule tour par tour (interviews_jodie.transcript) : le contenu
// publie est ainsi garanti identique a l'echange reellement suivi, jamais a une reconstruction
// cote client.
async function jodieTerminerEtPublier() {
  const it = _jodieInterview;
  if (!it || it.soumission) return;
  it.soumission = true;
  it.chargement = true;
  it.erreur = null;
  jodieRenderInterviewModal();

  const data = await jodieAppelApi({ action: 'publier', personnage: it.nom, interviewId: it.interviewId });

  it.chargement = false;
  it.soumission = false;

  // Un verrou de publication (409) n'est pas la preuve d'un article persiste.
  const dejaPubliee = data?.ok === true && data.dejaPubliee === true;

  if (!dejaPubliee && (!data || !data.ok)) {
    it.erreur = "Jodie n'arrive pas à finaliser son article pour le moment (problème réseau). Vos réponses sont conservées ; la publication reste à confirmer.";
    it.etapeErreur = 'article';
    jodieRenderInterviewModal();
    return;
  }

  it.articleTitre = data.titre || it.articleTitre;
  it.articleTexte = data.texte || it.articleTexte;
  it.articlePublie = true;

  if (dejaPubliee) {
    addJournalEntry('Votre interview avec Jodie Moitout a déjà été publiée.', 'event-info');
    showToast('Déjà publiée', 'Cette interview a déjà été traitée.', true);
  } else if (data.statut === 'publiee') {
    addJournalEntry('Vous avez donné une interview à Jodie Moitout, publiée dans La Tribune de Républia : « ' + data.titre + ' ».', 'event-good');
    showToast('Interview publiée !', 'Votre interview est parue dans La Tribune de Républia.', true, true);
  } else if (data.statut === 'en_attente') {
    addJournalEntry('Vous avez donné une interview à Jodie Moitout. Elle paraîtra dans La Tribune de Républia dès la prochaine édition.', 'event-good');
    showToast('Interview enregistrée !', "L'édition du jour n'est pas encore disponible ; votre interview paraîtra dans la prochaine édition de La Tribune de Républia.", true, true);
  }

  jodieRenderInterviewModal();
}

// =====================
// PETITES ANNONCES — La Tribune de Republia (chantier "refonte Journal du jour", 31 aout 2026).
// Flux dedie, HORS du pipeline PA/argent generique de doOrder()/executerOrdreGenerique() (comme
// gerer_finances/compte_offshore) : la verification "une annonce active a la fois" doit avoir
// lieu AVANT tout debit, ce que le pipeline generique (qui deduit PA/cout puis tire un resultat)
// ne permet pas proprement. Reutilise le modal generique #modal-postes/#postes-body (meme
// convention que ouvrirGestionHelvetia, plateau-justice-economie.js).
// =====================
const PETITE_ANNONCE_COUT_FR = 30;
const PETITE_ANNONCE_DUREE_JOURS = 3;
const PETITE_ANNONCE_PA = 1;

async function ouvrirFormulairePetiteAnnonce() {
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Petite annonce — La Tribune de Républia';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.2rem 1rem;font-style:italic;color:#8a8060">Chargement…</div>';
  document.getElementById('modal-postes').classList.add('open');

  const active = typeof sbGetAnnonceActiveDuJoueur === 'function'
    ? await sbGetAnnonceActiveDuJoueur(state.char?.name).catch(() => null)
    : null;

  if (active) {
    const expireLe = new Date(active.expire_at).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' });
    document.getElementById('postes-body').innerHTML = `
      <div style="padding:1rem">
        <div style="font-size:.82rem;color:#8a8060;margin-bottom:1rem;line-height:1.6">Vous avez déjà une annonce active, publiée jusqu'au ${escapeHtmlText(expireLe)}. Une seule annonce à la fois est autorisée.</div>
        <div class="lecture-longue" style="background:#141008;border:1px solid #2a2010;padding:.8rem;margin-bottom:1.2rem;font-size:.85rem;color:#c0b090">${escapeHtmlText(active.texte)}</div>
        <button onclick="retirerPetiteAnnonce('${active.id}')" style="width:100%;font-family:'Bebas Neue',sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.6rem 1.2rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Retirer mon annonce (sans remboursement)</button>
      </div>`;
    return;
  }

  document.getElementById('postes-body').innerHTML = `
    <div style="padding:1rem">
      <div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem;line-height:1.6">${PETITE_ANNONCE_COUT_FR} ${cur} pour une parution de ${PETITE_ANNONCE_DUREE_JOURS} jours dans La Tribune de Républia. Une seule annonce active à la fois.</div>
      <select id="annonce-categorie" style="width:100%;margin-bottom:.6rem;background:#141008;color:#c0b090;border:1px solid #2a2010;padding:.5rem;font-family:inherit">
        <option value="">Catégorie (facultatif)</option>
        <option value="Emploi">Emploi</option>
        <option value="Commerce">Commerce</option>
        <option value="Immobilier">Immobilier</option>
        <option value="Services">Services</option>
        <option value="Divers">Divers</option>
      </select>
      <textarea id="annonce-texte" maxlength="400" placeholder="Texte de votre annonce…" style="width:100%;min-height:100px;background:#141008;color:#c0b090;border:1px solid #2a2010;padding:.6rem;font-family:inherit;margin-bottom:.8rem;resize:vertical"></textarea>
      <button onclick="confirmerDepotPetiteAnnonce()" style="width:100%;font-family:'Bebas Neue',sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.6rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier (${PETITE_ANNONCE_COUT_FR} ${cur}, ${PETITE_ANNONCE_PA} PA)</button>
    </div>`;
}

async function confirmerDepotPetiteAnnonce() {
  const texte = (document.getElementById('annonce-texte')?.value || '').trim();
  const categorie = document.getElementById('annonce-categorie')?.value || null;
  if (!texte) { showToast('Texte manquant', 'Écrivez le texte de votre annonce.', false); return; }
  if (!TEST_MODE && state.pa < PETITE_ANNONCE_PA) {
    showToast('PA insuffisants', `Il vous manque ${PETITE_ANNONCE_PA - state.pa} PA.`, false); return;
  }
  const fondsDisponibles = typeof getFondsDisponiblesOrdinaires === 'function' ? getFondsDisponiblesOrdinaires() : state.arg;
  if (fondsDisponibles < PETITE_ANNONCE_COUT_FR) {
    showToast('Fonds insuffisants', `Cette annonce coûte ${PETITE_ANNONCE_COUT_FR} FR.`, false); return;
  }

  // Reverification anti-doublon juste avant l'ecriture (meme doctrine que
  // jodiePortraitPublier() : la fenetre entre l'ouverture du formulaire et la confirmation ne
  // doit jamais permettre une seconde annonce active).
  const dejaActive = typeof sbGetAnnonceActiveDuJoueur === 'function'
    ? await sbGetAnnonceActiveDuJoueur(state.char?.name).catch(() => null)
    : null;
  if (dejaActive) {
    showToast('Déjà publiée', 'Vous avez déjà une annonce active.', false);
    ouvrirFormulairePetiteAnnonce();
    return;
  }

  const ok = await sbDeposerPetiteAnnonce(
    state.char.name, state.char?.country || 'republic', state.currentCity || 'capitale',
    categorie, texte, PETITE_ANNONCE_DUREE_JOURS, PETITE_ANNONCE_COUT_FR
  ).catch(() => false);
  if (!ok) { showToast('Erreur', "L'annonce n'a pas pu être enregistrée. Réessayez plus tard.", false); return; }

  if (!TEST_MODE) state.pa = Math.max(0, state.pa - PETITE_ANNONCE_PA);
  if (typeof debiterFondsOrdinaires === 'function') await debiterFondsOrdinaires(PETITE_ANNONCE_COUT_FR);
  else state.arg = Math.max(0, state.arg - PETITE_ANNONCE_COUT_FR);
  // Recette EDITORIALE (12 septembre 2026) : la parution est vendue par le JOURNAL, son prix va donc
  // dans la caisse de la redaction du lieu -- jamais dans celle de l'atelier d'impression, et jamais
  // dans celle d'un autre journal. Prix et game design inchanges.
  if (typeof encaisserRecetteRedaction === 'function') {
    await encaisserRecetteRedaction(PETITE_ANNONCE_COUT_FR, 'la petite annonce');
  }

  showToast('Annonce publiée', `Votre petite annonce paraîtra dans La Tribune de Républia pendant ${PETITE_ANNONCE_DUREE_JOURS} jours.`, true);
  addJournalEntry('📰 Petite annonce déposée à La Tribune de Républia.', 'event-good');
  document.getElementById('modal-postes').classList.remove('open');
  if (typeof advanceTime === 'function') advanceTime(PETITE_ANNONCE_PA);
  if (typeof updateUI === 'function') updateUI();
}

async function retirerPetiteAnnonce(id) {
  const ok = await sbRetirerPetiteAnnonce(id).catch(() => false);
  if (!ok) { showToast('Erreur', "Le retrait n'a pas pu être enregistré. Réessayez plus tard.", false); return; }
  showToast('Annonce retirée', 'Votre annonce a été retirée (aucun remboursement).', true);
  document.getElementById('modal-postes').classList.remove('open');
}

// =====================
// FINANCES MODAL
// =====================
async function openFinancesModal(pa, cost) {
  const nom = state.char?.name;
  if (!nom || typeof sbGetComptesBancaires !== 'function' || typeof sbLoadPersonnage !== 'function') return;
  const [comptes, personnage] = await Promise.all([
    sbGetComptesBancaires(nom).catch(() => null),
    sbLoadPersonnage(nom).catch(() => null)
  ]);
  if (!Array.isArray(comptes) || !personnage || state.char?.name !== nom) {
    showToast('Comptes indisponibles', 'La situation bancaire ne peut pas être lue auprès du serveur. Aucun solde local ne sera affiché.', false);
    return;
  }
  if (typeof construireMapComptesBancaires === 'function') {
    state.comptesBancaires = construireMapComptesBancaires(comptes);
  }
  if (typeof personnage.liquide === 'number') state.liquide = personnage.liquide;
  if (typeof personnage.arg === 'number') { state.arg = personnage.arg; state.char.arg = personnage.arg; }
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';
  // Lot 3 (chantier fiscalite/Helvetia) : "En banque" affiche desormais le solde reel du compte
  // Banque nationale (comptes_bancaires), plus l'ancien champ plat state.banque (legacy, plus
  // mis a jour depuis le Lot 2). Ce modal reste partage entre Banque nationale et Helvetia (bug
  // d'origine du chantier, PAS corrige ici -- hors perimetre, reserve au futur lot Helvetia) :
  // il continue donc, comme avant ce lot, a toujours montrer/manipuler le compte Banque
  // nationale quel que soit le batiment d'ou il est ouvert.
  const soldeNational = state.comptesBancaires?.nationale?.solde || 0;

  // Placements/emprunts (chantier "Banque Nationale de Luthecia") : memes donnees persistantes
  // que la Fiche personnage (state.placementsBancaires deja hydrate, sbGetPretsEnCours en lecture
  // directe), filtrees sur la Banque nationale puisque ce modal ne gere que ce compte-la.
  const placementsServeur = (typeof relirePlacementsNationauxServeur === 'function' && state.char?.name)
    ? await relirePlacementsNationauxServeur(state.char.name) : null;
  const placementsActifs = (Array.isArray(placementsServeur) ? placementsServeur : []).filter(p => p && p.banque === 'nationale' && p.type === 'terme' && p.statut === 'actif');
  const placementsTermines = (Array.isArray(placementsServeur) ? placementsServeur : []).filter(p => p && p.banque === 'nationale' && p.type === 'terme' && p.statut !== 'actif');
  const totalPlacements = placementsActifs.reduce((s, p) => s + Number(p.montant || 0), 0);
  const pretsNationale = (typeof sbGetPretsEnCours === 'function' && state.char?.name)
    ? (await sbGetPretsEnCours(state.char.name).catch(() => [])).filter(p => (p.type_banque || 'nationale') === 'nationale')
    : [];

  document.getElementById('finances-body').innerHTML = `
    <div class="finance-row">
      <div class="finance-label">Argent total</div>
      <div class="finance-amount">${state.arg.toLocaleString('fr-FR')} ${cur}</div>
    </div>
    ${(() => {
      // Meme controle que le panneau Inventaire (resumeFortune, plateau-core.js) : si le total
      // annonce ne correspond pas a la somme reelle des poches, on le DIT ici aussi, au lieu de
      // laisser trois ecrans afficher trois chiffres sans explication. « En banque » ci-dessous
      // reste volontairement le solde de la banque NATIONALE -- c'est le sens de cet ecran-ci --
      // alors que le controle porte sur l'ensemble des comptes.
      const f = (typeof resumeFortune === 'function') ? resumeFortune() : null;
      if (!f || f.ecart === 0) return '';
      return `<div style="padding:.5rem 1rem;background:#151005;border-bottom:1px solid #6a4a20;font-size:.72rem;color:#cc9a44">`
        + `Écart de ${Math.abs(f.ecart).toLocaleString('fr-FR')} ${cur} avec le détail de vos poches `
        + `(${f.poches.toLocaleString('fr-FR')} ${cur}). Votre fiche n'est pas synchronisée avec le serveur — rechargez la page.</div>`;
    })()}
    <div class="finance-row">
      <div class="finance-label">Argent liquide (sur vous)</div>
      <div class="finance-amount">${state.liquide.toLocaleString('fr-FR')} ${cur}</div>
    </div>
    <div class="finance-row">
      <div class="finance-label">En banque</div>
      <div class="finance-amount">${soldeNational.toLocaleString('fr-FR')} ${cur}</div>
    </div>
    <div style="padding:.6rem 1rem;border-bottom:1px solid #1a1810">
      <div style="font-size:.75rem;color:#6a5a30;margin-bottom:.4rem;font-family:'Bebas Neue',sans-serif;letter-spacing:.1em">PLACEMENTS / INVESTIR</div>
      ${!Array.isArray(placementsServeur) ? '<div style="font-size:.78rem;color:#cc9a44">Lecture serveur indisponible : placement désactivé.</div>' : ''}
      <div style="font-size:.75rem;color:#a09070;margin:.4rem 0">Minimum 500 FR, immobilisation 7 jours, rendement de -12 % à +12 % à échéance. Coût : 1 PA.</div>
      <div style="display:flex;gap:.5rem;align-items:center;margin:.5rem 0">
        <input class="finance-input" id="investir-montant" type="number" min="500" step="100" placeholder="Montant à placer" />
        <select class="finance-input" id="investir-source" aria-label="Origine des fonds"><option value="nationale">Compte national</option><option value="liquide">Espèces</option></select>
        <button class="finance-btn" ${Array.isArray(placementsServeur) ? '' : 'disabled'} onclick="confirmerInvestir(1,0)">Placer</button>
      </div>
      ${placementsActifs.length === 0
        ? '<div style="font-size:.78rem;color:#9a8a68;font-style:italic">Aucun placement en cours.</div>'
        : `<div style="font-size:.82rem;color:#c0b090;margin-bottom:.3rem">${totalPlacements.toLocaleString('fr-FR')} ${cur} placés (${placementsActifs.length} investissement(s))</div>` +
          placementsActifs.map(p => {
            const joursRestants = p.prochaine_echeance ? Math.max(0, Math.ceil((new Date(p.prochaine_echeance).getTime() - Date.now()) / 86400000)) : null;
            const dateDebut = p.date_placement ? new Date(p.date_placement).toLocaleDateString('fr-FR') : 'inconnue';
            const dateFin = p.prochaine_echeance ? new Date(p.prochaine_echeance).toLocaleDateString('fr-FR') : 'inconnue';
            return `<div style="font-size:.74rem;color:#a99979;padding:.3rem 0;border-top:1px solid #252016"><strong>${Number(p.montant||0).toLocaleString('fr-FR')} ${cur}</strong> — souscrit le ${dateDebut}, échéance le ${dateFin}${joursRestants !== null ? ' (' + joursRestants + ' jour(s) restants)' : ''}</div>`;
          }).join('')}
      ${placementsTermines.length ? '<div style="margin-top:.7rem;font-size:.73rem;color:#b8a277">PLACEMENTS TERMINÉS</div>' + placementsTermines.map(p => {
        const fin = p.date_resolution || p.prochaine_echeance || p.date_placement;
        const date = fin ? new Date(fin).toLocaleDateString('fr-FR') : 'inconnue';
        return `<div style="font-size:.73rem;color:#8a8060;padding:.2rem 0">${Number(p.montant||0).toLocaleString('fr-FR')} ${cur} — ${p.statut === 'termine' ? 'terminé' : 'statut : ' + String(p.statut || 'inconnu')} le ${date}${p.montant_final != null ? ' ; résultat : ' + Number(p.montant_final).toLocaleString('fr-FR') + ' ' + cur : ''}</div>`;
      }).join('') : ''}
    </div>
    <div style="padding:.6rem 1rem;border-bottom:1px solid #1a1810">
      <div style="font-size:.75rem;color:#6a5a30;margin-bottom:.4rem;font-family:'Bebas Neue',sans-serif;letter-spacing:.1em">EMPRUNTS EN COURS</div>
      ${pretsNationale.length === 0
        ? '<div style="font-size:.78rem;color:#9a8a68;font-style:italic">Aucun emprunt en cours.</div>'
        : pretsNationale.map(p => `<div style="font-size:.78rem;color:#c0b090;padding:.15rem 0">${(TYPES_PRET?.[p.type_pret]?.label || p.type_pret || 'Prêt')} — ${(p.montant_restant||0).toLocaleString('fr-FR')} ${cur} restant, ${(p.mensualite||0).toLocaleString('fr-FR')} ${cur}/jour${p.jours_impayes > 0 ? ' (' + p.jours_impayes + ' jour(s) impayé(s))' : ''}</div>`).join('')}
    </div>
    <div style="padding:.8rem 1rem;border-bottom:1px solid #1a1810">
      <div style="font-size:.75rem;color:#6a5a30;margin-bottom:.5rem;font-family:'Bebas Neue',sans-serif;letter-spacing:.1em">DEPOT / RETRAIT</div>
      <div style="display:flex;gap:.5rem;align-items:center;margin-bottom:.5rem">
        <input class="finance-input" id="finance-amount-input" type="number" placeholder="Montant" min="1" max="${soldeNational}"/>
        <button class="finance-btn" onclick="deposerArgent(${pa},${cost})">Deposer</button>
        <button class="finance-btn danger" onclick="retirerArgent(${pa},${cost})">Retirer</button>
      </div>
      <div style="font-size:.72rem;color:#5a5040;font-style:italic">Le depot et le retrait sont 100% securises et sans risque.</div>
    </div>
    ${state.poste ? `
    <div style="padding:.8rem 1rem">
      <div style="font-size:.75rem;color:#6a5a30;margin-bottom:.3rem;font-family:'Bebas Neue',sans-serif;letter-spacing:.1em">MON POSTE</div>
      <div style="font-size:.85rem;color:#c0b090">${state.poste.name}</div>
    </div>` : ''}
  `;

  document.getElementById('modal-finances').classList.add('open');
}

// Lot 3 : raccorde a comptes_bancaires (Banque nationale) au lieu de l'ancien champ plat
// state.banque (jamais mis a jour depuis le Lot 2, donc jusqu'ici un depot/retrait etait
// invisible a tout le reste du nouveau modele). arg reste inchange dans les deux sens : simple
// deplacement entre deux poches deja comptees dedans.
// CHANTIER C (14 septembre 2026). Le dernier compte du jeu encore pilote par une ecriture
// cliente. Le navigateur deplacait l'argent entre liquide et compte national dans son propre
// etat, puis persistait les deux cotes SEPAREMENT -- le personnage d'un cote, le compte de
// l'autre, en fire-and-forget. Un echec du second appel creait ou detruisait de l'argent sans
// que personne en soit informe. Et sbMajCompteBancaire ecrivait un SOLDE ABSOLU sans le moindre
// controle d'identite.
// banque_nationale_mouvement fait le deplacement sous verrou, dans une seule transaction.
// Un depot/retrait ne cree ni ne detruit de valeur : 'arg' ne bouge pas, seule la repartition
// entre les poches change -- regle existante, conservee.
async function mouvementBanqueNationale(sens, amount, pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return null; }

  const v = await sbRpc('banque_nationale_mouvement', {
    p_acteur: state.char?.name, p_sens: sens, p_montant: amount
  }).then(function (rows) { return Array.isArray(rows) ? rows[0] : rows; }).catch(function () { return null; });

  if (!v || v.ok !== true) {
    const messages = {
      liquide_insuffisant: 'Vous n\'avez pas cette somme en liquide.',
      solde_insuffisant: 'Solde bancaire insuffisant.',
      montant_invalide: 'Montant invalide.'
    };
    showToast('Operation refusee', messages[(v && v.raison) || ''] || '', false);
    return null;
  }

  state.liquide = Number(v.liquide);
  if (!state.comptesBancaires) state.comptesBancaires = {};
  state.comptesBancaires.nationale = Object.assign({}, state.comptesBancaires.nationale,
    { id: v.compte, solde: Number(v.solde) });
  if (typeof updateUI === 'function') updateUI();
  return v;
}

async function deposerArgent(pa, cost) {
  const amount = parseInt(document.getElementById('finance-amount-input').value);
  if (!amount || amount <= 0) { showToast('Erreur', 'Montant invalide.', false); return; }
  const v = await mouvementBanqueNationale('depot', amount, pa, cost);
  if (!v) return;
  document.getElementById('modal-finances').classList.remove('open');
  showToast('Depot effectue', `${amount.toLocaleString('fr-FR')} deposes en banque.`, true);
  addJournalEntry(`Depot bancaire : ${amount.toLocaleString('fr-FR')}.`, '');
}

async function retirerArgent(pa, cost) {
  const amount = parseInt(document.getElementById('finance-amount-input').value);
  if (!amount || amount <= 0) { showToast('Erreur', 'Montant invalide.', false); return; }
  const v = await mouvementBanqueNationale('retrait', amount, pa, cost);
  if (!v) return;
  document.getElementById('modal-finances').classList.remove('open');
  showToast('Retrait effectue', `${amount.toLocaleString('fr-FR')} retires de la banque.`, true);
  addJournalEntry(`Retrait bancaire : ${amount.toLocaleString('fr-FR')}.`, '');
}


// =====================
// MANIFESTATION SPONTANEE (places des villes, decision de Fred du 1er novembre 2026)
// =====================
// Tout est decide par le serveur (manif_spontanee_organiser) : chef d'un groupe d'au moins
// 10 PJ presents sur la place, une par jour et par ville, POP de la cible +/- 1 par
// participant au clic, avis de recherche des manifestants le temps de la manifestation
// (1 h au plus, fin des que le chef quitte le groupe), trace pour les rumeurs.
// L'ecran choisit le sens et la cible, puis affiche ce que le serveur a decide.
const PLACES_MANIF_SPONTANEE = ['place-formulaire-liberte', 'place-armes-psm', 'place-du-rail-montrouge'];
const RAISONS_MANIF_SPONTANEE = {
  hors_place: 'Une manifestation spontanée se lance sur la place de la ville.',
  pas_chef: 'Seul le chef du groupe peut lancer la manifestation.',
  deja_aujourdhui: 'Une manifestation spontanée a déjà eu lieu aujourd\'hui dans cette ville.',
  cible_invalide: 'Choisissez un personnage existant.',
  sens_invalide: 'Choisissez « en faveur » ou « hostile ».',
  non_authentifie: 'Session expirée : reconnectez-vous.'
};
let _manifSpontaneeSens = 'pour';
let _manifSpontaneeEnvoi = false;

async function ouvrirManifestationSpontanee() {
  let cibles = [];
  if (typeof sbListPersonnages === 'function') {
    try { cibles = ((await sbListPersonnages()) || []).map(j => j && j.name).filter(Boolean); } catch (e) { cibles = []; }
  }
  cibles = Array.from(new Set(cibles)).sort((a, b) => a.localeCompare(b, 'fr'));
  _manifSpontaneeSens = 'pour';
  let html = '<div class="cpj-dialogue">';
  html += '<p class="cpj-note" style="margin:0 0 .8rem">Sans déclaration préalable. Il faut être le chef d\'un groupe d\'au moins 10 PJ présents sur la place. '
       + 'Chaque participant fait gagner (ou perdre) 1 POP à la cible, tout de suite. Pendant la manifestation (1 h au plus, fin dès que vous quittez le groupe), '
       + 'tous les manifestants sont hors-la-loi : la police présente peut les interpeller. Une seule manifestation spontanée par jour et par ville. 1 PA.</p>';
  if (cibles.length === 0) {
    html += '<p class="cpj-note">Aucun personnage à viser n\'est accessible pour l\'instant.</p></div>';
  } else {
    html += '<div style="display:flex;gap:.5rem;margin-bottom:.7rem">';
    html += '<button id="manif-sp-pour" class="cpj-touche cpj-primaire" style="flex:1" onclick="choisirSensManifSpontanee(\'pour\')">En faveur</button>';
    html += '<button id="manif-sp-contre" class="cpj-touche" style="flex:1" onclick="choisirSensManifSpontanee(\'contre\')">Hostile</button>';
    html += '</div>';
    html += '<p class="cpj-note" style="margin:0 0 .3rem">Personne visée</p>';
    html += '<select id="manif-sp-cible" class="cpj-champ" style="width:100%;margin-bottom:.8rem">';
    cibles.forEach(n => { const e = echapperTexteTract(n); html += '<option value="' + e + '">' + e + '</option>'; });
    html += '</select>';
    html += '<button id="manif-sp-valider" class="cpj-touche cpj-primaire" onclick="confirmerManifestationSpontanee()">Lancer la manifestation</button>';
    html += '</div>';
  }
  document.getElementById('postes-modal-title').textContent = 'Manifestation spontanée';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function choisirSensManifSpontanee(sens) {
  _manifSpontaneeSens = sens === 'contre' ? 'contre' : 'pour';
  const pour = document.getElementById('manif-sp-pour');
  const contre = document.getElementById('manif-sp-contre');
  if (pour) pour.classList.toggle('cpj-primaire', _manifSpontaneeSens === 'pour');
  if (contre) contre.classList.toggle('cpj-primaire', _manifSpontaneeSens === 'contre');
}

async function confirmerManifestationSpontanee() {
  if (_manifSpontaneeEnvoi) return;
  const cible = document.getElementById('manif-sp-cible')?.value;
  if (!cible) { showToast('Aucune cible', 'Choisissez la personne visée.', false); return; }
  _manifSpontaneeEnvoi = true;
  const btn = document.getElementById('manif-sp-valider');
  if (btn) { btn.disabled = true; btn.textContent = 'Rassemblement...'; }
  const brut = (typeof sbRpc === 'function')
    ? await sbRpc('manif_spontanee_organiser', { p_sens: _manifSpontaneeSens, p_cible: cible }).catch(() => null) : null;
  const v = Array.isArray(brut) ? brut[0] : brut;
  _manifSpontaneeEnvoi = false;
  if (!v || v.ok !== true) {
    if (btn) { btn.disabled = false; btn.textContent = 'Lancer la manifestation'; }
    const raison = v && v.raison;
    if (raison === 'groupe_insuffisant') {
      showToast('Pas assez de manifestants', 'Votre groupe compte ' + (v.presents || 0) + ' PJ présents sur la place : il en faut au moins ' + (v.minimum || 10) + '.', false);
    } else if (RAISONS_MANIF_SPONTANEE[raison]) {
      showToast('Manifestation impossible', RAISONS_MANIF_SPONTANEE[raison], false);
    } else if (!v) {
      showToast('Manifestation non confirmée', 'Le serveur n\'a pas répondu, ou la manifestation n\'est pas encore installée (elle attend les groupes de joueurs). Rien n\'a été prélevé.', false);
    } else if (typeof signalerRefusCout === 'function') {
      signalerRefusCout(v);
    }
    return;
  }
  if (typeof v.pa === 'number') state.pa = v.pa;
  if (typeof adopterJaugeServeur === 'function') adopterJaugeServeur('pop', v.pop);
  if (Array.isArray(v.recherche)) state.recherche = v.recherche;
  document.getElementById('modal-postes').classList.remove('open');
  const m = v.manif || {};
  const n = Array.isArray(m.participants) ? m.participants.length : 0;
  const effet = (m.effet_pop > 0 ? '+' : '') + m.effet_pop + ' POP';
  const sensTxt = m.sens === 'contre' ? 'contre ' : 'en faveur de ';
  showToast('Manifestation lancée !', n + ' manifestants ' + sensTxt + m.cible + ' (' + effet + '). Vous êtes hors-la-loi jusqu\'à la fin.', true, true);
  addJournalEntry('Manifestation spontanée ' + sensTxt + escapeHtmlText(m.cible || '') + ' : ' + n + ' manifestants, ' + effet + ' pour la cible. Hors-la-loi jusqu\'à la fin (1 h au plus).', 'event-info');
  state._manifSpontaneeActive = true;
  if (typeof updateUI === 'function') updateUI();
}

// Suivi : tant que le joueur est sur une place ou participe, le serveur est relu chaque minute.
// Cette lecture clot les manifestations echues et rend l'avis de recherche a jour (un membre du
// groupe apprend ainsi qu'il est hors-la-loi, puis qu'il ne l'est plus).
async function suivreManifestationSpontanee() {
  if (typeof state === 'undefined' || !state.char || typeof sbRpc !== 'function') return;
  const surPlace = PLACES_MANIF_SPONTANEE.indexOf(state.currentBuilding) !== -1;
  if (!surPlace && !state._manifSpontaneeActive) return;
  const brut = await sbRpc('manif_spontanee_lire', {}).catch(() => null);
  const v = Array.isArray(brut) ? brut[0] : brut;
  if (!v || v.ok !== true) return;
  const etaitActive = !!state._manifSpontaneeActive;
  if (Array.isArray(v.recherche)) state.recherche = v.recherche;
  if (typeof v.pop === 'number' && typeof adopterJaugeServeur === 'function') adopterJaugeServeur('pop', v.pop);
  state._manifSpontaneeActive = !!v.participe;
  if (v.participe && !etaitActive) {
    showToast('Vous manifestez', 'Vous êtes hors-la-loi jusqu\'à la fin de la manifestation.', false, true);
  } else if (etaitActive && !v.participe) {
    const motif = v.manif && v.manif.motif_fin === 'chef_parti' ? 'le chef a quitté le groupe' : 'l\'heure est écoulée';
    showToast('Manifestation terminée', 'Fin de la manifestation (' + motif + ') : vous n\'êtes plus hors-la-loi pour ce motif.', true);
    addJournalEntry('Fin de la manifestation spontanée (' + motif + ').', '');
  }
  if (typeof updateUI === 'function') updateUI();
}
if (typeof window !== 'undefined' && !window._suiviManifSpontanee) {
  window._suiviManifSpontanee = setInterval(() => { suivreManifestationSpontanee().catch(() => {}); }, 60000);
}
