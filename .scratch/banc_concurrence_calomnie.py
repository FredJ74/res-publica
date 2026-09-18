# -*- coding: utf-8 -*-
"""Concurrence reelle (HTTP parallele, cle anon) sur les RPC de tracts calomnieux et de voix PNJ.

Cree ses propres personnages de test en pays 'zzconc', les supprime a la fin. Ne touche jamais un
personnage reel ni un cycle electoral reel.
"""
import json, urllib.request, concurrent.futures, time

URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co'
KEY = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZ'
       'SI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw')
H = {'Content-Type': 'application/json', 'apikey': KEY, 'Authorization': 'Bearer ' + KEY}


def rpc(nom, params):
    req = urllib.request.Request(URL + '/rest/v1/rpc/' + nom, data=json.dumps(params).encode(), headers=H, method='POST')
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def get(table, q):
    req = urllib.request.Request(URL + '/rest/v1/' + table + '?' + q, headers=H)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def post(table, rows):
    req = urllib.request.Request(URL + '/rest/v1/' + table, data=json.dumps(rows).encode(),
                                 headers=dict(H, Prefer='return=representation'), method='POST')
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def delete(table, q):
    req = urllib.request.Request(URL + '/rest/v1/' + table + '?' + q, headers=H, method='DELETE')
    urllib.request.urlopen(req, timeout=30).read()


NOMS = ['zzconcA', 'zzconcB', 'zzconcVictime']
LOT = [{'type': 'tract_calomnieux', 'cible': 'zzconcVictime', 'quantite': 500}]


def nettoyer():
    """Supprime ce que la cle anon a le droit de supprimer.

    calomnies_actes et assemblee_requetes n'accordent que le SELECT a anon (aucune ecriture cliente
    possible : c'est la protection voulue). APRES CHAQUE EXECUTION, purger ces deux tables par MCP :
        DELETE FROM public.calomnies_actes  WHERE auteur LIKE 'zz%' OR cible LIKE 'zz%';
        DELETE FROM public.assemblee_requetes WHERE id LIKE 'zz%';
    """
    for n in NOMS:
        delete('personnages', 'name=eq.' + n)


echecs = 0


def verifier(ok, texte):
    global echecs
    print(('OK    ' if ok else 'ECHEC ') + texte)
    if not ok:
        echecs += 1


nettoyer()
post('personnages', [
    {'name': 'zzconcA', 'country': 'zzconc', 'current_city': 'capitale', 'stats': {'CHA': 40},
     'resources': {'pop': 50, 'inf': 100}, 'inventory': LOT, 'pa': 200},
    {'name': 'zzconcB', 'country': 'zzconc', 'current_city': 'capitale', 'stats': {'CHA': 40},
     'resources': {'pop': 50, 'inf': 100}, 'inventory': LOT, 'pa': 200},
    {'name': 'zzconcVictime', 'country': 'zzconc', 'current_city': 'capitale', 'stats': {'CHA': 10},
     'resources': {'pop': 100, 'inf': 100}, 'inventory': [], 'pa': 10},
])

# --- 1. Deux joueurs sur LE MEME PNJ contre LA MEME cible le meme jour : une reussite au maximum.
def tenter(i):
    joueur = 'zzconcA' if i % 2 == 0 else 'zzconcB'
    return rpc('calomnie_distribuer', {'p_requete': 'zzconc-duel-%d-%d' % (int(time.time()), i),
                                       'p_joueur': joueur, 'p_cible': 'zzconcVictime',
                                       'p_pnj_nom': 'Le Meme PNJ', 'p_vol_pnj': 10})

with concurrent.futures.ThreadPoolExecutor(max_workers=12) as ex:
    res = [r[0] if isinstance(r, list) else r for r in ex.map(tenter, range(12))]
reussites = [r for r in res if r.get('ok') and r.get('reussi')]
refus = [r for r in res if not r.get('ok') and r.get('raison') == 'deja_convaincu']
actes = get('calomnies_actes', "cible=eq.zzconcVictime&resultat=eq.reussite&select=id,pnj_cle,auteur")
verifier(len(reussites) <= 1 and len(actes) <= 1,
         'D1. 12 tentatives simultanees de 2 joueurs sur le meme PNJ : %d reussite(s), %d refus « deja convaincu », %d acte(s) en base'
         % (len(reussites), len(refus), len(actes)))

# --- 2. POP/INF de la victime : exactement -5 / -2 par reussite, jamais un cumul fantome.
v = get('personnages', 'name=eq.zzconcVictime&select=resources')[0]['resources']
attendu_pop = 100 - 5 * len(actes)
attendu_inf = 100 - 2 * len(actes)
verifier(v.get('pop') == attendu_pop and v.get('inf') == attendu_inf,
         'D2. effet applique exactement une fois : POP=%s (attendu %s), INF=%s (attendu %s)'
         % (v.get('pop'), attendu_pop, v.get('inf'), attendu_inf))

# --- 3. Idempotence : la meme requete jouee 8 fois en parallele ne cree qu'un acte.
rq = 'zzconc-idem-%d' % int(time.time())
def rejouer(i):
    return rpc('calomnie_distribuer', {'p_requete': rq, 'p_joueur': 'zzconcA', 'p_cible': 'zzconcVictime',
                                       'p_pnj_nom': 'Pnj Idempotent', 'p_vol_pnj': 10})
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
    res = [r[0] if isinstance(r, list) else r for r in ex.map(rejouer, range(8))]
actes_idem = get('calomnies_actes', "pnj_nom=eq.Pnj%20Idempotent&select=id")
verifier(len(actes_idem) == 1,
         'D3. meme id de requete joue 8 fois en parallele : %d acte enregistre' % len(actes_idem))

# --- 4. Le verrou porte bien sur le TRIPLET : un autre PNJ reste disponible le meme jour.
r = rpc('calomnie_distribuer', {'p_requete': 'zzconc-autrepnj-%d' % int(time.time()), 'p_joueur': 'zzconcA',
                                'p_cible': 'zzconcVictime', 'p_pnj_nom': 'Un Autre PNJ', 'p_vol_pnj': 10})
r = r[0] if isinstance(r, list) else r
verifier(r.get('ok') is True, 'D4. un AUTRE PNJ reste sollicitable le meme jour contre la meme cible (ok=%s)' % r.get('ok'))

# --- 5. Aucun residu de test.
nettoyer()
restes = len(get('personnages', 'name=like.zzconc*&select=name'))
verifier(restes == 0, 'D5. personnages de test supprimes : %d residu(s) (les actes sont purges par MCP)' % restes)

print('\n5 test(s), %d echec(s)' % echecs)
print("RAPPEL : purger calomnies_actes et assemblee_requetes (prefixe zz) par MCP.")
raise SystemExit(1 if echecs else 0)
