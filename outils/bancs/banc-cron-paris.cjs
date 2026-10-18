const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),{spawnSync}=require('node:child_process');
test('cron Paris : hiver, ete et transitions ; reparation quotidienne sans commit redondant',()=>{
 const code=`import runpy,sys,datetime,tempfile,json,pathlib
m=runpy.run_path(sys.argv[1]);f=m['planification_minuit_paris'];ajuster=m['ajuster']
for date,heure in [('2026-01-01T03:00:00+00:00',23),('2026-07-01T03:00:00+00:00',22),('2026-10-19T03:00:00+00:00',22),('2026-03-29T00:00:00+00:00',23),('2026-03-29T03:00:00+00:00',22),('2026-10-25T00:00:00+00:00',22),('2026-10-25T03:00:00+00:00',23)]:
 assert f(datetime.datetime.fromisoformat(date))==f'0 {heure} * * *'
with tempfile.TemporaryDirectory() as d:
 p=pathlib.Path(d)/'vercel.json';p.write_text(json.dumps({'crons':[{'path':'/api/cron-minuit','schedule':'0 23 * * *'},{'path':'/api/cron-assemblee','schedule':'0 22 * * *'}],'functions':{'test':{}}}))
 ete=datetime.datetime.fromisoformat('2026-10-19T03:00:00+00:00');assert ajuster(p,ete);avant=p.read_text();assert not ajuster(p,ete);assert p.read_text()==avant
 assert json.loads(avant)['crons'][1]['schedule']=='0 22 * * *'
print('7 dates et idempotence OK')`;
 const r=spawnSync('python3',['-c',code,path.resolve(__dirname,'../ajuster-cron-vercel.py')],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/idempotence OK/);
});
