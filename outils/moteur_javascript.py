"""Choix du moteur réel pour les contrôles, sans modifier leurs assertions.

Le repli Node réutilise l'adaptateur des bancs existant (print/readFile/load).
"""
from pathlib import Path
import shutil

def choisir_moteur(candidats):
    for candidat in candidats:
        if Path(candidat).is_file():
            return candidat
    node = shutil.which('node')
    if node:
        return [node, str(Path(__file__).parent / 'bancs' / 'shell-node.cjs')]
    return None

def commande_moteur(moteur, fichier):
    return (list(moteur) if isinstance(moteur, (list, tuple)) else [moteur]) + [fichier]
