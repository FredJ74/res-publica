#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Controles structurels sur migration_assemblee_nationale.sql.

Ce n'est PAS une validation par PostgreSQL : aucun serveur n'est joignable depuis cet
environnement, et la cle disponible est la cle anon (aucun DDL). Ce sont des controles de forme
et de coherence interne, du type de ceux qui attrapent une migration tronquee ou incoherente
avec le code qui l'appelle.
"""

import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
resultats = []


def controle(titre, ok, detail=''):
    resultats.append(ok)
    print("%s %-54s %s" % ("OK  " if ok else "ECHEC", titre, detail))


with open(os.path.join(RACINE, 'migration_assemblee_nationale.sql'), encoding='utf-8') as fh:
    SQL = fh.read()


# 1. Les corps de fonction $$ ... $$ doivent etre apparies
nb_dollars = SQL.count('$$')
controle("1. delimiteurs $$ apparies", nb_dollars % 2 == 0,
         '%d occurrences (%d corps de fonction)' % (nb_dollars, nb_dollars // 2))

# 2. Chaque CREATE FUNCTION a un LANGUAGE et se termine par $$;
fonctions = re.findall(r'CREATE OR REPLACE FUNCTION public\.(\w+)', SQL)
controle("2. fonctions declarees", len(fonctions) >= 17,
         '%d fonctions : %s' % (len(fonctions), ', '.join(sorted(fonctions)[:4]) + '...'))

sans_langage = []
for nom in fonctions:
    bloc = SQL[SQL.find('CREATE OR REPLACE FUNCTION public.' + nom):]
    bloc = bloc[:bloc.find('$$;') + 3] if '$$;' in bloc else bloc
    if 'LANGUAGE' not in bloc:
        sans_langage.append(nom)
controle("2 bis. toutes les fonctions declarent un LANGUAGE", not sans_langage,
         ', '.join(sans_langage) if sans_langage else 'plpgsql / sql')

# 3. Tables attendues
tables = set(re.findall(r'CREATE TABLE IF NOT EXISTS public\.(\w+)', SQL))
attendues = {'assemblee_sieges', 'assemblee_propositions', 'assemblee_intentions',
             'assemblee_votes', 'assemblee_scrutins', 'assemblee_indemnites'}
controle("3. les 6 tables sont creees", attendues <= tables,
         ', '.join(sorted(tables)))

# 4. Les 9 sieges sont seedes
seeds = re.findall(r"\('republic:[a-z_]+:\d'", SQL)
controle("4. les 9 sieges sont seedes", len(seeds) == 9, '%d lignes INSERT' % len(seeds))

# 5. RLS active sur les 6 tables + policy SELECT, aucune policy d'ecriture
rls = set(re.findall(r'ALTER TABLE public\.(\w+)\s+ENABLE ROW LEVEL SECURITY', SQL))
controle("5. RLS activee sur les 6 tables", attendues <= rls, '%d tables' % len(rls))

policies = re.findall(r'CREATE POLICY \w+\s+ON public\.\w+\s+FOR (\w+)', SQL)
controle("5 bis. aucune policy d'ecriture (SELECT uniquement)",
         set(policies) == {'SELECT'}, 'operations : %s' % sorted(set(policies)))

# 6. Toutes les fonctions d'ecriture sont SECURITY DEFINER
definers = set(re.findall(r'ALTER FUNCTION public\.(\w+)\([^)]*\)\s+SECURITY DEFINER', SQL))
# Fonctions qui N'ONT PAS a etre SECURITY DEFINER, pour une raison precise chacune :
#   - lectures pures (STABLE) : occupation des sieges, eligibilite au depot ;
#   - helper IMMUTABLE sans aucune ecriture : cle d'identite d'une convocation ;
#   - fonctions de TRIGGER : elles s'executent avec les droits de l'ecrivain qui les declenche et
#     n'ecrivent dans aucune autre table. Leur accorder une elevation serait un risque sans objet.
#     personnages_preserver_judiciaire est volontairement dans ce cas (voir le controle A12 de
#     verif_non_ecrasement_judiciaire.py).
NON_DEFINER = ('assemblee_occupation_sieges', 'assemblee_peut_deposer', 'assemblee_proposition_immuable',
               'assemblee_cle_convocation', 'personnages_preserver_judiciaire')
ecrivains = {f for f in fonctions if f not in NON_DEFINER}
manquants = sorted(ecrivains - definers)
controle("6. fonctions d'ecriture en SECURITY DEFINER", not manquants,
         ', '.join(manquants) if manquants else '%d fonctions' % len(definers))

# 7. Le trigger d'immutabilite protege bien les 4 champs
bloc_trig = SQL[SQL.find('FUNCTION public.assemblee_proposition_immuable'):]
bloc_trig = bloc_trig[:bloc_trig.find('$$;')]
proteges = [c for c in ('texte_original', 'categorie', 'type', 'auteur')
            if ('NEW.%s IS DISTINCT FROM OLD.%s' % (c, c)) in bloc_trig]
controle("7. trigger d'immutabilite : 4 champs proteges", len(proteges) == 4,
         ', '.join(proteges))

# 8. Le DDL sur une table existante est bien limite a personnages, et additif
alters = re.findall(r'ALTER TABLE public\.(\w+)\s+\n?\s+ADD COLUMN', SQL)
controle("8. DDL sur table existante limite a personnages",
         set(alters) <= {'personnages'}, 'tables alterees : %s' % (sorted(set(alters)) or 'aucune'))
# Seconde forme de DDL sur une table existante, ajoutee par la passe « non-ecrasement » : un trigger
# sur personnages. On verifie qu'il n'y en a pas d'autre, et sur aucune autre table existante.
triggers = re.findall(r'CREATE TRIGGER (\w+)\s+(?:BEFORE|AFTER) \w+ ON public\.(\w+)', SQL)
sur_tables_existantes = [(t, tab) for t, tab in triggers if not tab.startswith('assemblee_')]
controle("8 ter. trigger sur table existante : personnages uniquement",
         sur_tables_existantes == [('trg_personnages_preserver_judiciaire', 'personnages')],
         '%s' % sur_tables_existantes)
colonnes = re.findall(r'ADD COLUMN IF NOT EXISTS (\w+)', SQL)
attendues_col = {'bonus_lobbyiste', 'hospitalisation', 'stats_affaiblies', 'regen_jour'}
controle("8 bis. 4 colonnes additives avec IF NOT EXISTS",
         set(colonnes) == attendues_col, ', '.join(sorted(colonnes)))

# 9. Aucune suppression destructrice
destructeurs = re.findall(r'\b(DROP TABLE|DELETE FROM public\.personnages|TRUNCATE)\b', SQL)
controle("9. aucune instruction destructrice", not destructeurs,
         'aucun DROP TABLE / TRUNCATE' if not destructeurs else str(destructeurs))

# 10. La cle etrangere vers assemblee_propositions est en CASCADE (coherence des enfants)
cascades = len(re.findall(r'REFERENCES public\.assemblee_propositions\(id\) ON DELETE CASCADE', SQL))
controle("10. tables filles en ON DELETE CASCADE", cascades == 3,
         '%d references (intentions, votes, scrutins)' % cascades)

print("")
echecs = sum(1 for r in resultats if not r)
print("%d controle(s), %d echec(s)" % (len(resultats), echecs))
sys.exit(1 if echecs else 0)
