#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Preuve de NON-ECRASEMENT des donnees judiciaires serveur par une sauvegarde client ancienne.

AUCUN PostgreSQL n'est disponible dans cet environnement (verifie : ni psql, ni postgres, ni
initdb). Le trigger SQL n'a donc PAS pu etre execute. La preuve est construite en trois couches,
et chacune dit exactement ce qu'elle prouve :

  A. CONTROLES STRUCTURELS DU SQL -- le trigger existe, porte sur la bonne table au bon moment,
     et contient bien chacune des clauses dont depend la garantie.

  B. MODELE EXECUTABLE DE LA FUSION -- une transcription Python ligne a ligne de la logique du
     trigger, jouee sur des scenarios dont LE SCENARIO D'ECRASEMENT EXACT. Cela prouve que
     l'ALGORITHME est correct. Cela ne prouve PAS que le SQL s'execute : c'est pourquoi la couche A
     verifie en parallele que chaque regle du modele figure bien dans le SQL.

  C. CONTROLES DES ECRIVAINS JS -- aucun chemin client ne peut contourner la protection, et les
     sauvegardes ordinaires ne regressent pas.
"""

import os
import re
import sys
from datetime import datetime, timedelta, timezone

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
resultats = []


def controle(titre, ok, detail=''):
    resultats.append(ok)
    print("%s %-62s %s" % ("OK  " if ok else "ECHEC", titre, detail))


def lire(nom):
    with open(os.path.join(RACINE, nom), encoding='utf-8', errors='replace') as fh:
        return fh.read()


def sans_commentaires_js(src):
    return '\n'.join(l for l in src.split('\n') if not l.lstrip().startswith('//'))


def sans_commentaires_sql(src):
    return '\n'.join(l for l in src.split('\n') if not l.lstrip().startswith('--'))


SQL = lire('migration_assemblee_nationale.sql')
SQL_CODE = sans_commentaires_sql(SQL)


def bloc_fonction(nom):
    i = SQL_CODE.find('FUNCTION public.' + nom + '(')
    if i < 0:
        return ''
    j = SQL_CODE.find('$$;', i)
    return SQL_CODE[i:j]


TRIG = bloc_fonction('personnages_preserver_judiciaire')
CLE = bloc_fonction('assemblee_cle_convocation')
VENDEUR = bloc_fonction('assemblee_tracer_vente_interdite')
ECHUES = bloc_fonction('assemblee_marquer_convocations_echues')


print("=" * 100)
print("A. CONTROLES STRUCTURELS DU SQL")
print("=" * 100)

controle("A1. le trigger existe et est attache a personnages",
         bool(re.search(r'CREATE TRIGGER trg_personnages_preserver_judiciaire\s+BEFORE UPDATE ON public\.personnages',
                        SQL_CODE)),
         'BEFORE UPDATE ON public.personnages')

controle("A2. il s'execute pour chaque ligne (FOR EACH ROW)",
         'FOR EACH ROW EXECUTE FUNCTION public.personnages_preserver_judiciaire()' in SQL_CODE)

controle("A3. BEFORE et non AFTER (il doit pouvoir reecrire NEW)",
         'BEFORE UPDATE ON public.personnages' in SQL_CODE and 'RETURN NEW;' in TRIG,
         'NEW est modifie puis renvoye')

# A4 exige l'INSTRUCTION de reinjection elle-meme, pas seulement la presence de mots-cles : une
# premiere version se contentait de 'NOT EXISTS' + 'OLD.convocations', et aurait laisse passer un
# trigger dont la ligne d'ajout aurait ete supprimee (constate par mutation).
reinjection_conv = re.search(
    r'NOT EXISTS\s*\(.*?assemblee_cle_convocation\(v_old\).*?\)\s*THEN\s*v_convs\s*:=\s*v_convs\s*\|\|\s*jsonb_build_array\(v_old\);',
    TRIG, re.S)
controle("A4. convocations : reinjection des elements absents de NEW",
         bool(reinjection_conv) and 'NEW.convocations := v_convs' in TRIG,
         'NOT EXISTS ... THEN v_convs := v_convs || jsonb_build_array(v_old)')

controle("A5. convocations : traitee monotone (OLD OR NEW)",
         "COALESCE((v_old->>'traitee')::boolean, false)" in TRIG
         and "jsonb_build_object('traitee', true)" in TRIG)

controle("A6. convocations : echue monotone (OLD OR NEW)",
         "COALESCE((v_old->>'echue')::boolean, false)" in TRIG
         and "jsonb_build_object('echue', true" in TRIG)

controle("A7. historique : seules les traces 'serveur' sont protegees",
         "v_old->>'origine' = 'serveur'" in TRIG and "v_old ? 'id'" in TRIG)

controle("A8. historique : une trace serveur expiree n'est plus reinjectee",
         "now() < (v_old->>'expireTs')::timestamptz" in TRIG)

controle("A9. historique : correspondance par id, puis reinjection effective",
         "n.value->>'id' = v_old->>'id'" in TRIG
         and bool(re.search(r'THEN\s*v_hist\s*:=\s*v_hist\s*\|\|\s*jsonb_build_array\(v_old\);', TRIG))
         and 'NEW.historique_crimes := v_hist' in TRIG,
         'NOT EXISTS ... THEN v_hist := v_hist || jsonb_build_array(v_old)')

controle("A10. cout minimal : ne travaille que si la colonne change",
         'NEW.convocations IS DISTINCT FROM OLD.convocations' in TRIG
         and 'NEW.historique_crimes IS DISTINCT FROM OLD.historique_crimes' in TRIG)

controle("A11. cle d'identite : id, sinon cle derivee du contenu",
         "COALESCE(" in CLE and "e->>'id'" in CLE and "'legacy|'" in CLE)

controle("A12. le trigger n'est PAS SECURITY DEFINER (aucune elevation)",
         'personnages_preserver_judiciaire' not in
         ''.join(re.findall(r'ALTER FUNCTION public\.(\w+)\([^)]*\)\s+SECURITY DEFINER', SQL_CODE)))

controle("A13. RPC vendeur : trace marquee origine serveur + id + expireTs",
         "'origine', 'serveur'" in VENDEUR and "'id', 'trace-'" in VENDEUR and "'expireTs'" in VENDEUR)

controle("A14. RPC vendeur : convocation marquee origine serveur + id",
         "'id', 'conv-'" in VENDEUR and VENDEUR.count("'origine', 'serveur'") >= 2)

controle("A15. RPC echeance : pose echue, ne touche jamais est_emprisonne",
         "'echue', true" in ECHUES and 'est_emprisonne' not in ECHUES)

controle("A16. RPC echeance : ensembliste, verrou de ligne",
         'FOR UPDATE' in ECHUES and 'UPDATE public.personnages SET convocations' in ECHUES)


print("")
print("=" * 100)
print("B. MODELE EXECUTABLE DE LA FUSION (transcription Python du trigger)")
print("=" * 100)
print("   Prouve l'ALGORITHME. Ne prouve pas l'execution du SQL (voir couche A).")
print("")


def cle_convocation(e):
    """Transcription de public.assemblee_cle_convocation."""
    if e.get('id') is not None:
        return e['id']
    return 'legacy|%s|%s|%s|%s' % (e.get('motif', ''), e.get('jourEmission', ''),
                                   e.get('heureEmission', ''), e.get('limiteTs', ''))


def fusion_convocations(old, new):
    """Transcription du bloc CONVOCATIONS du trigger."""
    if new == old:                               # IS DISTINCT FROM
        return new
    res = []
    for elem in (new or []):                     # 1. partir de NEW, reporter les drapeaux monotones
        elem = dict(elem)
        o = next((x for x in (old or []) if cle_convocation(x) == cle_convocation(elem)), None)
        if o is not None:
            if o.get('traitee'):
                elem['traitee'] = True
            if o.get('echue'):
                elem['echue'] = True
                elem['echueTs'] = o.get('echueTs')
        res.append(elem)
    for o in (old or []):                        # 2. reinjecter ce qui manque
        if not any(cle_convocation(n) == cle_convocation(o) for n in res):
            res.append(o)
    return res


def fusion_historique(old, new, maintenant):
    """Transcription du bloc HISTORIQUE DES CRIMES du trigger."""
    if new == old:
        return new
    res = list(new or [])
    for o in (old or []):
        if (o.get('origine') == 'serveur' and 'id' in o
                and (o.get('expireTs') is None or maintenant < o['expireTs'])
                and not any(n.get('id') == o['id'] for n in res)):
            res.append(o)
    return res


MAINTENANT = datetime(2026, 9, 10, 20, 0, tzinfo=timezone.utc)
FUTUR = MAINTENANT + timedelta(days=5)
PASSE = MAINTENANT - timedelta(days=1)


# ---- Scenarios CONVOCATIONS
conv_client = {'id': 'conv-A', 'motif': 'achat_arme_illegal', 'traitee': False}
conv_serveur = {'id': 'conv-S', 'origine': 'serveur', 'motif': 'transaction_interdite',
                'limiteTs': '2026-09-12T08:00:00Z', 'traitee': False}

# B1 — LE SCENARIO D'ECRASEMENT EXACT
# Le vendeur est connecte, son etat en memoire date d'AVANT la vente. La RPC ecrit une convocation
# chez lui. Il sauvegarde ensuite son etat ancien, qui ne la contient pas.
base = [conv_client]
apres_rpc = [conv_client, conv_serveur]           # ce que la base contient apres la RPC
sauvegarde_ancienne = [conv_client]               # ce que le client republie
r = fusion_convocations(apres_rpc, sauvegarde_ancienne)
controle("B1. ECRASEMENT : convocation serveur survit a une sauvegarde ancienne",
         any(c['id'] == 'conv-S' for c in r), '%d convocation(s) apres fusion' % len(r))

# B2 — verdict d'echeance pose par le serveur, puis sauvegarde d'un etat ou echue est absent
old = [dict(conv_serveur, echue=True, echueTs='2026-09-12T08:05:00Z')]
new = [dict(conv_serveur)]                         # client ancien, sans echue
r = fusion_convocations(old, new)
controle("B2. le verdict serveur 'echue' ne peut pas etre efface",
         r[0].get('echue') is True, 'echue=%s' % r[0].get('echue'))

# B3 — convocation deja sanctionnee (traitee), sauvegarde d'un onglet ancien ou traitee=false
old = [dict(conv_client, traitee=True)]
new = [dict(conv_client, traitee=False)]
r = fusion_convocations(old, new)
controle("B3. 'traitee' ne peut pas redevenir faux -> pas de double sanction",
         r[0]['traitee'] is True, 'traitee=%s' % r[0]['traitee'])

# B4 — chemin client LEGITIME : le joueur se justifie, traitee passe a vrai
old = [dict(conv_client, traitee=False)]
new = [dict(conv_client, traitee=True)]
r = fusion_convocations(old, new)
controle("B4. le client peut toujours marquer une convocation traitee",
         r[0]['traitee'] is True)

# B5 — chemin client LEGITIME : nouvelle convocation creee cote client
new_conv = {'id': 'conv-B', 'motif': 'possession_illegale_douane', 'traitee': False}
r = fusion_convocations([conv_client], [conv_client, new_conv])
controle("B5. une convocation creee cote client est bien enregistree",
         any(c['id'] == 'conv-B' for c in r) and len(r) == 2)

# B6 — deux convocations meme motif, meme heure, mais ids distincts : aucune confusion
c1 = {'id': 'conv-1', 'motif': 'possession_illegale_douane', 'jourEmission': 4, 'heureEmission': 10}
c2 = {'id': 'conv-2', 'motif': 'possession_illegale_douane', 'jourEmission': 4, 'heureEmission': 10}
r = fusion_convocations([c1, c2], [c1])           # client ancien n'en connait qu'une
controle("B6. deux convocations jumelles (ids distincts) : aucune perdue",
         sorted(c['id'] for c in r) == ['conv-1', 'conv-2'])

# B7 — convocations anterieures au chantier, sans id : cle derivee du contenu
leg = {'motif': 'achat_arme_illegal', 'jourEmission': 3, 'heureEmission': 14, 'traitee': True}
r = fusion_convocations([leg], [dict(leg, traitee=False)])
controle("B7. convocation legacy sans id : reconnue, traitee preservee",
         len(r) == 1 and r[0]['traitee'] is True)

# B8 — idempotence : une sauvegarde qui ne change rien ne produit rien de nouveau
r = fusion_convocations([conv_client, conv_serveur], [conv_client, conv_serveur])
controle("B8. sauvegarde inchangee : fusion neutre (IS DISTINCT FROM)",
         r == [conv_client, conv_serveur])

# ---- Scenarios HISTORIQUE
trace_serveur = {'id': 'trace-S', 'origine': 'serveur', 'acte': 'transaction_interdite',
                 'expireTs': FUTUR}
crime_client = {'acte': 'vol', 'cible': 'X', 'jour': 4, 'expireJour': 12}

# B9 — LE SCENARIO D'ECRASEMENT EXACT, cote historique
r = fusion_historique([crime_client, trace_serveur], [crime_client], MAINTENANT)
controle("B9. ECRASEMENT : trace serveur survit a une sauvegarde ancienne",
         any(c.get('id') == 'trace-S' for c in r))

# B10 — trace serveur expiree : la purge normale n'est PAS contrariee
expiree = dict(trace_serveur, expireTs=PASSE)
r = fusion_historique([crime_client, expiree], [crime_client], MAINTENANT)
controle("B10. trace serveur expiree : purge acceptee, pas de reinjection",
         not any(c.get('id') == 'trace-S' for c in r))

# B11 — chemin client LEGITIME : un crime client decouvert est retire -> il ne revient PAS
r = fusion_historique([crime_client], [], MAINTENANT)
controle("B11. retrait legitime d'un crime client (decouverte) : definitif",
         r == [], 'aucune resurrection -> pas d\'arrestation perpetuelle')

# B12 — chemin client LEGITIME : ajout d'un crime client
nouveau = {'acte': 'incendier', 'cible': 'B', 'jour': 5, 'expireJour': 13}
r = fusion_historique([crime_client], [crime_client, nouveau], MAINTENANT)
controle("B12. un crime cree cote client est bien enregistre", nouveau in r and len(r) == 2)

# B13 — garde-fou : une trace serveur SANS id n'est pas protegee (d'ou l'exigence A13)
sans_id = {'origine': 'serveur', 'acte': 'transaction_interdite', 'expireTs': FUTUR}
r = fusion_historique([sans_id], [], MAINTENANT)
controle("B13. trace serveur sans id non protegee -> tout ecrivain serveur DOIT poser un id",
         r == [], 'exigence verifiee par A13 pour la seule RPC concernee')


print("")
print("=" * 100)
print("C. CONTROLES DES ECRIVAINS JS")
print("=" * 100)

SUPABASE = lire('supabase.js')
TOUS_JS = {f: lire(f) for f in [
    'plateau-assemblee.js', 'plateau-actions-illegales-rumeurs.js', 'plateau-justice-economie.js',
    'plateau-navigation.js', 'plateau-politique.js', 'plateau-core.js', 'plateau-personnage.js',
    'plateau-communication.js', 'plateau-pnj.js', 'plateau-organisations-quetes.js',
    'plateau-multijoueur.js', 'plateau-divers.js', 'plateau-gouvernement.js', 'supabase.js']}
CRON = lire('api/cron-minuit.js')
CRON_ASS = lire('api/cron-assemblee.js')

# C1 — pas de regression : la sauvegarde ordinaire ecrit toujours ces colonnes
save = SUPABASE[SUPABASE.find('async function sbSavePersonnage'):]
save = save[:save.find('\n}\n')]
controle("C1. sbSavePersonnage ecrit toujours convocations et historique_crimes",
         'convocations:' in save and 'historique_crimes:' in save,
         'aucune regression sur les ~15 ecritures client legitimes')

# C2 — seul le serveur peut poser 'echue'
pose_echue = []
for f, src in TOUS_JS.items():
    code = sans_commentaires_js(src)
    if re.search(r'\.echue\s*=\s*true|echue:\s*true', code):
        pose_echue.append(f)
controle("C2. aucun chemin client ne pose le verdict 'echue'", not pose_echue,
         ('pose par : ' + ', '.join(pose_echue)) if pose_echue else 'reserve a la RPC serveur')

# C3 — invariant APPEND-ONLY des convocations, sur lequel repose la reinjection
suppr = []
for f, src in TOUS_JS.items():
    code = sans_commentaires_js(src)
    if re.search(r'convocations\s*\.\s*(splice|pop|shift)\s*\(', code) \
       or re.search(r'convocations\s*=\s*[^;]*\.filter\(', code):
        suppr.append(f)
        continue
    # Une remise a [] n'est un retrait que si elle est INCONDITIONNELLE. La forme gardee
    # `if (!state.convocations) state.convocations = [];` n'initialise qu'un tableau ABSENT : il n'y
    # a rien a retirer. La premiere version de ce controle la comptait a tort comme un retrait
    # (4 faux positifs : navigation, justice, assemblee, actions-illegales).
    for ligne in code.split('\n'):
        if re.search(r'convocations\s*=\s*\[\s*\]\s*;', ligne) and 'if (!' not in ligne:
            suppr.append(f)
            break
controle("C3. aucun chemin client ne retire une convocation (append-only)", not suppr,
         ('retrait dans : ' + ', '.join(suppr)) if suppr else 'invariant de la reinjection verifie')

# C4 — les deux chemins client qui RETIRENT des crimes respectent les traces serveur
just = TOUS_JS['plateau-justice-economie.js']
decouv = just[just.find('function verifierDecouverteCrimesPasses'):]
decouv = decouv[:decouv.find('\n}\n')]
controle("C4. decouverte differee : exclut les traces serveur",
         "c.origine !== 'serveur'" in sans_commentaires_js(decouv))

ill = TOUS_JS['plateau-actions-illegales-rumeurs.js']
eff = ill[ill.find('function checkEffacementCrimes'):]
eff = eff[:eff.find('\n}\n')]
controle("C5. purge des crimes expires : respecte expireTs des traces serveur",
         'c.expireTs ?' in sans_commentaires_js(eff))

# C6 — le cron n'ecrit plus est_emprisonne (le bug du jourFin manquant)
cron_code = sans_commentaires_js(CRON)
bloc_conv = cron_code[cron_code.find('assemblee_marquer_convocations_echues'):]
bloc_conv = bloc_conv[:800]
controle("C6. le cron ne pose plus est_emprisonne sans jourFin",
         'est_emprisonne' not in bloc_conv and "sbRpc('assemblee_marquer_convocations_echues'" in cron_code)

# C7 — aucun nouveau chemin client d'ecriture DIRECTE des colonnes judiciaires d'un tiers
directs = []
for f, src in TOUS_JS.items():
    code = sans_commentaires_js(src)
    for m in re.finditer(r"sbUpdate\(\s*'personnages'[^;]*?\{([^}]*)\}", code, re.S):
        if 'convocations' in m.group(1) or 'historique_crimes' in m.group(1):
            directs.append(f)
# Un seul preexistant, connu et documente : le controle de fret (plateau-justice-economie.js).
controle("C7. ecriture directe client des colonnes judiciaires : seul le preexistant",
         directs == ['plateau-justice-economie.js'],
         'trouve(s) : %s (le controle de fret, preexistant, desormais protege par le trigger)'
         % (directs or 'aucun'))

# C8 — la trace vendeur n'est ecrite QUE par la fonction serveur interne : aucun client ne l'invoque
# (contrat du 11 septembre 2026) ni n'ecrit chez le vendeur par sbUpdate (C7 ci-dessus).
controle("C8. trace vendeur : fonction serveur interne, aucune invocation client",
         not any(re.search(r"sbRpc\(\s*'assemblee_tracer_vente_interdite'|sbAssembleeTracerVenteInterdite\(",
                           sans_commentaires_js(src)) for src in TOUS_JS.values()))

# C9 — toutes les convocations creees cote client portent un id
sites = []
sans_id = []
for f, src in TOUS_JS.items():
    code = sans_commentaires_js(src)
    for m in re.finditer(r"(?:convocations\.push\(\{|const nouvelleConvocation = \{)(.{0,400})", code, re.S):
        sites.append(f)
        if not re.search(r"\bid\s*:", m.group(1)):
            sans_id.append(f)
controle("C9. chaque convocation creee cote client porte un id stable",
         bool(sites) and not sans_id,
         '%d site(s) de creation, %d sans id' % (len(sites), len(sans_id)))

# C10 — le verdict serveur est bien honore cote client
ass = sans_commentaires_js(TOUS_JS['plateau-assemblee.js'])
controle("C10. le client honore le verdict serveur 'echue'",
         'if (c.echue === true) return true;' in ass)

# C11 — une justification tardive ne permet plus d'echapper a la non-presentation
conf = just[just.find('async function confirmerSeJustifier'):]
conf = sans_commentaires_js(conf[:conf.find('\n}\n')])
garde_avant_debit = conf.find('assembleeConvocationEchue(convocation)') < conf.find('deduireCoutOrdre')
controle("C11. justification apres echeance : refusee AVANT tout debit",
         'assembleeConvocationEchue(convocation)' in conf and garde_avant_debit,
         'renvoi vers la non-presentation, aucun PA facture')


print("")
echecs = sum(1 for r in resultats if not r)
print("%d controle(s), %d echec(s)" % (len(resultats), echecs))
sys.exit(1 if echecs else 0)
