/* Internationalisation statique du plateau : moteur i18next existant, pas de moteur concurrent.
 * Pilote du bandeau principal, sans modifier les ordres et messages serveur.
 */
(function (global) {
  'use strict';
  const engine=global.i18next, config=global.RP_I18N_RESOURCES;
  if(!engine || !config) return;
  // Les ressources des neuf langues restent disponibles pour les bancs, mais
  // le plateau public est exclusivement français sans autorisation explicite.
  const supported=global.RP_I18N_GAME_ENABLED === true
    ? Object.keys(global.RP_I18N_LANGUAGES||{fr:{}}) : ['fr'];
  // Point d'entrée commun avec le pont du plateau : préférence persistée,
  // sinon langue du navigateur, sinon français. L'accueil emploie cette priorité.
  let locale='fr';
  if(typeof global.RPPlateauI18n?.language==='function') {
    const detected=global.RPPlateauI18n.language();
    if(supported.includes(detected))locale=detected;
  } else {
    try {
      const saved=global.localStorage?.getItem('respublica_language');
      if(supported.includes(saved))locale=saved;
    } catch (_) { /* navigateur sans localStorage */ }
  }
  // Conserver la valeur affichée avant la première traduction, PAR clé et attribut.
  // Sans cela, changer vers une langue où une clé manque conserve la traduction
  // de la langue précédente au lieu du texte français réellement présent.
  // WeakMap évite de retenir les fenêtres/modales détruites après leur fermeture.
  const originals=new WeakMap();
  function originalFor(element,key,attribute) {
    let entries=originals.get(element);
    if(!entries){entries=new Map();originals.set(element,entries);}
    const token=attribute+'|'+key;
    if(!entries.has(token)) entries.set(token,attribute==='textContent'
      ? {value:element.textContent,exists:true}
      : {value:element.getAttribute(attribute),exists:element.hasAttribute(attribute)});
    return entries.get(token);
  }
  function restore(element,attribute,saved) {
    if(attribute==='textContent'){element.textContent=saved.value;return;}
    if(saved.exists)element.setAttribute(attribute,saved.value);
    else element.removeAttribute?.(attribute);
  }
  // Point d'entrée générique pour les futures interfaces créées par JavaScript.
  // Le rendu initial s'en sert aussi : les écrans n'instancient pas un 2e moteur.
  function apply(root) {
    const elementRoot=root||global.document;
    const nodes=Array.from(elementRoot.querySelectorAll?.('[data-i18n]')||[]);
    if(elementRoot.getAttribute?.('data-i18n')) nodes.unshift(elementRoot);
    for(const element of nodes) {
      const key=element.getAttribute('data-i18n');
      // Une clé encore absente du catalogue ne doit jamais devenir un libellé
      // technique affiché au joueur : conserver le français existant.
      if(!key) continue;
      const saved=originalFor(element,key,'textContent');
      const translated=engine.t(key,{defaultValue:null});
      if(typeof translated!=='string' || !translated.trim() || translated===key) {
        restore(element,'textContent',saved);
        element.removeAttribute?.('dir');
        continue;
      }
      element.textContent=element.hasAttribute('data-i18n-uppercase')
        ? translated.toLocaleUpperCase(locale) : translated;
      if(locale==='ar') element.setAttribute('dir','rtl');
      else element.removeAttribute?.('dir');
    }
    // Les placeholders sont localisés sans jamais réécrire la valeur saisie.
    const placeholderNodes=Array.from(elementRoot.querySelectorAll?.('[data-i18n-placeholder]')||[]);
    if(elementRoot.getAttribute?.('data-i18n-placeholder')) placeholderNodes.unshift(elementRoot);
    for(const element of placeholderNodes) {
      const key=element.getAttribute('data-i18n-placeholder');
      if(!key)continue;
      const saved=originalFor(element,key,'placeholder');
      const translated=engine.t(key,{defaultValue:null});
      if(typeof translated==='string' && translated.trim() && translated!==key)
        element.setAttribute('placeholder',translated);
      else restore(element,'placeholder',saved);
    }
    // Accessibilité : traduire l'intitulé vocal des contrôles tactiles sans
    // injecter de texte dans les boutons ni changer leur surface de clic.
    const ariaNodes=Array.from(elementRoot.querySelectorAll?.('[data-i18n-aria-label]')||[]);
    if(elementRoot.getAttribute?.('data-i18n-aria-label')) ariaNodes.unshift(elementRoot);
    for(const element of ariaNodes) {
      const key=element.getAttribute('data-i18n-aria-label');
      if(!key)continue;
      const saved=originalFor(element,key,'aria-label');
      const translated=engine.t(key,{defaultValue:null});
      if(typeof translated==='string' && translated.trim() && translated!==key)
        element.setAttribute('aria-label',translated);
      else restore(element,'aria-label',saved);
    }
    // Les info-bulles de la barre supérieure doivent être traduites sans
    // remplacer le contenu des boutons (icônes, badges, compteurs).
    const titleNodes=Array.from(elementRoot.querySelectorAll?.('[data-i18n-title]')||[]);
    if(elementRoot.getAttribute?.('data-i18n-title')) titleNodes.unshift(elementRoot);
    for(const element of titleNodes) {
      const key=element.getAttribute('data-i18n-title');
      if(!key) continue;
      const saved=originalFor(element,key,'title');
      const translated=engine.t(key,{defaultValue:null});
      if(typeof translated==='string' && translated.trim() && translated!==key)
        element.setAttribute('title',translated);
      else restore(element,'title',saved);
    }
  }
  global.RPI18nPlateau=Object.freeze({apply,locale:()=>locale});
  // Un changement de langue dans l'interface, y compris depuis un autre onglet,
  // doit mettre à jour le texte statique et les menus dynamiques ensemble.
  if(typeof engine.on==='function')engine.on('languageChanged',function(next) {
    if(!supported.includes(next)) {
      // Même un changement programmatique ne peut contourner l'ouverture fermée.
      if(typeof engine.changeLanguage==='function' && engine.language!=='fr')engine.changeLanguage('fr');
      return;
    }
    locale=next;
    global.document.documentElement.lang=locale;
    apply(global.document);
  });
  if(typeof global.addEventListener==='function')global.addEventListener('storage',function(event) {
    if(event.key!=='respublica_language' || !supported.includes(event.newValue))return;
    if(engine.language!==event.newValue && typeof engine.changeLanguage==='function')
      engine.changeLanguage(event.newValue);
  });
  engine.init({
    lng:locale,
    fallbackLng:'fr',
    supportedLngs:supported,
    resources:config,
    interpolation:{escapeValue:false}
  }, function(error) {
    if(error) { console.error('i18n plateau : initialisation impossible',error); return; }
    global.document.documentElement.lang=locale;
    apply(global.document);
  });
})(window);
