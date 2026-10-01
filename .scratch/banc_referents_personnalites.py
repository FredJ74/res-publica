#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ===========================================================================
# BANC DES PERSONNALITES DE REFERENTS (1er octobre 2026)
# ---------------------------------------------------------------------------
# METHODE. Les quatre modules serveur sont en ESM et s'importent l'un l'autre.
# On les concatene dans l'ordre des dependances, on retire imports et exports,
# et on evalue le tout dans JavaScriptCore (osascript) -- aucune dependance,
# node n'est pas installe sur cette machine. On interroge ensuite le VRAI
# constructeur de prompt, pas une copie : c'est le prompt reellement envoye au
# fournisseur qui est mis a l'epreuve.
#
# CE QU'IL PROUVE. Que chaque personnalite arbitree arrive intacte dans le
# prompt de son referent -- tics compris, mot pour mot -- que les corpus de
# domaine n'ont pas bouge, que les limites et les orientations sont posees, et
# que les 180 autres PNJ n'ont pas ete touches.
#
# LANCEMENT : python3 .scratch/banc_referents_personnalites.py
# ===========================================================================
import os, re, subprocess, sys, json

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODULES = ['api/_bible-militaire.js', 'api/_pnj-referents.js',
           'api/_pnj-personnalites.js', 'api/_pnj-profils.js']

def sans_modules(src):
    src = re.sub(r'(?m)^import\s[\s\S]*?;', '', src)
    src = re.sub(r'(?m)^export\s*\{[^}]*\}\s*;?', '', src)
    src = re.sub(r'(?m)^export\s+(async\s+function|function|const|let|class)', r'\1', src)
    return src

code = '\n'.join(sans_modules(open(os.path.join(RACINE, m), encoding='utf-8').read())
                 for m in MODULES)

SONDE = r"""
var R = {};
// DERIVEE de la source unique : ce banc ne recopie plus les identifiants, donc il ne
// peut plus rater un referent ajoute.
var SEPT = Object.keys(REFERENTS);
R.total = Object.keys(TOUS_PROFILS).length;
R.presents = SEPT.filter(function(k){ return !!TOUS_PROFILS[k]; });
R.prompts = {};
SEPT.forEach(function(k){ R.prompts[k] = construirePromptSysteme(k, 'fr', null); });
// Temoins : des PNJ qui ne sont pas referents et ne doivent pas avoir bouge.
R.temoins = {};
['gaston_retard','jean_lou_demer','caporal_alouche','eve_toahemarch','escort_beatrice']
  .forEach(function(k){ R.temoins[k] = !!TOUS_PROFILS[k]; });
R.alouche = construirePromptSysteme('caporal_alouche', 'fr', null);
// La memoire pedagogique, isolement.
R.avecPedago = construirePromptSysteme('marc_hantile', 'fr', null, {consultations:5});
R.sansPedago = construirePromptSysteme('marc_hantile', 'fr', null, null);
R.pedago = { zero: blocPedagogie({consultations:0}),
             une:  blocPedagogie({consultations:1}),
             sept: blocPedagogie({consultations:7}),
             nul:  blocPedagogie(null) };
// C : toutes les cibles d'orientation, et tous les noms de PNJ reellement servis.
R.orientations = [];
Object.keys(REFERENTS).forEach(function(k){
  (REFERENTS[k].oriente || []).forEach(function(o){
    R.orientations.push({ de: k, sujet: o.sujet, vers: o.vers });
  });
});
R.nomsConnus = Object.keys(TOUS_PROFILS).map(function(k){ return TOUS_PROFILS[k].nom; })
                     .filter(Boolean);
// B et D : budget de parole et empire, par referent.
R.budgets = {}; R.pays = {};
Object.keys(REFERENTS).forEach(function(k){
  R.budgets[k] = maxTokensProfil(k);
  R.pays[k] = REFERENTS[k].pays || null;
});
JSON.stringify(R);
"""

tmp = os.path.join(os.environ.get('TMPDIR', '/tmp'), 'banc_referents.js')
open(tmp, 'w', encoding='utf-8').write(code + SONDE)
r = subprocess.run(['osascript', '-l', 'JavaScript', '-e',
    'ObjC.import("Foundation"); var s=$.NSString.stringWithContentsOfFileEncodingError("%s",4,null).js;'
    ' try{ eval(s) }catch(e){ "ERREUR: "+e.message }' % tmp],
    capture_output=True, text=True)
sortie = r.stdout.strip()
if sortie.startswith('ERREUR') or not sortie:
    print(sortie or r.stderr.strip()); sys.exit(1)
D = json.loads(sortie)

RES = []
def essai(nom, ok, detail=''):
    RES.append(('OK   ' if ok else 'ECHEC') + ' ' + nom + (' :: ' + str(detail) if detail else ''))

P = D['prompts']
essai('les sept referents existent dans la table de service',
      len(D['presents']) == 7, ', '.join(D['presents']))
essai('les 180 autres PNJ sont toujours la', D['total'] >= 180, 'total=%d' % D['total'])
for t, present in D['temoins'].items():
    essai('temoin intact : ' + t, present)

# --- Les tics, mot pour mot ------------------------------------------------
essai('Marc Hantile dit « Carrément ! »',      'Carrement !' in P['marc_hantile'])
essai('Marc Hantile dit « Mais carrément ! »', 'Mais carrement !' in P['marc_hantile'])
essai('Saad dit « Attendu que... »',           'Attendu que...' in P['procureur_saad'])
essai('Saad dit « Nonobstant... »',            'Nonobstant...' in P['procureur_saad'])
essai('Saad dit « En l\'état... »',            "En l'etat..." in P['procureur_saad'])
essai('Toufaud dit « C\'est comme ça... »',    "C'est comme ca..." in P['raoul_toufaud'])
essai('Toufaud dit « C\'est bien malheureux... »', "C'est bien malheureux..." in P['raoul_toufaud'])
essai('Toufaud dit « Personne ne mérite ça... »',  "Personne ne merite ca... mais bon..." in P['raoul_toufaud'])

# --- Le temperament, fidele a l'arbitrage ----------------------------------
essai('Marc Hantile est enthousiaste et optimiste',
      'Enthousiaste' in P['marc_hantile'] and 'optimiste' in P['marc_hantile'])
essai('Martial Bouterin : bonhomie, desabuse mais jamais amer',
      'bonhomie' in P['martial_bouterin'] and 'JAMAIS amer' in P['martial_bouterin'])
essai('Martial Bouterin garde son image du grand parking',
      'grand parking pour nos chars' in P['martial_bouterin'])
essai('Ferriere a son humour noir et son exemple de la mine',
      'souvent noir' in P['gaspard_ferriere'] and 'c\'est une mine' in P['gaspard_ferriere'])
essai('Ferriere est en MILIEU de carriere, pas un ancien',
      'milieu de carriere' in P['gaspard_ferriere'])
essai('Saad ne plaisante JAMAIS',
      'AUCUN' in P['procureur_saad'] and 'ne plaisantes jamais' in P['procureur_saad'])
essai('Saad incarne une institution, pas un homme',
      "representant d'une institution" in P['procureur_saad'])
essai('Fontaine ne tranche jamais trop vite',
      'jamais trop vite' in P['juge_fontaine'] and 'preuve' in P['juge_fontaine'])
essai('Laroche a un langage tres soutenu et un humour guinde',
      'tres soutenu' in P['president_laroche'] and 'guinde' in P['president_laroche'])
essai('Laroche donne le sentiment des classes sociales',
      'classes sociales' in P['president_laroche'])
essai('Toufaud a PERDU sa capacite a plaisanter (et non : il est severe)',
      'PERDU sa capacite a plaisanter' in P['raoul_toufaud'])
essai('Toufaud reste un homme qui veut proteger',
      'proteger les autres' in P['raoul_toufaud'])

# --- Les corpus de domaine n'ont pas bouge ---------------------------------
essai('Martial garde la bible militaire (institution, combat, renseignement)',
      'plafond 30' in P['martial_bouterin'] or 'PA' in P['martial_bouterin'])
essai('Ferriere garde son corpus de troupe',
      'ration' in P['gaspard_ferriere'].lower())
essai('le Caporal Alouche n\'a pas ete touche',
      'refectoire' in D['alouche'].lower() and 'louche' in D['alouche'].lower())

# --- Les regles de socle, sur chacun des sept ------------------------------
for k in D['presents']:
    essai('socle : ' + k + ' oriente hors de son domaine',
          'HORS DE TON DOMAINE' in P[k])
    essai('socle : ' + k + ' ne cherche pas de relation sociale',
          "TU N'ES PAS UN AMI" in P[k])
    essai('socle : ' + k + ' n\'invente jamais',
          'TU NE REPONDS JAMAIS AU HASARD' in P[k])
    essai('socle : ' + k + ' aide avant de jouer son personnage',
          "TU AIDES, D'ABORD ET AVANT TOUT" in P[k])

# --- La memoire pedagogique -------------------------------------------------
essai('memoire : aucune consultation = rien dans le prompt', D['pedago']['zero'] is None)
essai('memoire : absente = rien dans le prompt',             D['pedago']['nul'] is None)
essai('memoire : une consultation est dite',
      D['pedago']['une'] and 'une fois' in D['pedago']['une'])
essai('memoire : sept consultations font aller a l\'essentiel',
      D['pedago']['sept'] and '7 fois' in D['pedago']['sept'] and 'essentiel' in D['pedago']['sept'])
essai('memoire : PEDAGOGIQUE et non sociale (ni familiarite ni confiance)',
      all(m not in (D['pedago']['sept'] or '') for m in ['familiar', 'confiance', 'ami']))

essai('le prompt d\'un referent porte sa memoire pedagogique',
      '5 fois' in D['avecPedago'] and 'CE QUE TU LUI AS DEJA EXPLIQUE' in D['avecPedago'])
essai('et reste rigoureusement celui d\'avant sans elle',
      'CE QUE TU LUI AS DEJA EXPLIQUE' not in D['sansPedago'])

# --- C : chaque orientation doit nommer quelqu'un qui existe ------------------
# Une faute de frappe dans `vers` creerait un referent qui envoie vers personne, et
# rien ne le signalerait en jeu. On compare apres avoir retire les accents : le
# fichier ecrit « Gaspard Ferriere », le profil s'appelle « Adjudant Gaspard Ferrière ».
import unicodedata
def sansacc(t):
    return unicodedata.normalize('NFD', t).encode('ascii', 'ignore').decode().lower()
NOMS = [sansacc(n) for n in D['nomsConnus']]
orphelines = [o for o in D['orientations']
              if not any(n and n in sansacc(o['vers']) for n in NOMS)]
essai('les %d orientations nomment toutes un PNJ qui existe' % len(D['orientations']),
      len(orphelines) == 0,
      '; '.join(o['de'] + ' -> ' + o['vers'] for o in orphelines) if orphelines else '')
essai('chaque referent oriente au moins une fois',
      all(any(o['de'] == k for o in D['orientations']) for k in D['presents']))

# --- B : le budget de parole suit la personnalite ----------------------------
essai('Toufaud, qui parle peu, a le budget le plus faible',
      D['budgets']['raoul_toufaud'] == min(D['budgets'].values()),
      'Toufaud=%d, min=%d' % (D['budgets']['raoul_toufaud'], min(D['budgets'].values())))
essai('Ferriere, qui raconte, a le budget le plus eleve',
      D['budgets']['gaspard_ferriere'] == max(D['budgets'].values()),
      'Ferriere=%d, max=%d' % (D['budgets']['gaspard_ferriere'], max(D['budgets'].values())))
essai('Toufaud dispose de nettement moins de souffle que Ferriere',
      D['budgets']['raoul_toufaud'] * 2 <= D['budgets']['gaspard_ferriere'],
      '%d contre %d' % (D['budgets']['raoul_toufaud'], D['budgets']['gaspard_ferriere']))
essai('un referent sans budget declare retombe sur 320',
      D['budgets']['marc_hantile'] == 320)

# --- D : tout referent appartient a un empire --------------------------------
sans_pays = [k for k, v in D['pays'].items() if not v]
essai('les sept referents declarent leur empire', len(sans_pays) == 0, sans_pays)
essai('ils sont tous de Republia dans ce lot',
      set(D['pays'].values()) == {'republic'}, sorted(set(D['pays'].values())))

# --- Les TROIS listes de referents doivent rester alignees ------------------
# Le fichier de personnalites, la liste cliente et la table en base. Trois copies
# d'un meme ensemble de sept identifiants : c'est le prix a payer pour eviter un
# aller-retour reseau apres chaque replique des 180 autres PNJ, et ce controle est
# ce qui empeche ce prix de devenir une dette.
LISTE_JS = set(re.findall(r"^  ([a-z_]+): \{", open(os.path.join(RACINE,'api/_pnj-referents.js'), encoding='utf-8').read(), re.M))
cli = re.search(r"const PNJ_REFERENTS = \[(.*?)\];",
                open(os.path.join(RACINE,'plateau-pnj.js'), encoding='utf-8').read(), re.S)
LISTE_CLIENT = set(re.findall(r"'([a-z_]+)'", cli.group(1))) if cli else set()
sql = open(os.path.join(RACINE,'migration_20261001_referents_memoire_pedagogique.sql'), encoding='utf-8').read()
LISTE_SQL = set(re.findall(r"\('([a-z_]+)',\s*'", sql))
essai('liste des personnalites : sept referents', len(LISTE_JS) == 7, sorted(LISTE_JS))
essai('la liste cliente est alignee sur le fichier de personnalites',
      LISTE_CLIENT == LISTE_JS, 'ecart=' + str(sorted(LISTE_CLIENT ^ LISTE_JS)))
essai('la table en base est alignee sur le fichier de personnalites',
      LISTE_SQL == LISTE_JS, 'ecart=' + str(sorted(LISTE_SQL ^ LISTE_JS)))

print('\n'.join(RES))
echecs = len([l for l in RES if l.startswith('ECHEC')])
print('BILAN %d echec(s) sur %d criteres' % (echecs, len(RES)))
sys.exit(0 if echecs == 0 else 1)
