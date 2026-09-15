# BANC — RPC rattacher_personnage (incident du 15 septembre 2026, « Acces refuse (http_404) »).
#
# Rejoue le contrat EXACT attendu par le client (auth.js rpAuthRattacherPersonnage +
# creation.js lignes 33-57), par HTTP reel contre PostgREST, avec de vraies sessions anonymes.
#
# DONNEES : uniquement des personnages 'zztest-...', supprimes a la fin. Les deux personnages
# reels (Arnie, Phileas Frogg) ne sont JAMAIS ecrits -- au plus lus en refus, ce qui n'ecrit rien.
# Les comptes anonymes crees par le banc ne sont pas supprimes : la suppression de comptes est
# soumise a autorisation explicite.

import json, re, sys, time, urllib.error, urllib.request

SRC = open('.scratch/banc_entrepots_commandes.py', encoding='utf-8').read()
URL = re.search(r'URL = "([^"]+)"', SRC).group(1)
BLOC = SRC[SRC.index('ANON = ('):SRC.index('SUF =')]
ANON = ''.join(re.findall(r'"([^"]*)"', BLOC))

SUF = str(int(time.time()))
resultats = []


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


def session_anonyme(etiquette):
    """Ouvre une session anonyme comme le fait le client. Reessaie : /auth/v1/signup est
       limite en debit cote Supabase, ce qui n'est pas un echec du code teste."""
    for essai in range(6):
        c, b = http('POST', '/auth/v1/signup', {})
        if c == 200 and isinstance(b, dict) and b.get('access_token'):
            return b['access_token'], (b.get('user') or {}).get('id')
        time.sleep(12)
    print('ABANDON : impossible d ouvrir une session anonyme pour %s (debit limite).' % etiquette)
    sys.exit(2)


def rattacher(nom, token):
    return http('POST', '/rest/v1/rpc/rattacher_personnage', {'p_nom': nom}, token=token)


def creer_personnage(nom, token):
    return http('POST', '/rest/v1/personnages', {
        'name': nom, 'country': 'republic', 'current_city': 'capitale',
        'stats': {}, 'resources': {}, 'qualifications': {}, 'effets_actifs': {},
        'stats_affaiblies': {}, 'demandeur_emploi': False, 'bonus_lobbyiste': 0
    }, token=token, prefer='return=representation')


def main():
    print('Ouverture des sessions anonymes (peut prendre un moment : debit limite)...')
    tokA, uidA = session_anonyme('A')
    tokC, uidC = session_anonyme('C')   # compte sans personnage
    nomA = 'zztest-rattache-a-' + SUF
    nomB = 'zztest-rattache-b-' + SUF

    # --- le compte A cree son personnage, comme un joueur normal
    c, b = creer_personnage(nomA, tokA)
    verifier('A cree son personnage', c in (200, 201), 'HTTP %s %s' % (c, b))
    if c not in (200, 201):
        return rapport()

    # ================= LE CAS QUI ETAIT CASSE =================
    c, b = rattacher(nomA, tokA)
    verifier('plus aucun 404 sur la RPC (c etait la panne)', c == 200, 'HTTP %s' % c)
    verifier('mon propre personnage : acces accorde',
             isinstance(b, dict) and b.get('ok') is True, b)
    verifier('mon propre personnage : reconnu comme deja rattache',
             isinstance(b, dict) and b.get('deja_rattache') is True, b)
    verifier('aucune raison renvoyee en cas de succes',
             isinstance(b, dict) and 'raison' not in b, b)

    # --- le proprietaire n a pas change au passage
    c, b = http('GET', '/rest/v1/personnages?select=name&name=eq.' + nomA, token=tokA)
    verifier('le personnage reste lisible par son proprietaire',
             c == 200 and isinstance(b, list) and len(b) == 1, '%s %s' % (c, b))

    # ================= REFUS : personnage d autrui =================
    c, b = rattacher(nomA, tokC)
    verifier('personnage d autrui : refus explicite, pas un 404', c == 200, 'HTTP %s' % c)
    verifier('personnage d autrui : raison personnage_deja_possede',
             isinstance(b, dict) and b.get('raison') == 'personnage_deja_possede', b)

    # le refus n a rien ecrit : le proprietaire est toujours A
    c, b = rattacher(nomA, tokA)
    verifier('le refus n a pas vole le personnage',
             isinstance(b, dict) and b.get('ok') is True, b)

    # ================= REFUS : un compte = un personnage =================
    c, b = creer_personnage(nomB, tokC)
    verifier('C cree son propre personnage', c in (200, 201), 'HTTP %s' % c)
    c, b = rattacher(nomA, tokC)
    verifier('compte deja pourvu : refus', isinstance(b, dict) and b.get('ok') is False, b)
    verifier('compte deja pourvu : raison et personnage nommes',
             isinstance(b, dict) and b.get('raison') == 'compte_deja_pourvu'
             and b.get('personnage') == nomB, b)

    # ================= CAS LIMITES =================
    c, b = rattacher('zztest-nexiste-pas-' + SUF, tokA)
    verifier('personnage inexistant : raison claire',
             isinstance(b, dict) and b.get('raison') == 'personnage_introuvable', b)

    c, b = rattacher(nomA, None)   # cle anon partagee, sans identite
    verifier('sans identite nominative : refuse par les droits (jamais execute)',
             c in (401, 403), 'HTTP %s %s' % (c, b))

    rapport()


def rapport():
    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-60s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    print('\nPersonnages zztest a nettoyer : zztest-rattache-%%-' + SUF)
    return 1 if ko else 0


if __name__ == '__main__':
    sys.exit(main() or 0)
