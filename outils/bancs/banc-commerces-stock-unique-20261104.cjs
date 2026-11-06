'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const read = n => fs.readFileSync(path.join(root,n),'utf8');
const justice = read('plateau-justice-economie.js');
const commerce = read('plateau-actions-illegales-rumeurs.js');
const nav = read('plateau-navigation.js');
const politique = read('plateau-politique.js');
const data = read('data.js');
const router = read('plateau-router.js');
let n=0;
function check(nom, ok) { assert.ok(ok,nom); console.log('OK', ++n, nom); }
function extract(src, start, end) {
 const a=src.indexOf(start), b=src.indexOf(end,a+start.length);
 assert.ok(a>=0&&b>a,'Fonction absente : '+start);
 return src.slice(a,b);
}
function dialogue() {
 const elements={'postes-modal-title':{textContent:''}, 'postes-body':{innerHTML:''},
 'modal-postes':{classList:{add:()=>{}}}};
 return {elements,document:{getElementById:id=>elements[id]||null}};
}
async function run(src,first,last,deps,state,args) {
 const ui=dialogue();
 const f=first.match(/function\s+(\w+)/)[1];
 const fn=new Function('state','document',...Object.keys(deps),extract(src,first,last)+';return '+f+';');
 await fn(state,ui.document,...Object.values(deps))(...args);
 return ui.elements['postes-body'].innerHTML;
}
async function main() {
 const ressources={bois:{label:'Bois',plafond:20,prixBase:7},minerai:{label:'Minerai',plafond:20,prixBase:10}};
 const factory={COUNTRIES:{republic:{cur:'FR'}},
   sbGetBatimentEtat:async()=>({usine:{stockMatieres:{bois:4,minerai:20},stockProduits:{armoire_souvenirs:3}}}),
   defautUsine:()=>({stockMatieres:{}}),matieresAccepteesParUsine:()=>['bois','minerai'],
   prixRachatMatierePremiereUsine:(_b,_p,_v,r)=>r.prixBase,
   produitsManufacturesUsine:()=>['armoire_souvenirs'],PRODUITS_MANUFACTURES_USINE:{armoire_souvenirs:{label:'Armoire à souvenirs'}},
   RESSOURCES_ECONOMIE:ressources,showToast:()=>{}};
 const position={country:'republic',currentCity:'ville_a',currentBuilding:'zone-production',char:{name:'Arnie'},inventory:[]};
 let html=await run(justice,'async function doOuvrirVendreMatierePremiereUsine(','async function confirmerVendreMatierePremiereUsineUI(',factory,position,['zone-production',0,0]);
 check('Scierie : stock visible sans inventaire',html.includes('Stock Bois : 4/20'));
 check('Scierie : prix d’achat visible sans inventaire',html.includes("Prix d'achat : 7 FR"));
 check('Scierie : saisie désactivée sans matière',html.includes('id="vendre-usine-qte-bois" min="1" max="0" disabled'));
 check('Scierie : stock plein toujours visible',html.includes('Stock Minerai : 20/20'));
 check('Scierie : produits finis toujours visibles',html.includes('Armoire à souvenirs : 3'));
 position.inventory=[{stackKey:'bois',qty:5}];
 html=await run(justice,'async function doOuvrirVendreMatierePremiereUsine(','async function confirmerVendreMatierePremiereUsineUI(',factory,position,['zone-production',0,0]);
 check('Scierie : vente disponible si matière possédée',html.includes("confirmerVendreMatierePremiereUsineUI("));
 const food={COUNTRIES:{republic:{cur:'FR'}},
   chargerCommerce:async()=>({stockMatieres:{bois:4},carte:['test'],parametres:{stockMax:{bois:20},prixAchatMatiere:{bois:7}}}),
   matieresAccepteesParCommerce:()=>['bois'],prixAchatMatiereCommerce:()=>7,plafondEffectifCommerce:()=>20,
   RESSOURCES_ECONOMIE:ressources,showToast:()=>{}};
 const shop={country:'republic',currentCity:'ville_a',currentBuilding:'magasin',currentRoom:'salle',char:{name:'Arnie'},inventory:[]};
 html=await run(commerce,'async function doVendreMatiereCommerce(','async function confirmerVendreMatiereCommerceUI(',food,shop,['bar','magasin','salle',0,0]);
 check('Commerce : stock visible sans inventaire',html.includes('Stock Bois : 4/20'));
 check('Commerce : prix visible sans inventaire',html.includes("Prix d'achat : 7 FR"));
 check('Commerce : saisie désactivée sans matière',html.includes('id="vendre-commerce-qte-bois" min="1" max="0" disabled'));
 shop.inventory=[{stackKey:'bois',qty:5}];
 html=await run(commerce,'async function doVendreMatiereCommerce(','async function confirmerVendreMatiereCommerceUI(',food,shop,['bar','magasin','salle',0,0]);
 check('Commerce : vente disponible après approvisionnement PJ',html.includes('confirmerVendreMatiereCommerceUI('));
 check('Commerce : don conservé',html.includes('>Donner</button>'));
 const arm={COUNTRIES:{republic:{cur:'FR'}},chargerArmurerieLocale:async()=>({parametres:{prixAchatMatiere:{metal:20}},stockMatieres:{metal:49}}),
 RESSOURCES_ECONOMIE:{metal:{label:'Métal'}},showToast:()=>{}};
 const gun={country:'republic',currentCity:'capitale',currentBuilding:'armurerie',char:{name:'Arnie'},inventory:[]};
 html=await run(commerce,'async function doVendreMatiereArmurerie(','async function confirmerVenteMatiere(',arm,gun,[]);
 check('Armurerie : aucun faux plafond inventé',html.includes('Stock Métal : 49 / sans plafond'));
 check('Armurerie : saisie désactivée sans matière',html.includes('id="vendre-qte-metal" min="1" max="0" disabled'));
 check('Scierie : ordre caisse historique conservé au tarif',data.includes("fn:'consulter_caisse_usine'"));
 check('Scierie : ordre stock historique conservé au tarif',data.includes("fn:'consulter_stock_usine'"));
 check('Scierie : deux ordres hérités masqués par le rendu',politique.includes("['consulter_caisse_usine','consulter_stock_usine'].includes(o.fn)"));
 check('Scierie : ordre vendre conservé',data.includes("fn:'vendre_matiere_usine'"));
 check('Anciennes routes caisse/stock supprimées',!router.includes("fn === 'consulter_caisse_usine'")&&!router.includes("fn === 'consulter_stock_usine'"));
 check('Caisses usines non publiées dans l’en-tête',!nav.includes("'usine-pharmaceutique-luthecia': 'usine'"));
 check('Caisses entrepôts publics conservées',nav.includes("'entrepot-logistique-luthecia': 'entrepot'"));
 console.log(n+'/'+n+' contrôles réussis');
}
main().catch(e=>{console.error(e.stack||e);process.exitCode=1});
