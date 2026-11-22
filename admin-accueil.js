// Outils du MJ — accueil des nouveaux joueurs (Fred, 22/11/2026, soir, GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, partie D).
// Réglages de accueil_parametres (ouverture automatique de l'interview, longueur du mot libre, bulle des PA). Le serveur exige
// un administrateur (admin_exiger) et journalise chaque changement (admin_journal).
async function admAccueilCharger() {
 const el = document.getElementById('adm-accueil'); if (!el) return;
 el.textContent = 'Chargement…';
 let r;
 try { r = await rpAdminRpc('admin_accueil_parametres_lire', {}); } catch (e) { el.textContent = 'Échec : ' + e.message; return; }
 el.textContent = '';
 if (!r || !r.ok) { el.textContent = 'Refus : ' + (r && r.raison); return; }
 const f = document.createElement('div'); f.className = 'adm-dossier';
 const t = document.createElement('strong'); t.textContent = 'Accueil des nouveaux joueurs'; f.append(t);
 for (const p of (r.parametres || [])) {
  const l = document.createElement('label'); l.className = 'adm-detail'; l.style.display = 'block';
  l.textContent = (p.libelle || p.cle) + ' ';
  const champ = document.createElement('input'); champ.type = 'number'; champ.step = 'any'; champ.min = 0; champ.value = p.valeur; champ.style.width = '7rem';
  const b = document.createElement('button'); b.type = 'button'; b.textContent = 'Enregistrer';
  const etat = document.createElement('span'); etat.className = 'adm-detail';
  b.onclick = async () => {
   const v = Number(champ.value);
   if (!Number.isFinite(v) || v < 0) { etat.textContent = ' Valeur invalide.'; return; }
   if (!confirm('Fixer « ' + (p.libelle || p.cle) + ' » à ' + v + ' ?')) return;
   try {
    const x = await rpAdminRpc('admin_accueil_parametre_fixer', { p_cle: p.cle, p_valeur: v });
    etat.textContent = x && x.ok ? ' ' + x.avant + ' → ' + x.valeur : ' Refus : ' + (x && x.raison);
   } catch (e) { etat.textContent = ' Échec : ' + e.message; }
  };
  l.append(champ, ' ', b, etat); f.append(l);
 }
 el.append(f);
}
