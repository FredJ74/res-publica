import importlib.util
import pathlib
import re
import tempfile
import unittest
import json

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('images_base', ROOT / 'outils/images/controler-images-base.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class CollecteImages(unittest.TestCase):
    def test_select_uniquement_et_identifiants_cites(self):
        sql = mod.requete([{'table_name': 'table"test', 'columns': ['image_path', 'contenu']}])
        self.assertTrue(sql.startswith('SELECT '))
        self.assertIn('public."table""test"', sql)
        self.assertNotRegex(sql, r'\b(?:UPDATE|DELETE|INSERT|CREATE|ALTER|DROP|CALL|COPY|DO|LOCK)\b')
        self.assertIn('regexp_matches', sql)
        self.assertIn('count(*)', sql)
        self.assertNotIn('user_id', sql)
        self.assertNotIn('SELECT *', sql)
        self.assertTrue(mod.METADONNEES.startswith('SELECT '))

    def test_chemins_nus_urls_et_alias_sont_distingues(self):
        ancien = mod.ROOT
        with tempfile.TemporaryDirectory() as temp:
            mod.ROOT = pathlib.Path(temp)
            try:
                (mod.ROOT / 'images').mkdir()
                (mod.ROOT / 'images/presente.webp').write_bytes(b'fixture')
                (mod.ROOT / 'vercel.json').write_text(json.dumps({'rewrites': [
                    {'source': '/images/ancienne.png', 'destination': '/images/presente.webp'}]}))
                urls = ['images/ancienne.png', 'images/absente.webp', 'dossier/fichier.webp',
                        'https://exemple.invalid/photo.jpg',
                        'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/ancienne.png']
                rows = [{'table_name': 'test', 'column_name': 'image_path', 'image_path': u,
                         'occurrences': 1} for u in urls]
                r = mod.controler(rows)
                self.assertEqual([x['statut'] for x in r['references']],
                                 ['presente', 'absente', 'stockage_ou_chemin_relatif_a_resoudre',
                                  'externe_a_verifier_http', 'absente'])
                self.assertEqual(r['occurrences'], 5)
                self.assertTrue(r['lecture_seule'])
            finally:
                mod.ROOT = ancien

    def test_aucun_client_sql_ni_reseau_dans_le_script(self):
        source = (ROOT / 'outils/images/controler-images-base.py').read_text()
        for interdit in ['psycopg', 'subprocess', 'urllib.request', 'execute_sql', 'apply_migration']:
            self.assertNotIn(interdit, source)


if __name__ == '__main__':
    unittest.main()
