# BANC D'ATTAQUE — AUTORITE DES POSTES (15 septembre 2026).
#
# Prouve qu'un joueur ne peut plus se fabriquer une autorite en ecrivant son propre `poste`, et
# que les chemins legitimes (election, nomination, candidature sur autorite PNJ, revocation,
# demission) continuent de fonctionner.
#
# Isolation : pays 'zztest', ville 'zzville-pst', personnages 'zztest-pst-*'. Les deux joueurs
# reels, les cycles electoraux reels et les postes reels ne sont jamais touches. Les fixtures
# serveur (cycle electoral, titulaire PNJ) sont posees par l'operateur via MCP avant le banc --
# elles ne sont PAS ecrivables par un client, c'est precisement ce que ce lot garantit.

import json, os, re, sys, time, urllib.error, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(RACINE, '.scratch/banc_entrepots_commandes.py'), encoding='utf-8').read()
URL = re.search(r'URL = "([^"]+)"', SRC).group(1)
BLOC = SRC[SRC.index('ANON = ('):SRC.index('SUF =')]
ANON = ''.join(re.findall(r'"([^"]*)"', BLOC))

# Noms FIXES, pas horodates : la fixture du cycle electoral doit nommer l'elu, et un cycle
# electoral n'est PAS ecrivable par un client -- c'est precisement ce que ce lot garantit. Le
# nettoyage prealable est fait en SQL par l'operateur.
PAYS = 'zztest'
VILLE = 'zzville-pst'
MAIRE = 'zztest-pst-maire'
CMR = 'zztest-pst-commissaire'
FRAUDEUR = 'zztest-pst-fraudeur'
resultats = []

POSTES_PRIVILEGIES = ['president', 'min_int', 'min_just', 'juge', 'commissaire',
                      'min_fin', 'pm', 'capitaine_port', 'chef_douanes', 'commandant']


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
    resultats.append((bool(cond), nom, str(detail)[:170]))


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
        'name': nom, 'country': PAYS, 'current_city': VILLE,
        'stats': {}, 'resources': {}, 'qualifications': {}, 'effets_actifs': {},
        'stats_affaiblies': {}, 'demandeur_emploi': False, 'bonus_lobbyiste': 0,
        'day': 5, 'pa': 20, 'liquide': 5000, 'arg': 5000
    }, token=token, prefer='return=representation')


def poste_de(nom):
    c, b = http('GET', '/rest/v1/personnages?select=poste&name=eq.' + urllib.request.quote(nom))
    return (b[0]['poste'] if b else None)


def forger(nom, token, poste_id, city=None):
    """Tente d'ecrire un poste sur SA PROPRE ligne — le geste que la faille autorisait."""
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(nom),
         {'poste': {'id': poste_id, 'name': poste_id, 'city': city}}, token=token)
    return poste_de(nom)


def main():
    print('Ouverture des sessions...')
    tokM, tokC, tokF = session('maire'), session('commissaire'), session('fraudeur')
    for nom, tok in ((MAIRE, tokM), (CMR, tokC), (FRAUDEUR, tokF)):
        c, b = creer(nom, tok)
        verifier('personnage %s cree' % nom.split('-')[2], c in (200, 201), 'HTTP %s %s' % (c, b))

    # ================== 1. FALSIFICATION DE POSTE ==================
    for poste in POSTES_PRIVILEGIES:
        obtenu = forger(FRAUDEUR, tokF, poste, VILLE)
        verifier('falsification refusee : %s' % poste, obtenu is None, obtenu)

    # depute (champ separe)
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(FRAUDEUR),
         {'poste_depute': {'id': 'depute', 'city': VILLE}}, token=tokF)
    c, b = http('GET', '/rest/v1/personnages?select=poste_depute&name=eq.' + urllib.request.quote(FRAUDEUR))
    verifier('falsification refusee : depute', (b[0]['poste_depute'] if b else 1) is None, b)

    # ================== 2. PREROGATIVES APRES FALSIFICATION ==================
    forger(FRAUDEUR, tokF, 'commissaire', VILLE)
    c, b = rpc('arrestation_urgence', {'p_cible': CMR, 'p_motif': 'abus'}, tokF)
    verifier('faux commissaire : arrestation refusee',
             b and b.get('raison') == 'autorite_insuffisante', b)
    c, b = rpc('caisse_commissariat_lire', {'p_id': 'republic_commissariat_capitale'}, tokF)
    verifier('faux commissaire : caisse refusee', b and b.get('ok') is False, b)
    c, b = rpc('commissaire_enqueter', {'p_cible': CMR}, tokF)
    verifier('faux commissaire : enquete refusee',
             b and b.get('raison') == 'autorite_insuffisante', b)

    forger(FRAUDEUR, tokF, 'president')
    c, b = rpc('presidence_gracier', {'p_condamne': CMR, 'p_jour': 5}, tokF)
    verifier('faux President : grace refusee',
             c in (400, 401, 403) or (b and b.get('ok') is not True), 'HTTP %s %s' % (c, b))

    forger(FRAUDEUR, tokF, 'juge')
    c, b = rpc('justice_prolonger_peine',
               {'p_cible': CMR, 'p_motifs': [{'type': 'x', 'jours': 5}], 'p_forcer_qhs': False}, tokF)
    verifier('faux juge : prolongation de peine refusee',
             c in (400, 401, 403) or (b and b.get('ok') is not True), 'HTTP %s %s' % (c, b))

    forger(FRAUDEUR, tokF, 'min_fin')
    c, b = rpc('entreprise_preempter',
               {'p_acteur': FRAUDEUR, 'p_entreprise': 'zztest', 'p_montant': 1, 'p_duree': 1}, tokF)
    verifier('faux ministre des Finances : preemption refusee',
             c in (400, 401, 403) or (b and b.get('ok') is not True), 'HTTP %s %s' % (c, b))

    forger(FRAUDEUR, tokF, 'capitaine_port')
    c, b = rpc('fixer_repartition_port',
               {'p_cle': 'zztest', 'p_capitale': 1, 'p_ville_a': 0, 'p_ville_b': 0}, tokF)
    verifier('faux capitaine du Port : repartition refusee',
             c in (400, 401, 403) or (b and b.get('ok') is not True), 'HTTP %s %s' % (c, b))

    c, b = rpc('poste_nommer', {'p_poste': 'commissaire', 'p_city': VILLE,
                                'p_destinataire': FRAUDEUR}, tokF)
    verifier('faux maire : nomination refusee',
             b and b.get('raison') == 'autorite_insuffisante', b)

    # ================== 3. CHEMIN LEGITIME : ELECTION ==================
    # Le cycle electoral a ete pose cote serveur (fixture MCP) avec MAIRE comme elu.
    obtenu = forger(MAIRE, tokM, 'maire', VILLE)
    verifier('elu legitime : le pont client est accepte',
             obtenu and obtenu.get('id') == 'maire', obtenu)

    # ================== 4. CHEMIN LEGITIME : NOMINATION ==================
    c, b = rpc('poste_nommer', {'p_poste': 'commissaire', 'p_city': VILLE,
                                'p_destinataire': CMR}, tokM)
    verifier('le maire elu peut nommer un commissaire',
             b and b.get('decision') == 'proposition_envoyee', b)
    nomination = (b or {}).get('id')

    c, b = rpc('poste_accepter_nomination', {'p_id': nomination}, tokF)
    verifier('un tiers ne peut pas accepter la nomination d autrui',
             b and b.get('raison') == 'nomination_pas_pour_vous', b)

    c, b = rpc('poste_accepter_nomination', {'p_id': nomination}, tokC)
    verifier('le destinataire accepte et prend la fonction', b and b.get('ok') is True, b)
    verifier('la fiche porte desormais le poste atteste',
             (poste_de(CMR) or {}).get('id') == 'commissaire', poste_de(CMR))

    c, b = rpc('arrestation_urgence', {'p_cible': FRAUDEUR, 'p_motif': 'trouble'}, tokC)
    verifier('commissaire LEGITIME : arrestation autorisee', b and b.get('ok') is True, b)
    c, b = rpc('poste_accepter_nomination', {'p_id': nomination}, tokC)
    verifier('une nomination ne se consomme qu une fois',
             b and b.get('raison') == 'nomination_introuvable', b)

    # ================== 5. REVOCATION ==================
    c, b = rpc('poste_revoquer', {'p_poste': 'commissaire', 'p_city': VILLE}, tokM)
    verifier('revocation refusee pendant la protection de 3 jours',
             b and b.get('raison') == 'titulaire_protege', b)
    http('PATCH', '/rest/v1/postes_attribues?id=eq.' + PAYS + '_commissaire_' + VILLE,
         {'depuis': '2026-09-01T00:00:00Z'}, token=tokM)   # doit echouer : table fermee
    c, b = http('GET', '/rest/v1/postes_attribues?select=depuis&id=eq.' + PAYS + '_commissaire_' + VILLE)
    verifier('un client ne peut pas rajeunir sa propre protection',
             b and b[0]['depuis'] > '2026-09-10', b)

    # ================== 6. PERTE DU POSTE ==================
    # Demission : NULL est toujours accepte, et doit effacer l'attestation -- sans quoi l'ancien
    # titulaire pourrait reecrire son poste sur sa fiche et le reprendre par la porte de sortie.
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(CMR),
         {'poste': None}, token=tokC)
    verifier('demission : la fiche ne porte plus le poste', poste_de(CMR) is None, poste_de(CMR))
    c, b = http('GET', '/rest/v1/postes_attribues?select=id&titulaire=eq.' + urllib.request.quote(CMR))
    verifier('demission : l attestation est effacee du registre', b == [], b)

    obtenu = forger(CMR, tokC, 'commissaire', VILLE)
    verifier('ancien titulaire : impossible de reprendre son poste', obtenu is None, obtenu)
    c, b = rpc('arrestation_urgence', {'p_cible': FRAUDEUR, 'p_motif': 'apres demission'}, tokC)
    verifier('ancien titulaire : prerogative refusee',
             b and b.get('raison') == 'autorite_insuffisante', b)

    # Le maire elu, lui, conserve sa fonction : une election n'est pas un registre de nomination.
    verifier('l elu conserve sa fonction', (poste_de(MAIRE) or {}).get('id') == 'maire', poste_de(MAIRE))

    return rapport()


def rapport():
    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-58s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    print('Fixtures a nettoyer : zztest-pst-*')
    return 1 if ko else 0


if __name__ == '__main__':
    sys.exit(main() or 0)
