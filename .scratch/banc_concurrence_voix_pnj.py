import json, urllib.request, concurrent.futures, time
URL='https://jxpwoosmmhohoihxpbuc.supabase.co'
KEY=('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZ'
     'SI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw')
H={'Content-Type':'application/json','apikey':KEY,'Authorization':'Bearer '+KEY}
def rpc(n,p):
    r=urllib.request.Request(URL+'/rest/v1/rpc/'+n,data=json.dumps(p).encode(),headers=H,method='POST')
    with urllib.request.urlopen(r,timeout=30) as x: return json.loads(x.read().decode())
def get(t,q):
    r=urllib.request.Request(URL+'/rest/v1/'+t+'?'+q,headers=H)
    with urllib.request.urlopen(r,timeout=30) as x: return json.loads(x.read().decode())
def post(t,rows):
    r=urllib.request.Request(URL+'/rest/v1/'+t,data=json.dumps(rows).encode(),headers=dict(H,Prefer='return=representation'),method='POST')
    with urllib.request.urlopen(r,timeout=30) as x: return json.loads(x.read().decode())
def dele(t,q):
    r=urllib.request.Request(URL+'/rest/v1/'+t+'?'+q,headers=H,method='DELETE'); urllib.request.urlopen(r,timeout=30).read()

CYCLE='zzvoixtest_maire_capitale'
ts=int(time.time()*1000)
for n in ('zzvoixA','zzvoixB'): dele('personnages','name=eq.'+n)
dele('cycles_electoraux','id=eq.'+CYCLE)
post('personnages',[{'name':'zzvoixA','country':'zzvoixtest','current_city':'capitale','stats':{'CHA':10},'resources':{'pop':50,'inf':10},'inventory':[],'pa':50},
                    {'name':'zzvoixB','country':'zzvoixtest','current_city':'capitale','stats':{'CHA':10},'resources':{'pop':50,'inf':10},'inventory':[],'pa':50}])
post('cycles_electoraux',[{'id':CYCLE,'country':'zzvoixtest','poste_id':'maire','city':'capitale',
  'data': json.dumps({'posteId':'maire','city':'capitale','phase':'campagne','dateDebutCandidatures':1,
                      'dateDebutCampagne':2,'dateVote':ts+86400000,'dateResultats':ts+172800000,
                      'candidats':[{'nom':'Alice'},{'nom':'Bob'}],'votes':{},'votesPNJ':{}})}])
echecs=0
def verifier(ok,t):
    global echecs
    print(('OK    ' if ok else 'ECHEC ')+t)
    if not ok: echecs+=1

def prospectus(i):
    j='zzvoixA' if i%2==0 else 'zzvoixB'
    return rpc('elections_voix_pnj_enregistrer',{'p_requete':'zzvoix-par-%d-%d'%(ts,i),'p_joueur':j,'p_cycle_id':CYCLE,
        'p_candidat':'Alice' if i%2==0 else 'Bob','p_pnj_nom':'Le Meme Electeur','p_canal':'prospectus','p_cle':None})
with concurrent.futures.ThreadPoolExecutor(max_workers=10) as ex:
    res=[r[0] if isinstance(r,list) else r for r in ex.map(prospectus,range(10))]
ok_n=sum(1 for r in res if r.get('ok'))
lignes=get('elections_tracts_pnj','cycle_id=eq.'+CYCLE+'&select=id,candidat,canal')
verifier(ok_n==1 and len(lignes)==1,'V1. 10 prospectus simultanes de 2 joueurs sur le MEME PNJ : %d accepte(s), %d ligne(s) (une seule voix)'%(ok_n,len(lignes)))

def conference(i):
    return rpc('elections_voix_pnj_enregistrer',{'p_requete':'zzvoix-conf-%d-%d'%(ts,i),'p_joueur':'zzvoixA','p_cycle_id':CYCLE,
        'p_candidat':'Alice','p_pnj_nom':'Un auditeur','p_canal':'conference','p_cle':'conference:zzvoixA:Alice:%d'%(i%3)})
with concurrent.futures.ThreadPoolExecutor(max_workers=9) as ex:
    res=[r[0] if isinstance(r,list) else r for r in ex.map(conference,range(9))]
conf=get('elections_tracts_pnj','cycle_id=eq.'+CYCLE+'&canal=eq.conference&select=id')
verifier(len(conf)==3,'V2. conference cliquee 3 fois de suite (9 appels paralleles, 3 cles) : %d electeur(s) au total, jamais 9'%len(conf))
total=sum(int(l.get('effet') or 0) for l in get('elections_tracts_pnj','cycle_id=eq.'+CYCLE+'&select=effet'))
verifier(total==4,'V3. depouillement : %d voix au total (1 prospectus + 3 conference), aucune perdue ni dupliquee'%total)
for n in ('zzvoixA','zzvoixB'): dele('personnages','name=eq.'+n)
dele('cycles_electoraux','id=eq.'+CYCLE)
restes=len(get('personnages','name=like.zzvoix*&select=name'))+len(get('cycles_electoraux','id=eq.'+CYCLE+'&select=id'))
verifier(restes==0,'V4. donnees de test supprimees : %d residu(s) (les voix sont purgees par MCP)'%restes)
print('\n4 test(s), %d echec(s)'%echecs)
