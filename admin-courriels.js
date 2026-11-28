// Page MJ — e-mails du jeu par Brevo (chantier 2 de Fred, 28/11/2026 au soir). Page MJ : français seulement.
// 1. Alerte : à l'ouverture de la page, les échecs d'envoi consignés par le serveur (admin_courriel_echecs_lire) s'affichent
//    en tête, en rouge, avec un message clair ; « Marquer comme lu » les acquitte (admin_courriel_echecs_acquitter).
// 2. E-mail de test à l'adresse du compte MJ et vérification de sa livraison (POST /api/courriel, jeton administrateur).
// 3. Notification de sanction par e-mail (appelée par admin-signalements.js après « Prononcer et notifier »).
const ADM_COURRIEL_RAISONS = {
  cle_absente: 'Aucun e-mail ne part : la clé BREVO_API_KEY est absente de Vercel. Ajoutez-la dans Vercel (Settings → Environment Variables, Production et Preview), puis redéployez.',
  cle_refusee: 'Aucun e-mail ne part : Brevo refuse la clé BREVO_API_KEY (clé invalide, révoquée ou expirée, droit « Emails transactionnels » manquant, ou adresse IP non autorisée dans Brevo). Créez une nouvelle clé dans Brevo (SMTP & API → Clés API), remplacez-la dans Vercel, puis redéployez.',
  envoi_echoue: 'Brevo n’a pas répondu (réseau ou délai dépassé) : l’e-mail n’est pas parti.'
};
const ADM_COURRIEL_CONTEXTES = { comptes_inactifs: 'avertissement de compte inactif', paiement_achat: 'confirmation d’achat',
  paiement_rappel: 'rappel d’abonnement annuel', paiement_doublon: 'paiement en double remboursé', sanction: 'notification de sanction', test_mj: 'e-mail de test' };
function admCourrielMessage(raison) {
  if (ADM_COURRIEL_RAISONS[raison]) return ADM_COURRIEL_RAISONS[raison];
  const m = /^(envoi_refuse|brevo_indisponible)_(\d+)$/.exec(String(raison || ''));
  if (m && m[1] === 'brevo_indisponible') return 'Brevo est indisponible (erreur ' + m[2] + ') : l’e-mail n’est pas parti.';
  if (m) return 'Brevo a refusé l’envoi (erreur ' + m[2] + ') : l’e-mail n’est pas parti. Voir le détail.';
  return 'Échec d’envoi (' + raison + ').';
}
function admCourrielDate(d) { try { return new Date(d).toLocaleString('fr-FR', { timeZone: 'Europe/Paris' }); } catch (_) { return String(d); } }

async function admCourrielAppel(corps) {
  const jeton = typeof rpAdminJeton === 'function' ? rpAdminJeton() : null;
  if (!jeton) return { ok: false, raison: 'session_absente' };
  try {
    const r = await fetch('/api/courriel', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + jeton }, body: JSON.stringify(corps) });
    return await r.json().catch(() => ({ ok: false, raison: 'http_' + r.status }));
  } catch (e) { return { ok: false, raison: 'reseau' }; }
}

async function admCourrielAlerte() {
  const z = document.getElementById('adm-alerte-courriel'); if (!z) return;
  let r;
  try { r = await rpAdminRpc('admin_courriel_echecs_lire', {}); } catch (e) { r = null; }
  z.textContent = '';
  if (!r || r.ok !== true || !(r.echecs || []).length) { z.hidden = true; return; }
  z.hidden = false;
  const t = document.createElement('strong'); t.textContent = 'Alerte e-mails (Brevo)'; z.append(t);
  for (const e of r.echecs) {
    const p = document.createElement('div'); p.style.marginTop = '6px';
    p.textContent = admCourrielMessage(e.raison) + ' — ' + e.compteur + ' échec(s) depuis le ' + admCourrielDate(e.premier_le)
      + ', dernier le ' + admCourrielDate(e.dernier_le) + (e.contexte ? ' (' + (ADM_COURRIEL_CONTEXTES[e.contexte] || e.contexte) + ')' : '')
      + (e.detail ? '. Détail : ' + e.detail : '') + '.';
    z.append(p);
  }
  const b = document.createElement('button'); b.type = 'button'; b.style.marginTop = '8px'; b.textContent = 'Marquer comme lu';
  b.onclick = async () => { const x = await rpAdminRpc('admin_courriel_echecs_acquitter', {}); if (x && x.ok) admCourrielAlerte(); };
  z.append(document.createElement('br'), b);
}

async function admCourrielsCharger() {
  const el = document.getElementById('adm-courriels'); if (!el) return;
  el.textContent = '';
  const f = document.createElement('div'); f.className = 'adm-dossier';
  const etat = document.createElement('div'); etat.className = 'adm-detail';
  let dernier = null;
  const envoyer = document.createElement('button'); envoyer.type = 'button'; envoyer.textContent = 'Envoyer un e-mail de test à l’adresse de ce compte MJ';
  const verifier = document.createElement('button'); verifier.type = 'button'; verifier.textContent = 'Vérifier la livraison'; verifier.disabled = true;
  envoyer.onclick = async () => {
    if (!confirm('Envoyer un e-mail de test à l’adresse de ce compte MJ ?')) return;
    etat.textContent = 'Envoi…';
    const r = await admCourrielAppel({ action: 'test' });
    if (r && r.ok) { dernier = r.messageId; verifier.disabled = !dernier; etat.textContent = 'E-mail accepté par Brevo (message ' + (dernier || '?') + '). Vérifiez la livraison dans une minute.'; }
    else etat.textContent = 'Échec : ' + admCourrielMessage(r && r.raison) + (r && r.detail ? ' Détail : ' + r.detail : '');
    admCourrielAlerte();
  };
  verifier.onclick = async () => {
    etat.textContent = 'Lecture des événements Brevo…';
    const r = await admCourrielAppel({ action: 'test_statut', message_id: dernier });
    if (!r || !r.ok) { etat.textContent = 'Lecture impossible : ' + admCourrielMessage(r && r.raison) + (r && r.detail ? ' Détail : ' + r.detail : ''); return; }
    etat.textContent = (r.livre ? 'Livré. ' : 'Pas encore livré. ') + 'Événements : '
      + ((r.evenements || []).map(e => e.event + ' (' + admCourrielDate(e.date) + (e.reason ? ', ' + e.reason : '') + ')').join(', ') || 'aucun pour l’instant');
  };
  f.append(envoyer, ' ', verifier, etat);
  el.append(f);
}

// Notification d'une sanction par e-mail (après le courrier de jeu). Renvoie un court texte pour le message de confirmation.
async function admCourrielSanction(id) {
  const r = await admCourrielAppel({ action: 'sanction', sanction: id });
  admCourrielAlerte();
  if (r && r.ok) return 'e-mail envoyé';
  if (r && r.raison === 'sans_adresse') return 'e-mail non envoyé : compte sans adresse';
  return 'e-mail non envoyé : ' + admCourrielMessage(r && r.raison);
}
