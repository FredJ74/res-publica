import json, urllib.request, concurrent.futures
URL='https://jxpwoosmmhohoihxpbuc.supabase.co'
KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw'
H={'Content-Type':'application/json','apikey':KEY,'Authorization':'Bearer '+KEY}
def rpc(nom, params):
    req=urllib.request.Request(URL+'/rest/v1/rpc/'+nom, data=json.dumps(params).encode(), headers=H, method='POST')
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())
def get(table, q):
    req=urllib.request.Request(URL+'/rest/v1/'+table+'?'+q, headers=H)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())
def post(table, row):
    req=urllib.request.Request(URL+'/rest/v1/'+table, data=json.dumps(row).encode(),
                               headers=dict(H, Prefer='return=representation'), method='POST')
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())
def delete(table, q):
    req=urllib.request.Request(URL+'/rest/v1/'+table+'?'+q, headers=H, method='DELETE')
    urllib.request.urlopen(req, timeout=30).read()

CLE='zzconc_capitale_la-tribune'
delete('batiments_etat','id=eq.'+CLE)
post('batiments_etat', {'id':CLE,'country':'zzconc','city':'capitale','building_id':'la-tribune',
                        'data': json.dumps({'imprimerie':{'caisse':1000,'stockBois':0}})})

def credit(i):  return rpc('batiment_caisse_mouvement', {'p_pays':'zzconc','p_ville':'capitale','p_building':'la-tribune','p_souscle':'imprimerie','p_delta':150})
def debit(i):   return rpc('batiment_caisse_mouvement', {'p_pays':'zzconc','p_ville':'capitale','p_building':'la-tribune','p_souscle':'imprimerie','p_delta':-150,'p_stock_cle':'stockBois','p_stock':10})

echecs=0
with concurrent.futures.ThreadPoolExecutor(max_workers=20) as ex:
    res=list(ex.map(credit, range(20)))
etat=json.loads(get('batiments_etat','id=eq.'+CLE+'&select=data')[0]['data'])
attendu=1000+20*150
ok = etat['imprimerie']['caisse']==attendu
print(('OK    ' if ok else 'ECHEC ')+'C1. 20 credits de 150 en parallele : caisse = %s (attendu %s)'%(etat['imprimerie']['caisse'],attendu))
echecs += 0 if ok else 1

with concurrent.futures.ThreadPoolExecutor(max_workers=20) as ex:
    res=list(ex.map(debit, range(20)))
etat=json.loads(get('batiments_etat','id=eq.'+CLE+'&select=data')[0]['data'])
reussis=sum(1 for r in res if r and r.get('ok'))
ok = etat['imprimerie']['caisse']==attendu-150*reussis and etat['imprimerie']['stockBois']==10*reussis
print(('OK    ' if ok else 'ECHEC ')+'C2. 20 debits de 150 + stock en parallele : %d acceptes, caisse=%s stock=%s (coherents)'%(reussis,etat['imprimerie']['caisse'],etat['imprimerie']['stockBois']))
echecs += 0 if ok else 1

# Vider la caisse puis tenter 20 debits : aucun ne doit passer sous zero.
solde=etat['imprimerie']['caisse']
rpc('batiment_caisse_mouvement', {'p_pays':'zzconc','p_ville':'capitale','p_building':'la-tribune','p_souscle':'imprimerie','p_delta':-solde+100})
with concurrent.futures.ThreadPoolExecutor(max_workers=20) as ex:
    res=list(ex.map(debit, range(20)))
etat=json.loads(get('batiments_etat','id=eq.'+CLE+'&select=data')[0]['data'])
reussis=sum(1 for r in res if r and r.get('ok'))
ok = etat['imprimerie']['caisse']>=0 and reussis==0 and etat['imprimerie']['caisse']==100
print(('OK    ' if ok else 'ECHEC ')+'C3. caisse a 100, 20 debits de 150 en parallele : %d accepte(s), caisse=%s (jamais negative)'%(reussis,etat['imprimerie']['caisse']))
echecs += 0 if ok else 1

delete('batiments_etat','id=eq.'+CLE)
reste=get('batiments_etat','id=eq.'+CLE+'&select=id')
print(('OK    ' if not reste else 'ECHEC ')+'C4. donnee de test supprimee : %d ligne(s) restante(s)'%len(reste))
echecs += 0 if not reste else 1
print('\n4 test(s), %d echec(s)'%echecs)
