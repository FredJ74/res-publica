// Banc : chaque commissaire dispose des mêmes pouvoirs (décision de Fred, 29/10/2026).
// Le gabarit commun de Montrouge et PSM (commissariat-local) doit offrir exactement les ordres de
// Luthécia (commissariat), aux mêmes coûts, et aucun habillage de ville ne doit les masquer.
const vm = require('vm'), fs = require('fs'), path = require('path');
const R = path.join(__dirname, '..', '..');
const ctx = { window: {}, console, document: {}, localStorage: { getItem() {} } };
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(R, 'data.js'), 'utf8'), ctx, { filename: 'data.js' });
const B = vm.runInContext('BUILDINGS', ctx);
let n = 0, ko = 0;
const t = (nom, ok) => { n++; if (!ok) ko++; console.log((ok ? 'ok   ' : 'ECHEC') + ' ' + nom); };
const ordres = b => Object.values(B[b].rooms).flatMap(r => (r.orders || []).map(o => o.fn + ':' + o.pa + '/' + o.cost + ':' + JSON.stringify(o.requiresPost || null))).sort();
const lut = ordres('commissariat'), loc = ordres('commissariat-local');
t('memes ordres, memes couts, memes postes requis qu a Luthecia', JSON.stringify(lut) === JSON.stringify(loc));
if (JSON.stringify(lut) !== JSON.stringify(loc)) console.log('  Luthecia seul :', lut.filter(x => !loc.includes(x)), '\n  local seul :', loc.filter(x => !lut.includes(x)));
const bur = fn => (B['commissariat-local'].rooms.bureau_commissaire?.orders || []).some(o => o.fn === fn);
t('bureau du commissaire present avec enquete, filature, chasse a l homme et dossiers', ['dossiers_plaintes', 'mener_enquete', 'organiser_filature', 'organiser_chasse_homme'].every(bur));
const acc = fn => B['commissariat-local'].rooms.accueil_loc.orders.some(o => o.fn === fn);
t('accueil : archives et arrestation d urgence', acc('archives_police') && acc('arreter'));
// Aucun habillage de ville ne redéfinit des ordres ni n'ajoute de pièce qui masquerait le gabarit.
const W = vm.runInContext('WORLD', ctx);
const habillages = [];
for (const [pays, villes] of Object.entries(W)) for (const [ville, v] of Object.entries(villes || {})) {
  const h = v?.buildingContext?.['commissariat-local']; if (h) habillages.push([pays + '/' + ville, h]);
}
t('habillages de ville trouves (' + habillages.length + ')', habillages.length >= 2);
t('aucun habillage ne porte d ordres ni de piece ajoutee', habillages.every(([, h]) => !h.roomsExtra
  && Object.values(h.roomOverrides || {}).every(r => !('orders' in r))));
console.log(`\n${n - ko}/${n} tests passes`);
process.exit(ko ? 1 : 0);
