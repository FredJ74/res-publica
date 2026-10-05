#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif "Diner d'affaires" complet :
- supabase.js : fonctions CRUD sur la table invitations_diner
- plateau-pnj.js : modale de choix, envoi, sondage (invite + inviteur), popup accepter/refuser
- plateau-router.js : route fn:'diner_affaires' vers ouvrirModalDinerAffaires
- plateau-core.js : demarre les 2 sondages au chargement
- plateau-actions-illegales-rumeurs.js : formulations de rumeur vraie (accepte/refuse)
- data.js : ordre mis a jour (300 FR, nouvelle description)
"""
import sys

def apply_patch(path, old, new, label):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    count = content.count(old)
    if count == 0:
        print(f"[ECHEC] {label} : ancre introuvable dans {path}")
        return False
    if count > 1:
        print(f"[ECHEC] {label} : ancre trouvee {count} fois dans {path} (doit etre unique)")
        return False
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[OK] {label}")
    return True

ok = True

# ------------------------------------------------------------------
# 1) supabase.js
# ------------------------------------------------------------------
old_sb = """async function sbAjusterPopJoueur(nomJoueur, delta) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomJoueur)}&select=pop`);
  const popActuel = rows?.[0]?.pop ?? 50;
  const nouveauPop = Math.max(0, Math.min(100, popActuel + delta));
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(nomJoueur)}`, { pop: nouveauPop });
  return nouveauPop;
}"""

new_sb = """async function sbAjusterPopJoueur(nomJoueur, delta) {
  const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(nomJoueur)}&select=pop`);
  const popActuel = rows?.[0]?.pop ?? 50;
  const nouveauPop = Math.max(0, Math.min(100, popActuel + delta));
  await sbUpdate('personnages', `name=eq.${encodeURIComponent(nomJoueur)}`, { pop: nouveauPop });
  return nouveauPop;
}

// =====================
// INVITATIONS A DINER (diner d'affaires entre PJ presents dans la meme piece)
// =====================
async function sbCreerInvitationDiner(inviteur, invite, country, city, buildingId, roomId, cout) {
  return sbInsert('invitations_diner', {
    inviteur, invite, country, city,
    building_id: buildingId, room_id: roomId,
    statut: 'attente', cout
  });
}

async function sbGetInvitationsDinerRecues(nomJoueur) {
  const filtre = `invite=eq.${encodeURIComponent(nomJoueur)}&statut=eq.attente`;
  return sbGet('invitations_diner', filtre) || [];
}

async function sbGetInvitationsDinerTraitees(nomInviteur, nomInvite) {
  const filtre = `inviteur=eq.${encodeURIComponent(nomInviteur)}&invite=eq.${encodeURIComponent(nomInvite)}&statut=neq.attente`;
  return sbGet('invitations_diner', filtre) || [];
}

async function sbRepondreInvitationDiner(id, accepte) {
  return sbUpdate('invitations_diner', `id=eq.${id}`, { statut: accepte ? 'acceptee' : 'refusee' });
}

async function sbSupprimerInvitationDiner(id) {
  return sbDelete('invitations_diner', `id=eq.${id}`);
}"""

ok &= apply_patch('supabase.js', old_sb, new_sb, "supabase.js - fonctions invitations_diner")

# ------------------------------------------------------------------
# 2) plateau-pnj.js
# ------------------------------------------------------------------
old_pnj = """function doEscortPiege() {"""

new_pnj = """function ouvrirModalDinerAffaires(pa, cost, successRate) {
  const presents = (window._vraisJoueursPresents || []).filter(p => p.name !== state.char?.name);
  if (presents.length === 0) {
    showToast('Personne à inviter', 'Aucun autre joueur n\\'est présent dans cette pièce pour l\\'instant.', false);
    return;
  }
  if (state.arg < cost) {
    showToast('Fonds insuffisants', cost + ' FR requis pour inviter quelqu\\'un à dîner.', false);
    return;
  }
  document.getElementById('postes-modal-title').textContent = '🍽️ Inviter à dîner';
  document.getElementById('postes-body').innerHTML =
    '<div style="padding:.8rem 1rem">' +
    '<div style="font-size:.75rem;color:#8a8060;font-style:italic;margin-bottom:.7rem">Choisissez un joueur présent. Le coût n\\'est prélevé que s\\'il accepte.</div>' +
    presents.map(p =>
      '<div onclick="envoyerInvitationDiner(\\'' + p.name.replace(/'/g,'') + '\\',' + pa + ',' + cost + ')" style="display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.4rem;cursor:pointer" onmouseover="this.style.background=\\'#1a1005\\'" onmouseout="this.style.background=\\'#0f0d05\\'">' +
        '<i class="ti ti-user" style="font-size:.9rem;color:#8a6a20"></i>' +
        '<div><div style="font-size:.82rem;color:#c0b090">' + p.name + '</div></div>' +
      '</div>'
    ).join('') +
    '</div>';
  document.getElementById('modal-postes').classList.add('open');
}

async function envoyerInvitationDiner(nomInvite, pa, cost) {
  document.getElementById('modal-postes').classList.remove('open');
  if (typeof sbCreerInvitationDiner !== 'function') return;
  await sbCreerInvitationDiner(state.char?.name, nomInvite, state.country, state.currentCity, state.currentBuilding, state.currentRoom, cost).catch(() => {});
  state._dinerEnAttente = {
    invite: nomInvite, pa, cost,
    country: state.country, city: state.currentCity,
    buildingId: state.currentBuilding, roomId: state.currentRoom
  };
  showToast('Invitation envoyée', 'En attente de la réponse de ' + nomInvite + '...', true);
  addJournalEntry('Invitation à dîner envoyée à ' + nomInvite + '.', 'event-info');
}

async function verifierReponseInvitationDiner() {
  if (!state._dinerEnAttente || !state.char?.name) return;
  const infos = state._dinerEnAttente;

  // Invitation caduque si l'inviteur (nous-meme) a quitte la piece d'origine
  if (state.currentBuilding !== infos.buildingId || state.currentRoom !== infos.roomId) {
    state._dinerEnAttente = null;
    return;
  }

  if (typeof sbGetInvitationsDinerTraitees !== 'function') return;
  try {
    const rows = await sbGetInvitationsDinerTraitees(state.char.name, infos.invite);
    const ligne = (rows || [])[0];
    if (!ligne) return;

    if (ligne.statut === 'acceptee') {
      if (state.arg >= infos.cost) {
        state.arg -= infos.cost;
        state.hp = Math.min(100, (state.hp || 0) + 10);
        state.inf = Math.min(100, (state.inf || 0) + 5);
        state.bonusPaProchainDormir = (state.bonusPaProchainDormir || 0) + 1;
        showToast('Dîner accepté !', infos.invite + ' a accepté votre invitation. +10 Santé, +5 INF, +1 PA au prochain Dormir. -' + infos.cost + ' FR.', true, true);
        addJournalEntry('Dîner d\\'affaires avec ' + infos.invite + ' : accepté. -' + infos.cost + ' FR. +10 Santé, +5 INF, +1 PA au prochain Dormir.', 'event-good');
        if (typeof advanceTime === 'function') advanceTime(Math.max(0, infos.pa || 0));
      } else {
        showToast('Fonds insuffisants', infos.invite + ' a accepté, mais vous n\\'avez plus les fonds pour régler l\\'addition.', false);
        addJournalEntry('Dîner d\\'affaires avec ' + infos.invite + ' accepté, mais fonds insuffisants pour payer.', 'event-bad');
      }
      if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('diner_affaires_accepte', infos.invite);
    } else if (ligne.statut === 'refusee') {
      showToast('Invitation refusée', infos.invite + ' a décliné votre invitation.', false);
      addJournalEntry('Dîner d\\'affaires avec ' + infos.invite + ' : refusé.', 'event-info');
      if (typeof tracerActionPourRumeur === 'function') tracerActionPourRumeur('diner_affaires_refuse', infos.invite);
    }

    if (typeof sbSupprimerInvitationDiner === 'function') sbSupprimerInvitationDiner(ligne.id).catch(() => {});
    state._dinerEnAttente = null;
    updateUI();
  } catch(e) {}
}

async function verifierInvitationsDinerRecues() {
  if (!state.char?.name || !state.currentBuilding || !state.currentRoom) return;
  if (state._dinerModalOuvert) return;
  if (typeof sbGetInvitationsDinerRecues !== 'function') return;
  try {
    const rows = await sbGetInvitationsDinerRecues(state.char.name);
    const valide = (rows || []).find(r =>
      r.country === state.country && r.city === state.currentCity &&
      r.building_id === state.currentBuilding && r.room_id === state.currentRoom
    );
    if (!valide) return;
    state._dinerModalOuvert = true;
    document.getElementById('postes-modal-title').textContent = '🍽️ Invitation à dîner';
    document.getElementById('postes-body').innerHTML =
      '<div style="padding:1.2rem">' +
      '<div style="font-size:.85rem;color:#c0b090;margin-bottom:1rem">' + valide.inviteur + ' vous invite à un dîner d\\'affaires, à ses frais.</div>' +
      '<div style="display:flex;gap:.5rem">' +
        '<button onclick="repondreInvitationDiner(' + valide.id + ',true,\\'' + valide.inviteur.replace(/'/g,'') + '\\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.5rem;border:1px solid #4a8a4a;background:transparent;color:#6a9a6a;cursor:pointer">✅ Accepter</button>' +
        '<button onclick="repondreInvitationDiner(' + valide.id + ',false,\\'' + valide.inviteur.replace(/'/g,'') + '\\')" style="flex:1;font-family:Bebas Neue,sans-serif;font-size:.75rem;letter-spacing:.08em;padding:.5rem;border:1px solid #5a2a2a;background:transparent;color:#8a3a2a;cursor:pointer">❌ Refuser</button>' +
      '</div></div>';
    document.getElementById('modal-postes').classList.add('open');
  } catch(e) {}
}

async function repondreInvitationDiner(id, accepte, nomInviteur) {
  document.getElementById('modal-postes').classList.remove('open');
  state._dinerModalOuvert = false;
  if (typeof sbRepondreInvitationDiner === 'function') await sbRepondreInvitationDiner(id, accepte).catch(() => {});
  if (accepte) {
    state.hp = Math.min(100, (state.hp || 0) + 10);
    state.inf = Math.min(100, (state.inf || 0) + 5);
    state.bonusPaProchainDormir = (state.bonusPaProchainDormir || 0) + 1;
    updateUI();
    showToast('Dîner accepté !', 'Vous rejoignez ' + nomInviteur + '. +10 Santé, +5 INF, +1 PA au prochain Dormir.', true, true);
    addJournalEntry('Vous avez accepté l\\'invitation à dîner de ' + nomInviteur + '. +10 Santé, +5 INF, +1 PA au prochain Dormir.', 'event-good');
  } else {
    showToast('Invitation déclinée', 'Vous avez refusé l\\'invitation de ' + nomInviteur + '.', false);
    addJournalEntry('Vous avez refusé l\\'invitation à dîner de ' + nomInviteur + '.', 'event-info');
  }
}

function demarrerPollingInvitationsDiner() {
  if (window._dinerPollingActif) return;
  window._dinerPollingActif = true;
  setInterval(() => { if (typeof verifierInvitationsDinerRecues === 'function') verifierInvitationsDinerRecues(); }, 4000);
  setInterval(() => { if (typeof verifierReponseInvitationDiner === 'function') verifierReponseInvitationDiner(); }, 4000);
}

function doEscortPiege() {"""

ok &= apply_patch('plateau-pnj.js', old_pnj, new_pnj, "plateau-pnj.js - systeme complet d'invitation a diner")

# ------------------------------------------------------------------
# 3) plateau-router.js
# ------------------------------------------------------------------
old_route = """  if (fn === 'lancer_rumeur_cible') { ouvrirModalLancerRumeur(pa, cost, successRate); return; }"""
new_route = """  if (fn === 'lancer_rumeur_cible') { ouvrirModalLancerRumeur(pa, cost, successRate); return; }
  if (fn === 'diner_affaires') { ouvrirModalDinerAffaires(pa, cost, successRate); return; }"""
ok &= apply_patch('plateau-router.js', old_route, new_route, "plateau-router.js - route diner_affaires")

# ------------------------------------------------------------------
# 4) plateau-core.js -- demarrer le sondage au chargement
# ------------------------------------------------------------------
old_core = """  setTimeout(() => { if (typeof demarrerPollingNotificationChat === 'function') demarrerPollingNotificationChat(); }, 2000);"""
new_core = """  setTimeout(() => { if (typeof demarrerPollingNotificationChat === 'function') demarrerPollingNotificationChat(); }, 2000);
  setTimeout(() => { if (typeof demarrerPollingInvitationsDiner === 'function') demarrerPollingInvitationsDiner(); }, 2000);"""
ok &= apply_patch('plateau-core.js', old_core, new_core, "plateau-core.js - demarrage sondage invitations diner")

# ------------------------------------------------------------------
# 5) plateau-actions-illegales-rumeurs.js -- formulations
# ------------------------------------------------------------------
old_form = """  torture_qhs:            (a, c) => 'Des bruits de couloir évoquent des méthodes brutales employées par ' + a + ' envers un détenu du QHS.'
};"""
new_form = """  torture_qhs:            (a, c) => 'Des bruits de couloir évoquent des méthodes brutales employées par ' + a + ' envers un détenu du QHS.',
  diner_affaires_accepte: (a, c) => a + ' a déjeuné avec ' + c + '. Que se sont-ils dit... ?',
  diner_affaires_refuse:  (a, c) => 'On raconte que ' + a + ' aurait tenté d\\'inviter ' + c + ' à dîner... sans succès.'
};"""
ok &= apply_patch('plateau-actions-illegales-rumeurs.js', old_form, new_form, "plateau-actions-illegales-rumeurs.js - formulations diner_affaires")

# ------------------------------------------------------------------
# 6) data.js -- ordre mis a jour
# ------------------------------------------------------------------
old_data = """{fn:'diner_affaires',label:'Diner d\\'affaires',  pa:2, cost:120, type:'legal',  icon:'ti-wine',     successRate:100, desc:'Invitation d\\'un contact. +Relation.'},"""
new_data = """{fn:'diner_affaires', label:'Diner d\\'affaires', pa:2, cost:300, type:'legal', icon:'ti-wine', successRate:100, desc:'Invitez un PJ present dans la piece a diner, a vos frais. Si accepte : +10 Sante, +5 INF pour chacun, +1 PA au prochain Dormir. Aucun cout si refuse.'},"""
ok &= apply_patch('data.js', old_data, new_data, "data.js - ordre Diner d'affaires (300 FR, cible presente)")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
