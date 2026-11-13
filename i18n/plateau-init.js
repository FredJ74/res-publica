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
      // Respecter un sens de lecture fixé par le contenu initial (ex. LTR).
      // Un aller-retour en arabe ne doit jamais effacer cet attribut métier.
      const savedDir=originalFor(element,key,'dir');
      // Variables de présentation isolées sous {{values.*}} : elles ne peuvent
      // remplacer lng, defaultValue ou une option du moteur.
      let values;
      const rawValues=element.getAttribute('data-i18n-values');
      if(rawValues!=null){
        try{
          const parsed=JSON.parse(rawValues);
          if(!parsed||typeof parsed!=='object'||Array.isArray(parsed))throw new Error('format');
          values=Object.create(null);
          for(const [name,value]of Object.entries(parsed)){
            if(!/^[A-Za-z][A-Za-z0-9_]*$/.test(name)||['constructor','prototype'].includes(name)||
               !(typeof value==='string'||typeof value==='number'&&Number.isFinite(value)))throw new Error('variable');
            values[name]=value;
          }
        }catch(_){restore(element,'textContent',saved);restore(element,'dir',savedDir);continue;}
      }
      const translated=engine.t(key,{defaultValue:null,values});
      if(typeof translated!=='string' || !translated.trim() || translated===key || /\{\{[^}]+\}\}/.test(translated)) {
        restore(element,'textContent',saved);
        restore(element,'dir',savedDir);
        continue;
      }
      element.textContent=element.hasAttribute('data-i18n-uppercase')
        ? translated.toLocaleUpperCase(locale) : translated;
      if(locale==='ar') element.setAttribute('dir','rtl');
      else restore(element,'dir',savedDir);
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
    // Préfixe textuel suivi d’un compteur stylé : ne pas supprimer son <b>.
    const prefixNodes=Array.from(elementRoot.querySelectorAll?.('[data-i18n-prefix]')||[]);
    if(elementRoot.getAttribute?.('data-i18n-prefix'))prefixNodes.unshift(elementRoot);
    for(const element of prefixNodes){
      const key=element.getAttribute('data-i18n-prefix'),node=element.firstChild;
      if(!key||node?.nodeType!==3)continue;
      const saved=originalFor(node,key,'textContent'),savedDir=originalFor(element,key,'dir');
      const translated=engine.t(key,{defaultValue:null});
      node.textContent=typeof translated==='string'&&translated.trim()&&translated!==key
        ? translated+(saved.value.match(/\s*$/)?.[0]||'') : saved.value;
      if(locale==='ar')element.setAttribute('dir','rtl');else restore(element,'dir',savedDir);
    }
    // Les légendes mobiles des tableaux du terminal utilisent data-l en CSS.
    const labelNodes=Array.from(elementRoot.querySelectorAll?.('[data-i18n-label]')||[]);
    if(elementRoot.getAttribute?.('data-i18n-label')) labelNodes.unshift(elementRoot);
    for(const element of labelNodes) {
      const key=element.getAttribute('data-i18n-label');if(!key)continue;
      const saved=originalFor(element,key,'data-l');
      const translated=engine.t(key,{defaultValue:null});
      if(typeof translated==='string' && translated.trim() && translated!==key)element.setAttribute('data-l',translated);
      else restore(element,'data-l',saved);
    }

  }
  // Marquage facultatif d'une notification locale déjà rendue, jamais d'une action métier.
  // Le prochain showToast écrit textContent et supprime ce span, sans ancien marqueur persistant.
  function markToast(key,fr,values,titleFr) {
    const node=global.document?.getElementById('toast-sub');
    if(!node||typeof key!=='string'||node.textContent!==fr)return false;
    const span=global.document.createElement('span');span.textContent=fr;span.setAttribute('data-i18n',key);
    try{if(values)span.setAttribute('data-i18n-values',JSON.stringify(values));}catch(_){return false;}
    node.replaceChildren(span);apply(node);
    const titleKey=global.RPToastI18n?.key?.(titleFr),title=global.document.getElementById('toast-result');
    if(titleKey&&title&&title.textContent===global.RPToastI18n.label(titleFr)){
      const heading=global.document.createElement('span');heading.textContent=titleFr;heading.setAttribute('data-i18n',titleKey);
      title.replaceChildren(heading);apply(title);
    }
    return true;
  }
  global.RPI18nPlateau=Object.freeze({apply,markToast,locale:()=>locale});
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
    // Mettre a jour le texte des ordres deja visibles (y compris dans les
    // sous-menus ouverts), sans rerender ni effet serveur.
    global.RPOrderI18n?.refreshVisibleLabels?.(global.document,engine,locale);
    global.RPRefreshOpenRoomNames?.();
    global.RPRefreshForumOpenLabels?.();
    // Certains modules du plateau sont chargés avant i18next. Ils enregistrent
    // une fonction passive plutôt que d'essayer de s'abonner trop tôt au moteur.
    // N'effectuer aucune action métier, chaque module ne repeint que son écran.
    const callbacks=global.RP_I18N_CHANGE_CALLBACKS;
    if(Array.isArray(callbacks))for(const callback of callbacks){
      if(typeof callback!=='function')continue;
      try{callback(next);}catch(err){console.error('i18n : rafraîchissement partiel indisponible',err);}
    }
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
