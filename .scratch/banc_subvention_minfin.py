# BANC — SUBVENTION DU MINISTRE DES FINANCES (16 septembre 2026).
#
# Le defaut corrige : la caisse du gouvernement etait reellement debitee, puis le beneficiaire
# etait credite par une ecriture directe sur SA fiche -- refusee depuis le chantier B. L'argent
# public quittait la caisse sans jamais arriver. Le banc verifie que les deux mouvements sont
# desormais indissociables, et qu'aucun client ne peut en fabriquer un seul.
#
# Il attaque comme un joueur : cle anon publique, vraies sessions anonymes, REST. Le pays de test
# est 'zztest', donc la caisse sollicitee est zztest_gouvernement-min_fin -- jamais celle de la
# Republique. Personnages et caisse sont crees puis retires par la passe.
#
# La fixture d'autorite (postes_attribues) est posee en SQL avant la passe : un client ne peut
# pas s'attribuer un poste, et c'est precisement ce que le banc verifie aussi.

import json, os, re, sys, time, urllib.error, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(RACINE, '.scratch/banc_entrepots_commandes.py'), encoding='utf-8').read()
URL = re.search(r'URL = "([^"]+)"', SRC).group(1)
BLOC = SRC[SRC.index('ANON = ('):SRC.index('SUF =')]
ANON = ''.join(re.findall(r'"([^"]*)"', BLOC))

PAYS = 'zztest'
CAISSE = PAYS + '_gouvernement-min_fin'
MINISTRE = 'zztest-sub-ministre'
BENEF = 'zztest-sub-beneficiaire'
QUIDAM = 'zztest-sub-quidam'
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


def session(etiquette):
    for _ in range(8):
        c, b = http('POST', '/auth/v1/signup', {})
        if c == 200 and isinstance(b, dict) and b.get('access_token'):
            return b['access_token']
        time.sleep(12)
    print('ABANDON : session anonyme impossible pour %s.' % etiquette)
    sys.exit(2)


def creer(nom, token):
    return http('POST', '/rest/v1/personnages', {
        'name': nom, 'country': PAYS, 'current_city': 'capitale',
        'stats': {}, 'resources': {}, 'qualifications': {}, 'effets_actifs': {},
        'stats_affaiblies': {}, 'demandeur_emploi': False, 'bonus_lobbyiste': 0,
        'day': 5, 'arg': 700, 'liquide': 0, 'hp': 100, 'moral': 75
    }, token=token, prefer='return=representation')


def fortune(nom, token):
    """La fortune n'est lisible que par son proprietaire (chantier B) : on lit avec SON jeton."""
    c, b = http('GET', '/rest/v1/personnages?select=arg&name=eq.' + urllib.request.quote(nom),
                token=token)
    return (b[0]['arg'] if b else None)


def caisse():
    c, b = http('GET', '/rest/v1/caisses_batiments?select=data&id=eq.' + CAISSE)
    return int((b[0]['data'] or {}).get('solde', 0)) if b else None


def poser_caisse(montant, token):
    """Amene la caisse de test au solde voulu, par la primitive publique existante."""
    actuel = caisse() or 0
    delta = montant - actuel
    if delta:
        rpc('caisse_institution_mouvement', {'p_id': CAISSE, 'p_delta': delta}, token)
    return caisse()


def main():
    print('Ouverture des sessions (debit limite : cela peut prendre une minute)...')
    tokM, tokB, tokQ = session('ministre'), session('beneficiaire'), session('quidam')
    for nom, tok in ((MINISTRE, tokM), (BENEF, tokB), (QUIDAM, tokQ)):
        c, b = creer(nom, tok)
        verifier('personnage %s cree' % nom.split('-')[2], c in (200, 201), 'HTTP %s' % c)

    # Le poste est deja atteste au registre (fixture SQL) : le client ne fait que le recopier,
    # et le declencheur l'accepte parce que le registre le confirme.
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(MINISTRE),
         {'poste': {'id': 'min_fin', 'name': 'Ministre des Finances'}}, token=tokM)
    c, b = http('GET', '/rest/v1/personnages?select=poste&name=eq.' + urllib.request.quote(MINISTRE))
    verifier('le ministre porte un poste atteste',
             (b[0]['poste'] if b else {}) and b[0]['poste'].get('id') == 'min_fin', b)

    # ================= 1. LE CAS NOMINAL =================
    poser_caisse(3000, tokM)
    avant_caisse, avant_benef = caisse(), fortune(BENEF, tokB)
    c, r = rpc('subvention_citoyen_verser', {'p_beneficiaire': BENEF, 'p_montant': 500}, tokM)
    verifier('subvention valide : acceptee', r and r.get('ok') is True, r)
    verifier('le beneficiaire recoit exactement 500',
             fortune(BENEF, tokB) == avant_benef + 500,
             '%s -> %s' % (avant_benef, fortune(BENEF, tokB)))
    verifier('la caisse est debitee d exactement 500', caisse() == avant_caisse - 500,
             '%s -> %s' % (avant_caisse, caisse()))

    # ================= 2. LES DEUX MOUVEMENTS SONT INDISSOCIABLES =================
    # Caisse vide : ni debit, ni credit. C'est le scenario exact du bug -- l'argent ne doit pas
    # pouvoir partir sans arriver, ni arriver sans partir.
    poser_caisse(0, tokM)
    avant_benef = fortune(BENEF, tokB)
    c, r = rpc('subvention_citoyen_verser', {'p_beneficiaire': BENEF, 'p_montant': 500}, tokM)
    verifier('caisse vide : refus', r and r.get('ok') is False
             and r.get('raison') == 'caisse_insuffisante', r)
    verifier('caisse vide : le beneficiaire n a rien recu',
             fortune(BENEF, tokB) == avant_benef, fortune(BENEF, tokB))
    verifier('caisse vide : la caisse reste a zero', caisse() == 0, caisse())

    # Caisse partielle : le versement partiel est le comportement d'origine, conserve.
    poser_caisse(200, tokM)
    avant_benef = fortune(BENEF, tokB)
    c, r = rpc('subvention_citoyen_verser', {'p_beneficiaire': BENEF, 'p_montant': 500}, tokM)
    verifier('caisse partielle : verse ce qui existe', r and r.get('ok') is True
             and int(r.get('verse') or 0) == 200, r)
    verifier('caisse partielle : le beneficiaire recoit exactement ce qui est sorti',
             fortune(BENEF, tokB) == avant_benef + 200,
             '%s -> %s' % (avant_benef, fortune(BENEF, tokB)))
    verifier('caisse partielle : la caisse est videe, pas negative', caisse() == 0, caisse())

    # ================= 3. L AUTORITE =================
    poser_caisse(3000, tokM)
    avant_caisse, avant_benef = caisse(), fortune(BENEF, tokB)
    c, r = rpc('subvention_citoyen_verser', {'p_beneficiaire': BENEF, 'p_montant': 500}, tokQ)
    verifier('un quidam ne subventionne pas',
             c in (400, 401, 403) or not (r and r.get('ok') is True), 'HTTP %s %s' % (c, r))
    verifier('et rien n a bouge', caisse() == avant_caisse and fortune(BENEF, tokB) == avant_benef,
             'caisse=%s benef=%s' % (caisse(), fortune(BENEF, tokB)))

    # Se declarer ministre sur sa propre fiche ne donne pas le pouvoir (chantier postes).
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(QUIDAM),
         {'poste': {'id': 'min_fin', 'name': 'Ministre des Finances'}}, token=tokQ)
    c, r = rpc('subvention_citoyen_verser', {'p_beneficiaire': BENEF, 'p_montant': 500}, tokQ)
    verifier('un faux ministre non plus',
             c in (400, 401, 403) or not (r and r.get('ok') is True), 'HTTP %s %s' % (c, r))
    verifier('et la caisse est intacte', caisse() == avant_caisse, caisse())

    # ================= 4. PARAMETRES =================
    for montant, libelle in ((0, 'nul'), (-500, 'negatif'), (9999, 'au-dessus du plafond')):
        avant_caisse = caisse()
        c, r = rpc('subvention_citoyen_verser', {'p_beneficiaire': BENEF, 'p_montant': montant}, tokM)
        verifier('montant %s : refuse' % libelle,
                 r and r.get('ok') is False and r.get('raison') == 'montant_invalide', r)
        verifier('montant %s : caisse intacte' % libelle, caisse() == avant_caisse, caisse())

    avant_caisse = caisse()
    c, r = rpc('subvention_citoyen_verser', {'p_beneficiaire': 'zztest-personne-inexistante',
                                             'p_montant': 500}, tokM)
    verifier('beneficiaire inconnu : refuse',
             r and r.get('ok') is False and r.get('raison') == 'beneficiaire_introuvable', r)
    verifier('beneficiaire inconnu : caisse intacte', caisse() == avant_caisse, caisse())

    # ================= 5. LE VIEUX CLIENT =================
    # C'est exactement ce que faisait l'ancien code : ecrire la fortune d'autrui.
    c, b = http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(BENEF),
                {'arg': 999999}, token=tokM)
    verifier('un client ne peut pas crediter la fiche d un autre',
             c in (401, 403) and 'personnage_non_possede' in str(b), 'HTTP %s %s' % (c, str(b)[:80]))
    verifier('la fortune du beneficiaire n a pas bouge', fortune(BENEF, tokB) is not None
             and fortune(BENEF, tokB) < 999999, fortune(BENEF, tokB))
    c, b = http('GET', '/rest/v1/personnages?select=arg&name=eq.' + urllib.request.quote(BENEF),
                token=tokM)
    verifier('il ne peut meme pas lire sa fortune',
             b == [] or (b and b[0].get('arg') is None), b)

    # ================= 6. LA CAISSE REELLE N A PAS ETE TOUCHEE =================
    c, b = http('GET', '/rest/v1/caisses_batiments?select=data&id=eq.republic_gouvernement-min_fin')
    verifier('la caisse de la Republique est hors du banc',
             b and int((b[0]['data'] or {}).get('solde', 0)) > 0,
             (b[0]['data'] or {}).get('solde') if b else None)

    return rapport(tokM)


def rapport(token):
    for nom in (MINISTRE, BENEF, QUIDAM):
        http('DELETE', '/rest/v1/personnages?name=eq.' + urllib.request.quote(nom), token=token)
    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-58s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    print('A retirer en SQL : caisse %s et la fixture de poste zztest.' % CAISSE)
    return 1 if ko else 0


if __name__ == '__main__':
    try:
        code = main() or 0
    except Exception as e:
        print('INTERROMPU : %s' % e)
        code = 2
    sys.exit(code)
