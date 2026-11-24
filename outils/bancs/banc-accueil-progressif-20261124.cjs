// Banc isolé : minuterie UI, premier accueil et dialogue PNJ, sans accès au serveur.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../../plateau-accueil-progressif.js'), 'utf8');

function environnement({entretien = 'a_faire'} = {}) {
  let clock = 0, timer = null;
  const values = new Map();
  const elements = new Map();
  const croix = {listeners: {}, focus() {}, addEventListener(type, cb) { this.listeners[type] = cb; }};
  function element(tag) {
    const el = {
      tag, innerHTML: '', classList: {add() {}, remove() {}},
      attributes: {}, listeners: {}, parentElement: null,
      setAttribute(k,v) {this.attributes[k]=v;},
      addEventListener(k,v) {this.listeners[k]=v;},
      querySelector(selector) {return selector === '.hg-bienvenue-croix' ? croix : null;},
      remove() {if(this.id)elements.delete(this.id);}
    };
    Object.defineProperty(el, 'id', {
      get() {return this._id;},
      set(x) {this._id=x;elements.set(x,this);}
    });
    return el;
  }
  const doc = {
    visibilityState: 'visible', activeElement: croix,
    head: {appendChild() {}},
    body: {appendChild(el) { el.parentElement = this; }},
    getElementById(id) {return elements.get(id) || null;},
    querySelector(selector) {
      if (selector.includes('#hg-bienvenue')) return elements.get('hg-bienvenue') || null;
      return null;
    },
    createElement: element
  };
  const window = {
    document: doc,
    state: {country:'soviet',currentCity:'ville_b',char:{name:'Testeur'}},
    localStorage: {getItem:k=>values.get(k)||null,setItem:(k,v)=>values.set(k,v)},
    setInterval(cb) {timer=cb;},
    addEventListener() {}
  };
  const DateFaux = class {static now() {return clock;}};
  vm.runInNewContext(source, {window, document:doc,Date:DateFaux, console, setTimeout() {}});
  const ui = window.RPAccueilProgressif;
  const accueilEtat = {ok:true, personnage:'Testeur',interview:{etat:entretien,ouvrir_auto:entretien==='a_faire'}};
  function avance(ms) {
    while(ms>0) {const step=Math.min(5000,ms);clock+=step;timer();ms-=step;}
  }
  return {ui,doc,croix,window,values,accueilEtat,avance};
}

test('Nouveau : bienvenue et croix uniquement, entretien après 5 minutes visibles',()=>{
  const e=environnement();
  e.ui.initialiser(e.accueilEtat);
  assert.ok(e.doc.getElementById('hg-bienvenue'));
  assert.match(e.doc.getElementById('hg-bienvenue').innerHTML,/Krasnov/);
  assert.equal(e.ui.entretienAutomatiqueAutorise(),false);
  e.avance(5*60*1000);
  assert.equal(e.ui.entretienAutomatiqueAutorise(),false,'la bienvenue non fermée bloque');
  const key={key:'Escape',prevented:false,preventDefault(){this.prevented=true;}};
  e.doc.getElementById('hg-bienvenue').listeners.keydown(key);
  assert.equal(key.prevented,true);
  assert.ok(e.doc.getElementById('hg-bienvenue'),'Échap ne ferme pas la bienvenue');
  e.croix.listeners.click();
  assert.equal(e.doc.getElementById('hg-bienvenue'),null);
  assert.equal(e.ui.entretienAutomatiqueAutorise(),true);
});
test('Une conversation PNJ empêche la relance automatique, mais pas le parcours volontaire',()=>{
  const e=environnement();
  e.ui.initialiser(e.accueilEtat);
  e.croix.listeners.click();
  e.ui.noterDiscussionPnj();
  e.avance(6*60*1000);
  assert.equal(e.ui.entretienAutomatiqueAutorise(),false);
  assert.equal(e.ui.etat().parle,true);
});
test('Journal reporté à une heure active et affiché une seule fois',()=>{
  const e=environnement();
  e.ui.initialiser(e.accueilEtat);
  e.croix.listeners.click();
  let appels=0;
  e.ui.programmerJournal(()=>appels++);
  e.avance(59*60*1000);
  assert.equal(appels,0);
  e.avance(60*1000);
  assert.equal(appels,1);
  e.ui.verifier();
  assert.equal(appels,1);
});
test('Ancien personnage : aucun accueil, Journal immédiat',()=>{
  const e=environnement({entretien:'faite'});
  e.ui.initialiser(e.accueilEtat);
  assert.equal(e.doc.getElementById('hg-bienvenue'),null);
  assert.equal(e.ui.entretienAutomatiqueAutorise(),true);
  let appels=0;
  e.ui.programmerJournal(()=>appels++);
  assert.equal(appels,1);
});
test('Le code de production raccorde les trois portes sans changer le journal manuel',()=>{
  const plateau = fs.readFileSync(path.join(__dirname,'../../plateau.html'),'utf8');
  const core = fs.readFileSync(path.join(__dirname,'../../plateau-core.js'),'utf8');
  const accueil = fs.readFileSync(path.join(__dirname,'../../plateau-accueil-interview.js'),'utf8');
  const pnj = fs.readFileSync(path.join(__dirname,'../../plateau-pnj.js'),'utf8');
  assert.ok(plateau.indexOf('plateau-accueil-progressif.js') < plateau.indexOf('plateau-accueil-interview.js'));
  assert.match(core,/RPAccueilProgressif\.programmerJournal\(/);
  assert.doesNotMatch(core,/afficherJournalDuJour\(\), 8000/);
  assert.match(accueil,/entretienAutomatiqueAutorise\(\)/);
  assert.match(pnj,/RPAccueilProgressif\?\.noterDiscussionPnj\(\)/);
});

test('Quête de Luthécia : le garde attend la fermeture et cinq minutes actives', () => {
  const e = environnement();
  e.ui.initialiser(e.accueilEtat);
  let garde = 0;
  e.window.queteAccueilAfficherGardeDifferee = () => garde++;
  e.avance(5 * 60 * 1000);
  assert.equal(garde, 0, 'bienvenue encore ouverte');
  e.croix.listeners.click();
  assert.ok(garde >= 1, 'garde autorisé après la bienvenue et cinq minutes');
  const quete = fs.readFileSync(path.join(__dirname,'../../plateau-quete-accueil.js'),'utf8');
  assert.match(quete,/gardeAttenteDecouverte: reporter/);
  assert.match(quete,/function queteAccueilAfficherGardeDifferee\(\)/);
});
