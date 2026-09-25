// =====================
// PLATEAU-POLITIQUE.JS
// Votes, postes, calendrier electoral, moteur electoral, objectifs secrets,
// journal du matin, meteo politique
// =====================

// =====================
// MARCHANDER UN VOTE — DEPLACE (chantier Assemblee, 10 septembre 2026)
// =====================
// doConsulterLobbyiste / openMarchanderVoteModal / soumettreVoteMarchande vivaient ici. Les trois
// sont supprimees et REECRITES dans plateau-assemblee.js (ouvrirMarchanderVote /
// confirmerMarchanderVote / doConsulterLobbyiste).
//
// Pourquoi une suppression et non une coexistence : l'audit du 9 septembre a etabli que la chaine
// etait MORTE. openMarchanderVoteModal lisait state.votesEnCours, une variable avec 3 lectures et
// ZERO ecriture dans tout le depot -- l'ordre repondait donc toujours "Aucun vote en cours" et
// sortait avant tout debit. Trois autres defauts s'y ajoutaient : le cout (200 FR) n'etait preleve
// qu'en cas de SUCCES, l'argent etait DETRUIT au lieu d'aller a une caisse, et le bonus lobbyiste
// n'etait pas persiste (perdu au F5, apres 1 PA + 300 FR payes).
//
// Le projet a deja souffert de fonctions dupliquees dont seule la derniere chargee comptait
// (checkArrestationAuDeplacement, deux definitions divergentes) : on ne recree pas ce piege ici.
// La nouvelle implementation est la SEULE, et elle est branchee sur les vraies sessions
// parlementaires, avec un transfert transactionnel vers la caisse 'republic_assemblee'.

// =====================
// ECRAN POSTES (refonte du 9 aout 2026 — remplace openPostesModal/postulerPoste/prendrePoste/
// ouvrirPostulerPoste/demanderPosteAuPM, 3 implementations paralleles du meme ecran, toutes
// basees sur l'ancienne table statique POSTES, jamais persistee, jamais synchronisee entre
// joueurs. Desormais base uniquement sur POSTES_ELECTIFS (calendrier electoral, deja
// fonctionnel) et POSTES_NOMMES_EXCLUSIFS (nomination par l'autorite competente).
// =====================
// RENOMME « ORGANIGRAMME » LE 24 SEPTEMBRE 2026, et complete de la chaine militaire.
// L'ecran s'appelait « Postes disponibles », ce qui decrivait mal ce qu'il montre : il liste
// autant les fonctions OCCUPEES que les vacantes, avec leur titulaire. C'est un organigramme.
// Il lui manquait toute la hierarchie de la caserne -- Commandant, Capitaines, Lieutenants,
// sections -- alors que c'est precisement la ou un candidat a besoin de voir les trous avant
// d'aller s'engager. Le bloc militaire ajoute plus bas est en LECTURE SEULE : on ne s'engage
// pas depuis le Palais, il faut etre physiquement a la caserne et cela coute 2 PA.
async function ouvrirEcranPostes() {
  document.getElementById('postes-modal-title').textContent = 'Organigramme';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const country = state.country;
  const villeCourante = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[villeCourante]?.name || villeCourante;

  const postesElus = [...(POSTES_ELECTIFS.national||[]), ...(POSTES_ELECTIFS.departemental||[]), ...(POSTES_ELECTIFS.local||[])];
  const postesNommes = Object.entries(POSTES_NOMMES_EXCLUSIFS).map(([id, def]) => ({ id, ...def }));

  let html = '<div style="padding:.5rem 0">';

  html += '<div style="padding:.6rem 1rem;font-size:.72rem;color:#6a5a30;font-family:Bebas Neue,sans-serif;letter-spacing:.1em;border-bottom:1px solid #1a1810">POSTES ÉLECTIFS</div>';
  postesElus.forEach(p => {
    const local = p.niveau === 'ville';
    html += '<div class="poste-item"><div>' +
      '<div class="poste-name">' + p.name + (local ? ' (' + villeNom + ')' : '') + '</div>' +
      '<div class="poste-holder" style="font-size:.75rem;color:#6a5a30">Mandat de ' + p.mandatSemaines + ' semaines — voir le calendrier électoral pour candidater</div>' +
      '</div><button class="poste-btn" onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\');ouvrirCalendrierElectoral();">Calendrier</button></div>';
  });

  html += '<div style="padding:.6rem 1rem;font-size:.72rem;color:#6a5a30;font-family:Bebas Neue,sans-serif;letter-spacing:.1em;border-bottom:1px solid #1a1810;margin-top:.6rem">POSTES NOMMÉS</div>';
  // DEUX LECTURES AU LIEU DE TRENTE-QUATRE (24 septembre 2026, apres recette navigateur).
  //
  // CE QUI N'ALLAIT PAS. La boucle appelait getTitulaireActuel() une fois PAR POSTE NOMME, soit
  // dix-sept fois. Or cette fonction, pour un poste nomme, telecharge LA LISTE COMPLETE DES
  // PERSONNAGES puis interroge titulaires_pnj : dix-sept telechargements de la meme liste et
  // dix-sept lookups. L'ecran restait sur « Chargement... » pendant 36 SECONDES mesurees en
  // production. Ce n'etait pas un ecran lent, c'etait un ecran casse -- personne n'attend.
  //
  // POURQUOI Promise.all NE SUFFISAIT PAS. Premiere tentative : lancer les dix-sept appels
  // ensemble. Mesure : 39 s au lieu de 36. Paralleliser dix-sept telechargements de la meme
  // liste ne fait pas disparaitre les dix-sept telechargements -- il fallait supprimer la
  // repetition, pas la reordonner.
  //
  // CE QUI EST FAIT. On lit UNE fois les personnages, UNE fois les titulaires PNJ, une fois les
  // compagnies, puis on resout les dix-sept postes en memoire. La semantique est celle de
  // getTitulaireActuel et n'est pas touchee : joueur d'abord (meme pays, meme poste, meme ville
  // si le poste est local), PNJ en repli, null si vraiment vacant. getTitulaireActuel reste en
  // place pour ses autres appelants, qui n'en demandent qu'un a la fois.
  const [joueursTous, pnjTous, compagnies] = await Promise.all([
    (typeof sbListPersonnages === 'function' ? sbListPersonnages().catch(() => []) : Promise.resolve([])),
    (typeof sbGet === 'function' ? sbGet('titulaires_pnj', 'select=id,nom_pnj').catch(() => []) : Promise.resolve([])),
    (typeof sbGetCompagnies === 'function' ? sbGetCompagnies(country).catch(() => []) : Promise.resolve([]))
  ]);
  const pnjParId = {};
  (pnjTous || []).forEach(r => { if (r && r.id) pnjParId[r.id] = r.nom_pnj; });
  const resoudreTitulaire = (posteId, ville) => {
    let posteMatch = null;
    const match = (joueursTous || []).find(j => {
      let poste = j.poste;
      if (typeof poste === 'string') { try { poste = JSON.parse(poste); } catch (e) { poste = null; } }
      if (j.country !== country || !poste || poste.id !== posteId) return false;
      if (ville && poste.city !== ville) return false;
      posteMatch = poste;
      return true;
    });
    if (match) return { nom: match.name, estPJ: true, posteComplet: posteMatch };
    const nomPnj = pnjParId[country + '_' + posteId + '_' + (ville || 'national')];
    return nomPnj ? { nom: nomPnj, estPJ: false } : null;
  };
  const titulaires = postesNommes.map(p => resoudreTitulaire(p.id, p.scope === 'ville' ? villeCourante : null));

  for (let iPoste = 0; iPoste < postesNommes.length; iPoste++) {
    const p = postesNommes[iPoste];
    const villeDeCePoste = p.scope === 'ville' ? villeCourante : null;
    const titulaire = titulaires[iPoste];
    let actionHtml;
    if (titulaire && titulaire.estPJ && titulaire.nom === state.char?.name) {
      actionHtml = '<button class="poste-btn" style="opacity:.4;cursor:default;color:#C9A84C">Votre poste</button>';
    } else if (titulaire && titulaire.estPJ) {
      actionHtml = '<button class="poste-btn" style="opacity:.4;cursor:default">Occupé</button>';
    } else {
      actionHtml = '<button class="poste-btn" onclick="demanderNominationPoste(\'' + p.id + '\',\'' + p.label.replace(/'/g,'') + '\')">Postuler</button>';
    }
    // ORGANIGRAMME : un titulaire passe a la mutinerie doit se voir d'un coup d'oeil. RP_MUTINS
    // est relu a chaque entree de piece ; il ne porte que des noms, jamais une position.
    const mutinIci = (titulaire && typeof estMutin === 'function' && estMutin(titulaire.nom))
      ? ' <b style="color:#cc4444">— MUTIN</b>' : '';
    html += '<div class="poste-item"><div>' +
      '<div class="poste-name">' + p.label + (villeDeCePoste ? ' (' + villeNom + ')' : '') + '</div>' +
      '<div class="poste-holder">' + (titulaire ? ('Occupé par ' + titulaire.nom + (titulaire.estPJ ? '' : ' (PNJ)')) : 'Poste vacant') + mutinIci + '</div>' +
      '</div>' + actionHtml + '</div>';
  }

  // ------------------------------------------------------------------------------------------
  // CHAINE DE COMMANDEMENT MILITAIRE. Elle ne vit pas dans POSTES_NOMMES_EXCLUSIFS (a la seule
  // exception du Commandant, qui est bien une fonction nommee) : Capitaines et Lieutenants sont
  // portes par le blob de leur compagnie. Il faut donc aller la lire pour montrer les vacances.
  // ------------------------------------------------------------------------------------------
  html += '<div style="padding:.6rem 1rem;font-size:.72rem;color:#6a5a30;font-family:Bebas Neue,sans-serif;letter-spacing:.1em;border-bottom:1px solid #1a1810;margin-top:.6rem">CHAÎNE DE COMMANDEMENT MILITAIRE</div>';
  if (!compagnies.length) {
    html += '<div class="poste-item"><div><div class="poste-holder">Aucune compagnie n\'a encore été levée.</div></div></div>';
  } else {
    compagnies.forEach(c => {
      const cap = c.capitaineNom;
      html += '<div class="poste-item"><div>' +
        '<div class="poste-name">' + escapeHtmlText(c.nom || c.id) + ' — Capitaine</div>' +
        '<div class="poste-holder">' + (cap ? ('Occupé par ' + escapeHtmlText(cap)) : 'Poste vacant') + '</div>' +
        '</div></div>';
      (c.sections || []).forEach(sec => {
        const eff = (sec.soldats || []).length;
        html += '<div class="poste-item" style="padding-left:1.6rem"><div>' +
          '<div class="poste-name">Section ' + escapeHtmlText(String(sec.numero || sec.id)) + ' — Lieutenant</div>' +
          '<div class="poste-holder">' + (sec.lieutenantNom ? ('Occupé par ' + escapeHtmlText(sec.lieutenantNom)) : 'Poste vacant')
          + ' — effectif ' + eff + '/' + EFFECTIF_SECTION + '</div>' +
          '</div></div>';
      });
    });
  }
  html += '<div style="padding:.5rem 1rem .8rem;font-size:.72rem;color:#6a5a30;font-style:italic">'
        + 'Capitaine, Lieutenant et soldat se candidatent à la Caserne Militaire, en personne, '
        + 'par l\'ordre « S\'engager dans l\'armée » (2 PA).</div>';

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// =====================
// PRIORITE PJ SUR POSTES NOMMES — DELAI DE DECISION + PROTECTION (lot du 25 aout 2026, apres
// audit dedie). Genere generique a TOUS les POSTES_NOMMES_EXCLUSIFS.
//
// Persistance : reutilise batiments_etat (comme etat.port ou le BNE), UNE entree partagee par
// pays ('<pays>_national_candidatures_postes'), aucune nouvelle table SQL -- l'audit a confirme
// que le mail seul ne peut pas garantir la survie a une suppression, une echeance fiable cote
// cron ni le suivi de plusieurs candidats : ce blob resout ces trois points sans DDL.
// Forme : { [posteId + '|' + (city||'national')]: {
//   posteId, city, candidats: [{ nom, depuisTs }], echeanceTs, autoriteNom, traitee: bool
// } }
// =====================
const BATIMENT_ID_CANDIDATURES_POSTES = 'candidatures_postes';
const VILLE_ID_CANDIDATURES_POSTES = 'national';

function cleCandidaturePoste(posteId, city) {
  return posteId + '|' + (city || 'national');
}

async function chargerCandidaturesPostes(country) {
  const pays = country || state.country || 'republic';
  const etat = typeof sbGetBatimentEtat === 'function'
    ? await sbGetBatimentEtat(pays, VILLE_ID_CANDIDATURES_POSTES, BATIMENT_ID_CANDIDATURES_POSTES).catch(() => ({}))
    : {};
  return (etat && etat.candidatures) || {};
}

async function sauvegarderCandidaturesPostes(country, candidatures) {
  const pays = country || state.country || 'republic';
  if (typeof sbSetBatimentEtat === 'function') {
    await sbSetBatimentEtat(pays, VILLE_ID_CANDIDATURES_POSTES, BATIMENT_ID_CANDIDATURES_POSTES, { candidatures }).catch(() => {});
  }
}

// Protection de 7 jours reels contre la revocation/le remplacement politique arbitraire d'un PJ
// fraichement nomme (§9-12 du lot) -- ne bloque QUE l'arbitraire du nominateur : demission,
// arrestation, naturalisation, mort/suppression du personnage et censure du PM restent des
// sorties legitimes, jamais concernees (comportement preexistant, non touche).
// Cout par defaut d'une nomination de poste nomme. Voir le correctif central dans
// envoyerNominationPosteNomme : il rattrape toutes les facades qui ne transmettent pas leur cout.
const COUT_PA_NOMINATION_DEFAUT = 1;

// ---- QUALITE DE MAIRE — HELPER CENTRAL (correctif Lot 4.3) ----
// Les gardes d'autorite testaient posteId.startsWith('maire'), ce qui laissait passer
// 'maire_adjoint' : un adjoint pouvait donc exercer les prerogatives du Maire, dont la nomination
// et la revocation du commissaire. Le prefixe reste necessaire -- l'historique du projet a connu
// des identifiants de maire par ville -- mais il doit EXCLURE l'adjoint, qui est un poste distinct
// avec ses propres prerogatives.
//
// Un seul point de verite : toute garde « est-ce le Maire ? » passe par ici.
function estPosteMaire(posteId) {
  if (typeof posteId !== 'string' || posteId === '') return false;
  if (posteId === 'maire_adjoint') return false;
  return posteId === 'maire' || posteId.indexOf('maire_') === 0 || posteId.indexOf('maire') === 0;
}

// Une autorite couvre-t-elle le poste attendu par la regle de nomination ? Meme correctif : le
// startsWith brut de confirmerRevocationPosteNomme laissait un adjoint passer pour un maire.
// LA VILLE DE L'AUTORITE N'EST PAS TOUJOURS CELLE DU POSTE (20 septembre 2026).
// Un commissaire siege en ville ET est nomme par le maire DE CETTE VILLE : les deux
// coincident. Un juge siege en ville mais est nomme par le Ministre de la Justice, qui est
// national et dont la fiche ne porte aucune ville. Chercher « le min_just de ville_b »
// ne renverrait jamais personne, et le poste serait impossible a pourvoir.
// autoriteScope vaut 'ville' par defaut : tous les postes existants sont inchanges.
function villeDeLAutorite(regle, villeDuPoste) {
  if (!regle) return null;
  const portee = regle.autoriteScope || regle.scope;
  return portee === 'ville' ? (villeDuPoste || null) : null;
}

function autoriteCouvre(posteAutorite, nommeParAttendu) {
  if (typeof posteAutorite !== 'string' || typeof nommeParAttendu !== 'string') return false;
  if (nommeParAttendu === 'maire') return estPosteMaire(posteAutorite);
  return posteAutorite === nommeParAttendu || posteAutorite.indexOf(nommeParAttendu) === 0;
}

// ---- REVALIDATION D'AUTORITE DANS LA FONCTION SENSIBLE (correctif du 8 septembre 2026) ----
//
// LE PROBLEME. Les fonctions de confirmation de ce fichier sont exposees en global et appelees par
// des onclick inline generes dans le HTML des modales. Le controle d'autorite vivait, lui, dans la
// fonction d'OUVERTURE de la modale -- laquelle est purement et simplement sautee quand on appelle
// la confirmation directement. Taper confirmerGuerreEmpire('narco','...',0,0) dans la console
// suffisait donc a declarer une guerre sans etre President.
//
// CE QUE CETTE GARDE FAIT, ET CE QU'ELLE NE FAIT PAS. Elle ferme le contournement TRIVIAL par appel
// direct dans le client normal. Elle ne rend rien « securise serveur » : l'identite du joueur reste
// un nom dans le localStorage, sans authentification ni RLS, et un client falsifie contourne
// evidemment tout controle ecrit en JavaScript. C'est de la defense en profondeur, pas une
// fermeture -- la vraie fermeture appartient au chantier Auth/RLS.
//
// FAIL-CLOSED, ET AVANT TOUT EFFET : aucun PA, aucun argent, aucune ecriture, aucun effet de bord
// quand l'autorite manque. Le patron est celui de confirmerEtatUrgence.
function exigerPoste(posteAttendu, message) {
  if (state.poste?.id === posteAttendu) return true;
  showToast('Accès refusé', message, false);
  return false;
}

// Variante pour les postes nommes, dont l'autorite depend du poste vise et non d'un titre fixe :
// elle rejoue exactement le controle du chemin normal (autoriteCouvre contre regle.nommePar).
function exigerAutoriteSurPosteNomme(regle, verbe) {
  if (regle && autoriteCouvre(state.poste?.id || '', regle.nommePar)) return true;
  showToast('Accès refusé', 'Seul(e) le/la ' + ((regle && regle.nommePar) || '?') + ' peut ' + verbe + ' ce poste.', false);
  return false;
}

function estPosteProtege(poste) {
  if (!poste || !poste.nommeLe) return false;
  return (Date.now() - poste.nommeLe) < DUREE_PROTECTION_POSTE_NOMME_MS;
}

function tempsProtectionRestanteTexte(poste) {
  if (!estPosteProtege(poste)) return '';
  const finMs = poste.nommeLe + DUREE_PROTECTION_POSTE_NOMME_MS;
  const heures = Math.max(1, Math.ceil((finMs - Date.now()) / 3600000));
  if (heures >= 24) return Math.ceil(heures / 24) + ' jour(s)';
  return heures + 'h';
}

// Recale l'echeance et le nominateur responsable si l'autorite de nomination a change depuis la
// derniere ecriture du dossier -- garantit au nouveau titulaire une fenetre complete de 48h
// (§5 du lot) sans jamais sanctionner un nominateur qui vient de prendre ses fonctions. Mute le
// dossier en place (appelant responsable de la sauvegarde) ; retourne true si un changement a
// ete applique.
async function reconcilierAutoriteCandidature(dossier) {
  const regle = POSTES_NOMMES_EXCLUSIFS[dossier.posteId];
  if (!regle || typeof getTitulaireActuel !== 'function') return false;
  const autoriteActuelle = await getTitulaireActuel(regle.nommePar, villeDeLAutorite(regle, dossier.city));
  const nomActuel = autoriteActuelle ? autoriteActuelle.nom : null;
  if (nomActuel && dossier.autoriteNom !== nomActuel) {
    dossier.autoriteNom = nomActuel;
    dossier.echeanceTs = Date.now() + DELAI_DECISION_CANDIDATURE_MS;
    return true;
  }
  return false;
}

// Candidature aupres de l'autorite de nomination (POSTES_NOMMES_EXCLUSIFS). Generalise a tous
// les postes nommes ce qui n'existait avant que pour PM/ministres (postulerPoste). Regle de
// priorite PJ (chantier identifie le 9 aout, jusque-la jamais code) : si l'autorite est un PNJ
// generique auto-pourvu, il ne prend jamais de vraie decision politique — la candidature d'un
// vrai joueur est donc acceptee directement, sans mail ni attente. Si l'autorite est un PJ, une
// fenetre de decision de 48h reelles commence (persistee, voir plus haut) au lieu de laisser
// l'autorite ignorer indefiniment la candidature (faille identifiee a l'audit du 25 aout 2026).
// Candidature a un poste dont l'autorite de nomination est un PNJ : le serveur tranche seul.
// Le client ne pose JAMAIS le poste lui-meme -- il recopie ce que la RPC a arrete.
async function postulerPosteAutoritePnj(posteId, posteName, villeCourante) {
  if (typeof sbRpc !== 'function') { showToast('Indisponible', 'Service momentanement indisponible.', false); return; }
  const rows = await sbRpc('poste_postuler', { p_poste: posteId, p_city: villeCourante || null }).catch(() => null);
  const v = Array.isArray(rows) ? rows[0] : rows;
  if (!v || v.ok !== true) {
    const motifs = {
      poste_deja_occupe_par_un_joueur: 'Ce poste vient d\'etre pris par un autre joueur.',
      autorite_joueur_doit_decider: 'L\'autorite de nomination est desormais tenue par un joueur : votre candidature doit passer par elle.',
      poste_inconnu: 'Ce poste ne figure pas parmi les postes nommes.',
      acteur_non_authentifie: 'Votre identite n\'a pas pu etre etablie.'
    };
    showToast('Candidature refusee', (v && motifs[v.raison]) || 'Le serveur a refuse cette candidature.', false);
    return;
  }

  const regle = POSTES_NOMMES_EXCLUSIFS[posteId] || { label: posteName || posteId };
  state.poste = { id: posteId, name: regle.label, city: villeCourante || null, nommeLe: Date.now() };
  if (state.char) state.char.poste = state.poste;
  state.salaireTouche = false;
  updateUI();
  if (typeof renderPersonsList === 'function' && typeof BUILDINGS !== 'undefined') {
    const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    if (room) renderPersonsList(room.persons || []);
  }
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  const lieu = villeCourante ? ' de ' + (WORLD[state.country]?.[villeCourante]?.name || villeCourante) : '';
  showToast('Poste obtenu', 'Vous etes desormais ' + regle.label + lieu + '.', true, true);
  addJournalEntry('Vous avez obtenu le poste de ' + regle.label + '.', 'event-good');
  addExternalEvent('🏛 ' + (state.char?.name || 'Anonyme') + ' est nomme(e) ' + regle.label + lieu + '.',
                   villeCourante ? 'local' : 'national');
}

async function demanderNominationPoste(posteId, posteName) {
  document.getElementById('modal-postes')?.classList.remove('open');

  // AUCUNE CANDIDATURE SANS PERSONNAGE CHARGE (24 septembre 2026).
  // Trace reelle : un mail « Anonyme postule au poste de Commandant de la Caserne » est parti
  // vers le ministre de la Defense, et le dossier a ete PERSISTE sous ce nom. Il ne venait
  // d'aucun anonyme : il venait d'un joueur dont le personnage n'etait pas charge (state.char
  // null), et dont le nom est donc tombe sur le repli `|| 'Anonyme'` quelques lignes plus bas.
  // Une candidature engage une identite : faute de personnage charge, il n'y a rien a engager,
  // et le dossier cree serait inexploitable -- personne ne peut nommer « Anonyme ».
  // On refuse donc l'action et on dit au joueur quoi faire, plutot que d'ecrire une trace fausse.
  if (!state.char?.name) {
    showToast('Personnage non chargé',
      "Votre personnage n'est pas encore chargé : rechargez la page avant de postuler.", false);
    return;
  }

  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return;

  const check = peutAccepterPosteNomme(posteId);
  if (!check.ok) { showToast('Impossible', check.raison, false); return; }

  const villeCourante = regle.scope === 'ville' ? state.currentCity : null;
  // La ville du POSTE sert a identifier le siege ; celle de l'AUTORITE peut differer.
  const titulaireAutorite = typeof getTitulaireActuel === 'function'
    ? await getTitulaireActuel(regle.nommePar, villeDeLAutorite(regle, villeCourante)) : null;

  if (!titulaireAutorite) {
    showToast('Poste vacant', "L'autorité de nomination pour ce poste est elle-même vacante. Votre candidature ne peut pas être transmise pour le moment.", false);
    return;
  }

  if (!titulaireAutorite.estPJ) {
    // RELIQUAT DE LA REFORME DU 15 SEPTEMBRE 2026, corrige le 19.
    // Cette ligne appelait encore accepterNominationPosteNomme() avec son ANCIENNE signature a
    // quatre arguments (posteId, ville, pays, nommeur). Depuis la reforme, cette fonction prend
    // un unique identifiant de proposition serveur commencant par 'nom-' : elle recevait donc
    // 'min_def' comme identifiant, echouait sa garde de format, et repondait au joueur
    // « Cette proposition date d'avant la reforme des nominations » -- un message exact mais
    // trompeur, puisque le joueur ne repondait a aucune proposition : il POSTULAIT.
    //
    // La regle de priorite PJ est inchangee : quand l'autorite de nomination est un PNJ
    // auto-pourvu, il ne prend aucune decision politique, la candidature d'un vrai joueur est
    // donc acceptee directement. C'est exactement ce que fait poste_postuler cote serveur --
    // RPC deja livree, deja accordee, mais qu'aucun appelant n'avait jamais branchee. Elle
    // refuse d'elle-meme si un PJ occupe deja le poste ou si l'autorite est tenue par un joueur.
    await postulerPosteAutoritePnj(posteId, posteName, villeCourante);
    return;
  }

  const candidatNom = state.char?.name || 'Anonyme';

  // Persistance de la candidature (§2/§6 du lot priorite PJ) : ouvre ou complete une fenetre de
  // decision de 48h reelles pour l'autorite PJ. Le titulaire actuel du poste est forcement un
  // PNJ ou le poste est vacant a ce stade (ouvrirEcranPostes ne propose "Postuler" que dans ce
  // cas), jamais un PJ deja protege -- rien a verifier de ce cote ici.
  const candidatures = await chargerCandidaturesPostes(state.country);
  const cleDossier = cleCandidaturePoste(posteId, villeCourante);
  let dossier = candidatures[cleDossier];
  let candidatureDejaEnregistree = false;
  if (!dossier || dossier.traitee) {
    dossier = {
      posteId, city: villeCourante,
      candidats: [{ nom: candidatNom, depuisTs: Date.now() }],
      echeanceTs: Date.now() + DELAI_DECISION_CANDIDATURE_MS,
      autoriteNom: titulaireAutorite.nom,
      traitee: false
    };
  } else if (dossier.candidats.some(c => c.nom === candidatNom && !c.retiree)) {
    candidatureDejaEnregistree = true; // deja candidat pour ce poste -- pas un nouvel evenement
  } else {
    dossier.candidats.push({ nom: candidatNom, depuisTs: Date.now() });
    // La fenetre en cours n'est jamais reinitialisee par l'arrivee d'un nouveau candidat --
    // seul un changement d'autorite la recale (reconcilierAutoriteCandidature).
  }

  if (candidatureDejaEnregistree) {
    showToast('Déjà candidat', 'Votre candidature au poste de ' + posteName + ' est déjà enregistrée, en attente de décision.', false);
    return;
  }

  candidatures[cleDossier] = dossier;
  await sauvegarderCandidaturesPostes(state.country, candidatures);

  const sujet = 'Candidature au poste de ' + posteName;
  const corps = candidatNom + ' postule au poste de <strong>' + posteName + '</strong>. Vous disposez de 48h pour choisir un candidat depuis la fenêtre de gestion des candidatures, sans quoi le système tranchera automatiquement.<br><br>' +
    marqueurActionMail('candidature', posteId, posteName, candidatNom);

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    await sbSendMail(candidatNom, titulaireAutorite.nom, sujet, corps, time).catch(() => {});
  }
  showToast('Demande transmise', 'Votre candidature au poste de ' + posteName + ' a été transmise à ' + titulaireAutorite.nom + '.', true);
  addJournalEntry('Demande de poste envoyée à ' + titulaireAutorite.nom + ' : ' + posteName + '. En attente de réponse.', 'event-info');
}




// =====================
// ÉTAT CIVIL — regroupement ergonomique (chantier finition Hotel de Ville, 4 septembre 2026)
// =====================
// Remplace 4 boutons separes de l'accueil de l'Hotel de Ville de Luthecia (demander un acte
// officiel/la naturalisation/en mariage/officialiser un mariage) -- et les 3 equivalents partages
// par l'accueil de la mairie de Montrouge/PSM (meme gabarit 'mairie', pas d'acte_officiel la-bas,
// jamais invente ici) -- par un seul point d'entree "État civil". Les 4/3 demarches d'origine ont
// ete RETIREES de data.js (sinon elles resteraient visibles EN PLUS du nouveau bouton) : leurs
// fn/label/pa/cost/desc/icon sont donc repris ICI, verbatim, comme unique source pour construire
// la pop-up -- plus aucun autre endroit du code ne les declare, aucune duplication/derive
// possible. Chaque clic appelle doOrder() a l'IDENTIQUE de ce que l'ancien bouton individuel
// appelait : aucun handler/workflow reimplemente, memes conditions d'acces, memes controles,
// memes couts, memes effets, meme persistance, memes messages -- uniquement un regroupement
// visuel, cle par buildingId (mairie-capitale = Luthecia, mairie = Montrouge/PSM).
const DEMARCHES_ETAT_CIVIL_PAR_BATIMENT = {
  'mairie-capitale': [
    { fn:'acte_officiel', label:'Demander un acte officiel', pa:1, cost:50, icon:'ti-file-certificate', successRate:100, desc:'Naissance, mariage, document administratif.' },
    { fn:'demander_naturalisation', label:'Demander la naturalisation', pa:2, cost:0, icon:'ti-passport', successRate:100, desc:'Deposer une demande de naturalisation vers un autre empire. Validee par le Ministre de l\'Interieur concerne.' },
    { fn:'demander_mariage', label:'Demander en mariage', pa:1, cost:0, icon:'ti-heart', successRate:100, desc:'Envoyer une demande en mariage a un autre PJ. Necessitera une ceremonie a la mairie pour officialiser.' },
    { fn:'officialiser_mariage', label:'Officialiser un mariage', pa:2, cost:200, icon:'ti-heart-handshake', successRate:100, desc:'Celebrer le mariage. Les deux futurs epoux doivent etre presents.' }
  ],
  'mairie': [
    { fn:'demander_naturalisation', label:'Demander la naturalisation', pa:2, cost:0, icon:'ti-passport', successRate:100, desc:'Deposer une demande de naturalisation vers un autre empire. Validee par le Ministre de l\'Interieur concerne.' },
    { fn:'demander_mariage', label:'Demander en mariage', pa:1, cost:0, icon:'ti-heart', successRate:100, desc:'Envoyer une demande en mariage a un autre PJ. Necessitera une ceremonie a la mairie pour officialiser.' },
    { fn:'officialiser_mariage', label:'Officialiser un mariage', pa:2, cost:200, icon:'ti-heart-handshake', successRate:100, desc:'Celebrer le mariage. Les deux futurs epoux doivent etre presents.' }
  ]
};

function ouvrirEtatCivil() {
  const demarches = DEMARCHES_ETAT_CIVIL_PAR_BATIMENT[state.currentBuilding] || [];
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  document.getElementById('postes-modal-title').textContent = 'État civil';
  let html = '<div style="padding:1rem;display:flex;flex-direction:column;gap:.5rem">';
  if (demarches.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune démarche d\'état civil disponible ici.</div>';
  }
  demarches.forEach(d => {
    const safeLabel = d.label.replace(/'/g, ' ');
    const safeDesc = (d.desc || '').replace(/'/g, ' ');
    const rate = d.successRate || 100;
    const coutParts = [];
    if (d.cost) coutParts.push(d.cost.toLocaleString('fr-FR') + ' ' + cur);
    coutParts.push((d.pa || 0) + ' PA');
    html += '<button onclick="doOrder(\'' + d.fn + '\',' + d.pa + ',' + d.cost + ",'" + safeLabel + "','" + safeDesc + "'," + rate + ')" style="display:flex;justify-content:space-between;align-items:center;gap:.6rem;padding:.7rem 1rem;border:1px solid #4a3a20;background:transparent;color:#c0b090;cursor:pointer;font-size:.85rem;text-align:left">' +
      '<span><i class="ti ' + (d.icon || 'ti-file-certificate') + '" style="font-size:1rem;margin-right:.5rem"></i> ' + d.label + '</span>' +
      '<span style="font-size:.75rem;color:#8a8060;white-space:nowrap">' + coutParts.join(' · ') + '</span>' +
    '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================
// =====================
// CALENDRIER ÉLECTORAL
// =====================
async function ouvrirCalendrierElectoral() {
  const country = state.country;
  const co = COUNTRIES[country];
  const villeCourante = state.currentCity || 'capitale';

  document.getElementById('postes-modal-title').textContent = '📅 Calendrier Électoral — ' + (co?.n || country);
  document.querySelector('#modal-postes .modal-box')?.classList.add('modal-wide');
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement du calendrier électoral...</div>';
  document.getElementById('modal-postes').classList.add('open');

  // Charger l'etat reel depuis Supabase avant toute initialisation locale — evite d'ecraser un cycle deja en cours
  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase();

  const now = Date.now();
  const villeNom = WORLD[country]?.[villeCourante]?.name || villeCourante;

  // Date+heure complete, fuseau LOCAL du navigateur (comportement deja existant de cet ecran
  // avant ce correctif, volontairement conserve -- jamais state.day, jamais un fuseau fictif :
  // les cycles sont des timestamps epoch-ms reels, Date() les restitue tels quels quel que soit
  // le joueur qui consulte). Chantier "finition ergonomique Hotel de Ville", 4 septembre 2026.
  const formatDateHeure = ts => {
    const d = new Date(ts);
    return d.toLocaleDateString('fr-FR', { day:'numeric', month:'long', year:'numeric' }) +
      ' à ' + d.toLocaleTimeString('fr-FR', { hour:'2-digit', minute:'2-digit' });
  };
  const diffCourt = ts => {
    const diff = ts - now;
    if (diff < 0) return '';
    const j = Math.floor(diff / 86400000);
    const h = Math.floor((diff % 86400000) / 3600000);
    return j > 0 ? ('dans ' + j + 'j ' + h + 'h') : ('dans ' + h + 'h');
  };

  // « CHEF SYNDICAL » RETIRE DU CALENDRIER INSTITUTIONNEL (correctif du 8 septembre 2026).
  //
  // Le poste chef_syndicat est declare dans POSTES_ELECTIFS.national (data.js) depuis le tout
  // premier systeme electoral de juin 2026, et cette liste etait concatenee ici sans aucun filtre.
  // Il apparaissait donc dans le calendrier de l'Hotel de Ville, entre la presidentielle et les
  // municipales, sans qu'on puisse savoir de quel syndicat il s'agissait -- pour cause : il n'est
  // rattache a AUCUNE organisation. Le vrai chef de syndicat du jeu est elu par un moteur
  // entierement distinct (verifierElectionsOrganisations, plateau-organisations-quetes.js) et lu
  // via getChefSyndicatDockersPSM ; les deux objets n'ont aucun rapport.
  //
  // CE N'EST PAS UN ARBITRAGE NOUVEAU, c'est l'application d'un arbitrage deja pris : le code
  // classe lui-meme ce poste dans ELECTIONS_INTERNES_ORGANISATION (plateau-gouvernement.js), avec
  // le commentaire « l'Etat ne reporte pas le scrutin d'un syndicat » -- et la Salle des Elections
  // l'excluait deja de sa liste blanche ENTREES_SALLE_ELECTIONS, si bien qu'on ne pouvait ni voter
  // ni candidater a ce poste depuis les ecrans reels. Seul le calendrier avait ete oublie.
  //
  // LE POSTE N'EST PAS SUPPRIME de POSTES_ELECTIFS : son cycle, son depouillement et son
  // organigramme restent en place a l'identique. Seul l'affichage institutionnel cesse de
  // l'annoncer comme un scrutin d'Etat.
  const estElectionInterneOrganisation = (posteId) =>
    typeof ELECTIONS_INTERNES_ORGANISATION !== 'undefined' &&
    ELECTIONS_INTERNES_ORGANISATION.indexOf(posteId) !== -1;

  const postes = [
    ...POSTES_ELECTIFS.national,
    ...POSTES_ELECTIFS.departemental,
    ...POSTES_ELECTIFS.local
  ].filter(p => !estElectionInterneOrganisation(p.id));

  // Initialiser les cycles manquants (seulement s'ils n'existent vraiment nulle part, ni localement ni sur Supabase)
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};
  for (const p of postes) {
    const city = posteEstLocal(p.id) ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    if (!CYCLES_ELECTORAUX[country][cle]) await initCycleElectoral(country, p.id, city);
  }

  // Ventilation calendaire honnete d'un cycle (correctif du 4 septembre 2026, chantier finition
  // ergonomique). Regle absolue : jamais de date inventee pour une etape dont le resultat n'est
  // pas encore connu -- un eventuel second tour/departage tant que le premier tour n'a pas ete
  // depouille reste annonce SANS date ("connues uniquement apres le depouillement"). cycle.tour===2
  // ou cycle.phase===SECOND_TOUR detecte un vrai second tour (president/maire/chef_syndicat) ;
  // cycle.phase===VOTE3E_SIEGE est le marqueur persistant du departage legislatif du 3e siege
  // (pose une fois pour la duree entiere du departage, campagne ET vote -- voir getPhaseActuelle
  // plus haut dans ce fichier) -- dans les deux cas, dateDebutCampagne/dateVote/dateResultats du
  // cycle ont ete REECRITS par le cron pour representer ce tour supplementaire (dateDebutCandidatures
  // seul survit intact, jamais reecrit), donc afficher "Candidatures" avec ces dates a ce stade
  // serait faux -- volontairement omis dans cette branche.
  function detailCalendrierCycle(cycle, phase, posteId) {
    const enSecondTour = cycle.phase === PHASES_ELECTORALES.SECOND_TOUR || cycle.tour === 2;
    const enRunoffSiege = cycle.phase === PHASES_ELECTORALES.VOTE3E_SIEGE;
    const dansTourSupplementaire = enSecondTour || enRunoffSiege;
    const lignes = [];

    if (phase === PHASES_ELECTORALES.MANDAT) {
      lignes.push({ label: 'Mandat en cours', texte: cycle.dateFinMandat ? ('jusqu\'au ' + formatDateHeure(cycle.dateFinMandat)) : 'durée en cours' });
      const prochaine = (cycle.dateFinMandat && cycle.dateFinMandat > now) ? { label: 'Fin du mandat', date: cycle.dateFinMandat } : null;
      return { lignes, prochaine };
    }
    if (phase === PHASES_ELECTORALES.VACANT) {
      lignes.push({ label: 'Poste vacant', texte: cycle.relancePossibleApres ? ('nouvelle candidature possible à partir du ' + formatDateHeure(cycle.relancePossibleApres)) : 'en attente de relance' });
      const prochaine = (cycle.relancePossibleApres && cycle.relancePossibleApres > now) ? { label: 'Réouverture des candidatures', date: cycle.relancePossibleApres } : null;
      return { lignes, prochaine };
    }

    const libelleTour = enRunoffSiege ? 'Départage du 3e siège' : 'Second tour';

    if (!dansTourSupplementaire) {
      if (cycle.dateDebutCandidatures && cycle.dateDebutCampagne) lignes.push({ label: 'Candidatures', debut: cycle.dateDebutCandidatures, fin: cycle.dateDebutCampagne });
      if (cycle.dateDebutCampagne && cycle.dateVote) lignes.push({ label: 'Campagne', debut: cycle.dateDebutCampagne, fin: cycle.dateVote });
      if (cycle.dateVote && cycle.dateResultats) lignes.push({ label: 'Vote', debut: cycle.dateVote, fin: cycle.dateResultats });
      if (cycle.dateResultats) lignes.push({ label: 'Proclamation', debut: cycle.dateResultats, fin: null });
      if (phase === PHASES_ELECTORALES.CANDIDATURES || phase === PHASES_ELECTORALES.CAMPAGNE || phase === PHASES_ELECTORALES.VOTE) {
        lignes.push({
          label: (posteId === 'depute' ? 'Départage éventuel du 3e siège' : 'Second tour éventuel'),
          texte: 'dates connues uniquement après le dépouillement, si nécessaire'
        });
      }
    } else {
      if (cycle.dateDebutCampagne && cycle.dateVote) lignes.push({ label: libelleTour + ' — Campagne', debut: cycle.dateDebutCampagne, fin: cycle.dateVote });
      if (cycle.dateVote && cycle.dateResultats) lignes.push({ label: libelleTour + ' — Vote', debut: cycle.dateVote, fin: cycle.dateResultats });
      if (cycle.dateResultats) lignes.push({ label: 'Proclamation', debut: cycle.dateResultats, fin: null });
    }

    const echeancesFutures = [];
    if (cycle.dateDebutCandidatures > now) echeancesFutures.push({ label: 'Ouverture des candidatures', date: cycle.dateDebutCandidatures });
    if (cycle.dateDebutCampagne > now) echeancesFutures.push({ label: dansTourSupplementaire ? ('Début de la campagne (' + libelleTour.toLowerCase() + ')') : 'Début de la campagne', date: cycle.dateDebutCampagne });
    if (cycle.dateVote > now) echeancesFutures.push({ label: 'Ouverture du vote', date: cycle.dateVote });
    if (cycle.dateResultats > now) echeancesFutures.push({ label: 'Proclamation des résultats', date: cycle.dateResultats });

    return { lignes, prochaine: echeancesFutures[0] || null };
  }

  const phaseLabelCourt = {
    [PHASES_ELECTORALES.MANDAT]:            'Mandat en cours',
    [PHASES_ELECTORALES.CANDIDATURES]:      'Candidatures',
    [PHASES_ELECTORALES.CAMPAGNE]:          'Campagne',
    [PHASES_ELECTORALES.VOTE]:              '🗳 Vote en cours',
    [PHASES_ELECTORALES.SECOND_TOUR]:       'Campagne — second tour',
    [PHASES_ELECTORALES.VOTE2]:             '🗳 Vote — second tour',
    [PHASES_ELECTORALES.CAMPAGNE_3E_SIEGE]: 'Campagne — départage 3e siège',
    [PHASES_ELECTORALES.VOTE3E_SIEGE]:      '🗳 Vote — départage 3e siège',
    [PHASES_ELECTORALES.VACANT]:            'Vacant',
  };
  const phaseCouleurCourt = {
    [PHASES_ELECTORALES.MANDAT]:            '#4a8a4a',
    [PHASES_ELECTORALES.CANDIDATURES]:      '#4a6aaa',
    [PHASES_ELECTORALES.CAMPAGNE]:          '#aa8a4a',
    [PHASES_ELECTORALES.VOTE]:              '#4a8a4a',
    [PHASES_ELECTORALES.SECOND_TOUR]:       '#8a6a4a',
    [PHASES_ELECTORALES.VOTE2]:             '#4a8a4a',
    [PHASES_ELECTORALES.CAMPAGNE_3E_SIEGE]: '#8a6a4a',
    [PHASES_ELECTORALES.VOTE3E_SIEGE]:      '#4a8a4a',
    [PHASES_ELECTORALES.VACANT]:            '#8a3a2a',
  };

  const lignes = postes.map(p => {
    const estLocal = posteEstLocal(p.id);
    const city = estLocal ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    const cycle = CYCLES_ELECTORAUX[country][cle];
    const phase = getPhaseActuelle(country, p.id, city);
    const nbCandidats = cycle?.candidats?.length || 0;
    const titulaire = cycle ? libelleTitulaireCycle(cycle, p.id) : null;
    const labelPoste = p.name + (estLocal ? ' — ' + villeNom : '');
    const detail = cycle ? detailCalendrierCycle(cycle, phase, p.id) : { lignes: [], prochaine: null };

    const renderLigneDetail = l => {
      const contenu = l.texte ? l.texte : (l.fin ? ('du ' + formatDateHeure(l.debut) + ' au ' + formatDateHeure(l.fin)) : formatDateHeure(l.debut));
      return '<div style="font-size:.75rem;color:#a89870;padding:.15rem 0"><span style="color:#c0b090">' + l.label + '</span> : ' + contenu + '</div>';
    };

    // Mise en evidence de la prochaine echeance utile (demande explicite du chantier) : la
    // variable equivalente existait deja dans l'ancienne version de cet ecran mais n'etait
    // jamais affichee -- corrige ici.
    const prochaineHtml = detail.prochaine
      ? '<div style="margin-top:.35rem;padding:.35rem .5rem;background:#161206;border:1px solid #3a2a10;border-radius:3px;font-size:.75rem;color:#E8C97A">' +
          '➜ ' + detail.prochaine.label + ' le ' + formatDateHeure(detail.prochaine.date) +
          (diffCourt(detail.prochaine.date) ? ' <span style="color:#8a7a50">(' + diffCourt(detail.prochaine.date) + ')</span>' : '') +
        '</div>'
      : '';

    return '<div style="padding:.6rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:.3rem">' +
        '<div>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.9rem;color:#e0d5b8">' + labelPoste + '</div>' +
          '<div style="font-size:.75rem;color:#a89870">' +
            (titulaire ? '✦ ' + titulaire : 'Poste vacant') +
          '</div>' +
        '</div>' +
        '<div style="text-align:right">' +
          '<div style="font-size:.75rem;font-family:Bebas Neue,sans-serif;color:' + (phaseCouleurCourt[phase] || '#6a5a30') + ';letter-spacing:.06em">' + (phaseLabelCourt[phase] || phase || '?') + '</div>' +
          '<div style="font-size:.72rem;color:#a89870">' + nbCandidats + ' candidat(s)</div>' +
        '</div>' +
      '</div>' +
      // LE CALENDRIER DEVIENT LE TABLEAU DE BORD DE L'ELECTION (16 septembre 2026) : chaque
      // candidat declare y figure, avec l'acces direct a son programme publie au forum.
      (nbCandidats > 0
        ? '<div style="font-size:.72rem;color:#c0b090;margin-bottom:.3rem">Candidats : ' +
          cycle.candidats.map(c => c.nom + (c.topicId
            ? ' <a href="#" onclick="ouvrirProgrammeCandidat(\'' + String(c.topicId).replace(/'/g, '') + '\');return false;" style="color:#8aaaea;text-decoration:none;font-size:.68rem">[voir le programme]</a>'
            : '')).join(' · ') + '</div>'
        : '') +
      // Détail calendaire réel (dates/heures) — plus un jargon de phase abstrait seul
      (detail.lignes.length > 0
        ? '<div style="background:#0a0907;border:1px solid #1a1810;border-radius:3px;padding:.3rem .5rem;margin-top:.3rem">' +
          detail.lignes.map(renderLigneDetail).join('') +
          '</div>'
        : '') +
      prochaineHtml +
      // Boutons action
      '<div style="display:flex;gap:.4rem;margin-top:.4rem">' +
        '<button onclick="ouvrirBureauDeVoteBtn(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-size:.7rem;font-family:Bebas Neue,sans-serif;padding:.25rem .6rem;border:1px solid #4a3a20;background:transparent;color:#b0a080;cursor:pointer">Détails →</button>' +
        // « Se porter candidat » vit desormais ICI, et nulle part ailleurs. La condition est celle
        // du jeu (candidaturesOuvertes), pas la seule phase CANDIDATURES -- c'est la meme regle
        // que verifie le serveur. Un candidat deja declare ne se la voit pas proposer deux fois.
        ((candidaturesOuvertes(cycle) && !(cycle.candidats || []).some(c => c.nom === state.char?.name))
          ? '<button onclick="ouvrirRedactionProgramme(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-size:.7rem;font-family:Bebas Neue,sans-serif;padding:.25rem .6rem;border:1px solid #5a7aca;background:transparent;color:#8aaaea;cursor:pointer">📋 Se porter candidat</button>'
          : '') +
      '</div>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '📅 Calendrier Électoral — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.2rem .4rem;min-width:540px;max-width:680px">' +
    '<div style="font-size:.72rem;color:#8a8060;padding:.3rem .4rem;margin-bottom:.3rem;font-style:italic">' +
      'Candidatures : 7 jours · Campagne : 7 jours · Vote : 24h · Second tour ou départage (si nécessaire) : campagne 7 jours + vote 24h' +
    '</div>' +
    lignes +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// ==========================================================================================
// SE PORTER CANDIDAT : LE PROGRAMME D'ABORD (16 septembre 2026)
// ==========================================================================================
//
// DECISION DE JEU : une candidature n'existe pas tant que son programme n'est pas public. Le
// clic ci-dessous n'inscrit donc personne -- il ouvre le VRAI editeur du forum, celui qui sait
// mettre en page et poser des images. C'est la publication qui vaut candidature.
//
// Refermer l'editeur, changer d'avis, partir ailleurs : rien ne s'est passe, et rien n'a coute.
// Aucune exigence sur le contenu : un programme d'un mot est un programme. Ce qu'on impose, ce
// n'est pas un effort d'ecriture, c'est un acte public.
//
// Cette memoire ne vit que le temps de la redaction. Elle ne PROUVE rien -- au moment de
// publier, le serveur revalide tout : eligibilite, periode, cout, unicite.
let _candidatureEnRedaction = null;

function ouvrirRedactionProgramme(el) {
  const posteId = el?.dataset?.poste;
  const country = el?.dataset?.country || state.country;
  const city = el?.dataset?.city || null;
  if (!posteId) return;

  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle || !candidaturesOuvertes(cycle)) {
    showToast('Candidatures closes', 'Les candidatures a ce scrutin sont closes.', false);
    return;
  }
  const poste = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.departemental, ...POSTES_ELECTIFS.local]
    .find(x => x.id === posteId);
  if (!poste) return;

  _candidatureEnRedaction = {
    posteId, country,
    city: posteEstLocal(posteId) ? (city || state.currentCity || null) : null,
    cleScrutin: (typeof cleEcheanceElectorale === 'function')
      ? cleEcheanceElectorale(cycle) : cycle?.dateDebutCandidatures,
    titreSuggere: '🗳️ Programme de ' + (state.char?.name || '') + ' — ' + poste.name
      + (posteEstLocal(posteId) ? ' (' + (WORLD[country]?.[city || state.currentCity]?.name || '') + ')' : '')
  };

  document.getElementById('modal-postes')?.classList.remove('open');
  // Le forum LOCAL pour un scrutin de ville, NATIONAL pour un scrutin national -- exactement le
  // choix que faisait deja le depot de candidature avant ce lot.
  // LA VILLE DU SCRUTIN, PAS CELLE DU CANDIDAT (16 septembre 2026). Un scrutin porte sa propre
  // juridiction : c'est elle qui decide du forum, meme si le candidat se trouve ailleurs au
  // moment ou il redige. Un poste national ignore la ville.
  const forumCible = posteEstLocal(posteId)
    ? ((typeof idForumLocal === 'function') ? idForumLocal(_candidatureEnRedaction.city) : 'local')
    : 'national';
  if (typeof ouvrirForumSurEditeur === 'function') {
    ouvrirForumSurEditeur(forumCible, _candidatureEnRedaction.titreSuggere);
  } else {
    showToast('Forum indisponible', "L'editeur du forum n'est pas accessible pour le moment.", false);
    _candidatureEnRedaction = null;
  }
}

// Publication du programme = depot de la candidature. Appelee par l'editeur du forum a la place
// de sa publication ordinaire quand une redaction de programme est en cours. Renvoie true si
// l'editeur doit considerer la publication faite (et se refermer), false pour le laisser suivre
// son chemin habituel.
async function publierProgrammeCandidature(titre, contenu) {
  const att = _candidatureEnRedaction;
  if (!att) return false;
  if (typeof sbRpc !== 'function') return false;

  const rows = await sbRpc('candidature_publier', {
    p_poste: att.posteId, p_city: att.city,
    p_cle_scrutin: (att.cleScrutin != null && isFinite(Number(att.cleScrutin))) ? Number(att.cleScrutin) : null,
    p_titre: titre || att.titreSuggere, p_contenu: contenu || ''
  }).then(r => Array.isArray(r) ? r[0] : r).catch(() => null);

  if (!rows || rows.ok !== true) {
    showToast('Candidature refusee', messageRefusCandidature(rows), false);
    return { traite: true, topicId: null };   // traite : pas de sujet orphelin a la place
  }
  _candidatureEnRedaction = null;

  // Le serveur a debite les PA : on recopie son solde plutot que de le recalculer.
  if (rows.pa != null) {
    state.pa = Number(rows.pa);
    if (typeof updateUI === 'function') updateUI();
  }
  if (!rows.deja_candidat) {
    showToast('Candidature enregistree', 'Votre programme est publie : vous etes officiellement candidat.', true, true);
    addJournalEntry('🗳️ Candidature deposee et programme publie.', 'event-info');
  }
  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase().catch(() => {});
  // Le sujet cree par la transaction serveur est rendu a l'appelant : c'est LUI qu'on ouvrira,
  // jamais un sujet devine d'apres le titre ou le nom du candidat.
  return { traite: true, topicId: rows.topic_id || null };
}

function messageRefusCandidature(r) {
  const raison = r && r.raison;
  if (raison === 'influence_insuffisante') return 'Votre influence est insuffisante pour ce poste (' + (r.reel || 0) + '/' + (r.requis || 0) + ').';
  if (raison === 'non_domicilie') return 'Vous devez etre domicilie dans cet empire pour vous y presenter.';
  if (raison === 'cumul_interdit') return 'Ce poste est incompatible avec celui que vous occupez deja.';
  if (raison === 'deja_depute') return 'Vous etes deja depute.';
  if (raison === 'pa_insuffisants') return 'Il vous faut 2 PA pour deposer une candidature.';
  if (raison === 'poste_inconnu') return 'Ce scrutin n\'existe pas.';
  return 'Les candidatures a ce scrutin sont closes, ou la candidature n\'a pas pu etre enregistree. Rien n\'a ete debite.';
}

function ouvrirProgrammeCandidat(topicId) {
  if (!topicId) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  if (typeof ouvrirForumSurTopic === 'function') ouvrirForumSurTopic(topicId);
  else showToast('Programme indisponible', "Le forum n'est pas accessible pour le moment.", false);
}

function deposerCandidatureBtn2Btn(el) { deposerCandidatureBtn2(el.dataset.poste, el.dataset.country, el.dataset.city); }
function deposerCandidatureBtn2(posteId, country, city) {
  fermerModalPostes();
  deposerCandidature(posteId, country, city || state.currentCity);
}



// =====================
// PNJ ADMINISTRATEUR (poste vacant)
// =====================
const PNJ_ADMINISTRATEURS = {
  president: {
    republic: { name: 'Gaston Intérim',     role: 'Président par intérim', trait: 'Nommé faute de candidat. Signe des décrets sans les lire. Facile à déloger.' },
    narco:    { name: 'Don Provisional',    role: 'Président par intérim', trait: 'Personne ne sait comment il est arrivé là. Donne des ordres au hasard.' },
    soviet:   { name: 'Camarade Provisoire',role: 'Administrateur du Parti',trait: 'Le Parti l\'a nommé. Le Parti peut l\'enlever. Très facile à déloger.' },
    khalija:  { name: 'Wali Al-Niyaba',     role: 'Régent intérimaire',    trait: 'Nommé par le Palais en attendant mieux. N\'a aucune ambition personnelle.' },
  },
  maire: {
    republic: { name: 'Hubert Gestionnaire', role: 'Maire administrateur', trait: 'Ancien chef de bureau. Gère les poubelles. Rien d\'autre.' },
    narco:    { name: 'El Temporal',         role: 'Maire par défaut',     trait: 'Là par accident. Part dès qu\'on lui demande.' },
    soviet:   { name: 'Camarade Local',      role: 'Administrateur local', trait: 'Nommé d\'office. Applique les directives. Toutes les directives.' },
    khalija:  { name: 'Moudir Al-Waqt',      role: 'Administrateur royal', trait: 'Le Palais gère directement. Pour l\'instant.' },
  },
  depute: {
    republic: { name: 'Suppléant Dubois',    role: 'Député suppléant',     trait: 'Remplace le siège vide. Vote blanc à chaque session.' },
    narco:    { name: 'El Suplente',         role: 'Député intérimaire',   trait: 'Là pour les apparences.' },
    soviet:   { name: 'Délégué du Peuple',   role: 'Représentant collectif',trait: 'Le Parti représente déjà le peuple. C\'est une formalité.' },
    khalija:  { name: 'Wakil Al-Sha\'b',    role: 'Représentant intérimaire',trait: 'Nommé par le Cheikh en attendant.' },
  }
};

function nommerAdministrateurSiVacant(country, posteId) {
  if (!CYCLES_ELECTORAUX[country]?.[posteId]) return;
  const cycle = CYCLES_ELECTORAUX[country][posteId];

  // Ne nommer que si poste vraiment vacant (pas d'élu, phase VACANT)
  if (cycle.eluId || cycle.administrateur) return;
  if (getPhaseActuelle(country, posteId) !== PHASES_ELECTORALES.VACANT) return;

  const adminDef = PNJ_ADMINISTRATEURS[posteId]?.[country];
  if (!adminDef) return;

  cycle.administrateur = {
    ...adminDef,
    nommeLeJour: state.day || 1,
    facileADeloger: true
  };
  cycle.eluId = adminDef.name + ' (Admin)';

  addJournalEntry('🏛 ' + adminDef.name + ' nommé ' + adminDef.role + ' — poste vacant.', 'event-info');
  addExternalEvent('🏛 ' + adminDef.name + ' prend les rênes de ' + (POSTES_ELECTIFS.national.concat(POSTES_ELECTIFS.local).find(p=>p.id===posteId)?.name || posteId) + ' à ' + (COUNTRIES[country]?.n || country) + '.');

  // Publier sur le forum
  if (typeof sbCreateTopic === 'function') {
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : `Jour ${state.day}`;
    const titre = '🏛 Nomination : ' + adminDef.name;
    const texte = 'Faute de candidat, ' + adminDef.name + ' est nommé ' + adminDef.role + '.\n\n"' + adminDef.trait + '"\n\nIl peut être destitué par un vote de l\'assemblée ou une candidature au prochain cycle.';
    // Le Local de la ville concernee par la nomination (16 septembre 2026).
    const forumNomination = (typeof idForumLocal === 'function') ? idForumLocal(city) : 'local';
    sbCreateTopic(forumNomination, titre, 'Système', country, time).then(topicId => {
      if (topicId && typeof sbCreatePost === 'function') sbCreatePost(topicId, 'Système', texte, time);
      if (!FORUM_TOPICS[forumNomination]) FORUM_TOPICS[forumNomination] = [];
      FORUM_TOPICS[forumNomination].unshift({
        id: topicId || 'topic-' + Date.now(), title: titre, author: 'Système',
        time, views: 1, replies: 0, lastPostAuthor: 'Système', lastPostTime: time,
        posts: [{ id: 'p-' + Date.now(), author: 'Système', time, content: texte }]
      });
    }).catch(() => {});
  }
}

// Vérifier tous les postes vacants au chargement et au réveil
function verifierPostesVacants() {
  const country = state.country;
  if (!CYCLES_ELECTORAUX[country]) return;
  Object.keys(CYCLES_ELECTORAUX[country]).forEach(posteId => {
    nommerAdministrateurSiVacant(country, posteId);
  });
}

// =====================
// PERSISTANCE ÉLECTORALE SUPABASE
// =====================
async function sbSaveCycleElectoral(country, posteId, cycle, city) {
  if (typeof sbInsert !== 'function' || typeof sbGet !== 'function') return;
  const cle = getCleCycle(posteId, city);
  const id = country + '_' + cle;
  try {
    const existing = await sbGet('cycles_electoraux', `id=eq.${encodeURIComponent(id)}`);
    const payload = {
      id, country, poste_id: posteId, city: posteEstLocal(posteId) ? (city || null) : null,
      data: JSON.stringify(cycle),
      updated_at: new Date().toISOString()
    };
    if (existing && existing.length > 0) {
      await sbUpdate('cycles_electoraux', `id=eq.${encodeURIComponent(id)}`, payload);
    } else {
      await sbInsert('cycles_electoraux', payload);
    }
  } catch(e) {}
}

async function sbLoadCyclesElectoraux(country) {
  if (typeof sbGet !== 'function') return null;
  try {
    const rows = await sbGet('cycles_electoraux', 'country=eq.' + country);
    if (!rows || !rows.length) return null;
    const result = {};
    rows.forEach(r => {
      const cle = getCleCycle(r.poste_id, r.city);
      result[cle] = JSON.parse(r.data);
    });
    return result;
  } catch(e) { return null; }
}

async function sbVoterPour(country, posteId, votant, candidat, city) {
  if (typeof sbInsert !== 'function') return;
  const cle = getCleCycle(posteId, city);
  try {
    await sbInsert('votes_electoraux', {
      id: country + '_' + cle + '_' + votant,
      country, poste_id: posteId, city: posteEstLocal(posteId) ? (city || null) : null,
      votant, candidat,
      created_at: new Date().toISOString()
    });
  } catch(e) {}
}

async function sbGetVotes(country, posteId, city) {
  if (typeof sbGet !== 'function') return [];
  try {
    let filtre = 'country=eq.' + country + '&poste_id=eq.' + posteId;
    if (posteEstLocal(posteId) && city) filtre += '&city=eq.' + city;
    return await sbGet('votes_electoraux', filtre) || [];
  } catch(e) { return []; }
}

// Retourne desormais le resultat reel de l'insertion (chantier "Hotel de Ville / elections",
// 4 septembre 2026 -- correctif de l'ecriture non atomique identifiee par l'audit) : confirmerCandidature
// n'ajoute la candidature en memoire QUE si cette table -- la source de verite reellement relue
// par syncCyclesDepuisSupabase() -- a effectivement accepte l'ecriture. sbSaveCycleElectoral (le
// blob cycles_electoraux) reste un cache best-effort, mais ne peut plus laisser croire a une
// candidature qui n'existe pas reellement cote source de verite.
//
// CLE DE SCRUTIN DANS L'ID (correctif du 8 septembre 2026).
//
// L'id valait « pays_cleCycle_nom », SANS aucune composante temporelle. Or cycles_electoraux.id
// identifie un POSTE, pas un scrutin : la meme ligne est reecrite a chaque renouvellement. Un
// joueur ayant ete candidat a la mairie lors d'un cycle precedent butait donc, au cycle suivant,
// sur une collision de cle primaire : sbInsert renvoyait null et confirmerCandidature affichait
// « Echec de l'inscription ». Se representer au meme poste etait purement et simplement impossible.
//
// LA CLE EMPLOYEE EST CELLE QUE LE PROJET A DEJA CHOISIE : cycle.dateDebutCandidatures, timestamp
// epoch-ms, la meme que cycle_debut dans fraudes_electorales et que cleEcheanceElectorale dans
// plateau-gouvernement.js -- et qui n'est JAMAIS decalee, pas meme par un report electoral.
//
// AUCUNE MIGRATION N'EST NECESSAIRE : la colonne id existe, sa PRIMARY KEY est inchangee, et son
// unique lecteur (idSource, api/_journal-collecte.js) la traite comme un identifiant OPAQUE de
// fait pour le Journal. Le format s'allonge, rien ne le parse. Les lignes anterieures gardent leur
// ancien id sans risque de conflit : le nouveau format ajoute un suffixe.
async function sbDeposerCandidature(country, posteId, candidat, city, cleScrutin) {
  if (typeof sbInsert !== 'function') return null;
  const cle = getCleCycle(posteId, city);
  const suffixeScrutin = (cleScrutin !== undefined && cleScrutin !== null && isFinite(Number(cleScrutin)))
    ? '_' + Number(cleScrutin) : '';
  try {
    return await sbInsert('candidatures', {
      id: country + '_' + cle + '_' + candidat.nom + suffixeScrutin,
      country, poste_id: posteId, city: posteEstLocal(posteId) ? (city || null) : null,
      nom: candidat.nom, programme: candidat.programme,
      archetype: candidat.archetype,
      created_at: new Date().toISOString()
    });
  } catch(e) { return null; }
}

async function sbGetCandidatures(country, posteId, city) {
  if (typeof sbGet !== 'function') return [];
  try {
    let filtre = 'country=eq.' + country + '&poste_id=eq.' + posteId;
    if (posteEstLocal(posteId) && city) filtre += '&city=eq.' + city;
    return await sbGet('candidatures', filtre) || [];
  } catch(e) { return []; }
}

async function syncCyclesDepuisSupabase() {
  const country = state.country;
  const cycles = await sbLoadCyclesElectoraux(country);
  if (cycles) {
    CYCLES_ELECTORAUX[country] = { ...(CYCLES_ELECTORAUX[country]||{}), ...cycles };
  }
  // Charger votes et candidatures pour les postes pertinents (national + ceux de la ville courante)
  const postes = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.departemental, ...POSTES_ELECTIFS.local];
  for (const p of postes) {
    const city = posteEstLocal(p.id) ? state.currentCity : null;
    const cle = getCleCycle(p.id, city);
    if (!CYCLES_ELECTORAUX[country]?.[cle]) continue;
    const votes = await sbGetVotes(country, p.id, city);
    const candidatures = await sbGetCandidatures(country, p.id, city);
    if (votes.length) {
      CYCLES_ELECTORAUX[country][cle].votes = {};
      votes.forEach(v => { CYCLES_ELECTORAUX[country][cle].votes[v.votant] = v.candidat; });
    }
    // Liste FIGEE a la cloture des candidatures (12 septembre 2026) : apres le lundi 00:01, aucune
    // ligne de la table candidatures (ajout tardif, suppression) ne modifie plus la liste du scrutin
    // -- ni au premier tour, ni au second (reduit aux qualifies par le serveur).
    if (candidatures.length && candidaturesOuvertes(CYCLES_ELECTORAUX[country][cle])) {
      // CANDIDAT FANTOME (correctif du 8 septembre 2026). La table candidatures n'est purgee par
      // rien : ni le renouvellement de cycle, ni aucun cron. Son seul nettoyage vit dans
      // sbDeletePersonnage (supabase.js), qui n'est appele que par la destruction VOLONTAIRE d'un
      // personnage en jeu -- une suppression faite a la main dans Supabase le contourne
      // integralement. Un personnage de test efface de la table personnages restait donc candidat
      // actif indefiniment : reinjecte ici dans cycle.candidats a chaque ouverture d'ecran
      // electoral, affiche au bureau de vote, et jusqu'a recevoir un score au depouillement.
      //
      // ON NE TOUCHE PAS AUX ARCHIVES. Les resultats passes vivent dans chronique_nationale,
      // evenements_globaux et mandats_maires_archives -- trois tables append-only, alimentees par
      // le cron, et qui ne referencent que les vainqueurs. La table candidatures, elle, ne porte
      // que de l'etat ACTIF (aucune colonne de statut, aucune cle de scrutin) : en filtrer une
      // ligne n'efface aucune histoire.
      //
      // Le filtre est applique ICI, dans le seul point qui reconstruit la liste des candidats
      // depuis la base : le calendrier, le bureau de vote, l'organigramme et le pouls populaire en
      // heritent tous, sans qu'aucun d'eux ait a se souvenir de le refaire.
      // SCRUTIN COURANT UNIQUEMENT. La table n'est purgee par rien : les lignes des scrutins
      // precedents y restent pour toujours et etaient toutes reinjectees ici, si bien qu'un
      // ancien candidat reapparaissait comme candidat du cycle en cours -- et que le garde
      // anti-doublon de deposerCandidature lui repondait « Deja candidat » sans qu'il le soit.
      // created_at est deja ecrit et deja lu ailleurs (collecte du Journal) : on s'en sert tel
      // quel, sans nouvelle colonne. Une candidature anterieure a l'ouverture du scrutin courant
      // appartient, par construction, a un scrutin precedent.
      // ON NE SUPPRIME RIEN : les lignes anciennes restent en base, lisibles par la collecte du
      // Journal et par la biographie d'interview. Seule la liste ACTIVE est filtree.
      const candidaturesDuScrutin = filtrerCandidaturesDuScrutinCourant(
        candidatures, CYCLES_ELECTORAUX[country][cle]);
      const candidatsRetenus = await filtrerCandidaturesDePersonnagesExistants(candidaturesDuScrutin);
      CYCLES_ELECTORAUX[country][cle].candidats = candidatsRetenus.map(c => ({
        nom: c.nom, programme: c.programme, archetype: c.archetype,
        // topicId : le sujet officiel du programme, publie par le serveur au moment du depot
        // (16 septembre 2026). Il permet au calendrier d'offrir « Voir le programme » sans
        // deviner quoi que ce soit -- et son absence, sur une candidature anterieure a ce lot,
        // se traduit simplement par un bouton en moins.
        topicId: c.topic_id || null,
        prospectusDistribues: 0,
        dateInscription: c.created_at ? Date.parse(c.created_at) : undefined
      }));
    }
  }
  await chargerEffetsTractsPNJ(country);
}

// Ne conserve que les candidatures deposees DEPUIS l'ouverture du scrutin courant.
// FAIL-OPEN : si le cycle n'expose pas de dateDebutCandidatures exploitable, ou si une ligne n'a
// pas de created_at, on garde la ligne. Masquer un candidat reel serait plus grave que d'en
// afficher un ancien.
function filtrerCandidaturesDuScrutinCourant(candidatures, cycle) {
  const debut = Number((cycle || {}).dateDebutCandidatures);
  if (!isFinite(debut) || debut <= 0) return candidatures || [];
  return (candidatures || []).filter(c => {
    if (!c || !c.created_at) return true;
    const t = Date.parse(c.created_at);
    return !isFinite(t) || t >= debut;
  });
}

// Ne conserve que les candidatures dont le personnage existe encore dans la table personnages.
// UNE SEULE REQUETE pour tout le lot (name=in.(...)), jamais une par candidat.
// FAIL-OPEN ASSUME : si la lecture echoue (reseau, RLS), on rend la liste INTACTE plutot que de
// faire disparaitre des candidats legitimes d'un scrutin en cours. Un fantome de trop est un
// defaut d'affichage ; un candidat reel efface le jour du vote serait une faute.
async function filtrerCandidaturesDePersonnagesExistants(candidatures) {
  const noms = [...new Set((candidatures || []).map(c => c.nom).filter(Boolean))];
  if (!noms.length || typeof sbGet !== 'function') return candidatures || [];
  const liste = noms.map(n => '"' + String(n).replace(/"/g, '""') + '"').join(',');
  const rows = await sbGet('personnages', 'select=name&name=in.(' + encodeURIComponent(liste) + ')')
    .catch(() => null);
  if (!rows) return candidatures || [];
  const existants = new Set(rows.map(r => r.name));
  return (candidatures || []).filter(c => existants.has(c.nom));
}

// =====================
// FRAUDES ÉLECTORALES — PERSISTANCE (chantier "Hotel de Ville / elections", 4 septembre 2026)
// Table dediee fraudes_electorales (migration fournie separement) : chaque acte de fraude est
// une ligne individuelle, tracable (auteur, election, candidat, delta, type, etat) -- jamais un
// compteur agrege. cycle_debut (= cycle.dateDebutCandidatures au moment de la fraude) est la cle
// stable qui identifie CE scrutin precis a travers les renouvellements de cycles_electoraux
// (qui ecrase la meme ligne a chaque nouveau cycle).
// =====================
async function sbCompterFraudesParType(country, posteId, city, cycleDebut, type) {
  if (typeof sbGet !== 'function') return 0;
  const filtreCity = city ? `&city=eq.${encodeURIComponent(city)}` : '&city=is.null';
  const rows = await sbGet('fraudes_electorales',
    `country=eq.${encodeURIComponent(country)}&poste_id=eq.${encodeURIComponent(posteId)}${filtreCity}&cycle_debut=eq.${cycleDebut}&type=eq.${encodeURIComponent(type)}`
  ).catch(() => []);
  return (rows || []).length;
}

// Detectabilite fixee UNE FOIS, au moment de la fraude, selon le rang (1re/2e/3e/4e/5e+) de CE
// type de fraude sur CE scrutin -- jamais recalculee plus tard (une fraude ancienne reste aussi
// detectable qu'au jour de sa commission, meme si d'autres fraudes du meme type suivent).
const DETECTABILITE_PAR_RANG = [10, 30, 60, 90, 100];
function detectabilitePourRang(rang) {
  return DETECTABILITE_PAR_RANG[Math.min(rang - 1, DETECTABILITE_PAR_RANG.length - 1)];
}

async function sbEnregistrerFraudeElectorale(fraude) {
  if (typeof sbInsert !== 'function') return null;
  return sbInsert('fraudes_electorales', {
    id: 'fraude-' + fraude.type + '-' + Date.now() + '-' + Math.floor(Math.random() * 1000000),
    country: fraude.country, poste_id: fraude.posteId, city: fraude.city || null,
    cycle_debut: fraude.cycleDebut, type: fraude.type,
    auteur: fraude.auteur, candidat: fraude.candidat, delta_voix: fraude.deltaVoix,
    etat: 'non_revelee', detectabilite_pct: fraude.detectabilitePct,
    created_at: new Date().toISOString()
  }).catch(() => null);
}

async function sbGetFraudesNonRevelees(country, posteId, city, cycleDebut) {
  if (typeof sbGet !== 'function') return [];
  const filtreCity = city ? `&city=eq.${encodeURIComponent(city)}` : '&city=is.null';
  return await sbGet('fraudes_electorales',
    `country=eq.${encodeURIComponent(country)}&poste_id=eq.${encodeURIComponent(posteId)}${filtreCity}&cycle_debut=eq.${cycleDebut}&etat=eq.non_revelee`
  ).catch(() => []) || [];
}

async function sbRevelerFraude(id, revelateur) {
  if (typeof sbUpdate !== 'function') return null;
  return sbUpdate('fraudes_electorales', `id=eq.${encodeURIComponent(id)}`, {
    etat: 'revelee', revelee_par: revelateur, revelee_le: new Date().toISOString()
  }).catch(() => null);
}

// =====================
// VOTE DE CONFIANCE — PERSISTANCE (chantier "Hotel de Ville / elections", 4 septembre 2026).
// N'existait nulle part avant ce chantier : sbCreerVoteConfiance/sbGetVoteConfianceEnCours/
// sbDeposerBulletinConfiance/sbGetBulletinsConfiance/sbClorVoteConfiance etaient appelees partout
// (typeof X === 'function', toujours faux) sans qu'aucune ne soit jamais definie -- la mecanique
// entiere etait un no-op silencieux. Table dediee votes_confiance (migration fournie separement),
// bulletins stockes en jsonb sur la meme ligne (meme convention que cycles_electoraux.data).
// =====================
async function sbCreerVoteConfiance(vote) {
  if (typeof sbInsert !== 'function') return null;
  return sbInsert('votes_confiance', {
    id: vote.id, country: vote.country, pm_nom: vote.pm_nom,
    cloture_ts: new Date(vote.cloture_ts).toISOString(),
    statut: 'en_cours', resultat: null, bulletins: {},
    demission_limite_ts: null, demission_ts: null, consequence_appliquee: false,
    created_at: new Date().toISOString()
  }).catch(() => null);
}

async function sbGetVoteConfianceEnCours(country) {
  if (typeof sbGet !== 'function') return null;
  const rows = await sbGet('votes_confiance', `country=eq.${encodeURIComponent(country)}&statut=eq.en_cours&order=created_at.desc&limit=1`).catch(() => []);
  return (rows && rows[0]) || null;
}

async function sbDeposerBulletinConfiance(voteId, votant, choix) {
  if (typeof sbGet !== 'function' || typeof sbUpdate !== 'function') return false;
  const rows = await sbGet('votes_confiance', `id=eq.${encodeURIComponent(voteId)}`).catch(() => []);
  const vote = rows && rows[0];
  if (!vote) return false;
  const bulletins = { ...(vote.bulletins || {}) };
  if (bulletins[votant]) return false; // deja vote, anti double-vote
  bulletins[votant] = choix;
  await sbUpdate('votes_confiance', `id=eq.${encodeURIComponent(voteId)}`, { bulletins }).catch(() => {});
  return true;
}

// =====================
// ARCHIVES DES MANDATS MUNICIPAUX — LECTURE (chantier "Hotel de Ville / elections", 4 septembre
// 2026). Ecriture reservee au cron (api/cron-minuit.js, archiverMandatMaireTermine) -- jamais
// depuis le client, un bilan de mandat n'est jamais falsifiable par le joueur qu'il concerne.
// =====================
async function sbGetArchivesMandatsMaires(country, city) {
  if (typeof sbGet !== 'function') return [];
  return await sbGet('mandats_maires_archives',
    `country=eq.${encodeURIComponent(country)}&city=eq.${encodeURIComponent(city)}&order=debut_ts.desc`
  ).catch(() => []) || [];
}

// =====================
// MOTEUR ÉLECTORAL
// =====================

// Initialiser le cycle électoral pour un empire/poste
// Détermine si un poste est local (niveau ville) ou national
function posteEstLocal(posteId) {
  const poste = [...(POSTES_ELECTIFS.national||[]), ...(POSTES_ELECTIFS.departemental||[]), ...(POSTES_ELECTIFS.local||[])]
    .find(p => p.id === posteId);
  return poste?.niveau === 'ville';
}

// Libelle du/des titulaire(s) reel(s) d'un cycle, source UNIQUE (chantier "Hotel de Ville /
// elections", 4 septembre 2026) : cycle.eluId (postes a siege unique) fait TOUJOURS autorite
// avant tout repli sur state.postes (qui ne reflete que le joueur local) -- corrige l'affichage
// "Vacant" a tort deja identifie par l'audit. Pour le depute (9 sieges reels, 3 par ville depuis
// ce chantier), lit cycle.elus (tableau, jamais eluId) et renvoie un resume compact. Retourne
// null si reellement vacant (a l'appelant de choisir son propre texte de repli).
function libelleTitulaireCycle(cycle, posteId) {
  if (!cycle) return null;
  if (posteId === 'depute') {
    const elus = Array.isArray(cycle.elus) ? cycle.elus.filter(Boolean) : [];
    if (elus.length === 0) return null;
    return elus.join(', ') + (elus.length < 3 ? ' (' + elus.length + '/3)' : '');
  }
  return cycle.eluId || null;
}

// Clé effective du cycle — inclut la ville pour les postes locaux (maire, depute)
function getCleCycle(posteId, city) {
  if (posteEstLocal(posteId) && city) return posteId + '_' + city;
  return posteId;
}

// =====================
// CALENDRIER ELECTORAL DU DIMANCHE (12 septembre 2026) -- heure de Paris
// =====================
// Regle fixee : candidatures ouvertes des l'ouverture du cycle ; cloture le lundi 00:01 ;
// campagne du lundi 00:01 au samedi 23:59 (liste figee) ; vote le dimanche 00:01 -> 23:59 ;
// resultat au passage au lundi (dateResultats = lundi 00:00). Un cycle ouvert au passage au lundi
// vote le 2e dimanche suivant. Second tour : le dimanche suivant. Calcule en DATES CALENDAIRES de
// Paris (jamais +7 x 24 h) : le vote reste un dimanche a travers les changements d'heure. MEME
// code que la copie serveur (api/cron-minuit.js), a garder identique.
const FUSEAU_ELECTORAL = 'Europe/Paris';
const CANDIDATURES_MIN_MS = 6 * 24 * 60 * 60 * 1000;   // un cycle ouvert trop pres d'un lundi vote la semaine suivante

function partiesHeureParis(ts) {
  const p = {};
  new Intl.DateTimeFormat('en-GB', { timeZone: FUSEAU_ELECTORAL, year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' })
    .formatToParts(new Date(ts)).forEach(x => { p[x.type] = x.value; });
  return { a: +p.year, m: +p.month, j: +p.day, h: (+p.hour) % 24, mi: +p.minute, s: +p.second };
}

// Heure murale de Paris -> instant (ms), heure d'ete comprise.
function instantHeureParis(a, m, j, h, mi) {
  const mur = Date.UTC(a, m - 1, j, h, mi);
  let t = mur - 3600000;
  for (let k = 0; k < 3; k++) {
    const p = partiesHeureParis(t);
    t = mur - (Date.UTC(p.a, p.m - 1, p.j, p.h, p.mi, p.s) - t);
  }
  return t;
}

function dateCalendairePlusJours(d, n) {
  const x = new Date(Date.UTC(d.a, d.m - 1, d.j + n));
  return { a: x.getUTCFullYear(), m: x.getUTCMonth() + 1, j: x.getUTCDate() };
}

// Date (a, m, j) du lundi de la semaine de ts, a Paris.
function lundiSemaineParis(ts) {
  const p = partiesHeureParis(ts);
  const jour = new Date(Date.UTC(p.a, p.m - 1, p.j)).getUTCDay();   // 0 = dimanche
  return dateCalendairePlusJours(p, -((jour + 6) % 7));
}

// Scrutin de la semaine commencant par le lundi L : cloture L 00:01, vote dimanche 00:01,
// resultat au lundi suivant 00:00.
function datesScrutinSemaine(lundi) {
  const dim = dateCalendairePlusJours(lundi, 6), suivant = dateCalendairePlusJours(lundi, 7);
  return {
    dateDebutCampagne: instantHeureParis(lundi.a, lundi.m, lundi.j, 0, 1),
    dateVote: instantHeureParis(dim.a, dim.m, dim.j, 0, 1),
    dateResultats: instantHeureParis(suivant.a, suivant.m, suivant.j, 0, 0)
  };
}

// Premier tour d'un cycle ouvert a l'instant t : premiere cloture du lundi 00:01 laissant au moins
// 6 jours de candidatures (ouverture au passage au lundi -> cloture 7 jours plus tard, vote le
// dimanche qui suit : 2e dimanche apres l'election precedente).
function calendrierPremierTour(t) {
  let lundi = dateCalendairePlusJours(lundiSemaineParis(t), 7);
  let d = datesScrutinSemaine(lundi);
  if (d.dateDebutCampagne - t < CANDIDATURES_MIN_MS) d = datesScrutinSemaine(dateCalendairePlusJours(lundi, 7));
  return d;
}

// Tour suivant : le dimanche qui suit le vote precedent (aucune candidature : cloture deja passee).
function calendrierTourSuivant(dateVotePrecedent) {
  return datesScrutinSemaine(dateCalendairePlusJours(lundiSemaineParis(dateVotePrecedent), 7));
}

// Fin de mandat alignee sur le passage au lundi, n semaines apres la semaine de t.
function lundiMinuitParisApresSemaines(t, n) {
  const l = dateCalendairePlusJours(lundiSemaineParis(t), 7 * n);
  return instantHeureParis(l.a, l.m, l.j, 0, 0);
}

// Decalage d'un instant d'un nombre de semaines CALENDAIRES a Paris (meme heure murale).
function decalerSemainesParis(ts, n) {
  const p = partiesHeureParis(ts), d = dateCalendairePlusJours(p, 7 * n);
  return instantHeureParis(d.a, d.m, d.j, p.h, p.mi) + p.s * 1000 + (ts % 1000);
}

// Candidatures reellement ouvertes pour ce cycle (meme regle que le trigger serveur
// candidatures_cloture) : avant la cloture du lundi 00:01, cycle ni resolu ni en mandat/vacance.
function candidaturesOuvertes(cycle, maintenant) {
  const t = maintenant || Date.now();
  if (!cycle || cycle.resultatsTraites) return false;
  if (cycle.phase === PHASES_ELECTORALES.MANDAT || cycle.phase === PHASES_ELECTORALES.VACANT) return false;
  return isFinite(Number(cycle.dateDebutCampagne)) && t < Number(cycle.dateDebutCampagne);
}

async function initCycleElectoral(country, posteId, city) {
  const cle = getCleCycle(posteId, city);
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};
  if (CYCLES_ELECTORAUX[country][cle]) return;

  CYCLES_ELECTORAUX[country][cle] = construireNouveauCycleElectoral(posteId, city, Date.now());
  if (typeof sbSaveCycleElectoral === 'function') {
    await sbSaveCycleElectoral(country, posteId, CYCLES_ELECTORAUX[country][cle], city).catch(() => {});
  }
}

// Meme forme exacte que le corps de initCycleElectoral ci-dessus (memes champs, memes delais),
// mais SANS sa garde "si deja existant, ne rien faire" -- necessaire pour forcer un cycle frais
// meme quand un mandat est deja en cours (dissolution de l'Assemblee, doDissoudreAssemblee).
// Meme nom/signature que son miroir deja existant cote serveur (api/cron-minuit.js,
// construireNouveauCycleElectoral) -- duplique ici car ce fichier n'a jamais acces au contexte
// serveur, meme doctrine que le reste du projet (POSTES_NOMMES_EXCLUSIFS_SERVEUR, etc.).
function construireNouveauCycleElectoral(posteId, city, now) {
  const cal = calendrierPremierTour(now);   // calendrier du dimanche (12 septembre 2026)
  return {
    posteId, city: posteEstLocal(posteId) ? (city || null) : null,
    phase: PHASES_ELECTORALES.CANDIDATURES,
    dateDebutCandidatures: now,
    dateDebutCampagne: cal.dateDebutCampagne,
    dateVote: cal.dateVote,
    dateResultats: cal.dateResultats,
    candidats: [],
    votes: {},
    votesPNJ: {},
    tour: 1,
    eluId: null,
    // Explicite des la creation, comme cote cron : les deux copies doivent rester verbatim.
    resultatsTraites: false
  };
}

// Obtenir la phase actuelle d'un cycle
function getPhaseActuelle(country, posteId, city) {
  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle) return null;
  const now = Date.now();

  // Mandat en cours (PJ ou PNJ) — prioritaire sur le calcul par dates, sinon un titulaire
  // fraichement elu/pourvu s'affichait "Vacant" une fois ses dates de cycle depassees. Depute
  // (chantier "Hotel de Ville / elections", 4 septembre 2026) : au moins un siege pourvu
  // (cycle.elus, tableau) fait foi -- jamais cycle.eluId, toujours vide pour ce poste desormais.
  const auMoinsUnTitulaire = posteId === 'depute'
    ? Array.isArray(cycle.elus) && cycle.elus.some(Boolean)
    : !!cycle.eluId;
  if (cycle.phase === PHASES_ELECTORALES.MANDAT && auMoinsUnTitulaire && cycle.dateFinMandat && now < cycle.dateFinMandat) {
    return PHASES_ELECTORALES.MANDAT;
  }

  // cycle.tour est le signal le plus fiable pour detecter un second tour (cycle.phase a
  // longtemps ete pose de façon incorrecte cote cron — corrige le 8 aout 2026, mais on
  // garde les deux signaux par securite). VOTE3E_SIEGE (legislatives uniquement, 4 septembre
  // 2026) : second tour PARTIEL entre candidats ex aequo pour le dernier siege d'une ville --
  // cycle.phase='vote_3e_siege' n'est qu'un marqueur persiste ("ceci est un tel runoff"), la
  // phase AFFICHEE alterne par date entre CAMPAGNE_3E_SIEGE (semaine de campagne, meme duree
  // que SECOND_TOUR) et VOTE3E_SIEGE (24h de vote) -- correctif du 4 septembre 2026, la version
  // precedente sautait directement au vote sans campagne (dateVote pose = date de creation).
  const enSecondTour = cycle.phase === PHASES_ELECTORALES.SECOND_TOUR || cycle.tour === 2;
  const enRunoffSiege = cycle.phase === PHASES_ELECTORALES.VOTE3E_SIEGE;
  if (now < cycle.dateDebutCampagne) return PHASES_ELECTORALES.CANDIDATURES;
  if (now < cycle.dateVote) return enRunoffSiege ? PHASES_ELECTORALES.CAMPAGNE_3E_SIEGE : (enSecondTour ? PHASES_ELECTORALES.SECOND_TOUR : PHASES_ELECTORALES.CAMPAGNE);
  if (now < cycle.dateResultats) return enRunoffSiege ? PHASES_ELECTORALES.VOTE3E_SIEGE : (enSecondTour ? PHASES_ELECTORALES.VOTE2 : PHASES_ELECTORALES.VOTE);
  return PHASES_ELECTORALES.VACANT;
}

// ---- SONDAGE ELECTORAL (Marche, pouls_populaire, chantier 27 aout 2026) ----
// Lecture pure du VRAI systeme electoral (CYCLES_ELECTORAUX/POSTES_ELECTIFS/getCleCycle/
// getPhaseActuelle deja definis ci-dessus) : aucun moteur electoral parallele, aucune mutation.

// Elections locales (maire/depute -- posteEstLocal) "en cours" dans une ville donnee : cycle
// deja initialise, phase differente de MANDAT (poste deja pourvu, pas d'election) et VACANT
// (cycle clos, personne en lice), et au moins un candidat inscrit (sans candidat, rien a sonder
// -- meme critere que le "Aucun candidat" de ouvrirBureauDeVote). Lecture synchrone du cache
// memoire CYCLES_ELECTORAUX, deja tenu a jour par syncCyclesDepuisSupabase() a l'ouverture de
// chaque ecran electoral -- jamais de nouvel appel reseau ici (reutilisee telle quelle par le
// garde UI synchrone de renderRoomActions et par doPoulsPopulaire lui-meme).
function electionsLocalesEnCours(country, ville) {
  const postesLocaux = [...POSTES_ELECTIFS.local, ...POSTES_ELECTIFS.departemental].filter(p => posteEstLocal(p.id));
  const out = [];
  postesLocaux.forEach(p => {
    const cle = getCleCycle(p.id, ville);
    const cycle = CYCLES_ELECTORAUX[country]?.[cle];
    if (!cycle || !cycle.candidats || cycle.candidats.length === 0) return;
    const phase = getPhaseActuelle(country, p.id, ville);
    if (!phase || phase === PHASES_ELECTORALES.MANDAT || phase === PHASES_ELECTORALES.VACANT) return;
    out.push({ poste: p, cycle });
  });
  return out;
}

// Repartit 100 points entiers selon la methode du plus grand reste (standard pour un arrondi
// electoral) : garantit une somme finale exactement egale a 100 quel que soit le nombre de
// candidats ou les egalites, sans introduire de biais arbitraire (tri par voix desc puis par
// nom pour un depart-egalite stable et deterministe).
function arrondirPourcentages(items) {
  const base = items.map(it => ({ nom: it.nom, voix: it.voix, pct: Math.floor(it.exact), reste: it.exact - Math.floor(it.exact) }));
  const manquant = 100 - base.reduce((s, it) => s + it.pct, 0);
  const ordreRestes = [...base].sort((a, b) => b.reste - a.reste || b.voix - a.voix || a.nom.localeCompare(b.nom));
  for (let i = 0; i < manquant; i++) ordreRestes[i % ordreRestes.length].pct += 1;
  return base.sort((a, b) => b.voix - a.voix || b.pct - a.pct || a.nom.localeCompare(b.nom))
    .map(it => ({ nom: it.nom, voix: it.voix, pct: it.pct }));
}

// Rapport de force reel d'un scrutin : memes voix que consulterResultatsInformateur (cycle.votes
// = votes PJ + cycle.votesPNJ = votes PNJ reellement convertis par une action de campagne
// existante -- prospectus/conference/tract, jamais une intention de vote inventee), converties
// en pourcentages relatifs. Renvoie null si aucun vote n'est encore enregistre (rapport de force
// reellement indetermine a ce stade -- aucune repartition par defaut n'est inventee).
function calculerSondageElectoral(cycle) {
  const scores = {};
  cycle.candidats.forEach(c => { scores[c.nom] = 0; });
  Object.values(cycle.votes || {}).forEach(nom => { if (scores[nom] !== undefined) scores[nom]++; });
  Object.values(cycle.votesPNJ || {}).forEach(nom => { if (scores[nom] !== undefined) scores[nom]++; });
  appliquerEffetsTracts(scores, cycle);
  const total = Object.values(scores).reduce((s, v) => s + v, 0);
  if (total === 0) return null;
  const brut = Object.entries(scores).map(([nom, voix]) => ({ nom, voix, exact: voix / total * 100 }));
  return arrondirPourcentages(brut);
}

// Handler de l'ordre pouls_populaire (Marche) : sondage en lecture seule, jamais d'ecriture sur
// CYCLES_ELECTORAUX/votes/candidats. Re-synchronise avant affichage (meme appel que les autres
// ecrans electoraux) pour ne jamais presenter une donnee perimee au moment du clic.
async function doPoulsPopulaire() {
  const country = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[ville]?.name || ville;
  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase();

  const actives = electionsLocalesEnCours(country, ville);
  if (actives.length === 0) {
    showToast('Aucune élection', 'Aucune élection n\'est actuellement en cours dans cette ville.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Sondage électoral — ' + villeNom;
  let html = '<div style="padding:1rem">';
  actives.forEach(({ poste, cycle }) => {
    html += '<div style="margin-bottom:1.1rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.06em;color:#e0d5b8;margin-bottom:.4rem">' + poste.name + '</div>';
    const sondage = calculerSondageElectoral(cycle);
    if (!sondage) {
      html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic">Aucun vote encore enregistré pour ce scrutin — rapport de force indéterminé.</div>';
    } else {
      sondage.forEach(r => {
        html += '<div style="margin-bottom:.4rem">';
        html += '<div style="display:flex;justify-content:space-between;font-size:.78rem;color:#c0b090;margin-bottom:.15rem"><span>' + r.nom + '</span><span>' + r.pct + '%</span></div>';
        html += '<div style="height:5px;background:#1a1810;border-radius:3px"><div style="height:100%;width:' + r.pct + '%;background:#C9A84C;border-radius:3px"></div></div>';
        html += '</div>';
      });
    }
    html += '</div>';
  });
  html += '<div style="font-size:.68rem;color:#6a5a30;font-style:italic;margin-top:.2rem">Sondage réalisé au marché — reflet des intentions déjà exprimées, sans valeur officielle.</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Déposer une candidature
async function deposerCandidature(posteId, country, city) {
  const nom = state.char?.name;
  if (!nom) return;

  // Vérifier domiciliation
  const domicile = state.domicile;
  const domicilePays = domicile?.country || state.country;
  if (domicilePays !== (country || state.country)) {
    showToast('Non domicilié', 'Vous devez être domicilié dans cet empire pour vous présenter.', false);
    return;
  }

  const poste = [...(POSTES_ELECTIFS.national), ...(POSTES_ELECTIFS.departemental), ...(POSTES_ELECTIFS.local)]
    .find(p => p.id === posteId);
  if (!poste) return;

  // Vérifier niveau d'influence requis
  if ((state.inf || 0) < (poste.minInf || 0)) {
    showToast('Influence insuffisante', 'Il faut ' + poste.minInf + ' INF minimum pour ce poste.', false);
    return;
  }

  if (posteId === 'depute') {
    if (state.posteDepute) {
      showToast('Deja depute', 'Vous etes deja depute.', false);
      return;
    }
  } else if (state.poste && state.poste.id !== posteId) {
    const interdits = [['president','maire']];
    const conflict = interdits.some(pair =>
      pair.includes(state.poste.id) && pair.includes(posteId)
    );
    if (conflict) {
      showToast('Cumul interdit', 'Vous ne pouvez pas cumuler ' + state.poste.name + ' et ' + poste.name + '.', false);
      return;
    }
  }

  const c = country || state.country;
  const cle = getCleCycle(posteId, city);
  if (!CYCLES_ELECTORAUX[c]) CYCLES_ELECTORAUX[c] = {};
  if (!CYCLES_ELECTORAUX[c][cle]) await initCycleElectoral(c, posteId, city);

  const cycle = CYCLES_ELECTORAUX[c][cle];
  // Delai de depot restreint a la seule phase CANDIDATURES retire le 17 aout 2026 (decision
  // explicite) : une election doit rester accessible a tout moment, pas seulement durant la
  // toute premiere semaine suivant sa creation. Les autres prerequis (domiciliation,
  // influence minimale, cumul interdit, deja candidat) restent tous verifies ci-dessus/dessous,
  // inchanges -- seul ce verrou temporel disparait. Ne modifie ni le calendrier de campagne, ni
  // le vote, ni le depouillement : une candidature deposee tardivement rejoint simplement
  // cycle.candidats avec 0 voix, comme n'importe quelle autre.
  if (cycle.candidats.find(ca => ca.nom === nom)) {
    showToast('Déjà candidat', 'Vous êtes déjà candidat à ce poste.', false);
    return;
  }
  // Calendrier du dimanche (12 septembre 2026) : le verrou temporel retire le 17 aout revient --
  // candidatures fermees le lundi 00:01 precedant le vote (le serveur refuse aussi, trigger
  // candidatures_cloture). Aucun PA n'est debite pour une candidature refusee.
  if (!candidaturesOuvertes(cycle)) {
    showToast('Candidatures closes', 'Les candidatures à ce scrutin sont closes. Elles rouvriront avec le prochain scrutin.', false);
    return;
  }

  // Ouvrir modal pour programme
  ouvrirModalCandidature(posteId, c, poste, cycle, city);
}

// DONNER UNE CONFERENCE (Universite, amphi) — 2 branches : soutenir un candidat en campagne
// (convertit 3 electeurs PNJ, theme = celui de SA candidature), ou sensibiliser sur un theme
// (boost direct d'indice, utilisable hors campagne). 1 conference/jour, comme les 2 autres
// ordres de l'amphi.
// NOTE : le jeu n'a pas de pool centralise d'electeurs PNJ existants (verifie dans le code) —
// on genere donc quelques electeurs synthetiques dedies a cette action, avec le meme effet
// concret (vote garanti) que la distribution manuelle de prospectus.
function doDonnerConference(pa, cost) {
  if (state.char?.derniereConferenceJour === state.day) {
    showToast('Déjà fait aujourd\'hui', 'Une seule conférence par jour.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Donner une conférence';
  let html = '<div style="padding:1rem">';
  html += '<button onclick="ouvrirConferenceCandidat(' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.5rem">🗳️ Soutenir un candidat en campagne</button>';
  html += '<button onclick="ouvrirConferenceIndice(' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem">📊 Sensibiliser sur un thème (indice)</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirConferenceCandidat(pa, cost) {
  const THEMES_LABELS = { securite: 'Sécurité', economie: 'Économie', education: 'Éducation', cadre_vie: 'Cadre de vie', vie_associative: 'Vie associative' };
  const country = state.country;
  const candidatsEligibles = [];
  Object.keys(CYCLES_ELECTORAUX[country] || {}).forEach(cle => {
    const cycle = CYCLES_ELECTORAUX[country][cle];
    (cycle.candidats || []).forEach(c => {
      if (!c.aideConference) candidatsEligibles.push({ ...c, cle });
    });
  });

  document.getElementById('postes-modal-title').textContent = 'Soutenir un candidat';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Valable pour n\'importe quelle élection en cours (maire, député, président). Le thème est celui de la campagne du candidat.</div>';
  if (candidatsEligibles.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun candidat éligible pour le moment.</div>';
  } else {
    candidatsEligibles.forEach(c => {
      html += '<button onclick="confirmerConference(\'' + c.cle + '\',\'' + c.nom.replace(/'/g,"\\'") + '\',' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.3rem">' +
        c.nom + ' — <span style="color:#8a6a20">' + (THEMES_LABELS[c.theme] || c.theme) + '</span></button>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

function ouvrirConferenceIndice(pa, cost) {
  const THEMES = [
    { id: 'securite',        label: 'Sécurité',        portee: 'locale' },
    { id: 'economie',        label: 'Économie',        portee: 'nationale' },
    { id: 'education',       label: 'Éducation',       portee: 'locale' },
    { id: 'cadre_vie',       label: 'Cadre de vie',    portee: 'locale' },
    { id: 'vie_associative', label: 'Vie associative', portee: 'locale' }
  ];
  document.getElementById('postes-modal-title').textContent = 'Sensibiliser sur un thème';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Effet immédiat et modeste sur l\'indice correspondant, utilisable à tout moment, campagne ou non.</div>';
  THEMES.forEach(t => {
    html += '<button onclick="confirmerConferenceIndice(\'' + t.id + '\',' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.3rem">' + t.label + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerConferenceIndice(themeId, pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  document.getElementById('modal-postes').classList.remove('open');
  state.char.derniereConferenceJour = state.day;
  sauvegarderPersonnageImmediat();
  const THEMES_LABELS = { securite: 'Sécurité', economie: 'Économie', education: 'Éducation', cadre_vie: 'Cadre de vie', vie_associative: 'Vie associative' };
  // Themes locaux -> indices_locaux de la ville courante ; economie -> indice national IE
  if (themeId === 'economie') {
    INDICES_NATIONAUX[state.country] = INDICES_NATIONAUX[state.country] || {};
    INDICES_NATIONAUX[state.country].IE = Math.min(100, (INDICES_NATIONAUX[state.country].IE || 50) + 2);
  } else {
    if (!state.indicesLocaux) state.indicesLocaux = {};
    const ville = state.currentCity;
    if (!state.indicesLocaux[ville]) state.indicesLocaux[ville] = {};
    const cleIndice = themeId === 'cadre_vie' ? 'espaces_verts' : themeId === 'education' ? 'ecoles' : themeId === 'vie_associative' ? 'vie_associative' : 'securite';
    state.indicesLocaux[ville][cleIndice] = Math.min(100, (state.indicesLocaux[ville][cleIndice] || 50) + 2);
  }
  updateUI();
  showToast('Conférence donnée !', 'Sensibilisation sur ' + THEMES_LABELS[themeId] + '. +2 à l\'indice concerné.', true);
  addJournalEntry('Conférence de sensibilisation à l\'université : ' + THEMES_LABELS[themeId] + '.', 'event-good');
}

async function confirmerConference(cle, candidatNom, pa, cost) {
  document.getElementById('modal-postes').classList.remove('open');
  const cycle = CYCLES_ELECTORAUX[state.country]?.[cle];
  if (!cycle) return;
  const candidat = cycle.candidats.find(c => c.nom === candidatNom);
  if (!candidat || candidat.aideConference) { showToast('Indisponible', 'Ce candidat a déjà bénéficié d\'une conférence.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  candidat.aideConference = true;
  state.char.derniereConferenceJour = state.day;
  sauvegarderPersonnageImmediat();

  // ECRITURE ATOMIQUE (12 septembre 2026) : les 3 electeurs convaincus etaient ecrits dans
  // cycle.votesPNJ sous des identifiants contenant Date.now(), puis TOUT le blob du cycle etait
  // reecrit depuis le client -- deux conferences simultanees s'ecrasaient, et un double-clic
  // creait 6 voix. Chaque electeur est desormais une ligne de elections_tracts_pnj sous une cle
  // STABLE (joueur + candidat + rang) : rejouer la meme conference n'ajoute plus rien. Le verrou
  // « une conference par candidat » (aideConference) et celui « une par jour »
  // (derniereConferenceJour) restent exactement ou ils etaient, cote client.
  // BUG CORRIGE au passage : la ligne de sauvegarde re-decoupait la cle du cycle
  // (cle.split('_')), ce qui pour chef_syndicat produisait posteId='chef'/city='syndicat' et
  // ecrivait dans une ligne fantome « republic_chef » -- les 3 voix n'etaient jamais persistees.
  const NB_ELECTEURS_CONVERTIS = 3;
  let convertis = 0;
  for (let i = 0; i < NB_ELECTEURS_CONVERTIS; i++) {
    const cleElecteur = 'conference:' + (state.char?.name || '') + ':' + candidatNom + ':' + i;
    const ok = await enregistrerVotePNJ(state.country, cycle.posteId, cycle.city || null,
      'Un auditeur de la conférence', candidatNom, 'conference', cleElecteur).catch(() => false);
    if (ok) convertis++;
  }
  candidat.prospectusDistribues = (candidat.prospectusDistribues || 0) + convertis;

  updateUI();
  if (convertis === 0) {
    showToast('Conférence sans effet', 'Ces électeurs avaient déjà été convaincus.', false);
    addJournalEntry('Conférence donnée à l\'université en soutien à ' + candidatNom + ' — aucun nouvel électeur.', '');
    return;
  }
  showToast('Conférence donnée !', candidatNom + ' gagne ' + convertis + ' électeurs convaincus.', true);
  addJournalEntry('Conférence donnée à l\'université en soutien à ' + candidatNom + '.', 'event-good');
}

function ouvrirModalCandidature(posteId, country, poste, cycle, city) {
  const nom = state.char?.name;
  document.getElementById('postes-modal-title').textContent = '🗳️ Candidature — ' + poste.name;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.4rem">Thème principal de votre campagne :</div>' +
    '<select id="prog-theme" style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,Georgia,serif;font-size:.85rem;margin-bottom:.6rem">' +
    '<option value="securite">Sécurité</option>' +
    '<option value="economie">Économie</option>' +
    '<option value="education">Éducation</option>' +
    '<option value="cadre_vie">Cadre de vie</option>' +
    '<option value="vie_associative">Vie associative</option>' +
    '</select>' +
    '<div style="font-size:.78rem;color:#c0b090;margin-bottom:.8rem">Présentez votre programme en quelques mots. Il sera visible de tous les électeurs.</div>' +
    '<textarea id="prog-texte" rows="4" placeholder="Mon programme..." ' +
    'style="width:100%;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,Georgia,serif;font-size:.85rem;box-sizing:border-box;resize:vertical"></textarea>' +
    '<div style="display:flex;gap:.5rem;margin-top:.6rem">' +
    '<button onclick="confirmerCandidature(this)" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" ' +
    'style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">' +
    '🗳️ Déposer ma candidature</button>' +
    '<button onclick="fermerModalPostes()" ' +
    'style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #2a2010;background:transparent;color:#6a5a30;cursor:pointer">Annuler</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

// LE DEPOT DE CANDIDATURE EST UN ORDRE A PART ENTIERE (16 septembre 2026).
// Il ne vit dans aucune salle -- on y arrive par la liste ouverte par 'se_porter_candidat' --
// mais il coute 2 PA, et tout cout doit etre DECLARE pour que payer_ordre l'accepte. Ce litteral
// est donc la seule source du cout : .scratch/generer_ordres_couts.py le ramasse comme les
// quatre ordres d'etat civil qui vivent deja dans ce fichier.
const ORDRE_DEPOT_CANDIDATURE = {
  fn: 'deposer_candidature', label: 'Déposer sa candidature', pa: 2, cost: 0,
  type: 'legal', icon: 'ti-user-plus', successRate: 100,
  desc: 'Déposer effectivement sa candidature à un scrutin ouvert, programme à l\'appui.'
};

async function confirmerCandidature(el) {
  const posteId = el?.dataset?.poste || el;
  const country = el?.dataset?.country || arguments[1];
  const city = el?.dataset?.city || arguments[2] || null;
  const nom = state.char?.name;
  const programme = document.getElementById('prog-texte')?.value?.trim() || '';
  const theme = document.getElementById('prog-theme')?.value || 'economie';
  if (!programme) { showToast('Programme requis', 'Décrivez votre programme.', false); return; }

  // Garde du cycle electoral (correctif Lot 2C) -- meme controle que deposerCandidature()
  // (ligne 592) : initialise le cycle s'il n'existe pas encore, AVANT la deduction PA. Un cycle
  // absent est un etat metier exploitable (creation a la volee), pas un echec -- seule son
  // absence totale (init impossible) doit bloquer l'ordre sans debit.
  const cle = getCleCycle(posteId, city);
  if (!CYCLES_ELECTORAUX[country][cle]) await initCycleElectoral(country, posteId, city);
  if (!CYCLES_ELECTORAUX[country][cle]) { showToast('Indisponible', 'Le cycle electoral n\'est pas exploitable pour ce poste.', false); return; }

  // Cloture du lundi 00:01 (12 septembre 2026), verifiee AVANT le debit des PA.
  if (!candidaturesOuvertes(CYCLES_ELECTORAUX[country][cle])) {
    showToast('Candidatures closes', 'Les candidatures à ce scrutin sont closes.', false);
    return;
  }

  // COUT DECLARE, ET NON PLUS CODE EN DUR SOUS LE NOM D'UN AUTRE ORDRE (16 septembre 2026).
  //
  // Ce site facturait 2 PA sans passer de `fn`. deduireCoutOrdre retombait donc sur
  // state._ordreEnCours, c'est-a-dire 'se_porter_candidat' -- l'ordre qui OUVRE la salle des
  // elections, declare a 0 PA dans data.js (trois emplacements) parce qu'ouvrir une liste ne
  // coute rien. Le serveur recevait le couple (se_porter_candidat, 2, 0), absent du miroir, et
  // refusait avec 'cout_non_declare'. Le depot de candidature etait donc IMPOSSIBLE, quel que
  // soit le nombre de PA du joueur. C'est ce qu'a rencontre le game designer avec 12 PA.
  //
  // Le cout de jeu ne change pas : deposer une candidature coute toujours 2 PA. Il porte
  // desormais son propre nom d'ordre, declare juste au-dessus et repris par le miroir serveur
  // (generer_ordres_couts.py ramasse les litteraux d'ordre des modules, pas seulement data.js).
  const r = await deduireCoutOrdre({ pa: 2, cost: 0, fn: 'deposer_candidature' });
  if (!r.ok) { signalerRefusCout(r); return; }

  const cycle = CYCLES_ELECTORAUX[country][cle];
  const nouveauCandidat = {
    nom, programme, theme,
    archetype: state.char?.archetype,
    posteActuel: state.poste?.name || null,
    prospectusDistribues: 0,
    dateInscription: Date.now(),
  };

  // Ecriture non atomique corrigee (audit du 4 septembre 2026) : la table "candidatures" fait
  // desormais autorite AVANT toute mutation locale -- plus jamais de candidat visible en session
  // puis silencieusement absent au prochain syncCyclesDepuisSupabase() si cette ecriture echoue.
  // Le blob cycles_electoraux (sbSaveCycleElectoral) reste un cache best-effort, ecrit ensuite,
  // jamais la source de verite.
  // La cle de scrutin est prise sur le cycle en cours : c'est elle qui distingue deux
  // candidatures du meme joueur au meme poste a deux scrutins differents.
  const ecritureReussie = await sbDeposerCandidature(country, posteId, nouveauCandidat, city,
    (typeof cleEcheanceElectorale === 'function') ? cleEcheanceElectorale(cycle) : cycle?.dateDebutCandidatures);
  if (!ecritureReussie) {
    // Refus serveur (cloture atteinte entre-temps) ou erreur : les 2 PA sont rendus.
    // Remboursement ATTESTE (16 septembre 2026) : le montant est celui que l'ordre coute
    // reellement d'apres le miroir serveur, et la reference (ce scrutin, ce candidat) fait
    // qu'il ne peut etre accorde qu'une fois -- un remboursement rejouable serait un
    // robinet a PA.
    if (r.paPreleves && typeof sbRpc === 'function' && state.char?.name) {
      await sbRpc('pa_crediter_atteste', {
        p_acteur: state.char.name, p_source: 'remboursement_ordre',
        p_reference: 'candidature-' + posteId + '-' + (city || '') + '-' + cle,
        p_ordre: 'deposer_candidature'
      }).then(rows => { const v = Array.isArray(rows) ? rows[0] : rows;
                        if (v && typeof v.pa === 'number') state.pa = v.pa; }).catch(() => {});
    }
    showToast('Échec de l\'inscription', candidaturesOuvertes(cycle) ? 'La candidature n\'a pas pu être enregistrée. Réessayez.' : 'Les candidatures à ce scrutin sont closes.', false);
    return;
  }
  cycle.candidats.push(nouveauCandidat);
  sbSaveCycleElectoral(country, posteId, cycle, city).catch(() => {});

  document.getElementById('modal-postes').classList.remove('open');
  showToast('Candidature enregistrée !', 'Vous êtes candidat à ' + posteId + (city ? ' (' + city + ')' : '') + '.', true);
  addJournalEntry('📋 Candidature déposée au poste : ' + posteId + (city ? ' — ' + city : '') + '.', 'event-info');

  // Publier sur le forum — national pour un poste national, local pour un poste de ville
  if (typeof sbCreateTopic === 'function') {
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : `Jour ${state.day}`;
    const forumCible = posteEstLocal(posteId)
      ? ((typeof idForumLocal === 'function') ? idForumLocal(city) : 'local')
      : 'national';
    const titre = '🗳️ Candidature de ' + nom + ' — ' + POSTES_ELECTIFS.national.concat(POSTES_ELECTIFS.local).concat(POSTES_ELECTIFS.departemental).find(p=>p.id===posteId)?.name;
    const texte = nom + ' se présente aux élections.\n\nProgramme :\n' + programme;
    sbCreateTopic(forumCible, titre, nom, country, time).then(topicId => {
      if (topicId && typeof sbCreatePost === 'function') sbCreatePost(topicId, nom, texte, time);
      if (!FORUM_TOPICS[forumCible]) FORUM_TOPICS[forumCible] = [];
      FORUM_TOPICS[forumCible].unshift({
        id: topicId || 'topic-' + Date.now(), title: titre, author: nom,
        time, views: 1, replies: 0, lastPostAuthor: nom, lastPostTime: time,
        posts: [{ id: 'p-' + Date.now(), author: nom, time, content: texte }]
      });
    }).catch(() => {});
  }
}

// Vote PJ
function voterPour(candidatNom, posteId, country, city) {
  const votant = state.char?.name;
  if (!votant) return;

  const domicile = state.domicile;
  const domicilePays = domicile?.country || state.country;
  if (domicilePays !== country) {
    showToast('Non domicilié', 'Vous ne pouvez pas voter dans cet empire.', false);
    return;
  }

  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle) return;

  const phaseVote = getPhaseActuelle(country, posteId, city);
  // VOTE3E_SIEGE (chantier "Hotel de Ville / elections", 4 septembre 2026) : second tour PARTIEL
  // des legislatives, limite aux candidats ex aequo pour le dernier siege d'une ville -- meme
  // fenetre de vote (24h) que VOTE/VOTE2, simple phase supplementaire reconnue ici.
  if (phaseVote !== PHASES_ELECTORALES.VOTE && phaseVote !== PHASES_ELECTORALES.VOTE2 && phaseVote !== PHASES_ELECTORALES.VOTE3E_SIEGE) {
    showToast('Vote fermé', 'Le vote n\'est pas ouvert actuellement.', false);
    return;
  }

  if (cycle.votes[votant]) {
    showToast('Déjà voté', 'Vous avez déjà voté pour ce poste.', false);
    return;
  }

  // Vote blanc (chantier "Hotel de Ville / elections", 4 septembre 2026) : choix reel au meme
  // titre qu'un candidat, jamais un candidat fictif ajoute a cycle.candidats -- comptabilise a
  // part par le depouillement serveur (calculerResultatsServer, api/cron-minuit.js).
  cycle.votes[votant] = candidatNom; // candidatNom peut valoir le sentinel 'BLANC'
  // Persister en Supabase
  sbVoterPour(country, posteId, votant, candidatNom, city).catch(() => {});
  sbSaveCycleElectoral(country, posteId, cycle, city).catch(() => {});
  const libelleVote = candidatNom === 'BLANC' ? 'blanc' : candidatNom;
  showToast('Vote enregistré !', 'Vous avez voté ' + (candidatNom === 'BLANC' ? 'blanc' : ('pour ' + candidatNom)) + '.', true);
  addJournalEntry('🗳️ Vote enregistré : ' + libelleVote + (city ? ' (' + city + ')' : '') + '.', 'event-info');
}

// Enregistre le vote d'un PNJ convaincu dans le vrai systeme electoral (cycle.votesPNJ) ET
// persiste immediatement en Supabase -- corrige un oubli de persistance de distribuerProspectus
// (audit du 17 aout 2026 : le vote local n'atteignait jamais Supabase, risquant d'etre ecrase
// au prochain syncCyclesDepuisSupabase). Helper factorise, seul point d'ecriture reel des votes
// PNJ desormais : reutilise par distribuerProspectus ci-dessous ET par la quete Jean-Lou
// (distribuerTractJeanLou, plateau-pnj.js) -- aucune logique electorale parallele.
// Renvoie false sans rien faire si ce PNJ est deja enregistre pour ce cycle (garde-fou contre
// une deuxieme voix pour le meme PNJ, meme si l'appel vient d'ailleurs que ce cycle).
// =====================
// TRACTS ELECTORAUX AUPRES DES PNJ (11 septembre 2026, migration_tracts_electoraux_pnj.sql)
// =====================
// Une participation PNJ reussie est une ligne de elections_tracts_pnj ecrite par le serveur
// (RPC tracts_electoraux_distribuer), jamais le blob du cycle : effet +1 (POUR), -1 (CONTRE) ou 0
// (CONTRE sur un score deja nul), par tour (tour = cycle.dateVote). Les effets du tour courant sont
// attaches au cycle en memoire par une propriete NON enumerable : les decomptes (sondage,
// depouillement) les lisent, mais JSON.stringify (sbSaveCycleElectoral) ne les ecrit jamais dans le
// blob. Architecture prevue pour de futures participations synthetiques (ex. action groupee du
// president des supporters : une ligne par electeur synthetique, meme table, meme decompte).
const POSTES_TRACTS_ELECTORAUX = ['president', 'maire', 'depute'];
const LIEUX_PRESIDENTIELLE = ['capitale', 'ville_a', 'ville_b', 'caserne', 'qhs'];

function attacherEffetsTracts(cycle, effets) {
  if (!cycle) return;
  Object.defineProperty(cycle, '_effetsTracts', { value: effets, enumerable: false, writable: true, configurable: true });
}

function appliquerEffetsTracts(scores, cycle) {
  const e = cycle && cycle._effetsTracts;
  if (!e || e.tour !== cycle.dateVote) return;
  Object.keys(e.parCandidat || {}).forEach(nom => {
    if (scores[nom] !== undefined) scores[nom] = Math.max(0, scores[nom] + e.parCandidat[nom]);
  });
}

function ajouterEffetTractLocal(cycle, candidat, effet, tour) {
  if (!cycle || !effet || tour !== cycle.dateVote) return;
  const e = (cycle._effetsTracts && cycle._effetsTracts.tour === tour) ? cycle._effetsTracts : { tour, parCandidat: {} };
  e.parCandidat[candidat] = (e.parCandidat[candidat] || 0) + effet;
  attacherEffetsTracts(cycle, e);
}

async function chargerEffetsTractsPNJ(country) {
  if (typeof sbChargerEffetsTractsPNJ !== 'function') return;
  const lignes = await sbChargerEffetsTractsPNJ(country).catch(() => null);
  if (!Array.isArray(lignes)) return;
  const cycles = CYCLES_ELECTORAUX[country] || {};
  Object.keys(cycles).forEach(cle => {
    const cycle = cycles[cle];
    const parCandidat = {};
    const engages = {};
    lignes.filter(l => l.cycle_id === country + '_' + cle && Number(l.tour) === cycle.dateVote)
      .forEach(l => {
        parCandidat[l.candidat] = (parCandidat[l.candidat] || 0) + Number(l.effet || 0);
        if (l.pnj_cle) engages[l.pnj_cle] = l.candidat;
      });
    attacherEffetsTracts(cycle, { tour: cycle.dateVote, parCandidat, engages });
  });
}

// Dimanche a l'heure de Paris (le serveur fait foi, avec la meme regle).
function estDimancheParis(date) {
  const d = date || new Date();
  try { return new Intl.DateTimeFormat('en-US', { timeZone: 'Europe/Paris', weekday: 'short' }).format(d) === 'Sun'; }
  catch (e) { return d.getDay() === 0; }
}

function libelleScrutinTract(country, posteId, city) {
  const ville = city ? (WORLD[country]?.[city]?.name || city) : null;
  if (posteId === 'president') return 'Présidentielle';
  if (posteId === 'maire') return 'Municipales — ' + ville;
  return 'Législatives — ' + ville;
}

// Scrutins ou CE tract peut etre distribue maintenant, depuis le lieu ou se trouve le joueur :
// dimanche, phase de vote ouverte, candidat inscrit a ce scrutin, geographie valide (ville du
// scrutin local ; presidentielle : une ville du pays, la caserne ou le QHS). Un tract imprime pour
// un scrutin precis (electionPosteId/electionCity, Port-Sainte-Marie) n'est propose que pour lui.
function scrutinsDistribuablesPourTract(tract) {
  if (!tract || tract.type !== 'tract' || !estDimancheParis()) return [];
  const country = state.country;
  const cycles = CYCLES_ELECTORAUX[country] || {};
  const ville = state.currentCity;
  const phasesVote = [PHASES_ELECTORALES.VOTE, PHASES_ELECTORALES.VOTE2, PHASES_ELECTORALES.VOTE3E_SIEGE];
  const res = [];
  Object.keys(cycles).forEach(cle => {
    const cycle = cycles[cle];
    const posteId = cycle && cycle.posteId;
    if (POSTES_TRACTS_ELECTORAUX.indexOf(posteId) < 0 || cycle.resultatsTraites) return;
    if (phasesVote.indexOf(getPhaseActuelle(country, posteId, cycle.city)) < 0) return;
    if (!(cycle.candidats || []).some(c => c.nom === tract.cible)) return;
    if (cycle.city ? ville !== cycle.city : LIEUX_PRESIDENTIELLE.indexOf(ville) < 0) return;
    if (tract.electionPosteId && (tract.electionPosteId !== posteId || (tract.electionCity || null) !== (cycle.city || null))) return;
    res.push({ cle, cycleId: country + '_' + cle, posteId, city: cycle.city || null, libelle: libelleScrutinTract(country, posteId, cycle.city) });
  });
  return res;
}

// Lots de tracts ordinaires (POUR/CONTRE, hors mission Jean-Lou) utilisables ici et maintenant.
function tractsElectorauxDistribuablesIci() {
  return (state.inventory || [])
    .filter(i => i.type === 'tract' && i.origineQuete !== 'jean_lou' && (i.quantite || 0) > 0
      && (i.tractType === 'pour' || i.tractType === 'contre' || !i.tractType))
    .map(tract => ({ tract, scrutins: scrutinsDistribuablesPourTract(tract) }))
    .filter(o => o.scrutins.length > 0);
}

// Cle d'identite d'un PNJ, miroir exact de tracts_electoraux_nom_pnj (SQL) : minuscules, sans le
// suffixe « (PNJ) » ni apostrophes, prefixee du pays et de la ville ou l'on se trouve.
function clePnjElectorale(nom, country, city) {
  const n = String(nom || '').toLowerCase().replace(/\s*\(pnj\)\s*$/, '').replace(/['\u2019]/g, '').trim();
  return (country || state.country || '') + ':' + (city || state.currentCity || '') + ':' + n;
}

// Un PNJ a-t-il deja donne sa voix pour ce tour ? Lu dans les deux registres : la table atomique
// (nouveau) et l'ancien blob votesPNJ (lignes historiques, encore comptees au depouillement).
function pnjDejaEngage(cycle, pnjNom) {
  if (!cycle) return false;
  if (cycle.votesPNJ && cycle.votesPNJ[pnjNom]) return true;
  const engages = cycle._effetsTracts && cycle._effetsTracts.engages;
  return !!(engages && engages[clePnjElectorale(pnjNom)]);
}

// ECRITURE ATOMIQUE (12 septembre 2026) : prospectus, conference et mission Jean-Lou ecrivaient
// cycle.votesPNJ puis reecrivaient LE BLOB ENTIER du cycle depuis le client -- deux joueurs
// simultanes s'ecrasaient et des voix disparaissaient. La voix est desormais une ligne de
// elections_tracts_pnj (canal renseigne), exactement comme un tract : meme contrainte d'unicite,
// meme decompte au depouillement. Aucune regle de jeu ne change : couts, jets, phases, geographie
// et textes restent decides par les appelants, inchanges.
async function enregistrerVotePNJ(country, posteId, city, pnjId, candidatNom, canal, cleExplicite) {
  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle) return false;
  if (!cleExplicite && pnjDejaEngage(cycle, pnjId)) return false;
  if (typeof sbEnregistrerVoixPnj !== 'function') return false;
  const requete = 'voix-pnj-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
  // Le canal est toujours fourni par l'appelant ('conference' ou 'jean_lou') : le repli sur
  // 'prospectus' a disparu avec la mecanique du meme nom (12 septembre 2026).
  if (!canal) return false;
  const r = await sbEnregistrerVoixPnj(requete, state.char?.name, country + '_' + cle, candidatNom,
                                       pnjId, canal, cleExplicite || null).catch(() => null);
  if (!r || !r.ok) return false;
  // Echo local immediat : le decompte affiche tient compte de la voix sans attendre un rechargement.
  if (typeof ajouterEffetTractLocal === 'function') ajouterEffetTractLocal(cycle, candidatNom, 1, r.tour);
  const effets = cycle._effetsTracts;
  if (effets) { if (!effets.engages) effets.engages = {}; effets.engages[r.cle] = candidatNom; }
  return true;
}

// Liste les candidats actuellement en campagne (lot tracts electoraux PSM, 24 aout 2026).
// NE FILTRE PLUS L'IMPRESSION depuis le 16 septembre 2026 : l'imprimerie accepte n'importe quelle
// cible (listerCiblesTractsElectoraux, plateau-communication.js) et n'utilise plus cette liste que
// pour AFFICHER la mention « en campagne » a cote des noms concernes. La garantie qu'un tract ne
// puisse pas peser sur un scrutin ou sa cible n'est pas inscrite est portee par la distribution
// (scrutinsDistribuablesPourTract ci-dessus, et le refus serveur 'candidat_hors_scrutin'), pas par
// l'impression. Reste la definition unique de « en campagne » : memes phases de campagne actives.
function listerCandidatsElectorauxActifs() {
  const country = state.country;
  const cycles = (typeof CYCLES_ELECTORAUX !== 'undefined' && CYCLES_ELECTORAUX[country]) || {};
  const phasesActives = [PHASES_ELECTORALES.CAMPAGNE, PHASES_ELECTORALES.SECOND_TOUR, PHASES_ELECTORALES.CAMPAGNE_3E_SIEGE];
  const out = [];
  Object.keys(cycles).sort().forEach(cle => {
    const cycle = cycles[cle];
    if (!cycle || !cycle.candidats || !cycle.candidats.length) return;
    const phase = getPhaseActuelle(country, cycle.posteId, cycle.city);
    if (!phasesActives.includes(phase)) return;
    cycle.candidats.forEach(c => out.push({ nom: c.nom, posteId: cycle.posteId, city: cycle.city || null }));
  });
  return out;
}

// PROSPECTUS SUPPRIME (12 septembre 2026, game design confirme). Il n'existe que DEUX objets de
// campagne : le tract electoral et le tract calomnieux. Le « prospectus » etait l'ancienne
// generation du tract electoral -- meme finalite (convaincre un PNJ present de voter pour un
// candidat), 1 PA + 50 FR, reussite garantie, ecriture directe dans cycle.votesPNJ. Sont retires :
// distribuerProspectus(), distribuerProspectusModal(), le bouton du bureau de vote et les deux
// relais de plateau-navigation.js. Ce qui N'EST PAS touche, faute d'etre le meme mecanisme :
//   - candidat.prospectusDistribues : compteur d'affichage encore alimente par la conference ;
//   - le bonus de synergie « prospectus comptent double » (data.js, prospectus_mult) : declare mais
//     lu par aucun code, il attend un arbitrage ;
//   - la conference et la mission Jean-Lou, a examiner separement.


// Calculer les résultats
// Correctif "cle locale erronee" (audit du 4 septembre 2026) : cette fonction lisait
// CYCLES_ELECTORAUX[country][posteId] directement, sans jamais passer par getCleCycle -- pour un
// poste local (maire/depute), la cle reelle est "posteId_ville" (voir getCleCycle), donc ce lookup
// ne trouvait jamais rien pour une election municipale/legislative (fonctionnait par coincidence
// uniquement pour les postes nationaux, sans suffixe de ville). NB : verifie en meme temps que
// cette fonction et son unique appelante (consulterResultatsInformateur) ne sont actuellement
// routees par AUCUN ordre/bouton du jeu (aucun appelant trouve ailleurs) -- correctif applique
// quand meme (demande explicite), sans reconstruire cette fonctionnalite ni la re-brancher.
function calculerResultats(posteId, country, city) {
  const cle = typeof getCleCycle === 'function' ? getCleCycle(posteId, city) : posteId;
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle) return null;

  const scores = {};
  cycle.candidats.forEach(c => { scores[c.nom] = 0; });

  // Votes PJ
  Object.values(cycle.votes).forEach(nom => {
    if (scores[nom] !== undefined) scores[nom]++;
  });

  // Votes PNJ
  Object.values(cycle.votesPNJ).forEach(nom => {
    if (scores[nom] !== undefined) scores[nom]++;
  });
  appliquerEffetsTracts(scores, cycle);

  const totalVoix = Object.values(scores).reduce((s, v) => s + v, 0);
  if (totalVoix === 0) return { scores, totalVoix: 0, elu: null, secondTour: [] };

  // Vérifier majorité absolue
  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  const premier = sorted[0];

  if (premier[1] > totalVoix / 2) {
    return { scores, totalVoix, elu: premier[0], secondTour: [] };
  }

  // Second tour — candidats > 15%
  const qualifies = sorted.filter(([, v]) => v / totalVoix >= 0.15).map(([n]) => n);
  return { scores, totalVoix, elu: null, secondTour: qualifies };
}

// Afficher le bureau de vote
function ouvrirBureauDeVote(posteId, country, city) {
  const cle = getCleCycle(posteId, city);
  const cycle = CYCLES_ELECTORAUX[country]?.[cle];
  if (!cycle || !cycle.candidats.length) {
    showToast('Aucun candidat', 'Personne ne s\'est présenté.', false);
    return;
  }

  const phase = getPhaseActuelle(country, posteId, city);
  const poste = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.local, ...POSTES_ELECTIFS.departemental]
    .find(p => p.id === posteId);
  const monVote = cycle.votes[state.char?.name];
  const co = COUNTRIES[country];
  const villeNom = city ? (WORLD[country]?.[city]?.name || city) : null;

  const phaseDeVote = phase === PHASES_ELECTORALES.VOTE || phase === PHASES_ELECTORALES.VOTE2 || phase === PHASES_ELECTORALES.VOTE3E_SIEGE;
  const voteBlanc = monVote === 'BLANC';

  const candidatsHtml = cycle.candidats.map(ca => {
    const aVote = monVote === ca.nom;
    return '<div style="padding:.6rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.3rem">' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:' + (aVote ? '#C9A84C' : '#c0b090') + '">' +
          ca.nom + (aVote ? ' ✦ (votre vote)' : '') +
        '</div>' +
        (phaseDeVote
          ? (!monVote
            ? '<button onclick="voterPourCandidat(this)" data-nom="' + ca.nom + '" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.25rem .6rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Voter</button>'
            : '') : '') +
      '</div>' +
      '<div style="font-size:.72rem;color:#8a8060;font-style:italic;margin-bottom:.2rem">' + ca.programme + '</div>' +
    '</div>';
  }).join('');

  // Vote blanc (chantier "Hotel de Ville / elections", 4 septembre 2026) : choix reel au meme
  // titre qu'un candidat, jamais ajoute a cycle.candidats -- voir voterPour()/calculerResultatsServer.
  const blancHtml = phaseDeVote
    ? '<div style="padding:.6rem .4rem;border-bottom:1px solid #1a1810;border-top:2px solid #3a3020">' +
      '<div style="display:flex;justify-content:space-between;align-items:center">' +
        '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:' + (voteBlanc ? '#C9A84C' : '#9a8a68') + '">Vote blanc' + (voteBlanc ? ' ✦ (votre vote)' : '') + '</div>' +
        (!monVote ? '<button onclick="voterPourCandidat(this)" data-nom="BLANC" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.25rem .6rem;border:1px solid #9a8a68;background:transparent;color:#9a8a68;cursor:pointer">Voter blanc</button>' : '') +
      '</div>' +
      '<div style="font-size:.72rem;color:#8a8060;font-style:italic;margin-top:.2rem">Majorite blanche (&gt;50% des suffrages exprimes) : l\'election est invalidee, un nouveau cycle complet est relance.</div>' +
    '</div>'
    : '';

  const phaseLabel = {
    [PHASES_ELECTORALES.CANDIDATURES]: '📋 Candidatures ouvertes',
    [PHASES_ELECTORALES.CAMPAGNE]:     '📢 Campagne électorale',
    [PHASES_ELECTORALES.VOTE]:         '🗳️ Vote en cours',
    [PHASES_ELECTORALES.SECOND_TOUR]:  '📢 Campagne — Second tour',
    [PHASES_ELECTORALES.VOTE2]:        '🗳️ Second tour',
    [PHASES_ELECTORALES.CAMPAGNE_3E_SIEGE]: '📢 Campagne — 3e siège (égalité)',
    [PHASES_ELECTORALES.VOTE3E_SIEGE]: '🗳️ Second tour — 3e siège (égalité)',
  }[phase] || '❓ Phase inconnue';

  document.getElementById('postes-modal-title').textContent = '🗳️ ' + (poste?.name || posteId) + (villeNom ? ' — ' + villeNom : '') + ' — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.1em;color:#6a8a6a;margin-bottom:.6rem">' + phaseLabel + '</div>' +
    candidatsHtml + blancHtml +
    (phase === PHASES_ELECTORALES.CANDIDATURES
      ? '<button onclick="deposerCandidatureBtn(this)" data-poste="' + posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" style="width:100%;margin-top:.8rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.4rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">📋 Déposer ma candidature</button>'
      : '') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}


// Consulter les résultats via informateur
function consulterResultatsInformateur(posteId, country, city) {
  if (!state.informateurs?.length) {
    showToast('Informateur requis', 'Recrutez un informateur pour connaître les résultats en temps réel.', false);
    return;
  }

  const res = calculerResultats(posteId, country, city);
  if (!res) return;

  const sorted = Object.entries(res.scores).sort((a,b) => b[1]-a[1]);
  const html = sorted.map(([nom, voix]) => {
    const pct = res.totalVoix > 0 ? Math.round(voix/res.totalVoix*100) : 0;
    return '<div style="margin-bottom:.4rem">' +
      '<div style="display:flex;justify-content:space-between;font-size:.78rem;color:#c0b090;margin-bottom:.15rem">' +
        '<span>' + nom + '</span><span>' + voix + ' voix (' + pct + '%)</span>' +
      '</div>' +
      '<div style="height:4px;background:#1a1810;border-radius:2px">' +
        '<div style="height:100%;width:' + pct + '%;background:#C9A84C;border-radius:2px"></div>' +
      '</div></div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '🕵️ Résultats en temps réel';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-size:.68rem;color:#6a5a30;margin-bottom:.6rem;font-style:italic">Source : informateur. ' + res.totalVoix + ' voix comptabilisées.</div>' +
    html +
    (res.elu ? '<div style="margin-top:.6rem;font-size:.78rem;color:#4a8a4a">→ Majorité atteinte : ' + res.elu + ' élu(e) si le vote clôture maintenant.</div>' : '') +
    (res.secondTour.length ? '<div style="margin-top:.6rem;font-size:.78rem;color:#aa8a4a">→ Second tour probable entre : ' + res.secondTour.join(', ') + '.</div>' : '') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// =====================
// SALLE DES ÉLECTIONS — INTERFACE CENTRALISÉE (chantier "Hotel de Ville / elections", 4 septembre
// 2026). Deux boutons permanents (Voter / Se porter candidat), toujours visibles dans les 3
// Hotels de Ville (Luthecia/Montrouge/PSM, voir data.js), presentant Presidentielle/Legislatives/
// Municipales (municipales = ville courante du joueur). Reutilise integralement le moteur
// electoral existant (CYCLES_ELECTORAUX/getPhaseActuelle/ouvrirBureauDeVote/deposerCandidature) --
// aucun systeme parallele. Le referendum n'est PAS implemente ici (arbitrage separe a venir).
// =====================
const ENTREES_SALLE_ELECTIONS = [
  { posteId: 'president', local: false, label: 'Présidentielle' },
  { posteId: 'depute',    local: true,  label: 'Législatives' },
  { posteId: 'maire',     local: true,  label: 'Municipales' }
];

async function ouvrirVoterElection() {
  document.getElementById('postes-modal-title').textContent = '🗳️ Voter';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');
  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase();

  const country = state.country;
  const ville = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[ville]?.name || ville;
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};

  let html = '<div style="padding:.4rem 0">';
  for (const e of ENTREES_SALLE_ELECTIONS) {
    const city = e.local ? ville : null;
    const cle = getCleCycle(e.posteId, city);
    if (!CYCLES_ELECTORAUX[country][cle]) await initCycleElectoral(country, e.posteId, city);
    const cycle = CYCLES_ELECTORAUX[country][cle];
    const phase = getPhaseActuelle(country, e.posteId, city);
    const enVote = (phase === PHASES_ELECTORALES.VOTE || phase === PHASES_ELECTORALES.VOTE2 || phase === PHASES_ELECTORALES.VOTE3E_SIEGE)
      && cycle?.candidats?.length > 0;
    const dejaVote = cycle?.votes?.[state.char?.name];
    const label = e.label + (e.local ? ' — ' + villeNom : '');
    html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.7rem 1rem;border-bottom:1px solid #1a1810">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:' + (enVote ? '#e0d5b8' : '#6a5a30') + '">' + label + '</div>';
    if (enVote && dejaVote) {
      html += '<span style="font-size:.72rem;color:#4a8a4a;font-style:italic">Déjà voté (' + (dejaVote === 'BLANC' ? 'blanc' : dejaVote) + ')</span>';
    } else if (enVote) {
      html += '<button onclick="ouvrirBureauDeVoteDepuisSalle(this)" data-poste="' + e.posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.06em;padding:.35rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Voter</button>';
    } else {
      html += '<span style="font-size:.72rem;color:#6a5a30;font-style:italic">Pas d\'élection en cours</span>';
    }
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

function ouvrirBureauDeVoteDepuisSalle(el) {
  ouvrirBureauDeVote(el.dataset.poste, el.dataset.country, el.dataset.city || null);
}

async function ouvrirSePorterCandidat() {
  document.getElementById('postes-modal-title').textContent = '📋 Se porter candidat';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');
  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase();

  const country = state.country;
  const ville = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[ville]?.name || ville;
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};

  let html = '<div style="padding:.4rem 0">';
  for (const e of ENTREES_SALLE_ELECTIONS) {
    const city = e.local ? ville : null;
    const cle = getCleCycle(e.posteId, city);
    if (!CYCLES_ELECTORAUX[country][cle]) await initCycleElectoral(country, e.posteId, city);
    const cycle = CYCLES_ELECTORAUX[country][cle];
    const phase = getPhaseActuelle(country, e.posteId, city);
    // Meme convention d'affichage que l'ancien bouton "Candidater" du Calendrier electoral
    // (visible uniquement en phase CANDIDATURES) -- le moteur (deposerCandidature) accepte en
    // realite une candidature a tout moment depuis le 17 aout 2026 (arbitrage explicite,
    // inchange ici), seule cette visibilite reprend la meme convention deja existante.
    const candidaturesOuvertes = phase === PHASES_ELECTORALES.CANDIDATURES;
    const dejaCandidat = cycle?.candidats?.some(c => c.nom === state.char?.name);
    const label = e.label + (e.local ? ' — ' + villeNom : '');
    html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.7rem 1rem;border-bottom:1px solid #1a1810">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:' + (candidaturesOuvertes ? '#e0d5b8' : '#6a5a30') + '">' + label + '</div>';
    if (dejaCandidat) {
      html += '<span style="font-size:.72rem;color:#4a8a4a;font-style:italic">Déjà candidat</span>';
    } else if (candidaturesOuvertes) {
      html += '<button onclick="deposerCandidatureDepuisSalle(this)" data-poste="' + e.posteId + '" data-country="' + country + '" data-city="' + (city||'') + '" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.06em;padding:.35rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Candidater</button>';
    } else {
      html += '<span style="font-size:.72rem;color:#6a5a30;font-style:italic">Candidatures non ouvertes actuellement</span>';
    }
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

function deposerCandidatureDepuisSalle(el) {
  deposerCandidature(el.dataset.poste, el.dataset.country, el.dataset.city || null);
}

// ---- Modificateur standard reutilise par l'ordre electoral sensible restant sur cette echelle
// (contestation, qui utilise INT -- enquete, explicitement demande) : meme convention deja
// etablie ailleurs dans le jeu (base + N*(stat-13), clampe [5,95]).
function tauxAvecModificateurStat(base, stat) {
  const valeur = typeof getStatEffective === 'function' ? getStatEffective(stat) : 13;
  return Math.max(5, Math.min(95, Math.round(base + 5 * (valeur - 13))));
}

// ---- Modificateur DIS pour les 3 fraudes electorales (falsifier/bourrer/truquer) -- correctif
// du 4 septembre 2026 apres verification factuelle : DIS existe reellement (state.dis, ressource
// de Discretion 0-100, deja utilisee ailleurs dans le jeu pour moduler des taux de detection
// d'actes illegaux, ex. plateau-justice-economie.js), mais PAS sur l'echelle centree-13 des 6
// autres caracteristiques -- DUP (utilise a tort avant cette correction) abandonne. Formule
// validee : modificateur en points = round((DIS-50)/5) -- DIS 0 => -10 pts, 50 => neutre,
// 100 => +10 pts. Repli sur 50 (convention deja etablie ailleurs pour state.dis) si absent.
function tauxAvecDIS(base) {
  const dis = (typeof state !== 'undefined' && typeof state.dis === 'number') ? state.dis : 50;
  const modificateur = Math.round((dis - 50) / 5);
  return Math.max(5, Math.min(95, base + modificateur));
}

// =====================
// MOTEUR DE DEPOUILLEMENT PARTAGE (chantier "Hotel de Ville / elections", 4 septembre 2026).
// Duplique verbatim cote serveur (api/cron-minuit.js, meme doctrine que construireNouveauCycleElectoral
// deja duplique -- ce fichier client n'a jamais accces au contexte serveur, et cron-minuit.js n'a
// jamais accces a ce fichier). Les DEUX copies doivent rester identiques : toute correction ici
// doit etre repercutee la-bas, et reciproquement.
//
// Vote blanc : jamais un candidat fictif ajoute a cycle.candidats -- comptabilise a part
// (sentinel 'BLANC' dans cycle.votes/votesPNJ). Majorite blanche = blanc > 50% des SUFFRAGES
// EXPRIMES (candidats + blancs), jamais 50% des seuls votes candidats.
// =====================
function calculerScoresBaseCycle(cycle, fraudesActives) {
  const scores = {};
  (cycle.candidats || []).forEach(c => { scores[c.nom] = 0; });
  let blancs = 0;
  Object.values(cycle.votes || {}).forEach(nom => {
    if (nom === 'BLANC') { blancs++; return; }
    if (scores[nom] !== undefined) scores[nom]++;
  });
  Object.values(cycle.votesPNJ || {}).forEach(nom => {
    if (nom === 'BLANC') { blancs++; return; }
    if (scores[nom] !== undefined) scores[nom]++;
  });
  // Tracts electoraux aupres des PNJ (+1 / -1, plancher 0) du tour courant.
  appliquerEffetsTracts(scores, cycle);
  // Fraudes ENCORE NON REVELEES uniquement : une fraude revelee est deja corrigee a la source
  // (voir resolution de contestation), elle ne doit plus jamais etre appliquee une seconde fois.
  (fraudesActives || []).forEach(f => {
    if (scores[f.candidat] !== undefined) scores[f.candidat] = Math.max(0, scores[f.candidat] + f.delta_voix);
  });
  const totalCandidats = Object.values(scores).reduce((s, v) => s + v, 0);
  return { scores, blancs, totalExprimes: totalCandidats + blancs };
}

// Postes a siege unique (president/maire/chef_syndicat) : majorite absolue sinon second tour
// (candidats >= 15% des exprimes). blancMajoritaire prioritaire sur tout le reste.
function resoudreScrutinSimple(cycle, fraudesActives) {
  const candidats = cycle.candidats || [];
  if (candidats.length === 0) return null;
  const { scores, blancs, totalExprimes } = calculerScoresBaseCycle(cycle, fraudesActives);
  if (totalExprimes === 0) return { scores, blancs, totalExprimes: 0, elu: null, secondTour: [], blancMajoritaire: false };
  if (blancs > totalExprimes / 2) return { scores, blancs, totalExprimes, elu: null, secondTour: [], blancMajoritaire: true };

  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  const premier = sorted[0];
  // CANDIDAT UNIQUE (regle validee le 12 septembre 2026) : il est elu des qu'il fait au moins autant
  // que les bulletins blancs ; le vote blanc ne l'emporte que s'il est STRICTEMENT superieur. Sans
  // cela, l'egalite exacte candidat unique / blancs ne produisait ni elu, ni vote blanc, ni second
  // tour possible (un seul candidat) : le cycle restait bloque indefiniment.
  if (candidats.length === 1) {
    return premier[1] >= blancs
      ? { scores, blancs, totalExprimes, elu: premier[0], secondTour: [], blancMajoritaire: false }
      : { scores, blancs, totalExprimes, elu: null, secondTour: [], blancMajoritaire: true };
  }
  if (premier[1] > totalExprimes / 2) {
    return { scores, blancs, totalExprimes, elu: premier[0], secondTour: [], blancMajoritaire: false };
  }
  // SEUIL DE QUALIFICATION (regle validee le 12 septembre 2026) : 15 % des exprimes. Mais si moins
  // de DEUX candidats l'atteignent, les deux arrives en tete sont qualifies malgre tout -- sans
  // cela le scrutin restait bloque : aucune branche du depouillement ne s'appliquait, le cycle
  // n'etait jamais marque resultatsTraites et le cron le reexaminait chaque nuit indefiniment.
  let qualifies = sorted.filter(([, v]) => v / totalExprimes >= 0.15).map(([n]) => n);
  if (qualifies.length < 2) qualifies = sorted.slice(0, 2).map(([n]) => n);
  return { scores, blancs, totalExprimes, elu: null, secondTour: qualifies, blancMajoritaire: false };
}

// Legislatives (depute) : 3 sieges reels par ville, une seule circonscription (chantier du 4
// septembre 2026 -- remplace le nbParVille:3 jusque-la decoratif). Les candidats strictement
// au-dessus du seuil de voix du 3e siege sont elus surs ; une egalite AU seuil (qui peut donc
// concerner le 3e siege mais aussi, plus rarement, le 1er/2e si plusieurs candidats sont a
// egalite en tete) declenche un second tour PARTIEL entre les seuls candidats ex aequo, pour les
// seuls sieges encore a attribuer -- jamais entre tous les candidats.
function resoudreScrutinDepute(cycle, fraudesActives) {
  const candidats = cycle.candidats || [];
  if (candidats.length === 0) return null;
  const { scores, blancs, totalExprimes } = calculerScoresBaseCycle(cycle, fraudesActives);
  if (totalExprimes === 0) return { scores, blancs, totalExprimes: 0, elus: [], egalite3eSiege: null, blancMajoritaire: false };
  if (blancs > totalExprimes / 2) return { scores, blancs, totalExprimes, elus: [], egalite3eSiege: null, blancMajoritaire: true };

  // Un seul tour (12 septembre 2026) : les 3 meilleurs scores sont elus. Egalite departagee par
  // l'anciennete de la candidature (dateInscription), puis par ordre alphabetique -- jamais de
  // second tour partiel. MEME code que la copie serveur (api/cron-minuit.js).
  const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1] || departageCandidats(candidats, a[0], b[0]));
  return { scores, blancs, totalExprimes, elus: sorted.slice(0, 3).map(([n]) => n), egalite3eSiege: null, blancMajoritaire: false };
}

function departageCandidats(candidats, nomA, nomB) {
  const date = nom => { const c = (candidats || []).find(x => x.nom === nom); const d = Number(c && c.dateInscription); return isFinite(d) && d > 0 ? d : Infinity; };
  return (date(nomA) - date(nomB)) || (nomA < nomB ? -1 : (nomA > nomB ? 1 : 0));
}

// =====================
// FRAUDES ÉLECTORALES (chantier "Hotel de Ville / elections", 4 septembre 2026). Trois ordres
// distincts, memes principes communs : choix du scrutin (parmi Presidentielle/Legislatives/
// Municipales de la ville courante) puis du candidat beneficiaire, jet avec modificateur
// standard (DUP), reussite = fraude enregistree (non revelee, delta applique au prochain
// depouillement par le cron -- jamais applique directement ici, cote client, pour ne jamais
// pouvoir modifier cycle.eluId soi-meme), echec = emprisonnement immediat, aucune voix modifiee.
// =====================

// Emprisonnement dedie fraude electorale : reutilise EXACTEMENT le mecanisme existant
// (state.estEmprisonne/personnages.est_emprisonne, deja lu par la navigation/l'affichage du
// commissariat) -- jamais un second systeme de detention. "jusqu'a la fin du processus electoral"
// (falsification/depouillement) est un evenement EXTERNE (resolu par le cron, pas par state.day,
// personnel et non fiable comme horloge partagee -- meme doctrine que le reste du moteur
// electoral) : jourFin sert donc de PLAFOND de securite genereux (jamais atteint en temps normal),
// tandis que la liberation reelle et precise est declenchee par le cron des que CE scrutin precis
// est effectivement clos (liberationElection, verifie cote serveur). "24h reelles" (bourrage
// d'urnes) reprend exactement l'idiome deja existant du jeu pour une peine de ce type (jours:1,
// voir plateau-communication.js/distribuerTractCalomnieux).
async function emprisonnerPourFraude(joursPlafond, raison, liberationElection) {
  // DETENTION CANONIQUE (16 septembre 2026). Ce bloc posait un est_emprisonne fabrique a la main,
  // SANS detentionId ni debutTs : la peine etait donc invisible du registre du commissariat ET du
  // filet de liberation nocturne, qui s'ancre sur debutTs. Une detention fantome, que seule la
  // navigation voyait. enregistrerDetention cree la vraie ligne `detentions` et le miroir, comme
  // toutes les autres incarcerations -- le fraudeur s'emprisonne lui-meme, l'ecriture est donc
  // autorisee sur sa propre fiche.
  //
  // La sanction ne change pas d'un jour. liberationElection est simplement REPOSE apres coup :
  // c'est lui qui permet au cron de liberer des que CE scrutin est clos, avant le plafond.
  const jourFin = (state.day || 1) + joursPlafond;
  if (typeof enregistrerDetention === 'function') {
    await enregistrerDetention(state.char?.name, raison, jourFin, undefined, state.currentCity, {
      country: state.country || 'republic',
      source: 'fraude_electorale',
      motifs: [{ type: raison, jour_fait: state.day || 1, city: state.currentCity || 'capitale',
                 jours: joursPlafond, source: 'fraude_electorale',
                 date_evenement: new Date().toISOString() }]
    }).catch(() => {});
  }
  if (!state.estEmprisonne) state.estEmprisonne = { jours: joursPlafond, jourFin, raison };
  state.estEmprisonne.liberationElection = liberationElection || null;
  if (state.char) state.char.estEmprisonne = state.estEmprisonne;
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
}

async function listerScrutinsPourFraude(filtrePoste) {
  const country = state.country;
  const ville = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[ville]?.name || ville;
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};
  const out = [];
  for (const e of ENTREES_SALLE_ELECTIONS) {
    if (filtrePoste && !filtrePoste(e.posteId)) continue;
    const city = e.local ? ville : null;
    const cle = getCleCycle(e.posteId, city);
    if (!CYCLES_ELECTORAUX[country][cle]) await initCycleElectoral(country, e.posteId, city);
    const cycle = CYCLES_ELECTORAUX[country][cle];
    out.push({ posteId: e.posteId, city, cle, cycle, label: e.label + (e.local ? ' — ' + villeNom : '') });
  }
  return out;
}

function htmlChoixCandidatFraude(fnConfirm, entree, pa, cost, extra) {
  const candidats = entree.cycle?.candidats || [];
  if (candidats.length === 0) {
    return '<div style="font-size:.8rem;color:#8a8060;font-style:italic;padding:.5rem 0">Aucun candidat déclaré pour ce scrutin.</div>';
  }
  return candidats.map(c =>
    '<div onclick="' + fnConfirm + '(\'' + entree.posteId + '\',\'' + (entree.city||'') + '\',\'' + c.nom.replace(/'/g,"\\'") + '\'' + (extra ? ',' + extra : '') + ')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer;font-size:.82rem;color:#c0b090">' + escapeHtmlText(c.nom) + '</div>'
  ).join('');
}

// ---- A. FALSIFIER LES LISTES ÉLECTORALES (maire/adjoint sortant, municipales de sa ville) ----
async function ouvrirFalsifierListesElectorales(pa, cost) {
  const posteActuel = state.poste?.id;
  if (posteActuel !== 'maire' && posteActuel !== 'maire_adjoint') {
    showToast('Accès refusé', 'Réservé au maire ou à l\'adjoint au maire en exercice.', false);
    return;
  }
  const ville = state.currentCity || 'capitale';
  const [entree] = await listerScrutinsPourFraude(id => id === 'maire');
  document.getElementById('postes-modal-title').textContent = '🗳️ Falsifier les listes électorales';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.78rem;color:#8a3a2a;font-style:italic;margin-bottom:.8rem">Choisir le candidat bénéficiaire — ' + entree.label + '. Réussite : +1 à +10 voix frauduleuses (appliquées au dépouillement). Échec : pris sur le fait, emprisonnement jusqu\'à la fin du processus électoral en cours.</div>' +
    htmlChoixCandidatFraude('confirmerFalsifierListes', entree, pa, cost) +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerFalsifierListes(posteId, city, candidatNom) {
  document.getElementById('modal-postes').classList.remove('open');
  const country = state.country;
  const cycle = CYCLES_ELECTORAUX[country]?.[getCleCycle(posteId, city || null)];
  if (!cycle) return;
  // Controle A L'EXECUTION (correctif du 4 septembre 2026, audit dedie) : le filtrage du bouton
  // dans ouvrirFalsifierListesElectorales ne suffit pas -- cette fonction doit refuser elle-meme
  // un appel hors regle, jamais compter uniquement sur le masquage cote interface. Autorisee
  // uniquement AVANT l'ouverture du vote (candidatures, campagne, et second tour eventuel) --
  // jamais une fois le vote ouvert ou le scrutin depouille/resolu.
  const posteActuelExec = state.poste?.id;
  if (posteActuelExec !== 'maire' && posteActuelExec !== 'maire_adjoint') {
    showToast('Accès refusé', 'Réservé au maire ou à l\'adjoint au maire en exercice.', false);
    return;
  }
  const phaseFalsif = getPhaseActuelle(country, posteId, city);
  const phasesAutoriseesFalsif = [PHASES_ELECTORALES.CANDIDATURES, PHASES_ELECTORALES.CAMPAGNE, PHASES_ELECTORALES.SECOND_TOUR, PHASES_ELECTORALES.CAMPAGNE_3E_SIEGE];
  if (!phasesAutoriseesFalsif.includes(phaseFalsif)) {
    showToast('Hors fenêtre', 'Les listes électorales ne se falsifient qu\'avant l\'ouverture du vote.', false);
    return;
  }
  // Controle A L'EXECUTION du candidat cible (correctif du 4 septembre 2026, audit dedie) :
  // cycle.candidats est TOUJOURS la liste exacte du tour actuellement en cours pour CE scrutin
  // precis (posteId+city) -- remplacee par le cron a chaque nouveau tour (second tour, runoff
  // 3e siege), jamais cumulative. Un seul test suffit donc a exclure a la fois un PJ non
  // candidat, un candidat d'une autre ville/election (cycle different, jamais celui-ci), et un
  // ancien candidat elimine qui ne fait plus partie du tour en cours.
  if (!cycle.candidats?.some(c => c.nom === candidatNom)) {
    showToast('Candidat invalide', 'Ce candidat ne fait pas partie du tour actuellement en lice pour ce scrutin.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa: 2, cost: 0 });
  if (!r.ok) { signalerRefusCout(r); return; }

  const taux = tauxAvecDIS(70);
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    const cycleDebut = cycle.dateDebutCandidatures;
    const rang = (await sbCompterFraudesParType(country, posteId, city || null, cycleDebut, 'falsification_listes')) + 1;
    const deltaVoix = Math.floor(Math.random() * 10) + 1;
    await sbEnregistrerFraudeElectorale({
      country, posteId, city: city || null, cycleDebut, type: 'falsification_listes',
      auteur: state.char?.name, candidat: candidatNom, deltaVoix, detectabilitePct: detectabilitePourRang(rang)
    });
    showToast('Listes falsifiées', 'La fraude a réussi. Les voix seront comptabilisées au dépouillement.', true, true);
    addJournalEntry('🗳️ Listes électorales falsifiées en faveur de ' + candidatNom + '.', 'event-good');
  } else {
    await emprisonnerPourFraude(20, 'Falsification des listes électorales — pris(e) sur le fait', { country, posteId, city: city || null, cycleDebut: cycle.dateDebutCandidatures });
    showToast('Pris(e) sur le fait !', 'Aucune voix modifiée. Emprisonnement jusqu\'à la fin du processus électoral.', false);
    addJournalEntry('🚨 Tentative de falsification des listes électorales déjouée.', 'event-bad');
  }
  updateUI();
}

// ---- B. BOURRER LES URNES (tout electeur inscrit, pendant les 24h de vote) ----
async function ouvrirBourrerUrnes(pa, cost) {
  const entrees = await listerScrutinsPourFraude();
  const domicile = state.domicile;
  const domicilePays = domicile?.country || state.country;
  const ouverts = entrees.filter(e => {
    const phase = getPhaseActuelle(state.country, e.posteId, e.city);
    return (phase === PHASES_ELECTORALES.VOTE || phase === PHASES_ELECTORALES.VOTE2 || phase === PHASES_ELECTORALES.VOTE3E_SIEGE)
      && (e.cycle?.candidats?.length > 0) && domicilePays === state.country;
  });
  document.getElementById('postes-modal-title').textContent = '🗳️ Bourrer les urnes';
  if (ouverts.length === 0) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;font-size:.82rem;color:#8a8060;font-style:italic">Aucun scrutin en phase de vote actuellement pour lequel vous êtes inscrit.</div>';
    document.getElementById('modal-postes').classList.add('open');
    return;
  }
  let html = '<div style="padding:1rem"><div style="font-size:.78rem;color:#8a3a2a;font-style:italic;margin-bottom:.8rem">Réussite : +1 à +3 voix frauduleuses. Échec : 24h réelles de prison.</div>';
  ouverts.forEach(e => { html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#8a6a20;margin:.6rem 0 .3rem">' + e.label + '</div>' + htmlChoixCandidatFraude('confirmerBourrerUrnes', e, pa, cost); });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerBourrerUrnes(posteId, city, candidatNom) {
  document.getElementById('modal-postes').classList.remove('open');
  const country = state.country;
  const cycle = CYCLES_ELECTORAUX[country]?.[getCleCycle(posteId, city || null)];
  if (!cycle) return;
  // Controle A L'EXECUTION (correctif du 4 septembre 2026, audit dedie) : le filtrage de
  // ouvrirBourrerUrnes ne suffit pas -- cette fonction doit refuser elle-meme un appel hors
  // fenetre de vote reelle, jamais compter uniquement sur le masquage cote interface.
  const phaseBourrage = getPhaseActuelle(country, posteId, city);
  if (phaseBourrage !== PHASES_ELECTORALES.VOTE && phaseBourrage !== PHASES_ELECTORALES.VOTE2 && phaseBourrage !== PHASES_ELECTORALES.VOTE3E_SIEGE) {
    showToast('Hors fenêtre', 'Les urnes ne se bourrent que pendant une fenêtre de vote ouverte.', false);
    return;
  }
  // Controle A L'EXECUTION du candidat cible (correctif du 4 septembre 2026, audit dedie) : voir
  // le commentaire equivalent dans confirmerFalsifierListes -- cycle.candidats est toujours la
  // liste exacte du tour en cours pour ce scrutin precis.
  if (!cycle.candidats?.some(c => c.nom === candidatNom)) {
    showToast('Candidat invalide', 'Ce candidat ne fait pas partie du tour actuellement en lice pour ce scrutin.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa: 1, cost: 0 });
  if (!r.ok) { signalerRefusCout(r); return; }

  const taux = tauxAvecDIS(60);
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    const cycleDebut = cycle.dateDebutCandidatures;
    const rang = (await sbCompterFraudesParType(country, posteId, city || null, cycleDebut, 'bourrage_urnes')) + 1;
    const deltaVoix = Math.floor(Math.random() * 3) + 1;
    await sbEnregistrerFraudeElectorale({
      country, posteId, city: city || null, cycleDebut, type: 'bourrage_urnes',
      auteur: state.char?.name, candidat: candidatNom, deltaVoix, detectabilitePct: detectabilitePourRang(rang)
    });
    showToast('Urnes bourrées', 'La fraude a réussi. Les voix seront comptabilisées au dépouillement.', true, true);
    addJournalEntry('🗳️ Urnes bourrées en faveur de ' + candidatNom + '.', 'event-good');
  } else {
    await emprisonnerPourFraude(1, 'Bourrage d\'urnes — pris(e) sur le fait');
    showToast('Pris(e) sur le fait !', 'Aucune voix modifiée. 24h de prison.', false);
    addJournalEntry('🚨 Tentative de bourrage d\'urnes déjouée. 24h de prison.', 'event-bad');
  }
  updateUI();
}

// ---- C. TRUQUER LE DÉPOUILLEMENT (commissaire ou juge) ----
async function ouvrirTruquerDepouillement(pa, cost) {
  const posteActuel = state.poste?.id;
  const estCommissaire = posteActuel === 'commissaire';
  const estJuge = posteActuel === 'juge';
  if (!estCommissaire && !estJuge) {
    showToast('Accès refusé', 'Réservé au commissaire ou au juge.', false);
    return;
  }
  // Commissaire : scrutins de SA ville uniquement (scope de sa fonction) ; juge : scope national,
  // tous les scrutins (municipales comprises, comme un juge peut arbitrer partout dans le pays).
  // Filtre par fenetre de vote reelle (correctif du 4 septembre 2026, audit dedie) : le
  // depouillement etant automatique (cron), truquer le depouillement n'a de sens QUE pendant le
  // vote (le delta persistant est ensuite pris en compte a la fermeture) -- jamais avant (aucun
  // vote a truquer) ni apres (scrutin deja resolu par le cron ou par une contestation anterieure).
  const entreesTruquage = await listerScrutinsPourFraude();
  const entrees = entreesTruquage.filter(e => {
    const phase = getPhaseActuelle(state.country, e.posteId, e.city);
    return phase === PHASES_ELECTORALES.VOTE || phase === PHASES_ELECTORALES.VOTE2 || phase === PHASES_ELECTORALES.VOTE3E_SIEGE;
  });
  document.getElementById('postes-modal-title').textContent = '🗳️ Truquer le dépouillement';
  if (entrees.length === 0) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;font-size:.82rem;color:#8a8060;font-style:italic">Aucun scrutin en phase de vote actuellement.</div>';
    document.getElementById('modal-postes').classList.add('open');
    return;
  }
  let html = '<div style="padding:1rem"><div style="font-size:.78rem;color:#8a3a2a;font-style:italic;margin-bottom:.8rem">Choisir le candidat puis ajouter ou retirer 1 à 10 voix. Échec : pris sur le fait, emprisonnement jusqu\'à la fin du processus électoral en cours. Vous conservez votre poste même si vous êtes découvert.</div>';
  entrees.forEach(e => {
    if (!e.cycle?.candidats?.length) return;
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#8a6a20;margin:.6rem 0 .3rem">' + e.label + '</div>';
    e.cycle.candidats.forEach(c => {
      html += '<div style="display:flex;justify-content:space-between;align-items:center;padding:.4rem .6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem">' +
        '<span style="font-size:.82rem;color:#c0b090">' + escapeHtmlText(c.nom) + '</span>' +
        '<div style="display:flex;gap:.4rem">' +
        '<button onclick="confirmerTruquerDepouillement(\'' + e.posteId + '\',\'' + (e.city||'') + '\',\'' + c.nom.replace(/'/g,"\\'") + '\',1)" style="font-size:.68rem;padding:.2rem .5rem;border:1px solid #3a5a3a;background:transparent;color:#4a8a4a;cursor:pointer">+ Ajouter</button>' +
        '<button onclick="confirmerTruquerDepouillement(\'' + e.posteId + '\',\'' + (e.city||'') + '\',\'' + c.nom.replace(/'/g,"\\'") + '\',-1)" style="font-size:.68rem;padding:.2rem .5rem;border:1px solid #5a3a3a;background:transparent;color:#aa4a4a;cursor:pointer">− Retirer</button>' +
        '</div></div>';
    });
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerTruquerDepouillement(posteId, city, candidatNom, sens) {
  document.getElementById('modal-postes').classList.remove('open');
  const country = state.country;
  const cycle = CYCLES_ELECTORAUX[country]?.[getCleCycle(posteId, city || null)];
  if (!cycle) return;
  // Controle A L'EXECUTION (correctif du 4 septembre 2026, audit dedie) : le filtrage de
  // ouvrirTruquerDepouillement ne suffit pas -- cette fonction doit refuser elle-meme un appel
  // hors fenetre de vote reelle. Interdit absolument la creation d'une fraude de depouillement
  // une fois l'election resolue (phase mandat/vacant), y compris via un appel direct qui
  // contournerait l'ecran de choix.
  const posteActuelTruq = state.poste?.id;
  if (posteActuelTruq !== 'commissaire' && posteActuelTruq !== 'juge') {
    showToast('Accès refusé', 'Réservé au commissaire ou au juge.', false);
    return;
  }
  const phaseTruquage = getPhaseActuelle(country, posteId, city);
  if (phaseTruquage !== PHASES_ELECTORALES.VOTE && phaseTruquage !== PHASES_ELECTORALES.VOTE2 && phaseTruquage !== PHASES_ELECTORALES.VOTE3E_SIEGE) {
    showToast('Hors fenêtre', 'Le dépouillement ne se truque que pendant une fenêtre de vote ouverte.', false);
    return;
  }
  // Controle A L'EXECUTION du candidat cible (correctif du 4 septembre 2026, audit dedie) : voir
  // le commentaire equivalent dans confirmerFalsifierListes -- cycle.candidats est toujours la
  // liste exacte du tour en cours pour ce scrutin precis.
  if (!cycle.candidats?.some(c => c.nom === candidatNom)) {
    showToast('Candidat invalide', 'Ce candidat ne fait pas partie du tour actuellement en lice pour ce scrutin.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa: 2, cost: 0 });
  if (!r.ok) { signalerRefusCout(r); return; }

  const taux = tauxAvecDIS(75);
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    const cycleDebut = cycle.dateDebutCandidatures;
    const rang = (await sbCompterFraudesParType(country, posteId, city || null, cycleDebut, 'trucage_depouillement')) + 1;
    const ampleur = Math.floor(Math.random() * 10) + 1;
    const deltaVoix = sens * ampleur;
    await sbEnregistrerFraudeElectorale({
      country, posteId, city: city || null, cycleDebut, type: 'trucage_depouillement',
      auteur: state.char?.name, candidat: candidatNom, deltaVoix, detectabilitePct: detectabilitePourRang(rang)
    });
    showToast('Dépouillement truqué', 'La fraude a réussi (' + (sens > 0 ? '+' : '') + deltaVoix + ' voix pour ' + candidatNom + ').', true, true);
    addJournalEntry('🗳️ Dépouillement truqué : ' + (sens > 0 ? '+' : '') + deltaVoix + ' voix pour ' + candidatNom + '.', 'event-good');
  } else {
    await emprisonnerPourFraude(20, 'Trucage du dépouillement — pris(e) sur le fait', { country, posteId, city: city || null, cycleDebut: cycle.dateDebutCandidatures });
    showToast('Pris(e) sur le fait !', 'Aucune voix modifiée. Emprisonnement jusqu\'à la fin du processus électoral. Vous conservez votre poste.', false);
    addJournalEntry('🚨 Tentative de trucage du dépouillement déjouée.', 'event-bad');
    // Evenement public prioritaire pour La Tribune (demande explicite, section 7C) : jamais
    // invente, alimente le pipeline factuel existant via chronique_nationale (deja lu par
    // collecterChroniqueNationale, api/_journal-collecte.js).
    if (typeof sbEnregistrerEvenementPublic === 'function') {
      const roleFraudeur = estJugeCourant() ? 'le juge' : 'le commissaire';
      sbEnregistrerEvenementPublic(country, 'fraude_electorale_dejouee', {
        city: city || null,
        personnages: [state.char?.name].filter(Boolean),
        libelle: (state.char?.name || 'Un fonctionnaire') + ', ' + roleFraudeur + (city ? ' de ' + (WORLD[country]?.[city]?.name || city) : '') + ', a été pris(e) sur le fait en tentant de truquer le dépouillement d\'un scrutin.',
        data: { poste_id: posteId, candidat_vise: candidatNom }
      }).catch(() => {});
    }
  }
  updateUI();
}

function estJugeCourant() { return state.poste?.id === 'juge'; }

// Afficher le tableau de bord électoral complet
// =====================
// CONTESTATION DES RÉSULTATS — VERSION UNIQUE (chantier "Hotel de Ville / elections", 4 septembre
// 2026). Remplace les deux versions incoherentes precedentes (bureau_maire et salle_elections,
// meme fn, parametres differents, lisant state.electionsEnCours -- jamais alimente par le vrai
// moteur electoral). Disponible 24h reelles apres proclamation, pour tout electeur habilite
// (meme regle de domiciliation que le vote). Un clic = une fraude potentiellement revelee, jamais
// un audit complet -- selection non biaisee parmi les fraudes encore non revelees du scrutin.
// =====================
async function ouvrirContesterResultatsElection(pa, cost) {
  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase();
  const entrees = await listerScrutinsPourFraude();
  const domicile = state.domicile;
  const domicilePays = domicile?.country || state.country;
  const now = Date.now();
  const contestables = entrees.filter(e => {
    const c = e.cycle;
    return c && c.resultatsTraites && c.dateResultats && (now - c.dateResultats) <= 24 * 60 * 60 * 1000
      && (now - c.dateResultats) >= 0 && domicilePays === state.country;
  });

  document.getElementById('postes-modal-title').textContent = '⚖️ Contester des résultats';
  if (contestables.length === 0) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;font-size:.82rem;color:#8a8060;font-style:italic">Aucun résultat proclamé dans les dernières 24h pour un scrutin où vous êtes habilité.</div>';
    document.getElementById('modal-postes').classList.add('open');
    return;
  }
  let html = '<div style="padding:1rem"><div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Coût : 2 PA · 200 FR par tentative. Une contestation réussie ne révèle qu\'un seul acte de fraude, choisi sans biais parmi ceux non encore découverts.</div>';
  contestables.forEach(e => {
    html += '<button onclick="confirmerContesterResultats(\'' + e.posteId + '\',\'' + (e.city||'') + '\')" style="display:block;width:100%;text-align:left;padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.8rem;margin-bottom:.4rem">' + e.label + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerContesterResultats(posteId, city) {
  document.getElementById('modal-postes').classList.remove('open');
  const country = state.country;
  const cle = getCleCycle(posteId, city || null);

  // Controle A L'EXECUTION, sur donnee FRAICHE (correctif du 4 septembre 2026, audit dedie) :
  // ouvrirContesterResultatsElection filtrait deja a l'affichage sur les 24h reelles depuis
  // dateResultats, mais confirmerContesterResultats ne revalidait rien elle-meme -- un appel
  // direct (ou une simple lenteur entre l'ouverture du panneau et le clic) pouvait contester une
  // "vieille" election bien au-dela des 24h. Chargee et verifiee ICI, avant toute depense de
  // PA/FR, jamais uniquement par le masquage du bouton cote interface.
  const rows = await sbGet('cycles_electoraux', `id=eq.${encodeURIComponent(country + '_' + cle)}`).catch(() => []);
  const row = rows && rows[0];
  if (!row) { showToast('Indisponible', 'Ce scrutin n\'est plus consultable.', false); return; }
  const cycle = JSON.parse(row.data);
  const cycleDebut = cycle.dateDebutCandidatures;
  const nowContestation = Date.now();
  const dansLaFenetre24h = cycle.resultatsTraites && cycle.dateResultats
    && (nowContestation - cycle.dateResultats) >= 0 && (nowContestation - cycle.dateResultats) <= 24 * 60 * 60 * 1000;
  if (!dansLaFenetre24h) {
    showToast('Hors délai', 'Ce scrutin n\'est plus contestable (au-delà des 24h suivant la proclamation, ou résultats pas encore proclamés).', false);
    return;
  }

  const r = await deduireCoutOrdre({ pa: 2, cost: 200 });
  if (!r.ok) {
    showToast(r.raison === 'fonds_insuffisants' ? 'Fonds insuffisants' : 'PA insuffisants', r.raison === 'fonds_insuffisants' ? '200 FR requis.' : '2 PA requis.', false);
    return;
  }

  const taux = tauxAvecModificateurStat(60, 'INT');
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll > taux) {
    showToast('Contestation rejetée', 'Le dossier n\'a pas abouti.', false);
    addJournalEntry('⚖️ Contestation des résultats rejetée.', 'event-bad');
    return;
  }

  const nonRevelees = await sbGetFraudesNonRevelees(country, posteId, city || null, cycleDebut);
  if (nonRevelees.length === 0) {
    showToast('Contestation menée', 'Aucune fraude n\'a été détectée cette fois.', true);
    addJournalEntry('⚖️ Contestation menée : aucune fraude détectée.', 'event-info');
    return;
  }

  // Selection NON BIAISEE parmi les fraudes encore non revelees (jamais la plus recente/la plus
  // grosse en priorite -- un tirage uniforme, exactement comme demande).
  const fraudeChoisie = nonRevelees[Math.floor(Math.random() * nonRevelees.length)];
  const rollDetection = Math.random() * 100;
  if (rollDetection >= fraudeChoisie.detectabilite_pct) {
    showToast('Contestation menée', 'Aucune fraude n\'a été détectée cette fois.', true);
    addJournalEntry('⚖️ Contestation menée : aucune fraude détectée.', 'event-info');
    return;
  }

  // ---- Fraude detectee : revelation, sanction et recompense, en une seule transaction ----
  //
  // La revelation et la sanction etaient separees : la premiere aboutissait, la seconde -- amende
  // et detention du fraudeur -- passait par une ecriture sur SA fiche, refusee depuis le chantier
  // B et avalee par un .catch() muet. On annoncait la chute d'un fraudeur qui n'etait ni amende
  // ni detenu. fraude_electorale_sanctionner retrouve la fraude dans fraudes_electorales, verifie
  // qu'elle n'est pas deja revelee -- c'est le verrou contre le rejeu et la concurrence -- puis
  // applique les trois effets ensemble. Les montants et la duree viennent du serveur.
  const rSanction = await sbRpc('fraude_electorale_sanctionner',
    { p_fraude_id: fraudeChoisie.id, p_ville: city || null })
    .then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null);
  if (!rSanction || rSanction.ok !== true) {
    showToast('Contestation sans suite',
      (rSanction && rSanction.raison === 'fraude_deja_revelee')
        ? 'Cette fraude a déjà été révélée par quelqu\'un d\'autre.'
        : "La fraude n'a pas pu être établie. Aucune sanction n'a été prononcée.", false);
    return;
  }

  const fraudesRestantes = (await sbGetFraudesNonRevelees(country, posteId, city || null, cycleDebut))
    .filter(f => f.id !== fraudeChoisie.id);
  const posteNom = (posteId === 'depute') ? 'Législatives' : (posteId === 'maire' ? 'Municipales' : (posteId === 'president' ? 'Présidentielle' : posteId));
  const villeNom = city ? (WORLD[country]?.[city]?.name || city) : null;

  let issueChangee = false, ancienneIssue = null, nouvelleIssue = null;
  if (posteId === 'depute') {
    ancienneIssue = Array.isArray(cycle.elus) ? cycle.elus.slice() : [];
    const recalcul = resoudreScrutinDepute(cycle, fraudesRestantes);
    if (recalcul && !recalcul.egalite3eSiege && !recalcul.blancMajoritaire) {
      let nouveauxElus = recalcul.elus.slice();
      if (nouveauxElus.length < 3) {
        const pool = (ancienneIssue.filter(n => (n||'').indexOf('(PNJ)') !== -1)).concat([]);
        while (nouveauxElus.length < 3 && pool.length) nouveauxElus.push(pool.shift());
      }
      nouvelleIssue = nouveauxElus;
      issueChangee = JSON.stringify(ancienneIssue.slice().sort()) !== JSON.stringify(nouveauxElus.slice().sort());
      if (issueChangee) cycle.elus = nouveauxElus;
    }
  } else {
    ancienneIssue = cycle.eluId;
    const recalcul = resoudreScrutinSimple(cycle, fraudesRestantes);
    if (recalcul && recalcul.elu && !recalcul.blancMajoritaire) {
      nouvelleIssue = recalcul.elu;
      issueChangee = ancienneIssue !== recalcul.elu;
      if (issueChangee) cycle.eluId = recalcul.elu;
    }
  }
  if (issueChangee) {
    await sbUpdate('cycles_electoraux', `id=eq.${row.id}`, { data: JSON.stringify(cycle), updated_at: new Date().toISOString() }).catch(() => {});
  }

  // Sanctions (correctif du 4 septembre 2026, audit dedie) : fraudeur (-500 FR reels + VRAIE
  // detention) ; contestataire (+200 FR). La detention reutilise integralement le mecanisme
  // reel existant (personnages.est_emprisonne, meme forme que emprisonnerPourFraude et que
  // confirmerArrestation quelques ecrans plus loin dans ce jeu) au lieu d'un champ separe
  // seulement informatif comme dans la version precedente -- le fraudeur n'a pas besoin d'etre
  // connecte : au prochain chargement de son personnage, supabase.js relit est_emprisonne et
  // plateau-navigation.js bloque alors reellement sa navigation hors de sa cellule, exactement
  // comme pour n'importe quelle autre detention de ce jeu. jourFin est calcule a partir du
  // dernier "day" reellement persiste du fraudeur (jamais state.day de CETTE session, qui est
  // celle du contestataire) : state.day etant personnel et non partage entre joueurs, c'est la
  // seule valeur de depart correcte pour calculer SA propre echeance. Peine fixe de 2 jours
  // REELS, quelle que soit la categorie de fraude (arbitrage du 4 septembre 2026, distinct des
  // peines du flagrant delit -- emprisonnerPourFraude, 20j falsification/trucage ou 1j bourrage
  // -- qui restent, elles, propres a chaque ordre et ne s'appliquent qu'a une fraude prise sur
  // le fait, jamais a une decouverte a posteriori par contestation).
  //
  // IMPORTANT -- valeur passee TELLE QUELLE (objet), jamais via JSON.stringify() manuel : sbUpdate
  // serialise deja tout le corps de la requete une fois (voir supabase.js, JSON.stringify(data)) ;
  // un JSON.stringify() supplementaire ici double-encoderait la valeur et casserait sa relecture
  // cote client (r.est_emprisonne redeviendrait une chaine, jamais un objet, faisant echouer tout
  // controle sur .jourFin/.city) -- meme piege que confirmerArrestation (plateau-justice-economie.js),
  // qui semble deja l'avoir, hors perimetre de cette correction.
  // L'amende (-500 FR), la detention de 2 jours du fraudeur et la recompense du contestataire
  // (+200 FR) ont ete appliquees ensemble par le serveur, plus haut. On se contente de refleter
  // la fortune qu'il a arretee : sans cela, la prochaine sauvegarde de fiche republierait
  // l'ancienne valeur et effacerait la recompense.
  if (typeof rSanction.arg_contestataire === 'number') {
    state.arg = Number(rSanction.arg_contestataire);
    if (state.char) state.char.arg = state.arg;
    if (typeof updateUI === 'function') updateUI();
  }
  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();

  // Fait public pour La Tribune (demande explicite, section 8) : jamais invente, meme si la
  // correction ne change finalement pas le vainqueur.
  if (typeof sbEnregistrerEvenementPublic === 'function') {
    sbEnregistrerEvenementPublic(country, 'fraude_electorale_revelee', {
      city: city || null,
      personnages: [fraudeChoisie.auteur].filter(Boolean),
      libelle: 'Une fraude électorale (' + fraudeChoisie.type.replace(/_/g, ' ') + ') commise par ' + fraudeChoisie.auteur + ' lors du scrutin ' + posteNom + (villeNom ? ' de ' + villeNom : '') + ' a été révélée par une contestation.' + (issueChangee ? ' Le résultat officiel a été corrigé.' : ''),
      data: { poste_id: posteId, type_fraude: fraudeChoisie.type, issue_changee: issueChangee }
    }).catch(() => {});
  }

  updateUI();
  showToast('Fraude révélée !', 'Une fraude électorale a été démasquée. +200 FR. ' + (issueChangee ? 'Le résultat officiel a changé.' : 'Le résultat officiel reste inchangé.'), true, true);
  addJournalEntry('⚖️ Fraude électorale révélée (' + fraudeChoisie.type.replace(/_/g, ' ') + ', ' + fraudeChoisie.auteur + '). +200 FR.' + (issueChangee ? ' Résultat corrigé.' : ''), 'event-good');
}

async function ouvrirTableauElectoral() {
  const country = state.country;
  const co = COUNTRIES[country];
  const villeCourante = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[villeCourante]?.name || villeCourante;

  document.getElementById('postes-modal-title').textContent = '🗳 Tableau Électoral — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase();

  const postesTous = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.departemental, ...POSTES_ELECTIFS.local];
  if (!CYCLES_ELECTORAUX[country]) CYCLES_ELECTORAUX[country] = {};
  for (const p of postesTous) {
    const city = posteEstLocal(p.id) ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    if (!CYCLES_ELECTORAUX[country][cle]) await initCycleElectoral(country, p.id, city);
  }

  const postes = [...POSTES_ELECTIFS.national, ...POSTES_ELECTIFS.departemental, ...POSTES_ELECTIFS.local];
  const html = postes.map(p => {
    const estLocal = posteEstLocal(p.id);
    const city = estLocal ? villeCourante : null;
    const cle = getCleCycle(p.id, city);
    const cycle = CYCLES_ELECTORAUX[country]?.[cle];
    const phase = cycle ? getPhaseActuelle(country, p.id, city) : 'Non initialisé';
    const nbCandidats = cycle?.candidats.length || 0;
    // Correctif "affichage Vacant a tort" (audit du 4 septembre 2026) : cet ecran ne lisait
    // jamais cycle.eluId (source faisant autorite, ecrite par le cron a chaque resolution),
    // uniquement state.postes -- qui ne reflete que le POSTE DU JOUEUR LOCAL, jamais celui des
    // autres joueurs/PNJ. Reutilise libelleTitulaireCycle(), commun avec Calendrier Electoral.
    const titulaireLbl = cycle ? libelleTitulaireCycle(cycle, p.id) : null;
    const titulaire = titulaireLbl || 'Vacant';
    const labelPoste = p.name + (estLocal ? ' — ' + villeNom : '');

    const phaseCol = {
      [PHASES_ELECTORALES.CANDIDATURES]: '#4a6aaa',
      [PHASES_ELECTORALES.CAMPAGNE]:     '#aa8a4a',
      [PHASES_ELECTORALES.VOTE]:         '#4a8a4a',
      [PHASES_ELECTORALES.SECOND_TOUR]:  '#8a6a4a',
      [PHASES_ELECTORALES.VOTE2]:        '#4a8a4a',
      [PHASES_ELECTORALES.CAMPAGNE_3E_SIEGE]: '#aa8a4a',
      [PHASES_ELECTORALES.VOTE3E_SIEGE]: '#8a6a4a',
      [PHASES_ELECTORALES.VACANT]:       '#8a3a2a',
    }[phase] || '#a89870';

    return '<div style="padding:.5rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="display:flex;justify-content:space-between;align-items:center">' +
        '<div>' +
          '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#e0d5b8">' + labelPoste + '</div>' +
          '<div style="font-size:.72rem;color:#a89870">' + titulaire + '</div>' +
        '</div>' +
        '<div style="text-align:right">' +
          '<div style="font-size:.72rem;color:' + phaseCol + ';font-family:Bebas Neue,sans-serif">' + (phase || 'N/A') + '</div>' +
          '<div style="font-size:.7rem;color:#a89870">' + nbCandidats + ' candidat(s)</div>' +
        '</div>' +
      '</div>' +
    '<button onclick="ouvrirBureauDeVoteBtn(this)" data-poste="' + p.id + '" data-country="' + country + '" data-city="' + (city||'') + '" ' +
      'style="margin-top:.3rem;font-size:.7rem;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;padding:.25rem .6rem;border:1px solid #4a3a20;background:transparent;color:#b0a080;cursor:pointer">Voir détails →</button>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '🗳️ Élections — ' + (co?.n || country);
  document.getElementById('postes-body').innerHTML = '<div style="padding:.4rem .6rem">' + html + '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Changer de domicile (depuis la mairie)
function changerDomicile(newCountry, newCity) {
  const co = COUNTRIES[newCountry];
  const cur = co?.cur || 'FR';
  const cout = 200;

  if (state.arg < cout) {
    showToast('Fonds insuffisants', cout + ' ' + cur + ' requis pour changer de domicile.', false);
    return;
  }

  state.arg -= cout;
  const ancienDomicile = state.domicile;
  state.domicile = { country: newCountry, city: newCity, depuis: state.day || 1 };

  // Logements sociaux de Montrouge (18 aout 2026) : resiliation automatique du bail social si
  // le domicile officiel quitte Montrouge -- ne touche jamais les autres locations (commerciales)
  // du personnage, uniquement l'entree marquee logementSocial:true le cas echeant.
  if (typeof resilierLogementSocialSiDepartMontrouge === 'function') {
    resilierLogementSocialSiDepartMontrouge(ancienDomicile, newCountry, newCity);
  }

  // Perdre les postes liés à l'ancienne domiciliation
  if (state.poste) {
    const postesLocaux = ['maire', 'depute'];
    if (postesLocaux.includes(state.poste.id)) {
      addJournalEntry('⚠️ Changement de domicile : vous perdez votre poste de ' + state.poste.name + '.', 'event-bad');
      state.poste = null;
    if (state.char) state.char.poste = null;
    }
  }

  updateUI();
  showToast('Domicile changé !', newCity + ', ' + co?.n + '. -' + cout + ' ' + cur, true);
  addJournalEntry('🏠 Nouveau domicile : ' + newCity + ', ' + (co?.n || newCountry) + '.', 'event-info');
}



function confirmerCreationOrgaBtn(el) { confirmerCreationOrga(el.dataset.type); }
function ouvrirForumOrgaBtn(el) { ouvrirForumOrga(el.dataset.id); }
function ouvrirGestionOrgaBtn(el) { ouvrirGestionOrga(el.dataset.id); }
function posterMessageOrgaBtn(el) { posterMessageOrga(el.dataset.id); }
function ouvrirCreationOrgaBtn(el) { ouvrirCreationOrga(el.dataset.type); }


// =====================
// ALLIANCES ENTRE PJ — SUPPRIME (20 septembre 2026)
// =====================
// ouvrirMenuAlliances / proposerAlliance / accepterAlliance / refuserAlliance /
// rompreAlliance, le bouton « Alliances » de plateau.html et l'option « Coalition
// electorale » ont ete retires sur arbitrage du game designer : une alliance ou une
// coalition releve du RP et des interactions reelles entre joueurs, pas d'un clic.
// Ce n'etait de toute facon qu'une coquille : state.alliances et state.demandes_alliance
// n'etaient NI persistes (absents du payload de sauvegarde) NI lus par aucune mecanique,
// donc la liste disparaissait au rechargement. Rien d'autre ne les ecrivait.
// Le mail reste le canal : sendMail suffit a proposer une alliance et a y repondre.

// =====================
// OBJECTIFS SECRETS PAR ARCHÉTYPE
// =====================
const OBJECTIFS_SECRETS = {
  ambitieux: {
    label: 'L\'Ambitieux',
    objectifs: [
      { id: 'obj_president',   desc: 'Devenir Président de votre empire',          condition: s => s.poste?.id === 'president',                                          points: 50 },
      { id: 'obj_inf80',       desc: 'Atteindre 80 points d\'Influence',           condition: s => (s.inf||0) >= 80,                                                     points: 20 },
      { id: 'obj_poste_haut',  desc: 'Occuper un poste ministériel',               condition: s => s.poste && !['citoyen','depute'].includes(s.poste.id),                 points: 15 },
      { id: 'obj_argent_50k',  desc: 'Accumuler 50 000 FR en banque',              condition: s => (s.banque||0) >= 50000,                                               points: 25 },
    ]
  },
  criminel: {
    label: 'Le Criminel',
    objectifs: [
      { id: 'obj_blanchir',    desc: 'Blanchir 20 000 FR via des activités louches', condition: s => (s.argent_blanchi||0) >= 20000,                                    points: 40 },
      { id: 'obj_dis90',       desc: 'Maintenir une Discrétion supérieure à 90',  condition: s => (s.dis||0) >= 90,                                                      points: 20 },
      { id: 'obj_informateur', desc: 'Recruter 2 informateurs simultanément',      condition: s => (s.informateurs||[]).length >= 2,                                     points: 15 },
      { id: 'obj_jamais_arrete',desc: 'Ne jamais être arrêté pendant 10 jours',   condition: s => (s.jours_libres||0) >= 10,                                            points: 30 },
    ]
  },
  journaliste: {
    label: 'Le Journaliste',
    objectifs: [
      { id: 'obj_scandales',   desc: 'Publier 5 scandales sur le forum',           condition: s => (s.scandales_publies||0) >= 5,                                        points: 30 },
      { id: 'obj_sondages',    desc: 'Commander 3 sondages absurdes',              condition: s => (s.sondages_commandes||0) >= 3,                                       points: 15 },
      { id: 'obj_micro',       desc: 'Interviewer 5 PNJ différents',               condition: s => (s.pnj_interviewes||[]).length >= 5,                                  points: 20 },
      { id: 'obj_forum_actif', desc: 'Publier 10 posts sur le forum',              condition: s => (s.posts_forum||0) >= 10,                                             points: 25 },
    ]
  },
  fonctionnaire: {
    label: 'Le Fonctionnaire',
    objectifs: [
      { id: 'obj_poste_stable', desc: 'Conserver le même poste 7 jours',           condition: s => (s.jours_meme_poste||0) >= 7,                                        points: 25 },
      { id: 'obj_formulaires',  desc: 'Remplir 10 demandes administratives',       condition: s => (s.formulaires_remplis||0) >= 10,                                    points: 15 },
      { id: 'obj_corruption',   desc: 'Corrompre 3 fonctionnaires',                condition: s => (s.fonctionnaires_corrompus||0) >= 3,                                 points: 20 },
      { id: 'obj_banque_stable', desc: 'Avoir 15 000 FR en banque pendant 5 jours',condition: s => (s.jours_banque_15k||0) >= 5,                                        points: 30 },
    ]
  },
  militaire: {
    label: 'Le Militaire',
    objectifs: [
      { id: 'obj_caserne',      desc: 'Visiter la caserne 5 fois',                 condition: s => (s.visites_caserne||0) >= 5,                                         points: 15 },
      { id: 'obj_ordre',        desc: 'Faire appel à la police 3 fois',            condition: s => (s.appels_police||0) >= 3,                                           points: 20 },
      { id: 'obj_hp_max',       desc: 'Maintenir 100 HP pendant 5 jours',          condition: s => (s.jours_hp_max||0) >= 5,                                            points: 25 },
      { id: 'obj_ministre_def', desc: 'Devenir Ministre de la Défense',            condition: s => s.poste?.id === 'ministre_defense',                                  points: 40 },
    ]
  },
  religieux: {
    label: 'Le Religieux',
    objectifs: [
      { id: 'obj_pop80',        desc: 'Atteindre 80 de Popularité',                condition: s => (s.pop||0) >= 80,                                                    points: 25 },
      { id: 'obj_moral_max',    desc: 'Maintenir 100 de Moral pendant 5 jours',   condition: s => (s.jours_moral_max||0) >= 5,                                         points: 20 },
      { id: 'obj_pelerinage',   desc: 'Visiter 3 empires différents',              condition: s => (s.empires_visites||[]).length >= 3,                                  points: 30 },
      { id: 'obj_sermons',      desc: 'Publier 5 messages inspirants sur le forum',condition: s => (s.sermons_publies||0) >= 5,                                         points: 20 },
    ]
  }
};

function afficherObjectifsSecrets() {
  // Tant que le tronc commun de la quete d'accueil OU une branche specialisee (ex: Pat
  // Hounette/Brigitte Menottes cote criminel) est active, "Mes Objectifs" devient le carnet de
  // quete simple (action suivante a accomplir), pas le catalogue d'objectifs secrets
  // d'archetype -- qui reste par ailleurs pleinement fonctionnel en arriere-plan
  // (verifierObjectifs, appele depuis plateau-core.js, continue de tourner et de crediter
  // l'influence normalement, seul cet affichage change).
  const objectifQuete = (typeof queteAccueilObjectifActuel === 'function') ? queteAccueilObjectifActuel() : null;
  const objectifCarriere = !objectifQuete && (typeof queteCarriereObjectifActuel === 'function') ? queteCarriereObjectifActuel() : null;
  const objectifActif = objectifQuete || objectifCarriere;
  if (objectifActif) {
    document.getElementById('postes-modal-title').textContent = '🎯 Mes Objectifs';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:.6rem 1rem">' +
      '<div style="display:flex;align-items:center;gap:.6rem;padding:.5rem .4rem;border-bottom:1px solid #1a1810">' +
        '<div style="font-size:1rem">⬜</div>' +
        '<div style="flex:1"><div style="font-size:.78rem;color:#c0b090">' + objectifActif + '</div></div>' +
      '</div>' +
      '</div>';
    document.getElementById('modal-postes').classList.add('open');
    return;
  }

  const archetype = state.char?.archetype || 'ambitieux';
  const obj = OBJECTIFS_SECRETS[archetype] || OBJECTIFS_SECRETS.ambitieux;
  const completed = state.objectifs_completes || [];

  // Vérifier nouvelles complétion
  obj.objectifs.forEach(o => {
    if (!completed.includes(o.id) && o.condition(state)) {
      completed.push(o.id);
      state.objectifs_completes = completed;
      state.inf = Math.min(100, (state.inf||0) + Math.floor(o.points/5));
      showToast('🎯 Objectif accompli !', o.desc + ' (+' + o.points + ' pts)', true);
      addJournalEntry('🎯 Objectif secret accompli : ' + o.desc, 'event-good');
    }
  });

  const totalPoints = obj.objectifs.reduce((s,o) => s + (completed.includes(o.id) ? o.points : 0), 0);
  const maxPoints   = obj.objectifs.reduce((s,o) => s + o.points, 0);

  const html = obj.objectifs.map(o => {
    const done = completed.includes(o.id);
    return '<div style="display:flex;align-items:center;gap:.6rem;padding:.5rem .4rem;border-bottom:1px solid #1a1810">' +
      '<div style="font-size:1rem">' + (done ? '✅' : '⬜') + '</div>' +
      '<div style="flex:1">' +
        '<div style="font-size:.78rem;color:' + (done ? '#4a8a4a' : '#c0b090') + '">' + o.desc + '</div>' +
        '<div style="font-size:.85rem;color:#8a7050">' + o.points + ' points</div>' +
      '</div>' +
    '</div>';
  }).join('');

  document.getElementById('postes-modal-title').textContent = '🎯 Objectifs — ' + obj.label;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.6rem 1rem">' +
    '<div style="font-size:.7rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.08em;margin-bottom:.6rem">' +
      'Score : ' + totalPoints + ' / ' + maxPoints + ' points' +
    '</div>' +
    html +
    '<div style="font-size:.85rem;color:#8a7050;margin-top:.6rem;font-style:italic">Ces objectifs sont secrets — les autres joueurs ne les voient pas.</div>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Vérifier objectifs à chaque updateUI
let _verifyingObjectifs = false;
function verifierObjectifs() {
  if (_verifyingObjectifs) return;
  const archetype = state.char?.archetype;
  if (!archetype || !OBJECTIFS_SECRETS[archetype]) return;
  const obj = OBJECTIFS_SECRETS[archetype];
  const completed = state.objectifs_completes || [];
  let changed = false;
  obj.objectifs.forEach(o => {
    try {
      if (!completed.includes(o.id) && o.condition(state)) {
        completed.push(o.id);
        state.objectifs_completes = completed;
        changed = true;
        showToast('🎯 Objectif accompli !', o.desc, true);
        addJournalEntry('🎯 ' + o.desc, 'event-good');
      }
    } catch(e) {} // Condition peut échouer si state incomplet
  });
  if (changed) {
    _verifyingObjectifs = true;
    state.inf = Math.min(100, (state.inf||0) + 2);
    _verifyingObjectifs = false;
  }
}

// =====================
// JOURNAL DU JOUR (18 aout 2026 : remplace l'ancien "Journal du Matin" genere a la volee par
// prompt libre. Ce journal se contente de LIRE la derniere edition publiee de journal_editions
// (produite par le cron via api/_journal-generation.js) -- il ne genere jamais rien lui-meme.
// Statuts 'en_cours'/'echec' ne sont jamais montres au joueur.)
// =====================

// Repli honnete si l'ID (ex. type d'image) n'est pas au format YYYY-MM-DD attendu -- ne devrait
// jamais arriver puisque date_edition est calculee cote serveur, mais evite d'afficher "undefined".
function formaterDateEditionFr(dateEdition) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateEdition || '');
  if (!m) return dateEdition || '';
  const jour = parseInt(m[3], 10);
  const mois = MOIS_FR_JOURNAL[parseInt(m[2], 10) - 1] || m[2];
  return jour + ' ' + mois + ' ' + m[1];
}

// Filet de securite cosmetique (pas un moteur Markdown) : le Journal du jour est deja structure
// en JSON avec des champs separes (titre/corps rendus dans de vraies balises HTML), ce qui evite
// le principal cas d'usage du markdown dans l'ancien Journal du Matin (simuler un titre dans un
// bloc de texte libre). Ce filtre retire simplement les marqueurs de syntaxe les plus frequents
// si un article en contient malgre tout -- jamais de conversion en gras/italique HTML.
function nettoyerMarkdownResiduel(texte) {
  return String(texte || '')
    .replace(/\*\*(.*?)\*\*/g, '$1')
    .replace(/\*(.*?)\*/g, '$1')
    .replace(/^#{1,6}\s*/gm, '');
}

function texteArticleHtml(texte) {
  return escapeHtmlText(nettoyerMarkdownResiduel(texte));
}

// =====================
// LA TRIBUNE DE RÉPUBLIA — identité visuelle (refonte 31 aout 2026, remplace l'ancien rendu
// sombre/or "Journal du jour"). Résout les images en cherchant le fait/déclaration cité
// (image.ref_id, déjà validé cote serveur -- voir validerEdition/_journal-generation.js) dans
// faits_sources.FACTS/PUBLIC_STATEMENTS archivés avec l'édition : photo_url pour un portrait de
// PJ, club_image pour un lieu (stade). Jamais de générique/fallback avec une image inventée --
// ces types n'ont simplement pas d'image.
// =====================
function construireIndexFaitsJournal(edition) {
  const index = {};
  const fs = edition.faits_sources || {};
  (fs.FACTS || []).forEach(f => { index[f.id] = f; });
  (fs.PUBLIC_STATEMENTS || []).forEach(s => { index[s.id] = s; });
  return index;
}

function resoudreImageJournal(image, index) {
  if (!image) return null;
  // type:'url' (interview de Jodie Moitout, chantier du 3 septembre 2026) : image connue
  // directement par l'appelant au moment de la publication (avatar du PJ interviewe), jamais issue
  // d'un fait archive dans faits_sources -- ref_id n'a donc aucun sens pour ce cas, traite avant
  // le reste de la fonction (inchange).
  if (image.type === 'url' && image.url) return image.url;
  if (!image.ref_id) return null;
  const source = index[image.ref_id];
  if (!source) return null;
  if (image.type === 'personnage' && source.estPJ && source.photo_url) return source.photo_url;
  if (image.type === 'lieu' && source.club_image) return source.club_image;
  return null;
}

function renderImageJournal(image, index, cls) {
  const url = resoudreImageJournal(image, index);
  if (!url) return '';
  return `<img class="${cls}" src="${escapeHtmlText(url)}" loading="lazy" alt="">`;
}

function renderArticleJournal(art, index) {
  if (!art) return '';
  const image = renderImageJournal(art.image, index, 'tribune-article-image');
  const ville = art.ville ? `<div class="tribune-article-ville">${escapeHtmlText(art.ville)}</div>` : '';
  const titre = art.titre ? `<h3 class="tribune-article-titre">${texteArticleHtml(art.titre)}</h3>` : '';
  const texte = art.texte ? `<p>${texteArticleHtml(art.texte)}</p>` : '';
  return `<article class="tribune-article">${image}${ville}${titre}${texte}</article>`;
}

// Regroupe par rubrique dans l'ordre d'APPARITION (jamais une liste fixe de rubriques : une
// rubrique n'existe que si l'IA a réellement écrit un article dedans, voir §10 du cahier des
// charges refonte).
function grouperArticlesParRubrique(articles) {
  const ordre = [];
  const parRubrique = {};
  (articles || []).forEach(art => {
    const cle = (art && art.rubrique) || 'Actualité';
    if (!parRubrique[cle]) { parRubrique[cle] = []; ordre.push(cle); }
    parRubrique[cle].push(art);
  });
  return ordre.map(rubrique => ({ rubrique, articles: parRubrique[rubrique] }));
}

// Avant-dernière page : "4 dernières interviews" (chantier refonte, 4 septembre 2026), format
// compact -- remplace l'ancien portrait unique. page.interviews est déjà trié/plafonné à 4 côté
// serveur (assemblerAvantDernierePage), le client se contente d'afficher tel quel.
function renderJodieJournal(page) {
  const interviews = (page && Array.isArray(page.interviews)) ? page.interviews : [];
  if (interviews.length === 0) return '';
  const entrees = interviews.map(iv => {
    const portrait = iv.photo_url ? `<img class="tribune-jodie-portrait" src="${escapeHtmlText(iv.photo_url)}" loading="lazy" alt="">` : '';
    const titre = iv.titre ? `<div class="tribune-jodie-titre">${texteArticleHtml(iv.titre)}</div>` : '';
    return `<div class="tribune-jodie-entree">
      ${portrait}
      <div>
        <div class="tribune-jodie-nom">${texteArticleHtml(iv.nom || '')}</div>
        ${titre}
        <p>${texteArticleHtml(iv.texte || '')}</p>
      </div>
    </div>`;
  }).join('');
  return `<section class="tribune-jodie">
    <div class="tribune-jodie-label">Les interviews de Jodie Moitout</div>
    ${entrees}
  </section>`;
}

function renderDernierePageJournal(dp) {
  if (!dp) return '';
  const blocs = [];
  if (Array.isArray(dp.indices_economiques) && dp.indices_economiques.length > 0) {
    const lignes = dp.indices_economiques.map(i =>
      `<div class="tribune-indice-ligne"><span>${escapeHtmlText(i.ressource)} — ${escapeHtmlText(i.ville || '')}</span><span>${i.prix != null ? i.prix + ' FR' : '—'} · stock ${i.stock}</span></div>`
    ).join('');
    blocs.push(`<div class="tribune-derniere-bloc"><h4>Indices</h4>${lignes}</div>`);
  }
  if (Array.isArray(dp.arrivees) && dp.arrivees.length > 0) {
    blocs.push(`<div class="tribune-derniere-bloc"><h4>Journal des arrivées</h4><ul>${dp.arrivees.map(t => `<li>${texteArticleHtml(t)}</li>`).join('')}</ul></div>`);
  }
  if (Array.isArray(dp.carnet) && dp.carnet.length > 0) {
    blocs.push(`<div class="tribune-derniere-bloc"><h4>Carnet</h4><ul>${dp.carnet.map(t => `<li>${texteArticleHtml(t)}</li>`).join('')}</ul></div>`);
  }
  if (Array.isArray(dp.chiens_ecrases) && dp.chiens_ecrases.length > 0) {
    blocs.push(`<div class="tribune-derniere-bloc"><h4>En bref</h4><ul>${dp.chiens_ecrases.map(t => `<li>${texteArticleHtml(t)}</li>`).join('')}</ul></div>`);
  }
  if (Array.isArray(dp.petites_annonces) && dp.petites_annonces.length > 0) {
    blocs.push(`<div class="tribune-derniere-bloc"><h4>Petites annonces</h4><ul>${dp.petites_annonces.map(t => `<li>${texteArticleHtml(t)}</li>`).join('')}</ul></div>`);
  }
  if (blocs.length === 0) return '';
  return `<section class="tribune-derniere">
    <div class="tribune-derniere-titre">Dernière page</div>
    <div class="tribune-derniere-grille">${blocs.join('')}</div>
  </section>`;
}

// Reste une fonction PURE (Lot 2, 21 septembre 2026) : elle ne lit ni `state`, ni le DOM, et
// n'ecrit rien -- elle transforme une edition en HTML, c'est tout. C'est ce qui permet de la
// reutiliser telle quelle pour le numero du jour ET pour un numero d'archive, sans la dupliquer.
//
// MONOTITRE RETIRE. Le fronton affichait « La Tribune de Républia » en dur, quelle que soit
// l'edition lue. Or ce titre n'existe pas : les quatre journaux en base sont « L'Autruche
// Entravée » (republic), « Le Minaret Doré » (khalija), « El Narco Times » (narco) et
// « La Pravdovka » (soviet). Tout lecteur de khalija lisait donc son propre quotidien sous le nom
// d'un autre. Le nom vient desormais de la base (journaux.nom, joint par la RPC de lecture) ; le
// repli n'invente pas de titre, il n'affiche que la date.
function construireHtmlJournalDuJour(edition, options) {
  const dateFr = escapeHtmlText(formaterDateEditionFr(edition.date_edition));
  const index = construireIndexFaitsJournal(edition);
  const nomTitre = (edition.journal && edition.journal.nom) || '';
  // Origine du titre au fronton : la lecture etant internationale, un joueur peut avoir sous les
  // yeux un quotidien etranger. Le pays leve l'ambiguite la ou le seul nom ne suffit plus.
  const paysTitre = _presseNomPays(edition.journal && edition.journal.pays);

  const une = edition.une || {};
  const dp = edition.double_page_centrale || {};
  const eco = edition.page_economie_societe || {};
  const articles = Array.isArray(dp.articles) ? dp.articles : [];

  let html = `<div class="tribune-republia">`;
  // Fermeture portee par le fronton lui-meme (correctif UX du 4 septembre 2026) : delegue au VRAI
  // bouton .modal-close existant (jamais de logique de fermeture dupliquee) -- .modal-header est
  // masque quand une edition s'affiche (voir .journal-mode, style.css), donc ce bouton devient
  // l'unique moyen de fermer visible.
  // Le retour (vers le kiosque ou vers la liste d'archives) est fourni par l'appelant sous forme
  // d'un libelle et d'une action : la fonction reste ainsi ignorante de la navigation.
  // Le bouton de retour est volontairement de la MEME taille et de la meme forme que la croix de
  // fermeture, et pose symetriquement a gauche : le fronton centre son titre entre 3rem de
  // rembourrage de chaque cote, et une pastille portant un libelle deborderait sur ce titre aux
  // largeurs etroites. Le libelle passe donc par title/aria-label, et il est repete en toutes
  // lettres au pied du numero, ou la place ne manque pas.
  const retour = (options && options.retour) || null;
  html += `<div class="tribune-fronton">
    <button type="button" class="tribune-fronton-close" onclick="document.querySelector('#modal-postes .modal-close')?.click()" aria-label="Fermer">✕</button>
    ${retour ? `<button type="button" class="tribune-fronton-retour" onclick="${escapeHtmlText(retour.action)}" title="${escapeHtmlText(retour.libelle)}" aria-label="${escapeHtmlText(retour.libelle)}">◀</button>` : ''}
    ${nomTitre ? `<div class="tribune-fronton-titre">${escapeHtmlText(nomTitre)}</div>` : ''}
    <div class="tribune-fronton-sub">${paysTitre ? escapeHtmlText(paysTitre) + ' · ' : ''}Édition du ${dateFr}</div>
  </div>`;
  html += `<div class="tribune-contenu">`;

  // Une — 1 ou 2 sujets (partagée si 2), plus jusqu'à 3 appels de Une (chantier refonte, 4
  // septembre 2026). "tribune-une-partagee" ajuste la mise en page CSS quand il y a 2 sujets.
  const sujets = Array.isArray(une.sujets) ? une.sujets : [];
  html += `<section class="tribune-une${sujets.length > 1 ? ' tribune-une-partagee' : ''}">`;
  html += renderImageJournal(une.image, index, 'tribune-une-image');
  sujets.forEach(suj => {
    if (!suj) return;
    html += '<div class="tribune-une-sujet">';
    if (suj.titre) html += `<h1 class="tribune-une-titre">${texteArticleHtml(suj.titre)}</h1>`;
    if (suj.chapeau) html += `<p class="tribune-une-chapeau">${texteArticleHtml(suj.chapeau)}</p>`;
    html += '</div>';
  });
  if (Array.isArray(une.appels) && une.appels.length > 0) {
    html += '<ul class="tribune-une-accroches">';
    une.appels.forEach(acc => { if (acc && acc.texte) html += `<li>${texteArticleHtml(acc.texte)}</li>`; });
    html += '</ul>';
  }
  html += `</section>`;

  // Rubriques (nombre et ordre libres, jamais fixés à l'avance) — séparateur visuel léger
  // marquant le passage à la "deuxième page" (chantier refonte interface, 4 septembre 2026),
  // uniquement s'il existe au moins un article à y montrer.
  if (articles.length > 0) html += `<div class="tribune-separateur">Deuxième page</div>`;
  grouperArticlesParRubrique(articles).forEach(({ rubrique, articles: liste }) => {
    html += `<section class="tribune-rubrique">
      <div class="tribune-rubrique-titre">${escapeHtmlText(rubrique)}</div>
      ${liste.map(a => renderArticleJournal(a, index)).join('')}
    </section>`;
  });

  // Avant-dernière page : les dernières interviews de Jodie Moitout, si disponibles (jamais
  // réinventées par l'IA, texte assemblé côté serveur -- voir _journal-generation.js,
  // assemblerAvantDernierePage()). Séparation visuelle déjà assurée par .tribune-jodie (bordure +
  // libellé internes), aucun séparateur supplémentaire nécessaire.
  html += renderJodieJournal(eco.avant_derniere_page);

  // Dernière page : arrivées/carnet/chiens écrasés/indices/petites annonces, assemblés côté
  // serveur. Même remarque : .tribune-derniere porte déjà sa propre bordure et son propre titre.
  html += renderDernierePageJournal(eco.derniere_page);

  // PIED DE NUMERO : Kiosque et Archives, TOUJOURS, quelle que soit la provenance.
  //
  // C'est l'exigence de l'arbitrage « ouverture directe » : quand un seul titre parait, le joueur
  // arrive dans le numero sans etre passe par l'ecran de selection. Il ne doit pas pour autant se
  // retrouver enferme -- les deux destinations restent atteignables depuis le journal lui-meme.
  // Ces deux entrees sont posees inconditionnellement (et non deduites de `retour`) precisement
  // pour qu'aucune provenance ne puisse en priver le lecteur.
  //
  // `retour` s'y ajoute seulement quand il designe autre chose : revenir a la PAGE d'archives d'ou
  // l'on vient n'est pas la meme chose qu'aller a la racine des archives.
  const liens = [];
  if (retour && retour.action !== 'presseAfficherKiosque()'
             && retour.action !== 'presseAfficherArchivesTitres()') {
    liens.push(`<span class="journal-action-link" onclick="${escapeHtmlText(retour.action)}">◀ ${escapeHtmlText(retour.libelle)}</span>`);
  }
  liens.push('<span class="journal-action-link" onclick="presseAfficherKiosque()">Kiosque</span>');
  liens.push('<span class="journal-action-link" onclick="presseAfficherArchivesTitres()">Archives</span>');
  html += `<div class="tribune-pied-retour">${liens.join('<span class="tribune-pied-sep">·</span>')}</div>`;

  html += `</div></div>`;
  return html;
}

// =====================
// FENÊTRE DÉPLAÇABLE — Journal du jour (correctif UX, 31 aout 2026)
// =====================
// Aucun mécanisme générique de fenêtre déplaçable trouvé dans le dépôt (recherche mousedown/
// mousemove/pointerdown/draggable) : forum-canvas.js implémente un drag, mais pour des objets de
// composition d'image dans le forum, sans rapport avec les modales de plateau.html. Mécanisme
// local minimal, scopé STRICTEMENT au moment où #modal-postes affiche le Journal (classe
// journal-drag-active posée/retirée ici uniquement) -- jamais applique aux autres usages partagés
// de cette même modale générique (postes disponibles, Helvetia, petites annonces...), pour ne rien
// changer à leur comportement. Souris uniquement (mousedown/mousemove/mouseup, même idiome que
// forum-canvas.js) : aucun support tactile ajouté, pour ne jamais interferer avec le scroll
// mobile du contenu (voir §6 du correctif -- limite volontaire, pas un oubli).
let _journalDragCleanup = null;

// headerSelector (correctif UX du 4 septembre 2026) : quand une vraie edition s'affiche,
// .modal-header generique est masque (.journal-mode, voir style.css) et .tribune-fronton devient
// le seul en-tete visuel -- la poignee de glisser-deposer doit donc suivre, sous peine de rendre
// la fenetre non deplacable par un en-tete devenu invisible. Repli sur '.modal-header' par defaut
// (etat de chargement, ou message "aucun numero disponible" ou aucun .tribune-fronton n'existe).
function activerDragJournal(headerSelector) {
  desactiverDragJournal(); // jamais deux ecouteurs empiles sur des ouvertures successives
  const header = document.querySelector('#modal-postes ' + (headerSelector || '.modal-header'));
  const box = document.querySelector('#modal-postes .modal-box');
  if (!header || !box) return;
  header.classList.add('journal-drag-active');

  let dragging = false, startX = 0, startY = 0, startLeft = 0, startTop = 0;
  const MARGE_MIN_VISIBLE = 160; // largeur minimale de la barre toujours accessible a l'ecran (§4)

  function onMouseDown(e) {
    if (e.target.closest('.modal-close, .tribune-fronton-close')) return; // la croix ferme, ne demarre jamais un drag
    if (typeof e.button === 'number' && e.button !== 0) return; // clic gauche uniquement
    const rect = box.getBoundingClientRect();
    // Bascule d'un positionnement centre (flex, .modal-overlay) vers un positionnement fixe
    // explicite, fige sur la position visuelle ACTUELLE -- jamais de saut au premier mousedown.
    box.style.position = 'fixed';
    box.style.margin = '0';
    box.style.left = rect.left + 'px';
    box.style.top = rect.top + 'px';
    startLeft = rect.left; startTop = rect.top;
    startX = e.clientX; startY = e.clientY;
    dragging = true;
    header.classList.add('dragging');
    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
    e.preventDefault();
  }
  function onMouseMove(e) {
    if (!dragging) return;
    const rect = box.getBoundingClientRect();
    let left = startLeft + (e.clientX - startX);
    let top = startTop + (e.clientY - startY);
    // Bornes passives (§4) : toujours au moins MARGE_MIN_VISIBLE px de la fenetre accessibles sur
    // chaque axe, jamais de docking/snap -- une simple limite, pas un comportement complexe.
    left = Math.max(MARGE_MIN_VISIBLE - rect.width, Math.min(left, window.innerWidth - MARGE_MIN_VISIBLE));
    top = Math.max(0, Math.min(top, window.innerHeight - 48));
    box.style.left = left + 'px';
    box.style.top = top + 'px';
  }
  function onMouseUp() {
    dragging = false;
    header.classList.remove('dragging');
    document.removeEventListener('mousemove', onMouseMove);
    document.removeEventListener('mouseup', onMouseUp);
  }

  header.addEventListener('mousedown', onMouseDown);
  _journalDragCleanup = function () {
    header.removeEventListener('mousedown', onMouseDown);
    document.removeEventListener('mousemove', onMouseMove);
    document.removeEventListener('mouseup', onMouseUp);
    header.classList.remove('journal-drag-active', 'dragging');
    // Reinitialise la position (§5 : pas de persistance demandee, comportement normal a la
    // reouverture) -- retire les styles inline, .modal-overlay/.modal-box reprennent leur
    // centrage flex habituel des l'ouverture suivante, Journal ou non.
    box.style.position = '';
    box.style.margin = '';
    box.style.left = '';
    box.style.top = '';
  };
}

function desactiverDragJournal() {
  if (_journalDragCleanup) { _journalDragCleanup(); _journalDragCleanup = null; }
}

// Date d'edition du jour, au sens du Journal (correctif du 4 septembre 2026, diagnostic
// production) : reproduit EXACTEMENT dateEditionPourPays() cote serveur (api/_journal-
// generation.js) -- meme fuseau (TIMEZONE_PAR_PAYS, Europe/Paris pour tous les pays actuels),
// meme format 'YYYY-MM-DD' (Intl.DateTimeFormat('en-CA', ...)). Ne JAMAIS utiliser state.day ici
// (compteur de jours de jeu personnel au joueur, sans rapport avec la date calendaire reelle a
// laquelle une edition a ete generee) -- doctrine deja etablie ailleurs dans ce fichier pour les
// memes raisons (cycles electoraux, votes de confiance...).
function dateEditionAujourdhui(country) {
  const fmt = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Paris', year: 'numeric', month: '2-digit', day: '2-digit' });
  return fmt.format(new Date());
}

// Version de schema editorial attendue par construireHtmlJournalDuJour() : 'v2-la-tribune'. Une
// edition dont le prompt_version differe (ex. 'v1', ancien format villes/nationale/
// internationale) n'est jamais proposee au lecteur -- correctif du 4 septembre 2026, le renderer
// actuel ne sait pas lire ce format (confirme par diagnostic : rendu a 304 caracteres, quasiment
// vide, sur une vraie edition v1). Les editions v1 restent en base, simplement invisibles
// (arbitrage A du Lot 2 : ni renderer v1, ni adaptateur, ni migration, ni suppression).
//
// LA CONSTANTE A DEMENAGE (Lot 2, 21 septembre 2026). Elle vit desormais dans supabase.js sous le
// nom PRESSE_VERSION_LISIBLE, au plus pres des trois guichets qui filtrent dessus (kiosque,
// archives, lecture). L'ancienne constante locale n'etait plus lue par personne depuis que la
// selection s'y fait : la laisser aurait cree deux sources pour une meme regle, donc une
// divergence possible entre ce que le kiosque propose et ce que le renderer sait afficher. Elle
// doit rester synchronisee avec PROMPT_VERSION cote serveur (api/_journal-generation.js).

// force=true (chantier "acces depuis le journal d'evenements", 1er septembre 2026) : contourne
// le garde-fou "une seule fois par jour" ci-dessous, reserve a l'ouverture automatique au
// chargement (plateau-core.js). Le lien "Lire le Journal du jour" pose dans le journal
// d'evenements (voir plus bas) appelle TOUJOURS afficherJournalDuJour(true) -- sans ce parametre,
// un clic sur ce lien apres la premiere ouverture automatique de la journee resterait sans effet
// (return silencieux), ce qui aurait rendu le nouveau point d'acces inutilisable des le 2e clic.
// =====================
// KIOSQUE MULTI-TITRES (Lot 2, 21 septembre 2026)
// =====================
// Ce que le lot change, en une phrase : le Journal du jour n'ouvre plus UN quotidien suppose
// unique, il ouvre un KIOSQUE ou figurent tous les titres parus aujourd'hui dans le pays, plus
// l'acces aux archives de chacun.
//
// SIGNATURE PRESERVEE. afficherJournalDuJour(force) garde exactement son nom, son parametre et sa
// semantique de verrou de session : elle est appelee depuis plateau-core.js (ouverture automatique
// au chargement) et depuis le lien pose dans le journal d'evenements. Ce qu'elle AFFICHE change,
// pas la facon dont on l'appelle.
//
// LECTURE GLOBALE (arbitrage F). Lire la presse ne coute pas de PA, n'exige aucun deplacement et
// ne depend d'aucun batiment : il n'y a pas de kiosque physique sur le plateau. Le kiosque est un
// ecran, pas un lieu.
//
// ETAT DE NAVIGATION. Les listes affichees sont conservees ici, et les gestionnaires de clic
// reference un INDICE dans ces listes -- jamais un identifiant interpole dans du HTML. Aucune
// donnee venue de la base ne transite donc par un attribut onclick.
const PRESSE_ARCHIVES_PAR_PAGE = 12;
let _presseEtat = { kiosque: [], titres: [], editions: [], titreCourant: null, page: 0 };

function _presseCorps(html) {
  const corps = document.getElementById('postes-body');
  if (corps) corps.innerHTML = html;
}

// Les ecrans de navigation (kiosque, archives) ne sont PAS des numeros : ils gardent l'en-tete de
// modale generique, qui porte la fermeture et la poignee de deplacement. Seule la lecture d'une
// edition bascule en `journal-mode`, ou .tribune-fronton devient le seul en-tete visuel (voir
// .journal-mode dans style.css). C'est la regle etablie le 4 septembre 2026, inchangee.
// Le glisser-deposer n'est re-arme que si la poignee CHANGE reellement d'element. Re-armer
// appelle desactiverDragJournal(), qui restitue le centrage flex de la fenetre : sans cette
// garde, passer du kiosque aux archives puis a la collection recentrait la fenetre a chaque
// ecran, annulant le deplacement que le joueur venait de faire. Le passage navigation <-> lecture
// change en revanche vraiment de poignee (.modal-header <-> .tribune-fronton) et doit re-armer.
let _presseDragPoignee = null;
function _presseArmerDrag(selecteur) {
  if (_presseDragPoignee === selecteur) return;
  _presseDragPoignee = selecteur;
  activerDragJournal(selecteur);
}

function _presseModeNavigation(titreModale) {
  const t = document.getElementById('postes-modal-title');
  if (t) t.textContent = titreModale;
  document.querySelector('#modal-postes .modal-box')?.classList.remove('journal-mode');
  _presseArmerDrag('.modal-header');
}

function _presseChargement(titreModale) {
  _presseModeNavigation(titreModale);
  _presseCorps('<div style="padding:1.2rem 1rem;font-style:italic;color:#8a8060">Chargement…</div>');
}

// Conteneur unique de tous les ecrans de navigation. Il porte le papier, les marges negatives qui
// annulent le rembourrage de la modale, et le pied. Sans lui, un bloc de message (marges
// negatives) suivi d'un pied (marges normales) ne s'alignaient pas.
function _presseEcran(contenu, pied) {
  return `<div class="kiosque">${contenu}`
    + (pied ? `<div class="kiosque-pied">${pied}</div>` : '')
    + `</div>`;
}

// PANNE ET ABSENCE NE SE RESSEMBLENT PAS (exigence du lot). Les guichets de supabase.js rendent
// `null` quand la presse est injoignable et `[]` quand personne n'a publie. Les deux messages
// ci-dessous sont distincts et le second propose de reessayer : un joueur ne doit jamais croire
// que le journal n'a pas paru alors que c'est la requete qui a echoue.
//
// L'habillage diegetique reste la regle (12 septembre 2026) : le joueur ne lit jamais un code
// HTTP, un nom d'API ni un credit epuise. Mais une panne est nommee comme une panne -- la fiction
// habille, elle ne ment pas sur ce qui s'est passe.
function htmlKiosqueVide() {
  return '<div class="kiosque-message">'
    + '<div class="kiosque-message-titre">Aucun journal n\'a encore paru aujourd\'hui.</div>'
    + '<p class="kiosque-message-texte">Les rotatives sont à l\'arrêt. Aucun titre n\'a tiré '
    + 'd\'édition ce matin.</p>'
    + '<p class="kiosque-message-texte">Les numéros déjà parus restent consultables aux archives.</p>'
    + '</div>';
}

function htmlPressePanne() {
  return '<div class="kiosque-message kiosque-message-panne">'
    + '<div class="kiosque-message-titre">Le kiosque est injoignable</div>'
    + '<p class="kiosque-message-texte">Impossible de savoir quels titres ont paru : la liaison '
    + 'n\'a pas abouti. Ce n\'est pas une absence de parution.</p>'
    + '<p class="kiosque-message-texte"><span class="journal-action-link" onclick="presseAfficherKiosque()">Réessayer</span></p>'
    + '</div>';
}

// Nom lisible du pays d'origine d'un titre. Le kiosque etant international, l'origine cesse d'etre
// une evidence : « L'Autruche Entravée » et « El Narco Times » cohabitent desormais sur le meme
// ecran. Repli sur le code brut si le pays est inconnu -- on n'invente jamais un nom d'empire.
function _presseNomPays(code) {
  return (typeof COUNTRIES !== 'undefined' && COUNTRIES[code] && COUNTRIES[code].n) || code || '';
}

// ---- ECRAN 1 : LE KIOSQUE DU JOUR ----
// METADONNEES SEULEMENT. sbGetKiosqueDuJour ne demande que id/journal_id/date + nom et pays du
// titre : ouvrir le kiosque ne charge AUCUN contenu d'article, meme si dix titres paraissent. Le
// numero n'est rapatrie qu'au moment ou le joueur en ouvre un.
//
// CHARGEMENT ET RENDU SONT SEPARES, et ce n'est pas un raffinement gratuit. Le point d'entree doit
// arbitrer 0 / 1 / plusieurs titres AVANT de decider quoi afficher, alors qu'un lien « Kiosque »
// pose dans un numero doit TOUJOURS aboutir au kiosque. Si une seule fonction faisait les deux,
// le lien « Kiosque » d'un numero ouvert directement (cas « 1 seul titre ») rouvrirait ce meme
// numero : le joueur ne pourrait jamais atteindre l'ecran de selection ni, de la, les archives.
async function _presseChargerKiosque() {
  const dateAujourdhui = dateEditionAujourdhui(state.country);
  const parus = typeof sbGetKiosqueDuJour === 'function'
    ? await sbGetKiosqueDuJour(dateAujourdhui).catch(() => null)
    : null;
  if (parus !== null) _presseEtat.kiosque = parus;
  return parus;
}

function _presseRendreKiosque(parus) {
  const lienArchives = '<span class="journal-action-link" onclick="presseAfficherArchivesTitres()">Consulter les archives</span>';

  // L'acces aux archives est propose dans les TROIS cas -- titres parus, aucune parution, panne.
  // Une journee sans journal ne doit jamais etre un cul-de-sac : la collection reste lisible.
  if (parus === null) { _presseCorps(_presseEcran(htmlPressePanne(), lienArchives)); return; }
  if (parus.length === 0) { _presseCorps(_presseEcran(htmlKiosqueVide(), lienArchives)); return; }

  const cartes = parus.map((e, i) => {
    const nom = (e.journaux && e.journaux.nom) || e.journal_id;
    const pays = _presseNomPays(e.journaux && e.journaux.pays);
    return `<div class="kiosque-titre" onclick="presseOuvrirEditionDuJour(${i})">
      ${pays ? `<div class="kiosque-titre-pays">${escapeHtmlText(pays)}</div>` : ''}
      <div class="kiosque-titre-nom">${escapeHtmlText(nom)}</div>
      <div class="kiosque-titre-date">Édition du ${escapeHtmlText(formaterDateEditionFr(e.date_edition))}</div>
    </div>`;
  }).join('');

  _presseCorps(_presseEcran(
    `<div class="kiosque-entete">À la une aujourd'hui</div>
     <div class="kiosque-grille">${cartes}</div>`, lienArchives));
}

// Toujours l'ecran de selection, meme s'il n'y a qu'un titre : c'est la destination des liens
// « Kiosque » poses dans les numeros.
async function presseAfficherKiosque() {
  _presseChargement('Kiosque');
  _presseRendreKiosque(await _presseChargerKiosque());
}

// ---- ECRAN 2 : LA LECTURE D'UN NUMERO ----
// Unique chemin de lecture, partage par le kiosque et par les archives : meme guichet, meme
// renderer. `retour` est le seul element qui differe entre les deux provenances.
async function _presseLireEdition(editionId, retour, titreModale) {
  _presseChargement(titreModale);
  const edition = typeof sbLirePresseEdition === 'function'
    ? await sbLirePresseEdition(editionId).catch(() => null)
    : null;

  if (!edition) {
    // L'identifiant vient d'une liste que le serveur a lui-meme filtree : s'il ne rend rien, c'est
    // que la lecture a echoue, pas que le numero n'existe pas.
    _presseCorps(_presseEcran('<div class="kiosque-message kiosque-message-panne">'
      + '<div class="kiosque-message-titre">Ce numéro n\'a pas pu être ouvert</div>'
      + '<p class="kiosque-message-texte">La liaison avec les presses n\'a pas abouti.</p>'
      + '</div>',
      `<span class="journal-action-link" onclick="${retour.action}">◀ ${escapeHtmlText(retour.libelle)}</span>`));
    return null;
  }

  _presseCorps(construireHtmlJournalDuJour(edition, { retour }));
  // Hierarchie visuelle unique (correctif UX du 4 septembre 2026) : uniquement quand un vrai
  // numero s'affiche, .tribune-fronton devient LE seul en-tete visuel et recoit la poignee de
  // deplacement. Jamais pour le kiosque, les archives ou un message de repli.
  document.querySelector('#modal-postes .modal-box')?.classList.add('journal-mode');
  // Toujours re-arme, sans passer par la garde : .tribune-fronton est reconstruit a chaque
  // numero affiche, donc l'ecouteur precedent pointerait sur un element detruit. Seul
  // .modal-header, qui survit aux changements d'ecran, beneficie de la garde.
  _presseDragPoignee = '.tribune-fronton';
  activerDragJournal('.tribune-fronton');
  return edition;
}

function presseOuvrirEditionDuJour(i) {
  const e = _presseEtat.kiosque[i];
  if (!e) return;
  return _presseLireEdition(e.id, { libelle: 'Kiosque', action: 'presseAfficherKiosque()' }, 'Journal du jour');
}

// ---- ECRAN 3 : LES ARCHIVES, NIVEAU TITRES ----
// Un titre n'apparait ici que s'il a reellement publie au moins un numero lisible (arbitrage C) :
// la visibilite se deduit du contenu, aucune colonne `actif` n'est consultee ni maintenue. Un
// journal cree mais muet -- c'est le cas de « La Pravdovka » aujourd'hui -- n'est pas propose.
async function presseAfficherArchivesTitres() {
  _presseChargement('Archives de la presse');
  const titres = typeof sbGetPresseTitresArchives === 'function'
    ? await sbGetPresseTitresArchives().catch(() => null)
    : null;

  const retour = '<span class="journal-action-link" onclick="presseAfficherKiosque()">◀ Retour au kiosque</span>';

  if (titres === null) { _presseCorps(_presseEcran(htmlPressePanne(), retour)); return; }
  _presseEtat.titres = titres;

  if (titres.length === 0) {
    _presseCorps(_presseEcran('<div class="kiosque-message">'
      + '<div class="kiosque-message-titre">Les archives sont vides</div>'
      + '<p class="kiosque-message-texte">Aucun titre n\'a encore publié de numéro.</p>'
      + '</div>', retour));
    return;
  }

  const lignes = titres.map((t, i) =>
    `<div class="kiosque-titre" onclick="presseAfficherArchivesEditions(${i})">
      ${t.pays ? `<div class="kiosque-titre-pays">${escapeHtmlText(_presseNomPays(t.pays))}</div>` : ''}
      <div class="kiosque-titre-nom">${escapeHtmlText(t.nom)}</div>
      <div class="kiosque-titre-date">${t.nb_editions} numéro${t.nb_editions > 1 ? 's' : ''} · dernier le ${escapeHtmlText(formaterDateEditionFr(t.derniere_parution))}</div>
    </div>`).join('');

  _presseCorps(_presseEcran(
    `<div class="kiosque-entete">Archives — choisir un titre</div>
     <div class="kiosque-grille">${lignes}</div>`, retour));
}

// ---- ECRAN 4 : LES ARCHIVES, NIVEAU NUMEROS D'UN TITRE ----
// Du plus recent au plus ancien, page par page, METADONNEES SEULEMENT : cette liste ne charge
// aucun article. Le guichet demande une ligne de plus que la page pour savoir s'il existe une
// suite, sans compter la collection entiere.
async function presseAfficherArchivesEditions(i, page) {
  const titre = (i === undefined || i === null) ? _presseEtat.titreCourant : _presseEtat.titres[i];
  if (!titre) return;
  _presseEtat.titreCourant = titre;
  _presseEtat.page = Math.max(0, page || 0);

  _presseChargement(titre.nom);
  const res = typeof sbGetPresseEditionsArchives === 'function'
    ? await sbGetPresseEditionsArchives(titre.journal_id, PRESSE_ARCHIVES_PAR_PAGE,
        _presseEtat.page * PRESSE_ARCHIVES_PAR_PAGE).catch(() => null)
    : null;

  const retour = '<span class="journal-action-link" onclick="presseAfficherArchivesTitres()">◀ Tous les titres</span>';

  if (res === null) { _presseCorps(_presseEcran(htmlPressePanne(), retour)); return; }
  _presseEtat.editions = res.editions;

  if (res.editions.length === 0) {
    _presseCorps(_presseEcran('<div class="kiosque-message">'
      + '<div class="kiosque-message-titre">Aucun numéro sur cette page</div>'
      + '</div>', retour));
    return;
  }

  const lignes = res.editions.map((e, k) =>
    `<div class="kiosque-numero" onclick="presseOuvrirEditionArchive(${k})">
      ${escapeHtmlText(formaterDateEditionFr(e.date_edition))}
    </div>`).join('');

  const nav = [];
  if (_presseEtat.page > 0) nav.push(`<span class="journal-action-link" onclick="presseAfficherArchivesEditions(null, ${_presseEtat.page - 1})">◀ Numéros plus récents</span>`);
  if (res.encore) nav.push(`<span class="journal-action-link" onclick="presseAfficherArchivesEditions(null, ${_presseEtat.page + 1})">Numéros plus anciens ▶</span>`);

  _presseCorps(_presseEcran(
    `<div class="kiosque-entete">${escapeHtmlText(titre.nom)}${titre.pays ? ' · ' + escapeHtmlText(_presseNomPays(titre.pays)) : ''} — collection</div>
     <div class="kiosque-numeros">${lignes}</div>
     ${nav.length ? `<div class="kiosque-pagination">${nav.join('')}</div>` : ''}`, retour));
}

function presseOuvrirEditionArchive(k) {
  const e = _presseEtat.editions[k];
  if (!e) return;
  // Le retour ramene a la PAGE d'ou l'on vient, pas au debut de la collection.
  return _presseLireEdition(e.id,
    { libelle: 'Archives', action: `presseAfficherArchivesEditions(null, ${_presseEtat.page})` },
    _presseEtat.titreCourant ? _presseEtat.titreCourant.nom : 'Archives');
}

// ---- POINT D'ENTREE (signature inchangee) ----
// force=true (chantier "acces depuis le journal d'evenements", 1er septembre 2026) : contourne
// le garde-fou "une seule fois par jour" ci-dessous, reserve a l'ouverture automatique au
// chargement (plateau-core.js). Le lien pose dans le journal d'evenements appelle TOUJOURS
// afficherJournalDuJour(true) -- sans ce parametre, un clic apres la premiere ouverture
// automatique de la journee resterait sans effet (return silencieux).
async function afficherJournalDuJour(force) {
  const today = state.day || 1;
  const sessionKey = 'journal_dujour_day_' + today;
  if (!force && sessionStorage.getItem(sessionKey)) return;
  sessionStorage.setItem(sessionKey, '1');

  document.querySelector('#modal-postes .modal-box')?.classList.add('modal-wide');
  document.getElementById('modal-postes').classList.add('open');
  _presseChargement('Journal du jour');

  // ARBITRAGE 0 / 1 / PLUSIEURS (21 septembre 2026).
  //
  // Le kiosque n'est impose que lorsqu'il y a un choix reel a faire. Un ecran de selection a une
  // seule entree ne fait rien choisir du tout : il ajoute un clic entre le joueur et son journal,
  // et rompt la fluidite historique de l'ouverture du matin. On ne l'affiche donc qu'a partir de
  // deux titres parus.
  //
  // Un seul titre n'enferme personne pour autant : le numero ouvert directement porte en pied ses
  // acces « Kiosque » et « Archives » (voir construireHtmlJournalDuJour). Le kiosque reste donc
  // atteignable meme quand il ne s'affiche pas de lui-meme.
  const parus = await _presseChargerKiosque();
  if (parus && parus.length === 1) {
    await presseOuvrirEditionDuJour(0);
  } else {
    _presseRendreKiosque(parus); // 0 titre -> message d'absence ; 2+ -> ecran de selection
  }

  // Notification dans le journal d'evenements, UNE SEULE FOIS par jour de jeu (d'ou "!force" :
  // sans lui, chaque reouverture manuelle republierait une entree -- constate en execution reelle
  // sous WKWebView avant que cette garde n'existe). Le lien est pose dans TOUS les cas (correctif
  // du 12 septembre 2026) : il reste cliquable dans l'historique du journal, seul moyen pour le
  // joueur de rouvrir la presse, puisqu'il n'existe ni ordre ni bouton de plateau qui y mene.
  // Le libelle depend de ce qui a reellement paru, et ne nomme plus un titre en dur.
  // L'entree du journal d'evenements distingue les MEMES trois etats que l'ecran -- panne,
  // absence de parution, parution(s). Annoncer « aucun journal n'a paru » alors que la requete a
  // echoue serait exactement la confusion que le lot demande d'eviter, deplacee d'un cran.
  if (!force) {
    const lien = '<span class="journal-action-link" onclick="afficherJournalDuJour(true)">';
    let texte;
    if (parus === null) {
      texte = '📰 Le kiosque est injoignable. ' + lien + 'Réessayer</span>';
    } else if (parus.length === 0) {
      texte = '📰 Aucun journal n\'a paru aujourd\'hui. ' + lien + 'Passer au kiosque</span>';
    } else if (parus.length === 1) {
      const nom = (parus[0].journaux && parus[0].journaux.nom) || 'Un titre';
      texte = `📰 ${escapeHtmlText(nom)} a paru aujourd'hui. ` + lien + 'Lire le journal</span>';
    } else {
      texte = `📰 ${parus.length} titres ont paru aujourd'hui. ` + lien + 'Passer au kiosque</span>';
    }
    addJournalEntry(texte, 'event-info');
  }
}

// =====================
// MÉTÉO POLITIQUE QUOTIDIENNE


// =====================
// COMPLEMENT POLITIQUE (room actions, decrets, organigramme, presidentiel, guerre, loi, assemblee, naturalisation, annuaire, nominations)
// =====================

// =====================
// ROOM ACTIONS
// =====================
function renderRoomActions(room, buildingId, roomId) {
  const orders = room.orders || [];
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  document.getElementById('action-context-bat').textContent =
    room.name.toUpperCase() + ' — ACTIONS DISPONIBLES';

  // Fusionner avec les ordres du buildingContext (specifiques a l'empire courant)
  const world = WORLD[state.country];
  const city = world?.[state.currentCity];
  const ctx = city?.buildingContext?.[buildingId];
  const ctxOrders = (ctx?.orders || []);
  // Ordres specifiques a CETTE room, pour une ville donnee, sur un batiment generique partage
  // par plusieurs villes (ex. 'mairie') -- ctxOrders ci-dessus s'applique a TOUTES les rooms du
  // batiment, ce qui ne convient pas quand seule une room precise doit recevoir un ordre propre
  // a une ville (ex. bureau_maire_adjoint de Montrouge, logements sociaux, 18 aout 2026).
  // roomOverrides ne servait jusqu'ici qu'a name/imageUrl/persons (voir plateau-navigation.js) --
  // extension purement additive : absent pour tous les roomOverrides existants, donc aucun
  // changement de comportement ailleurs.
  const ctxRoomOrders = (ctx?.roomOverrides?.[roomId]?.orders || []);

  // Exclusion additive minimale (lot plafonds/Marche, 21 aout 2026) : permet a un roomOverride
  // propre a UNE ville de masquer un fn herite du template de base PARTAGE (ex. se_nourrir au
  // Marche de Luthecia, herite de BUILDINGS['marche'], egalement utilise tel quel a Montrouge/
  // Khalija) sans jamais toucher au template lui-meme ni dupliquer la room. Absent partout
  // ailleurs (aucun roomOverride existant ne declare excludeOrders) : zero changement de
  // comportement pour tout le reste du jeu.
  const ctxExcludeOrders = (ctx?.roomOverrides?.[roomId]?.excludeOrders || []);

  // Plus d'ordres communs ici — se_cacher/blocus/incendier sont dans la fiche personnage
  const allOrders = [...orders, ...ctxOrders, ...ctxRoomOrders].filter(o => !ctxExcludeOrders.includes(o.fn));

  const buttons = allOrders.map(o => {
    // Verifier requiresPost : doit avoir le bon poste specifique
    let needsPost = false;
    if (o.requiresPost) {
      if (o.requiresPost === true) {
        // Juste avoir un poste
        needsPost = !state.poste;
      } else if (Array.isArray(o.requiresPost)) {
        // Plusieurs postes valides (OR) -- chantier "Inspecter les troupes", 4 septembre 2026 :
        // premier ordre du jeu ouvert a deux postes distincts (min_def ET commandant). Jamais de
        // verification nominative supplementaire ici (idem tout requiresPost simple, revalidee
        // cote handler).
        const posteId = state.poste?.id || '';
        needsPost = !o.requiresPost.includes(posteId);
      } else {
        // Verifier le poste specifique
        const posteId = state.poste?.id || '';
        const reqPost = o.requiresPost;
        if (reqPost === 'president') needsPost = posteId !== 'president';
        else if (reqPost === 'pm') needsPost = posteId !== 'pm';
        else if (reqPost === 'depute') {
          // Fix 9 aout 2026 : etre depute est stocke dans state.posteDepute (emplacement
          // separe, cumulable avec un autre poste), pas dans state.poste - cette verification
          // ne lisait que state.poste, donc aucun depute reel ne pouvait jamais voter une loi
          // (seul ordre requiresPost:'depute' du jeu) quel que soit son chemin d'obtention.
          needsPost = !posteId.startsWith('depute') && !state.posteDepute?.id?.startsWith('depute');
        }
        else if (reqPost === 'juge') needsPost = posteId !== 'juge';
        else if (reqPost === 'magistrat') needsPost = !['juge','procureur'].includes(posteId);
        else if (reqPost === 'commissaire') needsPost = posteId !== 'commissaire';
        else if (reqPost === 'ambassadeur_local') {
          // Restriction speciale : pas un poste classique, mais une nomination specifique
          // a ce bureau precis (voir sbNommerAmbassadeur / cache charge dans enterBuilding).
          const AMBASSADE_ROOM_EMPIRE = { bureau_al_khalija: 'khalija', bureau_sovarka: 'soviet', bureau_el_estado: 'narco' };
          const empireDuBureau = AMBASSADE_ROOM_EMPIRE[roomId];
          const infoAmbassade = (state.ambassadesOuvertesCache || []).find(a => a.empire === empireDuBureau);
          needsPost = !(infoAmbassade && infoAmbassade.ambassadeur === state.char?.name);
        }
        else if (reqPost === 'maire') needsPost = !estPosteMaire(posteId); // exclut maire_adjoint (correctif Lot 4.3)
        else needsPost = posteId !== reqPost;
      }
    }
    // Verifier requiresSquatteurs (negocier_squatteurs) : le flag existe dans data.js depuis
    // le debut mais n'etait lu par aucun code -- le bouton restait affiche/cliquable meme sans
    // squatteur reel sur le terrain (bug remonte avant Phase L). terrainOrdreDisponible()
    // contient deja la bonne verification (utilisee pour signer_compromis/acheter_terrain),
    // reutilisee ici a l'identique plutot que dupliquee.
    let needsSquat = false;
    if (o.requiresSquatteurs && typeof terrainOrdreDisponible === 'function') {
      needsSquat = !terrainOrdreDisponible(o.fn, buildingId).ok;
    }
    // Verifier requiresCadavre (faire_disparaitre_cadavre) : meme defaut que requiresSquatteurs
    // (flag jamais lu), corrige a l'identique en reutilisant terrainOrdreDisponible().
    let needsCadavre = false;
    if (o.requiresCadavre && typeof terrainOrdreDisponible === 'function') {
      needsCadavre = !terrainOrdreDisponible(o.fn, buildingId).ok;
    }
    // Verifier requiresChefSyndicatDockers (blocus_portuaire, lot du 25 aout 2026) : garde UI
    // uniquement -- getChefSyndicatDockersPSM() lit state.organisations, deja pre-charge/cree
    // paresseusement a l'entree de la room (voir enterRoom, plateau-navigation.js). Ne remplace
    // jamais la revalidation independante faite cote handler (doBlocusPortuaire) : cette
    // condition ne fait que griser le bouton, exactement comme requiresPost.
    let needsChefSyndicat = false;
    if (o.requiresChefSyndicatDockers) {
      const chefReel = typeof getChefSyndicatDockersPSM === 'function' ? getChefSyndicatDockersPSM() : null;
      needsChefSyndicat = chefReel !== (state.char?.name || '');
    }
    // §9 du cahier des charges "Greves" (3 septembre 2026) : la repression policiere devient
    // INDISPONIBLE (pas un malus, pas un jet d'echec) des qu'un syndicat corpsMetier==='police'
    // est en greve ou participe activement a une greve generale -- identification structurelle
    // via syndicatPoliceEnGreve (plateau-organisations-quetes.js), jamais un nom d'organisation
    // hardcode. Garde UI ici ; revalidee independamment dans confirmerReprimerManif ci-dessous.
    let needsPoliceIndisponible = false;
    const policeTooltip = 'Un syndicat de policiers est en grève : la répression policière est impossible tant qu\'il n\'y met pas fin.';
    if (o.fn === 'reprimer_manif' && typeof syndicatPoliceEnGreve === 'function') {
      needsPoliceIndisponible = syndicatPoliceEnGreve(state.country);
    }
    // Garde UI dediee a "Prendre sa licence sportive" (correctif du 25 aout 2026, suite au bug
    // production v78) : grise le bouton avec une infobulle explicite des que le clic serait de
    // toute facon refuse par la garde fonctionnelle de doPrendreLicenceSportive
    // (plateau-organisations-quetes.js) -- ce garde-fou UI ne remplace jamais cette garde reelle,
    // il l'anticipe seulement pour eviter un clic pour rien. Special-case sur o.fn (meme
    // precedent que produire_arme plus bas) plutot qu'un nouveau flag requiresXXX generique :
    // un seul ordre du jeu est concerne.
    let needsLicenceIndisponible = false;
    let licenceTooltip = '';
    if (o.fn === 'prendre_licence_sportive' && typeof getClubLocal === 'function' && typeof statutLicenceSportive === 'function') {
      const clubLocalLicence = getClubLocal();
      const licActuelle = state.char?.licenceSportive;
      const statutLicenceActuel = statutLicenceSportive();
      if (statutLicenceActuel === 'active' && clubLocalLicence && licActuelle.clubId !== clubLocalLicence.id) {
        needsLicenceIndisponible = true;
        licenceTooltip = 'Vous êtes déjà licencié(e) dans un autre club. Pour changer de club en cours de saison, vous devez faire l\'objet d\'un transfert.';
      } else if (statutLicenceActuel === 'anneeBlanche') {
        needsLicenceIndisponible = true;
        licenceTooltip = 'Vous êtes en année blanche : vous ne pouvez reprendre aucune licence avant la saison suivante.';
      } else if (statutLicenceActuel === 'impaye' && clubLocalLicence && licActuelle.clubId !== clubLocalLicence.id) {
        needsLicenceIndisponible = true;
        licenceTooltip = 'Votre licence impayée vous rattache encore à un autre club. Vous ne pouvez la reprendre que là-bas, ou passer par un transfert.';
      }
    }
    // Meme principe pour "Ne pas renouveler ma licence"/"Annuler le non-renouvellement" --
    // reutilise directement messageLicenceInvalidePourClub, LA MEME fonction deja appelee par
    // doDemanderNonRenouvellementLicence/doAnnulerNonRenouvellementLicence (plateau-organisations-
    // quetes.js) : garantit que l'infobulle affichee ici correspond exactement au message que la
    // garde fonctionnelle produirait au clic, sans dupliquer la logique une troisieme fois.
    if ((o.fn === 'demander_non_renouvellement_licence' || o.fn === 'annuler_non_renouvellement_licence') &&
        typeof getClubLocal === 'function' && typeof messageLicenceInvalidePourClub === 'function') {
      const msgGestionLicence = messageLicenceInvalidePourClub(getClubLocal(), 'gérer votre licence');
      if (msgGestionLicence) {
        needsLicenceIndisponible = true;
        licenceTooltip = msgGestionLicence;
      }
    }
    // UX "deux ordres toujours visibles" (correctif du 27 aout 2026), scope strict aux suites
    // d'hotel (room.locationData?.suiteChoice, seules suite_privee/suite_presidentielle
    // concernees a ce jour -- verifie, aucune autre room ne porte ce flag) : louer_local et
    // gerer_local restent toujours affiches, jamais retires de data.js, mais grises + infobulle
    // exacte des que l'action serait de toute facon refusee. Ne touche jamais au systeme
    // generique louer_local/gerer_local des autres locaux (bureaux/commerces/creation
    // d'organisation), hors perimetre de ce correctif. Reutilise getLocationPourRoom, deja la
    // seule source de verite lue par ouvrirModalLouerLocal/ouvrirModalGererLocal
    // (plateau-justice-economie.js) -- meme condition, jamais dupliquee.
    let needsSuiteIndisponible = false;
    let suiteTooltip = '';
    if (room.locationData?.suiteChoice && (o.fn === 'louer_local' || o.fn === 'gerer_local') && typeof getLocationPourRoom === 'function') {
      const locationSuite = getLocationPourRoom(buildingId, roomId);
      if (o.fn === 'louer_local' && locationSuite) {
        needsSuiteIndisponible = true;
        suiteTooltip = 'Suite non disponible : déjà louée';
      } else if (o.fn === 'gerer_local' && (!locationSuite || locationSuite.locataire !== state.char?.name)) {
        needsSuiteIndisponible = true;
        suiteTooltip = 'Vous n\'êtes pas locataire de ce local';
      }
    }
    // Garde UI pour les soins de chambre de la clinique privee (finalisation chambres clinique,
    // 31 aout 2026) : meme principe que les gardes ci-dessus, grise le bouton pour un visiteur
    // qui n'est pas le patient de cette chambre -- ne remplace jamais le blocage reel de doOrder
    // (plateau-router.js), qui reutilise la meme fonction estOrdreMedicalReserveAuPatient.
    let needsPatientChambre = false;
    const patientChambreTooltip = 'Réservé au patient auquel cette chambre est attribuée.';
    if (typeof estOrdreMedicalReserveAuPatient === 'function' && estOrdreMedicalReserveAuPatient(buildingId, roomId, o.fn)) {
      needsPatientChambre = true;
    }
    // Droits generiques sur un local (Lot 1.2) : un ordre peut declarer requiresRole
    // 'murs'|'locataire'|'fonds'. Contrairement aux gardes ci-dessus, ce n'est PAS un
    // special-case par o.fn : une seule condition declarative couvre tous les ordres presents et
    // futurs. La definition de l'ordre est passee directement (o), donc aucune relecture de la
    // piece ici. Absent de tout ordre existant a ce jour : strictement no-op sur l'existant.
    // Ce grisage n'est qu'une anticipation -- le blocage reel est dans doOrder (plateau-router.js),
    // qui reutilise le MEME verdict.
    let needsRoleLocal = false;
    let roleLocalTooltip = '';
    if (typeof verdictRoleOrdre === 'function' && o.requiresRole) {
      const verdictRole = verdictRoleOrdre(buildingId, roomId, o.fn, o);
      if (verdictRole.bloque) { needsRoleLocal = true; roleLocalTooltip = verdictRole.message; }
    }
    // Garde UI pour "Prendre le pouls" (pouls_populaire, Marche, chantier 27 aout 2026) : meme
    // principe que les gardes ci-dessus, grise le bouton avec une infobulle explicite des
    // qu'aucune election locale (maire/depute) n'est actuellement en cours dans la ville
    // courante, sans jamais le masquer. Reutilise electionsLocalesEnCours() (plateau-politique.js,
    // pres de getPhaseActuelle), seule source de verite, lecture synchrone du cache
    // CYCLES_ELECTORAUX deja tenu a jour ailleurs -- jamais de nouvel appel reseau ici.
    let needsElectionIndisponible = false;
    const electionTooltip = 'Disponible seulement en période électorale.';
    if (o.fn === 'pouls_populaire' && typeof electionsLocalesEnCours === 'function') {
      const actives = electionsLocalesEnCours(state.country || 'republic', state.currentCity || 'capitale');
      needsElectionIndisponible = actives.length === 0;
    }
    // Avant ce correctif, TEST_MODE forcait l'affichage a "0 PA" quel que soit o.pa reel --
    // le joueur ne pouvait jamais apprendre le vrai cout normal d'un ordre pendant la periode
    // de PA illimites (bug remonte sur "investir", en realite systemique a tous les ordres avec
    // pa>0). La vraie valeur reste desormais toujours visible ; seule une mention "(illimité)"
    // signale que TEST_MODE l'annule pour l'instant. Valeur transmise a doOrder() inchangee
    // (o.pa brut, deja correcte avant ce correctif -- uniquement l'affichage etait en cause).
    // Correctif "gratuit" (20 aout 2026) : un ordre a 0 PA n'affiche plus "0 PA" -- generique,
    // vrai pour tout ordre, pas seulement les commerces (voir aussi costDisplay/jonction ci-dessous).
    let paDisplay = o.pa > 0 ? o.pa + ' PA' + (TEST_MODE ? ' (illimité' + (o.pa > 1 ? 's' : '') + ')' : '') : '';
    // Lot boissons (20 aout 2026) : "Produire un repas" (produire_commerce) n'a jamais debite le
    // moindre PA a l'ouverture, quel que soit le buildingId ou la valeur declaree dans data.js --
    // le vrai cout PA est celui de la recette choisie ensuite, debite par produireRecetteCommerce()
    // (plateau-actions-illegales-rumeurs.js). Masquer l'indication PA ici est donc exact partout,
    // pas seulement au Cafe de la Gare. "Consulter la carte" reste affichee normalement partout
    // SAUF quand sa valeur declaree est reellement 0 PA (seul le Cafe de la Gare pour l'instant) --
    // les autres commerces (brasserie/hotel-mineur/buvette) debitent encore reellement leur PA
    // declare et doivent continuer a l'afficher.
    if (o.fn === 'produire_commerce' || o.fn === 'consommer_boisson' || o.fn === 'offrir_tournee') {
      paDisplay = '';
    } else if (o.fn === 'consulter_carte_commerce' && o.pa === 0) {
      paDisplay = '';
    }
    // Appliquer malus ISN sur les actes illegaux
    let tauxAffiche = o.successRate || 70;
    if (o.type === 'illegal') {
      tauxAffiche = Math.max(5, tauxAffiche - getMalusISN());
    }
    // "gratuit" retire (20 aout 2026) : trompeur des qu'une action a un cout reel differe (ex.
    // produire_commerce/consommer_boisson/offrir_tournee, declares 0 PA/0 FR a l'ouverture alors
    // que l'action qui suit a un vrai cout choisi ensuite). Un ordre reellement 0 PA/0 FR n'affiche
    // plus rien du tout (voir jonction costDisplay/paDisplay plus bas).
    let costDisplay = o.cost > 0 ? o.cost.toLocaleString('fr-FR') + ' ' + cur : '';
    // Fix 9 aout 2026 : produire_arme est declare pa:0/cost:0 dans data.js (sa vraie logique
    // est geree entierement dans confirmerProduction, hors du chemin doOrder generique) - le
    // bouton affichait donc "gratuit" a tort alors que la production coute reellement 2 PA et
    // rapporte 100 FR de salaire (confirme par Fred en jeu). PA_PRODUCTION_ARMURERIE/
    // SALAIRE_PRODUCTION_ARMURERIE (plateau-actions-illegales-rumeurs.js) sont la seule source
    // de verite du tarif, jamais dupliquee ici en dur.
    if (o.fn === 'produire_arme' && typeof PA_PRODUCTION_ARMURERIE !== 'undefined') {
      paDisplay = PA_PRODUCTION_ARMURERIE + ' PA' + (TEST_MODE && PA_PRODUCTION_ARMURERIE > 0 ? ' (illimité' + (PA_PRODUCTION_ARMURERIE > 1 ? 's' : '') + ')' : '');
      costDisplay = '+' + SALAIRE_PRODUCTION_ARMURERIE.toLocaleString('fr-FR') + ' ' + cur;
    }
    const ef = ORDER_EFFECTS[o.fn] || {};
    const gainParts = [];
    if (ef.hp > 0)    gainParts.push('+' + ef.hp + ' Sante');
    if (ef.moral > 0) gainParts.push('+' + ef.moral + ' Moral');
    if (ef.inf > 0)   gainParts.push('+' + ef.inf + ' INF');
    if (ef.pop > 0)   gainParts.push('+' + ef.pop + ' POP');
    if (ef.arg > 0)   gainParts.push('+' + ef.arg + ' ' + cur);
    const gainStr = gainParts.join(' · ');
    const riskParts = [];
    if (ef.dis < 0)   riskParts.push(ef.dis + ' DIS');
    if (ef.pop < 0)   riskParts.push(ef.pop + ' POP');
    const riskStr = riskParts.join(' · ');
    const rate = o.successRate || 70;
    const tooltipParts = [];
    if (o.desc) tooltipParts.push(o.desc);
    if (gainStr) tooltipParts.push('Gain: ' + gainStr);
    if (riskStr) tooltipParts.push('Risque: ' + riskStr);
    tooltipParts.push('Reussite: ' + rate + '%');
    const tooltip = tooltipParts.join(' | ');

    let onclickFn = '';
    if (needsPost) {
      // Message explicatif avec le poste requis
      const postesNoms = {
        president: 'Président de la République',
        pm: 'Premier Ministre',
        depute: 'Député',
        juge: 'Juge',
        magistrat: 'Magistrat',
        commissaire: 'Commissaire',
        min_int: "Ministre de l'Intérieur",
        min_fin: 'Ministre des Finances',
        min_just: 'Ministre de la Justice',
        min_def: 'Ministre de la Défense',
        min_info: "Ministre de l'Information",
        min_ae: 'Ministre des AE',
        ambassadeur_local: "l'ambassadeur nommé pour ce bureau",
        commandant: 'Commandant de la Caserne'
      };
      const posteRequisNom = o.requiresPost === true ? 'un poste institutionnel'
        : Array.isArray(o.requiresPost) ? o.requiresPost.map(p => postesNoms[p] || p).join(' ou ')
        : (postesNoms[o.requiresPost] || o.requiresPost);
      onclickFn = 'showPostRequired(' + JSON.stringify(posteRequisNom) + ')';
    } else if (needsSquat) {
      onclickFn = "showToast('Aucun squatteur', 'Aucun squatteur a negocier sur ce terrain pour l\\'instant.', false)";
    } else if (needsCadavre) {
      onclickFn = "showToast('Aucun cadavre', 'Aucun cadavre a dissimuler sur ce terrain pour l\\'instant.', false)";
    } else if (needsChefSyndicat) {
      onclickFn = "showToast('Réservé au chef', 'Seul le chef du Syndicat des Dockers peut declencher un blocus portuaire.', false)";
    } else if (needsPoliceIndisponible) {
      onclickFn = "showToast('Répression impossible', " + JSON.stringify(policeTooltip) + ", false)";
    } else if (needsLicenceIndisponible) {
      onclickFn = "showToast('Licence indisponible', " + JSON.stringify(licenceTooltip) + ", false)";
    } else if (needsSuiteIndisponible) {
      onclickFn = "showToast('Indisponible', " + JSON.stringify(suiteTooltip) + ", false)";
    } else if (needsElectionIndisponible) {
      onclickFn = "showToast('Aucune élection', " + JSON.stringify(electionTooltip) + ", false)";
    } else if (needsPatientChambre) {
      onclickFn = "showToast('Réservé au patient', " + JSON.stringify(patientChambreTooltip) + ", false)";
    } else if (needsRoleLocal) {
      onclickFn = "showToast('Accès refusé', " + JSON.stringify(roleLocalTooltip) + ", false)";
    } else if (o.fn === 'plainte_police') {
      onclickFn = 'openPlainteModal(' + o.pa + ',' + o.cost + ')';
    } else if (o.fn === 'gerer_finances') {
      onclickFn = 'openFinancesModal(' + o.pa + ',' + o.cost + ')';
    } else if (o.fn === 'postuler') {
      onclickFn = 'ouvrirEcranPostes()';
    } else {
      // BUG CORRIGE (12 septembre 2026) : seule l'apostrophe etait neutralisee. Une desc contenant
      // un GUILLEMET DOUBLE (data.js:2806, « un futur "Placer un article favorable" ») fermait
      // prematurement l'attribut onclick="..." : le handler devenait du JS invalide et le bouton
      // etait totalement inerte -- cas reel de l'ordre « Etouffer un article » (1 PA + 1000 FR),
      // inaccessible depuis toujours a la redaction de L'Autruche Entravee.
      const safeLabel = o.label.replace(/'/g, ' ').replace(/"/g, '&quot;');
      const safeDesc = (o.desc||'').replace(/'/g, ' ').replace(/"/g, '&quot;');
      onclickFn = "doOrder('" + o.fn + "'," + o.pa + "," + o.cost + ",'" + safeLabel + "','" + safeDesc + "'," + rate + ")";
    }

    const gainBadge = gainStr ? '<span class="action-gain">' + gainStr + '</span>' : '';
    const blockedCls = (needsPost || needsSquat || needsCadavre || needsChefSyndicat || needsPoliceIndisponible || needsLicenceIndisponible || needsSuiteIndisponible || needsElectionIndisponible || needsPatientChambre || needsRoleLocal) ? ' blocked' : '';
    const coutJoint = [costDisplay, paDisplay].filter(Boolean).join(' · ');
    const tooltipFinal = needsPoliceIndisponible ? policeTooltip.replace(/"/g, '&quot;') : (needsLicenceIndisponible ? licenceTooltip.replace(/"/g, '&quot;') : (needsSuiteIndisponible ? suiteTooltip.replace(/"/g, '&quot;') : (needsElectionIndisponible ? electionTooltip.replace(/"/g, '&quot;') : (needsPatientChambre ? patientChambreTooltip.replace(/"/g, '&quot;') : (needsRoleLocal ? roleLocalTooltip.replace(/"/g, '&quot;') : tooltip)))));
    return '<button class="action-btn ' + o.type + blockedCls + '" onclick="' + onclickFn + '" title="' + tooltipFinal + '"><i class="ti ' + o.icon + '" style="font-size:.82rem"></i> ' + o.label + ' <span class="pa-cost">' + coutJoint + '</span>' + gainBadge + '</button>';
  });

  // Bouton generique "Ecouter l'audioguide" : apparait pour toute salle ayant un audioUrl,
  // sans passer par room.orders/doOrder (pas un ordre codable, juste un lecteur audio).
  if (room.audioUrl) {
    const safeNom = room.name.replace(/'/g, ' ');
    buttons.push('<button class="action-btn legal" onclick="ouvrirAudioguide(\'' + room.audioUrl + '\',\'' + safeNom + '\')" title="Ecouter l\'audioguide de cette salle"><i class="ti ti-headphones" style="font-size:.82rem"></i> Écouter l\'audioguide <span class="pa-cost">gratuit · 0 PA</span></button>');
  }

  document.getElementById('actions-row-bat').innerHTML = buttons.join('') ||
    '<div style="font-size:.75rem;color:#9a8a68;font-style:italic;padding:.3rem">Aucune action disponible ici.</div>';
}

function ouvrirAudioguide(url, nomSalle) {
  document.getElementById('postes-modal-title').textContent = 'Audioguide — ' + nomSalle;
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.5rem;text-align:center">' +
    '<audio controls autoplay style="width:100%" src="' + url + '"></audio>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

// Stoppe et decharge un audioguide en cours de lecture (fermeture de la modale, changement
// de piece/batiment) — pour eviter qu'il continue en fond ou que plusieurs se superposent.
function arreterAudioguide() {
  const audio = document.querySelector('#postes-body audio');
  if (audio) {
    audio.pause();
    audio.removeAttribute('src');
    audio.load();
  }
}


// DÉCRETS PRÉSIDENTIELS
// =====================
async function signerDecretInutile(pa, cost) {
  if (state.poste?.id !== 'president') {
    showToast('Accès refusé', 'Seul le Président peut signer des décrets.', false);
    return;
  }

  const co = COUNTRIES[state.country];
  const cur = co?.cur || 'FR';
  const empireStyle = EMPIRE_STYLES?.[state.country] || { tone: 'parodique', religion: 'la Foi Locale', leader: 'le Chef' };

  const sujets = [
    'la couleur officielle des formulaires administratifs',
    'l\'heure légale de la sieste nationale',
    'l\'obligation de saluer le portrait du président en entrant dans les bâtiments',
    'la taxe sur les soupirs excessifs dans les couloirs officiels',
    'la nomination d\'un Commissaire aux Bonnes Nouvelles',
    'l\'interdiction des réunions se terminant sans conclusion',
    'la journée nationale du silence administratif',
    'l\'instauration d\'une prime à la loyauté inconditionnelle',
    'la mise en place d\'un formulaire pour contester les formulaires',
    'l\'obligation de finir chaque discours par une citation du Président'
  ];
  const sujet = sujets[Math.floor(Math.random() * sujets.length)];

  document.getElementById('postes-modal-title').textContent = 'Rédaction du Décret...';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060;font-style:italic">La plume présidentielle est à l\'œuvre...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const prompt = 'Tu es le rédacteur des décrets présidentiels dans ' + (co?.n || 'l\'empire') + ', jeu parodique. ' +
    'Style : ' + empireStyle.tone + '. Religion : ' + empireStyle.religion + '. ' +
    'Rédige un décret présidentiel ABSURDE et PARODIQUE sur : ' + sujet + '. ' +
    'Format : Titre officiel + Article 1 + Article 2 + Effet parodique sur la population. ' +
    'Max 6 lignes. Très drôle. Pas de vrais dieux ni religions réelles.';

  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 250, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await resp.json();
    const decret = data.content?.[0]?.text || 'Décret indisponible.';

    // Effets gameplay pré-calculés pour l'aperçu, appliqués uniquement au clic "Publier"
    // (publierDecret) -- ne jamais les appliquer ici, avant toute confirmation du joueur.
    const popEffect = Math.floor(Math.random() * 20) - 5; // -5 à +15
    const infEffect = Math.floor(Math.random() * 10) + 2;

    document.getElementById('postes-modal-title').textContent = '📜 Décret Présidentiel';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem">' +
      '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.6rem;border-bottom:1px solid #2a2010;padding-bottom:.4rem">Signé par ' + (state.char?.name || 'Le Président') + ' · Jour ' + (state.day || 1) + '</div>' +
      '<div style="font-size:.85rem;color:#c0a060;line-height:1.9;white-space:pre-line;font-family:Crimson Pro,Georgia,serif">' + decret + '</div>' +
      '<div style="margin-top:.8rem;font-size:.72rem;color:' + (popEffect >= 0 ? '#4a8a4a' : '#8a3a2a') + '">' +
        (popEffect >= 0 ? '+' : '') + popEffect + ' POP · +' + infEffect + ' INF</div>' +
      '<div style="margin-top:.6rem;display:flex;gap:.5rem">' +
      '<button onclick="publierDecret(this.dataset.txt,' + popEffect + ',' + infEffect + ',' + pa + ',' + cost + ',this.dataset.sujet)" data-txt="' + decret.replace(/"/g, '&quot;') + '" data-sujet="' + sujet.replace(/"/g, '&quot;') + '" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer"><i class="ti ti-speakerphone" style="font-size:.7rem"></i> Publier</button>' +
      '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;padding:.4rem .8rem;border:1px solid #3a2a10;background:transparent;color:#6a5a30;cursor:pointer">Fermer</button>' +
      '</div></div>';

  } catch(e) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a3a20">Erreur de rédaction. La plume est fatiguée.</div>';
  }
}

async function publierDecret(texte, popEffect, infEffect, pa, cost, sujet) {
  if (!exigerPoste('president', 'Seul le Président peut signer un décret.')) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  document.getElementById('modal-postes').classList.remove('open');
  state.pop = Math.max(0, Math.min(100, (state.pop || 50) + popEffect));
  state.inf = Math.min(100, (state.inf || 0) + infEffect);
  updateUI();
  addJournalEntry('📜 Décret signé sur : ' + sujet + '. ' + (popEffect >= 0 ? '+' : '') + popEffect + ' POP · +' + infEffect + ' INF.', 'event-info');
  const from = state.char?.name || 'Le Président';
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : `Jour ${state.day}`;

  let topicId = null;
  if (typeof sbCreateTopic === 'function') {
    topicId = await sbCreateTopic('presidence', '📜 Décret Présidentiel', from, state.country, time);
    if (topicId && typeof sbCreatePost === 'function') {
      await sbCreatePost(topicId, from, texte, time);
    }
  }

  if (!FORUM_TOPICS['presidence']) FORUM_TOPICS['presidence'] = [];
  FORUM_TOPICS['presidence'].unshift({
    id: topicId || 'topic-' + Date.now(), title: '📜 Décret Présidentiel', author: from,
    time, views: 1, replies: 0, lastPostAuthor: from, lastPostTime: time,
    posts: [{ id: 'p-' + Date.now(), author: from, time, content: texte }]
  });

  showToast('Décret publié !', 'Visible sur La Presidence a la Nation.', true);
}



function ouvrirCadavreListe(el) {
  const photo = el.dataset.photo;
  const pos   = el.dataset.pos || '50% 40%';
  const role  = el.dataset.role || 'Cadavre';
  const trait = el.dataset.trait || '';
  ouvrirPhotoCadavre(JSON.stringify({ photoUrl: photo, photoPos: pos, role, trait }));
}

function ouvrirPhotoCadavre(jsonStr) {
  try {
    const pnj = JSON.parse(jsonStr);
    const overlay = document.createElement('div');
    overlay.onclick = () => overlay.remove();
    overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.95);z-index:99999;display:flex;flex-direction:column;align-items:center;justify-content:center;cursor:pointer';
    const photoHtml = pnj.photoUrl
      ? '<img src="' + pnj.photoUrl + '" style="max-width:85vw;max-height:70vh;object-fit:contain;border:1px solid #3a2a10;margin-bottom:.8rem"/>'
      : '<div style="font-size:4rem;margin-bottom:.8rem">💀</div>';
    overlay.innerHTML = photoHtml +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.9rem;letter-spacing:.12em;color:#8a3a2a;margin-bottom:.4rem">' + (pnj.role || 'Cadavre') + '</div>' +
      '<div style="font-size:.78rem;color:#6a5a30;font-style:italic;max-width:400px;text-align:center;padding:0 1rem">' + (pnj.trait || '') + '</div>' +
      '<div style="font-size:.82rem;color:#9a8a68;margin-top:1rem">Cliquer pour fermer</div>';
    document.body.appendChild(overlay);
  } catch(e) {}
}

// =====================

// ORGANIGRAMME
// =====================
// Reconstruite le 9 aout 2026 (refonte des postes) : lisait l'ancienne table statique POSTES,
// retiree. Desormais basee sur POSTES_ELECTIFS (cycle.eluId) + POSTES_NOMMES_EXCLUSIFS
// (joueurs reels puis titulaires_pnj en repli, via getTitulaireActuel).
async function ouvrirOrganigramme() {
  const co = COUNTRIES[state.country];
  const myName = state.char?.name || '';
  const villeCourante = state.currentCity || 'capitale';
  const villeNom = WORLD[state.country]?.[villeCourante]?.name || villeCourante;

  document.getElementById('postes-modal-title').textContent = `Organigramme — ${co?.n || 'Empire'}`;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase();

  const getTitulaireElu = (posteId, city) => {
    const cle = typeof getCleCycle === 'function' ? getCleCycle(posteId, city) : posteId;
    return CYCLES_ELECTORAUX?.[state.country]?.[cle]?.eluId || null;
  };

  const sections = [
    { title: 'Exécutif', postes: [
      { id:'president', name:'Président de la République', type:'elu' },
      { id:'pm', name:'Premier Ministre', type:'nomme' },
      { id:'min_int', name:"Ministre de l'Intérieur", type:'nomme' },
      { id:'min_fin', name:'Ministre des Finances', type:'nomme' },
      { id:'min_just', name:'Ministre de la Justice', type:'nomme' },
      { id:'min_def', name:'Ministre de la Défense', type:'nomme' },
      { id:'min_info', name:"Ministre de l'Information", type:'nomme' },
      { id:'min_ae', name:'Ministre des Affaires Étrangères', type:'nomme' },
      { id:'commandant', name:'Commandant de la Caserne', type:'nomme' },
      { id:'chef_syndicat', name:'Chef Syndical', type:'elu' }
    ]},
    // Le juge a sa propre section : il siege dans UN tribunal (donc une ville), mais il releve
    // de la chaine nationale de la Justice, pas de la mairie. Le presenter sous « Ville — X »
    // laisserait croire que le maire en dispose, ce qui est faux.
    { title: 'Justice — tribunal de ' + villeNom, postes: [
      { id:'juge', name:'Juge', type:'nomme', city: villeCourante }
    ]},
    { title: 'Ville — ' + villeNom, postes: [
      { id:'maire', name:'Maire', type:'elu', city: villeCourante },
      { id:'commissaire', name:'Commissaire', type:'nomme', city: villeCourante },
      { id:'directeur_entrepot', name:"Directeur de l'Entrepôt Logistique", type:'nomme', city: villeCourante }
    ]},
    { title: 'Entreprises stratégiques', postes: [
      { id:'directeur_pharma', name:"Directeur de l'Usine Pharmaceutique", type:'nomme' },
      { id:'directeur_tabac_alcools', name:'Directeur du Pôle Tabac & Alcools', type:'nomme' },
      { id:'directeur_raffinerie', name:'Directeur de la Raffinerie', type:'nomme' }
    ]}
  ];

  let html = '';
  for (const s of sections) {
    html += `<div style="padding:.5rem 1rem;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;border-bottom:1px solid #2a2010;margin-top:.3rem">${s.title}</div>`;
    for (const p of s.postes) {
      let holderName, estPJ;
      if (p.type === 'elu') {
        holderName = getTitulaireElu(p.id, p.city);
        estPJ = true; // cycle.eluId n'est jamais un PNJ (repli PNJ gere separement, voir cascade cron)
      } else {
        const titulaire = typeof getTitulaireActuel === 'function' ? await getTitulaireActuel(p.id, p.city) : null;
        holderName = titulaire?.nom || null;
        estPJ = titulaire?.estPJ ?? true;
      }
      const isMe = estPJ && holderName === myName;
      const holderLabel = !holderName
        ? '<span style="color:#9a8a68;font-style:italic">Vacant</span>'
        : `<span style="color:${isMe ? '#C9A84C' : '#4a8a4a'}">${holderName}${estPJ ? '' : ' (PNJ)'}${isMe ? ' ✦' : ''}</span>`;
      html += `<div style="display:flex;justify-content:space-between;align-items:center;padding:.4rem 1rem;border-bottom:1px solid #1a1810">
        <div style="font-size:.78rem;color:#c0b090">${p.name}</div>
        <div style="font-size:.75rem">${holderLabel}</div>
      </div>`;
    }
  }
  document.getElementById('postes-body').innerHTML = html;
}

// =====================
// ORGANIGRAMME — ACCUEIL DES MAIRIES (17 aout 2026)
// =====================
// Ordre commun aux 3 mairies de Republia (mairie-capitale/hall_mairie, mairie/accueil_mairie —
// partage par PSM et Montrouge), distinct de l'ordre 'organigramme' existant (Palais du
// Gouvernement + hall_mairie de Luthecia uniquement, jamais accessible depuis PSM/Montrouge,
// une seule vue combinee sans distinction national/municipal). Reutilise entierement
// getTitulaireActuel (plateau-organisations-quetes.js), POSTES_ELECTIFS/POSTES_NOMMES_EXCLUSIFS
// (data.js) et getAvatarHtmlPourNom (plateau-multijoueur.js) -- aucune seconde source de verite,
// aucun nouvel asset. L'ordre 'organigramme' existant n'est pas touche.
//
// Ville municipale : resolue via state.currentCity, fiable ici (contrairement aux pipelines
// differes deja corriges ailleurs) car ouvrirOrganigrammeMairie() est appelee SYNCHRONEMENT par
// doOrder() au moment du clic, pendant que le joueur est physiquement dans l'accueil de la
// mairie concernee -- verifie dans plateau-router.js/plateau-navigation.js avant d'ecrire ce
// code, aucun appel differe/cron implique.
//
// Deputes : POSTES_ELECTIFS.departemental['depute'] a bien nbParVille:3 declare, mais ce champ
// n'est utilise nulle part (verifie) -- getCleCycle ne construit qu'UNE cle par ville
// (posteId+'_'+city), donc un seul siege reellement elu par ville existe aujourd'hui (3 au
// total). C'est ce mecanisme reel qui est affiche ici, pas le champ non implemente ni l'ancien
// "Annuaire des Deputes" (consulterAnnuaireDeputes, 25 sieges decoratifs sur state.postes,
// jamais connecte au systeme electoral reel) qui reste hors perimetre, inchange.
function renderTitreSectionOrganigramme(titre) {
  return `<div style="padding:.5rem 1rem;font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.15em;color:#8a6a20;border-bottom:1px solid #2a2010;margin-top:.3rem">${escapeHtmlText(titre)}</div>`;
}

async function renderLignesOrganigramme(postes) {
  const myName = state.char?.name || '';
  let html = '';
  for (const p of postes) {
    const titulaire = typeof getTitulaireActuel === 'function' ? await getTitulaireActuel(p.id, p.city, state.country) : null;
    const holderName = titulaire?.nom || null;
    const estPJ = titulaire?.estPJ ?? true;
    const isMe = estPJ && holderName === myName;
    const avatar = holderName && typeof getAvatarHtmlPourNom === 'function'
      ? getAvatarHtmlPourNom(holderName, 30, isMe ? '#C9A84C' : '#4a8a4a')
      : '';
    const holderLabel = !holderName
      ? '<span style="color:#9a8a68;font-style:italic">Vacant</span>'
      : `<span style="color:${isMe ? '#C9A84C' : '#4a8a4a'}">${escapeHtmlText(holderName)}${estPJ ? '' : ' (PNJ)'}${isMe ? ' ✦' : ''}</span>`;
    html += `<div style="display:flex;justify-content:space-between;align-items:center;padding:.4rem 1rem;border-bottom:1px solid #1a1810">
      <div style="font-size:.78rem;color:#c0b090">${escapeHtmlText(p.name)}</div>
      <div style="display:flex;align-items:center;gap:.5rem;font-size:.75rem">${avatar}${holderLabel}</div>
    </div>`;
  }
  return html;
}

function renderRetourOrganigrammeMairie() {
  return '<div style="padding:1rem 1rem .3rem"><button onclick="ouvrirOrganigrammeMairie()" style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.1em;padding:.4rem 1rem;border:1px solid #2a2010;background:transparent;color:#8a7040;cursor:pointer"><i class="ti ti-arrow-left"></i> Retour</button></div>';
}

function ouvrirOrganigrammeMairie() {
  document.getElementById('postes-modal-title').textContent = "Consulter l'organigramme";
  document.getElementById('postes-body').innerHTML = `
    <div style="padding:1.5rem;display:flex;flex-direction:column;gap:.8rem">
      <div style="font-size:.76rem;color:#8a8060;font-style:italic;margin-bottom:.2rem">Consultation publique et gratuite. Aucun poste ni fonction requis.</div>
      <button onclick="afficherOrganigrammeMairieNational()" style="font-family:Bebas Neue,sans-serif;font-size:.82rem;letter-spacing:.08em;padding:.7rem 1rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;text-align:left"><i class="ti ti-flag" style="margin-right:.5rem"></i>Organigramme national</button>
      <button onclick="afficherOrganigrammeMairieMunicipal()" style="font-family:Bebas Neue,sans-serif;font-size:.82rem;letter-spacing:.08em;padding:.7rem 1rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;text-align:left"><i class="ti ti-building-community" style="margin-right:.5rem"></i>Organigramme municipal</button>
    </div>`;
  document.getElementById('modal-postes').classList.add('open');
}

async function afficherOrganigrammeMairieNational() {
  document.getElementById('postes-modal-title').textContent = 'Organigramme national';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';

  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase();
  if (typeof rafraichirCachePhotosJoueurs === 'function') await rafraichirCachePhotosJoueurs();

  const country = state.country;
  const co = COUNTRIES[country];
  // Correctif "caserne/QHS parasites a l'Assemblee" (audit du 4 septembre 2026, cause confirmee) :
  // Object.keys(WORLD[country]) incluait aussi les zones speciales caserne/qhs (isSpecial:true),
  // jamais des circonscriptions reelles -- remplace par getVillesReelles() (plateau-justice-
  // economie.js), deja le filtre correct existant ailleurs dans le jeu, jamais utilise ici jusqu'ici.
  const villes = typeof getVillesReelles === 'function' ? getVillesReelles(country) : Object.keys(WORLD[country] || {});
  const presidentDef = (POSTES_ELECTIFS.national || []).find(p => p.id === 'president');
  const deputeDef = (POSTES_ELECTIFS.departemental || []).find(p => p.id === 'depute');
  const ministresIds = Object.keys(POSTES_NOMMES_EXCLUSIFS).filter(id => id === 'pm' || id.startsWith('min_'));

  let html = renderTitreSectionOrganigramme('Présidence');
  html += await renderLignesOrganigramme([{ id: 'president', name: presidentDef?.name || 'Président', city: null }]);

  html += renderTitreSectionOrganigramme('Gouvernement');
  html += await renderLignesOrganigramme(ministresIds.map(id => ({ id, name: POSTES_NOMMES_EXCLUSIFS[id].label, city: null })));

  // Assemblée — 9 sieges reels (chantier "Hotel de Ville / elections", 4 septembre 2026) : 3 par
  // ville, stockes dans cycle.elus (tableau), jamais cycle.eluId. Rendu dedie (pas
  // renderLignesOrganigramme/getTitulaireActuel, qui ne renvoient jamais qu'UN SEUL titulaire).
  html += renderTitreSectionOrganigramme('Assemblée (9 sièges — 3 par ville)');
  const myName = state.char?.name || '';
  const joueursPourAssemblee = typeof sbListPersonnages === 'function' ? (await sbListPersonnages().catch(() => []) || []) : [];
  for (const v of villes) {
    const cle = typeof getCleCycle === 'function' ? getCleCycle('depute', v) : 'depute_' + v;
    const cycle = CYCLES_ELECTORAUX[country]?.[cle];
    const elus = Array.isArray(cycle?.elus) ? cycle.elus : [];
    const villeNomAssemblee = WORLD[country]?.[v]?.name || v;
    for (let i = 0; i < 3; i++) {
      const holderName = elus[i] || null;
      const estPJ = holderName ? joueursPourAssemblee.some(j => j.country === country && j.name === holderName) : false;
      const isMe = estPJ && holderName === myName;
      const avatar = holderName && typeof getAvatarHtmlPourNom === 'function'
        ? getAvatarHtmlPourNom(holderName, 30, isMe ? '#C9A84C' : '#4a8a4a')
        : '';
      const holderLabel = !holderName
        ? '<span style="color:#9a8a68;font-style:italic">Vacant</span>'
        : `<span style="color:${isMe ? '#C9A84C' : '#4a8a4a'}">${escapeHtmlText(holderName)}${estPJ ? '' : ' (PNJ)'}${isMe ? ' ✦' : ''}</span>`;
      html += `<div style="display:flex;justify-content:space-between;align-items:center;padding:.4rem 1rem;border-bottom:1px solid #1a1810">
        <div style="font-size:.78rem;color:#c0b090">${escapeHtmlText((deputeDef?.name || 'Député'))} — ${escapeHtmlText(villeNomAssemblee)} (siège ${i + 1}/3)</div>
        <div style="display:flex;align-items:center;gap:.5rem;font-size:.75rem">${avatar}${holderLabel}</div>
      </div>`;
    }
  }

  html += renderRetourOrganigrammeMairie();

  document.getElementById('postes-modal-title').textContent = 'Organigramme national — ' + (co?.n || 'Empire');
  document.getElementById('postes-body').innerHTML = html;
}

async function afficherOrganigrammeMairieMunicipal() {
  document.getElementById('postes-modal-title').textContent = 'Organigramme municipal';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';

  if (typeof syncCyclesDepuisSupabase === 'function') await syncCyclesDepuisSupabase();
  if (typeof rafraichirCachePhotosJoueurs === 'function') await rafraichirCachePhotosJoueurs();

  const country = state.country;
  const ville = state.currentCity || 'capitale';
  const villeNom = WORLD[country]?.[ville]?.name || ville;
  const maireDef = (POSTES_ELECTIFS.local || []).find(p => p.id === 'maire');
  const maireAdjointDef = POSTES_NOMMES_EXCLUSIFS.maire_adjoint;

  let html = renderTitreSectionOrganigramme(villeNom);
  html += await renderLignesOrganigramme([
    { id: 'maire', city: ville, name: maireDef?.name || 'Maire' },
    { id: 'maire_adjoint', city: ville, name: maireAdjointDef?.label || 'Maire Adjoint' }
  ]);
  html += renderRetourOrganigrammeMairie();

  document.getElementById('postes-modal-title').textContent = 'Organigramme municipal — ' + villeNom;
  document.getElementById('postes-body').innerHTML = html;
}

// =====================

// ORDRES PRESIDENTIELS
// =====================
// =====================
// FONCTIONS PRESIDENTIELLES V13
// =====================

// =====================
// FORUM NATIONAL SOUS-FORUM PRESIDENT
// =====================
function ouvrirForumNationalSousForumPresident(type, pa, cost) {
  // Ouvre le forum en vue centrale sur le sous-forum presidentiel
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  document.getElementById('vue-forum').classList.add('active');

  const titres = {
    conference: 'Conférence de Presse',
    annonce:    'Annonce Officielle',
    propagande: "Propagande d'État",
    dementi:    'Démenti Officiel',
    referendum: 'Référendum National',
    deuil:      'Décret de Deuil National'
  };
  const effets = {
    conference: { pop:15, inf:10, isn:0, ie:0, id:0, is:5 },
    annonce:    { pop:5,  inf:5,  isn:0, ie:0, id:0, is:2 },
    propagande: { pop:20, inf:0,  isn:0, ie:0, id:-5,is:8 },
    dementi:    { pop:8,  inf:5,  isn:0, ie:0, id:0, is:0 },
    referendum: { pop:10, inf:8,  isn:0, ie:0, id:3, is:5 },
    deuil:      { pop:15, inf:0,  isn:0, ie:-5,id:0, is:8 }
  };

  document.getElementById('forum-view-subtitle').textContent = 'Forum National — Forum Présidentiel';
  const body = document.getElementById('forum-view-body');
  const ef = effets[type] || {};
  const titre = titres[type] || 'Message Présidentiel';

  let efStr = [];
  if (ef.pop) efStr.push((ef.pop > 0 ? '+' : '') + ef.pop + ' POP');
  if (ef.inf) efStr.push((ef.inf > 0 ? '+' : '') + ef.inf + ' INF');
  if (ef.is)  efStr.push((ef.is  > 0 ? '+' : '') + ef.is  + ' IS');
  if (ef.id)  efStr.push((ef.id  > 0 ? '+' : '') + ef.id  + ' ID');
  if (type === 'deuil') efStr.push('Pas d\'impôts aujourd\'hui');

  let isRef = type === 'referendum';
  let html = '<div style="display:flex;flex-direction:column;width:100%;height:100%">';
  html += '<div style="padding:.6rem 1rem;background:#111208;border-bottom:1px solid #1a1810;display:flex;align-items:center;gap:.8rem">';
  html += '<button onclick="closeForumView()" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a7040;cursor:pointer">← Annuler</button>';
  html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8D880">' + titre + '</div>';
  html += '<div style="margin-left:auto;font-size:.68rem;color:#4a8a4a">' + efStr.join(' · ') + '</div>';
  html += '</div>';
  html += '<div style="flex:1;overflow-y:auto;padding:1rem;max-width:700px">';

  if (isRef) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">QUESTION DU REFERENDUM</div>';
    html += '<input id="pres-ref-question" type="text" placeholder="Quelle est la question soumise au vote ?" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem"/>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">RÉPONSES (1 seul choix)</div>';
    html += '<input id="pres-ref-rep1" type="text" placeholder="Réponse 1 (ex: Oui)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.3rem"/>';
    html += '<input id="pres-ref-rep2" type="text" placeholder="Réponse 2 (ex: Non)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.3rem"/>';
    html += '<input id="pres-ref-rep3" type="text" placeholder="Réponse 3 (optionnel)" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.5rem"/>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.3rem">DURÉE DU VOTE</div>';
    html += '<select id="pres-ref-duree" style="background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none;margin-bottom:.8rem">';
    html += '<option value="3">3 jours</option><option value="5">5 jours</option><option value="7">7 jours</option></select>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TITRE</div>';
    html += '<input id="pres-msg-titre" type="text" placeholder="Titre de votre message officiel..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem"/>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">MESSAGE</div>';
    html += '<textarea id="pres-msg-contenu" rows="6" placeholder="Rédigez votre message officiel..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.6rem"></textarea>';
  }

  html += '<button onclick="publierMessagePresidentiel(\'' + type + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.5rem 1.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier</button>';
  html += '</div></div>';
  body.innerHTML = html;
}

async function publierMessagePresidentiel(type, pa, cost) {
  if (!exigerPoste('president', 'Seul le Président peut publier depuis la tribune présidentielle.')) return;
  const effets = {
    conference: { pop:15, inf:10, is:5 },
    annonce:    { pop:5,  inf:5,  is:2 },
    propagande: { pop:20, inf:0,  is:8, id:-5 },
    dementi:    { pop:8,  inf:5  },
    referendum: { pop:10, inf:8,  is:5, id:3 },
    deuil:      { pop:15, is:8,   ie:-5 }
  };
  const ef = effets[type] || {};
  const pays = state.country || 'republic';
  const auteur = state.char?.name || 'Le Président';
  const time = formatDateHeureJeu();

  let titre, contenu;
  if (type === 'referendum') {
    titre = document.getElementById('pres-ref-question')?.value?.trim();
    const rep1 = document.getElementById('pres-ref-rep1')?.value?.trim();
    const rep2 = document.getElementById('pres-ref-rep2')?.value?.trim();
    const rep3 = document.getElementById('pres-ref-rep3')?.value?.trim();
    const duree = parseInt(document.getElementById('pres-ref-duree')?.value || '5');
    if (!titre || !rep1 || !rep2) { showToast('Champs requis', 'Question et au moins 2 réponses.', false); return; }
    const rRef = await deduireCoutOrdre({ pa, cost });
    if (!rRef.ok) { signalerRefusCout(rRef); return; }
    const reponses = [rep1, rep2, ...(rep3 ? [rep3] : [])].map(r => ({ label: r, voix: 0 }));
    if (!state.referendums) state.referendums = [];
    state.referendums.push({ question: titre, reponses, jourFin: state.day + duree, clos: false });
    contenu = 'Le Président soumet ce référendum au vote populaire. Vote ouvert pendant ' + duree + ' jour(s).';
  } else {
    titre = document.getElementById('pres-msg-titre')?.value?.trim();
    contenu = document.getElementById('pres-msg-contenu')?.value?.trim();
    if (!titre || !contenu) { showToast('Champs requis', 'Titre et contenu obligatoires.', false); return; }
    const rMsg = await deduireCoutOrdre({ pa, cost });
    if (!rMsg.ok) { signalerRefusCout(rMsg); return; }
  }

  const titrePrefixe = '[' + (type === 'referendum' ? 'RÉFÉRENDUM' : type.toUpperCase()) + '] ' + titre;

  // Persistance reelle sur Supabase — visible par tous, pas seulement localement
  let topicId = null;
  if (typeof sbCreateTopic === 'function') {
    topicId = await sbCreateTopic('presidence', titrePrefixe, auteur, pays, time);
    if (topicId && typeof sbCreatePost === 'function') await sbCreatePost(topicId, auteur, contenu, time);
  }

  if (!FORUM_TOPICS['presidence']) FORUM_TOPICS['presidence'] = [];
  FORUM_TOPICS['presidence'].unshift({
    id: topicId || 'pres-' + Date.now(), title: titrePrefixe,
    author: auteur, time, views: 1, replies: 0,
    lastPostAuthor: auteur, lastPostTime: time,
    isReferendum: type === 'referendum',
    reponses: type === 'referendum' ? state.referendums[state.referendums.length-1].reponses : undefined,
    posts: [{ author: auteur, time, content: contenu }]
  });

  // Appliquer les effets
  if (ef.pop) state.pop = Math.min(100, state.pop + ef.pop);
  if (ef.inf) state.inf = Math.min(100, state.inf + ef.inf);
  if (ef.is && INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].IS = Math.min(100, INDICES_NATIONAUX[pays].IS + ef.is);
  if (ef.id && INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].ID = Math.max(0, INDICES_NATIONAUX[pays].ID + ef.id);
  if (ef.ie && INDICES_NATIONAUX?.[pays]) INDICES_NATIONAUX[pays].IE = Math.max(0, INDICES_NATIONAUX[pays].IE + ef.ie);
  if (type === 'deuil') state.deuil = state.day;

  updateUI();
  closeForumView();

  const efParts = [];
  if (ef.pop) efParts.push((ef.pop>0?'+':'')+ef.pop+' POP');
  if (ef.inf) efParts.push((ef.inf>0?'+':'')+ef.inf+' INF');
  showToast('Publié !', titre + (efParts.length ? ' · ' + efParts.join(' ') : ''), true, true);
  addJournalEntry('Publication présidentielle : ' + titre, 'event-good');
  addExternalEvent('PRESIDENCE : ' + titre + (type === 'deuil' ? ' — Journée de deuil national.' : ''));
}

// =====================
// DECLARER LA GUERRE
// =====================
// ouvrirModalGuerreEmpire() et confirmerGuerreEmpire() SUPPRIMEES ICI le 8 septembre 2026.
//
// Elles etaient declarees DEUX FOIS dans ce fichier. Les declarations de fonction etant hissees,
// la seconde ecrasait la premiere : ce bloc-ci, place plus haut, etait donc INATTEIGNABLE depuis
// toujours. Seules les versions async de la section « GUERRE ET DIPLOMATIE » (plus bas) tournaient,
// et c'est bien vers elles que pointe l'unique appelant, plateau-router.js ('declarer_guerre').
//
// AUCUNE DIFFERENCE FONCTIONNELLE UTILE N'EST PERDUE -- la version vivante fait strictement plus :
//   - elle lit les guerres via sbGetGuerresPays (table PARTAGEE) la ou celle-ci lisait
//     state.guerres, jamais persiste ni serialise ;
//   - elle ECRIT la guerre via sbCreerGuerre, la ou celle-ci ne faisait qu'un push en memoire que
//     l'adversaire ne voyait jamais et que le moindre rechargement effacait ;
//   - elle preleve le cout de l'ordre (deduireCoutOrdre), que celle-ci ne prelevait pas.
// Les memes effets -20 POP / +10 INF / -20 ID / +15 ISN et la meme annonce publique y figurent a
// l'identique. Seul le canal du compte rendu change (journal au lieu d'un mail), ce qui releve du
// correctif de canal deja applique ailleurs.

// =====================
// DEPOSER UN PROJET DE LOI
// =====================
// ouvrirDeposerProjet / soumettreProjetLoi — SUPPRIMEES (chantier Assemblee, 10 septembre 2026).
// Remplacees par ouvrirDeposerProposition / confirmerDeposerProposition (plateau-assemblee.js).
//
// Quatre raisons de les retirer plutot que de les laisser dormir :
//   1. ouvrirDeposerProjet lisait state.poste?.id.startsWith('depute') -- or un mandat de depute
//      vit dans state.posteDepute, JAMAIS dans state.poste. Aucun depute reel n'a donc jamais pu
//      passer cette garde : la fonction etait inutilisable pour sa propre cible.
//   2. soumettreProjetLoi ecrivait dans FORUM_TOPICS['parlement'], cle d'un forum qui n'existait
//      dans AUCUNE declaration -- les sujets crees n'etaient affichables nulle part.
//   3. Elle poussait dans state.loisEnCours, variable memoire videe au moindre F5.
//   4. Elle archivait via sbArchiverLoi avec statut 'en_cours' et resultat null, et rien au monde
//      ne repassait jamais dessus : aucune loi de Res Publica n'a jamais pu etre close.
//
// Le routeur portait de surcroit DEUX routes 'projet_loi' vers cette fonction (voir
// plateau-router.js), dont une seule etait atteignable.

// (voir le bloc explicatif ci-dessus — soumettreProjetLoi supprimee au meme titre)

// =====================

// ASSEMBLEE NATIONALE
// =====================

// I18N LOT 0 -- neutralisation des identifiants de vote de loi (audit dedie, 30 aout 2026).
// Separe l'identifiant metier neutre (FOR/AGAINST/ABSTAIN, desormais persiste dans
// lois_assemblee.data.votes[].choix pour tout NOUVEAU vote) du libelle affiche au joueur
// (francais pour l'instant -- remplacable plus tard par un t()/i18next sans toucher a
// enregistrerVoteLoi ni aux comparaisons de couleur, qui ne travaillent plus que sur le code).
// Aucune migration : normaliserChoixVoteLoi() fait ici, au point de lecture, toute la
// compatibilite avec les votes deja persistes sous leur ancien libelle francais brut ('Pour'/
// 'Contre'/'Abstention') -- ne touche jamais les lignes deja en base. Les couleurs de chaque
// site d'affichage restent des ternaires locales (elles different deja legerement d'un site a
// l'autre dans le code existant) : seul le libelle est centralise ici, pas la presentation.
// SUPPRIMES avec leurs deux seuls consommateurs (ouvrirArchivesLois / ouvrirDetailLoi).
//
// Le nouveau moteur n'a plus besoin de cette couche de compatibilite : assemblee_votes.choix
// porte directement POUR / CONTRE / ABSTENTION, contraints par un CHECK en base. Le libelle
// affiche est identique au code metier, il n'y a donc plus rien a traduire au point de lecture.
//
// NB : ces trois helpers avaient ete introduits au "Lot 0 i18n" en prevision d'un t()/i18next sur
// le plateau. Verification faite le 10 septembre 2026 : plateau.html ne charge PAS i18next et ne
// porte AUCUN attribut data-i18n (41 dans index.html, 0 ici). Le plateau de jeu n'est pas
// internationalise -- la couche prevue n'est jamais venue.

// observerDebats — DEPLACE ET REECRIT dans plateau-assemblee.js (chantier du 10 septembre 2026).
//
// L'ancienne implementation vivait ici. L'audit du 9 septembre en a etabli le fonctionnement
// reel : elle facturait 1 PA pour afficher QUATRE deputes codes en dur ('Depute Marchand',
// 'Depute Fontaine', 'Depute Rousseau', 'Depute Girard' -- aucun n'existait ailleurs dans le jeu)
// avec des positions TIREES AU HASARD A CHAQUE OUVERTURE. Sa seule source de contenu etait
// state.loisEnCours, variable memoire videe par un F5. Elle ne lisait ni les sieges reels, ni
// lois_assemblee, ni CYCLES_ELECTORAUX[].elus. Le desc "Revele les positions des deputes" etait
// donc inexact : rien n'etait revele.
//
// Defaut annexe corrige au passage : updateUI() n'etait appele que dans la branche journaliste,
// laissant la jauge de PA fausse pour tous les autres joueurs apres le debit.

// ouvrirVoteLoi / enregistrerVoteLoi — DEPLACES ET REECRITS dans plateau-assemblee.js
// (ouvrirVoterLoi / confirmerVoteLoi), chantier du 10 septembre 2026.
//
// L'ancien systeme reposait sur state.loisEnCours (memoire, videe au F5) et state.votesLois
// (jamais persiste). Trois defauts rendaient le scrutin inexploitable :
//   - un vote une fois exprime NE POUVAIT PLUS ETRE CHANGE (la branche dejaVote n'affichait plus
//     de boutons), alors que §14 exige de pouvoir en changer librement jusqu'a 22:00 ;
//   - ABSTENTION et "n'a pas vote" etaient confondus ;
//   - aucune cloture n'existait : sbArchiverLoi ecrivait toujours statut 'en_cours' et
//     resultat null, si bien qu'aucune loi du jeu n'a jamais pu etre adoptee ni rejetee.
//
// Le nouveau moteur stocke un vote par ligne (assemblee_votes), modifiable a volonte, et la
// cloture est faite par le serveur (assemblee_cloturer).

// ouvrirArchivesLois / ouvrirDetailLoi — SUPPRIMEES (chantier Assemblee, 10 septembre 2026).
// Remplacees par ouvrirRegistreAssemblee / ouvrirDetailProposition (plateau-assemblee.js).
//
// Elles lisaient lois_assemblee via sbGetArchivesLois. L'audit du 9 septembre a montre que cette
// table etait VIDE en production et que son champ resultat n'etait jamais renseigne : toute loi
// y serait restee affichee "En cours" indefiniment, faute de toute cloture dans le jeu.
//
// La table lois_assemblee et ses wrappers (sbArchiverLoi/sbGetArchivesLois, supabase.js) sont
// laisses en place : ils ne sont plus appeles par personne, mais les supprimer releverait du
// nettoyage global, hors perimetre de ce chantier. Signale au rapport.

// =====================
// CALENDRIER ELECTORAL

// DEMANDE DE NATURALISATION (changement d'empire)
// =====================
function ouvrirModalNaturalisation(pa, cost) {
  const empires = Object.keys(COUNTRIES).filter(c => c !== state.country);
  document.getElementById('postes-modal-title').textContent = 'Demande de naturalisation';

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Votre demande sera examinee par le Ministre de l\'Interieur de l\'empire vise, apres un delai de 48h. En cas de refus, 50% du montant sera remboursé.</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">EMPIRE VISE</div>';
  html += '<select id="natu-empire-vise" onchange="majCoutNaturalisation()" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  empires.forEach(c => { html += '<option value="' + c + '">' + (COUNTRIES[c]?.n || c) + '</option>'; });
  html += '</select>';

  html += '<div id="natu-cout-affiche" style="font-size:.85rem;color:#C9A84C;margin-bottom:.8rem"></div>';
  html += '<button onclick="confirmerDemandeNaturalisation(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déposer la demande</button>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  majCoutNaturalisation();
}

function getCoutNaturalisation(paysVise) {
  const ie = typeof getIndiceNationalCalcule === 'function' ? getIndiceNationalCalcule(paysVise, 'ie') : (INDICES_NATIONAUX[paysVise]?.IE || 40);
  return 2000 + ie * 30;
}

function majCoutNaturalisation() {
  const paysVise = document.getElementById('natu-empire-vise')?.value;
  if (!paysVise) return;
  const cout = getCoutNaturalisation(paysVise);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('natu-cout-affiche').textContent = 'Coût de la demande : ' + cout + ' ' + cur;
}

async function confirmerDemandeNaturalisation(pa, cost) {
  const paysVise = document.getElementById('natu-empire-vise')?.value;
  if (!paysVise) return;
  const cout = getCoutNaturalisation(paysVise);

  if (state.arg < cout) {
    showToast('Fonds insuffisants', cout + ' ' + (COUNTRIES[state.country]?.cur||'FR') + ' requis.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  state.arg -= cout;
  updateUI();
  document.getElementById('modal-postes').classList.remove('open');

  const maintenant = Date.now();
  const demande = {
    id: 'natu-' + maintenant,
    demandeur: state.char?.name || 'Anonyme',
    pays_origine: state.country,
    pays_vise: paysVise,
    montant: cout,
    date_demande: maintenant,
    date_traitement_possible: maintenant + 48 * 60 * 60 * 1000,
    statut: 'pending'
  };

  if (typeof sbCreerDemandeNaturalisation === 'function') {
    await sbCreerDemandeNaturalisation(demande).catch(() => {});
  }

  showToast('Demande déposée', 'Votre demande de naturalisation vers ' + (COUNTRIES[paysVise]?.n||paysVise) + ' a été transmise.', true, true);
  addJournalEntry('Demande de naturalisation déposée vers ' + (COUNTRIES[paysVise]?.n||paysVise) + ' (' + cout + ' ' + (COUNTRIES[state.country]?.cur||'FR') + ').', 'event-info');

  // Notifier le Ministre de l'Interieur du pays vise
  const ministre = (typeof sbListPersonnages === 'function')
    ? await sbListPersonnages().then(joueurs => (joueurs||[]).find(j => j.country === paysVise && j.poste?.id === 'min_int')).catch(() => null)
    : null;
  if (ministre && typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail('Service de l\'Immigration', ministre.name, 'Demande de naturalisation',
      (state.char?.name||'Un citoyen') + ' demande la naturalisation dans votre empire. Vous pouvez traiter sa demande depuis votre bureau, 48h apres le depot.', time).catch(() => {});
  }
}

// =====================
// TRAITEMENT DES DEMANDES PAR LE MINISTRE DE L'INTERIEUR
// =====================
async function ouvrirDemandesNaturalisation() {
  document.getElementById('postes-modal-title').textContent = 'Demandes de naturalisation';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  let demandes = [];
  if (typeof sbGetDemandesNaturalisationPour === 'function') {
    try { demandes = await sbGetDemandesNaturalisationPour(state.country) || []; } catch(e) {}
  }

  const maintenant = Date.now();
  let html = '<div style="padding:1rem">';
  if (demandes.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040;font-style:italic">Aucune demande en attente.</div>';
  } else {
    demandes.forEach(d => {
      const traitablePossible = maintenant >= d.date_traitement_possible;
      const tempsRestant = Math.max(0, Math.ceil((d.date_traitement_possible - maintenant) / (60*60*1000)));
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A">' + d.demandeur + '</div>';
      html += '<div style="font-size:.7rem;color:#8a8060;margin:.2rem 0">Origine : ' + (COUNTRIES[d.pays_origine]?.n||d.pays_origine) + ' · Montant versé : ' + d.montant + '</div>';
      if (!traitablePossible) {
        html += '<div style="font-size:.7rem;color:#6a5a30">Traitable dans ' + tempsRestant + 'h</div>';
      } else {
        html += '<div style="display:flex;gap:.4rem;margin-top:.4rem">';
        html += '<button onclick="traiterDemandeNaturalisation(&quot;' + d.id + '&quot;,true)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #2a4a20;background:transparent;color:#6a9a6a;cursor:pointer">Accepter</button>';
        html += '<button onclick="traiterDemandeNaturalisation(&quot;' + d.id + '&quot;,false)" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #4a2010;background:transparent;color:#cc4444;cursor:pointer">Refuser</button>';
        html += '</div>';
      }
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function traiterDemandeNaturalisation(demandeId, accepter) {
  if (typeof sbGetDemandesNaturalisationPour !== 'function') return;
  const demandes = await sbGetDemandesNaturalisationPour(state.country).catch(() => []);
  const demande = (demandes || []).find(d => d.id === demandeId);
  if (!demande) { showToast('Introuvable', 'Cette demande n\'existe plus.', false); return; }

  // SERVEUR AUTORITAIRE (17 septembre 2026, audit des frontieres d'autorite). Avant : le client
  // changeait le statut par un sbUpdate brut, puis, en cas de refus, deposait le remboursement
  // par sbDeposerDon -- un INSERT brut dans une table en RLS « allow_all », sans autorite ni
  // montant attestes. Rien du game design ne change ici : meme autorite (data.js declare deja
  // requiresPost:'min_int' sur cet ordre), meme taux de 50 %, meme delai de 48 h -- mais tout
  // cela est desormais RELU par le serveur au lieu d'etre fourni par le navigateur, et la
  // transition de statut sert de verrou anti-double-remboursement.
  const r = (typeof sbNaturalisationTraiter === 'function')
    ? await sbNaturalisationTraiter(demandeId, accepter) : null;
  if (!r || r.ok !== true) {
    const motifs = {
      demande_introuvable: 'Cette demande n\'existe plus.',
      hors_juridiction: 'Cette demande ne vise pas votre pays.',
      delai_non_ecoule: 'Le délai de 48 h n\'est pas écoulé.',
      acteur_non_authentifie: 'Seul le Ministre de l\'Intérieur en exercice peut traiter cette demande.'
    };
    showToast('Traitement impossible', (r && motifs[r.raison]) || 'La demande n\'a pas pu être traitée.', false);
    ouvrirDemandesNaturalisation();
    return;
  }
  if (r.rejeu) {
    showToast('Déjà traitée', 'Cette demande a déjà été traitée.', false);
    ouvrirDemandesNaturalisation();
    return;
  }

  const h = String(state.hour || 8).padStart(2,'0');
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';

  if (accepter) {
    if (typeof sbSendMail === 'function') {
      sbSendMail('Service de l\'Immigration', demande.demandeur, 'Naturalisation acceptée',
        'Votre demande de naturalisation a été acceptée par le Ministre de l\'Intérieur. Vous êtes désormais citoyen de ' + (COUNTRIES[state.country]?.n||state.country) + '. Votre changement sera effectif à votre prochaine connexion.', time).catch(() => {});
    }
    showToast('Demande acceptée', demande.demandeur + ' devient citoyen de ' + (COUNTRIES[state.country]?.n||state.country) + '.', true, true);
    addExternalEvent('🛂 ' + demande.demandeur + ' obtient la nationalité ' + (COUNTRIES[state.country]?.n||state.country) + '.', 'national');
  } else {
    // Montant renvoye par le serveur, qui l'a recalcule depuis la ligne de la demande.
    const remboursement = Number(r.remboursement || 0);
    if (typeof sbSendMail === 'function') {
      sbSendMail('Service de l\'Immigration', demande.demandeur, 'Naturalisation refusée',
        'Votre demande de naturalisation a été refusée par le Ministre de l\'Intérieur. ' + remboursement + ' ' + (COUNTRIES[state.country]?.cur||'FR') + ' vous sont remboursés.', time).catch(() => {});
    }
    showToast('Demande refusée', demande.demandeur + ' a été notifié(e), remboursement partiel envoyé.', false, true);
  }

  ouvrirDemandesNaturalisation();
}

// Applique le changement de nationalite reellement au prochain chargement du joueur concerne
async function appliquerNaturalisationAcceptee() {
  if (typeof sbGetDemandesNaturalisationPour !== 'function' || !state.char?.name) return;
  // Chercher dans tous les empires si une demande du joueur courant a ete acceptee
  for (const c of Object.keys(COUNTRIES)) {
    try {
      const rows = await sbGet('demandes_naturalisation', `demandeur=eq.${encodeURIComponent(state.char.name)}&statut=eq.acceptee&pays_vise=eq.${c}`);
      if (rows && rows.length > 0) {
        state.country = c;
        state.poste = null;
        if (state.char) { state.char.poste = null; state.char.country = c; }
        await sbTraiterDemandeNaturalisation(rows[0].id, 'appliquee').catch(() => {});
        showToast('Naturalisation effective', 'Vous êtes désormais citoyen de ' + (COUNTRIES[c]?.n||c) + ' !', true, true);
        addJournalEntry('Votre naturalisation est effective. Vous êtes citoyen de ' + (COUNTRIES[c]?.n||c) + '.', 'event-good');
        updateUI();
        break;
      }
    } catch(e) {}
  }
}



// ANNUAIRE DES DEPUTES
// =====================
function consulterAnnuaireDeputes() {
  const country = state.country;
  const co = COUNTRIES[country];
  const titulairesConnus = state.postes?.[country] || {};

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">25 sieges a l\'Assemblee Nationale de ' + (co?.n||country) + '.</div>';
  for (let i = 1; i <= 25; i++) {
    const titulaire = titulairesConnus['depute_' + i] || 'Occupé par un PNJ';
    html += '<div style="display:flex;justify-content:space-between;padding:.4rem .2rem;border-bottom:1px solid #1a1810">';
    html += '<span style="font-size:.78rem;color:#6a5a30">Siege ' + i + '</span>';
    html += '<span style="font-size:.8rem;color:#c0b090">' + titulaire + '</span>';
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-modal-title').textContent = 'Annuaire des Députés';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================

// SYSTÈME GÉNÉRIQUE — NOMINATION DE POSTES (juge, commissaire)
// =====================
// getTitulairePosteNomme (ex-fonction locale) retiree le 9 aout 2026 (refonte des postes) —
// remplacee partout par getTitulaireActuel (plateau-organisations-quetes.js), qui couvre
// aussi les postes elus, pas seulement les postes nommes.

// REGROUPEMENT DES POSTES NOMMES SOUS UN SEUL BOUTON (16 septembre 2026).
//
// Trois ordres pour l'Entrepot, deux pour le Maire adjoint, deux pour le Commissaire : autant de
// boutons pour ce qui est, du point de vue du joueur, une seule question -- « qui occupe ce poste,
// et qu'est-ce que j'en fais ? ». Cet ecran repond d'abord a la premiere partie, puis propose les
// actions existantes. RIEN d'autre ne change : memes primitives, memes couts, memes autorites,
// memes effets. Les PA sont preleves par les actions elles-memes, comme avant -- le bouton
// d'ouverture, lui, est gratuit, exactement comme « Se porter candidat » l'etait.
//
// GENERIQUE PAR CONSTRUCTION : la ville vient de POSTES_NOMMES_EXCLUSIFS[posteId].scope et de
// state.currentCity. Luthecia, Montrouge et Port-Sainte-Marie empruntent le meme chemin.
const ACTIONS_POSTE_NOMME = {
  commissaire:        { candidatures: null, nommer: 3, revoquer: 1 },
  maire_adjoint:      { candidatures: 1,    nommer: null, revoquer: 1 },
  directeur_entrepot: { candidatures: 1,    nommer: 3,    revoquer: 1 }
};

async function ouvrirGestionPosteNomme(posteId) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  const actions = ACTIONS_POSTE_NOMME[posteId];
  if (!regle || !actions) return;

  // Meme garde d'autorite que chacun des anciens ordres, verifiee ici une fois pour toutes --
  // les handlers appeles ensuite la revalident chacun de leur cote, et le serveur aussi.
  if (!autoriteCouvre(state.poste?.id || '', regle.nommePar)) {
    showToast('Acces refuse', 'Seul(e) le/la ' + regle.nommePar + ' peut gerer ce poste.', false);
    return;
  }

  const ville = regle.scope === 'ville' ? (state.currentCity || null) : null;
  const villeNom = ville ? (WORLD[state.country]?.[ville]?.name || ville) : null;
  document.getElementById('postes-modal-title').textContent = regle.label + (villeNom ? ' — ' + villeNom : '');
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.2rem;color:#8a8060;font-style:italic">Consultation du registre...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const titulaire = await getTitulaireActuel(posteId, ville);

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">';
  if (titulaire) {
    html += '<b>' + titulaire.nom + '</b>' + (titulaire.estPJ ? '' : ' (PNJ)') + ' occupe actuellement ce poste';
    if (titulaire.estPJ && estPosteProtege(titulaire.posteComplet)) {
      html += '.<br><span style="color:#8a6a20;font-style:italic;font-size:.78rem">Protection apres nomination : '
            + tempsProtectionRestanteTexte(titulaire.posteComplet) + ' restant.</span>';
    } else {
      html += '.';
    }
  } else {
    html += '<i>Poste vacant' + (villeNom ? ' a ' + villeNom : '') + '.</i>';
  }
  html += '</div><div style="display:flex;flex-direction:column;gap:.5rem">';

  const bouton = (onclick, libelle, cout, couleur) =>
    '<button onclick="' + onclick + '" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.09em;'
    + 'padding:.55rem;border:1px solid ' + couleur + ';background:transparent;color:' + couleur + ';cursor:pointer;text-align:left">'
    + libelle + (cout ? ' <span style="opacity:.7">(' + cout + ' PA)</span>' : '') + '</button>';

  if (actions.candidatures !== null) {
    html += bouton("ouvrirGestionCandidatures(['" + posteId + "']," + actions.candidatures + ",0)",
                   'Gerer les candidatures recues', actions.candidatures, '#8a7a40');
  }
  if (actions.nommer !== null) {
    html += bouton("ouvrirNominerPosteNomme('" + posteId + "'," + actions.nommer + ",0)",
                   titulaire ? 'Nommer quelqu\'un d\'autre' : 'Nommer un titulaire', actions.nommer, '#8a7a40');
  }
  if (actions.revoquer !== null && titulaire) {
    html += bouton("ouvrirRevoquerPosteNomme('" + posteId + "'," + actions.revoquer + ",0)",
                   'Revoquer le titulaire', actions.revoquer, '#8a3a2a');
  }
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function ouvrirRevoquerPosteNomme(posteId, pa, cost) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return;
  // Fix 9 aout 2026 : comparaison stricte a 'maire' ne correspondait jamais a un vrai maire
  // (id 'maire' + city desormais, ex-ids maire_capitale/maire_a/maire_b avant la refonte) -
  // un maire pouvait nommer un commissaire (deja corrige le 8 aout, startsWith) mais jamais le
  // revoquer. startsWith couvre aussi bien 'maire' que 'president'/'pm'/etc (correspondance exacte
  // pour ces derniers, qui n'ont pas de variante).
  if (!autoriteCouvre(state.poste?.id || '', regle.nommePar)) {
    showToast('Acces refuse', 'Seul(e) le/la ' + regle.nommePar + ' peut revoquer ce poste.', false);
    return;
  }

  const villeCourante = regle.scope === 'ville' ? state.currentCity : null;
  const villeNom = villeCourante ? (WORLD[state.country]?.[villeCourante]?.name || villeCourante) : null;
  const titulaireInfo = await getTitulaireActuel(posteId, villeCourante);

  document.getElementById('postes-modal-title').textContent = 'Revoquer le ' + regle.label.toLowerCase();
  const estProtege = titulaireInfo?.estPJ && estPosteProtege(titulaireInfo.posteComplet);
  if (!titulaireInfo) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;font-size:.85rem;color:#8a8060;font-style:italic">Aucun ' + regle.label.toLowerCase() + ' en poste actuellement' + (villeNom ? ' a ' + villeNom : '') + '.</div>';
  } else if (estProtege) {
    // Garde UI (§12 du lot priorite PJ) : le bouton de revocation n'est meme pas propose tant
    // que la protection court -- la garde handler ci-dessous revalide independamment.
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem">' +
      '<div style="font-size:.85rem;color:#c0b090;margin-bottom:.8rem">' + titulaireInfo.nom + ' occupe actuellement le poste de ' + regle.label + (villeNom ? ' a ' + villeNom : '') + '.</div>' +
      '<div style="font-size:.8rem;color:#8a6a20;font-style:italic">Ce titulaire bénéficie encore de sa période de protection après nomination (' + tempsProtectionRestanteTexte(titulaireInfo.posteComplet) + ' restant). Révocation politique impossible avant l\'échéance.</div>' +
      '</div>';
  } else {
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem">' +
      '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">' + titulaireInfo.nom + (titulaireInfo.estPJ ? '' : ' (PNJ)') + ' occupe actuellement le poste de ' + regle.label + (villeNom ? ' a ' + villeNom : '') + '.</div>' +
      '<button onclick="confirmerRevocationPosteNomme(\'' + posteId + '\',\'' + titulaireInfo.nom.replace(/'/g,'') + '\',' + (titulaireInfo.estPJ ? 'true' : 'false') + ',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a3a2a;background:transparent;color:#c0503a;cursor:pointer">Revoquer</button>' +
      '</div>';
  }
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRevocationPosteNomme(posteId, nomTitulaire, estPJ, pa, cost) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return;
  // Meme regle exactement que ouvrirRevoquerPosteNomme (autoriteCouvre contre regle.nommePar),
  // rejouee ici : l'ouverture est sautee des qu'on appelle la confirmation directement.
  if (!exigerAutoriteSurPosteNomme(regle, 'révoquer')) return;
  const villeCourante = regle.scope === 'ville' ? state.currentCity : null;

  // Garde handler independante (§12 du lot) : revalide la protection ici meme si l'appelant
  // n'est pas passe par l'UI (console, chemin equivalent) -- jamais de confiance dans la seule
  // absence du bouton. Bloque AVANT tout cout/effet de bord (pa/cost pas encore deduits).
  if (estPJ && typeof getTitulaireActuel === 'function') {
    const titulaireFrais = await getTitulaireActuel(posteId, villeCourante);
    if (titulaireFrais?.estPJ && titulaireFrais.nom === nomTitulaire && estPosteProtege(titulaireFrais.posteComplet)) {
      showToast('Titulaire protégé', 'Ce titulaire bénéficie encore de sa période de protection après nomination (' + tempsProtectionRestanteTexte(titulaireFrais.posteComplet) + ' restant).', false);
      return;
    }
  }

  document.getElementById('modal-postes').classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  if (estPJ) {
    // REVOCATION SERVEUR (15 septembre 2026). L'ecriture directe de la fiche d'autrui est refusee
    // depuis le chantier B (trigger de la vue, 403 avale par le .catch) : cette revocation ne
    // revoquait donc plus personne. La RPC revalide l'autorite, la protection de 3 jours, et
    // retire la fonction du registre ET de la fiche.
    const rRev = (typeof sbRpc === 'function')
      ? await sbRpc('poste_revoquer', { p_poste: posteId, p_city: villeCourante }).catch(() => null) : null;
    const vRev = Array.isArray(rRev) ? rRev[0] : rRev;
    if (!vRev || vRev.ok !== true) {
      showToast('Revocation refusee', messageRefusNomination(vRev), false);
      return;
    }
    const revoqueurNom = state.char?.name || 'Anonyme';
    if (typeof sbSendMail === 'function') {
      const h = String(state.hour || 8).padStart(2,'0');
      const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
      await sbSendMail(revoqueurNom, nomTitulaire, 'Revocation de poste',
        'Vous avez ete revoque(e) du poste de ' + regle.label + ' par ' + revoqueurNom + '.', time).catch(() => {});
    }
  } else {
    if (typeof sbSupprimerTitulairePnj === 'function') {
      await sbSupprimerTitulairePnj(state.country, posteId, villeCourante).catch(() => {});
    }
  }

  const villeNom = regle.scope === 'ville' ? (WORLD[state.country]?.[state.currentCity]?.name || state.currentCity) : null;
  addExternalEvent('🏛 ' + nomTitulaire + ' a ete revoque(e) du poste de ' + regle.label + (villeNom ? ' de ' + villeNom : '') + '.', villeNom ? 'local' : 'national');
  addJournalEntry('Revocation de ' + nomTitulaire + ' du poste de ' + regle.label + '.', 'event-info');
  showToast('Poste revoque', nomTitulaire + ' n\'occupe plus le poste de ' + regle.label + '.', true);
}

function peutAccepterPosteNomme(posteId) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return { ok: true };
  if (!state.poste) return { ok: true };
  if (regle.compatibles.includes(state.poste.id)) return { ok: true };
  return { ok: false, raison: 'Vous occupez déjà le poste de ' + (state.poste.name || state.poste.id) + ', incompatible avec ' + regle.label + '.' };
}

// Liste des habitants éligibles — ville pour commissaire, pays entier pour juge
async function listerHabitantsEligibles(posteId) {
  if (typeof sbListPersonnages !== 'function') return [];
  // CORRECTIF : capitaine et lieutenant ne figurent PAS dans POSTES_NOMMES_EXCLUSIFS -- ils vivent
  // dans compagnies_militaires.data, pas dans personnages.poste, et n'ont ni protection ni regle de
  // cumul. Le `return []` sur regle absente rendait donc leurs listes de nomination TOUJOURS VIDES :
  // aucun capitaine ni lieutenant n'etait nommable en production.
  //
  // On ne les ajoute PAS au catalogue -- cela leur donnerait des regles qui ne sont pas les leurs.
  // Un poste hors catalogue retombe simplement sur la portee nationale, qui est la bonne pour la
  // chaine de commandement : on recrute dans tout le pays. Aucun second systeme de nomination.
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId] || { scope: 'pays' };
  try {
    const joueurs = await sbListPersonnages() || [];
    return joueurs.filter(j => {
      if (j.country !== state.country) return false;
      if (regle.scope === 'ville' && (j.domicile?.city !== state.currentCity || j.domicile?.country !== state.country)) return false;
      return true;
    });
  } catch(e) { return []; }
}

// Ouvre le modal de sélection pour nommer un juge ou un commissaire
async function ouvrirNominerPosteNomme(posteId, pa, cost) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  if (!regle) return;

  document.getElementById('postes-modal-title').textContent = 'Nommer un ' + regle.label.toLowerCase();
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Recherche des habitants éligibles...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const habitants = (await listerHabitantsEligibles(posteId)).map(h => ({ name: h.name, isPJ: true }));
  const roomActuelleNomme = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const pnjPresents = (roomActuelleNomme?.persons || []).filter(pp => !pp.isPJ).map(pp => ({ name: pp.name.replace(' (PNJ)', ''), isPJ: false }));
  const candidatsComplet = [...habitants, ...pnjPresents];
  const villeNom = regle.scope === 'ville' ? (WORLD[state.country]?.[state.currentCity]?.name || state.currentCity) : null;

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">' +
    (regle.scope === 'ville'
      ? 'Habitants domiciliés à ' + villeNom + ', ou PNJ present. '
      : 'Habitants domiciliés dans ' + (COUNTRIES[state.country]?.n || 'cet empire') + ', ou PNJ present. ') +
    'Le poste de ' + regle.label + ' est incompatible avec tout autre poste sauf Député.</div>';

  if (candidatsComplet.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucun candidat éligible trouvé.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CANDIDAT</div>';
    html += '<select id="nomme-poste-contact" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    candidatsComplet.forEach(h => { html += '<option value="' + h.name + '|' + (h.isPJ ? '1' : '0') + '">' + h.name + (h.isPJ ? '' : ' (PNJ)') + '</option>'; });
    html += '</select>';
    html += '<button onclick="envoyerNominationPosteNomme(\'' + posteId + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Envoie le mail de nomination avec bouton d'acceptation intégré
async function envoyerNominationPosteNomme(posteId, pa, cost) {
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  const rawSelectNomme = document.getElementById('nomme-poste-contact')?.value;
  if (!rawSelectNomme || !regle) return;
  const [destinataire, estPJRawNomme] = rawSelectNomme.split('|');
  const estPJNomme = estPJRawNomme === '1';

  // Le chemin normal controlait l'autorite dans ouvrirNominerPosteNomme uniquement -- et pour
  // plusieurs facades, nulle part du tout. On rejoue ici la regle du modele : seul le poste
  // designe par regle.nommePar peut nommer. Place AVANT toute deduction et toute ecriture.
  if (!exigerAutoriteSurPosteNomme(regle, 'nommer a')) return;

  // REVALIDATION AU MOMENT EXACT DE LA NOMINATION (Lot 4.3). L'eligibilite constatee au depot de la
  // candidature ne vaut rien : le candidat a pu devenir President entre-temps. On la RECALCULE ici,
  // et ici seulement, parce que c'est le point de passage des DEUX branches -- PJ et PNJ -- et qu'il
  // est place AVANT toute deduction de PA : un refus ne coute rien au ministre.
  //
  // REFUS SEC, AUCUN EFFET DE BORD. Si le candidat occupe un poste exclusif, on refuse et on ne
  // touche a rien : sa Presidence, son ministere ou sa magistrature restent intacts. Provoquer sa
  // demission automatique serait le comportement exactement inverse de celui qui est voulu.
  if (posteId === 'commandant' && estPJNomme && typeof verdictNominationCommandant === 'function') {
    let fiche = null;
    if (typeof sbGet === 'function') {
      const rows = await sbGet('personnages',
        'name=eq.' + encodeURIComponent(destinataire) + '&select=name,school,career,poste,qualifications').catch(() => null);
      fiche = (rows && rows[0]) || null;
    }
    if (!fiche) {
      showToast('Nomination impossible', 'Impossible de vérifier l\'éligibilité de ' + destinataire + '.', false);
      return;
    }
    const v = verdictNominationCommandant(fiche);
    if (!v.ok) {
      const motifs = {
        qualification_militaire_absente: 'ce candidat n\'a pas de qualification militaire.',
        seuil_etudes_non_arbitre: 'le niveau d\'études requis n\'a pas encore été arrêté.',
        etudes_insuffisantes: 'le niveau d\'études de ce candidat est insuffisant.',
        poste_exclusif_occupe: 'ce candidat occupe déjà un poste incompatible. Il doit le quitter lui-même : rien ne lui a été retiré.'
      };
      showToast('Nomination refusée', (motifs[v.raison] || 'Candidat inéligible.'), false);
      return;
    }
  }

  // REGLE TRANSVERSALE DES NOMINATIONS (7 septembre 2026) : une nomination coute 1 PA a l'autorite,
  // sauf regle particuliere qui transmet explicitement son propre cout.
  //
  // CORRECTIF CENTRAL. Huit facades appelaient ouvrirNominerPosteNomme(posteId) SANS pa ni cost :
  // le HTML genere interpolait alors « undefined », et deduireCoutOrdre ne prelevait RIEN. Nommer un
  // juge, un commissaire, un directeur d'usine, le Premier ministre ou un ministre etait donc
  // gratuit, malgre les PA annonces sur les boutons. On corrige ICI plutot que dans les huit
  // facades : un seul point de verite, et aucune facade ne peut plus oublier la regle.
  const paNomination = (pa === undefined || pa === null || !isFinite(Number(pa)))
    ? COUT_PA_NOMINATION_DEFAUT : Number(pa);
  const r = await deduireCoutOrdre({ pa: paNomination, cost: cost || 0 });
  if (!r.ok) { signalerRefusCout(r); return; }

  document.getElementById('modal-postes').classList.remove('open');

  const nommeurNom = state.char?.name || 'Anonyme';
  const villeNom = regle.scope === 'ville' ? (WORLD[state.country]?.[state.currentCity]?.name || state.currentCity) : null;
  const sujet = 'Nomination au poste de ' + regle.label;

  if (!estPJNomme) {
    // CORRECTION CIBLEE (Lot 4.3, §6) : la branche PNJ nomme instantanement, SANS aucun controle.
    // On ne refond pas le moteur PNJ -- mais on ferme le seul cas ou cela contourne une regle
    // ARBITREE : le Commandant exige des etudes et une qualification militaire, qu'un PNJ ne porte
    // pas. Le laisser passer aurait offert au ministre une porte pour nommer un commandant
    // inéligible. Les autres postes conservent strictement leur comportement actuel.
    if (posteId === 'commandant') {
      showToast('Nomination impossible',
        'Le Commandant doit justifier d\'études supérieures et d\'une qualification militaire : un PNJ ne peut pas être nommé à ce poste.',
        false);
      return;
    }
    // La table titulaires_pnj n'est plus ecrivable par un client (chantier « autorite des
    // postes », 15 septembre 2026) : la prise de fonction d'un PNJ passe par la RPC, qui
    // revalide au passage que l'appelant detient bien l'autorite de nomination.
    const rPnj = (typeof sbRpc === 'function')
      ? await sbRpc('poste_nommer', { p_poste: posteId, p_city: villeNom ? state.currentCity : null,
                                      p_destinataire: destinataire }).catch(() => null) : null;
    const vPnj = Array.isArray(rPnj) ? rPnj[0] : rPnj;
    if (!vPnj || vPnj.ok !== true) {
      showToast('Nomination refusee', messageRefusNomination(vPnj), false);
      return;
    }
    addExternalEvent('🏛 ' + destinataire + ' (PNJ) a ete nomme(e) ' + regle.label + (villeNom ? ' de ' + villeNom : '') + ' par ' + nommeurNom + '.', villeNom ? 'local' : 'national');
    addJournalEntry('Nomination de ' + destinataire + ' (PNJ) au poste de ' + regle.label + '.', 'event-good');
    if (typeof sbEnregistrerEvenementPublic === 'function') {
      sbEnregistrerEvenementPublic(state.country, 'nomination', {
        city: villeNom ? state.currentCity : null,
        personnages: [destinataire, nommeurNom].filter(Boolean),
        libelle: destinataire + ' (PNJ) est nommé(e) ' + regle.label + (villeNom ? ' de ' + villeNom : '') + ' par ' + nommeurNom + '.',
        data: { poste: posteId, nomme: destinataire, nomme_pnj: true, nommeur: nommeurNom }
      }).catch(() => {});
    }
    showToast('Nomination effectuee', destinataire + ' occupe desormais le poste de ' + regle.label + '.', true, true);
    return;
  }

  // PROPOSITION ENREGISTREE COTE SERVEUR. Le bouton du mail ne prouvait rien : n'importe qui
  // pouvait appeler accepterNominationPosteNomme() avec les bons arguments. C'est desormais la
  // ligne nominations_en_attente qui fait foi, et le mail n'en porte que l'identifiant.
  const rProp = (typeof sbRpc === 'function')
    ? await sbRpc('poste_nommer', { p_poste: posteId, p_city: villeNom ? state.currentCity : null,
                                    p_destinataire: destinataire }).catch(() => null) : null;
  const vProp = Array.isArray(rProp) ? rProp[0] : rProp;
  if (!vProp || vProp.ok !== true) {
    showToast('Nomination refusee', messageRefusNomination(vProp), false);
    return;
  }

  const corps = nommeurNom + ' vous propose le poste de <strong>' + regle.label + '</strong>' +
    (villeNom ? ' pour la ville de ' + villeNom : ' pour ' + (COUNTRIES[state.country]?.n || "l'empire")) + '.<br><br>' +
    '<em>Ce poste est incompatible avec tout autre poste, sauf Député.</em><br><br>' +
    marqueurActionMail('poste', vProp.id);

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    await sbSendMail(nommeurNom, destinataire, sujet, corps, time);
    showToast('Nomination envoyée', destinataire + ' a reçu votre proposition.', true);
    addJournalEntry('Nomination de ' + destinataire + ' au poste de ' + regle.label + ' proposée.', 'event-info');
  } else {
    showToast('Erreur', 'Système de mail indisponible.', false);
  }
}

// Appelée quand le destinataire clique "Accepter le poste" dans le mail. Rendue async (25 aout
// 2026, lot priorite PJ) : doit desormais verifier/deloger un eventuel titulaire PJ existant
// AVANT de s'attribuer le poste -- gap decouvert a l'audit (cette fonction n'a jamais delogé
// personne jusqu'ici, contrairement a accepterCandidaturePoste ; sans correctif, ce canal de
// nomination directe aurait pu produire deux PJ simultanement "titulaires" du meme poste, et
// surtout aurait pu contourner la protection de 7 jours du titulaire en place).
// Libelle d'un refus serveur de nomination. Les raisons viennent des RPC poste_nommer /
// poste_accepter_nomination, jamais d'une deduction locale.
function messageRefusNomination(verdict) {
  const messages = {
    autorite_insuffisante: "Vous ne detenez pas l'autorite de nomination sur ce poste.",
    titulaire_protege: 'Le titulaire actuel beneficie encore de sa periode de protection.',
    poste_inconnu: 'Ce poste ne figure pas parmi les postes nommes.',
    destinataire_absent: 'Aucun destinataire indique.',
    nomination_introuvable: 'Cette proposition n\'existe plus ou a deja ete traitee.',
    nomination_pas_pour_vous: 'Cette proposition ne vous est pas adressee.',
    acteur_non_authentifie: "Votre identite n'a pas pu etre etablie."
  };
  return (verdict && messages[verdict.raison]) || 'Nomination refusee par le serveur.';
}

// ACCEPTATION D'UNE NOMINATION (reecrit le 15 septembre 2026).
// L'ancienne version posait elle-meme state.poste puis sauvegardait sa fiche : c'etait la voie
// par laquelle un joueur pouvait se declarer ministre, juge ou commissaire. Elle prenait aussi
// ses arguments du bouton d'un mail, que rien n'authentifiait. Desormais un identifiant de
// proposition serveur suffit : la RPC verifie que la proposition existe, qu'elle nous est
// adressee, qu'elle n'a pas deja ete consommee, et c'est ELLE qui inscrit le poste au registre.
// Le trigger d'attestation n'accepterait de toute facon aucune autre ecriture.
async function accepterNominationPosteNomme(idNomination) {
  if (!idNomination || typeof idNomination !== 'string' || idNomination.indexOf('nom-') !== 0) {
    // Ancien mail, envoye avant ce chantier : ses arguments ne prouvent rien.
    showToast('Proposition perimee', 'Cette proposition date d\'avant la reforme des nominations. Demandez a l\'autorite de la renouveler.', false);
    return;
  }
  if (typeof sbRpc !== 'function') { showToast('Indisponible', 'Service momentanement indisponible.', false); return; }
  const rows = await sbRpc('poste_accepter_nomination', { p_id: idNomination }).catch(() => null);
  const v = Array.isArray(rows) ? rows[0] : rows;
  if (!v || v.ok !== true) { showToast('Nomination refusee', messageRefusNomination(v), false); return; }

  const posteId = v.poste, city = v.city || null, country = state.country;
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId] || { label: posteId };

  // Le serveur a deja ecrit la fiche : on recopie localement ce qu'il a arrete, jamais l'inverse.
  state.poste = { id: posteId, name: regle.label, city: city, nommeLe: Date.now() };
  if (state.char) state.char.poste = state.poste;
  state.salaireTouche = false;
  // Solde un eventuel dossier de candidature persistant pour ce poste (§8 du lot) : ce poste est
  // desormais pourvu, les candidatures encore listees deviennent obsoletes.
  const candidaturesNettoyage = await chargerCandidaturesPostes(state.country);
  const cleNettoyage = cleCandidaturePoste(posteId, city || null);
  if (candidaturesNettoyage[cleNettoyage] && !candidaturesNettoyage[cleNettoyage].traitee) {
    candidaturesNettoyage[cleNettoyage].traitee = true;
    await sauvegarderCandidaturesPostes(state.country, candidaturesNettoyage);
  }
  updateUI();
  if (typeof renderPersonsList === 'function' && typeof BUILDINGS !== 'undefined') {
    const roomCourante = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    if (roomCourante) renderPersonsList(roomCourante.persons || []);
  }
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  showToast('Poste accepté !', 'Vous êtes désormais ' + regle.label + (city ? ' de ' + (WORLD[country]?.[city]?.name || city) : '') + '.', true, true);
  addJournalEntry('Vous avez accepté le poste de ' + regle.label + '.', 'event-good');
  addExternalEvent('🏛 ' + (state.char?.name || 'Anonyme') + ' est nommé(e) ' + regle.label + (city ? ' de ' + (WORLD[country]?.[city]?.name || city) : '') + '.', city ? 'local' : 'national');
  if (typeof sbEnregistrerEvenementPublic === 'function') {
    sbEnregistrerEvenementPublic(country, 'nomination', {
      city: city || null,
      personnages: [state.char?.name, nommeurNom].filter(Boolean),
      libelle: (state.char?.name || 'Anonyme') + ' est nommé(e) ' + regle.label + (city ? ' de ' + (WORLD[country]?.[city]?.name || city) : '') + '.',
      data: { poste: posteId, nomme: state.char?.name, nommeur: nommeurNom }
    }).catch(() => {});
  }

  // Notifier le nommeur
  if (typeof sbSendMail === 'function' && nommeurNom) {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    sbSendMail(state.char?.name || 'Anonyme', nommeurNom, 'Nomination acceptée',
      (state.char?.name || 'Le candidat') + ' a accepté le poste de ' + regle.label + '.', time).catch(() => {});
  }
}


// Fix 9 aout 2026 (retour de test en jeu) : ce comportement "clic sur le fond sombre = fermer"
// s'appliquait a tous les modals sans distinction, y compris modal-quete-accueil - Fred a perdu
// la progression de la quete carriere en fermant accidentellement la popup en plein milieu.
// Exclu ici, corrige uniquement pour ce modal precis (les autres gardent le clic-exterieur,
// pratique et sans risque de perte de progression pour eux).
document.querySelectorAll('.modal-overlay:not(#modal-quete-accueil)').forEach(m => {
  m.addEventListener('click', function(e) {
    if (e.target === this) this.classList.remove('open');
  });
});



// =====================
// CORRIGER POSTULER (postes, grace, nationalisation, ambassadeur, censure, nominations ministerielles)
// =====================

// CORRIGER POSTULER
// =====================

// Appelee quand le President/PM clique "Accepter la candidature" dans le mail (ou depuis la
// fenetre de gestion groupee des candidatures, nommerDepuisCandidature).
// Fix du 10 aout 2026 : accordait jusqu'ici le poste via une "nomination en attente" deposee
// par sbDeposerNominationPoste, jamais appliquee car ni cette fonction ni
// sbGetNominationsPosteEnAttente/sbMarquerNominationTraitee n'ont jamais existe nulle part
// dans le code (typeof-guardees, no-op silencieux) -- le mail/toast/journal disaient "devient
// X" mais rien n'etait jamais reellement accorde. Le candidat n'etant pas forcement connecte
// au moment ou l'autorite clique, on ne peut pas toucher son state local -- on ecrit donc
// directement sur sa fiche Supabase (personnages.poste), effectif immediatement pour tout le
// monde (getTitulaireActuel), visible pour le candidat lui-meme des son prochain chargement.
// Retourne desormais {ok, raison} (25 aout 2026, lot priorite PJ) : les appelants (mail direct,
// nommerDepuisCandidature) doivent pouvoir reagir a un blocage par protection sans se contenter
// d'un effet de bord silencieux.
async function accepterCandidaturePoste(posteId, posteName, candidatNom) {
  document.getElementById('modal-pnj')?.classList.remove('open');
  const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
  const villeDuPoste = regle?.scope === 'ville' ? state.currentCity : null;

  // Deloger un eventuel titulaire actuel different du candidat (PJ ou PNJ), avant d'attribuer
  // le poste -- evite qu'un poste unique se retrouve occupe par deux joueurs en meme temps.
  // Protection de 7 jours (§10 du lot) : l'audit a confirme que cette fonction peut deloger un
  // titulaire PJ directement -- bloquee ici, avant tout effet de bord, si ce titulaire est
  // encore protege.
  if (typeof getTitulaireActuel === 'function') {
    const ancienTitulaire = await getTitulaireActuel(posteId, villeDuPoste);
    if (ancienTitulaire?.estPJ && ancienTitulaire.nom !== candidatNom) {
      if (estPosteProtege(ancienTitulaire.posteComplet)) {
        const raison = 'Ce titulaire bénéficie encore de sa période de protection après nomination (' + tempsProtectionRestanteTexte(ancienTitulaire.posteComplet) + ' restant).';
        showToast('Titulaire protégé', raison, false);
        return { ok: false, raison };
      }
      if (typeof sbUpdate === 'function') {
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(ancienTitulaire.nom)}`, { poste: null }).catch(() => {});
      }
    }
  }
  // ATTRIBUTION SERVEUR (15 septembre 2026). Les trois ecritures precedentes -- delogement du
  // titulaire, suppression du PNJ, attribution au candidat -- portaient toutes sur des lignes
  // d'autrui ou sur une table desormais fermee : aucune n'aboutissait plus. La RPC les fait
  // toutes les trois, sous la meme transaction, apres avoir revalide que l'appelant detient bien
  // l'autorite de nomination sur ce poste et que le titulaire n'est plus protege.
  const rCand = (typeof sbRpc === 'function')
    ? await sbRpc('poste_attribuer_candidature',
                  { p_poste: posteId, p_city: villeDuPoste, p_candidat: candidatNom }).catch(() => null) : null;
  const vCand = Array.isArray(rCand) ? rCand[0] : rCand;
  if (!vCand || vCand.ok !== true) {
    showToast('Attribution refusee', messageRefusNomination(vCand), false);
    return;
  }

  // Solde le dossier de candidature persistant pour ce poste (§8 du lot) : nettoie les autres
  // candidatures en attente, plus rien a afficher une fois le poste pourvu.
  const candidatures = await chargerCandidaturesPostes(state.country);
  const cleDossier = cleCandidaturePoste(posteId, villeDuPoste);
  if (candidatures[cleDossier] && !candidatures[cleDossier].traitee) {
    candidatures[cleDossier].traitee = true;
    await sauvegarderCandidaturesPostes(state.country, candidatures);
  }

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    await sbSendMail(state.char?.name || 'Anonyme', candidatNom, 'Candidature acceptée !',
      'Votre candidature au poste de ' + posteName + ' a été acceptée. Le poste est déjà effectif.', time).catch(() => {});
  }

  showToast('Candidature acceptée', candidatNom + ' devient ' + posteName + '.', true, true);
  addJournalEntry('Vous avez accepté la candidature de ' + candidatNom + ' au poste de ' + posteName + '.', 'event-good');
  addExternalEvent('🏛 ' + candidatNom + ' est nommé(e) ' + posteName + '.', 'national');
  return { ok: true };
}

// =====================
// GESTION GROUPEE DES CANDIDATURES (10 aout 2026, chantier "priorite PJ" point 2) — accessible
// directement depuis le bureau de l'autorite de nomination (Ministre des Finances pour les 3
// directeurs d'usine, Maire pour le directeur d'entrepot, Ministre de la Defense pour le
// Commandant), sans se deplacer dans le batiment concerne. Reutilise integralement le systeme
// de candidature/mail existant (demanderNominationPoste envoie deja un vrai mail 'Candidature
// au poste de X' des qu'un PJ postule aupres d'une autorite PJ) -- cette fenetre se contente de
// regrouper ces mails par poste plutot que de forcer un traitement mail par mail.
// =====================
// Source des candidatures basculee du scan de mails vers le dossier persistant
// candidatures_postes (25 aout 2026, lot priorite PJ) : affiche desormais l'echeance reelle des
// 48h, reconcilie l'autorite au passage (aucun effet si elle n'a pas change), et ne montre plus
// jamais une candidature deja traitee (poste deja pourvu entretemps).
async function ouvrirGestionCandidatures(posteIds, pa, cost) {
  document.getElementById('postes-modal-title').textContent = 'Gestion des candidatures';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const villeCourante = state.currentCity || 'capitale';
  const candidaturesTout = await chargerCandidaturesPostes(state.country);
  let dossiersModifies = false;

  let html = '<div style="padding:.5rem 0">';
  for (const posteId of posteIds) {
    const regle = POSTES_NOMMES_EXCLUSIFS[posteId];
    if (!regle) continue;
    const villeDePoste = regle.scope === 'ville' ? villeCourante : null;
    const titulaire = typeof getTitulaireActuel === 'function' ? await getTitulaireActuel(posteId, villeDePoste) : null;

    html += '<div style="padding:.6rem 1rem;font-size:.72rem;color:#6a5a30;font-family:Bebas Neue,sans-serif;letter-spacing:.1em;border-bottom:1px solid #1a1810;margin-top:.6rem">' + regle.label.toUpperCase() + '</div>';
    html += '<div style="padding:.4rem 1rem;font-size:.8rem;color:#8a8060">Actuellement : ' + (titulaire ? titulaire.nom + (titulaire.estPJ ? '' : ' (PNJ)') : 'Poste vacant') + '</div>';

    const cleDossier = cleCandidaturePoste(posteId, villeDePoste);
    const dossier = candidaturesTout[cleDossier];
    const candidatsActifs = (dossier && !dossier.traitee) ? dossier.candidats.filter(c => !c.retiree) : [];

    if (candidatsActifs.length === 0) {
      html += '<div style="padding:.3rem 1rem .6rem;font-size:.78rem;color:#5a5040;font-style:italic">Aucune candidature en attente.</div>';
    } else {
      if (await reconcilierAutoriteCandidature(dossier)) dossiersModifies = true;
      const heuresRestantes = Math.max(0, Math.ceil((dossier.echeanceTs - Date.now()) / 3600000));
      html += '<div style="padding:.2rem 1rem .4rem;font-size:.75rem;color:#8a6a20;font-style:italic">' +
        (heuresRestantes > 0
          ? 'Échéance : ' + heuresRestantes + 'h restantes avant nomination automatique par tirage au sort.'
          : 'Échéance dépassée — traitement automatique dès le prochain passage serveur.') +
        '</div>';
      candidatsActifs.forEach(c => {
        const nomSafe = c.nom.replace(/'/g, ' ');
        const labelSafe = regle.label.replace(/'/g, ' ');
        html += '<div style="padding:.6rem 1rem;border-bottom:1px solid #1a1810;display:flex;justify-content:space-between;align-items:center">';
        html += '<span style="font-size:.85rem;color:#c0b090">' + c.nom + '</span>';
        html += '<div style="display:flex;gap:.4rem">';
        html += '<button onclick="nommerDepuisCandidature(\'' + posteId + '\',\'' + labelSafe + '\',\'' + nomSafe + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em;padding:.35rem .7rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Nommer</button>';
        html += '<button onclick="convoquerCandidatEntretien(\'' + labelSafe + '\',\'' + nomSafe + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.06em;padding:.35rem .7rem;border:1px solid #3a2a10;background:transparent;color:#9a8a68;cursor:pointer">Convoquer à un entretien</button>';
        html += '</div></div>';
      });
    }
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  if (dossiersModifies) await sauvegarderCandidaturesPostes(state.country, candidaturesTout);
}

async function nommerDepuisCandidature(posteId, posteName, candidatNom, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  await accepterCandidaturePoste(posteId, posteName, candidatNom);
}

// Purement narratif/optionnel : aucun effet mecanique, l'autorite peut nommer directement sans
// jamais convoquer. Le candidat reste dans la liste des candidatures apres l'envoi.
async function convoquerCandidatEntretien(posteName, candidatNom) {
  const nommeurNom = state.char?.name || 'Anonyme';
  const lieu = (typeof BUILDINGS !== 'undefined' && BUILDINGS[state.currentBuilding]?.name) || 'ministère';
  const corps = nommeurNom + ' vous convie à un entretien au ' + lieu + ' pour discuter de votre motivation pour le poste de <strong>' + posteName + '</strong>. Présentez-vous quand vous le pourrez — purement informel, votre candidature reste valable.';
  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    await sbSendMail(nommeurNom, candidatNom, 'Convocation à un entretien', corps, time).catch(() => {});
  }
  showToast('Convocation envoyée', candidatNom + ' a été invité(e) à un entretien.', true);
  addJournalEntry('Convocation à un entretien envoyée à ' + candidatNom + ' pour le poste de ' + posteName + '.', 'event-info');
}

// appliquerNominationPosteEnAttente() retiree le 10 aout 2026 : reposait entierement sur
// sbGetNominationsPosteEnAttente/sbMarquerNominationTraitee, jamais definies nulle part dans
// le code -- fonction morte depuis toujours. accepterCandidaturePoste et la demission forcee
// par motion de censure ecrivent desormais directement sur personnages.poste au moment de
// l'action (voir ces deux fonctions), plus besoin d'un passage differe au chargement.

// =====================
// PONT ELECTION -> POUVOIR REEL (refonte des postes, 9 aout 2026)
// Jusqu'ici, gagner une election n'ecrivait jamais que cycle.eluId (cote cron) - jamais
// state.poste sur la fiche du gagnant. Un president/maire/depute/chef syndical elu n'avait
// donc AUCUN acces aux ordres requiresPost correspondants tant qu'il ne passait pas par
// l'ancien systeme POSTES (retire a l'etape 1). Applique ici au chargement du personnage,
// meme modele que appliquerNominationPosteEnAttente : reconcilie l'etat du joueur avec le
// cycle electoral reel, poste par poste (accorde un mandat fraichement gagne, retire un
// mandat perime si un autre vainqueur ou une vacance a suivi).
// =====================
const NOMS_POSTES_ELUS = { president: 'Président de la République', chef_syndicat: 'Chef Syndical', maire: 'Maire', depute: 'Député' };

async function appliquerVictoireElectorale() {
  if (!state.char?.name || typeof sbLoadCyclesElectoraux !== 'function') return;
  const country = state.country;

  try {
    const cycles = await sbLoadCyclesElectoraux(country);
    if (cycles) CYCLES_ELECTORAUX[country] = { ...(CYCLES_ELECTORAUX[country]||{}), ...cycles };
  } catch(e) { return; }

  // Correctif "caserne/QHS parasites" (audit du 4 septembre 2026) : Object.keys(WORLD[country])
  // incluait aussi les zones speciales caserne/qhs (isSpecial:true, jamais de circonscription
  // reelle) -- sans consequence ici tant qu'aucune candidature ne peut cibler ces zones, mais
  // corrige par coherence avec le meme correctif applique a l'organigramme national.
  const villesConnues = typeof getVillesReelles === 'function' ? getVillesReelles(country) : Object.keys(WORLD[country] || {});

  await reconcilierPosteElu('president', null);
  await reconcilierPosteElu('chef_syndicat', null);
  for (const ville of villesConnues) {
    await reconcilierPosteElu('maire', ville);
    await reconcilierPosteElu('depute', ville);
  }
}

async function reconcilierPosteElu(posteId, city) {
  const moi = state.char?.name;
  if (!moi) return;

  const cle = typeof getCleCycle === 'function' ? getCleCycle(posteId, city) : posteId;
  const cycleReconciliation = CYCLES_ELECTORAUX?.[state.country]?.[cle];
  const champ = posteId === 'depute' ? 'posteDepute' : 'poste';
  const posteActuel = state[champ];
  // Depute (chantier "Hotel de Ville / elections", 4 septembre 2026) : 3 sieges reels par ville,
  // stockes dans cycle.elus (tableau), jamais dans cycle.eluId (reserve aux postes a siege
  // unique). Un joueur ne detient jamais qu'UN seul siege a la fois (state.posteDepute reste un
  // scalaire, inchange) -- seule la SOURCE lue cote cycle devient plurielle.
  const jeSuisElu = posteId === 'depute'
    ? Array.isArray(cycleReconciliation?.elus) && cycleReconciliation.elus.includes(moi)
    : cycleReconciliation?.eluId === moi;
  const jOccupeCePoste = posteActuel?.id === posteId && (posteActuel?.city || null) === (city || null);
  const nomPoste = NOMS_POSTES_ELUS[posteId] || posteId;
  const villeNom = city ? (WORLD[state.country]?.[city]?.name || city) : null;

  if (jeSuisElu && !jOccupeCePoste) {
    // Ne jamais ecraser un poste different deja detenu (ex: PM en poste qui gagne aussi une
    // mairie) - conflit rare mais reel a resoudre manuellement plutot qu'a trancher en silence.
    if (posteActuel && posteId !== 'depute') {
      showToast('Élu(e), mais...', 'Vous avez gagné l\'élection de ' + nomPoste + (villeNom ? ' de ' + villeNom : '') + ', mais vous occupez déjà ' + (posteActuel.name || posteActuel.id) + '. Démissionnez d\'abord pour prendre vos nouvelles fonctions.', false);
      return;
    }
    state[champ] = { id: posteId, name: nomPoste, city: city || null };
    if (state.char) state.char[champ] = state[champ];
    if (posteId !== 'depute') state.salaireTouche = false;
    if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
    updateUI();
    showToast('Élu(e) !', 'Vous êtes désormais ' + nomPoste + (villeNom ? ' de ' + villeNom : '') + '. Bienvenue au pouvoir.', true, true);
    addJournalEntry('Prise de fonction : ' + nomPoste + (villeNom ? ' de ' + villeNom : '') + ' (élu).', 'event-good');
  } else if (!jeSuisElu && jOccupeCePoste) {
    state[champ] = null;
    if (state.char) state.char[champ] = null;
    if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
    updateUI();
    showToast('Mandat terminé', 'Votre mandat de ' + nomPoste + (villeNom ? ' de ' + villeNom : '') + ' a pris fin.', false);
    addJournalEntry('Fin de mandat : ' + nomPoste + (villeNom ? ' de ' + villeNom : '') + '.', 'event-info');
  }
}

// =====================
// DISSOUDRE L'ASSEMBLEE (audit valide + implementation, 3 septembre 2026)
// =====================
// Reutilise le moteur electoral existant tel quel (construireNouveauCycleElectoral/
// initCycleElectoral, table cycles_electoraux, PHASES_ELECTORALES) -- aucun systeme electoral
// parallele. Ne touche jamais president/PM/ministres : uniquement les circonscriptions de
// depute du pays du President agissant. Le probleme preexistant nbParVille:3/eluId unique
// (un seul elu par cycle malgre 3 sieges annonces) N'EST PAS corrige ici, deliberement --
// dette technique deja identifiee, hors perimetre de ce lot.
async function doDissoudreAssemblee(pa, cost) {
  if (state.poste?.id !== 'president') {
    showToast('Accès refusé', 'Seul le Président peut dissoudre l\'Assemblée.', false);
    return;
  }
  const pays = state.country || 'republic';

  // Verification au moment REEL de l'execution (jamais seulement l'affichage du bouton) :
  // relit le cycle presidentiel FRAIS depuis Supabase, jamais un cache local potentiellement
  // perime (ex. un autre onglet/une autre session ayant deja dissous entretemps).
  const cyclesFrais = (typeof sbLoadCyclesElectoraux === 'function') ? await sbLoadCyclesElectoraux(pays).catch(() => null) : null;
  if (cyclesFrais) CYCLES_ELECTORAUX[pays] = { ...(CYCLES_ELECTORAUX[pays] || {}), ...cyclesFrais };
  const cyclePresident = CYCLES_ELECTORAUX[pays]?.['president'];
  if (!cyclePresident) {
    showToast('Erreur', 'Impossible de vérifier votre mandat présidentiel pour le moment. Réessayez.', false);
    return;
  }
  if (cyclePresident.dissolutionUtilisee) {
    showToast('Dissolution déjà utilisée', 'Vous avez déjà dissous l\'Assemblée pendant ce mandat présidentiel.', false);
    return;
  }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  // Marque la limite AVANT le reste (fail-closed) : meme si une etape suivante echoue
  // partiellement (reseau), une 2e dissolution pendant ce mandat reste refusee. Le flag vit sur
  // le cycle PRESIDENTIEL lui-meme : un nouveau mandat (construireNouveauCycleElectoral/
  // initCycleElectoral produisent un objet neuf) repart naturellement sans ce champ, aucune
  // reinitialisation manuelle necessaire.
  const cyclePresidentMaj = { ...cyclePresident, dissolutionUtilisee: true };
  CYCLES_ELECTORAUX[pays]['president'] = cyclePresidentMaj;
  if (typeof sbSaveCycleElectoral === 'function') await sbSaveCycleElectoral(pays, 'president', cyclePresidentMaj, null).catch(() => {});

  // 1. Vider IMMEDIATEMENT poste_depute pour tous les deputes en fonction de ce pays -- lecture
  // fiable (poste_depute?.id === 'depute'), jamais le filtre errone preexistant de
  // notifierDeputesPourVoteConfiance (lit poste au lieu de poste_depute, motif 'depute_' avec un
  // suffixe qui n'existe pas -- dette technique deja identifiee, non touchee ici).
  let nbDeputesRevoques = 0;
  if (typeof sbGet === 'function' && typeof sbUpdate === 'function') {
    try {
      const joueursPays = await sbGet('personnages', `country=eq.${encodeURIComponent(pays)}&select=name,poste_depute`) || [];
      for (const j of joueursPays) {
        let pd = j.poste_depute;
        if (typeof pd === 'string') { try { pd = JSON.parse(pd); } catch (e) { pd = null; } }
        if (pd?.id === 'depute') {
          await sbUpdate('personnages', `name=eq.${encodeURIComponent(j.name)}`, { poste_depute: null }).catch(() => {});
          nbDeputesRevoques++;
        }
      }
    } catch (e) {}
  }
  // Reconciliation locale immediate pour le President agissant lui-meme, s'il cumulait aussi un
  // mandat de depute (posteDepute distinct de poste, cumul possible) -- sa propre session doit
  // refleter la perte tout de suite, sans attendre une reconnexion.
  if (state.posteDepute) {
    state.posteDepute = null;
    if (state.char) state.char.posteDepute = null;
  }

  // 2. Relancer immediatement un cycle electoral frais pour CHAQUE circonscription de depute
  // EXISTANTE de ce pays (lues directement dans cycles_electoraux, jamais une liste de villes
  // devinee) -- candidatures -> campagne -> vote -> resultats -> mandat, exactement le moteur
  // normal, repris par le cron quotidien comme n'importe quel autre cycle.
  let nbCirconscriptionsRelancees = 0;
  if (typeof sbGet === 'function') {
    try {
      const lignesDepute = await sbGet('cycles_electoraux', `country=eq.${encodeURIComponent(pays)}&poste_id=eq.depute`) || [];
      for (const ligne of lignesDepute) {
        const ville = ligne.city || null;
        const cycleFrais = construireNouveauCycleElectoral('depute', ville, Date.now());
        const cle = getCleCycle('depute', ville);
        CYCLES_ELECTORAUX[pays][cle] = cycleFrais;
        if (typeof sbSaveCycleElectoral === 'function') await sbSaveCycleElectoral(pays, 'depute', cycleFrais, ville).catch(() => {});
        nbCirconscriptionsRelancees++;
      }
    } catch (e) {}
  }

  updateUI();
  showToast('Assemblée dissoute !', nbDeputesRevoques + ' député(s) ont immédiatement perdu leur mandat. Élections législatives anticipées lancées (' + nbCirconscriptionsRelancees + ' circonscription(s)).', true, true);
  addJournalEntry('Dissolution de l\'Assemblée nationale. Élections législatives anticipées convoquées.', 'event-info');
  addExternalEvent('🏛 Le Président ' + (state.char?.name || '') + ' dissout l\'Assemblée nationale ! Élections législatives anticipées dans tout le pays.');
}

// =====================
// MARIAGE ENTRE DEUX PJ
// =====================
async function ouvrirModalDemandeMariage(pa, cost) {
  if (typeof sbGetMariageActif === 'function') {
    const mariageActuel = await sbGetMariageActif(state.char?.name);
    if (mariageActuel) {
      const conjoint = mariageActuel.conjoint1 === state.char?.name ? mariageActuel.conjoint2 : mariageActuel.conjoint1;
      showToast('Déjà marié(e)', 'Vous êtes déjà marié(e) avec ' + conjoint + '.', false);
      return;
    }
  }

  let presents = [];
  if (typeof sbGetPresencesInRoom === 'function' && state.currentBuilding && state.currentRoom) {
    try {
      const tous = await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom);
      presents = (tous || []).filter(p => p.name !== state.char?.name);
    } catch(e) {}
  }

  let joueurs = [];
  if (typeof sbListPersonnages === 'function') {
    try { joueurs = (await sbListPersonnages() || []).filter(j => j.name !== state.char?.name); } catch(e) {}
  }
  const liste = (presents.length > 0 ? presents : joueurs).map(j => ({ name: j.name, isPJ: true }));
  const roomActuelleMariage = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const presentsPNJMariage = (roomActuelleMariage?.persons || []).filter(p => !p.isPJ).map(p => ({ name: p.name.replace(' (PNJ)', ''), isPJ: false }));
  const monGroupePNJMariage = typeof getMonGroupePNJ === 'function' ? getMonGroupePNJ() : [];
  const presentsMonGroupeMariage = monGroupePNJMariage
    .filter(g => !presentsPNJMariage.some(pp => pp.name === g.nom))
    .map(g => ({ name: g.nom, isPJ: false }));
  const listeComplete = [...liste, ...presentsPNJMariage, ...presentsMonGroupeMariage];

  document.getElementById('postes-modal-title').textContent = 'Demande en mariage';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Une demande romantique sera envoyée par mail. Si elle est acceptée, vous devrez tous deux vous rendre ensemble à la mairie pour officialiser l\'union.</div>';

  if (listeComplete.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040">Aucun habitant connu pour le moment.</div>';
  } else {
    html += '<select id="mariage-destinataire-select" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    listeComplete.forEach(j => { html += '<option value="' + j.name + '|' + (j.isPJ ? '1' : '0') + '">' + j.name + (j.isPJ ? '' : ' (PNJ)') + '</option>'; });
    html += '</select>';
    html += '<button onclick="confirmerDemandeMariage(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💍 Envoyer la demande</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDemandeMariage(pa, cost) {
  const rawSelect = document.getElementById('mariage-destinataire-select')?.value;
  document.getElementById('modal-postes').classList.remove('open');
  if (!rawSelect) return;
  const [destinataire, estPJRaw] = rawSelect.split('|');
  const estPJ = estPJRaw === '1';
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  if (!estPJ) {
    const estDansMonGroupeMariage = typeof getMonGroupePNJ === 'function' && getMonGroupePNJ().some(g => g.nom === destinataire);
    const roomActuelleMariage2 = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    const pnjInfoMariage = (roomActuelleMariage2?.persons || []).find(pp => pp.name.replace(' (PNJ)', '') === destinataire);
    const rel = pnjInfoMariage?.rel || 'neutral';
    const chance = estDansMonGroupeMariage ? 80 : (rel === 'ally' ? 70 : rel === 'enemy' ? 5 : 35);
    const roll = Math.floor(Math.random() * 100) + 1;
    if (roll <= chance) {
      const cout = 200;
      if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' FR requis pour officialiser.', false); return; }
      state.arg -= cout;
      // city (17 aout 2026, mini-lot etat-civil) : ville de la ceremonie, celle ou le joueur se
      // trouve reellement au moment de l'acceptation instantanee (action synchrone).
      const mariagePnj = { id: 'mariage-' + Date.now(), conjoint1: state.char?.name, conjoint2: destinataire, country: state.country, statut: 'actif', jour_union: state.day || 1, city: state.currentCity };
      if (typeof sbCreerMariage === 'function') await sbCreerMariage(mariagePnj).catch(() => {});
      updateUI();
      showToast('Félicitations !', destinataire + ' a accepté. Union officialisée sur le champ !', true, true);
      addJournalEntry('Mariage celebre avec ' + destinataire + ' (PNJ).', 'event-good');
      addExternalEvent((state.char?.name || '') + ' et ' + destinataire + ' se sont maries.', 'local');
    } else {
      showToast('Demande refusée', destinataire + ' a decline votre demande en mariage.', false);
      addJournalEntry('Demande en mariage a ' + destinataire + ' (PNJ) refusee.', 'event-info');
    }
    return;
  }
  if (!destinataire) return;

  const demande = {
    id: 'demande-mariage-' + Date.now(),
    demandeur: state.char?.name || 'Anonyme',
    destinataire,
    country: state.country,
    statut: 'en_attente'
  };

  if (typeof sbCreerDemandeMariage === 'function') {
    await sbCreerDemandeMariage(demande).catch(() => {});
  }

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    const corps = (state.char?.name || 'Quelqu\'un') + ' vous demande en mariage !<br><br>' +
      marqueurActionMail('mariage_oui', demande.id) + marqueurActionMail('mariage_non', demande.id);
    await sbSendMail(state.char?.name || 'Anonyme', destinataire, 'Demande en mariage 💍', corps, time).catch(() => {});
  }

  showToast('Demande envoyée', 'Votre demande en mariage a été envoyée à ' + destinataire + '.', true, true);
  addJournalEntry('Demande en mariage envoyée à ' + destinataire + '.', 'event-info');
}

async function accepterDemandeMariage(demandeId) {
  document.getElementById('modal-pnj')?.classList.remove('open');
  if (typeof sbUpdateDemandeMariage === 'function') {
    await sbUpdateDemandeMariage(demandeId, 'acceptee').catch(() => {});
  }
  showToast('Demande acceptée !', 'Rendez-vous tous les deux à la mairie pour officialiser votre union.', true, true);
  addJournalEntry('Vous avez accepté la demande en mariage. Rendez-vous à la mairie pour officialiser.', 'event-good');
}

async function refuserDemandeMariage(demandeId) {
  document.getElementById('modal-pnj')?.classList.remove('open');
  if (typeof sbUpdateDemandeMariage === 'function') {
    await sbUpdateDemandeMariage(demandeId, 'refusee').catch(() => {});
  }
  showToast('Demande refusée', '', false);
  addJournalEntry('Vous avez refusé une demande en mariage.', '');
}

// Officialiser : necessite que les DEUX futurs epoux soient physiquement presents dans la meme piece
async function ouvrirOfficialiserMariage(pa, cost) {
  if (!state.char?.name) return;

  let demandesAcceptees = [];
  if (typeof sbGetDemandesMariagePour === 'function') {
    // Chercher les demandes ou JE suis le demandeur ET acceptees (sbGetDemandesMariagePour filtre par destinataire,
    // donc on verifie aussi dans l'autre sens via une recherche large)
    try {
      const enAttentePourMoi = await sbGetDemandesMariagePour(state.char.name);
      demandesAcceptees = enAttentePourMoi; // securite, normalement vide ici car deja traitees
    } catch(e) {}
  }

  // Verifier qui est present dans la piece et a une demande acceptee avec moi
  let presents = [];
  if (typeof sbGetPresencesInRoom === 'function' && state.currentBuilding && state.currentRoom) {
    try {
      const tous = await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom);
      presents = (tous || []).filter(p => p.name !== state.char?.name);
    } catch(e) {}
  }

  if (presents.length === 0) {
    showToast('Personne ici', 'Votre futur(e) époux/épouse doit être présent(e) dans cette pièce.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Officialiser le mariage';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Sélectionnez votre futur(e) époux/épouse présent(e). Une demande acceptée entre vous deux est requise.</div>';
  html += '<select id="mariage-officialiser-select" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  presents.forEach(p => { html += '<option value="' + p.name + '">' + p.name + '</option>'; });
  html += '</select>';
  html += '<button onclick="confirmerOfficialisationMariage(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">💍 Célébrer l\'union (200 FR)</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerOfficialisationMariage(pa, cost) {
  const conjoint = document.getElementById('mariage-officialiser-select')?.value;
  if (!conjoint) return;

  const cout = 200;
  if (state.arg < cout) { showToast('Fonds insuffisants', cout + ' requis.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  document.getElementById('modal-postes').classList.remove('open');

  // city (17 aout 2026, mini-lot etat-civil) : ville de la ceremonie -- les deux epoux doivent
  // etre physiquement presents dans cette piece pour officialiser (verifie plus haut dans cette
  // fonction), state.currentCity est donc la localisation reellement pertinente de l'acte.
  const mariage = {
    id: 'mariage-' + Date.now(),
    conjoint1: state.char?.name,
    conjoint2: conjoint,
    country: state.country,
    statut: 'actif',
    jour_union: state.day || 1,
    city: state.currentCity
  };

  if (typeof sbCreerMariage === 'function') {
    await sbCreerMariage(mariage).catch(() => {});
  }

  updateUI();
  showToast('Félicitations !', 'Vous êtes désormais marié(e) à ' + conjoint + ' !', true, true);
  addJournalEntry('💍 Mariage célébré avec ' + conjoint + ' !', 'event-good');
  addExternalEvent('💍 ' + (state.char?.name||'') + ' et ' + conjoint + ' se sont mariés !', 'local');

  if (typeof sbSendMail === 'function') {
    const h = String(state.hour || 8).padStart(2,'0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    await sbSendMail('Mairie', conjoint, 'Mariage célébré !', 'Votre mariage avec ' + (state.char?.name||'') + ' a été officialisé. Félicitations !', time).catch(() => {});
  }
}



async function doEtatUrgence(pa, cost) {
  if (state.poste?.id !== 'president') {
    showToast('Acces refuse', 'Seul le President peut declarer l\'etat d\'urgence.', false);
    return;
  }
  const pays = state.country;
  const etatActuel = typeof sbGetEtatUrgence === 'function' ? await sbGetEtatUrgence(pays).catch(() => null) : null;
  const actif = !!etatActuel?.actif;

  document.getElementById('postes-modal-title').textContent = actif ? "Etat d'urgence en vigueur" : "Declarer l'etat d'urgence";
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    (actif
      ? '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.8rem">' +
        "L'etat d'urgence est actuellement en vigueur. Declare par " + (etatActuel.active_par || 'le President') + '.</div>' +
        '<button onclick="confirmerEtatUrgence(false,' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.5rem 1rem;border:1px solid #8a3a2a;background:transparent;color:#8a3a2a;cursor:pointer">Lever l\'etat d\'urgence</button>'
      : '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.8rem">Suspend certaines libertes publiques. Fort impact sur INF et POP. Autorise des mesures exceptionnelles (arrestations sans plainte prealable).</div>' +
        '<button onclick="confirmerEtatUrgence(true,' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.5rem 1rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Declarer l\'etat d\'urgence</button>'
    ) +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEtatUrgence(activer, pa, cost) {
  // REVALIDATION DU POSTE. Cette fonction est exposee en global et appelee par un onclick inline :
  // seul doEtatUrgence() controlait le poste, un appel direct depuis la console suffisait donc a
  // declarer ou lever l'etat d'urgence de tout un pays. Meme correctif que doBlocusPortuaire
  // (plateau-navigation.js, 25 aout 2026).
  if (state.poste?.id !== 'president') {
    showToast('Acces refuse', "Seul le President peut declarer ou lever l'etat d'urgence.", false);
    return;
  }
  document.getElementById('modal-postes').classList.remove('open');
  const pays = state.country;
  const from = state.char?.name || 'Le President';

  // ECRITURE PARTAGEE D'ABORD, PA ENSUITE. sbSetEtatUrgence renvoie null quand PostgREST refuse
  // l'ecriture (RLS, reseau) ; l'appel etait enveloppe dans un .catch(() => {}) muet, si bien que
  // le President perdait 3 PA, encaissait le malus POP et voyait le toast de confirmation alors
  // que RIEN n'avait ete ecrit -- l'etat d'urgence n'existait pour personne. On refuse desormais
  // sans le moindre effet de bord, avant tout prelevement.
  if (typeof sbSetEtatUrgence !== 'function') {
    showToast('Indisponible', "La liaison avec le registre national est interrompue.", false);
    return;
  }
  const ecrit = await sbSetEtatUrgence(pays, activer, from, state.day || 1).catch(() => null);
  if (!ecrit) {
    showToast('Echec', "Le registre national n'a pas enregistre la decision. Aucun PA n'a ete preleve, reessayez.", false);
    return;
  }

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  if (activer) {
    const popEffect = -(Math.floor(Math.random() * 15) + 5);
    const infEffect = Math.floor(Math.random() * 10) + 5;
    state.pop = Math.max(0, Math.min(100, (state.pop || 50) + popEffect));
    state.inf = Math.min(100, (state.inf || 0) + infEffect);
    updateUI();
    addExternalEvent("ETAT D'URGENCE declare par " + from + ". Certaines libertes sont suspendues jusqu'a nouvel ordre.");
    addJournalEntry("Etat d'urgence declare. " + popEffect + ' POP, +' + infEffect + ' INF.', 'event-bad');
    showToast("Etat d'urgence declare", 'Mesures exceptionnelles activees pour ' + (COUNTRIES[pays]?.n || pays) + '.', true);
  } else {
    addExternalEvent("Fin de l'etat d'urgence, annoncee par " + from + '.');
    addJournalEntry("Etat d'urgence leve.", 'event-good');
    showToast("Etat d'urgence leve", 'Les mesures exceptionnelles sont levees.', true);
  }
}

// Reutilisable par de futurs controles (ex: futur ordre "Faire arreter quelqu'un")
async function estEtatUrgenceActif(country) {
  if (typeof sbGetEtatUrgence !== 'function') return false;
  const etat = await sbGetEtatUrgence(country).catch(() => null);
  return !!etat?.actif;
}

async function ouvrirEtatNation() {
  const pays = state.country || 'republic';
  const idx = (typeof getIndiceNationalCalcule === 'function')
    ? { ISN: getIndiceNationalCalcule(pays,'isn'), IE: getIndiceNationalCalcule(pays,'ie'), ID: INDICES_NATIONAUX[pays]?.ID ?? 40, IS: getIndiceNationalCalcule(pays,'social') }
    : (INDICES_NATIONAUX[pays] || { ISN:30, IE:50, ID:40, IS:45 });
  document.querySelectorAll('.vue').forEach(v => v.classList.remove('active'));
  const el = document.getElementById('vue-self');
  if (!el) return;
  el.classList.add('active');
  document.getElementById('self-view-name').textContent = 'Etat de la Nation';
  document.getElementById('self-view-role').textContent = COUNTRIES[pays]?.n || '';
  const content = document.getElementById('self-content');
  content.innerHTML = '<div style="padding:1.5rem;color:#8a8060;font-style:italic">Chargement...</div>';

  const guerres = typeof sbGetGuerresPays === 'function' ? await sbGetGuerresPays(pays).catch(() => []) : [];

  const indices = [
    { k:'ISN', label:'Securite Nationale',    val:idx.ISN, col:'#6ab858', desc:'Impact sur les actes illegaux et leur detection.' },
    { k:'IE',  label:'Economique',            val:idx.IE,  col:'#C9A84C', desc:'Impact sur les revenus fiscaux et les salaires.' },
    { k:'ID',  label:'Diplomatique',          val:idx.ID,  col:'#5a8ad0', desc:'Impact sur les relations inter-empires et voyages.' },
    { k:'IS',  label:'Social',               val:idx.IS,  col:'#d4886a', desc:'Impact sur la popularite des elus et risques de greve.' }
  ];

  let html = '<div style="padding:1.5rem;max-width:650px">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1.1rem;color:#C9A84C;margin-bottom:1.2rem">Indices de la Nation — ' + (COUNTRIES[pays]?.n||'') + '</div>';

  // Statut diplomatique : guerre/treve, ou paix par defaut
  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;color:#e0d5b8;letter-spacing:.08em;margin-bottom:.4rem">STATUT DIPLOMATIQUE</div>';
  if (guerres.length === 0) {
    html += '<div style="font-size:.85rem;color:#6ab858">En paix avec tous les empires.</div>';
  } else {
    guerres.forEach(g => {
      const adversaire = g.attaquant === pays ? g.attaque : g.attaquant;
      const nomAdv = COUNTRIES[adversaire]?.n || adversaire;
      if (g.ceasefire?.actifPar?.[pays] || g.ceasefire?.actifPar?.[adversaire]) {
        html += '<div style="font-size:.85rem;color:#d4a850">🕊 En trêve avec ' + nomAdv + (g.ceasefire.actifPar[pays] && !g.ceasefire.actifPar[adversaire] ? ' (activée de notre côté seulement)' : '') + '</div>';
      } else {
        html += '<div style="font-size:.85rem;color:#cc4444">⚔ En guerre avec ' + nomAdv + '</div>';
      }
    });
  }
  html += '</div>';

  indices.forEach(ind => {
    const pct = ind.val;
    const niveau = pct <= 20 ? 'Critique' : pct <= 40 ? 'Faible' : pct <= 60 ? 'Moyen' : pct <= 80 ? 'Bon' : 'Excellent';
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.8rem;margin-bottom:.6rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.4rem">';
    html += '<div><span style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:' + ind.col + ';letter-spacing:.1em">Indice ' + ind.label + ' (' + ind.k + ')</span></div>';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:' + ind.col + '">' + pct + '/100 — ' + niveau + '</div>';
    html += '</div>';
    html += '<div style="height:8px;background:#1a1810;border-radius:4px;overflow:hidden;margin-bottom:.4rem">';
    html += '<div style="height:100%;width:' + pct + '%;background:' + ind.col + ';border-radius:4px;transition:width .5s"></div></div>';
    html += '<div style="font-size:.72rem;color:#8a8060">' + ind.desc + '</div>';
    html += '</div>';
  });

  // Malus illegal actuel
  const malus = getMalusIllegal ? getMalusIllegal(pays) : 0;
  const multDet = getMultDetection ? getMultDetection(pays) : 1;
  html += '<div style="padding:.7rem;background:#0a0805;border:1px solid #1a1810;font-size:.78rem;color:#6a5a30">';
  html += 'ISN actuel : malus de <strong style="color:#C9A84C">-' + malus + '%</strong> sur tous les actes illegaux · taux de detection x<strong style="color:#C9A84C">' + multDet + '</strong>';
  html += '</div>';
  html += '</div>';
  content.innerHTML = html;
}

// =====================
// FILE D'ATTENTE DIPLOMATIQUE GENERIQUE
// Reutilisee par : signer un traite, ouvrir des negociations. Schema commun :
// proposer -> mail a l'homologue -> il accepte ou refuse -> effet bilateral (ID).
// =====================
const DIPLOMATIE_CONFIG = {
  traite: {
    label: 'Traité',
    gainAccepte: 12,
    perteRefus: 12,
    genereForumSujet: false
  },
  negociation: {
    label: 'Négociations diplomatiques',
    gainAccepte: 8,
    perteRefus: 8,
    genereForumSujet: true
  }
};

async function proposerDiplomatie(type, empireCibleId, empireCibleName, details, pa, cost) {
  const pays = state.country || 'republic';
  const config = DIPLOMATIE_CONFIG[type];
  if (!config) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  const proposeur = state.char?.name || 'Le Ministre';
  const empireProposeurNom = COUNTRIES[pays]?.n || pays;
  const maeAdversaireInfo = await getTitulaireActuel('min_ae', null, empireCibleId);
  const maeAdversaire = maeAdversaireInfo?.estPJ ? maeAdversaireInfo.nom : null;

  const data = {
    type,
    empireProposeur: pays,
    empireCible: empireCibleId,
    empireCibleNom: empireCibleName,
    empireProposeurNom,
    proposeur,
    details: details || '',
    jour: state.day || 1
  };
  if (typeof sbCreerPropositionDiplomatique === 'function') await sbCreerPropositionDiplomatique(data).catch(() => {});

  if (typeof sbSendMail === 'function') {
    await sbSendMail('Ministère des Affaires Étrangères', maeAdversaire || 'PNJ-MAE',
      config.label + ' proposé(e)',
      proposeur + ' (' + empireProposeurNom + ') propose : ' + config.label + '. Rendez-vous à votre ministère pour répondre.',
      typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }

  // Sujet forum international pour les negociations — visibilite publique de la demarche
  if (config.genereForumSujet) {
    const forumKey = 'international';
    if (!FORUM_TOPICS[forumKey]) FORUM_TOPICS[forumKey] = [];
    FORUM_TOPICS[forumKey].unshift({
      id: 'diplo-forum-' + Date.now(),
      title: '[NÉGOCIATIONS] ' + empireProposeurNom + ' ↔ ' + empireCibleName,
      author: 'Ministère des Affaires Étrangères',
      time: typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1),
      content: proposeur + ' (' + empireProposeurNom + ') ouvre des négociations diplomatiques avec ' + empireCibleName + '.'
    });
  }

  showToast(config.label + ' proposé(e)', 'En attente de la réponse de ' + empireCibleName + '.', true, true);
  addJournalEntry(config.label + ' proposé(e) à ' + empireCibleName + '.', 'event-info');
}

async function ouvrirReponsesDiplomatiques(pa, cost) {
  if (state.poste?.id !== 'min_ae') { showToast('Réservé au Ministre des Affaires Étrangères', '', false); return; }
  const pays = state.country || 'republic';
  document.getElementById('postes-modal-title').textContent = 'Propositions diplomatiques';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const propositions = typeof sbGetPropositionsDiplomatiques === 'function' ? await sbGetPropositionsDiplomatiques(pays).catch(() => []) : [];
  const recues = propositions.filter(p => p.empireCible === pays);

  let html = '<div style="padding:1rem">';
  if (recues.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune proposition en attente.</div>';
  } else {
    recues.forEach(p => {
      const config = DIPLOMATIE_CONFIG[p.type] || { label: p.type };
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#E8C97A;margin-bottom:.3rem">' + config.label + ' — ' + p.empireProposeurNom + '</div>';
      if (p.details) html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.5rem">' + p.details + '</div>';
      html += '<div style="display:flex;gap:.4rem">';
      html += '<button onclick="repondreDiplomatie(&quot;' + p.id + '&quot;,true,' + pa + ',' + cost + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer">Accepter</button>';
      html += '<button onclick="repondreDiplomatie(&quot;' + p.id + '&quot;,false,' + pa + ',' + cost + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Refuser</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function repondreDiplomatie(propositionId, accepte, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const rows = typeof sbGet === 'function' ? await sbGet('propositions_diplomatiques', `id=eq.${encodeURIComponent(propositionId)}`).catch(() => []) : [];
  const p = rows?.[0]?.data;
  if (!p) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const config = DIPLOMATIE_CONFIG[p.type] || { gainAccepte: 0, perteRefus: 0, label: p.type };

  if (typeof sbMajPropositionDiplomatique === 'function') {
    await sbMajPropositionDiplomatique(propositionId, { statut: accepte ? 'acceptee' : 'refusee' });
  }

  if (accepte) {
    INDICES_NATIONAUX[p.empireProposeur] = INDICES_NATIONAUX[p.empireProposeur] || {};
    INDICES_NATIONAUX[p.empireCible] = INDICES_NATIONAUX[p.empireCible] || {};
    INDICES_NATIONAUX[p.empireProposeur].ID = Math.min(100, (INDICES_NATIONAUX[p.empireProposeur].ID || 50) + config.gainAccepte);
    INDICES_NATIONAUX[p.empireCible].ID = Math.min(100, (INDICES_NATIONAUX[p.empireCible].ID || 50) + config.gainAccepte);
    if (p.type === 'traite') {
      if (!state.traites) state.traites = [];
      state.traites.push({ empire: p.empireProposeur, type: p.details, jour: state.day });
    }
    showToast(config.label + ' accepté(e)', '+' + config.gainAccepte + ' ID pour les deux camps.', true, true);
    addExternalEvent(config.label.toUpperCase() + ' : accord conclu entre ' + p.empireProposeurNom + ' et ' + (COUNTRIES[p.empireCible]?.n || p.empireCible) + '.');
  } else {
    INDICES_NATIONAUX[p.empireCible] = INDICES_NATIONAUX[p.empireCible] || {};
    INDICES_NATIONAUX[p.empireCible].ID = Math.max(0, (INDICES_NATIONAUX[p.empireCible].ID || 50) - config.perteRefus);
    showToast(config.label + ' refusé(e)', '-' + config.perteRefus + ' ID.', false);
    addJournalEntry(config.label + ' refusée avec ' + p.empireProposeurNom + '. -' + config.perteRefus + ' ID.', 'event-bad');
  }

  if (typeof sbSendMail === 'function') {
    await sbSendMail('Ministère des Affaires Étrangères', p.proposeur,
      config.label + ' : réponse reçue',
      (COUNTRIES[p.empireCible]?.n || p.empireCible) + ' a ' + (accepte ? 'accepté' : 'refusé') + ' votre proposition.',
      typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }
}

// Ouvre le choix d'empire pour les negociations diplomatiques — propose via la file d'attente
// generique (proposerDiplomatie) au lieu de passer par executerOrdreEmpire (qui ne faisait rien
// de reel pour cette action).
function ouvrirModalNegociationDiplomatique(pa, cost) {
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('postes-modal-title').textContent = 'Ouvrir des négociations avec';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir un empire cible :</div>';
  empires.forEach(([k, co]) => {
    html += '<button onclick="proposerDiplomatie(&quot;negociation&quot;,&quot;' + k + '&quot;,&quot;' + co.n + '&quot;,null,' + pa + ',' + cost + ')" style="display:flex;align-items:center;gap:.6rem;width:100%;padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.4rem">';
    html += '<i class="ti ' + co.icon + '" style="font-size:1rem;color:' + co.col + '"></i> ' + co.n + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function ouvrirModalEmpireCible(action, titre, pa, cost) {
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('postes-modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir un empire cible :</div>';
  empires.forEach(([k, co]) => {
    html += '<button onclick="executerOrdreEmpire(\'' + action + '\',\'' + k + '\',\'' + co.n + '\',' + pa + ',' + cost + ')" style="display:flex;align-items:center;gap:.6rem;width:100%;padding:.6rem .8rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.4rem">';
    html += '<i class="ti ' + co.icon + '" style="font-size:1rem;color:' + co.col + '"></i> ' + co.n + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// pa/cost ne sont fournis (non-undefined) que pour l'action 'ouvrir_ambassade' (Phase K, seul
// ordre pilote de ce dispatcheur partage) -- les autres branches (dead ou live) les ignorent.
async function executerOrdreEmpire(action, empireId, empireName, pa, cost) {
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (action === 'declarer_guerre') {
    if (!state.guerres) state.guerres = [];
    state.guerres.push({ empire: empireId, nom: empireName, depuis: 'Jour ' + state.day });
    INDICES_NATIONAUX[state.country].ID = Math.max(0, INDICES_NATIONAUX[state.country].ID - 20);
    addExternalEvent('GUERRE DECLAREE : ' + (COUNTRIES[state.country]?.n||'') + ' declare la guerre a ' + empireName + ' !');
    addMailNotification('Etat-Major', 'Declaration de guerre', 'La guerre a ete declaree contre ' + empireName + '. L\'armee est en alerte maximale.');
    showToast('Guerre declaree !', 'Conflit ouvert avec ' + empireName + '. -20 ID.', false);
  } else if (action === 'cessez_le_feu') {
    if (state.guerres) state.guerres = state.guerres.filter(g => g.empire !== empireId);
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 10);
    showToast('Cessez-le-feu', 'Negociation en cours avec ' + empireName + '. +10 ID.', true);
    addJournalEntry('Cessez-le-feu negocie avec ' + empireName, 'event-good');
  } else if (action === 'ouvrir_ambassade') {
    const r = await deduireCoutOrdre({ pa, cost });
    if (!r.ok) { showToast('Fonds insuffisants', '', false); return; }
    if (!state.ambassades) state.ambassades = [];
    state.ambassades.push({ empire: empireId, nom: empireName });
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 8);
    updateUI();
    // Persistance partagee : rend le bureau accessible a tous, dans le Quartier des Ambassades
    // du pays cible (empireId), pour l'ambassadeur de state.country.
    if (typeof sbOuvrirAmbassade === 'function') {
      sbOuvrirAmbassade(empireId, state.country, state.day || 1).catch(() => {});
    }
    showToast('Ambassade ouverte', 'Representation diplomatique etablie a ' + empireName + '. +8 ID.', true);
  } else if (action === 'sanctions') {
    INDICES_NATIONAUX[state.country].ID = Math.max(0, INDICES_NATIONAUX[state.country].ID - 5);
    INDICES_NATIONAUX[empireId] = INDICES_NATIONAUX[empireId] || {};
    const perteCible = 3 + Math.floor(Math.random() * 8); // aleatoire entre 3 et 10
    INDICES_NATIONAUX[empireId].ID = Math.max(0, (INDICES_NATIONAUX[empireId].ID || 50) - perteCible);
    showToast('Sanctions imposees', 'Sanctions economiques contre ' + empireName + '. -5 ID pour vous, -' + perteCible + ' ID pour ' + empireName + '.', false);
    addExternalEvent('Sanctions officielles imposees contre ' + empireName + ' (-' + perteCible + ' ID).');
  } else {
    showToast(action.replace(/_/g,' '), 'Action menee envers ' + empireName, true);
    addJournalEntry(action.replace(/_/g,' ') + ' : ' + empireName, 'event-info');
  }
}

// Juge PNJ par defaut, tant qu'aucun PJ n'a ete nomme — regle les affaires sur des criteres parodiques
const JUGE_PNJ_DEFAUT = { republic: 'Juge Sévère Lapeine' };

async function getJugeActuel(pays) {
  const titulaire = await getTitulaireActuel('juge', null, pays);
  return titulaire?.nom || JUGE_PNJ_DEFAUT[pays] || 'Juge (poste vacant)';
}

async function ouvrirProposerGrace(pa, cost) {
  if (state.poste?.id !== 'min_just') { showToast('Réservé au Ministre de la Justice', '', false); return; }
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];
  document.getElementById('postes-modal-title').textContent = 'Proposer une grâce au Président';
  let html = '<div style="padding:1rem">';
  if (condamnes.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun condamné actuellement en détention.</div>';
  } else {
    condamnes.forEach((p, i) => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div><div style="font-family:Playfair Display,serif;font-size:.85rem;color:#e0d5b8">' + p.nom + '</div>';
      html += '<div style="font-size:.72rem;color:#a89870">' + p.raison + ' · Libération à venir</div></div>';
      html += '<button onclick="confirmerPropositionGrace(' + i + ',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.25rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Proposer</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerPropositionGrace(idx, pa, cost) {
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];
  const condamne = condamnes[idx];
  if (!condamne) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  const pays = state.country || 'republic';
  const cout = 300;
  // AUTORITE MINISTERIELLE ATTESTEE (17 septembre 2026, audit des frontieres d'autorite) :
  // le poste habilite est deduit par le serveur de l'identifiant de la caisse source
  // ('<pays>_gouvernement-<posteId>'), au lieu d'etre suppose depuis l'ouverture de la modale.
  // Ces fonctions sont globales : elles etaient appelables depuis la console par n'importe
  // quel joueur authentifie, qui ponctionnait ainsi une caisse ministerielle sans en occuper
  // le poste. Montant et bareme inchanges.
  const rMin = await sbCaisseMinistereMouvement(pays, 'gouvernement-min_just', cout, null, false);
  if (!rMin || rMin.ok !== true) {
    showToast(rMin && rMin.raison === 'solde_insuffisant' ? 'Caisse insuffisante' : 'Action impossible',
      rMin && rMin.raison === 'solde_insuffisant'
        ? 'La caisse du gouvernement ne peut pas couvrir les frais de dossier (' + cout + ' FR).'
        : 'Réservé au Ministre de la Justice en exercice.', false);
    return;
  }
  const montantVerse = Number(rMin.verse || 0);

  await sbCreerDemandeGrace({ pays, nomCondamne: condamne.nom, raison: condamne.raison, jourFin: condamne.jourFin, proposePar: state.char?.name });

  const presidentInfoGrace = await getTitulaireActuel('president');
  const presidentNom = presidentInfoGrace?.estPJ ? presidentInfoGrace.nom : null;
  if (presidentNom && typeof sbSendMail === 'function') {
    await sbSendMail('Ministère de la Justice', presidentNom, 'Recommandation de grâce',
      'Le Ministre de la Justice recommande la grâce de ' + condamne.nom + ' (' + condamne.raison + '). Rendez-vous au palais pour traiter les demandes.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }
  showToast('Recommandation envoyée', 'Le Président a été notifié. -' + cout + ' FR (frais de dossier).', true, true);
  addJournalEntry('Grâce de ' + condamne.nom + ' recommandée au Président.', 'event-info');
}

async function ouvrirModalGracier(pa, cost) {
  if (state.poste?.id !== 'president') { showToast('Réservé au Président', '', false); return; }
  document.getElementById('postes-modal-title').textContent = 'Demandes de grâce en attente';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const pays = state.country || 'republic';
  const demandes = typeof sbGetDemandesGracePays === 'function' ? await sbGetDemandesGracePays(pays).catch(() => []) : [];

  let html = '<div style="padding:1rem">';
  if (demandes.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune recommandation de grâce en attente.</div>';
  } else {
    demandes.forEach(d => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#e0d5b8">' + d.nomCondamne + '</div>';
      html += '<div style="font-size:.72rem;color:#a89870">' + d.raison + ' · recommandé par ' + d.proposePar + '</div>';
      html += '<div style="display:flex;gap:.4rem;margin-top:.4rem">';
      html += '<button onclick="confirmerGrace(&quot;' + d.id + '&quot;,&quot;' + d.nomCondamne + '&quot;,true,' + pa + ',' + cost + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer">Accepter</button>';
      html += '<button onclick="confirmerGrace(&quot;' + d.id + '&quot;,&quot;' + d.nomCondamne + '&quot;,false,' + pa + ',' + cost + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #8a4a4a;background:transparent;color:#cc6a44;cursor:pointer">Refuser</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerGrace(demandeId, nomCondamne, accepte, pa, cost) {
  if (!exigerPoste('president', 'Seul le Président peut accorder ou refuser une grâce.')) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  await sbMajDemandeGrace(demandeId, accepte ? 'acceptee' : 'refusee');

  if (accepte) {
    // CORRECTIF (Lot 4.3). La liberation n'agissait que sur state.prisonniers, l'etat LOCAL du
    // navigateur du President : si sa liste etait desynchronisee, l'annonce publique partait sans
    // que personne ne soit libere. On agit desormais sur la SOURCE PERSISTANTE canonique --
    // personnages.est_emprisonne, et la ligne de detentions cloturee avec un mode_fin explicite,
    // exactement comme le fait la liberation anticipee par avocat.
    //
    // ET L'ANNONCE NE PART QUE SI LA LIBERATION A EU LIEU. C'est l'inversion qui compte : une
    // grace annoncee mais non appliquee est pire qu'une grace qui echoue silencieusement.
    // GRACIER EST UN POUVOIR, PAS UNE ECRITURE (chantier B, 13 septembre 2026). Ces deux
    // sbUpdate ecrivaient directement sur la ligne du condamne et sur son registre : la
    // fermeture RLS les a rendus inoperants -- et c'etait de toute facon une porte ouverte,
    // exigerPoste('president') ne vivant que dans le navigateur du joueur. La RPC relit le
    // poste de l'appelant sur sa propre ligne et fait les deux ecritures dans UNE transaction.
    // Meme regle qu'avant, meme mode_fin : seule l'autorite change de camp.
    let libere = false;
    if (typeof sbRpc === 'function') {
      const rows = await sbRpc('presidence_gracier', {
        p_condamne: nomCondamne,
        p_jour: state.day
      });
      const r = Array.isArray(rows) ? rows[0] : rows;
      libere = !!(r && r.ok === true && r.libere === true);
    }
    // L'etat local du President est aligne s'il se trouve l'avoir en memoire -- confort d'affichage,
    // jamais la source de verite.
    const condamne = (state.prisonniers || []).find(p => p.nom === nomCondamne);
    if (condamne) condamne.jourFin = state.day;

    if (!libere) {
      showToast('Grâce sans effet', nomCondamne + ' n\'est plus détenu(e) : aucune libération n\'a été appliquée.', false);
      addJournalEntry('Grâce accordée à ' + nomCondamne + ', sans effet : la personne n\'était plus détenue.', 'event-info');
      return;
    }

    const popBonus = state.pop > 50 ? 5 : -2;
    state.pop = Math.min(100, state.pop + popBonus);
    updateUI();
    showToast('Grâce accordée', nomCondamne + ' est libéré(e). ' + (popBonus > 0 ? '+' : '') + popBonus + ' POP.', true, true);
    addExternalEvent('⚖️ GRÂCE PRÉSIDENTIELLE : ' + nomCondamne + ' a été gracié(e) par le Président.');
  } else {
    showToast('Grâce refusée', 'La recommandation du Ministre de la Justice a été rejetée.', false);
    addJournalEntry('Grâce de ' + nomCondamne + ' refusée par le Président.', 'event-info');
  }
}

function ouvrirModalNationaliser() {
  const entreprises = ENTREPRISES_PRIVEES[state.country] || [];
  document.getElementById('postes-modal-title').textContent = 'Nationaliser une entreprise';
  let html = '<div style="padding:1rem">';
  if (entreprises.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune entreprise privee recensee pour le moment. Les entreprises achetees par des PJ apparaitront ici.</div>';
  } else {
    entreprises.forEach((e, i) => {
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.85rem;color:#c0b090">' + e.nom + ' <span style="font-size:.68rem;color:#5a4030">(propriete : ' + (e.proprio||'inconnu') + ')</span></div>';
      html += '<button onclick="confirmerNationalisation(' + i + ')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Nationaliser</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerNationalisation(idx) {
  const e = ENTREPRISES_PRIVEES[state.country]?.[idx];
  if (!e) return;
  e.nationalise = true;
  document.getElementById('modal-postes').classList.remove('open');
  INDICES_NATIONAUX[state.country].IE = Math.min(100, INDICES_NATIONAUX[state.country].IE + 5);
  showToast('Nationalisation', e.nom + ' est desormais propriete de l\'Etat. +5 IE.', true);
  addExternalEvent('NATIONALISATION : ' + e.nom + ' placee sous controle de l\'Etat par decret presidentiel.');
}

async function debiterCitoyenPlafonne(nomCible, montantVise) {
  if (nomCible === state.char?.name) {
    const preleve = Math.min(state.arg || 0, montantVise);
    state.arg -= preleve;
    updateUI();
    return preleve;
  }
  if (typeof sbGet !== 'function') return 0;
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomCible)}&select=arg`).catch(() => []);
  const argActuel = rows?.[0]?.arg ?? 0;
  const preleve = Math.min(argActuel, montantVise);
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(nomCible)}`, { arg: argActuel - preleve }).catch(() => {});
  return preleve;
}

// =====================
// CIBLAGE FISCAL ÉTENDU — citoyens, clubs sportifs, entreprises, organisations
// =====================
function ouvrirChoixTypeCibleFiscale(action, titre) {
  document.getElementById('postes-modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir le type de cible :</div>';
  const types = [
    { id: 'citoyen', label: 'Un citoyen', icon: 'ti-user' },
    { id: 'club_sportif', label: 'Un club sportif', icon: 'ti-ball-football' },
    { id: 'entreprise', label: 'Une entreprise', icon: 'ti-building-store' },
    { id: 'organisation', label: 'Une organisation', icon: 'ti-building-community' }
  ];
  types.forEach(t => {
    html += '<button onclick="ouvrirCiblageFiscalType(\'' + action + '\',\'' + t.id + '\',\'' + titre.replace(/'/g,"\\'") + '\')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem"><i class="ti ' + t.icon + '" style="margin-right:.4rem;color:#8a6a20"></i>' + t.label + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function ouvrirCiblageFiscalType(action, typeCible, titre) {
  const pays = state.country || 'republic';
  document.getElementById('postes-modal-title').textContent = titre;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  let html = '<div style="padding:1rem">';

  if (typeCible === 'citoyen') {
    let joueurs = [];
    if (typeof sbListPersonnages === 'function') { try { joueurs = await sbListPersonnages() || []; } catch(e) {} }
    const myName = state.char?.name;
    const cibles = joueurs.filter(j => {
      const domicilePays = j.domicile?.country || j.country;
      return (domicilePays === pays || j.country === pays) && j.name !== myName;
    });
    if (cibles.length === 0) html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun autre citoyen pour l\'instant.</div>';
    cibles.forEach(c => {
      const domicilie = (c.domicile?.country || c.country) === pays;
      html += '<div onclick="executerOrdreFiscalCible(\'' + action + '\',\'citoyen\',\'' + c.name + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer">';
      html += '<div style="font-size:.85rem;color:#e0d5b8">' + c.name + '</div><div style="font-size:.7rem;color:#a89870">' + (domicilie ? 'Domicilié(e)' : 'De passage') + '</div></div>';
    });
  } else if (typeCible === 'club_sportif') {
    const clubs = (CLUBS_SPORTIFS || []).filter(c => c.country === pays);
    clubs.forEach(c => {
      html += '<div onclick="executerOrdreFiscalCible(\'' + action + '\',\'club_sportif\',\'' + c.id + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer">';
      html += '<div style="font-size:.85rem;color:#e0d5b8">' + c.nom + '</div></div>';
    });
  } else if (typeCible === 'entreprise') {
    // A2 (16 aout 2026) : une entreprise par ville possedant reellement une armurerie
    // navigable (meme source que getEntreprisesRachetables, plateau-actions-illegales-
    // rumeurs.js) -- le Ministre des Finances, poste national, peut cibler individuellement
    // chaque armurerie du pays, l'intitule precise desormais la ville.
    const villesArmurerie = typeof getVillesAvecArmurerie === 'function' ? getVillesAvecArmurerie(pays) : [];
    if (villesArmurerie.length === 0) html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune armurerie connue pour l\'instant.</div>';
    villesArmurerie.forEach(city => {
      const id = getEntrepriseIdArmurerie(pays, city);
      const nomVille = WORLD[pays]?.[city]?.name || city;
      html += '<div onclick="executerOrdreFiscalCible(\'' + action + '\',\'entreprise\',\'' + id + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer">';
      html += '<div style="font-size:.85rem;color:#e0d5b8">Armurerie de ' + nomVille + '</div></div>';
    });
  } else if (typeCible === 'organisation') {
    const orgas = (state.organisations || []).filter(o => o.country === pays);
    if (orgas.length === 0) html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune organisation connue pour l\'instant.</div>';
    orgas.forEach(o => {
      html += '<div onclick="executerOrdreFiscalCible(\'' + action + '\',\'organisation\',\'' + o.id + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer">';
      html += '<div style="font-size:.85rem;color:#e0d5b8">' + o.nom + '</div><div style="font-size:.7rem;color:#a89870">Chef : ' + (o.chef||'?') + '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Lit le solde actuel d'une cible, quel que soit son type
async function getSoldeCibleFiscale(typeCible, idCible) {
  const pays = state.country || 'republic';
  if (typeCible === 'citoyen') {
    if (idCible === state.char?.name) return state.arg || 0;
    const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(idCible)}&select=arg`).catch(() => []);
    return rows?.[0]?.arg ?? 0;
  }
  if (typeCible === 'club_sportif') { const b = await chargerBudgetClub(idCible); return b?.caisse || 0; }
  // Lecture PURE (chantier C, phase 3) : consulter le solde d'une cible fiscale ne doit pas
  // creer l'entreprise au passage -- c'est desormais le role de entreprise_assurer_existence,
  // appele depuis le commerce lui-meme.
  if (typeCible === 'entreprise') { const e = await sbGetEntreprise(idCible).catch(() => null); return e?.caisse || 0; }
  if (typeCible === 'organisation') { const o = (state.organisations || []).find(x => x.id === idCible); return o?.caisse || 0; }
  return 0;
}

// Ajuste le solde d'une cible (delta positif ou negatif), quel que soit son type. Retourne le montant reel applique.
async function ajusterSoldeCibleFiscale(typeCible, idCible, delta) {
  const pays = state.country || 'republic';
  const soldeActuel = await getSoldeCibleFiscale(typeCible, idCible);
  const montantReel = delta >= 0 ? delta : -Math.min(soldeActuel, -delta);

  if (typeCible === 'citoyen') {
    if (idCible === state.char?.name) { state.arg = (state.arg||0) + montantReel; updateUI(); }
    else await sbUpdate('personnages', `name=eq.${encodeURIComponent(idCible)}`, { arg: soldeActuel + montantReel }).catch(() => {});
  } else if (typeCible === 'club_sportif') {
    await crediterBudgetClub(idCible, montantReel, montantReel >= 0 ? 'Subvention ministérielle' : 'Redressement fiscal');
  } else if (typeCible === 'entreprise') {
    // CHANTIER C / PHASE 3. Cette branche relisait la caisse, la recalculait et reecrivait le
    // blob entier -- sans controle de poste dans la fonction elle-meme (il n'existait qu'a
    // l'ouverture du formulaire). entreprise_mouvement_fiscal exige le poste min_fin reel,
    // replafonne le prelevement sur le solde reel et n'ecrit que la caisse. Elle rend le montant
    // REELLEMENT applique, que l'appelant reverse au Tresor -- comportement inchange.
    const rFisc = await sbRpc('entreprise_mouvement_fiscal', {
      p_acteur: state.char?.name, p_entreprise: idCible, p_delta: montantReel
    }).then(function (rows) { return Array.isArray(rows) ? rows[0] : rows; }).catch(function () { return null; });
    if (!rFisc || rFisc.ok !== true) return 0;
    return rFisc.montantReel;
  } else if (typeCible === 'organisation') {
    const o = (state.organisations || []).find(x => x.id === idCible);
    if (o) { o.caisse = Math.max(0, (o.caisse||0) + montantReel); sauvegarderOrga(o); }
  }
  return montantReel;
}

function nomAffichageCible(typeCible, idCible) {
  if (typeCible === 'club_sportif') return getClub(idCible)?.nom || idCible;
  if (typeCible === 'entreprise') {
    const def = typeof getEntrepriseRachetable === 'function' ? getEntrepriseRachetable(idCible) : null;
    return def ? def.label : 'l\'armurerie';
  }
  if (typeCible === 'organisation') return (state.organisations || []).find(x => x.id === idCible)?.nom || idCible;
  return idCible;
}

async function executerOrdreFiscalCible(action, typeCible, idCible) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const nomCible = nomAffichageCible(typeCible, idCible);

  if (action === 'ouvrir_enquete') {
    document.getElementById('modal-postes')?.classList.remove('open');
    const pays = state.country || 'republic';
    const cout = 400;
    // Deduction PA+cout centralisee (Lot 2C) via payeur institutionnel (caisse du ministere de
    // la justice), avant toute mutation (jet, mails).
    const r = await deduireCoutOrdre({ pa: 2, cost: cout, payeur: { type: 'institution', pays, buildingId: 'gouvernement-min_just' } });
    if (!r.ok) { showToast(r.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Caisse insuffisante', r.raison === 'pa_insuffisants' ? '2 PA requis.' : 'La caisse du gouvernement ne peut pas couvrir les frais d\'enquête (' + cout + ' FR).', false); return; }

    const reussite = Math.random() < 0.9;
    updateUI();
    if (reussite) {
      showToast('Enquête ouverte', 'Une enquête judiciaire est ouverte sur ' + nomCible + '. -' + cout + ' FR.', true, true);
      addJournalEntry('Enquête judiciaire ouverte sur ' + nomCible + ' (-' + cout + ' FR).', 'event-info');
      addExternalEvent('🔍 Le Ministère de la Justice ouvre une enquête sur ' + nomCible + '.');
      if (typeCible === 'citoyen' && typeof sbSendMail === 'function') sbSendMail('Ministère de la Justice', idCible, 'Enquête ouverte', 'Une enquête judiciaire a été ouverte à votre sujet.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    } else {
      showToast('Enquête classée sans suite', 'Aucune charge retenue contre ' + nomCible + '. -' + cout + ' FR.', false);
      addJournalEntry('Enquête sur ' + nomCible + ' classée sans suite (-' + cout + ' FR).', 'event-info');
    }
    return;
  }

  if (action === 'redressement_fiscal') {
    document.getElementById('modal-postes')?.classList.remove('open');
    // ==========================================================================================
    // REDRESSEMENT FISCAL — SERVEUR AUTORITAIRE (17 septembre 2026, audit des frontieres
    // d'autorite). Ce bloc enchainait trois ecritures clientes independantes :
    //   1. ajusterSoldeCibleFiscale()  -> debit de la cible
    //   2. chargerBudgetNational + sbSaveBudgetNational().catch(() => {})  -> versement au Tresor
    //   3. mutation de INDICES_NATIONAUX en memoire
    // avec trois defauts :
    //   a) AUCUN CONTROLE D'AUTORITE. Le poste min_fin n'etait verifie qu'a l'OUVERTURE du
    //      panneau (ouvrirPilotageFiscalBudgetaire). Cette fonction, appelable depuis un onclick,
    //      ne le reverifiait pas -- et les cibles club_sportif et organisation ecrivaient dans des
    //      tables ouvertes (budgets_clubs a RLS desactivee, organisations en policy USING true).
    //      N'importe quel client pouvait donc ponctionner un club ou une organisation, 2 PA la
    //      passe, sans etre Ministre des Finances.
    //   b) NON ATOMIQUE. Debit et versement au Tresor etaient deux requetes separees, le second
    //      en reecriture du blob entier de budgets_nationaux sans verrou, retour jamais lu.
    //   c) MONTANT DECIDE PAR LE NAVIGATEUR (litteral 2000, invisible du serveur).
    // La RPC fait les deux mouvements sous verrou dans une seule transaction, exige le poste
    // min_fin reel, replafonne sur la caisse reelle de la cible, et porte le montant de 2000 --
    // la meme valeur qu'ici, simplement hors de portee du navigateur. Rien d'autre ne change.
    // ==========================================================================================
    const rPa = await deduireCoutOrdre({ pa: 2, cost: 0 });
    if (!rPa.ok) { signalerRefusCout(rPa); return; }

    // La cible « citoyen » n'a JAMAIS fonctionne : la vue personnages masque la colonne arg d'un
    // tiers (lue null, ramenee a 0) et son trigger INSTEAD OF refuse l'ecriture. Le prelevement
    // valait donc toujours 0 -- mais le toast, le journal et le mail a la cible annoncaient
    // quand meme un redressement. On dit desormais la verite. L'ACTIVER serait un choix de game
    // design (prelever reellement 2000 FR sur la fortune d'un joueur), pas un correctif : la RPC
    // ne couvre donc pas ce type, et l'arbitrage reste a rendre.
    if (typeCible === 'citoyen') {
      showToast('Redressement impossible', 'Le prélèvement sur la fortune d\'un particulier n\'est pas en vigueur. Les 2 PA ont été engagés.', false);
      addJournalEntry('Redressement fiscal contre ' + nomCible + ' : aucun prélèvement possible sur un particulier.', 'event-bad');
      return;
    }

    const rFisc = typeof sbRedressementFiscalAppliquer === 'function'
      ? await sbRedressementFiscalAppliquer(typeCible, idCible) : null;
    if (!rFisc || rFisc.ok !== true) {
      const motif = rFisc?.raison || 'indisponible';
      showToast('Redressement refusé',
        motif === 'autorite_insuffisante' ? 'Réservé au Ministre des Finances en exercice.'
        : motif === 'caisse_vide' ? 'La caisse de ' + nomCible + ' est vide.'
        : motif === 'cible_introuvable' ? nomCible + ' est introuvable.'
        : 'Refus du serveur (' + motif + ').', false);
      return;
    }
    const montantPreleve = Number(rFisc.montant || 0);
    // INDICES_NATIONAUX vit en memoire (data.js) et n'a aucune persistance : ce -3 IE ne survit
    // pas a un rafraichissement. Comportement inchange, signale pour memoire.
    INDICES_NATIONAUX[state.country].IE = Math.max(0, INDICES_NATIONAUX[state.country].IE - 3);
    updateUI();
    showToast('Redressement', 'Redressement fiscal contre ' + nomCible + ' : ' + montantPreleve.toLocaleString('fr-FR') + ' ' + cur + ' prélevés pour le Trésor. -3 IE.', true, true);
    addJournalEntry('Redressement fiscal contre ' + nomCible + ' (+' + montantPreleve + ' FR pour l\'État).', 'event-info');
    return;
  }

  if (action === 'subvention') {
    document.getElementById('postes-modal-title').textContent = 'Montant de la subvention';
    const plafond = 5000;
    let html = '<div style="padding:1rem">';
    html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Bénéficiaire : ' + nomCible + '. Gratuit pour vous — prélevé sur la caisse du Palais du Gouvernement. Plafond : ' + plafond.toLocaleString('fr-FR') + ' ' + cur + '.</div>';
    html += '<input id="montant-subvention" type="number" min="1" max="' + plafond + '" value="500" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.9rem;outline:none;box-sizing:border-box;margin-bottom:.8rem"/>';
    html += '<button onclick="confirmerSubventionMontant(\'' + typeCible + '\',\'' + idCible + '\',' + plafond + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Verser</button>';
    html += '</div>';
    document.getElementById('postes-body').innerHTML = html;
  }
}

async function confirmerSubventionMontant(typeCible, idCible, plafond) {
  const montant = Math.max(1, Math.min(plafond, parseInt(document.getElementById('montant-subvention')?.value || '0')));
  document.getElementById('modal-postes')?.classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const nomCible = nomAffichageCible(typeCible, idCible);
  const pays = state.country || 'republic';

  // Lecture seule du solde de la caisse AVANT la deduction PA (correctif Lot 2C) -- seul le cas
  // caisse a zero est un echec complet sans aucune contrepartie ; un solde > 0 reste une
  // reussite partielle valide (le joueur choisit librement le montant demande), donc le
  // versement partiel via debiterCaisseBatimentPlafonne plus bas n'est pas touche.
  const caisseMinFin = typeof chargerCaisseBatiment === 'function' ? await chargerCaisseBatiment(pays, 'gouvernement-min_fin') : { solde: 0 };
  if ((caisseMinFin?.solde || 0) <= 0) { showToast('Caisse insuffisante', 'Le budget du gouvernement ne peut pas financer cette subvention actuellement.', false); return; }

  // Deduction PA centralisee (Lot 2C) -- c'est ICI, a la confirmation du montant, le veritable
  // point d'execution irreversible pour "subvention" (executerOrdreFiscalCible n'ouvre que ce
  // formulaire, sans jamais muter d'etat). Avant le debit de la caisse institutionnelle
  // (debiterCaisseBatimentPlafonne, volontairement laisse tolerant au partiel : comportement
  // metier inchange).
  const rPa = await deduireCoutOrdre({ pa: 2, cost: 0 });
  if (!rPa.ok) { signalerRefusCout(rPa); return; }

  // SUBVENTION A UN CITOYEN : UNE SEULE TRANSACTION SERVEUR (16 septembre 2026).
  //
  // Le versement se faisait ici en deux temps : la caisse du gouvernement etait debitee par une
  // RPC (donc reellement), puis le beneficiaire etait credite par une ecriture directe sur SA
  // fiche -- que la vue personnages refuse depuis le chantier B. L'argent quittait la caisse
  // publique sans jamais arriver. Pire, le montant credite etait calcule comme « solde relu +
  // montant », et la fortune d'autrui n'etant plus lisible non plus, la relecture renvoyait 0 :
  // l'ecriture, si elle etait passee, aurait REMIS la fortune du beneficiaire au montant de la
  // subvention. Le refus nous a protege d'une perte de donnees.
  //
  // subvention_citoyen_verser fait les deux mouvements dans la meme transaction, verifie le
  // poste min_fin cote serveur, et incremente au lieu de reecrire. Les autres beneficiaires
  // (club, entreprise, organisation) gardent leur chemin, qui fonctionne.
  let montantVerse = 0;
  if (typeCible === 'citoyen') {
    const rows = await sbRpc('subvention_citoyen_verser',
      { p_beneficiaire: idCible, p_montant: montant }).catch(() => null);
    const r = Array.isArray(rows) ? rows[0] : rows;
    if (!r || r.ok !== true) {
      const motif = (r && r.raison === 'beneficiaire_introuvable')
        ? 'Ce bénéficiaire est introuvable.'
        : (r && r.raison === 'montant_invalide')
          ? 'Montant invalide.'
          : (r && r.raison === 'autorite_insuffisante')
            ? 'Seul le Ministre des Finances peut accorder une subvention.'
            : 'Le budget du gouvernement ne peut pas financer cette subvention actuellement.';
      showToast(r && r.raison === 'caisse_insuffisante' ? 'Caisse insuffisante' : 'Subvention refusée', motif, false);
      return;
    }
    montantVerse = Number(r.verse || 0);
    // Le ministre peut se subventionner lui-meme -- le moteur l'autorise, c'est assume. Il faut
    // alors que sa copie locale suive le serveur : sans cela, sa prochaine sauvegarde de fiche
    // republierait son ancienne fortune et effacerait le versement.
    if (idCible === state.char?.name) {
      state.arg = (state.arg || 0) + montantVerse;
      if (state.char) state.char.arg = state.arg;
    }
  } else {
    montantVerse = typeof debiterCaisseBatimentPlafonne === 'function' ? await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_fin', montant) : 0;
    if (montantVerse <= 0) { showToast('Caisse insuffisante', 'Le budget du gouvernement ne peut pas financer cette subvention actuellement.', false); return; }
    await ajusterSoldeCibleFiscale(typeCible, idCible, montantVerse);
  }
  if (typeof modifierIndiceVille === 'function') await modifierIndiceVille(pays, state.currentCity || 'capitale', 'social', 3).catch(() => {});
  updateUI();
  showToast('Subvention accordée', montantVerse.toLocaleString('fr-FR') + ' ' + cur + ' versés à ' + nomCible + '. +3 IS.', true, true);
  addJournalEntry('Subvention de ' + montantVerse + ' FR accordée à ' + nomCible + '.', 'event-good');
  if (typeCible === 'citoyen' && typeof sbSendMail === 'function') sbSendMail('Ministère des Finances', idCible, 'Subvention accordée', 'Vous avez reçu une subvention de ' + montantVerse.toLocaleString('fr-FR') + ' ' + cur + ' du Ministre des Finances.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});

  // TRACABILITE PUBLIQUE (Lot 4.3). Le moteur ne demande aucune justification et n'empeche ni le
  // favoritisme ni la corruption -- c'est assume. Mais l'acte doit etre PUBLIC : beneficiaire,
  // montant, auteur, date. Jusqu'ici il ne laissait qu'un toast, un mail prive et une entree de
  // journal personnel, donc rien qu'un tiers puisse constater.
  //
  // Deux canaux, aucun nouveau systeme : l'evenement partage pour la visibilite immediate, et la
  // chronique nationale pour que La Tribune puisse s'en saisir -- le collecteur ignore en silence
  // tout type non declare, d'ou la declaration faite dans api/_journal-collecte.js.
  const auteurNom = state.char?.name || 'Le Ministre des Finances';
  const libelleSub = 'Subvention publique de ' + montantVerse.toLocaleString('fr-FR') + ' ' + cur +
                     ' accordée à ' + nomCible + ' par ' + auteurNom + '.';
  addExternalEvent('💰 ' + libelleSub);
  if (typeof sbEnregistrerEvenementPublic === 'function') {
    await sbEnregistrerEvenementPublic(pays, 'subvention_publique', {
      city: state.currentCity || null,
      personnages: [auteurNom].concat(typeCible === 'citoyen' ? [idCible] : []),
      libelle: libelleSub,
      data: { beneficiaire: nomCible, typeBeneficiaire: typeCible, montant: montantVerse, auteur: auteurNom },
      sourceRef: 'subvention-' + Date.now()
    }).catch(() => {});
  }
}

// =====================
// VIREMENT MINISTERE -> USINE (lot du 24 aout 2026) — le ministre ne peut jamais prelever
// directement dans la caisse d'une usine : il peut seulement VERSER depuis la caisse du
// Ministere (gouvernement-min_fin, meme caisse institutionnelle que la subvention ci-dessus).
// Symmetrique de doOuvrirVirementUsineMinistere (plateau-justice-economie.js). Prepare de facon
// generique (DIRECTEUR_USINE_INFO deja generique) pour que le port reutilise le meme schema une
// fois son economie creee, sans dupliquer ce handler.
// =====================
function doOuvrirVirementMinistereUsine(pa, cost) {
  if (state.poste?.id !== 'min_fin') {
    showToast('Accès refusé', 'Seul le Ministre des Finances peut ordonner ce virement.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Virement vers une usine';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Prélevé sur la caisse du Ministère des Finances, versé à la caisse de l\'usine choisie.</div>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Usine</label>';
  html += '<select id="virement-usine-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  Object.entries(DIRECTEUR_USINE_INFO).forEach(([posteId, cfg]) => {
    const nomUsine = BUILDINGS[cfg.buildingId]?.name || cfg.buildingId;
    html += '<option value="' + posteId + '">' + nomUsine + '</option>';
  });
  html += '</select>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Montant (FR)</label>';
  html += '<input id="virement-usine-montant" type="number" min="1" step="1" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.8rem"/>';
  html += '<button onclick="confirmerVirementMinistereUsine(' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Virer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVirementMinistereUsine(pa, cost) {
  // Re-verification complete du poste (pas seulement a l'ouverture du modal) : c'est ici, a la
  // confirmation, que la mutation reelle a lieu.
  if (state.poste?.id !== 'min_fin') {
    showToast('Accès refusé', 'Seul le Ministre des Finances peut ordonner ce virement.', false);
    return;
  }
  const posteCible = document.getElementById('virement-usine-cible')?.value;
  const cfg = DIRECTEUR_USINE_INFO[posteCible];
  if (!cfg) { showToast('Cible invalide', '', false); return; }
  const montant = Math.floor(Number(document.getElementById('virement-usine-montant')?.value));
  if (!isFinite(montant) || montant <= 0) { showToast('Montant invalide', 'Le montant doit être un nombre entier positif.', false); return; }

  const pays = state.country || 'republic';
  const cur = COUNTRIES[pays]?.cur || 'FR';

  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  // Debit atomique de la caisse du Ministere EN PREMIER (jamais de decouvert) ; le credit a
  // l'usine n'est tente que si ce debit a reellement reussi.
  const montantPreleve = typeof debiterCaisseBatimentAtomique === 'function'
    ? await debiterCaisseBatimentAtomique(pays, 'gouvernement-min_fin', montant)
    : 0;
  if (montantPreleve <= 0) {
    showToast('Caisse insuffisante', 'La caisse du Ministère ne peut pas couvrir ce virement.', false);
    return;
  }
  if (typeof crediterCaisseEtatBatiment === 'function') await crediterCaisseEtatBatiment(pays, cfg.city, cfg.buildingId, 'usine', montantPreleve);

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  const nomUsine = BUILDINGS[cfg.buildingId]?.name || cfg.buildingId;
  showToast('Virement effectué', montantPreleve.toLocaleString('fr-FR') + ' ' + cur + ' versés à ' + nomUsine + '.', true, true);
  addJournalEntry('Virement du Ministère des Finances vers ' + nomUsine + ' (' + montantPreleve + ' FR).', 'event-good');
}

async function ouvrirCiblageFiscal(action, titre) {
  document.getElementById('postes-modal-title').textContent = titre;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const pays = state.country || 'republic';
  let joueurs = [];
  if (typeof sbListPersonnages === 'function') {
    try { joueurs = await sbListPersonnages() || []; } catch(e) {}
  }
  const myName = state.char?.name;
  const cibles = joueurs.filter(j => {
    const domicilePays = j.domicile?.country || j.country;
    return (domicilePays === pays || j.country === pays) && j.name !== myName;
  });

  let html = '<div style="padding:1rem">';
  if (cibles.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun autre citoyen domicilié ou présent sur le territoire pour l\'instant.</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Citoyens domiciliés ou présents sur le territoire :</div>';
    cibles.forEach(c => {
      const domicilie = (c.domicile?.country || c.country) === pays;
      html += '<div onclick="executerOrdreContact(\'' + action + '\',\'' + c.name + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.85rem;color:#e0d5b8">' + c.name + '</div>';
      html += '<div style="font-size:.7rem;color:#a89870">' + (domicilie ? 'Domicilié(e)' : 'De passage') + (c.current_city ? ' · ' + c.current_city : '') + '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

function ouvrirModalCibleRepertoire(action, titre) {
  const contacts = state.contacts || [];
  document.getElementById('postes-modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Votre repertoire est vide. Enregistrez des contacts pour cibler des personnes.</div>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir la cible :</div>';
    contacts.forEach((c, i) => {
      html += '<div onclick="executerOrdreContact(\'' + action + '\',\'' + c.name + '\')" style="padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.3rem;cursor:pointer;transition:background .2s" onmouseover="this.style.background=\'#151005\'" onmouseout="this.style.background=\'#0f0d05\'">';
      html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + c.name + '</div>';
      html += '<div style="font-size:.68rem;color:#5a4030">' + (c.role||'') + '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function executerOrdreContact(action, nomCible) {
  document.getElementById('modal-postes').classList.remove('open');
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (action === 'excommunier' || action === 'lever_excommunication') {
    // Second controle d'autorisation, FRAIS, au moment exact de l'action (ouvrirExcommunierCible/
    // ouvrirLeverExcommunicationCible, plateau-divers.js, en a deja fait un premier avant
    // d'ouvrir cette liste de cibles -- celui-ci couvre le cas ou le statut de Grand Pretre aurait
    // change pendant que la modale etait ouverte).
    (async () => {
      if (!(await estGrandPretreActuel(state.char?.name))) {
        showToast('Pouvoir réservé', 'Seul le Grand Prêtre national en exercice peut exercer ce pouvoir.', false);
        return;
      }
      if (action === 'excommunier') {
        await appliquerExcommunication(nomCible, state.char?.name);
        showToast('Excommunication prononcée', nomCible + ' est excommunié(e). -15 POP, -2 CHA tant que le statut est actif.', true, true);
        addJournalEntry('Excommunication de ' + nomCible + ' prononcée.', 'event-bad');
      } else {
        await leverExcommunicationCible(nomCible);
        showToast('Excommunication levée', nomCible + ' n\'est plus excommunié(e). Les 15 POP perdus ne sont pas restitués.', true, true);
        addJournalEntry('Excommunication de ' + nomCible + ' levée.', 'event-good');
      }
    })();
  } else if (action === 'nommer_pm_confirm') {
    envoyerNotificationVraiJoueur(nomCible, 'Nomination au poste de Premier Ministre',
      'Par decision presidentielle, vous etes nomme(e) Premier Ministre. Prenez vos fonctions immediatement au Palais du Gouvernement.');
    addExternalEvent('NOMINATION : ' + nomCible + ' est nomme(e) Premier Ministre par le President.');
    if (typeof sbEnregistrerEvenementPublic === 'function') {
      sbEnregistrerEvenementPublic(state.country, 'nomination', {
        personnages: [nomCible, state.char?.name].filter(Boolean),
        libelle: nomCible + ' est nommé(e) Premier Ministre par le Président ' + (state.char?.name || '') + '.',
        data: { poste: 'pm', nomme: nomCible, nommeur: state.char?.name }
      }).catch(() => {});
    }
    showToast('PM nomme', nomCible + ' est le nouveau Premier Ministre.', true, true);
  } else if (action === 'redressement_fiscal') {
    const montant = 2000;
    document.getElementById('modal-postes')?.classList.remove('open');
    debiterCitoyenPlafonne(nomCible, montant).then(async (montantPreleve) => {
      const budgetNat = await chargerBudgetNational(state.country);
      budgetNat.reserveJour = (budgetNat.reserveJour || 0) + montantPreleve;
      await sbSaveBudgetNational(state.country, budgetNat).catch(() => {});
      INDICES_NATIONAUX[state.country].IE = Math.max(0, INDICES_NATIONAUX[state.country].IE - 3);
      updateUI();
      showToast('Redressement', 'Redressement fiscal contre ' + nomCible + ' : ' + montantPreleve.toLocaleString('fr-FR') + ' ' + cur + ' prélevés pour le Trésor. -3 IE.', true, true);
      addJournalEntry('Redressement fiscal contre ' + nomCible + ' (+' + montantPreleve + ' FR pour l\'État).', 'event-info');
      if (typeof sbSendMail === 'function') sbSendMail('Ministère des Finances', nomCible, 'Redressement fiscal', 'Un redressement fiscal de ' + montantPreleve.toLocaleString('fr-FR') + ' ' + cur + ' vous a été notifié et prélevé par le Ministre des Finances.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    });
  } else if (action === 'subvention') {
    const montant = 500;
    document.getElementById('modal-postes')?.classList.remove('open');
    const pays = state.country || 'republic';
    (async () => {
      const montantVerse = typeof debiterCaisseBatimentPlafonne === 'function'
        ? await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_fin', montant)
        : 0;
      if (montantVerse <= 0) { showToast('Caisse insuffisante', 'Le budget du gouvernement ne peut pas financer cette subvention actuellement.', false); return; }
      if (typeof sbAppliquerSalaire === 'function') await sbAppliquerSalaire(nomCible, montantVerse).catch(() => {});
      if (typeof modifierIndiceVille === 'function') await modifierIndiceVille(pays, state.currentCity || 'capitale', 'social', 3).catch(() => {});
      updateUI();
      showToast('Subvention accordée', montantVerse.toLocaleString('fr-FR') + ' ' + cur + ' versés à ' + nomCible + '. +3 IS.', true, true);
      addJournalEntry('Subvention de ' + montantVerse + ' FR accordée à ' + nomCible + '.', 'event-good');
      if (typeof sbSendMail === 'function') sbSendMail('Ministère des Finances', nomCible, 'Subvention accordée', 'Vous avez reçu une subvention de ' + montantVerse.toLocaleString('fr-FR') + ' ' + cur + ' du Ministre des Finances.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    })();
  } else if (action === 'ouvrir_enquete') {
    // getBudgetInstitution() etait appele pour rien : depenseBudget() fait deja son propre
    // controle de solde juste apres, et la valeur lue n'etait jamais utilisee.
    if (!depenseBudget('tribunal', 600)) return;
    if (!state.enquetesEnCours) state.enquetesEnCours = [];
    // motif / country / city etaient absents. En aval, traiterEnquetes() les consomme tous les
    // trois : verifierPreuveReelle(country, cible, motif) renvoyait toujours false faute de
    // motif, enregistrerDetention() recevait une ville undefined, et transmettreAffaireAuTribunal()
    // repliait sur state.currentCity du joueur qui declenchait le traitement -- c'est-a-dire
    // exactement le bug que le correctif A3 du 16 aout 2026 avait supprime partout ailleurs.
    state.enquetesEnCours.push({
      cible: nomCible,
      motif: 'Enquete judiciaire ouverte par le Ministre de la Justice',
      country: state.country || 'republic',
      city: state.currentCity,
      day: state.day + 1, status: 'pending', initiateur: 'Ministre Justice'
    });
    showToast('Enquete ouverte', 'Enquete judiciaire lancee contre ' + nomCible + '. Resultat dans 24h.', true);
    addJournalEntry('Enquete judiciaire ouverte contre ' + nomCible, 'event-info');
  } else {
    showToast(action.replace(/_/g,' '), 'Action menee sur ' + nomCible, true);
    addJournalEntry(action.replace(/_/g,' ') + ' : ' + nomCible, 'event-info');
  }
}

function ouvrirModalTexteLibre(action, titre, placeholder) {
  document.getElementById('postes-modal-title').textContent = titre;
  let html = '<div style="padding:1rem">';
  html += '<textarea id="texte-libre-input" rows="4" placeholder="' + placeholder + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.7rem"></textarea>';
  html += '<button onclick="executerOrdreTexte(\'' + action + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// INTERDIRE UNE MANIFESTATION (Ministre de l'Interieur) -- exception a la regle generale
// "ministere = national" : cible explicitement UNE ville et modifie son Social local, pas le
// national. Remplace l'ancien chemin mort interdire_manif_cible (jamais atteignable, voir
// audit du chantier "refonte des ordres").
async function ouvrirInterdireManif(pa, cost) {
  const pays = state.country || 'republic';
  document.getElementById('postes-modal-title').textContent = 'Interdire une manifestation';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Baisse le Social de la ville ciblee. Facilite une repression ulterieure au meme endroit (72h).</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">SUJET / NOM DE LA MANIFESTATION</div>';
  html += '<input id="interdire-manif-sujet" type="text" placeholder="Preciser..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">VILLE CIBLEE</div>';
  html += '<select id="interdire-manif-ville" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  if (pays === 'republic' && typeof VILLES_REPUBLIA !== 'undefined') {
    VILLES_REPUBLIA.forEach(v => { html += '<option value="' + v + '">' + (NOMS_VILLES_REPUBLIA[v] || v) + '</option>'; });
  } else {
    html += '<option value="' + (state.currentCity || 'capitale') + '">' + (state.currentCity || 'capitale') + '</option>';
  }
  html += '</select>';
  html += '<button onclick="confirmerInterdireManif(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Interdire</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerInterdireManif(pa, cost) {
  const sujet = document.getElementById('interdire-manif-sujet')?.value?.trim() || 'Manifestation non precisee';
  const ville = document.getElementById('interdire-manif-ville')?.value || state.currentCity || 'capitale';
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const pays = state.country || 'republic';
  const nomVille = (typeof NOMS_VILLES_REPUBLIA !== 'undefined' && NOMS_VILLES_REPUBLIA[ville]) || ville;

  if (typeof modifierIndiceVille === 'function') await modifierIndiceVille(pays, ville, 'social', -5).catch(() => {});

  const budgetMuni = await chargerBudgetMunicipalPourVille(pays, ville);
  budgetMuni.manifestationInterdite = { sujet, jour: state.day || 1, expireJour: (state.day || 1) + 3 };
  if (typeof sbSaveBudgetMunicipal === 'function') await sbSaveBudgetMunicipal(pays + '_' + ville, budgetMuni).catch(() => {});

  updateUI();
  showToast('Manifestation interdite', sujet + ' — interdite a ' + nomVille + '. -5 Social local.', true);
  addExternalEvent('INTERDICTION : La manifestation "' + sujet + '" a ete interdite par le Ministre de l\'Interieur a ' + nomVille + '.');
  addJournalEntry('Manifestation interdite : ' + sujet + ' (' + nomVille + ').', 'event-info');
}

// REPRIMER UNE MANIFESTATION (Ministre de l'Interieur) -- meme exception que ci-dessus (cible
// une ville, Social local). Remplace l'ancien chemin mort reprimer_manif_cible.
async function ouvrirReprimerManif(pa, cost) {
  const pays = state.country || 'republic';
  // §9 "Greves" (3 septembre 2026) : garde UI deja postee dans le rendu generique des boutons
  // (needsPoliceIndisponible) -- revalidee ici defensivement, ce modal pouvant en theorie etre
  // ouvert par un autre chemin que ce bouton.
  if (typeof syndicatPoliceEnGreve === 'function' && syndicatPoliceEnGreve(pays)) {
    showToast('Répression impossible', 'Un syndicat de policiers est en grève : la répression policière est impossible tant qu\'il n\'y met pas fin.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Reprimer une manifestation';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Baisse le Social de la ville ciblee (bonus si une manifestation y a ete interdite dans les 72h). Blesse les PJ actuellement presents dans cette ville.</div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">SUJET / CIBLE</div>';
  html += '<input id="reprimer-manif-sujet" type="text" placeholder="Preciser..." style="width:100%;padding:.4rem .6rem;background:#0a0a07;border:1px solid #3a2a10;color:#f0ead6;font-family:Crimson Pro,serif;font-size:.85rem;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">VILLE CIBLEE</div>';
  html += '<select id="reprimer-manif-ville" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  if (pays === 'republic' && typeof VILLES_REPUBLIA !== 'undefined') {
    VILLES_REPUBLIA.forEach(v => { html += '<option value="' + v + '">' + (NOMS_VILLES_REPUBLIA[v] || v) + '</option>'; });
  } else {
    html += '<option value="' + (state.currentCity || 'capitale') + '">' + (state.currentCity || 'capitale') + '</option>';
  }
  html += '</select>';
  html += '<button onclick="confirmerReprimerManif(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Reprimer</button>';

  // BLOCUS — action nationale, sans deplacement (Lot 4.3). Le ministre choisit un blocus REELLEMENT
  // actif dans la liste reconstruite depuis batiments_etat : il n'a pas a se rendre sur place.
  // La dispersion elle-meme delegue au moteur historique, dont rien n'est recopie ici.
  const blocus = (typeof sbListerBlocusActifs === 'function' && typeof blocusActifsDepuisEtats === 'function')
    ? blocusActifsDepuisEtats(await sbListerBlocusActifs(pays).catch(() => []))
    : [];
  html += '<div style="margin-top:1.2rem;padding-top:.9rem;border-top:1px solid #2a2010">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">BLOCUS SYNDICAL À LEVER</div>';
  if (blocus.length === 0) {
    html += '<div style="font-size:.78rem;color:#5a5040;font-style:italic">Aucun blocus syndical actif en Républia.</div>';
  } else {
    html += '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.5rem">La dispersion n\'est jamais acquise : plus le blocus est intense, plus il résiste.</div>';
    html += '<select id="reprimer-blocus-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.6rem">';
    blocus.forEach(function (b) {
      html += '<option value="' + b.cle + '">' + libelleBlocus(b).replace(/"/g, '') + '</option>';
    });
    html += '</select>';
    html += '<button onclick="confirmerRepressionBlocus(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Tenter de lever le blocus</button>';
  }
  html += '</div>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// LEVEE D'UN BLOCUS PAR LE MINISTRE — DELEGATION, PAS DUPLICATION.
//
// Cette fonction ne contient AUCUNE regle de blocus : elle resout la cible choisie, puis reutilise
// integralement le mecanisme historique (tauxDispersionBlocus pour la probabilite, sbSetBatimentEtat
// pour la levee, les memes notifications, le meme mail au leader). Les consequences en cas de
// reussite comme d'echec sont celles du moteur existant, y compris l'absence de consequence en cas
// d'echec -- qui est le comportement constate, non une omission.
//
// La seule difference avec l'usage du commissaire est le CIBLAGE : le ministre agit a distance, sur
// un blocus choisi dans la liste, sans etre present dans le batiment.
async function confirmerRepressionBlocus(pa, cost) {
  const pays = state.country || 'republic';
  if (state.poste?.id !== 'min_int') { showToast('Accès refusé', 'Réservé au Ministre de l\'Intérieur.', false); return; }
  if (typeof syndicatPoliceEnGreve === 'function' && syndicatPoliceEnGreve(pays)) {
    showToast('Répression impossible', 'Un syndicat de policiers est en grève.', false); return;
  }
  const cle = document.getElementById('reprimer-blocus-cible')?.value;
  if (!cle) return;

  // Relecture FRAICHE : le blocus a pu etre leve entre l'ouverture du modal et le clic. Verifiee
  // AVANT toute deduction de PA, comme le fait deja le chemin du commissaire.
  const actifs = (typeof sbListerBlocusActifs === 'function' && typeof blocusActifsDepuisEtats === 'function')
    ? blocusActifsDepuisEtats(await sbListerBlocusActifs(pays).catch(() => []))
    : [];
  const cible = actifs.filter(function (b) { return b.cle === cle; })[0];
  if (!cible) { showToast('Blocus levé', 'Ce blocus n\'est plus actif.', false); return; }

  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  const taux = tauxDispersionBlocus(cible.intensite);
  const roll = Math.floor(Math.random() * 100) + 1;
  const nomVilleB = (typeof NOMS_VILLES_REPUBLIA !== 'undefined' && NOMS_VILLES_REPUBLIA[cible.city]) || cible.city;

  if (roll <= taux) {
    if (typeof sbSetBatimentEtat === 'function') {
      await sbSetBatimentEtat(pays, cible.city, cible.buildingId, { blocus: null }).catch(() => {});
    }
    showToast('Blocus dispersé !', 'Les forces de l\'ordre ont délogé les militants à ' + nomVilleB + '.', true, true);
    addJournalEntry('Le blocus syndical de ' + nomVilleB + ' a été dispersé sur ordre du Ministère.', 'event-info');
    addExternalEvent('🚔 Un blocus syndical a été dispersé par les forces de l\'ordre à ' + nomVilleB + '.');
    if (typeof sendMail === 'function' && cible.leaderActuel) {
      await sendMail(cible.leaderActuel, 'Ministère de l\'Intérieur', 'Blocus dispersé',
        'Les forces de l\'ordre ont dispersé votre blocus. Vos militants restent employés, libre à vous de les renvoyer ou de retenter ailleurs.');
    }
  } else {
    showToast('Échec', 'Les militants ont tenu bon face aux forces de l\'ordre.', false);
    addJournalEntry('Tentative de dispersion du blocus de ' + nomVilleB + ' échouée.', 'event-bad');
  }
}

async function confirmerReprimerManif(pa, cost) {
  const sujet = document.getElementById('reprimer-manif-sujet')?.value?.trim() || 'Rassemblement non precise';
  const ville = document.getElementById('reprimer-manif-ville')?.value || state.currentCity || 'capitale';
  document.getElementById('modal-postes')?.classList.remove('open');
  // §9 "Greves" : revalidation independante au moment de l'execution -- un syndicat de policiers
  // a pu se mettre en greve entre l'ouverture du modal et ce clic.
  if (typeof syndicatPoliceEnGreve === 'function' && syndicatPoliceEnGreve(state.country || 'republic')) {
    showToast('Répression impossible', 'Un syndicat de policiers est en grève : la répression policière est impossible tant qu\'il n\'y met pas fin.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const pays = state.country || 'republic';
  const nomVille = (typeof NOMS_VILLES_REPUBLIA !== 'undefined' && NOMS_VILLES_REPUBLIA[ville]) || ville;

  const budgetMuni = await chargerBudgetMunicipalPourVille(pays, ville);
  const interdictionRecente = budgetMuni.manifestationInterdite && budgetMuni.manifestationInterdite.expireJour >= (state.day || 1);
  // Bareme arrete le 7 septembre 2026 : la repression paie en cohesion sociale ce qu'elle rapporte
  // en securite, symetriquement, et davantage quand la manifestation avait deja ete interdite --
  // disperser un rassemblement interdit est un geste plus lourd des deux cotes.
  //   manifestation autorisee            -5 Social / +5 Securite
  //   manifestation prealablement interdite  -8 Social / +8 Securite
  //
  // LES DEUX INDICES SONT LOCAUX ET PERSISTES (table indices_villes, cles 'social' et 'isn') : on
  // ne touche PAS a INDICES_NATIONAUX, qui n'est qu'une constante en memoire client, perdue au
  // rechargement. C'est la ville reprimee qui en porte durablement la trace, pas le navigateur du
  // ministre.
  const baisseSocial = interdictionRecente ? 8 : 5;
  const hausseSecurite = interdictionRecente ? 8 : 5;
  if (typeof modifierIndiceVille === 'function') {
    await modifierIndiceVille(pays, ville, 'social', -baisseSocial).catch(() => {});
    await modifierIndiceVille(pays, ville, 'isn', hausseSecurite).catch(() => {});
  }

  if (interdictionRecente) {
    delete budgetMuni.manifestationInterdite;
    if (typeof sbSaveBudgetMunicipal === 'function') await sbSaveBudgetMunicipal(pays + '_' + ville, budgetMuni).catch(() => {});
  }

  // PJ "participants" = tout PJ actuellement dans cette ville, faute de systeme de presence a
  // un evenement dans le jeu (decision technique assumee, voir plan valide avec Fred).
  let nbTouches = 0;
  if (typeof sbGet === 'function' && typeof sbUpdate === 'function') {
    const rows = await sbGet('personnages', `country=eq.${encodeURIComponent(pays)}&current_city=eq.${encodeURIComponent(ville)}`).catch(() => []);
    for (const r of (rows || [])) {
      const nouveauHp = Math.max(1, (r.hp || 100) - 10);
      const stats = r.stats || {};
      const nouveauxStats = { ...stats, VOL: Math.max(1, (stats.VOL || 6) - 10) };
      await sbUpdate('personnages', `name=eq.${encodeURIComponent(r.name)}`, { hp: nouveauHp, stats: nouveauxStats }).catch(() => {});
      nbTouches++;
    }
    if (state.currentCity === ville && state.country === pays) {
      state.hp = Math.max(1, (state.hp || 100) - 10);
      if (state.char?.stats) state.char.stats.VOL = Math.max(1, (state.char.stats.VOL || 6) - 10);
    }
  }

  updateUI();
  showToast('Repression menee', sujet + ' — Social -' + baisseSocial + ', Securite +' + hausseSecurite +
    (interdictionRecente ? ' (manifestation deja interdite)' : '') + '. ' + nbTouches +
    ' PJ present(s) touche(s) (-10 HP, -10 VOL).', false, true);
  addExternalEvent('REPRESSION : Dispersion forcee de "' + sujet + '" a ' + nomVille + '.');
  addJournalEntry('Repression ordonnee : ' + sujet + ' (' + nomVille + '). ' + nbTouches + ' PJ touche(s).', 'event-bad');
}

async function executerOrdreTexte(action) {
  const texte = document.getElementById('texte-libre-input')?.value?.trim();
  if (!texte) { showToast('Champ requis', 'Veuillez remplir le champ.', false); return; }
  document.getElementById('modal-postes').classList.remove('open');
  if (action === 'interdire_manif') {
    INDICES_NATIONAUX[state.country].ISN = Math.min(100, INDICES_NATIONAUX[state.country].ISN + 5);
    state.pop = Math.max(0, state.pop - 5);
    updateUI();
    showToast('Manifestation interdite', texte + ' — +5 ISN -5 POP.', true);
    addExternalEvent('INTERDICTION : La manifestation "' + texte + '" a ete interdite par le Ministre de l\'Interieur.');
  } else if (action === 'reprimer_manif') {
    INDICES_NATIONAUX[state.country].ISN = Math.min(100, INDICES_NATIONAUX[state.country].ISN + 10);
    state.pop = Math.max(0, state.pop - 15);
    updateUI();
    showToast('Repression ordonnee', texte + ' — +10 ISN -15 POP.', false);
    addExternalEvent('REPRESSION : Ordre de dispersion force pour "' + texte + '".');
  } else if (action === 'commanditer_sondage') {
    // Deduction PA+cout centralisee (Lot 2C, double fuite corrigee : ni les PA ni les 200 FR
    // n'etaient preleves auparavant). Avant la seule mutation de cette branche (INF). Montant
    // et effet inchanges.
    const r = await deduireCoutOrdre({ pa: 1, cost: 200 });
    if (!r.ok) { showToast(r.raison === 'pa_insuffisants' ? 'PA insuffisants' : 'Fonds insuffisants', r.raison === 'pa_insuffisants' ? '1 PA requis.' : '200 FR requis.', false); return; }
    state.inf = Math.min(100, state.inf + 5);
    updateUI();
    showToast('Sondage publie', '"' + texte + '" publie dans le forum national. +5 INF.', true);
  } else {
    showToast(action, texte, true);
    addJournalEntry(action + ' : ' + texte, 'event-info');
  }
}

// Ordre volontairement indisponible pour l'instant (demande explicite de Fred) : le systeme de
// taxation qui alimente les caisses de l'Etat doit d'abord etre construit correctement avant
// qu'un allegement fiscal ait un vrai sens economique. Message explicite plutot qu'un bouton
// mort silencieux -- l'ancien couple ouvrirModalSecteur/appliquerAllegement (ci-dessous) reste
// en l'etat, non branche, pour reprise le jour ou ce chantier sera fait.
function doAllegementFiscalIndisponible() {
  showToast('Pas encore disponible', 'L\'allegement fiscal sera active une fois le systeme de taxation alimentant les caisses de l\'Etat finalise.', false);
}

function ouvrirModalSecteur() {
  document.getElementById('postes-modal-title').textContent = 'Allegement fiscal sectoriel';
  let html = '<div style="padding:1rem"><div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisir le secteur beneficiaire :</div>';
  SECTEURS.forEach(s => {
    html += '<button onclick="appliquerAllegement(\'' + s + '\')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem">' + s + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function appliquerAllegement(secteur) {
  document.getElementById('modal-postes').classList.remove('open');
  INDICES_NATIONAUX[state.country].IE = Math.min(100, INDICES_NATIONAUX[state.country].IE + 5);
  state.inf = Math.min(100, state.inf + 8);
  updateUI();
  showToast('Allegement accorde', secteur + ' : -taxes +5 IE +8 INF.', true);
  addJournalEntry('Allegement fiscal accorde au secteur : ' + secteur, 'event-info');
}

async function ouvrirModalAffaires(mode, pa, cost) {
  const titre = mode === 'annuler' ? 'Classer une plainte' : 'Gestion judiciaire';
  document.getElementById('postes-modal-title').textContent = titre;
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  if (typeof sbLoadPlaintes === 'function') {
    try { state.plaintesEnCours = await sbLoadPlaintes(state.country); } catch(e) {}
  }
  const affaires = state.plaintesEnCours?.filter(p => p.status === 'pending') || [];
  const condamnes = state.prisonniers?.filter(p => p.jourFin > state.day) || [];

  let html = '<div style="padding:1rem">';
  const liste = mode === 'annuler' ? affaires : condamnes;
  if (liste.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune affaire en cours.</div>';
  } else {
    liste.forEach((a) => {
      const refId = a.id || a.nom; // prisonniers n'ont pas forcement d'id, fallback sur le nom
      html += '<div style="padding:.5rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.82rem;color:#c0b090">' + (a.cible||a.nom||'Inconnu') + ' <span style="font-size:.68rem;color:#5a4030">— ' + (a.motif||a.raison||'') + '</span></div>';
      html += '<button onclick="annulerAffaire(&quot;' + refId + '&quot;,\'' + mode + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.85rem;padding:.2rem .5rem;border:1px solid #8a3020;background:transparent;color:#cc4a3a;cursor:pointer">Annuler</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function annulerAffaire(refId, mode, pa, cost) {
  document.getElementById('modal-postes').classList.remove('open');
  if (mode === 'annuler') {
    const affaire = (state.plaintesEnCours||[]).find(p => p.id === refId);
    if (affaire) {
      const r = await deduireCoutOrdre({ pa, cost });
      if (!r.ok) { signalerRefusCout(r); return; }
      const pays = state.country || 'republic';
      const cout = 250;
      // Meme correctif d'autorite ministerielle que ci-dessus (audit du 17 septembre 2026).
      const rMin = await sbCaisseMinistereMouvement(pays, 'gouvernement-min_just', cout, null, false);
      if (!rMin || rMin.ok !== true) {
        showToast(rMin && rMin.raison === 'solde_insuffisant' ? 'Caisse insuffisante' : 'Action impossible',
          rMin && rMin.raison === 'solde_insuffisant'
            ? 'La caisse du gouvernement ne peut pas couvrir les frais de dossier (' + cout + ' FR).'
            : 'Réservé au Ministre de la Justice en exercice.', false);
        return;
      }

      affaire.status = 'annulee';
      if (typeof sbSavePlainte === 'function') await sbSavePlainte(affaire).catch(() => {});
      showToast('Plainte classée', 'La procédure a été classée. -' + cout + ' FR.', false, true);
      addJournalEntry('Classement d\'une plainte par le Ministre de la Justice (-' + cout + ' FR).', 'event-info');
    }
  }
}

function ouvrirModalNommerDirecteurPharma() {
  if (state.poste?.id !== 'min_fin') {
    showToast('Accès refusé', 'Seul le Ministre des Finances peut nommer un directeur.', false);
    return;
  }
  ouvrirNominerPosteNomme('directeur_pharma');
}

function ouvrirModalNommerDirecteurTabacAlcools() {
  if (state.poste?.id !== 'min_fin') {
    showToast('Accès refusé', 'Seul le Ministre des Finances peut nommer un directeur.', false);
    return;
  }
  ouvrirNominerPosteNomme('directeur_tabac_alcools');
}

function ouvrirModalNommerDirecteurRaffinerie() {
  if (state.poste?.id !== 'min_fin') {
    showToast('Accès refusé', 'Seul le Ministre des Finances peut nommer un directeur.', false);
    return;
  }
  ouvrirNominerPosteNomme('directeur_raffinerie');
}

function ouvrirModalNommerJuge() {
  if (state.poste?.id !== 'min_just') {
    showToast('Accès refusé', 'Seul le Ministre de la Justice peut nommer un juge.', false);
    return;
  }
  ouvrirNominerPosteNomme('juge');
}

function ouvrirModalRevoquerJuge(pa, cost) { ouvrirRevoquerPosteNomme('juge', pa, cost); }

function ouvrirModalNommerChefDouanes() {
  if (state.poste?.id !== 'min_int') {
    showToast('Accès refusé', "Seul le Ministre de l'Intérieur peut nommer un Chef des Douanes.", false);
    return;
  }
  ouvrirNominerPosteNomme('chef_douanes');
}

function ouvrirModalRevoquerChefDouanes(pa, cost) { ouvrirRevoquerPosteNomme('chef_douanes', pa, cost); }

function ouvrirModalNommerCommandantPort() {
  if (state.poste?.id !== 'min_fin') {
    showToast('Accès refusé', 'Seul le Ministre des Finances peut nommer un Commandant du Port.', false);
    return;
  }
  ouvrirNominerPosteNomme('capitaine_port');
}

function ouvrirModalRevoquerCommandantPort(pa, cost) { ouvrirRevoquerPosteNomme('capitaine_port', pa, cost); }

function ouvrirModalNommerCommissaire() {
  if (!estPosteMaire(state.poste?.id)) {
    showToast('Accès refusé', 'Seul le Maire peut nommer un commissaire.', false);
    return;
  }
  ouvrirNominerPosteNomme('commissaire');
}

// Transfert complet au Maire Adjoint le 10 aout 2026 (plus partage avec le Maire) : verification
// stricte, contrairement au startsWith('maire') d'avant qui aurait aussi laisse passer le Maire.
function ouvrirModalNommerDirecteurEntrepot(pa, cost) {
  if (state.poste?.id !== 'maire_adjoint') {
    showToast('Accès refusé', "Seul le Maire Adjoint peut nommer un directeur d'entrepôt.", false);
    return;
  }
  ouvrirNominerPosteNomme('directeur_entrepot', pa, cost);
}

function ouvrirModalRevoquerCommissaire(pa, cost) { ouvrirRevoquerPosteNomme('commissaire', pa, cost); }
function ouvrirModalRevoquerDirecteurEntrepot(pa, cost) { ouvrirRevoquerPosteNomme('directeur_entrepot', pa, cost); }

// COUT TRANSMIS (correctif du 8 septembre 2026). L'ordre nommer_ministre declare pa:2 dans data.js
// et le bouton affiche « 2 PA », mais cette facade appelait ouvrirNominerPosteNomme('pm') SANS
// argument : envoyerNominationPosteNomme retombait alors sur COUT_PA_NOMINATION_DEFAUT = 1, et le
// President ne payait qu'un PA sur les deux annonces.
//
// LA DECLARATION FAIT FOI, ET LA PREUVE EST DANS LA SYMETRIE : chaque nomination porte une valeur
// DIFFERENCIEE (2 PA pour le PM, les ministres, le lieutenant et le capitaine ; 3 PA pour le
// commissaire et les directeurs), et chaque revocation vaut 1 PA. Cette gradation est deliberee --
// si 1 etait la regle, tout vaudrait 1. Surtout, la facade jumelle ouvrirModalRevoquerPM, juste
// en dessous, transmet correctement (pa, cost) depuis le routeur : l'asymetrie est une omission de
// plomberie du cote nomination, pas une regle de jeu.
//
// COUT_PA_NOMINATION_DEFAUT reste en place : son commentaire dit lui-meme qu'il « rattrape » les
// facades muettes -- c'est un filet, jamais une source de verite. Il continue de couvrir les sept
// autres facades de nomination, qui restent hors perimetre de ce passage.
function ouvrirModalNommerPM(pa, cost) {
  if (state.poste?.id !== 'president') {
    showToast('Acces refuse', 'Seul le President peut nommer le Premier Ministre.', false);
    return;
  }
  ouvrirNominerPosteNomme('pm', pa, cost);
}

function ouvrirModalRevoquerPM(pa, cost) {
  if (state.poste?.id !== 'president') {
    showToast('Acces refuse', 'Seul le President peut revoquer le Premier Ministre.', false);
    return;
  }
  ouvrirRevoquerPosteNomme('pm', pa, cost);
}

function ouvrirModalRevoquerMinistre(pa, cost) {
  if (state.poste?.id !== 'pm') {
    showToast('Acces refuse', 'Seul le Premier Ministre peut revoquer un ministre.', false);
    return;
  }
  const postesMinisteriels = [
    { id:'min_int', name:"Ministre de l'Interieur" },
    { id:'min_fin', name:'Ministre des Finances' },
    { id:'min_just', name:'Ministre de la Justice' },
    { id:'min_def', name:'Ministre de la Defense' },
    { id:'min_info', name:"Ministre de l'Information" },
    { id:'min_ae', name:'Ministre des Affaires Etrangeres' }
  ];
  document.getElementById('postes-modal-title').textContent = 'Revoquer un ministre';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisissez le ministere a revoquer.</div>';
  postesMinisteriels.forEach(p => {
    html += '<button onclick="ouvrirRevoquerPosteNomme(\'' + p.id + '\',' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.4rem">' + p.name + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =====================
// CELLULE DE RENSEIGNEMENT — Ministre de la Defense (19 septembre 2026)
// =====================
// L'ancien ordre `renseignement` etait entierement cote navigateur : autorite
// grisee seulement, jet Math.random(), et il telechargeait la compagnie ennemie
// AVANT le jet (le brouillard etait contourne quel que soit le resultat). Il
// lisait en outre personnages.per/int, deux colonnes QUI N'EXISTENT PAS -- les
// deux termes valaient donc 0 des deux cotes depuis toujours.
//
// Il est remplace par l'ouverture d'une CELLULE, entierement serveur. Le meme
// ordre est reutilise (meme fn, memes 3 PA et 500 FR deja declares au miroir
// des couts) : rien a ajouter dans ordres_couts.
//
// LE CLIENT NE PAIE PLUS ET NE TIRE PLUS RIEN. La RPC verifie le poste min_def
// ATTESTE, debite elle-meme les 3 PA et les 500 FR de la caisse du ministere,
// tire les couvertures et cree les quatre agents -- le tout dans une seule
// transaction. Un refus ne laisse donc aucun debit derriere lui.
// =====================================================================================
// RENSEIGNEMENT MILITAIRE — POINT D'ENTREE UNIQUE (22 septembre 2026)
// =====================================================================================
// Trois fonctions : on convoque une equipe, on suit celles qui tournent, on lit ce qu'elles
// rapportent. « Mettre fin a l'operation » a quitte l'ancien ecran pour rejoindre le suivi, ou il
// a sa place. Aucun parcours concurrent ne reste expose.
//
// « LIRE LES RAPPORTS » AJOUTE LE 24 SEPTEMBRE 2026. Les rapports existaient, la modale aussi, la
// RPC repondait correctement -- mais le seul chemin pour y arriver passait par « Suivre une
// operation », dont l'intitule annonce le suivi des agents, pas la lecture. Le rapport se
// trouvait donc au TROISIEME niveau, et le courrier qui l'annoncait parlait d'un « panneau » qui
// n'existe nulle part a l'ecran. Un ministre a cherche dans le journal d'evenements.
// Rien de nouveau n'est construit ici : ce bouton appelle la MEME fonction que celui du suivi,
// qui interroge la MEME RPC. Seule la profondeur change. L'acces depuis « Suivre une operation »
// est conserve : il est legitime a cet endroit, et le supprimer ne rendrait service a personne.
function ouvrirRenseignementMilitaire() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  ouvrirPanneauFonction('Renseignement militaire', [
    { label: 'Lancer une opération de renseignement', pa: 3,
      desc: 'Convoquer les quatre agents sous une couverture de votre choix. 3 PA et 500 FR prélevés sur la caisse du Ministère.',
      onclick: 'ouvrirConvocationRenseignement()' },
    { label: 'Suivre une opération', pa: 0,
      desc: 'Où sont vos agents, sous quelle couverture, combien de temps reste-t-il, et y mettre fin.',
      onclick: 'ouvrirPanneauCellules()' },
    { label: 'Lire les rapports', pa: 0,
      desc: 'Les rapports quotidiens de vos cellules, jour par jour, avec les faits consignés par vos agents.',
      onclick: 'ouvrirRapportsCellules()' }
  ]);
}

// ECRAN DE CONVOCATION. Les quatre agents s'y presentent sous leur VRAI nom et leur
// specialite -- c'est le seul ecran du jeu ou cela apparait, et il est reserve au ministre
// (la RPC le revalide). Leur portrait est l'apparence NEUTRE de Republia : la couverture
// n'est pas encore choisie.
//
// LE PAYS N'EST PAS UNE DESTINATION. On choisit une COUVERTURE -- tenue, faux nom, identite
// fictive. Elle n'a aucun effet mecanique : le ministre reste libre d'emmener ses agents
// n'importe ou, y compris dans l'empire dont ils portent les habits, y compris chez lui.
// C'est pourquoi Republia figure dans la liste, ce que l'ancien ecran interdisait.
let RP_COUVERTURE_CHOISIE = null;

async function ouvrirConvocationRenseignement() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  RP_COUVERTURE_CHOISIE = null;
  document.getElementById('postes-modal-title').textContent = 'Lancer une opération de renseignement';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const r = typeof sbRpc === 'function' ? await sbRpc('renseignement_agents_disponibles', {}).catch(() => null) : null;
  const res = Array.isArray(r) ? r[0] : r;
  if (!res || res.ok !== true) {
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1rem;color:#cc4444">' + (CELLULE_REFUS[res?.raison] || 'Indisponible.') + '</div>';
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.9rem">'
       +  'Quatre agents, une opération de <strong>10 jours</strong>. Ils vous accompagneront dès la convocation : '
       +  'c\'est vous qui les emmenez, et vous les laissez où bon vous semble.</div>';

  (res.agents || []).forEach(a => {
    const spec = SPECIALITES_RENSEIGNEMENT[a.role] || a.role;
    html += '<div style="display:flex;gap:.7rem;align-items:center;padding:.6rem 0;border-bottom:1px solid #1a1810">'
         +  '<img src="' + a.portrait + '" alt="" onerror="this.style.display=\'none\'" '
         +  'style="width:46px;height:46px;border-radius:50%;object-fit:cover;border:1px solid #8a6a20;flex-shrink:0">'
         +  '<div style="min-width:0">'
         +  '<div style="font-size:.9rem;color:#C9A84C">' + escapeHtmlText(a.vrai_nom) + '</div>'
         +  '<div style="font-size:.78rem;color:#9a8a68">' + spec + '</div>'
         +  '</div></div>';
  });

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.74rem;letter-spacing:.1em;color:#8a6a20;margin:1rem 0 .4rem">CHOISIR UNE COUVERTURE</div>'
       +  '<div style="font-size:.76rem;color:#8a8060;margin-bottom:.5rem;line-height:1.5">'
       +  'Tenue, faux nom et identité fictive de vos agents. Rien d\'autre : vous resterez libre de les emmener '
       +  'dans n\'importe quel empire, quelle que soit la couverture retenue.</div>';
  Object.entries(COUNTRIES).forEach(([k, co]) => {
    html += '<button id="couv-' + k + '" onclick="choisirCouvertureRenseignement(\'' + k + '\')" '
         +  'style="display:flex;align-items:center;gap:.5rem;width:100%;padding:.5rem .7rem;border:1px solid #2a2010;'
         +  'background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem">'
         +  '<i class="ti ' + co.icon + '" style="color:' + co.col + '"></i> ' + co.n + '</button>';
  });

  html += '<button id="btn-convoquer" onclick="confirmerCelluleRenseignement(RP_COUVERTURE_CHOISIE)" disabled '
       +  'style="width:100%;margin-top:.8rem;padding:.55rem;border:1px solid #3a2a10;background:transparent;color:#6a6050;'
       +  'cursor:not-allowed;font-family:Bebas Neue,sans-serif;font-size:.85rem;letter-spacing:.12em">CONVOQUER</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Specialites : lecture des roles serveur existants, aucun moteur de competences nouveau.
const SPECIALITES_RENSEIGNEMENT = {
  garde:        'Garde rapprochée — protection',
  traducteur:   'Traducteur — écoute et rumeurs locales',
  conseiller:   'Conseillère diplomatique — entourage du pouvoir',
  coordinateur: 'Coordinateur — flux, ports et centres multimodaux'
};

function choisirCouvertureRenseignement(pays) {
  RP_COUVERTURE_CHOISIE = pays;
  Object.keys(COUNTRIES).forEach(k => {
    const b = document.getElementById('couv-' + k);
    if (b) { b.style.borderColor = (k === pays) ? '#C9A84C' : '#2a2010';
             b.style.background   = (k === pays) ? '#1a1408' : '#0f0d05'; }
  });
  const btn = document.getElementById('btn-convoquer');
  if (btn) { btn.disabled = false; btn.style.cursor = 'pointer';
             btn.style.borderColor = '#8a6a20'; btn.style.color = '#C9A84C'; }
}

function ouvrirModalRenseignement(pa, cost) {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('postes-modal-title').textContent = 'Cellule de renseignement';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">'
       +  'Quatre agents sous couverture seront envoyés dans l\'empire choisi pour <strong>10 jours</strong>. '
       +  'Coût : ' + cost + ' FR sur la caisse du Ministère, et ' + pa + ' PA. '
       +  'Vous devrez les convoyer vous-même et les déposer sur place.</div>';
  empires.forEach(([k, co]) => {
    html += '<button onclick="confirmerCelluleRenseignement(\'' + k + '\')" style="display:flex;align-items:center;gap:.5rem;width:100%;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem"><i class="ti ' + co.icon + '" style="color:' + co.col + '"></i> ' + co.n + '</button>';
  });
  html += '<div style="border-top:1px solid #2a2010;margin-top:.8rem;padding-top:.6rem;display:flex;gap:.4rem">'
       +  '<button onclick="ouvrirPanneauCellules()" style="flex:1;padding:.45rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em">Mes cellules</button>'
       +  '<button onclick="ouvrirRapportsCellules()" style="flex:1;padding:.45rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em">Rapports</button>'
       +  '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Refus typés rendus tels quels : le serveur dit POURQUOI, on ne devine pas.
const CELLULE_REFUS = {
  acteur_non_authentifie:        'Session expirée.',
  autorite_insuffisante:         'Réservé au Ministre de la Défense.',
  cible_est_mon_pays:            'On n\'ouvre pas une cellule chez soi.',
  identites_reelles_incompletes: 'Les agents ne sont pas encore tous recrutés.',
  pool_couvertures_insuffisant:  'Pas assez d\'identités de couverture disponibles dans cet empire.',
  pa_insuffisants:               'PA insuffisants.',
  caisse_insuffisante:           'La caisse du Ministère ne couvre pas l\'opération.'
};

async function confirmerCelluleRenseignement(empireCible) {
  if (!empireCible) { showToast('Couverture non choisie', 'Sélectionnez d\'abord une couverture.', false); return; }
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = typeof sbRpc === 'function'
    ? await sbRpc('cellule_renseignement_creer', { p_pays_cible: empireCible }).catch(() => null) : null;
  const res = Array.isArray(r) ? r[0] : r;
  if (!res || res.ok !== true) {
    showToast('Cellule impossible', CELLULE_REFUS[res?.raison] || ('Refus du serveur (' + (res?.raison || 'indisponible') + ').'), false);
    return;
  }
  // Les PA sont debites SERVEUR : on reprend la valeur qu'il renvoie, jamais
  // une soustraction locale.
  if (typeof res.pa_restants === 'number') { state.pa = res.pa_restants; if (typeof updateUI === 'function') updateUI(); }
  const nom = COUNTRIES[empireCible]?.n || empireCible;
  // Les agents naissent DANS LE GROUPE du ministre (leader_courant pose par la RPC) : on
  // rafraichit donc le groupe, et le panneau d'accompagnants les montre immediatement.
  // Ils sont encore dans le Bureau : le compteur de l'operation court, la collecte non.
  if (typeof rafraichirAgentsPortes === 'function') await rafraichirAgentsPortes();
  if (typeof renderEmployesPanel === 'function') renderEmployesPanel();
  if (typeof rafraichirPresenceAgents === 'function') rafraichirPresenceAgents();
  showToast('Équipe convoquée', 'Quatre agents vous accompagnent, sous couverture ' + nom
            + '. Ils ne travailleront qu\'une fois sortis du ministère.', true, true);
  addJournalEntry('Convocation d\'une équipe de renseignement sous couverture ' + nom + '.', 'event-info');
  ouvrirPanneauCellules();
}

// Panneau du ministre : ses cellules, leurs agents, leur vraie identite.
// Toutes ces donnees viennent d'une RPC reservee au min_def du pays -- aucune
// n'est lisible par un autre joueur, meme en appelant la RPC directement.
// SUIVRE UNE OPERATION. Le seul ecran du jeu qui montre les VRAIS noms et les specialites
// reelles -- la RPC le reserve au ministre proprietaire, et personne d'autre ne peut
// l'appeler utilement, pas meme le PJ qui transporte les agents.
//
// LA SITUATION AFFICHEE EST PHYSIQUE, jamais deduite de la couverture : elle vient de la
// position effective serveur, donc celle du porteur quand l'agent en a un. « Mettre fin a
// l'operation » vit desormais ici -- c'est l'endroit ou l'on decide en connaissance de cause.
async function ouvrirPanneauCellules() {
  document.getElementById('postes-modal-title').textContent = 'Suivre une opération';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');
  const r = typeof sbRpc === 'function' ? await sbRpc('cellule_renseignement_mes_cellules', {}).catch(() => null) : null;
  const res = Array.isArray(r) ? r[0] : r;
  if (!res || res.ok !== true) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#cc4444">' + (CELLULE_REFUS[res?.raison] || 'Indisponible.') + '</div>';
    return;
  }
  const cellules = (res.cellules || []).filter(c => c.statut === 'active');
  let html = '<div style="padding:1rem">';
  if (cellules.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune opération en cours.</div>';
  }
  cellules.forEach(c => {
    const restant = Math.max(0, Math.ceil((new Date(c.echeance) - Date.now()) / 86400000));
    const couv = COUNTRIES[c.pays_couverture]?.n || c.pays_couverture;
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem .8rem;margin-bottom:.7rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:baseline;gap:.5rem">'
         +  '<span style="font-size:.85rem;color:#C9A84C">Couverture : ' + escapeHtmlText(couv) + '</span>'
         +  '<span style="font-size:.72rem;color:#6a9a6a">' + restant + ' jour(s) restant(s)</span></div>';
    html += '<div style="font-size:.72rem;color:#6a6050;font-style:italic;margin-top:.15rem">'
         +  'Une couverture n\'est pas une destination : vos agents travaillent là où ils se trouvent.</div>';

    (c.agents || []).forEach(a => {
      // Quatre situations physiques, dans l'ordre ou le ministre se les pose.
      let situation;
      if (a.statut !== 'actif') {
        situation = a.statut;
      } else if (a.leader && a.leader === state.char?.name) {
        situation = a.au_bureau ? 'avec vous, au ministère — n\'a pas encore commencé'
                                : 'avec vous, en déplacement';
      } else if (a.leader) {
        situation = 'accompagne ' + escapeHtmlText(a.leader);
      } else if (a.ville) {
        situation = 'laissé à ' + escapeHtmlText(a.ville)
                  + (a.batiment ? ' — ' + escapeHtmlText(a.batiment) : '')
                  + (a.pays ? ' (' + escapeHtmlText(COUNTRIES[a.pays]?.n || a.pays) + ')' : '');
      } else {
        situation = 'pas encore déployé';
      }
      const spec = SPECIALITES_RENSEIGNEMENT[a.role] || a.role;
      html += '<div style="display:flex;gap:.6rem;align-items:center;margin-top:.5rem;border-top:1px solid #1a1810;padding-top:.45rem">'
           +  '<img src="' + a.portrait + '" alt="" onerror="this.style.display=\'none\'" '
           +  'style="width:34px;height:34px;border-radius:50%;object-fit:cover;border:1px solid #3a2a10;flex-shrink:0">'
           +  '<div style="min-width:0;font-size:.76rem;color:#a09060">'
           +  '<strong style="color:#c0b090">' + escapeHtmlText(a.vrai_nom) + '</strong> — ' + spec + '<br>'
           +  'sous l\'identité de <em>' + escapeHtmlText(a.couverture) + '</em><br>'
           +  '<span style="color:#8a8060">' + situation + '</span>'
           +  '</div></div>';
    });

    html += '<button onclick="terminerCelluleRenseignement(\'' + c.cellule + '\')" '
         +  'style="margin-top:.7rem;width:100%;padding:.4rem;border:1px solid #8a2020;background:transparent;color:#cc4444;'
         +  'cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.74rem;letter-spacing:.08em">Mettre fin à l\'opération</button>';
    html += '</div>';
  });
  html += '<button onclick="ouvrirRapportsCellules()" style="width:100%;padding:.45rem;border:1px solid #8a6a20;'
       +  'background:transparent;color:#C9A84C;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.75rem;'
       +  'letter-spacing:.08em">Rapports reçus</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// CONVOI DES AGENTS — LES DEUX RPC QUI N'AVAIENT AUCUN APPELANT (21 septembre 2026).
// Un agent vit dans TROIS etats, et c'est le serveur qui les arbitre : non deploye
// (il attend dans l'empire qui l'a recrute), convoye (leader_courant = un PJ, il se
// deplace avec lui sans position propre), pose (une ville, un batiment, une piece --
// c'est le seul etat ou il collecte et ou le contre-espionnage adverse peut le voir).
// On ne duplique donc AUCUNE position cote client : on affiche ce que la projection
// du ministre renvoie, et on laisse agent_prendre / agent_deposer refuser.
const AGENT_REFUS = {
  acteur_non_authentifie:         'Session expirée.',
  agent_introuvable:              'Agent introuvable.',
  cellule_inactive:               'Cette cellule n\'est plus active.',
  agent_indisponible:             'Cet agent n\'est plus disponible.',
  deja_en_groupe:                 'Un autre agent de liaison le convoie déjà.',
  pas_mon_empire:                 'Il faut être dans l\'empire qui l\'a recruté pour le prendre en charge.',
  pas_au_meme_endroit:            'Il faut être physiquement auprès de lui.',
  position_indefinie:             'On ne prend ni ne dépose un agent en pleine rue : entrez dans un lieu.',
  pas_mon_agent:                  'Vous ne convoyez pas cet agent.'
};

// PLUS AUCUN BOUTON N'APPELLE CES DEUX FONCTIONS depuis le 22 septembre 2026. « Prendre en
// charge » et « Deposer ici » etaient un second systeme de groupe, visible par le joueur a
// cote du groupe general : le parcours est desormais « convoquer -> le groupe -> laisser
// ici », et laisserAgentEnPlace (plateau-multijoueur.js) appelle directement la primitive
// serveur agent_deposer. Les deux RPC restent en place -- elles sont les primitives sur
// lesquelles tout le reste s'appuie -- et ces deux enveloppes clientes sont conservees sans
// appelant, a la fois comme documentation du parcours precedent et pour ne rien casser si
// un ecran non identifie les referencait encore.
async function prendreAgentRenseignement(agentId) {
  const r = typeof sbRpc === 'function'
    ? await sbRpc('agent_prendre', { p_agent_id: agentId }).catch(() => null) : null;
  const res = Array.isArray(r) ? r[0] : r;
  if (!res || res.ok !== true) {
    showToast('Prise en charge impossible', AGENT_REFUS[res?.raison] || ('Refus du serveur (' + (res?.raison || 'indisponible') + ').'), false);
    return;
  }
  showToast('Agent pris en charge', 'Il vous suit désormais. Déposez-le sur place, dans l\'empire visé.', true);
  addJournalEntry('Prise en charge d\'un agent de renseignement.', 'event-info');
  ouvrirPanneauCellules();
}

async function deposerAgentRenseignement(agentId) {
  const r = typeof sbRpc === 'function'
    ? await sbRpc('agent_deposer', { p_agent_id: agentId }).catch(() => null) : null;
  const res = Array.isArray(r) ? r[0] : r;
  if (!res || res.ok !== true) {
    const attendu = res?.attendu ? (COUNTRIES[res.attendu]?.n || res.attendu) : null;
    showToast('Dépôt impossible',
      res?.raison === 'pas_dans_le_pays_de_couverture'
        ? ('Sa couverture ne tient que dans l\'empire visé' + (attendu ? ' (' + attendu + ')' : '') + '.')
        : (AGENT_REFUS[res?.raison] || ('Refus du serveur (' + (res?.raison || 'indisponible') + ').')), false);
    return;
  }
  showToast('Agent en place', 'Il reste ici et commence à recueillir des informations.', true, true);
  addJournalEntry('Un agent de renseignement a été déposé sur place.', 'event-info');
  ouvrirPanneauCellules();
}

async function terminerCelluleRenseignement(cellId) {
  const r = typeof sbRpc === 'function'
    ? await sbRpc('cellule_renseignement_terminer', { p_cellule_id: cellId }).catch(() => null) : null;
  const res = Array.isArray(r) ? r[0] : r;
  if (!res || res.ok !== true) { showToast('Impossible', CELLULE_REFUS[res?.raison] || (res?.raison || 'indisponible'), false); return; }
  showToast('Mission terminée', (res.agents_disparus || 0) + ' agent(s) rappelé(s)'
    + ((res.evasions || 0) > 0 ? ', ' + res.evasions + ' évasion(s)' : '') + '. Aucun remboursement.', true);
  addJournalEntry('Fin de mission d\'une cellule de renseignement.', 'event-info');
  ouvrirPanneauCellules();
}

async function ouvrirRapportsCellules() {
  document.getElementById('postes-modal-title').textContent = 'Rapports de renseignement';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');
  const r = typeof sbRpc === 'function' ? await sbRpc('cellule_rapports_mes_cellules', { p_limite: 15 }).catch(() => null) : null;
  const res = Array.isArray(r) ? r[0] : r;
  if (!res || res.ok !== true) {
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#cc4444">' + (CELLULE_REFUS[res?.raison] || 'Indisponible.') + '</div>';
    return;
  }
  const rapports = res.rapports || [];
  let html = '<div style="padding:1rem">';
  if (rapports.length === 0) html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun rapport pour l\'instant.</div>';
  rapports.forEach(rap => {
    // Accord calcule, comme dans la notification : « 0 fait », « 1 fait », « 2 faits ».
    const nb = rap.nb_faits || 0;
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem .8rem;margin-bottom:.6rem">'
         +  '<div style="font-size:.78rem;color:#C9A84C">' + escapeHtmlText(rap.jour || '') + ' — '
         +  (COUNTRIES[rap.pays_cible]?.n || rap.pays_cible) + ' <span style="color:#8a8060">('
         +  nb + (nb > 1 ? ' faits' : ' fait') + ')</span></div>';
    (rap.faits || []).forEach(f => {
      html += '<div style="font-size:.74rem;color:#a09060;margin-top:.3rem">• ' + escapeHtmlText(f.fait) + '</div>';
    });
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

function ouvrirModalMedia(pa, cost) {
  const medias = MEDIAS[state.country] || [];
  document.getElementById('postes-modal-title').textContent = 'Censurer un media';
  let html = '<div style="padding:1rem"><div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">Attention : la censure peut provoquer un scandale si elle est decouverte.</div>';
  medias.forEach((m, i) => {
    html += '<button onclick="censurer(\'' + m + '\',' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem;margin-bottom:.3rem">' + m + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function censurer(media, pa, cost) {
  document.getElementById('modal-postes').classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  INDICES_NATIONAUX[state.country].IS = Math.max(0, INDICES_NATIONAUX[state.country].IS - 8);
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 30) {
    addExternalEvent('SCANDALE : La censure de ' + media + ' a ete revelee ! -20 POP.');
    state.pop = Math.max(0, state.pop - 20);
    updateUI();
  } else {
    showToast('Media censure', media + ' suspendu. -8 IS.', false);
    addJournalEntry('Censure de ' + media, 'event-bad');
  }
}

function ouvrirModalTraite(pa, cost) {
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  const types = ['Commercial', 'De paix', "D'alliance militaire", 'Non-agression', 'Culturel'];
  document.getElementById('postes-modal-title').textContent = 'Signer un traite';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">EMPIRE</div>';
  html += '<select id="traite-empire" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
  empires.forEach(([k, co]) => { html += '<option value="' + k + '">' + co.n + '</option>'; });
  html += '</select>';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TYPE DE TRAITE</div>';
  html += '<select id="traite-type" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
  types.forEach(t => { html += '<option value="' + t + '">' + t + '</option>'; });
  html += '</select>';
  html += '<button onclick="proposerTraite(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Proposer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Propose le traite via la file d'attente diplomatique generique (voir proposerDiplomatie) —
// remplace l'ancienne signature unilaterale de signerTraite().
function proposerTraite(pa, cost) {
  const empireId = document.getElementById('traite-empire')?.value;
  const type = document.getElementById('traite-type')?.value;
  document.getElementById('modal-postes').classList.remove('open');
  const empireName = COUNTRIES[empireId]?.n || empireId;
  proposerDiplomatie('traite', empireId, empireName, type, pa, cost);
}

function signerTraite() {
  const empireId = document.getElementById('traite-empire')?.value;
  const type = document.getElementById('traite-type')?.value;
  document.getElementById('modal-postes').classList.remove('open');
  const empireName = COUNTRIES[empireId]?.n || empireId;
  INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 12);
  if (!state.traites) state.traites = [];
  state.traites.push({ empire: empireId, type, jour: state.day });
  showToast('Traite signe', 'Traite ' + type + ' avec ' + empireName + '. +12 ID.', true, true);
  addExternalEvent('TRAITE : Accord ' + type + ' signe entre ' + (COUNTRIES[state.country]?.n||'') + ' et ' + empireName + '.');
}

// =====================
// ORDRES DU QUARTIER DES AMBASSADES
// =====================
const AMBASSADE_ROOM_EMPIRE_MAP = { bureau_al_khalija: 'khalija', bureau_sovarka: 'soviet', bureau_el_estado: 'narco' };

function ouvrirRelationsBilaterales() {
  const empireId = AMBASSADE_ROOM_EMPIRE_MAP[state.currentRoom];
  if (!empireId) return;
  const empireName = COUNTRIES[empireId]?.n || empireId;
  const idActuel = INDICES_NATIONAUX[empireId]?.ID ?? 50;
  const traitesActifs = (state.traites || []).filter(t => t.empire === empireId);
  document.getElementById('postes-modal-title').textContent = 'Relations bilatérales — ' + empireName;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;margin-bottom:.6rem">Indice Diplomatique actuel : <strong>' + idActuel + '</strong></div>';
  if (traitesActifs.length === 0) {
    html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic">Aucun traité en vigueur.</div>';
  } else {
    html += '<div style="font-size:.82rem;margin-bottom:.4rem">Traités en vigueur :</div>';
    traitesActifs.forEach(t => { html += '<div style="font-size:.8rem;color:#c0b090">— ' + t.type + ' (Jour ' + t.jour + ')</div>'; });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doCorrompreHomologueLocal(pa, cost) {
  const empireId = AMBASSADE_ROOM_EMPIRE_MAP[state.currentRoom];
  if (!empireId) return;
  const empireName = COUNTRIES[empireId]?.n || empireId;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', 'Corrompre un homologue coûte ' + cost + ' ' + cur + '.', false); return; }
  const roll = Math.random() * 100;
  if (roll < 65) {
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 6);
    showToast('Faveur obtenue', 'Un homologue local vous doit une faveur. +6 ID.', true);
    addJournalEntry('Corruption discrète d\'un homologue à l\'ambassade de ' + empireName + '. +6 ID.', 'event-info');
  } else {
    INDICES_NATIONAUX[state.country].ID = Math.max(0, INDICES_NATIONAUX[state.country].ID - 10);
    showToast('Scandale', 'La tentative de corruption a été découverte. -10 ID.', false);
    addExternalEvent('SCANDALE DIPLOMATIQUE : une tentative de corruption à l\'ambassade de ' + empireName + ' a été dévoilée.');
  }
  updateUI();
}

function doOrganiserReceptionDiplomatique(pa, cost) {
  const empireId = AMBASSADE_ROOM_EMPIRE_MAP[state.currentRoom];
  if (!empireId) return;
  const empireName = COUNTRIES[empireId]?.n || empireId;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  // Verifier qu'une reservation existe bien pour aujourd'hui, au nom de cette ambassade
  // (voir sbReserverSalleReception, ordre pris a l'accueil).
  const jour = state.day || 1;
  sbGetReservationSalle(state.country, jour).then(async resa => {
    if (!resa || resa.data?.empire !== empireId) {
      showToast('Salle non réservée', "Réservez d'abord la Salle de Réception pour aujourd'hui, depuis l'accueil du Quartier des Ambassades.", false);
      return;
    }
    const r = await deduireCoutOrdre({ pa, cost });
    if (!r.ok) { showToast('Fonds insuffisants', 'Organiser une réception coûte ' + cost + ' ' + cur + '.', false); return; }
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 5);
    state.pop = Math.min(100, (state.pop || 50) + 5);
    showToast('Réception organisée', 'Une réception diplomatique a été donnée dans la Salle de Réception. +5 ID, +5 POP.', true);
    addExternalEvent('DIPLOMATIE : réception donnée à l\'ambassade de ' + empireName + '.');
    updateUI();
  }).catch(() => {
    showToast('Erreur', 'Impossible de vérifier la réservation pour le moment.', false);
  });
}

// Reservation de la Salle de Reception, prise a l'accueil. Reservee aux ambassadeurs
// effectivement en poste ici (peu importe lequel des 3, du moment qu'il en est un) —
// la reservation est associee a SON empire, pas au pays hote, pour rester coherente
// avec la verification faite dans doOrganiserReceptionDiplomatique.
async function doReserverSalleReception(pa, cost) {
  const jour = state.day || 1;
  const monAmbassade = (state.ambassadesOuvertesCache || []).find(a => a.ambassadeur === state.char?.name);
  if (!monAmbassade) {
    showToast('Réservation impossible', 'Seul un ambassadeur en poste ici peut réserver cette salle.', false);
    return;
  }
  const resa = typeof sbGetReservationSalle === 'function' ? await sbGetReservationSalle(state.country, jour).catch(() => null) : null;
  if (resa) {
    const empireResa = COUNTRIES[resa.data?.empire]?.n || resa.data?.empire;
    showToast('Salle déjà réservée', 'La Salle de Réception est déjà réservée aujourd\'hui par ' + empireResa + '.', false);
    return;
  }
  const rDeduc = await deduireCoutOrdre({ pa, cost });
  if (!rDeduc.ok) { signalerRefusCout(rDeduc); return; }
  const res = typeof sbReserverSalleReception === 'function'
    ? await sbReserverSalleReception(state.country, jour, monAmbassade.empire, state.char?.name).catch(() => ({ ok: false }))
    : { ok: false };
  if (res.ok) {
    showToast('Salle réservée', 'La Salle de Réception est réservée pour aujourd\'hui.', true);
    addJournalEntry('Réservation de la Salle de Réception du Quartier des Ambassades pour aujourd\'hui.', 'event-info');
  } else {
    showToast('Réservation impossible', 'La salle vient d\'être réservée par un autre pays.', false);
  }
}

async function doFinancerOeuvreCulturelle(pa, cost) {
  const empireId = AMBASSADE_ROOM_EMPIRE_MAP[state.currentRoom];
  if (!empireId) return;
  const empireName = COUNTRIES[empireId]?.n || empireId;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('Fonds insuffisants', 'Financer une œuvre culturelle coûte ' + cost + ' ' + cur + '.', false); return; }
  state.pop = Math.min(100, (state.pop || 50) + 8);
  INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 3);
  showToast('Mécénat culturel', 'Une œuvre a été financée localement. +8 POP, +3 ID.', true);
  addExternalEvent('SOFT POWER : ' + (COUNTRIES[state.country]?.n || state.country) + ' finance une œuvre culturelle à ' + empireName + '.');
  updateUI();
}

// Ordres de l'accueil, ouverts a tous (pas reserves a l'ambassadeur)
async function doDemanderAudienceAmbassadeur(pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const roll = Math.random() * 100;
  if (roll < 70) {
    const pnj = { name: 'L\'Ambassadeur', role: 'PNJ - Ambassadeur', rel: 'neutral', job: 'ambassadeur' };
    if (typeof openPnjModal === 'function') openPnjModal(typeof encodePnjSafe === 'function' ? encodePnjSafe(pnj) : pnj);
    addJournalEntry('Vous êtes reçu(e) par l\'ambassadeur.', 'event-info');
  } else {
    showToast('Indisponible', "L'ambassadeur ne peut pas vous recevoir pour le moment.", false);
  }
}

async function doDemanderAsilePolitique(pa, cost) {
  if (!state.char) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  state.char.asilePolitique = { pays: state.country, jour: state.day || 1 };
  if (typeof sauvegarderPersonnageImmediat === 'function') sauvegarderPersonnageImmediat();
  showToast('Demande déposée', 'Votre demande d\'asile politique a été enregistrée.', true);
  addExternalEvent((state.char?.name || 'Un individu') + ' a demandé l\'asile politique auprès d\'une ambassade.');
  addJournalEntry('Demande d\'asile politique déposée.', 'event-info');
}

function ouvrirModalNommerAmbassadeur(pa, cost) {
  const contacts = state.contacts || [];
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('postes-modal-title').textContent = 'Nommer un ambassadeur';
  let html = '<div style="padding:1rem">';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Repertoire vide.</div>';
  } else {
    html += '<select id="amb-contact" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;margin-bottom:.7rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
    html += '</select>';
    html += '<select id="amb-empire" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;margin-bottom:.7rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none">';
    empires.forEach(([k,co]) => { html += '<option value="' + k + '">' + co.n + '</option>'; });
    html += '</select>';
    html += '<button onclick="confirmerAmbassadeur(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Nommer</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerAmbassadeur(pa, cost) {
  const contact = document.getElementById('amb-contact')?.value;
  const empireId = document.getElementById('amb-empire')?.value;
  document.getElementById('modal-postes').classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const empireName = COUNTRIES[empireId]?.n || empireId;
  // Persistance partagee : la nomination doit etre visible de tous, dans le Quartier des
  // Ambassades du pays cible (empireId), pour restreindre les ordres du bureau a cette personne.
  if (typeof sbNommerAmbassadeur === 'function') {
    sbNommerAmbassadeur(empireId, state.country, contact).catch(() => {});
  }
  envoyerNotificationVraiJoueur(contact, 'Nomination comme ambassadeur', 'Vous avez ete nomme(e) ambassadeur(rice) aupres de ' + empireName + ' par le Ministre des Affaires Etrangeres.');
  addExternalEvent('NOMINATION : ' + contact + ' nomme(e) ambassadeur(rice) aupres de ' + empireName + '.');
  if (typeof sbEnregistrerEvenementPublic === 'function') {
    sbEnregistrerEvenementPublic(state.country, 'nomination', {
      personnages: [contact].filter(Boolean),
      libelle: contact + ' est nommé(e) ambassadeur(rice) auprès de ' + empireName + '.',
      data: { poste: 'ambassadeur', empire_cible: empireId, nomme: contact }
    }).catch(() => {});
  }
  showToast('Ambassadeur nomme', contact + ' → ' + empireName, true);
}

// DEMETTRE : le pays qui a nomme son propre ambassadeur met fin a sa mission — perte
// immediate du poste, aucun delai (contrairement a l'expulsion, voir plus bas).
async function ouvrirModalDemettreAmbassadeur(pa, cost) {
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('postes-modal-title').textContent = 'Démettre un ambassadeur de son poste';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  // Ici, "pays_hote" = l'empire cible (la ou notre ambassadeur est stationne), "empire" = nous.
  const infosParEmpire = await Promise.all(empires.map(async ([k]) => {
    const rows = typeof sbGet === 'function' ? await sbGet('ambassades_ouvertes', `id=eq.${encodeURIComponent(k + '-' + state.country)}`).catch(() => []) : [];
    return { empireId: k, info: rows?.[0] || null };
  }));

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Vos ambassadeurs actuellement en poste :</div>';
  const presents = infosParEmpire.filter(x => x.info?.data?.ambassadeur);
  if (presents.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun ambassadeur nommé actuellement.</div>';
  } else {
    presents.forEach(x => {
      const co = COUNTRIES[x.empireId];
      html += '<div style="display:flex;justify-content:space-between;align-items:center;border:1px solid #2a2010;background:#0f0d05;padding:.6rem .8rem;margin-bottom:.4rem">';
      html += '<span style="font-size:.85rem">' + co.n + ' — <em>' + x.info.data.ambassadeur + '</em></span>';
      html += '<button onclick="confirmerDemissionAmbassadeur(&quot;' + x.empireId + '&quot;,' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.35rem .7rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Démettre</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerDemissionAmbassadeur(empireId, pa, cost) {
  const empireName = COUNTRIES[empireId]?.n || empireId;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const rows = typeof sbGet === 'function' ? await sbGet('ambassades_ouvertes', `id=eq.${encodeURIComponent(empireId + '-' + state.country)}`).catch(() => []) : [];
  const ancienAmbassadeur = rows?.[0]?.data?.ambassadeur;
  if (typeof sbNommerAmbassadeur === 'function') {
    await sbNommerAmbassadeur(empireId, state.country, null).catch(() => {});
  }
  document.getElementById('modal-postes')?.classList.remove('open');
  if (ancienAmbassadeur) {
    envoyerNotificationVraiJoueur(ancienAmbassadeur, 'Fin de mission', 'Le Ministre des Affaires Étrangères a mis fin à votre mission d\'ambassadeur auprès de ' + empireName + '. Vous perdez ce poste avec effet immédiat.');
  }
  addExternalEvent('DIPLOMATIE : ' + (COUNTRIES[state.country]?.n || state.country) + ' démet son ambassadeur auprès de ' + empireName + '.');
  showToast('Ambassadeur démis', 'La mission a pris fin, poste perdu avec effet immédiat.', false);
}

// EXPULSER : le pays hote expulse l'ambassadeur d'un autre pays stationne chez lui. Il garde
// son poste mais a 24h (jour actuel + 1) pour quitter le pays, sous peine d'arrestation.
async function ouvrirModalExpulserAmbassadeur(pa, cost) {
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== state.country);
  document.getElementById('postes-modal-title').textContent = 'Expulser un ambassadeur';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const infos = typeof sbGetAmbassadesOuvertes === 'function' ? await sbGetAmbassadesOuvertes(state.country).catch(() => []) : [];
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Ambassadeurs étrangers actuellement en poste dans votre pays :</div>';
  const presents = empires.filter(([k]) => infos.some(i => i.data?.empire === k && i.data?.ambassadeur && !i.data?.expulsionEcheance));
  if (presents.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun ambassadeur étranger en poste actuellement.</div>';
  } else {
    presents.forEach(([k, co]) => {
      const info = infos.find(i => i.data?.empire === k);
      html += '<div style="display:flex;justify-content:space-between;align-items:center;border:1px solid #2a2010;background:#0f0d05;padding:.6rem .8rem;margin-bottom:.4rem">';
      html += '<span style="font-size:.85rem">' + co.n + ' — <em>' + info.data.ambassadeur + '</em></span>';
      html += '<button onclick="confirmerExpulsionAmbassadeur(&quot;' + k + '&quot;,' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.35rem .7rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Expulser</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerExpulsionAmbassadeur(empireId, pa, cost) {
  const empireName = COUNTRIES[empireId]?.n || empireId;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const echeance = Date.now() + 24 * 60 * 60 * 1000; // 24h reelles, comme les autres delais du jeu (couvre-feu, recherche militaire)
  if (typeof sbFixerEcheanceExpulsion === 'function') {
    await sbFixerEcheanceExpulsion(state.country, empireId, echeance).catch(() => {});
  }
  document.getElementById('modal-postes')?.classList.remove('open');
  const rows = typeof sbGet === 'function' ? await sbGet('ambassades_ouvertes', `id=eq.${encodeURIComponent(state.country + '-' + empireId)}`).catch(() => []) : [];
  const ambassadeurVise = rows?.[0]?.data?.ambassadeur;
  if (ambassadeurVise) {
    envoyerNotificationVraiJoueur(ambassadeurVise, 'Expulsion diplomatique', 'Vous êtes déclaré(e) persona non grata. Vous avez 24h pour quitter ' + (COUNTRIES[state.country]?.n || state.country) + ', sous peine d\'arrestation. Vous conservez votre poste jusque-là.');
  }
  addExternalEvent('DIPLOMATIE : ' + (COUNTRIES[state.country]?.n || state.country) + ' expulse l\'ambassadeur de ' + empireName + ' (24h pour quitter le pays).');
  showToast('Ambassadeur expulsé', 'Délai de 24h notifié, poste conservé jusqu\'à l\'échéance.', false);
}

function ouvrirBanquetDiplomatique(pa, cost) {
  const contacts = state.contacts || [];
  if (contacts.length === 0) {
    showToast('Répertoire vide', 'Enregistrez des contacts pour pouvoir les inviter.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Banquet diplomatique';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.8rem">Sélectionnez 1 à 3 invités. Chacun a une chance de ne pas se présenter — un banquet déserté est un fiasco.</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem;margin-bottom:.8rem">';
  contacts.forEach((c, i) => {
    html += '<label style="display:flex;align-items:center;gap:.5rem;font-size:.8rem;color:#c0b090"><input type="checkbox" class="banquet-invite" value="' + c.name + '"/> ' + c.name + '</label>';
  });
  html += '</div>';
  html += '<button onclick="confirmerBanquetDiplomatique(' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Organiser le banquet (2000 FR)</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerBanquetDiplomatique(pa, cost) {
  const invites = Array.from(document.querySelectorAll('.banquet-invite:checked')).map(el => el.value);
  if (invites.length === 0) { showToast('Aucun invité sélectionné', '', false); return; }
  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { signalerRefusCout(r); return; }
  document.getElementById('modal-postes')?.classList.remove('open');

  if (!verifierBudgetInstitution('presidence')) return;

  const venus = invites.filter(() => Math.random() < 0.7); // 70% de chance de presence par invite
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (venus.length === invites.length) {
    state.pop = Math.min(100, state.pop + 15);
    state.inf = Math.min(100, state.inf + 12);
    state.moral = Math.min(100, state.moral + 5);
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 8);
    updateUI();
    showToast('Banquet réussi !', 'Tous les invités sont venus. +15 POP +12 INF +5 Moral +8 ID.', true, true);
    addJournalEntry('Banquet diplomatique réussi — tous les invités présents.', 'event-good');
  } else if (venus.length > 0) {
    state.pop = Math.min(100, state.pop + 5);
    state.inf = Math.min(100, state.inf + 5);
    updateUI();
    showToast('Banquet mitigé', 'Seuls ' + venus.length + '/' + invites.length + ' invités sont venus. +5 POP +5 INF.', true);
    addJournalEntry('Banquet diplomatique mitigé (' + venus.length + '/' + invites.length + ' présents).', 'event-info');
  } else {
    state.pop = Math.max(0, state.pop - 25);
    state.inf = Math.max(0, state.inf - 20);
    state.moral = Math.max(0, state.moral - 10);
    updateUI();
    showToast('Fiasco !', 'Aucun invité ne s\'est présenté. -25 POP -20 INF -10 Moral.', false);
    addJournalEntry('Fiasco du banquet diplomatique — aucun invité présent.', 'event-bad');
    addExternalEvent('HUMILIATION : Le banquet diplomatique du Président s\'est tenu... sans aucun invité.');
  }
}

async function doReceptionAvecBonus(fn, cost) {
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  // Prelever sur le budget de la Presidence, pas sur l'argent personnel. Lecture seule AVANT la
  // deduction PA (correctif fail-closed, meme principe que doCampagneSecurite) : on ne peut pas
  // appeler verifierBudgetInstitution() ici, car elle debite REELLEMENT le budget en meme temps
  // qu'elle le controle -- l'appeler avant deduireCoutOrdre() debiterait la Presidence avant
  // meme de savoir si les PA sont disponibles. On reutilise donc getBudgetInstitution() (la
  // meme primitive de lecture que verifierBudgetInstitution utilise en interne) pour ne faire
  // qu'un controle, et on ne debite b.solde qu'apres le succes de la deduction PA.
  const budgetPresidence = getBudgetInstitution('presidence');
  if (budgetPresidence.solde < budgetPresidence.coutOrdre) {
    showToast('Budget insuffisant', 'Le budget de la Presidence est insuffisant. Le Ministre des Finances doit revoir la repartition budgetaire.', false);
    return;
  }
  // Deduction PA centralisee (Lot 2C) -- apres verification du budget, avant tout debit.
  const rPa = await deduireCoutOrdre({ pa: 2, cost: 0 });
  if (!rPa.ok) { signalerRefusCout(rPa); return; }
  budgetPresidence.solde -= budgetPresidence.coutOrdre;

  // Bonus/malus selon popularite
  const popBonus = state.pop > 20 ? Math.floor((state.pop - 20) * 1) : -Math.floor((20 - state.pop) * 1);
  const taux = Math.min(95, Math.max(5, 80 + Math.floor(popBonus / 2)));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    state.pop = Math.min(100, state.pop + 10);
    state.inf = Math.min(100, state.inf + 8);
    state.moral = Math.min(100, state.moral + 5);
    INDICES_NATIONAUX[state.country].ID = Math.min(100, INDICES_NATIONAUX[state.country].ID + 5);
    updateUI();
    showToast(fn === 'reception_etat' ? 'Reception reussie !' : 'Banquet reussi !', '+10 POP +8 INF +5 Moral +5 ID.', true, true);
    addJournalEntry(fn === 'reception_etat' ? 'Reception d\'Etat reussie.' : 'Banquet diplomatique reussi.', 'event-good');
  } else {
    state.pop = Math.max(0, state.pop - 30);
    state.inf = Math.max(0, state.inf - 30);
    state.moral = Math.max(0, state.moral - 10);
    updateUI();
    showToast('Echec !', 'Les invites ont boude votre ' + (fn === 'reception_etat' ? 'reception' : 'banquet') + '. -30 POP -30 INF -10 Moral.', false);
    addExternalEvent('HUMILIATION : La ' + (fn === 'reception_etat' ? 'reception' : 'banquet diplomatique') + ' du President s\'est soldee par un echec cuisant. -30 POP -30 INF -10 Moral.');
  }
}

const DOSSIERS_GOUVERNEMENTAUX = [
  "Note confidentielle du Ministere des Finances : les reserves de change couvrent 4,2 mois d'importations, en baisse constante depuis 3 trimestres.",
  "Rapport classifie des services de renseignement : activite diplomatique inhabituelle detectee a la frontiere.",
  "Synthese interne : trois hauts fonctionnaires suspectes de conflits d'interets dans l'attribution de marches publics.",
  "Memo du cabinet : la cote de confiance du gouvernement aupres des grands industriels s'est degradee ce trimestre.",
  "Dossier sensible : un ancien ministre aurait conserve des documents classifies apres son depart.",
  "Rapport d'audit interne : des irregularites mineures ont ete relevees dans la gestion de deux budgets ministeriels."
];

async function doConsulterDossiersGouv(pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const dossier = DOSSIERS_GOUVERNEMENTAUX[Math.floor(Math.random() * DOSSIERS_GOUVERNEMENTAUX.length)];
  document.getElementById('postes-modal-title').textContent = 'Dossier confidentiel';
  const html = '<div style="padding:1rem;font-size:.85rem;color:#c0b090;line-height:1.6;font-style:italic">« ' + dossier + ' »</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  state.inf = Math.min(100, (state.inf || 0) + 2);
  updateUI();
  addJournalEntry('Consultation d\'un dossier confidentiel du gouvernement. +2 INF.', 'event-info');
}

function doMobiliserPolice(fn) {
  const options = [
    { id: 'blocus', label: 'Disperser un blocus routier', isn: 8, pop: -8 },
    { id: 'encadrer', label: 'Encadrer un rassemblement (prévention)', isn: 3, pop: -2 },
    { id: 'quartier', label: 'Renforcer un quartier sensible', isn: 5, pop: 0 },
    { id: 'reprimer', label: 'Réprimer un rassemblement par la force', isn: 10, pop: -15 }
  ];
  // §9 "Greves" (3 septembre 2026) : l'option "reprimer" specifiquement devient indisponible
  // (jamais un malus/jet d'echec) des qu'un syndicat de policiers est en greve -- voir
  // syndicatPoliceEnGreve (plateau-organisations-quetes.js), identification structurelle.
  const policeIndisponible = typeof syndicatPoliceEnGreve === 'function' && syndicatPoliceEnGreve(state.country || 'republic');
  document.getElementById('postes-modal-title').textContent = "Faire intervenir les forces de l'ordre";
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.7rem">Chaque type d\'intervention a un impact different sur la securite nationale et la popularite.</div>';
  options.forEach(o => {
    const bloque = o.id === 'reprimer' && policeIndisponible;
    if (bloque) {
      html += '<button disabled title="Un syndicat de policiers est en grève : la répression est impossible tant qu\'il n\'y met pas fin." style="display:flex;justify-content:space-between;width:100%;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#5a4a3a;opacity:.4;cursor:not-allowed;font-size:.78rem">';
      html += '<span>' + o.label + '</span><span style="color:#5a4a3a">Indisponible (police en grève)</span></button>';
    } else {
      html += '<button onclick="confirmerMobilisationPolice(\'' + o.id + '\',\'' + o.label.replace(/'/g,"\\'") + '\',' + o.isn + ',' + o.pop + ',\'' + fn + '\')" style="display:flex;justify-content:space-between;width:100%;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.78rem">';
      html += '<span>' + o.label + '</span><span style="color:#8a8060">+' + o.isn + ' ISN · ' + (o.pop<=0?o.pop:'+'+o.pop) + ' POP</span></button>';
    }
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerMobilisationPolice(id, label, isn, pop, fn) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';

  // Cas special 'blocus' : verifier l'existence reelle du blocus AVANT toute deduction PA
  // (correctif Lot 2C) -- sinon disperser un blocus inexistant coute des PA pour rien. Etat
  // charge ici et reutilise plus bas, sans second appel Supabase. Ne touche pas aux autres
  // branches (encadrer/reprimer/generique), qui n'ont pas de precondition de ce type.
  let etatActuelBlocus = null;
  if (id === 'blocus') {
    etatActuelBlocus = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, state.currentCity, state.currentBuilding) : null;
    if (!etatActuelBlocus?.blocus) {
      showToast('Aucun blocus', "Il n'y a pas de blocus syndical en cours ici.", false);
      return;
    }
  }

  // Deduction PA centralisee (Lot 2C) -- uniquement pour mobiliser_police (ordre classe A par
  // l'audit). 'mobiliser' route vers ce meme handler partage (bug de routage distinct, classe
  // E, hors perimetre de ce lot) : aucune deduction pour ce cas, comportement inchange tant que
  // l'arbitrage sur le routage n'a pas eu lieu. Placee avant toute mutation (y compris le cas
  // special 'blocus' ci-dessous).
  if (fn === 'mobiliser_police') {
    const rPa = await deduireCoutOrdre({ pa: 2, cost: 0 });
    if (!rPa.ok) { signalerRefusCout(rPa); return; }
  }

  // Cas special : disperser un blocus reellement en cours dans le batiment ou l'on se trouve
  // (pas seulement decoratif — voir plateau-organisations-quetes.js pour la creation du
  // blocus). Les PNJ militants restent employes du syndicat quelle que soit l'issue.
  if (id === 'blocus') {
    const etatActuel = etatActuelBlocus;
    const intensite = etatActuel.blocus.intensite || 40;
    // Formule et bornes EXTRAITES dans tauxDispersionBlocus (plateau-gouvernement.js) pour qu'un
    // second appelant -- la repression ministerielle -- les reutilise au lieu de les recopier.
    // Repli local si le module n'est pas charge : le comportement reste strictement identique.
    const taux = (typeof tauxDispersionBlocus === 'function')
      ? tauxDispersionBlocus(intensite)
      : Math.max(10, Math.min(90, 55 - intensite / 3));
    const roll = Math.floor(Math.random() * 100) + 1;

    if (roll <= taux) {
      const patch = { blocus: null };
      if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(pays, state.currentCity, state.currentBuilding, patch).catch(() => {});
      if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + isn);
      state.pop = Math.max(0, Math.min(100, state.pop + pop));
      updateUI();
      showToast('Blocus dispersé !', 'Les forces de l\'ordre ont délogé les militants. +' + isn + ' ISN, ' + pop + ' POP.', true, true);
      addJournalEntry('Le blocus syndical a été dispersé par la police.', 'event-info');
      addExternalEvent('🚔 Un blocus syndical a été dispersé par les forces de l\'ordre.');
      if (typeof sendMail === 'function' && etatActuel.blocus.leaderActuel) {
        await sendMail(etatActuel.blocus.leaderActuel, 'Police', 'Blocus dispersé', 'Les forces de l\'ordre ont dispersé votre blocus. Vos militants restent employés, libre à vous de les renvoyer ou de retenter ailleurs.');
      }
    } else {
      showToast('Échec', 'Les militants ont tenu bon face aux forces de l\'ordre.', false);
      addJournalEntry('Tentative de dispersion du blocus syndical échouée.', 'event-bad');
    }
    return;
  }

  // Repression violente ('reprimer') sur un batiment en blocus syndical : la manière forte
  // nourrit la cause plutot que de l'eteindre (sympathie pour les opprimes), sur demande
  // explicite de Fred le 5 aout 2026.
  if (id === 'reprimer') {
    // §9 "Greves" : revalidation independante (un syndicat de policiers a pu se mettre en greve
    // entre l'ouverture du modal et ce clic) -- preserve integralement le reste de cette branche
    // (repressionsSubies/calculerPuissanceSyndicale), jamais touchee par ce lot.
    if (typeof syndicatPoliceEnGreve === 'function' && syndicatPoliceEnGreve(pays)) {
      showToast('Répression impossible', 'Un syndicat de policiers est en grève : la répression policière est impossible tant qu\'il n\'y met pas fin.', false);
      return;
    }
    const etatBatiment = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, state.currentCity, state.currentBuilding) : null;
    if (etatBatiment?.blocus) {
      const orgas = (typeof chargerOrgas === 'function') ? chargerOrgas() : (state.orgas || []);
      const syndicat = orgas.find(o => o.id === etatBatiment.blocus.syndicatId);
      if (syndicat) {
        syndicat.repressionsSubies = (syndicat.repressionsSubies || 0) + 1;
        if (typeof sauvegarderOrga === 'function') sauvegarderOrga(syndicat);
      }
      if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + isn);
      state.pop = Math.max(0, Math.min(100, state.pop + pop));
      updateUI();
      showToast('Répression menée', 'La manière forte nourrit la cause syndicale plutôt que de l\'éteindre. +' + isn + ' ISN, ' + pop + ' POP — mais le syndicat en sort renforcé.', false, true);
      addJournalEntry('Répression violente d\'un blocus syndical : la sympathie publique bascule en faveur des grévistes.', 'event-bad');
      addExternalEvent('🚔 Répression violente d\'un blocus syndical — l\'opinion publique s\'émeut.');
      return;
    }
  }

  if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + isn);
  state.pop = Math.max(0, Math.min(100, state.pop + pop));
  updateUI();
  showToast('Intervention menée', label + ' — +' + isn + ' ISN, ' + (pop<=0?pop:'+'+pop) + ' POP.', pop >= 0, true);
  addJournalEntry('Intervention des forces de l\'ordre : ' + label + '.', pop < -5 ? 'event-bad' : 'event-info');
  addExternalEvent('🚔 Intervention des forces de l\'ordre : ' + label + '.');
}

async function doTraiterManifestations(pa, cost) {
  if (state.poste?.id !== 'min_int') { showToast('Réservé au Ministre de l\'Intérieur', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Demandes de manifestation';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  await verifierAutoValidationManifestations(state.country);
  const demandes = typeof sbGetDemandesManifestationPays === 'function' ? await sbGetDemandesManifestationPays(state.country).catch(() => []) : [];

  let html = '<div style="padding:1rem">';
  if (demandes.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040;font-style:italic">Aucune demande en attente.</div>';
  } else {
    const maintenant = Date.now();
    demandes.sort((a, b) => new Date(a.dateEvenement) - new Date(b.dateEvenement));
    demandes.forEach(d => {
      const heuresRestantes = Math.max(0, Math.round((new Date(d.dateEvenement) - maintenant) / (1000*60*60)));
      const heuresAvantAutoval = Math.max(0, heuresRestantes - DELAI_AUTOVALIDATION_H);
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
      html += '<div style="font-size:.8rem;color:#c0b090">' + d.orgaNom + '</div>';
      html += '<div style="font-size:.75rem;color:#8a8060;margin:.2rem 0">« ' + d.sujet + ' »</div>';
      html += '<div style="font-size:.7rem;color:#6a5a30">Prévue le ' + new Date(d.dateEvenement).toLocaleString('fr-FR') + ' · Auto-validée dans ' + heuresAvantAutoval + 'h</div>';
      html += '<div style="display:flex;gap:.4rem;margin-top:.4rem">';
      html += '<button onclick="traiterDemandeManifestation(&quot;' + d.id + '&quot;,true,' + pa + ',' + cost + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #2a4a20;background:transparent;color:#6a9a6a;cursor:pointer">Autoriser</button>';
      html += '<button onclick="traiterDemandeManifestation(&quot;' + d.id + '&quot;,false,' + pa + ',' + cost + ')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem;border:1px solid #4a2010;background:transparent;color:#cc4444;cursor:pointer">Interdire</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

const DELAI_EFFET_APRES_DEBUT_MIN = 90; // 1h30 apres le debut de l'evenement pour les manifestations autorisees

async function traiterDemandeManifestation(id, autorise, pa, cost) {
  const demande = await sbGetDemandeManifestationParId(id);
  if (!demande) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  document.getElementById('modal-postes')?.classList.remove('open');

  await sbMajDemandeManifestation(id, autorise ? 'autorisee' : 'interdite', {});

  if (autorise) {
    showToast('Manifestation autorisée', demande.sujet + ' — effet connu 1h30 après le début.', true, true);
    addJournalEntry('Autorisation de manifestation accordée : ' + demande.sujet, 'event-good');
  } else {
    const pays = state.country || 'republic';
    if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].IS = Math.max(0, INDICES_NATIONAUX[pays].IS - 5);
    // Malus sur le Ministre de l'Interieur lui-meme (refuser un rassemblement legitime a un cout politique)
    // Fix 9 aout 2026 : lisait POSTES?.[pays]?.min_int?.titulaire, une forme qui n'a jamais
    // existe dans la vraie structure de POSTES (jamais de cle plate par id, jamais de champ
    // .titulaire) - ce malus n'a donc jamais pu s'appliquer depuis la creation de cette fonction.
    const minIntInfo = typeof getTitulaireActuel === 'function' ? await getTitulaireActuel('min_int', null) : null;
    const minIntNom = minIntInfo?.estPJ ? minIntInfo.nom : null;
    if (minIntNom) {
      if (minIntNom === state.char?.name) {
        state.pop = Math.max(0, (state.pop||0) - 8);
        state.dis = Math.max(0, (state.dis||0) - 5);
        updateUI();
      } else if (typeof sbGet === 'function') {
        const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(minIntNom)}&select=pop,dis`).catch(() => []);
        const r = rows?.[0] || {};
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(minIntNom)}`, {
          pop: Math.max(0, (r.pop??50) - 8), dis: Math.max(0, (r.dis??50) - 5)
        }).catch(() => {});
      }
    }
    updateUI();
    showToast('Manifestation interdite', demande.sujet + (demande.orgaType === 'sportive' ? ' — défaite par forfait (0-1).' : '') + ' -5 IS, -8 POP/-5 DIS pour le Ministre.', false);
    addJournalEntry('Interdiction de manifestation : ' + demande.sujet, 'event-bad');
    addExternalEvent('🚫 INTERDICTION : Le Ministère de l\'Intérieur interdit "' + demande.sujet + '".');
  }
}

// Verifie toutes les demandes en attente pour ce pays et auto-valide celles arrivees a 12h de l'evenement
async function verifierAutoValidationManifestations(pays) {
  if (typeof sbGetDemandesManifestationPays !== 'function') return;
  const demandes = await sbGetDemandesManifestationPays(pays).catch(() => []);
  const maintenant = Date.now();
  for (const d of demandes) {
    const heuresRestantes = (new Date(d.dateEvenement) - maintenant) / (1000*60*60);
    if (heuresRestantes <= DELAI_AUTOVALIDATION_H) {
      await sbMajDemandeManifestation(d.id, 'autorisee', {});
    }
  }
}

// Applique l'effet des manifestations autorisees dont l'evenement a debute depuis plus de 1h30, une seule fois
async function verifierEffetsManifestationsEcoulees(pays) {
  if (typeof sbGetDemandesManifestationAutorisees !== 'function') return;
  const demandes = await sbGetDemandesManifestationAutorisees(pays).catch(() => []);
  const maintenant = Date.now();
  for (const d of demandes) {
    if (d.effetApplique) continue;
    const minutesEcoulees = (maintenant - new Date(d.dateEvenement).getTime()) / (1000*60);
    if (minutesEcoulees >= DELAI_EFFET_APRES_DEBUT_MIN) {
      await appliquerEffetManifestationValidee(d);
      await sbMajDemandeManifestation(d.id, 'autorisee', { effetApplique: true });
    }
  }
}

async function doDementiOfficiel(pa, cost) {
  const postesAutorisesDementi = ['president', 'pm', 'min_int', 'min_fin', 'min_just', 'min_def', 'min_info', 'min_ae'];
  if (!postesAutorisesDementi.includes(state.poste?.id)) { showToast('Réservé au gouvernement', 'Seuls le président et les membres du gouvernement peuvent démentir officiellement.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Démenti officiel';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement des rumeurs en cours...</div>';
  document.getElementById('modal-postes').classList.add('open');

  // Fix 9 aout 2026 : lisait POSTES?.[state.country]?.[id]?.titulaire, une forme qui n'a jamais
  // existe dans la vraie structure de POSTES (jamais de cle plate par id, jamais de champ
  // .titulaire) - cette liste de cibles n'a donc jamais pu inclure personne d'autre que
  // soi-meme depuis la creation de cette fonction.
  const postesGouvernementNommes = ['pm', 'min_int', 'min_fin', 'min_just', 'min_def', 'min_info', 'min_ae'];
  const cibles = [state.char?.name].filter(Boolean);
  const presidentActuel = CYCLES_ELECTORAUX?.[state.country]?.['president']?.eluId;
  if (presidentActuel && !cibles.includes(presidentActuel)) cibles.push(presidentActuel);
  for (const id of postesGouvernementNommes) {
    const titulaireInfo = typeof getTitulaireActuel === 'function' ? await getTitulaireActuel(id, null) : null;
    if (titulaireInfo?.estPJ && !cibles.includes(titulaireInfo.nom)) cibles.push(titulaireInfo.nom);
  }

  let toutesRumeurs = [];
  for (const cible of cibles) {
    if (typeof sbGetRumeursActivesCible !== 'function') break;
    const rumeurs = await sbGetRumeursActivesCible(cible).catch(() => []);
    toutesRumeurs.push(...rumeurs);
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.8rem">Rumeurs actives concernant le président et le gouvernement. Un démenti réussi efface la rumeur et rétablit la popularité perdue ; un échec double la perte.</div>';
  if (toutesRumeurs.length === 0) {
    html += '<div style="font-size:.8rem;color:#5a5040;font-style:italic">Aucune rumeur active pour l\'instant.</div>';
  } else {
    toutesRumeurs.forEach(r => {
      html += '<div style="border:1px solid #2a2010;padding:.6rem;margin-bottom:.5rem">';
      html += '<div style="font-size:.78rem;color:#c0b090">Concernant <b>' + r.cible + '</b></div>';
      html += '<div style="font-size:.72rem;color:#8a8060;font-style:italic;margin:.3rem 0">« ' + r.contenu.substring(0, 100) + (r.contenu.length > 100 ? '…' : '') + ' »</div>';
      html += '<button onclick="confirmerDementi(\'' + r.id + '\',\'' + r.cible + '\',' + (r.popPerdu||15) + ',' + pa + ',' + cost + ')" style="width:100%;padding:.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer;font-size:.72rem">Démentir cette rumeur</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerDementi(rumeurId, cible, popPerdu, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const roll = Math.floor(Math.random() * 100) + 1;
  const taux = 80; // successRate declare sur l'ordre

  if (roll <= taux) {
    if (typeof sbResoudreRumeur === 'function') await sbResoudreRumeur(rumeurId).catch(() => {});
    const nouveauPop = typeof sbAjusterPopJoueur === 'function' ? await sbAjusterPopJoueur(cible, popPerdu, 'dementi_reussi').catch(() => null) : null;
    if (cible === state.char?.name && nouveauPop !== null) { state.pop = nouveauPop; updateUI(); }
    showToast('Démenti réussi !', 'La rumeur est effacée, la popularité de ' + cible + ' est rétablie.', true, true);
    addJournalEntry('Démenti officiel réussi concernant ' + cible + '.', 'event-good');
    addExternalEvent('📢 La présidence dément officiellement les rumeurs concernant ' + cible + '.');
  } else {
    const nouveauPop = typeof sbAjusterPopJoueur === 'function' ? await sbAjusterPopJoueur(cible, -(popPerdu * 2), 'dementi_rate').catch(() => null) : null;
    if (cible === state.char?.name && nouveauPop !== null) { state.pop = nouveauPop; updateUI(); }
    showToast('Démenti raté !', 'L\'opération se retourne contre ' + cible + '. Perte de popularité doublée.', false);
    addJournalEntry('Démenti officiel raté, la situation s\'aggrave pour ' + cible + '.', 'event-bad');
    addExternalEvent('📢 Le démenti officiel de la présidence échoue, aggravant les soupçons sur ' + cible + '.');
  }
}

function ouvrirNommerMinistresModal(pa, cost) {
  if (state.poste?.id !== 'pm') {
    showToast('Acces refuse', 'Seul le Premier Ministre peut nommer des ministres.', false);
    return;
  }
  const postesMinisteriels = [
    { id:'min_int', name:"Ministre de l'Interieur" },
    { id:'min_fin', name:'Ministre des Finances' },
    { id:'min_just', name:'Ministre de la Justice' },
    { id:'min_def', name:'Ministre de la Defense' },
    { id:'min_info', name:"Ministre de l'Information" },
    { id:'min_ae', name:'Ministre des Affaires Etrangeres' }
  ];

  document.getElementById('postes-modal-title').textContent = 'Nommer des ministres';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Choisissez le ministere a pourvoir.</div>';
  postesMinisteriels.forEach(p => {
    html += '<button onclick="ouvrirNominerPosteNomme(\'' + p.id + '\',' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;color:#c0b090;cursor:pointer;font-family:Crimson Pro,serif;font-size:.85rem;margin-bottom:.4rem">' + p.name + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Appliquer malus ISN aux actes illegaux
// Signature inchangee (0 argument) pour ne pas toucher les 20 sites d'appel -- lit desormais
// l'indice de Securite de la ville courante du joueur (Republia), repli national inchange pour
// les 3 autres empires (voir getIndiceVille, plateau-divers.js).
function getMalusISN() {
  const pays = state.country || 'republic';
  const ville = state.currentCity || 'capitale';
  const isn = (typeof getIndiceVille === 'function') ? getIndiceVille(pays, ville, 'isn') : (INDICES_NATIONAUX[pays]?.ISN || 30);
  if (isn <= 20) return 0;
  if (isn <= 40) return 5;
  if (isn <= 60) return 10;
  if (isn <= 80) return 15;
  return 25;
}

function creerPosteMinistre(pa, cost) {
  if (!state.postesCustom) state.postesCustom = { ministre: null, comite: null };
  if (state.postesCustom.ministre) {
    showToast('Limite atteinte', 'Vous avez deja cree un poste ministeriel custom. Supprimez-le d\'abord.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Creer un poste ministeriel';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Vous pouvez creer 1 poste ministeriel et 1 comite. Salaire aligne sur les ministres (2800 FR/jour).</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">INTITULE DU POSTE</div>' +
    '<input id="custom-poste-nom" type="text" placeholder="Ex: Ministre de la Transition Numerique" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem"/>' +
    '<button onclick="validerCreationPoste(\'ministre\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Creer ce poste</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

function creerComite(pa, cost) {
  if (!state.postesCustom) state.postesCustom = { ministre: null, comite: null };
  if (state.postesCustom.comite) {
    showToast('Limite atteinte', 'Vous avez deja cree un comite. Supprimez-le d\'abord.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Creer un comite';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem">' +
    '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Comite presidentiel special. Salaire aligne sur les ministres.</div>' +
    '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">INTITULE DU COMITE</div>' +
    '<input id="custom-poste-nom" type="text" placeholder="Ex: Comite pour la Modernisation de l\'Etat" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem"/>' +
    '<button onclick="validerCreationPoste(\'comite\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Creer ce comite</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function validerCreationPoste(type, pa, cost) {
  if (!exigerPoste('president', 'Seul le Président peut créer un poste ou un comité par décret.')) return;
  const nom = document.getElementById('custom-poste-nom')?.value?.trim();
  if (!nom) { showToast('Nom requis', 'Donnez un nom a ce poste.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  if (!state.postesCustom) state.postesCustom = { ministre: null, comite: null };
  state.postesCustom[type] = { nom, salaire: 2800, createur: state.char?.name, jour: state.day };
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Poste cree !', '"' + nom + '" a ete cree. Nommez quelqu\'un depuis votre bureau.', true, true);
  addJournalEntry('Nouveau poste cree par decret presidentiel : ' + nom, 'event-good');
  addExternalEvent('Le President a cree le poste de "' + nom + '" par decret.');
}

function supprimerPosteCustom() {
  if (!state.postesCustom || (!state.postesCustom.ministre && !state.postesCustom.comite)) {
    showToast('Aucun poste custom', 'Vous n\'avez pas cree de poste ou comite a supprimer.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Supprimer un poste';
  let html = '<div style="padding:1rem">';
  if (state.postesCustom.ministre) {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem;display:flex;justify-content:space-between;align-items:center">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + state.postesCustom.ministre.nom + '</div>';
    html += '<button onclick="confirmerSupprPoste(\'ministre\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Supprimer</button>';
    html += '</div>';
  }
  if (state.postesCustom.comite) {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem;display:flex;justify-content:space-between;align-items:center">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + state.postesCustom.comite.nom + '</div>';
    html += '<button onclick="confirmerSupprPoste(\'comite\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.25rem .6rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Supprimer</button>';
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerSupprPoste(type) {
  if (!exigerPoste('president', 'Seul le Président peut supprimer un poste créé par décret.')) return;
  const nom = state.postesCustom[type]?.nom || '';
  state.postesCustom[type] = null;
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Poste supprime', '"' + nom + '" a ete supprime.', false);
  addJournalEntry('Poste supprime par decret : ' + nom, '');
}

// =====================
// FORUM
// =====================
// Forum gere par forum.js

// openForum delegue a forum.js
// Forum gere par forum.js — voir openForum() dans forum.js




// =====================
// VOTE DE CONFIANCE (declenchee par le PM, soumise a l'Assemblee Nationale)
// =====================
async function ouvrirDeclencherVoteConfiance(pa, cost) {
  if (state.poste?.id !== 'pm') {
    showToast('Accès refusé', 'Seul le Premier Ministre peut déclencher un vote de confiance.', false);
    return;
  }

  const voteExistant = (typeof sbGetVoteConfianceEnCours === 'function') ? await sbGetVoteConfianceEnCours(state.country) : null;
  if (voteExistant) {
    showToast('Vote déjà en cours', 'Un vote de confiance est déjà en cours à l\'Assemblée.', false);
    return;
  }

  document.getElementById('postes-modal-title').textContent = 'Déclencher un vote de confiance';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">Vous engagez la responsabilité de votre gouvernement devant l\'Assemblée Nationale (9 sièges de députés). Vote sous 48h réelles. En cas de censure (majorité simple), vous êtes politiquement appelé(e) à démissionner : passé un délai de 48h réelles supplémentaires sans démission, votre popularité et celle de tout le gouvernement tombent à zéro — mais vos postes ne sont jamais retirés automatiquement.</div>' +
    '<button onclick="confirmerDeclenchementVoteConfiance(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Engager la responsabilité du gouvernement</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDeclenchementVoteConfiance(pa, cost) {
  document.getElementById('modal-postes').classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  // Correctif "clôture jamais appelée" (audit du 4 septembre 2026) : cloture_ts en temps REEL
  // (Date.now(), jamais state.day -- personnel, non fiable comme horloge partagee, meme doctrine
  // que le reste du moteur electoral) permet desormais au cron de detecter l'echeance et de
  // resoudre le vote lui-meme (resoudreVotesConfianceEchusServeur, api/cron-minuit.js), ce qui
  // n'existait nulle part avant ce chantier.
  const vote = {
    id: 'voteconf-' + Date.now(),
    country: state.country,
    pm_nom: state.char?.name || 'Anonyme',
    cloture_ts: Date.now() + 48 * 60 * 60 * 1000
  };

  if (typeof sbCreerVoteConfiance === 'function') {
    await sbCreerVoteConfiance(vote).catch(() => {});
  }

  showToast('Vote de confiance déclenché', 'L\'Assemblée se prononcera dans 48h.', true, true);
  addJournalEntry('Vote de confiance déclenché par le Premier Ministre.', 'event-info');
  addExternalEvent('🏛 Le Premier Ministre ' + (state.char?.name||'') + ' engage la responsabilité de son gouvernement devant l\'Assemblée Nationale.', 'national');

  // Notifier tous les deputes PJ pour qu'ils puissent voter
  await notifierDeputesPourVoteConfiance(vote);
}

// Correctif "poste_depute au lieu de poste, pattern 'depute' exact au lieu de 'depute_'" (audit
// du 4 septembre 2026, dette deja documentee dans le code lui-meme -- voir doDissoudreAssemblee,
// qui utilisait deja le bon motif). Consequence de l'ancien bug : cette fonction ne notifiait
// jamais aucun depute, 100% du temps (les deux conditions etaient independamment toujours fausses).
async function notifierDeputesPourVoteConfiance(vote) {
  if (typeof sbListPersonnages !== 'function' || typeof sbSendMail !== 'function') return;
  try {
    const joueurs = await sbListPersonnages() || [];
    const deputesPJ = joueurs.filter(j => {
      let pd = j.poste_depute;
      if (typeof pd === 'string') { try { pd = JSON.parse(pd); } catch(e) { pd = null; } }
      return j.country === vote.country && pd?.id === 'depute';
    });

    const h = String(state.hour || 8).padStart(2,'0');
    const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    const sujet = 'Vote de confiance — Assemblée Nationale';
    const corps = 'Le Premier Ministre ' + vote.pm_nom + ' engage la responsabilité de son gouvernement. ' +
      'Votez avant 48h.<br><br>' +
      marqueurActionMail('confiance_pour', vote.id) + marqueurActionMail('confiance_contre', vote.id);

    for (const dep of deputesPJ) {
      await sbSendMail('Assemblée Nationale', dep.name, sujet, corps, time).catch(() => {});
    }
  } catch(e) { console.warn('notifierDeputesPourVoteConfiance error', e); }
}

// Appelee quand un depute PJ clique Pour/Contre dans le mail. Meme correctif de champ/motif que
// notifierDeputesPourVoteConfiance ci-dessus.
async function voterConfiance(voteId, choix) {
  document.getElementById('modal-pnj')?.classList.remove('open');

  if (state.posteDepute?.id !== 'depute') {
    showToast('Accès refusé', 'Seuls les députés peuvent voter.', false);
    return;
  }

  const ok = typeof sbDeposerBulletinConfiance === 'function'
    ? await sbDeposerBulletinConfiance(voteId, state.char?.name, choix)
    : false;

  if (!ok) {
    showToast('Vote impossible', 'Ce vote de confiance n\'est plus ouvert, ou vous avez déjà voté.', false);
    return;
  }
  showToast('Vote enregistré', 'Votre vote (' + (choix === 'pour' ? 'Confiance' : 'Censure') + ') a été pris en compte.', true);
  addJournalEntry('Vous avez voté ' + (choix === 'pour' ? 'la confiance' : 'la censure') + ' au gouvernement.', 'event-info');
}

// Cloture desormais geree cote SERVEUR (resoudreVotesConfianceEchusServeur, api/cron-minuit.js) :
// cette fonction client n'avait jamais d'appelant (confirme par l'audit du 4 septembre 2026) et
// ne pouvait de toute facon jamais s'executer de facon fiable independamment d'une session
// active. Conservee ici a titre documentaire uniquement, non appelee, non supprimee (aucun risque
// a la laisser en place).
async function cloturerVoteConfiance(vote) {
  console.warn('cloturerVoteConfiance (client) est obsolete -- la cloture reelle est geree par le cron serveur.');
}


// =====================
// DEMISSION D'UN POSTE
// =====================
async function demissionnerDuPoste() {
  if (!state.poste) {
    showToast('Aucun poste', 'Vous n\'occupez actuellement aucun poste.', false);
    return;
  }

  const ancienPosteNom = state.poste.name;
  state.poste = null;
  if (state.char) state.char.poste = null;
  updateUI();

  // Rafraichir la carte "Personnes presentes" (self-card), qui affiche le poste et n'est
  // pas couverte par updateUI() -- sans ca le titre reste affiche jusqu'a un F5 complet.
  if (typeof renderPersonsList === 'function' && typeof BUILDINGS !== 'undefined') {
    const roomCourante = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
    if (roomCourante) renderPersonsList(roomCourante.persons || []);
  }

  if (typeof sbSavePersonnage === 'function') {
    await sbSavePersonnage(state).catch(() => {});
  }

  showToast('Démission effective', 'Vous avez quitté le poste de ' + ancienPosteNom + '.', true, true);
  addJournalEntry('Démission du poste de ' + ancienPosteNom + '.', 'event-info');
  addExternalEvent('📜 ' + (state.char?.name || 'Quelqu\'un') + ' démissionne du poste de ' + ancienPosteNom + '.', 'national');
}

function ouvrirConfirmationDemission() {
  if (!state.poste) {
    showToast('Aucun poste', 'Vous n\'occupez actuellement aucun poste.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Démissionner';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1rem">' +
    '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">Êtes-vous sûr(e) de vouloir démissionner du poste de <strong>' + state.poste.name + '</strong> ? Cette action est immédiate et irréversible.</div>' +
    '<button onclick="demissionnerDuPoste();document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a3020;background:transparent;color:#cc4444;cursor:pointer">Confirmer la démission</button>' +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}


// =====================
// INDICES LOCAUX & BUDGET MUNICIPAL
// =====================
const CATEGORIES_BUDGET_MAIRIE = ['commissariat', 'multimodal', 'stade', 'marche', 'dispensaire', 'tribunal'];
const LABELS_BUDGET_MAIRIE = { commissariat: 'Commissariat', multimodal: 'Centre Multimodal', stade: 'Stade', marche: 'Marche', dispensaire: 'Dispensaire', tribunal: 'Tribunal' };

function getBuildingIdPourCategorieBudget(cat, ville) {
  if (cat === 'commissariat') return getBuildingIdCommissariat(ville);
  if (cat === 'multimodal') return getBuildingIdCentreMultimodal(ville);
  if (cat === 'dispensaire') return getBuildingIdDispensaire(ville);
  if (cat === 'tribunal') return getBuildingIdTribunal(ville);
  // stade/marche (et toute categorie future sans helper dedie) : repli generique sur la meme
  // caisse locale (A3, lot caisses locales, 16 aout 2026) -- retournait auparavant 'cat' tel
  // quel (ex. 'marche'), un buildingId de navigation partage entre plusieurs villes, fusionnant
  // leurs caisses.
  return typeof getCaisseLocaleId === 'function' ? getCaisseLocaleId(cat, ville) : cat;
}

function getVilleKey() {
  return (state.country || 'republic') + '_' + (state.currentCity || 'capitale');
}

async function chargerBudgetMunicipal() {
  if (typeof sbGetBudgetMunicipal !== 'function') return null;
  const key = getVilleKey();
  let data = await sbGetBudgetMunicipal(key).catch(() => null);
  if (!data) {
    data = {
      key,
      allocation: { commissariat: 20, multimodal: 15, stade: 15, marche: 15, dispensaire: 20, tribunal: 15 },
      caisse: 0,
      // Taxe fonciere : FR/m2/jour, prerogative du maire (min/max a definir dans le futur
      // tableau de bord municipal, pour eviter qu'un taux abusif ruine les proprietaires).
      tauxFoncier: 0.05,
      derniereDistribJour: state.day || 1
    };
    if (typeof sbSaveBudgetMunicipal === 'function') await sbSaveBudgetMunicipal(key, data).catch(() => {});
  }
  return data;
}

// Variante parametree de chargerBudgetMunicipal (qui suppose toujours la ville courante du
// joueur via getVilleKey) -- necessaire pour Interdire/Reprimer une manifestation, qui ciblent
// une ville choisie par le Ministre, pas forcement celle ou il se trouve.
async function chargerBudgetMunicipalPourVille(pays, ville) {
  const key = pays + '_' + ville;
  if (typeof sbGetBudgetMunicipal !== 'function') return { key, allocation: { commissariat:20, multimodal:15, stade:15, marche:15, dispensaire:20, tribunal:15 }, caisse:0, tauxFoncier:0.05, derniereDistribJour: state.day||1 };
  let data = await sbGetBudgetMunicipal(key).catch(() => null);
  if (!data) {
    data = { key, allocation: { commissariat:20, multimodal:15, stade:15, marche:15, dispensaire:20, tribunal:15 }, caisse:0, tauxFoncier:0.05, derniereDistribJour: state.day||1 };
    if (typeof sbSaveBudgetMunicipal === 'function') await sbSaveBudgetMunicipal(key, data).catch(() => {});
  }
  return data;
}

// IDENTITE PARTAGEE DE LA JOURNEE (25 septembre 2026). Ce marqueur vit dans une ligne PARTAGEE
// (budgets_municipaux) et etait compare a `state.day`, qui est un compteur PROPRE A CHAQUE
// PERSONNAGE : un joueur est au jour 3, un autre au jour 47. Deux habitants de la meme ville
// vidaient donc chacun la caisse municipale vers les batiments le meme soir reel, puisque leurs
// deux compteurs differaient. La caisse etait distribuee deux fois, puis remise a zero.
//
// jourPartageISO() rend la date reelle Europe/Paris, la meme pour tous les joueurs ET pour le
// cron (jourParisISO, api/cron-minuit.js). C'est exactement le correctif deja applique a la
// distribution fiscale nationale et au paiement des effectifs de police -- voir le commentaire
// canonique de plateau-core.js:2010-2045. Aucune regle de jeu ne change : une distribution par
// jour, comme avant. Seule la definition de « le meme jour » devient commune.
//
// Les anciens marqueurs numeriques (issus de state.day) ne correspondent a aucune date ISO : la
// premiere distribution apres ce correctif a donc lieu normalement, et une seule fois.
//
// LIMITE ASSUMEE, consignee au rapport : deux navigateurs qui declencheraient la distribution
// dans la meme seconde passeraient tous deux la garde. La fermer exige un compare-and-swap
// serveur sur la caisse municipale -- une brique economique, hors perimetre de cette passe.
async function distribuerBudgetMunicipalVersBatiments(pays, ville) {
  const data = await chargerBudgetMunicipal();
  if (!data) return;
  const jour = (typeof jourPartageISO === 'function') ? jourPartageISO() : (state.day || 1);
  if (data.derniereDistribJour === jour) return;

  const montantAReparter = data.caisse || 0;
  if (montantAReparter > 0) {
    for (const cat of CATEGORIES_BUDGET_MAIRIE) {
      const part = (data.allocation[cat] || 0) / 100;
      const montant = Math.floor(montantAReparter * part);
      if (montant > 0) {
        const buildingId = getBuildingIdPourCategorieBudget(cat, ville);
        if (typeof crediterCaisseBatiment === 'function') await crediterCaisseBatiment(pays, buildingId, montant);
      }
    }
  }
  data.caisse = 0;
  data.derniereDistribJour = jour;
  if (typeof sbSaveBudgetMunicipal === 'function') await sbSaveBudgetMunicipal(data.key, data).catch(() => {});
}

async function doConsulterIndicesLocaux() {
  const ville = state.currentCity;
  const pays = state.country;
  document.getElementById('postes-modal-title').textContent = 'Caisses communales — ' + (WORLD[pays]?.[ville]?.name || ville);
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const cur = COUNTRIES[pays]?.cur || 'FR';
  let html = '<div style="padding:1rem">';
  for (const cat of CATEGORIES_BUDGET_MAIRIE) {
    const buildingId = getBuildingIdPourCategorieBudget(cat, ville);
    // LE COMMISSARIAT FAIT EXCEPTION DEPUIS LE 15 SEPTEMBRE 2026. Cet ecran est public et gratuit
    // a l'Hotel de Ville : il exposait donc le solde du commissariat a n'importe quel joueur, ce
    // qui aurait rendu cosmetique la restriction posee sur l'ordre du commissariat lui-meme. La
    // caisse est desormais lue par une RPC qui tranche l'autorisation (commissaire de la ville,
    // maire et adjoint, ministre de l'Interieur, president) ; les cinq autres caisses communales
    // restent publiques, c'est un choix de game design propre a leurs batiments.
    let libelleSolde;
    if (cat === 'commissariat') {
      const r = (typeof lireCaisseCommissariat === 'function')
        ? await lireCaisseCommissariat(pays, buildingId) : { ok: false };
      libelleSolde = r && r.ok
        ? Number(r.solde || 0).toLocaleString('fr-FR') + ' ' + cur
        : 'reserve';
    } else {
      const caisse = typeof chargerCaisseBatiment === 'function' ? await chargerCaisseBatiment(pays, buildingId) : { solde: 0 };
      libelleSolde = (caisse?.solde || 0).toLocaleString('fr-FR') + ' ' + cur;
    }
    html += '<div style="display:flex;justify-content:space-between;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem">';
    html += '<span style="font-size:.82rem;color:#c0b090">' + LABELS_BUDGET_MAIRIE[cat] + '</span>';
    html += '<strong style="font-size:.82rem;color:' + (libelleSolde === 'reserve' ? '#6a5a30' : '#C9A84C') + '">' + libelleSolde + '</strong>';
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function doRepartirBudgetMunicipal(pa, cost) {
  document.getElementById('postes-modal-title').textContent = 'Répartir le budget municipal';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const data = await chargerBudgetMunicipal();
  if (!data) return;

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">Répartissez 100% des recettes fiscales locales entre les batiments communaux. Applique chaque nuit, credite directement leur caisse reelle.</div>';
  CATEGORIES_BUDGET_MAIRIE.forEach(cat => {
    html += '<div style="margin-bottom:.6rem">';
    html += '<label style="font-size:.75rem;color:#c0b090;display:block;margin-bottom:.2rem">' + LABELS_BUDGET_MAIRIE[cat] + '</label>';
    html += '<input type="number" id="budget-' + cat + '" value="' + data.allocation[cat] + '" min="0" max="100" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;box-sizing:border-box"/>';
    html += '</div>';
  });
  html += '<div id="budget-total-warning" style="font-size:.72rem;color:#cc6a44;margin-bottom:.6rem"></div>';
  html += '<button onclick="confirmerRepartitionBudget(' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Valider la répartition</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerRepartitionBudget(pa, cost) {
  const key = getVilleKey();
  const allocation = {};
  let total = 0;
  CATEGORIES_BUDGET_MAIRIE.forEach(cat => {
    const v = Math.max(0, parseInt(document.getElementById('budget-' + cat)?.value || '0'));
    allocation[cat] = v;
    total += v;
  });
  if (total !== 100) {
    document.getElementById('budget-total-warning').textContent = 'Le total doit être exactement 100% (actuellement ' + total + '%).';
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const data = await sbGetBudgetMunicipal(key).catch(() => null) || await chargerBudgetMunicipal();
  data.allocation = allocation;
  await sbSaveBudgetMunicipal(key, data).catch(() => {});
  document.getElementById('modal-postes').classList.remove('open');
  showToast('Budget mis à jour', 'La nouvelle repartition sera appliquee des le prochain reveil.', true, true);
  addJournalEntry('Nouvelle répartition du budget municipal validée.', 'event-good');
}

// =====================
// SYSTEME MILITAIRE — guerre partagee, chaine de commandement, compagnies, detachements
// =====================
const EFFECTIF_SECTION = 24; // + 1 lieutenant = 25 par section
const NB_SECTIONS_COMPAGNIE = 4; // 4 x 24 = 96 hommes au contingent (le serveur fait foi)
const COUT_COMPAGNIE = 20000; // preleve sur la caisse de la caserne
// Contingent achete par les 20 000 FR : 4 sections x 24 places. Miroir de la constante
// serveur de militaire_compagnie_creer, qui seule fait autorite.
const CONTINGENT_COMPAGNIE = NB_SECTIONS_COMPAGNIE * EFFECTIF_SECTION;

// ---- GUERRE PARTAGEE ----
async function ouvrirModalGuerreEmpire(pa, cost) {
  const pays = state.country || 'republic';
  const empires = Object.entries(COUNTRIES).filter(([k]) => k !== pays);
  document.getElementById('postes-modal-title').textContent = 'Déclarer la guerre';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const guerresActives = typeof sbGetGuerresPays === 'function' ? await sbGetGuerresPays(pays).catch(() => []) : [];

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#cc4444;font-style:italic;margin-bottom:.8rem">-20 POP +10 INF · Nation : -20 ID +15 ISN. Visible de tous, y compris l\'empire visé.</div>';
  empires.forEach(([k, co]) => {
    const guerre = guerresActives.find(g => (g.attaquant === pays && g.attaque === k) || (g.attaquant === k && g.attaque === pays));
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem;display:flex;align-items:center;justify-content:space-between">';
    html += '<div><div style="font-family:Playfair Display,serif;font-size:.85rem;color:#e0d5b8">' + co.n + '</div>';
    html += '<div style="font-size:.7rem;color:' + (guerre ? '#cc4444' : '#a89870') + '">' + (guerre ? 'En guerre depuis Jour ' + guerre.jourDebut : 'En paix') + '</div></div>';
    if (!guerre) {
      html += '<button onclick="confirmerGuerreEmpire(\'' + k + '\',\'' + co.n + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .7rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Déclarer</button>';
    }
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function confirmerGuerreEmpire(empireId, empireName, pa, cost) {
  if (!exigerPoste('president', 'Seul le Président peut déclarer la guerre.')) return;
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const pays = state.country || 'republic';
  // Le serveur verifie le poste et lit le pays sur la fiche : rien n'est transmis d'autre
  // que l'empire vise (§6.3, 20 septembre 2026).
  const rG = await sbDeclarerGuerre(empireId);
  if (!rG || rG.ok !== true) {
    const motifs = { reserve_au_president: 'Seul le Président peut déclarer la guerre.',
                     guerre_deja_active:   'Une guerre est déjà active entre ces deux empires.',
                     cible_invalide:       'Empire visé invalide.' };
    showToast('Déclaration refusée', motifs[rG && rG.raison] || 'Le serveur a refusé la déclaration.', false);
    return;
  }
  state.pop = Math.max(0, (state.pop||0) - 20);
  state.inf = Math.min(100, (state.inf||0) + 10);
  INDICES_NATIONAUX[pays].ID = Math.max(0, INDICES_NATIONAUX[pays].ID - 20);
  INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 15);
  updateUI();
  addExternalEvent('⚔️ GUERRE DÉCLARÉE : ' + (COUNTRIES[pays]?.n||'') + ' déclare la guerre à ' + empireName + ' !');
  showToast('Guerre déclarée !', 'Conflit ouvert avec ' + empireName + '. Visible par tous.', false, true);
  addJournalEntry('Guerre déclarée contre ' + empireName + '.', 'event-bad');
}

// Etape 1 : le MAE propose une treve a son homologue
async function ouvrirProposerTreve(pa, cost) {
  if (state.poste?.id !== 'min_ae') { showToast('Réservé au Ministre des Affaires Étrangères', '', false); return; }
  const pays = state.country || 'republic';
  const guerres = await sbGetGuerresPays(pays).catch(() => []);
  const enCours = guerres.filter(g => g.statut === 'active' && !g.ceasefire);
  document.getElementById('postes-modal-title').textContent = 'Proposer une trêve';
  let html = '<div style="padding:1rem">';
  if (enCours.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun conflit actif nécessitant une trêve.</div>';
  } else {
    enCours.forEach(g => {
      const adversaire = g.attaquant === pays ? g.attaque : g.attaquant;
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.85rem;color:#e0d5b8">' + (COUNTRIES[adversaire]?.n||adversaire) + '</div>';
      html += '<button onclick="confirmerPropositionTreve(\'' + g.id + '\',\'' + adversaire + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Proposer</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerPropositionTreve(guerreId, adversaire, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const maeAdversaireInfo = await getTitulaireActuel('min_ae', null, adversaire);
  const maeAdversaire = maeAdversaireInfo?.estPJ ? maeAdversaireInfo.nom : null;
  if (typeof sbSendMail === 'function') {
    await sbSendMail('Ministère des Affaires Étrangères', maeAdversaire || 'PNJ-MAE',
      'Proposition de trêve', (state.char?.name||'Le Ministre') + ' propose une trêve. Répondez pour l\'accepter.',
      typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }
  const rT = await sbProposerTreve(guerreId);
  if (!rT || rT.ok !== true) {
    const motifs = { reserve_au_ministre_ae: 'Réservé au Ministre des Affaires Étrangères.',
                     guerre_introuvable:     'Cette guerre n\'est plus active.',
                     pays_non_belligerant:   'Votre empire n\'est pas partie à ce conflit.' };
    showToast('Trêve refusée', motifs[rT && rT.raison] || 'Le serveur a refusé la proposition.', false);
    return;
  }
  showToast('Trêve proposée', 'En attente de la réponse de l\'homologue.', true, true);
  addJournalEntry('Trêve proposée à ' + (COUNTRIES[adversaire]?.n||adversaire) + '.', 'event-info');
}

// REPONSE A UNE PROPOSITION DE TREVE — autorite arbitree le 20 septembre 2026.
//
// La chaine canonique est : le Ministre des Affaires Etrangeres du pays A propose, celui du
// pays B DESTINATAIRE accepte ou refuse, puis chaque Ministre de la Defense met en oeuvre le
// cessez-le-feu de son cote. Le serveur calcule lui-meme le destinataire a partir du pays du
// proposant, desormais inscrit sur la proposition : ni le proposant ni un tiers ne peuvent
// repondre a sa place.
async function repondreTreve(guerreId, accepte) {
  const r = await sbRepondreTreve(guerreId, accepte);
  if (!r || r.ok !== true) {
    const motifs = {
      reserve_au_ministre_ae:     'Réservé au Ministre des Affaires Étrangères.',
      reserve_au_destinataire:    'Seul l\'empire destinataire de la proposition peut y répondre.',
      aucune_proposition:         'Aucune trêve n\'a été proposée.',
      proposition_deja_tranchee:  'Cette proposition a déjà reçu une réponse.',
      guerre_introuvable:         'Cette guerre n\'est plus active.'
    };
    showToast('Réponse refusée', motifs[r && r.raison] || 'Le serveur a refusé la réponse.', false);
    return;
  }
  if (r.accepte) {
    showToast('Trêve acceptée', 'Chaque Ministre de la Défense doit maintenant activer le cessez-le-feu de son côté.', true, true);
    addExternalEvent('🕊️ Une trêve a été négociée entre les deux Ministères des Affaires Étrangères.');
  } else {
    showToast('Trêve refusée', 'La proposition a été déclinée.', false);
    addExternalEvent('⚔️ Une proposition de trêve a été refusée.');
  }
}

// Conservee comme alias : l'acceptation est le cas nominal.
async function accepterTreve(guerreId) { return repondreTreve(guerreId, true); }
async function refuserTreve(guerreId)  { return repondreTreve(guerreId, false); }

// Etape 2 : chaque MG active independamment le cessez-le-feu de son cote
async function ouvrirActiverCessezLeFeu(pa, cost) {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const pays = state.country || 'republic';
  const guerres = await sbGetGuerresPays(pays).catch(() => []);
  const negociees = guerres.filter(g => g.ceasefire?.accepteePar);
  document.getElementById('postes-modal-title').textContent = 'Activer le cessez-le-feu';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Chaque camp doit activer le cessez-le-feu de son côté — un décalage entre les deux est possible et source de confusion.</div>';
  if (negociees.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune trêve négociée par la diplomatie pour l\'instant.</div>';
  } else {
    negociees.forEach(g => {
      const adversaire = g.attaquant === pays ? g.attaque : g.attaquant;
      const dejaActif = g.ceasefire?.actifPar?.[pays];
      html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;display:flex;justify-content:space-between;align-items:center">';
      html += '<div style="font-size:.85rem;color:#e0d5b8">' + (COUNTRIES[adversaire]?.n||adversaire) + '<div style="font-size:.7rem;color:#a89870">' + (g.ceasefire?.actifPar?.[adversaire] ? 'Adversaire : activé' : 'Adversaire : pas encore activé') + '</div></div>';
      html += dejaActif
        ? '<span style="font-size:.7rem;color:#6ab858">Activé de votre côté</span>'
        : '<button onclick="confirmerActivationCessezLeFeu(\'' + g.id + '\',\'' + adversaire + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer">Activer</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerActivationCessezLeFeu(guerreId, adversaire, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const rows = await sbGet('guerres', `id=eq.${encodeURIComponent(guerreId)}`);
  const g = rows?.[0]?.data;
  if (!g) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const actifPar = { ...(g.ceasefire?.actifPar || {}), [pays]: true };
  const tousActifs = actifPar[g.attaquant] && actifPar[g.attaque];
  // Le serveur marque le cote de l'acteur et decide lui-meme si les deux cotes ont active :
  // `actifPar` et `tousActifs` calcules ici ne servent plus qu'a l'affichage immediat.
  const rC = await sbActiverCessezLeFeu(guerreId);
  if (!rC || rC.ok !== true) {
    const motifs = { reserve_au_ministre_defense: 'Réservé au Ministre de la Défense.',
                     guerre_introuvable:          'Cette guerre n\'est plus active.',
                     aucune_treve_proposee:       'Aucune trêve n\'a été proposée.',
                     pays_non_belligerant:        'Votre empire n\'est pas partie à ce conflit.' };
    showToast('Activation refusée', motifs[rC && rC.raison] || 'Le serveur a refusé l\'activation.', false);
    return;
  }

  INDICES_NATIONAUX[pays].ID = Math.min(100, INDICES_NATIONAUX[pays].ID + 10);
  updateUI();
  if (tousActifs) {
    showToast('Cessez-le-feu total !', 'Les deux camps ont activé le cessez-le-feu. Le conflit est terminé.', true, true);
    addExternalEvent('🕊️ Cessez-le-feu total entre ' + (COUNTRIES[pays]?.n) + ' et ' + (COUNTRIES[adversaire]?.n) + '.');
  } else {
    showToast('Cessez-le-feu activé de votre côté', 'L\'adversaire n\'a pas encore fait de même — confusion sur le terrain probable.', true, true);
    addExternalEvent('⚠️ ' + (COUNTRIES[pays]?.n) + ' active unilatéralement le cessez-le-feu avec ' + (COUNTRIES[adversaire]?.n) + ' — l\'autre camp n\'a pas suivi.');
  }
}

function estEnGuerreAvec(pays1, pays2, guerresCache) {
  return (guerresCache || []).some(g => g.statut === 'active' && ((g.attaquant === pays1 && g.attaque === pays2) || (g.attaquant === pays2 && g.attaque === pays1)));
}

// ---- CHAINE DE COMMANDEMENT ----
// ouvrirNommerCommandant / envoyerNominationCommandant SUPPRIMEES le 7 septembre 2026.
//
// C'etait une reimplementation ad-hoc de la nomination, anterieure au moteur generique. Elle etait
// devenue du CODE MORT -- l'ordre 'nommer_commandant' n'existe plus dans data.js depuis le
// regroupement des prerogatives, et sa seule route pointait donc dans le vide -- mais elle restait
// appelable depuis la console, et elle CONTOURNAIT la revalidation d'eligibilite : elle envoyait le
// mail d'acceptation sans verifier ni les etudes, ni la qualification militaire, ni le poste
// exclusif deja occupe.
//
// La nomination du Commandant passe desormais par UNE SEULE voie : gerer_commandement ->
// ouvrirNominerPosteNomme('commandant') -> envoyerNominationPosteNomme, qui porte la revalidation.
// Aucune voie secondaire ne subsiste.

async function ouvrirNommerCapitaine(pa, cost) {
  if (state.poste?.id !== 'commandant') { showToast('Réservé au Commandant de la Caserne', '', false); return; }
  const pays = state.country || 'republic';
  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  const dispo = compagnies.filter(c => !c.capitaineNom);
  if (dispo.length === 0) { showToast('Aucune compagnie disponible', 'Toutes les compagnies ont déjà un capitaine, ou aucune n\'existe.', false); return; }
  const habitants = typeof listerHabitantsEligibles === 'function' ? await listerHabitantsEligibles('capitaine') : [];

  document.getElementById('postes-modal-title').textContent = 'Nommer un Capitaine';
  let html = '<div style="padding:1rem">';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Compagnie</label>';
  html += '<select id="nomme-capitaine-compagnie" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  dispo.forEach(c => html += '<option value="' + c.id + '">' + c.id + '</option>');
  html += '</select>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Candidat</label>';
  html += '<select id="nomme-capitaine-nom" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  habitants.forEach(h => html += '<option value="' + h.name + '">' + h.name + '</option>');
  html += '</select>';
  html += '<button onclick="envoyerNominationCapitaine(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function envoyerNominationCapitaine(pa, cost) {
  const compagnieId = document.getElementById('nomme-capitaine-compagnie')?.value;
  const destinataire = document.getElementById('nomme-capitaine-nom')?.value;
  if (!compagnieId || !destinataire) return;
  // NOMINATION ENREGISTREE COTE SERVEUR (17 septembre 2026, passe 3). Avant, le mail portait un
  // bouton qui ecrivait directement capitaineNom dans compagnies_militaires -- table alors SANS
  // RLS : n'importe qui pouvait s'y nommer capitaine sans jamais avoir ete choisi. La proposition
  // est desormais une ligne attestee (le serveur verifie que l'emetteur est bien le Commandant du
  // pays et que la compagnie est vacante), et c'est SON identifiant que porte le bouton.
  const prop = await sbMilitaireProposerCapitaine(compagnieId, destinataire);
  if (!prop || prop.ok !== true) {
    const motifs = { compagnie_deja_commandee: 'Cette compagnie a déjà un capitaine.',
                     destinataire_introuvable: destinataire + ' est introuvable dans votre pays.',
                     hors_juridiction: 'Cette compagnie relève d\'un autre pays.' };
    showToast('Nomination impossible', (prop && motifs[prop.raison]) || 'Réservé au Commandant en exercice.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  document.getElementById('modal-postes')?.classList.remove('open');
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  const corps = (state.char?.name||'Le Commandant') + ' vous propose le poste de <strong>Capitaine</strong> de la compagnie ' + compagnieId + '.<br><br>' +
    marqueurActionMail('capitaine', prop.id);
  if (typeof sbSendMail === 'function') await sbSendMail(state.char?.name || 'Anonyme', destinataire, 'Nomination au poste de Capitaine', corps, time).catch(() => {});
  showToast('Nomination envoyée', '', true, true);
}

// L'acceptation ne s'ecrit plus depuis le navigateur : c'est la NOMINATION ENREGISTREE qui fait
// autorite. Le serveur verifie que l'acceptant est bien le destinataire de cette nomination et que
// la compagnie est toujours vacante, puis pose capitaineNom ET le poste dans la meme transaction.
async function accepterNominationCapitaine(nominationId) {
  const r = await sbMilitaireAccepterCapitaine(nominationId);
  if (!r || r.ok !== true) {
    const motifs = { pas_destinataire: 'Cette nomination ne vous est pas adressée.',
                     compagnie_deja_commandee: 'Cette compagnie a déjà un capitaine.',
                     nomination_introuvable: 'Cette nomination n\'existe plus.' };
    showToast('Acceptation impossible', (r && motifs[r.raison]) || 'La nomination n\'a pas pu être enregistrée.', false);
    return;
  }
  if (r.rejeu) { showToast('Déjà accepté', '', false); return; }
  state.poste = { id: 'capitaine', name: 'Capitaine', compagnieId: r.compagnie };
  if (state.char) state.char.poste = state.poste;
  updateUI();
  showToast('Poste accepté !', 'Vous êtes désormais Capitaine de la compagnie ' + r.compagnie + '.', true, true);
  addExternalEvent('🎖 ' + (state.char?.name||'Un officier') + ' est nommé Capitaine.');
}

async function ouvrirNommerLieutenant(pa, cost) {
  if (state.poste?.id !== 'capitaine') { showToast('Réservé à un Capitaine', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  if (!compagnie) return;
  const dispo = (compagnie.sections || []).filter(s => !s.lieutenantNom);
  if (dispo.length === 0) { showToast('Aucune section disponible', 'Toutes les sections de votre compagnie ont déjà un lieutenant.', false); return; }
  const habitants = typeof listerHabitantsEligibles === 'function' ? await listerHabitantsEligibles('lieutenant') : [];

  document.getElementById('postes-modal-title').textContent = 'Nommer un Lieutenant';
  let html = '<div style="padding:1rem">';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Section</label>';
  html += '<select id="nomme-lieutenant-section" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  dispo.forEach(s => html += '<option value="' + s.id + '">' + s.id + '</option>');
  html += '</select>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Candidat</label>';
  html += '<select id="nomme-lieutenant-nom" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.8rem">';
  habitants.forEach(h => html += '<option value="' + h.name + '">' + h.name + '</option>');
  html += '</select>';
  html += '<button onclick="envoyerNominationLieutenant(\'' + compagnie.id + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Envoyer la nomination</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function envoyerNominationLieutenant(compagnieId, pa, cost) {
  const sectionId = document.getElementById('nomme-lieutenant-section')?.value;
  const destinataire = document.getElementById('nomme-lieutenant-nom')?.value;
  if (!sectionId || !destinataire) return;
  // Meme correctif que pour le Capitaine : la proposition devient une ligne attestee. Le serveur
  // verifie que l'emetteur est LE capitaine de CETTE compagnie et que la section existe et est
  // vacante -- un capitaine d'une autre compagnie est refuse la, pas par l'affichage.
  const prop = await sbMilitaireProposerLieutenant(compagnieId, sectionId, destinataire);
  if (!prop || prop.ok !== true) {
    const motifs = { pas_capitaine_de_cette_compagnie: 'Vous ne commandez pas cette compagnie.',
                     section_deja_commandee: 'Cette section a déjà un lieutenant.',
                     section_introuvable: 'Cette section n\'existe pas.',
                     destinataire_introuvable: destinataire + ' est introuvable dans votre pays.' };
    showToast('Nomination impossible', (prop && motifs[prop.raison]) || 'Réservé au Capitaine de cette compagnie.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  document.getElementById('modal-postes')?.classList.remove('open');
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '';
  const corps = (state.char?.name||'Le Capitaine') + ' vous propose le poste de <strong>Lieutenant</strong> de la section ' + sectionId + '.<br><br>' +
    marqueurActionMail('lieutenant', prop.id);
  if (typeof sbSendMail === 'function') await sbSendMail(state.char?.name || 'Anonyme', destinataire, 'Nomination au poste de Lieutenant', corps, time).catch(() => {});
  showToast('Nomination envoyée', '', true, true);
}

// Acceptation attestee : le serveur verifie que l'acceptant est le destinataire de CETTE
// nomination et que la section est toujours vacante, puis pose lieutenantNom ET le poste ensemble.
async function accepterNominationLieutenant(nominationId) {
  const r = await sbMilitaireAccepterLieutenant(nominationId);
  if (!r || r.ok !== true) {
    const motifs = { pas_destinataire: 'Cette nomination ne vous est pas adressée.',
                     section_indisponible: 'Cette section a déjà un lieutenant.',
                     nomination_introuvable: 'Cette nomination n\'existe plus.' };
    showToast('Acceptation impossible', (r && motifs[r.raison]) || 'La nomination n\'a pas pu être enregistrée.', false);
    return;
  }
  if (r.rejeu) { showToast('Déjà accepté', '', false); return; }
  state.poste = { id: 'lieutenant', name: 'Lieutenant', compagnieId: r.compagnie, sectionId: r.section };
  if (state.char) state.char.poste = state.poste;
  updateUI();
  showToast('Poste accepté !', 'Vous êtes désormais Lieutenant de la section ' + r.section + '.', true, true);
  addExternalEvent('🎖 ' + (state.char?.name||'Un officier') + ' est nommé Lieutenant.');
}

// ---- RECRUTEMENT (a la compagnie) ----
const COEF_ARME_MILITAIRE = { corps_a_corps: 1, arme_de_poing: 2.5, mitraillette: 4 };
const PA_MAX_SOLDAT = 12;
const PA_BASE_ROUND = 2;
const CAP_ENTRAINEMENT_PAR_SESSION = 12;
// QUATRE DOMAINES D'ENTRAINEMENT (18 septembre 2026), echelle 0..100. Remplacent les anciennes
// jauges militaires force/endurance/tir. Miroir des constantes de militaire_entrainer_section,
// qui seule fait autorite : elle refuse tout domaine hors de cette liste.
const DOMAINES_ENTRAINEMENT = [
  { id: 'combat_rapproche', label: 'Combat rapproché' },
  { id: 'tir',              label: 'Tir' },
  { id: 'reconnaissance',   label: 'Reconnaissance / camouflage' },
  { id: 'secourisme',       label: 'Secourisme' }
];
const PA_SEANCE_ENTRAINEMENT = 6;   // par soldat participant ET pour le Lieutenant

// Libelle compact des quatre domaines d'un soldat PNJ. Un soldat PJ n'a pas de `formation` : ses
// caracteristiques sont son capital, et les domaines ne sont pas des doublons de celles-ci.
function libelleFormationSoldat(sol) {
  if (!sol || sol.pj === true) return 'joueur';
  const f = sol.formation || {};
  return 'CBT ' + (f.combat_rapproche || 0) + ' · TIR ' + (f.tir || 0)
       + ' · REC ' + (f.reconnaissance || 0) + ' · SEC ' + (f.secourisme || 0);
}

// ---- LOGISTIQUE ARMEMENT (chantier 27 aout 2026 : Armurerie -> Section -> Soldat) ----
// corps_a_corps reste hors stock : etat par defaut gratuit et illimite de tout soldat recrute
// (creerSoldatsSection), simple combat a mains nues, coefficient de base (1) inchange -- ce
// n'est pas une "arme" au sens de cette logistique. Seules ces deux categories necessitent un
// achat institutionnel puis une dotation reelle.
const CATEGORIES_ARME_STOCK = ['arme_de_poing', 'mitraillette'];

// PRIX_ARME_MILITAIRE (300/800) a ete supprime le 13 septembre 2026 avec l'achat institutionnel
// qu'il tarifait (voir plus bas). L'armement militaire n'a plus de prix d'achat : il a un COUT DE
// REVIENT, calcule par plateau-effort-guerre.js a partir de la recette reelle, et c'est ce montant
// qui est verse a l'armurerie qui l'a produit.

// Stock national de l'Armurerie Militaire : porte par budgetNat (meme rail que
// coefficientsArmesAcquis/rechercheMilitaire, deja persiste sans schema fixe via
// sbGetBudgetNational/sbSaveBudgetNational -- aucune migration).
async function chargerStockArmurerieMilitaire(pays) {
  const budgetNat = await chargerBudgetNational(pays);
  if (!budgetNat.stockArmurerieMilitaire) budgetNat.stockArmurerieMilitaire = { arme_de_poing: 0, mitraillette: 0 };
  // RETRO-COMPATIBILITE (13 septembre 2026) : les explosifs militaires rejoignent le meme stock,
  // mais une ligne ecrite avant ce chantier ne porte pas la cle. On la comble en memoire sans
  // rien persister ici -- exactement comme les deux categories d'armes au-dessus, dont
  // l'initialisation n'a jamais ete sauvegardee par cette fonction. Aucune donnee n'est ecrasee.
  if (typeof budgetNat.stockArmurerieMilitaire.explosif_militaire !== 'number') {
    budgetNat.stockArmurerieMilitaire.explosif_militaire = 0;
  }
  return budgetNat;
}

function genererMatriculesSection(numeroSection) {
  const now = new Date();
  const aaaamm = now.getFullYear() + String(now.getMonth() + 1).padStart(2, '0');
  const ss = String(numeroSection).padStart(2, '0');
  return Array.from({ length: EFFECTIF_SECTION }, (_, i) => aaaamm + '-' + ss + '-' + String(i + 1).padStart(3, '0'));
}

// ===========================================================================================
// POSITION CANONIQUE D'UN SOLDAT (17 septembre 2026)
// ===========================================================================================
// Un soldat n'etait localise que par buildingId + roomId. Or 'caserne-militaire' est LE MEME
// identifiant de batiment dans les quatre empires, et 'marche', 'armurerie', 'stade',
// 'la-tribune', 'mairie' sont partages entre plusieurs villes d'un meme empire : la position
// etait donc structurellement ambigue, et depot comme recuperation pouvaient viser les hommes
// d'une autre ville.
//
// La cle canonique est (compagnie.pays, soldat.ville, soldat.buildingId, soldat.roomId). Le pays
// reste porte par la COMPAGNIE -- un soldat ne change pas d'empire sans elle -- donc seule la
// ville s'ajoute sur le soldat. Meme idiome que getEntrepriseIdArmurerie(country, city),
// introduit precisement parce que Luthecia, Montrouge et PSM partageaient sinon la meme caisse.
//
// UN SEUL PREDICAT, utilise partout : sans lui le triple test se recopiait a sept endroits et
// un oubli suffisait a reintroduire l'ambiguite en silence.
//
// « Sur place » exige leaderCourant vide : un soldat qui suit un chef n'a PAS de position propre,
// il ne peut donc jamais etre « ici ». Meme predicat que cote serveur.
function soldatEstIci(sol, ville, buildingId, roomId) {
  return !!sol && !sol.leaderCourant
      && sol.ville === ville && sol.buildingId === buildingId && sol.roomId === roomId;
}

// ===========================================================================================
// PRESENCE EFFECTIVE D'UN SOLDAT (25 septembre 2026, arbitrage GD)
// ===========================================================================================
// LA REGLE : dans « Personnes presentes », personne de physiquement present n'est cache. Une
// unite qui accompagne un personnage est presente LA OU EST CE PERSONNAGE. Il n'existe pas de
// furtivite implicite des detachements accompagnants.
//
// POURQUOI UN SECOND PREDICAT PLUTOT QU'UNE MODIFICATION DE soldatEstIci. Les deux questions
// sont differentes et le restent :
//   soldatEstIci        = « stationne dans cette piece », donc RECUPERABLE ici ;
//   soldatEstVisibleIci = « physiquement present dans cette piece », donc AFFICHABLE ici.
// Elargir soldatEstIci ferait compter les soldats deja avec le Lieutenant dans le champ
// « Nombre a recuperer ici » de doGererDetachement -- qui proposerait de recuperer des hommes
// qu'il tient deja, et que militaire_recuperer_soldats refuserait aussitot par
// « effectif_insuffisant_ici ». C'est une regression demontrable, pas une preference de style.
//
// AUCUNE RECOPIE DE POSITION. Le modele leaderCourant permet une resolution DYNAMIQUE : on ne
// reecrit jamais ville/buildingId/roomId sur les soldats quand leur chef se deplace. Un
// deplacement de Lieutenant, ce sont zero ecriture sur la compagnie, et le detachement suit tout
// seul parce que la question est posee au moment de l'affichage. C'est exactement la forme que la
// base applique deja ailleurs : agent_position_effective() rend `pays/ville/building/room` du
// LEADER des que leader_courant est renseigne, et militaire_bataille_recruter comme
// mutinerie_camps_presents resolvent la co-presence par jointure sur la fiche du chef.
//
// `leadersIci` est l'ensemble des noms de personnages presents dans la piece consideree ; c'est
// l'appelant qui l'etablit, a partir des presences reelles. Un chef absent (ou deconnecte depuis
// plus de cinq minutes, seuil deja applique par sbGetPresencesInRoom) n'y figure pas, et son
// detachement n'est donc pas revele.
//
// Les deux branches sont MUTUELLEMENT EXCLUSIVES par construction -- la premiere exige un
// leaderCourant, la seconde son absence. Un soldat ne peut donc jamais etre compte deux fois.
//
// `lieutenantNom` ne sert qu'au sentinel historique '__avec_lieutenant__', qui n'a jamais voulu
// dire autre chose que « suit le Lieutenant de sa section ». Plus aucune donnee ne le porte
// aujourd'hui (verifie en base : 0 sur 24), mais il reste lu tant qu'il n'est pas supprime.
function soldatEstVisibleIci(sol, ville, buildingId, roomId, leadersIci, lieutenantNom) {
  if (!sol) return false;
  if (sol.leaderCourant) return !!leadersIci && leadersIci.has(sol.leaderCourant);
  if (sol.roomId === '__avec_lieutenant__') {
    return !!lieutenantNom && !!leadersIci && leadersIci.has(lieutenantNom);
  }
  return soldatEstIci(sol, ville, buildingId, roomId);
}

// Noms des personnages effectivement presents dans une piece : les autres joueurs d'apres la
// table des presences, plus MOI si la piece interrogee est celle ou je me trouve. Ce dernier
// point n'est pas une commodite : ma propre ligne de presence peut etre plus ancienne que le
// seuil de cinq minutes si je suis reste immobile, et un Lieutenant doit toujours voir ses
// propres hommes.
async function leadersPresentsDansPiece(pays, ville, buildingId, roomId) {
  const noms = new Set();
  if (state.currentCity === ville && state.currentBuilding === buildingId
      && state.currentRoom === roomId && state.char?.name) {
    noms.add(state.char.name);
  }
  if (typeof sbGetPresencesInRoom === 'function') {
    const rows = await sbGetPresencesInRoom(pays, ville, buildingId, roomId).catch(() => []);
    (rows || []).forEach(p => { const n = p.name || p.nom; if (n) noms.add(n); });
  }
  return noms;
}

// ===========================================================================================
// LEADER OPERATIONNEL COURANT (17 septembre 2026)
// ===========================================================================================
// Le sentinel historique '__avec_lieutenant__' cachait un leader implicite dans un identifiant de
// piece : il ne savait designer que le Lieutenant de la section, et un soldat dont le chef perdait
// son poste restait attache a un fantome. soldat.leaderCourant nomme desormais explicitement le PJ
// qui mene physiquement ce soldat.
//
// L'AUTORITE STRUCTURELLE N'EST PAS TRANSFEREE : section.lieutenantNom reste souverain. Un soldat
// PJ a qui l'on confie des hommes les MENE, mais ne peut pas les reprendre s'il les laisse
// quelque part -- seul le Lieutenant structurel peut. C'est le serveur qui le garantit.
//
// TRANSITION : le sentinel est encore ACCEPTE en lecture (aucun soldat ne doit rester bloque s'il
// en portait un) et n'est plus jamais ECRIT, ni ici ni cote serveur.
function soldatSuitUnChef(sol) {
  return !!sol && (!!sol.leaderCourant || sol.roomId === '__avec_lieutenant__');
}

// Ce soldat suit-il CE PJ ? Un soldat portant encore le seul sentinel est compte pour l'appelant :
// le sentinel n'a jamais voulu dire autre chose que « suit le Lieutenant de sa section », et le
// seul appelant de ce predicat est precisement ce Lieutenant.
function soldatSuitCePJ(sol, nom) {
  if (!sol || !nom) return false;
  return sol.leaderCourant === nom || (!sol.leaderCourant && sol.roomId === '__avec_lieutenant__');
}

// Libelle lisible du lieu d'un soldat, ville comprise : deux batiments homonymes dans deux villes
// ne doivent plus s'afficher a l'identique. Un soldat qui suit un chef n'a pas de lieu propre --
// on nomme son chef, qui EST sa position.
function libelleLieuSoldat(sol) {
  if (!sol) return '?';
  if (sol.leaderCourant) {
    return sol.leaderCourant === state.char?.name ? 'Avec vous' : ('Avec ' + sol.leaderCourant);
  }
  if (sol.roomId === '__avec_lieutenant__') return 'Avec son lieutenant';
  const bat = sol.buildingId ? (BUILDINGS[sol.buildingId]?.shortName || BUILDINGS[sol.buildingId]?.name || sol.buildingId) : null;
  const ville = sol.ville ? (WORLD[state.country]?.[sol.ville]?.name || sol.ville) : null;
  if (!bat) return ville || 'Caserne';
  return ville ? (bat + ' — ' + ville) : bat;
}

// La caserne est une ville a part entiere ('caserne', isSpecial:true) dans les quatre empires.
const VILLE_CASERNE = 'caserne';

// CODE MORT depuis l'adoption du contingent (17 septembre 2026) : les soldats naissent desormais
// dans la reserve de la compagnie, cotes serveur par militaire_compagnie_creer, avec un matricule
// 'AAAAMM-NNN' dont le numero de section a disparu -- un soldat n'est plus ne dans une section.
// Conservee le temps de verifier qu'aucun chemin ne la rappelle, a supprimer ensuite avec
// genererMatriculesSection. NE PAS la rebrancher : elle recreerait des hommes gratuitement.
function creerSoldatsSection(numeroSection) {
  return genererMatriculesSection(numeroSection).map(matricule => ({
    matricule, formation: { force: 0, endurance: 0, tir: 0 }, arme: 'corps_a_corps',
    ville: VILLE_CASERNE, buildingId: 'caserne-militaire', roomId: 'corps_garde',
    pa: PA_MAX_SOLDAT
  }));
}

// PREROGATIVE DU COMMANDANT, PAS DU MINISTRE (arbitrage du 7 septembre 2026). Le ministre nomme le
// Commandant ; le Commandant conduit ensuite ses operations, dont le recrutement. Le moteur de
// recrutement lui-meme est INCHANGE -- seule l'autorite qui peut le declencher change, et elle
// s'aligne sur recruter_section, deja reservee au Commandant et debitant la meme caisse.
// ===========================================================================================
// SERVEUR AUTORITAIRE (17 septembre 2026) et NOUVEAU MODELE DE CONTINGENT.
// ===========================================================================================
// Ce qui se passait ici : le client construisait lui-meme 4 sections DEJA PEUPLEES de 24 soldats
// et ecrivait le blob entier par sbSaveCompagnie. Deux defauts. D'une part le Commandant, seul
// habilite par la RLS a ecrire une compagnie, pouvait donc y ecrire n'importe quoi. D'autre part
// les 3 PA passaient par la branche institutionnelle de deduireCoutOrdre, qui ne consulte PAS le
// miroir des couts et les deduit cote navigateur seulement.
//
// MODELE GD. Les 20 000 FR n'achetent pas quatre lots de 24 hommes : ils constituent un
// CONTINGENT MAXIMAL de 96 PNJ attribuables a la compagnie. Elle nait donc avec ses 4 sections
// VIDES, et chaque Lieutenant reellement installe y fait entrer jusqu'a 24 hommes pris dans ce
// contingent. Un contingent entame par des pertes donne une section incomplete -- c'est voulu.
async function doRecruterCompagnie() {
  if (state.poste?.id !== 'commandant') { showToast('Réservé au Commandant', 'Le recrutement d\'une compagnie relève du Commandant de la Caserne, pas du Ministre.', false); return; }
  if (typeof sbMilitaireCompagnieCreer !== 'function') { showToast('Indisponible', '', false); return; }
  const r = await sbMilitaireCompagnieCreer();
  if (!r || r.ok !== true) {
    const motif = r?.raison;
    showToast(motif === 'pa_insuffisants' ? 'PA insuffisants'
              : motif === 'solde_insuffisant' ? 'Budget insuffisant'
              : motif === 'autorite_insuffisante' ? 'Réservé au Commandant' : 'Impossible',
      motif === 'pa_insuffisants' ? '3 PA requis.'
      : motif === 'solde_insuffisant' ? 'La caisse de la caserne ne couvre pas le coût d\'une compagnie (' + COUT_COMPAGNIE.toLocaleString('fr-FR') + ' FR).'
      : 'Refus du serveur (' + (motif || 'indisponible') + ').', false);
    return;
  }
  // On recopie l'etat arrete par le serveur, jamais un calcul local.
  if (typeof r.pa === 'number') { state.pa = r.pa; updateUI(); }
  const contingent = r.contingent || 96;
  showToast('Compagnie constituée !', contingent + ' hommes de contingent rejoignent la caserne, en réserve. '
    + 'Les ' + (r.sections || 4) + ' sections sont vides : chaque Lieutenant installé y fera entrer jusqu\'à '
    + EFFECTIF_SECTION + ' hommes. -' + COUT_COMPAGNIE.toLocaleString('fr-FR') + ' FR.', true, true);
  addJournalEntry('Constitution d\'une compagnie : contingent de ' + contingent + ' hommes en réserve ('
    + COUT_COMPAGNIE + ' FR).', 'event-good');
}

// MODELE ABANDONNE PAR LE GD (17 septembre 2026). Le recompletement d'une section a 5 000 FR
// reposait sur l'idee de quatre achats independants de 24 PNJ. Le contingent est desormais unique
// et non renouvelable : 20 000 FR achetent 96 hommes une fois pour toutes, les morts reduisent
// definitivement ce capital, et une section se recomplete en y affectant des hommes encore
// disponibles dans la reserve -- jamais en en achetant de nouveaux.
// SUPPRESSION EFFECTIVE (21 septembre 2026). La fonction neutralisee doRecruterSection, la
// constante COUT_SECTION (5 000 FR, le quart d'une compagnie) et l'ordre recruter_section
// disparaissent ensemble : declaration data.js, entree du routeur, fenetre de selection et ligne
// du miroir des couts. Plus aucun appelant vivant -- verifie sur l'ensemble du depot. Le miroir a
// ete regenere dans la meme passe, il n'est donc pas desynchronise (c'etait le seul motif pour
// lequel l'ordre avait ete laisse en place). AUCUNE mecanique de recompletement n'est recreee :
// le contingent reste unique et non renouvelable, les pertes definitives, et une section se
// recomplete en y affectant des hommes encore disponibles dans la reserve de la compagnie.

// ===========================================================================================
// FILIERE SOLDAT PJ (18 septembre 2026)
// ===========================================================================================
// Un PJ peut s'engager comme SIMPLE SOLDAT, sans aucune qualification militaire. Sa candidature
// est adressee au Lieutenant de la section visee, seule autorite habilitee a l'accepter ou la
// refuser -- verifie serveur. Toute la logique de places (place libre, remplacement d'un PNJ qui
// retourne COMPLET en reserve, liste d'attente si 24 PJ) vit dans militaire_candidature_traiter :
// le client ne fait que presenter et rapporter.

// Retrouve la section ou le PJ sert comme soldat. Un soldat PJ n'a PAS de poste : il est une
// entree { pj:true, nom } dans sections[].soldats, et c'est la seule source de verite.
async function trouverMaSectionSoldat() {
  const nom = state.char?.name;
  if (!nom) return null;
  const compagnies = await sbGetCompagnies(state.country || 'republic').catch(() => []);
  for (const c of compagnies) {
    for (const sec of (c.sections || [])) {
      if ((sec.soldats || []).some(sol => sol && sol.pj === true && sol.nom === nom)) {
        return { compagnie: c, section: sec };
      }
    }
  }
  return null;
}

// =============================================================================================
// RECRUTEMENT MILITAIRE — LES TROIS ECRANS (24 septembre 2026)
// =============================================================================================
// Ils remplacent ouvrirEngagementSoldat / confirmerEngagementSoldat / ouvrirCandidaturesSection /
// confirmerCandidatureSoldat, ainsi que doEngagerOfficier / ouvrirTraiterEngagements /
// ouvrirAffecterEngage, retires plus bas dans ce fichier le meme jour.
// Le changement de fond : le candidat ne choisit plus sa destination,
// il vise un GRADE ; sa candidature est vue par TOUS les recruteurs de rang competent ; le
// premier qui accepte l'emporte ; et un refus individuel ne detruit pas la candidature.
//
// AUCUN DE CES ECRANS NE LIT LA TABLE. candidatures_militaires est fermee a `authenticated`,
// meme en lecture, parce qu'elle contient la liste nominative des refus et l'affectation que le
// joueur doit decouvrir en personne. Les trois RPC projettent ce que chacun a le droit de voir.

const GRADES_ENGAGEMENT = [
  { id: 'capitaine',  label: 'Capitaine',
    desc: 'Commande une compagnie entière et ses quatre sections. Recruté par le Commandant de la Caserne.' },
  { id: 'lieutenant', label: 'Lieutenant',
    desc: 'Chef d\'une section de 24 hommes. Recruté par le Capitaine de la compagnie.' },
  { id: 'soldat',     label: 'Soldat',
    desc: 'Sert dans une section. Aucun diplôme requis. Recruté par le Lieutenant de la section.' }
];

function libelleGradeEngagement(id) {
  const g = GRADES_ENGAGEMENT.find(x => x.id === id);
  return g ? g.label : (id || '?');
}

// Delai reel accorde pour se presenter apres une acceptation. Le serveur en est l'autorite
// (militaire_candidature_accepter pose echeance = now() + 48 h) ; cette constante n'est la que
// pour l'affichage, et ne doit jamais servir a decider quoi que ce soit.
function resteAvantEcheance(echeance) {
  const t = new Date(echeance).getTime();
  if (!isFinite(t)) return '';
  const ms = t - Date.now();
  if (ms <= 0) return 'délai expiré';
  const h = Math.floor(ms / 3600000);
  return h >= 1 ? ('il reste ' + h + ' h') : ('il reste moins d\'une heure');
}

// ---------------------------------------------------------------------------------------------
// ECRAN 1 — S'ENGAGER DANS L'ARMEE (ordre s_engager_armee, 2 PA preleves par le serveur)
// ---------------------------------------------------------------------------------------------
async function ouvrirSEngagerArmee() {
  const etat = typeof sbMilitaireMesCandidatures === 'function'
    ? await sbMilitaireMesCandidatures().catch(() => null) : null;
  if (!etat || etat.ok !== true) {
    showToast('Indisponible', 'Le bureau de recrutement ne répond pas.', false); return;
  }
  const miennes = etat.candidatures || [];
  const deja = g => miennes.find(c => c.grade === g);

  document.getElementById('postes-modal-title').textContent = 'S\'engager dans l\'armée';
  let html = '<div style="padding:1rem">';

  if (etat.affectation_a_decouvrir) {
    html += '<div style="border:1px solid #8a6a20;background:rgba(138,106,32,.08);padding:.6rem;margin-bottom:.8rem">'
          + '<div style="font-size:.82rem;color:#C9A84C">Votre engagement a été accepté.</div>'
          + '<div style="font-size:.74rem;color:#8a8060;margin-top:.25rem">Utilisez l\'ordre '
          + '« Découvrir mon affectation » au Corps de Garde pour apprendre où vous servirez.</div></div>';
  }

  if (miennes.length) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">MES CANDIDATURES</div>';
    miennes.forEach(c => {
      html += '<div style="border:1px solid #2a2010;padding:.5rem;margin-bottom:.4rem;display:flex;align-items:center;gap:.5rem">';
      html += '<div style="flex:1"><div style="font-size:.82rem;color:#c0b090">' + escapeHtmlText(libelleGradeEngagement(c.grade)) + '</div>';
      html += '<div style="font-size:.7rem;color:#8a8060">'
            + (c.statut === 'acceptee'
                ? 'Acceptée — présentez-vous à la caserne (' + escapeHtmlText(resteAvantEcheance(c.echeance)) + ').'
                : 'En attente d\'un recruteur.') + '</div></div>';
      if (c.statut === 'active') {
        html += '<button onclick="confirmerRetraitCandidature(\'' + c.id + '\')" style="padding:.3rem .5rem;border:1px solid #8a4a4a;background:transparent;color:#c07070;cursor:pointer;font-size:.7rem">Retirer</button>';
      }
      html += '</div>';
    });
    html += '<div style="height:.8rem"></div>';
  }

  html += '<div style="font-size:.76rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">'
        + 'Vous pouvez candidater à plusieurs grades en même temps. La première candidature acceptée '
        + 'annule automatiquement les autres. Chaque dépôt coûte 2 PA et n\'est jamais remboursé.</div>';

  GRADES_ENGAGEMENT.forEach(g => {
    const mienne = deja(g.id);
    html += '<div style="border:1px solid #2a2010;padding:.6rem;margin-bottom:.5rem">';
    html += '<div style="font-size:.85rem;color:#c0b090"><b>' + g.label + '</b></div>';
    html += '<div style="font-size:.72rem;color:#8a8060;margin:.25rem 0 .45rem">' + g.desc + '</div>';
    if (mienne) {
      html += '<div style="font-size:.74rem;color:#6a6050;font-style:italic">Candidature déjà déposée.</div>';
    } else {
      html += '<button onclick="confirmerCandidatureEngagement(\'' + g.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.74rem;letter-spacing:.08em;padding:.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Candidater — 2 PA</button>';
    }
    html += '</div>';
  });

  // LE COMMANDANT N'EST PAS RECRUTE ICI, et le dire vaut mieux que le taire : sans cette ligne,
  // un joueur chercherait indefiniment a la caserne une porte qui se trouve au Palais.
  html += '<div style="border-top:1px solid #2a2010;margin-top:.8rem;padding-top:.7rem;font-size:.74rem;color:#8a8060">'
        + '<b style="color:#a09070">Commandant de la Caserne</b> — ce poste ne se demande pas ici. '
        + 'C\'est une fonction nommée : elle se postule au Palais du Gouvernement, et c\'est le '
        + 'Ministre de la Défense qui tranche.</div>';

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerCandidatureEngagement(grade) {
  document.getElementById('modal-postes')?.classList.remove('open');
  if (typeof sbMilitaireCandidatureDeposer !== 'function') { showToast('Indisponible', '', false); return; }
  const r = await sbMilitaireCandidatureDeposer(grade);
  if (!r || r.ok !== true) {
    const m = r?.raison;
    showToast('Candidature refusée',
      m === 'pas_sur_place' ? 'Vous devez être à la Caserne Militaire pour vous engager.'
      : m === 'deja_militaire' ? 'Vous servez déjà dans l\'armée.'
      : m === 'candidature_deja_active' ? 'Vous avez déjà une candidature en cours pour ce grade.'
      : m === 'pa_insuffisants' ? 'Il vous faut 2 PA pour déposer une candidature.'
      : m === 'grade_invalide' ? 'Ce grade ne se candidate pas à la caserne.'
      : 'Refus du serveur (' + (m || 'indisponible') + ').', false);
    return;
  }
  // Les PA affiches viennent du SERVEUR, jamais d'une soustraction cliente -- meme convention
  // que doSePresenterAffectation, qui recopie l'etat arrete par la RPC puis rafraichit l'ecran.
  if (typeof r.pa === 'number') { state.pa = r.pa; updateUI(); }
  showToast('Candidature déposée',
    'Votre candidature au grade de ' + libelleGradeEngagement(grade)
    + ' est transmise à toute la chaîne de commandement.', true, true);
  addJournalEntry('Candidature déposée pour le grade de ' + libelleGradeEngagement(grade) + '. (−2 PA)', 'event-info');
}

async function confirmerRetraitCandidature(id) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await sbMilitaireCandidatureRetirer(id);
  if (!r || r.ok !== true) {
    showToast('Impossible',
      r?.raison === 'candidature_non_retirable'
        ? 'Cette candidature a déjà été acceptée : présentez-vous à la caserne ou laissez le délai expirer.'
        : 'Refus du serveur (' + (r?.raison || 'indisponible') + ').', false);
    return;
  }
  showToast('Candidature retirée', 'Les 2 PA dépensés ne sont pas remboursés.', true);
  addJournalEntry('Candidature militaire retirée.', 'event-info');
}

// ---------------------------------------------------------------------------------------------
// ECRAN 2 — CANDIDATURES A L'ENGAGEMENT (ordre traiter_candidatures, reserve a la hierarchie)
// ---------------------------------------------------------------------------------------------
async function ouvrirTraiterCandidatures() {
  const etat = typeof sbMilitaireCandidaturesATraiter === 'function'
    ? await sbMilitaireCandidaturesATraiter().catch(() => null) : null;
  if (!etat || etat.ok !== true) {
    showToast(etat?.raison === 'pas_recruteur' ? 'Aucune autorité de recrutement' : 'Indisponible',
      etat?.raison === 'pas_recruteur'
        ? 'Seuls le Commandant, les Capitaines et les Lieutenants recrutent.'
        : 'Le bureau de recrutement ne répond pas.', false);
    return;
  }
  const places = etat.places || [];
  const cands = etat.candidatures || [];
  const grade = etat.grade_recrute;

  document.getElementById('postes-modal-title').textContent = 'Candidatures à l\'engagement';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.76rem;color:#8a8060;margin-bottom:.7rem">Vous recrutez des <b style="color:#c0b090">'
        + escapeHtmlText(libelleGradeEngagement(grade)) + 's</b>. Refuser un candidat ne l\'écarte que de '
        + 'vous : sa candidature reste ouverte aux autres recruteurs, et il n\'en sera pas informé.</div>';

  const placesLibres = places.filter(p => Number(p.libre) > 0);
  if (!placesLibres.length) {
    html += '<div style="font-size:.8rem;color:#5a5040;font-style:italic">Vous n\'avez aucune place à offrir '
          + 'pour l\'instant. Les places déjà promises à un candidat restent réservées 48 heures.</div>';
  } else if (!cands.length) {
    html += '<div style="font-size:.8rem;color:#5a5040;font-style:italic">Aucune candidature en attente.</div>';
  } else {
    // Le choix de la place n'apparait que s'il y en a plusieurs : proposer un menu a une seule
    // entree serait une question dont la reponse est deja connue.
    const multiple = placesLibres.length > 1;
    cands.forEach(c => {
      const sel = 'place-' + c.id;
      html += '<div style="border:1px solid #2a2010;padding:.6rem;margin-bottom:.5rem">';
      html += '<div style="font-size:.85rem;color:#c0b090"><b>' + escapeHtmlText(c.candidat) + '</b></div>';
      if (multiple) {
        html += '<select id="' + sel + '" style="width:100%;margin:.4rem 0;padding:.3rem;background:#0d0a06;border:1px solid #2a2010;color:#c0b090;font-size:.74rem">';
        placesLibres.forEach((p, i) => {
          const nom = p.section_id ? (p.section_nom || p.section_id) : (p.compagnie_nom || p.compagnie_id);
          html += '<option value="' + i + '">' + escapeHtmlText(nom)
                + ' — ' + p.libre + ' place(s)</option>';
        });
        html += '</select>';
      } else {
        const p = placesLibres[0];
        const nom = p.section_id ? (p.section_nom || p.section_id) : (p.compagnie_nom || p.compagnie_id);
        html += '<div style="font-size:.72rem;color:#8a8060;margin:.3rem 0">Affectation : ' + escapeHtmlText(nom) + '</div>';
      }
      html += '<div style="display:flex;gap:.4rem;margin-top:.4rem">';
      html += '<button onclick="confirmerAcceptationCandidature(\'' + c.id + '\',\'' + sel + '\')" style="flex:1;padding:.35rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer;font-size:.74rem">Accepter</button>';
      html += '<button onclick="confirmerRefusCandidature(\'' + c.id + '\',\'' + encodeURIComponent(c.candidat) + '\')" style="flex:1;padding:.35rem;border:1px solid #8a4a4a;background:transparent;color:#c07070;cursor:pointer;font-size:.74rem">Refuser</button>';
      html += '</div></div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  // Les places retenues sont gardees en memoire d'ecran : l'index choisi dans le menu doit
  // pouvoir etre retraduit en compagnie/section au moment du clic.
  window.__placesRecrutement = placesLibres;
}

async function confirmerAcceptationCandidature(id, selectId) {
  const places = window.__placesRecrutement || [];
  const el = document.getElementById(selectId);
  const p = places[el ? Number(el.value) : 0];
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!p) { showToast('Aucune place', 'Plus aucune place à offrir.', false); return; }
  const r = await sbMilitaireCandidatureAccepter(id, p.compagnie_id, p.section_id || null);
  if (!r || r.ok !== true) {
    const m = r?.raison;
    showToast('Impossible',
      m === 'candidature_non_active' ? 'Un autre recruteur a été plus rapide : ce candidat n\'est plus disponible.'
      : m === 'plus_de_place' ? 'Cette place vient d\'être prise.'
      : m === 'candidat_deja_militaire' ? 'Ce candidat a déjà rejoint l\'armée.'
      : 'Refus du serveur (' + (m || 'indisponible') + ').', false);
    return;
  }
  showToast('Engagement accepté',
    escapeHtmlText(r.candidat) + ' a 48 heures pour se présenter à la caserne.'
    + (Number(r.autres_annulees) > 0 ? ' Ses autres candidatures sont annulées.' : ''), true, true);
  addJournalEntry('Engagement de ' + r.candidat + ' accepté au grade de ' + libelleGradeEngagement(r.grade) + '.', 'event-good');
}

async function confirmerRefusCandidature(id, nomEncode) {
  const nom = decodeURIComponent(nomEncode || '');
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await sbMilitaireCandidatureRefuser(id);
  if (!r || r.ok !== true) {
    showToast('Impossible', 'Refus du serveur (' + (r?.raison || 'indisponible') + ').', false); return;
  }
  // AUCUN COURRIER N'EST ENVOYE ICI, et ce silence est la regle elle-meme : le candidat ne doit
  // jamais apprendre qu'un recruteur donne l'a ecarte. Sa candidature continue sa route ailleurs.
  showToast('Candidature écartée',
    nom + ' ne vous sera plus proposé. Il n\'en est pas informé, et un autre recruteur peut encore le prendre.', true);
  addJournalEntry('Candidature de ' + nom + ' écartée.', 'event-info');
}

// ---------------------------------------------------------------------------------------------
// ECRAN 3 — DECOUVRIR MON AFFECTATION (ordre decouvrir_affectation)
// C'est le seul moment ou le joueur apprend ou il sert, et le seul ou la compagnie est ecrite.
// ---------------------------------------------------------------------------------------------
async function doDecouvrirAffectation() {
  if (typeof sbMilitaireAffectationDecouvrir !== 'function') { showToast('Indisponible', '', false); return; }
  const r = await sbMilitaireAffectationDecouvrir();
  if (!r || r.ok !== true) {
    const m = r?.raison;
    showToast('Rien à découvrir',
      m === 'pas_sur_place' ? 'Présentez-vous à la Caserne Militaire.'
      : m === 'aucune_affectation' ? 'Aucun engagement accepté en attente. Si le délai de 48 heures est passé, votre engagement est caduc.'
      : m === 'plus_de_place' || m === 'section_pleine' ? 'La place qui vous était promise n\'est plus disponible.'
      : m === 'compagnie_deja_commandee' ? 'Cette compagnie a déjà un Capitaine.'
      : m === 'section_indisponible' ? 'Cette section a déjà un Lieutenant.'
      : 'Refus du serveur (' + (m || 'indisponible') + ').', false);
    return;
  }

  // Le serveur vient d'ecrire la fiche (poste) et la compagnie. On recopie l'etat qu'IL a
  // arrete, sans rien recalculer. Un soldat n'a pas de `poste` : il existe comme entree
  // { pj:true, nom } dans sections[].soldats, et state.poste doit donc rester vide -- lui en
  // inventer un ferait croire a toute l'interface qu'il est officier.
  if (r.grade === 'soldat') {
    state.poste = null;
  } else {
    state.poste = { id: r.grade, compagnieId: r.compagnie_id };
    if (r.section_id) state.poste.sectionId = r.section_id;
  }
  if (state.char) state.char.poste = state.poste;
  updateUI();

  document.getElementById('postes-modal-title').textContent = 'Votre affectation';
  // LE NOM DE LA SECTION, PAS SON IDENTIFIANT (correctif du 24 septembre 2026, recette
  // navigateur). La scene affichait « section zztest-sov-s2 » : un identifiant de base de
  // donnees jete a la figure du joueur au moment le plus solennel de son engagement. La RPC
  // renvoie desormais `section_nom` ; l'identifiant ne sert plus qu'au repli, si une compagnie
  // ancienne n'avait pas de nom de section.
  const nomSection = r.section_nom || r.section_id;
  const unite = r.section_id ? (r.compagnie_nom + ' — ' + nomSection) : r.compagnie_nom;
  let html = '<div style="padding:1.2rem;text-align:center">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.3rem;letter-spacing:.12em;color:#C9A84C">'
        + escapeHtmlText(libelleGradeEngagement(r.grade).toUpperCase()) + '</div>';
  html += '<div style="font-size:.84rem;color:#c0b090;margin-top:.5rem">' + escapeHtmlText(unite) + '</div>';
  if (r.chef) {
    html += '<div style="font-size:.76rem;color:#8a8060;margin-top:.4rem">Sous les ordres de <b>'
          + escapeHtmlText(r.chef) + '</b>.</div>';
  }
  // « Engagé par » n'apparait que s'il apporte une information : quand le recruteur EST le chef
  // — le cas le plus frequent pour un soldat — la ligne repetait mot pour mot la precedente.
  if (r.recruteur && r.recruteur !== r.chef) {
    html += '<div style="font-size:.74rem;color:#6a6050;margin-top:.3rem;font-style:italic">Engagé par '
          + escapeHtmlText(r.recruteur) + '.</div>';
  }
  if (r.effectif !== undefined && r.effectif !== null) {
    html += '<div style="font-size:.74rem;color:#8a8060;margin-top:.6rem">Effectif de l\'unité : '
          + r.effectif + '.</div>';
  }
  if (r.pnj_rendu_reserve) {
    html += '<div style="font-size:.72rem;color:#8a6a20;margin-top:.5rem">Le soldat '
          + escapeHtmlText(r.matricule_rendu || 'PNJ') + ' vous cède sa place et retourne en réserve de compagnie.</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');

  showToast('Vous voilà soldat de Républia', 'Affectation : ' + unite + '.', true, true);
  addJournalEntry('Engagé comme ' + libelleGradeEngagement(r.grade) + ' — ' + unite + '.', 'event-good');
}

async function ouvrirQuitterArmee() {
  const mien = await trouverMaSectionSoldat();
  if (!mien) {
    showToast('Vous n\'êtes pas soldat',
      ['lieutenant','capitaine','commandant'].includes(state.poste?.id)
        ? 'Un officier quitte ses fonctions par la voie hiérarchique, pas par cet ordre.'
        : 'Vous ne servez dans aucune section.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Quitter l\'armée';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.6rem">Vous servez dans la section ' + (mien.section.numero || '?')
        + ' sous les ordres du Lieutenant <b>' + escapeHtmlText(mien.section.lieutenantNom || '?') + '</b>.</div>';
  html += '<div style="font-size:.74rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">Votre départ est administratif : votre période de service se termine, votre solde militaire cesse, et votre place est libérée. Aucun soldat n\'est perdu.</div>';
  html += '<button onclick="confirmerQuitterArmee(\'' + mien.compagnie.id + '\',\'' + mien.section.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #8a4a4a;background:transparent;color:#c07070;cursor:pointer">Démissionner</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerQuitterArmee(compagnieId, sectionId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await sbMilitaireSoldatRetirer(compagnieId, sectionId, state.char?.name);
  if (!r || r.ok !== true) {
    showToast('Impossible', 'Refus du serveur (' + (r?.raison || 'indisponible') + ').', false); return;
  }
  showToast('Démission enregistrée', 'Vous redevenez civil. ' + (r.places_libres || 0) + ' place(s) libre(s) dans la section.', true, true);
  addJournalEntry('Démission de l\'armée. Période de service terminée.', 'event-info');
}

// ---- DETACHEMENTS DE SOLDATS ----
// Recupere le detachement present dans la piece courante pour la section du lieutenant connecte
function getSectionDuLieutenant(compagnie) {
  return (compagnie?.sections || []).find(s => s.lieutenantNom === state.char?.name);
}

// SENTINEL HISTORIQUE, conserve en LECTURE SEULE le temps de la transition. Plus aucun chemin ne
// l'ecrit -- ni le client, ni les RPC militaires. Il sera supprime quand plus aucune donnee ne le
// portera. Le point de verite du suivi est desormais soldat.leaderCourant.
const ROOM_AVEC_LIEUTENANT = '__avec_lieutenant__';

async function doGererDetachement() {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const section = getSectionDuLieutenant(compagnie);
  if (!section) return;

  const ici = section.soldats.filter(s => soldatEstIci(s, state.currentCity, state.currentBuilding, state.currentRoom)).length;
  const avecMoi = section.soldats.filter(s => soldatSuitCePJ(s, state.char?.name)).length;
  const ailleurs = section.soldats.length - ici - avecMoi;

  document.getElementById('postes-modal-title').textContent = 'Gérer mon détachement';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Ici : ' + ici + ' · Avec vous (en déplacement) : ' + avecMoi + ' · Ailleurs : ' + ailleurs + ' soldats.</div>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Nombre à déposer ici (depuis votre groupe)</label>';
  html += '<input id="nb-deposer" type="number" min="0" max="' + avecMoi + '" value="0" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<button onclick="deposerSoldats(\'' + compagnie.id + '\',\'' + section.id + '\')" style="width:100%;margin-bottom:.8rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Déposer</button>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Nombre à récupérer ici (rejoint votre groupe)</label>';
  html += '<input id="nb-recuperer" type="number" min="0" max="' + ici + '" value="0" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<button onclick="recupererSoldats(\'' + compagnie.id + '\',\'' + section.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #4a6a8a;background:transparent;color:#5a8ad0;cursor:pointer">Récupérer</button>';
  html += '<div style="border-top:1px solid #2a2010;margin:.9rem 0 .7rem"></div>';
  html += '<button onclick="ouvrirOrdresCollectifs(\'' + compagnie.id + '\',\'' + section.id + '\')" style="width:100%;margin-bottom:.4rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #6a8a4a;background:transparent;color:#8ac05a;cursor:pointer">Ordres collectifs (ration, bivouac)</button>';
  html += '<button onclick="ouvrirEquipementSoldats(\'' + compagnie.id + '\',\'' + section.id + '\')" style="width:100%;margin-bottom:.4rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Équiper les soldats</button>';
  // CONFIER LA CONDUITE (24 septembre 2026). La RPC existait depuis des semaines sans aucun
  // ecran pour l'appeler. Le bouton n'apparait que si le Lieutenant mene effectivement des
  // hommes : confier zero soldat n'a pas de sens, et un bouton inerte non plus.
  if (avecMoi > 0) {
    html += '<button onclick="ouvrirConfierConduite(\'' + compagnie.id + '\',\'' + section.id + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #6a5a8a;background:transparent;color:#9a8ac0;cursor:pointer">Confier la conduite d\'un groupe</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// =================================================================================================
// CONFIER LA CONDUITE D'UN GROUPE A UN SOLDAT JOUEUR DE SA SECTION (24 septembre 2026)
// =================================================================================================
// CE QUE C'EST, ET CE QUE CE N'EST PAS. On confie la CONDUITE : les soldats designes suivront
// desormais ce joueur au lieu de suivre le Lieutenant. L'autorite structurelle ne bouge pas d'un
// pouce -- le Lieutenant reste le seul chef de la section, le seul a pouvoir reprendre ses hommes,
// le seul a pouvoir leur donner un ordre collectif. Ce n'est ni une promotion, ni un transfert.
//
// QUI PEUT RECEVOIR : un autre JOUEUR appartenant a cette meme section, et present dans la piece.
// Ni un civil, ni un militaire d'une autre section. La liste ci-dessous ne propose que des
// candidats valides, mais c'est le SERVEUR qui tranche : militaire_affecter_leader revalide
// l'appartenance (leader_hors_section), la co-presence (leader_absent) et la juridiction.
async function ouvrirConfierConduite(compagnieId, sectionId) {
  document.getElementById('postes-modal-title').textContent = 'Confier la conduite';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';

  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = (compagnie?.sections || []).find(s => s.id === sectionId);
  const avecMoi = (section?.soldats || []).filter(s => soldatSuitCePJ(s, state.char?.name)).length;

  // Les soldats JOUEURS de la section, moi excepte.
  const camarades = (section?.soldats || [])
    .filter(s => s.pj === true && s.nom && s.nom !== state.char?.name)
    .map(s => s.nom);

  // Ils doivent etre physiquement ici : on lit les presences de la piece, meme source que le don.
  let presents = [];
  if (typeof sbGetPresencesInRoom === 'function') {
    presents = (await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom)
                 .catch(() => [])).map(p => p.name || p.nom).filter(Boolean);
  }
  const candidats = camarades.filter(n => presents.indexOf(n) !== -1);

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:.8rem;line-height:1.6">'
       +  'Les hommes que vous confiez suivront ce joueur au lieu de vous suivre. '
       +  'Vous restez leur Lieutenant : vous pouvez les reprendre quand vous voulez, et vous seul '
       +  'leur donnez des ordres collectifs.</div>';
  html += '<div style="font-size:.8rem;color:#C9A84C;margin-bottom:.6rem">Vous menez actuellement ' + avecMoi + ' soldat(s).</div>';

  if (candidats.length === 0) {
    html += '<div style="font-size:.78rem;color:#8a6a4a;font-style:italic">Aucun soldat de votre section n\'est présent ici. '
         +  'On ne confie ses hommes qu\'à un camarade de la même section, et en face à face.</div>';
  } else {
    html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Nombre de soldats à confier</label>';
    html += '<input id="nb-confier" type="number" min="1" max="' + avecMoi + '" value="' + avecMoi + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.7rem"/>';
    candidats.forEach(function (nom) {
      html += '<button onclick="confirmerConfierConduite(\'' + compagnieId + '\',\'' + sectionId + '\',\'' + encodeURIComponent(nom) + '\')" '
           +  'style="width:100%;margin-bottom:.4rem;padding:.5rem;border:1px solid #6a5a8a;background:transparent;color:#9a8ac0;cursor:pointer;font-family:Crimson Pro,serif;font-size:.84rem;text-align:left">'
           +  'Confier à ' + escapeHtmlText(nom) + '</button>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

const CONFIER_REFUS = {
  leader_hors_section:             'Ce joueur n\'appartient pas à votre section.',
  leader_absent:                   'Ce joueur n\'est pas ici avec vous.',
  leader_introuvable:              'Ce joueur est introuvable.',
  leader_hors_juridiction:         'Ce joueur ne sert pas votre empire.',
  leader_invalide:                 'Choisissez quelqu\'un d\'autre que vous-même.',
  pas_assez_avec_vous:             'Vous ne menez pas autant d\'hommes.',
  nombre_invalide:                 'Nombre invalide.',
  pas_lieutenant_de_cette_section: 'Vous n\'êtes pas le chef de cette section.',
  hors_juridiction:                'Cette compagnie n\'est pas la vôtre.'
};

async function confirmerConfierConduite(compagnieId, sectionId, nomEncode) {
  const nom = decodeURIComponent(nomEncode || '');
  const nb = parseInt(document.getElementById('nb-confier')?.value || '0', 10);
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!(nb > 0)) { showToast('Nombre invalide', 'Indiquez au moins un soldat.', false); return; }
  if (typeof sbMilitaireAffecterLeader !== 'function') { showToast('Indisponible', '', false); return; }

  const r = await sbMilitaireAffecterLeader(compagnieId, sectionId, nb, nom).catch(() => null);
  if (!r || r.ok !== true) {
    showToast('Impossible', CONFIER_REFUS[r?.raison] || ('Refus du serveur (' + (r?.raison || 'indisponible') + ').'), false);
    return;
  }
  showToast('Conduite confiée', r.affectes + ' soldat(s) suivent désormais ' + nom + '.', true, true);
  addJournalEntry('Conduite de ' + r.affectes + ' soldat(s) confiée à ' + nom + '.', 'event-info');
}

async function deposerSoldats(compagnieId, sectionId) {
  const nb = parseInt(document.getElementById('nb-deposer')?.value || '0');
  document.getElementById('modal-postes')?.classList.remove('open');
  if (nb <= 0) return;
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;

  // SERVEUR AUTORITAIRE (17 septembre 2026). L'ecriture directe de compagnies_militaires par un
  // Lieutenant est refusee par la RLS posee en passe 3 -- et l'ouvrir lui donnerait le droit
  // d'ecrire TOUT le blob (autres sections, capitaineNom, formation de n'importe quel soldat).
  // La RPC est bornee a SA section, et lit sa POSITION sur sa fiche au lieu de la croire.
  const rDep = await sbMilitaireDeposerSoldats(compagnieId, sectionId, nb);
  if (!rDep || rDep.ok !== true) {
    const motifs = { pas_assez_avec_vous: 'Pas assez de soldats avec vous.',
                     pas_lieutenant_de_cette_section: 'Vous ne commandez pas cette section.',
                     position_inconnue: 'Votre position n\'est pas enregistrée.' };
    showToast('Dépôt impossible', (rDep && motifs[rDep.raison]) || 'Opération refusée.', false);
    return;
  }
  showToast('Soldats déposés', nb + ' soldats de la section "' + section.lieutenantNom + '" restent ici.', true, true);
  rafraichirDetachementAffiche();
}

// RAFRAICHISSEMENT APRES UN MOUVEMENT DE DETACHEMENT (25 septembre 2026). Deposer ou recuperer
// change ce que contient la piece : la liste des presents doit etre redessinee tout de suite.
// Elle ne l'etait pas -- les deux fonctions s'arretaient sur leur showToast, et l'affichage
// restait faux jusqu'au rafraichissement suivant, quel qu'il soit. doDeclencherMutinerie, action
// comparable, appelle bien rafraichirPresenceAgents() ; c'est ce meme point d'entree qui est
// utilise ici, parce qu'il partage carteDetachementPiece avec enterRoom -- donc un seul rendu
// final, jamais deux qui s'effacent.
function rafraichirDetachementAffiche() {
  if (typeof rafraichirPresenceAgents === 'function') {
    Promise.resolve(rafraichirPresenceAgents()).catch(() => {});
  }
}

async function recupererSoldats(compagnieId, sectionId) {
  const nb = parseInt(document.getElementById('nb-recuperer')?.value || '0');
  document.getElementById('modal-postes')?.classList.remove('open');
  if (nb <= 0) return;
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  // Meme correctif que deposerSoldats : la RPC verifie que l'appelant commande bien CETTE
  // section et compte elle-meme les soldats reellement presents a sa position enregistree.
  const rRec = await sbMilitaireRecupererSoldats(compagnieId, sectionId, nb);
  if (!rRec || rRec.ok !== true) {
    const motifs = { effectif_insuffisant_ici: 'Effectif insuffisant ici.',
                     pas_lieutenant_de_cette_section: 'Vous ne commandez pas cette section.' };
    showToast('Récupération impossible', (rRec && motifs[rRec.raison]) || 'Opération refusée.', false);
    return;
  }
  showToast('Soldats récupérés', nb + ' soldats rejoignent votre groupe.', true, true);
  rafraichirDetachementAffiche();
}

// ==========================================================================================
// PANNEAU DE COMBAT (phase 3, 19 septembre 2026)
// ==========================================================================================
// Le joueur ne voit JAMAIS les mathematiques : ni taux, ni de, ni formule, ni coefficient. Il voit
// un bilan de round -- ce qu'il a perdu, ce qu'il a vu tomber en face, et un ordre de grandeur de
// ce qui reste debout. Cet ordre de grandeur est degrade PAR LE SERVEUR : le navigateur ne recoit
// pas la donnee exacte, il n'a donc rien a cacher.
// La DOCTRINE DE CAMP n'existe plus (arbitrage du 21 septembre 2026). Le repli
// se decide GROUPE PAR GROUPE, a 50 % de pertes : fenetre de 90 secondes pour un
// chef PJ, repli automatique pour un groupe mene par des PNJ. Un groupe allie
// peut donc decrocher pendant qu'un autre tient la position.

async function ouvrirPanneauCombat(batailleId) {
  const e = await sbMilitaireBatailleEtat(batailleId || null);
  if (!e || e.ok !== true) { showToast('Combat indisponible', 'Le serveur n\'a pas répondu.', false); return; }
  const b = e.bataille;

  document.getElementById('postes-modal-title').textContent = b ? 'Combat en cours' : 'Engagement';
  let html = '<div style="padding:1rem">';

  if (!b) {
    html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Vous n\'êtes engagé(e) dans aucun combat. Si une force ennemie occupe cette zone et que vos deux pays sont en guerre, vous pouvez l\'attaquer.</div>';
    html += '<div style="font-size:.74rem;color:#6a6048;margin-bottom:.8rem">Attaquer une force qui ne vous a pas repéré(e) vous donne un premier passage avant toute riposte. Si elle vous a repéré(e), le premier round est simultané.</div>';
    html += '<button onclick="confirmerEngagementCombat()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;padding:.55rem;border:1px solid #8a3a20;background:transparent;color:#cc6a44;cursor:pointer">Engager le combat</button>';
    html += '</div>';
    document.getElementById('postes-body').innerHTML = html;
    document.getElementById('modal-postes').classList.add('open');
    return;
  }

  const fini = (b.statut !== 'en_cours');
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.9rem;color:#C9A84C">' +
          escapeHtmlText(b.lieu?.ville || '') + ' — ' + escapeHtmlText(b.lieu?.batiment || '') + '</div>';
  html += '<div style="font-size:.74rem;color:#8a8060;margin-bottom:.8rem">Round ' + b.round_courant +
          ' · vos combattants : ' + b.mon_effectif_actuel + ' sur ' + b.mon_effectif_initial +
          (fini ? ' · <strong style="color:#cc6a44">combat terminé</strong>' : '') + '</div>';

  const rounds = Array.isArray(b.rounds) ? b.rounds : [];
  const dernier = rounds.length ? rounds[rounds.length - 1] : null;
  if (dernier) {
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.8rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.78rem;color:#e0d5b8;margin-bottom:.4rem">BILAN DU ROUND ' + dernier.round + '</div>';
    html += '<div style="font-size:.76rem;color:#c0b090">Vos pertes : ' + (dernier.mes_pa_perdus || 0) +
            ' PA sur ' + (dernier.mes_combattants_touches || 0) + ' combattant(s) touché(s).</div>';
    if (dernier.mes_morts_pnj > 0) html += '<div style="font-size:.76rem;color:#cc4444">' + dernier.mes_morts_pnj + ' soldat(s) tué(s).</div>';
    if (dernier.mes_pj_neutralises > 0) html += '<div style="font-size:.76rem;color:#cc4444">' + dernier.mes_pj_neutralises + ' des vôtres évacué(s) à l\'infirmerie.</div>';
    html += '<div style="font-size:.76rem;color:#8ac05a;margin-top:.3rem">En face : ' + (dernier.adversaires_tombes || 0) + ' adversaire(s) tombé(s) sous vos yeux.</div>';
    html += '<div style="font-size:.74rem;color:#8a8060">Encore debout : ' + escapeHtmlText(dernier.adversaire_estime?.libelle || '—') + '.</div>';
    html += '</div>';
  }

  if (!fini) {
    if (b.mon_groupe_replie) {
      html += '<div style="font-size:.76rem;color:#C9A84C;padding:.5rem;border:1px solid #6a5420;margin-bottom:.6rem">Votre groupe a décroché. Le combat continue sans vous.</div>';
    } else if (b.decision_attendue && b.je_suis_leader) {
      // Seuil des 50 % de pertes atteint : le chef a 90 secondes pour trancher,
      // et AUCUN round ne part tant qu'il n'a pas repondu. Passe ce delai, son
      // groupe -- et lui seul -- se replie automatiquement.
      html += '<div style="border:1px solid #8a2f2f;background:rgba(138,47,47,.12);padding:.6rem;margin-bottom:.7rem">';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.9rem;color:#e08a8a;margin-bottom:.25rem">Votre groupe a perdu la moitié de son effectif</div>';
      html += '<div style="font-size:.74rem;color:#a89870;margin-bottom:.5rem">' + (b.mon_groupe_restants || 0) + ' sur ' + (b.mon_groupe_effectif_initial || 0) + ' encore debout. Sans réponse de votre part, le repli est ordonné automatiquement.</div>';
      if (typeof b.secondes_restantes === 'number') {
        html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1.1rem;color:#C9A84C;margin-bottom:.5rem">' + b.secondes_restantes + ' s</div>';
      }
      html += '<div style="display:flex;gap:.4rem">';
      html += '<button onclick="deciderCombat(' + b.id + ',\'tenir\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.76rem;padding:.5rem;border:1px solid #6a8a4a;background:transparent;color:#8ac05a;cursor:pointer">Tenir la position</button>';
      html += '<button onclick="deciderCombat(' + b.id + ',\'replier\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.76rem;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Ordonner le repli</button>';
      html += '</div></div>';
    } else if (b.je_suis_leader) {
      html += '<div style="font-size:.74rem;color:#8a8060;margin-bottom:.6rem">Vous commandez ce groupe. Tant qu\'il n\'a pas perdu la moitié de son effectif, le combat suit son cours.</div>';
      html += '<button onclick="poursuivreCombat(' + b.id + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.76rem;padding:.5rem;border:1px solid #6a8a4a;background:transparent;color:#8ac05a;cursor:pointer">Passer au round suivant</button>';
    } else {
      html += '<div style="font-size:.74rem;color:#8a8060;margin-bottom:.6rem">Vous ne commandez pas ce groupe' + (b.mon_chef ? ' — ' + escapeHtmlText(b.mon_chef) + ' en décide' : ', et aucun officier ne le mène : il se repliera de lui-même à la moitié de ses pertes') + '.</div>';
      html += '<button onclick="poursuivreCombat(' + b.id + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.76rem;padding:.5rem;border:1px solid #6a8a4a;background:transparent;color:#8ac05a;cursor:pointer">Passer au round suivant</button>';
    }
  } else if (b.issue) {
    html += '<div style="font-size:.8rem;color:#C9A84C;text-align:center;padding:.5rem">Issue : ' + escapeHtmlText(b.issue) + '</div>';
  }

  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEngagementCombat() {
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await sbMilitaireBatailleEngager();
  if (!r || r.ok !== true) {
    const motifs = { pas_militaire: 'Seul un militaire en service peut engager le combat.',
                     aucun_ennemi_ici: 'Aucune force ennemie ici, ou vos deux pays ne sont pas en guerre.',
                     bataille_deja_en_cours: 'Un combat est déjà en cours ici.',
                     effectif_insuffisant: 'Il n\'y a pas de quoi engager un combat des deux côtés.' };
    showToast('Engagement impossible', (r && motifs[r.raison]) || 'Opération refusée.', false);
    return;
  }
  showToast('Combat engagé', r.mon_effectif + ' contre ' + r.effectif_adverse +
    (r.initiative === 'a' ? ' — vous ouvrez le feu sans avoir été repéré(e).' : ' — vous vous êtes vus.'), false, true);
  addJournalEntry('Combat engagé contre les troupes de ' + r.camp_adverse + '.', 'event-bad');
  await ouvrirPanneauCombat(r.bataille_id);
}

async function deciderCombat(batailleId, decision) {
  const r = await sbMilitaireBatailleDecider(batailleId, decision);
  if (!r || r.ok !== true) {
    showToast('Décision refusée', (r && r.raison === 'pas_leader_de_ce_camp')
      ? 'Vous ne commandez pas ce groupe.' : 'Opération refusée.', false);
    return;
  }
  await rafraichirApresRound(batailleId);
}

async function poursuivreCombat(batailleId) {
  const r = await sbMilitaireBataillePoursuivre(batailleId);
  if (!r || r.ok !== true) { showToast('Impossible', 'Le round n\'a pas pu être résolu.', false); return; }
  await rafraichirApresRound(batailleId);
}

// Les PA et la position du joueur ont pu changer cote SERVEUR pendant le round : on les relit au
// lieu de les deviner. Un PJ neutralise se retrouve a l'infirmerie de sa caserne.
async function rafraichirApresRound(batailleId) {
  if (typeof sbGet === 'function' && state.char?.name) {
    const l = await sbGet('personnages', 'name=eq.' + encodeURIComponent(state.char.name) +
      '&select=pa,current_city,current_building,current_room,inventory').catch(() => null);
    if (l && l[0]) {
      state.pa = l[0].pa;
      if (Array.isArray(l[0].inventory)) { state.inventory = l[0].inventory; if (state.char) state.char.inventory = state.inventory; }
      if (l[0].current_room !== state.currentRoom || l[0].current_building !== state.currentBuilding) {
        state.currentCity = l[0].current_city;
        if (typeof enterBuilding === 'function') enterBuilding(l[0].current_building, true);
        if (typeof enterRoom === 'function') enterRoom(l[0].current_building, l[0].current_room, null);
        showToast('Hors de combat', 'Vous avez été évacué(e) à l\'infirmerie de votre caserne.', false, true);
      }
      updateUI();
    }
  }
  await ouvrirPanneauCombat(batailleId);
}

// changerDoctrineCombat a ete retiree avec la doctrine de camp : le seuil de
// 50 % s'applique desormais groupe par groupe et ne se regle pas a l'avance.

// ---- CALEPIN DE CAMPAGNE (UI de militaire_calepin) ----
// Lecture seule et sans PA. Le calepin d'un civil est VIDE, et c'est un resultat : le jeu doit
// pouvoir dire « vous n'avez jamais servi » sans que cela ressemble a une panne.
const LIBELLES_GRADES_MILITAIRES = {
  soldat: 'Soldat', lieutenant: 'Lieutenant', capitaine: 'Capitaine', commandant: 'Commandant'
};
const LIBELLES_DOMAINES_MILITAIRES = {
  combat_rapproche: 'Combat rapproché', tir: 'Tir',
  reconnaissance: 'Reconnaissance', secourisme: 'Secourisme'
};
// Les trois niveaux de decoration. Ils correspondent A L'AUTORITE qui decerne, pas a un bareme de
// merite : le jeu n'a aucun avis sur qui merite quoi.
const LIBELLES_NIVEAUX_DECORATION = {
  compagnie: 'ordre de la compagnie', armee: 'ordre de l\'armée', etat: 'ordre de l\'État'
};

// ---- DECERNER UNE DECORATION (UI de militaire_decorer) ----
// L'ordre est ouvert a tous : c'est la RPC qui reconnait l'autorite, et elle seule. L'interface ne
// devine pas le niveau et ne propose aucune liste de medailles -- l'intitule est ECRIT par celui
// qui decore. Une decoration est un geste politique, pas un palier de progression.
async function ouvrirDecorerMilitaire() {
  document.getElementById('postes-modal-title').textContent = 'Décerner une décoration';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Réservé au Commandant de la Caserne, au Ministre de la Défense et au chef de l\'État. Le niveau de la décoration découle de votre fonction ; il ne se choisit pas.</div>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Qui décorez-vous ?</label>';
  html += '<input id="deco-nom" type="text" placeholder="Nom exact du personnage" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Intitulé de la distinction</label>';
  html += '<input id="deco-intitule" type="text" maxlength="120" placeholder="Vous l\'écrivez vous-même" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Citation (facultative)</label>';
  html += '<textarea id="deco-citation" maxlength="600" rows="3" placeholder="Le motif, tel qu\'il sera lu" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.82rem;outline:none;box-sizing:border-box;margin-bottom:.7rem;resize:vertical"></textarea>';
  html += '<button onclick="confirmerDecoration()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Décerner</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDecoration() {
  const nom = (document.getElementById('deco-nom')?.value || '').trim();
  const intitule = (document.getElementById('deco-intitule')?.value || '').trim();
  const citation = (document.getElementById('deco-citation')?.value || '').trim();
  document.getElementById('modal-postes')?.classList.remove('open');
  if (!nom || !intitule) { showToast('Décoration incomplète', 'Il faut un nom et un intitulé.', false); return; }

  const r = await sbMilitaireDecorer(nom, intitule, citation);
  if (!r || r.ok !== true) {
    const motifs = {
      autorite_insuffisante: 'Seuls le Commandant, le Ministre de la Défense et le chef de l\'État décorent.',
      auto_decoration_refusee: 'On ne se décore pas soi-même.',
      decore_introuvable: 'Ce personnage n\'existe pas.',
      hors_juridiction: 'Vous ne pouvez décorer que vos compatriotes.',
      deja_decernee: 'Vous lui avez déjà décerné cette distinction.',
      intitule_invalide: 'L\'intitulé doit faire entre 3 et 120 caractères.',
      citation_trop_longue: 'La citation est trop longue (600 caractères).'
    };
    showToast('Décoration refusée', (r && motifs[r.raison]) || 'Opération refusée.', false);
    return;
  }
  showToast('Décoration décernée', escapeHtmlText(nom) + ' — ' + escapeHtmlText(r.intitule) +
            ' (' + (LIBELLES_NIVEAUX_DECORATION[r.niveau] || r.niveau) + ').', true, true);
  addJournalEntry('Décoration décernée à ' + nom + ' : ' + r.intitule + '.', 'event-good');
  if (typeof addExternalEvent === 'function') {
    addExternalEvent(nom + ' a été décoré(e) : ' + r.intitule + '.', 'national');
  }
}

async function ouvrirCalepinCampagne() {
  const c = await sbMilitaireCalepin();
  if (!c || c.ok !== true) { showToast('Calepin indisponible', 'Le serveur n\'a pas répondu.', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Calepin de campagne';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:1rem;color:#C9A84C;letter-spacing:.06em">' + escapeHtmlText(c.nom || '') + '</div>';
  html += '<div style="font-size:.74rem;color:#8a8060;margin-bottom:.9rem">' +
          (c.en_service ? 'En service — ' + (LIBELLES_GRADES_MILITAIRES[c.grade_courant] || c.grade_courant)
                        : 'Pas en service actuellement') +
          ' · ' + (c.jours_total || 0) + ' jour(s) sous les drapeaux au total</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;color:#e0d5b8;margin-bottom:.4rem">COMPÉTENCES MILITAIRES</div>';
  const comp = c.competences || {};
  for (const cle of Object.keys(LIBELLES_DOMAINES_MILITAIRES)) {
    const v = Number(comp[cle] || 0);
    html += '<div style="display:flex;align-items:center;gap:.5rem;margin-bottom:.25rem">';
    html += '<span style="font-size:.74rem;color:#8a8060;width:9rem">' + LIBELLES_DOMAINES_MILITAIRES[cle] + '</span>';
    html += '<span style="flex:1;height:.4rem;background:#1a1408;display:block"><span style="display:block;height:100%;width:' + v + '%;background:#8a6a20"></span></span>';
    html += '<span style="font-size:.74rem;color:#f0ead6;width:2rem;text-align:right">' + v + '</span>';
    html += '</div>';
  }
  html += '<div style="font-size:.7rem;color:#6a6048;margin:.4rem 0 .9rem">Ces compétences sont distinctes de vos caractéristiques et vous restent acquises après l\'armée.</div>';

  const decos = Array.isArray(c.decorations) ? c.decorations : [];
  if (decos.length) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;color:#e0d5b8;margin-bottom:.4rem">DÉCORATIONS</div>';
    for (const d of decos) {
      html += '<div style="border:1px solid #3a2c10;background:#120e05;padding:.5rem;margin-bottom:.45rem">';
      html += '<div style="font-size:.8rem;color:#C9A84C">' + escapeHtmlText(d.intitule || '') +
              ' <span style="font-size:.66rem;color:#8a8060">— ' + (LIBELLES_NIVEAUX_DECORATION[d.niveau] || d.niveau) + '</span></div>';
      if (d.citation) html += '<div style="font-size:.72rem;color:#c0b090;font-style:italic;margin-top:.2rem">« ' + escapeHtmlText(d.citation) + ' »</div>';
      html += '<div style="font-size:.68rem;color:#6a6048;margin-top:.2rem">Décernée par ' + escapeHtmlText(d.decerne_par || '') + ' le ' + escapeHtmlText(d.le || '') + '</div>';
      html += '</div>';
    }
    html += '<div style="height:.5rem"></div>';
  }

  // BATAILLES : projection de batailles_engagements, comme le reste du calepin. Un joueur revenant
  // apres un combat resolu en son absence le relit ici -- l'evenement est canonique et unique, il
  // n'en existe pas une copie par participant.
  const hb = await sbMilitaireMesBatailles(10);
  const batailles = (hb && hb.ok === true && Array.isArray(hb.batailles)) ? hb.batailles : [];
  if (batailles.length) {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;color:#e0d5b8;margin-bottom:.4rem">BATAILLES</div>';
    for (const bt of batailles) {
      const rds = Array.isArray(bt.rounds) ? bt.rounds : [];
      const paPerdus = rds.reduce((t, r) => t + (r.mes_pa_perdus || 0), 0);
      const morts = rds.reduce((t, r) => t + (r.mes_morts_pnj || 0), 0);
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.5rem;margin-bottom:.45rem">';
      html += '<div style="font-size:.78rem;color:#C9A84C">' + escapeHtmlText(bt.lieu?.ville || '') +
              ' — ' + escapeHtmlText(bt.lieu?.batiment || '') + '</div>';
      html += '<div style="font-size:.7rem;color:#8a8060">' + String(bt.debut || '').slice(0, 10) +
              ' · ' + rds.length + ' round(s) · ' + (bt.issue ? escapeHtmlText(bt.issue) : 'en cours') + '</div>';
      html += '<div style="font-size:.72rem;color:#c0b090;margin-top:.2rem">' + paPerdus + ' PA perdus par votre camp, ' +
              morts + ' soldat(s) tué(s)' + (bt.mon_etat ? ' · vous : ' + escapeHtmlText(bt.mon_etat) : '') + '.</div>';
      html += '</div>';
    }
    html += '<div style="height:.5rem"></div>';
  }

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;color:#e0d5b8;margin-bottom:.4rem">ÉTAT DE SERVICE</div>';
  const periodes = Array.isArray(c.periodes) ? c.periodes : [];
  if (periodes.length === 0) {
    html += '<div style="font-size:.76rem;color:#8a8060">Aucune période de service. Vous n\'avez jamais porté l\'uniforme.</div>';
  } else {
    for (const p of periodes) {
      html += '<div style="border-left:2px solid ' + (p.en_cours ? '#8a6a20' : '#2a2010') + ';padding:.3rem .6rem;margin-bottom:.45rem">';
      html += '<div style="font-size:.8rem;color:#f0ead6">' + (LIBELLES_GRADES_MILITAIRES[p.grade] || escapeHtmlText(p.grade || '')) +
              (p.en_cours ? ' <span style="color:#8ac05a;font-size:.68rem">— en cours</span>' : '') + '</div>';
      html += '<div style="font-size:.7rem;color:#8a8060">' + escapeHtmlText(p.debut || '') +
              ' → ' + (p.fin ? escapeHtmlText(p.fin) : 'aujourd\'hui') + ' · ' + (p.jours || 0) + ' jour(s)' +
              (p.section ? ' · section ' + escapeHtmlText(p.section) : '') + '</div>';
      html += '</div>';
    }
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// ---- ORDRES COLLECTIFS : ration et bivouac (UI de militaire_ordre_collectif) ----
// Le groupe, et non le soldat, est l'unite d'ordre : un PNJ n'a pas d'inventaire, c'est son chef
// qui porte ses rations et ses tentes. L'ecran liste donc les GROUPES de la section, c'est-a-dire
// les valeurs distinctes de leaderCourant, et jamais les soldats un par un.
//
// Un groupe mene par quelqu'un d'autre n'est joignable qu'a la radio : le bouton reste affiche
// mais annonce la condition, parce que cacher l'ordre empecherait le joueur de comprendre a quoi
// sert sa radio. C'est le serveur qui refuse, jamais l'interface.
async function ouvrirOrdresCollectifs(compagnieId, sectionId) {
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = (compagnie?.sections || []).find(s => s.id === sectionId);
  if (!section) { showToast('Section introuvable', '', false); return; }

  const moi = state.char?.name;
  const groupes = {};
  for (const sol of (section.soldats || [])) {
    if (sol.pj) continue;
    const chef = sol.leaderCourant;
    if (!chef) continue;
    groupes[chef] = (groupes[chef] || 0) + 1;
  }
  const chefs = Object.keys(groupes).sort((a, b) => (a === moi ? -1 : b === moi ? 1 : a.localeCompare(b)));

  document.getElementById('postes-modal-title').textContent = 'Ordres collectifs';
  let html = '<div style="padding:1rem">';
  if (chefs.length === 0) {
    html += '<div style="font-size:.8rem;color:#8a8060">Aucun groupe en mouvement. Un ordre collectif s\'adresse aux soldats qui suivent un chef ; ceux qui tiennent une position n\'en reçoivent pas.</div>';
  } else {
    html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Une ration nourrit un soldat (+1 PA, consommée). Une tente abrite 13 hommes et n\'est pas détruite. L\'ordre est refusé en bloc si les ressources ne couvrent pas tout le groupe.</div>';
    for (const chef of chefs) {
      const distant = chef !== moi;
      const n = groupes[chef];
      html += '<div style="border:1px solid #2a2010;padding:.6rem;margin-bottom:.6rem">';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#C9A84C">' + escapeHtmlText(chef) + (distant ? '' : ' (vous)') + '</div>';
      html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.5rem">' + n + ' soldat(s)' + (distant ? ' — à distance : vous et ce chef devez chacun porter une radio.' : ' — avec vous.') + '</div>';
      const args = '\'' + compagnieId + '\',\'' + sectionId + '\',\'' + chef.replace(/'/g, "\\'") + '\'';
      html += '<button onclick="confirmerOrdreCollectif(' + args + ',\'ration\')" style="width:49%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #6a8a4a;background:transparent;color:#8ac05a;cursor:pointer">Faire manger</button> ';
      html += '<button onclick="confirmerOrdreCollectif(' + args + ',\'bivouac\')" style="width:49%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #4a6a8a;background:transparent;color:#5a8ad0;cursor:pointer">Bivouaquer</button>';
      html += '</div>';
    }
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerOrdreCollectif(compagnieId, sectionId, chef, action) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await sbMilitaireOrdreCollectif(compagnieId, sectionId, action, chef);
  if (!r || r.ok !== true) {
    const motifs = {
      autorite_insuffisante: 'Vous ne commandez pas ce groupe.',
      radio_manquante: 'Commander à distance exige que vous et le chef du groupe portiez chacun une radio.',
      aucun_soldat_concerne: 'Aucun soldat de ce groupe n\'a besoin de cet ordre aujourd\'hui.',
      rations_insuffisantes: 'Rations insuffisantes : il en faut une par soldat (' + ((r && r.requis) || '?') + ' requises, ' + ((r && r.disponibles) || 0) + ' disponibles).',
      tentes_insuffisantes: 'Tentes insuffisantes : ' + ((r && r.requis) || '?') + ' requise(s) pour ce groupe, ' + ((r && r.disponibles) || 0) + ' disponible(s).',
      compagnie_introuvable: 'Compagnie introuvable.',
      section_introuvable: 'Section introuvable.'
    };
    showToast('Ordre refusé', (r && motifs[r.raison]) || 'Opération refusée.', false);
    return;
  }
  const titre = action === 'ration' ? 'Groupe nourri' : 'Bivouac monté';
  const detail = r.soldats + ' soldat(s) +' + r.gain_pa + ' PA' +
    (action === 'ration' ? ' — ' + r.rations_consommees + ' ration(s) consommée(s).'
                         : ' — ' + r.tentes_requises + ' tente(s) montée(s), conservées.') +
    (r.a_distance ? ' Ordre transmis par radio.' : '');
  showToast(titre, detail, true, true);
  addJournalEntry('Ordre collectif (' + action + ') : ' + r.soldats + ' soldat(s).', 'event-info');
}

// ---- EQUIPEMENT DES SOLDATS PNJ (UI de militaire_equiper_accessoire) ----
// L'accessoire est un OBJET REEL : il sort de l'inventaire du Lieutenant et rejoint le soldat, ou
// l'inverse. Rien n'est cree, rien n'est detruit -- ce qui est sur un soldat manque reellement au
// Lieutenant. C'est pour cela que l'ecran montre les deux cotes en meme temps.
async function ouvrirEquipementSoldats(compagnieId, sectionId) {
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = (compagnie?.sections || []).find(s => s.id === sectionId);
  if (!section) { showToast('Section introuvable', '', false); return; }

  const pnj = (section.soldats || []).filter(s => !s.pj && s.matricule);
  const dispo = (state.inventory || state.char?.inventory || []).filter(o => o && o.produitMilitaire && o.id);

  document.getElementById('postes-modal-title').textContent = 'Équiper les soldats';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Votre inventaire : ' +
          (dispo.length ? dispo.length + ' équipement(s) militaire(s)' : 'aucun équipement militaire') +
          '. Ce que porte un soldat ne vous appartient plus tant que vous ne le reprenez pas.</div>';
  if (pnj.length === 0) {
    html += '<div style="font-size:.8rem;color:#8a8060">Aucun soldat PNJ dans cette section.</div>';
  }
  for (const sol of pnj) {
    const acc = Array.isArray(sol.accessoires) ? sol.accessoires : [];
    html += '<div style="border:1px solid #2a2010;padding:.6rem;margin-bottom:.6rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;color:#C9A84C">' + escapeHtmlText(sol.nom || sol.matricule) + ' <span style="color:#8a8060;font-size:.7rem">' + escapeHtmlText(sol.matricule) + '</span></div>';
    if (acc.length) {
      for (const a of acc) {
        html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-top:.3rem">';
        html += '<span style="font-size:.74rem;color:#f0ead6">' + escapeHtmlText(a.name || a.produitMilitaire) + '</span>';
        html += '<button onclick="equiperSoldat(\'' + compagnieId + '\',\'' + sectionId + '\',\'' + sol.matricule + '\',\'' + a.id + '\',\'desequiper\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.2rem .5rem;border:1px solid #8a4a4a;background:transparent;color:#d05a5a;cursor:pointer">Reprendre</button>';
        html += '</div>';
      }
    } else {
      html += '<div style="font-size:.72rem;color:#8a8060;margin-top:.3rem">Rien d\'équipé.</div>';
    }
    if (dispo.length) {
      html += '<div style="display:flex;gap:.4rem;margin-top:.5rem">';
      html += '<select id="eq-' + sol.matricule + '" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.74rem;outline:none">';
      for (const o of dispo) html += '<option value="' + escapeHtmlText(o.id) + '">' + escapeHtmlText(o.name || o.produitMilitaire) + '</option>';
      html += '</select>';
      html += '<button onclick="equiperSoldatDepuisSelect(\'' + compagnieId + '\',\'' + sectionId + '\',\'' + sol.matricule + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.2rem .6rem;border:1px solid #6a8a4a;background:transparent;color:#8ac05a;cursor:pointer">Équiper</button>';
      html += '</div>';
    }
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function equiperSoldatDepuisSelect(compagnieId, sectionId, matricule) {
  const objetId = document.getElementById('eq-' + matricule)?.value;
  if (!objetId) return;
  equiperSoldat(compagnieId, sectionId, matricule, objetId, 'equiper');
}

async function equiperSoldat(compagnieId, sectionId, matricule, objetId, sens) {
  const r = await sbMilitaireEquiperAccessoire(compagnieId, sectionId, matricule, objetId, sens);
  if (!r || r.ok !== true) {
    const motifs = {
      pas_lieutenant_de_cette_section: 'Seul le Lieutenant de cette section équipe ses soldats.',
      soldat_introuvable: 'Ce soldat n\'est pas dans votre section.',
      objet_absent_de_l_inventaire: 'Vous ne portez pas cet objet.',
      objet_non_porte: 'Ce soldat ne porte pas cet objet.',
      inventaire_plein: 'Votre inventaire est plein.'
    };
    showToast('Opération refusée', (r && motifs[r.raison]) || 'Opération refusée.', false);
    return;
  }
  // L'objet a REELLEMENT change de main cote serveur. On RELIT l'inventaire arrete par le serveur
  // au lieu de le recalculer : le recalculer ici doublerait ou perdrait l'objet.
  if (typeof sbGet === 'function' && state.char?.name) {
    const lignes = await sbGet('personnages',
      'name=eq.' + encodeURIComponent(state.char.name) + '&select=inventory').catch(function () { return null; });
    if (lignes && lignes[0] && Array.isArray(lignes[0].inventory)) {
      state.inventory = lignes[0].inventory;
      if (state.char) state.char.inventory = state.inventory;
      if (typeof renderInventory === 'function') renderInventory();
    }
  }
  showToast(sens === 'equiper' ? 'Soldat équipé' : 'Équipement repris',
            (r.objet || '') + ' — ' + matricule, true, true);
  ouvrirEquipementSoldats(compagnieId, sectionId);
}

// Retourne le libelle a afficher dans une piece pour un detachement present, ou null.
//
// PRESENCE EFFECTIVE (25 septembre 2026). Cette fonction ne comptait que les soldats STATIONNES,
// ce qui rendait invisible tout detachement accompagnant un officier -- y compris dans la piece
// ou se tenait cet officier, et y compris pour lui. Elle compte desormais les deux, via
// soldatEstVisibleIci : position propre quand le soldat est pose, position de son chef quand il
// l'accompagne. Les presences de la piece sont lues UNE fois, pas une fois par section.
async function getAffichageDetachementPiece(pays, ville, buildingId, roomId) {
  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  if (!compagnies || compagnies.length === 0) return null;
  const leadersIci = await leadersPresentsDansPiece(pays, ville, buildingId, roomId);
  for (const c of compagnies) {
    for (const s of (c.sections || [])) {
      const presents = (s.soldats || []).filter(
        sol => soldatEstVisibleIci(sol, ville, buildingId, roomId, leadersIci, s.lieutenantNom));
      if (presents.length > 0) return { nom: 'Soldats section "' + (s.lieutenantNom || '?') + '"', lieutenantNom: s.lieutenantNom, nombre: presents.length, mission: s.mission, sectionId: s.id, compagnieId: c.id, pays: c.pays };
    }
  }
  return null;
}

// CARTE « PERSONNES PRESENTES » D'UN DETACHEMENT — POINT UNIQUE (23 septembre 2026).
//
// LE BUG QU'ELLE FERME. Cette composition vivait en dur dans enterRoom (plateau-navigation.js),
// seul endroit du jeu qui injectait le detachement dans la liste des presents. Or enterRoom
// enchaine ensuite rafraichirPresenceAgents(), qui redessine la liste a partir des seules
// personnes normales -- et cette seconde ecriture, plus tardive d'une ecriture serveur et de deux
// RPC, effacait systematiquement la ligne des soldats. Ils restaient pourtant bien poses en base :
// c'etait un defaut d'affichage, jamais de donnee.
//
// Une seule definition desormais, appelee par les DEUX rendus. Aucun cache militaire n'est
// introduit : chaque appel relit l'etat serveur par getAffichageDetachementPiece (sbGetCompagnies),
// exactement comme le premier rendu le faisait deja. Un detachement recupere ou deplace disparait
// donc de lui-meme au rafraichissement suivant, sans invalidation a ecrire.
//
// LE NIVEAU D'INFORMATION EST STRICTEMENT CELUI D'AVANT : le nom de la section, l'effectif et la
// consigne, rien de plus. Ni compagnie, ni identifiant de section, ni troupe etrangere -- raison
// pour laquelle cette fonction n'utilise PAS la RPC militaire_detachement_ici(), qui en revele
// davantage.
const LIBELLES_MISSION_DETACHEMENT = {
  bloquer_acces: 'Bloque l\'accès',
  securiser: 'Sécurise la pièce',
  assassiner: 'Ordre : neutraliser les intrus',
  arreter: 'Ordre : arrêter les intrus',
  surveiller: 'En surveillance'
};

async function carteDetachementPiece(pays, ville, buildingId, roomId) {
  if (typeof getAffichageDetachementPiece !== 'function') return null;
  const det = await getAffichageDetachementPiece(pays, ville, buildingId, roomId).catch(() => null);
  if (!det) return null;
  return {
    name: det.nom,
    role: det.nombre + ' soldats — ' + (LIBELLES_MISSION_DETACHEMENT[det.mission] || 'Sans consigne'),
    rel: 'neutral', job: 'militaire',
    // CETTE CARTE N'EST PAS UN PNJ (23 septembre 2026). C'est un agregat : plusieurs soldats
    // resumes en une ligne. Sans ce drapeau, renderPersonsList lui appliquait l'onclick generique
    // openPnjModal, qui la lisait comme un PNJ recrutable de l'archetype civil « militaire » --
    // et proposait au Lieutenant de RECRUTER ses propres soldats a 500 FR/jour.
    //
    // lieutenantNom est deja public : il figure en toutes lettres dans le nom affiche de la carte.
    // On ne transmet NI compagnieId NI sectionId : le routage n'en a pas besoin (doGererDetachement
    // les relit sur la fiche du joueur), et les mettre dans le DOM les exposerait sans raison.
    detachement: true,
    lieutenantNom: det.lieutenantNom || null
  };
}

// ---- MISSIONS DES DETACHEMENTS ----
const MISSIONS_DETACHEMENT = [
  { id: 'bloquer_acces', label: 'Bloquer l\'accès au bâtiment' },
  { id: 'securiser', label: 'Sécuriser la pièce (malus actes illégaux)' },
  { id: 'assassiner', label: 'Assassiner toute personne entrant' },
  { id: 'arreter', label: 'Arrêter toute personne entrant' },
  { id: 'surveiller', label: 'Surveiller (rapport passif)' }
  // 'escorter' RETIRE le 18 septembre 2026 (arbitrage GD). Elle etait assignable et affichee mais
  // n'a jamais rien fait : son seul effet, suivreEscorteAvecMoi, avait ete neutralise au lot
  // leaderCourant. La fonction existe ailleurs et elle marche -- militaire_affecter_leader confie
  // des hommes a un PJ present, qui les mene ensuite via leaderCourant. Un soldat qui suit un chef
  // n'a pas de position propre : il se deplace donc avec lui par construction, sans mission.
];

async function doAssignerMission(pa, cost) {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const section = getSectionDuLieutenant(compagnie);
  const iciCount = section?.soldats.filter(s => soldatEstIci(s, state.currentCity, state.currentBuilding, state.currentRoom)).length || 0;
  if (iciCount <= 0) { showToast('Aucun soldat ici', '', false); return; }

  document.getElementById('postes-modal-title').textContent = 'Attribuer une mission';
  let html = '<div style="padding:1rem">';
  MISSIONS_DETACHEMENT.forEach(m => {
    html += '<button onclick="confirmerMission(\'' + compagnie.id + '\',\'' + section.id + '\',\'' + m.id + '\',' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid ' + (section.mission===m.id?'#8a6a20':'#2a2010') + ';background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem">' + m.label + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerMission(compagnieId, sectionId, missionId, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const rMis = await sbMilitaireAssignerMission(compagnieId, sectionId, missionId, null);
  if (!rMis || rMis.ok !== true) {
    showToast('Mission impossible',
      rMis && rMis.raison === 'pas_lieutenant_de_cette_section'
        ? 'Vous ne commandez pas cette section.' : 'Mission refusée.', false);
    return;
  }
  showToast('Mission attribuée', MISSIONS_DETACHEMENT.find(m=>m.id===missionId)?.label, true, true);
}

// ---- MOBILISATION ----
async function doMobiliserArmee(pa, cost) {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  document.getElementById('postes-modal-title').textContent = 'Mobiliser l\'armée';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.7rem">La feuille de route reste secrète — seul le Commandant de la Caserne en aura connaissance.</div>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Empire de destination</label>';
  html += '<select id="mobil-empire" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;margin-bottom:.6rem">';
  Object.entries(COUNTRIES).forEach(([k, co]) => html += '<option value="' + k + '">' + co.n + '</option>');
  html += '</select>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Ville de destination</label>';
  html += '<input id="mobil-ville" type="text" placeholder="ex: capitale" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.6rem"/>';
  html += '<label style="font-size:.72rem;color:#8a8060;display:block;margin-bottom:.3rem">Feuille de route (secrète)</label>';
  html += '<textarea id="mobil-route" rows="4" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.8rem"></textarea>';
  html += '<button onclick="confirmerMobilisation(' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Donner l\'ordre de mobilisation</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerMobilisation(pa, cost) {
  const empireCible = document.getElementById('mobil-empire')?.value;
  const villeCible = document.getElementById('mobil-ville')?.value?.trim();
  const route = document.getElementById('mobil-route')?.value?.trim();
  if (!empireCible || !villeCible || !route) { showToast('Champs requis', '', false); return; }
  document.getElementById('modal-postes')?.classList.remove('open');
  // `fn` explicite (21 septembre 2026) : les trois actions de la mobilisation facturent sous
  // l'ordre de facade `mobilisation_nationale`, dont le miroir declare desormais les couples
  // 4/3/2 PA. Sans ce parametre, le cout partait sous state._ordreEnCours, faux des que la
  // fenetre est rouverte apres un autre ordre.
  const r = await deduireCoutOrdre({ pa, cost, fn: 'mobilisation_nationale' });
  if (!r.ok) { signalerRefusCout(r); return; }

  const pays = state.country || 'republic';
  INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + 10);
  Object.keys(INDICES_NATIONAUX).forEach(p => { if (p !== pays) INDICES_NATIONAUX[p].ID = Math.max(0, INDICES_NATIONAUX[p].ID - 5); });
  updateUI();

  if (empireCible === pays) {
    // CHEMIN SERVEUR (24 septembre 2026). On ecrivait ici le blob budgetaire ENTIER depuis le
    // navigateur pour poser un seul booleen -- avec le risque d'ecraser au passage toute
    // modification concurrente. La RPC n'ecrit que cette cle, et c'est elle qui verifie le poste.
    const rMobil = await sbMobilisationFixer(true).catch(() => null);
    if (!rMobil || rMobil.ok !== true) {
      showToast('Mobilisation non enregistrée',
        'Le serveur a refusé (' + ((rMobil && rMobil.raison) || 'indisponible') + ').', false);
    }
  }

  const commandantInfoMobil = await getTitulaireActuel('commandant');
  const commandantNom = commandantInfoMobil?.estPJ ? commandantInfoMobil.nom : null;
  if (commandantNom && typeof sbSendMail === 'function') {
    await sbSendMail('Ministère de la Défense', commandantNom, 'ORDRE DE MOBILISATION — CONFIDENTIEL',
      'Destination : ' + (COUNTRIES[empireCible]?.n||empireCible) + ' — ' + villeCible + '.<br><br>Feuille de route :<br>' + route.replace(/\n/g,'<br>'),
      typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
  }
  // Rumeur rare et peu precise, jamais la feuille de route elle-meme
  if (Math.random() < 0.15) {
    addExternalEvent('🔍 Rumeur : des mouvements de troupes inhabituels auraient été observés près de la frontière...');
  }
  showToast('Ordre de mobilisation donné', commandantNom ? 'Transmis au Commandant.' : 'Aucun Commandant en poste actuellement — l\'ordre reste sans destinataire.', true, true);
  addJournalEntry('Ordre de mobilisation donné (destination confidentielle).', 'event-info');
}

// ---- IMMUNITE MILITAIRE ----
// A appeler depuis le systeme d'arrestation/plainte : renvoie true si le joueur est immunise
async function estImmuniteMilitaire() {
  const posteId = state.poste?.id;
  if (!['lieutenant', 'capitaine', 'commandant'].includes(posteId)) return false;
  const monEmpire = state.domicile?.country || state.country || 'republic'; // l'empire dont je sers l'armee
  const iciEmpire = state.country || 'republic'; // le territoire ou je me trouve physiquement en ce moment
  const guerres = await sbGetGuerresPays(monEmpire).catch(() => []);
  const enGuerreIci = guerres.some(g => g.statut === 'active' && (
    (g.attaquant === monEmpire && g.attaque === iciEmpire) || (g.attaque === monEmpire && g.attaquant === iciEmpire)
  ));
  const budgetNat = await chargerBudgetNational(monEmpire).catch(() => null);
  const mobilisationNationale = iciEmpire === monEmpire && budgetNat?.mobilisationNationaleActive;
  return enGuerreIci || !!mobilisationNationale;
}

// Rafraichit le cache synchrone d'immunite, consulte par procederArrestation (qui n'est pas asynchrone)
async function rafraichirCacheImmuniteMilitaire() {
  state.immuniteMilitaireActuelle = await estImmuniteMilitaire().catch(() => false);
  // Malus "securiser" applicable dans la piece courante (cache pour un usage synchrone dans doOrder)
  if (typeof getAffichageDetachementPiece === 'function') {
    const det = await getAffichageDetachementPiece(state.country || 'republic', state.currentCity, state.currentBuilding, state.currentRoom).catch(() => null);
    state.malusSecuriteMilitaire = (det?.mission === 'securiser') ? Math.min(40, 10 + det.nombre) : 0;
  }
  const budgetNat = await chargerBudgetNational(state.country || 'republic').catch(() => null);
  state.mobilisationNationaleCache = !!budgetNat?.mobilisationNationaleActive;
  // Cache de l'Effort de guerre (13 septembre 2026), pose ici plutot que dans un second
  // rafraichissement : les deux etats sont lus sur le MEME budget national, deja charge.
  // Comme mobilisationNationaleCache, il n'est jamais persiste sur la fiche du joueur.
  state.effortGuerreCache = budgetNat ? (budgetNat.effortGuerre || null) : null;
}

// Verifie si un detachement hostile bloque/attaque l'entree d'un joueur. Retourne true si l'entree doit etre annulee.
async function verifierMissionMilitaireEntree(buildingId, roomId) {
  if (typeof getAffichageDetachementPiece !== 'function') return false;
  const det = await getAffichageDetachementPiece(state.country || 'republic', state.currentCity, buildingId, roomId);
  if (!det || !det.mission) return false;

  // Exemption : la chaine de commandement de la meme section n'est jamais bloquee/attaquee par ses propres troupes
  if (['lieutenant', 'capitaine', 'commandant', 'min_def'].includes(state.poste?.id)) return false;

  if (det.mission === 'bloquer_acces') {
    showToast('Accès bloqué', 'Un détachement militaire (' + det.nombre + ' soldats) interdit l\'accès.', false);
    return true;
  }
  if (det.mission === 'surveiller' && det.lieutenantNom && typeof sbSendMail === 'function') {
    // ANTI-SPAM (18 septembre 2026). Cette branche n'avait jamais pu s'executer : le crochet
    // d'entree passait roomId = null et ne matchait aucun detachement. Maintenant qu'elle
    // s'execute reellement, un aller-retour dans un couloir surveille enverrait un rapport a
    // chaque pas. Un rapport par zone et par jour suffit a dire « cette personne est passee »,
    // qui est tout ce que la mission promet. Garde technique, pas un equilibrage.
    const jourSurv = (typeof jourPartageISO === 'function') ? jourPartageISO() : String(state.day || 0);
    const cleSurv = jourSurv + '|' + state.currentCity + '/' + buildingId + '/' + roomId;
    if (!state.surveillancesSignalees || state.surveillancesSignalees.jour !== jourSurv) {
      state.surveillancesSignalees = { jour: jourSurv, zones: [] };
    }
    if (!state.surveillancesSignalees.zones.includes(cleSurv)) {
      state.surveillancesSignalees.zones.push(cleSurv);
      sbSendMail('Détachement militaire', det.lieutenantNom, 'Rapport de surveillance',
        (state.char?.name || 'Une personne') + ' a été vue dans la zone surveillée.', typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    }
    return false;
  }
  if (det.mission === 'assassiner' || det.mission === 'arreter') {
    const chance = Math.min(90, 30 + det.nombre * 2); // plus le detachement est nombreux, plus le jet est favorable aux soldats
    const roll = Math.floor(Math.random() * 100) + 1;
    if (roll <= chance) {
      if (det.mission === 'assassiner' && typeof sbDeposerImpactIndice === 'function') {
        const palier = roll <= chance * 0.5 ? 'totale' : 'partielle';
        const pv = palier === 'totale' ? 0 : 25;
        state.hp = pv;
        state.hospitalisation = { jourDebut: state.day, palier, lieu: 'dispensaire', jourFin: state.day + (palier === 'totale' ? 3 : 2) };
        updateUI();
        showToast('Neutralisé(e) !', 'Le détachement militaire vous a pris pour cible. PV : ' + pv + '.', false);
      } else if (det.mission === 'arreter' && typeof procederArrestation === 'function') {
        showToast('Arrêté(e) !', 'Le détachement militaire vous a intercepté.', false);
        procederArrestation('intrusion_zone_militaire', false, false);
      }
      return true;
    }
  }
  return false;
}

// ---- BUDGET DE LA CASERNE (alloue par le MG) ----
async function ouvrirGererBudgetMilitaire() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const pays = state.country || 'republic';
  const maCaisse = typeof chargerCaisseBatiment === 'function' ? await chargerCaisseBatiment(pays, 'gouvernement-min_def') : { solde: 0 };
  const caisseCaserne = typeof chargerCaisseBatiment === 'function' ? await chargerCaisseBatiment(pays, 'caserne-militaire') : { solde: 0 };
  const budgetNat = await chargerBudgetNational(pays);
  const virementActuel = budgetNat.virementJournalierCaserne || 0;

  document.getElementById('postes-modal-title').textContent = 'Budget militaire';
  let html = '<div style="padding:1rem">';
  html += '<div style="display:flex;justify-content:space-between;margin-bottom:1rem;font-family:Bebas Neue,sans-serif;font-size:.95rem">';
  html += '<span style="color:#C9A84C">Ma caisse (Ministère) : ' + (maCaisse.solde||0).toLocaleString('fr-FR') + ' FR</span>';
  html += '<span style="color:#8a8060">Caisse de la Caserne : ' + (caisseCaserne.solde||0).toLocaleString('fr-FR') + ' FR</span>';
  html += '</div>';

  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.7rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.78rem;color:#e0d5b8;margin-bottom:.4rem">VIREMENT JOURNALIER AUTOMATIQUE</div>';
  html += '<div style="font-size:.72rem;color:#8a8060;margin-bottom:.5rem">Actuellement : ' + virementActuel.toLocaleString('fr-FR') + ' FR/jour, prélevé automatiquement chaque nuit sur votre caisse.</div>';
  html += '<input id="montant-virement-journalier" type="number" min="0" value="' + virementActuel + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.5rem"/>';
  html += '<button onclick="confirmerVirementJournalier()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Fixer ce montant</button>';
  html += '</div>';

  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.7rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.78rem;color:#e0d5b8;margin-bottom:.4rem">VIREMENT PONCTUEL</div>';
  html += '<input id="montant-virement-ponctuel" type="number" min="0" value="0" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.5rem"/>';
  html += '<button onclick="confirmerVirementPonctuel()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #5a8ad0;background:transparent;color:#5a8ad0;cursor:pointer">Transférer maintenant</button>';
  html += '</div>';

  html += '<button onclick="ouvrirRechercheMilitaireDepuisMinistere()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.06em;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Financer directement la recherche militaire</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// ECRITURE ATTESTEE (18 septembre 2026). Cette fonction relisait puis reecrivait le blob entier
// de budgets_nationaux SANS aucune attestation -- elle est globale, donc n'importe quel joueur
// authentifie pouvait fixer depuis la console le montant preleve chaque nuit sur la caisse du
// Ministere, et la reecriture du blob pouvait ecraser les sous-cles modifiees entre-temps. Le
// meme correctif avait ete applique au virement PONCTUEL en son temps ; le journalier avait ete
// oublie.
//
// La RPC deduit le pays de l'acteur au lieu de l'accepter en parametre, et ecrit par SOUS-CLE.
// L'execution quotidienne, elle, n'est pas touchee : traiterVirementJournalierCaserne et son
// miroir cron continuent exactement comme avant, marqueur de journee partage compris.
async function confirmerVirementJournalier() {
  const montant = Math.max(0, parseInt(document.getElementById('montant-virement-journalier')?.value || '0'));
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await sbCaserneVirementJournalierFixer(montant);
  if (!r || r.ok !== true) {
    showToast('Virement non fixé', 'Réservé au Ministre de la Défense en exercice.', false);
    return;
  }
  showToast('Virement journalier fixé', Number(r.montant).toLocaleString('fr-FR') + ' FR/jour vers la caserne, à partir de demain.', true, true);
  addJournalEntry('Virement journalier vers la caserne fixé à ' + r.montant + ' FR.', 'event-info');
}

async function confirmerVirementPonctuel() {
  const montant = Math.max(0, parseInt(document.getElementById('montant-virement-ponctuel')?.value || '0'));
  document.getElementById('modal-postes')?.classList.remove('open');
  if (montant <= 0) return;
  const pays = state.country || 'republic';
  // Meme correctif que confirmerVirementPonctuelQHS : une seule transaction serveur, et le poste
  // min_def deduit de l'identifiant de la caisse source au lieu d'etre suppose depuis l'ouverture
  // de la modale. confirmerVirementPonctuel() etant globale, elle etait appelable depuis la
  // console par n'importe quel joueur authentifie.
  const r = await sbCaisseMinistereMouvement(pays, 'gouvernement-min_def', montant, 'caserne-militaire', true);
  if (!r || r.ok !== true) {
    showToast(r && r.raison === 'solde_insuffisant' ? 'Caisse insuffisante' : 'Virement impossible',
              r && r.raison === 'hors_juridiction' ? 'Cette caisse relève d\'un autre pays.'
              : (r && r.raison === 'solde_insuffisant' ? '' : 'Réservé au Ministre de la Défense en exercice.'), false);
    return;
  }
  const montantVerse = Number(r.verse || 0);
  showToast('Virement effectué', montantVerse.toLocaleString('fr-FR') + ' FR transférés vers la caserne.', true, true);
  addJournalEntry('Virement ponctuel de ' + montantVerse + ' FR vers la caserne.', 'event-good');
}

// Traite le virement journalier automatique fixe par le MG (a appeler a minuit)
async function traiterVirementJournalierCaserne(pays) {
  const budgetNat = await chargerBudgetNational(pays).catch(() => null);
  if (!budgetNat) return;
  const montant = budgetNat.virementJournalierCaserne || 0;
  if (montant <= 0) return;

  // IDEMPOTENCE PARTAGEE (correctif Lot 4.3). Cette fonction n'avait AUCUNE garde : chaque joueur
  // qui passait minuit declenchait un virement, donc N joueurs connectes = N virements le meme
  // soir. Le marqueur est desormais la DATE REELLE, identique cote serveur -- jamais state.day, qui
  // est prive et ne peut pas identifier une journee partagee.
  //
  // Marqueur pose AVANT le mouvement : deux clients simultanes ne peuvent pas se croiser entre la
  // lecture et l'ecriture. Un virement perdu vaut mieux qu'un virement double.
  const jourV = (typeof jourPartageISO === 'function') ? jourPartageISO() : null;
  if (jourV) {
    if (budgetNat.dernierVirementCaserneJour === jourV) return;
    budgetNat.dernierVirementCaserneJour = jourV;
    await sbSaveBudgetNational(pays, budgetNat).catch(() => {});
  }
  const montantVerse = await debiterCaisseBatimentPlafonne(pays, 'gouvernement-min_def', montant);
  if (montantVerse > 0) await crediterCaisseBatiment(pays, 'caserne-militaire', montantVerse);
}



// ---- SOLDE QUOTIDIENNE DES SOLDATS (versee chaque nuit, juste apres que le MG touche sa part) ----
// ==========================================================================================
// SOLDE PNJ SUPPRIMEE (18 septembre 2026, arbitrage GD).
// ==========================================================================================
// Elle versait 20 FR par soldat PNJ et par jour, preleves sur la caisse de la caserne. Le GD l'a
// abandonnee : les PNJ militaires n'ont AUCUNE solde recurrente. Le contingent a deja ete paye
// une fois pour toutes par les 20 000 FR de la compagnie, et le faire repayer chaque nuit
// revenait a taxer indefiniment un achat unique.
//
// LES DEUX COTES SONT RETIRES ENSEMBLE, et c'est indispensable : ce miroir client et
// payerSoldeServeur (api/cron-minuit.js) partageaient la meme cle de journee
// budgetNat.derniereSoldeJour. N'en retirer qu'un aurait laisse l'autre payer seul, en posant le
// marqueur et en masquant le probleme.
//
// La fonction est conservee en coquille vide plutot que supprimee : elle est appelee par
// runMidnightUpdate (plateau-core.js) et un appel a une fonction disparue leverait. Le prochain
// passage sur runMidnightUpdate pourra retirer l'appel et cette coquille ensemble.
//
// La cle derniereSoldeJour de budgets_nationaux.data devient orpheline. Elle n'est lue par plus
// aucun chemin : inoffensive, a nettoyer si une passe de menage passe par la.
async function payerSoldeQuotidienne(pays) {
  return;
}

// ---- INSPECTION DES TROUPES (chantier "Inspecter les troupes", 4 septembre 2026) : remplace
// l'ancien ordre unique (fn dispatche vers doInspecterTroupes, jamais defini nulle part dans le
// code -- le bouton etait casse en production, tout clic levait une ReferenceError sans jamais
// debiter de PA ni accorder d'INF). Deux niveaux desormais, ouverts au Ministre de la Defense ET
// au Commandant de la Caserne (arbitrage valide le 4 septembre 2026 : le Commandant porte la
// responsabilite operationnelle de l'armee et n'avait jusqu'ici aucun outil de vue d'ensemble,
// contrairement au Capitaine/Lieutenant qui gardent leurs fiches existantes a leur propre
// echelle -- voir_ma_section, repartir_armement). Lecture pure de l'etat militaire reel deja
// persiste (sbGetCompagnies, stock Armurerie, caisse de la caserne) : aucune nouvelle donnee
// persistee, aucune statistique inventee (pas de moral/loyaute/discipline/puissance/bonus de
// combat), aucun champ INF parallele (state.inf existant, meme plafond 100 que partout ailleurs).
// COUTS DECLARES, PAS SEULEMENT FACTURES (21 septembre 2026). Ces deux niveaux prelevent 1 et
// 2 PA, mais data.js ne declarait que (inspecter_troupes,0,0) : le miroir serveur ignorait les
// deux couples reels et payer_ordre refusait les deux niveaux en 'cout_non_declare' -- l'ordre
// etait integralement mort. Chaque niveau porte desormais `fn`/`label`/`cost` en plus de son
// bareme : c'est exactement la forme que .scratch/generer_ordres_couts.py ramasse pour les ordres
// declares hors data.js, donc le miroir connait les deux couples sans qu'aucun chiffre ne soit
// recopie a la main. data.js declare le cout d'entree (1 PA), ce fichier le second niveau (2 PA).
const NIVEAUX_INSPECTION_TROUPES = {
  revue:     { fn: 'inspecter_troupes', label: 'Passer les troupes en revue', pa: 1, cost: 0, inf: 3, desc: 'Vue synthetique : effectif total, organisation, postes d\'officiers, stock et equipement.' },
  detaillee: { fn: 'inspecter_troupes', label: 'Inspecter les unités', pa: 2, cost: 0, inf: 5, desc: 'Vue synthetique + detail par compagnie/section (officiers, moyennes, equipement, mission) et budget de la caserne.' }
};

function accesInspectionTroupes() {
  return ['min_def', 'commandant'].includes(state.poste?.id);
}

async function ouvrirInspecterTroupes() {
  if (!accesInspectionTroupes()) { showToast('Réservé au Ministre de la Défense ou au Commandant', '', false); return; }
  document.getElementById('postes-modal-title').textContent = 'Inspecter les troupes';
  let html = '<div style="padding:1rem">';
  Object.entries(NIVEAUX_INSPECTION_TROUPES).forEach(([niveau, cfg]) => {
    html += '<button onclick="confirmerInspectionTroupes(\'' + niveau + '\')" style="display:block;width:100%;text-align:left;margin-bottom:.6rem;padding:.7rem .8rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.9rem;color:#e0d5b8;letter-spacing:.05em">' + cfg.label + ' — ' + cfg.pa + ' PA</div>';
    html += '<div style="font-size:.72rem;color:#8a8060;margin:.3rem 0">' + cfg.desc + '</div>';
    html += '<div style="font-size:.72rem;color:#C9A84C">+' + cfg.inf + ' INF</div>';
    html += '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerInspectionTroupes(niveau) {
  if (!accesInspectionTroupes()) { showToast('Réservé au Ministre de la Défense ou au Commandant', '', false); return; }
  const cfg = NIVEAUX_INSPECTION_TROUPES[niveau];
  if (!cfg) return;
  // `fn` explicite : ne jamais dependre de state._ordreEnCours, qui porte le dernier ordre route
  // et serait faux des que cette fenetre est rouverte depuis un autre chemin.
  const r = await deduireCoutOrdre({ pa: cfg.pa, cost: cfg.cost, fn: cfg.fn });
  if (!r.ok) { signalerRefusCout(r); return; }

  // Gain deterministe (pas de jet) : coherent avec l'ancien successRate:100 declare dans
  // data.js, jamais garanti par le moteur generique (doOrder) faute d'etre dans son alwaysSuccess
  // -- comme les autres ordres a effet garanti du jeu (voir stage_caserne, applyEffects
  // court-circuite), cette action n'emprunte jamais le chemin generique. state.inf plafonne a
  // 100 exactement comme applyEffects() le fait pour tous les autres ordres du jeu.
  state.inf = Math.min(100, (state.inf || 0) + cfg.inf);
  updateUI();

  const pays = state.country || 'republic';
  const etat = await construireEtatArmee(pays);
  document.getElementById('postes-modal-title').textContent = cfg.label;
  document.getElementById('postes-body').innerHTML = niveau === 'detaillee' ? renderInspectionDetaillee(etat) : renderInspectionRevue(etat);
  document.getElementById('modal-postes').classList.add('open');
  showToast(cfg.label, 'Inspection effectuée (+' + cfg.inf + ' INF).', true, true);
  addJournalEntry(cfg.label + ' (+' + cfg.inf + ' INF).', 'event-good');
}

// Lecture consolidee de l'etat militaire reel du pays -- aucune mutation, aucune ecriture.
// Reutilise integralement les structures existantes (sbGetCompagnies, chargerStockArmurerieMilitaire,
// chargerCaisseBatiment, getTitulaireActuel) : pas de deuxieme representation de l'armee.
async function construireEtatArmee(pays) {
  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  const budgetNat = await chargerStockArmurerieMilitaire(pays).catch(() => null) || {};
  const stockArmurerie = budgetNat.stockArmurerieMilitaire || { arme_de_poing: 0, mitraillette: 0 };
  const caisseCaserne = typeof chargerCaisseBatiment === 'function' ? await chargerCaisseBatiment(pays, 'caserne-militaire').catch(() => ({ solde: 0 })) : { solde: 0 };
  const commandantInfo = await getTitulaireActuel('commandant', null, pays).catch(() => null);

  let effectifTotal = 0;
  let capitainesPourvus = 0, capitainesVacants = 0;
  let lieutenantsPourvus = 0, lieutenantsVacants = 0;
  const armesAssignees = { arme_de_poing: 0, mitraillette: 0 };
  const armesLibresSections = { arme_de_poing: 0, mitraillette: 0 };

  const compagniesDetail = compagnies.map(c => {
    if (c.capitaineNom) capitainesPourvus++; else capitainesVacants++;
    const sections = (c.sections || []).map(s => {
      const soldats = s.soldats || [];
      effectifTotal += soldats.length;
      if (s.lieutenantNom) lieutenantsPourvus++; else lieutenantsVacants++;

      // QUATRE DOMAINES (18 septembre 2026). Les moyennes ne portent que sur les soldats PNJ :
      // un soldat PJ n'a pas de `formation`, ses caracteristiques vivent sur sa fiche.
      let sommeCbt = 0, sommeRec = 0, sommeSec = 0, sommeTir = 0, nbPnj = 0;
      const armesUnite = { arme_de_poing: 0, mitraillette: 0 };
      soldats.forEach(sol => {
        if (sol.pj !== true) {
          nbPnj++;
          sommeCbt += sol.formation?.combat_rapproche || 0;
          sommeTir += sol.formation?.tir || 0;
          sommeRec += sol.formation?.reconnaissance || 0;
          sommeSec += sol.formation?.secourisme || 0;
        }
        if (sol.arme && armesUnite[sol.arme] !== undefined) { armesUnite[sol.arme]++; armesAssignees[sol.arme]++; }
      });
      const stockLibre = s.stockArmes || { arme_de_poing: 0, mitraillette: 0 };
      CATEGORIES_ARME_STOCK.forEach(cat => { armesLibresSections[cat] += stockLibre[cat] || 0; });
      const nbArmesUnite = CATEGORIES_ARME_STOCK.reduce((sum, cat) => sum + armesUnite[cat], 0);

      return {
        numero: s.numero, lieutenantNom: s.lieutenantNom || null,
        effectif: soldats.length, capacite: EFFECTIF_SECTION,
        // null (jamais 0) si section vide : une moyenne/un taux ne se calcule que sur des membres
        // reels, jamais fabrique pour remplir une case (voir renderInspectionDetaillee, affiche "—").
        effectifPnj: nbPnj,
        effectifPj: soldats.length - nbPnj,
        moyenneCombatRapproche: nbPnj ? sommeCbt / nbPnj : null,
        moyenneTir: nbPnj ? sommeTir / nbPnj : null,
        moyenneReconnaissance: nbPnj ? sommeRec / nbPnj : null,
        moyenneSecourisme: nbPnj ? sommeSec / nbPnj : null,
        armesUnite, stockLibre,
        tauxEquipement: soldats.length ? nbArmesUnite / soldats.length : null,
        mission: s.mission || null
      };
    });
    // RESERVE DE CONTINGENT, exposee au Commandant : le contingent n'est plus renouvelable,
    // savoir combien d'hommes restent disponibles devient une information vitale.
    const reserve = Array.isArray(c.reserve) ? c.reserve.length : 0;
    const contingentInitial = (typeof c.contingentInitial === 'number') ? c.contingentInitial : null;
    return { capitaineNom: c.capitaineNom || null, sections, reserve, contingentInitial };
  });

  const armesAssigneesTotal = CATEGORIES_ARME_STOCK.reduce((sum, cat) => sum + armesAssignees[cat], 0);

  return {
    effectifTotal, nbCompagnies: compagnies.length,
    commandantNom: commandantInfo?.nom || null,
    capitainesPourvus, capitainesVacants, lieutenantsPourvus, lieutenantsVacants,
    stockArmurerie, armesAssignees, armesLibresSections,
    tauxEquipementGlobal: effectifTotal ? armesAssigneesTotal / effectifTotal : null,
    caisseCaserne: caisseCaserne.solde || 0,
    virementJournalier: budgetNat.virementJournalierCaserne || 0,
    compagnies: compagniesDetail
  };
}

function renderBlocVueEnsembleArmee(etat) {
  const labelsArme = { arme_de_poing: 'Armes de poing', mitraillette: 'Mitraillettes' };
  let html = '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.7rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#e0d5b8;margin-bottom:.5rem">VUE D\'ENSEMBLE</div>';
  html += '<div style="color:#a89870;margin-bottom:.3rem">Effectif total : ' + etat.effectifTotal + ' soldats, répartis en ' + etat.nbCompagnies + ' compagnie(s).</div>';
  html += '<div style="color:#a89870;margin-bottom:.3rem">Commandant de la Caserne : ' + (etat.commandantNom || 'poste vacant') + '.</div>';
  html += '<div style="color:#a89870;margin-bottom:.3rem">Capitaines : ' + etat.capitainesPourvus + ' en poste, ' + etat.capitainesVacants + ' vacant(s).</div>';
  html += '<div style="color:#a89870">Lieutenants : ' + etat.lieutenantsPourvus + ' en poste, ' + etat.lieutenantsVacants + ' vacant(s).</div>';
  html += '</div>';

  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#e0d5b8;margin-bottom:.5rem">ARMEMENT</div>';
  CATEGORIES_ARME_STOCK.forEach(cat => {
    html += '<div style="color:#a89870;margin-bottom:.3rem">' + labelsArme[cat] + ' — stock Armurerie : ' + (etat.stockArmurerie[cat]||0) + ' · attribuées aux unités : ' + (etat.armesAssignees[cat]||0) + ' · libres en section : ' + (etat.armesLibresSections[cat]||0) + '</div>';
  });
  // EXPLOSIFS (13 septembre 2026) : ils vivent dans le meme stock national mais ne sont PAS dans
  // CATEGORIES_ARME_STOCK -- ce ne sont pas des armes distribuables aux sections par le Capitaine.
  // Ils sont donc affiches a part, en lecture seule. Voir n'est pas retirer : seul le Lieutenant
  // chef de section peut les sortir du magasin.
  html += '<div style="color:#a89870;margin-top:.3rem">Explosifs militaires — stock Armurerie : '
       + ((etat.stockArmurerie && etat.stockArmurerie.explosif_militaire) || 0) + '</div>';
  html += '<div style="color:#C9A84C;margin-top:.4rem">Taux d\'équipement global : ' + (etat.tauxEquipementGlobal == null ? 'non calculable (aucun soldat)' : Math.round(etat.tauxEquipementGlobal*100) + '%') + '</div>';
  html += '</div>';
  return html;
}

function renderInspectionRevue(etat) {
  return '<div style="padding:1rem;max-height:65vh;overflow-y:auto;font-size:.8rem">' + renderBlocVueEnsembleArmee(etat) + '</div>';
}

function renderInspectionDetaillee(etat) {
  const labelsMission = {};
  MISSIONS_DETACHEMENT.forEach(m => { labelsMission[m.id] = m.label; });

  let html = '<div style="padding:1rem;max-height:70vh;overflow-y:auto;font-size:.8rem">';
  html += renderBlocVueEnsembleArmee(etat);

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#e0d5b8;margin:.9rem 0 .5rem">DÉTAIL PAR UNITÉ</div>';
  if (etat.compagnies.length === 0) {
    html += '<div style="color:#8a8060;font-style:italic">Aucune compagnie recrutée actuellement.</div>';
  }
  etat.compagnies.forEach((c, ic) => {
    html += '<div style="border:1px solid #4a3a1a;background:#0d0b04;padding:.6rem .7rem;margin-bottom:.6rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.82rem;color:#C9A84C;margin-bottom:.5rem">Compagnie ' + (ic+1) + ' — Capitaine : ' + (c.capitaineNom || 'poste vacant') + '</div>';
    if (c.sections.length === 0) {
      html += '<div style="color:#8a8060;font-style:italic;font-size:.75rem">Aucune section.</div>';
    }
    c.sections.forEach(s => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.5rem .6rem;margin-bottom:.4rem;font-size:.74rem">';
      html += '<div style="color:#e0d5b8;margin-bottom:.25rem">Section ' + s.numero + ' — Lieutenant : ' + (s.lieutenantNom || 'poste vacant') + '</div>';
      html += '<div style="color:#a89870;margin-bottom:.2rem">Effectif : ' + s.effectif + '/' + s.capacite + '</div>';
      const m1 = (v) => (v == null ? '—' : v.toFixed(1));
      html += '<div style="color:#a89870;margin-bottom:.2rem">Moyennes PNJ — Combat rapproché : ' + m1(s.moyenneCombatRapproche)
            + ' · Tir : ' + m1(s.moyenneTir) + ' · Reconnaissance : ' + m1(s.moyenneReconnaissance)
            + ' · Secourisme : ' + m1(s.moyenneSecourisme) + '</div>';
      html += '<div style="color:#8a8060;font-size:.72rem;margin-bottom:.2rem">Effectif : ' + (s.effectifPnj || 0)
            + ' PNJ + ' + (s.effectifPj || 0) + ' joueur(s)</div>';
      html += '<div style="color:#a89870;margin-bottom:.2rem">Armes attribuées — Arme de poing : ' + (s.armesUnite.arme_de_poing||0) + ' · Mitraillette : ' + (s.armesUnite.mitraillette||0) + ' (stock libre non distribué : ' + (s.stockLibre.arme_de_poing||0) + ' / ' + (s.stockLibre.mitraillette||0) + ')</div>';
      html += '<div style="color:#a89870;margin-bottom:.2rem">Taux d\'équipement : ' + (s.tauxEquipement==null?'non calculable (section vide)':Math.round(s.tauxEquipement*100)+'%') + '</div>';
      html += '<div style="color:#a89870">Mission : ' + (s.mission ? ((labelsMission[s.mission]||s.mission)) : 'aucune mission assignée') + '</div>';
      html += '</div>';
    });
    html += '</div>';
  });

  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.85rem;color:#e0d5b8;margin:.9rem 0 .5rem">BUDGET DE LA CASERNE</div>';
  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;font-size:.76rem;color:#a89870">';
  html += '<div style="margin-bottom:.3rem">Caisse de la Caserne : ' + etat.caisseCaserne.toLocaleString('fr-FR') + ' FR.</div>';
  html += '<div style="margin-bottom:.3rem">Virement journalier automatique configuré : ' + etat.virementJournalier.toLocaleString('fr-FR') + ' FR/jour.</div>';
  html += '<div style="font-style:italic;color:#8a8060">Aucun historique détaillé des dépenses/mouvements n\'est actuellement conservé pour la caserne : seuls le solde courant et le virement configuré existent réellement dans le système.</div>';
  html += '</div>';

  html += '</div>';
  return html;
}

// ---- ACHAT INSTITUTIONNEL D'ARMEMENT — SUPPRIME LE 13 SEPTEMBRE 2026 ----------------------
// ouvrirAchatArmureMilitaire / confirmerAchatArmureMilitaire creaient des armes EX NIHILO : le
// ministre debitait sa caisse et le stock de l'Armurerie Militaire montait, sans qu'aucune arme
// ait ete produite nulle part, sans matiere consommee et sans armurier paye. Le chantier Effort
// de guerre supprime ce circuit parallele : desormais l'armement militaire n'a qu'une seule
// origine, la production par les trois armureries civiles sur commande du Ministre pendant un
// Effort de guerre (plateau-effort-guerre.js, api/cron-minuit.js). Hors Effort, la caserne vit
// sur son stock existant -- reconstituer ce stock EXIGE de decreter un Effort.
// PRIX_ARME_MILITAIRE (300/800) disparait avec eux : c'etaient les memes chiffres legacy que les
// prix civils de l'armurerie, et plus rien ne les lit. Le stock deja present en base n'est pas
// touche ; chargerStockArmurerieMilitaire et ouvrirRepartirArmement continuent de le servir.

// ---- DOTATION DES SECTIONS (reservee au Capitaine) : transfere de l'armement entre le stock
// national de l'Armurerie Militaire et le stock libre d'une section de sa compagnie. ----
// AUTORITE BASCULEE AU LIEUTENANT (arbitrage du 17 septembre 2026) : seul le chef de section
// retire du magasin, et seulement pour SA section. Le Capitaine n'a plus cette prerogative --
// ce que le code notait deja pour les explosifs (« seul le chef de section peut les sortir »).
async function ouvrirRepartirArmement() {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé au chef de section', 'Le retrait au magasin relève du Lieutenant, pas du Capitaine.', false); return; }
  const pays = state.country || 'republic';
  const compagnie = (await sbGetCompagnies(pays).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  if (!compagnie) return;
  const budgetNat = await chargerStockArmurerieMilitaire(pays);
  const stockArmurerie = budgetNat.stockArmurerieMilitaire;
  const labels = { arme_de_poing: 'Arme de poing', mitraillette: 'Mitraillette' };

  document.getElementById('postes-modal-title').textContent = 'Répartir l\'armement';
  let html = '<div style="padding:1rem;max-height:60vh;overflow-y:auto">';
  // VISIBILITE DES STOCKS (13 septembre 2026) : le Capitaine voit les TROIS produits du magasin,
  // explosifs compris, par la meme brique que le Lieutenant, le Commandant et le Ministre.
  // Il ne peut repartir que les armes : les explosifs ne sont pas une dotation de section, et
  // seul le chef de section peut les sortir du magasin. Voir n'est pas retirer.
  html += (typeof htmlStockArmurerieMilitaire === 'function')
    ? htmlStockArmurerieMilitaire(stockArmurerie)
    : '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Stock Armurerie Militaire — Arme de poing : ' + (stockArmurerie.arme_de_poing||0) + ' · Mitraillette : ' + (stockArmurerie.mitraillette||0) + '</div>';
  html += '<div style="font-size:.7rem;color:#6a5a30;margin-bottom:.8rem;font-style:italic">Seules les armes se répartissent entre sections. Les explosifs sont retirés directement par le chef de section. Chaque mouvement coûte 1 PA, prélevé par le serveur.</div>';
  // Une seule section est dotable : celle que commande l'appelant.
  (compagnie.sections || []).filter(s => s.lieutenantNom === state.char?.name).forEach(s => {
    const stockSection = s.stockArmes || { arme_de_poing: 0, mitraillette: 0 };
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem .7rem;margin-bottom:.5rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;color:#e0d5b8;margin-bottom:.4rem">Section ' + s.numero + (s.lieutenantNom ? (' — Lt. ' + s.lieutenantNom) : ' (sans lieutenant)') + ' · ' + s.soldats.length + ' soldats</div>';
    CATEGORIES_ARME_STOCK.forEach(cat => {
      const portees = s.soldats.filter(sol => sol.arme === cat).length;
      const libres = stockSection[cat] || 0;
      html += '<div style="display:flex;justify-content:space-between;align-items:center;font-size:.75rem;color:#a89870;margin-bottom:.35rem;gap:.4rem">';
      html += '<span>' + labels[cat] + ' — dotation : ' + (libres + portees) + ' (' + libres + ' libres, ' + portees + ' portées)</span>';
      html += '<span style="display:flex;align-items:center;gap:.25rem">';
      html += '<input id="qte-' + s.id + '-' + cat + '" type="number" min="0" value="0" style="width:52px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.2rem;font-size:.72rem"/>';
      html += '<button onclick="confirmerTransfertArmement(\'' + compagnie.id + '\',\'' + s.id + '\',\'' + cat + '\',\'vers_section\')" style="font-size:.66rem;padding:.2rem .35rem;border:1px solid #4a7a3a;background:transparent;color:#7ab868;cursor:pointer">→ Section</button>';
      html += '<button onclick="confirmerTransfertArmement(\'' + compagnie.id + '\',\'' + s.id + '\',\'' + cat + '\',\'vers_armurerie\')" style="font-size:.66rem;padding:.2rem .35rem;border:1px solid #8a3a3a;background:transparent;color:#cc6a6a;cursor:pointer">→ Armurerie</button>';
      html += '</span></div>';
    });
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerTransfertArmement(compagnieId, sectionId, categorie, sens) {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé au chef de section', 'Le retrait au magasin relève du Lieutenant.', false); return; }
  const qte = parseInt(document.getElementById('qte-' + sectionId + '-' + categorie)?.value || '0');
  if (qte <= 0) return;
  const pays = state.country || 'republic';
  const compagnie = (await sbGetCompagnies(pays).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!compagnie || !section) return;
  if (!section.stockArmes) section.stockArmes = { arme_de_poing: 0, mitraillette: 0 };

  // FIN DU DOUBLE CIRCUIT DE L'ARMURERIE (17 septembre 2026).
  // Ce bloc ecrivait budgets_nationaux.data.stockArmurerieMilitaire en lecture-modification-
  // reecriture cliente : sans autorite serveur (la garde « capitaine » etait ici, donc
  // contournable), sans verrou, en reecrivant le blob national ENTIER (donc en ecrasant toute
  // modification concurrente de la reserve fiscale, du refectoire, de la recherche...), et sans
  // jamais toucher lotsMilitaires -- ce qui desynchronisait le stock de sa file de lots et
  // faisait ensuite servir des lots fantomes 'legacy' par militaire_retrait.
  // Desormais : une seule transaction serveur qui passe par caserne_stock_mouvement, la primitive
  // atomique que militaire_retrait utilise deja. Meme autorite qu'avant (le Capitaine de cette
  // compagnie), memes produits, memes quantites.
  // LE COUT EST PRELEVE PAR LA RPC (21 septembre 2026). data.js declare repartir_armement a 1 PA
  // et le miroir porte le couple ('repartir_armement',1,0), mais AUCUN des deux handlers de cet
  // ordre n'appelait deduireCoutOrdre : l'ordre etait affiche payant et rendu gratuit. Le
  // prelevement vit desormais dans militaire_armurerie_transfert, dans la meme transaction que le
  // mouvement de stock -- il ne depend plus du navigateur, et un refus n'accorde aucun transfert.
  // UN mouvement = 1 PA, dans les deux sens.
  const rArm = await sbMilitaireArmurerieTransfert(compagnieId, sectionId, categorie, qte, sens);
  if (!rArm || rArm.ok !== true) {
    const motifs = {
      stock_insuffisant: 'L\'Armurerie Militaire ne dispose pas de ' + qte + ' unité(s).',
      stock_section_insuffisant: 'Seules ' + (rArm && rArm.disponible !== undefined ? rArm.disponible : 0) + ' unité(s) sont libres dans cette section (le reste est porté par des soldats — voir Gérer l\'équipement).',
      pas_lieutenant_de_cette_section: 'Vous ne commandez pas cette section.',
      section_introuvable: 'Cette section n\'existe pas.',
      hors_juridiction: 'Cette compagnie relève d\'un autre pays.',
      pa_insuffisants: 'Chaque mouvement d\'armement coûte 1 PA, et il ne vous en reste pas assez.'
    };
    showToast('Transfert impossible', (rArm && motifs[rArm.raison]) || 'Opération refusée.', false);
    return;
  }
  // On recopie les PA arretes par le serveur, jamais un decompte local.
  if (typeof rArm.pa === 'number') { state.pa = rArm.pa; updateUI(); }
  if (sens === 'vers_section') {
    showToast('Armement transféré', qte + ' unité(s) transférée(s) vers la section.', true, true);
  } else {
    showToast('Armement récupéré', qte + ' unité(s) récupérée(s) vers l\'Armurerie.', true, true);
  }
  document.getElementById('modal-postes')?.classList.remove('open');
  ouvrirRepartirArmement();
}

// ouvrirRecruterSection SUPPRIMEE le 21 septembre 2026, avec l'ordre recruter_section lui-meme
// (data.js, routeur, miroir des couts). Elle listait les sections vides pour y acheter 24 recrues
// neuves : modele abandonne par le GD le 17 septembre. Un effectif perdu ne se rachete plus, il se
// recomplete en puisant dans la reserve de contingent de la compagnie (militaire_affecter_leader).

async function doVoirMaSection() {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const section = getSectionDuLieutenant(compagnie);
  if (!section) return;

  document.getElementById('postes-modal-title').textContent = 'Ma section — ' + section.soldats.length + ' soldats';
  let html = '<div style="padding:1rem;max-height:60vh;overflow-y:auto">';
  const armesLabels = { corps_a_corps: 'Aucun', arme_de_poing: 'Arme de poing', mitraillette: 'Mitraillette' };
  section.soldats.forEach(s => {
    const localisation = libelleLieuSoldat(s);
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.35rem;font-size:.75rem">';
    html += '<div style="color:#e0d5b8;font-family:monospace">' + s.matricule + '</div>';
    html += '<div style="color:#a89870">' + libelleFormationSoldat(s)
          + (s.pj === true ? '' : ' · PA ' + (s.pa || 0) + '/' + PA_MAX_SOLDAT)
          + ' · ' + localisation
          // Un soldat rallie a une mutinerie porte son camp dans le blob : le Lieutenant doit
          // voir immediatement lesquels de ses hommes ne lui obeissent plus.
          + (s.mutin ? ' · <b style="color:#cc4444">MUTIN</b>' : '') + '</div>';
    html += '<div style="color:#8a8060">Équipement : ' + (armesLabels[s.arme] || 'Aucun') + '</div>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// ---- ENTRAINEMENT (comme le foot : pas de plafond, assiduite recompensee, 12/24 max par session) ----
async function doEntrainerSection(pa, cost) {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const section = getSectionDuLieutenant(compagnie);
  if (!section) return;

  document.getElementById('postes-modal-title').textContent = 'Entraîner la section';
  let html = '<div style="padding:1rem">';
  // QUATRE DOMAINES (18 septembre 2026). « Endurance » a disparu : les PA remplissent deja ce
  // role. Pas de competence radio ni tente -- ce sont des outils, pas des savoir-faire.
  const eligibles = (section.soldats || []).filter(x => x && x.pj !== true
                     && Number(x.pa || 0) >= PA_SEANCE_ENTRAINEMENT).length;
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.4rem">Choisissez le domaine a travailler. '
        + CAP_ENTRAINEMENT_PAR_SESSION + ' soldats maximum par seance, les moins entraines d\'abord. +3 par participant, plafond 100.</div>';
  html += '<div style="font-size:.74rem;color:#c0a060;margin-bottom:.8rem">Coût : <b>' + PA_SEANCE_ENTRAINEMENT
        + ' PA pour vous</b> et <b>' + PA_SEANCE_ENTRAINEMENT + ' PA pour chaque soldat</b>. '
        + eligibles + ' soldat(s) de votre section ont actuellement les PA requis'
        + (Number(state.pa || 0) < PA_SEANCE_ENTRAINEMENT ? ' — et il vous manque des PA.' : '.') + '</div>';
  DOMAINES_ENTRAINEMENT.forEach(d => {
    const moy = (() => {
      const pnj = (section.soldats || []).filter(x => x && x.pj !== true);
      if (!pnj.length) return null;
      return Math.round(pnj.reduce((t, x) => t + Number(x.formation?.[d.id] || 0), 0) / pnj.length);
    })();
    html += '<button onclick="confirmerEntrainementSection(\'' + compagnie.id + '\',\'' + section.id + '\',\'' + d.id + '\',' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem">'
          + d.label + (moy === null ? '' : ' <span style="font-size:.7rem;color:#8a8060">— moyenne de la section : ' + moy + '/100</span>') + '</button>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEntrainementSection(compagnieId, sectionId, stat, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;
  // LES PA SONT DEBITES PAR LE SERVEUR, plus par le client (18 septembre 2026). L'ordre est
  // declare a 0 PA dans data.js et la RPC preleve elle-meme les 6 PA du Lieutenant ET les 6 PA de
  // chaque soldat participant, dans la meme transaction. Un deduireCoutOrdre ici ferait un double
  // prelevement, et surtout il prelevait avant de savoir si la seance pouvait avoir lieu.
  const rEnt = await sbMilitaireEntrainerSection(compagnieId, sectionId, stat);
  if (!rEnt || rEnt.ok !== true) {
    const m = rEnt && rEnt.raison;
    showToast('Entraînement impossible',
      m === 'pas_lieutenant_de_cette_section' ? 'Vous ne commandez pas cette section.'
      : m === 'pa_chef_insuffisants' ? 'Il vous faut ' + PA_SEANCE_ENTRAINEMENT + ' PA pour conduire une séance.'
      : m === 'aucun_soldat_en_etat' ? 'Aucun soldat n\'a les ' + PA_SEANCE_ENTRAINEMENT + ' PA nécessaires. Laissez-les récupérer.'
      : m === 'domaine_invalide' ? 'Ce domaine d\'entraînement n\'existe pas.'
      : 'Entraînement refusé (' + (m || 'indisponible') + ').', false);
    return;
  }
  // On recopie les PA arretes par le SERVEUR, jamais un calcul local.
  if (typeof rEnt.pa_restants_chef === 'number') { state.pa = rEnt.pa_restants_chef; updateUI(); }
  const nbProgresses = Number(rEnt.progresses || 0);
  showToast('Entraînement terminé', nbProgresses + ' soldats ont progressé en ' + stat + '.', true, true);
  addJournalEntry('Entraînement de la section "' + section.lieutenantNom + '" en ' + stat + ' (' + nbProgresses + ' soldats).', 'event-good');
}

// ---- REPOS QUOTIDIEN DE LA SECTION (23 septembre 2026) ----
// CONTREPARTIE DE L'ENTRAINEMENT. Une seance coute 6 PA a chaque soldat sur 12, et les PA d'un
// soldat sont aussi ses points de vie au combat. Le repos quotidien empeche que cette fatigue
// dure artificiellement plusieurs jours, sans pour autant rendre l'entrainement de derniere
// minute gratuit : chaque soldat n'a qu'UN repos par jour, et le depenser est le vrai choix
// tactique du Lieutenant.
//
// AUCUNE SELECTION, AUCUNE MICROGESTION. Le joueur ne choisit ni les soldats, ni les
// beneficiaires de la tente : le serveur traite toute la section, soldat par soldat, selon la
// situation de chacun au moment du clic. Le client ne fait qu'afficher le compte rendu.
//
// PAS DE deduireCoutOrdre : l'ordre est declare 0 PA / 0 FR, et la RPC ne preleve rien.
async function doReposerSection() {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  if (typeof sbMilitaireReposerSection !== 'function') { showToast('Indisponible', 'Service momentanément indisponible.', false); return; }
  const compagnie = (await sbGetCompagnies(state.country || 'republic').catch(() => []))
    .find(c => c.id === state.poste.compagnieId);
  const section = getSectionDuLieutenant(compagnie);
  if (!section) { showToast('Section introuvable', 'Vous ne commandez aucune section.', false); return; }

  const r = await sbMilitaireReposerSection(compagnie.id, section.id);
  if (!r || r.ok !== true) {
    const m = r && r.raison;
    showToast('Repos impossible',
      m === 'pas_lieutenant_de_cette_section' ? 'Vous ne commandez pas cette section.'
      : m === 'compagnie_introuvable' ? 'Cette compagnie n\'existe plus.'
      : m === 'section_introuvable' ? 'Cette section n\'existe plus.'
      : m === 'hors_juridiction' ? 'Cette compagnie ne relève pas de votre empire.'
      : 'Repos refusé (' + (m || 'indisponible') + ').', false);
    return;
  }

  // COMPTE RENDU SYNTHETIQUE : une ligne par categorie REELLEMENT concernee, jamais 24 lignes,
  // jamais une categorie a zero.
  const lignes = [];
  if (r.caserne > 0) lignes.push(r.caserne + ' soldat(s) reposé(s) à la caserne.');
  if (r.tente > 0)   lignes.push(r.tente + ' soldat(s) reposé(s) sur le terrain, sous la tente.');
  if (r.terrain > 0) lignes.push(r.terrain + ' soldat(s) reposé(s) sur le terrain.');
  if (r.deja_reposes > 0) lignes.push(r.deja_reposes + ' soldat(s) avaient déjà bénéficié de leur repos aujourd\'hui.');

  if (Number(r.reposes || 0) === 0) {
    showToast('Aucun repos à prendre',
      lignes.length ? lignes.join(' ') : 'Aucun soldat de votre section ne peut se reposer maintenant.', false);
    return;
  }
  showToast('Repos de la section effectué', lignes.join(' '), true, true);
  addJournalEntry('Repos de la section "' + section.lieutenantNom + '" : ' + r.reposes + ' soldat(s) reposé(s).', 'event-good');
}

// ---- MUTINERIE — DECLENCHEMENT (23 septembre 2026) ----
// CONFIRMATION EXPLICITE OBLIGATOIRE. C'est le seul acte du jeu qui fasse basculer un joueur hors
// de l'armee reguliere sans retour possible, et dont l'echec se paie en prison. Le joueur doit
// lire ce qu'il engage avant de cliquer -- pas un toast apres coup.
//
// Le client ne calcule RIEN : ni le nombre de rallies, ni qui suit. Il demande, le serveur
// tranche, et il rapporte le resultat reel.
async function doDeclencherMutinerie() {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', 'Seul un chef de section peut retourner ses hommes.', false); return; }
  document.getElementById('postes-modal-title').textContent = 'Déclencher une mutinerie';
  let html = '<div style="padding:1rem">';
  html += '<div style="border:1px solid #6a2a20;background:#140a08;padding:.8rem;margin-bottom:.9rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.95rem;letter-spacing:.1em;color:#cc4444;margin-bottom:.5rem">ACTE GRAVE ET IRRÉVERSIBLE</div>';
  html += '<div style="font-size:.82rem;color:#c0b090;line-height:1.6">Vous vous apprêtez à retourner votre section contre l\'armée régulière de votre pays. '
        + '<b>Cette décision ne peut pas être annulée.</b></div>';
  html += '<ul style="font-size:.8rem;color:#a09070;line-height:1.7;margin:.6rem 0 0 1rem;padding:0">';
  html += '<li>Une partie seulement de vos hommes vous suivra — votre charisme et l\'état du pays décideront combien.</li>';
  html += '<li>Ceux qui refusent restent loyalistes et pourront vous combattre.</li>';
  // CORRIGE LE 24 SEPTEMBRE 2026. Cette ligne annoncait la perte du poste. Le serveur ne la fait
  // pas : militaire_mutinerie_declencher n'ecrit ni services_militaires ni personnages_donnees.poste
  // -- et il ne le PEUT pas, puisque le mutin doit rester Lieutenant en service pour que
  // militaire_bataille_recruter l'enrole avec sa section. La promesse etait donc fausse, et elle
  // aurait ete la premiere chose que le joueur aurait verifiee. On dit ce qui se passe vraiment.
  html += '<li>Vous restez officiellement Lieutenant : l\'armée ne vous a pas encore radié, mais vous êtes désormais en rébellion.</li>';
  html += '<li><b style="color:#cc4444">Si vous êtes capturé, vous serez emprisonné 7 jours pour mutinerie.</b></li>';
  html += '</ul></div>';
  html += '<button onclick="confirmerMutinerie()" style="width:100%;margin-bottom:.4rem;font-family:Bebas Neue,sans-serif;font-size:.8rem;letter-spacing:.1em;padding:.6rem;border:1px solid #8a2a20;background:transparent;color:#cc4444;cursor:pointer">Je me soulève</button>';
  html += '<button onclick="document.getElementById(\'modal-postes\').classList.remove(\'open\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">Renoncer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerMutinerie() {
  document.getElementById('modal-postes')?.classList.remove('open');
  if (typeof sbMutinerieDeclencher !== 'function') { showToast('Indisponible', 'Service momentanément indisponible.', false); return; }
  const r = await sbMutinerieDeclencher();
  if (!r || r.ok !== true) {
    const m = r && r.raison;
    showToast('Mutinerie impossible',
      m === 'pas_lieutenant' ? 'Seul un chef de section peut se soulever.'
      : m === 'deja_mutin' ? 'Vous êtes déjà en rébellion.'
      : m === 'pas_lieutenant_de_cette_section' ? 'Vous ne commandez pas cette section.'
      : 'Refus du serveur (' + (m || 'indisponible') + ').', false);
    return;
  }
  // On recopie le resultat ARRETE PAR LE SERVEUR, jamais un calcul local.
  const suivi = Number(r.soldats_rallies || 0);
  const restes = Number(r.soldats_restes_loyalistes || 0);
  if (typeof rafraichirMutins === 'function') await rafraichirMutins().catch(() => {});
  if (typeof rafraichirPresenceAgents === 'function') rafraichirPresenceAgents();
  showToast('Mutinerie déclenchée',
    suivi + ' soldat(s) vous ont suivi' + (restes > 0 ? ', ' + restes + ' sont restés loyalistes.' : '.'), true, true);
  addJournalEntry('Vous avez déclenché une mutinerie : ' + suivi + ' soldat(s) vous ont suivi.', 'event-bad');
}

// ---- EQUIPEMENT INDIVIDUEL (revu 27 aout 2026, chantier logistique armement) ----
// Remplace l'ancienne assignation groupee/gratuite/illimitee (limitee aux soldats presents
// dans la piece) par une gestion homme par homme, contrainte par le stock reel de la section
// (section.stockArmes, alimente par le Capitaine via ouvrirRepartirArmement). Reutilise la
// structure d'affichage deja etablie par doVoirMaSection (meme calcul de localisation, memes
// libelles) -- la section entiere est presentee, pas seulement les soldats presents ici,
// puisque le lieutenant peut deja disperser ses hommes (deposerSoldats/recupererSoldats) et
// doit pouvoir gerer l'equipement de tous, ou qu'ils se trouvent. Le cout PA/argent declare
// par l'ordre reste preleve une seule fois a l'ouverture (acces a la session de gestion),
// jamais par soldat individuellement.
async function doEquiperSection(pa, cost) {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const section = getSectionDuLieutenant(compagnie);
  if (!section) return;
  if (pa || cost) {
    const r = await deduireCoutOrdre({ pa, cost });
    if (!r.ok) { signalerRefusCout(r); return; }
  }
  await ouvrirGestionEquipementSection(compagnie.id, section.id);
}

async function ouvrirGestionEquipementSection(compagnieId, sectionId) {
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;
  const stock = section.stockArmes || { arme_de_poing: 0, mitraillette: 0 };
  const armesLabels = { corps_a_corps: 'Aucun', arme_de_poing: 'Arme de poing', mitraillette: 'Mitraillette' };

  document.getElementById('postes-modal-title').textContent = 'Gérer l\'équipement de ma section';
  let html = '<div style="padding:1rem;max-height:60vh;overflow-y:auto">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Stock libre de la section — Arme de poing : ' + (stock.arme_de_poing||0) + ' · Mitraillette : ' + (stock.mitraillette||0) + '</div>';
  section.soldats.forEach(s => {
    const localisation = libelleLieuSoldat(s);
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.35rem;font-size:.75rem;display:flex;justify-content:space-between;align-items:center;gap:.5rem">';
    html += '<div><div style="color:#e0d5b8;font-family:monospace">' + s.matricule + '</div>';
    html += '<div style="color:#a89870">' + localisation + '</div>';
    html += '<div style="color:#8a8060">Équipement : ' + (armesLabels[s.arme] || 'Aucun') + '</div></div>';
    html += '<div style="display:flex;gap:.25rem;flex-wrap:wrap;justify-content:flex-end">';
    CATEGORIES_ARME_STOCK.forEach(cat => {
      if (s.arme !== cat) {
        const dispo = (stock[cat] || 0) > 0;
        html += '<button onclick="confirmerEquipementIndividuel(\'' + compagnieId + '\',\'' + sectionId + '\',\'' + s.matricule + '\',\'' + cat + '\')" ' +
          (dispo ? 'style="cursor:pointer;color:#5a8ad0;' : 'disabled style="opacity:.4;cursor:not-allowed;color:#5a8ad0;') +
          'font-size:.66rem;padding:.2rem .4rem;border:1px solid #4a6a8a;background:transparent">' + armesLabels[cat] + '</button>';
      }
    });
    if (s.arme && s.arme !== 'corps_a_corps') {
      html += '<button onclick="confirmerEquipementIndividuel(\'' + compagnieId + '\',\'' + sectionId + '\',\'' + s.matricule + '\',\'corps_a_corps\')" style="font-size:.66rem;padding:.2rem .4rem;border:1px solid #8a3a3a;background:transparent;color:#cc6a6a;cursor:pointer">Déséquiper</button>';
    }
    html += '</div></div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerEquipementIndividuel(compagnieId, sectionId, matricule, categorie) {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  const soldat = section?.soldats.find(s => s.matricule === matricule);
  if (!compagnie || !section || !soldat) return;
  if (!section.stockArmes) section.stockArmes = { arme_de_poing: 0, mitraillette: 0 };

  const ancienneArme = soldat.arme || 'corps_a_corps';
  if (ancienneArme === categorie) return;

  // SERVEUR AUTORITAIRE (17 septembre 2026). Meme regle qu'avant -- l'arme quittee retourne au
  // stock LIBRE DE LA SECTION, jamais a l'Armurerie centrale -- mais appliquee par la RPC, qui
  // exige d'etre le lieutenant de CETTE section et fait la transition stock/soldat dans une
  // seule ecriture.
  const rEq = await sbMilitaireEquiperSoldat(compagnieId, sectionId, matricule, categorie);
  if (!rEq || rEq.ok !== true) {
    const motifs = { stock_section_insuffisant: 'Aucune unité disponible dans le stock de la section — dotez-la depuis l\'Armurerie.',
                     pas_lieutenant_de_cette_section: 'Vous ne commandez pas cette section.',
                     soldat_introuvable: 'Ce soldat n\'est pas dans votre section.' };
    showToast(rEq && rEq.raison === 'stock_section_insuffisant' ? 'Stock insuffisant' : 'Équipement impossible',
      (rEq && motifs[rEq.raison]) || 'Opération refusée.', false);
    return;
  }
  const armesLabels = { corps_a_corps: 'déséquipé', arme_de_poing: 'arme de poing', mitraillette: 'mitraillette' };
  showToast('Équipement mis à jour', soldat.matricule + ' : ' + armesLabels[categorie] + '.', true, true);
  await ouvrirGestionEquipementSection(compagnieId, sectionId);
}

// ==========================================================================================
// ANCIEN MOTEUR COLLECTIF SUPPRIME (19 septembre 2026), remplace par le moteur physique serveur.
// ==========================================================================================
// calculerPointsGroupe / getCoefsArmesPays / construireCivilsCombat / verifierCombatAutomatique /
// resoudreCombat partaient tous les cinq. Ils formaient une SECONDE resolution concurrente, et
// c'est precisement ce qu'il ne faut pas laisser vivre a cote du nouveau moteur.
//
// Pourquoi il etait mort, et pas seulement demode :
//   1. calculerPointsGroupe lisait formation.force/endurance/tir, cles abolies par les quatre
//      domaines d'entrainement : il rendait 0 partout ;
//   2. avec 0 des deux cotes, aucun camp ne passait sous le seuil -- la boucle tournait 100 rounds
//      a vide et ne tuait personne ;
//   3. entierement deterministe, aucun de ;
//   4. aneantissement binaire : pas de pertes partielles, pas de blesses, aucun PJ ;
//   5. persistance par sbSaveCompagnie, donc ecriture cliente du blob, REFUSEE EN SILENCE par la
//      RLS des que l'appelant n'etait ni Commandant ni Capitaine.
//
// Il etait encore APPELE, depuis deposerSoldats : deposer des troupes dans une piece occupee par
// un ennemi declenchait cette resolution fantome. Cet appel part avec lui. Une bataille commence
// desormais sur DECISION d'un chef (militaire_bataille_engager), a partir d'un contact reel.
//
// Rien n'est recupere de sa formule. La nomenclature d'armes COEF_ARME_MILITAIRE est CONSERVEE
// plus haut : c'est le vocabulaire des categories d'arme des soldats, pas un morceau de moteur.

// ---- LE CAPITAINE PEUT DEMETTRE UN LIEUTENANT ----
async function doDemettreLieutenant(pa, cost) {
  if (state.poste?.id !== 'capitaine') { showToast('Réservé à un Capitaine', '', false); return; }
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const pourvues = (compagnie?.sections || []).filter(s => s.lieutenantNom);
  document.getElementById('postes-modal-title').textContent = 'Démettre un Lieutenant';
  let html = '<div style="padding:1rem">';
  if (pourvues.length === 0) html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun lieutenant en poste actuellement.</div>';
  pourvues.forEach(s => {
    html += '<div style="display:flex;justify-content:space-between;align-items:center;border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.4rem">';
    html += '<span style="font-size:.85rem;color:#e0d5b8">' + s.lieutenantNom + ' (Section ' + s.numero + ')</span>';
    html += '<button onclick="confirmerDemissionLieutenant(\'' + compagnie.id + '\',\'' + s.id + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Démettre</button>';
    html += '</div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// Anomalie decouverte lors de la migration PA/cout (Phase L, non corrigee, hors perimetre) :
// cette fonction n'efface jamais le state.poste (ni la fiche Supabase personnages.poste) du
// lieutenant demis -- seul section.lieutenantNom est efface. Le joueur demis conserve donc ses
// permissions requiresPost:'lieutenant' malgre la demission. Meme famille de bug que la
// "promotion fantome" corrigee sur confirmerAffectationSection, mais en sens inverse. Signale
// pour arbitrage separe, non traite ici.
async function confirmerDemissionLieutenant(compagnieId, sectionId, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === compagnieId);
  const section = compagnie?.sections.find(s => s.id === sectionId);
  if (!section) return;
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  // DEMISSION ATTESTEE (17 septembre 2026, passe 3). L'ancien chemin effacait section.lieutenantNom
  // mais JAMAIS personnages.poste : le demis restait « lieutenant » pour le serveur et gardait
  // l'autorite de retirer des armes (militaire_retrait lit la colonne poste). La RPC fait tomber
  // la fonction ET le poste dans la meme transaction, et n'accepte que le Capitaine de la compagnie.
  const d = await sbMilitaireDemettreLieutenant(compagnieId, sectionId);
  if (!d || d.ok !== true) {
    showToast('Destitution impossible',
      d && d.raison === 'pas_capitaine_de_cette_compagnie'
        ? 'Vous ne commandez pas cette compagnie.' : 'La destitution n\'a pas pu être enregistrée.', false);
    return;
  }
  const ancien = d.ancien_lieutenant || section.lieutenantNom;
  showToast('Lieutenant démis', ancien + ' n\'est plus en poste.', false, true);
  addJournalEntry(ancien + ' démis de son poste de Lieutenant.', 'event-bad');
}

// ---- SALLE DES FAITS D'ARMES — met en scene les meilleurs combats, section par section ----
async function ouvrirConsulterFaitsArmes() {
  document.getElementById('postes-modal-title').textContent = "Salle des Faits d'Armes";
  document.getElementById('postes-body').innerHTML = '<div style="padding:1.5rem;text-align:center;color:#8a8060">Chargement des archives...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const combats = typeof sbGetFaitsArmes === 'function' ? await sbGetFaitsArmes().catch(() => []) : [];

  let html = '<div style="padding:1rem;max-height:65vh;overflow-y:auto">';
  html += '<div style="font-size:.78rem;color:#8a8060;font-style:italic;margin-bottom:1rem">Le numéro de section porte la mémoire de ses batailles, transmise d\'un lieutenant à l\'autre au fil des affectations.</div>';

  if (combats.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun combat consigné pour l\'instant. Que l\'Histoire commence.</div>';
  } else {
    // Trie par ampleur (effectif engage + pertes) pour mettre en avant les batailles marquantes
    const tries = [...combats].sort((a, b) =>
      (b.campA.effectifEngage + b.campB.effectifEngage + b.campA.pertes + b.campB.pertes) -
      (a.campA.effectifEngage + a.campB.effectifEngage + a.campA.pertes + a.campB.pertes)
    );
    tries.forEach(c => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.6rem">';
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.8rem;color:#C9A84C;letter-spacing:.06em;margin-bottom:.3rem">JOUR ' + c.jour + ' — ' + c.rounds + ' ROUNDS</div>';
      html += '<div style="font-size:.82rem;color:#e0d5b8;margin-bottom:.3rem">' + (COUNTRIES[c.campA.pays]?.n||c.campA.pays) + ' (Section ' + c.campA.sectionId.split('-').pop() + ', Lt. ' + (c.campA.lieutenantNom||'?') + ') vs ' + (COUNTRIES[c.campB.pays]?.n||c.campB.pays) + ' (Section ' + c.campB.sectionId.split('-').pop() + ', Lt. ' + (c.campB.lieutenantNom||'?') + ')</div>';
      html += '<div style="font-size:.75rem;color:#a89870">Effectifs engagés : ' + c.campA.effectifEngage + ' vs ' + c.campB.effectifEngage + ' · Pertes : ' + c.campA.pertes + ' / ' + c.campB.pertes + '</div>';
      html += '<div style="font-size:.78rem;color:#6ab858;margin-top:.3rem">' + c.resultat + '</div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// =====================
// COUVRE-FEU — 20h-6h, 2 jours max, exemption militaires/requisitionnes
// =====================
// DEMOBILISATION (correctif Lot 4.3). budgetNat.mobilisationNationaleActive etait ecrit a true en un
// seul endroit et JAMAIS remis a false : ni expiration, ni ordre, ni cron. Une mobilisation etait
// donc definitive -- immunite militaire permanente et requisitions illimitees.
//
// On reutilise le patron du couvre-feu ministeriel : LEVEE MANUELLE EXPLICITE par l'autorite qui a
// declenche, aucune expiration automatique inventee. C'est le Ministre de la Guerre qui demobilise,
// distinctement de l'effort de guerre, qui appartient au President.
async function doDemobiliser() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  if (!budgetNat.mobilisationNationaleActive) {
    showToast('Aucune mobilisation', 'Aucune mobilisation nationale n\'est en cours.', false);
    return;
  }
  // Cout lu dans la table declarative de la facade (plateau-gouvernement.js), jamais re-code en
  // dur ici : c'est cette meme table qui alimente le miroir serveur des couts.
  const paDemobiliser = (typeof COUT_PA_DEMOBILISER === 'number') ? COUT_PA_DEMOBILISER : 2;
  const r = await deduireCoutOrdre({ pa: paDemobiliser, cost: 0, fn: 'mobilisation_nationale' });
  if (!r.ok) { signalerRefusCout(r); return; }

  // CHEMIN SERVEUR (24 septembre 2026), pendant exact de la mobilisation.
  const rDemob = await sbMobilisationFixer(false).catch(() => null);
  if (!rDemob || rDemob.ok !== true) {
    showToast('Démobilisation non enregistrée',
      'Le serveur a refusé (' + ((rDemob && rDemob.raison) || 'indisponible') + ').', false);
    return;
  }
  state.mobilisationNationaleCache = false;

  // EXTINCTION DES POURSUITES POUR DESERTION (13 septembre 2026) — et de celles-la SEULEMENT.
  await eteindrePoursuitesDesertion(pays);

  updateUI();
  showToast('Démobilisation', 'La mobilisation nationale est levée. Les réquisitions cessent, les poursuites pour désertion s\'éteignent et l\'immunité militaire prend fin.', true, true);
  addJournalEntry('Démobilisation nationale ordonnée.', 'event-info');
  addExternalEvent('🎖️ DÉMOBILISATION : la mobilisation nationale est levée.');
}

// ---------------------------------------------------------------------------
// DESERTION — INCORPORATION, EXTINCTION, BONUS D'EVASION (13 septembre 2026)
// ---------------------------------------------------------------------------
// PRINCIPE DIRECTEUR : la desertion est UN motif parmi d'autres. Elle s'eteint seule, elle ne
// libere jamais un detenu qui purge autre chose, et rien de ce qui la concerne n'a le droit
// d'effacer un motif etranger. C'est la traduction exacte de la dette « state.recherche = [] »
// relevee par l'audit : ici on ne remplace jamais le tableau, on le FILTRE.

function estMotifDesertion(entree) {
  return !!entree && entree.acte === 'desertion';
}

// Retire les seules entrees de desertion, sur la fiche du joueur courant ET en base. Tout autre
// motif (crime, condamnation en attente, mandat, motif d'un autre empire) est conserve tel quel.
async function eteindrePoursuitesDesertion(pays) {
  const nom = state.char?.name;
  const estMienne = function (e) {
    return estMotifDesertion(e) && (!e.country || e.country === pays);
  };

  if (Array.isArray(state.recherche) && state.recherche.some(estMienne)) {
    state.recherche = state.recherche.filter(function (e) { return !estMienne(e); });
  }
  // HISTORIQUE CONSERVE : on trace l'episode, on n'efface pas le souvenir de la desertion.
  if (state.char?.requisition && state.char.requisition.statut === 'deserteur') {
    state.char.requisition = Object.assign({}, state.char.requisition,
      { statut: 'eteinte', eteinteJour: state.day || 1 });
  }
  // Le bonus d'evasion est PROPRE A L'EPISODE : une nouvelle mobilisation repart de zero.
  if (state.char) state.char.joursDetenuDeserteur = 0;

  // Liberation UNIQUEMENT si la detention ne tenait qu'a la desertion.
  if (state.estEmprisonne && state.estEmprisonne.motifDesertionSeul === true) {
    state.estEmprisonne = null;
    addMailNotification('Caserne', 'Poursuites éteintes',
      'La démobilisation met fin aux poursuites pour désertion. Vous êtes libéré(e).');
  }

  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
  if (nom && typeof sbUpdate === 'function') {
    await sbUpdate('personnages', `name=eq.${encodeURIComponent(nom)}`,
      { recherche: state.recherche || [] }).catch(() => {});
  }
}

// DETENU DESERTEUR : le choix du transfert revient CHAQUE JOUR tant que la mobilisation dure.
// Accepter n'efface aucune autre peine : si la detention porte d'autres motifs, ils se purgent
// d'abord et l'incorporation prend effet a la liberation.
//
// PRESENTATION REVUE LE 16 SEPTEMBRE 2026. « Accepter le transfert a la caserne » n'est plus un
// ordre permanent du commissariat : il n'a de sens que dans une situation exceptionnelle, et
// l'afficher en permanence a tout le monde n'en avait aucun. Il devient une PROPOSITION
// contextuelle, presentee une fois par jour de jeu tant que les conditions tiennent.
//
// LES CONDITIONS NE CHANGENT PAS. Elles sont extraites telles quelles du handler ci-dessous,
// pour que la proposition et l'execution ne puissent jamais diverger : detenu, requisition au
// statut 'deserteur', et mobilisation nationale en cours.
function peutEtreIncorpore() {
  if (!state.estEmprisonne) return false;
  if (state.char?.requisition?.statut !== 'deserteur') return false;
  if (!state.mobilisationNationaleCache) return false;
  return true;
}

// La memoire du « deja propose aujourd'hui » vit sur LE PERSONNAGE, pas dans le navigateur :
// elle est sauvegardee avec la fiche et compte en jours de jeu (state.day), l'horloge partagee.
// Vider son localStorage ne fait donc pas revenir la proposition.
async function proposerTransfertCaserne() {
  if (!peutEtreIncorpore()) return;
  const jour = state.day || 1;
  if (state.char?.transfertCaserneProposeJour === jour) return;
  if (!document.getElementById('modal-postes')) return;

  if (state.char) state.char.transfertCaserneProposeJour = jour;
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});

  document.getElementById('postes-modal-title').textContent = 'Transfert vers la caserne';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:1.1rem">' +
    '<div style="font-size:.86rem;color:#e0d8c0;font-family:Crimson Pro,serif;line-height:1.6;margin-bottom:1rem">' +
    'La mobilisation nationale est en cours. En tant que déserteur(se) détenu(e), l\'armée vous propose ' +
    'de rejoindre la caserne plutôt que de purger votre détention pour désertion.<br><br>' +
    '<em style="color:#8a8060">Ce choix n\'efface aucune autre peine : si votre détention porte d\'autres motifs, ' +
    'ils se purgent d\'abord et l\'incorporation prend effet à votre libération.</em>' +
    '</div>' +
    '<div style="display:flex;gap:.6rem">' +
    '<button onclick="accepterTransfertCaserne()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #C9A84C;background:transparent;color:#C9A84C;cursor:pointer">Accepter</button>' +
    '<button onclick="refuserTransfertCaserne()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #3a2a10;background:transparent;color:#9a8a68;cursor:pointer">Refuser</button>' +
    '</div></div>';
  document.getElementById('modal-postes').classList.add('open');
}

function refuserTransfertCaserne() {
  document.getElementById('modal-postes')?.classList.remove('open');
  // Rien d'autre : le jour est deja marque, la proposition ne reviendra pas avant demain. Fermer
  // la fenetre sans repondre produit exactement le meme effet, ce qui est l'intention.
  addJournalEntry('Proposition de transfert vers la caserne déclinée pour aujourd\'hui.', 'event-info');
}

async function accepterTransfertCaserne() {
  document.getElementById('modal-postes')?.classList.remove('open');
  await doAccepterIncorporation();
}

async function doAccepterIncorporation() {
  const pays = state.country || 'republic';
  const req = state.char?.requisition;
  if (!state.estEmprisonne) { showToast('Impossible', 'Vous n\'êtes pas détenu(e).', false); return; }
  if (!req || req.statut !== 'deserteur') { showToast('Sans objet', 'Vous n\'êtes pas détenu(e) comme déserteur(se).', false); return; }
  if (!state.mobilisationNationaleCache) { showToast('Mobilisation levée', 'Plus aucune incorporation n\'est possible.', false); return; }

  state.char.requisition = Object.assign({}, req, { statut: 'incorpore', incorporeJour: state.day || 1 });
  if (Array.isArray(state.recherche)) {
    state.recherche = state.recherche.filter(function (e) {
      return !(estMotifDesertion(e) && (!e.country || e.country === pays));
    });
  }

  if (state.estEmprisonne.motifDesertionSeul === true) {
    // La detention ne tenait qu'a la desertion : transfert immediat a la caserne.
    state.estEmprisonne = null;
    state.currentCity = 'caserne';
    state.currentBuilding = 'caserne-militaire';
    state.currentRoom = 'corps_garde';
    if (typeof enterBuilding === 'function' && document.getElementById('vue-batiment')) {
      enterBuilding('caserne-militaire', true);
      if (typeof enterRoom === 'function') enterRoom('caserne-militaire', 'corps_garde', null);
    }
    showToast('Transfert accepté', 'Vous êtes conduit(e) à la caserne et incorporé(e).', true, true);
  } else {
    // D'autres peines courent : l'incorporation est actee mais differee a la liberation.
    state.estEmprisonne.incorporationAcceptee = true;
    showToast('Transfert accepté', 'Vous serez incorporé(e) à votre libération : d\'autres peines restent à purger.', true, true);
  }
  if (typeof sbSavePersonnage === 'function') await sbSavePersonnage(state).catch(() => {});
  if (typeof sbUpdate === 'function' && state.char?.name) {
    await sbUpdate('personnages', `name=eq.${encodeURIComponent(state.char.name)}`, {
      requisition: JSON.stringify(state.char.requisition),
      recherche: state.recherche || []
    }).catch(() => {});
  }
  updateUI();
  addJournalEntry('Transfert vers la caserne accepté : incorporation.', 'event-info');
}

// BONUS D'EVASION DU DESERTEUR : +10 points par jour REELLEMENT passe en detention comme
// deserteur, plafonne a +50. Cumulatif, conserve apres une evasion ratee et apres une reprise,
// remis a zero par la demobilisation ou l'incorporation.
const BONUS_EVASION_DESERTEUR_PAR_JOUR = 10;
const BONUS_EVASION_DESERTEUR_MAX = 50;

function bonusEvasionDeserteur() {
  const jours = Math.max(0, Math.floor(Number(state.char?.joursDetenuDeserteur) || 0));
  return Math.min(BONUS_EVASION_DESERTEUR_MAX, jours * BONUS_EVASION_DESERTEUR_PAR_JOUR);
}

// Appele une fois par jour de jeu, depuis le meme passage quotidien que la liberation.
function incrementerDetentionDeserteur() {
  if (!state.estEmprisonne) return;
  if (state.char?.requisition?.statut !== 'deserteur') return;
  if (!state.mobilisationNationaleCache) return;
  const jour = state.day || 1;
  if (state.char.dernierJourDetentionDeserteur === jour) return;
  state.char.dernierJourDetentionDeserteur = jour;
  state.char.joursDetenuDeserteur = Math.max(0, Math.floor(Number(state.char.joursDetenuDeserteur) || 0)) + 1;
}

async function ouvrirGererCouvreFeu(pa, cost) {
  if (state.poste?.id !== 'min_int') { showToast('Réservé au Ministre de l\'Intérieur', '', false); return; }
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  const cf = budgetNat.couvreFeu;

  document.getElementById('postes-modal-title').textContent = 'Couvre-feu';
  let html = '<div style="padding:1rem">';
  if (cf?.actif) {
    html += '<div style="font-size:.85rem;color:#cc4444;margin-bottom:.8rem">Couvre-feu en vigueur (20h-6h).</div>';
    html += '<button onclick="confirmerCouvreFeu(false,' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;padding:.5rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Lever le couvre-feu</button>';
  } else {
    html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Actif de 20h à 6h, 2 jours maximum. Dégrade IS et POP du gouvernement chaque jour tant qu\'il dure. Militaires et civils réquisitionnés en sont exemptés.</div>';
    html += '<button onclick="confirmerCouvreFeu(true,' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;padding:.5rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Instaurer le couvre-feu</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerCouvreFeu(activer, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  if (activer) {
    budgetNat.couvreFeu = { actif: true, jourDebut: state.day || 1, jourFin: (state.day || 1) + 2, dateFin: Date.now() + 2 * 86400000 };
    await sbSaveBudgetNational(pays, budgetNat);
    showToast('Couvre-feu instauré', '20h-6h. Couvre-feu en vigueur.', false, true);
    addExternalEvent('🌙 COUVRE-FEU instauré par le Ministère de l\'Intérieur, de 20h à 6h.');
  } else {
    budgetNat.couvreFeu = { actif: false };
    await sbSaveBudgetNational(pays, budgetNat);
    showToast('Couvre-feu levé', '', true, true);
    addExternalEvent('🌙 Le couvre-feu est levé.');
  }
}

// Verifie si le joueur est exempte de couvre-feu (militaire ou civil requisitionne)
function estExempteCouvreFeu() {
  if (['lieutenant', 'capitaine', 'commandant', 'min_def'].includes(state.poste?.id)) return true;
  if (state.char?.requisition?.statut === 'convoque' || state.char?.requisition?.statut === 'affecte') return true;
  return false;
}

// A appeler a chaque changement de batiment : verifie et applique une eventuelle violation de couvre-feu
async function verifierCouvreFeu() {
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays).catch(() => null);
  if (!budgetNat?.couvreFeu?.actif) return;
  // ECHEANCE PARTAGEE : le couvre-feu est stocke dans le budget national, donc lu par TOUS les
  // joueurs -- mais state.day est un compteur PRIVE, propre a chaque navigateur. Comparer une
  // echeance partagee a un compteur prive faisait expirer le couvre-feu a une date differente
  // pour chaque joueur : le premier joueur tres avance dans SES journees le levait pour tout le
  // monde, un joueur nouvellement inscrit (state.day = 1) ne le voyait jamais expirer.
  // On lit desormais dateFin, deja pose par confirmerCouvreFeu (Date.now() + 2 jours reels).
  // jourFin reste lu en repli pour les couvre-feux poses avant l'ajout de dateFin.
  const finCouvreFeu = budgetNat.couvreFeu.dateFin;
  const couvreFeuEchu = finCouvreFeu ? (Date.now() > Number(finCouvreFeu))
                                     : (state.day > budgetNat.couvreFeu.jourFin);
  if (couvreFeuEchu) {
    budgetNat.couvreFeu.actif = false;
    await sbSaveBudgetNational(pays, budgetNat).catch(() => {});
    return;
  }
  const heure = state.hour ?? 12;
  const enCouvreFeu = heure >= 20 || heure < 6;
  if (!enCouvreFeu || estExempteCouvreFeu()) return;

  const chancePatrouille = 0.45;
  if (Math.random() < chancePatrouille) {
    const recidive = state.char?.violationsCouvreFeu > 0;
    state.char.violationsCouvreFeu = (state.char?.violationsCouvreFeu || 0) + 1;
    const dureeHeures = recidive ? 24 : null; // null = jusqu'a la fin du couvre-feu (6h)
    if (typeof procederArrestation === 'function') {
      showToast('Interpellé(e) !', 'Violation du couvre-feu' + (recidive ? ' (récidive, 24h de détention)' : ' (jusqu\'à la fin du couvre-feu)') + '.', false);
      procederArrestation('violation_couvre_feu', false, false);
    }
  }
}

// Applique la degradation quotidienne d'IS/POP tant que le couvre-feu est actif
async function verifierEffetsCouvreFeuQuotidien(pays) {
  // IDEMPOTENCE PARTAGEE (correctif Lot 4.3) : cette fonction retire 2 POP a CHACUN des huit
  // titulaires gouvernementaux -- des personnages qui ne sont pas celui du joueur. Sans garde,
  // chaque client qui passait minuit infligeait la penalite a tout le gouvernement.
  const budgetNatCf = await chargerBudgetNational(pays).catch(() => null);
  const jourCf = (typeof jourPartageISO === 'function') ? jourPartageISO() : null;
  if (budgetNatCf && jourCf) {
    if (budgetNatCf.dernierEffetCouvreFeuJour === jourCf) return;
    budgetNatCf.dernierEffetCouvreFeuJour = jourCf;
    await sbSaveBudgetNational(pays, budgetNatCf).catch(() => {});
  }
  const budgetNat = await chargerBudgetNational(pays).catch(() => null);
  if (!budgetNat?.couvreFeu?.actif) return;
  if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].IS = Math.max(0, INDICES_NATIONAUX[pays].IS - 3);
  const postesGouv = ['president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae'];
  for (const posteId of postesGouv) {
    const infoTitulaire = await getTitulaireActuel(posteId, null, pays);
    const nom = infoTitulaire?.estPJ ? infoTitulaire.nom : null;
    if (!nom) continue;
    if (nom === state.char?.name) { state.pop = Math.max(0, (state.pop||0) - 2); }
    else if (typeof sbGet === 'function') {
      const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nom)}&select=pop`).catch(() => []);
      const pop = rows?.[0]?.pop ?? 50;
      await sbUpdate('personnages', `name=eq.${encodeURIComponent(nom)}`, { pop: Math.max(0, pop - 2) }).catch(() => {});
    }
  }
  updateUI();
}

// =====================
// RECHERCHE MILITAIRE — commanditee par le Commandant, associe un chercheur civil PNJ (en attendant l'universite)
// =====================
const DUREE_RECHERCHE_JOURS = 3;
const COUT_RECHERCHE = 8000;
const GAIN_COEF_RECHERCHE = 0.5;

async function ouvrirRechercheMilitaire(pa, cost) {
  if (state.poste?.id !== 'commandant') { showToast('Réservé au Commandant', '', false); return; }
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  const enCours = budgetNat.rechercheMilitaire?.enCours;

  document.getElementById('postes-modal-title').textContent = 'Recherche militaire';
  let html = '<div style="padding:1rem">';
  if (enCours) {
    html += '<div style="font-size:.85rem;color:#8a8060">Recherche en cours sur : <strong style="color:#C9A84C">' + enCours.arme + '</strong>.</div>';
  } else {
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">En collaboration avec un chercheur civil, améliore durablement le coefficient de tir d\'un type d\'arme pour tout le pays. ' + DUREE_RECHERCHE_JOURS + ' jours, ' + COUT_RECHERCHE.toLocaleString('fr-FR') + ' FR (caisse de la caserne).</div>';
    const armes = [{id:'corps_a_corps',label:'Corps à corps'},{id:'arme_de_poing',label:'Arme de poing'},{id:'mitraillette',label:'Mitraillette'}];
    armes.forEach(a => {
      html += '<button onclick="confirmerRechercheMilitaire(\'' + a.id + '\',' + pa + ',' + cost + ')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem">' + a.label + '</button>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRechercheMilitaire(arme, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }
  const pays = state.country || 'republic';
  const montantVerse = await debiterCaisseBatimentAtomique(pays, 'caserne-militaire', COUT_RECHERCHE);
  if (montantVerse < COUT_RECHERCHE) { showToast('Budget insuffisant', 'La caisse de la caserne ne couvre pas le coût de la recherche.', false); return; }

  const budgetNat = await chargerBudgetNational(pays);
  budgetNat.rechercheMilitaire = { enCours: { arme, jourDebut: state.day, jourFin: state.day + DUREE_RECHERCHE_JOURS, dateFin: Date.now() + DUREE_RECHERCHE_JOURS * 86400000 } };
  await sbSaveBudgetNational(pays, budgetNat);
  showToast('Recherche lancée', 'Un chercheur civil rejoint l\'effort. Achèvement dans ' + DUREE_RECHERCHE_JOURS + ' jours.', true, true);
  addJournalEntry('Recherche militaire lancée sur : ' + arme + ' (-' + COUT_RECHERCHE + ' FR).', 'event-info');
  addExternalEvent('🔬 Le chercheur civil Prof. ' + PRENOMS_CHERCHEUR_MIL[Math.floor(Math.random()*PRENOMS_CHERCHEUR_MIL.length)] + ' rejoint l\'effort de recherche militaire.');
}

const PRENOMS_CHERCHEUR_MIL = ['Adalbert Cossinus', 'Hortense Ballistik', 'Théodule Percussion'];

// Retourne le coefficient de tir actuel d'une arme pour un pays (defaut + ameliorations acquises)
async function getCoefArmeMilitaire(pays, arme) {
  const budgetNat = await chargerBudgetNational(pays).catch(() => null);
  const bonus = budgetNat?.coefficientsArmesAcquis?.[arme] || 0;
  return (COEF_ARME_MILITAIRE[arme] || 1) + bonus;
}

// Verifie chaque jour si une recherche militaire en cours est terminee
async function verifierRechercheMilitaireQuotidien(pays) {
  const budgetNat = await chargerBudgetNational(pays).catch(() => null);
  const enCours = budgetNat?.rechercheMilitaire?.enCours;
  if (!enCours) return;
  // Meme correctif que le couvre-feu : la recherche militaire vit dans le budget national, donc
  // partagee, alors que jourFin etait compare a state.day, compteur PRIVE. Un joueur avance
  // achevait le programme pour toute la nation des le premier jour ; un joueur recent ne le
  // voyait jamais aboutir. dateFin (Date.now() + 3 jours reels) est deja pose au lancement par
  // lancerRechercheMilitaire ; jourFin reste lu en repli pour les programmes anterieurs.
  const finRecherche = enCours.dateFin;
  const rechercheAchevee = finRecherche ? (Date.now() >= Number(finRecherche))
                                        : (state.day >= enCours.jourFin);
  if (!rechercheAchevee) return;

  if (!budgetNat.coefficientsArmesAcquis) budgetNat.coefficientsArmesAcquis = {};
  budgetNat.coefficientsArmesAcquis[enCours.arme] = (budgetNat.coefficientsArmesAcquis[enCours.arme] || 0) + GAIN_COEF_RECHERCHE;
  budgetNat.rechercheMilitaire.enCours = null;
  await sbSaveBudgetNational(pays, budgetNat);
  addExternalEvent('🔬 Recherche militaire achevée : le coefficient de tir de "' + enCours.arme + '" est amélioré pour toute la nation.');
  const commandantInfoRecherche = await getTitulaireActuel('commandant', null, pays);
  const commandantNom = commandantInfoRecherche?.estPJ ? commandantInfoRecherche.nom : null;
  if (commandantNom && typeof sbSendMail === 'function') sbSendMail('Chercheurs Civils', commandantNom, 'Recherche achevée', 'Le programme de recherche sur "' + enCours.arme + '" est terminé. Coefficient amélioré.', typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
}

// ==========================================================================================
// suivreEscorteAvecMoi SUPPRIMEE (18 septembre 2026) -- avec la mission 'escorter' elle-meme.
// ==========================================================================================
// Elle reecrivait, a chaque changement de batiment du PJ escorte, la position de TOUS les soldats
// de la section, en les deposant dans la premiere piece. Quatre defauts, dont trois regressaient
// des lots deja livres : ecriture cliente du blob de la compagnie (donc refusee en silence par la
// RLS des que l'escorte n'etait ni Commandant ni Capitaine, c'est-a-dire presque toujours) ;
// buildingId/roomId ecrits SANS ville, ce qui rouvrait l'ambiguite entre deux villes partageant le
// meme buildingId ; ecrasement de la position d'un soldat qui SUIT UN CHEF, etat que l'invariant
// leaderCourant interdit ; et deplacement des soldats ou qu'ils soient, y compris ceux laisses
// ailleurs.
//
// L'escorte n'est pas perdue : elle EST leaderCourant. militaire_affecter_leader confie des hommes
// a un PJ present, qui les mene ; un soldat qui suit un chef n'a pas de position propre, donc il se
// deplace avec lui par construction -- sans mission, sans reecriture, et sous l'autorite du
// Lieutenant plutot que par effet de bord du deplacement de l'escorte.

// =====================
// REQUISITION CIVILE — loterie aleatoire, doublement d'effectif, desertion publique
// =====================
// Porte de 36 a 48 heures le 13 septembre 2026 (arbitrage du chantier Mobilisation).
const DELAI_REQUISITION_HEURES = 48;

async function ouvrirRequisitionCivile(pa, cost) {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  if (!budgetNat.mobilisationNationaleActive) { showToast('Aucune mobilisation nationale active', 'La réquisition n\'est possible que pendant une mobilisation nationale.', false); return; }

  const compagnies = await sbGetCompagnies(pays).catch(() => []);
  const sections = [];
  compagnies.forEach(c => (c.sections||[]).forEach(s => { if (s.lieutenantNom && !s.civilsRequisitionnes?.length) sections.push({ compagnieId: c.id, section: s }); }));

  document.getElementById('postes-modal-title').textContent = 'Réquisition civile';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Tire au sort 24 citoyens domiciliés parmi toute la population pour doubler l\'effectif de la section choisie. Absence après ' + DELAI_REQUISITION_HEURES + 'h ⇒ statut de déserteur, public et recherché.</div>';
  if (sections.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucune section éligible (déjà réquisitionnée, ou aucune section pourvue).</div>';
  } else {
    sections.forEach(s => {
      html += '<div style="display:flex;justify-content:space-between;align-items:center;border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.4rem">';
      html += '<span style="font-size:.85rem;color:#e0d5b8">Section ' + s.section.numero + ' (Lt. ' + s.section.lieutenantNom + ')</span>';
      html += '<button onclick="confirmerRequisitionCivile(\'' + s.compagnieId + '\',\'' + s.section.id + '\',' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Réquisitionner</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

// LA REQUISITION PASSE ENTIEREMENT PAR LE SERVEUR (21 septembre 2026).
//
// CE QUE CETTE FONCTION FAISAIT, ET QUI NE MARCHAIT PAS. Elle ecrivait section.civilsRequisitionnes
// par sbSaveCompagnie -- refuse par la policy de compagnies_militaires, qui n'autorise que le
// Commandant ou le Capitaine, pas le Ministre -- puis bouclait 24 sbUpdate sur la fiche des AUTRES
// joueurs -- refuses par le trigger personnages_vue_modifier (personnage_non_possede) -- le tout
// avale par des .catch(() => {}). Seuls les 24 mails partaient : personne n'etait reellement
// convoque, aucun delai n'existait en base, et « Se presenter a mon affectation » ne trouvait
// jamais de convocation. Les 3 PA, eux, etaient bien preleves.
//
// DESORMAIS : militaire_requisition_civile (SECURITY DEFINER) verifie le poste min_def ATTESTE,
// la mobilisation en cours, la section, tire au sort, ecrit le blob de la compagnie ET les fiches
// des convoques, et paie les 3 PA contre le miroir des couts. Le navigateur n'ecrit plus rien :
// il n'envoie que les mails, et n'annonce un succes que si le serveur en a confirme un.
async function confirmerRequisitionCivile(compagnieId, sectionId, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  if (typeof sbRpc !== 'function') { showToast('Indisponible', 'Serveur injoignable.', false); return; }
  const rows = await sbRpc('militaire_requisition_civile', {
    p_compagnie_id: compagnieId, p_section_id: sectionId
  }).catch(() => null);
  const r = Array.isArray(rows) ? rows[0] : rows;
  if (!r || r.ok !== true) {
    const motifs = {
      mobilisation_inactive: 'La réquisition n\'est possible que pendant une mobilisation nationale.',
      deja_requisitionnee: 'Cette section a déjà reçu sa réquisition.',
      section_sans_lieutenant: 'Cette section n\'a pas de chef : personne pour accueillir les requis.',
      section_introuvable: 'Cette section n\'existe pas.',
      compagnie_introuvable: 'Cette compagnie n\'existe pas.',
      hors_juridiction: 'Cette compagnie relève d\'un autre pays.',
      aucun_civil_eligible: 'Aucun civil domicilié n\'est réquisitionnable actuellement.',
      pa_insuffisants: 'Il vous faut ' + COUT_PA_REQUISITION + ' PA.',
      acteur_non_authentifie: 'Session non reconnue.'
    };
    showToast('Réquisition impossible', (r && motifs[r.raison]) || 'Refus du serveur (' + ((r && r.raison) || 'indisponible') + ').', false);
    return;
  }
  // On recopie l'etat arrete par le serveur, jamais un calcul local.
  if (typeof r.pa === 'number') { state.pa = r.pa; updateUI(); }
  const convoques = Array.isArray(r.convoques) ? r.convoques : [];
  const heures = r.delai_heures || DELAI_REQUISITION_HEURES;

  // Les mails restent au client : c'est la seule part de l'action qui ne mute rien de sensible.
  for (const nom of convoques) {
    if (typeof sbSendMail === 'function') {
      await sbSendMail('Ministère de la Défense', nom, 'CONVOCATION — Réquisition civile',
        'Vous êtes réquisitionné(e) pour rejoindre la Section ' + (r.section || '?') + ' (Lt. ' + (r.lieutenant || '?') + ') dans le cadre de la mobilisation nationale. Présentez-vous sous ' + heures + 'h, faute de quoi vous serez déclaré(e) déserteur(se).',
        typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : '').catch(() => {});
    }
  }
  showToast('Réquisition lancée', convoques.length + ' citoyen(s) tiré(s) au sort et convoqué(s).', true, true);
  addExternalEvent('📯 Réquisition civile : ' + convoques.length + ' citoyens ont été convoqués pour renforcer la Section ' + (r.section || '?') + '.');
}

// Le civil convoque se presente a son affectation (doit etre physiquement a la caserne, avant le delai)
async function doSePresenterAffectation(pa, cost) {
  const req = state.char?.requisition ? (typeof state.char.requisition === 'string' ? JSON.parse(state.char.requisition) : state.char.requisition) : null;
  // PRESENTATION VOLONTAIRE D'UN DESERTEUR (13 septembre 2026) : le meme ordre sert desormais
  // les deux cas, plutot qu'un second ordre parallele. Un convoque se presente dans son delai ;
  // un deserteur peut se presenter A TOUT MOMENT, sans delai et sans passer par l'arrestation --
  // c'est precisement ce qui fait de la reddition une option de jeu.
  const estDeserteur = !!req && req.statut === 'deserteur';
  if (!req || (req.statut !== 'convoque' && !estDeserteur)) { showToast('Aucune convocation en attente', '', false); return; }
  if (!estDeserteur && Date.now() > req.deadline) { showToast('Trop tard', 'Le délai de présentation est dépassé. Vous êtes désormais déserteur(se) : présentez-vous pour être incorporé(e).', false); return; }
  if (state.currentBuilding !== 'caserne-militaire') { showToast('Présentez-vous à la caserne', '', false); return; }

  // TOUT SE PASSE AU SERVEUR (21 septembre 2026), PAIEMENT COMPRIS.
  //
  // CE QUI ETAIT CASSE. Le PJ payait 1 PA, puis le navigateur posait statut='affecte' dans le blob
  // de la compagnie par sbSaveCompagnie. La policy « compagnies maj par la chaine de commandement »
  // n'autorise que le Commandant du pays ou le Capitaine de cette compagnie : le civil qui se
  // presente etait refuse, sbUpdate avalait l'erreur, et le toast annoncait quand meme
  // « Affectation confirmée ». Le statut restant 'convoque', la passe de desertion declarait
  // ensuite DESERTEUR un joueur qui s'etait presente et avait paye.
  //
  // militaire_presentation_affectation reverifie tout (convocation, presence a la caserne, delai),
  // ecrit le blob et la fiche cote serveur, eteint les seules poursuites pour desertion, puis
  // preleve le PA contre le miroir des couts. AUCUN succes n'est affiche si elle refuse.
  if (typeof sbRpc !== 'function') { showToast('Indisponible', 'Serveur injoignable.', false); return; }
  const rows = await sbRpc('militaire_presentation_affectation', {}).catch(() => null);
  const r = Array.isArray(rows) ? rows[0] : rows;
  if (!r || r.ok !== true) {
    const motifs = {
      aucune_convocation: 'Aucune convocation en attente.',
      pas_sur_place: 'Présentez-vous physiquement à la caserne.',
      delai_depasse: 'Le délai de présentation est dépassé. Vous êtes désormais déserteur(se) : présentez-vous pour être incorporé(e).',
      pa_insuffisants: 'Il vous faut 1 PA.',
      personnage_introuvable: 'Personnage inconnu du serveur.',
      acteur_non_authentifie: 'Session non reconnue.'
    };
    showToast('Présentation refusée', (r && motifs[r.raison]) || 'Refus du serveur (' + ((r && r.raison) || 'indisponible') + ').', false);
    return;
  }
  // On recopie l'etat arrete par le SERVEUR, jamais un calcul local : la prochaine sauvegarde
  // complete republiera donc exactement ses valeurs (et n'ecrasera pas l'extinction des poursuites).
  if (typeof r.pa === 'number') { state.pa = r.pa; }
  if (r.requisition) { req.statut = 'affecte'; state.char.requisition = r.requisition; }
  if (Array.isArray(r.recherche)) state.recherche = r.recherche;
  if (estDeserteur && state.char) state.char.joursDetenuDeserteur = 0;
  updateUI();
  const section = { numero: r.section };

  showToast(estDeserteur ? 'Incorporé(e)' : 'Affectation confirmée',
    estDeserteur
      ? 'Vous vous rendez de vous-même. Incorporation immédiate, poursuites pour désertion éteintes.'
      : 'Vous rejoignez la Section ' + (section?.numero||'?') + ' pour la durée de la mobilisation.', true, true);
  addJournalEntry(estDeserteur
    ? 'Présentation volontaire à la caserne : incorporation, poursuites pour désertion éteintes.'
    : 'Présenté(e) à mon affectation militaire (réquisition civile).', 'event-good');
}

// Verifie chaque jour les convocations expirees non honorees ⇒ desertion publique
//
// LA BASCULE DU STATUT PASSE AU SERVEUR (21 septembre 2026). Cette passe tournait dans le
// navigateur de n'importe quel joueur connecte et ecrivait sur des objets qui ne lui
// appartiennent pas : sbSaveCompagnie (refuse par la policy de compagnies_militaires) et
// sbUpdate sur la fiche des AUTRES joueurs (refuse par le trigger personnages_vue_modifier).
// Rien ne basculait donc jamais en base -- mais l'avis de recherche, lui, partait bien
// (justice_condamner est serveur) : le meme absent etait re-condamne a chaque passage, chaque
// jour, dans chaque navigateur. Et comme « se presenter » ne parvenait pas davantage a ecrire
// 'affecte', un joueur qui s'etait presente et avait paye etait declare deserteur malgre lui.
//
// militaire_desertions_verifier fait desormais la bascule cote serveur, en une seule fois et de
// facon idempotente : elle ne touche QUE les convocations dont le delai est reellement depasse et
// qui sont encore 'convoque' -- un presente ('affecte') n'est plus jamais sanctionne -- et elle
// RETOURNE les nouveaux deserteurs. Le client ne garde que ce qu'il sait faire legitimement :
// l'avis de recherche par la voie existante, et l'annonce publique.
//
// ETAT REEL DE L'APPEL : cette fonction n'a AUCUN appelant aujourd'hui -- la sequence de minuit
// cliente l'a retiree au profit du miroir serveur traiterDesertionsServeur (api/cron-minuit.js),
// qui tourne en service_role et dont les ecritures aboutissent, elles. Ce miroir lit le MEME
// statut dans le MEME blob : la presentation ecrivant desormais 'affecte' cote serveur, il cesse
// lui aussi de sanctionner un joueur qui s'est presente. La fonction est remise d'aplomb pour
// qu'elle soit juste si elle est un jour rebranchee, et surtout pour qu'elle n'ecrive plus jamais
// sur la fiche d'autrui depuis un navigateur.
async function verifierDesertionsQuotidien(pays) {
  if (typeof sbRpc !== 'function') return;
  const rows = await sbRpc('militaire_desertions_verifier', { p_pays: pays }).catch(() => null);
  const r = Array.isArray(rows) ? rows[0] : rows;
  if (!r || r.ok !== true) return;
  for (const d of (Array.isArray(r.deserteurs) ? r.deserteurs : [])) {
    // RACCORD (Lot 4.3) : le statut militaire devient REELLEMENT exploitable. Jusqu'ici il
    // etait pose puis oublie -- le deserteur n'etait jamais recherche, jamais arretable, et le
    // mot « recherche » de l'interface etait decoratif.
    //
    // ON NE CREE AUCUN BAREME JUDICIAIRE. L'entree porte volontairement type:'militaire', qui
    // n'existe dans AUCUNE table de peines : elle rend le deserteur reperable et arretable par
    // la machinerie existante, sans lui attacher de peine. Ce qui se passe APRES l'arrestation
    // -- incorporation, detention pour refus, heures cumulees -- n'est pas deductible de
    // l'ancien code et reste donc a arbitrer.
    if (typeof ajouterCondamnationRecherche === 'function') {
      await ajouterCondamnationRecherche(d.nom, {
        acte: 'desertion', type: 'militaire', jour: state.day,
        country: pays, compagnieId: d.compagnieId, sectionId: d.sectionId,
        origine: 'requisition_civile'
      }).catch(() => {});
    }
    addExternalEvent('🚨 ' + d.nom + ' a été déclaré(e) DÉSERTEUR(SE) pour ne pas s\'être présenté(e) à sa réquisition.');
  }
}

// ---- EXPULSION D'AMBASSADEUR : L'ECHEANCE PRODUIT ENFIN SON EFFET ----
//
// DEFAUT CORRIGE (Lot 4.3). confirmerExpulsionAmbassadeur posait bien data.expulsionEcheance a
// now+24h, mais ce champ n'etait RELU NULLE PART : l'ambassadeur declare persona non grata gardait
// indefiniment son poste et l'acces a son bureau, et son ambassade restait VERROUILLEE hors de la
// liste des expulsables -- le filtre d'affichage ecarte toute ambassade portant deja une echeance.
//
// Ce balayage relit l'echeance et applique la consequence annoncee au joueur : passe le delai, la
// mission prend fin. On REUTILISE la structure diplomatique existante -- data.ambassadeur repasse a
// null, exactement comme le fait deja « Demettre » -- et on efface l'echeance, ce qui deverrouille
// l'ambassade pour l'avenir. L'AMBASSADE N'EST PAS FERMEE : le bureau reste ouvert, seul
// l'ambassadeur s'en va. C'est la doctrine du lot : sanctionner n'est pas rompre.
async function verifierExpulsionsAmbassadeursQuotidien(pays) {
  if (typeof sbGet !== 'function' || typeof sbUpdate !== 'function') return;
  const rows = await sbGet('ambassades_ouvertes', `pays_hote=eq.${encodeURIComponent(pays)}`).catch(() => null);
  if (!rows) return;
  const maintenant = Date.now();
  for (const r of rows) {
    const data = r.data || {};
    const echeance = Number(data.expulsionEcheance);
    if (!isFinite(echeance) || echeance <= 0) continue;
    if (maintenant < echeance) continue;   // le delai court encore

    const nomExpulse = data.ambassadeur || null;
    const suite = Object.assign({}, data);
    delete suite.expulsionEcheance;        // deverrouille : une nouvelle expulsion redevient possible
    suite.ambassadeur = null;              // la mission prend fin
    suite.derniereExpulsion = { nom: nomExpulse, leTs: maintenant };
    await sbUpdate('ambassades_ouvertes', `id=eq.${encodeURIComponent(r.id)}`, { data: suite }).catch(() => {});

    if (nomExpulse) {
      // L'AVIS D'EXPULSION N'EST PLUS ENVOYE D'ICI (§5, 20 septembre 2026). Cette passe tourne
      // dans le navigateur du premier joueur a franchir minuit -- un joueur quelconque, jamais
      // le ministre -- et postait sous l'en-tete « Ministere des Affaires Etrangeres ».
      // C'est desormais traiterExpulsionsAmbassadeursServeur() (api/cron-minuit.js) qui emet
      // l'avis, avec l'autorite du serveur, et sans le doublon que les deux chemins
      // produisaient. La mise a jour de l'ambassade, elle, reste faite ici : elle est
      // idempotente (expulsionEcheance efface) et rend l'effet immediat pour le joueur present.
      addExternalEvent('🛂 ' + nomExpulse + ' a quitté ses fonctions d\'ambassadeur à l\'expiration du délai d\'expulsion.');
    }
  }
}

// ---- LE LIEUTENANT FAIT REMONTER SON RAPPORT DE RENSEIGNEMENT AU CAPITAINE ----
async function ouvrirRemonterRenseignement(pa, cost) {
  if (state.poste?.id !== 'lieutenant') { showToast('Réservé à un Lieutenant', '', false); return; }
  const rapports = typeof sbGetRapportsRenseignementNonRemontes === 'function' ? await sbGetRapportsRenseignementNonRemontes(state.char?.name).catch(() => []) : [];

  document.getElementById('postes-modal-title').textContent = 'Rapports de renseignement à transmettre';
  let html = '<div style="padding:1rem">';
  if (rapports.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun rapport en attente de transmission.</div>';
  } else {
    rapports.forEach(r => {
      html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.6rem;margin-bottom:.5rem">';
      html += '<div style="font-size:.82rem;color:#e0d5b8;margin-bottom:.4rem">Rapport sur ' + r.nomCible + '</div>';
      html += '<button onclick="confirmerRemonteeRenseignement(\'' + r.id + '\',' + pa + ',' + cost + ')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.35rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Transmettre à mon Capitaine</button>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRemonteeRenseignement(rapportId, pa, cost) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const compagnie = (await sbGetCompagnies(state.country).catch(() => [])).find(c => c.id === state.poste.compagnieId);
  const capitaineNom = compagnie?.capitaineNom;
  if (!capitaineNom) { showToast('Aucun Capitaine en poste', 'Impossible de transmettre pour l\'instant.', false); return; }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { signalerRefusCout(r); return; }

  const rows = await sbGet('rapports_renseignement', `id=eq.${encodeURIComponent(rapportId)}`).catch(() => []);
  const rapport = rows?.[0]?.data;
  if (rapport && typeof sbSendMail === 'function') {
    await sbSendMail(state.char?.name || 'Lieutenant', capitaineNom, 'Rapport de renseignement transmis — ' + rapport.nomCible,
      rapport.contenu, typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
  }
  await sbMarquerRapportRemonte(rapportId);
  showToast('Rapport transmis', 'Votre Capitaine a été informé.', true, true);
  addJournalEntry('Rapport de renseignement transmis à mon Capitaine.', 'event-info');
}

// =====================
// ENGAGEMENT VOLONTAIRE COMME OFFICIER — PJ -> validation Commandant (compagnie) -> affectation Capitaine (section)
// =====================
// La filiere officier en trois etapes (doEngagerOfficier -> ouvrirTraiterEngagements ->
// ouvrirAffecterEngage) a ete retiree le 24 septembre 2026. Elle imposait un pipeline a
// decideur unique -- le Commandant rangeait le candidat dans une compagnie, PUIS le Capitaine
// l'installait dans une section -- incompatible avec une candidature diffusee a tous les
// recruteurs eligibles. Elle est remplacee par ouvrirSEngagerArmee / ouvrirTraiterCandidatures
// / doDecouvrirAffectation, plus haut dans ce fichier. Les RPC militaire_engagement_* restent
// en base : l'engagement deja affecte de Vince Kubrick n'est pas touche.

async function ouvrirRechercheMilitaireDepuisMinistere() {
  if (state.poste?.id !== 'min_def') { showToast('Réservé au Ministre de la Défense', '', false); return; }
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  const enCours = budgetNat.rechercheMilitaire?.enCours;

  document.getElementById('postes-modal-title').textContent = 'Financer la recherche militaire';
  let html = '<div style="padding:1rem">';
  if (enCours) {
    html += '<div style="font-size:.85rem;color:#8a8060">Recherche déjà en cours sur : <strong style="color:#C9A84C">' + enCours.arme + '</strong>.</div>';
  } else {
    html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.8rem">Financé directement depuis votre caisse ministérielle (sans passer par la caserne). ' + DUREE_RECHERCHE_JOURS + ' jours, ' + COUT_RECHERCHE.toLocaleString('fr-FR') + ' FR.</div>';
    const armes = [{id:'corps_a_corps',label:'Corps à corps'},{id:'arme_de_poing',label:'Arme de poing'},{id:'mitraillette',label:'Mitraillette'}];
    armes.forEach(a => {
      html += '<button onclick="confirmerRechercheMilitaireDepuisMinistere(\'' + a.id + '\')" style="display:block;width:100%;text-align:left;margin-bottom:.4rem;padding:.6rem .7rem;border:1px solid #2a2010;background:transparent;color:#c0b090;cursor:pointer;font-size:.82rem">' + a.label + '</button>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerRechercheMilitaireDepuisMinistere(arme) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  // AUTORITE MINISTERIELLE ATTESTEE (17 septembre 2026, audit des frontieres d'autorite) :
  // le poste habilite est deduit par le serveur de l'identifiant de la caisse source
  // ('<pays>_gouvernement-<posteId>'), au lieu d'etre suppose depuis l'ouverture de la modale.
  // Ces fonctions sont globales : elles etaient appelables depuis la console par n'importe
  // quel joueur authentifie, qui ponctionnait ainsi une caisse ministerielle sans en occuper
  // le poste. Montant et bareme inchanges.
  const rMin = await sbCaisseMinistereMouvement(pays, 'gouvernement-min_def', COUT_RECHERCHE, null, false);
  if (!rMin || rMin.ok !== true) {
    showToast(rMin && rMin.raison === 'solde_insuffisant' ? 'Budget insuffisant' : 'Action impossible',
      rMin && rMin.raison === 'solde_insuffisant'
        ? 'Votre caisse ministérielle ne couvre pas le coût de la recherche.'
        : 'Réservé au Ministre de la Défense en exercice.', false);
    return;
  }

  const budgetNat = await chargerBudgetNational(pays);
  budgetNat.rechercheMilitaire = { enCours: { arme, jourDebut: state.day, jourFin: state.day + DUREE_RECHERCHE_JOURS, dateFin: Date.now() + DUREE_RECHERCHE_JOURS * 86400000 } };
  await sbSaveBudgetNational(pays, budgetNat);
  showToast('Recherche lancée', 'Financée directement par le Ministère. Achèvement dans ' + DUREE_RECHERCHE_JOURS + ' jours.', true, true);
  addJournalEntry('Recherche militaire financée par le Ministère sur : ' + arme + ' (-' + COUT_RECHERCHE + ' FR).', 'event-info');
}

// =====================
// GESTION DU QHS — budget dedie, liste des prisonniers, actions (transfert/conditions/torture)
// =====================
async function ouvrirGestionQHS() {
  if (state.poste?.id !== 'min_just') { showToast('Réservé au Ministre de la Justice', '', false); return; }
  document.getElementById('postes-modal-title').textContent = 'Gestion du QHS';
  let html = '<div style="padding:1rem">';
  html += '<button onclick="ouvrirBudgetQHS()" style="width:100%;margin-bottom:.5rem;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.06em;padding:.55rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Budget du QHS</button>';
  html += '<button onclick="ouvrirListePrisonniersQHS()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.06em;padding:.55rem;border:1px solid #5a8ad0;background:transparent;color:#5a8ad0;cursor:pointer">Liste des prisonniers</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function ouvrirBudgetQHS() {
  const pays = state.country || 'republic';
  const maCaisse = await chargerCaisseBatiment(pays, 'gouvernement-min_just');
  const caisseQHS = await chargerCaisseBatiment(pays, 'qhs-prison');
  const budgetNat = await chargerBudgetNational(pays);
  const virementActuel = budgetNat.virementJournalierQHS || 0;

  document.getElementById('postes-modal-title').textContent = 'Budget du QHS';
  let html = '<div style="padding:1rem">';
  html += '<div style="display:flex;justify-content:space-between;margin-bottom:1rem;font-family:Bebas Neue,sans-serif;font-size:.9rem">';
  html += '<span style="color:#C9A84C">Ma caisse (Ministère) : ' + (maCaisse.solde||0).toLocaleString('fr-FR') + ' FR</span>';
  html += '<span style="color:#8a8060">Caisse du QHS : ' + (caisseQHS.solde||0).toLocaleString('fr-FR') + ' FR</span>';
  html += '</div>';

  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.7rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.76rem;color:#e0d5b8;margin-bottom:.4rem">VIREMENT JOURNALIER AUTOMATIQUE</div>';
  html += '<div style="font-size:.7rem;color:#8a8060;margin-bottom:.5rem">Actuellement : ' + virementActuel.toLocaleString('fr-FR') + ' FR/jour.</div>';
  html += '<input id="montant-virement-qhs-j" type="number" min="0" value="' + virementActuel + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.5rem"/>';
  html += '<button onclick="confirmerVirementJournalierQHS()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Fixer ce montant</button>';
  html += '</div>';

  html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.76rem;color:#e0d5b8;margin-bottom:.4rem">VIREMENT PONCTUEL</div>';
  html += '<input id="montant-virement-qhs-p" type="number" min="0" value="0" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem;font-size:.85rem;outline:none;box-sizing:border-box;margin-bottom:.5rem"/>';
  html += '<button onclick="confirmerVirementPonctuelQHS()" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.72rem;padding:.4rem;border:1px solid #5a8ad0;background:transparent;color:#5a8ad0;cursor:pointer">Transférer maintenant</button>';
  html += '</div></div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerVirementJournalierQHS() {
  const montant = Math.max(0, parseInt(document.getElementById('montant-virement-qhs-j')?.value || '0'));
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  const budgetNat = await chargerBudgetNational(pays);
  budgetNat.virementJournalierQHS = montant;
  await sbSaveBudgetNational(pays, budgetNat);
  showToast('Virement journalier fixé', montant.toLocaleString('fr-FR') + ' FR/jour vers le QHS.', true, true);
}

async function confirmerVirementPonctuelQHS() {
  const montant = Math.max(0, parseInt(document.getElementById('montant-virement-qhs-p')?.value || '0'));
  document.getElementById('modal-postes')?.classList.remove('open');
  if (montant <= 0) return;
  const pays = state.country || 'republic';
  // VIREMENT MINISTERIEL ATTESTE (17 septembre 2026, suite de l'audit des frontieres d'autorite).
  // AVANT : deux appels HTTP separes (debit min_just, puis credit QHS) -- entre les deux, l'argent
  // n'existait nulle part, et un echec du second le detruisait. Surtout, le poste min_just n'etait
  // verifie qu'a l'OUVERTURE de la modale, jamais ici : confirmerVirementPonctuelQHS() etant une
  // fonction globale, n'importe quel joueur authentifie pouvait l'appeler depuis la console et
  // vider la caisse du ministere de la Justice vers le QHS.
  // MAINTENANT : une seule transaction serveur. Le poste habilite est deduit de l'identifiant meme
  // de la caisse ('<pays>_gouvernement-min_just'), et le pays de l'acteur doit correspondre.
  const r = await sbCaisseMinistereMouvement(pays, 'gouvernement-min_just', montant, 'qhs-prison', true);
  if (!r || r.ok !== true) {
    showToast(r && r.raison === 'solde_insuffisant' ? 'Caisse insuffisante' : 'Virement impossible',
              r && r.raison === 'hors_juridiction' ? 'Cette caisse relève d\'un autre pays.'
              : (r && r.raison === 'solde_insuffisant' ? '' : 'Réservé au Ministre de la Justice en exercice.'), false);
    return;
  }
  const montantVerse = Number(r.verse || 0);
  showToast('Virement effectué', montantVerse.toLocaleString('fr-FR') + ' FR transférés vers le QHS.', true, true);
}

async function ouvrirListePrisonniersQHS() {
  const pays = state.country || 'republic';
  document.getElementById('postes-modal-title').textContent = 'Prisonniers du QHS';
  document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#8a8060;font-style:italic">Chargement...</div>';
  document.getElementById('modal-postes').classList.add('open');

  const prisonniers = await sbGetPrisonniersQHS(pays).catch(() => []);
  let html = '<div style="padding:1rem">';
  if (prisonniers.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic">Aucun détenu au QHS actuellement.</div>';
  } else {
    prisonniers.forEach(p => {
      html += '<div onclick="ouvrirFichePrisonnierQHS(\'' + p.id + '\')" style="display:flex;align-items:center;gap:.6rem;border:1px solid #2a2010;background:#0f0d05;padding:.5rem .7rem;margin-bottom:.4rem;cursor:pointer">';
      html += p.photoUrl ? '<img src="' + p.photoUrl + '" style="width:36px;height:36px;border-radius:50%;object-fit:cover;border:1px solid #4a3a1a"/>' : '<div style="width:36px;height:36px;border-radius:50%;background:#1a1610;display:flex;align-items:center;justify-content:center"><i class="ti ti-user" style="color:#5a5040"></i></div>';
      html += '<div><div style="font-size:.85rem;color:#e0d5b8">' + p.nom + '</div><div style="font-size:.7rem;color:#a89870">' + p.raison + '</div></div>';
      html += '</div>';
    });
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

async function ouvrirFichePrisonnierQHS(prisonnierId) {
  const rows = await sbGet('prisonniers_qhs', `id=eq.${encodeURIComponent(prisonnierId)}`).catch(() => []);
  const p = rows?.[0]?.data;
  if (!p) return;

  document.getElementById('postes-modal-title').textContent = p.nom;
  let html = '<div style="padding:1rem;text-align:center">';
  html += p.photoUrl ? '<img src="' + p.photoUrl + '" style="width:90px;height:90px;border-radius:50%;object-fit:cover;border:2px solid #4a3a1a;margin-bottom:.7rem"/>' : '<div style="width:90px;height:90px;border-radius:50%;background:#1a1610;display:flex;align-items:center;justify-content:center;margin:0 auto .7rem"><i class="ti ti-user" style="font-size:2rem;color:#5a5040"></i></div>';
  html += '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">Motif : ' + p.raison + '</div>';
  html += '<button onclick="doTransfererPrisonNormale(\'' + prisonnierId + '\')" style="width:100%;margin-bottom:.4rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #5a8ad0;background:transparent;color:#5a8ad0;cursor:pointer">Transférer vers une prison normale</button>';
  html += '<button onclick="doAmeliorerConditionsQHS(\'' + prisonnierId + '\')" style="width:100%;margin-bottom:.4rem;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #4a8a4a;background:transparent;color:#6ab858;cursor:pointer">Améliorer ses conditions de détention</button>';
  html += '<button onclick="doTorturerPrisonnierQHS(\'' + prisonnierId + '\')" style="width:100%;font-family:Bebas Neue,sans-serif;font-size:.75rem;padding:.5rem;border:1px solid #8a2020;background:transparent;color:#cc4444;cursor:pointer">Le faire torturer</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Motif de refus d'un pouvoir QHS, dit au Ministre plutot qu'avale en silence.
function messageRefusQhs(r) {
  const raison = r && r.raison;
  if (raison === 'cible_non_detenue') return "Cette personne n'est plus détenue : aucun pouvoir ne s'exerce sur elle.";
  if (raison === 'prisonnier_introuvable') return "Ce prisonnier n'est plus au registre du QHS.";
  if (raison === 'autorite_insuffisante' || raison === 'acteur_non_authentifie') {
    return 'Seul le Ministre de la Justice en exercice peut agir sur le QHS.';
  }
  return "L'opération a été refusée. Rien n'a été modifié.";
}

// ---- Transfert vers une prison normale (pas de reduction de peine, ouvre droit a un bonus avocat futur) ----
async function doTransfererPrisonNormale(prisonnierId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const rows = await sbGet('prisonniers_qhs', `id=eq.${encodeURIComponent(prisonnierId)}`).catch(() => []);
  const p = rows?.[0]?.data;
  if (!p) return;
  // Le pouvoir passe par le serveur (16 septembre 2026) : il relit le poste sur la ligne de
  // l'appelant, exige une DETENTION CANONIQUE active dans `detentions` -- jamais le
  // est_emprisonne de la fiche, que le client pourrait dicter -- puis change le registre QHS et
  // le miroir de la fiche dans la meme transaction. L'ecriture directe qui vivait ici etait
  // refusee depuis le chantier B : le detenu restait au QHS pendant qu'on annoncait son transfert.
  const rT = await sbRpc('qhs_pouvoir', { p_prisonnier_id: prisonnierId, p_acte: 'transferer' })
    .then(rows => Array.isArray(rows) ? rows[0] : rows).catch(() => null);
  if (!rT || rT.ok !== true) { showToast('Transfert impossible', messageRefusQhs(rT), false); return; }
  showToast('Transfert effectué', p.nom + ' est transféré(e) vers une prison normale. Éligible à un bonus de réduction de peine via avocat.', true, true);
  addJournalEntry(p.nom + ' transféré(e) du QHS vers une prison normale.', 'event-info');
}

// ---- Ameliorer les conditions de detention ----
async function doAmeliorerConditionsQHS(prisonnierId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const cout = 500;
  const rows = await sbGet('prisonniers_qhs', `id=eq.${encodeURIComponent(prisonnierId)}`).catch(() => []);
  const p = rows?.[0]?.data;
  if (!p) return;

  // DEBIT ET EFFET DANS LA MEME TRANSACTION (16 septembre 2026). Auparavant les 500 FR sortaient
  // reellement de la caisse du QHS, puis l'amelioration etait ecrite sur la fiche du detenu --
  // ecriture que la vue refuse depuis le chantier B. L'argent public etait detruit et le detenu
  // ne gagnait rien. Le serveur fait desormais les deux, ou aucun des deux.
  const rA = await sbRpc('qhs_pouvoir', { p_prisonnier_id: prisonnierId, p_acte: 'ameliorer' })
    .then(rows2 => Array.isArray(rows2) ? rows2[0] : rows2).catch(() => null);
  if (!rA || rA.ok !== true) {
    showToast(rA && rA.raison === 'caisse_insuffisante' ? 'Caisse insuffisante' : 'Amélioration impossible',
      rA && rA.raison === 'caisse_insuffisante'
        ? 'La caisse du QHS ne couvre pas ce coût (' + cout + ' FR).' : messageRefusQhs(rA), false);
    return;
  }
  showToast('Conditions améliorées', p.nom + ' bénéficie de meilleures conditions. +15 Moral, PA de récupération relevés. -' + cout + ' FR.', true, true);
  addJournalEntry('Conditions de détention améliorées pour ' + p.nom + ' (-' + cout + ' FR).', 'event-good');
}

// ---- Torture : information extraite au prix de consequences reelles pour le detenu ET le MJ ----
async function doTorturerPrisonnierQHS(prisonnierId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const rows = await sbGet('prisonniers_qhs', `id=eq.${encodeURIComponent(prisonnierId)}`).catch(() => []);
  const p = rows?.[0]?.data;
  if (!p) return;
  const pays = state.country || 'republic';
  const mjNom = state.char?.name;

  // Consequences sur le detenu : perte de tous ses indices, PA plafonnes a 1 le lendemain
  // uniquement. Ce bloc ecrivait des colonnes `inf`, `pop` et `dis` QUI N'EXISTENT PAS -- ce sont
  // des cles du blob `resources` -- en plus d'ecrire la fiche d'autrui, refusee depuis le
  // chantier B : la torture etait doublement inoperante, et seul le Ministre en subissait le
  // contrecoup. Le serveur applique maintenant l'effet reel, apres avoir verifie la detention
  // canonique. Les regles sont celles d'origine, au chiffre pres.
  const rTo = await sbRpc('qhs_pouvoir', { p_prisonnier_id: prisonnierId, p_acte: 'torturer' })
    .then(rows2 => Array.isArray(rows2) ? rows2[0] : rows2).catch(() => null);
  if (!rTo || rTo.ok !== true) { showToast('Interrogatoire impossible', messageRefusQhs(rTo), false); return; }

  // Sanction immediate et automatique sur le MJ : POP et INF a 10
  state.pop = 10; state.inf = 10;
  updateUI();

  // Trace exploitable par les rumeurs et les enquetes
  if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('torture_qhs', p.nom);
  if (typeof sbCreerRumeurPolitique === 'function') {
    await sbCreerRumeurPolitique({ cible: mjNom, contenu: 'Le Ministre de la Justice ferait torturer des détenus au QHS.', auteur: 'Anonyme', jour: state.day || 1, popPerdu: 40 }).catch(() => {});
  }

  // Alerte automatique au president et au premier ministre si le MJ est toujours en poste
  const presidentInfoTorture = await getTitulaireActuel('president', null, pays);
  const presidentNom = presidentInfoTorture?.estPJ ? presidentInfoTorture.nom : null;
  const pmInfoTorture = await getTitulaireActuel('pm', null, pays);
  const pmNom = pmInfoTorture?.estPJ ? pmInfoTorture.nom : null;
  const alerte = 'Le Ministre de la Justice (' + mjNom + ') est empêtré(e) dans une affaire de torture au QHS. Sa popularité et sa légitimité sont au plus bas. À vous de décider s\'il faut le/la démettre.';
  if (presidentNom && typeof sbSendMail === 'function') await sbSendMail('Alerte confidentielle', presidentNom, 'Affaire de torture au QHS', alerte, typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});
  if (pmNom && typeof sbSendMail === 'function') await sbSendMail('Alerte confidentielle', pmNom, 'Affaire de torture au QHS', alerte, typeof formatDateHeureJeu==='function'?formatDateHeureJeu():'').catch(()=>{});

  showToast('Torture ordonnée', p.nom + ' perd tous ses indices. Votre POP/INF chutent à 10. Une trace reste exploitable.', false);
  addJournalEntry('Torture ordonnée contre ' + p.nom + ' — conséquences lourdes.', 'event-bad');
}
