'use strict';
// Politique de déploiement : jamais de preview automatique des branches de travail.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const config=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../vercel.json'),'utf8'));
const flag=config.git?.deploymentEnabled;
assert.deepEqual(flag,{'*':false,main:true},'Vercel doit construire automatiquement main uniquement');
assert.equal(config.ignoreCommand,'node vercel-ignore-build.cjs','Préserver l’exclusion des builds purement documentaires');
assert.ok(Array.isArray(config.crons)&&config.crons.some(x=>x.path==='/api/cron-minuit'),'Préserver le cron de minuit');
console.log('OK : main seul, previews désactivées, ignoreCommand et cron conservés');
