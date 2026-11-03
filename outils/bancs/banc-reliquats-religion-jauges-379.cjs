'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
test('les anciens ordres religieux sans catalogue ne peuvent plus créditer les jauges',()=>{
 const data=fs.readFileSync('data.js','utf8');
 const router=fs.readFileSync('plateau-router.js','utf8');
 const divers=fs.readFileSync('plateau-divers.js','utf8');
 for(const ordre of ['benediction_etat','consulter_confessions']){
   assert.doesNotMatch(data,new RegExp("fn:['\\\"]"+ordre+"['\\\"]"),'ordre encore exposé');
   assert.doesNotMatch(router,new RegExp("fn === ['\\\"]"+ordre+"['\\\"]"),'ancienne route');
 }
 assert.doesNotMatch(divers,/function doBenedictionEtat\(/);
 assert.doesNotMatch(divers,/function doConsulterConfessions\(/);
});
