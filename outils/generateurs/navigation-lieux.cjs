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
const rows=vm.runInContext(`Object.entries(WORLD).flatMap(([pays,villes])=>Object.entries(villes).flatMap(([ville,v])=>((pays==='soviet'&&ville==='capitale')?(v.buildings||[]).flatMap(id=>id==='palais-gouvernement'?[id,'assemblee']:[id]):(pays==='soviet'&&['ville_a','ville_b'].includes(ville))?(v.buildings||[]).flatMap(id=>id==='tribunal-local'?[id,'siege-syndical']:[id]):(v.buildings||[])).filter(id=>!(pays==='republic'&&ville==='ville_b'&&['services-sociaux-montrouge','parking-tribunal-montrouge'].includes(id))&&!(pays==='republic'&&ville==='ville_a'&&['terrain-a-batir-psm-12','terrain-a-batir-psm-13'].includes(id))&&!(pays==='soviet'&&ville==='capitale'&&['imprimerie-librairie','capitaine-sauvage','musee-novomirsk','palais-ambassades-novomirsk','pavillon-ambassadeurs-novomirsk','residence-imperiale-novomirsk','entrepot-logistique-novomirsk','siege-renseignement','caserne-militaire','garage-novomirsk','musee-national-republia','logements-novomirsk','pharmacie-officielle-novomirsk','poissonniere-novomirsk','salon-coiffure-novomirsk','usine-pharmaceutique-luthecia'].includes(id))&&!(pays==='soviet'&&ville==='ville_b'&&['entrepot-logistique-krasnov','station-service-krasnov','marche','universite','kolkhoze-spirituel','musee-novomirsk','cafe-tabac-cheminots-montrouge'].includes(id))&&!(pays==='soviet'&&ville==='ville_a'&&['entrepot-logistique-starovka','port-starovka','marche','armurerie','capitaine-sauvage','universite','logements-novomirsk','locaux-starovka'].includes(id))).map(id=>({pays,ville,id,locked:BUILDINGS[id]?.locked===true,membership:v.buildingContext?.[id]?.requiresMembership||BUILDINGS[id]?.requiresMembership||null,rooms:Object.keys({...BUILDINGS[id]?.rooms,...v.buildingContext?.[id]?.roomsExtra}).filter(r=>(pays==='soviet'&&ville==='capitale'&&(id==='hotel-republica'||id==='palais-presidentiel'))||!v.buildingContext?.[id]?.roomsExclues?.includes(r)).filter(r=>!(pays==='soviet'&&ville==='capitale'&&id==='palais-presidentiel'&&(r==='appartements_president'||r==='musee_presidentiel'))).filter(r=>!(pays==='soviet'&&r==='salle_partis'))}))))`,c);
// Starovka et Krasnov (10/11/2026) : siège syndical retiré (migration 20261110004000) mais gardé ici, et
// bâtiments du socle ajoutés par la même migration, exclus de cette génération historique.
// Centre d'affaires de Novomirsk : bureaux et salles de réunion ajoutés par leurs migrations (06-07/11) ;
// la référence historique garde ses pièces d'origine.
for(const x of rows)if(x.pays==='soviet'&&x.ville==='capitale'&&x.id==='centre-affaires')x.rooms=["hall", "bureau_prestige", "bureau_standard", "open_space", "tribune_republia"];
const quote=x=>x===null?'NULL':"'"+String(x).replace(/'/g,"''")+"'";
const blocs=[];for(let i=0;i<rows.length;i+=60){const part=rows.slice(i,i+60);blocs.push('-- Généré par outils/generateurs/navigation-lieux.cjs depuis data.js.\nINSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership) VALUES\n'+part.map(x=>'('+[quote(x.pays),quote(x.ville),quote(x.id),quote(JSON.stringify(x.rooms))+'::jsonb',x.locked,quote(x.membership)].join(',')+')').join(',\n')+'\nON CONFLICT(pays,ville,batiment) DO UPDATE SET pieces=EXCLUDED.pieces,ferme=EXCLUDED.ferme,membership=EXCLUDED.membership;\n');}
const noms=JSON.parse(fs.readFileSync(path.join(root,'outils/audits/LIVRAISON-GROUPES-219-20261030.json'),'utf8')).migrations.filter(x=>/_navigation_lieux_reference\.sql$/.test(x.fichier)).map(x=>x.fichier);
if(noms.length!==blocs.length)throw Error('Nombre de morceaux navigation différent du manifeste');
if(process.argv.includes('--verifier')){for(let i=0;i<noms.length;i++)if(fs.readFileSync(path.join(root,noms[i]),'utf8')!==blocs[i])throw Error('Référence dérivée de data.js : '+noms[i]);console.log(rows.length+' bâtiments conformes à data.js');}
else for(let i=0;i<noms.length;i++)fs.writeFileSync(path.join(root,noms[i]),blocs[i]);
