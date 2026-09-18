#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RES PUBLICA -- Orchestrateur de la mise en production du chantier "durabilite championnat".
Prepare le 5 septembre 2026. RIEN N'A ETE EXECUTE : dry-run par defaut, --execute obligatoire.

Toutes les operations de base passent par l'API Management Supabase
(POST /v1/projects/{ref}/database/query), qui execute du SQL avec les droits `postgres` --
donc au-dessus de la RLS. C'est ce qui permet de neutraliser id=1 APRES l'avoir verrouillee.

CREDENTIAL REQUIS (un seul, a fournir une fois) :
    export SUPABASE_ACCESS_TOKEN=sbp_xxxxxxxx
Jeton d'acces personnel Supabase (Account -> Access Tokens). Sans lui, aucune commande DDL
n'est possible depuis cet environnement : il n'y a ni CLI supabase, ni psql, ni driver
PostgreSQL, ni cle service_role en local. La cle anon presente dans supabase.js ne permet
QUE du CRUD soumis a la RLS, jamais du DDL.

PHASES (a executer dans cet ordre exact) :
    inspect   lecture seule : etat RLS + policies actuelles des tables concernees
    phase1    RLS (championnat SEULEMENT) + restauration + neutralisation  <- gele tout
    -- DEPLOIEMENT DU CODE ICI (git push / Vercel), puis bump ?v= et version.json --
    phase3    suppression des 2 topics forum parasites
    phase4    nettoyage de l'edition du Journal du 2 septembre

Usage :
    python3 .scratch/deploiement-championnat.py inspect
    python3 .scratch/deploiement-championnat.py phase1            # dry-run
    python3 .scratch/deploiement-championnat.py phase1 --execute  # ecrit reellement
"""

import json, os, sys, urllib.request, urllib.error

PROJECT_REF = 'jxpwoosmmhohoihxpbuc'
API = 'https://api.supabase.com/v1/projects/%s/database/query' % PROJECT_REF
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TOPICS_PARASITES = ['topic-1788287684370', 'topic-1788544522313']   # 01/09 et 04/09
# 8 editions (corrige le 5 septembre 2026) : le cron du 04/09 23:00 UTC a produit des editions
# datees du 05/09 qui ont collecte la SECONDE J1 parasite. Les editions du 01/09 sont exclues :
# elles portent la couverture LEGITIME de la vraie J2 du 29 aout.
EDITIONS_A_NETTOYER = ['khalija_2026-09-02', 'narco_2026-09-02', 'republic_2026-09-02',
                       'republic_2026-09-03', 'republic_2026-09-04',
                       'khalija_2026-09-05', 'narco_2026-09-05', 'republic_2026-09-05']
FAITS_PARASITES = [
    'championnat:j1-olympique-luthecia-sharq-al-nour',
    'championnat:j1-brise-mariannaise-al-baraka-fc',
    'championnat:j1-cheminote-montrouge-nadi-al-madina',
    'championnat:j1-rojos-cartel-kolkhoze-ouvrier',
    'championnat:j1-fronterizos-unidos-spartak-sibirsk',
    'championnat:j1-jaguares-selva-dynamo-novomirsk',
]


def token():
    t = os.environ.get('SUPABASE_ACCESS_TOKEN')
    if not t:
        raise SystemExit(
            "ABANDON : SUPABASE_ACCESS_TOKEN absent.\n"
            "  Aucune execution DDL n'est possible sans ce jeton depuis cet environnement\n"
            "  (ni CLI supabase, ni psql, ni driver PostgreSQL, ni cle service_role en local).\n"
            "  export SUPABASE_ACCESS_TOKEN=sbp_...  puis relancer.")
    return t


def sql(requete, execute=True):
    """Execute du SQL via l'API Management. Renvoie la liste de lignes (souvent vide pour du DDL)."""
    if not execute:
        print('    [DRY-RUN] SQL non envoye (%d caracteres)' % len(requete))
        return None
    data = json.dumps({'query': requete}).encode('utf-8')
    req = urllib.request.Request(API, data=data, method='POST', headers={
        'Authorization': 'Bearer ' + token(), 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            corps = r.read().decode('utf-8')
            return json.loads(corps) if corps.strip() else []
    except urllib.error.HTTPError as e:
        raise SystemExit('ECHEC SQL (HTTP %s) : %s' % (e.code, e.read().decode('utf-8')[:800]))


def litteral(v):
    """Litteral SQL sur pour une chaine (aucune interpolation non echappee)."""
    return "'" + str(v).replace("'", "''") + "'"


# ---------------------------------------------------------------- inspect
def inspecter(execute=True):
    print('=== ETAT RLS ET POLICIES ACTUELLES ===\n')
    lignes = sql("""
        SELECT c.relname AS table_name, c.relrowsecurity AS rls_active, c.relforcerowsecurity AS rls_forcee
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname IN ('championnat','paris_sportifs','forum_topics','forum_posts','journal_editions')
        ORDER BY c.relname;""", execute)
    print('RLS par table :'); print(json.dumps(lignes, indent=2, ensure_ascii=False))

    lignes = sql("""
        SELECT tablename, policyname, cmd, roles, permissive, qual, with_check
        FROM pg_policies WHERE schemaname = 'public'
          AND tablename IN ('championnat','paris_sportifs','forum_topics','forum_posts','journal_editions')
        ORDER BY tablename, policyname;""", execute)
    print('\nPolicies existantes :'); print(json.dumps(lignes, indent=2, ensure_ascii=False))

    lignes = sql("""
        SELECT grantee, privilege_type FROM information_schema.role_table_grants
        WHERE table_schema='public' AND table_name='championnat' AND grantee IN ('anon','authenticated','service_role')
        ORDER BY grantee, privilege_type;""", execute)
    print('\nGRANTs sur championnat :'); print(json.dumps(lignes, indent=2, ensure_ascii=False))

    lignes = sql("SELECT id, updated_at FROM public.championnat ORDER BY id;", execute)
    print('\nLignes championnat :'); print(json.dumps(lignes, indent=2, ensure_ascii=False))
    return 0


# ---------------------------------------------------------------- phase 1
def phase1(execute):
    print('=== PHASE 1 — verrouillage, restauration, neutralisation ===\n')

    # Le blob restaure est produit par le script de reparation, qui le derive des publications
    # forum legitimes et le verifie contre le calendrier deterministe. On ne le recalcule pas ici.
    chemin = os.path.join(RACINE, '.scratch', 'championnat-blob-propose.json')
    if not os.path.exists(chemin):
        raise SystemExit('ABANDON : %s absent.\n  Lancer d abord : python3 .scratch/reparation-championnat-J1-J2.py' % chemin)
    with open(chemin, encoding='utf-8') as f:
        blob = json.load(f)
    joues = sum(1 for j in blob['calendrier'] if all(m['played'] for m in j['matchs']))
    print('  Blob restaure : saison %s, %d journees jouees, ancrage J%s au %s'
          % (blob['numero'], joues, blob['ancrageDimanche']['numero'], blob['ancrageDimanche']['kickoffISO']))
    if joues != 2 or blob['ancrageDimanche']['numero'] != 3:
        raise SystemExit('ABANDON : blob inattendu (attendu : 2 journees jouees, ancrage J3).')

    neutralisation = {
        'schemaVersion': 9999, 'numero': 0, 'phase': 'terminee', 'calendrier': [], 'palmares': [],
        'resultatsFinales': None, 'stadeFinaleClubId': None, 'stadesUtilises': [],
        'ancrageDimanche': None, 'dateDebut': None,
        'OBSOLETE': ('Ligne abandonnee le 5 septembre 2026. Le championnat vit desormais en id=2. '
                     'Cette ligne subsiste uniquement pour rendre inertes les anciens onglets '
                     'clients qui ont id=eq.1 code en dur. Ne rien y ecrire, ne pas la supprimer.'),
    }

    with open(os.path.join(RACINE, 'migration_championnat_rls.sql'), encoding='utf-8') as f:
        migration = f.read()

    # ORDRE VOLONTAIRE, en une seule transaction : la RLS est posee AVANT toute autre operation,
    # ce qui gele instantanement tous les clients anon (anciens comme actuels) ; la restauration
    # et la neutralisation se font ensuite avec les droits postgres, au-dessus de la RLS. Il
    # n'existe donc AUCUNE fenetre pendant laquelle un vieux client pourrait encore ecrire, ni
    # pendant laquelle la restauration pourrait etre ecrasee.
    requete = (
        "BEGIN;\n"
        "-- 1. verrouillage serveur de championnat UNIQUEMENT (migration_championnat_rls.sql)\n"
        + migration + "\n"
        "-- 2. creation de la ligne canonique id=2, avec les vraies J1/J2 restaurees\n"
        "INSERT INTO public.championnat (id, data, updated_at)\n"
        "VALUES (2, " + litteral(json.dumps(blob, ensure_ascii=False)) + "::jsonb, "
        + litteral(blob['derniereJourneeResolueLe']) + "::timestamptz)\n"
        "ON CONFLICT (id) DO NOTHING;\n"
        "-- 3. neutralisation de la ligne historique id=1 (droits postgres : au-dessus de la RLS)\n"
        "UPDATE public.championnat SET data = " + litteral(json.dumps(neutralisation, ensure_ascii=False)) + "::jsonb\n"
        " WHERE id = 1;\n"
        "COMMIT;\n")

    print('\n  Transaction : RLS -> INSERT id=2 -> UPDATE id=1 (neutralisation)')
    sql(requete, execute)
    if not execute:
        print('\nDRY-RUN : rien ecrit. Relancer avec --execute pour appliquer.')
        return 0

    print('\n  Verification post-application :')
    print(json.dumps(sql("""
        SELECT id, updated_at, data->>'phase' AS phase, data->>'numero' AS numero,
               data->'ancrageDimanche'->>'numero' AS ancrage_journee,
               data->>'derniereSemaineResolue' AS semaine
        FROM public.championnat ORDER BY id;"""), indent=2, ensure_ascii=False))
    print(json.dumps(sql("""
        SELECT tablename, policyname, cmd FROM pg_policies
        WHERE schemaname='public' AND tablename = 'championnat'
        ORDER BY cmd;"""), indent=2, ensure_ascii=False))
    print('\nPHASE 1 OK. Deployer MAINTENANT le code (qui lit id=2), puis bump ?v= et version.json.')
    return 0


# ---------------------------------------------------------------- phase 3
def phase3(execute):
    print('=== PHASE 3 — suppression des topics forum parasites ===\n')
    ids = ', '.join(litteral(t) for t in TOPICS_PARASITES)
    print('  Topics vises :', TOPICS_PARASITES)
    apercu = sql("SELECT id, created_at, title FROM public.forum_topics WHERE id IN (%s);" % ids, execute)
    print('  Trouves :'); print(json.dumps(apercu, indent=2, ensure_ascii=False))
    # Garde-fou : ne jamais toucher aux publications legitimes des 22 et 29 aout.
    requete = ("BEGIN;\n"
               "DELETE FROM public.forum_posts  WHERE topic_id IN (%s);\n"
               "DELETE FROM public.forum_topics WHERE id       IN (%s);\n"
               "COMMIT;\n" % (ids, ids))
    sql(requete, execute)
    if execute:
        print('  Restant (doit ne contenir que les 22/08 et 29/08) :')
        print(json.dumps(sql("SELECT id, created_at, title FROM public.forum_topics "
                             "WHERE forum_id = 'sport' ORDER BY created_at;"), indent=2, ensure_ascii=False))
    else:
        print('\nDRY-RUN : rien supprime.')
    return 0


# ---------------------------------------------------------------- phase 4
def phase4(execute):
    print('=== PHASE 4 — nettoyage du Journal (edition du 2 septembre) ===\n')
    ids = ', '.join(litteral(e) for e in EDITIONS_A_NETTOYER)
    faits = ', '.join(litteral(f) for f in FAITS_PARASITES)
    print('  Editions visees :', EDITIONS_A_NETTOYER)
    print('  Faits parasites :', len(FAITS_PARASITES))
    apercu = sql("""
        SELECT id, statut,
               jsonb_array_length(COALESCE(faits_sources->'FACTS','[]'::jsonb)) AS nb_facts
        FROM public.journal_editions WHERE id IN (%s) ORDER BY id;""" % ids, execute)
    print('  Avant :'); print(json.dumps(apercu, indent=2, ensure_ascii=False))

    # Retire UNIQUEMENT les 6 faits issus de la J1 parasite, en conservant tout le reste du
    # tableau FACTS. La deduplication du Journal (DEJA_COUVERT) relit exactement ce tableau sur
    # les editions 'publiee' : les retirer suffit, il n'existe aucune table de marqueurs separee.
    requete = """
BEGIN;
UPDATE public.journal_editions
   SET faits_sources = jsonb_set(
         faits_sources, '{FACTS}',
         COALESCE((SELECT jsonb_agg(f)
                     FROM jsonb_array_elements(faits_sources->'FACTS') AS f
                    WHERE f->>'id' NOT IN (%s)), '[]'::jsonb))
 WHERE id IN (%s)
   AND faits_sources ? 'FACTS';
COMMIT;
""" % (faits, ids)
    sql(requete, execute)
    if execute:
        print('  Apres :')
        print(json.dumps(sql("""
            SELECT id, statut,
                   jsonb_array_length(COALESCE(faits_sources->'FACTS','[]'::jsonb)) AS nb_facts,
                   (SELECT count(*) FROM jsonb_array_elements(faits_sources->'FACTS') f
                     WHERE f->>'id' LIKE 'championnat:%%') AS nb_championnat
            FROM public.journal_editions WHERE id IN (%s) ORDER BY id;""" % ids),
            indent=2, ensure_ascii=False))
        print("\n  NOTE : le CONTENU redactionnel des 2 editions publiees (khalija/narco du 02/09)")
        print("  mentionne peut-etre ces matchs en clair. A relire visuellement apres coup :")
        print("  retirer les passages sportifs est une edition de texte, pas une operation SQL sure.")
    else:
        print('\nDRY-RUN : rien modifie.')
    return 0


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    execute = '--execute' in sys.argv
    phase = args[0] if args else 'inspect'
    if not execute and phase != 'inspect':
        print('*** MODE DRY-RUN — aucune ecriture. Ajouter --execute pour appliquer. ***\n')
    if phase == 'inspect':
        return inspecter(True)
    if phase == 'phase1':
        return phase1(execute)
    if phase == 'phase3':
        return phase3(execute)
    if phase == 'phase4':
        return phase4(execute)
    raise SystemExit('Phase inconnue : %s (inspect | phase1 | phase3 | phase4)' % phase)


if __name__ == '__main__':
    sys.exit(main())
