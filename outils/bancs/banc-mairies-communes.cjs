// Banc : services communs des mairies des trois villes (décision de Fred, 29/10/2026).
const vm = require('vm'), fs = require('fs'), path = require('path');
const R = path.join(__dirname, '..', '..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const ctx = { window: {}, console, document: {}, localStorage: { getItem() {} } };
vm.createContext(ctx); vm.runInContext(lire('data.js'), ctx, { filename: 'data.js' });
const B = vm.runInContext('BUILDINGS', ctx), W = vm.runInContext('WORLD', ctx);
const poli = lire('plateau-politique.js'), routeur = lire('plateau-router.js'), enigme = lire('plateau-enigme-portrait.js');
let n = 0, ko = 0; const t = (nom, ok) => { n++; if (!ok) ko++; console.log((ok ? 'ok   ' : 'ECHEC') + ' ' + nom); };
// Ordres supplémentaires d'état civil (plateau-politique.js), par gabarit.
const extra = g => { const m = poli.match(new RegExp("\\n  '" + g + "': \\[([\\s\\S]*?)\\n  \\]")); return m ? [...m[1].matchAll(/fn:'([a-z_]+)'/g)].map(x => x[1]) : []; };
const ordresVille = (ville, gabarit) => {
  const h = W.republic[ville].buildingContext?.[gabarit] || {};
  const fns = [];
  for (const r of Object.values(B[gabarit].rooms)) (r.orders || []).forEach(o => fns.push(o.fn));
  for (const r of Object.values(h.roomsExtra || {})) (r.orders || []).forEach(o => fns.push(o.fn));
  for (const r of Object.values(h.roomOverrides || {})) (r.orders || []).forEach(o => fns.push(o.fn));
  return fns.concat(extra(gabarit));
};
const villes = { capitale: 'mairie-capitale', ville_a: 'mairie', ville_b: 'mairie' };
const communs = ['calendrier_elections', 'objet_trouve', 'acte_officiel', 'consulter_mandats_maires', 'consulter_etat_civil', 'etat_civil', 'demander_logement_social'];
for (const [v, g] of Object.entries(villes)) {
  const f = ordresVille(v, g), nom = W.republic[v].name;
  t(nom + ' : services communs presents une seule fois', communs.every(c => f.filter(x => x === c).length === 1));
  t(nom + ' : ni postuler, ni gerer_finances, ni corrompre_fonct', !['postuler', 'gerer_finances', 'corrompre_fonct'].some(x => f.includes(x)));
  // 29/10/2026 : tableau de bord des logements sociaux de l'adjoint dans les trois mairies.
  t(nom + ' : tableau de bord des logements sociaux present une seule fois', f.filter(x => x === 'traiter_demandes_logement_social').length === 1);
}
const ls = lire('plateau-logements-sociaux.js');
t('sans logements sociaux, la demande affiche « Il n y a pas de logements sociaux dans la ville. » avant tout cout',
  /fn === 'demander_logement_social'\) \{ demanderLogementSocialCommun\(pa, cost\)/.test(routeur)
  && /aucun_logement_social: "Il n'y a pas de logements sociaux dans la ville\."/.test(ls)
  && /sbRpcVerdict\('logements_sociaux_offre'[\s\S]{0,160}offre\.offre === false\) \{\s*showToast\('Logements sociaux', LOGEMENTS_SOCIAUX_MOTIFS\.aucun_logement_social/.test(ls));
t('archives des maires lues pour la ville courante', /sbGetArchivesMandatsMaires\(paysArchives, villeArchives\)/.test(enigme) && !/sbGetArchivesMandatsMaires\('republic', 'capitale'\)/.test(enigme));
console.log(`\n${n - ko}/${n} tests passes`); process.exit(ko ? 1 : 0);
