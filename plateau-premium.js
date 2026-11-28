// PREMIUM — écran (mission du soir du 25/11/2026, bloc 4 ; décisions de Fred du 25/11 au soir).
// Jamais de pay-to-win : mêmes statistiques en gratuit et en premium. Le serveur décide de tout (premium_droits_lire,
// premium_achat_preparer via /api/paiement, publicite_joueur_*, premium_pub_externe_dormir) ; l'écran n'affiche aucun prix
// que la base ne lui rend pas, et aucun prix n'est écrit ici. Sans la migration 20261125700000 : « inclus pendant la bêta ».
// Pour Codex : tout l'objet TXT ci-dessous (français seulement).
(function () {
  'use strict';
  const TXT = {
    titre: 'Options premium',
    principe: 'Le premium ne donne aucun avantage de jeu : mêmes statistiques pour tous. Il apporte du confort et de la personnalisation.',
    beta: 'Pendant la bêta, toutes les options sont offertes à tous.',
    indisponible: 'Les options premium sont offertes à tous pendant la bêta.',
    abonne: 'Abonnement actif jusqu’au {date}.',
    abonneAnnule: 'Abonnement résilié : il reste actif jusqu’au {date}.',
    semaineLibre: 'Renouvellement d’image de la semaine : disponible.',
    semaineUtilisee: 'Renouvellement d’image de la semaine : utilisé (le suivant la semaine prochaine, sans report).',
    inclusBeta: 'Inclus pendant la bêta',
    inclusAbonnement: 'Inclus dans votre abonnement',
    acquis: 'Option acquise',
    bientot: 'Bientôt disponible',
    acheter: 'Acheter — {prix}',
    commande: 'Ouverture du paiement…',
    refus: 'Achat impossible : {raison}.',
    natureOption: 'Option achetée une fois, qui dure.',
    natureUnite: 'À l’unité.',
    natureAbonnement: 'Toutes les options sans les acheter, et un renouvellement d’image par semaine (non cumulable).',
    fermer: 'Fermer',
    pubTitre: 'Réclame',
    pubPar: 'Une réclame de {nom}',
    pubExterne: 'Publicité',
    pubJoueurs: 'Publicité en ville et au cinéma',
    pubIntro: 'Vantez votre commerce ou votre cause, dans le ton de la ville. Une campagne à la fois par support.',
    pubRue: 'Dans la rue (une apparition par jour et par passant, dans votre ville)',
    pubCinema: 'Au cinéma de Montrouge (avant la séance)',
    pubCourte: 'Campagne courte',
    pubLongue: 'Campagne longue (prix dégressif)',
    pubCommerce: 'Un commerce',
    pubCause: 'Une cause',
    pubTitreChamp: 'Accroche (60 caractères)',
    pubTexteChamp: 'Texte (280 caractères)',
    pubLancer: 'Lancer la campagne',
    pubLancee: 'Campagne lancée jusqu’au {fin}.',
    pubMes: 'Mes campagnes',
    pubRetirer: 'Retirer',
    pubAucune: 'Aucune campagne.',
    autresSupports: 'Autres supports : la rue et le cinéma de Montrouge'
  };
  const RAISONS = {
    prix_non_fixe: 'prix pas encore fixé', inclus_pendant_la_beta: 'inclus pendant la bêta', paiement_inactif: 'paiement pas encore ouvert',
    option_deja_acquise: 'option déjà acquise', deja_abonne: 'déjà abonné', option_premium_requise: 'option premium nécessaire',
    campagne_deja_en_cours: 'une campagne est déjà en cours sur ce support', texte_trop_court: 'texte trop court',
    reserve_proprietaire_fonds: 'réservé au propriétaire du commerce', cible_requise: 'à acheter depuis le lieu concerné'
  };
  const t = (k, v) => String(TXT[k] || k).replace(/\{([a-z]+)\}/g, (m, n) => (v && Object.hasOwn(v, n)) ? String(v[n]) : m);
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const raison = r => RAISONS[r] || String(r || 'indisponible').replace(/_/g, ' ');
  const prix = c => (Number(c) / 100).toLocaleString('fr-FR', { style: 'currency', currency: 'EUR' });
  const dateFr = d => { try { return new Date(d).toLocaleDateString('fr-FR'); } catch (_) { return String(d); } };
  const rpc = async (fn, p) => (typeof sbRpc === 'function') ? sbRpc(fn, p || {}).catch(() => null) : null;
  const un = r => Array.isArray(r) ? r[0] : r;

  async function lireDroits() {
    const r = un(await rpc('premium_droits_lire'));
    return r && r.ok === true ? r : null;
  }

  function modal(titre, html) {
    const m = document.getElementById('modal-postes'), ti = document.getElementById('postes-modal-title'), c = document.getElementById('postes-body');
    if (!m || !c) return null;
    if (ti) ti.textContent = titre;
    c.innerHTML = '<div class="hg-premium" style="padding:1rem;max-width:680px;margin:auto">' + html + '</div>';
    m.classList.add('open');
    return c;
  }

  function etatProduit(d, p) {
    if (p.nature === 'option') {
      if (d.beta) return { etat: t('inclusBeta') };
      if (d.abonne) return { etat: t('inclusAbonnement') };
      if (p.droit) return { etat: t('acquis') };
    }
    if (p.nature === 'abonnement' && d.abonne) return { etat: d.abonnement && d.abonnement.annule ? t('abonneAnnule', { date: dateFr(d.abonnement.fin) }) : t('abonne', { date: dateFr(d.abonnement.fin) }) };
    if (d.beta && p.nature !== 'unite') return { etat: t('inclusBeta') };
    if (!p.prix_fixe || !(Number(p.prix_centimes) >= 200) || !d.paiement_ouvert) return { etat: t('bientot') };
    return { achat: true };
  }

  async function ouvrirPremium(focus, cible) {
    const c = modal(t('titre'), '<p>…</p>');
    if (!c) return;
    const d = await lireDroits();
    let h = '<p>' + esc(t('principe')) + '</p>';
    if (!d) { c.querySelector('.hg-premium').innerHTML = h + '<p><strong>' + esc(t('indisponible')) + '</strong></p>'; return; }
    if (d.beta) h += '<p><strong>' + esc(t('beta')) + '</strong></p>';
    if (d.abonne) h += '<p>' + esc(d.semaine && d.semaine.renouvellement_inclus_utilise ? t('semaineUtilisee') : t('semaineLibre')) + '</p>';
    const ordre = ['commerce_premium', 'bureau_six', 'personnalisation_local', 'publicite_joueur', 'renouvellement_image', 'abonnement_mensuel', 'abonnement_annuel'];
    const produits = (d.produits || []).filter(p => ordre.includes(p.produit)).sort((a, b) => ordre.indexOf(a.produit) - ordre.indexOf(b.produit));
    for (const p of produits) {
      const e = etatProduit(d, p);
      const nat = p.nature === 'option' ? t('natureOption') : p.nature === 'unite' ? t('natureUnite') : t('natureAbonnement');
      h += '<section data-premium-produit="' + esc(p.produit) + '" style="margin:.8rem 0;padding:.8rem;border:1px solid #48576a;border-radius:8px' +
        (p.produit === focus ? ';outline:2px solid #B99A57' : '') + '"><strong>' + esc(p.libelle) + '</strong><div class="cpj-note">' + esc(nat) + '</div>' +
        (e.achat ? '<button type="button" data-premium-acheter="' + esc(p.produit) + '">' + esc(t('acheter', { prix: prix(p.prix_centimes) })) + '</button>'
                 : '<div>' + esc(e.etat) + '</div>') + '</section>';
    }
    h += '<p><button type="button" data-premium-pubs>' + esc(t('pubJoueurs')) + '</button></p><div id="premium-retour" role="status"></div>';
    const zone = c.querySelector('.hg-premium');
    zone.innerHTML = h;
    zone.querySelectorAll('[data-premium-acheter]').forEach(b => b.addEventListener('click', () => {
      const code = b.getAttribute('data-premium-acheter'), c2 = code === focus ? cible : null;
      // Paiement (28/11/2026) : écran de confirmation (vendeur, CGV, renonciation au droit de rétractation) de plateau-paiement.js.
      if (window.RPPaiement && typeof window.RPPaiement.confirmerAchat === 'function') {
        window.RPPaiement.confirmerAchat(code, c2, produits.find(x => x.produit === code)); return;
      }
      commander(code, c2);
    }));
    const pb = zone.querySelector('[data-premium-pubs]');
    if (pb) pb.addEventListener('click', ouvrirPublicitesJoueur);
  }

  async function commander(produit, cible) {
    const retour = document.getElementById('premium-retour');
    if (retour) retour.textContent = t('commande');
    try {
      if (typeof window.rpAuthAssurerSession === 'function') await window.rpAuthAssurerSession();
      const jeton = typeof window.rpAuthJeton === 'function' ? window.rpAuthJeton() : null;
      if (!jeton) { if (retour) retour.textContent = t('refus', { raison: raison('acteur_non_authentifie') }); return; }
      const res = await fetch('/api/paiement', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + jeton },
        body: JSON.stringify({ action: 'commander', produit, cible: cible || null }) });
      const j = await res.json().catch(() => null);
      if (j && j.ok && typeof j.url === 'string' && /^(https:\/\/|\/)/.test(j.url)) { window.location.assign(j.url); return; }
      if (retour) retour.textContent = t('refus', { raison: raison(j && j.raison) });
    } catch (_) { if (retour) retour.textContent = t('refus', { raison: raison('indisponible') }); }
  }

  // Publicités de joueurs (rue, cinéma de Montrouge) : création et suivi.
  async function ouvrirPublicitesJoueur() {
    const c = modal(t('pubJoueurs'), '');
    if (!c) return;
    const z = c.querySelector('.hg-premium');
    z.innerHTML = '<p>' + esc(t('pubIntro')) + '</p>' +
      '<label><input type="radio" name="hg-pub-support" value="rue" checked> ' + esc(t('pubRue')) + '</label><br>' +
      '<label><input type="radio" name="hg-pub-support" value="cinema"> ' + esc(t('pubCinema')) + '</label>' +
      // Deux durées au choix, réglées par le MJ (décision de Fred, 26/11 ; migration 20261125810000).
      '<p><label><input type="radio" name="hg-pub-duree" value="courte" checked> ' + esc(t('pubCourte')) + '</label> ' +
      '<label><input type="radio" name="hg-pub-duree" value="longue"> ' + esc(t('pubLongue')) + '</label></p>' +
      '<p><label><input type="radio" name="hg-pub-objet" value="commerce" checked> ' + esc(t('pubCommerce')) + '</label> ' +
      '<label><input type="radio" name="hg-pub-objet" value="cause"> ' + esc(t('pubCause')) + '</label></p>' +
      '<label for="hg-pub-titre">' + esc(t('pubTitreChamp')) + '</label><input id="hg-pub-titre" maxlength="60" style="display:block;width:100%;margin:.3rem 0 .8rem">' +
      '<label for="hg-pub-texte">' + esc(t('pubTexteChamp')) + '</label><textarea id="hg-pub-texte" maxlength="280" rows="4" style="display:block;width:100%;margin:.3rem 0 .8rem"></textarea>' +
      '<button type="button" id="hg-pub-lancer">' + esc(t('pubLancer')) + '</button><div id="hg-pub-retour" role="status" style="margin:.6rem 0"></div>' +
      '<h4>' + esc(t('pubMes')) + '</h4><div id="hg-pub-mes"></div>';
    z.querySelector('#hg-pub-lancer').addEventListener('click', async () => {
      const support = (z.querySelector('input[name="hg-pub-support"]:checked') || {}).value;
      const objet = (z.querySelector('input[name="hg-pub-objet"]:checked') || {}).value;
      const duree = (z.querySelector('input[name="hg-pub-duree"]:checked') || {}).value || 'courte';
      const r = un(await rpc('publicite_joueur_creer', { p_support: support, p_objet: objet,
        p_titre: z.querySelector('#hg-pub-titre').value, p_texte: z.querySelector('#hg-pub-texte').value, p_duree: duree }));
      z.querySelector('#hg-pub-retour').textContent = r && r.ok ? t('pubLancee', { fin: dateFr(r.fin) }) : t('refus', { raison: raison(r ? r.raison : 'indisponible') });
      mesPublicites(z.querySelector('#hg-pub-mes'));
    });
    mesPublicites(z.querySelector('#hg-pub-mes'));
  }
  async function mesPublicites(el) {
    if (!el) return;
    const r = un(await rpc('publicite_joueur_mes'));
    const l = (r && r.publicites) || [];
    el.textContent = '';
    if (!l.length) { el.textContent = t('pubAucune'); return; }
    for (const p of l) {
      const d = document.createElement('div'); d.className = 'cpj-note';
      d.textContent = (p.support === 'cinema' ? '🎬 ' : '🏙️ ') + p.titre + ' — ' + dateFr(p.debut) + ' → ' + dateFr(p.fin) + ' (' + p.statut + ')';
      if (p.statut === 'active') {
        const b = document.createElement('button'); b.type = 'button'; b.textContent = t('pubRetirer');
        b.onclick = async () => { await rpc('publicite_joueur_retirer', { p_id: p.id }); mesPublicites(el); };
        d.append(' ', b);
      }
      el.append(d);
    }
  }

  // Petite fenêtre de réclame (pop-up en ville, réclame au cinéma, publicité au réveil). Texte toujours échappé.
  function afficherReclame(titre, corps, signature, image, lien) {
    if (typeof document === 'undefined' || document.getElementById('hg-reclame')) return;
    const d = document.createElement('div');
    d.id = 'hg-reclame'; d.setAttribute('role', 'dialog'); d.setAttribute('aria-label', titre);
    d.style.cssText = 'position:fixed;right:16px;bottom:16px;max-width:min(360px,calc(100vw - 32px));z-index:9999;background:#1d232c;color:#e0e6ed;' +
      'border:1px solid #B99A57;border-radius:10px;padding:14px 16px;box-shadow:0 6px 24px rgba(0,0,0,.5);font-size:.92rem;line-height:1.45';
    d.innerHTML = '<div style="font-size:.72rem;letter-spacing:.08em;text-transform:uppercase;color:#B99A57">' + esc(signature) + '</div>' +
      '<div style="font-weight:700;margin:.3rem 0;color:#E5C477">' + esc(titre) + '</div>' +
      (image && /^https:\/\//.test(image) ? '<img src="' + esc(image) + '" alt="" style="max-width:100%;border-radius:6px;margin:.3rem 0">' : '') +
      '<div>' + esc(corps) + '</div>' +
      (lien && /^https:\/\//.test(lien) ? '<a href="' + esc(lien) + '" target="_blank" rel="noopener noreferrer sponsored">' + esc(lien.replace(/^https:\/\//, '').slice(0, 40)) + '</a>' : '') +
      '<div style="text-align:right;margin-top:.5rem"><button type="button">' + esc(t('fermer')) + '</button></div>';
    d.querySelector('button').addEventListener('click', () => d.remove());
    document.body.appendChild(d);
  }

  // Une demande par support et par jour au plus (le serveur tient le vrai compte : une apparition par jour et par joueur).
  const demandes = {};
  const jourParis = () => { try { return new Date().toLocaleDateString('fr-CA', { timeZone: 'Europe/Paris' }); } catch (_) { return new Date().toISOString().slice(0, 10); } };
  async function tirer(support) {
    const k = support + ':' + jourParis();
    if (demandes[k]) return;
    demandes[k] = true;
    const r = un(await rpc('publicite_joueur_tirer', { p_support: support }));
    const p = r && r.ok && r.publicite;
    if (p) afficherReclame(p.titre, p.texte, t('pubPar', { nom: p.annonceur }));
  }
  function encadreReclames(buildingId, roomId) {
    try {
      if (typeof state === 'undefined' || !state || !state.char || !state.char.name) return '';
      if (buildingId === 'cinema-montrouge' && /^salle_[12]$/.test(String(roomId))) setTimeout(() => tirer('cinema'), 400);
      else setTimeout(() => tirer('rue'), 1500);
    } catch (_) { /* jamais d'effet sur les ordres */ }
    return '';
  }

  // Publicité des annonceurs extérieurs, au réveil (Dormir) : le serveur décide (réglage MJ, abonnés exclus, une par jour).
  async function pubExterneAuDormir() {
    const r = un(await rpc('premium_pub_externe_dormir'));
    const a = r && r.ok && r.annonce;
    if (a && a.texte) afficherReclame(a.annonceur || t('pubExterne'), a.texte, t('pubExterne'), a.image_url, a.lien_url);
  }

  if (typeof window !== 'undefined') {
    window.ouvrirPremium = ouvrirPremium;
    window.ouvrirPublicitesJoueur = ouvrirPublicitesJoueur;
    window.premiumPubExterneAuDormir = pubExterneAuDormir;
    window.RPPremium = Object.freeze({ lireDroits, ouvrirPremium, ouvrirPublicitesJoueur, pubExterneAuDormir, tirer, afficherReclame, TXT });
    window.RP_ENCADRES_PIECE = window.RP_ENCADRES_PIECE || [];
    if (!window.RP_ENCADRES_PIECE.includes(encadreReclames)) window.RP_ENCADRES_PIECE.push(encadreReclames);
  }
})();
