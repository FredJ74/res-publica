// Référence serveur issue des déclarations existantes. Aucune règle inventée.
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({});vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),c);
const rows=vm.runInContext(`Object.entries(WORLD).flatMap(([pays,villes])=>Object.entries(villes).flatMap(([ville,v])=>(v.buildings||[]).map(id=>({pays,ville,id,locked:BUILDINGS[id]?.locked===true,membership:v.buildingContext?.[id]?.requiresMembership||BUILDINGS[id]?.requiresMembership||null,rooms:Object.keys({...BUILDINGS[id]?.rooms,...v.buildingContext?.[id]?.roomsExtra}).filter(r=>!v.buildingContext?.[id]?.roomsExclues?.includes(r))}))))`,c);
const quote=x=>x===null?'NULL':"'"+String(x).replace(/'/g,"''")+"'";
const blocs=[];for(let i=0;i<rows.length;i+=60){const part=rows.slice(i,i+60);blocs.push('-- Généré par outils/generateurs/navigation-lieux.cjs depuis data.js.\nINSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership) VALUES\n'+part.map(x=>'('+[quote(x.pays),quote(x.ville),quote(x.id),quote(JSON.stringify(x.rooms))+'::jsonb',x.locked,quote(x.membership)].join(',')+')').join(',\n')+'\nON CONFLICT(pays,ville,batiment) DO UPDATE SET pieces=EXCLUDED.pieces,ferme=EXCLUDED.ferme,membership=EXCLUDED.membership;\n');}
const noms=blocs.map((_,i)=>`migrations/2026102818530${i+1}_navigation_lieux_reference.sql`);
if(process.argv.includes('--verifier')){for(let i=0;i<noms.length;i++)if(fs.readFileSync(path.join(root,noms[i]),'utf8')!==blocs[i])throw Error('Référence dérivée de data.js : '+noms[i]);console.log(rows.length+' bâtiments conformes à data.js');}
else for(let i=0;i<noms.length;i++)fs.writeFileSync(path.join(root,noms[i]),blocs[i]);
