'use strict';
// Chromium local, aucune connexion Supabase : le serveur est un http.server statique.
// Les appels réseau externes sont bloqués avant l'initialisation du jeu.
const assert=require('node:assert/strict');
const {chromium}=require('playwright');

const ORIGIN=process.env.I18N_STATIC_ORIGIN||'http://127.0.0.1:8765';
const LANGS=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
async function run(){
 const browser=await chromium.launch({headless:true});
 let checks=0;
 try{
  for(const language of LANGS){
   const mobile=language==='ar'||language==='ko'||language==='zh-TW';
   const page=await browser.newPage({viewport:mobile?{width:375,height:667}:{width:1440,height:900}});
   await page.route('**/*',route=>{
    const requestUrl=route.request().url();
    if(requestUrl.startsWith(ORIGIN+'/'))return route.continue();
    return route.abort(); // polices externes, Supabase, IA, analytics : bloqués
   });
   await page.goto(ORIGIN+'/index.html',{waitUntil:'domcontentloaded'});
   await page.waitForFunction(()=>window.i18next?.isInitialized===true && !!document.querySelector('#lang-btn-fr'));
   assert.equal(await page.locator('#lang-switcher button').count(),9,language+': neuf langues visibles');
   // La langue est changée par le vrai bouton UI, pas seulement en mémoire.
   await page.locator('#lang-btn-'+language).click();
   await page.waitForFunction(lang=>window.i18next.language===lang,language);
   const state=await page.evaluate(()=>{
    const node=document.querySelector('[data-i18n="home.createCharacter"]');
    const message=node?.textContent?.trim();
    const expected=window.RP_I18N_RESOURCES?.[window.i18next.language]?.translation?.home?.createCharacter;
    return {language:window.i18next.language,htmlLang:document.documentElement.lang,
     message,expected,dir:node?.getAttribute('dir'),
     saved:localStorage.getItem('respublica_language'),
     title:document.title};
   });
   assert.equal(state.htmlLang,language);
   assert.equal(state.saved,language);
   assert.equal(state.message,state.expected,language+': traduction visible');
   assert.ok(state.title.includes('Human Gambit'),language+': marque inchangée');
   assert.equal(state.dir,language==='ar'?'rtl':null,language+': RTL local seulement');
   checks++;
   // Retour navigateur réel : le choix doit survivre à un reload sans compte.
   await page.reload({waitUntil:'domcontentloaded'});
   await page.waitForFunction(lang=>window.i18next?.language===lang,language);
   assert.equal(await page.locator('[data-i18n="home.createCharacter"]').first().textContent(),state.expected);
   checks++;
   await page.close();
  }
  // Plateau hors session : seules les ressources i18n sont autorisées.
  // Cela teste le HTML réel sans ouvrir de compte ni exécuter les moteurs métier.
  for(const language of LANGS){
   const page=await browser.newPage({viewport:{width:393,height:852}});
   await page.addInitScript(lang=>localStorage.setItem('respublica_language',lang),language);
   await page.route('**/*',route=>{
    const url=new URL(route.request().url());
    if(url.origin!==ORIGIN)return route.abort();
    if(url.pathname.endsWith('.js') && !url.pathname.startsWith('/i18n/'))return route.abort();
    return route.continue();
   });
   await page.goto(ORIGIN+'/plateau.html',{waitUntil:'domcontentloaded'});
   await page.waitForFunction(lang=>window.i18next?.isInitialized===true &&
     document.documentElement.lang===lang,language);
   const state=await page.evaluate(()=>{
    const language=window.i18next.language;
    const node=document.querySelector('[data-i18n="plateau.rulesIntro"]');
    const expected=window.RP_I18N_RESOURCES?.[language]?.translation?.plateau?.rulesIntro;
    const mail=document.querySelector('#compose-mail-subject');
    return {language,label:node?.textContent?.trim(),expected,dir:node?.getAttribute('dir'),
      placeholder:mail?.getAttribute('placeholder'),
      expectedPlaceholder:window.RP_I18N_RESOURCES?.[language]?.translation?.plateau?.subjectPlaceholder};
   });
   assert.equal(state.label,state.expected,language+': guide sur le plateau réel');
   assert.equal(state.placeholder,state.expectedPlaceholder,language+': composition de mail');
   assert.equal(state.dir,language==='ar'?'rtl':null,language+': direction limitée au texte');
   checks++;
   await page.close();
  }

  console.log('I18N CHROMIUM : '+checks+' vérifications accueil/rechargement/plateau, neuf langues, mobile/bureau, sans réseau externe');
 }finally {await browser.close();}
}
run().catch(error=>{console.error(error);process.exitCode=1});
