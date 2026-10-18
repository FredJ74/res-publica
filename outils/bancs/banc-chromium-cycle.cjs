const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawn}=require('node:child_process');
const {lancerChromium}=require('./fixtures/chromium-cdp.cjs');
function profil(t){const p=fs.mkdtempSync(path.join(os.tmpdir(),'hg-cdp-cycle-'));t.after(()=>fs.rmSync(p,{recursive:true,force:true,maxRetries:3}));return p;}
function processus(t,code){let pid;return {
 spawnImpl:(exe,args,options)=>{const p=spawn(process.execPath,['-e',code],options);pid=p.pid;return p;},
 verifierArret:()=>{assert.throws(()=>process.kill(pid,0),e=>e.code==='ESRCH');}
};}
function serveur(profil,delai=0,partiel=false){return `
const fs=require('node:fs'),http=require('node:http');
console.error('ERROR:dbus/bus.cc: Failed to connect to the bus');
const s=http.createServer((req,res)=>{res.setHeader('Content-Type','application/json');res.end(JSON.stringify({webSocketDebuggerUrl:'ws://127.0.0.1:'+s.address().port+'/devtools/browser/banc'}));});
s.listen(0,'127.0.0.1',()=>{
const fichier=${JSON.stringify(path.join(profil,'DevToolsActivePort'))};
${partiel?"fs.writeFileSync(fichier,String(s.address().port)+'\\n');":''}
setTimeout(()=>fs.writeFileSync(fichier,s.address().port+'\\n/devtools/browser/banc\\n'),${delai});
});`}
test('initialisation lente (>5 s), fichier partiel et aucun message DevTools stderr : API verifiee',async t=>{
 const p=profil(t),simulation=processus(t,serveur(p,5500,true));
 const c=await lancerChromium({executable:'simulation',profil:p,delaiDemarrage:12000,spawnImpl:simulation.spawnImpl});
 try{assert.ok(c.initialisationMs>=5500);assert.match(c.logs(),/dbus/);assert.doesNotMatch(c.logs(),/DevTools listening/);}
 finally{await c.arreter();}simulation.verifierArret();
});
test('processus qui sort avant DevTools : echec de lancement, pas echec assertion',async t=>{
 const simulation=processus(t,"console.error('diagnostic sortie');process.exit(23)");
 await assert.rejects(lancerChromium({executable:'simulation',profil:profil(t),spawnImpl:simulation.spawnImpl}),e=>e.code==='HG_CHROMIUM_EXIT'&&/code=23/.test(e.message));simulation.verifierArret();
});
test('executable absent : erreur spawn traitee sans evenement error non capture',async t=>{
 await assert.rejects(lancerChromium({executable:'/hg-chromium-inexistant',profil:profil(t)}),e=>e.code==='HG_CHROMIUM_SPAWN');
});
test('initialisation bloquee et SIGTERM ignore : delai distinct, SIGKILL et fermeture confirmes',async t=>{
 const simulation=processus(t,"process.on('SIGTERM',()=>{});console.error('dbus non bloquant ne prouve pas que DevTools est pret');setInterval(()=>{},1000)");
 await assert.rejects(lancerChromium({executable:'simulation',profil:profil(t),delaiDemarrage:500,spawnImpl:simulation.spawnImpl}),e=>e.code==='HG_CHROMIUM_TIMEOUT');simulation.verifierArret();
});
test('port publie sans API DevTools : ne pas declarer le navigateur pret',async t=>{
 const p=profil(t),simulation=processus(t,`require('node:fs').writeFileSync(${JSON.stringify(path.join(p,'DevToolsActivePort'))},'1\\n/devtools/browser/banc\\n');setInterval(()=>{},1000)`);
 await assert.rejects(lancerChromium({executable:'simulation',profil:p,delaiDemarrage:500,spawnImpl:simulation.spawnImpl}),e=>e.code==='HG_CHROMIUM_TIMEOUT');simulation.verifierArret();
});
test('Chromium reel : avertissements eventuels D-Bus et readiness controles separement',async t=>{
 const executable=process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(p=>fs.existsSync(p));assert.ok(executable,'Chromium requis');
 const c=await lancerChromium({executable,profil:profil(t),delaiDemarrage:60000});
 try{t.diagnostic(`DevTools verifie en ${c.initialisationMs} ms ; messages D-Bus presents : ${/dbus/i.test(c.logs())}`);assert.ok(c.port>0);c.controlerProcessus();}
 finally{await c.arreter();}
});
