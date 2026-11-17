'use strict';

/**
 * Moteur déterministe de la traversée du goulag de Sovarka.
 *
 * Aucun accès client direct : les fonctions ci-dessous sont des règles pures.
 * Le futur RPC devra verrouiller le personnage, vérifier les droits et persister
 * l'état + les PA + l'inventaire dans UNE transaction. Les décisions du 16/11 sont
 * documentées dans GAME-DESIGN-GOULAG-SOVARKA.md.
 */
const ITINERAIRES = Object.freeze({
  starovka: Object.freeze({ ville: 'ville_a', minimumPA: 7, progressions: 7 }),
  krasnov: Object.freeze({ ville: 'ville_b', minimumPA: 10, progressions: 10 }),
});

class RefusGoulag extends Error {
  constructor(code) {
    super(code);
    this.name = 'RefusGoulag';
    this.code = code;
  }
}

function refuser(code) { throw new RefusGoulag(code); }
function entier(x) { return Number.isSafeInteger(x) && x >= 0; }
function verifierPA(pa) {
  if (!entier(pa) || pa < 1) refuser('pa_invalides');
}
function verifierJour(jour) {
  if (typeof jour !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(jour)) refuser('jour_invalide');
}
function verifierEtat(etat) {
  if (!etat || typeof etat !== 'object' || !ITINERAIRES[etat.destination]
    || !['detenu', 'visiteur'].includes(etat.statut) || !entier(etat.progressions)
    || etat.progressions >= ITINERAIRES[etat.destination].progressions
    || !Array.isArray(etat.jours)) refuser('traversee_invalide');
}

/**
 * L'habilitation, la détention, la confiscation et le gel de peine doivent
 * être vérifiés/effectués dans le RPC, jamais depuis cette fonction.
 * Le seuil 7/10 PA n'est PAS une dépense.
 */
function demarrer({ destination, statut, pa }) {
  const route = ITINERAIRES[destination];
  if (!route) refuser('destination_invalide');
  if (!['detenu', 'visiteur'].includes(statut)) refuser('statut_invalide');
  verifierPA(pa);
  if (pa < route.minimumPA) refuser('pa_insuffisants_depart');
  return {
    destination, statut, progressions: 0, jours: [], termine: false,
    prochaineEtape: route.progressions, pa,
  };
}

/**
 * jour : date civile canonique Europe/Paris, fournie par le serveur.
 * Les appels en concurrence doivent être sérialisés par le RPC.
 */

/** Choix unique à partir du 5e jour civil de traversée (pas la 5e progression). */
function choisirChampignons(etat, choix, jourDepuisDepart) {
  verifierEtat(etat);
  verifierPA(etat.pa);
  if (!entier(jourDepuisDepart) || jourDepuisDepart < 5 || etat.champignonsChoisis)
    refuser('champignons_indisponibles');
  if (!['manger','refuser'].includes(choix))
    refuser('choix_champignons_invalide');
  if (choix === 'manger') {
    return {...etat, pa:etat.pa > 7 ? 7 : etat.pa + 1,
      champignonsChoisis:true, champignonsRefuses:false};
  }
  return {...etat, champignonsChoisis:true,
    champignonsRefuses:etat.pa>7};
}

/** Montant encore non validé : aucune déduction silencieuse. */
function sommeilAvecChampignons(pa, gain, malus = 2) {
  verifierPA(pa);
  if (!entier(gain) || gain < 1) refuser('gain_invalide');
  if (!entier(malus) || malus < 1 || malus > gain)
    refuser('malus_champignons_invalide');
  return Math.min(pa + gain, Math.max(7, pa + gain - malus));
}

function agir(etat, action, jour) {
  verifierEtat(etat);
  verifierPA(etat.pa);
  verifierJour(jour);
  if (!['abri', 'dormir', 'progresser'].includes(action)) refuser('ordre_inconnu');
  const precedent = etat.jours.find(x => x.jour === jour);
  const e = precedent ? { ...precedent } : { jour, abri: false, sommeil: false, progression: false };
  const paAvant = etat.pa;
  let pa = paAvant;
  let progressions = etat.progressions;
  let boisGagne = 0;

  if (action === 'abri') {
    if (e.abri || e.sommeil) refuser('abri_deja_fait');
    if (pa - 1 < 1) refuser('pa_insuffisants');
    pa -= 1;
    e.abri = true;
  } else if (action === 'dormir') {
    if (e.sommeil) refuser('sommeil_deja_fait');
    const gain = e.abri ? 6 : 3;
    pa = etat.champignonsRefuses ? sommeilAvecChampignons(pa, gain, 2) : pa + gain;
    e.sommeil = true;
    if (etat.champignonsRefuses) etat = {...etat,champignonsRefuses:false};
  } else {
    if (e.progression) refuser('progression_deja_faite');
    if (pa - 5 < 1) refuser('pa_insuffisants');
    pa -= 5;
    e.progression = true;
    progressions += 1;
    const total = ITINERAIRES[etat.destination].progressions;
    if (progressions === total - 1) boisGagne = 5;
    if (progressions === total) boisGagne = 3;
  }

  const jours = etat.jours.filter(x => x.jour !== jour).concat(e);
  const arrive = progressions === ITINERAIRES[etat.destination].progressions;
  return {
    ...etat, jours, progressions,
    pa: arrive ? 1 : pa, termine: arrive,
    prochaineEtape: Math.max(0, ITINERAIRES[etat.destination].progressions - progressions),
    boisGagne, // le RPC doit déposer le bois atomiquement, une seule fois
    arrivee: arrive ? ITINERAIRES[etat.destination].ville : null,
    reposForceJours: arrive ? 3 : 0,
  };
}

module.exports = { ITINERAIRES, RefusGoulag, demarrer, agir, choisirChampignons, sommeilAvecChampignons };
