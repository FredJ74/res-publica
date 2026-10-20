/* Francs exacts. Le BigInt interne compte les centimes, jamais le stockage SQL.
 * Les montants transportes sont des chaines decimales, sans arrondi implicite. */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.HGMonnaie = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  function centimes(value) {
    if (typeof value !== 'string' || !/^-?(?:0|[1-9]\d*)(?:\.\d{1,2})?$/.test(value)) {
      throw new TypeError('montant_decimal_invalide');
    }
    const negatif = value[0] === '-';
    const [entier, fraction = ''] = (negatif ? value.slice(1) : value).split('.');
    const n = BigInt(entier) * 100n + BigInt(fraction.padEnd(2, '0'));
    return negatif ? -n : n;
  }
  function francs(n) {
    const signe = n < 0n ? '-' : '';
    if (n < 0n) n = -n;
    return signe + String(n / 100n) + '.' + String(n % 100n).padStart(2, '0');
  }
  function normaliser(v) { return francs(centimes(v)); }
  function additionner(a, b) { return francs(centimes(a) + centimes(b)); }
  function soustraire(a, b) { return francs(centimes(a) - centimes(b)); }
  function comparer(a, b) { const n = centimes(a) - centimes(b); return n < 0n ? -1 : n > 0n ? 1 : 0; }
  function multiplierEntier(a, n) {
    if (!Number.isSafeInteger(n)) throw new TypeError('quantite_entiere_requise');
    return francs(centimes(a) * BigInt(n));
  }
  // Arrondi commercial explicite au centime, symetrique, sans nombres binaires.
  function pourcentageArrondi(a, taux) {
    if (!Number.isSafeInteger(taux)) throw new TypeError('taux_entier_requis');
    const n = centimes(a) * BigInt(taux), signe = n < 0n ? -1n : 1n;
    return francs(signe * (((n < 0n ? -n : n) + 50n) / 100n));
  }
  // Seule passerelle des anciens nombres entiers : les floats ne sont jamais devines.
  function historique(v) {
    if (typeof v === 'number' && Number.isSafeInteger(v)) return normaliser(String(v));
    return normaliser(v);
  }
  function lireSaisie(v) {
    if (typeof v !== 'string') throw new TypeError('saisie_invalide');
    return normaliser(v.trim().replace(',', '.'));
  }
  return Object.freeze({ normaliser, additionner, soustraire, comparer, multiplierEntier, pourcentageArrondi, historique, lireSaisie });
});
