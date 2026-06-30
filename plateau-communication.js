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
    document.getElementById('postes-body').innerHTML = '<div style="padding:1rem;color:#4a4030;font-style:italic">Aucun joueur enregistre pour l\'instant.</div>';
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
            ${!isMe ? `<button onclick="composerMailPour(this.dataset.name)" data-name="${j.name}" style="font-family:Bebas Neue,sans-serif;font-size:.62rem;letter-spacing:.06em;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a8060;cursor:pointer">
              <i class="ti ti-mail" style="font-size:.65rem"></i>
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
    const h = String(state.hour || 8).padStart(2,'0');
    const time = 'Jour ' + (state.day || 1) + ' · ' + h + 'h';
    if (typeof sbSendMail === 'function') await sbSendMail(from, to, subject, body, time);
    addJournalEntry('Mail envoyé à ' + to + ' : "' + subject + '".', 'event-info');
    showToast('Mail envoyé', 'À ' + to + ' — "' + subject + '"', true);
  }
  fermerComposeMail();
}

// =====================
// TRACTS
// =====================
function ouvrirModalImprimerTracts() {
  const contacts = state.contacts || [];
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  document.getElementById('postes-modal-title').textContent = 'Faire imprimer des tracts';
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">150 ' + cur + ' par lot de 10 tracts.</div>';

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

    html += '<button onclick="confirmerImpression()" style="font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Commander</button>';
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

function confirmerImpression() {
  const type = window._tractType || 'pour';
  const cible = document.getElementById('tract-cible')?.value;
  const quantite = parseInt(document.getElementById('tract-quantite')?.value || '10');
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const cout = quantite / 10 * 150;

  if (state.arg < cout) {
    showToast('Fonds insuffisants', 'Il vous faut ' + cout + ' ' + cur, false);
    return;
  }

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

  updateUI();
  showToast('Tracts imprimes !', quantite + ' tracts ' + type + ' ' + cible + ' ajoutes a votre inventaire. -' + cout + ' ' + cur, true, true);
  addJournalEntry('Production de ' + quantite + ' tracts ' + type + ' ' + cible, 'event-info');
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

function distribuerTractPNJ(pnjName) {
  const tracts = (state.inventory||[]).filter(i => i.type === 'tract');
  if (tracts.length === 0) {
    showToast('Aucun tract', 'Vous n\'avez pas de tracts en inventaire.', false);
    return;
  }
  // Utiliser le premier lot de tracts disponible
  const tract = tracts[0];
  tract.quantite -= 1;
  if (tract.quantite <= 0) {
    const i = state.inventory.indexOf(tract);
    state.inventory.splice(i, 1);
  }

  // Jet 50% + bonus INF/10
  const bonusInf = Math.floor(state.inf / 10);
  const taux = Math.min(80, 50 + bonusInf);
  const roll = Math.floor(Math.random() * 100) + 1;
  const succes = roll <= taux;

  if (succes) {
    // Verifier si periode electorale
    const enElection = state.electionsEnCours?.some(e => e.phase === 'campagne');
    const estCandidat = state.electionsEnCours?.some(e =>
      e.candidats?.some(c => c.nom === tract.cible)
    );

    if (enElection && estCandidat) {
      // +1 voix au candidat
      state.electionsEnCours.forEach(e => {
        const candidat = e.candidats?.find(c => c.nom === tract.cible);
        if (candidat) candidat.voix = (candidat.voix||0) + 1;
      });
      showToast('Tract distribue !', pnjName + ' votera pour ' + tract.cible + '. +1 voix.', true, true);
    } else {
      // +/- POP sur la cible
      if (tract.tractType === 'pour') {
        state.pop = Math.min(100, state.pop + 2);
        showToast('Tract distribue !', '+2 POP pour ' + tract.cible, true);
      } else {
        state.pop = Math.max(0, state.pop - 2);
        showToast('Tract distribue !', '-2 POP pour ' + tract.cible, true);
      }
    }
    addJournalEntry('Tract distribue a ' + pnjName + ' — succes.', 'event-good');
  } else {
    showToast('Sans effet', pnjName + ' n\'a pas ete convaincu(e). Tract consomme.', false);
    addJournalEntry('Distribution de tract a ' + pnjName + ' — sans effet.', '');
  }
  updateUI();
}

function doLogePortail() {
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
      <div style="margin-top:.8rem;font-size:.72rem;color:#4a4030;font-style:italic">
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
    html += '<div style="font-size:.72rem;color:#6a5a30;margin-bottom:.5rem">Tour ' + (e.tour||1) + ' · Resultats : Jour ' + e.jourResultat + '</div>';

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

  html += '<div style="font-size:.72rem;color:#4a4030;font-style:italic;margin-top:.5rem">Calendrier : candidatures semaine 1-3 · campagne semaine 4-5 · resultats dimanche soir.</div>';
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
  openForum_module(forumId || 'local');
}

function closeForumView() {
  document.getElementById('vue-forum').classList.remove('active');
  if (state.currentBuilding) {
    document.getElementById('vue-batiment').classList.add('active');
  } else {
    document.getElementById('vue-rue').classList.add('active');
  }
}

function buildForumHTML(forumId) {
  let topics = FORUM_TOPICS[forumId] || [];
  // Charger depuis Supabase si forum tribunal
  if (forumId.startsWith('tribunal_') && typeof sbLoadForumTopics === 'function') {
    sbLoadForumTopics(forumId).then(rows => {
      if (rows?.length) {
        FORUM_TOPICS[forumId] = rows;
        renderForumTopics(forumId);
      }
    }).catch(()=>{});
  }
  const labels = {
    local:'Forum Local', regional:'Forum Regional', national:'Forum National',
    international:'Forum International', gouv:'Forum Gouvernemental',
    syndical:'Forum Syndical', president:'Forum Presidentiel', conseil:'Conseil des Ministres'
  };

  let html = '<div style="display:flex;height:100%">';

  // Sidebar forums
  html += '<div style="width:160px;background:#111208;border-right:1px solid #1a1a10;overflow-y:auto;flex-shrink:0">';
  const tribunalKey = 'tribunal_' + (state.currentCity || 'capitale');
  const villeNomForum = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const forums = [
    {id:'local',label:'Local'},{id:'regional',label:'Regional'},{id:'national',label:'National'},
    {id:'international',label:'International'},{id:'president',label:'Presidentiel'},
    {id:'conseil',label:'Conseil Min.'},{id:'gouv',label:'Gouvernemental'},{id:'syndical',label:'Syndical'},
    {id:tribunalKey,label:'⚖️ Tribunal — ' + villeNomForum}
  ];
  forums.forEach(f => {
    const active = f.id === forumId;
    html += '<div onclick="openForumView(\'' + f.id + '\')" style="padding:.5rem .7rem;cursor:pointer;' +
      (active ? 'background:#1a1a10;border-left:2px solid #C9A84C;' : 'border-left:2px solid transparent;') +
      'border-bottom:1px solid #1a1a10">' +
      '<div style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.08em;color:' +
      (active ? '#E8C97A' : '#8a8060') + '">' + f.label + '</div>' +
      '<div style="font-size:.6rem;color:#4a4030">' + (FORUM_TOPICS[f.id]?.length || 0) + ' sujets</div>' +
      '</div>';
  });
  html += '</div>';

  // Contenu principal
  html += '<div style="flex:1;display:flex;flex-direction:column;overflow:hidden">';

  // Header
  html += '<div style="padding:.6rem 1rem;background:#111208;border-bottom:1px solid #2a2810;display:flex;justify-content:space-between;align-items:center">';
  html += '<div style="font-family:Playfair Display,serif;font-size:.9rem;color:#E8D880">' + (labels[forumId]||'Forum') + '</div>';
  html += '<button onclick="ouvrirNouveauSujet(\'' + forumId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;padding:.3rem .7rem;border:1px solid #6a5a20;background:transparent;color:#C9A84C;cursor:pointer">+ Nouveau sujet</button>';
  html += '</div>';

  // Liste des sujets
  html += '<div style="flex:1;overflow-y:auto">';
  if (topics.length === 0) {
    html += '<div style="padding:2rem;text-align:center;font-size:.82rem;color:#4a4030;font-style:italic">Aucun sujet pour le moment.</div>';
  } else {
    // En-tete
    html += '<div style="display:grid;grid-template-columns:1fr 80px 60px 80px;padding:.3rem .8rem;background:#0a0a05;border-bottom:1px solid #1a1808">';
    ['Sujet','Auteur','Reponses','Date'].forEach(h => {
      html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.62rem;letter-spacing:.1em;color:#4a4030">' + h + '</div>';
    });
    html += '</div>';
    topics.forEach((t, i) => {
      const isRef = t.isReferendum;
      html += '<div onclick="ouvrirSujetForum(\'' + forumId + '\',' + i + ')" style="display:grid;grid-template-columns:1fr 80px 60px 80px;padding:.5rem .8rem;background:#151208;border-bottom:1px solid #1e1a08;cursor:pointer;transition:background .15s" onmouseover="this.style.background=\'#1e1a08\'" onmouseout="this.style.background=\'#151208\'">';
      html += '<div><div style="font-size:.85rem;color:' + (isRef ? '#8ad080' : '#E0D090') + ';margin-bottom:.1rem">' +
        (isRef ? '<i class="ti ti-checkbox" style="font-size:.75rem"></i> ' : '') + t.title + '</div>' +
        '<div style="font-size:.68rem;color:#6a6040">' + (t.author||'Anonyme') + '</div></div>';
      html += '<div style="font-size:.75rem;color:#9a9060;align-self:center">' + (t.author||'') + '</div>';
      html += '<div style="font-size:.75rem;color:#6a6040;align-self:center;text-align:center">' + (t.replies||t.posts?.length||0) + '</div>';
      html += '<div style="font-size:.72rem;color:#5a5030;align-self:center">' + (t.time||'') + '</div>';
      html += '</div>';
    });
  }
  html += '</div></div></div>';
  return html;
}

function ouvrirSujetForum(forumId, topicIdx) {
  const topic = (FORUM_TOPICS[forumId]||[])[topicIdx];
  if (!topic) return;
  const body = document.getElementById('forum-view-body');
  let html = '<div style="display:flex;flex-direction:column;width:100%;height:100%">';
  html += '<div style="padding:.5rem 1rem;background:#111208;border-bottom:1px solid #1a1810;display:flex;align-items:center;gap:.8rem">';
  html += '<button onclick="openForumView(\'' + forumId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a7040;cursor:pointer">← Retour</button>';
  html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8D880">' + topic.title + '</div>';
  html += '</div>';
  html += '<div style="flex:1;overflow-y:auto;padding:.8rem 1rem">';

  // Referendum special
  if (topic.isReferendum && topic.reponses) {
    const dejaVote = state.refVotes?.[topic.id];
    html += '<div style="background:#0f0d05;border:1px solid #2a3a20;padding:.8rem;margin-bottom:.8rem">';
    html += '<div style="font-family:Playfair Display,serif;font-size:.82rem;color:#8ad080;margin-bottom:.6rem">REFERENDUM : ' + topic.title.replace('[REFERENDUM] ','') + '</div>';
    topic.reponses.forEach((r, ri) => {
      const total = topic.reponses.reduce((s, x) => s + (x.voix||0), 0) || 1;
      const pct = Math.round((r.voix||0) / total * 100);
      html += '<div style="margin-bottom:.4rem">';
      if (!dejaVote) {
        html += '<button onclick="voterReferendum(\'' + forumId + '\',' + topicIdx + ',' + ri + ')" style="width:100%;text-align:left;padding:.4rem .7rem;border:1px solid #2a3a20;background:#0a0a05;color:#c0c080;cursor:pointer;font-family:Crimson Pro,serif;font-size:.82rem">' + r.label + '</button>';
      } else {
        html += '<div style="padding:.4rem .7rem;border:1px solid #1a2810;background:#0a0a05;font-family:Crimson Pro,serif;font-size:.82rem;color:' + (dejaVote === ri ? '#8ad080' : '#5a5030') + '">';
        html += r.label + ' <span style="float:right;font-family:Bebas Neue,sans-serif">' + pct + '%</span></div>';
        html += '<div style="height:4px;background:#0a0a05;margin-top:.1rem"><div style="height:100%;width:' + pct + '%;background:#4a8a4a"></div></div>';
      }
      html += '</div>';
    });
    if (dejaVote !== undefined) html += '<div style="font-size:.7rem;color:#4a6a3a;margin-top:.3rem">Vote enregistre.</div>';
    html += '</div>';
  }

  // Posts
  (topic.posts||[]).forEach(p => {
    html += '<div style="background:#181408;border:1px solid #2a2408;padding:.7rem;margin-bottom:.5rem">';
    html += '<div style="display:flex;justify-content:space-between;margin-bottom:.4rem">';
    html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.75rem;color:#E8C97A">' + (p.author||'Anonyme') + '</div>';
    html += '<div style="font-size:.65rem;color:#4a4030">' + (p.time||'') + '</div>';
    html += '</div>';
    html += '<div style="font-size:.88rem;color:#c8c090;line-height:1.7">' + (p.content||'') + '</div>';
    html += '</div>';
  });

  // Zone de reponse
  html += '<div style="margin-top:.8rem;border-top:1px solid #1a1810;padding-top:.8rem">';
  html += '<textarea id="forum-reply-text" rows="3" placeholder="Votre reponse..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#d0c890;padding:.5rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.4rem"></textarea>';
  html += '<button onclick="publierReponse(\'' + forumId + '\',' + topicIdx + ')" style="font-family:Bebas Neue,sans-serif;font-size:.72rem;letter-spacing:.1em;padding:.4rem .9rem;border:1px solid #6a5a20;background:transparent;color:#C9A84C;cursor:pointer">Repondre</button>';
  html += '</div></div></div>';
  body.innerHTML = html;
}

function voterReferendum(forumId, topicIdx, reponseIdx) {
  const topic = (FORUM_TOPICS[forumId]||[])[topicIdx];
  if (!topic || !topic.reponses) return;
  if (!state.refVotes) state.refVotes = {};
  state.refVotes[topic.id] = reponseIdx;
  topic.reponses[reponseIdx].voix = (topic.reponses[reponseIdx].voix||0) + 1;
  ouvrirSujetForum(forumId, topicIdx);
  showToast('Vote enregistre', 'Vous avez vote pour : ' + topic.reponses[reponseIdx].label, true);
}

function publierReponse(forumId, topicIdx) {
  const texte = document.getElementById('forum-reply-text')?.value?.trim();
  if (!texte) return;
  const topic = (FORUM_TOPICS[forumId]||[])[topicIdx];
  if (!topic) return;
  if (!topic.posts) topic.posts = [];
  topic.posts.push({ author: state.char?.name||'Anonyme', time: 'Jour ' + state.day, content: texte });
  topic.replies = (topic.replies||0) + 1;
  ouvrirSujetForum(forumId, topicIdx);
  showToast('Reponse publiee', '', true);
}

function ouvrirNouveauSujet(forumId) {
  const body = document.getElementById('forum-view-body');
  let html = '<div style="display:flex;flex-direction:column;width:100%;height:100%">';
  html += '<div style="padding:.5rem 1rem;background:#111208;border-bottom:1px solid #1a1810;display:flex;align-items:center;gap:.8rem">';
  html += '<button onclick="openForumView(\'' + forumId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.68rem;padding:.2rem .5rem;border:1px solid #2a2010;background:transparent;color:#8a7040;cursor:pointer">← Annuler</button>';
  html += '<div style="font-family:Playfair Display,serif;font-size:.88rem;color:#E8D880">Nouveau sujet</div>';
  html += '</div>';
  html += '<div style="flex:1;overflow-y:auto;padding:1rem">';
  html += '<input id="new-topic-title" type="text" placeholder="Titre du sujet..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#d0c890;padding:.6rem;font-family:Crimson Pro,serif;font-size:.88rem;outline:none;margin-bottom:.6rem"/>';
  html += '<textarea id="new-topic-content" rows="6" placeholder="Contenu du message..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#d0c890;padding:.6rem;font-family:Crimson Pro,serif;font-size:.85rem;outline:none;resize:none;margin-bottom:.6rem"></textarea>';
  html += '<button onclick="publierNouveauSujet(\'' + forumId + '\')" style="font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.1em;padding:.5rem 1.2rem;border:1px solid #8a6a20;background:transparent;color:#C9A84C;cursor:pointer">Publier</button>';
  html += '</div></div>';
  body.innerHTML = html;
}

function publierNouveauSujet(forumId) {
  const titre = document.getElementById('new-topic-title')?.value?.trim();
  const contenu = document.getElementById('new-topic-content')?.value?.trim();
  if (!titre || !contenu) { showToast('Champs requis', 'Titre et contenu obligatoires.', false); return; }
  if (!FORUM_TOPICS[forumId]) FORUM_TOPICS[forumId] = [];
  const newTopic = {
    id: 'topic-' + Date.now(),
    title: titre,
    author: state.char?.name||'Anonyme',
    time: 'Jour ' + state.day,
    replies: 0,
    posts: [{ author: state.char?.name||'Anonyme', time: 'Jour ' + state.day, content: contenu }]
  };
  FORUM_TOPICS[forumId].unshift(newTopic);
  showToast('Sujet publie !', titre, true, true);
  openForumView(forumId);
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
  const h = String(state.hour).padStart(2,'0');
  const m = String(state.minute||0).padStart(2,'0');
  const div = document.createElement('div');
  div.className = 'journal-entry journal-external';
  div.innerHTML = `
    <span class="journal-time">Jour ${state.day} · ${h}h${m}</span>
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
      const div = document.createElement('div');
      div.className = 'journal-entry journal-external';
      div.innerHTML = `
        <span class="journal-time">Jour ${r.jour || '?'}</span>
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

// Recupere et applique les vols subis par le joueur depuis sa derniere connexion
async function recupererVolsEnAttente() {
  if (typeof sbRecupererVolsEnAttente !== 'function') return;
  const moi = state.char?.name;
  if (!moi) return;
  try {
    const vols = await sbRecupererVolsEnAttente(moi);
    if (!vols || vols.length === 0) return;
    const cur = COUNTRIES[state.country]?.cur || 'FR';
    let totalPerdu = 0;
    for (const vol of vols) {
      if (vol.type_butin === 'argent') {
        totalPerdu += vol.montant || 0;
        state.arg = Math.max(0, (state.arg || 0) - (vol.montant || 0));
      }
      if (typeof sbMarquerVolTraite === 'function') await sbMarquerVolTraite(vol.id).catch(() => {});
    }
    if (totalPerdu > 0) {
      updateUI();
      addJournalEntry('🤏 On vous a discrètement dérobé ' + totalPerdu + ' ' + cur + '.', 'event-bad');
      showToast('Vous avez été volé(e)', '-' + totalPerdu + ' ' + cur + ' dérobé(s) discrètement.', false, true);
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
      if (imp.indice === 'hp_set') {
        // Attaque recue (assassinat/empoisonnement) — valeur absolue, pas un delta
        state.hp = Math.max(0, imp.delta);
        state.regenJour = state.day; // demarre la regeneration naturelle (+10/jour)
        resume.push('⚔️ Agression ! PV tombés à ' + imp.delta);
      }
      if (typeof sbMarquerImpactTraite === 'function') await sbMarquerImpactTraite(imp.id).catch(() => {});
    }
    if (resume.length > 0) {
      updateUI();
      const agrappe = resume.some(r => r.includes('Agression'));
      if (agrappe) {
        showToast('Agression !', 'Vous avez été attaqué(e). PV : ' + state.hp + '. Récupération : +10/jour.', false, true);
        addJournalEntry('Vous avez été victime d\'une agression. Vos PV sont tombés à ' + state.hp + '.', 'event-bad');
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
function doArchivesPolice() {
  const prisonniers = state.prisonniers || [];
  const derniers30j = prisonniers.filter(p => {
    const dayNum = parseInt(p.depuis.replace('Jour ','')) || 0;
    return state.day - dayNum <= 30;
  });

  let msg = '';
  if (derniers30j.length === 0) {
    msg = 'Archives consultees : aucune personne emprisonnee au cours des 30 derniers jours.';
  } else {
    msg = `Archives consultees : ${derniers30j.length} personne(s) emprisonnee(s) ces 30 derniers jours : ${derniers30j.map(p => p.nom + ' (' + p.depuis + ')').join(', ')}.`;
  }
  showToast('Archives consultees', msg.substring(0, 80) + '...', true);
  addJournalEntry(msg, 'event-info');
}

// Notification mail simple
function addMailNotification(from, subject, body) {
  if (!state.mails) state.mails = [];
  state.mails.push({ from, subject, body, day: state.day, read: false });
  addExternalEvent(`Nouveau mail de ${from} : "${subject}"`);
  // Mettre a jour le badge immediatement
  const unread = state.mails.filter(m => !m.read).length;
  const badge = document.getElementById('mail-badge');
  if (badge) { badge.textContent = unread; badge.style.display = unread > 0 ? 'inline' : 'none'; }
}

function showPostRequired(posteNom) {
  const msg = posteNom
    ? 'Cet ordre est réservé au ' + posteNom + '. Postez votre candidature au Palais du Gouvernement.'
    : 'Vous devez occuper un poste institutionnel pour accéder à cet ordre.';
  showToast('Accès restreint', msg, false);
}

// =====================
// FINANCES MODAL
// =====================
function openFinancesModal() {
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
        <button class="finance-btn" onclick="deposerArgent()">Deposer</button>
        <button class="finance-btn danger" onclick="retirerArgent()">Retirer</button>
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

function deposerArgent() {
  const amount = parseInt(document.getElementById('finance-amount-input').value);
  if (!amount || amount <= 0 || amount > state.liquide) {
    showToast('Erreur', 'Montant invalide ou insuffisant en liquide.', false);
    return;
  }
  state.liquide -= amount;
  state.banque += amount;
  document.getElementById('modal-finances').classList.remove('open');
  showToast('Depot effectue', `${amount.toLocaleString('fr-FR')} deposes en banque.`, true);
  addJournalEntry(`Depot bancaire : ${amount.toLocaleString('fr-FR')}.`, '');
}

function retirerArgent() {
  const amount = parseInt(document.getElementById('finance-amount-input').value);
  if (!amount || amount <= 0 || amount > state.banque) {
    showToast('Erreur', 'Montant invalide ou solde bancaire insuffisant.', false);
    return;
  }
  state.banque -= amount;
  state.liquide += amount;
  document.getElementById('modal-finances').classList.remove('open');
  showToast('Retrait effectue', `${amount.toLocaleString('fr-FR')} retires de la banque.`, true);
  addJournalEntry(`Retrait bancaire : ${amount.toLocaleString('fr-FR')}.`, '');
}

