'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const R=path.resolve(__dirname,'../..');
const src=fs.readFileSync(path.join(R,'plateau-politique.js'),'utf8');
const data=fs.readFileSync(path.join(R,'data.js'),'utf8');
const start=src.indexOf('  // Bureau du commissaire : boutons principaux identiques aux greffes');
const end=src.indexOf('  // Greffes : boutons principaux au gabarit standard',start);
assert.ok(start>0&&end>start);
const group=src.slice(start,end);
test('bureau du commissaire : deux boutons standards ouvrent une pop-up, jamais un details',()=>{
 assert.match(group, /\['commissariat', 'commissariat-local'\]\.includes\(buildingId\)/);
 assert.match(group, /roomId === 'bureau_commissaire'/);
 for(const fn of ['mener_enquete','organiser_filature','organiser_chasse_homme','gerer_effectifs_police','recruter_policier','recruter_policier_cynophile'])assert.ok(group.includes("'"+fn+"'"),fn);
 assert.match(group,/action-btn legal/);
 assert.match(group,/ouvrirMenuOrdresCommissaire/);
 assert.doesNotMatch(group,/<details|<summary/);
 assert.match(group,/buttons\[i\]/);
 assert.match(group,/nonClasses/);
 assert.match(group,/buttons\.slice\(ordresTerrainLuthecia\.length\)/);
 assert.match(data,/'commissariat': \{/);
 assert.match(data,/'commissariat-local': \{/);
});
test('sous-menu : mêmes 2 familles et commandes préexistantes ; hors bureau interdit',()=>{
 const a=src.indexOf('function ouvrirMenuOrdresCommissaire(index) {');
 const b=src.indexOf('function ouvrirMenuOrdresGreffe(index)',a);
 assert.ok(a>0&&b>a);
 const modal={classList:{add(x){this.last=x;this.count=(this.count||0)+1}}};
 const titre={textContent:''}, corps={innerHTML:''};
 const elems={'postes-modal-title':titre,'postes-body':corps,'modal-postes':modal};
 const ctx={window:{_commissaireOrdresGroupes:{0:{titre:'Enquêtes',entries:[{html:'<button class="action-btn legal">Mener l’enquête</button>'},{html:'<button class="action-btn legal">Organiser une filature</button>'},{html:'<button class="action-btn legal">Organiser une chasse à l’homme</button>'}]},1:{titre:'Gérer les effectifs',entries:[{html:'<button class="action-btn legal">Gérer mes effectifs</button>'},{html:'<button class="action-btn legal">Recruter un policier</button>'},{html:'<button class="action-btn legal">Recruter une unité cynophile</button>'}]} }},state:{country:'republic',currentBuilding:'commissariat',currentRoom:'bureau_commissaire'},document:{getElementById:id=>elems[id]}};
 vm.createContext(ctx);vm.runInContext(src.slice(a,b),ctx);
 ctx.ouvrirMenuOrdresCommissaire(0);
 assert.equal(titre.textContent,'Enquêtes');assert.equal((corps.innerHTML.match(/<button/g)||[]).length,3);
 assert.equal(modal.classList.last,'open');
 ctx.state.currentBuilding='commissariat-local';ctx.ouvrirMenuOrdresCommissaire(1);
 assert.equal(titre.textContent,'Gérer les effectifs');assert.equal((corps.innerHTML.match(/<button/g)||[]).length,3);
 assert.equal(modal.classList.count,2);
 for(const [building,room,country] of [['tribunal','bureau_commissaire','republic'],['commissariat','accueil_police','republic'],['commissariat','bureau_commissaire','estado']]){
  ctx.state.currentBuilding=building;ctx.state.currentRoom=room;ctx.state.country=country;
  ctx.ouvrirMenuOrdresCommissaire(0);
  assert.equal(modal.classList.count,2);
 }
});
