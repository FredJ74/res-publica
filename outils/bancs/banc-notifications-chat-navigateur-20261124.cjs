// Chromium réel, vrai plateau.html : notifications du navigateur pour le chat (purge A.8, Fred, 24/11/2026).
// Bulle de proposition avec « ? » (jamais pendant la première heure), réglage activer/couper, une notification par
// interlocuteur jusqu'à la reconnexion et pas plus d'une par heure, jamais le texte du message, rien pour le PNJ guide.
// Vrais fichiers : plateau-fenetres-auto.js, plateau-notifications-chat.js ; serveur et API Notification simulés.
const test = require('node:test'), assert = require('node:assert/strict');
const { avecJeu, page } = require('./mobile-navigateur.cjs');

function simuler() {
  const S = { premiere: true, active: false, proposee: false };
  window.__S = S; window.__appels = []; window.__notifs = []; window.__permission = 'default';
  window.Notification = class { constructor(t, o) { window.__notifs.push({ titre: t, corps: o && o.body }); }
    static get permission() { return window.__permission; } static async requestPermission() { window.__permission = 'granted'; return 'granted'; } };
  const lire = () => ({ ok: true, active: S.active, proposee: S.proposee, a_proposer: !S.proposee && !S.premiere, premiere_heure: S.premiere });
  window.sbRpc = async (fn, a) => {
    window.__appels.push([fn, a]);
    if (fn === 'notifications_chat_lire') return lire();
    if (fn === 'notifications_chat_fixer') { S.active = !!a.p_active; S.proposee = true; return lire(); }
    return null;
  };
  window.state = { char: { name: 'Bernard' }, country: 'soviet', currentCity: 'ville_b', currentBuilding: 'bar-sever' };
  window.nomBatimentTraduit = () => 'Bar Sever';
  window.showToast = () => {};
}
async function preparer(b, o) {
  const p = await page(b, o, 390, 844, false, { texteMinimum: true });
  const erreurs = []; p.on('pageerror', e => erreurs.push(e.message));
  await p.evaluate(simuler);
  for (const s of ['plateau-accueil-progressif.js', 'plateau-notifications-chat.js']) await p.addScriptTag({ url: o + '/' + s });
  await p.waitForFunction(() => window.RPNotifChat);
  return { p, erreurs };
}
const cacher = p => p.evaluate(() => { Object.defineProperty(document, 'hidden', { configurable: true, get: () => true }); document.hasFocus = () => false; });

test('proposition : pas pendant la première heure, puis bulle avec « ? », activation enregistrée au serveur', async () => avecJeu(async (b, o) => {
  const { p, erreurs } = await preparer(b, o);
  await p.evaluate(() => window.RPNotifChat.messageRecu({ id: 'm1', auteur: 'Ivan', conversation_id: 'Bernard__Ivan' }, 'Ivan'));
  await p.waitForTimeout(200);
  assert.equal(await p.locator('#hg-notif-proposition').count(), 0, 'première heure : la bulle attend');
  await p.evaluate(() => { window.__S.premiere = false; return window.RPNotifChat.lire(true); });
  await p.evaluate(() => window.RPNotifChat.messageRecu({ id: 'm2', auteur: 'Ivan', conversation_id: 'Bernard__Ivan' }, 'Ivan'));
  await p.waitForSelector('#hg-notif-proposition');
  await p.locator('#hg-notif-proposition .hg-notif-q').click();
  assert.match(await p.locator('#hg-notif-aide').innerText(), /jamais le contenu du message/);
  const t = await p.evaluate(() => parseFloat(getComputedStyle(document.querySelector('#hg-notif-proposition p')).fontSize));
  assert.ok(t >= 15.2, 'texte lisible ' + t);
  await p.locator('[data-notif="oui"]').click();
  await p.waitForSelector('#hg-notif-proposition', { state: 'detached' });
  assert.deepEqual(await p.evaluate(() => window.__appels.filter(a => a[0] === 'notifications_chat_fixer').map(a => a[1])), [{ p_active: true }]);
  assert.deepEqual(erreurs, []);
}));

test('notifications : nom et lieu sans le message, une par interlocuteur, une par heure, anonyme, rien pour le PNJ guide', async () => avecJeu(async (b, o) => {
  const { p, erreurs } = await preparer(b, o);
  await p.evaluate(() => { window.__S.premiere = false; window.__S.proposee = true; window.__S.active = true; window.__permission = 'granted'; localStorage.clear(); });
  // Jeu sous les yeux : pas de notification.
  await p.evaluate(() => window.RPNotifChat.messageRecu({ id: 'a', auteur: 'Ivan', message: 'SECRET' }, 'Ivan'));
  assert.equal(await p.evaluate(() => window.__notifs.length), 0);
  await cacher(p);
  await p.evaluate(() => window.RPNotifChat.messageRecu({ id: 'g', auteur: 'pnj:Vera Pravdina', message: 'piste' }, 'Vera Pravdina'));
  assert.equal(await p.evaluate(() => window.__notifs.length), 0, 'PNJ guide : jamais');
  await p.evaluate(() => window.RPNotifChat.messageRecu({ id: 'b', auteur: 'Ivan', message: 'SECRET' }, 'Ivan'));
  await p.evaluate(() => window.RPNotifChat.messageRecu({ id: 'c', auteur: 'Ivan', message: 'SECRET 2' }, 'Ivan'));
  await p.evaluate(() => window.RPNotifChat.messageRecu({ id: 'd', auteur: 'Olga', message: 'SECRET 3' }, 'Olga'));
  let n = await p.evaluate(() => window.__notifs);
  assert.deepEqual(n, [{ titre: 'Human Gambit', corps: 'Ivan vous a parlé (Bar Sever)' }], 'une seule : par interlocuteur et par heure');
  await p.evaluate(() => localStorage.clear());   // une heure plus tard
  await p.evaluate(() => window.RPNotifChat.messageRecu({ id: 'e', auteur: 'masque:1234', message: 'SECRET 4' }, 'Individu masqué'));
  n = await p.evaluate(() => window.__notifs);
  assert.equal(n[1].corps, 'Quelqu’un vous a parlé');
  assert.ok(n.every(x => !/SECRET/.test(x.corps)), 'jamais le texte du message');
  // Réglage dans le chat : couper.
  await p.evaluate(() => { const d = document.createElement('div'); d.id = 'zone-test'; document.body.appendChild(d); return window.RPNotifChat.insererReglage(d); });
  assert.match((await p.locator('[data-notif-reglage]').innerText()).replace(/\s+/g, ' '), /Notifications du chat : activées/);
  await p.locator('[data-notif-basculer="couper"]').click();
  await p.waitForFunction(() => /coupées/.test(document.querySelector('[data-notif-reglage]')?.innerText || ''));
  assert.deepEqual(erreurs, []);
}));
