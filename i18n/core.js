/* Human Gambit — socle de traduction autonome, non activé par défaut.
 * Aucune lecture/écriture des comptes, du serveur ou des données joueurs.
 * Inclure explicitement ce fichier et ses catalogues pour activer le socle.
 */
(function (root) {
  'use strict';
  var catalogs = Object.create(null);
  var locale = 'fr';
  var fallback = 'fr';
  function validTag(tag) { return typeof tag === 'string' && /^[a-z]{2}(?:-[A-Z]{2})?$/.test(tag); }
  function own(obj, key) { return Object.prototype.hasOwnProperty.call(obj, key); }
  function register(tag, messages) {
    if (!validTag(tag) || !messages || typeof messages !== 'object' || Array.isArray(messages)) throw new TypeError('Catalogue invalide');
    var copy = Object.create(null);
    Object.keys(messages).forEach(function (key) {
      if (!/^[a-z][a-z0-9_.-]*$/.test(key) || typeof messages[key] !== 'string') throw new TypeError('Entrée de traduction invalide : ' + key);
      copy[key] = messages[key];
    });
    catalogs[tag] = Object.freeze(copy);
  }
  function setLocale(tag) {
    if (!validTag(tag) || !own(catalogs, tag)) return false;
    locale = tag;
    return true;
  }
  function translate(key, params) {
    if (typeof key !== 'string') throw new TypeError('Clé invalide');
    var current = catalogs[locale], base = catalogs[fallback];
    var value = current && own(current, key) ? current[key] : base && own(base, key) ? base[key] : key;
    return value.replace(/\{([a-z][a-z0-9_]*)\}/g, function (token, name) {
      return params && own(params, name) ? String(params[name]) : token;
    });
  }
  function number(value, options) { return new Intl.NumberFormat(locale, options).format(value); }
  function date(value, options) { return new Intl.DateTimeFormat(locale, options).format(value); }
  root.HGI18n = Object.freeze({
    register: register, setLocale: setLocale, t: translate, number: number, date: date,
    getLocale: function () { return locale; },
    supported: function () { return Object.keys(catalogs); }
  });
})(typeof globalThis !== 'undefined' ? globalThis : this);
