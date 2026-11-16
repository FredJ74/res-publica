'use strict';
const assert = require('node:assert/strict');
const { demarrer, agir, choisirChampignons, sommeilAvecChampignons, RefusGoulag } = require('../../api/_goulag-survie.js');
const erreur = (fn, code) => assert.throws(fn, e => e instanceof RefusGoulag && e.code === code);
const date = n => `2026-11-${String(n).padStart(2, '0')}`;

erreur(() => demarrer({ destination: 'starovka', statut: 'detenu', pa: 6 }), 'pa_insuffisants_depart');
erreur(() => demarrer({ destination: 'krasnov', statut: 'detenu', pa: 9 }), 'pa_insuffisants_depart');
erreur(() => demarrer({ destination: 'krasnov', statut: 'detenu', pa: 0 }), 'pa_invalides');
erreur(() => demarrer({ destination: 'luthecia', statut: 'detenu', pa: 20 }), 'destination_invalide');
erreur(() => demarrer({ destination: 'starovka', statut: 'intrus', pa: 20 }), 'statut_invalide');

const depart = demarrer({ destination: 'starovka', statut: 'detenu', pa: 7 });
assert.equal(depart.pa, 7, 'Le seuil 7 PA ne doit pas être débité');

let e = agir(depart, 'progresser', date(1));
assert.equal(e.pa, 2);
erreur(() => agir(e, 'progresser', date(1)), 'progression_deja_faite');
e = agir(e, 'dormir', date(1));
assert.equal(e.pa, 5);
erreur(() => agir(e, 'dormir', date(1)), 'sommeil_deja_fait');
erreur(() => agir(e, 'progresser', date(2)), 'pa_insuffisants');
e = agir(e, 'dormir', date(2));
assert.equal(e.pa, 8);
e = agir(e, 'progresser', date(3));
assert.equal(e.pa, 3);
erreur(() => agir(e, 'abri', date(2)), 'abri_deja_fait');

// Le mode optimisé reste à solde constant sur chaque cycle complet.
let a = demarrer({ destination: 'starovka', statut: 'visiteur', pa: 7 });
for (let j = 1; j <= 7; j++) {
  a = agir(a, 'abri', date(j));
  a = agir(a, 'progresser', date(j));
  if (j === 6) assert.equal(a.boisGagne, 5);
  if (j < 7) {
    assert.equal(a.pa, 1);
    a = agir(a, 'dormir', date(j));
    assert.equal(a.pa, 7);
    assert.equal(a.termine, false);
  } else {
    assert.equal(a.termine, true);
    assert.equal(a.pa, 1);
    assert.equal(a.arrivee, 'ville_a');
    assert.equal(a.reposForceJours, 3);
    assert.equal(a.boisGagne, 3);
  }
}
erreur(() => agir(a, 'dormir', date(8)), 'traversee_invalide');

// Progression sans abri : −5 +3 = −2 PA.
let sansAbri = demarrer({ destination: 'krasnov', statut: 'visiteur', pa: 10 });
sansAbri = agir(sansAbri, 'progresser', date(1));
sansAbri = agir(sansAbri, 'dormir', date(1));
assert.equal(sansAbri.pa, 8);
erreur(() => agir({ ...sansAbri, pa: 5 }, 'progresser', date(2)), 'pa_insuffisants');

// Le solde à l'arrivée est FORCÉ à 1 même en arrivant avec plus de PA.
let k = demarrer({ destination: 'krasnov', statut: 'visiteur', pa: 20 });
for (let j = 1; j <= 10; j++) {
  k = agir(k, 'abri', date(j));
  k = agir(k, 'progresser', date(j));
  if (j === 8) assert.equal(k.boisGagne, 0);
  if (j === 9) assert.equal(k.boisGagne, 5);
  if (j !== 10) k = agir(k, 'dormir', date(j));
}
assert.equal(k.pa, 1);
assert.equal(k.arrivee, 'ville_b');
assert.equal(k.boisGagne, 3);
assert.equal(k.progressions, 10);

// Aucun ordre débiteur ne fait tomber à zéro.
const basse = { ...depart, pa: 1 };
erreur(() => agir(basse, 'abri', date(1)), 'pa_insuffisants');
erreur(() => agir(basse, 'progresser', date(1)), 'pa_insuffisants');


// Evénement du cinquième jour : la décision est une fois, côté serveur.
let cinquieme={...depart, progressions:5};
for(const pa of [6,7,8,20]) {
  const resultat=choisirChampignons({...cinquieme,pa},'manger');
  assert.equal(resultat.pa, pa>7?7:pa+1);
  erreur(()=>choisirChampignons(resultat,'manger'),'champignons_indisponibles');
}
const refus=choisirChampignons({...cinquieme,pa:20},'refuser');
assert.equal(refus.champignonsRefuses,true);
erreur(()=>agir(refus,'dormir',date(4)),'malus_champignons_non_arbitre');
assert.equal(sommeilAvecChampignons(8,6,6),8);
assert.equal(sommeilAvecChampignons(6,3,3),7);
assert.equal(sommeilAvecChampignons(20,6,2),24);
erreur(()=>sommeilAvecChampignons(20,6,undefined),'malus_champignons_non_arbitre');
erreur(()=>choisirChampignons({...cinquieme,progressions:4},'manger'),'champignons_indisponibles');

console.log('Goulag Sovarka : seuils, survie, double-clic, jours, bois, arrivée et fatigue : OK');
