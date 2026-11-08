const vm=require('node:vm'),fs=require('node:fs'),cp=require('node:child_process'),assert=require('node:assert/strict');
const base='30887df7f53b7e56b188dde2f8e1b274f8185de4';
process.chdir(require('node:path').resolve(__dirname,'../../..'));
function load(s){const c={window:{},console};vm.createContext(c);vm.runInContext(s+';this.snapshot={WORLD,COUNTRIES};',c);return JSON.stringify(c.snapshot,(k,v)=>k==='i18nKey'?undefined:v);}
const a=load(cp.execFileSync('git',['show',base+':data.js'],{encoding:'utf8',maxBuffer:5e6})),b=load(fs.readFileSync('data.js','utf8'));assert.equal(a,b);
console.log(JSON.stringify({base,donnees_inchangees_hors_i18nKey:true,octets:a.length}));
