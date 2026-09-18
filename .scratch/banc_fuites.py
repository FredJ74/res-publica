# -*- coding: utf-8 -*-
"""Banc « Produire une fuite » : appels HTTP reels avec la cle anon, comme le navigateur.

Couvre les cas A a J demandes : cible sans trace, trace non decouverte par la justice, plusieurs
traces, trace deja fuitee, toutes fuitees, trace judiciaire intacte, concurrence, absence d'effet
POP/INF, absence de l'identite du commanditaire, et repli sans invention.

Donnees de test en pays 'zzfuite', supprimees en fin d'execution. Les tables fuites_journalistiques
et chronique_nationale n'accordent que le SELECT a anon : APRES CHAQUE EXECUTION, purger par MCP :
    DELETE FROM public.fuites_journalistiques WHERE cible LIKE 'zz%' OR auteur LIKE 'zz%';
    DELETE FROM public.chronique_nationale     WHERE type = 'fuite_journalistique' AND data->>'cible' LIKE 'zz%';
    DELETE FROM public.assemblee_requetes      WHERE id LIKE 'zzfuite%';
"""
import json
import urllib.request
import concurrent.futures
import time

URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co'
KEY = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZ'
       'SI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw')
H = {'Content-Type': 'application/json', 'apikey': KEY, 'Authorization': 'Bearer ' + KEY}
echecs = 0


def rpc(nom, params):
    r = urllib.request.Request(URL + '/rest/v1/rpc/' + nom, data=json.dumps(params).encode(), headers=H, method='POST')
    with urllib.request.urlopen(r, timeout=30) as x:
        v = json.loads(x.read().decode())
    return v[0] if isinstance(v, list) and v else v


def get(t, q):
    r = urllib.request.Request(URL + '/rest/v1/' + t + '?' + q, headers=H)
    with urllib.request.urlopen(r, timeout=30) as x:
        return json.loads(x.read().decode())


def post(t, rows):
    r = urllib.request.Request(URL + '/rest/v1/' + t, data=json.dumps(rows).encode(),
                               headers=dict(H, Prefer='return=representation'), method='POST')
    with urllib.request.urlopen(r, timeout=30) as x:
        return json.loads(x.read().decode())


def dele(t, q):
    r = urllib.request.Request(URL + '/rest/v1/' + t + '?' + q, headers=H, method='DELETE')
    urllib.request.urlopen(r, timeout=30).read()


def verifier(ok, texte, detail=''):
    global echecs
    print(('OK    ' if ok else 'ECHEC ') + texte + (('   [' + detail + ']') if detail else ''))
    if not ok:
        echecs += 1


TS = int(time.time())
# fuites_journalistiques garde une ligne par trace fuitee et anon n'a pas le droit de la supprimer :
# chaque execution utilise donc des personnages NEUFS, suffixes par l'horodatage, sinon les traces
# des executions precedentes faussent les comptages.
SUF = str(TS)[-6:]
JOURNA, PROPRE, VOYOU = 'zzfuiteJourna' + SUF, 'zzfuitePropre' + SUF, 'zzfuiteVoyou' + SUF
NOMS = [JOURNA, PROPRE, VOYOU]


def nettoyer():
    for n in NOMS:
        dele('personnages', 'name=eq.' + n)
    dele('actions_tracables', 'auteur=eq.' + VOYOU)


nettoyer()
post('personnages', [
    {'name': JOURNA, 'country': 'zzfuite', 'current_city': 'capitale', 'stats': {'CHA': 10},
     'resources': {'pop': 50, 'inf': 50}, 'inventory': [], 'pa': 60, 'historique_crimes': []},
    {'name': PROPRE, 'country': 'zzfuite', 'current_city': 'capitale', 'stats': {'CHA': 10},
     'resources': {'pop': 50, 'inf': 50}, 'inventory': [], 'pa': 10, 'historique_crimes': []},
    {'name': VOYOU, 'country': 'zzfuite', 'current_city': 'capitale', 'stats': {'CHA': 10},
     'resources': {'pop': 64, 'inf': 41}, 'inventory': [], 'pa': 10,
     'historique_crimes': [
         {'acte': 'vol', 'cible': PROPRE, 'jour': 5, 'expireJour': 13},
         {'acte': 'incendier', 'jour': 6, 'expireJour': 21}]},
])
post('actions_tracables', [{'id': 'zzfuite-act-%d' % TS, 'auteur': VOYOU, 'cible': PROPRE,
                            'type_action': 'corruption', 'country': 'zzfuite', 'city': 'capitale',
                            'jour': 7, 'jour_expiration': 14, 'decouvert': False}])

# A. cible sans aucune trace
r = rpc('fuite_reserver', {'p_requete': 'zzfuite-a-%d' % TS, 'p_joueur': JOURNA, 'p_cible': PROPRE})
verifier(r.get('ok') is True and r.get('trouve') is False,
         'A. cible sans trace : aucune fuite creee, aucune affaire inventee', json.dumps(r))

# B. trace non decouverte par la justice -> eligible, fuite creee
r = rpc('fuite_reserver', {'p_requete': 'zzfuite-b-%d' % TS, 'p_joueur': JOURNA, 'p_cible': VOYOU})
faits = r.get('faits') or {}
verifier(r.get('trouve') is True and faits.get('acte') and faits.get('decouverte_justice') is False,
         'B. trace jamais decouverte par la justice : eligible, fuite creee sur « %s »' % faits.get('acte'))
fuite1 = r.get('fuite_id')

# C. plusieurs traces : une seule choisie par appel
n1 = len(get('fuites_journalistiques', 'cible=eq.' + VOYOU + '&select=id'))
verifier(n1 == 1, 'C. plusieurs traces disponibles : une seule retenue par appel', '%d fuite(s)' % n1)

# D. trace deja fuitee : plus jamais selectionnee
vues = set()
for i in range(2):
    rr = rpc('fuite_reserver', {'p_requete': 'zzfuite-d%d-%d' % (i, TS), 'p_joueur': JOURNA, 'p_cible': VOYOU})
    if rr.get('trouve'):
        vues.add(json.dumps(rr.get('faits'), sort_keys=True))
lignes = get('fuites_journalistiques', 'cible=eq.' + VOYOU + '&select=trace_cle')
verifier(len(lignes) == len(set(l['trace_cle'] for l in lignes)) == 3,
         'D. chaque trace ne fuite qu\'une fois : 3 traces, 3 cles distinctes', '%d ligne(s)' % len(lignes))

# E. toutes les traces fuitees
r = rpc('fuite_reserver', {'p_requete': 'zzfuite-e-%d' % TS, 'p_joueur': JOURNA, 'p_cible': VOYOU})
verifier(r.get('ok') is True and r.get('trouve') is False and len(get('fuites_journalistiques', 'cible=eq.' + VOYOU + '&select=id')) == 3,
         'E. toutes les traces deja fuitees : aucune nouvelle publication', json.dumps(r))

# F. les traces judiciaires sont intactes
p = get('personnages', 'name=eq.' + VOYOU + '&select=historique_crimes,resources')[0]
a = get('actions_tracables', 'auteur=eq.' + VOYOU + '&select=id,decouvert')
verifier(len(p['historique_crimes']) == 2 and len(a) == 1 and a[0]['decouvert'] is False,
         'F. traces judiciaires inchangees : ni supprimees, ni modifiees',
         '%d crime(s), %d action(s) tracable(s)' % (len(p['historique_crimes']), len(a)))

# H. aucune modification POP/INF de la cible
verifier(p['resources'].get('pop') == 64 and p['resources'].get('inf') == 41,
         'H. aucune modification POP/INF de la cible', json.dumps(p['resources']))

# I. publication : auteur public, commanditaire absent
r = rpc('fuite_publier', {'p_fuite_id': fuite1, 'p_contenu': 'Notre cellule enquete revele une affaire.'})
ch = get('chronique_nationale', 'id=eq.' + str(r.get('chronique_id')) + '&select=libelle,data,personnages')
ok_i = (r.get('ok') is True and ch
        and ch[0]['data'].get('auteur_public') == 'Cellule enquête de la rédaction'
        and JOURNA not in json.dumps(ch[0])
        and ch[0]['personnages'] == [VOYOU])
verifier(ok_i, 'I. publication signee « Cellule enquete de la redaction », commanditaire absent du contenu public')

# J. repli sans invention : publier sans texte ne fabrique aucun fait
r2 = rpc('fuite_publier', {'p_fuite_id': fuite1, 'p_contenu': ''})
verifier(r2.get('rejeu') is True and len(get('chronique_nationale', "type=eq.fuite_journalistique&select=id")) >= 1,
         'J. republication sans texte : aucun doublon, aucun fait ajoute')

# G. concurrence : 10 demandes simultanees ne peuvent pas republier une trace
dele('personnages', 'name=eq.' + VOYOU)
post('personnages', [{'name': VOYOU, 'country': 'zzfuite', 'current_city': 'capitale', 'stats': {'CHA': 10},
                      'resources': {'pop': 64, 'inf': 41}, 'inventory': [], 'pa': 10,
                      'historique_crimes': [{'acte': 'chantage', 'cible': PROPRE, 'jour': 9, 'expireJour': 20}]}])


def tenter(i):
    return rpc('fuite_reserver', {'p_requete': 'zzfuite-g%d-%d' % (i, TS), 'p_joueur': JOURNA, 'p_cible': VOYOU})


with concurrent.futures.ThreadPoolExecutor(max_workers=10) as ex:
    res = list(ex.map(tenter, range(10)))
trouves = sum(1 for x in res if x.get('trouve'))
total = len(get('fuites_journalistiques', 'cible=eq.' + VOYOU + '&select=id'))
verifier(trouves == 1 and total == 4,
         'G. 10 demandes simultanees : une seule trace publiee, jamais deux fois la meme',
         '%d reservation(s), %d fuite(s) au total' % (trouves, total))

nettoyer()
restes = len(get('personnages', 'name=like.zzfuite*&select=name'))
verifier(restes == 0, 'K. personnages de test supprimes (fuites et chroniques purgees par MCP)', '%d residu(s)' % restes)

print('\n10 test(s), %d echec(s)' % echecs)
print("RAPPEL : purger fuites_journalistiques, chronique_nationale et assemblee_requetes (prefixe zz) par MCP.")
raise SystemExit(1 if echecs else 0)
