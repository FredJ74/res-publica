# BANC — LES PA SONT SERVEUR-AUTORITAIRES (16 septembre 2026).
#
# Critere de fermeture du chantier, tel qu'il a ete pose : « un joueur ne doit plus pouvoir
# obtenir un seul PA supplementaire en manipulant le client, sa fiche ou une requete directe ».
# Ce banc essaie donc les trois, puis verifie l'autre moitie du contrat -- que les gains
# LEGITIMES marchent toujours, au bon montant, une seule fois, et qu'ils survivent a une
# reconnexion. Un verrou qui casserait le repos nocturne ne serait pas un verrou, ce serait une
# panne.
#
# Le game design n'est pas touche : +12 au repos, plafond 30, sanction QHS qui remplace le stock,
# bonus differe consomme au Dormir. Le banc CONSTATE ces valeurs, il ne les choisit pas.
#
# Donnees : un personnage 'zztest-pa-aut-*' cree et supprime par la passe.

import json, os, re, sys, time, urllib.error, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(RACINE, '.scratch/banc_entrepots_commandes.py'), encoding='utf-8').read()
URL = re.search(r'URL = "([^"]+)"', SRC).group(1)
BLOC = SRC[SRC.index('ANON = ('):SRC.index('SUF =')]
ANON = ''.join(re.findall(r'"([^"]*)"', BLOC))

JOUEUR = 'zztest-pa-aut-' + str(int(time.time()))
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


def rpc(fn, params, token=None):
    c, b = http('POST', '/rest/v1/rpc/' + fn, params, token=token or JETON)
    if isinstance(b, list):
        b = b[0] if b else None
    return c, b


def session():
    for _ in range(8):
        c, b = http('POST', '/auth/v1/signup', {})
        if c == 200 and isinstance(b, dict) and b.get('access_token'):
            return b['access_token']
        time.sleep(12)
    print('ABANDON : session anonyme impossible (limitation de debit).')
    sys.exit(2)


def pa():
    """Relecture SERVEUR, jamais la valeur renvoyee par l'appel qu'on teste."""
    c, b = http('GET', '/rest/v1/personnages?select=pa&name=eq.' + urllib.request.quote(JOUEUR))
    return (b[0]['pa'] if b else None)


def ecrire_pa(valeur):
    return http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR),
                {'pa': valeur}, token=JETON)[0]


def main():
    global JETON
    print('Ouverture de la session...')
    JETON = session()

    # ================= 1. LA NAISSANCE ==================
    # creation.js envoie 10, mais rien ne l'y obligeait : on naissait avec ce qu'on voulait.
    c, b = http('POST', '/rest/v1/personnages', {
        'name': JOUEUR, 'country': 'republic', 'current_city': 'capitale',
        'stats': {}, 'resources': {}, 'qualifications': {}, 'effets_actifs': {},
        'stats_affaiblies': {}, 'demandeur_emploi': False, 'bonus_lobbyiste': 0,
        'day': 5, 'pa': 999, 'hp': 100, 'moral': 75, 'liquide': 5000, 'arg': 5000
    }, token=JETON, prefer='return=representation')
    verifier('naitre avec 999 PA : borne a la reserve de depart', c in (200, 201) and pa() == 10,
             'HTTP %s / pa=%s' % (c, pa()))

    # ================= 2. LA REQUETE DIRECTE ==================
    code = ecrire_pa(999)
    verifier('PATCH pa=999 : la valeur serveur ne bouge pas', pa() == 10, 'HTTP %s / pa=%s' % (code, pa()))
    ecrire_pa(11)
    verifier('PATCH pa=11 : pas meme un seul PA de plus', pa() == 10, pa())
    ecrire_pa(30)
    verifier('PATCH pa=30 (le plafond du jeu) : refuse aussi', pa() == 10, pa())

    # La baisse reste permise : les debits clients residuels (Helvetia, notaire, petite annonce,
    # aliment perime) et les mises a zero d'hospitalisation doivent continuer de mordre.
    ecrire_pa(4)
    verifier('une BAISSE cliente reste effective (debits residuels intacts)', pa() == 4, pa())
    ecrire_pa(999)
    verifier('et on ne remonte pas depuis ce nouveau plancher', pa() == 4, pa())

    # ================= 3. LA FICHE ==================
    # Le vrai chemin du jeu : sbSavePersonnage publie la fiche ENTIERE en permanence. Le refus
    # doit etre silencieux, sinon chaque sauvegarde echouerait et le jeu ne fonctionnerait plus.
    code, _ = http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR),
                   {'pa': 30, 'moral': 63, 'hp': 88, 'day': 6}, token=JETON)
    c2, b = http('GET', '/rest/v1/personnages?select=pa,moral,hp,day&name=eq.'
                 + urllib.request.quote(JOUEUR), token=JETON)
    f = b[0] if b else {}
    verifier('la sauvegarde de fiche n echoue pas', code in (200, 204), 'HTTP %s' % code)
    verifier('elle ecrit bien les autres champs',
             f.get('moral') == 63 and f.get('hp') == 88 and f.get('day') == 6, f)
    verifier('mais les PA qu elle publie sont ignores', f.get('pa') == 4, f)

    # ================= 4. LES DEPENSES ==================
    avant = pa()
    c, b = rpc('payer_ordre', {'p_acteur': JOUEUR, 'p_fn': 'plainte_police', 'p_pa': 1, 'p_cost': 0})
    verifier('un ordre a 1 PA est accepte', b and b.get('ok') is True, b)
    verifier('et debite exactement 1 PA', pa() == avant - 1, '%s -> %s' % (avant, pa()))

    avant = pa()
    c, b = rpc('payer_ordre', {'p_acteur': JOUEUR, 'p_fn': 'arreter', 'p_pa': 3, 'p_cost': 0})
    verifier('un ordre a 3 PA est accepte quand il en reste assez', b and b.get('ok') is True, b)
    verifier('et debite exactement 3 PA', pa() == avant - 3, '%s -> %s' % (avant, pa()))

    c, b = rpc('payer_ordre', {'p_acteur': JOUEUR, 'p_fn': 'arreter', 'p_pa': 3, 'p_cost': 0})
    verifier('a 0 PA, l ordre est refuse pour manque de PA',
             b and b.get('ok') is False and b.get('raison') == 'pa_insuffisants', b)
    verifier('et rien n est preleve sur ce refus', pa() == 0, pa())

    # Tenter de se recharger juste avant de payer ne change rien : c'est le scenario reel.
    ecrire_pa(20)
    c, b = rpc('payer_ordre', {'p_acteur': JOUEUR, 'p_fn': 'arreter', 'p_pa': 3, 'p_cost': 0})
    verifier('se recharger avant de payer ne debloque pas l ordre',
             b and b.get('ok') is False and b.get('raison') == 'pa_insuffisants', b)

    # ================= 5. LES GAINS LEGITIMES ==================
    # (a) remboursement atteste : montant declare au serveur, jamais rejouable.
    c, b = rpc('pa_crediter_atteste', {'p_acteur': JOUEUR, 'p_source': 'aliment_frais',
                                       'p_reference': JOUEUR + '-repas-1', 'p_ordre': None})
    verifier('un aliment frais rend bien 1 PA', b and b.get('ok') is True and b.get('montant') == 1, b)
    verifier('credite reellement en base', pa() == 1, pa())
    c, b = rpc('pa_crediter_atteste', {'p_acteur': JOUEUR, 'p_source': 'aliment_frais',
                                       'p_reference': JOUEUR + '-repas-1', 'p_ordre': None})
    verifier('le meme repas ne peut pas etre rejoue',
             b and b.get('ok') is False and b.get('raison') == 'credit_deja_accorde', b)
    verifier('et le rejeu ne credite rien', pa() == 1, pa())

    c, b = rpc('pa_crediter_atteste', {'p_acteur': JOUEUR, 'p_source': 'source_inventee',
                                       'p_reference': 'x', 'p_ordre': None})
    verifier('une source de gain inventee par le client est refusee',
             b and b.get('ok') is False and b.get('raison') == 'source_non_declaree', b)

    # (b) bonus differe : le client nomme la source, le SERVEUR en fixe le montant.
    c, b = rpc('pa_bonus_differe_crediter', {'p_acteur': JOUEUR, 'p_source': 'service_etage_hotel'})
    verifier('le service d etage arme un bonus differe de 1',
             b and b.get('ok') is True and b.get('montant') == 1, b)
    verifier('le bonus n est PAS un PA immediat', pa() == 1, pa())
    c, b = rpc('pa_bonus_differe_crediter', {'p_acteur': JOUEUR, 'p_source': 'gros_bonus_invente'})
    verifier('une source de bonus inventee est refusee',
             b and b.get('ok') is False and b.get('raison') == 'source_non_declaree', b)

    # (c) bonus de chambre : il faut une reservation reelle, et l hotel doit etre declare.
    c, b = rpc('pa_bonus_chambre', {'p_acteur': JOUEUR, 'p_batiment': 'hotel-republica'})
    verifier('pas de bonus de chambre sans reservation payee',
             b and b.get('ok') is False and b.get('raison') == 'aucune_reservation', b)
    c, b = rpc('pa_bonus_chambre', {'p_acteur': JOUEUR, 'p_batiment': 'zztest-palace-invente'})
    verifier('un hotel invente par le client ne donne aucun bonus',
             b and b.get('ok') is False and b.get('raison') == 'hotel_non_declare', b)

    # (d) repos nocturne : +12, plus le bonus differe arme, plafonne a 30, une fois par jour.
    avant = pa()
    c, b = rpc('pa_repos_nocturne', {'p_acteur': JOUEUR})
    verifier('le repos nocturne rend les PA', b and b.get('ok') is True, b)
    verifier('+12 et le bonus differe consomme', pa() == min(30, avant + 12 + 1),
             '%s -> %s (attendu %s)' % (avant, pa(), min(30, avant + 12 + 1)))
    verifier('le serveur annonce le bonus consomme', b and b.get('bonus_consomme') == 1, b)
    apres_repos = pa()
    c, b = rpc('pa_repos_nocturne', {'p_acteur': JOUEUR})
    verifier('on ne se repose pas deux fois le meme jour',
             b and b.get('ok') is False and b.get('raison') == 'deja_repose', b)
    verifier('et le second repos ne credite rien', pa() == apres_repos, pa())

    # (e) le bonus differe a bien ete remis a zero : il ne se recycle pas au repos suivant.
    c, b = rpc('pa_bonus_differe_crediter', {'p_acteur': JOUEUR, 'p_source': 'repas_gastronomique'})
    verifier('un nouveau bonus s arme apres consommation',
             b and b.get('ok') is True and b.get('bonus_differe') == 1, b)

    # ================= 5 bis. LES ALIMENTS ==================
    # L'effet en PA est applique dans la transaction qui RETIRE l'aliment : c'est la seule
    # unicite exacte. Le piege evite ici : deux aliments identiques ont la meme signature
    # (name/type/stackKey) -- si l'unicite reposait sur elle, le second n'aurait plus jamais
    # rien rapporte. Le banc achete donc deux fois le meme pain.
    maintenant = int(time.time() * 1000)
    pain = {'name': 'Pain de campagne', 'type': 'consommable', 'icon': 'ti-bread',
            'familleProduitMarche': 'aliment', 'dateAchat': maintenant}
    vieux = dict(pain, name='Pain rassis', dateAchat=maintenant - 9 * 24 * 3600 * 1000)
    http('PATCH', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR),
         {'inventory': [dict(pain), dict(pain), vieux], 'pa': 5}, token=JETON)
    depart = pa()

    sig = {'name': 'Pain de campagne', 'type': 'consommable', 'stackKey': ''}
    c, b = rpc('inventaire_consommer', {'p_acteur': JOUEUR, 'p_index': 0, 'p_signature': sig})
    verifier('un aliment frais rapporte 1 PA a la consommation',
             b and b.get('ok') is True and pa() == depart + 1, '%s -> %s' % (depart, pa()))
    c, b = rpc('inventaire_consommer', {'p_acteur': JOUEUR, 'p_index': 0, 'p_signature': sig})
    verifier('le SECOND pain identique rapporte lui aussi 1 PA',
             b and b.get('ok') is True and pa() == depart + 2, '%s -> %s' % (depart, pa()))
    c, b = rpc('inventaire_consommer', {'p_acteur': JOUEUR, 'p_index': 0, 'p_signature': sig})
    verifier('mais il n y en avait que deux : le troisieme essai ne donne rien',
             b and b.get('ok') is False and pa() == depart + 2, '%s / pa=%s' % (b, pa()))

    c, b = rpc('inventaire_consommer', {'p_acteur': JOUEUR, 'p_index': 0,
                                        'p_signature': {'name': 'Pain rassis', 'type': 'consommable',
                                                        'stackKey': ''}})
    verifier('un aliment perime coute 1 PA',
             b and b.get('ok') is True and b.get('aliment_frais') is False
             and pa() == depart + 1, '%s / pa=%s' % (b and b.get('aliment_frais'), pa()))

    # ================= 6. LA RECONNEXION ==================
    # Le client garde une copie locale ; c'est le serveur qui fait foi au retour.
    solde = pa()
    ecrire_pa(30)
    c, b = http('GET', '/rest/v1/personnages?select=pa&name=eq.' + urllib.request.quote(JOUEUR),
                token=JETON)
    verifier('apres reconnexion, le solde lu est celui du serveur',
             b and b[0]['pa'] == solde, '%s (serveur %s)' % (b[0]['pa'] if b else '?', solde))

    return rapport()


def rapport():
    http('DELETE', '/rest/v1/personnages?name=eq.' + urllib.request.quote(JOUEUR), token=JETON)
    c, reste = http('GET', '/rest/v1/personnages?select=name&name=eq.' + urllib.request.quote(JOUEUR))
    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %-58s %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    print('nettoyage : %s' % ('personnage de test supprime' if not reste else 'RESIDU ' + JOUEUR))
    return 1 if (ko or reste) else 0


if __name__ == '__main__':
    sys.exit(main() or 0)
