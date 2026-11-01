"""Banc PRIME DE SIGNATURE (31/10/2026, suite de #295) sur PostgreSQL JETABLE exclusivement.
Aucun DSN ni compte réel accepté. Reprend le décor et les doublures du banc des caisses
collectives (même fixture JWT), joue 20261031200000 et 20261031201000 TELLES QUELLES (état de la
production), puis 20261031220000.

Contre-épreuve : avant 20261031220000, une offre peut porter une prime arbitraire et le serveur ne
la verse pas (l'écran l'ajoutait de lui-même : argent sorti de nulle part) ; après, la prime est
bornée à l'offre, payée par la caisse du club d'arrivée et versée une seule fois au joueur.
Usage : python3 outils/bancs/banc-prime-signature-local.py --local-jetable
"""
import argparse, importlib.util, json, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location('banc_caisses', ROOT / 'outils/bancs/banc-caisses-collectives-local.py')
B = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(B)
M3 = ROOT / 'migrations/20261031220000_transfert_prime_signature_serveur.sql'
EMPREINTES_PRODUCTION = {'club_transfert_conclure(text)': '057d4b8e51e41eae3bc59d615a4df391',
                         'transferts_clubs_garder()': '57b1fac354c1140d9644954909424b1f'}

OFFRE = """INSERT INTO transferts_clubs VALUES ('%s','propose','{"statut":"propose","joueur":"Vince Kubrick","clubDepartId":"olympique-luthecia","clubArriveeId":"cheminote-montrouge","prixClub":400,"proposePar":"Jean Jaaj"%s}') RETURNING 1"""
ACCORD = """UPDATE transferts_clubs SET statut='attente_joueur', data=data||'{"statut":"attente_joueur"}' WHERE id='%s' RETURNING 1"""


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--local-jetable', action='store_true', required=True)
    p.parse_args()
    try:
        import pgserver, psycopg2
        server = pgserver.get_server(tempfile.mkdtemp(prefix='hg-prime-'), cleanup_mode='delete')
        c = psycopg2.connect(server.get_uri()); c.autocommit = True; q = c.cursor(); Erreur = psycopg2.Error
    except ImportError:
        c = q = B._SessionPsql(); Erreur = B._ErreurPsql
        print('(pilote psql local : pgserver/psycopg2 absents)')
    q.execute(B.SCHEMA)
    # Droit de la production (prévol du 31/10) : le crédit interne n'est pas exposé à l'écran.
    q.execute('REVOKE ALL ON FUNCTION assemblee_crediter_joueur(text, integer) FROM PUBLIC, anon, authenticated')
    n = [0]; echecs = []

    def qui(nom):
        q.execute('RESET ROLE')
        q.execute("SELECT set_config('hg.uid', %s, false), set_config('hg.poste', '', false)", (B.UID.get(nom, ''),))
        q.execute('SET ROLE authenticated')

    def serveur(): q.execute('RESET ROLE')

    def essai(sql, args=None):
        try:
            q.execute(sql, args)
            r = q.fetchone() if q.description else None
            return None if not r or r[0] is None else str(r[0])
        except Erreur as e:
            return 'ERR:' + (e.pgerror or str(e)).strip().splitlines()[0]

    def verifie(nom, obtenu, attendu):
        n[0] += 1
        ok = attendu(obtenu) if callable(attendu) else obtenu == attendu
        print(('OK  ' if ok else 'ECHEC ') + str(n[0]) + ' ' + nom + ' -> ' + str(obtenu))
        if not ok: echecs.append(nom)

    def un(sql, args=None):
        serveur(); q.execute(sql, args); return q.fetchone()[0]

    def caisses():
        serveur(); q.execute("SELECT (data->>'caisse')::float FROM budgets_clubs WHERE id IN ('cheminote-montrouge','olympique-luthecia') ORDER BY id")
        a = float(q.fetchone()[0]); q.execute("SELECT (data->>'caisse')::float FROM budgets_clubs WHERE id='olympique-luthecia'"); d = float(q.fetchone()[0])
        return (a, d)   # (arrivée cheminote, départ olympique)

    def vince():
        serveur(); q.execute("SELECT liquide::float, arg::float FROM personnages_donnees WHERE name='Vince Kubrick'"); return tuple(float(x) for x in q.fetchone())

    def conclure(tid):
        qui('Vince Kubrick'); r = essai("SELECT club_transfert_conclure(%s)::text", (tid,))
        return json.loads(r) if r and not r.startswith('ERR:') else r

    def preparer(tid, prime_json, caisse_arrivee):
        serveur(); q.execute("UPDATE budgets_clubs SET data=jsonb_set(data,'{caisse}',%s::jsonb) WHERE id='cheminote-montrouge'", (str(caisse_arrivee),))
        qui('Jean Jaaj'); r1 = essai(OFFRE % (tid, prime_json))
        qui('Angie Porcelana'); r2 = essai(ACCORD % tid)
        return (r1, r2)

    refus = lambda r: isinstance(r, str) and r.startswith('ERR:')

    # ============================================= A. ÉTAT DE LA PRODUCTION (avant 20261031220000)
    serveur(); q.execute(B.DECOR)
    q.execute(B.M1.read_text()); q.execute(B.M2.read_text())
    for f, h in EMPREINTES_PRODUCTION.items():
        # Corps sans lignes de commentaire : Supabase les retire à l'application.
        verifie('A0 empreinte identique à la production : ' + f, un("SELECT md5(regexp_replace(prosrc, E'\\\\n[ \\\\t]*--[^\\\\n]*', '', 'g')) FROM pg_proc WHERE oid=%s::regprocedure", ('public.' + f,)), h)
    verifie('A1 avant : une offre peut porter une prime forgée (texte)', preparer('t-av-texte', ',"prixJoueur":"9999999"', 500)[0], '1')
    verifie('A2 avant : une offre peut porter une prime d un million', preparer('t-av', ',"prixJoueur":1000000', 500), ('1', '1'))
    av = vince(); r = conclure('t-av')
    verifie('A3 avant : le serveur conclut sans verser la prime (l écran l ajoutait de lui-même)',
            (r.get('ok'), 'prime' in r, 'fiche' in r, vince() == av, caisses()), (True, False, False, True, (100.0, 1400.0)))

    # ============================================= B. APRÈS 20261031220000
    serveur(); q.execute(M3.read_text()); q.execute(M3.read_text())   # rejouable
    q.execute(B.DECOR)
    verifie('B1 prime en texte refusée à l offre', preparer('t-txt', ',"prixJoueur":"300"', 0)[0], refus)
    verifie('B2 prime négative refusée à l offre', preparer('t-neg', ',"prixJoueur":-50', 0)[0], refus)
    verifie('B3 prime décimale refusée à l offre', preparer('t-dec', ',"prixJoueur":10.5', 0)[0], refus)

    verifie('B4 offre avec prime de 300 acceptée par la présidente de départ', preparer('t1', ',"prixJoueur":300', 500), ('1', '1'))
    av = vince(); cav = caisses(); r = conclure('t1')
    verifie('B5 arrivée couvre le prix mais pas la prime : refus intégral, rien ne bouge',
            (r.get('raison'), caisses() == cav, vince() == av, un("SELECT statut FROM transferts_clubs WHERE id='t1'")),
            ('caisse_club_insuffisante', True, True, 'attente_joueur'))
    qui('Angie Porcelana')
    r = essai("SELECT club_transfert_conclure('t1')::text")
    verifie('B6 un autre personnage ne peut pas encaisser la prime', json.loads(r).get('raison'), 'pas_le_joueur')
    qui('Angie Porcelana')
    verifie('B7 termes immuables : la prime ne se relève pas après l offre',
            essai("""UPDATE transferts_clubs SET data=data||'{"prixJoueur":5000}' WHERE id='t1' RETURNING 1"""), refus)
    qui('Vince Kubrick')
    verifie('B8 le joueur ne peut pas se déclarer payé lui-même',
            essai("""UPDATE transferts_clubs SET statut='termine', data=data||'{"statut":"termine","primeVersee":300}' WHERE id='t1' RETURNING 1"""), refus)

    serveur(); q.execute("UPDATE budgets_clubs SET data=jsonb_set(data,'{caisse}','700') WHERE id='cheminote-montrouge'")
    av = vince(); r = conclure('t1')
    verifie('B9 conclu : arrivée -700, départ +400, joueur +300 (liquide et arg)',
            (r.get('ok'), r.get('prime'), caisses(), vince()), (True, 300, (0.0, 1400.0), (av[0] + 300, av[1] + 300)))
    verifie('B10 la réponse porte la fiche canonique', (float(r['fiche']['liquide']), float(r['fiche']['arg'])), vince())
    verifie('B11 versement tracé : caisse du club et transfert',
            (un("SELECT data->'historique'->-1->>'motif' FROM budgets_clubs WHERE id='cheminote-montrouge'"),
             int(un("SELECT (data->>'primeVersee')::int FROM transferts_clubs WHERE id='t1'"))),
            ('Prime de signature de Vince Kubrick', 300))
    apres = vince()
    for i in (1, 2):
        r = conclure('t1')
        verifie('B12.%d double clic / réponse perdue : rejeu sans second versement' % i,
                (r.get('rejeu'), r.get('prime'), vince(), caisses(), (float(r['fiche']['liquide']), float(r['fiche']['arg']))),
                (True, 300, apres, (0.0, 1400.0), apres))

    verifie('B13 offre sans prime (écran actuel)', preparer('t0', '', 400), ('1', '1'))
    av = vince(); r = conclure('t0')
    verifie('B14 sans prime : prix seul, joueur inchangé, fiche rendue',
            (r.get('ok'), r.get('prime'), vince() == av, caisses(), (float(r['fiche']['liquide']), float(r['fiche']['arg'])) == av),
            (True, 0, True, (0.0, 1800.0), True))

    serveur()
    q.execute("""SELECT has_function_privilege('anon','club_transfert_conclure(text)','EXECUTE'),
                        has_function_privilege('authenticated','assemblee_crediter_joueur(text,integer)','EXECUTE')""")
    verifie('B15 ACL : conclusion fermée aux anonymes, crédit interne non exposé', tuple(v in (True, 't') for v in q.fetchone()), (False, False))

    print(('%d cas, %d échec(s).' % (n[0], len(echecs))) + ('' if not echecs else ' ' + ', '.join(echecs)))
    if hasattr(c, 'arreter'): c.arreter()
    raise SystemExit(1 if echecs else 0)


if __name__ == '__main__':
    main()
