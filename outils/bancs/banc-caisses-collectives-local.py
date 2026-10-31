"""Banc #295 sur PostgreSQL JETABLE exclusivement : caisses des clubs et des organisations.
Aucun DSN ni compte réel accepté. auth.uid() est une fixture de JWT, exiger_poste et payer_ordre
des doublures fidèles au contrat (refus nommé, prélèvement PA + coût) ; les migrations
20261031200000 (portes serveur) et 20261031201000 (fermeture) sont jouées TELLES QUELLES.

Contre-épreuve : avant la fermeture, un joueur réécrit librement la caisse d'un club et celle de
l'organisation d'un autre ; après, ces écritures sont refusées ou sans effet, et les mouvements
légitimes passent par les portes serveur, une seule fois par requête.
Usage : python3 outils/bancs/banc-caisses-collectives-local.py --local-jetable
"""
import argparse, json, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
M1 = ROOT / 'migrations/20261031200000_caisses_collectives_portes_serveur.sql'
M2 = ROOT / 'migrations/20261031201000_caisses_collectives_fermer_ecran.sql'
UID = {'Jean Jaaj': '11111111-1111-1111-1111-111111111111',
       'Vince Kubrick': '22222222-2222-2222-2222-222222222222',
       'Angie Porcelana': '33333333-3333-3333-3333-333333333333',
       'Arnie': '44444444-4444-4444-4444-444444444444'}

SCHEMA = r'''
CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('hg.uid', true), '')::uuid $$;
CREATE TABLE personnages_donnees(name text PRIMARY KEY, user_id uuid, country text DEFAULT 'republic', day integer DEFAULT 3,
  liquide numeric DEFAULT 0, arg numeric DEFAULT 0, pa integer DEFAULT 10, resources jsonb DEFAULT '{}');
CREATE TABLE comptes_bancaires(personnage text, banque text, solde numeric, PRIMARY KEY (personnage, banque));
CREATE TABLE ordres_couts(fn text, pa integer, cost integer);
CREATE TABLE clubs_football(id text PRIMARY KEY, nom text, pays text, ville text);
CREATE TABLE budgets_clubs(id text PRIMARY KEY, data jsonb, updated_at timestamptz DEFAULT now());
CREATE TABLE presidents_clubs(id text PRIMARY KEY, data jsonb, updated_at timestamptz DEFAULT now());
CREATE TABLE transferts_clubs(id text PRIMARY KEY, statut text, data jsonb, updated_at timestamptz DEFAULT now());
CREATE TABLE organisations(id text PRIMARY KEY, country_origine text, data text, created_at timestamptz DEFAULT now());
CREATE TABLE caisses_batiments(id text PRIMARY KEY, data jsonb, updated_at timestamptz DEFAULT now());

CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT name FROM personnages_donnees WHERE user_id = auth.uid() $$;
CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql STABLE AS
$$ SELECT coalesce(nullif(current_setting('role', true), 'none'), session_user) NOT IN ('anon', 'authenticated') $$;
CREATE FUNCTION acteur_identifie() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS
$$ SELECT est_appel_serveur() OR mon_personnage() IS NOT NULL $$;
CREATE FUNCTION exiger_acteur(p text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN IF p IS DISTINCT FROM mon_personnage() THEN RAISE EXCEPTION 'acteur_interdit'; END IF; END $$;
CREATE FUNCTION exiger_poste(p text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF mon_personnage() IS NULL OR current_setting('hg.poste', true) IS DISTINCT FROM p THEN
    RAISE EXCEPTION 'poste_requis: %', p USING ERRCODE = '42501';
  END IF;
  RETURN mon_personnage();
END $$;
-- Doublure de payer_ordre : ordre déclaré, PA puis coût (liquide, puis compte national).
CREATE FUNCTION payer_ordre(p_acteur text, p_fn text, p_pa integer, p_cost integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE r record;
BEGIN
  PERFORM exiger_acteur(p_acteur);
  IF NOT EXISTS (SELECT 1 FROM ordres_couts WHERE fn = p_fn AND pa = p_pa AND cost = p_cost) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare'); END IF;
  SELECT * INTO r FROM personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF r.pa < p_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  IF r.liquide < p_cost THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'disponible', r.liquide); END IF;
  UPDATE personnages_donnees SET pa = pa - p_pa, liquide = liquide - p_cost, arg = arg - p_cost WHERE name = p_acteur;
  RETURN jsonb_build_object('ok', true, 'pa', r.pa - p_pa, 'liquide', r.liquide - p_cost);
END $$;
CREATE FUNCTION helvetia_debiter_fonds_ordinaires(p text, m numeric) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE l numeric; n numeric;
BEGIN
  SELECT liquide INTO l FROM personnages_donnees WHERE name = p FOR UPDATE;
  SELECT coalesce((SELECT solde FROM comptes_bancaires WHERE personnage = p AND banque = 'nationale'), 0) INTO n;
  IF l + n < m THEN RETURN false; END IF;
  UPDATE personnages_donnees SET liquide = greatest(0, l - m), arg = arg - m WHERE name = p;
  UPDATE comptes_bancaires SET solde = solde - greatest(0, m - l) WHERE personnage = p AND banque = 'nationale';
  RETURN true;
END $$;
CREATE FUNCTION assemblee_crediter_joueur(p_nom text, p_montant integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_liquide integer; v_arg integer;
BEGIN
  UPDATE personnages_donnees SET liquide = COALESCE(liquide, 0) + GREATEST(0, p_montant), arg = COALESCE(arg, 0) + GREATEST(0, p_montant)
   WHERE name = p_nom RETURNING liquide, arg INTO v_liquide, v_arg;
  RETURN jsonb_build_object('liquide', v_liquide, 'arg', v_arg);
END $$;

-- Droits et politiques recopiés de la production (prévol PR #296).
ALTER TABLE budgets_clubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE organisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE transferts_clubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE presidents_clubs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Lecture publique du budget club" ON budgets_clubs FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY budgets_clubs_ecriture_acteur ON budgets_clubs FOR INSERT TO authenticated WITH CHECK (acteur_identifie());
CREATE POLICY budgets_clubs_maj_acteur ON budgets_clubs FOR UPDATE TO authenticated USING (acteur_identifie()) WITH CHECK (acteur_identifie());
CREATE POLICY organisations_lecture_publique ON organisations FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY organisations_ecriture_acteur ON organisations FOR INSERT TO authenticated WITH CHECK (acteur_identifie());
CREATE POLICY organisations_maj_acteur ON organisations FOR UPDATE TO authenticated USING (acteur_identifie()) WITH CHECK (acteur_identifie());
CREATE POLICY organisations_suppression_acteur ON organisations FOR DELETE TO authenticated USING (acteur_identifie());
CREATE POLICY "Lecture publique transferts clubs" ON transferts_clubs FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY transferts_clubs_ecriture_acteur ON transferts_clubs FOR INSERT TO authenticated WITH CHECK (acteur_identifie());
CREATE POLICY transferts_clubs_maj_acteur ON transferts_clubs FOR UPDATE TO authenticated USING (acteur_identifie()) WITH CHECK (acteur_identifie());
CREATE POLICY presidents_clubs_lecture ON presidents_clubs FOR SELECT TO anon, authenticated USING (true);
GRANT USAGE ON SCHEMA public, auth TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON budgets_clubs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON organisations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON transferts_clubs TO authenticated;
GRANT SELECT ON presidents_clubs, personnages_donnees, comptes_bancaires, clubs_football, ordres_couts TO authenticated;
'''

DECOR = r'''
TRUNCATE personnages_donnees, comptes_bancaires, ordres_couts, clubs_football, budgets_clubs, presidents_clubs,
         transferts_clubs, organisations, caisses_batiments;
INSERT INTO personnages_donnees(name, user_id, liquide, arg, pa) VALUES
 ('Jean Jaaj', '11111111-1111-1111-1111-111111111111', 5000, 5000, 10),
 ('Vince Kubrick', '22222222-2222-2222-2222-222222222222', 200, 200, 10),
 ('Angie Porcelana', '33333333-3333-3333-3333-333333333333', 4000, 4000, 10),
 ('Arnie', '44444444-4444-4444-4444-444444444444', 0, 0, 10);
INSERT INTO comptes_bancaires VALUES ('Angie Porcelana', 'nationale', 0), ('Vince Kubrick', 'nationale', 0);
INSERT INTO ordres_couts VALUES ('orga_collecte', 2, 0), ('orga_dividendes', 1, 0), ('se_syndiquer', 1, 50),
 ('rejoindre_club_supporters', 1, 50), ('sponsoriser_club', 1, 0);
INSERT INTO clubs_football(id) VALUES ('olympique-luthecia'), ('cheminote-montrouge');
INSERT INTO budgets_clubs VALUES ('olympique-luthecia', '{"caisse":1000,"historique":[],"salaires":{"titulaire":100,"remplacant":50,"primeVictoire":150}}'),
                                 ('cheminote-montrouge', '{"caisse":0,"historique":[]}');
INSERT INTO presidents_clubs VALUES ('olympique-luthecia', '{"president":"Angie Porcelana"}'), ('cheminote-montrouge', '{"president":"Jean Jaaj"}');
INSERT INTO caisses_batiments VALUES ('republic_gouvernement-min_fin', '{"solde":3000}');
INSERT INTO organisations VALUES
 ('orga_eco', 'republic', '{"type":"economique","nom":"Jaaj SA","chef":"Jean Jaaj","fondateur":"Jean Jaaj","caisse":1000,
   "membres":[{"nom":"Jean Jaaj","grade":"PDG","gradeIdx":4},{"nom":"Vince Kubrick","grade":"Associe","gradeIdx":0}],
   "election":{"enCours":true,"phase":"vote","candidats":[{"nom":"Jean Jaaj"},{"nom":"Vince Kubrick"}],"votes":{"Jean Jaaj":"Jean Jaaj"}}}'),
 ('orga_rel', 'republic', '{"type":"religieuse","nom":"Eglise","chef":"Angie Porcelana","fondateur":"Angie Porcelana","caisse":0,"membres":[{"nom":"Angie Porcelana","grade":"Grand Pretre","gradeIdx":3}]}'),
 ('orga_syndicat_dockers_republic_ville_a', 'republic', '{"type":"syndicale","nom":"Dockers","chef":"Étienne Dantafasse (PNJ)","fondateur":"Étienne Dantafasse (PNJ)","chefEstPnj":true,"caisse":0,"membres":[]}');
'''


class _ErreurPsql(Exception):
    def __init__(self, msg): super().__init__(msg); self.pgerror = msg


class _SessionPsql:
    """Repli sans pilote Python : une session psql persistante sur un cluster local jetable
    (initdb + pg_ctl). Même interface minimale que psycopg2 pour ce banc."""
    Error = _ErreurPsql

    def __init__(self):
        import subprocess, shutil, socket
        bindir = next((d for d in ('/usr/lib/postgresql/17/bin', '/usr/lib/postgresql/16/bin') if Path(d, 'initdb').exists()), None)
        if not bindir: raise SystemExit('ni pgserver/psycopg2 ni binaires PostgreSQL locaux')
        import os
        self.dir = tempfile.mkdtemp(prefix='hg-caisses-')
        pre = []
        if os.geteuid() == 0:   # initdb refuse root : le cluster jetable appartient à « postgres »
            shutil.chown(self.dir, 'postgres'); os.chmod(self.dir, 0o755); pre = ['runuser', '-u', 'postgres', '--']
        s = socket.socket(); s.bind(('127.0.0.1', 0)); self.port = s.getsockname()[1]; s.close()
        run = lambda *a: subprocess.run(pre + list(a), check=True, capture_output=True)
        run(bindir + '/initdb', '-D', self.dir + '/d', '-U', 'postgres', '--auth=trust')
        run(bindir + '/pg_ctl', '-D', self.dir + '/d', '-l', self.dir + '/journal', '-o', '-p %d -k %s -c listen_addresses=' % (self.port, self.dir), '-w', 'start')
        self.bindir = bindir
        self.pre = pre
        self.p = subprocess.Popen(pre + [bindir + '/psql', '-X', '-q', '-A', '-t', '-h', self.dir, '-p', str(self.port), '-U', 'postgres', 'postgres'],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        self.description = None; self._rows = []; self.autocommit = True

    def cursor(self): return self

    def execute(self, sql, args=None):
        if args:
            sql = sql % tuple("'" + str(a).replace("'", "''") + "'" for a in args)
        self.p.stdin.write(sql.rstrip().rstrip(';') + ';\n\\echo __FIN__\n'); self.p.stdin.flush()
        lignes = []
        while True:
            l = self.p.stdout.readline()
            if l == '' or l.rstrip('\n') == '__FIN__': break
            lignes.append(l.rstrip('\n'))
        erreurs = [l for l in lignes if 'ERROR:' in l]
        if erreurs: self.description = None; raise _ErreurPsql(erreurs[0].split('ERROR:', 1)[1].strip())
        self._rows = [l.split('|') for l in lignes if l != '' and not l.startswith(('NOTICE:', 'WARNING:', 'DETAIL:', 'HINT:', 'CONTEXT:'))]
        self.description = True if self._rows else None

    def fetchone(self): return tuple(self._rows[0]) if self._rows else None

    def arreter(self):
        import subprocess
        self.p.stdin.close(); self.p.wait()
        subprocess.run(self.pre + [self.bindir + '/pg_ctl', '-D', self.dir + '/d', '-m', 'immediate', 'stop'], capture_output=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--local-jetable', action='store_true', required=True)
    p.parse_args()
    try:
        import pgserver, psycopg2
        server = pgserver.get_server(tempfile.mkdtemp(prefix='hg-caisses-'), cleanup_mode='delete')
        c = psycopg2.connect(server.get_uri()); c.autocommit = True; q = c.cursor(); Erreur = psycopg2.Error
    except ImportError:
        c = q = _SessionPsql(); Erreur = _ErreurPsql
        print('(pilote psql local : pgserver/psycopg2 absents)')
    q.execute(SCHEMA)
    n = [0]; echecs = []

    def qui(nom, poste=None):
        q.execute('RESET ROLE')
        q.execute("SELECT set_config('hg.uid', %s, false), set_config('hg.poste', %s, false)", (UID.get(nom, ''), poste or ''))
        q.execute('SET ROLE authenticated')

    def serveur():
        q.execute('RESET ROLE')

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

    def caisse_club(cid):
        serveur(); q.execute("SELECT (data->>'caisse')::numeric FROM budgets_clubs WHERE id=%s", (cid,)); return float(q.fetchone()[0])

    def orga(oid):
        serveur(); q.execute('SELECT data::jsonb FROM organisations WHERE id=%s', (oid,)); v = q.fetchone()[0]; return json.loads(v) if isinstance(v, str) else v

    def fiche(nom):
        serveur(); q.execute('SELECT liquide::float, pa FROM personnages_donnees WHERE name=%s', (nom,)); a, b = q.fetchone(); return (float(a), int(b))

    refus = lambda r: isinstance(r, str) and r.startswith('ERR:')

    # ========================================================= A. CONTRE-ÉPREUVE (avant)
    serveur(); q.execute(DECOR)
    qui('Vince Kubrick')
    verifie('A1 avant : Vince réécrit la caisse du club',
            essai("UPDATE budgets_clubs SET data=jsonb_set(data,'{caisse}','999999') WHERE id='olympique-luthecia' RETURNING data->>'caisse'"), '999999')
    verifie('A2 avant : Vince vide la caisse de l organisation de Jean',
            essai("UPDATE organisations SET data=jsonb_set(data::jsonb,'{caisse}','0')::text WHERE id='orga_eco' RETURNING data::jsonb->>'caisse'"), '0')
    verifie('A3 avant : Vince se proclame chef de l organisation de Jean',
            essai("UPDATE organisations SET data=jsonb_set(data::jsonb,'{chef}','\"Vince Kubrick\"')::text WHERE id='orga_eco' RETURNING data::jsonb->>'chef'"), 'Vince Kubrick')
    verifie('A4 avant : Vince supprime l organisation de Jean',
            essai("DELETE FROM organisations WHERE id='orga_eco' RETURNING id"), 'orga_eco')

    # ========================================================= B. MIGRATIONS (rejouées deux fois)
    serveur()
    for m in (M1, M2, M1, M2):
        q.execute(m.read_text())
    print('OK  migrations appliquées et rejouées (idempotentes)')
    q.execute(DECOR)

    # ========================================================= C. REFUS
    qui('Vince Kubrick')
    verifie('C1 Vince ne peut plus réécrire une caisse de club',
            essai("UPDATE budgets_clubs SET data=jsonb_set(data,'{caisse}','999999') WHERE id='olympique-luthecia' RETURNING 1"), refus)
    verifie('C2 Vince ne peut pas créer de caisse de club',
            essai("INSERT INTO budgets_clubs VALUES ('x','{\"caisse\":5}') RETURNING 1"), refus)
    qui('Vince Kubrick')
    essai("UPDATE organisations SET data=jsonb_set(data::jsonb,'{caisse}','0')::text WHERE id='orga_eco'")
    verifie('C3 caisse d organisation forgée : la valeur du serveur reste', orga('orga_eco')['caisse'], 1000)
    qui('Vince Kubrick')
    verifie('C4 Vince ne se proclame pas chef',
            essai("UPDATE organisations SET data=jsonb_set(data::jsonb,'{chef}','\"Vince Kubrick\"')::text WHERE id='orga_eco' RETURNING 1"),
            lambda r: refus(r) and 'direction_non_autorisee' in r)
    qui('Vince Kubrick')
    essai("""UPDATE organisations SET data=jsonb_set(data::jsonb,'{membres}',(SELECT jsonb_agg(CASE WHEN e->>'nom'='Vince Kubrick'
             THEN e||'{"gradeIdx":4,"grade":"PDG"}' ELSE e END) FROM jsonb_array_elements(data::jsonb->'membres') e))::text WHERE id='orga_eco'""")
    verifie('C5 membre ordinaire : son grade de chef auto-attribué est annulé',
            [m['gradeIdx'] for m in orga('orga_eco')['membres'] if m['nom'] == 'Vince Kubrick'], [0])
    qui('Vince Kubrick')
    essai("""UPDATE organisations SET data=jsonb_set(data::jsonb,'{membres}',(SELECT jsonb_agg(e) FROM jsonb_array_elements(data::jsonb->'membres') e
             WHERE e->>'nom'<>'Jean Jaaj'))::text WHERE id='orga_eco'""")
    verifie('C6 réponse tardive / blob périmé : Jean n est pas effacé', any(m['nom'] == 'Jean Jaaj' for m in orga('orga_eco')['membres']), True)
    qui('Vince Kubrick')
    essai("UPDATE organisations SET data=jsonb_set(data::jsonb,'{tresorier}','\"Vince Kubrick\"')::text WHERE id='orga_eco'")
    verifie('C7 Vince ne se nomme pas trésorier', orga('orga_eco').get('tresorier'), None)
    qui('Vince Kubrick')
    essai("DELETE FROM organisations WHERE id='orga_eco'")
    serveur(); q.execute("SELECT count(*) FROM organisations WHERE id='orga_eco'")
    verifie('C8 Vince ne supprime pas l organisation de Jean', str(q.fetchone()[0]), '1')
    qui('Vince Kubrick')
    verifie('C9 pas de fondation avec une caisse garnie',
            essai("""INSERT INTO organisations VALUES ('orga_x','republic','{"type":"economique","chef":"Vince Kubrick","fondateur":"Vince Kubrick","caisse":5000,"membres":[]}') RETURNING 1"""),
            lambda r: refus(r) and 'caisse_initiale' in r)
    verifie('C10 pas de fondation au nom d un autre joueur',
            essai("""INSERT INTO organisations VALUES ('orga_y','republic','{"type":"economique","chef":"Jean Jaaj","fondateur":"Jean Jaaj","caisse":0,"membres":[]}') RETURNING 1"""),
            lambda r: refus(r) and 'fondateur_usurpe' in r)
    verifie('C11 Vince ne verse pas les dividendes de l organisation de Jean',
            essai("SELECT organisation_ordre_financier('banc-c11-000000001','orga_eco','orga_dividendes')->>'raison'"), 'pas_gestionnaire_caisse')
    verifie('C12 subvention refusée sans le poste de ministre',
            essai("SELECT subvention_collective_verser('banc-c12-000000001','club_sportif','olympique-luthecia',500)::text"), refus)
    verifie('C13 salaires refusés à qui ne préside pas le club',
            essai("SELECT club_salaires_fixer('olympique-luthecia',99999,99999,99999)->>'raison'"), 'reserve_au_president')
    verifie('C14 offre de transfert forgée refusée',
            essai("""INSERT INTO transferts_clubs VALUES ('t-forge','attente_joueur','{"statut":"attente_joueur","joueur":"Vince Kubrick","clubDepartId":"olympique-luthecia","clubArriveeId":"cheminote-montrouge","prixClub":100}') RETURNING 1"""),
            lambda r: refus(r) and 'offre_non_autorisee' in r)
    verifie('C15 Vince ne vote pas à la place de Jean',
            essai("""UPDATE organisations SET data=jsonb_set(data::jsonb,'{election,votes,Jean Jaaj}','"Vince Kubrick"')::text WHERE id='orga_eco' RETURNING 1"""),
            lambda r: refus(r) and 'vote_pour_autrui' in r)
    avant = caisse_club('olympique-luthecia'); fv = fiche('Vince Kubrick')
    qui('Vince Kubrick')
    verifie('C16 sponsoring sans les fonds : refusé',
            essai("SELECT club_sponsoriser('banc-c16-000000001','olympique-luthecia',3000)->>'raison'"), 'fonds_insuffisants')
    verifie('C17 débit échoué : aucun crédit au club, rien prélevé', (caisse_club('olympique-luthecia'), fiche('Vince Kubrick')), (avant, fv))

    # ========================================================= D. OPÉRATIONS LÉGITIMES
    qui('Jean Jaaj')
    r = essai("SELECT organisation_ordre_financier('banc-d1-0000000001','orga_eco','orga_dividendes')::text"); r = json.loads(r)
    verifie('D1 Jean (chef) verse les dividendes : 300 sortent de la caisse vers lui',
            (r.get('ok'), r.get('montant'), r.get('caisse'), fiche('Jean Jaaj')), (True, 300, 700, (5300.0, 9)))
    qui('Jean Jaaj')
    r = json.loads(essai("SELECT organisation_ordre_financier('banc-d1-0000000001','orga_eco','orga_dividendes')::text"))
    verifie('D2 rejeu : aucun second versement', (r.get('rejeu'), orga('orga_eco')['caisse'], fiche('Jean Jaaj')), (True, 700, (5300.0, 9)))
    qui('Jean Jaaj')
    verifie('D3 requête réutilisée pour un autre ordre : refusée',
            essai("SELECT organisation_ordre_financier('banc-d1-0000000001','orga_eco','orga_collecte')->>'raison'"), 'requete_deja_utilisee')
    qui('Jean Jaaj')
    essai("""UPDATE organisations SET data=jsonb_set(jsonb_set(data::jsonb,'{tresorier}','"Vince Kubrick"'),'{membres}',(SELECT jsonb_agg(CASE WHEN e->>'nom'='Vince Kubrick'
             THEN e||'{"gradeIdx":1}' ELSE e END) FROM jsonb_array_elements(data::jsonb->'membres') e))::text WHERE id='orga_eco'""")
    o = orga('orga_eco')
    verifie('D4 le chef promeut et nomme un trésorier', (o.get('tresorier'), [m['gradeIdx'] for m in o['membres'] if m['nom'] == 'Vince Kubrick']), ('Vince Kubrick', [1]))
    qui('Jean Jaaj')
    verifie('D5 avec un trésorier, le chef ne gère plus la caisse',
            essai("SELECT organisation_ordre_financier('banc-d5-0000000001','orga_eco','orga_dividendes')->>'raison'"), 'pas_gestionnaire_caisse')
    qui('Vince Kubrick')
    r = json.loads(essai("SELECT organisation_ordre_financier('banc-d6-0000000001','orga_eco','orga_dividendes')::text"))
    verifie('D6 le trésorier dispose de la caisse', (r.get('ok'), r.get('montant')), (True, 210))
    qui('Angie Porcelana')
    r = json.loads(essai("SELECT organisation_ordre_financier('banc-d7-0000000001','orga_rel','orga_collecte')::text"))
    verifie('D7 collecte religieuse tirée par le serveur (200 à 699)', (r.get('ok'), 200 <= r.get('montant', 0) <= 699, orga('orga_rel')['caisse'] == r.get('montant')), (True, True, True))
    qui('Vince Kubrick')
    r = json.loads(essai("SELECT club_supporters_cotiser('banc-d8-0000000001','olympique-luthecia')::text"))
    verifie('D8 cotisation supporter : 50 du joueur vers le club', (r.get('ok'), caisse_club('olympique-luthecia'), fiche('Vince Kubrick')[0]), (True, 1050.0, 360.0))
    qui('Vince Kubrick')
    r = json.loads(essai("SELECT club_supporters_cotiser('banc-d8-0000000001','olympique-luthecia')::text"))
    verifie('D9 cotisation rejouée : un seul encaissement', (r.get('rejeu'), caisse_club('olympique-luthecia'), fiche('Vince Kubrick')[0]), (True, 1050.0, 360.0))
    qui('Angie Porcelana')
    r = json.loads(essai("SELECT club_sponsoriser('banc-d10-000000001','olympique-luthecia',1500)::text"))
    verifie('D10 sponsoring argent : 1500 au club, +5 INF', (r.get('ok'), caisse_club('olympique-luthecia'), r.get('inf')), (True, 2550.0, 5))
    qui('Arnie')
    r = json.loads(essai("SELECT organisation_adhesion_payante('banc-d11-000000001','orga_syndicat_dockers_republic_ville_a','Adherent')::text"))
    verifie('D11 adhésion aux dockers sans les 50 FR : refusée, rien crédité', (r.get('raison'), orga('orga_syndicat_dockers_republic_ville_a')['caisse']), ('fonds_insuffisants', 0))
    qui('Vince Kubrick')
    r = json.loads(essai("SELECT organisation_adhesion_payante('banc-d12-000000001','orga_syndicat_dockers_republic_ville_a','Adherent')::text"))
    o = orga('orga_syndicat_dockers_republic_ville_a')
    verifie('D12 adhésion aux dockers : membre au grade 0, 50 à la caisse', (r.get('ok'), o['caisse'], [(m['nom'], m['gradeIdx']) for m in o['membres']]), (True, 50, [('Vince Kubrick', 0)]))
    qui('Angie Porcelana', 'min_fin')
    r = json.loads(essai("SELECT subvention_collective_verser('subv-d13-00000001','organisation','orga_rel',5000)::text"))
    serveur(); q.execute("SELECT (data->>'solde')::numeric FROM caisses_batiments"); solde_min = float(q.fetchone()[0])
    verifie('D13 subvention ministérielle : partielle, plafonnée à la caisse du ministère', (r.get('ok'), r.get('verse'), solde_min), (True, 3000, 0.0))
    qui('Angie Porcelana')
    r = json.loads(essai("SELECT club_salaires_fixer('olympique-luthecia',120,60,200)::text"))
    verifie('D14 la présidente fixe les salaires', r.get('salaires'), {'titulaire': 120, 'remplacant': 60, 'primeVictoire': 200})
    qui('Vince Kubrick')
    verifie('D15 adhésion ordinaire au grade 0 toujours possible',
            essai("""UPDATE organisations SET data=jsonb_set(data::jsonb,'{membres}',(data::jsonb->'membres')||'[{"nom":"Vince Kubrick","grade":"Fidele","gradeIdx":0}]')::text WHERE id='orga_rel'
                     RETURNING (SELECT count(*) FROM jsonb_array_elements(data::jsonb->'membres') e WHERE e->>'nom'='Vince Kubrick')"""), '1')
    qui('Vince Kubrick')
    verifie('D16 vote pour soi accepté',
            essai("""UPDATE organisations SET data=jsonb_set(data::jsonb,'{election,votes,Vince Kubrick}','"Vince Kubrick"')::text WHERE id='orga_eco' RETURNING 1"""), '1')
    serveur(); q.execute("""UPDATE organisations SET data=jsonb_set(data::jsonb,'{election,votes,Angie Porcelana}','"Vince Kubrick"')::text WHERE id='orga_eco'""")
    qui('Vince Kubrick')
    essai("""UPDATE organisations SET data=jsonb_set(jsonb_set(jsonb_set(data::jsonb,'{chef}','"Vince Kubrick"'),'{election}','{"enCours":false,"phase":null,"candidats":[],"votes":{}}'),
             '{membres}',(SELECT jsonb_agg(CASE WHEN e->>'nom'='Vince Kubrick' THEN e||'{"gradeIdx":4,"grade":"PDG"}' ELSE e END) FROM jsonb_array_elements(data::jsonb->'membres') e))::text WHERE id='orga_eco'""")
    o = orga('orga_eco')
    verifie('D17 clôture d élection par un membre : le vainqueur des votes devient chef',
            (o['chef'], [m['gradeIdx'] for m in o['membres'] if m['nom'] == 'Vince Kubrick'], o['caisse']), ('Vince Kubrick', [4], 490))

    # Transfert : négociation par l'écran, règlement par le serveur.
    qui('Jean Jaaj')
    verifie('D18 le président d arrivée dépose une offre',
            essai("""INSERT INTO transferts_clubs VALUES ('t1','propose','{"statut":"propose","joueur":"Vince Kubrick","clubDepartId":"olympique-luthecia","clubArriveeId":"cheminote-montrouge","prixClub":400,"proposePar":"Jean Jaaj"}') RETURNING 1"""), '1')
    qui('Vince Kubrick')
    verifie('D19 le joueur ne peut pas accepter à la place du club de départ',
            essai("""UPDATE transferts_clubs SET statut='attente_joueur', data=data||'{"statut":"attente_joueur"}' WHERE id='t1' RETURNING 1"""), refus)
    qui('Angie Porcelana')
    verifie('D20 la présidente de départ accepte',
            essai("""UPDATE transferts_clubs SET statut='attente_joueur', data=data||'{"statut":"attente_joueur"}' WHERE id='t1' RETURNING 1"""), '1')
    qui('Vince Kubrick')
    r = json.loads(essai("SELECT club_transfert_conclure('t1')::text"))
    verifie('D21 arrivée sans fonds : refus, aucun crédit au départ', (r.get('raison'), caisse_club('olympique-luthecia')), ('caisse_club_insuffisante', 2550.0))
    serveur(); q.execute("UPDATE budgets_clubs SET data=jsonb_set(data,'{caisse}','500') WHERE id='cheminote-montrouge'")
    qui('Vince Kubrick')
    r = json.loads(essai("SELECT club_transfert_conclure('t1')::text"))
    verifie('D22 transfert conclu : 400 de l arrivée au départ', (r.get('ok'), caisse_club('cheminote-montrouge'), caisse_club('olympique-luthecia')), (True, 100.0, 2950.0))
    qui('Vince Kubrick')
    r = json.loads(essai("SELECT club_transfert_conclure('t1')::text"))
    verifie('D23 transfert rejoué : rien ne bouge', (r.get('rejeu'), caisse_club('cheminote-montrouge'), caisse_club('olympique-luthecia')), (True, 100.0, 2950.0))

    qui('Angie Porcelana')
    verifie('D24 la cheffe dissout sa propre organisation', essai("DELETE FROM organisations WHERE id='orga_rel' RETURNING id"), 'orga_rel')

    # ========================================================= E. DROITS FINAUX
    serveur()
    q.execute("""SELECT has_table_privilege('authenticated','budgets_clubs','INSERT'), has_table_privilege('authenticated','budgets_clubs','UPDATE'),
                        EXISTS (SELECT 1 FROM pg_policies WHERE policyname='organisations_suppression_acteur'), has_table_privilege('authenticated','caisses_collectives_operations','SELECT'),
                        has_function_privilege('authenticated','club_caisse_ajuster_interne(text,numeric,text,integer)','EXECUTE'),
                        has_function_privilege('authenticated','organisation_caisse_ajuster_interne(text,numeric)','EXECUTE'),
                        has_function_privilege('anon','club_sponsoriser(text,text,integer)','EXECUTE')""")
    verifie('E1 ACL : aucune écriture directe des caisses, primitives internes fermées', tuple(v in (True, 't') for v in q.fetchone()), (False,) * 7)

    print(('%d cas, %d échec(s).' % (n[0], len(echecs))) + ('' if not echecs else ' ' + ', '.join(echecs)))
    if hasattr(c, 'arreter'): c.arreter()
    raise SystemExit(1 if echecs else 0)


if __name__ == '__main__':
    main()
