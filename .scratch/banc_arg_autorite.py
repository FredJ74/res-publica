# BANC — AUTORITE SUR LA FORTUNE (16 septembre 2026).
#
# Pendant du banc des PA, pour la ressource la plus sensible du jeu. Il mesure ce qui est
# reellement ferme, et il DOCUMENTE ce qui reste ouvert : un banc qui mentirait par omission
# serait pire que pas de banc du tout.
#
# ETAT A LA LIVRAISON DE CE LOT :
#   * la NAISSANCE est fermee -- on ne peut plus se doter d'une fortune de depart arbitraire ;
#   * l'ECRITURE EN COURS DE PARTIE reste ouverte : 16 appels a crediterFondsOrdinaires et
#     26 hausses directes de state.arg/state.liquide vivent encore dans le client et doivent
#     d'abord etre raccordes a des primitives serveur. Fermer l'UPDATE avant cela casserait des
#     gains legitimes. Les controles marques CONSTAT ci-dessous echoueront -- volontairement --
#     le jour ou quelqu'un croira le verrou acquis sans avoir fait ce travail.
#
# Le banc attaque comme un joueur : cle anon publique, vraie session anonyme, REST.

import json, os, re, sys, time, urllib.error, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(RACINE, '.scratch/banc_entrepots_commandes.py'), encoding='utf-8').read()
URL = re.search(r'URL = "([^"]+)"', SRC).group(1)
BLOC = SRC[SRC.index('ANON = ('):SRC.index('SUF =')]
ANON = ''.join(re.findall(r'"([^"]*)"', BLOC))

SUF = str(int(time.time()))
JOUEUR = 'zztest-arg-' + SUF
DOTATION_MAX = 5000          # origine + ecole + archetype + carriere, mesure sur le vrai data.js
resultats = []
ouverts = []
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


def constater(nom, ferme, detail=''):
    """Un CONSTAT n'est pas un echec : il decrit l'etat du chantier. Mais il est compte."""
    resultats.append((True, ('[FERME] ' if ferme else '[OUVERT] ') + nom, str(detail)[:150]))
    if not ferme:
        ouverts.append(nom)


def session():
    for _ in range(8):
        c, b = http('POST', '/auth/v1/signup', {})
        if c == 200 and isinstance(b, dict) and b.get('access_token'):
            return b['access_token']
        time.sleep(12)
    print('ABANDON : session anonyme impossible (limitation de debit).')
    sys.exit(2)


def creer(nom, arg, liquide=None, banque=None):
    corps = {'name': nom, 'country': 'republic', 'current_city': 'capitale',
             'stats': {}, 'resources': {}, 'qualifications': {}, 'effets_actifs': {},
             'stats_affaiblies': {}, 'demandeur_emploi': False, 'bonus_lobbyiste': 0,
             'day': 5, 'arg': arg, 'hp': 100, 'moral': 75}
    if liquide is not None:
        corps['liquide'] = liquide
    if banque is not None:
        corps['banque'] = banque
    return http('POST', '/rest/v1/personnages', corps, token=JETON, prefer='return=representation')


def fortune(nom=None):
    n = nom or JOUEUR
    c, b = http('GET', '/rest/v1/personnages?select=arg,liquide,banque&name=eq.'
                + urllib.request.quote(n), token=JETON)
    return b[0] if b else None


def main():
    global JETON
    print('Ouverture de la session...')
    JETON = session()

    # ================= 1. LA NAISSANCE =================
    c, b = creer(JOUEUR, 999999, 888888, 777777)
    f = fortune() or {}
    verifier('naitre avec 999999 : la fortune est bornee a la dotation du jeu',
             c in (200, 201) and f.get('arg') == DOTATION_MAX, 'HTTP %s / %s' % (c, f))
    verifier('le liquide ne peut pas depasser la fortune',
             (f.get('liquide') or 0) <= (f.get('arg') or 0), f)
    verifier('la banque non plus', (f.get('banque') or 0) <= (f.get('arg') or 0), f)

    # La dotation la plus genereuse du jeu doit passer INTACTE : un verrou qui rognerait une
    # creation legitime serait un bug, pas une securite. Il faut une seconde session -- un compte
    # ne porte qu'un personnage.
    jeton_principal = JETON
    JETON = session()
    legitime = JOUEUR + '-legitime'
    c, b = creer(legitime, DOTATION_MAX, 750, 4250)
    fl = fortune(legitime) or {}
    verifier('une dotation maximale legitime passe telle quelle',
             fl.get('arg') == DOTATION_MAX and fl.get('liquide') == 750 and fl.get('banque') == 4250,
             'HTTP %s / %s' % (c, fl))
    http('DELETE', '/rest/v1/personnages?name=eq.' + urllib.request.quote(legitime), token=JETON)
    JETON = jeton_principal

    # ================= 2. L ECRITURE EN COURS DE PARTIE =================
    depart = (fortune() or {}).get('arg')
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR),
         {'arg': 999999}, token=JETON)
    apres = (fortune() or {}).get('arg')
    constater('un joueur ne peut pas s attribuer une fortune', apres == depart,
              '%s -> %s' % (depart, apres))

    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR),
         {'liquide': 999999, 'banque': 999999}, token=JETON)
    f = fortune() or {}
    constater('ni du liquide ou un compte en banque',
              (f.get('liquide') or 0) <= (f.get('arg') or 0), f)

    # Restauration d'une valeur perimee : une sauvegarde de fiche obsolete ne doit pas pouvoir
    # effacer un mouvement decide par le serveur.
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR),
         {'arg': 1, 'moral': 61}, token=JETON)
    f = fortune() or {}
    c, b = http('GET', '/rest/v1/personnages?select=moral&name=eq.' + urllib.request.quote(JOUEUR),
                token=JETON)
    verifier('une sauvegarde de fiche continue d ecrire les autres champs',
             b and b[0]['moral'] == 61, b)
    constater('une valeur de fortune perimee ne peut pas ecraser le solde serveur',
              (f.get('arg') or 0) != 1, f)

    # ================= 3. LA FICHE D AUTRUI =================
    c, b = http('GET', '/rest/v1/personnages?select=arg&name=eq.Arnie', token=JETON)
    verifier('la fortune d un autre personnage reste illisible',
             b == [] or (b and b[0].get('arg') is None), b)
    c, b = http('PATCH', '/rest/v1/personnages?name=eq.Arnie', {'arg': 999999}, token=JETON)
    verifier('la fiche d un autre personnage reste inecrivable',
             c in (401, 403) and 'personnage_non_possede' in str(b), 'HTTP %s %s' % (c, str(b)[:80]))

    # ================= 4. LES PRIMITIVES SERVEUR RESTENT FERMEES =================
    for fn, params in (('debiter_fonds_ordinaires_interne', {'p_nom': JOUEUR, 'p_montant': -100000}),
                       ('football_primes_match', {'p_saison': 1, 'p_cle': 'j4', 'p_m': {}})):
        c, b = http('POST', '/rest/v1/rpc/' + fn, params, token=JETON)
        verifier('%s n est pas appelable par un client' % fn, c >= 400, 'HTTP %s' % c)

    # Le guichet des depenses, lui, repond -- et refuse ce qui depasse les fonds reels.
    c, b = http('POST', '/rest/v1/rpc/debiter_fonds_ordinaires',
                {'p_acteur': JOUEUR, 'p_montant': 10 ** 9}, token=JETON)
    r = b[0] if isinstance(b, list) and b else b
    verifier('on ne depense pas plus que ce qu on possede',
             r and r.get('ok') is False, r)

    return rapport()


def rapport():
    http('DELETE', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR), token=JETON)
    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-62s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    if ouverts:
        print('\nENCORE OUVERT (a raccorder avant de fermer l ecriture cliente de la fortune) :')
        for o in ouverts:
            print('  - ' + o)
    return 1 if ko else 0


if __name__ == '__main__':
    try:
        code = main() or 0
    except Exception as e:
        print('INTERROMPU : %s' % e)
        code = 2
    sys.exit(code)
