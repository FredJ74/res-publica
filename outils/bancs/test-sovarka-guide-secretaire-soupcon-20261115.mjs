// Décisions de Fred du 15/11/2026 : guide des baies sauvages (lecture 2 PA, +1 INT 24 h), secrétaire de
// mairie de Krasnov (Galina Dokladova), questions parodiques des fonctionnaires de Sovarka.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { consigneSoupconSovarka, estFonctionnaireSovarka } from '../../api/_pnj-fonctionnaires-sovarka.js';
import { TOUS_PROFILS } from '../../api/_pnj-profils.js';
import { SCENES_PNJ } from '../../api/_pnj-scenes-generes.js';
const read = p => fs.readFileSync(new URL('../../' + p, import.meta.url), 'utf8');

const accueilKrasnov = SCENES_PNJ[JSON.stringify(['soviet', 'ville_b', 'mairie', 'accueil_mairie'])];
const posKrasnov = { ok: true, country: 'soviet', city: 'ville_b', building: 'mairie', room: 'accueil_mairie' };

test('Galina Dokladova : PNJ de l’accueil de Krasnov, fiche et rôle traduit', () => {
  assert.deepEqual(accueilKrasnov.personnes, ['Galina Dokladova']);
  assert.equal(TOUS_PROFILS.galina_dokladova?.nom, 'Galina Dokladova');
  assert.match(read('data.js'), /name:'Galina Dokladova \(PNJ\)', role:'Secrétaire de mairie de Krasnov'/);
  assert.match(read('i18n/sovarka-roles-resources.js'), /\["Secrétaire de mairie de Krasnov","Krasnov town hall secretary"(,"[^"]+"){7}\]/);
});

test('Fonctionnaires de Sovarka : présence confirmée, pays, exclusions', () => {
  assert.equal(estFonctionnaireSovarka('galina_dokladova', TOUS_PROFILS.galina_dokladova, posKrasnov, accueilKrasnov), true);
  // Hors de Sovarka, ou hors de la pièce : jamais.
  assert.equal(estFonctionnaireSovarka('galina_dokladova', TOUS_PROFILS.galina_dokladova, { ...posKrasnov, country: 'republic' }, accueilKrasnov), false);
  assert.equal(estFonctionnaireSovarka('galina_dokladova', TOUS_PROFILS.galina_dokladova, posKrasnov, { personnes: ['Quelqu’un'] }), false);
  // Un assassin du centre d'affaires n'est pas fonctionnaire.
  const p = TOUS_PROFILS.sovarka_moissei_kisseliov;
  assert.equal(estFonctionnaireSovarka('sovarka_moissei_kisseliov', p, posKrasnov, { personnes: [p.nom] }), false);
});

test('Environ une conversation sur quatre, stable pour un joueur, un PNJ et un jour', () => {
  const jour = new Date('2026-11-15T10:00:00Z');
  let oui = 0;
  for (let i = 0; i < 2000; i++) if (consigneSoupconSovarka('galina_dokladova', TOUS_PROFILS.galina_dokladova, posKrasnov, accueilKrasnov, 'joueur-' + i, jour)) oui++;
  assert.ok(oui > 400 && oui < 600, 'part observée : ' + oui + '/2000');
  const id = [...Array(50).keys()].map(i => 'j' + i).find(j => consigneSoupconSovarka('galina_dokladova', TOUS_PROFILS.galina_dokladova, posKrasnov, accueilKrasnov, j, jour));
  const c = consigneSoupconSovarka('galina_dokladova', TOUS_PROFILS.galina_dokladova, posKrasnov, accueilKrasnov, id, new Date('2026-11-15T22:30:00Z'));
  assert.ok(c.includes('ministère de la Sécurité du Peuple') && c.includes('Une seule fois'));
  assert.equal(consigneSoupconSovarka('galina_dokladova', TOUS_PROFILS.galina_dokladova, posKrasnov, accueilKrasnov, null, jour), '');
});

test('Le chat ajoute la consigne au prompt système', () => {
  const chat = read('api/chat.js');
  assert.match(chat, /consigneSoupconSovarka\(req\.body\.profil, TOUS_PROFILS\[req\.body\.profil\], position, scene, utilisateur\.id\)/);
});

test('Guide des baies : déposé en inventaire, bouton Lire, serveur', () => {
  assert.match(read('plateau-actions-illegales-rumeurs.js'), /id: 'guide_baies_krasnov', label: 'Guide des baies sauvages de Krasnov', familleProduitMarche: 'livre'/);
  assert.match(read('plateau-personnage.js'), /item\.type === 'guide_baies_krasnov' && typeof lireGuideBaies === 'function'/);
  assert.match(read('plateau-sovarka-provinces.js'), /provActe\('guide_baies_lire', \{\}, 'lire'\)/);
  const m = read('migrations/20261115103000_guide_baies_lecture.sql');
  assert.match(m, /SET famille_produit_marche = 'livre'/);
  assert.match(m, /'lire_guide_baies', 2, 0/);
  assert.match(m, /'deltas', jsonb_build_object\('INT', 1\)/);
  assert.match(m, /v_now \+ 24 \* 3600 \* 1000/);
  assert.match(m, /'effet_deja_actif'/);
  const i18n = read('i18n/sovarka-provinces-resources.js');
  assert.equal((i18n.match(/"guideRead": /g) || []).length, 9);
  assert.equal((i18n.match(/"m_effet_deja_actif": /g) || []).length, 9);
});
