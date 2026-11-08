#!/usr/bin/env python3
import copy
import importlib.util
import unittest
from unittest.mock import patch
import json
import subprocess
from pathlib import Path

R = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('plan97', R / 'outils/livraison/preparer-recette97-219.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Plan(unittest.TestCase):
    def test_ordre_exact_et_sources_verifiees(self):
        result = module.preparer()
        self.assertEqual(result['nombre'], 97)
        # L'empreinte des 461 tarifs du plan historique ne change jamais.
        self.assertEqual(result['tarifs_source'], {
            'lignes': 461,
            'md5': '0ffc6e1caad1f58114eeba150d3d5f48'
        })
        self.assertEqual(result['tarifs_ajoutes_apres_plan97'], [
            {'fn': 'ssm_besoin_aide', 'pa': 0, 'cost': 0},
            {'fn': 'ssm_demander_rendezvous', 'pa': 0, 'cost': 0}
        ])
        # Les deux virements restent dans le plan historique, mais un seul menu gratuit
        # les remplace dans le catalogue actuel : -2 +1 = -1 entree.
        self.assertEqual(result['tarifs_ajoutes_manufactures'], [
            {'fn': 'consulter_catalogue_manufactures', 'pa': 0, 'cost': 0}
        ])
        # 464 tarifs de la coupe PSM + 1 ordre de dérivés pétrochimiques (04/11/2026).
        self.assertEqual(result['tarifs_ajoutes_petrochimie'], [
            {'fn': 'produire_derives_petrochimiques', 'pa': 1, 'cost': 0}
        ])
        self.assertEqual(result['tarifs_ajoutes_naval'], [{'fn': 'consulter_devis_chantier_naval', 'pa': 0, 'cost': 0}])
        self.assertEqual(result['tarifs_ajoutes_renseignement'], [{'fn': 'interroger_renseignement', 'pa': 2, 'cost': 0}])
        self.assertEqual(result['tarifs_ajoutes_vehicules'], [{'fn': f, 'pa': 0, 'cost': 0} for f in
                         ('garage_reviser', 'garage_vehicules', 'mes_vehicules', 'station_carburant')])
        self.assertEqual(result['tarifs_ajoutes_sovarka'], [{'fn': 'contrebande_poissonniere', 'pa': 1, 'cost': 0}, {'fn': 'pharmacie_medicaments', 'pa': 0, 'cost': 0}, {'fn': 'poissonniere_poisson', 'pa': 0, 'cost': 0}, {'fn': 'salon_coupe', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_cession', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_commerces_libres', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_demander_local', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_dossiers_commerciaux', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_retirer_droit', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_signer_attribution', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_terrain_municipal', 'pa': 0, 'cost': 0}])
        self.assertEqual(result['tarifs_ajoutes_sovarka_reunions'], [{'fn': 'sovarka_demande_location', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_reunion_evenement', 'pa': 1, 'cost': 0}, {'fn': 'sovarka_reunion_reserver', 'pa': 0, 'cost': 0}])
        self.assertEqual(result['tarifs_ajoutes_diner_sovarka'], [{'fn':'diner_affaires','pa':2,'cost':100}])
        self.assertEqual(result['tarifs_ajoutes_sovarka_pouvoir'], [{'fn': 'sovarka_mon_parti', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_parti_fonder', 'pa': 2, 'cost': 15}, {'fn': 'sovarka_partis', 'pa': 0, 'cost': 0}, {'fn': 'sovarka_repas_presidentiel', 'pa': 0, 'cost': 0}])
        self.assertEqual(result['tarifs_actuels']['lignes'], 490)  # +3 partis de Sovarka (07/11), -1 Soviet Suprême retiré (08/11)
        self.assertEqual(len(result['tarifs_actuels']['md5']), 32)
        self.assertFalse(result['execution_autorisee'])
        self.assertTrue(result['ancien_plan_tarifaire_conforme_source'])
        self.assertEqual(
            [item['version'] for item in result['migrations'][-2:]],
            ['20261101170000', '20261101171000']
        )

    def test_ajouts_sovarka_non_conformes_refuses(self):
        source = json.loads(subprocess.check_output([
            module.sys.executable, str(R / 'outils/generateurs/generer_ordres_couts.py'), '--json'
        ], cwd=R, text=True))
        result = module.preparer()
        ajouts = result['tarifs_ajoutes_sovarka'] + result['tarifs_ajoutes_sovarka_reunions'] + result['tarifs_ajoutes_sovarka_pouvoir']
        for ajout in ajouts:
            for mutation in ('absence', 'prix', 'pa', 'doublon'):
                alteree = copy.deepcopy(source)
                cible = next(x for x in alteree if x['fn'] == ajout['fn'])
                if mutation == 'absence':
                    alteree.remove(cible)
                elif mutation == 'doublon':
                    alteree.append(copy.deepcopy(cible))
                else:
                    cible['cost' if mutation == 'prix' else 'pa'] += 1
                with self.subTest(ordre=ajout['fn'], mutation=mutation), \
                     patch.object(module.subprocess, 'check_output', return_value=json.dumps(alteree)), \
                     self.assertRaisesRegex(ValueError, 'Ordres (réunions |pouvoir )?Sovarka'):
                    module.preparer()

    def test_variante_diner_sans_exclure_les_tarifs_historiques(self):
        source = json.loads(subprocess.check_output([
            module.sys.executable, str(R / 'outils/generateurs/generer_ordres_couts.py'), '--json'
        ], cwd=R, text=True))
        for mutation in ('absence', 'prix', 'pa', 'doublon'):
            alteree = copy.deepcopy(source)
            cible = next(x for x in alteree if x == {'fn':'diner_affaires','pa':2,'cost':100})
            if mutation == 'absence':
                alteree.remove(cible)
            elif mutation == 'doublon':
                alteree.append(copy.deepcopy(cible))
            else:
                cible['cost' if mutation == 'prix' else 'pa'] += 1
            with self.subTest(mutation=mutation), \
                 patch.object(module.subprocess, 'check_output', return_value=json.dumps(alteree)), \
                 self.assertRaisesRegex(ValueError, 'Dîner Sovarka'):
                module.preparer()

    def test_omission_inversion_et_source_alteree_refusees(self):
        entries = module.preparer()['migrations']
        for change in ('omission', 'inversion', 'empreinte'):
            altered = copy.deepcopy(entries)
            if change == 'omission':
                altered.pop()
            elif change == 'inversion':
                altered[-1], altered[-2] = altered[-2], altered[-1]
            else:
                altered[-1]['sha256'] = '0' * 64
            with self.subTest(modif=change), self.assertRaises(ValueError):
                module.verifier_ordre(altered)


if __name__ == '__main__':
    unittest.main(verbosity=2)
