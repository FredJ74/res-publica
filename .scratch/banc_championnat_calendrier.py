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


def creer_ligne(ident, semaine, matchs, journee=1, numero=1):
    """Cree une ligne de championnat de test. L'INSERT n'est pas soumis au verrou : c'est le
       decor du scenario, pas une tentative de resolution."""
    LIGNES.append(ident)
    http('DELETE', '/rest/v1/championnat?id=eq.%d' % ident, token=JETON)
    c, b = http('POST', '/rest/v1/championnat', {
        'id': ident,
        'data': {'schemaVersion': 2, 'numero': numero, 'phase': 'reguliere',
                 'derniereSemaineResolue': semaine,
                 'calendrier': [{'numero': journee, 'matchs': matchs}]}
    }, token=JETON, prefer='return=representation')
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
             r and r.get('ok') is True and len(apres_pub or []) == len(avant or []) + 1,
             '%d -> %d' % (len(avant or []), len(apres_pub or [])))
    nouveau = [t['id'] for t in (apres_pub or []) if t not in (avant or [])]
    TOPICS.extend(nouveau)
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
    for tid in TOPICS:
        http('DELETE', '/rest/v1/forum_posts?topic_id=eq.' + tid, token=JETON)
        http('DELETE', '/rest/v1/forum_topics?id=eq.' + tid, token=JETON)
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
    sys.exit(main() or 0)
