#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Controles statiques des droits et de l'autorite serveur de l'Assemblee (etat final des trois
migrations : nationale, securisation_droits du 10/09, actions_joueur du 11/09/2026).

Attrape :
  - une fonction SECURITY DEFINER laissee aux droits par defaut (Supabase accorde EXECUTE a anon) ;
  - une RPC exposee a anon qui accepterait un resultat, un montant, un cout ou un horaire ;
  - un appelant qui invoquerait une RPC systeme avec la cle anon ;
  - une derive entre les couts/formules du serveur et les definitions du jeu (data.js, JS) ;
  - un retour du debit ou du jet cote client dans les actions devenues serveur.
Complement des tests reels en base, pas un substitut.
"""

import os
import re

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
resultats = []


def controle(titre, ok, detail=''):
    resultats.append(bool(ok))
    print("%s %-66s %s" % ("OK  " if ok else "ECHEC", titre, detail))


def lire(chemin):
    with open(os.path.join(RACINE, chemin), encoding='utf-8') as fh:
        return fh.read()


def sans_commentaires_js(src):
    return '\n'.join(l for l in src.split('\n') if not l.lstrip().startswith('//'))


def corps_js(src, nom):
    i = src.find('function ' + nom + '(')
    if i < 0:
        return ''
    j = src.find('{', i)
    d = 0
    for k in range(j, len(src)):
        if src[k] == '{':
            d += 1
        elif src[k] == '}':
            d -= 1
            if d == 0:
                return src[j:k + 1]
    return ''


BASE = lire('migration_assemblee_nationale.sql')
SECU = lire('migration_assemblee_securisation_droits.sql')
ACTIONS = lire('migration_assemblee_actions_joueur.sql')
INTERDICTIONS = lire('migration_assemblee_interdictions_ventes.sql')
TOUT = BASE + '\n' + SECU + '\n' + ACTIONS + '\n' + INTERDICTIONS
DROITS = SECU + '\n' + ACTIONS + '\n' + INTERDICTIONS

LECTURES_PUBLIQUES = {'assemblee_occupation_sieges', 'assemblee_peut_deposer', 'assemblee_cle_convocation',
                      'assemblee_objet_vise', 'assemblee_loi_en_vigueur', 'assemblee_verifier_vente'}
ACTIONS_JOUEUR = {'assemblee_marchander', 'assemblee_consulter_lobbyiste', 'assemblee_neutraliser_depute',
                  'assemblee_reveiller_depute', 'assemblee_deposer', 'assemblee_lier_topic',
                  'assemblee_amender', 'assemblee_retirer', 'assemblee_voter', 'assemblee_verser_indemnite',
                  'assemblee_achat_illegal'}

# Etat final : derniere definition de chaque fonction ; une fonction supprimee sans etre recreee
# ensuite n'existe plus.
defs = {}
for m in re.finditer(r'CREATE OR REPLACE FUNCTION public\.(\w+)\((.*?)\)\s*RETURNS(.*?)AS \$\$(.*?)\$\$;', TOUT, re.S):
    defs[m.group(1)] = {'pos': m.start(), 'args': m.group(2), 'entete': m.group(3), 'corps': m.group(4)}
for m in re.finditer(r'DROP FUNCTION IF EXISTS public\.(\w+)\(', TOUT):
    nom = m.group(1)
    if nom in defs and defs[nom]['pos'] < m.start():
        del defs[nom]

secdef = {n for n, d in defs.items() if 'SECURITY DEFINER' in d['entete']}
secdef |= {n for n in re.findall(r'ALTER FUNCTION public\.(\w+)\([^)]*\)\s+SECURITY DEFINER', BASE) if n in defs}
revoques = set(re.findall(r'REVOKE ALL ON FUNCTION public\.(\w+)\([^)]*\)\s+FROM PUBLIC, anon, authenticated;', DROITS))
grants_anon = set(re.findall(r'GRANT EXECUTE ON FUNCTION public\.(\w+)\([^)]*\)\s+TO [^;]*\banon\b', DROITS)) & set(defs)

# 1-4. Droits
controle('1. chaque SECURITY DEFINER revoquee a PUBLIC/anon/authenticated', not (secdef - revoques),
         '%d fonctions SECURITY DEFINER' % len(secdef) if not (secdef - revoques) else str(sorted(secdef - revoques)))
sans_statut = sorted(set(defs) - revoques - LECTURES_PUBLIQUES)
controle('2. aucune fonction laissee aux droits par defaut', not sans_statut,
         '%d fonctions classees' % len(defs) if not sans_statut else str(sans_statut))
controle('3. anon : 6 lectures publiques + 11 actions joueur, rien d\'autre', grants_anon == LECTURES_PUBLIQUES | ACTIONS_JOUEUR,
         'en trop : %s · manquant : %s' % (sorted(grants_anon - LECTURES_PUBLIQUES - ACTIONS_JOUEUR),
                                           sorted((LECTURES_PUBLIQUES | ACTIONS_JOUEUR) - grants_anon)))
controle('4. aucune lecture publique en SECURITY DEFINER', not (LECTURES_PUBLIQUES & secdef))

# 5. Aucune RPC exposee n'accepte un resultat, un montant, un cout, une caisse ou un horaire
INTERDITS = r'p_reussi|p_montant|p_caisse_key|p_cloture_ts|p_taux|p_jet|p_pa\b|p_fr\b|p_cout|p_bonus|p_resultat|p_prix'
fautives = sorted(n for n in grants_anon if re.search(INTERDITS, defs[n]['args']))
controle('5. aucun parametre de resultat/montant/cout/caisse/horaire expose', not fautives, str(fautives or ''))

# 6-7. Temps parlementaire (securisation du 10/09)
controle('6. ouverture : echeance calculee par la base, fenetre verifiee',
         'p_cloture_ts' not in defs['assemblee_ouvrir_session']['args']
         and 'assemblee_fenetre_ouverture(now())' in defs['assemblee_ouvrir_session']['corps']
         and 'assemblee_prochaine_cloture(now())' in defs['assemblee_ouvrir_session']['corps'])
controle('7. cloture apres echeance ; reveil des seuls endormis avant minuit',
         'scrutin_non_echu' in defs['assemblee_cloturer']['corps']
         and 'endormi_ts < v_minuit' in defs['assemblee_reveil_minuit']['corps'])

# 8. search_path fige
figees = {n for n, d in defs.items() if 'SET search_path' in d['entete']}
figees |= set(re.findall(r'ALTER FUNCTION public\.(\w+)\([^)]*\)\s+SET search_path', DROITS))
controle('8. search_path fige sur chaque SECURITY DEFINER', not (secdef - figees), str(sorted(secdef - figees)) if secdef - figees else '')

# 9. Crons sous identite serveur
CA = lire('api/cron-assemblee.js')
CM = lire('api/cron-minuit.js')
sbrpc_ca = re.search(r'async function sbRpc\(.*?\n\}', CA, re.S).group(0)
appels_cm = [a for a in re.findall(r"sbRpc\('(assemblee_\w+)'[^)]*\)", CM) if a not in LECTURES_PUBLIQUES]
sous_service_cm = re.findall(r"sbRpc\('(assemblee_\w+)'[^)]*HEADERS_SERVICE\)", CM)
controle('9. crons : RPC systeme sous HEADERS_SERVICE, aucun horaire transmis',
         'HEADERS_SERVICE' in sbrpc_ca and 'p_cloture_ts' not in CA and appels_cm and sorted(appels_cm) == sorted(sous_service_cm))

# 10. Aucun client n'appelle une RPC systeme ou interne
INTERNES = sorted(set(defs) - LECTURES_PUBLIQUES - ACTIONS_JOUEUR)
CLIENT = {n: sans_commentaires_js(lire(n)) for n in sorted(os.listdir(RACINE))
          if n.endswith('.js') and (n.startswith('plateau') or n in ('supabase.js', 'forum.js', 'data.js', 'creation.js'))}
fautifs = ['%s:%s' % (f, s) for f, src in CLIENT.items() for s in INTERNES if re.search(r"sbRpc\(\s*'" + s + "'", src)]
controle('10. aucun fichier client n\'appelle une RPC systeme ou interne', not fautifs, str(fautifs or '%d fonctions internes' % len(INTERNES)))

# 11. Idempotence : chaque action a effet ouvre une requete, ou est idempotente par nature
PAR_REQUETE = {'assemblee_marchander', 'assemblee_consulter_lobbyiste', 'assemblee_neutraliser_depute',
               'assemblee_reveiller_depute', 'assemblee_deposer', 'assemblee_amender', 'assemblee_achat_illegal'}
sans_requete = sorted(n for n in PAR_REQUETE if 'assemblee_requete_ouvrir(p_requete' not in defs[n]['corps'])
nature = ('ON CONFLICT (id) DO UPDATE' in defs['assemblee_voter']['corps']
          and "statut <> 'debat'" in defs['assemblee_retirer']['corps']
          and 'topic_deja_lie' in defs['assemblee_lier_topic']['corps']
          and 'unique_violation' in defs['assemblee_verser_indemnite']['corps'])
controle('11. idempotence : requete pour 7 actions, nature pour vote/retrait/topic/indemnite', not sans_requete and nature,
         str(sans_requete) if sans_requete else '')

# 12. Jet et verrous serveur
jets = all('floor(random() * 100)::integer + 1' in defs[n]['corps'] for n in ('assemblee_marchander', 'assemblee_neutraliser_depute'))
verrous = all('FOR UPDATE' in defs[n]['corps'] for n in PAR_REQUETE - {'assemblee_amender', 'assemblee_achat_illegal'}) \
          and "FROM public.assemblee_sieges WHERE id = p_siege_id FOR UPDATE" in defs['assemblee_reveiller_depute']['corps'] \
          and "FROM public.assemblee_sieges WHERE id = p_siege_id FOR UPDATE" in defs['assemblee_neutraliser_depute']['corps']
controle('12. jet tire par le serveur, verrous personnage/siege', jets and verrous)

# 13. Couts serveur == definitions des ordres (data.js)
DATA = lire('data.js')
def ordre(fn):
    m = re.search(r"\{fn:'" + fn + r"'[^}]*?pa:(\d+), cost:(\d+)", DATA)
    return (int(m.group(1)), int(m.group(2))) if m else None
def const(n, c):
    m = re.search(c + r'\s+CONSTANT integer := (\d+);', defs[n]['corps'])
    return int(m.group(1)) if m else None
couts = {
    'marchander': (ordre('marchander_vote'), (const('assemblee_marchander', 'c_pa'), const('assemblee_marchander', 'c_fr'))),
    'lobbyiste': (ordre('consulter_lobbyiste'), (const('assemblee_consulter_lobbyiste', 'c_pa'), const('assemblee_consulter_lobbyiste', 'c_fr'))),
    'reveiller': (ordre('reveiller_depute'), (const('assemblee_reveiller_depute', 'c_pa'), 0)),
    'depot': (ordre('projet_loi'), (const('assemblee_deposer', 'c_pa'), 0)),
    'abrogation': (ordre('proposer_abrogation'), (const('assemblee_deposer', 'c_pa'), 0)),
}
divergents = {k: v for k, v in couts.items() if v[0] != v[1]}
controle('13. couts serveur identiques aux ordres de data.js', not divergents,
         str(divergents) if divergents else ', '.join('%s %d PA+%d' % (k, v[1][0], v[1][1]) for k, v in couts.items()))

# 14. Neutralisation : SQL == NEUTRALISER_MODES (JS)
ILL = lire('plateau-actions-illegales-rumeurs.js')
modes_js = {m.group(1): (m.group(2), int(m.group(3)), int(m.group(4)), int(m.group(5)))
            for m in re.finditer(r"(\w+):\s*\{ label:[^}]*?stat: '(\w+)', base: (\d+), cap: (\d+), paPJ: \d+, paDepute: (\d+)", ILL)}
taux_sql = {m.group(1): (m.group(2), int(m.group(3)), int(m.group(4)))
            for m in re.finditer(r"\('(\w+)', '(\w+)', (\d+), (\d+)\)", defs['assemblee_taux_neutralisation']['corps'])}
pa_sql = dict(re.findall(r"p_mode = '(\w+)' THEN v_pa := (\d+);", defs['assemblee_neutraliser_depute']['corps']))
aligne = modes_js and all(taux_sql.get(k) == v[:3] and int(pa_sql.get(k, -1)) == v[3] for k, v in modes_js.items())
controle('14. neutralisation : stat/base/cap/PA depute identiques au JS', aligne,
         ', '.join('%s %s %d cap %d %d PA' % (k, *v) for k, v in modes_js.items()))
controle('14 bis. PER cible 6 et bonus criminal_c +15 dans la formule serveur',
         '6 / 2.0' in defs['assemblee_taux_neutralisation']['corps']
         and "p_career = 'criminal_c' THEN 15" in defs['assemblee_taux_neutralisation']['corps'])

# 15. Categories d'interdiction : SQL == JS
ASS = lire('plateau-assemblee.js')
cats_js = re.findall(r"^\s{2}(\w+):\s+\{ label:", ASS[ASS.find('const CATEGORIES_INTERDICTION'):ASS.find('};', ASS.find('const CATEGORIES_INTERDICTION'))], re.M)
cats_sql = re.findall(r"'(\w+)'", re.search(r"c_categories CONSTANT text\[\] := ARRAY\[(.*?)\];", defs['assemblee_deposer']['corps'], re.S).group(1))
controle('15. categories d\'interdiction identiques (JS / serveur)', cats_js and sorted(cats_js) == sorted(cats_sql), '%d categories' % len(cats_js))

# 16. La sauvegarde client ne republie plus bonus_lobbyiste
SB = lire('supabase.js')
payload = SB[SB.find('async function sbSavePersonnage'):]
payload = payload[:payload.find('updated_at:')]
controle('16. sbSavePersonnage ne republie plus bonus_lobbyiste', 'bonus_lobbyiste:' not in sans_commentaires_js(payload))

# 17. Plus aucun debit ni jet local dans les actions devenues serveur
HANDLERS = {'confirmerMarchanderVote': ASS, 'doConsulterLobbyiste': ASS, 'confirmerReveillerDepute': ASS,
            'confirmerDeposerProposition': ASS, 'confirmerProposerAbrogation': ASS, 'neutraliserDeputePnj': ILL,
            'verserIndemniteParlementaire': ASS}
locaux = sorted(h for h, src in HANDLERS.items()
                if re.search(r'deduireCoutOrdre|debiterFondsOrdinaires|crediterFondsOrdinaires|Math\.random|state\.pa\s*=|state\.dis\s*=',
                             sans_commentaires_js(corps_js(src, h))))
controle('17. aucun debit, credit ni jet local dans les 7 gestionnaires', not locaux, str(locaux or ''))

# 18. Journal des requetes prive
controle('18. assemblee_requetes : RLS active, aucun droit anon',
         'ALTER TABLE public.assemblee_requetes ENABLE ROW LEVEL SECURITY;' in ACTIONS
         and 'REVOKE ALL ON TABLE public.assemblee_requetes FROM PUBLIC, anon, authenticated;' in ACTIONS)

# 19. Les chances affichees reproduisent celles du serveur
controle('19. affichage client = formules serveur (stats de base, plafonds)',
         "Math.min(66, Math.round(50 + (assembleeStatBase('CHA') + assembleeStatBase('ENT')) / 2))" in ASS
         and 'm.base + (stat * 2) + neutraliserBonusCarriere() - (6 / 2)' in ILL
         and 'estDepute ? neutraliserTauxDepute(cle) : neutraliserTaux(cle, cible)' in ILL)

print()
print('%d controle(s), %d echec(s)' % (len(resultats), resultats.count(False)))
