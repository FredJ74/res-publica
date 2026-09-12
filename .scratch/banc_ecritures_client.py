# -*- coding: utf-8 -*-
"""Fumigation des ECRITURES CLIENTES reelles (HTTP, cle anon exactement comme le navigateur).

Raison d'etre : le 12 septembre 2026, un trigger pose sur cycles_electoraux appelait une fonction
dont l'EXECUTE etait revoque a anon. Une fonction de trigger s'executant avec les droits de celui
qui ecrit, TOUTE creation ou sauvegarde de cycle electoral depuis le navigateur echouait en
  42501 : permission denied for function cycle_electoral_aligne_dimanche
sans qu'aucun test cote base ne le voie (en SQL direct, le proprietaire a tous les droits).

Ce banc ecrit donc comme le client, avec la meme cle, sur des donnees de test dediees (prefixe zz)
qu'il supprime ensuite.
"""
import json, urllib.request, time, datetime, zoneinfo

URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co'
KEY = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZ'
       'SI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw')
H = {'Content-Type': 'application/json', 'apikey': KEY, 'Authorization': 'Bearer ' + KEY, 'Prefer': 'return=representation'}
echecs = 0


def req(methode, chemin, corps=None):
    r = urllib.request.Request(URL + '/rest/v1/' + chemin,
                               data=json.dumps(corps).encode() if corps is not None else None,
                               headers=H, method=methode)
    try:
        return 200, urllib.request.urlopen(r, timeout=30).read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def verifier(ok, texte, detail=''):
    global echecs
    print(('OK    ' if ok else 'ECHEC ') + texte + ('   [' + detail + ']' if detail else ''))
    if not ok:
        echecs += 1


ts = int(time.time() * 1000)
req('DELETE', 'cycles_electoraux?id=eq.zzclient_maire_capitale')
req('DELETE', 'personnages?name=eq.zzclientPJ')
req('DELETE', 'batiments_etat?id=eq.zzclient_capitale_la-tribune')

# 1. Creation d'un cycle electoral (initCycleElectoral -> sbSaveCycleElectoral)
cycle = {'posteId': 'maire', 'city': 'capitale', 'phase': 'candidatures', 'dateDebutCandidatures': ts,
         'dateDebutCampagne': ts + 3600000, 'dateVote': ts + 7 * 86400000, 'dateResultats': ts + 8 * 86400000,
         'candidats': [], 'votes': {}, 'votesPNJ': {}}
c, b = req('POST', 'cycles_electoraux', [{'id': 'zzclient_maire_capitale', 'country': 'zzclient',
                                          'poste_id': 'maire', 'city': 'capitale', 'data': json.dumps(cycle)}])
verifier(c == 200, 'E1. le client peut CREER un cycle electoral', 'HTTP %d %s' % (c, b[:90]))

# 2. Sauvegarde du meme cycle (toute action electorale passe par la)
cycle['phase'] = 'campagne'
c, b = req('PATCH', 'cycles_electoraux?id=eq.zzclient_maire_capitale', {'data': json.dumps(cycle)})
verifier(c == 200, 'E2. le client peut SAUVEGARDER un cycle electoral', 'HTTP %d %s' % (c, b[:90]))

# 3. Le trigger de calendrier fait toujours son travail au passage
c, b = req('GET', 'cycles_electoraux?id=eq.zzclient_maire_capitale&select=data')
jour = ''
if c == 200 and b.strip() != '[]':
    d = json.loads(json.loads(b)[0]['data'])
    dt = datetime.datetime.fromtimestamp(d['dateVote'] / 1000, zoneinfo.ZoneInfo('Europe/Paris'))
    jour = dt.strftime('%A %d/%m %H:%M')
    verifier(dt.isoweekday() == 7 and (dt.hour, dt.minute) == (0, 1),
             'E3. le trigger aligne toujours le vote sur le dimanche 00:01', jour)
else:
    verifier(False, 'E3. relecture du cycle', 'HTTP %d' % c)

# 4. Sauvegarde d'un personnage (sbSavePersonnage), avec popBase/infBase : les deltas sont fusionnes
c, b = req('POST', 'personnages', [{'name': 'zzclientPJ', 'country': 'zzclient', 'current_city': 'capitale',
                                    'stats': {'CHA': 10}, 'resources': {'pop': 50, 'inf': 20}, 'inventory': [], 'pa': 10}])
verifier(c == 200, 'E4. le client peut CREER un personnage', 'HTTP %d %s' % (c, b[:90]))
c, b = req('PATCH', 'personnages?name=eq.zzclientPJ', {'resources': {'pop': 55, 'popBase': 50, 'inf': 18, 'infBase': 20}})
apres = json.loads(b)[0]['resources'] if c == 200 else {}
verifier(c == 200 and apres.get('pop') == 55 and apres.get('inf') == 18
         and 'popBase' not in apres and 'infBase' not in apres,
         'E5. sauvegarde en delta : POP et INF fusionnees, popBase/infBase jamais stockees', json.dumps(apres))

# 5. Ecriture d'un etat de batiment (caisses, stocks)
c, b = req('POST', 'batiments_etat', [{'id': 'zzclient_capitale_la-tribune', 'country': 'zzclient', 'city': 'capitale',
                                       'building_id': 'la-tribune', 'data': json.dumps({'imprimerie': {'caisse': 10}})}])
verifier(c == 200, 'E6. le client peut ECRIRE un etat de batiment', 'HTTP %d %s' % (c, b[:90]))

# 6. Nettoyage
req('DELETE', 'cycles_electoraux?id=eq.zzclient_maire_capitale')
req('DELETE', 'personnages?name=eq.zzclientPJ')
req('DELETE', 'batiments_etat?id=eq.zzclient_capitale_la-tribune')
restes = sum(len(json.loads(req('GET', p)[1])) for p in (
    'cycles_electoraux?id=eq.zzclient_maire_capitale&select=id',
    'personnages?name=eq.zzclientPJ&select=name',
    'batiments_etat?id=eq.zzclient_capitale_la-tribune&select=id'))
verifier(restes == 0, 'E7. donnees de test supprimees', '%d residu(s)' % restes)

print('\n7 test(s), %d echec(s)' % echecs)
raise SystemExit(1 if echecs else 0)
