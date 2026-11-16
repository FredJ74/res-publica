'use strict';
const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const html=read('plateau.html'),street=read('plateau-exploration-mobile.js'),room=read('plateau-interieurs-mobile.js');
for(const [id,token] of [['hg-explore-primary','data-explore-tab'],['hg-room-primary','data-room-tab']]){
  assert.equal(html.split('id="'+id+'"').length-1,1,'unique '+id);
  const section=html.slice(html.indexOf('id="'+id+'"'),html.indexOf('</nav>',html.indexOf('id="'+id+'"')));
  assert.equal(section.split(token+'=').length-1,3,'three controls '+id);
}
assert.ok(html.indexOf('id="hg-explore-primary"')<html.indexOf('class="rue-container"'));
assert.ok(html.indexOf('id="hg-room-primary"')<html.indexOf('class="piece-container"'));
assert.match(street,/getElementById\('hg-explore-primary'\)/);
assert.match(room,/getElementById\('hg-room-primary'\)/);
assert.match(street,/if\(!b\.isConnected\)bar\.append\(b\)/);
assert.match(room,/if\(!button\.isConnected\)nav\.append\(button\)/);
assert.match(html,/html-nav-visible-r1-20261117/);
console.log('OK barres visibles avant JS, aucune duplication et scripts versionnés');
