// Même géographie que le navigateur, sans déduire une direction de l'ordre des voisins.
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),ctx=vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(root,'plateau-rue-centrale.js'),'utf8'),ctx);
const rows=vm.runInContext(`Object.entries(RUE_CENTRALE_NOEUDS).flatMap(([pays,nodes])=>Object.entries(nodes).map(([noeud,n])=>({pays,noeud,directions:{liens:n.liens||{},parArrivee:n.liensParArrivee||{}}})))`,ctx);
const quote=x=>"'"+String(x).replace(/'/g,"''")+"'";
for(let i=0;i<rows.length;i+=12){
 const body='-- Généré par outils/generateurs/navigation-directions.cjs. Ne pas modifier à la main.\n'+rows.slice(i,i+12).map(r=>`UPDATE public.rue_noeuds_serveur SET directions=${quote(JSON.stringify(r.directions))}::jsonb WHERE country=${quote(r.pays)} AND noeud=${quote(r.noeud)};`).join('\n')+'\n';
 const f=path.join(root,`migrations/20261029223${400+Math.floor(i/12)}_navigation_directions_reference.sql`);
 if(body.length>12500)throw Error('Lot trop volumineux');
 if(process.argv.includes('--verifier')){if(fs.readFileSync(f,'utf8')!==body)throw Error('Direction divergente : '+f);}else fs.writeFileSync(f,body);
}
console.log(rows.length+' nœuds : directions issues du même catalogue');
