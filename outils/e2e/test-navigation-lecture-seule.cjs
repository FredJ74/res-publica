'use strict';
// Fixture structurelle : aucune authentification ni requete serveur.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const acorn=require('acorn');

test('la consultation authentifiee se termine avant les ordres de deplacement',()=>{
 const source=fs.readFileSync(path.join(__dirname,'luthecia.cjs'),'utf8');
 const ast=acorn.parse(source,{ecmaVersion:'latest'});
 assert.ok(ast.body.length>0);
 const debut=source.indexOf("if(conf.mode==='consultation_seule'){\n   await etape('consultation-position-existante'");
 const suivant=source.indexOf("await etape('office-notarial-entree'");
 assert.ok(debut>=0&&suivant>debut);
 const section=source.slice(debut,suivant);
 assert.match(section,/return rapport;/);
 assert.doesNotMatch(section,/\.aller\(|\.sortir\(|\.piece\(|rue_position_enregistrer/);
});
