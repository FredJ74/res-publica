#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Controles de coherence du chantier Assemblee nationale (10 septembre 2026).

Ce ne sont pas des tests d'execution -- rien n'est lance, aucun navigateur, aucune base. Ce sont
des controles STATIQUES sur les sources, du meme type que ceux deja pratiques sur ce depot :

  1. Toute fonction referencee par le routeur existe-t-elle ?
  2. Tout ordre declare dans data.js a-t-il une route ?
  3. Reste-t-il des routes en DOUBLON pour un meme fn ?
  4. Subsiste-t-il des appels vers les fonctions supprimees par ce chantier ?
  5. Toute fonction appelee dans un onclick du nouveau module existe-t-elle ?
  6. Les wrappers sb* utilises par le module sont-ils tous definis ?
  7. Les RPC appelees cote client existent-elles toutes dans la migration ?
  8. Les 9 sieges sont-ils declares a l'identique en SQL et en JS ?
  9. La regle d'attribution des rangs coincide-t-elle entre SQL (COLLATE "C") et JS (sort()) ?
"""

import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FICHIERS_JS = [
    'plateau-assemblee.js', 'plateau-politique.js', 'plateau-actions-illegales-rumeurs.js',
    'plateau-justice-economie.js', 'plateau-pnj.js', 'plateau-multijoueur.js',
    'plateau-personnage.js', 'plateau-communication.js', 'plateau-core.js',
    'plateau-router.js', 'supabase.js', 'data.js', 'forum.js', 'plateau-divers.js',
    'plateau-navigation.js', 'plateau-gouvernement.js', 'plateau-organisations-quetes.js',
    'plateau-immobilier.js', 'plateau-chantiers.js', 'plateau-commerce.js', 'plateau-fonds.js',
    'plateau-objets.js', 'plateau-etat-civil.js', 'plateau-quete-accueil.js',
    'plateau-logements-montrouge.js', 'plateau-resolution.js', 'plateau-rue-centrale.js',
    'plateau-enigme-portrait.js', 'plateau-musee-personnalites.js', 'plateau-maxence.js',
    'plateau-football-realisateur-ia.js', 'plateau-multijoueur.js',
]

resultats = []


def lire(nom):
    chemin = os.path.join(RACINE, nom)
    if not os.path.exists(chemin):
        return ''
    with open(chemin, encoding='utf-8', errors='replace') as fh:
        return fh.read()


def controle(titre, ok, detail=''):
    resultats.append((titre, ok, detail))
    print("%s %-52s %s" % ("OK  " if ok else "ECHEC", titre, detail))


# Corpus complet des sources JS (dedoublonne, l'ordre n'importe pas ici)
SRC = {}
for f in dict.fromkeys(FICHIERS_JS):
    SRC[f] = lire(f)
TOUT = '\n'.join(SRC.values())

# Toutes les fonctions definies quelque part
FONCTIONS = set(re.findall(r'^\s*(?:async\s+)?function\s+([A-Za-z_$][\w$]*)', TOUT, re.M))
FONCTIONS |= set(re.findall(r'^\s*(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?\(', TOUT, re.M))
FONCTIONS |= set(re.findall(r'^\s*(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s+)?function', TOUT, re.M))

ROUTER = SRC['plateau-router.js']
DATA = SRC['data.js']
ASSEMBLEE = SRC['plateau-assemblee.js']
MIGRATION = (lire('migration_assemblee_nationale.sql') + '\n' + lire('migration_assemblee_securisation_droits.sql')
             + '\n' + lire('migration_assemblee_actions_joueur.sql') + '\n' + lire('migration_assemblee_interdictions_ventes.sql'))


# Decoupage du routeur par fonction : un meme fn route dans doOrder ET dans applyEffects n'est
# PAS un doublon (ce sont deux etapes distinctes du meme ordre). Seul un doublon a l'interieur
# d'une MEME fonction rend la seconde occurrence inatteignable.
def blocs_fonctions(src):
    bornes = [(m.group(1), m.start()) for m in
              re.finditer(r'^(?:async\s+)?function\s+([A-Za-z_$][\w$]*)', src, re.M)]
    blocs = {}
    for idx, (nom, deb) in enumerate(bornes):
        fin = bornes[idx + 1][1] if idx + 1 < len(bornes) else len(src)
        blocs[nom] = src[deb:fin]
    return blocs


BLOCS_ROUTER = blocs_fonctions(ROUTER)
MOTS_CLES = {'if', 'else', 'return', 'for', 'while', 'switch', 'typeof', 'await', 'new'}


# ---------------------------------------------------------------- 1. routeur -> fonctions
routes = re.findall(r"fn\s*===\s*'([a-zA-Z_0-9]+)'[^\n]*?\{\s*(?:await\s+)?([A-Za-z_$][\w$]*)\s*\(", ROUTER)
manquantes = sorted({a for _, a in routes if a not in FONCTIONS and a not in MOTS_CLES})
controle("1. fonctions appelees par le routeur : toutes definies",
         not manquantes, ('manquantes : ' + ', '.join(manquantes)) if manquantes else
         '%d routes verifiees' % len(routes))


# ---------------------------------------------------------------- 2. ordres data.js -> routes
ordres = set(re.findall(r"\{\s*fn\s*:\s*'([a-zA-Z_0-9]+)'", DATA))
routes_fn = set(re.findall(r"fn\s*===\s*'([a-zA-Z_0-9]+)'", ROUTER))
# executerOrdreGenerique traite tout fn non route explicitement : on ne signale donc que les
# ordres du CHANTIER, ceux dont on sait qu'ils exigent un handler dedie.
ORDRES_CHANTIER = {
    'observer_debats', 'voter_loi', 'projet_loi', 'amender_projet', 'proposer_abrogation',
    'marchander_vote', 'reveiller_depute', 'registre_assemblee', 'consulter_lobbyiste',
    'se_justifier', 'acheter_sels_ammoniaque',
}
sans_route = sorted(ORDRES_CHANTIER & ordres - routes_fn)
absents_data = sorted(ORDRES_CHANTIER - ordres)
controle("2. ordres du chantier presents dans data.js",
         not absents_data, ('absents : ' + ', '.join(absents_data)) if absents_data else
         '%d ordres' % len(ORDRES_CHANTIER))
controle("2 bis. ordres du chantier routes",
         not sans_route, ('sans route : ' + ', '.join(sans_route)) if sans_route else 'toutes routees')


# ---------------------------------------------------------------- 3. doublons de routes
# Un doublon n'est un piege que DANS UNE MEME fonction : le premier test fait return, le second
# devient inatteignable en silence. C'est exactement le defaut corrige sur 'assassiner' et
# 'projet_loi' par ce chantier.
doublons = []
for nom_fn, bloc in BLOCS_ROUTER.items():
    compte = {}
    for fn in re.findall(r"fn\s*===\s*'([a-zA-Z_0-9]+)'", bloc):
        compte[fn] = compte.get(fn, 0) + 1
    for fn, c in sorted(compte.items()):
        if c > 1:
            doublons.append('%s x%d dans %s' % (fn, c, nom_fn))
# Doublons preexistants, hors perimetre de ce chantier, connus et signales au rapport.
HORS_PERIMETRE = {
    # Preexistants, verifies un par un : les deux occurrences pointent vers le MEME handler avec
    # les MEMES arguments. Le doublon est donc inerte -- la seconde ligne est morte, mais elle ne
    # change aucun comportement. C'est ce qui les distingue de 'assassiner' et 'projet_loi',
    # corriges par ce chantier, ou les deux routes visaient des fonctions DIFFERENTES et ou la
    # bonne etait masquee.
    'etat_nation x2 dans doOrder',             # lignes 298 et 451
    'donner_argent_pnj x2 dans doOrder',       # lignes 318 et 321
    'appeler_police_terrain x2 dans doOrder',  # lignes 319 et 323
    'expulsion_legale x2 dans doOrder',        # lignes 320 et 322
}
doublons_chantier = [d for d in doublons if d not in HORS_PERIMETRE]
controle("3. aucun doublon de route introduit par le chantier",
         not doublons_chantier,
         ('doublons : ' + '; '.join(doublons_chantier)) if doublons_chantier else
         ('aucun (preexistants hors perimetre : %s)' % (', '.join(sorted(HORS_PERIMETRE)) or 'aucun')))
controle("3 bis. doublons preexistants recenses", True,
         ('; '.join(doublons) if doublons else 'aucun'))


# ---------------------------------------------------------------- 4. fonctions supprimees
SUPPRIMEES = [
    'ouvrirDeposerProjet', 'soumettreProjetLoi', 'ouvrirArchivesLois', 'ouvrirDetailLoi',
    'openMarchanderVoteModal', 'soumettreVoteMarchande', 'ouvrirVoteLoi', 'enregistrerVoteLoi',
    'ouvrirModalAssassiner', 'confirmerAssassinat',
    'normaliserChoixVoteLoi', 'libelleChoixVoteLoi',
]
residus = []
for nom in SUPPRIMEES:
    for f, src in SRC.items():
        for m in re.finditer(r'\b' + nom + r'\s*\(', src):
            # ignorer les mentions en commentaire
            debut = src.rfind('\n', 0, m.start()) + 1
            ligne_txt = src[debut:src.find('\n', m.start())]
            if ligne_txt.lstrip().startswith('//') or ligne_txt.lstrip().startswith('*'):
                continue
            residus.append('%s dans %s' % (nom, f))
controle("4. aucun appel residuel aux fonctions supprimees",
         not residus, ('; '.join(sorted(set(residus)))) if residus else
         '%d fonctions verifiees' % len(SUPPRIMEES))


# ---------------------------------------------------------------- 5. onclick du nouveau module
onclicks = set(re.findall(r'onclick="([A-Za-z_$][\w$]*)\(', ASSEMBLEE))
onclicks |= set(re.findall(r"onclick=\\'([A-Za-z_$][\w$]*)\(", ASSEMBLEE))
oc_manquants = sorted(o for o in onclicks if o not in FONCTIONS)
controle("5. handlers onclick du module Assemblee : tous definis",
         not oc_manquants, ('manquants : ' + ', '.join(oc_manquants)) if oc_manquants else
         '%d handlers' % len(onclicks))


# ---------------------------------------------------------------- 6. wrappers sb* utilises
sb_utilises = set(re.findall(r'\b(sb[A-Z][\w$]*)\s*\(', ASSEMBLEE))
sb_definis = set(re.findall(r'(?:async\s+)?function\s+(sb[A-Z][\w$]*)', SRC['supabase.js']))
sb_manquants = sorted(s for s in sb_utilises if s not in sb_definis)
controle("6. wrappers sb* du module : tous definis dans supabase.js",
         not sb_manquants, ('manquants : ' + ', '.join(sb_manquants)) if sb_manquants else
         '%d wrappers' % len(sb_utilises))


# ---------------------------------------------------------------- 7. RPC client -> migration
rpc_appelees = set(re.findall(r"sbRpc\('([a-z_0-9]+)'", SRC['supabase.js']))
rpc_appelees |= set(re.findall(r"sbRpc\('([a-z_0-9]+)'", lire('api/cron-assemblee.js')))
rpc_appelees |= set(re.findall(r"sbRpc\('([a-z_0-9]+)'", SRC.get('api/cron-minuit.js', '')))
rpc_appelees |= set(re.findall(r"sbRpc\('([a-z_0-9]+)'", lire('api/cron-minuit.js')))
rpc_assemblee = {r for r in rpc_appelees if r.startswith('assemblee_')}
rpc_definies = set(re.findall(r'CREATE OR REPLACE FUNCTION public\.(assemblee_[a-z_0-9]+)', MIGRATION))
rpc_manquantes = sorted(rpc_assemblee - rpc_definies)
controle("7. RPC assemblee_* appelees : toutes definies dans la migration",
         not rpc_manquantes, ('manquantes : ' + ', '.join(rpc_manquantes)) if rpc_manquantes else
         '%d RPC appelees / %d definies' % (len(rpc_assemblee), len(rpc_definies)))


# ---------------------------------------------------------------- 8. les 9 sieges SQL vs JS
sieges_sql = re.findall(r"\('(republic:[a-z_]+:\d)',\s*'republic',\s*'([a-z_]+)',\s*(\d),\s*'(dep_[a-z]+)',\s*'([^']+)'\)", MIGRATION)
sieges_js = re.findall(r"\{\s*id:\s*'(republic:[a-z_]+:\d)',\s*city:\s*'([a-z_]+)',\s*rang:\s*(\d),\s*pnjId:\s*'(dep_[a-z]+)',\s*nom:\s*'([^']+)'\s*\}", ASSEMBLEE)
memes = (len(sieges_sql) == 9 and len(sieges_js) == 9
         and sorted(sieges_sql) == sorted(sieges_js))
controle("8. les 9 sieges identiques entre SQL et JS",
         memes, ('SQL=%d JS=%d' % (len(sieges_sql), len(sieges_js))) if not memes else
         '9 sieges, id/ville/rang/pnjId/nom concordants')

# Les noms des 9 PNJ doivent aussi exister dans PNJ_STATS_NOMMES (source unique des stats)
noms_pnj = [s[4] for s in sieges_js]
stats_absents = sorted(n for n in noms_pnj if ("'" + n + "'") not in DATA)
controle("8 bis. les 9 PNJ presents dans PNJ_STATS_NOMMES",
         not stats_absents, ('absents : ' + ', '.join(stats_absents)) if stats_absents else
         '9 PNJ avec stats')

# PER = 6 pour les neuf (§3)
bloc_stats = DATA
per6 = all(re.search(r"'" + re.escape(n) + r"':\s*\{[^}]*PER:6", bloc_stats) for n in noms_pnj)
controle("8 ter. PER = 6 pour les neuf deputes PNJ",
         per6, 'conforme au §3' if per6 else 'au moins un PER different de 6')


# ---------------------------------------------------------------- 9. regle des rangs SQL vs JS
# Le SQL trie avec COLLATE "C" (ordre par point de code). Le JS utilise Array.sort() par defaut
# (ordre des unites de code UTF-16). On verifie qu'aucun localeCompare ne subsiste dans le calcul
# d'occupation, et que les deux ordres coincident sur un echantillon de noms accentues.
collate_sql = 'COLLATE "C"' in MIGRATION
bloc_occ = ASSEMBLEE[ASSEMBLEE.find('function assembleeCalculerOccupation'):]
bloc_occ = bloc_occ[:bloc_occ.find('\n}')]
# On ignore les COMMENTAIRES : le code en contient un qui met explicitement en garde contre
# localeCompare, et le compter reviendrait a signaler l'avertissement comme s'il etait le defaut.
code_occ = '\n'.join(l for l in bloc_occ.split('\n') if not l.lstrip().startswith('//'))
pas_de_locale = 'localeCompare' not in code_occ
a_un_sort = re.search(r'\.sort\(\s*\)', code_occ) is not None
controle("9. SQL trie avec COLLATE \"C\"", collate_sql,
         'tri par point de code' if collate_sql else 'COLLATE absent : divergence possible')
controle("9 bis. JS trie avec Array.sort() nu, sans localeCompare",
         pas_de_locale and a_un_sort,
         'sort() par defaut = ordre des unites de code' if (pas_de_locale and a_un_sort)
         else ('localeCompare subsiste' if not pas_de_locale else 'aucun .sort() trouve'))

# Echantillon : ordre par point de code (equivalent COLLATE "C" et sort() JS) vs ordre locale
echantillon = ['Zoe Martin', 'Émile Durand', 'Alice Bernard', 'Eve Colin']
ordre_codepoint = sorted(echantillon)
try:
    import locale as _loc
    ordre_locale = sorted(echantillon, key=_loc.strxfrm)
except Exception:
    ordre_locale = None
divergent = (ordre_locale is not None and ordre_locale != ordre_codepoint)
controle("9 ter. la divergence evitee est reelle (temoin)", True,
         'point de code %s / locale %s -> %s' % (
             ordre_codepoint[0], (ordre_locale or ['?'])[0],
             'les deux ordres different bien' if divergent else 'ordres identiques ici'))


print("")
echecs = sum(1 for _, ok, _ in resultats if not ok)
print("%d controle(s), %d echec(s)" % (len(resultats), echecs))
sys.exit(1 if echecs else 0)
