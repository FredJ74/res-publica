"""Régressions du contrôleur : vrais processus locaux, aucun jeu ni service distant."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

spec = importlib.util.spec_from_file_location('controleur', Path(__file__).with_name('controler-client.py'))
controleur = importlib.util.module_from_spec(spec)
spec.loader.exec_module(controleur)


class ControleurProcessus(unittest.TestCase):
    def lancer(self, texte, **options):
        return controleur.executer_banc([sys.executable, '-u', '-c', texte], cwd=Path(__file__).parent,
                                        delai=options.pop('delai', 2), delai_arret=.3, **options)

    def test_succes_et_refus_assertion_distincts(self):
        self.assertEqual(self.lancer('print("OK local")'), (0, 'OK local\n'))
        code, sortie = self.lancer('print("avant assertion"); raise AssertionError("vrai refus")')
        self.assertEqual(code, 1)
        self.assertIn('avant assertion', sortie)
        self.assertIn('AssertionError: vrai refus', sortie)
        self.assertNotIn('Delai de', sortie)

    def test_executable_absent(self):
        code, sortie = controleur.executer_banc(['/hg/executable/inexistant'], cwd=Path.cwd())
        self.assertEqual(code, 125)
        self.assertIn('Lancement impossible', sortie)

    def test_timeout_conserve_les_deux_flux(self):
        debut = time.monotonic()
        code, sortie = self.lancer('import time,sys; print("stdout partiel"); '
                                  'print("stderr partiel",file=sys.stderr); time.sleep(60)', delai=2)
        self.assertEqual(code, 124)
        self.assertIn('stdout partiel', sortie)
        self.assertIn('stderr partiel', sortie)
        self.assertIn('banc non valide', sortie)
        self.assertLess(time.monotonic() - debut, 6)

    def test_timeout_tue_enfant_ignorant_sigterm_et_preserve_autre_session(self):
        with tempfile.TemporaryDirectory(prefix='hg-controleur-') as dossier:
            pid = Path(dossier) / 'enfant.pid'
            enfant = ('import os,signal,time,pathlib; signal.signal(signal.SIGTERM,signal.SIG_IGN); '
                      f'pathlib.Path({str(pid)!r}).write_text(str(os.getpid())); time.sleep(60)')
            parent = ('import subprocess,sys,time; '
                      f'subprocess.Popen([sys.executable,"-u","-c",{enfant!r}]); '
                      'print("parent pret"); time.sleep(60)')
            temoin = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'],
                                       start_new_session=True)
            try:
                code, sortie = self.lancer(parent, delai=3)
                self.assertEqual(code, 124, sortie)
                self.assertTrue(pid.exists(), 'enfant réellement lancé, pas de succès par défaut')
                enfant_pid = int(pid.read_text())
                # Linux peut conserver brièvement un zombie réadopté : il est arrêté.
                arrete = False
                for _ in range(50):
                    proc = Path(f'/proc/{enfant_pid}/stat')
                    if not proc.exists() or proc.read_text().split(') ')[1].startswith('Z'):
                        arrete = True
                        break
                    time.sleep(.02)
                self.assertTrue(arrete, 'un descendant ignore TERM et continue après le timeout')
                self.assertIsNone(temoin.poll(), 'une session étrangère a été arrêtée')
            finally:
                if pid.exists():
                    try:
                        os.kill(int(pid.read_text()), signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                temoin.kill()
                temoin.wait(timeout=2)

    def test_parent_ignore_sigterm(self):
        code, sortie = self.lancer('import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); '
                                  'print("TERM ignore"); time.sleep(60)', delai=2)
        self.assertEqual(code, 124)
        self.assertIn('TERM ignore', sortie)

    def test_signal_term_cleanup_et_bilan_interrompu(self):
        with tempfile.TemporaryDirectory(prefix='hg-controleur-signal-') as dossier:
            dossier = Path(dossier)
            bancs = dossier / 'bancs'
            bancs.mkdir()
            (bancs / 'banc-test.cjs').write_text('fixture')
            pid = dossier / 'pid'
            texte = ('import os,pathlib,time; '
                     f'pathlib.Path({str(pid)!r}).write_text(str(os.getpid())); time.sleep(60)')
            lanceur = ('import importlib.util,pathlib,sys,signal; '
                       f's=importlib.util.spec_from_file_location("c",{str(Path(controleur.__file__))!r}); '
                       'c=importlib.util.module_from_spec(s);s.loader.exec_module(c); '
                       'signal.signal(signal.SIGTERM,c.interrompre); '
                       f'c.ICI=pathlib.Path({str(bancs)!r}); '
                       f'c.shutil.which=lambda _: {sys.executable!r}; '
                       'vrai=c.executer_banc; '
                       f'c.executer_banc=lambda *a,**kw: vrai([sys.executable,"-u","-c",{texte!r}],**kw); '
                       f'sys.argv=["c","--rapport",{str(dossier / 'rapport')!r}]; '
                       'sys.exit(c.main())')
            proc = subprocess.Popen([sys.executable, '-c', lanceur], stdout=subprocess.DEVNULL,
                                    stderr=subprocess.DEVNULL, start_new_session=True)
            try:
                limite = time.monotonic() + 10
                while not pid.exists() and proc.poll() is None and time.monotonic() < limite:
                    time.sleep(.02)
                self.assertTrue(pid.exists(), 'le banc doit être lancé avant annulation')
                proc.terminate()
                self.assertEqual(proc.wait(timeout=3), 143)
                bilan = json.loads((dossier / 'rapport/execution.json').read_text())
                self.assertEqual(bilan['etat'], 'interrompue')
                self.assertEqual(bilan['bancs_termines'], 0)
                with self.assertRaises(ProcessLookupError):
                    os.kill(int(pid.read_text()), 0)
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait(timeout=2)
                if pid.exists():
                    try:
                        os.kill(int(pid.read_text()), signal.SIGKILL)
                    except ProcessLookupError:
                        pass

    def test_bilan_partiel_persiste_et_echec_ne_devient_pas_succes(self):
        with tempfile.TemporaryDirectory(prefix='hg-controleur-rapport-') as dossier:
            dossier = Path(dossier)
            bancs = dossier / 'bancs'
            bancs.mkdir()
            (bancs / 'banc-a.cjs').write_text('fixture')
            (bancs / 'banc-b.cjs').write_text('fixture')
            ancien = controleur.ICI
            executeur = controleur.executer_banc
            argv = sys.argv
            appels = []
            def execution(*args, **kwargs):
                if appels:
                    bilan = json.loads((dossier / 'rapport/execution.json').read_text())
                    self.assertEqual(bilan['etat'], 'en_cours')
                    self.assertEqual(bilan['bancs_termines'], 1)
                    raise KeyboardInterrupt()
                appels.append(True)
                return 124, 'diagnostic partiel\n'
            try:
                controleur.ICI = bancs
                controleur.executer_banc = execution
                sys.argv = ['controleur', '--rapport', str(dossier / 'rapport')]
                with self.assertRaises(KeyboardInterrupt):
                    controleur.main()
                bilan = json.loads((dossier / 'rapport/execution.json').read_text())
                self.assertEqual(bilan, {'etat': 'interrompue', 'bancs_prevus': 2,
                                        'bancs_termines': 1, 'echecs': 1})
                self.assertEqual(json.loads((dossier / 'rapport/resultats.json').read_text())[0]['code'], 124)
                self.assertEqual((dossier / 'rapport/banc-a.cjs.log').read_text(), 'diagnostic partiel\n')
                self.assertEqual(list((dossier / 'rapport').glob('*.tmp')), [])
            finally:
                controleur.ICI, controleur.executer_banc, sys.argv = ancien, executeur, argv


if __name__ == '__main__':
    unittest.main()
