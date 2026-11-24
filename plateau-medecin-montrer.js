// SANTÉ ET FORÊT (Fred, 22/11/2026, après-midi : GAME-DESIGN-SANTE-20261122.md), points 12, 14 et 22.
// Le serveur décide de tout (migration 20261122234000_medecin_montrer) ; cet écran n'affiche que ses réponses.
//  • Point 14, jauges Santé et Moral du panneau « Mon personnage » : valeurs recopiées de #r-hp / #r-moral (état du serveur),
//    infobulle au survol, au clavier et au toucher ; seuils lus sur le serveur (sante_paliers_lire), repli sur les valeurs
//    décidées par Fred. Texte de l'infobulle ≥ texte courant (1 rem, plancher plateau-texte-minimum.js 0,95 rem).
//  • Point 12, médecin de terrain (carrière « doctor ») : « Diagnostiquer » et « Soigner » sur la carte d'un autre joueur
//    présent ; le médecin fixe son tarif (medecin_proposer) ; le patient voit le prix dans une fenêtre et accepte ou refuse
//    (medecin_repondre) ; aucun prélèvement sans son accord.
//  • Point 22, « Montrer un objet » : depuis la fiche d'un objet ou la carte d'un joueur (objet_montrer) ; l'autre voit
//    le nom, l'image et la description dans une fenêtre ; rien ne change de main ; une ligne au journal des deux.
// Les fenêtres reçues arrivent par le journal d'événements du serveur (plateau-evenements-personnage.js).
(function (global) {
  'use strict';
  const doc = global.document;
  // Clés de traduction pour Codex : medecinMontrer.* (français seulement ici).
  const FR = {
    pa: 'PA', sante: 'Santé', moral: 'Moral', influence: 'Influence', popularite: 'Popularité', discretion: 'Discrétion',
    // Deuxième ligne du panneau de gauche (Fred, 23/11/2026, point 16) ; descriptions reprises de l'ancien onglet Statistiques.
    influence_txt: 'Influence {n} / 100 : votre poids politique et votre réseau.',
    popularite_txt: 'Popularité {n} / 100 : le soutien que vous accorde la population.',
    discretion_txt: 'Discrétion {n} / 100 : votre capacité à agir sans être remarqué.',
    // Jauge des PA (Fred, 24/11/2026, mission Purge A.6) : reprend la bulle d'accueil des PA (GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, point 26).
    pa_txt: 'PA {n} / {max} : votre énergie du jour, chaque action en coûte. Dormir les recharge ; à 0, c’est l’hôpital.',
    paInfosTitre: 'Plus d’informations sur les PA',
    paInfosOu: '{nom}, l’infirmière d’accueil, vous expliquera les PA. Vous la trouverez ici : {lieu}, pièce « {piece} ».',
    paInfosAucune: 'Il n’y a pas d’infirmière d’accueil dans cette ville. Les PA sont votre énergie du jour : chaque action en coûte, dormir les recharge et à 0, c’est l’hôpital.',
    sante_haut: 'Santé {n} : vous êtes en pleine forme ; sous les coups, vous perdez moins de PA.',
    sante_bien: 'Santé {n} : vous perdez un peu moins de PA sous les coups. Mangez, dormez dans un lit ou consultez un médecin pour la garder.',
    sante_moyen: 'Santé {n} : vous encaissez les coups normalement. Mangez, dormez dans un lit ou consultez un médecin.',
    sante_bas: 'Santé {n} : vous perdez un peu plus de PA sous les coups. Mangez, dormez dans un lit ou consultez un médecin.',
    sante_critique: 'Santé {n} : vous perdez beaucoup plus de PA sous les coups. Mangez, dormez dans un lit ou consultez un médecin au plus vite.',
    moral_haut: 'Moral {n} : excellent moral. Repas, sommeil, soins, médecin et alcool vous rendent {mult} fois plus de Santé.',
    moral_moyen: 'Moral {n} : repas, sommeil, soins et médecin vous rendent la Santé normalement. À partir de {haut}, ils en rendraient davantage.',
    moral_bas: 'Moral {n} : moral au plus bas. Repas, sommeil, soins et médecin ne vous rendent que {mult} de la Santé habituelle. Remontez le moral pour mieux guérir.',
    diagnostiquer: 'Diagnostiquer', soigner: 'Soigner', montrer: 'Montrer un objet', montrerJoueur: 'Montrer à ce joueur',
    titreActe: '{acte} — {cible}',
    introDiag: 'Vous examinez {cible} : vous verrez sa Santé exacte, ses maladies en cours et le médicament qui soigne chacune. Il ou elle recevra le même diagnostic. Coût pour vous : {pa} PA, seulement si le patient accepte.',
    introSoin: 'Vous soignez {cible} avec une trousse de premiers secours (vous en avez {trousses}) : +{sante} Santé, plus ou moins selon son moral. Coût pour vous : {pa} PA et une trousse, seulement si le patient accepte.',
    tarif: 'Votre tarif ({cur}) — 0 pour un acte gratuit :', proposer: 'Proposer', annuler: 'Annuler', fermer: 'Fermer',
    envoye: 'Proposition envoyée à {cible}. Il ou elle voit votre tarif et accepte ou refuse.',
    titreProposition: 'Un médecin vous propose ses soins',
    propDiag: '{medecin} vous propose un diagnostic : votre Santé exacte, vos maladies en cours et le médicament qui soigne chacune.',
    propSoin: '{medecin} vous propose des soins : +{sante} Santé, plus ou moins selon votre moral.',
    prix: 'Prix demandé : {prix} {cur}.', gratuit: 'Gratuit.', accord: 'Rien n’est prélevé sans votre accord.',
    accepter: 'Accepter et payer', accepterGratuit: 'Accepter', refuser: 'Refuser',
    refuse: 'Vous avez refusé. Rien n’a été prélevé.',
    titreDiagnostic: 'Diagnostic', santeExacte: 'Santé : {n}', aucuneMaladie: 'Aucune maladie en cours.',
    seSoigne: 'se soigne avec : {m}', dejaPris: 'déjà pris',
    titreSoin: 'Soins reçus', soinTexte: 'Santé {avant} → {apres} (+{gain}).',
    titreMontre: '{de} vous montre un objet', montrerChoisir: 'Choisissez l’objet à montrer à {cible} :',
    montrerFait: 'Vous montrez « {nom} » à {cible}.', inventaireVide: 'Votre inventaire est vide.',
    choisirJoueur: 'Choisissez d’abord un joueur présent.',
    refus: 'Action impossible',
    r_reserve_aux_medecins: 'Seul un médecin peut faire cela.', r_pas_au_meme_endroit: 'Vous n’êtes pas au même endroit.',
    r_pa_insuffisants: 'Vous n’avez pas assez de PA.', r_aucune_trousse: 'Il vous faut une trousse de premiers secours.',
    r_tarif_invalide: 'Tarif invalide.', r_patient_invalide: 'Choisissez un autre personnage.', r_patient_introuvable: 'Personnage introuvable.',
    r_proposition_close: 'Cette proposition n’est plus valable.', r_proposition_expiree: 'Cette proposition a expiré.',
    r_proposition_introuvable: 'Cette proposition n’existe plus.', r_fonds_insuffisants: 'Vous n’avez pas assez d’argent.',
    r_medecin_sans_pa: 'Le médecin n’a plus assez de PA. Rien n’a été prélevé.', r_medecin_sans_trousse: 'Le médecin n’a plus de trousse. Rien n’a été prélevé.',
    r_medecin_indisponible: 'Ce médecin ne peut plus exercer. Rien n’a été prélevé.', r_objet_introuvable: 'Objet introuvable.',
    r_destinataire_invalide: 'Choisissez un autre joueur.', r_destinataire_introuvable: 'Joueur introuvable.',
    r_inconnu: 'Le serveur n’a pas répondu. Rien n’a été fait.'
  };
  const t = (k, v) => String(FR[k] == null ? k : FR[k]).replace(/\{(\w+)\}/g, (_, x) => (v && v[x] != null ? v[x] : ''));
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const etat = () => global.state || {};
  const raison = r => t(r && FR['r_' + r.raison] ? 'r_' + r.raison : 'r_inconnu');
  async function rpc(fn, args) {
    try {
      if (typeof global.sbRpcVerdict === 'function') return await global.sbRpcVerdict(fn, args || {});
      if (typeof global.sbRpc === 'function') return await global.sbRpc(fn, args || {});
    } catch (_) { /* nommé plus bas */ }
    return null;
  }
  const toast = (titre, corps, ok) => { if (typeof global.showToast === 'function') global.showToast(titre, corps, !!ok); };
  const resynchroniser = () => { if (typeof global.rpResynchroniserEtat === 'function') global.rpResynchroniserEtat('sante-medecin'); };

  // ---------------------------------------------------------------------------------------------------------------
  // Fenêtre commune (classes du thème : modal-overlay / modal-box / cpj-*)
  // ---------------------------------------------------------------------------------------------------------------
  function fenetre(id, titre, corpsHtml, boutons) {
    if (!doc) return null;
    doc.getElementById(id)?.remove();
    const fond = doc.createElement('div');
    fond.id = id; fond.className = 'modal-overlay open hg-sante-fenetre'; fond.setAttribute('role', 'dialog'); fond.setAttribute('aria-modal', 'true');
    fond.innerHTML = '<div class="modal-box"><div class="modal-header"><div class="modal-title">' + esc(titre) + '</div>'
      + '<button type="button" class="modal-close" data-fermer><i class="ti ti-x"></i></button></div>'
      + '<div class="modal-body cpj-dialogue hg-sante-corps">' + corpsHtml + '<div class="hg-sante-boutons"></div></div></div>';
    const zone = fond.querySelector('.hg-sante-boutons');
    const fermer = () => fond.remove();
    (boutons || [{ libelle: t('fermer') }]).forEach(b => {
      const el = doc.createElement('button');
      el.type = 'button'; el.className = 'cpj-touche' + (b.primaire ? ' cpj-primaire' : ''); el.textContent = b.libelle;
      if (b.attr) el.setAttribute(b.attr, '');
      el.onclick = async () => { if (b.action) { el.disabled = true; const garder = await b.action(fond); el.disabled = false; if (garder === true) return; } fermer(); };
      zone.appendChild(el);
    });
    fond.querySelector('[data-fermer]').onclick = fermer;
    fond.addEventListener('click', e => { if (e.target === fond) fermer(); });
    doc.body.appendChild(fond);
    return fond;
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Point 14 : jauges Santé et Moral
  // ---------------------------------------------------------------------------------------------------------------
  let paliers = { moral_seuil_haut: 75, moral_seuil_bas: 25, moral_mult_haut: 1.5, moral_mult_bas: 0.5 };
  let paliersLus = false;
  async function lirePaliers() {
    if (paliersLus) return;
    const r = await rpc('sante_paliers_lire', {});
    if (r && r.ok === true) { paliersLus = true; Object.keys(paliers).forEach(k => { if (r[k] != null && !isNaN(Number(r[k]))) paliers[k] = Number(r[k]); }); }
  }
  const nombreFr = x => String(Math.round(Number(x) * 100) / 100).replace('.', ',');
  function texteSante(n) {
    if (n >= 75) return t('sante_haut', { n });
    if (n > 50) return t('sante_bien', { n });
    if (n === 50) return t('sante_moyen', { n });
    if (n >= 25) return t('sante_bas', { n });
    return t('sante_critique', { n });
  }
  function texteMoral(n) {
    if (n >= paliers.moral_seuil_haut) return t('moral_haut', { n, mult: nombreFr(paliers.moral_mult_haut) });
    if (n < paliers.moral_seuil_bas) return t('moral_bas', { n, mult: paliers.moral_mult_bas === 0.5 ? 'la moitié' : '×' + nombreFr(paliers.moral_mult_bas) });
    return t('moral_moyen', { n, haut: paliers.moral_seuil_haut });
  }
  // Chaque jauge recopie une case de l'état du serveur (updateUI, plateau-core.js).
  const SOURCES_JAUGES = { pa: 'r-pa', sante: 'r-hp', moral: 'r-moral', influence: 'r-inf', popularite: 'r-pop', discretion: 'r-dis' };
  function valeurJauge(cle) {
    const brut = doc && doc.getElementById(SOURCES_JAUGES[cle] || 'r-moral');
    const n = Number(String(brut && brut.textContent || '').trim());
    return Number.isFinite(n) && String(brut && brut.textContent || '').trim() !== '' ? Math.max(0, cle === 'pa' ? Math.round(n) : Math.min(100, Math.round(n))) : null;
  }
  // PA_MAX et state sont des déclarations lexicales de plateau-core.js (const / let) : jamais sur window.
  const paMax = () => (typeof PA_MAX === 'number' ? PA_MAX : 30);
  const etatJeu = () => (typeof state !== 'undefined' && state) || global.state || {};
  function texteJauge(cle) {
    const n = valeurJauge(cle);
    if (n == null) return '';
    if (cle === 'sante') return texteSante(n);
    if (cle === 'moral') return texteMoral(n);
    return t(cle + '_txt', { n, max: paMax() });
  }
  function majJauges() {
    if (!doc) return;
    Object.keys(SOURCES_JAUGES).forEach(cle => {
      const n = valeurJauge(cle);
      const val = doc.getElementById('hg-jauge-' + cle + '-val'), barre = doc.getElementById('hg-jauge-' + cle + '-barre');
      const boite = doc.getElementById('hg-jauge-' + cle);
      if (val) val.textContent = n == null ? '—' : String(n);
      if (barre) barre.style.width = (n == null ? 0 : n) + '%';
      if (boite) { boite.setAttribute('aria-label', n == null ? t(cle) : texteJauge(cle)); boite.classList.toggle('hg-jauge-basse', cle !== 'pa' && n != null && n < 25); }
    });
    const bulle = doc.getElementById('hg-jauge-bulle');
    if (bulle && !bulle.hidden && bulle.dataset.jauge) bulle.textContent = texteJauge(bulle.dataset.jauge);
  }
  function montrerBulle(boite) {
    const cle = boite.dataset.jauge;
    let bulle = doc.getElementById('hg-jauge-bulle');
    if (!bulle) { bulle = doc.createElement('div'); bulle.id = 'hg-jauge-bulle'; bulle.className = 'hg-jauge-bulle'; bulle.setAttribute('role', 'tooltip'); doc.body.appendChild(bulle); }
    if (bulle.hidden || bulle.dataset.jauge !== cle) bulle.dataset.depuis = String(Date.now());
    bulle.dataset.jauge = cle; bulle.textContent = texteJauge(cle) || t(cle); bulle.hidden = false;
    const r = boite.getBoundingClientRect(), vw = global.innerWidth || 1024;
    const largeur = Math.min(300, vw - 32);
    bulle.style.maxWidth = largeur + 'px';
    const gauche = Math.max(16, Math.min(r.left, vw - largeur - 16));
    bulle.style.left = gauche + 'px'; bulle.style.top = (r.bottom + 8) + 'px';
    const h = bulle.getBoundingClientRect().height, vh = global.innerHeight || 768;
    if (r.bottom + 8 + h > vh - 8) bulle.style.top = Math.max(8, r.top - h - 8) + 'px';
  }
  function cacherBulle() { const b = doc && doc.getElementById('hg-jauge-bulle'); if (b) b.hidden = true; }
  function brancherJauges() {
    if (!doc) return;
    Object.values(SOURCES_JAUGES).forEach(id => { const el = doc.getElementById(id); if (el) new MutationObserver(majJauges).observe(el, { childList: true, characterData: true, subtree: true }); });
    doc.querySelectorAll('.hg-jauge[data-jauge]').forEach(boite => {
      boite.addEventListener('mouseenter', () => montrerBulle(boite));
      boite.addEventListener('mouseleave', cacherBulle);
      boite.addEventListener('focus', () => montrerBulle(boite));
      boite.addEventListener('blur', cacherBulle);
      boite.addEventListener('click', e => {   // toucher (et clic) : bascule
        e.stopPropagation();
        const b = doc.getElementById('hg-jauge-bulle');
        // Un toucher émet aussi focus et mouseenter juste avant le clic : ne refermer que si la bulle était déjà ouverte.
        if (b && !b.hidden && b.dataset.jauge === boite.dataset.jauge && e.pointerType !== 'mouse'
            && Date.now() - Number(b.dataset.depuis || 0) > 600) { cacherBulle(); return; }
        montrerBulle(boite);
      });
      boite.addEventListener('keydown', e => { if (e.key === 'Escape') cacherBulle(); });
    });
    doc.addEventListener('click', e => { if (!e.target.closest || !e.target.closest('.hg-jauge')) cacherBulle(); });
    global.addEventListener('scroll', cacherBulle, true);
    majJauges();
    lirePaliers().then(majJauges);
  }

  // ---------------------------------------------------------------------------------------------------------------
  // « Plus d'informations sur les PA ? » (Fred, 24/11/2026, mission Purge A.6) : l'infirmière d'accueil de l'hôpital ou du
  // dispensaire de la ville où se trouve le joueur. Dans sa pièce : la conversation s'ouvre (fiche DeepSeek complétée pour
  // expliquer les PA, api/_pnj-personnalites.js, SAVOIR_PA) ; ailleurs : on dit où la trouver. Relevé ville par ville
  // (banc-pa-jauge-infirmiere-20261124.cjs) : aucune infirmière n'a eu à être créée.
  const INFIRMIERES_PA = {
    republic: {
      capitale: { batiment: 'dispensaire-public', piece: 'salle_attente', nom: 'Anne Tibiotique' },
      ville_a: { batiment: 'dispensaire-public-v', piece: 'attente', nom: 'Betty Dine' },
      ville_b: { batiment: 'dispensaire-public-v', piece: 'attente', nom: 'Agnès Thésie' }
    },
    soviet: {
      capitale: { batiment: 'dispensaire-public', piece: 'salle_attente', nom: 'Ekaterina Bintova' },
      ville_a: { batiment: 'dispensaire-public-v', piece: 'attente', nom: 'Raïssa Bintova' },
      ville_b: { batiment: 'dispensaire-public-v', piece: 'attente', nom: 'Nadejda Oukolova' }
    }
  };
  global.RP_INFIRMIERES_PA = INFIRMIERES_PA;
  const sansPnj = n => String(n || '').replace(/\s*\(PNJ\)\s*$/i, '').trim();
  function personnesPiece(batiment, piece) {
    if (typeof global.personnesNormalesDeLaPiece === 'function') return global.personnesNormalesDeLaPiece(batiment, piece) || [];
    return [];
  }
  function ouvrirInfirmierePa() {
    const s = etatJeu(), inf = (INFIRMIERES_PA[s.country] || {})[s.currentCity];
    if (!inf) { fenetre('hg-pa-infos-fenetre', t('paInfosTitre'), '<p class="hg-sante-texte">' + esc(t('paInfosAucune')) + '</p>'); return false; }
    if (s.currentBuilding === inf.batiment && s.currentRoom === inf.piece) {
      const pnj = personnesPiece(inf.batiment, inf.piece).find(p => sansPnj(p.name) === inf.nom);
      if (pnj && typeof global.openPnjModal === 'function' && typeof global.encodePnjSafe === 'function') {
        global.openPnjModal(global.encodePnjSafe(pnj));
        return true;
      }
    }
    const B = (global.BUILDINGS || {})[inf.batiment] || {};
    const ctx = ((((global.WORLD || {})[s.country] || {})[s.currentCity] || {}).buildingContext || {})[inf.batiment] || {};
    const salle = (ctx.roomOverrides || {})[inf.piece] || {}, base = (B.rooms || {})[inf.piece] || (ctx.roomsExtra || {})[inf.piece] || {};
    fenetre('hg-pa-infos-fenetre', t('paInfosTitre'), '<p class="hg-sante-texte">'
      + esc(t('paInfosOu', { nom: inf.nom, lieu: ctx.name || B.name || inf.batiment, piece: salle.name || base.name || inf.piece })) + '</p>');
    return false;
  }
  global.ouvrirInfirmierePa = ouvrirInfirmierePa;

  // ---------------------------------------------------------------------------------------------------------------
  // Point 12 : médecin de terrain
  // ---------------------------------------------------------------------------------------------------------------
  // Miroir des tarifs (ordres_couts, migration 20261122234000), lu par outils/generateurs/generer_ordres_couts.py.
  // L'écran n'en tire aucun coût : les PA affichés et débités viennent du serveur (medecin_etat, medecin_repondre).
  const ORDRES_MEDECIN = [
    { fn: 'medecin_diagnostiquer', label: 'Diagnostiquer', pa: 1, cost: 0, type: 'legal', icon: 'ti-stethoscope' },
    { fn: 'medecin_soigner', label: 'Soigner', pa: 2, cost: 0, type: 'legal', icon: 'ti-first-aid-kit' }
  ];
  global.RP_ORDRES_MEDECIN = ORDRES_MEDECIN;
  const estMedecinLocal = () => (etat().char && etat().char.career) === 'doctor';
  function boutonsCarte(pnj) {
    if (!pnj || pnj.isPJ !== true || pnj.masque === true) return '';
    const nom = String(pnj.name || '').replace(' (PNJ)', '').trim();
    if (!nom || nom === (etat().char && etat().char.name)) return '';
    global._hgSanteCible = nom;   // jamais de nom dans un attribut onclick
    let html = '';
    if (estMedecinLocal()) {
      html += '<button class="pnj-action-btn hg-medecin-acte" data-acte="diagnostic" onclick="hgMedecinOuvrir(\'diagnostic\')"><i class="ti ti-stethoscope" style="font-size:.85rem"></i> ' + esc(t('diagnostiquer')) + '</button>';
      html += '<button class="pnj-action-btn hg-medecin-acte" data-acte="soin" onclick="hgMedecinOuvrir(\'soin\')"><i class="ti ti-first-aid-kit" style="font-size:.85rem"></i> ' + esc(t('soigner')) + '</button>';
    }
    if ((etat().inventory || []).length) html += '<button class="pnj-action-btn hg-montrer-objet" onclick="hgMontrerChoisir()"><i class="ti ti-eye" style="font-size:.85rem"></i> ' + esc(t('montrer')) + '</button>';
    return html;
  }
  async function ouvrirActe(acte) {
    const cible = global._hgSanteCible;
    if (!cible) return;
    doc.getElementById('modal-pnj')?.classList.remove('open');
    const e = await rpc('medecin_etat', {});
    if (!e || e.ok !== true) { toast(t('refus'), raison(e), false); return; }
    if (e.medecin !== true) { toast(t('refus'), t('r_reserve_aux_medecins'), false); return; }
    const pa = acte === 'diagnostic' ? e.pa_diagnostic : e.pa_soin;
    const intro = acte === 'diagnostic' ? t('introDiag', { cible: esc(cible), pa }) : t('introSoin', { cible: esc(cible), pa, trousses: e.trousses, sante: e.sante_soin });
    const corps = '<p class="cpj-note hg-sante-texte">' + intro + '</p>'
      + '<label class="hg-sante-texte">' + esc(t('tarif', { cur: e.monnaie || 'FR' }))
      + ' <input type="number" class="cpj-champ hg-medecin-prix" min="0" max="' + Number(e.tarif_max || 100000) + '" step="1" value="0" inputmode="numeric"></label>';
    fenetre('hg-medecin-acte', t('titreActe', { acte: t(acte === 'diagnostic' ? 'diagnostiquer' : 'soigner'), cible }), corps, [
      { libelle: t('proposer'), primaire: true, attr: 'data-proposer', action: async fond => {
        const prix = Math.floor(Number(fond.querySelector('.hg-medecin-prix').value));
        if (!Number.isFinite(prix) || prix < 0) { toast(t('refus'), t('r_tarif_invalide'), false); return true; }
        const r = await rpc('medecin_proposer', { p_patient: cible, p_acte: acte, p_prix: prix });
        if (!r || r.ok !== true) { toast(t('refus'), raison(r), false); return true; }
        toast(t(acte === 'diagnostic' ? 'diagnostiquer' : 'soigner'), t('envoye', { cible }), true);
        if (typeof global.addJournalEntry === 'function') global.addJournalEntry(esc(t('envoye', { cible })), '');
      } },
      { libelle: t('annuler') }
    ]);
  }
  // Patient : la proposition s'ouvre dans une fenêtre (journal d'événements ou propositions en attente).
  const propositionsVues = new Set();
  function fenetreProposition(p) {
    if (!p || p.id == null || propositionsVues.has(p.id)) return;
    propositionsVues.add(p.id);
    const prix = Number(p.prix) || 0;
    const corps = '<p class="hg-sante-texte">' + esc(p.acte === 'soin' ? t('propSoin', { medecin: p.medecin, sante: p.sante_soin || 12 }) : t('propDiag', { medecin: p.medecin })) + '</p>'
      + '<p class="hg-sante-texte hg-medecin-prix-affiche"><strong>' + esc(prix > 0 ? t('prix', { prix, cur: p.monnaie || 'FR' }) : t('gratuit')) + '</strong></p>'
      + '<p class="cpj-note hg-sante-texte">' + esc(t('accord')) + '</p>';
    fenetre('hg-medecin-proposition-' + p.id, t('titreProposition'), corps, [
      { libelle: prix > 0 ? t('accepter') : t('accepterGratuit'), primaire: true, attr: 'data-accepter', action: async () => {
        const r = await rpc('medecin_repondre', { p_proposition: p.id, p_accepte: true });
        if (!r || r.ok !== true) { toast(t('refus'), raison(r), false); return; }
        resynchroniser();
        if (r.acte === 'diagnostic') fenetreDiagnostic(r.diagnostic, p.medecin);
        else if (r.soin) fenetre('hg-medecin-soin', t('titreSoin'), '<p class="hg-sante-texte">' + esc(t('soinTexte', r.soin)) + '</p>');
      } },
      { libelle: t('refuser'), attr: 'data-refuser', action: async () => {
        const r = await rpc('medecin_repondre', { p_proposition: p.id, p_accepte: false });
        if (!r || r.ok !== true) { toast(t('refus'), raison(r), false); return; }
        toast(t('refuser'), t('refuse'), true);
      } }
    ]);
  }
  function fenetreDiagnostic(d, qui) {
    if (!d) return;
    const maladies = Array.isArray(d.maladies) ? d.maladies : [];
    const liste = maladies.length
      ? '<ul class="hg-sante-texte hg-diagnostic-liste">' + maladies.map(m => '<li><strong>' + esc(m.nom) + '</strong>'
          + (m.medicament_nom ? ' — ' + esc(t('seSoigne', { m: m.medicament_nom })) + (m.traitee ? ' (' + esc(t('dejaPris')) + ')' : '') : '') + '</li>').join('') + '</ul>'
      : '<p class="hg-sante-texte">' + esc(t('aucuneMaladie')) + '</p>';
    fenetre('hg-medecin-diagnostic', t('titreDiagnostic') + (qui ? ' — ' + qui : ''),
      '<p class="hg-sante-texte"><strong>' + esc(t('santeExacte', { n: d.sante })) + '</strong></p>' + liste);
  }
  async function propositionsEnAttente() {
    const r = await rpc('medecin_propositions_lire', {});
    if (r && r.ok === true) (r.propositions || []).forEach(fenetreProposition);
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Point 22 : montrer un objet
  // ---------------------------------------------------------------------------------------------------------------
  async function montrerObjet(idx, cible) {
    const item = (etat().inventory || [])[idx];
    cible = cible || global._hgSanteCible;
    if (!item) { toast(t('refus'), t('r_objet_introuvable'), false); return false; }
    if (!cible) { toast(t('refus'), t('choisirJoueur'), false); return false; }
    const r = await rpc('objet_montrer', { p_destinataire: cible, p_index: idx, p_nom: item.name || null });
    if (!r || r.ok !== true) { toast(t('refus'), raison(r), false); return false; }
    toast(t('montrer'), t('montrerFait', { nom: item.name, cible }), true);
    // La ligne du journal vient du serveur (objet_montre_envoye) : on la lit tout de suite.
    if (typeof global.lireEvenementsPersonnage === 'function') global.lireEvenementsPersonnage();
    return true;
  }
  function montrerDepuisFiche(idx) {
    const sel = doc.getElementById('donner-objet-cible') || doc.getElementById('montrer-objet-cible');
    return montrerObjet(idx, sel && sel.value);
  }
  function montrerChoisir() {
    const cible = global._hgSanteCible;
    if (!cible) return;
    doc.getElementById('modal-pnj')?.classList.remove('open');
    const inv = etat().inventory || [];
    let corps = '<p class="cpj-note hg-sante-texte">' + esc(inv.length ? t('montrerChoisir', { cible }) : t('inventaireVide')) + '</p><div class="hg-montrer-liste">';
    inv.forEach((item, idx) => {
      if (!item) return;
      corps += '<button type="button" class="cpj-touche hg-montrer-choix" data-idx="' + idx + '"><i class="ti ' + esc(item.icon || 'ti-package') + '"></i> ' + esc(item.name) + '</button>';
    });
    corps += '</div>';
    const f = fenetre('hg-montrer-choix', t('montrer') + ' — ' + cible, corps, [{ libelle: t('annuler') }]);
    f && f.querySelectorAll('.hg-montrer-choix').forEach(b => { b.onclick = async () => { b.disabled = true; if (await montrerObjet(Number(b.dataset.idx), cible)) f.remove(); else b.disabled = false; }; });
  }
  const imageSure = u => typeof u === 'string' && (/^https:\/\/[^\s"'<>]+$/.test(u) || /^images\/[^\s"'<>:]+$/.test(u)) ? u : '';
  function fenetreObjetMontre(p) {
    const img = imageSure(p.image);
    const corps = (img ? '<img class="hg-montrer-image" src="' + esc(img) + '" alt="">' : '<div class="hg-montrer-icone"><i class="ti ' + esc(p.icon || 'ti-package') + '"></i></div>')
      + '<p class="hg-sante-texte hg-montrer-nom"><strong>' + esc(p.nom) + '</strong></p>'
      + (p.desc ? '<p class="hg-sante-texte hg-montrer-desc">' + esc(p.desc) + '</p>' : '');
    fenetre('hg-objet-montre', t('titreMontre', { de: p.de || '' }), corps);
  }

  // Journal d'événements du serveur → fenêtres.
  const g = global.rpEvenementsPersonnageGestionnaires = global.rpEvenementsPersonnageGestionnaires || {};
  g.medecin_proposition = ev => fenetreProposition(ev.params || {});
  g.medecin_diagnostic_resultat = ev => { const p = ev.params || {}; fenetreDiagnostic(p, p.patient); resynchroniser(); };
  g.medecin_soin_fait = () => resynchroniser();
  g.objet_montre = ev => fenetreObjetMontre(ev.params || {});

  global.hgMedecinMontrerBoutonsCarte = boutonsCarte;
  global.hgMedecinOuvrir = ouvrirActe;
  global.hgMontrerChoisir = montrerChoisir;
  global.hgMontrerObjet = montrerObjet;
  global.hgMontrerDepuisFiche = montrerDepuisFiche;
  global.hgSanteTexteJauge = (cle, n) => (cle === 'sante' ? texteSante(n) : texteMoral(n));
  global.hgMedecinPropositionsEnAttente = propositionsEnAttente;
  if (doc) {
    if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', brancherJauges); else brancherJauges();
    global.setTimeout(propositionsEnAttente, 7000);
  }
})(typeof window !== 'undefined' ? window : globalThis);
