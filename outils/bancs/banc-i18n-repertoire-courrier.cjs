'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const locales=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function fn(s,name){let a=s.indexOf('function '+name+'(');assert.ok(a>=0);if(s.slice(a-6,a)==='async ')a-=6;return s.slice(a,s.indexOf('\n}',a)+2);}
const fr={title:'Répertoire des Joueurs',empty:"Aucun joueur enregistre pour l'instant.",count:'{{values.n}} joueur(s)',home:' · Domicile : {{values.city}}',privacy:"Les mails entre joueurs peuvent être interceptés en jeu par les services d'écoute de Sovarka.",missing:"Votre personnage n'est pas chargé : rechargez la page avant d'envoyer un message.",required:'Remplissez tous les champs.',sent:'À {{values.to}} — "{{values.subject}}"'};
test('huit sources françaises exactes, neuf langues, noms et variables conservés',()=>{
 const c={};c.window=c;vm.createContext(c);for(const f of ['i18n/resources.js','i18n/player-directory-resources.js'])vm.runInContext(read(f),c);
 assert.equal(JSON.stringify(c.RP_I18N_RESOURCES.fr.translation.playerDirectory),JSON.stringify(fr));
 for(const l of locales){const r=c.RP_I18N_RESOURCES[l].translation.playerDirectory;assert.deepEqual(Object.keys(r).sort(),Object.keys(fr).sort());
  for(const k of Object.keys(fr)){assert.ok(r[k].trim());assert.equal((r[k].match(/\{\{[^}]+\}\}/g)||[]).join(),(fr[k].match(/\{\{[^}]+\}\}/g)||[]).join());if(l!=='fr')assert.notEqual(r[k],fr[k]);}
  assert.ok(r.privacy.includes('Sovarka'));
 }
});
test('envoi, réception, destinataires, tracts et notifications métier intacts',()=>{
 const before=execFileSync('git',['show','1163bad:plateau-communication.js'],{cwd:root,encoding:'utf8',maxBuffer:4e6}),after=read('plateau-communication.js');
 const clean=source=>source.replace(/^.*window\.RPPlayerDirectoryI18n\?\.toast.*\n/gm,'');
 for(const name of ['verifierNouveauxMails','composerMailPour','fermerComposeMail','envoyerComposeMail','imprimerTractsServeur'])assert.equal(fn(clean(after),name),fn(before,name));
 assert.equal(clean(after.slice(after.indexOf('function composerMailPour('))),before.slice(before.indexOf('function composerMailPour(')));
 assert.match(read('plateau.html'),/data-i18n="playerDirectory.privacy"/);
 assert.match(read('plateau.html'),/player-directory-resources\.js/);
});
