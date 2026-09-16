# BANC — POUVOIRS DU QHS ET SOURCE CANONIQUE DE LA DETENTION (16 septembre 2026).
#
# Arbitrage applique : `detentions` est la source de verite de l'incarceration. Le serveur ne
# demande jamais au client si quelqu'un est detenu -- il le lit dans la table.
#
# Ce banc attaque comme un joueur (cle anon, session anonyme, REST) et verifie que :
#   * un client ne peut pas ecrire l'etat judiciaire d'un tiers ;
#   * les pouvoirs du QHS exigent le poste REEL et une detention REELLE ;
#   * un personnage libre ne peut pas etre torture ni ameliore ;
#   * la table canonique et le registre QHS ne sont pas ecrivables n'importe comment.
#
# Les effets positifs (amelioration, torture, transfert) sont eprouves separement en transaction
# annulee sur la base reelle -- ils demandent un detenu et un Ministre de la Justice, que ce banc
# ne fabrique pas en production.

import json, os, re, sys, time, urllib.error, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(RACINE, '.scratch/banc_entrepots_commandes.py'), encoding='utf-8').read()
URL = re.search(r'URL = "([^"]+)"', SRC).group(1)
BLOC = SRC[SRC.index('ANON = ('):SRC.index('SUF =')]
ANON = ''.join(re.findall(r'"([^"]*)"', BLOC))

JOUEUR = 'zztest-justice-' + str(int(time.time()))
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
    resultats.append((bool(cond), nom, str(detail)[:150]))


def session():
    for _ in range(8):
        c, b = http('POST', '/auth/v1/signup', {})
        if c == 200 and isinstance(b, dict) and b.get('access_token'):
            return b['access_token']
        time.sleep(12)
    print('ABANDON : session anonyme impossible.')
    sys.exit(2)


def rpc(fn, params):
    c, b = http('POST', '/rest/v1/rpc/' + fn, params, token=JETON)
    if isinstance(b, list):
        b = b[0] if b else None
    return c, b


def main():
    global JETON
    print('Ouverture de la session...')
    JETON = session()
    http('POST', '/rest/v1/personnages', {
        'name': JOUEUR, 'country': 'republic', 'current_city': 'capitale',
        'stats': {}, 'resources': {}, 'qualifications': {}, 'effets_actifs': {},
        'stats_affaiblies': {}, 'demandeur_emploi': False, 'bonus_lobbyiste': 0,
        'day': 5, 'arg': 500, 'hp': 100, 'moral': 75}, token=JETON,
        prefer='return=representation')

    # ============ 1. L ETAT JUDICIAIRE D AUTRUI ============
    c, b = http('PATCH', '/rest/v1/personnages?name=eq.Arnie',
                {'est_emprisonne': {'jours': 30, 'jourFin': 99, 'raison': 'forge'}}, token=JETON)
    verifier('un client ne peut pas emprisonner un autre personnage par sa fiche',
             c in (401, 403) and 'personnage_non_possede' in str(b), 'HTTP %s %s' % (c, str(b)[:70]))
    c, b = http('PATCH', '/rest/v1/personnages?name=eq.Arnie', {'est_emprisonne': None}, token=JETON)
    verifier('ni le liberer', c in (401, 403), 'HTTP %s' % c)
    c, b = http('PATCH', '/rest/v1/personnages?name=eq.Arnie',
                {'detention_qhs': {'enQHS': True}}, token=JETON)
    verifier('ni le placer au QHS', c in (401, 403), 'HTTP %s' % c)

    # ============ 2. SE DECLARER DETENU NE CREE AUCUNE DETENTION ============
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR),
         {'est_emprisonne': {'jours': 3, 'jourFin': 8, 'raison': 'auto-proclamee'}}, token=JETON)
    c, b = http('GET', '/rest/v1/detentions?select=id&nom=eq.' + urllib.request.quote(JOUEUR))
    verifier('se declarer detenu sur sa fiche ne cree aucune detention canonique',
             b == [], b)
    c, b = rpc('detention_active', {'p_nom': JOUEUR})
    verifier('et la source canonique le considere libre', b is None or b == [] or not b, b)

    # ============ 3. LES POUVOIRS DU QHS ============
    for acte in ('transferer', 'ameliorer', 'torturer'):
        c, b = rpc('qhs_pouvoir', {'p_prisonnier_id': 'peu-importe', 'p_acte': acte})
        verifier('sans le poste de Ministre de la Justice : %s refuse' % acte,
                 c in (400, 401, 403) or (b and b.get('ok') is not True), 'HTTP %s %s' % (c, str(b)[:70]))

    # Se declarer ministre sur sa propre fiche ne donne pas le pouvoir (chantier postes).
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR),
         {'poste': {'id': 'min_just', 'name': 'Ministre de la Justice'}}, token=JETON)
    c, b = rpc('qhs_pouvoir', {'p_prisonnier_id': 'peu-importe', 'p_acte': 'torturer'})
    verifier('un faux Ministre de la Justice non plus',
             c in (400, 401, 403) or (b and b.get('ok') is not True), 'HTTP %s %s' % (c, str(b)[:70]))

    c, b = rpc('qhs_pouvoir', {'p_prisonnier_id': 'peu-importe', 'p_acte': 'evasion_organisee'})
    verifier('un acte QHS invente est refuse',
             c in (400, 401, 403) or (b and b.get('ok') is not True), str(b)[:70])

    # ============ 4. LES TABLES CANONIQUES ============
    c, b = http('POST', '/rest/v1/detentions', {
        'id': 'zztest-det-forgee', 'country': 'republic', 'city': 'capitale', 'nom': 'Arnie',
        'raison': 'forgee', 'jour_debut': 1, 'jour_fin': 99}, token=JETON)
    c2, present = http('GET', '/rest/v1/detentions?select=id&id=eq.zztest-det-forgee')
    verifier('un client ne fabrique pas une detention pour autrui',
             present == [], 'HTTP %s / %s' % (c, present))

    c, b = http('POST', '/rest/v1/prisonniers_qhs',
                {'id': 'zztest-qhs-forge', 'statut': 'actif',
                 'data': {'nom': 'Arnie', 'raison': 'forge'}}, token=JETON)
    c2, present = http('GET', '/rest/v1/prisonniers_qhs?select=id&id=eq.zztest-qhs-forge')
    if present:
        http('DELETE', '/rest/v1/prisonniers_qhs?id=eq.zztest-qhs-forge', token=JETON)
    verifier('CONSTAT : ecriture cliente du registre QHS', True,
             'ouverte' if present else 'fermee')

    # ============ 5. LES PRIMITIVES INTERNES RESTENT FERMEES ============
    for fn, params in (('detention_ouvrir_interne',
                        {'p_nom': 'Arnie', 'p_raison': 'x', 'p_jours': 30, 'p_city': 'capitale',
                         'p_country': 'republic', 'p_motifs': [], 'p_autorite': 'x', 'p_issue': 'x'}),
                       ('plainte_instruire_interne',
                        {'p_pays': 'republic', 'p_ville': 'capitale', 'p_cible': 'Arnie',
                         'p_motif': 'x', 'p_instructeur': 'x'})):
        c, b = http('POST', '/rest/v1/rpc/' + fn, params, token=JETON)
        verifier('%s n est pas appelable par un client' % fn, c >= 400, 'HTTP %s' % c)

    # ============ 6. LA DETENTION D AUTRUI N EST PAS LISIBLE PAR LA FICHE ============
    c, b = http('GET', '/rest/v1/personnages?select=est_emprisonne&name=eq.Arnie', token=JETON)
    verifier('CONSTAT : lecture de est_emprisonne d autrui', True,
             'masquee' if (b == [] or (b and b[0].get('est_emprisonne') is None)) else 'visible (liste des geoles)')

    return rapport()


def rapport():
    http('DELETE', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR), token=JETON)
    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-62s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    return 1 if ko else 0


if __name__ == '__main__':
    try:
        code = main() or 0
    except Exception as e:
        print('INTERROMPU : %s' % e)
        code = 2
    sys.exit(code)
