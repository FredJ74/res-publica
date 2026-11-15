import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs';
const css=fs.readFileSync('style.css','utf8');
const nav=fs.readFileSync('plateau-navigation.js','utf8');
const html=fs.readFileSync('plateau.html','utf8');
test('panorama entier, mais conteneur compact : actions juste en dessous',()=>{
 const image=css.match(/\.piece-image\[data-cadrage-integral\]\s*\{([^}]+)\}/)?.[1];
 const container=css.match(/\.piece-container\[data-cadrage-integral\]\s*\{([^}]+)\}/)?.[1];
 assert.ok(image&&container);
 assert.match(image,/aspect-ratio:\s*10\s*\/\s*3/);
 assert.match(image,/min-height:\s*0/);
 assert.match(image,/background-size:\s*100% 100%,\s*contain\s*!important/);
 assert.match(container,/flex:\s*0 0 auto/);
 assert.match(container,/grid-template-rows:\s*auto/);
 assert.match(nav,/pieceImg\.closest\('\.piece-container'\)\?\.toggleAttribute\('data-cadrage-integral'/);
 assert.match(nav,/pieceImg\.toggleAttribute\('data-cadrage-integral'/);
});
test('cache des deux sources rafraîchi',()=>{
 for (const name of ['style.css','plateau-navigation.js'])
 assert.match(html,new RegExp(name.replace('.','\\.')+'\\?v=[^"]*krasnov-accueil-sans-vide-20261115'));
});
