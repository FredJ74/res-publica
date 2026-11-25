// Outils du MJ — comptes de test (Fred, 24 et 25/11/2026, purge A.1 et mission de jour 1.3).
// Liste des comptes de test (Arnie, Tom Tom, Bernard Bernardov) et interrupteur qui les RÉINTÈGRE dans le dépouillement des
// élections le temps d'un test ; il s'éteint de lui-même à l'heure choisie. Le serveur exige un administrateur (admin_exiger)
// et journalise chaque changement. Sans la migration 20261125160000, l'interrupteur est annoncé indisponible.
async function admComptesTestCharger() {
 const el = document.getElementById('adm-comptes-test'); if (!el) return;
 el.textContent = 'Chargement…';
 let r;
 try { r = await rpAdminRpc('admin_comptes_test_lire', {}); } catch (e) { el.textContent = 'Échec : ' + e.message; return; }
 el.textContent = '';
 if (!r || !r.ok) { el.textContent = 'Refus : ' + (r && r.raison); return; }
 const f = document.createElement('div'); f.className = 'adm-dossier';
 const t = document.createElement('strong'); t.textContent = 'Comptes de test'; f.append(t);
 const l = document.createElement('p'); l.className = 'adm-detail';
 l.textContent = 'Personnages : ' + ((r.personnages || []).join(', ') || 'aucun') + '.';
 f.append(l);
 const etat = document.createElement('p'); etat.className = 'adm-detail';
 if (r.elections_inclus === undefined) {
  etat.textContent = 'Interrupteur des élections indisponible (migration non appliquée) : les comptes de test restent exclus du dépouillement.';
  f.append(etat); el.append(f); return;
 }
 etat.textContent = r.elections_inclus
  ? 'Élections : comptes de test RÉINTÉGRÉS dans le dépouillement jusqu’au ' + new Date(r.elections_inclus_jusqu_au).toLocaleString('fr-FR') + '.'
  : 'Élections : comptes de test exclus du dépouillement (réglage normal).';
 f.append(etat);
 const duree = document.createElement('input'); duree.type = 'number'; duree.min = 1; duree.max = 720; duree.value = 48; duree.style.width = '5rem';
 const on = document.createElement('button'); on.type = 'button'; on.textContent = 'Réintégrer pour un test (heures)';
 const off = document.createElement('button'); off.type = 'button'; off.textContent = 'Les exclure de nouveau';
 const msg = document.createElement('span'); msg.className = 'adm-detail';
 const fixer = async (actif) => {
  const h = Number(duree.value);
  if (actif && (!Number.isInteger(h) || h < 1 || h > 720)) { msg.textContent = ' Durée invalide (1 à 720 heures).'; return; }
  if (!confirm(actif ? 'Réintégrer les comptes de test dans le dépouillement des élections pendant ' + h + ' h ?' : 'Exclure de nouveau les comptes de test des élections ?')) return;
  try {
   const x = await rpAdminRpc('admin_comptes_test_elections_fixer', { p_actif: actif, p_heures: actif ? h : null });
   if (x && x.ok) admComptesTestCharger(); else msg.textContent = ' Refus : ' + (x && x.raison);
  } catch (e) { msg.textContent = ' Échec : ' + e.message; }
 };
 on.onclick = () => fixer(true); off.onclick = () => fixer(false);
 const ligne = document.createElement('div'); ligne.className = 'adm-detail';
 ligne.append(duree, ' ', on, ' ', off, msg); f.append(ligne);
 el.append(f);
}
