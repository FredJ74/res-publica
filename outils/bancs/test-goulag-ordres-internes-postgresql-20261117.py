#!/usr/bin/env python3
"""Ordres internes du goulag de Sovarka (décisions de Fred du 17/11/2026) — épreuves PostgreSQL.

Base jetable locale : baseline du dépôt + relevé vivant et migrations du moteur préparé par Codex
(PR #1020, lus dans --moteur-1020, une copie de la branche chatgpt/goulag-moteur-survie-20261116)
+ les quatre migrations de ce chantier. L'activation (CHECK active IS FALSE retiré) et les
paramètres de corruption n'existent QUE dans cette base jetable : ce ne sont pas des décisions.
"""
import argparse, concurrent.futures, importlib.util, json, re, sys, tempfile, unittest, uuid
from pathlib import Path
import pgserver, psycopg2
from psycopg2.extras import Json

R = Path(__file__).resolve().parents[2]
arg = argparse.ArgumentParser()
arg.add_argument('--postgres-bin', type=Path)
arg.add_argument('--moteur-1020', type=Path, required=True,
                 help='copie de la branche de la PR #1020 (migrations + fixtures du relevé vivant)')
opt, reste = arg.parse_known_args()
M = opt.moteur_1020.resolve()
F = M / 'outils/bancs/fixtures/goulag-20261116'
sys.path.insert(0, str(R / 'outils/baseline'))
spec = importlib.util.spec_from_file_location('ep', R / 'outils/baseline/epreuve-postgresql.py')
ep = importlib.util.module_from_spec(spec); spec.loader.exec_module(ep)
if opt.postgres_bin: ep.configurer_binaires(opt.postgres_bin)

MIGRATIONS_1020 = [p for p in sorted((M / 'migrations').glob('*goulag*.sql'))
                   if '105000' not in p.name and 'ordres_internes' not in p.name]
MIGRATIONS = sorted((R / 'migrations').glob('20261117*_goulag_ordres_internes_*.sql'))
DETENU, VISITEUR, REPUBLIC, JUGE = '__goulag_detenu', '__goulag_visiteur', '__goulag_republic', '__goulag_juge'


class OrdresInternes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert len(MIGRATIONS) == 4, MIGRATIONS
        assert MIGRATIONS_1020, 'migrations #1020 introuvables'
        cls.tmp = tempfile.TemporaryDirectory(prefix='hg-goulag-ordres-')
        cls.s = pgserver.get_server(Path(cls.tmp.name) / 'data', cleanup_mode='delete')
        cls.c = psycopg2.connect(cls.s.get_uri()); q = cls.c.cursor()
        for role in ['anon', 'authenticated', 'service_role', 'authenticator', 'supabase_auth_admin',
                     'supabase_admin', 'dashboard_user', 'supabase_read_only_user', 'hg219_cert_ro_20261101']:
            q.execute('CREATE ROLE ' + role)
        q.execute(ep.PLATEFORME); morceaux, _ = ep.assembler(); ep.installer(q, morceaux)
        # Relevé vivant de Codex (16/11) : même décor que les épreuves de #1020.
        for t in json.loads((F / 'colonnes-vivantes.json').read_text()):
            q.execute('SELECT to_regclass(%s)', ('public.' + t['name'],)); existe = q.fetchone()[0] is not None
            for v in t['columns']:
                for seq in re.findall(r"nextval\('([a-z_0-9.]+)'::regclass\)", v['default'] or ''):
                    q.execute('CREATE SEQUENCE IF NOT EXISTS ' + seq)
            cols = ['"' + v['name'] + '" ' + v['type'] + (' DEFAULT ' + v['default'] if v['default'] else '') for v in t['columns']]
            if not existe:
                q.execute('CREATE TABLE public."' + t['name'] + '" (' + ','.join(cols) + ')')
                for k in t['constraints'] or []:
                    q.execute('ALTER TABLE public."' + t['name'] + '" ADD CONSTRAINT "' + k['name'] + '" ' + k['definition'])
            else:
                for col in cols: q.execute('ALTER TABLE public."' + t['name'] + '" ADD COLUMN IF NOT EXISTS ' + col)
        q.execute('SET check_function_bodies=off')
        for f in json.loads((F / 'fonctions-vivantes.json').read_text()):
            q.execute(f['definition'])
            signature = 'public.' + f['signature']
            q.execute('REVOKE ALL ON FUNCTION ' + signature + ' FROM PUBLIC,anon,authenticated,service_role')
            acl = f.get('acl')
            if acl is None or re.search(r'(?:\{|,)=X', acl): q.execute('GRANT EXECUTE ON FUNCTION ' + signature + ' TO PUBLIC')
            for role in ['anon', 'authenticated', 'service_role']:
                if acl and re.search(r'(?:\{|,)' + role + r'=X', acl): q.execute('GRANT EXECUTE ON FUNCTION ' + signature + ' TO ' + role)
        q.execute('SET check_function_bodies=on')
        q.execute('ALTER TABLE public.rue_noeuds_serveur ADD COLUMN IF NOT EXISTS directions jsonb')
        for table, rows in json.loads((F / 'references-vivantes.json').read_text()).items():
            for row in rows:
                q.execute('INSERT INTO public.' + table + ' SELECT * FROM jsonb_populate_record(NULL::public.' + table + ',%s) ON CONFLICT DO NOTHING', (Json(row),))
        for p in MIGRATIONS_1020: q.execute(p.read_text())
        RACCORDEES = ['public.goulag_toundra_demarrer(text)', 'public.pa_repos_nocturne(text)', 'public.detention_clore_purgee()']
        cls.avant = {}
        for sig in RACCORDEES:
            q.execute('SELECT pg_get_functiondef(%s::regprocedure)', (sig,)); cls.avant[sig] = q.fetchone()[0]
        for p in MIGRATIONS: q.execute(p.read_text())
        q.execute('DROP TRIGGER IF EXISTS fixture_goulag_revision ON public.personnages_donnees;CREATE TRIGGER fixture_goulag_revision BEFORE UPDATE OF inventory ON public.personnages_donnees FOR EACH ROW EXECUTE FUNCTION public.inventaire_revision_garder()')
        for i, (nom, pays) in enumerate([(DETENU, 'soviet'), (VISITEUR, 'soviet'), (REPUBLIC, 'republic'), (JUGE, 'soviet')], 1):
            uid = f'00000000-0000-4000-8000-{i:012}'
            q.execute('INSERT INTO auth.users(id) VALUES(%s)', (uid,))
            q.execute("SELECT set_config('request.jwt.claims',%s,true)", (json.dumps({'sub': uid, 'role': 'authenticated'}),))
            q.execute("INSERT INTO public.personnages_donnees(name,country,user_id,pa,current_city,current_building,current_room,inventory) VALUES(%s,%s,%s,20,'qhs','qhs-prison','entree_qhs','[]')", (nom, pays, uid))
        cls.c.commit()

    @classmethod
    def tearDownClass(cls):
        cls.c.close(); cls.s.cleanup(); cls.tmp.cleanup()

    def setUp(self): self.q = self.c.cursor(); self._client = False
    def tearDown(self): self.c.rollback(); self.q.close()

    # -- outils ---------------------------------------------------------------
    def sql(self, sql, args=None):
        appel = re.match(r'SELECT public\.([a-z_0-9]+)\(', sql)
        if self._client and appel: self.q.execute("SELECT set_config('request.path',%s,true)", ('/rpc/' + appel[1],))
        self.q.execute(sql, args); return self.q.fetchone()[0] if self.q.description else None

    def client(self, i=1):
        self.sql("SELECT set_config('request.jwt.claims',%s,true)", (json.dumps({'sub': f'00000000-0000-4000-8000-{i:012}', 'role': 'authenticated'}),))
        self.q.execute('SET LOCAL ROLE authenticated'); self._client = True

    def admin(self): self.q.execute('RESET ROLE'); self._client = False

    def activer(self):
        self.q.execute('ALTER TABLE public.sovarka_goulag_configuration DROP CONSTRAINT sovarka_goulag_activation_figee')
        self.q.execute("UPDATE public.sovarka_goulag_configuration SET active=true")

    def val(self, sql, args=None):
        self.admin(); return self.sql(sql, args)

    def detenu(self, jours=3, piece='cellules_qhs', pa=10, depot=True, ident='fx-det'):
        """Détenu au goulag, registre ouvert par le VRAI déclencheur différé."""
        self.activer()
        self.q.execute("UPDATE public.personnages_donnees SET pa=%s,current_city='qhs',current_building='qhs-prison',current_room=%s,"
                       "est_emprisonne=jsonb_build_object('debutTs',extract(epoch from now())*1000,'jours',%s,'qhs',true,'detentionId',%s),"
                       "detention_qhs='{\"enQHS\":true,\"paLimite1Jour\":false}' WHERE name=%s", (pa, piece, jours, ident, DETENU))
        self.q.execute("INSERT INTO public.detentions(id,nom,country,city,qhs,jour_debut,jour_fin) VALUES(%s,%s,'soviet','capitale',true,1,%s)", (ident, DETENU, 1 + jours))
        self.q.execute('SET CONSTRAINTS ALL IMMEDIATE'); self.q.execute('SET CONSTRAINTS ALL DEFERRED')
        if depot:
            self.assertTrue(self.sql('SELECT public.sovarka_goulag_confisquer_interne(%s,%s)', (DETENU, ident))['ok'])
        self.assertEqual(self.sql('SELECT jours_restants FROM public.sovarka_goulag_registre WHERE detention_id=%s', (ident,)), jours)

    def present(self, nom=VISITEUR, piece='bureau_chef', origine='ville_b'):
        self.q.execute("INSERT INTO public.sovarka_goulag_visites(nom,origine) VALUES(%s,%s) ON CONFLICT(nom) DO UPDATE SET present=true", (nom, origine))
        self.q.execute("UPDATE public.personnages_donnees SET current_city='qhs',current_building='qhs-prison',current_room=%s WHERE name=%s", (piece, nom))

    def juge(self, piece='bureau_chef'):
        self.q.execute("UPDATE public.personnages_donnees SET poste='{\"id\":\"juge\",\"city\":\"capitale\"}' WHERE name=%s", (JUGE,))
        self.q.execute("INSERT INTO public.postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('fx-juge','soviet','juge','capitale',%s,'fixture') ON CONFLICT DO NOTHING", (JUGE,))
        self.present(JUGE, piece)

    def lendemain(self):
        self.admin()
        self.q.execute("UPDATE public.personnages_donnees SET pa_repos_le=pa_repos_le-1 WHERE pa_repos_le IS NOT NULL")
        self.q.execute("UPDATE public.sovarka_goulag_registre SET dernier_sommeil=dernier_sommeil-1,dernier_repas=dernier_repas-1,derniere_tentative=derniere_tentative-1")

    def graine(self, condition):
        for n in [i / 50 for i in range(-50, 51)]:
            self.sql('SELECT setseed(%s)', (n,)); v = self.sql('SELECT random()')
            if condition(int(v * 100) + 1):
                self.sql('SELECT setseed(%s)', (n,)); return n
        self.fail('graine introuvable')

    # -- verrou et isolement ---------------------------------------------------
    def test_inactif_aucun_effet(self):
        self.client()
        for appel in ["SELECT public.sovarka_goulag_dormir()", "SELECT public.sovarka_goulag_manger()",
                      "SELECT public.sovarka_goulag_detenu_aller('mirador')", "SELECT public.sovarka_goulag_liste_detenus()",
                      "SELECT public.sovarka_goulag_registre_consulter()", "SELECT public.sovarka_goulag_incidents_consulter()",
                      f"SELECT public.sovarka_goulag_interroger('{DETENU}','{uuid.uuid4()}')",
                      f"SELECT public.sovarka_goulag_sanctionner('{DETENU}',1,'{uuid.uuid4()}')",
                      f"SELECT public.sovarka_goulag_corrompre('{uuid.uuid4()}')"]:
            r = self.sql(appel); self.assertFalse(r['ok'], appel); self.assertEqual(r['raison'], 'goulag_non_active', appel)
        self.admin()
        self.assertEqual(self.sql('SELECT public.sovarka_goulag_controle_minuit(current_date)'), {'ok': True, 'inactif': True})
        self.assertEqual(self.sql('SELECT count(*) FROM public.sovarka_goulag_controles'), 0)
        self.assertEqual(self.sql(f"SELECT pa FROM public.personnages_donnees WHERE name='{DETENU}'"), 20)

    def test_permissions_et_rls(self):
        for table in ['registre', 'incidents', 'tentatives', 'controles', 'parametres', 'interrogatoires', 'traces_revelees', 'corruptions']:
            self.assertTrue(self.sql('SELECT relrowsecurity FROM pg_class WHERE oid=%s::regclass', ('public.sovarka_goulag_' + table,)))
            for role in ['anon', 'authenticated', 'service_role']:
                self.assertFalse(self.sql("SELECT has_table_privilege(%s,%s,'SELECT,INSERT,UPDATE,DELETE')", (role, 'public.sovarka_goulag_' + table)), table)
        self.q.execute("SELECT p.oid::regprocedure::text FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.proname LIKE 'sovarka_goulag%' AND (p.proname LIKE '%_interne' OR p.prorettype='trigger'::regtype)")
        for (sig,) in self.q.fetchall():
            for role in ['anon', 'authenticated', 'service_role']:
                self.assertFalse(self.sql("SELECT has_function_privilege(%s,%s,'EXECUTE')", (role, sig)), sig)
        for role in ['anon', 'authenticated']:
            self.assertFalse(self.sql("SELECT has_function_privilege(%s,'public.sovarka_goulag_controle_minuit(date)','EXECUTE')", (role,)))
        self.assertTrue(self.sql("SELECT has_function_privilege('service_role','public.sovarka_goulag_controle_minuit(date)','EXECUTE')"))
        for fn in ['sovarka_goulag_dormir()', 'sovarka_goulag_interroger(text,uuid)', 'sovarka_goulag_sanctionner(text,integer,uuid)']:
            self.assertFalse(self.sql("SELECT has_function_privilege('anon',%s,'EXECUTE')", ('public.' + fn,)))

    def test_parametres_corruption_non_decides_par_defaut(self):
        self.assertEqual(self.sql('SELECT count(*) FROM public.sovarka_goulag_parametres WHERE valeur IS NULL'), 4)

    def test_migrations_rejouables(self):
        for p in MIGRATIONS: self.q.execute(p.read_text())
        src = self.sql("SELECT pg_get_functiondef('public.goulag_toundra_demarrer(text)'::regprocedure)")
        self.assertEqual(src.count('goulag_sortie_jet_20261117'), 1)
        self.assertEqual(self.sql("SELECT pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure)").count('goulag_sommeil_dortoir_20261117'), 1)

    def test_retour_arriere_restaure_les_fonctions(self):
        script = (R / 'outils/bancs/banc-goulag-ordres-internes-retour-arriere-20261117.sql').read_text()
        script = script.replace('BEGIN;', '', 1).replace('ROLLBACK;', '')
        self.q.execute(script)
        for sig, texte in self.avant.items():
            self.assertEqual(self.sql('SELECT pg_get_functiondef(%s::regprocedure)', (sig,)), texte, sig)
        self.assertIsNone(self.sql("SELECT to_regclass('public.sovarka_goulag_registre')"))
        self.assertIsNotNone(self.sql("SELECT to_regclass('public.sovarka_goulag_traversees')"))
        # Puis réinstallation : le lot est rejouable après un retour arrière.
        for p in MIGRATIONS: self.q.execute(p.read_text())
        self.assertIsNotNone(self.sql("SELECT to_regclass('public.sovarka_goulag_registre')"))

    def test_republia_qhs_inchange(self):
        """Le QHS de Républia garde son repos plafonné à 3 PA et ignore les ordres du goulag."""
        self.activer()
        self.q.execute("UPDATE public.personnages_donnees SET current_city='qhs',current_building='qhs-prison',current_room='cellules_qhs',pa=1,"
                       "est_emprisonne='{\"jours\":3,\"qhs\":true}',detention_qhs='{\"enQHS\":true,\"paLimite1Jour\":false}' WHERE name=%s", (REPUBLIC,))
        self.q.execute("INSERT INTO public.detentions(id,nom,country,city,qhs,jour_debut,jour_fin) VALUES('fx-rep',%s,'republic','capitale',true,1,4)", (REPUBLIC,))
        self.q.execute('SET CONSTRAINTS ALL IMMEDIATE')
        self.assertEqual(self.sql("SELECT count(*) FROM public.sovarka_goulag_registre"), 0)
        self.client(3)
        self.assertEqual(self.sql('SELECT public.sovarka_goulag_dormir()')['raison'], 'hors_goulag')
        r = self.sql(f"SELECT public.pa_repos_nocturne('{REPUBLIC}')"); self.assertTrue(r['ok'], r); self.assertEqual(r['pa'], 3)

    # -- registre et justice réelle -------------------------------------------
    def test_registre_ouvert_par_le_vrai_jugement(self):
        self.activer()
        self.q.execute("UPDATE public.personnages_donnees SET poste='{\"id\":\"juge\",\"city\":\"capitale\"}',current_city='capitale',current_building='tribunal',current_room='bureau_juge' WHERE name=%s", (JUGE,))
        self.q.execute("INSERT INTO public.postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('fx-juge','soviet','juge','capitale',%s,'fixture')", (JUGE,))
        self.q.execute("INSERT INTO public.plaintes_en_cours(id,country,city,data) VALUES('fx-affaire','soviet','capitale',%s)", (json.dumps({'status': 'saisie', 'audience_ouverte_le': 'fixture', 'cible': VISITEUR}),))
        self.client(4); r = self.sql("SELECT public.sovarka_goulag_juger('fx-affaire','vol',30)"); self.assertTrue(r['ok'], r)
        self.admin(); self.q.execute('SET CONSTRAINTS ALL IMMEDIATE')
        reg = self.sql("SELECT row_to_json(r) FROM public.sovarka_goulag_registre r WHERE nom=%s", (VISITEUR,))
        self.assertEqual((reg['jugement_id'], reg['tribunal_pays'], reg['tribunal_ville'], reg['juge'], reg['jours_restants']),
                         ('jug-fx-affaire', 'soviet', 'capitale', JUGE, 30))

    def test_jugement_inconnu_jamais_invente(self):
        self.detenu()
        reg = self.sql("SELECT row_to_json(r) FROM public.sovarka_goulag_registre r WHERE detention_id='fx-det'")
        self.assertIsNone(reg['jugement_id']); self.assertIsNone(reg['tribunal_ville']); self.assertIsNone(reg['juge'])

    # -- dortoir ---------------------------------------------------------------
    def test_dormir_dortoir_un_par_jour_sans_double_repos(self):
        self.detenu(jours=3, pa=10)
        self.client(); r = self.sql('SELECT public.sovarka_goulag_dormir()')
        self.assertTrue(r['ok'], r); self.assertEqual((r['pa'], r['jours_restants'], r['gain']), (11, 2, 1))
        self.assertEqual(self.sql('SELECT public.sovarka_goulag_dormir()')['raison'], 'deja_dormi_aujourdhui')
        r = self.sql(f"SELECT public.pa_repos_nocturne('{DETENU}')"); self.assertFalse(r['ok']); self.assertEqual(r['pa'], 11)
        self.lendemain(); self.client()
        r = self.sql(f"SELECT public.pa_repos_nocturne('{DETENU}')"); self.assertFalse(r['ok']); self.assertEqual(r['raison'], 'sommeil_goulag_dortoir')
        self.assertEqual(self.val(f"SELECT pa FROM public.personnages_donnees WHERE name='{DETENU}'"), 11)

    def test_temps_ecoule_ne_purge_jamais(self):
        self.detenu(jours=2)
        self.q.execute("UPDATE public.personnages_donnees SET est_emprisonne=est_emprisonne||jsonb_build_object('debutTs',1000) WHERE name=%s", (DETENU,))
        self.client(); r = self.sql('SELECT public.detention_clore_purgee()')
        self.assertFalse(r['ok']); self.assertEqual(r['raison'], 'peine_goulag_au_sommeil')
        self.admin(); self.assertEqual(self.sql('SELECT public.sovarka_goulag_controle_minuit(current_date)')['detenus'], 1)
        self.assertEqual(self.sql("SELECT jours_restants FROM public.sovarka_goulag_registre WHERE detention_id='fx-det'"), 2)
        self.assertIsNone(self.sql("SELECT mode_fin FROM public.detentions WHERE id='fx-det'"))

    def test_sommeil_final_libere_devant_entree(self):
        self.q.execute("UPDATE public.personnages_donnees SET inventory='[{\"id\":\"montre-unique\"},{\"type\":\"cle_serrure\",\"id\":\"cle\"}]' WHERE name=%s", (DETENU,))
        self.detenu(jours=1, pa=5)
        self.assertEqual(self.sql(f"SELECT inventory FROM public.personnages_donnees WHERE name='{DETENU}'"), [{'type': 'cle_serrure', 'id': 'cle'}])
        self.client(); r = self.sql('SELECT public.sovarka_goulag_dormir()'); self.assertTrue(r['libere'], r)
        self.admin()
        pos = self.sql(f"SELECT jsonb_build_array(current_city,current_building,current_room) FROM public.personnages_donnees WHERE name='{DETENU}'")
        self.assertEqual(pos, ['qhs', 'qhs-prison', 'entree_qhs'])
        self.assertEqual(self.sql("SELECT mode_fin FROM public.detentions WHERE id='fx-det'"), 'purgee')
        self.assertIsNone(self.sql(f"SELECT est_emprisonne FROM public.personnages_donnees WHERE name='{DETENU}'"))
        self.assertEqual(self.sql("SELECT etat FROM public.sovarka_goulag_depots WHERE detention_id='fx-det'"), 'restitue')
        self.assertEqual(len(self.sql(f"SELECT inventory FROM public.personnages_donnees WHERE name='{DETENU}'")), 2)
        self.assertTrue(self.sql(f"SELECT present FROM public.sovarka_goulag_visites WHERE nom='{DETENU}'"))
        reg = self.sql("SELECT row_to_json(r) FROM public.sovarka_goulag_registre r WHERE detention_id='fx-det'")
        self.assertIsNotNone(reg['liberation_le']); self.assertIsNone(reg['evasion_le'])
        self.assertEqual(self.sql(f"SELECT count(*) FROM public.mails WHERE to_player='{DETENU}' AND subject='Libération'"), 1)
        # Un libéré n'est plus détenu : aucun second sommeil du camp, aucune nouvelle purge.
        self.client(); self.assertEqual(self.sql('SELECT public.sovarka_goulag_dormir()')['raison'], 'non_detenu_goulag')

    def test_manger_dortoir_une_fois_par_jour(self):
        self.detenu(pa=10)
        self.client(); r = self.sql('SELECT public.sovarka_goulag_manger()'); self.assertEqual((r['ok'], r['pa']), (True, 11))
        self.assertEqual(self.sql('SELECT public.sovarka_goulag_manger()')['raison'], 'deja_mange')
        self.admin(); self.q.execute(f"UPDATE public.personnages_donnees SET current_room='mirador' WHERE name='{DETENU}'")
        self.lendemain(); self.client(); self.assertEqual(self.sql('SELECT public.sovarka_goulag_manger()')['raison'], 'pas_au_dortoir')
        self.assertEqual(self.val(f"SELECT pa FROM public.personnages_donnees WHERE name='{DETENU}'"), 11)

    def test_greve_de_la_faim_absente_du_goulag_seulement(self):
        data = (R / 'data.js').read_text()
        debut = data.index("name:'Camp de rééducation de Sovarka'"); goulag = data[debut:data.index('khalija: {', debut)]
        self.assertIn("excludeOrders:['greve_faim'", goulag)
        self.assertIn("{fn:'greve_faim'", data[data.index("'qhs-prison': {\n    name: \"Quartier Haute Securite\""):])

    # -- cachot et sanction ----------------------------------------------------
    def test_sanction_juge_present_seulement(self):
        self.detenu(jours=5); self.juge(piece='mirador')
        self.client(4); r = self.sql(f"SELECT public.sovarka_goulag_sanctionner('{DETENU}',1,'{uuid.uuid4()}')")
        self.assertEqual(r['raison'], 'juge_absent_du_bureau')
        self.admin(); self.q.execute(f"UPDATE public.personnages_donnees SET current_room='bureau_chef' WHERE name='{JUGE}'")
        self.client(4); self.assertEqual(self.sql(f"SELECT public.sovarka_goulag_sanctionner('{DETENU}',3,'{uuid.uuid4()}')")['raison'], 'parametres_invalides')
        # Ministre de la Justice présent : aucun pouvoir disciplinaire du seul fait de sa fonction.
        self.admin(); self.present(VISITEUR, 'bureau_chef')
        self.q.execute(f"UPDATE public.personnages_donnees SET poste='{{\"id\":\"min_just\"}}' WHERE name='{VISITEUR}'")
        self.q.execute(f"INSERT INTO public.postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('fx-min','soviet','min_just','capitale','{VISITEUR}','fixture')")
        self.client(2); self.assertEqual(self.sql(f"SELECT public.sovarka_goulag_sanctionner('{DETENU}',2,'{uuid.uuid4()}')")['raison'], 'reserve_juge_sovarka')
        req = str(uuid.uuid4()); self.client(4)
        r = self.sql(f"SELECT public.sovarka_goulag_sanctionner('{DETENU}',2,'{req}')"); self.assertTrue(r['ok'], r); self.assertEqual(r['cachot_nuits'], 2)
        self.assertTrue(self.sql(f"SELECT public.sovarka_goulag_sanctionner('{DETENU}',2,'{req}')")['rejeu'])
        r = self.sql(f"SELECT public.sovarka_goulag_sanctionner('{DETENU}',2,'{uuid.uuid4()}')"); self.assertEqual(r['cachot_nuits'], 2)
        self.admin()
        self.assertEqual(self.sql(f"SELECT current_room FROM public.personnages_donnees WHERE name='{DETENU}'"), 'cachot_disciplinaire')
        self.assertEqual(self.sql("SELECT count(*) FROM public.sovarka_goulag_incidents WHERE nature='sanction_disciplinaire'"), 2)

    def test_cachot_deux_nuits_puis_retour_dortoir(self):
        self.detenu(jours=5, pa=10)
        self.sql("SELECT public.sovarka_goulag_cachot_placer_interne(%s,'fx-det',2,'decision_judiciaire')", (DETENU,))
        self.client()
        for appel in ["SELECT public.sovarka_goulag_manger()", "SELECT public.sovarka_goulag_detenu_aller('mirador')"]:
            self.assertFalse(self.sql(appel)['ok'], appel)
        r = self.sql('SELECT public.sovarka_goulag_dormir()'); self.assertEqual((r['gain'], r['pa'], r['jours_restants'], r['cachot_nuits']), (0, 10, 4, 1))
        self.lendemain(); self.client(); r = self.sql('SELECT public.sovarka_goulag_dormir()')
        self.assertEqual((r['jours_restants'], r['cachot_nuits'], r['room']), (3, 0, 'cellules_qhs'))
        self.assertEqual(self.val(f"SELECT current_room FROM public.personnages_donnees WHERE name='{DETENU}'"), 'cellules_qhs')
        self.assertIsNone(self.sql("SELECT cachot_motif FROM public.sovarka_goulag_registre WHERE detention_id='fx-det'"))

    def test_cachot_peine_achevee_libere(self):
        self.detenu(jours=1)
        self.sql("SELECT public.sovarka_goulag_cachot_placer_interne(%s,'fx-det',2,'evasion_echouee')", (DETENU,))
        self.client(); r = self.sql('SELECT public.sovarka_goulag_dormir()'); self.assertTrue(r['libere'], r)
        self.assertEqual(self.val(f"SELECT current_room FROM public.personnages_donnees WHERE name='{DETENU}'"), 'entree_qhs')

    def test_cachot_compteur_incoherent_jamais_indefini(self):
        self.detenu(jours=4, piece='cachot_disciplinaire')
        self.client(); r = self.sql('SELECT public.sovarka_goulag_dormir()')
        self.assertEqual((r['ok'], r['raison']), (False, 'sanction_terminee'))
        self.assertEqual(self.val(f"SELECT current_room FROM public.personnages_donnees WHERE name='{DETENU}'"), 'cellules_qhs')
        with self.assertRaises(psycopg2.errors.CheckViolation):
            self.q.execute("UPDATE public.sovarka_goulag_registre SET cachot_nuits=3 WHERE detention_id='fx-det'")

    # -- bureau : interrogatoire et registre -------------------------------
    def test_interrogatoire_pa_plancher_et_refus(self):
        self.detenu(pa=1); self.present()
        self.client(2); self.assertEqual(self.sql(f"SELECT public.sovarka_goulag_interroger('{DETENU}','{uuid.uuid4()}')")['raison'], 'detenu_epuise')
        self.admin(); self.q.execute(f"UPDATE public.personnages_donnees SET pa=8 WHERE name='{DETENU}'")
        self.client(2); r = self.sql(f"SELECT public.sovarka_goulag_interroger('{DETENU}','{uuid.uuid4()}')"); self.assertEqual(r['pa_detenu'], 1)
        self.assertEqual(self.sql(f"SELECT public.sovarka_goulag_interroger('{DETENU}','{uuid.uuid4()}')")['raison'], 'detenu_epuise')
        self.admin(); self.q.execute(f"UPDATE public.personnages_donnees SET pa=20 WHERE name='{DETENU}'")
        self.client(2); self.assertEqual(self.sql(f"SELECT public.sovarka_goulag_interroger('{DETENU}','{uuid.uuid4()}')")['pa_detenu'], 13)
        self.assertEqual(self.val("SELECT interrogatoires FROM public.sovarka_goulag_registre WHERE detention_id='fx-det'"), 2)

    def test_interrogatoire_probabilites(self):
        self.detenu(pa=30); self.present()
        for vi, vd, attendu in [(10, 10, 50), (12, 8, 70), (8, 12, 30), (30, 1, 95), (1, 30, 5)]:
            self.admin()
            self.q.execute("UPDATE public.personnages_donnees SET stats=jsonb_build_object('VOL',%s) WHERE name=%s", (vi, VISITEUR))
            self.q.execute("UPDATE public.personnages_donnees SET stats=jsonb_build_object('VOL',%s),pa=30 WHERE name=%s", (vd, DETENU))
            self.client(2); self.assertEqual(self.sql(f"SELECT public.sovarka_goulag_interroger('{DETENU}','{uuid.uuid4()}')")['probabilite'], attendu)

    def test_interrogatoire_trace_unique_et_courrier_au_seul_juge(self):
        self.detenu(pa=30); self.present()
        self.q.execute("UPDATE public.sovarka_goulag_registre SET juge=%s,jugement_id='jug-fx' WHERE detention_id='fx-det'", (JUGE,))
        self.q.execute("UPDATE public.personnages_donnees SET historique_crimes='[{\"id\":\"c1\",\"acte\":\"vol\",\"cible\":\"Boris\",\"jour\":3}]' WHERE name=%s", (DETENU,))
        self.q.execute("INSERT INTO public.actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration,decouvert) VALUES('a-connue',%s,'x','fraude','soviet','capitale',1,8,true)", (DETENU,))
        self.q.execute("UPDATE public.personnages_donnees SET stats='{\"VOL\":30}' WHERE name=%s", (VISITEUR,))
        self.q.execute("UPDATE public.personnages_donnees SET stats='{\"VOL\":1}' WHERE name=%s", (DETENU,))
        req = str(uuid.uuid4()); self.client(2); self.graine(lambda j: j <= 95)
        r = self.sql(f"SELECT public.sovarka_goulag_interroger('{DETENU}','{req}')")
        self.assertTrue(r['reussi'], r); self.assertTrue(r['revelation']); self.assertTrue(r['transmis_au_juge'])
        self.assertTrue(self.sql(f"SELECT public.sovarka_goulag_interroger('{DETENU}','{req}')")['rejeu'])
        self.graine(lambda j: j <= 95); r = self.sql(f"SELECT public.sovarka_goulag_interroger('{DETENU}','{uuid.uuid4()}')")
        self.assertTrue(r['reussi']); self.assertFalse(r['revelation'])
        self.admin()
        self.assertEqual(self.sql("SELECT count(*) FROM public.sovarka_goulag_traces_revelees"), 1)
        self.assertEqual(self.sql("SELECT count(*) FROM public.mails WHERE subject LIKE 'Interrogatoire au goulag%%'"), 1)
        self.assertEqual(self.sql("SELECT to_player FROM public.mails WHERE subject LIKE 'Interrogatoire au goulag%%'"), JUGE)
        self.assertEqual(self.sql(f"SELECT pa FROM public.personnages_donnees WHERE name='{DETENU}'"), 16)
        self.assertEqual(self.sql("SELECT interrogatoires FROM public.sovarka_goulag_registre WHERE detention_id='fx-det'"), 2)
        self.assertTrue(self.sql("SELECT decouvert FROM public.actions_tracables WHERE id='a-connue'"))

    def test_lectures_reservees_aux_habilites_presents(self):
        self.detenu()
        self.client(); self.assertEqual(self.sql('SELECT public.sovarka_goulag_liste_detenus()')['raison'], 'reserve_habilite_entree')
        self.admin(); self.q.execute(f"UPDATE public.personnages_donnees SET current_city='qhs',current_building='qhs-prison',current_room='entree_qhs' WHERE name='{VISITEUR}'")
        self.client(2); self.assertFalse(self.sql('SELECT public.sovarka_goulag_liste_detenus()')['ok'])
        self.admin(); self.present(VISITEUR, 'entree_qhs')
        self.client(2); r = self.sql('SELECT public.sovarka_goulag_liste_detenus()')
        self.assertEqual(r['detenus'], [{'nom': DETENU, 'jours_restants': 3, 'statut': 'detenu', 'controle_jour': None}])
        self.assertEqual(self.sql('SELECT public.sovarka_goulag_registre_consulter()')['raison'], 'reserve_habilite_bureau')
        self.assertEqual(self.sql('SELECT public.sovarka_goulag_incidents_consulter()')['raison'], 'reserve_habilite_mirador')

    # -- mirador : corruption --------------------------------------------------
    def test_corruption_bloquee_tant_que_non_arbitree(self):
        self.detenu(piece='mirador')
        self.client(); r = self.sql(f"SELECT public.sovarka_goulag_corrompre('{uuid.uuid4()}')")
        self.assertEqual(r['raison'], 'corruption_a_arbitrer'); self.assertEqual(len(r['parametres']), 4)
        self.assertEqual(self.val('SELECT count(*) FROM public.sovarka_goulag_corruptions'), 0)

    def test_corruption_objet_puis_bonus_evasion_95(self):
        self.detenu(piece='entree_qhs', pa=20)
        self.q.execute("UPDATE public.personnages_donnees SET current_room='mirador',inventory='[{\"name\":\"Montre\",\"type\":\"objet\",\"stackKey\":\"montre\"}]' WHERE name=%s", (DETENU,))
        # Valeurs de FIXTURE uniquement (aucune décision) : 50 %, +20, objet rendu si échec, 1/jour.
        self.q.execute("UPDATE public.sovarka_goulag_parametres SET valeur=CASE cle WHEN 'corruption_taux_base' THEN 50 WHEN 'corruption_bonus_objet' THEN 20 WHEN 'corruption_objet_perdu_si_echec' THEN 0 ELSE 1 END")
        self.client(); self.graine(lambda j: j <= 70)
        req = str(uuid.uuid4())
        r = self.sql(f"SELECT public.sovarka_goulag_corrompre('{req}',0,'{{\"name\":\"Montre\",\"type\":\"objet\",\"stackKey\":\"montre\"}}')")
        self.assertTrue(r['reussi'], r); self.assertEqual(r['taux'], 70); self.assertTrue(r['objet_perdu']); self.assertEqual(r['inventory'], [])
        self.assertTrue(self.sql(f"SELECT public.sovarka_goulag_corrompre('{req}')")['rejeu'])
        self.assertEqual(self.sql(f"SELECT public.sovarka_goulag_corrompre('{uuid.uuid4()}')")['raison'], 'gardien_deja_corrompu')
        self.assertTrue(self.sql("SELECT public.sovarka_goulag_detenu_aller('entree_qhs')")['ok'])
        self.graine(lambda j: 80 < j <= 95)
        r = self.sql("SELECT public.goulag_toundra_demarrer('starovka')"); self.assertTrue(r['ok'], r)
        self.admin()
        self.assertEqual(self.sql("SELECT (taux,reussi,corruption)::text FROM public.sovarka_goulag_tentatives"), '(95,t,t)')
        self.assertFalse(self.sql("SELECT corruption_bonus FROM public.sovarka_goulag_registre WHERE detention_id='fx-det'"))

    # -- évasion ----------------------------------------------------------------
    def test_evasion_echouee_cachot_deux_nuits_peine_conservee(self):
        self.detenu(jours=6, piece='entree_qhs', pa=12)
        self.client(); self.graine(lambda j: j > 80)
        r = self.sql("SELECT public.goulag_toundra_demarrer('starovka')")
        self.assertEqual((r['ok'], r['raison'], r['cachot_nuits'], r['taux']), (False, 'evasion_echouee', 2, 80))
        self.admin()
        self.assertEqual(self.sql(f"SELECT current_room FROM public.personnages_donnees WHERE name='{DETENU}'"), 'cachot_disciplinaire')
        self.assertEqual(self.sql("SELECT jours_restants FROM public.sovarka_goulag_registre WHERE detention_id='fx-det'"), 6)
        self.assertEqual(self.sql("SELECT count(*) FROM public.sovarka_goulag_traversees"), 0)
        self.assertIsNone(self.sql("SELECT mode_fin FROM public.detentions WHERE id='fx-det'"))
        self.assertEqual(self.sql("SELECT etat FROM public.sovarka_goulag_depots WHERE detention_id='fx-det'"), 'confisque')
        self.assertEqual(self.sql("SELECT nature FROM public.sovarka_goulag_incidents"), 'evasion_echouee')
        self.assertEqual(self.sql(f"SELECT pa FROM public.personnages_donnees WHERE name='{DETENU}'"), 12)
        # Même jour, même hors cachot : aucune seconde tentative.
        self.q.execute("UPDATE public.sovarka_goulag_registre SET cachot_nuits=0,cachot_motif=NULL")
        self.q.execute(f"UPDATE public.personnages_donnees SET current_room='entree_qhs' WHERE name='{DETENU}'")
        self.client(); self.assertEqual(self.sql("SELECT public.goulag_toundra_demarrer('starovka')")['raison'], 'tentative_deja_faite_aujourdhui')

    def test_evasion_pa_insuffisants_sans_jet(self):
        self.detenu(piece='entree_qhs', pa=9)
        self.client(); self.assertEqual(self.sql("SELECT public.goulag_toundra_demarrer('krasnov')")['raison'], 'pa_insuffisants_depart')
        self.assertEqual(self.val('SELECT count(*) FROM public.sovarka_goulag_tentatives'), 0)

    def test_evasion_reussie_reliquat_du_sommeil_et_controle_minuit(self):
        self.detenu(jours=5, piece='cellules_qhs', pa=20)
        self.client(); self.sql('SELECT public.sovarka_goulag_dormir()')
        self.assertTrue(self.sql("SELECT public.sovarka_goulag_detenu_aller('entree_qhs')")['ok'])
        self.graine(lambda j: j <= 80)
        r = self.sql("SELECT public.goulag_toundra_demarrer('krasnov')"); self.assertTrue(r['ok'], r)
        self.assertEqual(float(r['peine_gelee_secondes']), 4 * 86400)
        self.admin(); self.present(VISITEUR, 'entree_qhs')
        self.client(2); liste = self.sql('SELECT public.sovarka_goulag_liste_detenus()')['detenus']
        self.assertEqual((liste[0]['statut'], liste[0]['jours_restants']), ('detenu', 4))
        self.admin(); c = self.sql("SELECT public.sovarka_goulag_controle_minuit(current_date+1)")
        self.assertEqual(c['en_fuite'], 1)
        self.assertTrue(self.sql("SELECT public.sovarka_goulag_controle_minuit(current_date+1)")['deja_fait'])
        self.assertEqual(self.sql("SELECT public.sovarka_goulag_controle_minuit(current_date+2)")['en_fuite'], 0)
        self.client(2); liste = self.sql('SELECT public.sovarka_goulag_liste_detenus()')['detenus']
        self.assertEqual((liste[0]['statut'], liste[0]['jours_restants']), ('en_fuite', 4))
        self.admin()
        self.assertEqual(self.sql("SELECT count(*) FROM public.sovarka_goulag_incidents WHERE nature='absence_minuit'"), 1)
        reg = self.sql("SELECT row_to_json(r) FROM public.sovarka_goulag_registre r WHERE detention_id='fx-det'")
        self.assertIsNotNone(reg['evasion_le']); self.assertIsNone(reg['liberation_le'])
        # Registre du bureau : l'évasion n'est pas une sortie effective.
        self.present(VISITEUR, 'bureau_chef'); self.client(2)
        ligne = self.sql('SELECT public.sovarka_goulag_registre_consulter()')['registre'][0]
        self.assertIsNone(ligne['sortie_le']); self.assertIsNotNone(ligne['evasion_le'])

    def test_reincarceration_reprend_le_reliquat(self):
        self.detenu(jours=5, piece='entree_qhs', pa=20)
        self.client(); self.graine(lambda j: j <= 80)
        self.assertTrue(self.sql("SELECT public.goulag_toundra_demarrer('starovka')")['ok'])
        self.admin()
        self.q.execute(f"UPDATE public.sovarka_goulag_traversees SET en_cours=false WHERE nom='{DETENU}'")
        r = self.sql(f"SELECT public.detention_ouvrir_interne('{DETENU}','Reprise',0,'capitale','soviet','[]','Commissariat','reincarceration')"); self.assertTrue(r['ok'], r)
        self.q.execute(f"UPDATE public.personnages_donnees SET current_city='qhs',current_building='qhs-prison',current_room='cellules_qhs' WHERE name='{DETENU}'")
        self.sql("SELECT public.detention_qhs_poser_interne(%s,%s,'Reprise')", (DETENU, r['detention_id']))
        self.q.execute('SET CONSTRAINTS ALL IMMEDIATE')
        nouveau = self.sql("SELECT row_to_json(x) FROM public.sovarka_goulag_registre x WHERE detention_id=%s", (r['detention_id'],))
        self.assertEqual((nouveau['jours_restants'], nouveau['detention_precedente_id']), (5, 'fx-det'))
        self.assertIsNotNone(self.sql("SELECT reincarcere_le FROM public.sovarka_goulag_registre WHERE detention_id='fx-det'"))

    def test_visiteur_part_sans_jet(self):
        self.activer(); self.present(VISITEUR, 'entree_qhs')
        self.q.execute(f"UPDATE public.personnages_donnees SET pa=7 WHERE name='{VISITEUR}'")
        self.client(2); r = self.sql("SELECT public.goulag_toundra_demarrer('starovka')"); self.assertTrue(r['ok'], r)
        self.assertEqual(r['statut'], 'visiteur')
        self.assertEqual(self.val('SELECT count(*) FROM public.sovarka_goulag_tentatives'), 0)

    # -- concurrence (données validées, dernier test) ------------------------
    def test_zz_concurrence_sommeil_et_interrogatoire(self):
        self.detenu(jours=4, pa=20); self.present(); self.c.commit()

        def appel(args):
            i, requete = args
            with psycopg2.connect(self.s.get_uri()) as c:
                q = c.cursor()
                q.execute("SELECT set_config('request.jwt.claims',%s,true)", (json.dumps({'sub': f'00000000-0000-4000-8000-{i:012}', 'role': 'authenticated'}),))
                q.execute("SELECT set_config('request.path',%s,true)", ('/rpc/' + re.match(r'SELECT public\.([a-z_0-9]+)\(', requete)[1],))
                q.execute('SET LOCAL ROLE authenticated')
                q.execute(requete); return q.fetchone()[0]

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as e:
            res = list(e.map(appel, [(1, 'SELECT public.sovarka_goulag_dormir()')] * 2))
        self.assertEqual(sum(r['ok'] for r in res), 1, res)
        self.assertEqual(self.sql("SELECT jours_restants FROM public.sovarka_goulag_registre WHERE detention_id='fx-det'"), 3)
        req = str(uuid.uuid4())
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as e:
            res = list(e.map(appel, [(2, f"SELECT public.sovarka_goulag_interroger('{DETENU}','{req}')")] * 2))
        self.assertTrue(all(r['ok'] for r in res), res)
        self.assertEqual(self.sql(f"SELECT pa FROM public.personnages_donnees WHERE name='{DETENU}'"), 14)
        self.assertEqual(self.sql("SELECT interrogatoires FROM public.sovarka_goulag_registre WHERE detention_id='fx-det'"), 1)
        self.q.execute(f"UPDATE public.personnages_donnees SET current_room='entree_qhs' WHERE name='{DETENU}'"); self.c.commit()
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as e:
            res = list(e.map(appel, [(1, "SELECT public.goulag_toundra_demarrer('starovka')")] * 2))
        self.assertEqual(self.sql('SELECT count(*) FROM public.sovarka_goulag_tentatives'), 1)
        self.assertEqual(sum(1 for r in res if r.get('raison') == 'tentative_deja_faite_aujourdhui' or r.get('raison') == 'sanction_cachot_en_cours' or r.get('raison') == 'pas_entree_goulag'), 1, res)


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0]] + reste, verbosity=2)
