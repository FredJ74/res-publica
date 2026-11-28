// Page MJ — Premium (mission du soir du 25/11/2026, bloc 4). Prix en euros, réglages MJ : aucun prix par défaut ;
// la base refuse tout prix sous 2 € (commission fixe par paiement). Bêta « tout gratuit », publicité extérieure, durée des
// campagnes de joueurs, modération des publicités de joueurs. Pour Codex : page MJ, français seulement.
async function admPremiumCharger() {
  const el = document.getElementById('adm-premium'); if (!el) return;
  el.textContent = 'Chargement…';
  let r;
  try { r = await rpAdminRpc('premium_admin_lire', {}); } catch (e) { el.textContent = 'Échec : ' + e.message + ' (migration 20261125700000 non appliquée ?)'; return; }
  el.textContent = '';
  if (!r || !r.ok) { el.textContent = 'Refus : ' + (r && r.raison); return; }
  const p = r.parametres || {};
  const bloc = (titre) => { const f = document.createElement('div'); f.className = 'adm-dossier'; const t = document.createElement('strong'); t.textContent = titre; f.append(t); el.append(f); return f; };
  const ligne = (f, ...enfants) => { const d = document.createElement('div'); d.className = 'adm-detail'; d.append(...enfants); f.append(d); return d; };
  const msg = () => { const s = document.createElement('span'); s.className = 'adm-detail'; return s; };
  const bouton = (texte, fn) => { const b = document.createElement('button'); b.type = 'button'; b.textContent = texte; b.onclick = fn; return b; };
  const appliquer = async (fn, params, m) => {
    try { const x = await rpAdminRpc(fn, params); if (x && x.ok) admPremiumCharger(); else m.textContent = ' Refus : ' + (x && x.raison); }
    catch (e) { m.textContent = ' Échec : ' + e.message; }
  };

  const g = bloc('Réglages');
  const m1 = msg();
  ligne(g, 'Bêta : options offertes à tous — ' + (p.beta_tout_gratuit === '1' ? 'OUI ' : 'NON '),
    bouton(p.beta_tout_gratuit === '1' ? 'Terminer la gratuité' : 'Rendre tout gratuit', () => {
      if (p.beta_tout_gratuit === '1' && !window.confirm('Terminer la gratuité de la bêta ? Les options deviennent payantes (si un prix est fixé).')) return;
      appliquer('premium_admin_parametre_fixer', { p_cle: 'beta_tout_gratuit', p_valeur: p.beta_tout_gratuit === '1' ? '0' : '1' }, m1);
    }), m1);
  const m2 = msg();
  ligne(g, 'Publicité des annonceurs au réveil (joueurs gratuits, une par jour) — ' + (p.pub_externe_active === '1' ? 'ACTIVE ' : 'éteinte '),
    bouton(p.pub_externe_active === '1' ? 'Éteindre' : 'Activer', () => appliquer('premium_admin_parametre_fixer',
      { p_cle: 'pub_externe_active', p_valeur: p.pub_externe_active === '1' ? '0' : '1' }, m2)), m2);
  // Publicités de joueurs (décision de Fred, 26/11) : deux durées de campagne, courte et longue, en jours (courte < longue).
  const champJours = v => { const x = document.createElement('input'); x.type = 'number'; x.min = 1; x.max = 60; x.value = v; x.style.width = '4rem'; return x; };
  const courte = champJours(p.publicite_duree_courte || 5), longue = champJours(p.publicite_duree_longue || 10);
  const m3 = msg(), m4 = msg();
  ligne(g, 'Campagne de publicité courte (jours) : ', courte, ' ',
    bouton('Enregistrer', () => appliquer('premium_admin_parametre_fixer', { p_cle: 'publicite_duree_courte', p_valeur: String(courte.value) }, m3)), m3);
  ligne(g, 'Campagne de publicité longue (jours) : ', longue, ' ',
    bouton('Enregistrer', () => appliquer('premium_admin_parametre_fixer', { p_cle: 'publicite_duree_longue', p_valeur: String(longue.value) }, m4)), m4);

  // Paiement par Stripe en fonctionnement mixte (décision de Fred, 28/11/2026) : UE → éditeur vendeur (Stripe classique),
  // reste du monde → Stripe vendeur (Managed Payments). Les clés Stripe restent dans Vercel, jamais ici.
  const pa = bloc('Paiement (Stripe) — France et UE : l’éditeur vend ; reste du monde : Stripe vend (Managed Payments)');
  const bascule = (cle, libelle, oui, non) => { const m = msg(); ligne(pa, libelle + ' — ' + (p[cle] === '1' ? oui + ' ' : non + ' '),
    bouton(p[cle] === '1' ? 'Désactiver' : 'Activer', () => appliquer('premium_admin_paiement_fixer', { p_cle: cle, p_valeur: p[cle] === '1' ? '0' : '1' }, m)), m); };
  bascule('paiement_mp_actif', 'Managed Payments activé dans le compte Stripe (sinon : aucun achat hors UE)', 'OUI', 'non');
  bascule('paiement_mp_pour_ue', 'Managed Payments aussi pour la France et l’UE (Stripe vendeur partout)', 'OUI', 'non');
  const texte = (cle, libelle, largeur) => {
    const x = document.createElement('input'); x.type = 'text'; x.value = p[cle] || ''; x.style.width = largeur || '22rem';
    const m = msg(); ligne(pa, libelle + ' : ', x, ' ', bouton('Enregistrer', () => appliquer('premium_admin_paiement_fixer', { p_cle: cle, p_valeur: x.value }, m)), m);
  };
  texte('vendeur_editeur_nom', 'Nom de l’éditeur affiché comme vendeur (UE)');
  texte('cgv_url', 'Adresse des CGV (sans CGV : aucun achat réel)');
  texte('paiement_pays_exclus', 'Pays sans achats (codes à deux lettres, séparés par des virgules)', '30rem');
  texte('paiement_pays_ue', 'Pays vendus par l’éditeur (France et UE)', '30rem');
  texte('rappel_annuel_jours', 'Rappel avant renouvellement annuel (jours, 30 à 60)', '4rem');

  const pr = bloc('Prix (euros TTC, 2 € minimum ; vide = pas encore fixé, rien n’est affiché aux joueurs ; campagne longue : prix par jour plus bas que la courte)');
  for (const x of r.produits || []) {
    const champ = document.createElement('input'); champ.type = 'number'; champ.min = 2; champ.step = '0.01'; champ.style.width = '6rem';
    champ.value = x.prix_centimes == null ? '' : (x.prix_centimes / 100).toFixed(2);
    const m = msg();
    ligne(pr, x.libelle + ' (' + x.nature + ') : ', champ, ' € ', bouton('Fixer', () => {
      const v = champ.value.trim();
      const c = v === '' ? null : Math.round(Number(v.replace(',', '.')) * 100);
      if (c !== null && !(c >= 200)) { m.textContent = ' Refus : 2 € minimum.'; return; }
      appliquer('premium_admin_prix_fixer', { p_produit: x.produit, p_centimes: c }, m);
    }), m);
  }

  const st = bloc('État');
  ligne(st, 'Abonnés : ' + (r.abonnes || 0) + ' · achats payés : ' + ((r.achats || {}).payes || 0) + ' · en attente : ' + ((r.achats || {}).en_attente || 0) +
    ' · annonces extérieures : ' + (r.annonces || []).length + ' (aucune régie branchée).');

  const pubs = bloc('Publicités de joueurs en cours');
  if (!(r.publicites_joueurs || []).length) ligne(pubs, 'Aucune.');
  for (const x of r.publicites_joueurs || []) {
    const m = msg();
    ligne(pubs, '[' + x.support + ', ' + x.ville + ', jusqu’au ' + x.fin + '] ' + x.personnage + ' — « ' + x.titre + ' » ' + x.texte + ' ',
      bouton('Retirer', () => { const motif = window.prompt('Motif du retrait :', 'modération'); if (motif !== null) appliquer('premium_admin_publicite_retirer', { p_id: x.id, p_motif: motif }, m); }), m);
  }
}
