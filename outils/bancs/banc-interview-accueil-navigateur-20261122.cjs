'use strict';
// Interview d'accueil (Fred, 21/11/2026, GAME-DESIGN-INTERVIEW-ACCUEIL-20261121.md, points 2 à 5), dans un vrai
// navigateur (Chrome/Chromium) : style.css réel, fonctions réelles de forum.js et de plateau-communication.js
// extraites telles quelles. L'API /api/jodie-portrait est une fixture (aucun compte, aucun appel distant).
// Vérifie :
//  - titre de la fenêtre : « Courrier » dans la boîte mail (liste, lecture, interview), « Forum » au forum ;
//  - compteur de la Boîte Mail : nombre réel de messages et de non lus, mis à jour en direct à la lecture ;
//    « Aucun message » seulement si la boîte est vide ;
//  - invitation de Tom Tom à Krasnov par Anatoli Kolosov : boutons sous le courrier seulement si le serveur confirme ;
//    refus déjà donné = message, aucun bouton ; panne = « Réessayer » ; formulaire jamais ouvert si l'envoi est impossible ;
//  - premier jour : réponses envoyées, aperçu, publication, retour à la boîte sans recharger ;
//  - lisibilité : la question est le texte le plus contrasté de la fenêtre, casse normale, ≥ 17 px (texte courant) ;
//    indications, « Précédent », « Suivant », envoi, « Retour au courrier » : contraste AA (≥ 4,5:1) mesuré ;
//    contre-épreuve : l'ancien libellé (.forum-field-label) échoue.
// Usage : HG_CHROMIUM=<chrome> NODE_PATH=outils/e2e/node_modules node outils/bancs/banc-interview-accueil-navigateur-20261122.cjs
const { test } = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const { lancerChromium } = require('./fixtures/chromium-cdp.cjs');
const { chromium } = require('../e2e/node_modules/playwright');
const acorn = require('../e2e/node_modules/acorn');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
function extraire(source, noms) {
  const trouves = new Set();
  const code = acorn.parse(source, { ecmaVersion: 'latest' }).body.filter(n => {
    const nom = n.type === 'FunctionDeclaration' ? n.id.name : n.type === 'VariableDeclaration' ? n.declarations[0].id.name : null;
    if (noms.includes(nom)) { trouves.add(nom); return true; } return false;
  }).map(n => source.slice(n.start, n.end)).join('\n');
  const manquants = noms.filter(n => !trouves.has(n));
  assert.deepEqual(manquants, [], 'fonctions introuvables');
  return code;
}
const FORUM = extraire(lire('forum.js'), ['escapeHtmlText', 'rpForumLibelle', 'rpForumCompte', 'rpForumPlateauLibelle', 'rpForumUiOuvert',
  'rpForumNomOuvert', 'rpForumPlateauOuvert', 'renderForumContent', 'renderMailView', 'renderMailRead', 'renderMailInbox', 'mailSujetAffiche',
  'mailVuTraduit', 'mailsRecusVisibles', 'renderForumSidebar', 'htmlCompteurBoiteMail', 'titreFenetreForum', 'appliquerTitreFenetreForum',
  'rafraichirVoyantsEtCompteursForum', 'renderForumModal', 'readMail']);
const PORTRAIT = extraire(lire('plateau-communication.js'), ['PRESSE_ANTENNES_ACCUEIL', 'JODIE_PORTRAIT_SUJET_PROPOSITION', 'JODIE_PORTRAIT_SUJET_REFUS',
  'JODIE_PORTRAIT_TITRE_PREFIXE', 'JODIE_QUESTIONS_INTERVIEW', 'PORTRAIT_TXT', 'portraitTexte', 'portraitSujetInvitation', 'portraitSujetRefus',
  'portraitAntenneInvitation', 'portraitJournaliste', 'jodiePortraitEtat', 'portraitMessageEtat', 'portraitRendreBoite', 'jodiePortraitRefuser',
  'jodiePortraitOuvrirInterview', 'jodiePortraitRafraichirEtatMail', 'jodieInterviewAllerPage', 'renderJodieInterviewForm',
  'jodiePortraitGenererApercu', 'renderJodiePortraitPreview', 'jodiePortraitPublier']);

async function ouvrir(largeur = 1280) {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-interview-'));
  const executable = process.env.HG_CHROMIUM || ['/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable'].find(p => fs.existsSync(p));
  assert.ok(executable, 'Chromium requis (HG_CHROMIUM)');
  const chrome = await lancerChromium({ executable, profil });
  const navigateur = await chromium.connectOverCDP('http://127.0.0.1:' + chrome.port);
  const page = await navigateur.contexts()[0].newPage();
  const erreurs = []; page.on('pageerror', e => erreurs.push(e.message));
  await page.setViewportSize({ width: largeur, height: 760 });
  await page.route('**/*', r => r.abort());
  await page.setContent('<style>' + lire('style.css') + '</style><div id="modal-forum" class="modal-overlay open"><div class="modal-box modal-fullscreen">' +
    '<div class="modal-header"><div class="modal-title" id="modal-forum-title">Forum</div></div><div id="forum-body"></div></div></div>');
  await page.addScriptTag({ content: `
    var forumView='mail', mailView='inbox', mailRubrique='recus', currentMailId=null, currentForumId=null, mailDefaultTo='';
    var state={char:{name:'Tom Tom'}}, toasts=[], appels=[], etatApi={ok:true,peutRepondre:true,journaliste:'Anatoli Kolosov',journal:'La Voix de Sovarka'};
    var MAILS=[
      {id:'inv',to:'Tom Tom',from:'Anatoli Kolosov',subject:'Un portrait pour La Voix de Sovarka ?',body:'<p>Bonjour, accepteriez-vous ?</p>',time:'21/11 13h',read:false},
      {id:'vieux',to:'Tom Tom',from:'Mairie de Krasnov',subject:'Bienvenue',body:'<p>Bienvenue.</p>',time:'20/11 15h',read:true}];
    function getMails(){return MAILS;} function getMyMails(){return MAILS;} function trierMailsRecents(l){return l;}
    function markMailRead(id){const m=MAILS.find(x=>x.id===id); if(m) m.read=true;}
    function rafraichirVoyantMailLocal(){} function extraireActionsMail(c){return {corps:c,actions:[]};} function boutonsActionMail(){return '';}
    function sanitizeRichHtml(x){return x;} function formatDateAffichage(t){return t;} function getAvatarHtmlPost(){return '';}
    function htmlSelecteurPaysForums(){return '';} function htmlPointRougeActivite(){return '<span class="point-rouge"></span>';}
    function renderCategorieHeader(){return '';} function getForums(){return {};} function canAccessForum(){return false;}
    function forumADeLActiviteNonVue(){return false;} function renderForumAccueil(){return '<div id="accueil-forum">Forums</div>';}
    function formatDateHeureJeu(){return '22/11 10h';}
    function showToast(t,m,ok){toasts.push({t,m,ok});}
    async function verifierNouveauxMails(){}
    async function jodiePortraitAppelApi(p){
      appels.push(JSON.parse(JSON.stringify(p)));
      if(p.action==='etat') return etatApi;
      if(p.action==='apercu') return {ok:true,texte:'Tom Tom est arrivé à Krasnov.',jeton:'j1',journaliste:'Anatoli Kolosov',journal:'La Voix de Sovarka'};
      if(p.action==='publier') return {ok:true,journaliste:'Anatoli Kolosov'};
      if(p.action==='refuser') return {ok:true};
      return {ok:false,error:'action inconnue'};
    }
    ${FORUM}
    ${PORTRAIT}
    renderForumModal();` });
  const fermer = async () => { await navigateur.close(); await chrome.arreter(); fs.rmSync(profil, { recursive: true, force: true }); };
  return { page, fermer, erreurs };
}
const titre = page => page.locator('#modal-forum-title').innerText();
const compteur = page => page.locator('.forum-mail-item .forum-nav-count').innerText();

test('titre de la fenêtre et compteur de la Boîte Mail, en direct', { timeout: 60000 }, async () => {
  const { page, fermer, erreurs } = await ouvrir();
  try {
    assert.equal(await titre(page), 'Courrier');
    assert.equal(await compteur(page), '2 messages · 1 non lu(s)');
    await page.evaluate(() => readMail('inv'));
    assert.equal(await titre(page), 'Courrier', 'lecture d’un courrier : « Courrier », jamais « Forum »');
    assert.equal(await compteur(page), '2 messages', 'pendant la lecture : jamais « Aucun message »');
    await page.evaluate(() => { forumView = 'list'; renderForumModal(); });
    assert.equal(await titre(page), 'Forum');
    await page.evaluate(() => { forumView = 'mail'; MAILS.length = 0; renderForumModal(); });
    assert.equal(await titre(page), 'Courrier');
    assert.equal(await compteur(page), 'Aucun message');
    await page.evaluate(() => { MAILS.push({ id: 'n', to: 'Tom Tom', from: 'X', subject: 'S', body: '', time: 't', read: false }); rafraichirVoyantsEtCompteursForum(); });
    assert.equal(await compteur(page), '1 message · 1 non lu(s)', 'arrivée d’un courrier : compteur à jour sans recharger');
    assert.deepEqual(erreurs, []);
  } finally { await fermer(); }
});

test('invitation d’Anatoli Kolosov : boutons seulement si l’envoi sera possible ; refus et panne sans impasse', { timeout: 60000 }, async () => {
  const { page, fermer, erreurs } = await ouvrir();
  try {
    await page.evaluate(() => readMail('inv'));
    await page.locator('#jodie-portrait-etat button', { hasText: "Accepter l'interview" }).waitFor();
    assert.equal(await page.locator('#jodie-portrait-etat button', { hasText: 'Refuser' }).count(), 1);
    // Déjà refusé : un message, aucun bouton ; le formulaire ne s'ouvre pas même si on force l'appel.
    await page.evaluate(() => { etatApi = { ok: true, peutRepondre: false, raison: 'refuse' }; jodiePortraitRafraichirEtatMail(); });
    await page.locator('#jodie-portrait-etat', { hasText: 'Vous avez décliné cette proposition.' }).waitFor();
    assert.equal(await page.locator('#jodie-portrait-etat button').count(), 0);
    await page.evaluate(() => jodiePortraitOuvrirInterview());
    assert.equal(await page.evaluate(() => mailView), 'read', 'aucun formulaire impossible à envoyer');
    assert.equal(await page.evaluate(() => toasts.at(-1).t), 'Interview impossible');
    // Panne : message et « Réessayer », qui relance la vérification sans recharger.
    await page.evaluate(() => { etatApi = { ok: false, error: 'Connexion au serveur indisponible.' }; document.getElementById('jodie-portrait-etat').innerHTML = ''; jodiePortraitRafraichirEtatMail(); });
    await page.locator('#jodie-portrait-etat button', { hasText: 'Réessayer' }).waitFor();
    await page.evaluate(() => { etatApi = { ok: true, peutRepondre: true, journaliste: 'Anatoli Kolosov', journal: 'La Voix de Sovarka' }; });
    await page.click('#jodie-portrait-etat button:has-text("Réessayer")');
    await page.locator('#jodie-portrait-etat button', { hasText: "Accepter l'interview" }).waitFor();
    assert.deepEqual(erreurs, []);
  } finally { await fermer(); }
});

for (const largeur of [390, 1280]) test('premier jour : cinq réponses, aperçu, publication, retour à la boîte — ' + largeur, { timeout: 60000 }, async () => {
  const { page, fermer, erreurs } = await ouvrir(largeur);
  try {
    await page.evaluate(() => readMail('inv'));
    await page.click('#jodie-portrait-etat button:has-text("Accepter l\'interview")');
    await page.waitForFunction(() => mailView === 'jodie-interview');
    assert.match(await page.locator('#forum-main .forum-title-main').innerText(), /Interview avec Anatoli Kolosov/);
    assert.equal(await titre(page), 'Courrier');
    for (let i = 0; i < 5; i++) {
      await page.fill('#jodie-reponse-' + i, 'Réponse ' + (i + 1));
      if (i < 4) await page.click('button:has-text("Suivant")');
    }
    // Une réponse effacée : retour direct à la question vide, message qui la nomme, rien n'est envoyé.
    await page.evaluate(() => { window._jodieInterviewReponses[2] = ' '; });
    await page.click('button:has-text("Envoyer mes réponses à Anatoli Kolosov")');
    assert.match(await page.locator('#forum-main').innerText(), /Question 3 sur 5/);
    assert.equal(await page.evaluate(() => toasts.at(-1).m), 'Il manque la réponse à la question 3. Écrivez-la, puis renvoyez.');
    assert.equal(await page.evaluate(() => appels.filter(a => a.action === 'apercu').length), 0);
    await page.fill('#jodie-reponse-2', 'Réponse 3');
    await page.click('button:has-text("Suivant")'); await page.click('button:has-text("Suivant")');
    await page.click('button:has-text("Envoyer mes réponses à Anatoli Kolosov")');
    await page.waitForFunction(() => mailView === 'jodie-preview');
    assert.match(await page.locator('#forum-main').innerText(), /La Voix de Sovarka[\s\S]*Tom Tom est arrivé à Krasnov/);
    await page.click('button:has-text("Publier dans Presse & Médias")');
    await page.waitForFunction(() => mailView === 'inbox');
    assert.equal(await page.evaluate(() => toasts.at(-1).m), 'Anatoli Kolosov a publié votre portrait dans Presse & Médias.');
    const ap = await page.evaluate(() => appels.filter(a => a.action === 'apercu'));
    assert.deepEqual(ap.map(a => a.reponses), [['Réponse 1', 'Réponse 2', 'Réponse 3', 'Réponse 4', 'Réponse 5']]);
    assert.deepEqual(erreurs, []);
  } finally { await fermer(); }
});

test('lisibilité : question la plus contrastée, casse normale, ≥ 17 px ; indications et boutons au niveau AA', { timeout: 60000 }, async () => {
  const { page, fermer } = await ouvrir();
  try {
    await page.evaluate(() => { window._portraitAccueil = { journaliste: 'Anatoli Kolosov', journal: 'La Voix de Sovarka' };
      window._jodieInterviewReponses = ['a', 'b', '', '', '']; window._jodieInterviewPage = 4; mailView = 'jodie-interview'; renderForumModal(); });
    const mesures = await page.evaluate(() => {
      const lum = c => { const [r, g, b] = c.match(/[\d.]+/g).slice(0, 3).map(Number).map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
      const fond = el => { for (let e = el; e; e = e.parentElement) { const b = getComputedStyle(e).backgroundColor; const a = b.match(/[\d.]+/g); if (a && (a.length < 4 || Number(a[3]) > 0.5)) return b; } return 'rgb(0,0,0)'; };
      const ratio = el => { const a = lum(getComputedStyle(el).color), b = lum(fond(el)); return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05); };
      const m = el => el && ({ ratio: ratio(el), taille: parseFloat(getComputedStyle(el).fontSize), casse: getComputedStyle(el).textTransform, texte: el.innerText.trim() });
      const main = document.getElementById('forum-main');
      const boutons = [...main.querySelectorAll('button')];
      // Ancien libellé, pour la contre-épreuve : même fenêtre, même fond.
      const ancien = document.createElement('label'); ancien.className = 'forum-field-label'; ancien.textContent = 'Ancien libellé'; main.querySelector('.forum-field').appendChild(ancien);
      return { question: m(main.querySelector('.rp-portrait-question')), aide: m(main.querySelector('.rp-portrait-aide')),
        reponse: m(main.querySelector('textarea')), titre: m(main.querySelector('.forum-title-main')),
        boutons: boutons.map(m), ancien: m(ancien) };
    });
    const q = mesures.question;
    assert.match(q.texte, /^5\. Y a-t-il quelque chose/);
    assert.equal(q.casse, 'none');
    assert.ok(q.taille >= 17 && q.taille >= mesures.aide.taille && q.taille >= mesures.reponse.taille, 'taille de la question ' + q.taille);
    const autres = [mesures.aide, mesures.reponse, mesures.titre, ...mesures.boutons];
    console.log('contrastes mesurés : ' + [q, ...autres, mesures.ancien].map(x => `« ${x.texte.slice(0, 24)} » ${x.ratio.toFixed(2)}:1, ${x.taille}px`).join(' ; '));
    for (const x of [q, ...autres]) assert.ok(x.ratio >= 4.5, `contraste AA « ${x.texte} » : ${x.ratio.toFixed(2)}`);
    for (const x of autres) assert.ok(q.ratio >= x.ratio, `la question (${q.ratio.toFixed(2)}) est plus lisible que « ${x.texte} » (${x.ratio.toFixed(2)})`);
    assert.deepEqual(mesures.boutons.map(b => b.texte), ['Retour au courrier', 'Précédent', 'Envoyer mes réponses à Anatoli Kolosov']);
    assert.ok(mesures.ancien.ratio < 4.5, 'contre-épreuve : l’ancien libellé était sous le niveau AA (' + mesures.ancien.ratio.toFixed(2) + ')');
  } finally { await fermer(); }
});
