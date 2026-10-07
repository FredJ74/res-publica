ObjC.import('Foundation');
function lire(p){ return $.NSString.stringWithContentsOfFileEncodingError(p, 4, null).js; }
function ecrire(p, s){ $.NSString.alloc.initWithUTF8String(s).writeToFileAtomicallyEncodingError(p, true, 4, null); }

// --- DOM minimal ------------------------------------------------------------
var NOEUDS = {};
function noeud(id){
  if (!NOEUDS[id]) NOEUDS[id] = {
    id:id, textContent:'', innerHTML:'', value:'', className:'', checked:false,
    dataset:{}, classes:{},
    classList:{
      add:function(){ for(var i=0;i<arguments.length;i++) NOEUDS[id].classes[arguments[i]]=true; },
      remove:function(){ for(var i=0;i<arguments.length;i++) delete NOEUDS[id].classes[arguments[i]]; },
      toggle:function(c,v){ if(v) NOEUDS[id].classes[c]=true; else delete NOEUDS[id].classes[c]; },
      contains:function(c){ return !!NOEUDS[id].classes[c]; }
    }
  };
  return NOEUDS[id];
}
function moissonner(html){
  var re=/<input\b[^>]*id="([^"]+)"[^>]*>/g, m;
  while((m=re.exec(html))){
    var n=noeud(m[1]); var v=/value="([^"]*)"/.exec(m[0]); if(v) n.value=v[1];
  }
}
['postes-body','postes-modal-title','modal-postes','#modal-postes .modal-box','mil-ecran','mil-msg']
  .forEach(function(id){ noeud(id); });
var document = {
  getElementById:function(id){ return NOEUDS[id] ? NOEUDS[id] : null; },
  querySelector:function(s){ return noeud(s); },
  querySelectorAll:function(){ return []; }
};

// --- SOCLE ------------------------------------------------------------------
var COUNTRIES = { republic: { cur:'FR', name:'Républia' } };
var WORLD = { republic: { caserne:{name:'Caserne'}, capitale:{name:'Luthécia'}, ville_b:{name:'Montrouge'} } };
var state = { country:'republic', char:{name:'Vince Kubrick'}, poste:{id:'lieutenant'} };
function escapeHtmlText(s){ return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;')
  .replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
function addJournalEntry(){}
function updateUI(){}
function showToast(){}

// --- TRANSPORT BOUCHONNE : la forme EXACTE rendue par la RPC reelle ---------
function etatBase(){
  return { ok:true, moi:'Vince Kubrick', pays:'republic', ma_ville:'caserne',
    suis_a_la_caserne:true, radio_moi:true, tentes:1, capacite_tente:13, par_tente:13,
    places_pj:1, places_tente_libres:12, effectif:3,
    mon_inventaire:[
      { signature:'ration_combat|vivres', name:'Ration de combat', icon:'ti-soup', type:'vivres', qte:10, arme:false },
      { signature:'revolver .38|arme', name:'Revolver .38', icon:'ti-crosshair', type:'arme', qte:1, arme:true },
      { signature:'tente|equipement', name:'Tente de campagne', icon:'ti-tent', type:'equipement', qte:1, arme:false }
    ],
    soldats:[
      { matricule:'202609-017', pa:9, pa_max:12, arme:'mitraillette', arme_feu:true,
        avec_moi:true, leader:'Vince Kubrick', ville:null, copresent:true, radio:false,
        a_ration:false, rations_jour:0, max_ration_jour:2, a_dormi:false,
        possessions:[
          { signature:'tente|equipement', name:'Tente de campagne', icon:'ti-tent', type:'equipement', qte:1 },
          { signature:'mitraillette|arme', name:'Mitraillette', icon:'ti-crosshair', type:'arme', qte:1 },
          { signature:'explosif_militaire|explosif', name:'Explosifs militaires', icon:'ti-bomb', type:'explosif', qte:1 }
        ] },
      { matricule:'202609-007', pa:12, pa_max:12, arme:'arme_de_poing', arme_feu:true,
        avec_moi:true, leader:'Vince Kubrick', ville:null, copresent:true, radio:false,
        a_ration:true, rations_jour:0, max_ration_jour:2, a_dormi:false,
        possessions:[
          { signature:'radio|equipement', name:'Radio de campagne', icon:'ti-radio', type:'equipement', qte:1 },
          { signature:'arme_de_poing|arme', name:'Pistolet militaire', icon:'ti-crosshair', type:'arme', qte:1 },
          { signature:'couteau de poche|blanche', name:'Couteau de poche', icon:'ti-blade', type:'blanche', qte:1 }
        ] },
      { matricule:'202609-023', pa:4, pa_max:12, arme:'corps_a_corps', arme_feu:false,
        avec_moi:false, leader:null, ville:'ville_b', copresent:false, radio:false,
        a_ration:false, rations_jour:0, max_ration_jour:2, a_dormi:false, possessions:[] }
    ] };
}
var ETAT = etatBase();
var ENVOIS = [];
function sbMilitaireTerminalSection(){ return Promise.resolve(ETAT); }
var REPONSE_TRANSFERT = null;
function sbMilitaireTerminalTransferer(req, mat, sig, qte, sens){
  ENVOIS.push('transfert ' + sens + ' ' + mat + ' ' + sig + ' x' + qte);
  if (REPONSE_TRANSFERT) return Promise.resolve(REPONSE_TRANSFERT);
  return Promise.resolve({ ok:true, sens:sens, matricule:mat, signature:sig,
    quantite:qte, objet:'Ration de combat', arme:'mitraillette' });
}
function sbMilitaireTerminalManger(req, mats){
  ENVOIS.push('manger [' + mats.join(',') + ']');
  return Promise.resolve({ ok:true, action:'manger', avec_ration:1, sans_ration:1, gain_pa:1,
    details:[{matricule:'202609-017', raison:'sans_ration', execute:true}] });
}
function sbMilitaireTerminalDormir(req, mats, tentes){
  ENVOIS.push('dormir [' + mats.join(',') + '] tente [' + tentes.join(',') + ']');
  return Promise.resolve({ ok:true, action:'dormir', caserne:2, tente:0, terrain:0, reposes:2, details:[] });
}
function sbMilitaireTerminalRejoindre(req, mats){
  ENVOIS.push('rejoindre [' + mats.join(',') + ']');
  return Promise.resolve({ ok:true, action:'rejoindre', rejoints:1, details:[] });
}
function nouvelleCleMilitaire(){ return 'mil-banc-abcdef'; }

// --- LE VRAI FICHIER --------------------------------------------------------
eval(lire('/Users/fredericjasseron/ResPublica/plateau-militaire-terminal.js'));
var _machine = milMachine;
milMachine = function(h, p){ _machine(h, p); moissonner(noeud('postes-body').innerHTML); };

var R=[];
function verifie(nom, cond, det){ R.push((cond?'[OK]    ':'[ECHEC] ')+nom+(det?'  — '+det:'')); }

(async function(){
 try {
  await ouvrirTerminalSection();
  var c = noeud('postes-body').innerHTML;

  verifie('A1 la coque militaire est posee et l\'ecran defile (min-height gere en CSS)',
    noeud('#modal-postes .modal-box').classList.contains('mil-machine')
    && c.indexOf('id="mil-ecran"') !== -1);
  verifie('A2 la plaque porte le pays derive du referentiel',
    c.indexOf('SYST') !== -1 && c.indexOf('RÉPUBLIA') !== -1);
  verifie('A3 les 3 soldats sont listes (y compris le distant)',
    c.indexOf('202609-017')!==-1 && c.indexOf('202609-007')!==-1 && c.indexOf('202609-023')!==-1);
  verifie('A4 les six colonnes sont en en-tete, et AUCUNE colonne ETAT',
    c.indexOf('Inventaire')!==-1 && c.indexOf('Armement')!==-1 && c.indexOf('Ordres')!==-1
    && c.indexOf('>État<')===-1);

  verifie('B  soldat groupe -> AVEC MOI', c.indexOf('AVEC MOI')!==-1);
  verifie('C  soldat distant -> la VILLE reelle, nommee par le referentiel',
    c.indexOf('Montrouge')!==-1);
  verifie('PA affiche x/12', c.indexOf('9/12')!==-1 && c.indexOf('4/12')!==-1);

  // D : tout l'inventaire, d'un coup d'oeil
  verifie('D  017 : Tente + Mitraillette + Explosifs lisibles dans la ligne',
    c.indexOf('Tente de campagne')!==-1 && c.indexOf('Mitraillette')!==-1
    && c.indexOf('Explosifs militaires')!==-1);
  verifie('D  007 : Radio + Pistolet + Couteau lisibles dans la ligne',
    c.indexOf('Radio de campagne')!==-1 && c.indexOf('Pistolet militaire')!==-1
    && c.indexOf('Couteau de poche')!==-1);
  verifie('D  chaque objet porte ICONE + LIBELLE, jamais l\'icone seule',
    /<i class="ti ti-tent"[^>]*><\/i>Tente de campagne/.test(c));
  verifie('D  aucun « voir l\'inventaire », aucun comptage a la place des objets',
    c.indexOf('Voir l\'inventaire')===-1 && c.indexOf('objets</')===-1);

  // GERER : n'importe quel objet, pas seulement les militaires
  ENVOIS = [];
  milGerer('202609-017');
  c = noeud('postes-body').innerHTML;
  verifie('E1 le panneau de gestion s\'ouvre DANS la ligne (aucune sous-fenetre)',
    c.indexOf('mil-panneau')!==-1 && c.indexOf('Votre paquetage')!==-1
    && c.indexOf('Son paquetage')!==-1);
  verifie('E2 tout mon inventaire est propose, y compris une arme CIVILE',
    c.indexOf('Revolver .38')!==-1 && c.indexOf('Ration de combat')!==-1);

  noeud('mil-q-d-202609-017-0').value = '3';
  await milTransferer('202609-017', encodeURIComponent('ration_combat|vivres'),
                      'mil-q-d-202609-017-0', 'donner');
  verifie('E3 DONNER 3 rations : une seule requete, quantite 3, sens donner',
    ENVOIS.length===1 && ENVOIS[0]==='transfert donner 202609-017 ration_combat|vivres x3',
    ENVOIS.join(' / '));
  verifie('E4 le terminal reste ouvert et affiche le compte rendu',
    noeud('#modal-postes .modal-box').classList.contains('mil-machine')
    && noeud('mil-msg').textContent.indexOf('3 ×')!==-1, noeud('mil-msg').textContent);
  verifie('E5 le panneau reste ouvert apres le transfert (pas de perte de contexte)',
    noeud('postes-body').innerHTML.indexOf('mil-panneau')!==-1);

  ENVOIS = [];
  noeud('mil-q-r-202609-017-1').value = '1';
  await milTransferer('202609-017', encodeURIComponent('mitraillette|arme'),
                      'mil-q-r-202609-017-1', 'reprendre');
  verifie('F  REPRENDRE part bien en sens inverse',
    ENVOIS[0].indexOf('transfert reprendre')===0, ENVOIS.join(' / '));
  verifie('H/I le compte rendu annonce l\'armement recalcule par le serveur',
    noeud('mil-msg').textContent.indexOf('armement')!==-1, noeud('mil-msg').textContent);

  // G : soldat distant -> GERER ferme
  c = noeud('postes-body').innerHTML;
  verifie('G  soldat distant : GERER desactive, et le motif est donne au survol',
    /disabled title="[^"]*n'est pas avec vous/.test(c) || c.indexOf('pas avec vous')!==-1);

  // K / L : les cases liees. On passe par le HTML RENDU, pas par les ensembles
  // internes : `let` au sommet d'un script n'est pas visible depuis un eval, et
  // surtout c'est l'etat VU par le joueur qui doit etre juste.
  function coche(mat, quoi){
    var c = noeud('postes-body').innerHTML;
    var i = c.indexOf(mat);
    var bloc = c.substring(i, i + 2600);
    var re = new RegExp("<input type=\"checkbox\"([^>]*)onchange=\"milCocher\\('" + quoi + "','" + mat + "'");
    var m = re.exec(bloc);
    return !!m && m[1].indexOf('checked') !== -1;
  }
  milGerer('202609-017');            // referme le panneau
  milToutCocher(false);
  milCocher('tente', '202609-017', true);
  verifie('K  cocher TENTE coche automatiquement DORMIR (etat rendu a l\'ecran)',
    coche('202609-017','tente') && coche('202609-017','dormir'),
    'tente=' + coche('202609-017','tente') + ' dormir=' + coche('202609-017','dormir'));
  milCocher('dormir', '202609-017', false);
  verifie('L  decocher DORMIR decoche TENTE',
    !coche('202609-017','dormir') && !coche('202609-017','tente'),
    'tente=' + coche('202609-017','tente') + ' dormir=' + coche('202609-017','dormir'));

  // J : ordre collectif MANGER
  ENVOIS = [];
  milCocher('manger','202609-017',true); milCocher('manger','202609-007',true);
  await milOrdonnerManger();
  verifie('J1 ORDONNER DE MANGER envoie les deux matricules en UN appel',
    ENVOIS.length===1 && ENVOIS[0]==='manger [202609-017,202609-007]', ENVOIS.join(' / '));
  verifie('J2 le compte rendu distingue « avec ration » de « sans ration »',
    noeud('mil-msg').textContent.indexOf('avec ration')!==-1
    && noeud('mil-msg').textContent.indexOf('sans ration')!==-1, noeud('mil-msg').textContent);
  verifie('J3 la selection est videe apres l\'ordre',
    !coche('202609-017','manger') && !coche('202609-007','manger'));

  // DORMIR + TENTE
  ENVOIS = [];
  milCocher('tente','202609-017',true); milCocher('dormir','202609-007',true);
  await milOrdonnerDormir();
  verifie('DORMIR envoie la selection ET la sous-selection sous tente',
    ENVOIS[0]==='dormir [202609-017,202609-007] tente [202609-017]', ENVOIS.join(' / '));

  // M / N : la capacite vient du serveur et s'affiche
  var c2 = noeud('postes-body').innerHTML;
  verifie('M  le bandeau annonce 1 tente et 12 places libres (13 - 1 PJ)',
    c2.indexOf('>1<')!==-1 && c2.indexOf('>12<')!==-1);
  ETAT = etatBase(); ETAT.tentes = 2; ETAT.capacite_tente = 26; ETAT.places_tente_libres = 25;
  await milRafraichir();
  verifie('N  2 tentes -> 25 places libres affichees (26 - 1 PJ)',
    noeud('postes-body').innerHTML.indexOf('>25<')!==-1);

  // O : sans radio, les cases du distant sont fermees
  ETAT = etatBase(); ETAT.radio_moi = false;
  await milRafraichir();
  c2 = noeud('postes-body').innerHTML;
  verifie('O  sans radio : les cases du soldat distant sont desactivees',
    c2.indexOf('mil-case-off')!==-1);
  verifie('O  et REJOINDRE reste visible mais inerte, avec son motif',
    c2.indexOf('Rejoindre')!==-1 && c2.indexOf('hors liaison')!==-1);

  // Q : avec radio, REJOINDRE part
  ETAT = etatBase();
  await milRafraichir();
  ENVOIS = [];
  await milRejoindre('202609-023');
  verifie('Q  REJOINDRE envoie le matricule du groupe distant',
    ENVOIS[0]==='rejoindre [202609-023]', ENVOIS.join(' / '));

  // REJOINDRE n'est PAS propose pour un soldat deja avec moi
  c2 = noeud('postes-body').innerHTML;
  var lig017 = c2.substring(c2.indexOf('202609-017'), c2.indexOf('202609-007'));
  verifie('REJOINDRE n\'apparait que pour un soldat distant',
    lig017.indexOf('milRejoindre')===-1);

  // R : refus « autre ville » lisible
  var faux = { ok:true, action:'rejoindre', rejoints:0,
               details:[{matricule:'202609-023', raison:'autre_ville_transport_requis', ville:'ville_b'}] };
  sbMilitaireTerminalRejoindre = function(){ return Promise.resolve(faux); };
  await milRejoindre('202609-023');
  verifie('R  autre ville : le motif « il faut un transport » est affiche, aucune teleportation',
    noeud('mil-msg').textContent.indexOf('transport')!==-1, noeud('mil-msg').textContent);

  // refus de transfert lisible
  REPONSE_TRANSFERT = { ok:false, raison:'pas_co_presents' };
  await milTransferer('202609-017', encodeURIComponent('ration_combat|vivres'),
                      'mil-q-d-202609-017-0', 'donner');
  verifie('un refus serveur est traduit, jamais un code brut',
    noeud('mil-msg').textContent.indexOf('physiquement')!==-1, noeud('mil-msg').textContent);
 } catch(e) {
  R.push('!!! EXCEPTION : ' + e.message + '\n' + (e.stack||''));
 }
 var ko = R.filter(function(l){ return l.indexOf('[ECHEC]')===0 || l.indexOf('!!!')===0; }).length;
 var ok = R.filter(function(l){ return l.indexOf('[OK]')===0; }).length;
 ecrire('/tmp/rapport_mil.txt', R.join('\n') + '\n\n' + ok + ' verts, ' + ko + ' echec(s).');
})();
'lance'
