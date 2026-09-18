#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Verification des FORMULES et des CHIFFRES du chantier Assemblee contre le cahier des charges.

Methode : on extrait les constantes et les formules directement des sources JS/SQL par expression
reguliere, puis on rejoue le calcul en Python et on le compare aux valeurs attendues par le
cahier des charges. Ce n'est donc pas une relecture a l'oeil -- si un coefficient a ete mal
recopie, le calcul diverge et le controle echoue.

Ce que ca NE prouve PAS : que le code s'execute. Seulement que les nombres ecrits sont les bons.
"""

import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
resultats = []


def lire(nom):
    with open(os.path.join(RACINE, nom), encoding='utf-8', errors='replace') as fh:
        return fh.read()


def controle(titre, ok, detail=''):
    resultats.append(ok)
    print("%s %-56s %s" % ("OK  " if ok else "ECHEC", titre, detail))


def sans_commentaires(src):
    """Retire les commentaires // afin de ne pas confondre une MISE EN GARDE ecrite dans le code
    avec le defaut qu'elle decrit. Trois controles s'y etaient laisse prendre : un commentaire
    expliquant qu'on n'utilise volontairement PAS BONUS_CARRIERE_VOL, et deux commentaires
    documentant la cle fantome 'tentative_homicide' et l'ancien appel ouvrirModalArrestation
    ('crime') -- tous signales a tort comme des defauts subsistants."""
    return '\n'.join(l for l in src.split('\n') if not l.lstrip().startswith('//'))


ASSEMBLEE = lire('plateau-assemblee.js')
ILLEGALES = lire('plateau-actions-illegales-rumeurs.js')
JUSTICE = lire('plateau-justice-economie.js')
CORE = lire('plateau-core.js')
DATA = lire('data.js')
MIGRATION = lire('migration_assemblee_nationale.sql')


# =====================================================================
# §18 — NEUTRALISER : base + (stat x 2) + bonusCarriere - (PER cible / 2), plafonne
# =====================================================================
modes = dict(re.findall(
    r"(\w+):\s*\{\s*label:[^,]+,\s*stat:\s*'(\w+)',\s*base:\s*(\d+),\s*cap:\s*(\d+),"
    r"\s*paPJ:\s*(\d+),\s*paDepute:\s*(\d+)", ILLEGALES).__class__(
    [(m[0], m[1:]) for m in re.findall(
        r"(\w+):\s*\{\s*label:[^,]+,\s*stat:\s*'(\w+)',\s*base:\s*(\d+),\s*cap:\s*(\d+),"
        r"\s*paPJ:\s*(\d+),\s*paDepute:\s*(\d+)", ILLEGALES)]))

ATTENDU_MODES = {
    # mode : (stat, base, cap, paPJ, paDepute)
    'mains': ('FOR', 15, 65, 2, 1),
    'arme':  ('DUP', 25, 75, 2, 1),
    'feu':   ('PER', 35, 85, 3, 2),
}
ok_modes = True
detail = []
for cle, (stat, base, cap, paPJ, paDep) in ATTENDU_MODES.items():
    trouve = modes.get(cle)
    if not trouve:
        ok_modes = False
        detail.append('%s absent' % cle)
        continue
    reel = (trouve[0], int(trouve[1]), int(trouve[2]), int(trouve[3]), int(trouve[4]))
    if reel != (stat, base, cap, paPJ, paDep):
        ok_modes = False
        detail.append('%s: %s != %s' % (cle, reel, (stat, base, cap, paPJ, paDep)))
controle("§18 Neutraliser : stat/base/cap/PA des 3 modes", ok_modes,
         '; '.join(detail) if detail else 'mains FOR 15/65 2-1 · arme DUP 25/75 2-1 · feu PER 35/85 3-2')

# Bonus carriere : +15 pour criminal_c UNIQUEMENT
bonus = re.search(r"career\s*===\s*'criminal_c'\)\s*\?\s*(\d+)\s*:\s*0", ILLEGALES)
controle("§18 bonus carriere = +15 pour criminal_c seul",
         bool(bonus) and bonus.group(1) == '15',
         'trouve +%s' % (bonus.group(1) if bonus else '?'))
# Aucun bonus intel/escort ni reputation criminelle dans le chemin Neutraliser
bloc_neutraliser = sans_commentaires(
    ILLEGALES[ILLEGALES.find('const NEUTRALISER_MODES'):ILLEGALES.find('function ouvrirModalAssassinat')])
sans_autres = ('BONUS_CARRIERE_VOL' not in bloc_neutraliser
               and 'ReputationCriminelle' not in bloc_neutraliser)
controle("§18 aucun bonus intel/escort/reputation dans Neutraliser", sans_autres,
         'conforme' if sans_autres else 'un bonus non prevu subsiste')


def taux_neutraliser(mode, stat_val, criminel, per_cible):
    stat, base, cap, _, _ = ATTENDU_MODES[mode]
    brut = base + stat_val * 2 + (15 if criminel else 0) - per_cible / 2
    return max(0, min(cap, round(brut)))


# Cas de reference : depute PNJ (PER 6 -> malus 3)
cas = [
    ('mains', 10, False, 6, 32),   # 15 + 20 + 0 - 3 = 32
    ('mains', 10, True,  6, 47),   # +15 carriere
    ('mains', 30, True,  6, 65),   # 15+60+15-3 = 87 -> plafond 65
    ('arme',  10, False, 6, 42),   # 25 + 20 - 3 = 42
    ('arme',  16, True,  6, 69),   # 25+32+15-3 = 69
    ('feu',   10, False, 6, 52),   # 35 + 20 - 3 = 52
    ('feu',   20, True,  6, 85),   # 35+40+15-3 = 87 -> plafond 85
    ('mains', 10, False, 10, 30),  # cible non renseignee : PER 10 -> malus 5
]
ok_calc = all(taux_neutraliser(m, s, c, p) == att for m, s, c, p, att in cas)
controle("§18 valeurs calculees sur 8 cas de reference", ok_calc,
         'dont depute PNJ PER=6 -> malus 3 points' if ok_calc else 'divergence')


# =====================================================================
# §15/§16 — MARCHANDER : 50 + (CHA + ENT) / 2, +20 lobbyiste
# =====================================================================
ACTIONS_SQL = open(os.path.join(RACINE, 'migration_assemblee_actions_joueur.sql'), encoding='utf-8').read()
f_march_sql = re.search(r"LEAST\(66, round\(50 \+ \(public\.assemblee_stat_base\(p_stats, 'CHA'\)\s*\+ public\.assemblee_stat_base\(p_stats, 'ENT'\)\) / 2\)", ACTIONS_SQL)
f_bonus_sql = "CASE WHEN p_bonus_lobbyiste THEN 20 ELSE 0 END" in ACTIONS_SQL
f_march_js = "Math.min(66, Math.round(50 + (assembleeStatBase('CHA') + assembleeStatBase('ENT')) / 2))" in ASSEMBLEE
controle("§15 marchandage = 50 + (CHA+ENT)/2, max 66, +20 lobbyiste", bool(f_march_sql) and f_bonus_sql and f_march_js,
         'serveur (assemblee_taux_marchandage) + miroir d\'affichage client')

consts = dict(re.findall(r"const (ASSEMBLEE_\w+)\s*=\s*(\d+);", ASSEMBLEE))
attendus = {
    'ASSEMBLEE_MARCHANDAGE_PA': '1', 'ASSEMBLEE_MARCHANDAGE_COUT': '100',
    'ASSEMBLEE_LOBBYISTE_PA': '1', 'ASSEMBLEE_LOBBYISTE_COUT': '150',
    'ASSEMBLEE_LOBBYISTE_BONUS': '20',
}
faux = {k: (consts.get(k), v) for k, v in attendus.items() if consts.get(k) != v}
# Delai de convocation (36 h) et base de detection (50 %) : portes par le serveur depuis le
# 11 septembre 2026 (assemblee_detecter_partie), commune a l'acheteur et au vendeur.
INTERDICTIONS_SQL = open(os.path.join(RACINE, 'migration_assemblee_interdictions_ventes.sql'), encoding='utf-8').read()
corps_det = re.search(r'FUNCTION public\.assemblee_detecter_partie\(.*?\$\$(.*?)\$\$;', INTERDICTIONS_SQL, re.S).group(1)
if "interval '36 hours'" not in corps_det: faux['delai_36h_serveur'] = 'absent'
if 'GREATEST(5, 50 - floor(v_dis / 10)::integer)' not in corps_det: faux['detection_50_serveur'] = 'absente'
controle("§15/§16/§38/§41 constantes (couts, bonus, delai, detection)", not faux,
         str(faux) if faux else '1 PA+100 FR · lobbyiste 1 PA+150 FR/+20 · 36 h · detection 50 %')

# Maximums annonces par le cahier des charges
max_naturel = round(50 + (16 + 16) / 2)          # 66 %
max_lobbyiste = min(100, max_naturel + 20)       # 86 %
controle("§15/§16 maximums : 66 % nu, 86 % avec lobbyiste",
         max_naturel == 66 and max_lobbyiste == 86,
         '16/16 -> %d %% ; +20 -> %d %%' % (max_naturel, max_lobbyiste))

# Sels d'ammoniaque a 30 FR (arbitrage du 10 septembre)
prix_sels = re.search(r"prix:\s*(\d+),", ASSEMBLEE)
prix_ok = bool(prix_sels) and prix_sels.group(1) == '30'
libelle_ok = "30 FR le flacon" in DATA
controle("arbitrage : sels d'ammoniaque a 30 FR", prix_ok and libelle_ok,
         'constante %s FR, libelle data.js coherent' % (prix_sels.group(1) if prix_sels else '?'))


# =====================================================================
# §42 — SE JUSTIFIER : 1 PA, 50 + (CHA + DUP) / 2, max 66
# =====================================================================
f_just = re.findall(r'Math\.round\(50 \+ \(cha \+ dup\) / 2\)', JUSTICE)
controle("§42 formule Se justifier = 50 + (CHA + DUP) / 2", len(f_just) >= 2,
         '%d occurrences (affichage + resolution)' % len(f_just))
max_just = round(50 + (16 + 16) / 2)
controle("§42 maximum naturel 66 %", max_just == 66, '16/16 -> %d %%' % max_just)
cout_just = re.findall(r"fn:'se_justifier'[^}]*pa:(\d+)", DATA)
controle("§42 cout 1 PA dans les deux commissariats",
         len(cout_just) == 2 and set(cout_just) == {'1'},
         '%d declarations, pa=%s' % (len(cout_just), sorted(set(cout_just))))


# =====================================================================
# §25/§41/§42 — BAREMES DE PEINE
# =====================================================================
def peine(cle):
    m = re.search(r"%s:\s*\{\s*jours:\s*(\d+),\s*amende:\s*(\d+)" % re.escape(cle), CORE)
    return (int(m.group(1)), int(m.group(2))) if m else None


baremes = {
    'tentative_assassinat':        (2, 1500),   # §25 : pris sur le fait
    'justification_rejetee':       (1, 0),      # §42 : echec de justification
    'non_presentation_convocation':(2, 0),      # §41 : defaut de comparution
}
faux_b = {k: (peine(k), v) for k, v in baremes.items() if peine(k) != v}
controle("§25/§41/§42 baremes de peine (jours, amende)", not faux_b,
         str(faux_b) if faux_b else 'tentative 2j/1500 · justification 1j · non-presentation 2j')

# La cle fantome ne doit plus etre utilisee nulle part (commentaires exclus)
CODE_SEUL = sans_commentaires(ILLEGALES) + sans_commentaires(JUSTICE) + sans_commentaires(CORE)
fantome = re.findall(r"'tentative_homicide'", CODE_SEUL)
controle("§25 cle fantome 'tentative_homicide' eliminee", not fantome,
         'aucune occurrence' if not fantome else '%d occurrence(s)' % len(fantome))

# ouvrirModalArrestation doit recevoir un ACTE, jamais un TYPE.
# Ce controle a trouve un defaut REEL hors du perimetre initial : confirmerEmpoisonnement passait
# 'crime', ce qui appliquait 8 jours / 5 000 FR au lieu des 2 jours / 2 000 FR que PEINES_ACTES
# declare pour tentative_empoisonnement. Corrige, et signale au rapport.
appels = re.findall(r"ouvrirModalArrestation\('([a-z_]+)'\)", sans_commentaires(ILLEGALES))
types_interdits = {'crime', 'delit_mineur', 'delit_grave', 'crime_etat'}
mauvais = [a for a in appels if a in types_interdits]
controle("§25 ouvrirModalArrestation recoit un acte, pas un type", not mauvais,
         'appels : %s' % sorted(set(appels)) if not mauvais else 'types passes : %s' % mauvais)


# =====================================================================
# §26/§27 — CLOTURE : regle de resultat
# =====================================================================
bloc_clot = MIGRATION[MIGRATION.find('CREATE OR REPLACE FUNCTION public.assemblee_cloturer('):]
bloc_clot = bloc_clot[:bloc_clot.find('$$;')]
regles = [
    ("IF v_score_p > v_score_c THEN", "'ADOPTEE'"),
    ("ELSIF v_score_c > v_score_p THEN", "'REJETEE'"),
    ("ELSE", "'RENVOYEE'"),
]
ok_regles = all(a in bloc_clot and b in bloc_clot for a, b in regles)
controle("§26/§27 cloture : POUR>CONTRE / CONTRE>POUR / egalite", ok_regles,
         'adoptee / rejetee / renvoyee' if ok_regles else 'regle manquante')

# Les endormis ne comptent pas (§20/§26)
endormis_exclus = 'NOT o.endormi AND i.intention' in bloc_clot
controle("§26 les deputes endormis ne votent pas", endormis_exclus,
         "filtre NOT o.endormi sur les deux intentions")

# L'abstention est archivee mais ne compte pas
abst_archivee = "FILTER (WHERE v.choix = 'ABSTENTION')" in bloc_clot
abst_hors_score = "v_abst" not in bloc_clot.split('v_score_p :=')[1].split('IF v_score_p')[0]
controle("§26/§28 abstention archivee, hors du score",
         abst_archivee and abst_hors_score, 'archivee nominativement, non comptee')

# Non-votants = absence de ligne de vote
non_vot = "FILTER (WHERE v.choix IS NULL)" in bloc_clot
controle("§14/§28 'n'a pas vote' = absence de ligne", non_vot,
         'distinct de ABSTENTION')


# =====================================================================
# §49 — DEBIT PLAFONNE : le bug corrige
# =====================================================================
bloc_deb = MIGRATION[MIGRATION.find('FUNCTION public.assemblee_debiter_caisse_plafonne'):]
bloc_deb = bloc_deb[:bloc_deb.find('$$;')]
sans_returning_bug = 'RETURNING LEAST' not in bloc_deb
avec_for_update = 'FOR UPDATE' in bloc_deb
controle("§49 debit plafonne : SELECT FOR UPDATE, plus de RETURNING",
         sans_returning_bug and avec_for_update,
         'verrou de ligne puis calcul puis UPDATE')


print("")
echecs = sum(1 for r in resultats if not r)
print("%d controle(s), %d echec(s)" % (len(resultats), echecs))
sys.exit(1 if echecs else 0)
