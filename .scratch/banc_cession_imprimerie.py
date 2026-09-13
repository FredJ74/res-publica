# -*- coding: utf-8 -*-
# BANC OBSOLETE (13 septembre 2026) -- constatait une cession ponctuelle du 12/09 ; la ligne caisses_batiments visee n'existe plus depuis la reinitialisation de la beta.
# Remplace par banc_attaques_chantier_b.py, banc_economie_chantier_c.py
# et banc_fermeture_batiments_etat.py. Conserve pour memoire, ne plus lancer.
"""Banc de concurrence REELLE sur la cession d'une imprimerie (12 septembre 2026).

Appels HTTP simultanes avec la cle anon, comme le ferait le navigateur, sur des donnees de test
dediees (prefixe zz, creees et supprimees autour du banc). Verifie les deux scenarios que le
statique ne peut pas prouver :
  - double-clic : N appels PARALLELES avec le MEME id de requete -> un seul credit de 180 000 FR ;
  - acheteurs concurrents : N appels PARALLELES avec des ids DIFFERENTS -> une seule cession, les
    autres refusees 'deja_vendue', et toujours un seul credit.
"""
import json
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co'
ANON = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9p'
        'aHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0'
        '._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw')
HDRS = {'apikey': ANON, 'Authorization': 'Bearer ' + ANON, 'Content-Type': 'application/json'}
CAISSE = 'zztestpays_gouvernement-min_fin'
echecs = []


def verifier(ok, texte, detail=''):
    print(('OK    ' if ok else 'ECHEC ') + texte + (('   [' + str(detail) + ']') if detail else ''))
    if not ok:
        echecs.append(texte)


def rpc(nom, corps):
    req = urllib.request.Request(URL + '/rest/v1/rpc/' + nom, data=json.dumps(corps).encode(),
                                 headers=HDRS, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode() or 'null')
    except Exception as e:
        return {'erreur': str(e)}


def get(table, filtre):
    req = urllib.request.Request(URL + '/rest/v1/' + table + '?' + filtre, headers=HDRS)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def solde_caisse():
    rows = get('caisses_batiments', 'id=eq.' + CAISSE)
    return (rows[0]['data'] or {}).get('solde', 0) if rows else None


def proprietaire(imp):
    rows = get('entreprises', 'id=eq.' + imp)
    return (rows[0]['data'] or {}).get('proprietaire') if rows else None


def cession(req_id, acheteur, imp):
    return rpc('imprimerie_cession_finaliser', {
        'p_requete': req_id, 'p_acheteur': acheteur, 'p_imprimerie_id': imp,
        'p_prix': 180000, 'p_jour': 12})


# ---------------------------------------------------------------- 1. DOUBLE-CLIC (meme id)
IMP_A = 'imprimerie-zztestpays-capitale-la-tribune'
s0 = solde_caisse()
verifier(s0 == 0, 'C0. caisse de test initialisee a 0', s0)

with ThreadPoolExecutor(max_workers=8) as ex:
    res = list(ex.map(lambda i: cession('zzhttp-doubleclic-01', 'zzAcheteurA', IMP_A), range(8)))
oks = [r for r in res if isinstance(r, dict) and r.get('ok') is True and not r.get('rejeu')]
rejeux = [r for r in res if isinstance(r, dict) and r.get('rejeu')]
verifier(len(oks) == 1, 'C1. double-clic x8, meme id : UNE seule cession effective', len(oks))
verifier(len(oks) + len(rejeux) == 8, 'C2. les 7 autres appels sont des rejeux, jamais des erreurs',
         json.dumps([r.get('raison') or ('ok' if r.get('ok') else r) for r in res])[:200])
verifier(solde_caisse() - s0 == 180000, 'C3. la caisse du ministere est creditee de 180 000 FR, UNE fois',
         solde_caisse() - s0)
verifier(oks and oks[0].get('solde') == 179000 and oks[0].get('acompte') == 1000,
         'C4. acompte de 1 000 FR deduit : solde reclame 179 000, total paye 180 000',
         oks[0] if oks else '')
verifier(proprietaire(IMP_A) == 'zzAcheteurA', 'C5. propriete transferee a l acheteur', proprietaire(IMP_A))

# ---------------------------------------------------------------- 2. ACHETEURS CONCURRENTS (ids differents)
IMP_B = 'imprimerie-zztestpays-villeb-la-tribune'
s1 = solde_caisse()
with ThreadPoolExecutor(max_workers=8) as ex:
    res2 = list(ex.map(lambda i: cession('zzhttp-concurrent-%02d' % i, 'zzAcheteurB', IMP_B), range(8)))
oks2 = [r for r in res2 if isinstance(r, dict) and r.get('ok') is True]
refus = [r for r in res2 if isinstance(r, dict) and r.get('raison') == 'deja_vendue']
verifier(len(oks2) == 1, 'C6. 8 finalisations simultanees, ids differents : une seule aboutit', len(oks2))
verifier(len(refus) == 7, 'C7. les 7 autres sont refusees (bien deja vendu), sans effet',
         json.dumps([r.get('raison') or 'ok' for r in res2]))
verifier(solde_caisse() - s1 == 180000, 'C8. un seul credit de 180 000 FR, aucun credit partiel ni double',
         solde_caisse() - s1)
verifier(proprietaire(IMP_B) == 'zzAcheteurB', 'C9. propriete transferee une fois', proprietaire(IMP_B))

# ---------------------------------------------------------------- 3. PRIX NON NEGOCIABLE COTE CLIENT
r = rpc('imprimerie_cession_finaliser', {'p_requete': 'zzhttp-prixbas-001', 'p_acheteur': 'zzAcheteurC',
                                         'p_imprimerie_id': IMP_A, 'p_prix': 1, 'p_jour': 12})
verifier(isinstance(r, dict) and r.get('raison') == 'prix_invalide',
         'C10. un client ne peut pas imposer un prix inferieur', r)
verifier(solde_caisse() - s1 == 180000, 'C11. aucun mouvement de caisse sur ce refus', solde_caisse() - s1)

print('\n%d controle(s), %d echec(s)' % (12, len(echecs)))
sys.exit(1 if echecs else 0)
