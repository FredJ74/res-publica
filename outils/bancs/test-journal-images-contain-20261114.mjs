import assert from 'node:assert/strict';
import fs from 'node:fs';
const css=fs.readFileSync('style.css','utf8');
const html=fs.readFileSync('plateau.html','utf8');
const readStyle=name=>{
 const re=new RegExp('\\.'+name+'\\s*\\{([^}]*)\\}', 'g');
 const blocks=[...css.matchAll(re)];
 assert.equal(blocks.length,1,name+' : une seule règle pour éviter les conflits');
 return blocks[0][1];
};
for(const name of ['tribune-une-image','tribune-article-image']){
 const style=readStyle(name);
 assert.match(style,/width:\s*100%/);
 assert.match(style,/height:\s*auto/);
 assert.match(style,/object-fit:\s*contain/);
 assert.match(style,/object-position:\s*center center/);
 assert.match(style,/margin:\s*0 auto/);
 assert.doesNotMatch(style,/object-fit:\s*cover/);
 console.log(name+': cadrage intégral centré OK');
}
assert.match(css,/\.tribune-une-partagee \.tribune-une-image\{grid-column:1\/-1\}/);
assert.match(html,/style\.css\?v=[^"]*journal-images-entieres-20261114/);
console.log('Journal : images de Une et articles entières, centrées, versionnées.');
