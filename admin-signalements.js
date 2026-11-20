// File de modération des messages signalés (Fred, 20/11/2026) : courrier, forum, conversations.
// Le serveur trie : ouverts d'abord, impliquant un personnage MINEUR en tête (marqués « mineur »), puis les plus anciens.
// Accès : admin_exiger() côté serveur (admin_signalements_lire, admin_signalement_traiter).
const ADM_SIG_SOURCES = { courrier: 'Courrier', forum: 'Forum', conversation: 'Conversation' };
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
     + ' · signalé par ' + s.signale_par + ' le ' + new Date(s.cree_le).toLocaleString('fr-FR') + ' · message ' + s.message_id;
   bloc.append(info);
   const motif = document.createElement('p'); motif.textContent = 'Motif : ' + (s.motif || ''); bloc.append(motif);
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
   el.append(bloc);
  }
 } catch (e) { el.textContent = 'Erreur : ' + e.message; }
}
