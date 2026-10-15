// node --test outils/bancs/banc-nominations-municipales.cjs
// Code client reel en VM ; seules les dependances DOM/transport sont simulees.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ROOT = path.resolve(__dirname, '../..');
const postes = ['commissaire', 'maire_adjoint', 'directeur_entrepot'];
const villes = ['capitale', 'ville_a', 'ville_b'];
function jeu(ville = 'capitale') {
  const elements = new Map();
  function element(id) {
    if (!elements.has(id)) elements.set(id, {innerHTML:'', textContent:'', value:'Candidat|1',
      classList:{add(){},remove(){}}, style:{}});
    return elements.get(id);
  }
  const appels = [], paiements = [], messages = [], evenements = [];
  const ctx = vm.createContext({console, Date, JSON, setTimeout, clearTimeout, TEST_MODE:false,
    document:{getElementById:element,querySelectorAll:()=>[]},
    state:{country:'republic', currentCity:ville, currentBuilding:ville==='capitale'?'mairie-capitale':'mairie',
      currentRoom:ville==='capitale'?'bureau_maire':'bureau_maire_local',
      poste:{id:'maire',city:ville}, char:{name:'Maire',country:'republic'}},
    showToast:(...a)=>messages.push(a), addExternalEvent:(...a)=>evenements.push(a),
    addJournalEntry:()=>{}, signalerRefusCout:()=>{},
    deduireCoutOrdre:async o=>{paiements.push(o); return {ok:true};},
    getTitulaireActuel:async()=>({nom:'Titulaire', estPJ:true, posteComplet:{nommeLe:0}}),
    sbListPersonnages:async()=>[{name:'Candidat',country:'republic',domicile:{country:'republic',city:ville}}],
    sbRpc:async(fn,args)=>{appels.push({fn,args});return {ok:true,id:'nom-test'};},
    sbGetBatimentEtat:async()=>({candidatures:{}}),
    sbSetBatimentEtat:async(...a)=>{appels.push({fn:'sauvegarde',args:a});return {};},
    sbSendMail:async()=>{}, marqueurActionMail:()=>'',
    sbSupprimerTitulairePnj:async()=>{throw Error('DELETE client interdit pour un poste municipal');}
  });
  ctx.window=ctx;
  for (const f of ['data.js','plateau-politique.js','plateau-router.js']) {
    vm.runInContext(fs.readFileSync(path.join(ROOT,f),'utf8'),ctx,{filename:f});
  }
  return {ctx,element,appels,paiements,messages,evenements,run:s=>vm.runInContext(s,ctx)};
}
function simple(x) { return JSON.parse(JSON.stringify(x)); }

test('les bureaux partages ont un seul bouton Nominations ; les autres pouvoirs sont conserves',()=>{
  const j=jeu();
  for(const [bid,rid] of [['mairie-capitale','bureau_maire'],['mairie','bureau_maire_local']]) {
    const ordres=j.run(`BUILDINGS['${bid}'].rooms['${rid}'].orders`);
    assert.equal(ordres.filter(o=>o.fn==='nominations_municipales').length,1);
    assert.ok(!ordres.some(o=>['commissaire_gestion','maire_adjoint_gestion','entrepot_direction'].includes(o.fn)));
    assert.deepEqual(simple(ordres.map(o=>o.fn)),['fixer_impots_locaux','repartition_budget_local','subvention_proposer','campagne_securite','nominations_municipales']);
    const adj=j.run(`BUILDINGS['${bid}'].rooms.bureau_maire_adjoint.orders`);
    assert.deepEqual(simple(adj.map(o=>o.fn)),['traiter_demandes_permis','consulter_dossiers_urbanisme','acte_officiel_mairie','financer_communal']);
  }
});
test('audit des contextes locaux : aucun ancien bouton reintroduit par une surcharge',()=>{
  const j=jeu();let count=0;
  for(const [pays,monde] of Object.entries(j.run('WORLD'))) for(const [ville,city] of Object.entries(monde)) {
    if(!city?.buildings) continue;
    for(const bid of ['mairie-capitale','mairie']) if(city.buildings.includes(bid)) {
      count++;
      const ctx=city.buildingContext?.[bid]||{};
      for(const [rid,r] of Object.entries({...ctx.roomOverrides,...ctx.roomsExtra})) {
        assert.ok(!(r.orders||[]).some(o=>['commissaire_gestion','maire_adjoint_gestion','entrepot_direction'].includes(o.fn)),`${pays}/${ville}/${bid}/${rid}`);
      }
    }
  }
  assert.ok(count>=3);
});
for(const ville of villes) {
  test(`${ville} : le menu ouvre exactement les trois dossiers sans facturation`,()=>{
    const j=jeu(ville);j.ctx.doOrder('nominations_municipales',0,0,'Nominations');
    const html=j.element('postes-body').innerHTML;
    for(const p of postes)assert.ok(html.includes(`ouvrirGestionPosteNomme('${p}')`));
    assert.equal((html.match(/<button/g)||[]).length,3);assert.equal(j.paiements.length,0);
  });
  for(const poste of postes) {
    test(`${ville}/${poste} : titulaire et actions existantes, candidatures incluses`,async()=>{
      const j=jeu(ville);await j.ctx.ouvrirGestionPosteNomme(poste);
      const html=j.element('postes-body').innerHTML;
      assert.ok(html.includes('Titulaire'));
      assert.ok(html.includes(`ouvrirGestionCandidatures(['${poste}'],${poste==='commissaire'?3:1},0)`));
      assert.ok(html.includes(`ouvrirRevoquerPosteNomme('${poste}',1,0)`));
      assert.equal(html.includes(`ouvrirNominerPosteNomme('${poste}',3,0)`),poste!=='maire_adjoint');
    });
    test(`${ville}/${poste} : une candidature est attribuee via la RPC et son tarif propre`,async()=>{
      const j=jeu(ville);await j.ctx.nommerDepuisCandidature(poste,'Poste','Candidat',0,0);
      assert.deepEqual(simple(j.paiements),[{fn:poste==='commissaire'?'nommer_commissaire':`gerer_candidature_${poste}`,pa:poste==='commissaire'?3:1,cost:0}]);
      assert.deepEqual(simple(j.appels[0]),{fn:'poste_attribuer_candidature',args:{p_poste:poste,p_city:ville,p_candidat:'Candidat'}});
    });
    for(const estPJ of [true,false])test(`${ville}/${poste} : revocation ${estPJ?'PJ':'PNJ'} par la RPC existante`,async()=>{
      const j=jeu(ville);await j.ctx.confirmerRevocationPosteNomme(poste,'Titulaire',estPJ,0,0);
      assert.deepEqual(simple(j.paiements),[{fn:`revoquer_${poste}`,pa:1,cost:0}]);
      assert.deepEqual(simple(j.appels[0]),{fn:'poste_revoquer',args:{p_poste:poste,p_city:ville}});
    });
    test(`${ville}/${poste} : titulaire protege, aucun paiement ni RPC de revocation`,async()=>{
      const j=jeu(ville);j.ctx.getTitulaireActuel=async()=>({nom:'Titulaire',estPJ:true,posteComplet:{nommeLe:Date.now()}});
      await j.ctx.confirmerRevocationPosteNomme(poste,'Titulaire',true,1,0);
      assert.equal(j.paiements.length,0);assert.equal(j.appels.length,0);
    });
    for(const role of ['maire_adjoint','citoyen','maire_autre_ville'])test(`${ville}/${poste} : ${role} refuse, y compris les confirmations directes`,async()=>{
      const j=jeu(ville);j.ctx.state.poste={id:role==='maire_autre_ville'?'maire':role,city:role==='maire_autre_ville'?'autre':ville};
      j.ctx.ouvrirNominationsMunicipales();
      await j.ctx.ouvrirGestionPosteNomme(poste);
      await j.ctx.ouvrirGestionCandidatures([poste],1,0);
      await j.ctx.ouvrirNominerPosteNomme(poste,3,0);
      await j.ctx.envoyerNominationPosteNomme(poste,0,0);
      await j.ctx.nommerDepuisCandidature(poste,'Poste','Candidat',0,0);
      const r=await j.ctx.accepterCandidaturePoste(poste,'Poste','Candidat');assert.equal(r.ok,false);
      await j.ctx.ouvrirRevoquerPosteNomme(poste,1,0);
      await j.ctx.confirmerRevocationPosteNomme(poste,'Titulaire',false,0,0);
      assert.equal(j.paiements.length,0);assert.equal(j.appels.length,0);assert.equal(j.evenements.length,0);
      assert.equal(j.element('postes-body').innerHTML,'');
    });
  }
  for(const poste of ['commissaire','directeur_entrepot'])for(const pj of [true,false])test(`${ville}/${poste} : nomination ${pj?'PJ':'PNJ'} et cout 3 PA`,async()=>{
    const j=jeu(ville);j.element('nomme-poste-contact').value=`Candidat|${pj?'1':'0'}`;
    await j.ctx.envoyerNominationPosteNomme(poste,0,0);
    assert.deepEqual(simple(j.paiements),[{fn:`nommer_${poste}`,pa:3,cost:0}]);
    assert.deepEqual(simple(j.appels[0]),{fn:'poste_nommer',args:{p_poste:poste,p_city:ville,p_destinataire:'Candidat'}});
  });
}
test('la facade historique de l’entrepot refuse l’adjoint avant toute consultation',async()=>{
  const j=jeu();j.ctx.state.poste.id='maire_adjoint';await j.ctx.ouvrirModalNommerDirecteurEntrepot(3,0);
  assert.equal(j.element('postes-body').innerHTML,'');assert.equal(j.appels.length,0);
});
test('un refus serveur ne produit pas de faux succes client',async()=>{
  const j=jeu();j.ctx.sbRpc=async()=>({ok:false,raison:'autorite_insuffisante'});
  await j.ctx.confirmerRevocationPosteNomme('directeur_entrepot','Titulaire',false,1,0);
  assert.equal(j.evenements.length,0);assert.ok(j.messages.some(m=>m[0]==='Revocation refusee'));
});
test('le referentiel du cron suit la meme autorite, sans modifier les autres postes',()=>{
  const j=jeu();vm.runInContext(fs.readFileSync(path.join(ROOT,'api/_referentiels-generes.js'),'utf8').replace(/^export /gm,''),j.ctx);
  assert.equal(j.run('POSTES_NOMMES_EXCLUSIFS_SERVEUR.directeur_entrepot.nommePar'),'maire');
  assert.deepEqual(simple(j.run('POSTES_NOMMES_EXCLUSIFS_SERVEUR')),simple(j.run('POSTES_NOMMES_EXCLUSIFS')));
});
for(const ville of villes)for(const poste of postes)test(`${ville}/${poste} : dossier de candidatures et poste vacant`,async()=>{
  const j=jeu(ville);
  j.ctx.getTitulaireActuel=async id=>id==='maire'?{nom:'Maire',estPJ:true}:null;
  const dossier={posteId:poste,city:ville,autoriteNom:'Maire',echeanceTs:Date.now()+86400000,
    traitee:false,candidats:[{nom:'Candidat',depuisTs:Date.now()}]};
  j.ctx.sbGetBatimentEtat=async()=>({candidatures:{[`${poste}|${ville}`]:dossier}});
  await j.ctx.ouvrirGestionPosteNomme(poste);
  assert.ok(j.element('postes-body').innerHTML.includes('Poste vacant'));
  assert.ok(!j.element('postes-body').innerHTML.includes('ouvrirRevoquerPosteNomme'));
  await j.ctx.ouvrirGestionCandidatures([poste],poste==='commissaire'?3:1,0);
  const html=j.element('postes-body').innerHTML;
  assert.ok(html.includes('Candidat'));assert.ok(html.includes('nommerDepuisCandidature'));
  assert.ok(html.includes('Convoquer à un entretien'));assert.equal(j.paiements.length,0);
});
