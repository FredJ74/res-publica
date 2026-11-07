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
  console.log('I18N CHROMIUM : '+checks+' parcours accueil/rechargement, neuf langues, mobile/bureau, sans réseau externe');
 }finally {await browser.close();}
}
run().catch(error=>{console.error(error);process.exitCode=1});
