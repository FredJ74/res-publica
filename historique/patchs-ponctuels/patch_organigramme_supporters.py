#!/usr/bin/env python3
PATH = "plateau-organisations-quetes.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function doConsulterOrganigrammeSupporters() {
  const orga = getClubSupportersLocal();
  if (!orga) { showToast('Indisponible', 'Aucun club de supporters ici.', false); return; }

  const def = TYPES_ORGANISATIONS.supporters;
  const grades = def?.grades?.[orga.country] || [];

  document.getElementById('postes-modal-title').textContent = 'Organigramme — ' + orga.nom;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;margin-bottom:.2rem">' + orga.nom + (orga.chefEstPnj ? ' (poste de président vacant — assuré par PNJ)' : '') + '</div>';
  html += '<div style="font-size:.75rem;color:#8a8060;margin-bottom:.8rem">Président actuel : ' + orga.chef + '</div>';

  const membresTries = [...(orga.membres || [])].sort((a, b) => (b.gradeIdx || 0) - (a.gradeIdx || 0));
  html += '<div style="max-height:280px;overflow-y:auto;display:flex;flex-direction:column;gap:.3rem">';
  if (membresTries.length === 0) {
    html += '<div style="font-size:.78rem;color:#5a5040;font-style:italic">Aucun membre pour l\\'instant.</div>';
  }
  membresTries.forEach(m => {
    const estChef = m.nom === orga.chef;
    html += '<div style="display:flex;justify-content:space-between;padding:.35rem .5rem;border:1px solid #2a2010;font-size:.78rem;color:' + (estChef ? '#C9A84C' : '#c0b090') + '"><span>' + m.nom + (estChef ? ' 👑' : '') + '</span><span>' + m.grade + '</span></div>';
  });
  html += '</div>';

  if (orga.election?.enCours) {
    html += '<div style="margin-top:1rem;padding:.6rem;border:1px solid #4a3a1a;background:#0f0d05">';
    html += '<div style="font-size:.75rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.06em">ÉLECTION EN COURS — ' + (orga.election.phase === 'candidatures' ? 'Candidatures ouvertes' : 'Vote en cours') + '</div>';
    html += '<div style="font-size:.72rem;color:#8a8060;margin-top:.3rem;font-style:italic">« ' + orga.election.motivation + ' » — ' + orga.election.motivateur + '</div>';
    if (orga.election.candidats.length > 0) {
      html += '<div style="font-size:.75rem;color:#c0b090;margin-top:.5rem">Candidats : ' + orga.election.candidats.map(c => c.nom).join(', ') + '</div>';
    }
    html += '</div>';
  }
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}"""

new = """function doConsulterOrganigrammeSupporters() {
  if (typeof rafraichirCachePhotosJoueurs === 'function') {
    rafraichirCachePhotosJoueurs().then(() => {
      // Re-affiche seulement si on est encore sur la liste (pas deja sur une fiche membre)
      if (document.getElementById('postes-body')?.dataset.vue !== 'membre') doConsulterOrganigrammeSupporters();
    }).catch(() => {});
  }

  const orga = getClubSupportersLocal();
  if (!orga) { showToast('Indisponible', 'Aucun club de supporters ici.', false); return; }
  window._orgaSupportersCourante = orga;

  const def = TYPES_ORGANISATIONS.supporters;
  const grades = def?.grades?.[orga.country] || [];

  document.getElementById('postes-modal-title').textContent = 'Organigramme — ' + orga.nom;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;margin-bottom:.25rem">' + orga.nom + (orga.chefEstPnj ? ' (poste de président vacant — assuré par PNJ)' : '') + '</div>';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.9rem">Président actuel : ' + orga.chef + '</div>';

  const membresTries = [...(orga.membres || [])].sort((a, b) => (b.gradeIdx || 0) - (a.gradeIdx || 0));
  html += '<div style="max-height:280px;overflow-y:auto;display:flex;flex-direction:column;gap:.35rem">';
  if (membresTries.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040;font-style:italic">Aucun membre pour l\\'instant.</div>';
  }
  membresTries.forEach(m => {
    const estChef = m.nom === orga.chef;
    const nomEchap = m.nom.replace(/'/g, "\\\\'");
    html += '<div onclick="afficherDetailMembreSupporters(\\'' + nomEchap + '\\')" style="cursor:pointer;display:flex;justify-content:space-between;align-items:center;padding:.5rem .6rem;border:1px solid #2a2010;font-size:.9rem;color:' + (estChef ? '#C9A84C' : '#c0b090') + '"><span>' + m.nom + (estChef ? ' 👑' : '') + '</span><span>' + m.grade + '</span></div>';
  });
  html += '</div>';

  if (orga.election?.enCours) {
    html += '<div style="margin-top:1rem;padding:.6rem;border:1px solid #4a3a1a;background:#0f0d05">';
    html += '<div style="font-size:.82rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.06em">ÉLECTION EN COURS — ' + (orga.election.phase === 'candidatures' ? 'Candidatures ouvertes' : 'Vote en cours') + '</div>';
    html += '<div style="font-size:.8rem;color:#8a8060;margin-top:.3rem;font-style:italic">« ' + orga.election.motivation + ' » — ' + orga.election.motivateur + '</div>';
    if (orga.election.candidats.length > 0) {
      html += '<div style="font-size:.82rem;color:#c0b090;margin-top:.5rem">Candidats : ' + orga.election.candidats.map(c => c.nom).join(', ') + '</div>';
    }
    html += '</div>';
  }
  html += '</div>';
  const bodyEl = document.getElementById('postes-body');
  bodyEl.innerHTML = html;
  bodyEl.dataset.vue = 'liste';
  document.getElementById('modal-postes').classList.add('open');
}

// Fiche detail d'un membre du club de supporters : photo (si connue), grade, et un bouton
// pour lui ecrire directement (ouvre la messagerie avec son nom deja rempli en destinataire).
function afficherDetailMembreSupporters(nom) {
  const orga = window._orgaSupportersCourante;
  const membre = orga?.membres?.find(m => m.nom === nom);
  const avatar = (typeof getAvatarHtmlPourNom === 'function') ? getAvatarHtmlPourNom(nom, 72, '#C9A84C') : '';
  const nomEchap = nom.replace(/'/g, "\\\\'");

  let html = '<div style="padding:1.2rem;display:flex;flex-direction:column;align-items:center;gap:.6rem">';
  html += avatar;
  html += '<div style="font-size:1rem;color:#f0ead6;font-family:Bebas Neue,sans-serif;letter-spacing:.04em">' + nom + '</div>';
  if (membre) html += '<div style="font-size:.85rem;color:#8a8060">' + membre.grade + '</div>';
  html += '<button class="pnj-action-btn" onclick="ecrireAMembre(\\'' + nomEchap + '\\')" style="margin-top:.6rem"><i class="ti ti-mail" style="font-size:.85rem"></i> Écrire à ' + nom + '</button>';
  html += '<button class="pnj-action-btn" onclick="doConsulterOrganigrammeSupporters()" style="margin-top:.3rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Retour à l\\'organigramme</button>';
  html += '</div>';

  const bodyEl = document.getElementById('postes-body');
  bodyEl.innerHTML = html;
  bodyEl.dataset.vue = 'membre';
}

// Ouvre la messagerie directement en mode redaction, destinataire pre-rempli.
function ecrireAMembre(nom) {
  document.getElementById('modal-postes')?.classList.remove('open');
  document.getElementById('modal-forum')?.classList.add('open');
  if (typeof forumView !== 'undefined') forumView = 'mail';
  if (typeof mailView !== 'undefined') mailView = 'compose';
  if (typeof renderMailCompose === 'function') renderMailCompose(nom);
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Organigramme des supporters : police agrandie + fiche membre cliquable avec photo et 'Écrire à'.")
