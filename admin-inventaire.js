// Outils du MJ — capacité d'inventaire d'un personnage (Fred, 22/11/2026, fin de nuit, point 3).
// 100 unités par défaut ; le MJ la règle de 1 à 10 000. Le serveur exige un administrateur (admin_exiger), journalise
// (admin_journal) et prévient aussitôt le joueur : son navigateur relit la nouvelle capacité sans recharger.
async function admInventaireCharger() {
 const el = document.getElementById('adm-inventaire'); if (!el) return;
 el.textContent = '';
 const f = document.createElement('div'); f.className = 'adm-dossier';
 const t = document.createElement('strong'); t.textContent = 'Capacité d’inventaire d’un personnage'; f.append(t);
 const aide = document.createElement('p'); aide.className = 'adm-detail';
 aide.textContent = 'Nombre d’unités qu’un personnage peut porter (100 par défaut). Au-delà, il ne peut plus ramasser, recevoir ni acheter.';
 f.append(aide);
 const ligne = (label, champ) => { const l = document.createElement('label'); l.className = 'adm-detail'; l.style.display = 'block'; l.textContent = label + ' '; l.append(champ); f.append(l); return champ; };
 const nom = document.createElement('input'); nom.type = 'text'; nom.placeholder = 'Nom exact du personnage'; ligne('Personnage', nom);
 const cap = document.createElement('input'); cap.type = 'number'; cap.min = 1; cap.max = 10000; cap.value = 100; ligne('Capacité (unités)', cap);
 const etat = document.createElement('p'); etat.className = 'adm-detail';
 const lireB = document.createElement('button'); lireB.type = 'button'; lireB.textContent = 'Lire';
 lireB.onclick = async () => {
  if (!nom.value.trim()) return;
  try {
   const r = await rpAdminRpc('admin_inventaire_capacite_lire', { p_nom: nom.value.trim() });
   if (r && r.ok) { cap.value = r.capacite; etat.textContent = r.nom + ' porte ' + r.porte + ' unité(s) pour une capacité de ' + r.capacite + '.'; }
   else etat.textContent = 'Refus : ' + (r && r.raison === 'personnage_introuvable' ? 'personnage introuvable.' : (r && r.raison));
  } catch (e) { etat.textContent = 'Échec : ' + e.message; }
 };
 const fixer = document.createElement('button'); fixer.type = 'button'; fixer.textContent = 'Enregistrer';
 fixer.onclick = async () => {
  const n = nom.value.trim(), c = Number(cap.value);
  if (!n || !Number.isInteger(c) || c < 1 || c > 10000) { etat.textContent = 'Indiquez un personnage et une capacité entière entre 1 et 10 000.'; return; }
  if (!confirm('Fixer la capacité de ' + n + ' à ' + c + ' unités ?')) return;
  try {
   const r = await rpAdminRpc('admin_inventaire_capacite_fixer', { p_nom: n, p_capacite: c });
   etat.textContent = r && r.ok ? 'Capacité de ' + r.nom + ' : ' + r.avant + ' → ' + r.capacite + ' (il porte ' + r.porte + ' unité(s)).'
     : 'Refus : ' + (r && r.raison === 'personnage_introuvable' ? 'personnage introuvable.' : (r && r.raison));
  } catch (e) { etat.textContent = 'Échec : ' + e.message; }
 };
 f.append(lireB, ' ', fixer, etat);
 el.append(f);
}
