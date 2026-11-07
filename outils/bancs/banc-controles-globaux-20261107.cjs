const {test}=require('node:test'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
test('contrôles globaux : extensions SQL strictes, références exhaustives et seeds intègres',()=>{
 const r=spawnSync('python3',['outils/bancs/test-controles-globaux-20261107.py'],{cwd:require('node:path').resolve(__dirname,'../..'),encoding:'utf8',timeout:60000});
 assert.ifError(r.error);assert.equal(r.status,0,(r.stdout||'')+(r.stderr||''));
 assert.match(r.stderr,/Ran 5 tests/);assert.match(r.stderr,/\bOK\b/);
});
