// Outils du MJ — paramètres de la Santé (Fred, 22/11/2026, après-midi, GAME-DESIGN-SANTE-20261122.md).
// Toutes les valeurs chiffrées de la Santé (robustesse, Moral, alcool, sommeil, repas, soins, médecin, MST) sont dans
// sante_parametres. Le serveur exige un administrateur (admin_exiger) et journalise chaque changement (admin_journal).
const ADM_SANTE_GROUPES = { general: 'Général', combat: 'Combat', moral: 'Moral', alcool: 'Alcool', sommeil: 'Sommeil',
  repas: 'Repas', soins: 'Soins', medecin: 'Médecin de terrain', maladies: 'Maladies', medicaments: 'Médicaments', usines: 'Usines d’État' };
async function admSanteCharger() {
 const el = document.getElementById('adm-sante'); if (!el) return;
 el.textContent = 'Chargement…';
 let r;
 try { r = await rpAdminRpc('admin_sante_parametres_lire', {}); } catch (e) { el.textContent = 'Échec : ' + e.message; return; }
 el.textContent = '';
 if (!r || !r.ok) { el.textContent = 'Refus : ' + (r && r.raison); return; }
 const parGroupe = {};
 for (const p of (r.parametres || [])) (parGroupe[p.groupe] = parGroupe[p.groupe] || []).push(p);
 for (const g of Object.keys(parGroupe)) {
  const f = document.createElement('div'); f.className = 'adm-dossier';
  const t = document.createElement('strong'); t.textContent = ADM_SANTE_GROUPES[g] || g; f.append(t);
  for (const p of parGroupe[g]) {
   const l = document.createElement('label'); l.className = 'adm-detail'; l.style.display = 'block';
   l.textContent = (p.libelle || p.cle) + ' ';
   const champ = document.createElement('input'); champ.type = 'number'; champ.step = 'any'; champ.value = p.valeur; champ.style.width = '7rem';
   const b = document.createElement('button'); b.type = 'button'; b.textContent = 'Enregistrer';
   const etat = document.createElement('span'); etat.className = 'adm-detail';
   b.onclick = async () => {
    const v = Number(champ.value);
    if (!Number.isFinite(v)) { etat.textContent = ' Valeur invalide.'; return; }
    if (!confirm('Fixer « ' + (p.libelle || p.cle) + ' » à ' + v + ' ?')) return;
    try {
     const x = await rpAdminRpc('admin_sante_parametre_fixer', { p_cle: p.cle, p_valeur: v });
     etat.textContent = x && x.ok ? ' ' + x.avant + ' → ' + x.valeur : ' Refus : ' + (x && x.raison);
    } catch (e) { etat.textContent = ' Échec : ' + e.message; }
   };
   l.append(champ, ' ', b, etat); f.append(l);
  }
  el.append(f);
 }
}
