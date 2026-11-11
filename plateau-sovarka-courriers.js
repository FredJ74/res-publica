// SOVARKA : COURRIERS ET PHRASES DU SERVEUR DANS LA LANGUE DU JOUEUR (11/11/2026, mission i18n de Fred).
// Les fonctions serveur de Sovarka écrivent leurs courriers en français dans public.mails (texte figé,
// historique conservé). Ce module ne change rien à ce texte : à l'affichage, s'il reconnaît EN ENTIER le
// sujet et le corps d'un modèle connu, il présente la même phrase dans la langue choisie, avec les mêmes
// données (noms, partis, titres de lois, motifs, montants, dates) recopiées telles quelles. Sinon, ou en
// français, il rend le courrier d'origine. Aucune décision n'est déduite du texte ; aucun appel serveur.
// Seul le destinataire voit le courrier : la présentation traduite ne révèle rien qu'il n'ait déjà reçu.
(function (global) {
  'use strict';
  const cat = () => global.RPSovarkaMessagesI18n;
  const T = (k, v) => cat().text(k, v);
  const NOMBRE = '-?\\d+(?:[.,]\\d+)?';
  const MOTIFS_VAR = {
    loyer: NOMBRE, prix: NOMBRE, montant: NOMBRE, du: NOMBRE, taux: NOMBRE,
    devise: 'PSK|FR', date: '\\d{2}/\\d{2}', carac: 'CHA|DUP|ENT|INT|PER|VOL',
    creature: 'Loup solitaire|Meute de loups|Ours'
  };
  const CREATURES = { 'Loup solitaire': 'cf_loup', 'Meute de loups': 'cf_meute', Ours: 'cf_ours' };
  // [clé du sujet, clés possibles du corps, expéditeur imposé (null : nom de parti, libre)].
  const MODELES = [
    ['cs_droit_retire', ['cr_droit_retire'], 'Tribunal Populaire'],
    ['cs_demande_acceptee', ['cr_demande_acceptee_loyer', 'cr_demande_acceptee', 'cr_demande_attente'], 'Mairie'],
    ['cs_cession_proposee', ['cr_cession_proposee'], 'Notaire'],
    ['cs_cession_enregistree', ['cr_cession_enregistree'], 'Notaire'],
    ['re_t_conference_presse', ['cr_reu_conference_presse'], "Centre d'affaires de Novomirsk"],
    ['re_t_reseautage', ['cr_reu_reseautage'], "Centre d'affaires de Novomirsk"],
    ['re_t_seminaire', ['cr_reu_seminaire'], "Centre d'affaires de Novomirsk"],
    ['re_t_buffet', ['cr_reu_buffet'], "Centre d'affaires de Novomirsk"],
    ['cs_pm_designe', ['cr_pm_designe'], null],
    ['cs_fin_fonctions', ['cr_fin_fonctions'], null],
    ['cs_demande_adhesion', ['cr_demande_adhesion'], null],
    ['cs_successeur', ['cr_successeur'], null],
    ['cs_adhesion_refusee', ['cr_adhesion_refusee'], null],
    ['cs_adhesion_acceptee', ['cr_adhesion_acceptee_prix', 'cr_adhesion_acceptee'], null],
    ['cs_loi_a_trancher', ['cr_loi_a_trancher'], 'Secrétariat du Conseil du Peuple'],
    ['cs_loi_promulguee', ['cr_loi_promulguee'], 'Conseil du Peuple'],
    ['cs_loi_refusee', ['cr_loi_refusee'], 'Conseil du Peuple'],
    ['cs_saisine', ['cr_saisine'], 'Ministère de la Justice prolétarienne'],
    ['cs_saisine_rejetee', ['cr_saisine_rejetee'], 'Tribunal Populaire'],
    ['cs_conscription', ['cr_conscription'], 'Ministère de la Défense de la Patrie'],
    ['cs_conscription_levee', ['cr_conscription_levee'], 'Ministère de la Défense de la Patrie'],
    ['cs_refractaire', ['cr_refractaire'], 'Ministère de la Défense de la Patrie'],
    ['cs_autocritique', ['cr_autocritique'], 'Conseil du Peuple'],
    ['cs_convocation', ['cr_convocation'], 'Secrétariat du Conseil du Peuple'],
    ['cs_indemnite', ['cr_indemnite'], 'Secrétariat du Conseil du Peuple'],
    ['cs_pressentiment', ['cr_pressentiment'], 'Pressentiment'],
    ['cs_bon_rembourse', ['cr_bon_planche', 'cr_bon'], 'Banque de Sovarka'],
    ['cs_foret', ['cr_foret_victoire_ours', 'cr_foret_victoire'], 'Événement']
  ];
  const echapperRegex = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const cache = {};
  // Le français du catalogue reproduit le texte du serveur : on en tire un motif ancré, variables capturées.
  function motif(cle) {
    if (cache[cle]) return cache[cle];
    const fr = cat().fr(cle);
    const noms = [];
    const re = fr.split(/(\{\w+\})/).map(part => {
      const m = /^\{(\w+)\}$/.exec(part);
      if (!m) return echapperRegex(part);
      if (noms.includes(m[1])) return '\\k<' + m[1] + '>';
      noms.push(m[1]);
      return '(?<' + m[1] + '>' + (MOTIFS_VAR[m[1]] || '[\\s\\S]+?') + ')';
    }).join('');
    return (cache[cle] = new RegExp('^' + re + '$'));
  }
  const capter = (cle, texte) => { const m = motif(cle).exec(String(texte == null ? '' : texte)); return m ? { ...(m.groups || {}) } : null; };
  function presenter(v) {
    const r = { ...v };
    if (r.carac) r.carac = T('re_c_' + r.carac);
    if (r.creature && CREATURES[r.creature]) r.creature = T(CREATURES[r.creature]);
    if (r.odj === cat().fr('cr_odj_vide')) r.odj = T('cr_odj_vide');
    return r;
  }
  function langue() {
    return global.RP_I18N_GAME_ENABLED === true ? (global.RPPlateauI18n?.language?.() || 'fr') : 'fr';
  }
  // Rend { subject, body } traduits, ou null (courrier inconnu, langue française, catalogue absent).
  function traduire(mail) {
    if (!mail || !cat() || langue() === 'fr') return null;
    for (const [cs, corps, expediteur] of MODELES) {
      if (expediteur !== null && mail.from !== expediteur) continue;
      const vs = capter(cs, mail.subject);
      if (!vs) continue;
      for (const cr of corps) {
        const vb = capter(cr, mail.body);
        if (!vb) continue;
        if (Object.keys(vs).some(k => k in vb && vb[k] !== vs[k])) continue;
        const v = presenter({ ...vs, ...vb });
        return { subject: T(cs, v), body: T(cr, v) };
      }
    }
    return null;
  }
  // Courrier tel qu'il doit s'afficher : traduit si reconnu, sinon intact.
  function vu(mail) {
    const t = traduire(mail);
    return t ? { ...mail, subject: t.subject, body: t.body } : mail;
  }
  // Une phrase du serveur (réplique, ragot, fausse alerte, nom fixe) : traduite si elle correspond EN ENTIER
  // à l'un des modèles donnés, sinon null (l'appelant garde alors le texte d'origine).
  function phrase(cles, texte) {
    if (!cat() || langue() === 'fr' || texte == null) return null;
    for (const cle of cles) {
      const v = capter(cle, texte);
      if (v) return T(cle, presenter(v));
    }
    return null;
  }
  // Ragots des maisons : ce que le PJ laisse échapper (sp_) et ce qu'il apprend (sv_). Un ragot répété
  // (« On m'a raconté ici même que … ») n'est traduit que si la phrase rapportée l'est aussi.
  const SECRETS_PJ = ['sp_poste', 'sp_argent', 'sp_vit', 'sp_louche_cible', 'sp_louche', 'sp_rien'];
  const SECRETS_VILLE = ['sv_rien', 'sv_rapport_cible', 'sv_rapport', 'sv_vol_cible', 'sv_vol', 'sv_louche_cible', 'sv_louche'];
  function ragot(texte) {
    if (!cat() || langue() === 'fr' || texte == null) return null;
    // Le ragot rapporté d'abord : les modèles sp_ commencent par un nom libre et l'avaleraient.
    const r = capter('sv_raconte', texte);
    if (r) {
      const rapporte = phrase(SECRETS_PJ, r.ragot.charAt(0).toUpperCase() + r.ragot.slice(1));
      return rapporte ? T('sv_raconte', { ragot: rapporte }) : null;
    }
    return phrase(SECRETS_VILLE.concat(SECRETS_PJ), texte);
  }
  global.RPCourriersSovarka = Object.freeze({ traduire, vu, phrase, ragot, langue, modeles: MODELES.length });
})(typeof window !== 'undefined' ? window : globalThis);
