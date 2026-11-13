// Chambres de clinique (relevé de Fred, 13/11/2026) : escort pour l'occupant, « Sortir de l'hôpital »
// réservé au patient hospitalisé, plus de « Vérifier les bonus », plus de commerce dans une chambre.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const lire = f => fs.readFileSync(new URL('../../' + f, import.meta.url), 'utf8');

function ordresChambre({ locataire, hospitalisation = null, country = 'republic' }) {
  const ctx = { state: { country, currentCity: 'capitale', char: { name: 'Arnie' }, hospitalisation,
    locationsActives: locataire ? [{ buildingId: 'clinique-privee', roomId: 'chambre_3', locataire }] : [] } };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(lire('i18n/clinic-stay-resources.js'), ctx);
  vm.runInContext(lire('plateau-clinique-nuitee.js'), ctx);
  return ctx.RP_ORDRES_DYNAMIQUES[0]('clinique-privee', 'chambre_3');
}

// Client d'une nuit : escort proposé, « Sortir de l'hôpital » masqué, montant en FR.
let o = ordresChambre({ locataire: 'Arnie' });
assert.ok(o.some(x => x.fn === 'escort_standard'), 'escort pour l’occupant');
assert.match(o.find(x => x.fn === 'escort_standard').desc, /800 FR/);
assert.ok(o.some(x => (x.masque || []).includes('sortie_hopital')), 'sortie masquée hors hospitalisation');
assert.ok(!o.some(x => x.fn === 'clinique_verifier_bonus'), 'plus de vérification manuelle');

// Patient hospitalisé en Sovarka : escort proposé, sortie visible, montant en PSK.
o = ordresChambre({ locataire: 'Arnie', hospitalisation: { lieu: 'clinique' }, country: 'soviet' });
assert.ok(o.some(x => x.fn === 'escort_standard'));
assert.match(o.find(x => x.fn === 'escort_standard').desc, /800 PSK/);
assert.ok(!o.some(x => (x.masque || []).includes('sortie_hopital')), 'sortie visible pour le patient');

// Visiteur (chambre d'un autre) : pas d'appel d'escort.
o = ordresChambre({ locataire: 'Ben' });
assert.ok(!o.some(x => x.fn === 'escort_standard'), 'pas d’escort pour un visiteur');

// Plus de route ni de traduction pour l'ancien bouton.
assert.doesNotMatch(lire('plateau-router.js'), /clinique_verifier_bonus/);
assert.doesNotMatch(lire('i18n/clinic-stay-resources.js'), /verifyLabel/);

// Commerce : jamais dans une chambre de clinique, d'hôtel, de résidence ou un logement.
const commerce = lire('plateau-commerce-pj.js');
assert.match(commerce, /function commercePjPieceNonCommerciale[\s\S]*clinique\|hotel\|hopital\|residence\|pavillon/);
assert.match(commerce, /if \(commercePjPieceNonCommerciale\(buildingId, roomId\)\) return \[\];/);

// Le standard affiche les francs en Républia.
assert.match(lire('plateau-escorts-sovarka.js'), /state\.country !== 'soviet'\) \? texte\.replace\(\/\\bPSK\\b\/g, 'FR'\)/);

// Portraits des deux escorts des cliniques, en WebP.
for (const n of ['Irina', 'Boris']) for (const s of ['', '_vignette'])
  assert.ok(fs.existsSync(new URL(`../../images/personnages/Clinique_escort_${n}${s}.webp`, import.meta.url)), n + s);

console.log('test-clinique-chambres-escorts-20261113 : OK');
