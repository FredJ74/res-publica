# BANC — CLOISONNEMENT DU FORUM LOCAL PAR VILLE (16 septembre 2026).
#
# Le Forum Local etait commun aux trois villes de Republia : un programme municipal de Montrouge
# paraissait a cote de celui de Luthecia. Il en existe desormais un PAR VILLE, sous l'identifiant
# 'local_<ville>' -- meme schema que 'tribunal_<ville>', deja en place, donc valable pour Sovarka
# sans un cas particulier de plus.
#
# Le banc attaque comme un joueur (cle anon, session anonyme, REST) : il verifie que la frontiere
# tient a la LECTURE comme a l'ECRITURE, et qu'un navigateur ne peut pas la franchir en changeant
# la ville qu'il annonce.

import json, os, re, sys, time, urllib.error, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(RACINE, '.scratch/banc_entrepots_commandes.py'), encoding='utf-8').read()
URL = re.search(r'URL = "([^"]+)"', SRC).group(1)
BLOC = SRC[SRC.index('ANON = ('):SRC.index('SUF =')]
ANON = ''.join(re.findall(r'"([^"]*)"', BLOC))

SUF = str(int(time.time()))
JOUEUR = 'zztest-local-' + SUF
VILLE_A, VILLE_B = 'capitale', 'ville_b'     # Luthecia et Montrouge
resultats, TOPICS = [], []
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
    resultats.append((bool(cond), nom, str(detail)[:150]))


def session():
    for _ in range(8):
        c, b = http('POST', '/auth/v1/signup', {})
        if c == 200 and isinstance(b, dict) and b.get('access_token'):
            return b['access_token']
        time.sleep(12)
    print('ABANDON : session anonyme impossible.')
    sys.exit(2)


def poser_ville(ville):
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR),
         {'current_city': ville}, token=JETON)


def publier(forum_id, titre):
    tid = 'zztest-loc-' + forum_id + '-' + SUF
    TOPICS.append(tid)
    c, b = http('POST', '/rest/v1/forum_topics', {
        'id': tid, 'forum_id': forum_id, 'title': titre, 'author': JOUEUR,
        'country': 'republic', 'time': 'x', 'views': 1, 'replies': 0,
        'last_post_author': JOUEUR, 'last_post_time': 'x'}, token=JETON)
    c2, present = http('GET', '/rest/v1/forum_topics?select=id&id=eq.' + tid)
    return (present != [])


def sujets(forum_id):
    """Exactement la requete du jeu : sbLoadForumTopics ne filtre que sur forum_id."""
    c, b = http('GET', '/rest/v1/forum_topics?select=id,title&forum_id=eq.'
                + urllib.request.quote(forum_id))
    return [t['id'] for t in (b or [])]


def main():
    global JETON
    print('Ouverture de la session...')
    JETON = session()
    http('POST', '/rest/v1/personnages', {
        'name': JOUEUR, 'country': 'republic', 'current_city': VILLE_A,
        'stats': {}, 'resources': {}, 'qualifications': {}, 'effets_actifs': {},
        'stats_affaiblies': {}, 'demandeur_emploi': False, 'bonus_lobbyiste': 0,
        'day': 5, 'arg': 500, 'hp': 100, 'moral': 75}, token=JETON, prefer='return=representation')

    # ============ 1. CHACUN CHEZ SOI ============
    poser_ville(VILLE_A)
    verifier('un joueur publie dans le Local de sa ville', publier('local_' + VILLE_A, 'Sujet de Luthecia'))
    poser_ville(VILLE_B)
    verifier('et dans celui de sa nouvelle ville apres deplacement',
             publier('local_' + VILLE_B, 'Sujet de Montrouge'))

    a, b = sujets('local_' + VILLE_A), sujets('local_' + VILLE_B)
    idA, idB = 'zztest-loc-local_' + VILLE_A + '-' + SUF, 'zztest-loc-local_' + VILLE_B + '-' + SUF
    verifier('le sujet de Luthecia est dans le Local de Luthecia', idA in a, a[:4])
    verifier('il n apparait PAS dans le Local de Montrouge', idA not in b, b[:4])
    verifier('le sujet de Montrouge est dans le Local de Montrouge', idB in b, b[:4])
    verifier('il n apparait PAS dans le Local de Luthecia', idB not in a, a[:4])

    # ============ 2. LA FRONTIERE TIENT A L ECRITURE ============
    # Le joueur est a Montrouge : il ne doit pas pouvoir publier dans le Local de Luthecia.
    verifier('on ne publie pas dans le Local d une autre ville',
             not publier('local_' + VILLE_A + '-fraude', 'Tentative'), 'refus attendu')
    tid = 'zztest-loc-frontiere-' + SUF
    TOPICS.append(tid)
    c, b2 = http('POST', '/rest/v1/forum_topics', {
        'id': tid, 'forum_id': 'local_' + VILLE_A, 'title': 'Depuis Montrouge', 'author': JOUEUR,
        'country': 'republic', 'time': 'x', 'views': 1, 'replies': 0,
        'last_post_author': JOUEUR, 'last_post_time': 'x'}, token=JETON)
    c2, present = http('GET', '/rest/v1/forum_topics?select=id&id=eq.' + tid)
    verifier('meme en annoncant une autre ville dans la requete', present == [],
             'HTTP %s / %s' % (c, present))

    # ============ 3. LES AUTRES ECHELLES NE BOUGENT PAS ============
    verifier('le National reste partage a l echelle du pays', publier('national', 'Sujet national'))
    verifier('l International reste global', publier('international', 'Sujet international'))
    nat = sujets('national')
    verifier('et le National ne contient aucun sujet de ville',
             all('local_' not in t for t in nat), nat[:4])

    # ============ 4. LES PROGRAMMES SUIVENT LE SCRUTIN ============
    c, b3 = http('GET', '/rest/v1/forum_topics?select=id,forum_id&id=like.topic-programme-*')
    hors_local = [t for t in (b3 or []) if t['forum_id'] == 'local']
    verifier('aucun programme ne subsiste dans l ancien Local global', hors_local == [], hors_local)

    c, anciens = http('GET', '/rest/v1/forum_topics?select=id&forum_id=eq.local')
    verifier('plus aucun sujet dans l ancien Local global', anciens == [], anciens)

    return rapport()


def rapport():
    for tid in TOPICS:
        http('DELETE', '/rest/v1/forum_posts?topic_id=eq.' + tid, token=JETON)
        http('DELETE', '/rest/v1/forum_topics?id=eq.' + tid, token=JETON)
    http('DELETE', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR), token=JETON)
    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-58s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    return 1 if ko else 0


if __name__ == '__main__':
    try:
        code = main() or 0
    except Exception as e:
        print('INTERROMPU : %s' % e); code = 2
        rapport()
    sys.exit(code)
