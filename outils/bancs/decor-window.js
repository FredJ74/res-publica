// DECOR DE BANC -- pose un objet `window` AVANT le chargement des modules du navigateur.
//
// POURQUOI UN FICHIER SEPARE, sur le modele de decor-env-serveur.js. lancer-banc.py concatene le
// preambule, puis les sources, puis le banc. Or plusieurs modules du plateau touchent `window` AU
// CHARGEMENT -- plateau-assemblee.js, par exemple :
//     window._assembleeCategories = window._assembleeCategories || { parId: null, ts: 0 };
// Un banc qui poserait `window` depuis son propre corps arriverait trop tard : le module a deja
// leve une TypeError sur un objet inexistant, et le banc ne demarre pas du tout.
//
// Ce decor doit donc etre la PREMIERE source de la ligne SOURCES: du banc.
//
// `globalThis` ET NON UN OBJET VIDE, et c'est deliberе : les modules du plateau ecrivent sur
// `window` des registres que d'autres relisent ensuite par leur nom global (RP_ORDRES_DYNAMIQUES
// en est l'exemple). Un `window` separe du global ferait divergier les deux vues, et un banc
// verrait un registre vide la ou le navigateur en voit un rempli.
//
// NE PAS CONFONDRE AVEC UNE SOURCE DU JEU : ce fichier ne part jamais en production, il n'existe
// que pour les bancs.
if (typeof window === 'undefined') { globalThis.window = globalThis; }
if (typeof document === 'undefined') {
  // Le strict minimum pour qu'un module qui PREPARE un style au chargement ne tombe pas. Aucun
  // banc ne doit se servir de ce faux document pour affirmer quoi que ce soit sur l'affichage :
  // les bancs d'ecran lisent la SOURCE, ils ne la font pas tourner.
  globalThis.document = {
    getElementById: function () { return null; },
    createElement: function () { return { style: {}, classList: { add: function () {}, remove: function () {} },
                                          appendChild: function () {}, addEventListener: function () {} }; },
    head: { appendChild: function () {} },
    body: { appendChild: function () {} }
  };
}
