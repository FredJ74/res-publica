# -*- coding: utf-8 -*-
"""Banc « Fabriquer un scandale » et « Corrompre un journaliste » : appels HTTP reels (cle anon).

Donnees de test en pays 'zzpresse', supprimees en fin d'execution. Les tables scandales_presse,
scandales_tentatives, corruptions_presse et chronique_nationale n'accordent que le SELECT a anon :
APRES CHAQUE EXECUTION, purger par MCP :
    DELETE FROM public.scandales_presse      WHERE auteur LIKE 'zz%' OR cible LIKE 'zz%';
    DELETE FROM public.scandales_tentatives  WHERE auteur LIKE 'zz%';
    DELETE FROM public.corruptions_presse    WHERE corrupteur LIKE 'zz%';
    DELETE FROM public.chronique_nationale   WHERE type = 'scandale_presse' AND (data->>'cible') LIKE 'zz%';
    DELETE FROM public.assemblee_requetes    WHERE id LIKE 'zz%';
    DELETE FROM public.actions_tracables     WHERE auteur LIKE 'zz%';
    DELETE FROM public.jugements             WHERE id LIKE 'zz%';
    DELETE FROM public.detentions            WHERE id LIKE 'zz%';
"""
import json, urllib.request, concurrent.futures, time

URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co'
KEY = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZ'
       'SI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw')
H = {'Content-Type': 'application/json', 'apikey': KEY, 'Authorization': 'Bearer ' + KEY}
echecs = 0


def rpc_brut(n, p):
    r = urllib.request.Request(URL + '/rest/v1/rpc/' + n, data=json.dumps(p).encode(), headers=H, method='POST')
    with urllib.request.urlopen(r, timeout=30) as x:
        return json.loads(x.read().decode())


def rpc(n, p):
    """Fonction scalaire : PostgREST renvoie la valeur, parfois enveloppee dans une liste."""
    v = rpc_brut(n, p)
    return v[0] if isinstance(v, list) and len(v) == 1 and isinstance(v[0], dict) else v


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
# scandales_tentatives garde une ligne par auteur et par jour, et anon n'a pas le droit de la
# supprimer : chaque execution utilise donc des personnages NEUFS, suffixes par l'horodatage.
SUF = str(TS)[-6:]
SCRIBE, TIERS = 'zzpresseScribe' + SUF, 'zzpresseTiers' + SUF
CIBLE, ACCUSE = 'zzpresseCible' + SUF, 'zzpresseAccuse' + SUF
NOMS = [SCRIBE, TIERS, CIBLE, ACCUSE]


def nettoyer():
    for n in NOMS:
        dele('personnages', 'name=eq.' + n)
    dele('jugements', 'id=like.zzpresse*')
    dele('detentions', 'id=like.zzpresse*')


nettoyer()
post('personnages', [
    {'name': SCRIBE, 'country': 'zzpresse', 'current_city': 'capitale', 'stats': {'CHA': 13},
     'resources': {'pop': 50, 'inf': 50}, 'inventory': [], 'pa': 90, 'liquide': 50000, 'banque': 0, 'career': 'press'},
    {'name': TIERS, 'country': 'zzpresse', 'current_city': 'capitale', 'stats': {'CHA': 13},
     'resources': {'pop': 50, 'inf': 50}, 'inventory': [], 'pa': 90, 'liquide': 50000, 'banque': 0, 'career': 'autre'},
    # PostgREST exige que toutes les lignes d'un lot portent EXACTEMENT les memes cles.
    {'name': CIBLE, 'country': 'zzpresse', 'current_city': 'capitale', 'stats': {'CHA': 13},
     'resources': {'pop': 70, 'inf': 60, 'dis': 50}, 'inventory': [], 'pa': 10, 'liquide': 0, 'banque': 0, 'career': 'autre'},
    {'name': ACCUSE, 'country': 'zzpresse', 'current_city': 'capitale', 'stats': {'CHA': 13},
     'resources': {'pop': 50, 'inf': 50, 'dis': 50}, 'inventory': [], 'pa': 10, 'liquide': 0, 'banque': 0, 'career': 'autre'},
])

# ---------------------------------------------------------------- FABRIQUER UN SCANDALE
# La limite « une tentative par jour et par auteur » impose d'utiliser plusieurs auteurs pour
# obtenir a coup sur une acceptation (taux 50 % avec la carriere presse).
AUTEURS = ['zzpresseAuteur%s%02d' % (SUF, i) for i in range(12)]
post('personnages', [{'name': n, 'country': 'zzpresse', 'current_city': 'capitale', 'stats': {'CHA': 13},
                      'resources': {'pop': 50, 'inf': 50}, 'inventory': [], 'pa': 90, 'liquide': 50000,
                      'banque': 0, 'career': 'press'} for n in AUTEURS])
NOMS.extend(AUTEURS)

r = rpc('scandale_tenter', {'p_requete': 'zzpresse-s1-%d' % TS, 'p_joueur': SCRIBE,
                            'p_cible': CIBLE, 'p_accusation': 'Il aurait vendu des faux permis.',
                            'p_malus_isn': 0})
verifier(r.get('ok') is True and 'accepte' in r,
         'S1. la redaction se prononce (accepte=%s, jet %s pour %s %%)' % (r.get('accepte'), r.get('jet'), r.get('taux')))
premier = r
refus = premier if premier.get('accepte') is False else None

# S2 : une seule tentative par jour, consommee meme en cas de refus
r2 = rpc('scandale_tenter', {'p_requete': 'zzpresse-s2-%d' % TS, 'p_joueur': SCRIBE,
                             'p_cible': CIBLE, 'p_accusation': 'Autre chose.', 'p_malus_isn': 0})
verifier(r2.get('raison') == 'deja_tente_aujourdhui',
         'S2. une seule tentative par jour et par auteur, consommee meme si la redaction refuse', json.dumps(r2))

# S3 : concurrence -- 8 demandes simultanees d'un autre auteur, une seule passe
def tenter(i):
    return rpc('scandale_tenter', {'p_requete': 'zzpresse-s3-%d-%d' % (i, TS), 'p_joueur': TIERS,
                                   'p_cible': CIBLE, 'p_accusation': 'Accusation concurrente.',
                                   'p_malus_isn': 0})
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
    res = list(ex.map(tenter, range(8)))
passes = sum(1 for x in res if x.get('ok') and x.get('raison') is None)
verifier(passes == 1, 'S3. 8 demandes simultanees du meme auteur : une seule tentative consommee', '%d passee(s)' % passes)

# S4 : publication d'une acceptation -> effets, auteur public, donnees de plainte
accepte = premier if premier.get('accepte') else next((x for x in res if x.get('accepte')), None)
if not accepte:
    for i, nom in enumerate(AUTEURS):
        x = rpc('scandale_tenter', {'p_requete': 'zzpresse-s4-%d-%d' % (i, TS), 'p_joueur': nom,
                                    'p_cible': CIBLE, 'p_accusation': 'Accusation numero %d.' % i,
                                    'p_malus_isn': 0})
        if x.get('accepte'):
            accepte = x
            break
        if x.get('accepte') is False and refus is None:
            refus = x
# Un refus est obtenu de facon fiable avec des auteurs sans bonus et un malus ISN maximal
# (taux = max(5, 35 - 25) = 10 %) : six auteurs distincts, un seul essai chacun par jour.
if refus is None:
    REFUSEURS = ['zzpresseRefus%s%02d' % (SUF, i) for i in range(6)]
    post('personnages', [{'name': n, 'country': 'zzpresse', 'current_city': 'capitale', 'stats': {'CHA': 13},
                          'resources': {'pop': 50, 'inf': 50}, 'inventory': [], 'pa': 90, 'liquide': 50000,
                          'banque': 0, 'career': 'autre'} for n in REFUSEURS])
    NOMS.extend(REFUSEURS)
    for i, nom in enumerate(REFUSEURS):
        x = rpc('scandale_tenter', {'p_requete': 'zzpresse-s3b-%d-%d' % (i, TS), 'p_joueur': nom,
                                    'p_cible': CIBLE, 'p_accusation': 'Accusation faible.', 'p_malus_isn': 25})
        if x.get('accepte') is False:
            refus = x
            break
verifier(refus is not None and refus.get('pa') is None and refus.get('cout') is None
         and refus.get('scandale_id') is None,
         'S3 bis. refus de la redaction : aucun PA ni FR annonce, aucun scandale cree',
         json.dumps(refus) if refus else 'aucun refus obtenu')
if accepte:
    av = get('personnages', 'name=eq.' + CIBLE + '&select=resources')[0]['resources']
    pub = rpc('scandale_publier', {'p_scandale_id': accepte['scandale_id'], 'p_article': 'Article de test.'})
    ap = get('personnages', 'name=eq.' + CIBLE + '&select=resources')[0]['resources']
    lig = get('scandales_presse', 'id=eq.%d&select=*' % accepte['scandale_id'])[0]
    ch = get('chronique_nationale', 'id=eq.' + str(pub.get('chronique_id')) + '&select=data,personnages,libelle')
    verifier(ap['pop'] == av['pop'] - 15 and ap['inf'] == av['inf'] - 15 and ap.get('dis') == av.get('dis'),
             'S4. publication : POP -15 et INF -15 sur la cible, aucune autre ressource touchee',
             'avant=%s apres=%s' % (json.dumps(av), json.dumps(ap)))
    verifier(ch and ch[0]['data'].get('auteur_public') == lig['auteur'] and lig['auteur'] in json.dumps(ch[0]),
             'S5. auteur PUBLIC : le nom du commanditaire figure dans la publication')
    verifier(all(lig.get(k) for k in ('auteur', 'cible', 'accusation', 'article', 'chronique_id', 'jour_paris', 'cree_le'))
             and lig['type_contenu'] == 'kompromat' and lig['statut'] == 'publie' and lig['plainte_ref'] is None,
             'S6. plainte future : identifiant, auteur, cible, date, accusation, article, reference, statut')
    pub2 = rpc('scandale_publier', {'p_scandale_id': accepte['scandale_id'], 'p_article': 'Autre texte.'})
    ap2 = get('personnages', 'name=eq.' + CIBLE + '&select=resources')[0]['resources']
    verifier(pub2.get('rejeu') is True and ap2['pop'] == ap['pop'] and ap2['inf'] == ap['inf'],
             'S7. republication : aucun second effet POP/INF, aucun doublon de chronique')
    verifier(isinstance(pub.get('total_auteur'), int) and pub['total_auteur'] >= 1,
             'S8. compteur de carriere : %s scandale(s) publie(s) par cet auteur' % pub.get('total_auteur'))
else:
    verifier(False, 'S4-S8. aucune acceptation obtenue en 9 tentatives (aleatoire defavorable)')

# S9 : aucun mandat, aucune detection automatique
rech = get('personnages', 'name=eq.' + SCRIBE + '&select=recherche')[0]['recherche']
verifier(not rech, 'S9. aucun mandat ni detection automatique pour l auteur', json.dumps(rech))

# ---------------------------------------------------------------- CORROMPRE UN JOURNALISTE
post('jugements', [{'id': 'zzpresse-jug-%d' % TS, 'country': 'zzpresse', 'city': 'capitale',
                    'accuse': ACCUSE, 'motif': 'corruption', 'peine': '3 jours',
                    'juge': 'zzJuge', 'jour': 4, 'executee': True}])
AFF = 'jugements:zzpresse-jug-%d' % TS
affaires = rpc_brut('corruption_presse_affaires', {'p_pays': 'zzpresse'})
verifier(any(a['affaire_ref'] == AFF for a in affaires),
         'C1. l affaire judiciaire du jour est proposee a la corruption', '%d affaire(s)' % len(affaires))

r = rpc('corruption_presse_tenter', {'p_requete': 'zzpresse-c2-%d' % TS, 'p_joueur': SCRIBE,
                                     'p_affaire_ref': AFF, 'p_option': 'etouffer', 'p_malus_isn': 0})
verifier(r.get('taux') == 55, 'C2. formule 30 + CHA 13 + floor(INF 50/4) = 55 %%', 'taux=%s' % r.get('taux'))
verifier(r.get('ok') is True and (
    (r.get('reussi') and r.get('pa') == 2 and r.get('cout') == 500) or
    (not r.get('reussi') and r.get('pa') == 0 and r.get('cout') == 0)),
    'C3. cout annonce : %s PA et %s FR selon l issue (%s)' % (r.get('pa'), r.get('cout'), 'accord' if r.get('reussi') else 'refus'))

tr = get('corruptions_presse', 'affaire_ref=eq.' + AFF + '&corrupteur=eq.' + SCRIBE + '&select=*')
act = get('actions_tracables', 'auteur=eq.' + SCRIBE + '&select=type_action,cible')
verifier(len(tr) == 1 and tr[0]['affaire_pj'] == ACCUSE and tr[0]['option'] == 'etouffer'
         and tr[0]['jour_paris'] and any('corruption_presse' in a['type_action'] for a in act),
         'C4. trace enregistree (reussite=%s) : corrupteur, affaire, PJ, option, date, issue' % tr[0]['reussite'])

r2 = rpc('corruption_presse_tenter', {'p_requete': 'zzpresse-c5-%d' % TS, 'p_joueur': SCRIBE,
                                      'p_affaire_ref': AFF, 'p_option': 'favorable', 'p_malus_isn': 0})
verifier(r2.get('raison') == 'deja_tente', 'C5. une seule tentative par affaire et par corrupteur')

r3 = rpc('corruption_presse_tenter', {'p_requete': 'zzpresse-c6-%d' % TS, 'p_joueur': TIERS,
                                      'p_affaire_ref': AFF, 'p_option': 'favorable', 'p_malus_isn': 0})
verifier(r3.get('ok') is True and r3.get('raison') is None, 'C6. un autre PJ peut tenter sur la meme affaire')

etat = rpc_brut('corruption_presse_etat', {'p_affaire_ref': AFF})
reussies = [t for t in get('corruptions_presse', 'affaire_ref=eq.' + AFF + '&select=option,reussite') if t['reussite']]
attendu = None
if any(t['option'] == 'etouffer' for t in reussies):
    attendu = 'etouffee'
elif any(t['option'] == 'favorable' for t in reussies):
    attendu = 'favorable'
verifier(etat == attendu, 'C7. etat editorial lisible par la collecte : %s' % (etat or 'traitement normal'))

jug = get('jugements', 'id=eq.zzpresse-jug-%d&select=motif,peine,executee' % TS)[0]
verifier(jug['motif'] == 'corruption' and jug['peine'] == '3 jours' and jug['executee'] is True,
         'C8. le dossier judiciaire est strictement inchange')

def concurrent_tenter(i):
    return rpc('corruption_presse_tenter', {'p_requete': 'zzpresse-c9-%d-%d' % (i, TS), 'p_joueur': TIERS,
                                            'p_affaire_ref': AFF, 'p_option': 'etouffer', 'p_malus_isn': 0})
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
    res9 = list(ex.map(concurrent_tenter, range(6)))
n9 = len(get('corruptions_presse', 'affaire_ref=eq.' + AFF + '&corrupteur=eq.' + TIERS + '&select=id'))
verifier(n9 == 1, 'C9. 6 demandes simultanees du meme corrupteur : une seule trace', '%d trace(s)' % n9)

r10 = rpc('corruption_presse_tenter', {'p_requete': 'zzpresse-c10-%d' % TS, 'p_joueur': SCRIBE,
                                       'p_affaire_ref': 'jugements:inexistant', 'p_option': 'etouffer', 'p_malus_isn': 0})
verifier(r10.get('raison') == 'affaire_non_eligible', 'C10. affaire inconnue ou deja publiee : non eligible')

nettoyer()
restes = len(get('personnages', 'name=like.zzpresse*&select=name'))
verifier(restes == 0, 'C11. personnages de test supprimes (tables presse purgees par MCP)', '%d residu(s)' % restes)

print('\n%d test(s), %d echec(s)' % (18, echecs))
print("RAPPEL : purger scandales_presse, scandales_tentatives, corruptions_presse, chronique_nationale,")
print("         actions_tracables, jugements, detentions et assemblee_requetes (prefixe zz) par MCP.")
raise SystemExit(1 if echecs else 0)
