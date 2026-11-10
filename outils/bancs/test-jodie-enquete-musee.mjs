import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const lire = f => fs.readFileSync(new URL('../../' + f, import.meta.url), 'utf8');
const enigme = lire('plateau-enigme-portrait.js');
const sql = lire('migrations/20261109221000_jodie_enquete_sociale.sql');
const dialogue = lire('plateau-pnj.js');
const social = lire('plateau-social-pnj.js');
const api = lire('api/chat.js');
const prompt = lire('api/_pnj-profils.js');

function simuler(options = {}) {
  const elements = {};
  function creerElement() {
    const e = { innerHTML: '', textContent: '', style: {}, attributes: {},
      setAttribute(k,v) { this.attributes[k] = v; },
      classList: { add(n) { if(n==='open') modal.ouvert=true; }, remove(n) { if(n==='open') modal.ouvert=false; } }
    };
    return e;
  }
  const modal = creerElement();
  modal.ouvert = false;
  const title = creerElement(), body = creerElement();
  const postes = creerElement(), postesBody = creerElement();
  const question = { value: '', disabled: false };
  elements['modal-postes'] = postes;
  elements['postes-modal-title'] = creerElement();
  elements['postes-body'] = postesBody;
  elements['jodie-enquete-question'] = question;
  const appels = [];
  const conversations = [];
  const ctx = {
    state: { char: { name: 'Angie', enigme1: { etape: 'declenchee' } }, day: 1 },
    document: {
      body: { appendChild(el) {
        elements[el.id] = el;
        elements['jodie-enquete-body'] = body;
        elements['jodie-enquete-titre'] = title;
      }},
      createElement: creerElement,
      getElementById: id => elements[id] || null,
      querySelector: () => options.autreModale ? {} : null
    },
    sbRpcVerdict: async (rpc, params) => {
      appels.push({rpc, ...params});
      if (params.p_action === 'etat') return options.etat || {ok:true,type:'aucun'};
      return {ok:true,type:'aucun',contact:{choix:params.p_reponse, premierLe:'2026-11-09'}};
    },
    reponsePnjServeur: async (_, texte) => 'Je prends note : ' + texte,
    pnjSocialNoterConversation: (...a) => conversations.push(a),
    escapeHtmlText: x => x.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;'),
    showToast: () => {}
  };
  vm.createContext(ctx);
  vm.runInContext(enigme.slice(enigme.indexOf('let jodieEnqueteAppelEnCours =')), ctx);
  return {ctx,modal,title,body,question,appels,conversations};
}

test('appel initial J+1 illustré, destination exacte et mémoire du marché', async () => {
  const s=simuler({etat:{ok:true,type:'premier',lieu_precedent:'marche',contact:{}}});
  await s.ctx.jodieEnqueteVerifierAppel();
  assert.equal(s.modal.ouvert,true);
  assert.match(s.body.innerHTML,/images\/jodie-moitout\.webp/);
  assert.match(s.body.innerHTML,/Musée de la Ville de Luthécia/);
  assert.match(s.body.innerHTML,/passage au marché/);
  assert.match(s.body.innerHTML,/Comptez sur moi/);
  assert.match(s.body.innerHTML,/Pas maintenant/);
});

test('une rencontre à la rédaction est reconnue dans le même appel', async () => {
  const s=simuler({etat:{ok:true,type:'premier',lieu_precedent:'autruche',contact:{}}});
  await s.ctx.jodieEnqueteVerifierAppel();
  assert.match(s.body.innerHTML,/locaux de L.Autruche Entravée/);
});

test('l’appel ne vole pas une fenêtre déjà ouverte', async () => {
  const s=simuler({etat:{ok:true,type:'premier'},autreModale:true});
  await s.ctx.jodieEnqueteVerifierAppel();
  assert.equal(s.modal.ouvert,false);
});

test('refus conservé côté serveur, sans supprimer calepin ni énigme', async () => {
  const s=simuler({etat:{ok:true,type:'premier',contact:{}}});
  await s.ctx.jodieEnqueteVerifierAppel();
  await s.ctx.jodieEnqueteRepondre('refuse');
  assert.ok(s.appels.some(x=>x.p_action==='choix' && x.p_reponse==='refuse'));
  assert.equal(s.ctx.state.char.enigme1.etape,'declenchee');
  assert.equal(s.ctx.state.char.enigme1.jodie.choix,'refuse');
  assert.equal(s.modal.ouvert,false);
});

test('conversation téléphonique réutilise la réponse serveur et la mémoire sociale', async () => {
  const s=simuler({etat:{ok:true,type:'premier',contact:{}}});
  await s.ctx.jodieEnqueteVerifierAppel();
  s.question.value='Pourquoi me choisir ?';
  await s.ctx.jodieEnqueteParler();
  assert.match(s.body.innerHTML,/Je prends note/);
  assert.equal(s.conversations[0][0],'jodie_moitout');
  assert.equal(s.conversations[0][1],'Pourquoi me choisir ?');
});

test('conclusion : libre choix de transmettre ses découvertes', async () => {
  const s=simuler({etat:{ok:true,type:'conclusion',contact:{}}});
  await s.ctx.jodieEnqueteVerifierAppel();
  assert.match(s.body.innerHTML,/Garder mes découvertes/);
  await s.ctx.jodieEnqueteRepondre('informer');
  assert.ok(s.appels.some(x=>x.p_action==='conclusion' && x.p_reponse==='informer'));
});

test('la presse réutilise modal-postes sans effacer ni raccrocher Jodie', async () => {
  const s=simuler({etat:{ok:true,type:'premier',contact:{}}});
  await s.ctx.jodieEnqueteVerifierAppel();
  const texte = s.body.innerHTML;
  s.ctx.document.getElementById('postes-body').innerHTML = 'Édition des journaux';
  s.ctx.document.getElementById('modal-postes').classList.add('open');
  s.ctx.document.getElementById('modal-postes').classList.remove('open');
  assert.equal(s.modal.ouvert,true);
  assert.equal(s.body.innerHTML,texte);
  s.ctx.jodieEnqueteFermerAppel();
  assert.equal(s.modal.ouvert,false);
});

test('serveur : unicité, J+1, rappel et mémoire commune', () => {
  assert.match(sql,/3\*86400/);
  assert.match(sql,/premierLe/);
  assert.match(sql,/rappelLe/);
  assert.match(sql,/conclusionLe/);
  assert.match(sql,/current_building NOT IN \('marche','la-tribune'\)/);
  assert.match(sql,/pnj_id='jodie_moitout'/);
  assert.match(sql,/jsonb_array_length\(v_paroles\)>6/);
  assert.match(sql,/v_dossier = '\{\}'::jsonb/);
  assert.doesNotMatch(sql,/jsonb_object_length/);
  assert.match(social,/jodie_moitout_autruche' \? 'jodie_moitout'/);
  assert.match(dialogue,/pnjSocialNoterConversation\(profilServeur, action\)/);
  assert.match(api,/profilId === 'jodie_moitout_autruche' \? 'jodie_moitout'/);
  assert.match(prompt,/PAROLES PASSÉES DU JOUEUR/);
  assert.match(enigme,/enigme1TerminerEtRecevoirJodie/);
});

// Garde du report de J+3 à J+1, tout en respectant la clôture de l'accueil.
test('déclenchement J+1 seulement après accueil, rappel toujours après trois jours', () => {
  const migration = lire('migrations/20261109230000_jodie_declenchement_j1.sql');
  assert.match(migration,/>=1\*86400/);
  assert.match(migration,/carriere_terminee/);
  assert.match(migration,/quete_terminee_sans_aide/);
  assert.match(migration,/presentation_en_cours/);
  assert.match(migration,/premierLe/);
  assert.match(migration,/>=3\*86400/);
  assert.match(lire('plateau-enigme-portrait.js'),/ENIGME1_DELAI_DECLENCHEMENT_JOURS = 1/);
});
