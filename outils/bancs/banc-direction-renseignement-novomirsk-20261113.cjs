const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const read = x => fs.readFileSync(x,'utf8');
const data=read('data.js');
const pnj=read('api/_pnj-personnalites.js');
const politique=read('plateau-politique.js');
const arch=read('migrations/20261113220500_novomirsk_archives_renseignement.sql');
const ministeres=read('migrations/20261113222000_sovarka_renseignement_ministeres.sql');

test('scripts joueurs sans erreur de syntaxe',()=>{
 new vm.Script(data,{filename:'data.js'});
 new vm.Script(politique,{filename:'plateau-politique.js'});
 assert.ok(pnj.includes("export { profilsPersonnalites"));
});
test('Novomirsk uniquement : accueil à deux PNJ distincts avec fiches DeepSeek',()=>{
 const i=data.indexOf("'siege-renseignement': {",data.indexOf("buildingContext:"));
 const j=data.indexOf("// Caserne centrale",i);
 assert.ok(i>=0 && j>i);
 const ctx=data.slice(i,j);
 assert.match(ctx,/Sergent Viktor Muetov \(PNJ\)/);
 assert.match(ctx,/Elena Diamentevia \(PNJ\)/);
 assert.match(pnj,/'sergent_viktor_muetov': \{/);
 assert.match(pnj,/'elena_diamentevia': \{/);
 assert.match(pnj,/Nous connaissons vos secrets/);
 assert.match(pnj,/Je ne suis pas habilitée à répondre/);
 assert.match(pnj,/Je ne suis pas habilité à répondre/);
 const entries=pnj.match(/'sergent_viktor_muetov': \{/g)||[];
 assert.equal(entries.length,1,'Pas de profil de Viktor concurrent');
});
test('Salle des écoutes : pas de renseignement militaire, archives issues de la mécanique existante',()=>{
 const i=data.indexOf("'siege-renseignement': {",data.indexOf("buildingContext:"));
 const j=data.indexOf("// Caserne centrale",i);
 const ctx=data.slice(i,j);
 assert.match(ctx,/excludeOrders:\s*\['renseignement_militaire'\]/);
 assert.match(ctx,/fn:\s*'voler_archives_ecoute'/);
 assert.match(ctx,/pa:\s*2,\s*cost:\s*0/);
 assert.match(ctx,/successRate:\s*45/);
 assert.ok(data.includes("Dérober un rapport d’écoute au hasard parmi ceux des 30 derniers jours."));
 assert.match(arch,/p.current_room IS DISTINCT FROM ''salle_ecoutes''/);
 assert.match(arch,/novomirsk/);
 assert.match(arch,/starovka/);
 assert.match(arch,/krasnov/);
});
test('Ministres : interface et contrôle serveur indépendants des autres empires',()=>{
 assert.match(data,/fn:\s*'renseignement_militaire'.*requiresPost:\s*'min_int'/);
 assert.match(politique,/function peutDirigerRenseignement\(\)/);
 assert.match(politique,/state.country === 'soviet' && state.poste\?\.id === 'min_int'/);
 assert.match(ministeres,/v_pays = ''soviet'' AND v_poste = ''min_int''/);
 assert.match(ministeres,/v_caisse := v_pays \|\| ''_gouvernement-'' \|\| v_poste/);
 assert.match(ministeres,/v_ici_piece='bureau_min_int'/);
 assert.match(ministeres,/v_ici_piece='bureau_min_def'/);
 assert.match(ministeres,/renseignement_agents_disponibles\(\)/);
 assert.match(ministeres,/cellule_rapports_mes_cellules\(integer\)/);
});
