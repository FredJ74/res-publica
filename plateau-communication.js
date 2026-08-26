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
  try {
    const mails = await sbGetMailsFor(nom);
    const nonLus = (mails || []).filter(m => !m.read && m.to_player === nom).length;
    const badge = document.getElementById('mail-badge');
    if (badge) {
      if (nonLus > 0) {
        badge.textContent = nonLus;
        badge.style.display = 'inline';
      } else {
        badge.style.display = 'none';
      }
    }
    // Mettre à jour le titre de la page
    if (nonLus > 0) {
      document.title = '(' + nonLus + ') Res Publica';
    } else {
      document.title = 'Res Publica';
    }
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
async function ouvrirModalImprimerTracts(pa, cost) {
  const contacts = state.contacts || [];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Faire imprimer des tracts';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">150 ' + cur + ' par lot de 10 tracts.</div>';

  if (state.currentBuilding === 'la-tribune' && typeof sbGetBatimentEtat === 'function') {
    const etat = await sbGetBatimentEtat(state.country, 'capitale', 'la-tribune');
    const stockBois = etat.imprimerie?.stockBois || 0;
    html += '<div style="font-size:.76rem;color:' + (stockBois > 0 ? '#8a8060' : '#cc5540') + ';margin-bottom:.8rem"><i class="ti ti-trees" style="font-size:.75rem"></i> Stock de bois de Gustave : ' + stockBois + '</div>';
  }

  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Repertoire vide. Ajoutez des contacts pour cibler un PJ.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">TYPE DE TRACT</div>';
    html += '<div style="display:flex;gap:.5rem;margin-bottom:.7rem">';
    html += '<button id="tract-type-pour" onclick="selectTractType(\'pour\')" style="flex:1;padding:.4rem;border:1px solid #4a8a4a;background:#0a1008;color:#6a9a6a;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em">POUR un PJ</button>';
    html += '<button id="tract-type-contre" onclick="selectTractType(\'contre\')" style="flex:1;padding:.4rem;border:1px solid #2a2010;background:#0f0d05;color:#5a5040;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em">CONTRE un PJ</button>';
    html += '</div>';

    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
    html += '<select id="tract-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.7rem">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
    html += '</select>';

    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">QUANTITE</div>';
    html += '<select id="tract-quantite" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    [10,20,50,100].forEach(q => {
      const cout = q / 10 * 150;
      html += '<option value="' + q + '">' + q + ' tracts — ' + cout + ' ' + cur + '</option>';
    });
    html += '</select>';

    html += '<button onclick="confirmerImpression(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Commander</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  // Selectionner "pour" par defaut
  window._tractType = 'pour';
}

function selectTractType(type) {
  window._tractType = type;
  const btnPour = document.getElementById('tract-type-pour');
  const btnContre = document.getElementById('tract-type-contre');
  if (type === 'pour') {
    btnPour.style.cssText = 'flex:1;padding:.4rem;border:1px solid #4a8a4a;background:#0a1808;color:#6a9a6a;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
    btnContre.style.cssText = 'flex:1;padding:.4rem;border:1px solid #2a2010;background:#0f0d05;color:#5a5040;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
  } else {
    btnPour.style.cssText = 'flex:1;padding:.4rem;border:1px solid #2a2010;background:#0f0d05;color:#5a5040;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
    btnContre.style.cssText = 'flex:1;padding:.4rem;border:1px solid #8a2020;background:#1a0808;color:#9a4a4a;cursor:pointer;font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em';
  }
}

async function confirmerImpression(pa, cost) {
  const type = window._tractType || 'pour';
  const cible = document.getElementById('tract-cible')?.value;
  const quantite = parseInt(document.getElementById('tract-quantite')?.value || '10');
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cout = quantite / 10 * 150;
  const nbLots = quantite / 10;

  if (state.arg < cout) {
    showToast('Fonds insuffisants', 'Il vous faut ' + cout + ' ' + cur, false);
    return;
  }

  // A La Tribune (Luthecia) : Gustave a besoin de bois pour imprimer. Recette dynamique -
  // ne consomme jamais plus de 50% du prix du lot (150 FR) en valeur de bois, quel que soit
  // le cours actuel du bois a l'entrepot. Rien n'est debite si le stock manque.
  let etatImprimerie = null, boisParLot = 0;
  if (state.currentBuilding === 'la-tribune' && typeof sbGetBatimentEtat === 'function') {
    const etatEntrepot = await sbGetBatimentEtat(state.country, 'capitale', 'entrepot-logistique-luthecia');
    const stockBoisEntrepot = etatEntrepot.entrepot?.stock?.bois || 0;
    const prixBoisPourGustave = (typeof getPrixRessource === 'function' ? getPrixRessource('bois', stockBoisEntrepot) : 5) * 1.10;
    boisParLot = Math.max(1, Math.floor(75 / prixBoisPourGustave)); // 75 FR = 50% de 150 FR/lot

    etatImprimerie = await sbGetBatimentEtat(state.country, 'capitale', 'la-tribune');
    const stockBois = etatImprimerie.imprimerie?.stockBois || 0;
    const boisNecessaire = boisParLot * nbLots;
    if (stockBois < boisNecessaire) {
      document.getElementById('modal-postes')?.classList.remove('open');
      showToast('Gustave manque de bois', 'Il me faudrait ' + boisNecessaire + ' bois pour ce lot, il ne m\'en reste que ' + stockBois + '. Vous auriez du bois à me vendre ?', false);
      return;
    }
  }

  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  document.getElementById('modal-postes').classList.remove('open');
  state.arg -= cout;
  if (!state.inventory) state.inventory = [];

  // Chercher si un lot similaire existe deja
  const existing = state.inventory.find(i => i.type === 'tract' && i.cible === cible && i.tractType === type);
  if (existing) {
    existing.quantite += quantite;
  } else {
    state.inventory.push({
      type: 'tract',
      name: 'Tracts ' + (type === 'pour' ? 'POUR' : 'CONTRE') + ' ' + cible,
      icon: 'ti-file-description',
      tractType: type,
      cible: cible,
      quantite: quantite,
      legal: true
    });
  }

  if (etatImprimerie) {
    const boisConsomme = boisParLot * nbLots;
    etatImprimerie.imprimerie = {
      ...(etatImprimerie.imprimerie || {}),
      stockBois: (etatImprimerie.imprimerie?.stockBois || 0) - boisConsomme,
      caisse: (etatImprimerie.imprimerie?.caisse || 0) + cout
    };
    if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, 'capitale', 'la-tribune', etatImprimerie).catch(() => {});
  }

  updateUI();
  showToast('Tracts imprimes !', quantite + ' tracts ' + type + ' ' + cible + ' ajoutes a votre inventaire. -' + cout + ' ' + cur, true, true);
  addJournalEntry('Production de ' + quantite + ' tracts ' + type + ' ' + cible, 'event-info');
}

// =====================
// IMPRIMERIE PSM — TRACTS ELECTORAUX / TRACTS CALOMNIEUX (lot du 24 aout 2026)
// =====================
// Fn dediees et propres a PSM (imprimer_tracts_electoraux/imprimer_tracts_calomnieux),
// distinctes de imprimer_tracts/imprimer_clandestin utilises par la-tribune (Luthecia/
// Montrouge, ouvrirModalImprimerTracts/confirmerImpression ci-dessus, NON touches) : aucun
// risque de regression sur ces deux villes. Cout reel des deux ordres : 1 PA + bois pris dans
// le stock personnel du joueur (stackKey 'bois', meme lot que confirmerVendreBoisImprimerie plus
// bas dans le fichier) -- pas de caisse/stock institutionnel comme Gustave, pas de
// batiments_etat. Quantite de bois par lot volontairement simple/non optimisee (decision
// explicite : "ce n'est pas le sujet").
const BOIS_PAR_LOT_TRACTS_PSM = 1;

function stockBoisPersonnel() {
  const lot = (state.inventory || []).find(i => i.stackKey === 'bois' && (i.qty || 0) > 0);
  return { lot, qte: lot?.qty || 0 };
}

// --- Tract electoral (accueil_imprimerie) ---
// Arbitrage du 24 aout 2026 : le vrai moteur electoral (CYCLES_ELECTORAUX/votesPNJ) ne connait
// qu'un vote POUR un candidat nomme, jamais de vote "contre" ni de score negatif. Le tract
// electoral est donc EXCLUSIVEMENT en faveur de la cible choisie -- aucun choix pour/contre
// propose ici. La fonction hostile (nuire a une cible) est desormais entierement portee par le
// tract calomnieux (voir plus bas). La cible est restreinte aux candidats reellement en
// campagne (listerCandidatsElectorauxActifs, plateau-politique.js) pour garantir qu'un tract
// imprime soit toujours distribuable dans le vrai systeme.
function ouvrirModalImprimerTractsElectoraux(pa, cost) {
  const candidats = (typeof listerCandidatsElectorauxActifs === 'function') ? listerCandidatsElectorauxActifs() : [];
  const { qte: stockBois } = stockBoisPersonnel();
  document.getElementById('postes-modal-title').textContent = 'Imprimer des tracts électoraux';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">1 PA + ' + BOIS_PAR_LOT_TRACTS_PSM + ' bois pour un lot de 10 tracts, en faveur du candidat choisi.</div>';
  html += '<div style="font-size:.76rem;color:' + (stockBois >= BOIS_PAR_LOT_TRACTS_PSM ? '#8a8060' : '#cc5540') + ';margin-bottom:.8rem"><i class="ti ti-trees" style="font-size:.75rem"></i> Bois en stock personnel : ' + stockBois + '</div>';
  if (candidats.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Aucun candidat en campagne actuellement.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CANDIDAT SOUTENU</div>';
    html += '<select id="tract-electoral-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    candidats.forEach((c, idx) => { html += '<option value="' + idx + '">' + c.nom + '</option>'; });
    html += '</select>';
    html += '<button onclick="confirmerImprimerTractsElectoraux(' + pa + ',' + cost + ')" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Imprimer 10 tracts</button>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
  window._candidatsElectorauxActifs = candidats;
}

async function confirmerImprimerTractsElectoraux(pa, cost) {
  const idx = parseInt(document.getElementById('tract-electoral-cible')?.value ?? '-1');
  const candidat = (window._candidatsElectorauxActifs || [])[idx];
  if (!candidat) { showToast('Aucun candidat', '', false); return; }

  const { lot, qte } = stockBoisPersonnel();
  if (qte < BOIS_PAR_LOT_TRACTS_PSM) {
    showToast('Pas assez de bois', 'Il faut ' + BOIS_PAR_LOT_TRACTS_PSM + ' bois en stock personnel pour ce lot.', false);
    return;
  }

  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  lot.qty -= BOIS_PAR_LOT_TRACTS_PSM;
  if (lot.qty <= 0) state.inventory = state.inventory.filter(i => i !== lot);

  if (!state.inventory) state.inventory = [];
  const existing = state.inventory.find(i => i.type === 'tract' && i.cible === candidat.nom && i.tractType === 'pour');
  if (existing) {
    existing.quantite = (existing.quantite || 0) + 10;
  } else {
    state.inventory.push({ type: 'tract', name: 'Tracts POUR ' + candidat.nom, icon: 'ti-file-description', tractType: 'pour', cible: candidat.nom, quantite: 10, legal: true, electionPosteId: candidat.posteId, electionCity: candidat.city });
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Tracts imprimés !', '10 tracts en faveur de ' + candidat.nom + ' ajoutés à votre inventaire.', true, true);
  addJournalEntry('Impression de 10 tracts électoraux en faveur de ' + candidat.nom + '.', 'event-info');
}

// --- Tract calomnieux (atelier) ---
// Cible libre dans le repertoire (comme l'ancien imprimer_tracts) : contrairement au tract
// electoral, il n'y a pas de notion de "candidat en campagne" a respecter, la calomnie visant a
// nuire a la POP d'une cible quelconque, pas a fausser un vote. Reutilise checkDetection/
// ACTES_ILLEGAUX['imprimer_tracts_calomnieux'] (plateau-core.js, cle renommee a l'identique
// depuis l'ancienne imprimer_clandestin) -- meme mecanisme de detection qu'ailleurs, aucun
// systeme parallele.
function ouvrirModalImprimerTractsCalomnieux(pa, cost) {
  const contacts = state.contacts || [];
  const { qte: stockBois } = stockBoisPersonnel();
  document.getElementById('postes-modal-title').textContent = 'Imprimer des tracts calomnieux';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">1 PA + ' + BOIS_PAR_LOT_TRACTS_PSM + ' bois pour un lot de 10 tracts calomnieux (illégal).</div>';
  html += '<div style="font-size:.76rem;color:' + (stockBois >= BOIS_PAR_LOT_TRACTS_PSM ? '#8a8060' : '#cc5540') + ';margin-bottom:.8rem"><i class="ti ti-trees" style="font-size:.75rem"></i> Bois en stock personnel : ' + stockBois + '</div>';
  if (contacts.length === 0) {
    html += '<div style="font-size:.85rem;color:#8a8060">Repertoire vide. Ajoutez des contacts pour cibler un PJ.</div>';
  } else {
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.4rem">CIBLE</div>';
    html += '<select id="tract-calomnieux-cible" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;margin-bottom:.8rem">';
    contacts.forEach(c => { html += '<option value="' + c.name + '">' + c.name + '</option>'; });
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

  const { lot, qte } = stockBoisPersonnel();
  if (qte < BOIS_PAR_LOT_TRACTS_PSM) {
    showToast('Pas assez de bois', 'Il faut ' + BOIS_PAR_LOT_TRACTS_PSM + ' bois en stock personnel pour ce lot.', false);
    return;
  }

  const r = await deduireCoutOrdre({ pa, cost: 0 });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }

  lot.qty -= BOIS_PAR_LOT_TRACTS_PSM;
  if (lot.qty <= 0) state.inventory = state.inventory.filter(i => i !== lot);

  if (!state.inventory) state.inventory = [];
  const existing = state.inventory.find(i => i.type === 'tract_calomnieux' && i.cible === cible);
  if (existing) {
    existing.quantite = (existing.quantite || 0) + 10;
  } else {
    state.inventory.push({ type: 'tract_calomnieux', name: 'Tracts calomnieux contre ' + cible, icon: 'ti-alert-triangle', cible: cible, quantite: 10, legal: false });
  }

  document.getElementById('modal-postes')?.classList.remove('open');
  updateUI();
  showToast('Tracts imprimés !', '10 tracts calomnieux contre ' + cible + ' ajoutés à votre inventaire (illégal).', true, true);
  addJournalEntry('Impression clandestine de 10 tracts calomnieux contre ' + cible + '.', 'event-info');
  if (typeof checkDetection === 'function') checkDetection('imprimer_tracts_calomnieux', 'success');
}

// Verifie les objets recus (dons d'un autre joueur, reellement persistes via
// sbDonnerObjetJoueur) et les ajoute a l'inventaire local. Meme rythme que les mails.
async function verifierObjetsRecus() {
  if (typeof sbGetObjetsRecus !== 'function' || !state.char?.name) return;
  try {
    const objets = await sbGetObjetsRecus(state.char.name);
    if (!objets || objets.length === 0) return;

    for (const { id, expediteur, objet } of objets) {
      const qteAjoutee = typeof addToInventory === 'function' ? addToInventory(objet) : 0;
      if (qteAjoutee > 0) {
        if (typeof sbSupprimerObjetRecu === 'function') await sbSupprimerObjetRecu(id).catch(() => {});
        // Carte postale (Lot 4, 23 aout 2026) : message fixe, jamais de nom d'expediteur ni de
        // contenu du message a l'arrivee (point 10 du cahier des charges) -- l'expediteur et le
        // texte ne sont reveles qu'a la lecture volontaire (lireCartePostale, plateau-
        // personnage.js). Aucun Moral ici : le seul declencheur de Moral est la premiere lecture.
        if (objet.familleProduitMarche === 'carte_postale') {
          if (typeof showToast === 'function') showToast('Courrier reçu', 'Une carte postale est arrivée dans votre inventaire.', true, true);
          if (typeof addJournalEntry === 'function') addJournalEntry('Vous avez reçu une carte postale. Elle a été placée dans votre inventaire.', 'event-good');
        } else {
          if (typeof showToast === 'function') showToast('Objet reçu !', expediteur + ' vous a donné "' + objet.name + '".', true, true);
          if (typeof addJournalEntry === 'function') addJournalEntry(expediteur + ' vous a donné "' + objet.name + '".', 'event-good');
        }
      }
      // Si l'inventaire est plein (qteAjoutee === 0), l'objet reste en attente en base et
      // sera propose de nouveau au prochain passage, une fois de la place liberee.
    }
  } catch(e) {}
}

function donnerTracts(pjName) {
  const tracts = (state.inventory||[]).filter(i => i.type === 'tract');
  if (tracts.length === 0) {
    showToast('Aucun tract', 'Vous n\'avez pas de tracts en inventaire.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Donner des tracts a ' + pjName;
  let html = '<div style="padding:1rem">';
  tracts.forEach((t, idx) => {
    html += '<div style="border:1px solid #2a2010;background:#0f0d05;padding:.7rem;margin-bottom:.5rem">';
    html += '<div style="font-size:.82rem;color:#c0b090;margin-bottom:.4rem">' + t.name + ' <span style="color:#C9A84C">(' + t.quantite + ' restants)</span></div>';
    html += '<div style="display:flex;align-items:center;gap:.5rem">';
    html += '<input id="don-tract-' + idx + '" type="number" min="1" max="' + t.quantite + '" value="1" style="width:60px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.3rem;font-size:.82rem;outline:none">';
    html += '<button onclick="confirmerDonTracts(' + idx + ',\'' + pjName + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.08em;padding:.3rem .6rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Donner</button>';
    html += '</div></div>';
  });
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function confirmerDonTracts(tractIdx, pjName) {
  const tracts = (state.inventory||[]).filter(i => i.type === 'tract');
  const tract = tracts[tractIdx];
  if (!tract) return;
  const quantite = parseInt(document.getElementById('don-tract-' + tractIdx)?.value || '1');
  if (quantite < 1 || quantite > tract.quantite) {
    showToast('Quantite invalide', 'Entre 1 et ' + tract.quantite, false);
    return;
  }
  document.getElementById('modal-postes').classList.remove('open');
  tract.quantite -= quantite;
  if (tract.quantite <= 0) {
    const i = state.inventory.indexOf(tract);
    state.inventory.splice(i, 1);
  }

  // Ajouter au PJ simule si applicable
  const pjSim = state.pjSimules?.find(p => p.name === pjName);
  if (pjSim) {
    if (!pjSim.inventory) pjSim.inventory = [];
    const existing = pjSim.inventory.find(i => i.type === 'tract' && i.cible === tract.cible && i.tractType === tract.tractType);
    if (existing) { existing.quantite += quantite; }
    else { pjSim.inventory.push({...tract, quantite}); }
  }

  updateUI();
  showToast('Tracts donnes', quantite + ' tracts remis a ' + pjName + '.', true);
  addJournalEntry('Don de ' + quantite + ' tracts a ' + pjName, 'event-info');
}

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

// --- Electoral : 1 tract -> 1 PNJ, vrai vote ---
// N'accepte que tractType:'pour' (24 aout 2026, correctif) : un ancien tract tractType:'contre'
// (imprime avant ce lot, quand un choix pour/contre existait encore) ne doit JAMAIS devenir
// silencieusement un vote pour sa cible -- son sens hostile d'origine reste correctement porte
// par l'ancien circuit du marche (distribuer_tract/confirmerDistribuerTract, plateau-pnj.js,
// non touche : sbAjusterPopJoueur(cible, -delta) inchange). Ce circuit-ci ne fait que refuser
// poliment de les traiter, avec message explicite, plutot que de les ignorer silencieusement.
function distribuerTractElectoralPNJ(pnjName) {
  const tracts = (state.inventory || []).filter(i => i.type === 'tract' && i.origineQuete !== 'jean_lou' && i.tractType === 'pour' && (i.quantite || 0) > 0);
  if (tracts.length === 0) {
    const tractsContreAnciens = (state.inventory || []).filter(i => i.type === 'tract' && i.origineQuete !== 'jean_lou' && i.tractType === 'contre' && (i.quantite || 0) > 0);
    if (tractsContreAnciens.length > 0) {
      showToast('Ancien format', 'Vos tracts "contre" (ancien format) ne se distribuent pas ici. Utilisez "Distribuer un tract" au marché, circuit inchangé pour ces tracts.', false);
    } else {
      showToast('Aucun tract', 'Vous n\'avez pas de tract électoral en inventaire.', false);
    }
    return;
  }
  if (tracts.length === 1) {
    confirmerDistribuerTractElectoral(tracts[0].cible, pnjName);
    return;
  }
  document.getElementById('postes-modal-title').textContent = 'Distribuer un tract électoral à ' + pnjName;
  let html = '<div style="padding:.8rem 1rem">';
  html += '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Choisissez le candidat à soutenir aupres de ' + pnjName + '.</div>';
  html += tracts.map(t =>
    '<div onclick="confirmerDistribuerTractElectoral(\'' + t.cible.replace(/'/g, '') + '\',\'' + pnjName + '\')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\'#1a1005\'" onmouseout="this.style.background=\'#0f0d05\'">' +
      '<i class="ti ti-file-description" style="font-size:.9rem;color:#6a9a6a"></i>' +
      '<div><div style="font-size:.82rem;color:#c0b090">Pour ' + t.cible + '</div>' +
      '<div style="font-size:.85rem;color:#9a8a68">' + t.quantite + ' restants</div></div>' +
    '</div>'
  ).join('');
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerDistribuerTractElectoral(cible, pnjName) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const tract = (state.inventory || []).find(i => i.type === 'tract' && i.origineQuete !== 'jean_lou' && i.tractType === 'pour' && i.cible === cible && (i.quantite || 0) > 0);
  if (!tract) { showToast('Lot épuisé', 'Ce lot de tracts n\'est plus disponible.', false); return; }

  // Resolution de l'election reelle AVANT toute consommation (tract.electionPosteId/City poses
  // a l'impression ne sont qu'une trace -- toujours re-resolus ici pour couvrir aussi les tracts
  // legacy imprimes avant ce lot).
  const election = (typeof trouverElectionParCandidat === 'function') ? trouverElectionParCandidat(cible) : null;
  if (!election) {
    showToast('Élection introuvable', cible + ' n\'est candidat(e) à aucune élection en cours.', false);
    return;
  }
  const cle = (typeof getCleCycle === 'function') ? getCleCycle(election.posteId, election.city) : election.posteId;
  const cycle = (typeof CYCLES_ELECTORAUX !== 'undefined') ? CYCLES_ELECTORAUX[election.country]?.[cle] : null;
  if (!cycle) { showToast('Élection introuvable', '', false); return; }

  // Garde-fou explicite AVANT consommation (regle du 24 aout 2026) : un PNJ deja vote ne peut
  // plus recevoir de tract electoral -- refus avant tract consomme et avant tout effet.
  if (cycle.votesPNJ && cycle.votesPNJ[pnjName]) {
    showToast('Déjà convaincu', pnjName + ' a déjà voté pour cette élection.', false);
    return;
  }

  // Consommation (1 tract, succes ou echec) -- meme convention que confirmerDistribuerTract.
  tract.quantite -= 1;
  if (tract.quantite <= 0) state.inventory = state.inventory.filter(i => i !== tract);

  // Meme formule que distribuerTractJeanLou (plateau-pnj.js) : 50% + INF/10, plafonne 80%.
  const bonusInf = Math.floor((state.inf || 0) / 10);
  const taux = Math.min(80, 50 + bonusInf);
  const roll = Math.floor(Math.random() * 100) + 1;
  const succes = roll <= taux;

  if (succes) {
    const ok = (typeof enregistrerVotePNJ === 'function') ? await enregistrerVotePNJ(election.country, election.posteId, election.city, pnjName, cible) : false;
    if (ok) {
      showToast('Tract distribué !', pnjName + ' est convaincu(e) et votera pour ' + cible + '.', true, true);
      addJournalEntry('Tract électoral distribué à ' + pnjName + ' — vote enregistré pour ' + cible + '.', 'event-good');
    } else {
      // Deja vote entre-temps (course concurrente improbable) -- tract tout de meme consomme.
      showToast('Déjà convaincu', pnjName + ' avait déjà voté.', false);
      addJournalEntry('Tract électoral distribué à ' + pnjName + ' — déjà voté.', '');
    }
  } else {
    showToast('Sans effet', pnjName + ' n\'a pas été convaincu(e). Tract consommé.', false);
    addJournalEntry('Distribution de tract électoral à ' + pnjName + ' — sans effet.', '');
  }
  updateUI();
}

// --- Calomnieux : 1 tract -> 1 PNJ, -5 POP sur la cible, risque penal a l'echec critique ---
function distribuerTractCalomnieuxPNJ(pnjName) {
  const tracts = (state.inventory || []).filter(i => i.type === 'tract_calomnieux' && (i.quantite || 0) > 0);
  if (tracts.length === 0) {
    showToast('Aucun tract', 'Vous n\'avez pas de tract calomnieux en inventaire.', false);
    return;
  }
  if (tracts.length === 1) {
    confirmerDistribuerTractCalomnieux(tracts[0].cible, pnjName);
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

// Seuils utilises (24 aout 2026, corrige au meme jour : 10% exactement, pas 25%) : reussite =
// meme formule que le tract electoral (50% + INF/10, plafonne 80%), taux de reussite general
// inchange. En cas d'echec (100-taux), 10% exactement de ces echecs sont "critiques" (flagrant
// delit), les 90% restants "simples" (sans consequence).
async function confirmerDistribuerTractCalomnieux(cible, pnjName) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const tract = (state.inventory || []).find(i => i.type === 'tract_calomnieux' && i.cible === cible && (i.quantite || 0) > 0);
  if (!tract) { showToast('Lot épuisé', 'Ce lot de tracts n\'est plus disponible.', false); return; }

  tract.quantite -= 1;
  if (tract.quantite <= 0) state.inventory = state.inventory.filter(i => i !== tract);

  const bonusInf = Math.floor((state.inf || 0) / 10);
  const taux = Math.min(80, 50 + bonusInf);
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    // Reussite : -5 POP reel et persistant sur la cible.
    if (typeof sbAjusterPopJoueur === 'function') sbAjusterPopJoueur(cible, -5).catch(() => {});
    showToast('Tract distribué !', pnjName + ' relaie la calomnie. -5 POP pour ' + cible + '.', true, true);
    addJournalEntry('Tract calomnieux distribué à ' + pnjName + ' — succès. -5 POP pour ' + cible + '.', 'event-good');
  } else {
    const rollCritique = Math.floor(Math.random() * 100) + 1;
    const critique = rollCritique <= 10;
    if (critique) {
      // Echec critique : destruction de TOUS les tracts calomnieux detenus + 1 jour de
      // detention. Reutilise directement l'architecture existante (state.estEmprisonne, meme
      // forme que procederArrestation) plutot que cette derniere : celle-ci calculerait 2 jours
      // via PEINES.delit_mineur (pas 1) et ouvrirait un choix corruption/fuite/resistance non
      // souhaite ici (flagrant delit, sanction immediate et non negociable).
      state.inventory = (state.inventory || []).filter(i => i.type !== 'tract_calomnieux');
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
        state.estEmprisonne = { jours: 1, jourFin: (state.day || 1) + 1, raison: 'Distribution de tracts calomnieux' };
        if (typeof enregistrerDetention === 'function') {
          enregistrerDetention(state.char?.name, 'Distribution de tracts calomnieux', (state.day || 1) + 1, undefined, state.currentCity, {
            country: state.country,
            motifs: [{ type: 'Distribution de tracts calomnieux', jour_fait: state.day, city: state.currentCity, jours: 1, source: 'flagrant_delit' }]
          }).catch(() => {});
        }
        showToast('Flagrant délit !', pnjName + ' alerte immédiatement la police. Tous vos tracts calomnieux sont détruits. 1 jour de détention.', false, true);
        addJournalEntry('Distribution de tract calomnieux à ' + pnjName + ' — échec critique. Tracts calomnieux détruits, 1 jour de détention.', 'event-bad');
      }
    } else {
      showToast('Sans effet', pnjName + ' n\'a pas été convaincu(e). Tract consommé.', false);
      addJournalEntry('Distribution de tract calomnieux à ' + pnjName + ' — sans effet.', '');
    }
  }
  updateUI();
}

async function doLogePortail(pa, cost) {
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
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

function calculerResultatElection(election) {
  if (!election || !election.candidats) return;
  const total = election.candidats.reduce((s, c) => s + (c.voix||0), 0) || 1;
  // Ajouter voix PNJ pour simulation realiste
  election.candidats.forEach(c => {
    if (!c.isPJ) c.voix = (c.voix||0) + Math.floor(Math.random() * 200 + 50);
  });
  const sorted = [...election.candidats].sort((a,b) => (b.voix||0) - (a.voix||0));
  const totalFinal = sorted.reduce((s,c) => s + (c.voix||0), 0);
  const premier = sorted[0];
  const pct = Math.round((premier.voix||0) / totalFinal * 100);

  if (pct > 50) {
    // Elu au premier tour
    election.phase = 'termine';
    election.resultat = { elu: premier.nom, pct, tour: 1 };
    addExternalEvent('ELECTION : ' + premier.nom + ' elu(e) au 1er tour avec ' + pct + '% des voix (' + election.nom + ')');
    addMailNotification('Commission Electorale', 'Resultats election : ' + election.nom, premier.nom + ' est elu(e) avec ' + pct + '% des voix. Mandat de 5 semaines.');
  } else {
    // Second tour entre les 2 premiers
    const deuxieme = sorted[1];
    election.tour = 2;
    election.phase = 'campagne';
    election.candidats = [sorted[0], sorted[1]].map(c => ({...c, voix: 0}));
    election.jourResultat = election.jourResultat + 7;
    addExternalEvent('ELECTION : Aucun candidat n\'a la majorite. Second tour entre ' + premier.nom + ' et ' + deuxieme.nom);
    addMailNotification('Commission Electorale', '2eme tour — ' + election.nom, 'Aucun candidat n\'a obtenu la majorite absolue. Second tour entre ' + premier.nom + ' et ' + deuxieme.nom + '.');
  }
}

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

  // Partager via Supabase — scope 'local' = visible uniquement dans la ville courante, sinon national
  if (typeof sbAddEvenementGlobal === 'function') {
    const city = scope === 'local' ? (state.currentCity || null) : null;
    sbAddEvenementGlobal(state.country || 'republic', city, text, state.day || 1).catch(() => {});
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
    let total = 0;
    for (const don of dons) {
      total += don.montant;
      if (typeof sbMarquerDonTraite === 'function') await sbMarquerDonTraite(don.id).catch(() => {});
    }
    if (total > 0) {
      state.arg = (state.arg || 0) + total;
      updateUI();
      addJournalEntry('💰 Vous avez reçu ' + total + ' ' + cur + ' en dons.', 'event-good');
      showToast('Dons reçus !', '+' + total + ' ' + cur + ' crédité(s) sur votre compte.', true, true);
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
              transfereOk = vol.voleur && typeof sbDonnerObjetJoueur === 'function'
                ? await sbDonnerObjetJoueur({ name: stack.name, icon: stack.icon, stackable: true, stackKey: vol.objet_id, qty: perte }, vol.voleur, 'Butin de vol').then(() => true).catch(() => false)
                : false;
              if (transfereOk && typeof sbUpdate === 'function') {
                await sbUpdate('vols_en_attente', `id=eq.${encodeURIComponent(vol.id)}`, { type_butin: 'matiere_confirmee' }).catch(() => {});
              }
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
            transfereOk = vol.voleur && typeof sbDonnerObjetJoueur === 'function'
              ? await sbDonnerObjetJoueur({ ...state.inventory[idx] }, vol.voleur, 'Butin de vol').then(() => true).catch(() => false)
              : false;
            if (transfereOk && typeof sbUpdate === 'function') {
              await sbUpdate('vols_en_attente', `id=eq.${encodeURIComponent(vol.id)}`, { type_butin: 'objet_confirme' }).catch(() => {});
            }
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
      }
      if (imp.indice === 'poison_start') {
        state.empoisonnement = { actif: true, palier: imp.palier, poisonType: imp.poisonType };
        if (!state.statsAffaiblies) state.statsAffaiblies = {};
        (imp.statsTouchees || []).forEach(s => { state.statsAffaiblies[s] = true; });
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
function appliquerRegenerationNaturelle() {
  if (!state.regenJour) return;
  if ((state.hp || 0) >= 100) { state.regenJour = null; return; }
  state.hp = Math.min(100, (state.hp || 0) + 10);
  if (state.hp >= 100) state.regenJour = null;
  addJournalEntry('Régénération naturelle : +10 PV. PV actuels : ' + state.hp + '.', 'event-info');
}

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
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
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
    html += '<div style="display:flex;justify-content:space-between"><span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + d.nom + (d.qhs ? ' <span style="color:#8a3a2a">(QHS)</span>' : '') + '</span><span style="font-size:.7rem;color:#5a4030">' + annee + ' · ' + duree + '</span></div>';
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
  const modeFinLabels = { purgee: 'Peine purgée', anticipee_avocat: 'Libération anticipée (avocat)', evasion: 'Évasion', transfert_qhs: 'Transfert au QHS' };
  const estUneLiberation = { purgee: true, anticipee_avocat: true, evasion: false, transfert_qhs: false };
  let statutTexte, statutCouleur;
  if (d.mode_fin && modeFinLabels[d.mode_fin]) {
    statutTexte = modeFinLabels[d.mode_fin];
    statutCouleur = d.mode_fin === 'evasion' ? '#cc4444' : (d.mode_fin === 'transfert_qhs' ? '#9a8a4a' : '#6a9a6a');
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

  if (d.qhs) html += '<div style="font-size:.78rem;color:#8a3a2a;margin-top:.3rem">Détention en QHS (haute sécurité)</div>';
  html += '</div>';

  if (d.detention_precedente_id) {
    html += '<div style="font-size:.7rem;color:#6a5a30;margin-top:.5rem;font-style:italic">Fait suite à une détention antérieure interrompue.</div>';
  }

  html += '<button class="pnj-action-btn" onclick="enigme1RevenirResultatsArchives()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Retour aux résultats</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}

// Notification mail simple
function addMailNotification(from, subject, body) {
  if (!state.mails) state.mails = [];
  state.mails.push({ from, subject, body, day: state.day, time: formatDateHeureJeu(), read: false });
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
function renderJodieInterviewForm() {
  if (!window._jodieInterviewReponses) window._jodieInterviewReponses = ['', '', '', '', ''];
  let html = '<div class="forum-header-bar">' +
    '<button class="forum-back-btn" onclick="mailView=\'inbox\';document.getElementById(\'forum-main\').innerHTML=renderForumContent()"><i class="ti ti-arrow-left"></i> Retour</button>' +
    '<div class="forum-title-main" style="flex:1">Interview avec Jodie Moitout</div>' +
    '</div>';
  html += '<div style="padding:.8rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:1rem">Jodie prend des notes. Répondez avec vos mots — c\'est ce qui fera un bon portrait.</div>';
  JODIE_QUESTIONS_INTERVIEW.forEach((q, i) => {
    html += '<div class="forum-field" style="margin-bottom:.8rem">';
    html += '<label class="forum-field-label">' + (i + 1) + '. ' + escapeHtmlText(q) + '</label>';
    html += '<textarea id="jodie-reponse-' + i + '" rows="3" maxlength="500" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem .6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:vertical;box-sizing:border-box" oninput="window._jodieInterviewReponses[' + i + ']=this.value">' + escapeHtmlText(window._jodieInterviewReponses[i] || '') + '</textarea>';
    html += '</div>';
  });
  html += '<button class="forum-new-btn" onclick="jodiePortraitGenererApercu()"><i class="ti ti-feather"></i> Envoyer mes réponses à Jodie</button>';
  html += '</div>';
  return html;
}

// Validation (aucun envoi vide, section 4 du lot) puis generation IA du portrait -- reutilise
// TEL QUEL le mecanisme deja en production pour Jeremy (queteAccueilGenererReponseMailJeremy(),
// plateau-quete-accueil.js : meme endpoint /api/chat, meme construction de prompt en texte libre
// avec echappement des guillemets du joueur, meme lecture data.content[0].text, meme reponse de
// repli en cas d'echec) -- aucun second moteur IA construit ici. On ne fournit au modele QUE les
// 5 reponses et le nom du PJ, jamais d'autre donnee de personnage (aucun fait invente en dehors
// des reponses fournies).
async function jodiePortraitGenererApercu() {
  const reponses = (window._jodieInterviewReponses || []).map(r => (r || '').trim());
  if (reponses.some(r => !r)) {
    showToast('Réponses incomplètes', 'Merci de répondre à chacune des 5 questions.', false);
    return;
  }
  const nom = state.char?.name || '';
  document.getElementById('forum-main').innerHTML = '<div style="padding:2rem;text-align:center;color:#8a8060">Jodie rédige...</div>';

  const prompt = "Tu es Jodie Moitout, journaliste micro-trottoir pour le journal L'Autruche Entravee (groupe La Tribune), dans le jeu Res Publica. Le pays s'appelle Républia, avec un accent aigu sur le e (jamais \"Republia\" sans accent). " +
    "Tu viens d'interviewer " + nom + ", un nouvel habitant, en lui posant 5 questions. Voici ses reponses :\n\n" +
    JODIE_QUESTIONS_INTERVIEW.map((q, i) => (i + 1) + ". " + q + "\nReponse : \"" + reponses[i].replace(/"/g, "'") + "\"").join("\n\n") + "\n\n" +
    "Redige un COURT portrait journalistique (120 a 200 mots), a la troisieme personne, dans un ton enjoue et un peu malicieux, fidele aux reponses fournies SANS inventer de faits substantiels supplementaires sur " + nom + ". Pas de titre (il sera ajoute separement). " +
    "Texte BRUT uniquement, sans aucune mise en forme Markdown : pas d'astérisque (ni simple * pour l'italique, ni double ** pour le gras), pas de dièse # en début de ligne, pas de liste à puces. La ponctuation française normale reste bienvenue (guillemets « », tirets, points de suspension). " +
    "Reponds UNIQUEMENT avec le texte de l'article, sans introduction ni commentaire.";

  let texte = null;
  try {
    // Modele corrige le 21 aout 2026 : 'claude-sonnet-4-20250514' (mai 2025) est desormais
    // retire par Anthropic (confirme en production, HTTP 404 not_found_error) -- remplace par
    // 'claude-haiku-4-5-20251001', deja utilise et fonctionnel ailleurs dans le jeu (plateau-pnj.js).
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 500, messages: [{ role: 'user', content: prompt }] })
    });
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    const data = await resp.json();
    texte = data.content?.[0]?.text || null;
  } catch (e) { texte = null; }

  if (!texte) {
    showToast('Indisponible', "Jodie n'arrive pas à mettre ses idées en ordre pour le moment. Réessayez plus tard.", false);
    mailView = 'jodie-interview';
    document.getElementById('forum-main').innerHTML = renderForumContent();
    return;
  }

  // Nettoyage defensif AVANT stockage (audit du 21 aout 2026) : un seul point d'ecriture de
  // window._jodiePortraitTexte dans toute cette fonction -- l'apercu (renderJodiePortraitPreview)
  // et la publication (jodiePortraitPublier) le relisent tel quel, jamais recalcule ni renettoye
  // separement : impossible d'avoir une version nettoyee a l'ecran et une version brute publiee.
  window._jodiePortraitTexte = jodieNettoyerMarkdown(texte);
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

// Publication reelle -- appelle DIRECTEMENT sbCreateTopic()/sbCreatePost() (supabase.js), jamais
// showNewTopicForm()/submitComposeCanvas() (forum.js, chemin UI reserve aux PJ dont
// career==='press') : ces primitives elles-memes n'imposent AUCUNE restriction de career (verifie
// avant implementation), la restriction n'existe que cote UI joueur -- rester entierement en
// dehors de ce chemin UI garantit de ne jamais l'affaiblir pour les joueurs ordinaires.
// author:'Jodie Moitout' explicitement fige EN DUR ici, jamais state.char?.name -- c'est
// precisement le bug (faux auteur PJ sur un article systeme) que ce lot doit ne jamais reproduire.
// Second controle anti-republication juste avant l'ecriture (le premier a lieu a l'ouverture de
// l'interview, jodiePortraitOuvrirInterview() ci-dessus) : aucune fenetre ou l'interview aurait pu
// se derouler entierement sans jamais reverifier avant l'ecriture definitive.
async function jodiePortraitPublier() {
  const nom = state.char?.name || '';
  const titre = JODIE_PORTRAIT_TITRE_PREFIXE + nom;
  const texte = window._jodiePortraitTexte;
  if (!texte) { showToast('Erreur', 'Aucun portrait à publier.', false); return; }

  if (await jodiePortraitDejaPublie(nom)) {
    showToast('Déjà publié', 'Ce portrait a déjà été publié.', false);
    mailView = 'inbox'; document.getElementById('forum-main').innerHTML = renderForumContent();
    return;
  }

  if (typeof sbCreateTopic !== 'function' || typeof sbCreatePost !== 'function') {
    showToast('Indisponible', "La publication n'a pas pu être enregistrée. Réessayez plus tard.", false);
    return;
  }
  const time = typeof formatDateHeureJeu === 'function' ? formatDateHeureJeu() : new Date().toISOString();
  // NOTE (limite preexistante, signalee et non corrigee ici -- hors perimetre de ce lot) :
  // sbCreateTopic() renvoie TOUJOURS un id genere localement, meme si l'ecriture Supabase
  // sous-jacente echoue reellement (defaut deja identifie et explicitement laisse hors perimetre
  // par un correctif anterieur, commit 458c334) -- ce controle est donc best-effort, comme pour
  // tous les autres appelants existants de cette primitive. sbCreatePost(), en revanche, renvoie
  // bien null sur un echec reel (verifie ici explicitement, pas seulement via .catch() qui ne
  // couvrirait qu'un rejet, jamais un retour null resolu) : le texte de l'article est le contenu
  // reellement visible du portrait, sa perte silencieuse serait le defaut le plus genant.
  const topicId = await sbCreateTopic('presse', titre, 'Jodie Moitout', state.country || 'republic', time, false, false, null, null, null);
  if (!topicId) { showToast('Échec', "La publication n'a pas pu être enregistrée. Réessayez plus tard.", false); return; }
  const postId = await sbCreatePost(topicId, 'Jodie Moitout', texte, time, false, false, [], null, null, null, null).catch(() => null);
  if (!postId) {
    showToast('Publication incomplète', "Le sujet a été créé mais le texte n'a pas pu être enregistré. Réessayez.", false);
    return;
  }

  window._jodiePortraitTexte = null;
  window._jodieInterviewReponses = null;
  showToast('Portrait publié !', 'Jodie a publié votre portrait dans Presse & Médias.', true, true);
  mailView = 'inbox';
  document.getElementById('forum-main').innerHTML = renderForumContent();
}

// =====================
// FINANCES MODAL
// =====================
function openFinancesModal(pa, cost) {
  const cur = COUNTRIES[state.char?.country || 'republic']?.cur || 'FR';

  document.getElementById('finances-body').innerHTML = `
    <div class="finance-row">
      <div class="finance-label">Argent total</div>
      <div class="finance-amount">${state.arg.toLocaleString('fr-FR')} ${cur}</div>
    </div>
    <div class="finance-row">
      <div class="finance-label">Argent liquide (sur vous)</div>
      <div class="finance-amount">${state.liquide.toLocaleString('fr-FR')} ${cur}</div>
    </div>
    <div class="finance-row">
      <div class="finance-label">En banque</div>
      <div class="finance-amount">${state.banque.toLocaleString('fr-FR')} ${cur}</div>
    </div>
    <div style="padding:.8rem 1rem;border-bottom:1px solid #1a1810">
      <div style="font-size:.75rem;color:#6a5a30;margin-bottom:.5rem;font-family:'Bebas Neue',sans-serif;letter-spacing:.1em">DEPOT / RETRAIT</div>
      <div style="display:flex;gap:.5rem;align-items:center;margin-bottom:.5rem">
        <input class="finance-input" id="finance-amount-input" type="number" placeholder="Montant" min="1" max="${state.banque}"/>
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

async function deposerArgent(pa, cost) {
  const amount = parseInt(document.getElementById('finance-amount-input').value);
  if (!amount || amount <= 0 || amount > state.liquide) {
    showToast('Erreur', 'Montant invalide ou insuffisant en liquide.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  state.liquide -= amount;
  state.banque += amount;
  document.getElementById('modal-finances').classList.remove('open');
  showToast('Depot effectue', `${amount.toLocaleString('fr-FR')} deposes en banque.`, true);
  addJournalEntry(`Depot bancaire : ${amount.toLocaleString('fr-FR')}.`, '');
}

async function retirerArgent(pa, cost) {
  const amount = parseInt(document.getElementById('finance-amount-input').value);
  if (!amount || amount <= 0 || amount > state.banque) {
    showToast('Erreur', 'Montant invalide ou solde bancaire insuffisant.', false);
    return;
  }
  const r = await deduireCoutOrdre({ pa, cost });
  if (!r.ok) { showToast('PA insuffisants', '', false); return; }
  state.banque -= amount;
  state.liquide += amount;
  document.getElementById('modal-finances').classList.remove('open');
  showToast('Retrait effectue', `${amount.toLocaleString('fr-FR')} retires de la banque.`, true);
  addJournalEntry(`Retrait bancaire : ${amount.toLocaleString('fr-FR')}.`, '');
}

