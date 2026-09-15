# BANC — CONSOMMATION DES PA PAR payer_ordre (16 septembre 2026).
#
# Ne par du bug rapporte en production : « 12 PA affiches, ordre a 2 PA, refus PA insuffisants ».
# Le banc reproduit d'abord le mecanisme exact du refus, puis verifie que la primitive commune de
# paiement est saine -- couts 1, 2 et 3 PA, egalite stricte, manque d'une unite, persistance.
#
# Donnees : un personnage 'zztest-pa-*' cree et supprime par la passe. Aucun personnage reel
# n'est touche.

import json, os, re, sys, time, urllib.error, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(RACINE, '.scratch/banc_entrepots_commandes.py'), encoding='utf-8').read()
URL = re.search(r'URL = "([^"]+)"', SRC).group(1)
BLOC = SRC[SRC.index('ANON = ('):SRC.index('SUF =')]
ANON = ''.join(re.findall(r'"([^"]*)"', BLOC))

SUF = str(int(time.time()))
JOUEUR = 'zztest-pa-' + SUF
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


def rpc(fn, params, token):
    c, b = http('POST', '/rest/v1/rpc/' + fn, params, token=token)
    if isinstance(b, list):
        b = b[0] if b else None
    return c, b


def session():
    for _ in range(8):
        c, b = http('POST', '/auth/v1/signup', {})
        if c == 200 and isinstance(b, dict) and b.get('access_token'):
            return b['access_token']
        time.sleep(12)
    print('ABANDON : session anonyme impossible.')
    sys.exit(2)


def pa_serveur():
    c, b = http('GET', '/rest/v1/personnages?select=pa&name=eq.' + urllib.request.quote(JOUEUR))
    return (b[0]['pa'] if b else None)


def poser_pa(valeur, token):
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR),
         {'pa': valeur}, token=token)


def payer(fn, pa, cost, token):
    return rpc('payer_ordre', {'p_acteur': JOUEUR, 'p_fn': fn, 'p_pa': pa, 'p_cost': cost}, token)


def main():
    print('Ouverture de la session...')
    tok = session()
    c, b = http('POST', '/rest/v1/personnages', {
        'name': JOUEUR, 'country': 'republic', 'current_city': 'capitale',
        'stats': {}, 'resources': {}, 'qualifications': {}, 'effets_actifs': {},
        'stats_affaiblies': {}, 'demandeur_emploi': False, 'bonus_lobbyiste': 0,
        'day': 5, 'pa': 12, 'liquide': 5000, 'arg': 5000
    }, token=tok, prefer='return=representation')
    verifier('personnage de test cree avec 12 PA', c in (200, 201) and pa_serveur() == 12,
             'HTTP %s / pa=%s' % (c, pa_serveur()))

    # ============ REPRODUCTION DU BUG D'ORIGINE ============
    # L'ancien code facturait 2 PA sous le nom de 'se_porter_candidat', declare a 0 PA.
    c, b = payer('se_porter_candidat', 2, 0, tok)
    verifier('BUG D ORIGINE reproduit : (se_porter_candidat, 2 PA) est refuse',
             b and b.get('ok') is False, b)
    verifier('et la raison n est PAS un manque de PA',
             b and b.get('raison') == 'cout_non_declare', b)
    verifier('aucun PA preleve par ce refus', pa_serveur() == 12, pa_serveur())

    # ============ LE CORRECTIF ============
    c, b = payer('deposer_candidature', 2, 0, tok)
    verifier('12 PA / depot de candidature a 2 PA : ACCEPTE', b and b.get('ok') is True, b)
    verifier('le serveur renvoie 10 PA', b and b.get('pa') == 10, b)
    verifier('le serveur a reellement debite : relecture a 10', pa_serveur() == 10, pa_serveur())
    verifier('le montant preleve est annonce', b and b.get('pa_preleves') == 2, b)

    # ============ COUTS 1 / 2 / 3 PA SUR D AUTRES ORDRES ============
    for fn, cout in (('plainte_police', 1), ('se_justifier', 1), ('arreter', 3)):
        avant = pa_serveur()
        c, b = payer(fn, cout, 0, tok)
        verifier('%s a %d PA : accepte' % (fn, cout), b and b.get('ok') is True, b)
        verifier('%s : %d PA reellement debites' % (fn, cout), pa_serveur() == avant - cout,
                 '%s -> %s' % (avant, pa_serveur()))

    # ============ CAS LIMITES ============
    poser_pa(2, tok)
    verifier('PA repositionnes a 2', pa_serveur() == 2, pa_serveur())
    c, b = payer('deposer_candidature', 2, 0, tok)
    verifier('PA exactement egaux au cout : accepte', b and b.get('ok') is True, b)
    verifier('solde ramene a 0', pa_serveur() == 0, pa_serveur())

    poser_pa(1, tok)
    c, b = payer('deposer_candidature', 2, 0, tok)
    verifier('un PA de moins que le cout : refuse',
             b and b.get('ok') is False and b.get('raison') == 'pa_insuffisants', b)
    verifier('le refus annonce le solde reel', b and b.get('pa_reel') == 1, b)
    verifier('rien n est preleve sur un refus', pa_serveur() == 1, pa_serveur())

    # ============ LE CLIENT PEUT-IL FALSIFIER SES PA ? ============
    poser_pa(999, tok)
    falsifiable = (pa_serveur() == 999)
    verifier('CONSTAT : les PA restent ecrits par le client (a signaler, hors lot)',
             True, 'pa apres falsification = %s' % pa_serveur())
    if falsifiable:
        c, b = payer('arreter', 3, 0, tok)
        verifier('un solde falsifie est pris pour argent comptant par payer_ordre',
                 True, 'accepte=%s' % (b and b.get('ok')))

    return rapport()


def rapport():
    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-58s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    print('Personnage a nettoyer : ' + JOUEUR)
    return 1 if ko else 0


if __name__ == '__main__':
    sys.exit(main() or 0)
