"""Banc ÉTAPE A de la fermeture des organisations (20261031230000, PRÉPARÉE) sur PostgreSQL JETABLE.
Aucun DSN ni compte réel accepté. Reprend le décor du banc des caisses collectives, joue
20261031200000 et 20261031201000 TELLES QUELLES (état de la production), puis vérifie que :
  * la migration se refuse sans les contrats #219, puis sans feu vert explicite ;
  * contre-épreuve : avant elle, l'écran réécrit nom, visibilité et élection par la sauvegarde
    générale ; après, ces champs restent ceux du serveur (copie périmée remplacée) ;
  * les chemins encore sans commande (grève, blocus, militants PNJ, adhésion supporters,
    création) continuent de fonctionner ; la caisse reste gardée.
Les trois commandes #219 sont des doublures minimales (le vrai contrat est celui de Codex).
Usage : python3 outils/bancs/banc-organisations-champs-commandes-local.py --local-jetable
"""
import argparse, importlib.util, json, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location('banc_caisses', ROOT / 'outils/bancs/banc-caisses-collectives-local.py')
B = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(B)
MA = ROOT / 'migrations/20261031230000_organisations_champs_commandes_serveur.sql'

DOUBLURES_219 = ''.join("""
CREATE FUNCTION organisation_commande_%s(p_requete text, p_organisation text, p_action text, p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE organisations SET data = (data::jsonb || p_parametres)::text WHERE id = p_organisation;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION organisation_commande_%s(text, text, text, jsonb) TO authenticated;
""" % (n, n) for n in ('membres', 'administrative', 'evenement'))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--local-jetable', action='store_true', required=True)
    p.parse_args()
    try:
        import pgserver, psycopg2
        server = pgserver.get_server(tempfile.mkdtemp(prefix='hg-orgas-'), cleanup_mode='delete')
        c = psycopg2.connect(server.get_uri()); c.autocommit = True; q = c.cursor(); Erreur = psycopg2.Error
    except ImportError:
        c = q = B._SessionPsql(); Erreur = B._ErreurPsql
        print('(pilote psql local : pgserver/psycopg2 absents)')
    q.execute(B.SCHEMA)
    n = [0]; echecs = []; acteur = [None]

    def qui(nom):
        acteur[0] = nom
        q.execute('RESET ROLE')
        q.execute("SELECT set_config('hg.uid', %s, false)", (B.UID.get(nom, ''),))
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

    def orga(oid):
        serveur(); q.execute('SELECT data::jsonb::text FROM organisations WHERE id=%s', (oid,)); v = q.fetchone()[0]
        return json.loads(v) if isinstance(v, str) else v

    def ecrire(oid, modif):
        """Sauvegarde générale de l'écran : le blob entier relu puis modifié (comme sbSaveOrganisation)."""
        o = orga(oid); modif(o); qui(acteur[0])
        return essai("UPDATE organisations SET data=%s WHERE id=%s RETURNING 1", (json.dumps(o), oid))

    refus = lambda r: isinstance(r, str) and r.startswith('ERR:')

    serveur(); q.execute(B.DECOR); q.execute(B.M1.read_text()); q.execute(B.M2.read_text())

    # ================================== P. LA MIGRATION SE REFUSE AVANT SES CONDITIONS
    verifie('P1 refusée sans les contrats #219', essai(MA.read_text()), lambda r: refus(r) and 'contrats_219_absents' in r)
    serveur(); q.execute(DOUBLURES_219)
    verifie('P2 refusée sans feu vert explicite', essai(MA.read_text()), lambda r: refus(r) and 'feu_vert_requis' in r)

    # ================================== A. CONTRE-ÉPREUVE (avant l'étape A)
    qui('Jean Jaaj')
    verifie('A1 avant : le chef renomme par la sauvegarde générale', (ecrire('orga_eco', lambda o: o.update(nom='Blob SA')), orga('orga_eco')['nom']), ('1', 'Blob SA'))
    qui('Vince Kubrick')
    verifie('A2 avant : un membre change visibilité et élection par la sauvegarde générale',
            (ecrire('orga_eco', lambda o: o.update(visible=False, election={'enCours': False})), orga('orga_eco').get('visible'), orga('orga_eco')['election']),
            ('1', False, {'enCours': False}))

    # ================================== B. APRÈS L'ÉTAPE A
    serveur(); q.execute(B.DECOR)
    q.execute("SELECT set_config('hg.feu_vert_organisations', 'parcours_valides', false)")
    q.execute(MA.read_text()); q.execute(MA.read_text())   # rejouable
    q.execute("SELECT set_config('hg.feu_vert_organisations', '', false)")
    election0 = orga('orga_eco')['election']

    qui('Jean Jaaj')
    verifie('B1 renommage par la sauvegarde générale : écriture acceptée, nom du serveur conservé',
            (ecrire('orga_eco', lambda o: o.update(nom='Blob SA')), orga('orga_eco')['nom']), ('1', 'Jaaj SA'))
    qui('Vince Kubrick')
    verifie('B2 visibilité, élection et invitations : copie de l écran remplacée',
            (ecrire('orga_eco', lambda o: o.update(visible=False, election={'enCours': False}, invitationsEnvoyees=['X'])),
             'visible' in orga('orga_eco'), orga('orga_eco')['election'], 'invitationsEnvoyees' in orga('orga_eco')),
            ('1', False, election0, False))
    qui('Jean Jaaj')
    verifie('B3 la commande serveur renomme', essai("SELECT organisation_commande_administrative('r1','orga_eco','informations','{\"nom\":\"Jaaj Holding\"}')::text"),
            lambda r: r is not None and '"ok": true' in r)
    verifie('B4 copie périmée (ancien nom) + grève : nom du serveur gardé, grève enregistrée',
            (ecrire('orga_eco', lambda o: o.update(nom='Jaaj SA', greve={'enCours': True, 'batiment': 'usine'})),
             orga('orga_eco')['nom'], orga('orga_eco').get('greve')), ('1', 'Jaaj Holding', {'enCours': True, 'batiment': 'usine'}))
    verifie('B5 blocus réussi compté (chemin sans commande)',
            (ecrire('orga_eco', lambda o: o.update(blocusReussis=1)), orga('orga_eco').get('blocusReussis')), ('1', 1))
    verifie('B6 militant PNJ ajouté aux membres (chemin sans commande)',
            (ecrire('orga_eco', lambda o: o['membres'].append({'nom': 'Militant Dupont', 'grade': 'Militant (PNJ)', 'estPnj': True})),
             [m['nom'] for m in orga('orga_eco')['membres']][-1]), ('1', 'Militant Dupont'))
    verifie('B7 la caisse reste celle du serveur', (ecrire('orga_eco', lambda o: o.update(caisse=999999)), orga('orga_eco')['caisse']), ('1', 1000))
    qui('Arnie')
    verifie('B8 adhésion de soi au grade 0 (supporters, chemin sans commande)',
            (ecrire('orga_rel', lambda o: o['membres'].append({'nom': 'Arnie', 'grade': 'Fidele', 'gradeIdx': 0})),
             'Arnie' in [m['nom'] for m in orga('orga_rel')['membres']]), ('1', True))
    verifie('B9 création d une organisation (chemin sans commande) toujours possible',
            essai("""INSERT INTO organisations VALUES ('orga_arnie','republic','{"type":"politique","nom":"Parti","chef":"Arnie","fondateur":"Arnie","caisse":0,"membres":[{"nom":"Arnie","grade":"Chef","gradeIdx":3}]}') RETURNING id"""), 'orga_arnie')
    verifie('B10 nom fixé à la création, puis tenu par le serveur',
            (ecrire('orga_arnie', lambda o: o.update(nom='Autre')), orga('orga_arnie')['nom']), ('1', 'Parti'))

    serveur()
    q.execute("""SELECT prosecdef FROM pg_proc WHERE proname='organisations_champs_commandes_garder'""")
    verifie('B11 garde non SECURITY DEFINER (current_user = écran)', q.fetchone()[0] in (False, 'f'), True)

    print(('%d cas, %d échec(s).' % (n[0], len(echecs))) + ('' if not echecs else ' ' + ', '.join(echecs)))
    if hasattr(c, 'arreter'): c.arreter()
    raise SystemExit(1 if echecs else 0)


if __name__ == '__main__':
    main()
