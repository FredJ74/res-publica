// Bancs navigateur communs : HTML réel, trafic extérieur refusé, ressources fermées même en échec.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http'),zlib=require('node:zlib'),crypto=require('node:crypto');
const {chromium}=require('../e2e/node_modules/playwright');
const R=path.resolve(__dirname,'../..');
const reference=fs.readFileSync(path.join(__dirname,'fixtures/mobile-temoin-728010c8.json.gz'));
assert.equal(crypto.createHash('sha256').update(reference).digest('hex'),'7d79fac32ee8d3059505c494b18ccc958199698478b9702fc7d7017717f52d3c');
const temoin=JSON.parse(zlib.gunzipSync(reference));
assert.equal(temoin.commit,'728010c844597087e7c4063f72fabbcb2a746723');
const lecture=(f,ancien)=>ancien?Buffer.from(temoin.fichiers[f]):fs.readFileSync(path.join(R,f));
function preuve(nom,b){const d=process.env.HG_MOBILE_PREUVES;if(d){fs.mkdirSync(d,{recursive:true});fs.writeFileSync(path.join(d,nom),b);}}
async function avecJeu(f){
 const serveur=http.createServer((q,r)=>{let u=new URL(q.url,'http://localhost');let nom=u.pathname.slice(1),ancien=u.searchParams.has('ancien');
 try{let b=lecture(nom,ancien);if(nom==='plateau.html')b=Buffer.from(b.toString().replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,''));r.setHeader('Content-Type',nom.endsWith('.css')?'text/css':nom.endsWith('.js')?'text/javascript':'text/html');r.end(b);}catch{r.writeHead(404);r.end();}});
 await new Promise(r=>serveur.listen(0,'127.0.0.1',r));const origine='http://127.0.0.1:'+serveur.address().port;
 let b;try{b=await chromium.launch({executablePath:process.env.HG_CHROMIUM||['/usr/bin/chromium','/usr/bin/google-chrome','/usr/bin/google-chrome-stable'].find(fs.existsSync),args:['--no-sandbox']});await f(b,origine);}finally{if(b)await b.close();serveur.closeAllConnections();await new Promise(r=>serveur.close(r));}
}
async function page(b,o,w,h,ancien=false,options={}){const c=await b.newContext({viewport:{width:w,height:h},hasTouch:w<1024,...options.contexte});await c.route('**/*',r=>r.request().url().startsWith(o+'/')?r.continue():r.abort());const p=await c.newPage();p.setDefaultTimeout(5000);await p.goto(o+'/plateau.html'+(ancien?'?ancien':''));if(ancien){await p.addStyleTag({content:lecture('style.css',true).toString()});}else await p.addScriptTag(options.mobileSource ? {content:options.mobileSource} : {url:o+'/plateau-mobile.js'});await p.waitForTimeout(500);return p;}

module.exports={R,temoin,lecture,preuve,avecJeu,page};
