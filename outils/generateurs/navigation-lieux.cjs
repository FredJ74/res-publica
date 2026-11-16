// Référence serveur issue des déclarations existantes. Aucune règle inventée.
// Palais présidentiel de Sovarka (08/11/2026) : ses pièces réelles sont posées par la migration
// 20261108190500 ; la référence historique (empreinte du manifeste #219) reste inchangée.
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({});vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),c);
// Les références datées du 31/10 sont immuables (empreintes du chantier #219).
// Les deux nouveaux locaux de Montrouge sont ajoutés par la livraison SQL dédiée,
// et exclus uniquement de cette génération HISTORIQUE, pour préserver ses octets.
// Idem pour les lots 12 et 13 de PSM (migration 20261104191500, 04/11/2026).
// Idem pour les bâtiments raccordés à Novomirsk (GAME-DESIGN-NOVOMIRSK.md, migrations 20261104203000 et suivantes) ;
// (garage de Novomirsk et station-service de Krasnov : migration 20261105222000) ;
// le Grand Hôtel de Novomirsk garde ici ses pièces d'origine : ses suites sont retirées par 20261104215000.
// Appartements présidentiels du Palais du Parti (Novomirsk) : migration 20261107130000.
// Salle des partis des trois mairies de Sovarka : migration 20261107184000.
// Soviet Suprême retiré de Novomirsk le 08/11 (pas de chambre des députés) : la référence historique le garde.
// Logements, pharmacie, poissonnière, salon de coiffure, usine Pharmanov (Novomirsk), entrepôt et port de Starovka : leurs migrations des 05-06/11.
const rows=vm.runInContext(`Object.entries(WORLD).flatMap(([pays,villes])=>Object.entries(villes).flatMap(([ville,v])=>((pays==='soviet'&&ville==='capitale')?(v.buildings||[]).flatMap(id=>id==='palais-gouvernement'?[id,'assemblee']:id==='tribunal'?[id,'banque-nationale','banque-privee']:[id]):(pays==='soviet'&&['ville_a','ville_b'].includes(ville))?(v.buildings||[]).flatMap(id=>id==='tribunal-local'?[id,'siege-syndical']:id==='mairie'?[id,'banque-locale']:[id]):(v.buildings||[])).filter(id=>!(pays==='republic'&&ville==='ville_b'&&['services-sociaux-montrouge','parking-tribunal-montrouge'].includes(id))&&!(pays==='republic'&&ville==='ville_a'&&['terrain-a-batir-psm-12','terrain-a-batir-psm-13'].includes(id))&&!(pays==='soviet'&&ville==='capitale'&&['imprimerie-librairie','capitaine-sauvage','musee-novomirsk','palais-ambassades-novomirsk','pavillon-ambassadeurs-novomirsk','residence-imperiale-novomirsk','entrepot-logistique-novomirsk','siege-renseignement','caserne-militaire','garage-novomirsk','musee-national-republia','logements-novomirsk','pharmacie-officielle-novomirsk','poissonniere-novomirsk','salon-coiffure-novomirsk','usine-pharmaceutique-luthecia'].includes(id))&&!(pays==='soviet'&&ville==='ville_b'&&['entrepot-logistique-krasnov','station-service-krasnov','marche','universite','kolkhoze-spirituel','musee-novomirsk','cafe-tabac-cheminots-montrouge','station-radar-krasnov','maison-krasnov','maison-krasnov-bureaux','maison-krasnov-rouge','maison-krasnov-bleue','maison-krasnov-eglise','maison-krasnov-terrains','ferme-krasnov','distillerie-krasnov'].includes(id))&&!(pays==='soviet'&&ville==='ville_a'&&['entrepot-logistique-starovka','port-starovka','marche','armurerie','capitaine-sauvage','universite','logements-novomirsk','locaux-starovka','poste-vigilance-glaciale','maison-starovka','ferme-starovka','fourreur-starovka'].includes(id))).map(id=>({pays,ville,id,locked:BUILDINGS[id]?.locked===true,membership:v.buildingContext?.[id]?.requiresMembership||BUILDINGS[id]?.requiresMembership||null,rooms:Object.keys({...BUILDINGS[id]?.rooms,...v.buildingContext?.[id]?.roomsExtra}).filter(r=>(pays==='soviet'&&ville==='capitale'&&(id==='hotel-republica'||id==='palais-presidentiel'))||!v.buildingContext?.[id]?.roomsExclues?.includes(r)).filter(r=>!(pays==='soviet'&&ville==='capitale'&&id==='palais-presidentiel'&&(r==='appartements_president'||r==='musee_presidentiel'))).filter(r=>!(pays==='soviet'&&r==='salle_partis')).filter(r=>!(pays==='soviet'&&ville==='capitale'&&id==='stade'&&r==='boutique')).filter(r=>!(pays==='soviet'&&ville==='ville_b'&&id==='zone-production'&&/^foret_vue_/.test(r)))}))))`,c);
// Starovka et Krasnov (10/11/2026) : siège syndical retiré (migration 20261110004000) mais gardé ici, et
// bâtiments du socle ajoutés par la même migration, exclus de cette génération historique.
// Boutique du stade de Novomirsk (Dynamo, #669, 10/11/2026) : ajoutée par sa migration, exclue ici.
// Provinces de Sovarka (10/11/2026, #681 et #686) : centres d'écoute, maisons, fermes, distillerie, fourreur et
// quatre vues de la forêt profonde ajoutés par leurs migrations, exclus ici (maisonnettes de Krasnov : 20261114180000) ; banque privée retirée de Novomirsk
// (#681) mais gardée dans la référence historique.
// Banques de Sovarka retirées le 15/11/2026 (bons d'État au guichet des mairies, migration 20261115170000) :
// la référence historique les garde, à leur place d'origine.
// Centre d'affaires de Novomirsk : bureaux et salles de réunion ajoutés par leurs migrations (06-07/11) ;
// la référence historique garde ses pièces d'origine.
for(const x of rows)if(x.pays==='soviet'&&x.ville==='capitale'&&x.id==='centre-affaires')x.rooms=["hall", "bureau_prestige", "bureau_standard", "open_space", "tribune_republia"];
// Ajouts postérieurs au 31/10, posés par leurs migrations et exclus de cette génération HISTORIQUE (15/11/2026) :
// chambres d'hôpital des dispensaires (13-14/11), chambres des appartements (relecture du 13/11), salle des
// élections des mairies de Starovka et Krasnov (14/11), boutique du stade de Krasnov (14/11) et de Starovka (15/11), salles de la raffinerie de Starovka (15/11), immeubles,
// logements et Tabac/Presse de Krasnov et de Novomirsk (12-14/11), quatre bureaux du centre d'affaires de Krasnov (15/11).
// Tabac/Presse de Starovka et retrait de la tribune (15/11) : aucune réécriture des migrations historiques.
const EXCLUS_APRES_3110={soviet:{ville_a:['presse-starovka'],capitale:['logements-novomirsk-marche','logements-novomirsk-quais'],ville_b:['logements-krasnov-place-ours','logements-krasnov-rue-tabac','logements-novomirsk','tabac-presse-krasnov']}};
for(let i=rows.length-1;i>=0;i--)if(EXCLUS_APRES_3110[rows[i].pays]?.[rows[i].ville]?.includes(rows[i].id))rows.splice(i,1);
for(const x of rows){
 if(/^dispensaire-public/.test(x.id))x.rooms=x.rooms.filter(r=>r!=='chambre');
 x.rooms=x.rooms.filter(r=>!/_chambre_\d+$/.test(r));
 if(x.pays==='soviet'&&x.id==='mairie')x.rooms=x.rooms.filter(r=>r!=='salle_elections');
 if(x.pays==='soviet'&&(x.ville==='ville_b'||x.ville==='ville_a')&&x.id==='stade')x.rooms=x.rooms.filter(r=>r!=='boutique');
 // Raffinerie de Starovka (15/11) : deux salles ajoutées par 20261115192000, hors de la référence du 31/10.
 if(x.pays==='soviet'&&x.ville==='ville_a'&&x.id==='usine-principale')x.rooms=x.rooms.filter(r=>r!=='salle_ventes_raffinerie'&&r!=='interieur_raffinerie');
 if(x.pays==='soviet'&&['ville_a','ville_b'].includes(x.ville)&&x.id==='centre-affaires')x.rooms=["hall","bureau_prestige","bureau_standard","open_space","tribune_republia"];
}
const quote=x=>x===null?'NULL':"'"+String(x).replace(/'/g,"''")+"'";
const blocs=[];for(let i=0;i<rows.length;i+=60){const part=rows.slice(i,i+60);blocs.push('-- Généré par outils/generateurs/navigation-lieux.cjs depuis data.js.\nINSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership) VALUES\n'+part.map(x=>'('+[quote(x.pays),quote(x.ville),quote(x.id),quote(JSON.stringify(x.rooms))+'::jsonb',x.locked,quote(x.membership)].join(',')+')').join(',\n')+'\nON CONFLICT(pays,ville,batiment) DO UPDATE SET pieces=EXCLUDED.pieces,ferme=EXCLUDED.ferme,membership=EXCLUDED.membership;\n');}
const noms=JSON.parse(fs.readFileSync(path.join(root,'outils/audits/LIVRAISON-GROUPES-219-20261030.json'),'utf8')).migrations.filter(x=>/_navigation_lieux_reference\.sql$/.test(x.fichier)).map(x=>x.fichier);
if(noms.length!==blocs.length)throw Error('Nombre de morceaux navigation différent du manifeste');
if(process.argv.includes('--verifier')){for(let i=0;i<noms.length;i++)if(fs.readFileSync(path.join(root,noms[i]),'utf8')!==blocs[i])throw Error('Référence dérivée de data.js : '+noms[i]);console.log(rows.length+' bâtiments conformes à data.js');}
else for(let i=0;i<noms.length;i++)fs.writeFileSync(path.join(root,noms[i]),blocs[i]);
