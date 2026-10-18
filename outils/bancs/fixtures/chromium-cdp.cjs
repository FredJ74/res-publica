// Cycle de vie du navigateur de banc, sans service externe ni donnees de jeu.
const fs = require('node:fs'), path = require('node:path');
const { spawn } = require('node:child_process');
const http = require('node:http');
const { performance } = require('node:perf_hooks');
const attendre = ms => new Promise(r => setTimeout(r, ms));
// CDP est local : ignorer tout proxy HTTP configure sur les runners CI.
function lireVersionLocale(port, delai) {
  return new Promise((resolve, reject) => {
    const req = http.get({hostname:'127.0.0.1',port,path:'/json/version',agent:false,timeout:delai}, res => {
      let corps='';
      res.setEncoding('utf8');
      res.on('data', bloc => { corps+=bloc; if(corps.length>65536) req.destroy(new Error('Reponse DevTools trop volumineuse')); });
      res.on('end', () => {
        if(res.statusCode!==200) return reject(new Error('DevTools HTTP '+res.statusCode));
        try { resolve(JSON.parse(corps)); } catch(e) { reject(e); }
      });
      res.on('error',reject);
    });
    req.on('timeout',()=>req.destroy(new Error('Delai HTTP DevTools')));
    req.on('error',reject);
  });
}
function erreur(code, message, logs) {
  return Object.assign(new Error(`${message}${logs ? '\nChromium (fin des journaux) : '+logs : ''}`), { code });
}
async function lancerChromium({ executable, profil, delaiDemarrage = 20000, spawnImpl = spawn }) {
  let logs = '', fin = null, erreurSpawn = null, ferme = false;
  const p = spawnImpl(executable, ['--headless','--no-sandbox','--disable-gpu','--disable-background-networking',
    '--remote-debugging-port=0','--user-data-dir='+profil,'about:blank'],
    { detached:true, env:{...process.env,XDG_CONFIG_HOME:profil,XDG_CACHE_HOME:profil} });
  p.stderr.on('data', b => { logs = (logs + b).slice(-8000); });
  p.stdout.resume();
  p.on('error', e => { erreurSpawn = e; });
  p.on('exit', (code, signal) => { fin = {code, signal}; });
  p.on('close', () => { ferme = true; });
  const controlerProcessus = () => {
    if (erreurSpawn) throw erreur('HG_CHROMIUM_SPAWN', 'Chromium impossible a lancer : '+erreurSpawn.message, logs);
    if (fin) throw erreur('HG_CHROMIUM_EXIT', `Chromium termine avant la fin du banc (code=${fin.code}, signal=${fin.signal})`, logs);
  };
  async function arreter() {
    function signaler(signal) {
      if (!p.pid) return;
      try { process.kill(-p.pid, signal); } catch { try { p.kill(signal); } catch {} }
    }
    // Le groupe doit etre termine meme si le processus principal est deja sorti.
    signaler('SIGTERM');
    const limite = performance.now()+1000;
    while (!ferme && performance.now()<limite) await attendre(20);
    signaler('SIGKILL');
    const finLimite = performance.now()+1000;
    while (!ferme && performance.now()<finLimite) await attendre(20);
    if (!ferme) throw erreur('HG_CHROMIUM_CLEANUP', 'Arret Chromium non confirme', logs);
  }
  const debut = performance.now(), limite = debut+delaiDemarrage;
  let derniereErreur = 'point DevTools pas encore publie';
  try {
    while (performance.now()<limite) {
      controlerProcessus();
      let port;
      try {
        // Fichier officiel de Chromium, independant du moment/format de stderr.
        const lignes = fs.readFileSync(path.join(profil,'DevToolsActivePort'),'utf8').trim().split(/\r?\n/);
        if (/^\d+$/.test(lignes[0]) && lignes[1]?.startsWith('/devtools/browser/')) port=Number(lignes[0]);
      } catch (e) { if (e.code !== 'ENOENT') derniereErreur=e.message; }
      if (!port) port=Number(logs.match(/DevTools listening on ws:\/\/127\.0\.0\.1:(\d+)\//)?.[1]);
      if (port>0 && port<=65535) {
        try {
          const version=await lireVersionLocale(port,Math.max(1, Math.min(1500, Math.ceil(limite-performance.now()))));
          if (!version.webSocketDebuggerUrl?.startsWith(`ws://127.0.0.1:${port}/devtools/browser/`)) throw Error('DevTools pas encore pret');
          controlerProcessus();
          return { port, arreter, controlerProcessus, logs:()=>logs, initialisationMs:Math.round(performance.now()-debut) };
        } catch (e) { derniereErreur=e.message; }
      }
      await attendre(Math.min(50, Math.max(0,limite-performance.now())));
    }
    controlerProcessus();
    throw erreur('HG_CHROMIUM_TIMEOUT', `Initialisation Chromium depasse ${delaiDemarrage} ms : ${derniereErreur}`, logs);
  } catch (e) {
    try { await arreter(); } catch (nettoyage) { e.message += '\n'+nettoyage.message; }
    throw e;
  }
}
module.exports={lancerChromium};
