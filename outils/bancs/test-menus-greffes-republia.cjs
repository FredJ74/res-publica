const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const source=fs.readFileSync(path.join(root,'plateau-politique.js'),'utf8');
const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
test('greffes republicains : regroupement commun sans retirer les ordres',()=>{
  const section=source.slice(source.indexOf('// Greffes de Républia :'),source.indexOf("document.getElementById('actions-row-bat').innerHTML",source.indexOf('// Greffes de Républia :')));
  assert.match(section,/\['tribunal','tribunal-local'\]\.includes\(buildingId\) && roomId === 'greffe'/);
  for(const fn of ['archives','greffe_affaires','greffe_archives','demander_juge_instruction','casier_mon_extrait','casier_extrait_enquete','orga_extrait_duplicata','avocat_dossiers','avocat_barreau','falsifier_document','greffe_corrompre_dossier','greffe_corrompre_faux_casier']){
    assert.ok(section.includes("'"+fn+"'"),'ordre non classé: '+fn);
  }
  assert.match(section,/buttons\[index\]/);
  assert.match(section,/buttons\.slice\(ordresTerrainLuthecia\.length\)/);
  assert.match(section,/ouvrirMenuOrdresGreffe/);\n  assert.match(source,/function ouvrirMenuOrdresGreffe\\(index\\)/);\n  assert.match(source,/modal\\.classList\\.add\\('open'\\)/);
  assert.match(section,/nonClasses/);
  assert.match(data,/'tribunal-local': \{/);
  assert.match(data,/'tribunal': \{/);
});
