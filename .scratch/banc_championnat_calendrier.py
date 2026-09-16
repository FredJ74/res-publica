# BANC — CALENDRIER DU CHAMPIONNAT, VERROU SERVEUR (16 septembre 2026).
#
# Ne du mail/compte rendu apparu le mercredi 16 septembre a 00h38, alors que le contrat de jeu
# est : UNE journee par semaine, le DIMANCHE a 20:00, une seule fois.
#
# Le championnat n'a aucun moteur serveur -- ce sont les navigateurs qui le font avancer. Le
# calendrier ne pouvait donc etre verifie que par du JavaScript, qu'un onglet ancien ne contient
# pas. Le banc mesure le verrou qui vit desormais dans la base, la ou aucun client ne passe a
# cote : il attaque comme un client (cle anon, session anonyme), pas en service_role.
#
# L'HORLOGE EST CONTROLEE par la semaine de reference de chaque ligne de test : l'echeance est
# calculee par le serveur comme le dimanche 20h de la semaine SUIVANT la derniere resolution.
# Poser cette semaine, c'est donc placer le scenario avant ou apres l'echeance, sans toucher a
# l'horloge de la machine.
#
# Donnees : des lignes championnat 99xx et des sujets de forum zztest, cree(e)s et supprime(e)s
# par la passe. La ligne reelle (id=2) n'est jamais ecrite.

import datetime, json, os, re, sys, time, urllib.error, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(RACINE, '.scratch/banc_entrepots_commandes.py'), encoding='utf-8').read()
URL = re.search(r'URL = "([^"]+)"', SRC).group(1)
BLOC = SRC[SRC.index('ANON = ('):SRC.index('SUF =')]
ANON = ''.join(re.findall(r'"([^"]*)"', BLOC))

JOUEUR_PRIME = 'zztest-prime-' + str(int(time.time()))
LIGNES = []          # ids de championnat crees par le banc
TOPICS = []          # sujets de forum crees par le banc, retires en fin de passe
resultats = []
JETON = None


def http(method, path, body=None, token=None, prefer=None):
    req = urllib.request.Request(URL + path, method=method)
    req.add_header('apikey', ANON)
    req.add_header('Authorization', 'Bearer ' + (token or ANON))
    if prefer:
        req.add_header('Prefer', prefer)
    data = None
    if body is not None:
        req.add_header('Content-Type', 'application/json')
        data = json.dumps(body).encode()
    try:
        with urllib.request.urlopen(req, data, timeout=40) as r:
            t = r.read().decode()
            return r.status, (json.loads(t) if t.strip() else None)
    except urllib.error.HTTPError as e:
        t = e.read().decode()
        try:
            return e.code, json.loads(t)
        except Exception:
            return e.code, t


def verifier(nom, cond, detail=''):
    resultats.append((bool(cond), nom, str(detail)[:160]))


def session():
    for _ in range(8):
        c, b = http('POST', '/auth/v1/signup', {})
        if c == 200 and isinstance(b, dict) and b.get('access_token'):
            return b['access_token']
        time.sleep(12)
    print('ABANDON : session anonyme impossible (limitation de debit).')
    sys.exit(2)


def semaine_iso(decalage_semaines):
    """Cle 'YYYY-Www' de la semaine ISO decalee de N semaines par rapport a aujourd'hui."""
    d = datetime.date.today() + datetime.timedelta(weeks=decalage_semaines)
    an, sem, _ = d.isocalendar()
    return '%04d-W%02d' % (an, sem)


def match(home, away, joue, bh=None, ba=None):
    m = {'home': home, 'away': away, 'played': joue}
    if joue:
        m.update({'scoreHome': bh, 'scoreAway': ba,
                  'recit': '%s s\'impose %d-%d face à %s' % (home, bh, ba, away)})
    return m


def creer_ligne(ident, semaine, matchs, journee=1, numero=1, extra=None):
    """Cree une ligne de championnat de test. L'INSERT n'est pas soumis au verrou : c'est le
       decor du scenario, pas une tentative de resolution."""
    LIGNES.append(ident)
    http('DELETE', '/rest/v1/championnat?id=eq.%d' % ident, token=JETON)
    data = {'schemaVersion': 2, 'numero': numero, 'phase': 'reguliere',
            'derniereSemaineResolue': semaine,
            'calendrier': [{'numero': journee, 'matchs': matchs}]}
    data.update(extra or {})
    c, b = http('POST', '/rest/v1/championnat', {'id': ident, 'data': data},
                token=JETON, prefer='return=representation')
    return c


def lire(ident):
    c, b = http('GET', '/rest/v1/championnat?select=data&id=eq.%d' % ident)
    return (b[0]['data'] if b else None)


def ecrire(ident, data):
    return http('PATCH', '/rest/v1/championnat?id=eq.%d' % ident, {'data': data},
                token=JETON, prefer='return=representation')


def joue(ident, journee=0, idx=0):
    d = lire(ident)
    return bool(d['calendrier'][journee]['matchs'][idx].get('played')) if d else None


M_A = ('olympique-luthecia', 'sharq-al-nour')
M_B = ('brise-mariannaise', 'al-baraka-fc')


def main():
    global JETON
    print('Ouverture de la session...')
    JETON = session()

    # ============ 1. AVANT L ECHEANCE : LE CAS DU 16 SEPTEMBRE ============
    # Derniere resolution dans la semaine EN COURS -> l'echeance est le dimanche 20h de la
    # semaine prochaine. Tout instant d'ici la -- mercredi 00h38 compris -- est un refus.
    creer_ligne(9901, semaine_iso(0), [match(*M_A, False), match(*M_B, False)])
    d = lire(9901)
    d['calendrier'][0]['matchs'][0].update(
        {'played': True, 'scoreHome': 4, 'scoreAway': 3, 'recit': 'fantome'})
    d['derniereSemaineResolue'] = semaine_iso(0)
    c, b = ecrire(9901, d)
    verifier('avant le dimanche 20h : la resolution est refusee', joue(9901) is False,
             'HTTP %s / joue=%s' % (c, joue(9901)))
    verifier('et la requete ne modifie aucune ligne', b in (None, []), b)

    # ============ 2. A PARTIR DU DIMANCHE 20h ============
    # Derniere resolution il y a deux semaines -> l'echeance (dimanche 20h de la semaine
    # suivante) est passee : la journee due peut etre jouee, y compris en rattrapage.
    creer_ligne(9902, semaine_iso(-2), [match(*M_A, False), match(*M_B, False)])
    d = lire(9902)
    d['calendrier'][0]['matchs'][0].update(
        {'played': True, 'scoreHome': 2, 'scoreAway': 1, 'recit': 'match regulier'})
    d['derniereSemaineResolue'] = semaine_iso(0)
    c, b = ecrire(9902, d)
    verifier('apres l echeance : la resolution est acceptee', joue(9902) is True,
             'HTTP %s / joue=%s' % (c, joue(9902)))

    # ============ 3. UNE SEULE FOIS ============
    # La ligne 9902 porte desormais la semaine courante : la journee suivante est hors creneau.
    d = lire(9902)
    d['calendrier'][0]['matchs'][1].update(
        {'played': True, 'scoreHome': 5, 'scoreAway': 0, 'recit': 'deuxieme match de la semaine'})
    c, b = ecrire(9902, d)
    verifier('pas de seconde resolution dans la meme semaine',
             joue(9902, idx=1) is False, 'joue=%s' % joue(9902, idx=1))

    # ============ 4. UN MATCH JOUE EST DEFINITIF ============
    d = lire(9902)
    d['calendrier'][0]['matchs'][0]['scoreHome'] = 9
    c, b = ecrire(9902, d)
    verifier('le score d un match joue ne se reecrit pas',
             lire(9902)['calendrier'][0]['matchs'][0]['scoreHome'] == 2,
             lire(9902)['calendrier'][0]['matchs'][0]['scoreHome'])

    d = lire(9902)
    d['calendrier'][0]['matchs'][0]['played'] = False
    c, b = ecrire(9902, d)
    verifier('un match joue ne redevient pas a jouer', joue(9902) is True, joue(9902))

    # ============ 5. LE MARQUEUR DE SEMAINE NE RECULE PAS ============
    d = lire(9902)
    d['derniereSemaineResolue'] = semaine_iso(-5)
    c, b = ecrire(9902, d)
    verifier('la semaine resolue ne peut pas etre ramenee en arriere',
             lire(9902)['derniereSemaineResolue'] == semaine_iso(0),
             lire(9902)['derniereSemaineResolue'])

    # ============ 6. LE JEU ORDINAIRE CONTINUE DE FONCTIONNER ============
    # Progression minute par minute, compositions, boycott : aucun match ne change d'etat, donc
    # rien a arbitrer. Un verrou qui bloquerait cela arreterait le jeu.
    d = lire(9902)
    d['calendrier'][0]['matchs'][1]['live'] = {'statut': 'mt1', 'minuteGeneree': 23,
                                               'scoreHome': 0, 'scoreAway': 0}
    d['calendrier'][0]['matchs'][1]['boycotte'] = True
    c, b = ecrire(9902, d)
    apres = lire(9902)['calendrier'][0]['matchs'][1]
    verifier('la progression live d un match en cours passe',
             (apres.get('live') or {}).get('minuteGeneree') == 23, apres.get('live'))
    verifier('le boycott passe aussi', apres.get('boycotte') is True, apres.get('boycotte'))

    # ============ 7. COURSE ENTRE CLIENTS ============
    # Deux navigateurs revendiquent la meme journee avec la meme version : un seul gagne.
    creer_ligne(9903, semaine_iso(-2), [match(*M_A, False)])
    c, b = http('GET', '/rest/v1/championnat?select=data,updated_at&id=eq.9903')
    version = b[0]['updated_at']
    d = b[0]['data']
    d['calendrier'][0]['matchs'][0].update(
        {'played': True, 'scoreHome': 1, 'scoreAway': 0, 'recit': 'course'})
    d['derniereSemaineResolue'] = semaine_iso(0)
    # Reproduction fidele de ecrireChampionnatCAS : PATCH conditionne sur la version lue au
    # debut du tick. Les trois clients sont partis de la MEME version.
    gagnants = 0
    for _ in range(3):
        c, rep = http('PATCH',
                      '/rest/v1/championnat?id=eq.9903&updated_at=eq.'
                      + urllib.request.quote(str(version)),
                      {'data': d, 'updated_at': datetime.datetime.utcnow().isoformat()},
                      token=JETON, prefer='return=representation')
        if rep:
            gagnants += 1
    verifier('trois clients revendiquent la meme journee : un seul gagne', gagnants == 1,
             '%d gagnant(s)' % gagnants)

    # ============ 8. LA PUBLICATION DU COMPTE RENDU ============
    c, b = http('POST', '/rest/v1/rpc/championnat_publier_journee', {'p_journee': 99},
                token=JETON)
    r = b[0] if isinstance(b, list) and b else b
    verifier('une journee inconnue n a pas de compte rendu',
             r and r.get('ok') is False and r.get('raison') == 'journee_inconnue', r)

    c, b = http('POST', '/rest/v1/rpc/championnat_publier_journee', {'p_journee': 5},
                token=JETON)
    r = b[0] if isinstance(b, list) and b else b
    verifier('une journee non jouee non plus',
             r and r.get('ok') is False and r.get('raison') == 'journee_non_jouee', r)

    # La journee 4 EST jouee en base : elle a deja son sujet, publie le 13 septembre. La RPC ne
    # doit pas en creer un second (idempotence).
    c, avant = http('GET', '/rest/v1/forum_topics?select=id&author=eq.Ligue%20Officielle')
    c, b = http('POST', '/rest/v1/rpc/championnat_publier_journee', {'p_journee': 4},
                token=JETON)
    r = b[0] if isinstance(b, list) and b else b
    c, apres_pub = http('GET', '/rest/v1/forum_topics?select=id&author=eq.Ligue%20Officielle')
    verifier('publier une journee deja jouee ne cree pas de doublon',
             r and r.get('ok') is True
             and len(apres_pub or []) == len(avant or []) + (0 if r.get('deja_publie') else 1),
             '%d -> %d (deja=%s)' % (len(avant or []), len(apres_pub or []), r.get('deja_publie')))
    # Le sujet produit par la RPC est retire en fin de passe, qu'il vienne d'etre cree ou
    # qu'une passe precedente l'ait laisse : le forum des joueurs ne garde rien du banc.
    TOPICS.append((r or {}).get('topic_id'))
    c, b = http('POST', '/rest/v1/rpc/championnat_publier_journee', {'p_journee': 4},
                token=JETON)
    r = b[0] if isinstance(b, list) and b else b
    c, encore = http('GET', '/rest/v1/forum_topics?select=id&author=eq.Ligue%20Officielle')
    verifier('et la republier non plus',
             r and r.get('deja_publie') is True and len(encore or []) == len(apres_pub or []), r)

    # ============ 9. LE CHEMIN EXACT DU 16 SEPTEMBRE ============
    # Un onglet fantome publie directement son compte rendu, sans rien avoir ecrit en base.
    fantome = 'zztest-topic-fantome-' + str(int(time.time()))
    c, b = http('POST', '/rest/v1/forum_topics', {
        'id': fantome, 'forum_id': 'sport', 'title': 'Journée 1 — Saison 1',
        'author': 'Ligue Officielle', 'country': 'republic', 'time': '16/09/2026 · 00h38',
        'views': 1, 'replies': 0, 'last_post_author': 'Ligue Officielle',
        'last_post_time': '16/09/2026 · 00h38'}, token=JETON)
    c2, present = http('GET', '/rest/v1/forum_topics?select=id&id=eq.' + fantome)
    verifier('un client ne publie plus lui-meme un compte rendu de journee',
             present == [], 'HTTP %s / %s' % (c, present))

    c, b = http('POST', '/rest/v1/forum_posts', {
        'id': fantome + '-post', 'topic_id': fantome, 'author': 'Ligue Officielle',
        'content': 'Olympique de Luthécia s\'impose 4-3 face à Sharq Al-Nour.',
        'time': '16/09/2026 · 00h38'}, token=JETON)
    c2, present = http('GET', '/rest/v1/forum_posts?select=id&id=eq.' + fantome + '-post')
    verifier('et son message ne reste pas orphelin', present == [], 'HTTP %s / %s' % (c, present))

    # Les sujets ordinaires des joueurs continuent de passer.
    ordinaire = 'zztest-topic-ordinaire-' + str(int(time.time()))
    http('POST', '/rest/v1/forum_topics', {
        'id': ordinaire, 'forum_id': 'local', 'title': 'Journée de folie au marché',
        'author': 'zztest Joueur', 'country': 'republic', 'time': 'x', 'views': 1, 'replies': 0,
        'last_post_author': 'zztest Joueur', 'last_post_time': 'x'}, token=JETON)
    c, present = http('GET', '/rest/v1/forum_topics?select=id&id=eq.' + ordinaire)
    verifier('un sujet ordinaire de joueur passe toujours', present != [], present)
    http('DELETE', '/rest/v1/forum_topics?id=eq.' + ordinaire, token=JETON)

    # ============ 11. PHASES FINALES : LA MEME AUTORITE ============
    # Les playoffs vivent dans data.playoffs, hors du calendrier : c'est pour cela qu'ils
    # echappaient encore au verrou. Le tableau, les qualifications et les scores restent ceux du
    # jeu -- seule l'autorite change de camp.
    def tableau(etape, avec_resultats=True):
        t = {'etape': etape, 'prochainKickoffISO': '2026-01-01T19:00:00.000Z',
             'quarts': {'paires': [['a', 'b']], 'aller': None, 'retour': None, 'vainqueurs': None},
             'demies': {'paires': None, 'aller': None, 'retour': None, 'vainqueurs': None},
             'finale': {'paire': ['a', 'b'], 'resultat': None}}
        if avec_resultats:
            t['quarts']['aller'] = [{'home': 'a', 'away': 'b', 'scoreHome': 2, 'scoreAway': 1,
                                     'recit': 'Quart aller'}]
        return t

    # (a) trop tot : la semaine courante est deja consommee -> l'echeance est la semaine prochaine
    creer_ligne(9904, semaine_iso(0), [match(*M_A, True, 1, 0)],
                extra={'playoffs': tableau('quarts_aller')})
    d = lire(9904); d['playoffs']['etape'] = 'quarts_retour'
    d['playoffs']['quarts']['retour'] = [{'home': 'b', 'away': 'a', 'recit': 'Quart retour'}]
    d['derniereSemaineResolue'] = semaine_iso(0)
    c, b = ecrire(9904, d)
    verifier('playoff avant l echeance : le tour ne tombe pas',
             lire(9904)['playoffs']['etape'] == 'quarts_aller', lire(9904)['playoffs']['etape'])

    # (b) a l'heure : le tour tombe
    creer_ligne(9905, semaine_iso(-2), [match(*M_A, True, 1, 0)],
                extra={'playoffs': tableau('quarts_aller'), 'palmares': []})
    d = lire(9905); d['playoffs']['etape'] = 'quarts_retour'
    d['playoffs']['quarts']['retour'] = [{'home': 'b', 'away': 'a', 'recit': 'Quart retour'}]
    d['derniereSemaineResolue'] = semaine_iso(0)
    c, b = ecrire(9905, d)
    verifier('playoff a l echeance : le tour est joue',
             lire(9905)['playoffs']['etape'] == 'quarts_retour', lire(9905)['playoffs']['etape'])

    # (c) le meme tour ne retombe pas dans la foulee
    d = lire(9905); d['playoffs']['etape'] = 'demies_aller'
    d['playoffs']['demies']['aller'] = [{'recit': 'Demie aller'}]
    c, b = ecrire(9905, d)
    verifier('pas deux tours dans la meme semaine',
             lire(9905)['playoffs']['etape'] == 'quarts_retour', lire(9905)['playoffs']['etape'])

    # (d) on ne saute pas un tour, on ne revient pas en arriere
    creer_ligne(9906, semaine_iso(-2), [match(*M_A, True, 1, 0)],
                extra={'playoffs': tableau('quarts_aller')})
    d = lire(9906); d['playoffs']['etape'] = 'finale'
    c, b = ecrire(9906, d)
    verifier('un tour ne peut pas etre saute',
             lire(9906)['playoffs']['etape'] == 'quarts_aller', lire(9906)['playoffs']['etape'])
    d = lire(9906); d['playoffs']['etape'] = 'termine'
    c, b = ecrire(9906, d)
    verifier('on ne se declare pas directement termine',
             lire(9906)['playoffs']['etape'] == 'quarts_aller', lire(9906)['playoffs']['etape'])

    # (e) une manche acquise est definitive
    d = lire(9906)
    d['playoffs']['quarts']['aller'] = [{'home': 'a', 'away': 'b', 'scoreHome': 9, 'scoreAway': 0,
                                         'recit': 'Quart aller refait'}]
    c, b = ecrire(9906, d)
    verifier('le resultat d une manche jouee ne se reecrit pas',
             lire(9906)['playoffs']['quarts']['aller'][0]['scoreHome'] == 2,
             lire(9906)['playoffs']['quarts']['aller'][0])

    # (f) un champion proclame le reste, et le palmares ne se raccourcit pas
    creer_ligne(9907, semaine_iso(-2), [match(*M_A, True, 1, 0)],
                extra={'playoffs': tableau('termine'), 'phase': 'terminee',
                       'palmares': [{'saison': 1, 'champion': 'Dynamo Novomirsk'}],
                       'resultatsFinales': {'champion': 'dynamo-novomirsk',
                                            'stadeClubId': 'olympique-luthecia',
                                            'finale': {'recit': 'Finale'}}})
    d = lire(9907); d['resultatsFinales']['champion'] = 'rojos-cartel'
    c, b = ecrire(9907, d)
    verifier('un champion proclame ne change pas de nom',
             lire(9907)['resultatsFinales']['champion'] == 'dynamo-novomirsk',
             lire(9907)['resultatsFinales']['champion'])
    d = lire(9907); d['palmares'] = []
    c, b = ecrire(9907, d)
    verifier('le palmares ne se raccourcit pas', len(lire(9907)['palmares']) == 1,
             lire(9907)['palmares'])

    # (g) course entre clients sur un tour de playoff : un seul gagnant
    creer_ligne(9908, semaine_iso(-2), [match(*M_A, True, 1, 0)],
                extra={'playoffs': tableau('quarts_aller')})
    c, b = http('GET', '/rest/v1/championnat?select=data,updated_at&id=eq.9908')
    version, d = b[0]['updated_at'], b[0]['data']
    d['playoffs']['etape'] = 'quarts_retour'
    d['playoffs']['quarts']['retour'] = [{'recit': 'Quart retour'}]
    d['derniereSemaineResolue'] = semaine_iso(0)
    gagnants = 0
    for _ in range(3):
        c, rep = http('PATCH', '/rest/v1/championnat?id=eq.9908&updated_at=eq.'
                      + urllib.request.quote(str(version)),
                      {'data': d, 'updated_at': datetime.datetime.utcnow().isoformat()},
                      token=JETON, prefer='return=representation')
        if rep:
            gagnants += 1
    verifier('trois clients sur le meme tour de playoff : un seul gagne', gagnants == 1,
             '%d gagnant(s)' % gagnants)

    # ============ 12. LES COMMUNIQUES OFFICIELS ============
    for titre in ('Quarts de finale (aller) — Saison 1', '🏆 Sacre du champion — Saison 1',
                  'Journée 7 — Saison 1'):
        faux = 'zztest-officiel-' + str(int(time.time() * 1000))
        http('POST', '/rest/v1/forum_topics', {
            'id': faux, 'forum_id': 'sport', 'title': titre, 'author': 'Ligue Officielle',
            'country': 'republic', 'time': 'x', 'views': 1, 'replies': 0,
            'last_post_author': 'Ligue Officielle', 'last_post_time': 'x'}, token=JETON)
        c, present = http('GET', '/rest/v1/forum_topics?select=id&id=eq.' + faux)
        verifier('aucun client ne signe « %s »' % titre[:34], present == [], present)

    # Les RPC ne publient rien qui ne soit acquis en base (la saison reelle est en phase
    # reguliere : ni tour, ni sacre).
    for fn, params, attendu in (
            ('championnat_publier_tour', {'p_manche': 'quarts_aller'}, 'manche_non_jouee'),
            ('championnat_publier_tour', {'p_manche': 'finale_secrete'}, 'manche_inconnue'),
            ('championnat_publier_sacre', {}, 'sacre_non_acquis')):
        c, b = http('POST', '/rest/v1/rpc/' + fn, params, token=JETON)
        r = b[0] if isinstance(b, list) and b else b
        verifier('%s refuse : %s' % (fn.replace('championnat_publier_', ''), attendu),
                 r and r.get('ok') is False and r.get('raison') == attendu, r)

    # ============ 13. LES PRIMES DE MATCH ============
    # Le defaut d'origine : sbAppliquerSalaire creditait la fiche d'un AUTRE personnage. La vue
    # le refuse depuis le chantier B, et l'appel etait avale par un .catch() muet -- la prime
    # disparaissait sans bruit. Le versement passe desormais par le serveur ; ce bloc verifie
    # qu'un client ne peut ni s'en fabriquer une, ni en choisir le montant ou le beneficiaire.
    # Le personnage de test n'a AUCUNE licence : il n'est eligible a rien.
    creer_perso = {'name': JOUEUR_PRIME, 'country': 'republic', 'current_city': 'capitale',
                   'stats': {}, 'resources': {}, 'qualifications': {}, 'effets_actifs': {},
                   'stats_affaiblies': {}, 'demandeur_emploi': False, 'bonus_lobbyiste': 0,
                   'day': 5, 'arg': 1000, 'liquide': 0, 'hp': 100, 'moral': 75}
    http('POST', '/rest/v1/personnages', creer_perso, token=JETON, prefer='return=representation')

    def argent(nom):
        # Avec le jeton : depuis le chantier B, la fortune n'est lisible que par son proprietaire.
        c, b = http('GET', '/rest/v1/personnages?select=arg&name=eq.' + urllib.request.quote(nom),
                    token=JETON)
        return (b[0]['arg'] if b else None)

    depart = argent(JOUEUR_PRIME)
    verifier('personnage de test cree, sans licence', depart == 1000, depart)

    # (a) le client ne choisit PAS le beneficiaire ni le montant : la RPC n'a qu'un parametre,
    #     et toute tentative d'en passer d'autres est rejetee par l'API elle-meme.
    c, b = http('POST', '/rest/v1/rpc/football_primes_journee',
                {'p_journee': 4, 'p_beneficiaire': JOUEUR_PRIME, 'p_montant': 999999}, token=JETON)
    verifier('on ne peut pas glisser un beneficiaire ni un montant dans l appel',
             c >= 400, 'HTTP %s' % c)

    # (b) une journee reellement jouee, mais aucun licencie de test : rien n'est verse.
    c, b = http('POST', '/rest/v1/rpc/football_primes_journee', {'p_journee': 4}, token=JETON)
    r = b[0] if isinstance(b, list) and b else b
    verifier('journee reelle : l appel aboutit', r and r.get('ok') is True, r)
    verifier('un non-licencie ne touche rien', argent(JOUEUR_PRIME) == depart,
             '%s -> %s' % (depart, argent(JOUEUR_PRIME)))

    # (c) match qui n'existe pas
    c, b = http('POST', '/rest/v1/rpc/football_primes_journee', {'p_journee': 99}, token=JETON)
    r = b[0] if isinstance(b, list) and b else b
    verifier('journee inexistante : refus',
             r and r.get('ok') is False and r.get('raison') == 'journee_inconnue', r)
    c, b = http('POST', '/rest/v1/rpc/football_primes_tour', {'p_manche': 'coupe_imaginaire'},
                token=JETON)
    r = b[0] if isinstance(b, list) and b else b
    verifier('manche inventee : refus',
             r and r.get('ok') is False and r.get('raison') == 'manche_inconnue', r)

    # (d) journee non jouee : aucun versement
    c, b = http('POST', '/rest/v1/rpc/football_primes_journee', {'p_journee': 5}, token=JETON)
    r = b[0] if isinstance(b, list) and b else b
    verifier('journee a venir : aucun versement',
             r and r.get('ok') is True and r.get('verses') == 0, r)

    # (e) LE VIEUX CLIENT : c'est exactement ce que faisait sbAppliquerSalaire. Il doit echouer,
    #     et le verrou du chantier B doit rester entier.
    # La fortune d'autrui n'est meme pas lisible (chantier B) : on mesure donc le REFUS lui-meme,
    # qui est la preuve directe, plutot qu'un solde qu'on ne peut pas relire.
    c, lecture = http('GET', '/rest/v1/personnages?select=arg&name=eq.Arnie', token=JETON)
    verifier('la fortune d un autre personnage reste masquee',
             lecture == [] or (lecture and lecture[0].get('arg') is None), lecture)
    c, b = http('PATCH', '/rest/v1/personnages?name=eq.Arnie', {'arg': 999999}, token=JETON)
    verifier('un client ne credite pas la fiche d un autre (personnage_non_possede)',
             c in (401, 403) and 'personnage_non_possede' in str(b), 'HTTP %s %s' % (c, str(b)[:90]))

    # (f) le registre des primes reste invisible au client
    c, b = http('GET', '/rest/v1/football_primes_versees?select=reference', token=JETON)
    verifier('le registre des primes n est pas lisible par un client', c >= 400, 'HTTP %s' % c)
    c, b = http('POST', '/rest/v1/football_primes_versees',
                {'reference': 'zztest-forge', 'beneficiaire': JOUEUR_PRIME,
                 'club': 'olympique-luthecia', 'role': 'titulaires', 'montant': 99999},
                token=JETON)
    verifier('ni falsifiable', c >= 400, 'HTTP %s' % c)

    # ============ 10. LA LIGNE REELLE EST INTACTE ============
    c, b = http('GET', '/rest/v1/championnat?select=data&id=eq.2')
    reelle = b[0]['data'] if b else {}
    verifier('le championnat reel n a pas ete touche par le banc',
             reelle.get('derniereSemaineResolue') == '2026-W37'
             and reelle.get('phase') == 'reguliere',
             reelle.get('derniereSemaineResolue'))

    return rapport()


def rapport():
    # Le banc ne laisse aucun sujet au forum des joueurs.
    for tid in [t for t in TOPICS if t]:
        http('DELETE', '/rest/v1/forum_posts?topic_id=eq.' + tid, token=JETON)
        http('DELETE', '/rest/v1/forum_topics?id=eq.' + tid, token=JETON)
    http('DELETE', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR_PRIME),
         token=JETON)
    for ident in LIGNES:
        http('DELETE', '/rest/v1/championnat?id=eq.%d' % ident, token=JETON)
    c, reste = http('GET', '/rest/v1/championnat?select=id&id=gt.9000')
    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-58s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    if reste:
        print('!! lignes de test restantes : %s (la suppression est interdite a tous, '
              'elles doivent etre retirees en SQL)' % reste)
    return 1 if ko else 0


if __name__ == '__main__':
    # Le rapport (et donc le nettoyage) doit passer meme si une assertion leve : une passe morte
    # en cours de route laissait jusqu'ici ses sujets au forum de production.
    try:
        code = main() or 0
    except Exception as e:
        print('INTERROMPU : %s' % e)
        code = 2
        rapport()
    sys.exit(code)
