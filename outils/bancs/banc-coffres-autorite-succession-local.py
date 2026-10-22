#!/usr/bin/env python3
"""Precondition #69 : attaque historique puis correction reelle, pas un resultat simule."""
from pathlib import Path
import runpy
if __name__=='__main__':
 runpy.run_path(str(Path(__file__).with_name('banc-successions-autorisations-local.py')),run_name='__main__')
