// Expérience : main intact, seul le contrôleur de texte déjà livré est chargé dans les bancs historiques.
const h=require(process.cwd()+'/outils/bancs/mobile-navigateur.cjs'),page=h.page;
h.page=async(...args)=>{const p=await page(...args);await p.addScriptTag({url:args[1]+'/plateau-texte-minimum.js'});return p;};
