// File de modération des messages signalés (Fred, 20/11/2026) : courrier, forum, conversations.
// Depuis le 28/11/2026 : aussi les images personnalisées et les noms de personnages (contenu_signaler), et les sanctions
// (admin_sanction_prononcer) : toute sanction est notifiée au joueur avec sa raison (règle enfreinte, contenu visé,
// durée, contestation possible à contact@human-gambit.com) par un courrier « Modération » et une fenêtre à sa connexion.
// Le serveur trie : ouverts d'abord, impliquant un personnage MINEUR en tête (marqués « mineur »), puis les plus anciens.
// Accès : admin_exiger() côté serveur (admin_signalements_lire, admin_signalement_traiter, admin_sanction_*).
const ADM_SIG_SOURCES = { courrier: 'Courrier', forum: 'Forum', conversation: 'Conversation', image: 'Image personnalisée', nom: 'Nom de personnage' };
const ADM_SANCTIONS = { avertissement: 'Avertissement', retrait_contenu: 'Retrait du contenu', suspension: 'Suspension (ordres, forum, courrier et chat bloqués)' };
function admSignalementFormSanction(s, tous) {
 const f = document.createElement('form'); f.className = 'adm-detail';
 f.style.margin = '.5rem 0'; f.style.display = 'grid'; f.style.gap = '.3rem'; f.style.maxWidth = '36rem';
 const champ = (libelle, el) => { const l = document.createElement('label'); l.textContent = libelle + ' '; l.append(el); f.append(l); return el; };
 const type = document.createElement('select');
 for (const [v, l] of Object.entries(ADM_SANCTIONS)) { const o = document.createElement('option'); o.value = v; o.textContent = l; type.append(o); }
 champ('Sanction', type);
 const regle = champ('Règle enfreinte', Object.assign(document.createElement('input'), { required: true, maxLength: 300, placeholder: 'Ex. : Charte de conduite, article 3 (respect des autres joueurs)' }));
 const contenu = champ('Contenu visé', Object.assign(document.createElement('textarea'), { rows: 2, maxLength: 2000, value: s.extrait || '' }));
 const duree = champ('Durée (jours, suspension seulement)', Object.assign(document.createElement('input'), { type: 'number', min: 1, max: 3650, value: 3 }));
 const raison = champ('Raison communiquée au joueur', Object.assign(document.createElement('textarea'), { rows: 2, required: true, maxLength: 1000 }));
 const maj = () => { duree.disabled = type.value !== 'suspension'; }; type.onchange = maj; maj();
 const b = document.createElement('button'); b.type = 'submit'; b.textContent = 'Prononcer et notifier ' + (s.auteur || '');
 f.append(b);
 f.onsubmit = async (e) => {
  e.preventDefault();
  try {
   const r = await rpAdminRpc('admin_sanction_prononcer', { p_signalement_id: s.id, p_personnage: s.auteur || null, p_type: type.value,
     p_regle: regle.value, p_contenu: contenu.value, p_raison: raison.value, p_duree_jours: type.value === 'suspension' ? Number(duree.value) : null });
   if (!r || r.ok !== true) throw Error((r && r.raison) || 'refus');
   alert('Sanction enregistrée et notifiée' + (r.notification && r.notification.ok === true ? '.' : ' (courrier non posé : ' + JSON.stringify(r.notification) + ').'));
   admSignalementsCharger(tous);
  } catch (err) { alert('Non enregistré : ' + err.message); }
 };
 return f;
}
async function admSignalementsCharger(tous) {
 const el = document.getElementById('adm-signalements'); if (!el) return;
 el.textContent = 'Chargement…';
 try {
  const d = await rpAdminRpc('admin_signalements_lire', { p_tous: !!tous });
  const liste = (d && d.signalements) || [];
  el.textContent = '';
  if (!liste.length) { el.textContent = 'Aucun signalement en attente.'; return; }
  for (const s of liste) {
   const bloc = document.createElement('div'); bloc.className = 'adm-dossier';
   if (s.mineur) bloc.style.borderLeft = '4px solid #c0392b';
   const titre = document.createElement('strong');
   titre.textContent = (s.mineur ? '[MINEUR] ' : '') + (ADM_SIG_SOURCES[s.source] || s.source) + ' — ' + (s.statut || '');
   bloc.append(titre);
   const info = document.createElement('p'); info.className = 'adm-detail';
   info.textContent = 'Auteur : ' + (s.auteur || '?') + (s.destinataires && s.destinataires.length ? ' · destinataire(s) : ' + s.destinataires.join(', ') : '')
     + ' · signalé par ' + s.signale_par + ' le ' + new Date(s.cree_le).toLocaleString('fr-FR') + ' · ' + (s.source === 'image' || s.source === 'nom' ? 'contenu' : 'message') + ' ' + s.message_id;
   bloc.append(info);
   const motif = document.createElement('p'); motif.textContent = 'Motif : ' + (s.motif || ''); bloc.append(motif);
   if (s.source === 'image' && /^(https?:\/\/|\/?images\/)/i.test(String(s.extrait || ''))) {
    const img = document.createElement('img'); img.src = s.extrait; img.alt = 'Image signalée'; img.loading = 'lazy';
    img.style.maxWidth = '18rem'; img.style.maxHeight = '12rem'; img.style.display = 'block'; bloc.append(img);
   }
   const extrait = document.createElement('pre'); extrait.style.whiteSpace = 'pre-wrap'; extrait.style.maxHeight = '12em'; extrait.style.overflow = 'auto';
   extrait.textContent = s.extrait || '(message introuvable)'; bloc.append(extrait);
   for (const [statut, libelle] of [['traite', 'Marquer traité'], ['rejete', 'Rejeter'], ['ouvert', 'Rouvrir']]) {
    if (statut === s.statut) continue;
    const b = document.createElement('button'); b.type = 'button'; b.textContent = libelle;
    b.onclick = async () => {
     try {
      const r = await rpAdminRpc('admin_signalement_traiter', { p_id: s.id, p_statut: statut });
      if (!r || r.ok !== true) throw Error((r && r.raison) || 'refus');
      admSignalementsCharger(tous);
     } catch (e) { alert('Non enregistré : ' + e.message); }
    };
    bloc.append(b, ' ');
   }
   if (s.auteur) {
    const bs = document.createElement('button'); bs.type = 'button'; bs.textContent = 'Sanctionner…';
    bs.onclick = () => { if (!bloc.querySelector('form')) bloc.append(admSignalementFormSanction(s, tous)); };
    bloc.append(bs);
   }
   el.append(bloc);
  }
 } catch (e) { el.textContent = 'Erreur : ' + e.message; }
}
