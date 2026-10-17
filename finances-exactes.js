/* Transport rejouable prepare pour le raccordement financier. Non active dans les pages
 * tant que les circuits historiques et le catalogue vivant ne sont pas verifies. */
(function(root,factory){
  if(typeof module==='object'&&module.exports)module.exports=factory(require('./monnaie.js'));
  else root.HGFinancesExactes=factory(root.HGMonnaie);
})(typeof globalThis!=='undefined'?globalThis:this,function(M){
  'use strict';
  function etatValide(e,nom){
    if(!e||e.version!==2||e.personnage!==nom||typeof e.revision!=='string'||!/^\d+$/.test(e.revision)||!Array.isArray(e.comptes))return false;
    try{
      for(const k of ['arg','liquide','banque'])if(e[k]!==null&&M.normaliser(e[k])!==e[k])return false;
      const ids=new Set();
      for(const c of e.comptes){
        if(!c||typeof c.id!=='string'||ids.has(c.id)||M.normaliser(c.solde)!==c.solde)return false;
        ids.add(c.id);
      }
    }catch(_){return false;}
    return true;
  }
  function creerControleur({contexte,stockage,envoyer,appliquer,uuid}){
    let enVol=null,numero=0;
    function identite(){
      const c=contexte();
      if(!c||!c.uid||!c.personnage||!c.session)throw Error('session_financiere_requise');
      return {uid:c.uid,personnage:c.personnage,session:c.session};
    }
    const meme=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
    function cle(c){return 'hg.finances.v2:'+encodeURIComponent(c.uid)+':'+encodeURIComponent(c.personnage);}
    function pending(c){
      const raw=stockage.getItem(cle(c));if(raw===null)return null;
      const p=JSON.parse(raw);
      if(!p||p.version!==2||p.uid!==c.uid||p.personnage!==c.personnage||typeof p.requete!=='string'||!p.operation||!p.arguments)throw Error('intention_financiere_invalide');
      return p;
    }
    async function traiter(p,c){
      const tour=++numero;
      // Nouvelle copie pour le transport : l'appelant et l'adaptateur ne peuvent modifier
      // l'intention conservee avant l'envoi (ni la remplacer lors d'une reponse perdue).
      const r=await envoyer(JSON.parse(JSON.stringify(p)));
      if(!r||r.ok!==true||!etatValide(r.etat,c.personnage))throw Error('verdict_financier_non_confirme');
      const courant=pending(c);
      if(courant&&courant.requete===p.requete)stockage.removeItem(cle(c));
      if(tour===numero&&meme(c,identite()))appliquer(r.etat);
      return r;
    }
    function lancer(operation,args){
      const c=identite(),body=JSON.parse(JSON.stringify(args));
      const existant=pending(c);
      if(existant&&(!meme(existant.arguments,body)||existant.operation!==operation))return Promise.reject(Error('operation_precedente_a_confirmer'));
      if(enVol){
        if(meme(enVol.c,c)&&enVol.operation===operation&&meme(enVol.arguments,body))return enVol.promesse;
        return Promise.reject(Error('operation_financiere_en_cours'));
      }
      const p=existant||{version:2,uid:c.uid,personnage:c.personnage,requete:uuid(),operation,arguments:body};
      // Une panne de stockage interdit l'envoi : aucun mouvement sans identite durable.
      stockage.setItem(cle(c),JSON.stringify(p));
      const entree={c,operation,arguments:body};enVol=entree;
      entree.promesse=traiter(p,c).finally(()=>{if(enVol===entree)enVol=null;});
      return entree.promesse;
    }
    function reprendre(){
      const c=identite(),p=pending(c);
      return p?lancer(p.operation,p.arguments):Promise.resolve(null);
    }
    function invalider(){numero++;}
    return Object.freeze({lancer,reprendre,invalider});
  }
  return Object.freeze({etatValide,creerControleur});
});
