// ACCUEIL DES NOUVEAUX JOUEURS (Fred, 22/11/2026, GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, partie D, points 23 à 26).
//  23. À la première connexion, l'interview RP s'ouvre d'elle-même : Jodie Moitout en Républia, Vera Pravdina (La Voix
//      de Sovarka) en Sovarka. Six chemins et un mot libre ; l'article est publié par /api/journal-interview
//      (action 'accueil_publier', mode accueil d'interviews_jodie ; en Sovarka, retouché à la gloire du Parti).
//  24. Le chemin choisi dépose dans « Mes objectifs » un parcours de trois étapes (lieu, ordre existant, PNJ référent).
//      Une étape liée à un ordre payant est validée par le serveur quand l'ordre est payé ; les autres par le bouton
//      « J'ai fait cette étape » (enregistré au serveur).
//  25. En se fermant, la fenêtre se réduit et file vers « Mes objectifs ». Fermée sans réponse, l'interview reste dans
//      « Mes objectifs » comme première étape, à reprendre ou à ignorer.
//  26. Au premier ordre qui coûte des PA, la jauge des PA s'allume et une bulle HRP s'ouvre à côté. Une seule fois par
//      personnage : le serveur le mémorise (accueil_personnages.bulle_pa_le) et prévient par personnage_evenements.
// Le serveur décide de tout (RPC accueil_*, migration 20261123140000) : ce module affiche et transmet des intentions.
(function (global) {
  'use strict';
  const doc = global.document;
  if (!doc) return;

  const TXT = {
    attend: '{j} vous attend pour une interview',
    redige: '{j} rédige votre article',
    reprendre: "Reprendre l'interview",
    ignorer: 'Ignorer',
    intro: '{j}, {journal}, vous tend son micro.',
    motLabel: 'Un mot à vous (facultatif)',
    motAide: 'Ce que vous voulez que les lecteurs sachent de vous.',
    repondre: 'Répondre',
    plusTard: 'Plus tard',
    fermer: 'Fermer',
    fermerAria: "Fermer l'interview",
    choisirChemin: 'Choisissez un chemin pour répondre.',
    enregistre: 'Réponse enregistrée : {c}. {j} rédige son article…',
    publier: "Publier l'article",
    publie: 'Publié par {j}',
    attentePublication: "L'article paraîtra dans la prochaine édition du journal.",
    echecPublication: "{j} n'arrive pas à finaliser son article pour le moment. Votre réponse est gardée : réessayez, ou reprenez plus tard depuis Mes objectifs.",
    echecChoix: "Réponse non enregistrée. Réessayez dans un instant.",
    parcoursDepose: 'Votre parcours « {c} » vous attend dans Mes objectifs.',
    parcoursTitre: 'Votre parcours : {c}',
    ou: 'Où : {l}',
    jaiFait: "J'ai fait cette étape",
    auto: "Se coche d'elle-même quand le serveur voit passer cet ordre ; sinon, cochez-la.",
    bulle: 'Vous venez de dépenser {pa} PA. Les PA sont votre énergie du jour : chaque action en coûte. Dormir les recharge. À 0, c\'est l\'hôpital.',
    hrp: 'Hors jeu',
    compris: 'Compris'
  };
  // Portraits des deux journalistes (Vera Pravdina : portrait fourni par Fred le 23/11/2026, point 15 ; plus de pastille « V »).
  const PORTRAITS = { 'Jodie Moitout': 'images/jodie-moitout.webp', 'Vera Pravdina': 'images/Sovarka/Novomirsk/Novo_vera_pravdina_portrait.webp' };
  const f = (t, v) => String(t).replace(/\{(\w+)\}/g, (_, k) => (v && v[k] != null ? v[k] : ''));
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  let etat = null, pourNom = null, chargement = null, fenetre = null, choix = null, publication = false, article = null;

  // ------------------------------------------------------------------ styles (texte jamais sous 0,95 rem)
  function styles() {
    if (doc.getElementById('hg-accueil-styles')) return;
    const s = doc.createElement('style');
    s.id = 'hg-accueil-styles';
    s.textContent = [
      '#hg-accueil-interview{position:fixed;inset:0;z-index:12000;display:flex;align-items:center;justify-content:center;padding:16px;background:rgba(5,4,2,.72)}',
      '#hg-accueil-interview.hg-acc-part{background:rgba(5,4,2,0);transition:background .5s}',
      '.hg-acc-carte{position:relative;width:min(560px,100%);max-height:calc(100vh - 32px);overflow-y:auto;box-sizing:border-box;background:#0f0d07;border:1px solid #6a5420;border-radius:6px;padding:20px;color:#f0ead6;font-family:"Crimson Pro",Georgia,serif;font-size:1.05rem;line-height:1.45;box-shadow:0 12px 48px rgba(0,0,0,.6);transform-origin:center}',
      '.hg-acc-carte.hg-acc-file{transition:transform .65s cubic-bezier(.55,0,.75,.2),opacity .65s ease-in;opacity:.15}',
      '.hg-acc-fermer{position:absolute;top:8px;right:8px;width:44px;height:44px;border:0;background:transparent;color:#e8dcb0;font-size:1.6rem;cursor:pointer;line-height:1}',
      '.hg-acc-entete{display:flex;align-items:center;gap:12px;margin:0 40px 12px 0}',
      '.hg-acc-portrait{width:64px;height:64px;border-radius:50%;object-fit:cover;object-position:62% 20%;border:1px solid #6a5420;flex:none;background:#1a160a;display:flex;align-items:center;justify-content:center;font-size:1.6rem;color:#C9A84C}',
      '.hg-acc-nom{margin:0;font-family:"Playfair Display",Georgia,serif;font-size:1.25rem;color:#E8D880}',
      '.hg-acc-journal{margin:0;font-size:1rem;color:#cfc3a0}',
      '.hg-acc-question{font-size:1.15rem;color:#fbf6e6;margin:0 0 14px}',
      '.hg-acc-chemins{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:0 0 14px}',
      '@media (max-width:520px){.hg-acc-chemins{grid-template-columns:1fr}}',
      '.hg-acc-chemin{min-height:44px;padding:8px 10px;border:1px solid #4a3c18;border-radius:4px;background:#17130a;color:#f0ead6;font:inherit;font-size:1rem;text-align:left;cursor:pointer}',
      '.hg-acc-chemin[aria-checked="true"]{border-color:#E8C860;background:#2a2108;color:#fff4c8;box-shadow:0 0 0 1px #E8C860 inset}',
      '.hg-acc-label{display:block;font-size:1rem;color:#e8dcb0;margin:0 0 4px}',
      '.hg-acc-aide{font-size:.95rem;color:#c8bc98;margin:0 0 6px}',
      '.hg-acc-mot{width:100%;box-sizing:border-box;min-height:72px;background:#121005;border:1px solid #4a3c18;color:#f0ead6;padding:8px;font:inherit;font-size:1rem;resize:vertical}',
      '.hg-acc-actions{display:flex;flex-wrap:wrap;gap:8px;margin-top:14px}',
      '.hg-acc-btn{min-height:44px;padding:8px 16px;border:1px solid #8a6a20;border-radius:4px;background:#2a2108;color:#fff4c8;font:inherit;font-size:1rem;cursor:pointer}',
      '.hg-acc-btn[disabled]{opacity:.55;cursor:not-allowed}',
      '.hg-acc-btn.hg-acc-second{background:transparent;color:#e8dcb0;border-color:#4a3c18}',
      '.hg-acc-msg{font-size:1rem;color:#e8dcb0;margin:10px 0 0;min-height:1em}',
      '.hg-acc-msg.hg-acc-erreur{color:#ff9d8a}',
      '.hg-acc-article{margin-top:12px;padding:12px;border:1px solid #3a2a10;background:#0b0904}',
      '.hg-acc-article h3{margin:0 0 6px;font-family:"Playfair Display",Georgia,serif;font-size:1.15rem;color:#E8D880}',
      '.hg-acc-article p{margin:0;white-space:pre-wrap;font-size:1rem;color:#e6dcc0}',
      '.hg-acc-surtitre{font-size:.95rem;color:#d8b860;margin:0 0 4px}',
      // Mes objectifs
      '.hg-acc-obj{padding:0 0 .4rem;font-size:1rem}',
      '.hg-acc-obj-ligne{display:flex;align-items:flex-start;gap:.6rem;padding:.5rem .4rem;border-bottom:1px solid #1a1810}',
      '.hg-acc-obj-ligne .hg-acc-coche{font-size:1rem;line-height:1.4}',
      '.hg-acc-obj-texte{flex:1;font-size:1rem;color:#e6dcc0}',
      '.hg-acc-obj-texte.fait{color:#7fc07f}',
      '.hg-acc-obj-lieu{font-size:.95rem;color:#c8bc98;margin-top:2px}',
      '.hg-acc-obj-titre{font-family:"Bebas Neue",sans-serif;letter-spacing:.06em;font-size:1.05rem;color:#C9A84C;margin:.4rem 0 .2rem}',
      '.hg-acc-obj-actions{display:flex;flex-wrap:wrap;gap:6px;margin-top:6px}',
      '#postes-body [data-accueil-objectifs] .hg-acc-btn{min-height:44px;padding:6px 12px;font-size:1rem!important;line-height:1.3}',
      // Cible qui reçoit la fenêtre, jauge des PA allumée, bulle HRP
      '@keyframes hgAccPulse{0%{box-shadow:0 0 0 0 rgba(232,200,96,.9)}100%{box-shadow:0 0 0 14px rgba(232,200,96,0)}}',
      '.hg-acc-cible{animation:hgAccPulse .9s ease-out 2}',
      '@keyframes hgPaAllume{0%,100%{box-shadow:0 0 0 2px #6ada6a,0 0 10px 2px rgba(106,218,106,.7)}50%{box-shadow:0 0 0 2px #b8ffb8,0 0 22px 6px rgba(106,218,106,.95)}}',
      '.hg-pa-allumee{animation:hgPaAllume 1.2s ease-in-out infinite;border-radius:3px;position:relative;z-index:2}',
      '#hg-bulle-pa{position:fixed;z-index:12500;box-sizing:border-box;width:min(330px,calc(100vw - 32px));padding:12px 14px;background:#0d1a0d;border:1px solid #6ada6a;border-radius:6px;color:#f2fff2;font-family:"Crimson Pro",Georgia,serif;font-size:1rem;line-height:1.45;box-shadow:0 8px 28px rgba(0,0,0,.6)}',
      '#hg-bulle-pa .hg-bulle-hrp{display:inline-block;font-size:.95rem;color:#b8ffb8;border:1px solid #4a8a4a;border-radius:3px;padding:0 6px;margin-bottom:6px}',
      '#hg-bulle-pa p{margin:0 0 10px;font-size:1rem}',
      '#hg-bulle-pa button{min-height:44px;padding:6px 16px;border:1px solid #6ada6a;border-radius:4px;background:#173017;color:#f2fff2;font:inherit;font-size:1rem;cursor:pointer}',
      '@media (prefers-reduced-motion:reduce){.hg-acc-carte.hg-acc-file{transition:opacity .2s}.hg-acc-cible,.hg-pa-allumee{animation:none}.hg-pa-allumee{box-shadow:0 0 0 2px #6ada6a}}'
    ].join('\n');
    doc.head.appendChild(s);
  }

  // ------------------------------------------------------------------ serveur
  async function rpc(fn, args) {
    if (typeof global.sbRpc !== 'function') return null;
    try { const r = await global.sbRpc(fn, args || {}); return Array.isArray(r) ? r[0] : r; } catch (_) { return null; }
  }
  async function charger() {
    const nom = global.state?.char?.name;
    if (!nom) return null;
    const r = await rpc('accueil_etat');
    if (r && r.ok === true && r.personnage === nom) { etat = r; pourNom = nom; }
    return etat;
  }
  function adopter(r) { if (r && r.ok === true && r.personnage === global.state?.char?.name) etat = r; return r; }
  async function apiPublier() {
    try {
      if (typeof global.rpAuthAssurerSession === 'function') await global.rpAuthAssurerSession();
      const jeton = typeof global.rpAuthJeton === 'function' ? global.rpAuthJeton() : null;
      if (!jeton) return null;
      const resp = await fetch('/api/journal-interview', {
        method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + jeton },
        body: JSON.stringify({ action: 'accueil_publier', personnage: global.state.char.name })
      });
      const data = await resp.json().catch(() => null);
      return resp.ok ? data : null;
    } catch (_) { return null; }
  }

  const journaliste = () => etat?.interview?.journaliste || '';
  const enAttente = () => ['a_faire', 'article_a_publier'].includes(etat?.interview?.etat);

  // ------------------------------------------------------------------ fenêtre de l'interview
  function cibleObjectifs() {
    // Bureau : le bouton « Mes objectifs » du panneau. Téléphone : ce qui ouvre le panneau « Personnage » (identité de
    // l'en-tête, ou l'accès « Personnage »), sinon la barre d'identité.
    const visibles = ['#left button[onclick^="afficherObjectifsSecrets"]', '#hg-mobile-brand', '[data-hg-panneau="personnage"]', '#hg-mobile-identite-20261117']
      .map(s => doc.querySelector(s))
      .filter(e => e && e.getClientRects().length && e.getBoundingClientRect().width > 0);
    return visibles[0] || null;
  }

  function rendre() {
    if (!fenetre || !etat) return;
    const carte = fenetre.querySelector('.hg-acc-carte');
    const j = journaliste(), it = etat.interview || {};
    const portrait = PORTRAITS[j]
      ? '<img class="hg-acc-portrait" alt="" src="' + esc(PORTRAITS[j]) + '">'
      : '<div class="hg-acc-portrait" aria-hidden="true">' + esc(j.charAt(0)) + '</div>';
    let h = '<button type="button" class="hg-acc-fermer" data-acc="fermer" aria-label="' + esc(TXT.fermerAria) + '">×</button>' +
      '<div class="hg-acc-entete">' + portrait + '<div><h2 class="hg-acc-nom" id="hg-acc-titre">' + esc(j) + '</h2>' +
      '<p class="hg-acc-journal">' + esc(it.journal || '') + '</p></div></div>';
    if (it.etat === 'a_faire' || it.etat === 'ignoree') {
      h += '<p class="hg-acc-question">« ' + esc(it.question || '') + ' »</p>' +
        '<div class="hg-acc-chemins" role="radiogroup" aria-labelledby="hg-acc-titre">' +
        (etat.chemins || []).map(c => '<button type="button" role="radio" class="hg-acc-chemin" data-chemin="' + esc(c.id) + '" aria-checked="' +
          (choix === c.id) + '">' + esc(c.libelle) + '</button>').join('') + '</div>' +
        '<label class="hg-acc-label" for="hg-acc-mot">' + esc(TXT.motLabel) + '</label>' +
        '<p class="hg-acc-aide">' + esc(TXT.motAide) + '</p>' +
        '<textarea id="hg-acc-mot" class="hg-acc-mot" maxlength="' + (etat.mot_max || 280) + '"></textarea>' +
        '<div class="hg-acc-actions"><button type="button" class="hg-acc-btn" data-acc="repondre"' + (choix ? '' : ' disabled') + '>' + esc(TXT.repondre) + '</button>' +
        '<button type="button" class="hg-acc-btn hg-acc-second" data-acc="fermer">' + esc(TXT.plusTard) + '</button></div>' +
        '<p class="hg-acc-msg" role="status" aria-live="polite">' + (choix ? '' : esc(TXT.choisirChemin)) + '</p>';
    } else {
      const c = etat.chemin?.libelle || '';
      if (article && (article.titre || article.texte)) {
        h += '<div class="hg-acc-article"><p class="hg-acc-surtitre">' + esc(f(TXT.publie, { j })) + '</p>' +
          '<h3>' + esc(article.titre || '') + '</h3><p>' + esc(article.texte || '') + '</p></div>';
        if (article.statut === 'en_attente') h += '<p class="hg-acc-msg">' + esc(TXT.attentePublication) + '</p>';
        h += '<p class="hg-acc-msg">' + esc(f(TXT.parcoursDepose, { c })) + '</p>';
        h += '<div class="hg-acc-actions"><button type="button" class="hg-acc-btn" data-acc="fermer">' + esc(TXT.fermer) + '</button></div>';
      } else if (it.etat === 'article_a_publier') {
        h += '<p class="hg-acc-msg" role="status" aria-live="polite">' + esc(f(TXT.enregistre, { c, j })) + '</p>';
        if (!publication) h += '<p class="hg-acc-msg hg-acc-erreur">' + esc(f(TXT.echecPublication, { j })) + '</p>' +
          '<div class="hg-acc-actions"><button type="button" class="hg-acc-btn" data-acc="publier">' + esc(TXT.publier) + '</button>' +
          '<button type="button" class="hg-acc-btn hg-acc-second" data-acc="fermer">' + esc(TXT.plusTard) + '</button></div>';
      } else {
        h += '<p class="hg-acc-msg">' + esc(f(TXT.parcoursDepose, { c })) + '</p>' +
          '<div class="hg-acc-actions"><button type="button" class="hg-acc-btn" data-acc="fermer">' + esc(TXT.fermer) + '</button></div>';
      }
    }
    carte.innerHTML = h;
  }

  function ouvrir() {
    if (!etat || !enAttente()) return false;
    styles();
    if (!fenetre) {
      fenetre = doc.createElement('div');
      fenetre.id = 'hg-accueil-interview';
      fenetre.setAttribute('role', 'dialog');
      fenetre.setAttribute('aria-modal', 'true');
      fenetre.setAttribute('aria-labelledby', 'hg-acc-titre');
      fenetre.innerHTML = '<div class="hg-acc-carte"></div>';
      fenetre.addEventListener('click', clic);
      fenetre.addEventListener('keydown', e => { if (e.key === 'Escape') { e.preventDefault(); fermer(); } });
      doc.body.appendChild(fenetre);
    }
    article = null;
    rendre();
    setTimeout(() => (fenetre?.querySelector('.hg-acc-chemin,.hg-acc-btn') || null)?.focus?.({ preventScroll: true }), 30);
    if (etat.interview.etat === 'article_a_publier' && !publication) publierArticle();
    return true;
  }

  async function clic(e) {
    const b = e.target.closest('[data-acc],[data-chemin]');
    if (!b || b.disabled) return;
    if (b.dataset.chemin) {
      choix = b.dataset.chemin;
      fenetre.querySelectorAll('.hg-acc-chemin').forEach(x => x.setAttribute('aria-checked', String(x.dataset.chemin === choix)));
      const rep = fenetre.querySelector('[data-acc="repondre"]'); if (rep) rep.disabled = false;
      const msg = fenetre.querySelector('.hg-acc-msg'); if (msg) msg.textContent = '';
      return;
    }
    if (b.dataset.acc === 'fermer') return fermer();
    if (b.dataset.acc === 'repondre') return repondre();
    if (b.dataset.acc === 'publier') return publierArticle();
  }

  async function repondre() {
    if (!choix || publication) return;
    const mot = (fenetre.querySelector('#hg-acc-mot')?.value || '').trim();
    const bouton = fenetre.querySelector('[data-acc="repondre"]'); if (bouton) bouton.disabled = true;
    const r = adopter(await rpc('accueil_choisir_chemin', { p_chemin: choix, p_mot: mot || null }));
    if (!r || r.ok !== true) {
      const msg = fenetre.querySelector('.hg-acc-msg');
      if (msg) { msg.textContent = TXT.echecChoix; msg.classList.add('hg-acc-erreur'); }
      if (bouton) bouton.disabled = false;
      return;
    }
    rafraichirObjectifs();
    await publierArticle();
  }

  async function publierArticle() {
    if (publication) return;
    publication = true;
    rendre();
    const data = await apiPublier();
    publication = false;
    if (data && data.ok) {
      article = { titre: data.titre, texte: data.texte, statut: data.statut };
      await charger();
      const j = journaliste();
      if (typeof global.addJournalEntry === 'function') global.addJournalEntry(esc(j + ' a publié votre interview : « ' + (data.titre || '') + ' ».'), 'event-good');
    }
    rendre();
    rafraichirObjectifs();
  }

  // Point 25 : la fenêtre se réduit et file vers « Mes objectifs ».
  function fermer() {
    if (!fenetre) return;
    const f0 = fenetre, carte = f0.querySelector('.hg-acc-carte');
    fenetre = null; choix = null;
    const cible = cibleObjectifs();
    const fin = () => {
      f0.remove();
      if (cible) { cible.classList.remove('hg-acc-cible'); void cible.offsetWidth; cible.classList.add('hg-acc-cible'); setTimeout(() => cible.classList.remove('hg-acc-cible'), 2000); }
      rafraichirObjectifs();
    };
    const reduit = global.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    if (!carte || !cible) { fin(); return; }
    const a = carte.getBoundingClientRect(), c = cible.getBoundingClientRect();
    const dx = (c.left + c.width / 2) - (a.left + a.width / 2), dy = (c.top + c.height / 2) - (a.top + a.height / 2);
    f0.classList.add('hg-acc-part');
    carte.classList.add('hg-acc-file');
    carte.style.transform = reduit ? 'none' : 'translate(' + dx + 'px,' + dy + 'px) scale(0.06)';
    f0.dataset.fileVers = cible.closest('#left') ? 'objectifs' : 'personnage';
    let fait = false;
    const terminer = () => { if (!fait) { fait = true; fin(); } };
    carte.addEventListener('transitionend', e => { if (e.propertyName === 'transform' || e.propertyName === 'opacity') terminer(); });
    setTimeout(terminer, 900);
  }

  // ------------------------------------------------------------------ « Mes objectifs » (points 24 et 25)
  function objectifsHtml() {
    if (!etat || !etat.interview) return '';
    const it = etat.interview, j = it.journaliste || '';
    let h = '';
    if (it.etat === 'a_faire' || it.etat === 'article_a_publier') {
      h += '<div class="hg-acc-obj-ligne"><div class="hg-acc-coche" aria-hidden="true">⬜</div><div class="hg-acc-obj-texte">' +
        esc(f(it.etat === 'a_faire' ? TXT.attend : TXT.redige, { j })) +
        '<div class="hg-acc-obj-actions"><button type="button" class="hg-acc-btn" data-acc-obj="reprendre">' + esc(TXT.reprendre) + '</button>' +
        (it.etat === 'a_faire' ? '<button type="button" class="hg-acc-btn hg-acc-second" data-acc-obj="ignorer">' + esc(TXT.ignorer) + '</button>' : '') +
        '</div></div></div>';
    }
    if (etat.chemin && Array.isArray(etat.etapes) && etat.etapes.length) {
      h += '<div class="hg-acc-obj-titre">' + esc(f(TXT.parcoursTitre, { c: etat.chemin.libelle })) + '</div>';
      for (const e of etat.etapes) {
        h += '<div class="hg-acc-obj-ligne" data-etape="' + e.n + '"><div class="hg-acc-coche" aria-hidden="true">' + (e.faite ? '✅' : '⬜') + '</div>' +
          '<div class="hg-acc-obj-texte' + (e.faite ? ' fait' : '') + '">' + esc(e.n + '. ' + e.texte) +
          '<div class="hg-acc-obj-lieu">' + esc(f(TXT.ou, { l: e.lieu })) + '</div>' +
          (!e.faite && e.validation === 'ordre' ? '<div class="hg-acc-obj-lieu">' + esc(TXT.auto) + '</div>' : '') +
          (!e.faite ? '<div class="hg-acc-obj-actions"><button type="button" class="hg-acc-btn hg-acc-second" data-acc-obj="etape" data-n="' + e.n + '">' + esc(TXT.jaiFait) + '</button></div>' : '') +
          '</div></div>';
      }
    }
    return h ? '<div class="hg-acc-obj" data-accueil-objectifs>' + h + '</div>' : '';
  }
  async function objectifsClic(e) {
    const b = e.target.closest('[data-acc-obj]');
    if (!b || b.disabled) return;
    b.disabled = true;
    if (b.dataset.accObj === 'reprendre') {
      doc.getElementById('modal-postes')?.classList.remove('open');
      ouvrir();
      return;
    }
    if (b.dataset.accObj === 'ignorer') adopter(await rpc('accueil_ignorer'));
    if (b.dataset.accObj === 'etape') adopter(await rpc('accueil_etape_valider', { p_n: Number(b.dataset.n) }));
    rafraichirObjectifs(true);
  }
  // Appelé par afficherObjectifsSecrets (plateau-politique.js) : place l'accueil en tête de la fenêtre.
  async function insererObjectifs(body) {
    if (!body) return;
    styles();
    if (!etat || pourNom !== global.state?.char?.name) await charger();
    body.querySelector('[data-accueil-objectifs]')?.remove();
    const h = objectifsHtml();
    if (!h) return;
    // Dans le premier bloc de la fenêtre (celui que traduit RPPlayerMissionsI18n), en tête.
    (body.firstElementChild || body).insertAdjacentHTML('afterbegin', h);
    const zone = body.querySelector('[data-accueil-objectifs]');
    zone.addEventListener('click', objectifsClic);
  }
  function rafraichirObjectifs(force) {
    const modal = doc.getElementById('modal-postes');
    const body = doc.getElementById('postes-body');
    if (!modal?.classList.contains('open') || !body) return;
    if (force || body.querySelector('[data-accueil-objectifs]')) insererObjectifs(body);
  }

  // ------------------------------------------------------------------ bulle des PA (point 26)
  function jaugePa() {
    const cands = [doc.getElementById('hg-identite-pa'), doc.getElementById('r-pa')?.parentElement]
      .filter(e => e && e.getClientRects().length && e.getBoundingClientRect().width > 0);
    return cands[0] || null;
  }
  function afficherBullePa(pa) {
    styles();
    doc.getElementById('hg-bulle-pa')?.remove();
    const jauge = jaugePa();
    const bulle = doc.createElement('div');
    bulle.id = 'hg-bulle-pa';
    bulle.setAttribute('role', 'dialog');
    bulle.setAttribute('aria-label', 'PA');
    bulle.innerHTML = '<span class="hg-bulle-hrp">' + esc(TXT.hrp) + '</span><p>' + esc(f(TXT.bulle, { pa })) + '</p>' +
      '<button type="button">' + esc(TXT.compris) + '</button>';
    doc.body.appendChild(bulle);
    if (jauge) jauge.classList.add('hg-pa-allumee');
    const placer = () => {
      const l = bulle.getBoundingClientRect(), W = global.innerWidth, H = global.innerHeight, m = 16;
      let x, y;
      if (jauge) {
        const r = jauge.getBoundingClientRect();
        if (r.right + 12 + l.width <= W - m) { x = r.right + 12; y = r.top; }              // à droite de la jauge
        else { x = Math.min(Math.max(m, r.left), W - m - l.width); y = r.bottom + 10; }     // dessous
        if (y + l.height > H - m) y = Math.max(m, r.top - 10 - l.height);                   // sinon au-dessus
      } else { x = (W - l.width) / 2; y = m; }
      bulle.style.left = Math.round(Math.max(m, x)) + 'px';
      bulle.style.top = Math.round(Math.max(m, y)) + 'px';
    };
    placer();
    const fermerBulle = () => { bulle.remove(); jauge?.classList.remove('hg-pa-allumee'); global.removeEventListener('resize', placer); };
    bulle.querySelector('button').addEventListener('click', fermerBulle);
    global.addEventListener('resize', placer);
    if (etat?.bulle_pa) etat.bulle_pa.vue = true;
  }

  // Le serveur prévient par son journal d'événements (plateau-evenements-personnage.js).
  const gestionnaires = global.rpEvenementsPersonnageGestionnaires = global.rpEvenementsPersonnageGestionnaires || {};
  gestionnaires.accueil_bulle_pa = ev => afficherBullePa(Number(ev?.params?.pa) || 1);
  gestionnaires.accueil_etape = () => { charger().then(() => rafraichirObjectifs()); };
  // Calendrier du nouveau venu (purge A.3) : le serveur déclare l'interview due ; l'écran relit et l'ouvre dès que libre.
  gestionnaires.accueil_interview = () => { charger().then(() => verifier()); };

  // Un paiement qui baisse les PA alors que la bulle n'a jamais été vue : lire tout de suite le journal du serveur
  // (sans attendre le signal temps réel). Aucune décision locale : c'est le serveur qui a écrit, ou non, la bulle.
  function brancherPaiement() {
    const avant = global.appliquerPaiementServeur;
    if (typeof avant !== 'function' || avant.__accueil) return;
    const enveloppe = function (r) {
      const pa0 = global.state?.pa;
      const res = avant.apply(this, arguments);
      if (r && typeof r.pa === 'number' && typeof pa0 === 'number' && r.pa < pa0 && etat && etat.bulle_pa && !etat.bulle_pa.vue
          && typeof global.lireEvenementsPersonnage === 'function') setTimeout(global.lireEvenementsPersonnage, 300);
      return res;
    };
    enveloppe.__accueil = true;
    global.appliquerPaiementServeur = enveloppe;
  }
  // Ordres payés par leur propre commande serveur (sans payer_ordre_interne) : quand les PA affichés (valeur du serveur)
  // baissent juste après un ordre, le navigateur le SIGNALE ; le serveur seul décide si c'est la première fois.
  let dernierOrdre = 0, paVu = null, paNom = null;
  function brancherOrdres() {
    const avant = global.doOrder;
    if (typeof avant === 'function' && !avant.__accueil) {
      const env = function () { dernierOrdre = Date.now(); return avant.apply(this, arguments); };
      env.__accueil = true;
      global.doOrder = env;
    }
    const el = doc.getElementById('r-pa');
    if (!el || el.__accueil) return;
    el.__accueil = true;
    paVu = Number(el.textContent); paNom = global.state?.char?.name || null;
    new MutationObserver(() => {
      const nom = global.state?.char?.name, v = Number(el.textContent);
      if (!nom || !Number.isFinite(v)) return;
      const avantPa = paNom === nom ? paVu : null;
      paVu = v; paNom = nom;
      if (avantPa == null || v >= avantPa || Date.now() - dernierOrdre > 120000) return;
      if (!etat || !etat.bulle_pa || etat.bulle_pa.vue || etat.bulle_pa.active === false) return;
      const pa = avantPa - v;
      setTimeout(async () => {
        if (etat.bulle_pa.vue || doc.getElementById('hg-bulle-pa')) return;
        const r = await rpc('accueil_bulle_pa_signaler', { p_pa: pa });
        if (r && r.ok === true && r.montrer) afficherBullePa(r.pa || pa);
        else if (r && r.ok === true) etat.bulle_pa.vue = true;
      }, 1500);
    }).observe(el, { childList: true, characterData: true, subtree: true });
  }

  // ------------------------------------------------------------------ démarrage (points 23 et 25)
  // Ne pas couvrir la quête d'accueil de Luthécia (garde du Palais, Jérémy) ni un dialogue de PNJ en cours.
  function occupe() {
    if (doc.querySelector('#hg-bienvenue, #modal-quete-accueil.open, #modal-pnj.open, .modal-overlay.open, #hg-accueil-interview')) return true;
    // Calendrier du nouveau venu (purge A.3) : seule une fenêtre réellement ouverte retarde l'interview due.
    if (etat && etat.calendrier && etat.calendrier.actif) return false;
    const e = global.state?.char?.queteAccueil?.etape;
    return e === 'garde_en_cours';
  }
  async function verifier() {
    const nom = global.state?.char?.name;
    if (!nom) return;
    brancherPaiement();
    brancherOrdres();
    if (pourNom !== nom) {
      if (chargement) return;
      chargement = charger().finally(() => { chargement = null; });
      await chargement;
    }
    // Bienvenue, calendrier du nouveau venu et portier des fenêtres automatiques : plateau-accueil-progressif.js (#1188,
    // repris par la purge A.2/A.3) ; le serveur seul décide du moment de l'interview (accueil_etat → ouvrir_auto).
    const prog = global.RPAccueilProgressif;
    if (prog) prog.initialiser(etat);
    if (prog && prog.bienvenueEnCours()) return;
    if (etat?.interview?.ouvrir_auto && (prog ? prog.entretienAutomatiqueAutorise() : true) && !occupe()) {
      etat.interview.ouvrir_auto = false;
      if (ouvrir()) { if (prog) prog.marquer('interview'); rpc('accueil_interview_vue'); }
    }
  }

  global.RPAccueil = Object.freeze({ charger, ouvrir, fermer, insererObjectifs, afficherBullePa, etat: () => etat, verifier, TXT });
  if (!global.__RP_ACCUEIL_SANS_MINUTERIE) {
    setTimeout(verifier, 2500);
    setInterval(verifier, 5000);
  }
})(typeof window !== 'undefined' ? window : globalThis);
