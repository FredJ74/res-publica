// Régression forums, exécution : node outils/bancs/banc-forums-territoires-adhesions-20261103.cjs
// Aucune requête réelle, aucun état PJ modifié.
'use strict';
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const racine = path.resolve(__dirname, '../..');
const lire = nom => fs.readFileSync(path.join(racine, nom), 'utf8');
let compte = 0;
function verifier(nom, resultat) {
  assert.ok(resultat, nom);
  console.log('OK', ++compte, nom);
}
async function main() {
  const state = {country:'republic',currentCity:'capitale',char:{name:'PJ'},
    organisations:[
      {id:'jaaj',nom:'Organisation Jaaj',chef:'Jaaj',membres:[{nom:'Jaaj'}]},
      {id:'amis',nom:'Club',chef:'Autre',membres:[{nom:'PJ'}]},
      {id:'dirige',nom:'Groupe',chef:'PJ',membres:[]}
    ]};
  const contexte = vm.createContext({
    state, WORLD:{republic:{capitale:{name:'Luthécia'},ville_a:{name:'Port-Sainte-Marie'}},
      narco:{ville_a:{name:'Puerto Negro'}}},
    document:{getElementById:()=>null}, console,
    setTimeout,clearTimeout,Date,localStorage:{getItem:()=>null,setItem:()=>{}}
  });
  vm.runInContext(lire('forum.js'), contexte);
  const obtenir = expr => vm.runInContext(expr,contexte);
  verifier('organisation étrangère absente', !obtenir('getForums()')['org_jaaj']);
  verifier('organisation adhérente visible', !!obtenir('getForums()')['org_amis']);
  verifier('chef admis', !!obtenir('getForums()')['org_dirige']);
  verifier('accès direct organisation étrangère refusé', !obtenir("canAccessForum('org_jaaj')"));
  verifier('forum local Luthécia', !!obtenir('getForums().local_capitale'));
  state.currentCity = 'ville_a';
  verifier('forum PSM uniquement sur place',
    !!obtenir('getForums().local_ville_a') && !obtenir('getForums().local_capitale'));
  state.country = 'narco';
  obtenir("FORUM_TOPICS.national = [{id:'cache-republic'}]");
  obtenir('getForums()');
  verifier('cache national purgé au changement de pays', !obtenir('FORUM_TOPICS.national'));
  state.country = 'republic';
  state.currentCity = 'capitale';
  verifier('retour à Luthécia', !!obtenir('getForums().local_capitale'));

  const sb = lire('supabase.js');
  const section1 = sb.slice(sb.indexOf('function sbForumEstTerritorial('),
    sb.indexOf('async function sbLoadForumPosts('));
  const section2 = sb.slice(sb.indexOf('async function sbActiviteForumCibles('),
    sb.indexOf('async function sbCreateTopic('));
  verifier('sections Supabase présentes', section1.length > 1000 && section2.length > 1000);
  let urlLue = '';
  const lignes = [
    {forum_id:'national',country:'republic',created_at:'2026-11-03T10:00:00Z'},
    {forum_id:'national',country:'narco',created_at:'2026-11-03T11:00:00Z'},
    {forum_id:'local_ville_a',country:'narco',created_at:'2026-11-03T12:00:00Z'},
    {forum_id:'international',country:'narco',created_at:'2026-11-03T13:00:00Z'}
  ];
  const sbContexte = vm.createContext({
    state, Date, console, setTimeout, clearTimeout, AbortController,
    SUPABASE_URL:'https://exemple.invalid',
    sbEnTetes:()=>({}),
    fetch:async url => { urlLue = url; return {ok:true,json:async()=>[]}; },
    sbGet:async(table,filtre)=> table === 'forum_posts'
      ? [{created_at:'2026-11-03T12:30:00Z',forum_topics:{forum_id:'local_ville_a',country:'narco'}}]
      : lignes
  });
  vm.runInContext(section1 + '\n' + section2, sbContexte);
  const f = expr => vm.runInContext(expr,sbContexte);
  const nombres = await f("sbCompterSujetsForums(['national','local_ville_a','international'])");
  verifier('compteur national filtré par pays', nombres.national === 1);
  verifier('compteur local étranger nul', nombres.local_ville_a === 0);
  verifier('international inchangé', nombres.international === 1);
  await f("sbLoadForumTopicsVerdict('national')");
  verifier('requête nationale filtrée dès PostgREST', urlLue.includes('country=eq.republic'));
  await f("sbLoadForumTopicsVerdict('local_ville_a')");
  verifier('requête locale filtrée dès PostgREST', urlLue.includes('country=eq.republic'));
  const activite = await f("sbActiviteForumCibles(['national','local_ville_a','international'])");
  verifier('activité locale étrangère ignorée', activite.local_ville_a === null);
  verifier('activité nationale locale conservée', !!activite.national);
  const delta = await f("sbActiviteForumDepuis(['national','local_ville_a'],null,null)");
  verifier('delta étranger ignoré', !delta.parForum.local_ville_a);
  verifier('delta national conservé', !!delta.parForum.national);
  console.log(compte + '/' + compte + ' vérifications réussies');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
