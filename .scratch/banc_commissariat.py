# BANC — REFONTE DU COMMISSARIAT DE LUTHECIA (15 septembre 2026).
#
# Verifie par HTTP reel, avec de vraies sessions anonymes, ce que le SERVEUR tranche :
# arrestation d'urgence, acces a la caisse, plainte-dossier, enquete, et le retrait du
# cambriolage. Tout est en 'zztest-' / 'zzville-cmr' / 'zzville-pnj' : les deux personnages reels
# et les trois commissariats reels ne sont jamais ecrits.
#
# NOTE DE LECTURE. Le banc pose les postes en PATCHant la ligne du personnage, parce que c'est
# exactement ainsi que le jeu les attribue (state.poste ecrit cote client puis sauvegarde). Ce
# n'est donc pas un contournement invente pour le test : c'est le modele reel, et c'est aussi la
# faille systemique signalee dans le rapport -- aucune table n'atteste qui detient un poste.

import json, os, re, sys, time, urllib.error, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(RACINE, '.scratch/banc_entrepots_commandes.py'), encoding='utf-8').read()
URL = re.search(r'URL = "([^"]+)"', SRC).group(1)
BLOC = SRC[SRC.index('ANON = ('):SRC.index('SUF =')]
ANON = ''.join(re.findall(r'"([^"]*)"', BLOC))

SUF = str(int(time.time()))
VILLE = 'zzville-cmr'
VILLE_PNJ = 'zzville-pnj'
CMR = 'zztest-cmr-commissaire-' + SUF
CIBLE = 'zztest-cmr-cible-' + SUF
QUIDAM = 'zztest-cmr-quidam-' + SUF
CAISSE = 'republic_commissariat_' + VILLE
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
    print('ABANDON : session anonyme impossible pour %s (debit limite).' % etiquette)
    sys.exit(2)


def creer(nom, token, ville):
    return http('POST', '/rest/v1/personnages', {
        'name': nom, 'country': 'republic', 'current_city': ville,
        'stats': {}, 'resources': {}, 'qualifications': {}, 'effets_actifs': {},
        'stats_affaiblies': {}, 'demandeur_emploi': False, 'bonus_lobbyiste': 0,
        'day': 5, 'pa': 20, 'liquide': 5000, 'arg': 5000
    }, token=token, prefer='return=representation')


def poser_poste(nom, token, poste):
    return http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(nom),
                {'poste': poste}, token=token)


def lire(nom):
    c, b = http('GET', '/rest/v1/personnages?select=name,est_emprisonne&name=eq.' +
                urllib.request.quote(nom))
    return (b[0] if b else None)


def main():
    print('Ouverture des sessions (debit limite : cela peut prendre une minute)...')
    tokC, tokQ, tokX = session('commissaire'), session('quidam'), session('cible')

    for nom, tok in ((CMR, tokC), (QUIDAM, tokQ), (CIBLE, tokX)):
        c, b = creer(nom, tok, VILLE)
        verifier('personnage %s cree' % nom.split('-')[2], c in (200, 201), 'HTTP %s %s' % (c, b))

    poser_poste(CMR, tokC, {'id': 'commissaire', 'name': 'Commissaire', 'city': VILLE})

    # --- FIXTURES zztest (tables ouvertes en ecriture cliente, aucune donnee reelle touchee) ---
    rpc('caisse_institution_mouvement', {'p_id': CAISSE, 'p_delta': 500}, tokC)   # cree la caisse
    http('POST', '/rest/v1/indices_villes',
         {'id': 'republic_' + VILLE, 'data': {'isn': 30, 'ie': 50, 'social': 45, 'piete': 40, 'moral': 50}},
         token=tokC, prefer='resolution=merge-duplicates')
    http('POST', '/rest/v1/titulaires_pnj',
         {'id': 'republic_commissaire_' + VILLE_PNJ, 'country': 'republic',
          'poste_id': 'commissaire', 'city': VILLE_PNJ, 'nom_pnj': 'zztest Commissaire PNJ'},
         token=tokC, prefer='resolution=merge-duplicates')

    # =================== ARRESTATION D'URGENCE ===================
    c, b = rpc('arrestation_urgence', {'p_cible': CIBLE, 'p_motif': 'test'}, tokQ)
    verifier('sans poste : arrestation refusee',
             b and b.get('raison') == 'autorite_insuffisante', b)

    poser_poste(QUIDAM, tokQ, {'id': 'juge', 'name': 'Juge'})
    c, b = rpc('arrestation_urgence', {'p_cible': CIBLE, 'p_motif': 'test'}, tokQ)
    verifier('le juge est EXCLU des autorites habilitees',
             b and b.get('raison') == 'autorite_insuffisante', b)
    poser_poste(QUIDAM, tokQ, None)

    c, b = rpc('arrestation_urgence', {'p_cible': CMR, 'p_motif': 'test'}, tokC)
    verifier('on ne s arrete pas soi-meme', b and b.get('raison') == 'cible_est_l_acteur', b)

    c, b = rpc('arrestation_urgence', {'p_cible': CIBLE, 'p_motif': ''}, tokC)
    verifier('motif obligatoire', b and b.get('raison') == 'motif_absent', b)

    # le coeur : aucune condition d'etat d'urgence, le commissaire est habilite
    c, b = rpc('arrestation_urgence', {'p_cible': CIBLE, 'p_motif': 'trouble a l ordre public'}, tokC)
    verifier('le commissaire peut arreter, sans etat d urgence', b and b.get('ok') is True, b)
    verifier('duree de 1 jour', b and (b.get('jour_fin') - b.get('jour_debut')) == 1, b)
    det_id = (b or {}).get('detention_id')

    ligne = lire(CIBLE)
    ee = (ligne or {}).get('est_emprisonne') or {}
    verifier('la cible est reellement detenue', isinstance(ee, dict) and ee.get('jours') == 1, ee)
    verifier('ancres de liberation presentes (jours + debutTs)',
             ee.get('jours') and ee.get('debutTs'), ee)
    verifier('jourFin exprime dans le day de la CIBLE', ee.get('jourFin') == 6, ee)
    verifier('detentionId relie a la ligne de registre', ee.get('detentionId') == det_id, ee)
    verifier('ville et pays portes par la detention',
             ee.get('city') == VILLE and ee.get('country') == 'republic', ee)

    c, reg = http('GET', '/rest/v1/detentions?select=*&id=eq.' + str(det_id))
    d = reg[0] if reg else None
    verifier('ligne detentions creee', bool(d), reg)
    verifier('registre : autorite nommee', d and 'commissaire' in (d.get('autorite') or ''), d and d.get('autorite'))
    verifier('registre : issue judiciaire renseignee',
             d and d.get('issue_judiciaire') == 'arrestation_urgence', d and d.get('issue_judiciaire'))
    verifier('registre : motifs structures', d and isinstance(d.get('motifs'), list) and d['motifs'], d and d.get('motifs'))
    verifier('registre : detention ouverte (mode_fin vide)', d and d.get('mode_fin') is None, d and d.get('mode_fin'))
    verifier('registre : jamais QHS', d and d.get('qhs') is False, d and d.get('qhs'))

    c, idx = http('GET', '/rest/v1/indices_villes?select=data&id=eq.republic_' + VILLE)
    d0 = (idx[0]['data'] if idx else {}) or {}
    verifier('effet de ville : securite +1 (cle isn)', d0.get('isn') == 31, d0)
    verifier('effet de ville : indice social -1', d0.get('social') == 44, d0)

    c, b = rpc('arrestation_urgence', {'p_cible': CIBLE, 'p_motif': 'bis'}, tokC)
    verifier('cible deja detenue : refus', b and b.get('raison') == 'cible_deja_detenue', b)

    # juridiction : le commissaire d une autre ville n a pas autorite
    poser_poste(CMR, tokC, {'id': 'commissaire', 'name': 'Commissaire', 'city': 'zzville-ailleurs'})
    c, b = rpc('arrestation_urgence', {'p_cible': QUIDAM, 'p_motif': 'hors zone'}, tokC)
    verifier('commissaire hors de SA ville : refus',
             b and b.get('raison') == 'hors_juridiction_ville', b)
    poser_poste(CMR, tokC, {'id': 'commissaire', 'name': 'Commissaire', 'city': VILLE})

    # --- FIXTURES zztest (tables ouvertes en ecriture cliente, aucune donnee reelle touchee) ---
    rpc('caisse_institution_mouvement', {'p_id': CAISSE, 'p_delta': 500}, tokC)   # cree la caisse
    http('POST', '/rest/v1/indices_villes',
         {'id': 'republic_' + VILLE, 'data': {'isn': 30, 'ie': 50, 'social': 45, 'piete': 40, 'moral': 50}},
         token=tokC, prefer='resolution=merge-duplicates')
    http('POST', '/rest/v1/titulaires_pnj',
         {'id': 'republic_commissaire_' + VILLE_PNJ, 'country': 'republic',
          'poste_id': 'commissaire', 'city': VILLE_PNJ, 'nom_pnj': 'zztest Commissaire PNJ'},
         token=tokC, prefer='resolution=merge-duplicates')

    # =================== CAISSE ===================
    c, b = http('GET', '/rest/v1/caisses_batiments?select=id&id=eq.' + CAISSE, token=tokQ)
    verifier('lecture directe d une caisse de commissariat : plus rien ne sort',
             c == 200 and b == [], 'HTTP %s %s' % (c, b))
    c, b = http('GET', '/rest/v1/caisses_batiments?select=id&id=like.*commissariat*', token=tokQ)
    verifier('aucune caisse de commissariat lisible en masse', c == 200 and b == [], b)
    c, b = http('GET', '/rest/v1/caisses_batiments?select=id&id=eq.republic_tribunal_capitale', token=tokQ)
    verifier('les autres caisses restent lisibles (aucune regression)', c == 200, 'HTTP %s' % c)

    c, b = rpc('caisse_commissariat_lire', {'p_id': CAISSE}, tokQ)
    verifier('un joueur ordinaire ne lit pas la caisse',
             b and b.get('raison') == 'autorite_insuffisante', b)
    c, b = rpc('caisse_commissariat_lire', {'p_id': CAISSE}, tokC)
    verifier('le commissaire lit la caisse de SA ville', b and b.get('ok') is True, b)
    verifier('solde reellement renvoye', b and b.get('solde') is not None, b)
    c, b = rpc('caisse_commissariat_lire', {'p_id': 'republic_commissariat_capitale'}, tokC)
    verifier('le commissaire ne lit pas la caisse d une autre ville',
             b and b.get('raison') == 'autorite_insuffisante', b)

    poser_poste(QUIDAM, tokQ, {'id': 'min_int', 'name': "Ministre de l'Interieur"})
    c, b = rpc('caisse_commissariat_lire', {'p_id': CAISSE}, tokQ)
    verifier('le ministre de l Interieur lit les commissariats de son empire',
             b and b.get('ok') is True, b)
    poser_poste(QUIDAM, tokQ, None)

    # l oracle de lecture par mouvement nul est ferme
    c, b = rpc('caisse_institution_mouvement_plafonne', {'p_id': CAISSE, 'p_montant': 0}, tokQ)
    verifier('mouvement nul refuse (plus d oracle de lecture)',
             b and b.get('ok') is False and b.get('raison') == 'parametres_invalides', b)
    verifier('aucun solde renvoye par le mouvement plafonne', b and 'solde' not in b, b)
    c, b = rpc('caisse_institution_mouvement', {'p_id': CAISSE, 'p_delta': 0}, tokQ)
    verifier('delta nul refuse', b and b.get('ok') is False, b)
    c, b = rpc('caisse_institution_mouvement', {'p_id': CAISSE, 'p_delta': 1}, tokQ)
    verifier('un mouvement reel ne divulgue plus le solde', b and 'solde' not in b, b)

    # =================== PLAINTE ===================
    # ville a commissaire PNJ, sans element a charge : classement sans suite.
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(QUIDAM),
         {'current_city': VILLE_PNJ}, token=tokQ)
    c, b = rpc('plainte_deposer', {'p_cible': CIBLE, 'p_motif': 'nuisances'}, tokQ)
    verifier('plainte deposee (commissaire PNJ)', b and b.get('ok') is True, b)
    verifier('commissaire PNJ : classement sans suite faute d element',
             b and b.get('decision') == 'classee', b)
    verifier('aucune transmission magique au tribunal', b and b.get('decision') != 'transmise', b)

    # meme ville PNJ, mais la cible a un acte trace non decouvert : enquete + garde a vue reelle
    http('POST', '/rest/v1/actions_tracables',
         {'id': 'zztest-acte-' + SUF, 'auteur': CMR, 'cible': CIBLE, 'type_action': 'vol',
          'country': 'republic', 'city': VILLE_PNJ, 'jour': 4, 'jour_expiration': 40,
          'decouvert': False}, token=tokQ)
    c, b = rpc('plainte_deposer', {'p_cible': CMR, 'p_motif': 'vol presume'}, tokQ)
    verifier('plainte avec element a charge : enquete ouverte',
             b and b.get('decision') == 'enquete_ouverte', b)
    ligne = lire(CMR)
    eeC = (ligne or {}).get('est_emprisonne') or {}
    verifier('garde a vue reelle de 2 jours a l issue de l enquete',
             isinstance(eeC, dict) and eeC.get('jours') == 2, eeC)

    # ville a commissaire PJ : le dossier attend sa decision
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(QUIDAM),
         {'current_city': VILLE}, token=tokQ)
    c, b = rpc('plainte_deposer', {'p_cible': CIBLE, 'p_motif': 'tapage'}, tokQ)
    verifier('commissaire PJ : le dossier lui est transmis, rien n est decide',
             b and b.get('decision') == 'transmise_commissaire', b)
    verifier('le commissaire competent est nomme', b and b.get('commissaire') == CMR, b)
    dossier = (b or {}).get('id')

    c, b = rpc('plainte_deposer', {'p_cible': CIBLE, 'p_motif': 'tapage bis'}, tokQ)
    verifier('anti-spam : une seule plainte en cours par cible',
             b and b.get('raison') == 'plainte_deja_en_cours', b)

    c, b = rpc('plainte_traiter', {'p_id': dossier, 'p_decision': 'classer'}, tokQ)
    verifier('un non-commissaire ne peut pas instruire',
             b and b.get('raison') == 'autorite_insuffisante', b)

    c, b = http('PATCH', '/rest/v1/plaintes_en_cours?id=eq.' + str(dossier),
                {'data': '{"status":"classee"}'}, token=tokQ)
    c2, apres = http('GET', '/rest/v1/plaintes_en_cours?select=data&id=eq.' + str(dossier))
    verifier('un joueur ne peut pas modifier le dossier d autrui',
             apres and 'commissaire_pj' in (apres[0]['data'] or ''), 'HTTP %s' % c)

    c, b = http('DELETE', '/rest/v1/plaintes_en_cours?id=eq.' + str(dossier), token=tokQ)
    c2, apres = http('GET', '/rest/v1/plaintes_en_cours?select=id&id=eq.' + str(dossier))
    verifier('un joueur ne peut pas supprimer une plainte', bool(apres), 'HTTP %s' % c)

    c, b = rpc('plainte_traiter', {'p_id': dossier, 'p_decision': 'classer'}, tokC)
    verifier('le commissaire classe son dossier', b and b.get('decision') == 'classee', b)
    c, b = rpc('plainte_traiter', {'p_id': dossier, 'p_decision': 'enqueter'}, tokC)
    verifier('un dossier deja instruit ne se rejoue pas',
             b and b.get('raison') == 'dossier_deja_instruit', b)

    # =================== MIROIR DES COUTS ===================
    # Le miroir n'est pas lisible par un client (RLS sans policy de lecture, et c'est voulu) :
    # on le teste donc par son COMPORTEMENT, via payer_ordre, qui est le seul consommateur reel.
    c, b = rpc('payer_ordre', {'p_acteur': CMR, 'p_fn': 'arreter', 'p_pa': 3, 'p_cost': 500}, tokC)
    verifier('arreter ne coute plus 500 FR (cout non declare)',
             b and b.get('raison') == 'cout_non_declare', b)
    c, b = rpc('payer_ordre', {'p_acteur': CMR, 'p_fn': 'arreter', 'p_pa': 3, 'p_cost': 0}, tokC)
    verifier('arreter coute 3 PA et 0 FR', b and b.get('ok') is True, b)
    c, b = rpc('payer_ordre', {'p_acteur': CMR, 'p_fn': 'cambrioler_caisse_commissariat',
                               'p_pa': 3, 'p_cost': 0}, tokC)
    verifier('cambrioler_caisse_commissariat : ordre inconnu du serveur',
             b and b.get('raison') == 'ordre_inconnu', b)
    for fn in ('dossiers_plaintes', 'subvention_min_int'):
        c, b = rpc('payer_ordre', {'p_acteur': CMR, 'p_fn': fn, 'p_pa': 0, 'p_cost': 0}, tokC)
        verifier('%s est un ordre declare et gratuit' % fn, b and b.get('ok') is True, b)

    return rapport()


def rapport():
    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-62s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    print('Fixtures a nettoyer : zztest-cmr-%%-' + SUF)
    return 1 if ko else 0


if __name__ == '__main__':
    sys.exit(main() or 0)
