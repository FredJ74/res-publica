#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DU LOT DE CORRECTIFS TECHNIQUES (1er octobre 2026)

Trois anomalies constatees par le diagnostic de Republia, trois corrections, et des
gardes pour qu'aucune ne revienne. Ce banc ne verifie QUE ce lot ; il ne remplace pas
les bancs de famille, qui sont rejoues a cote.

  A  LE NOM DE L'ORDRE EST TRANSMIS AU SERVEUR. payer_ordre valide le couple
     (pa, cost) contre le miroir et a besoin de savoir quel ordre il facture. Les
     voyages facturent apres une modale, donc hors du passage de doOrder qui depose
     state._ordreEnCours -- et le bouton taxi de la Caserne/du QHS n'y passe meme pas.
     Le nom est desormais une propriete du mode, passee explicitement via l'option `fn`.
     La garde porte sur les deux points de facturation, pas sur le bouton : c'est la
     facturation qui etait fautive.

  B  LA CLE DU PERE ISCOPE. Elle avait ete calculee sur une chaine dont l'echappement
     unicode etait double, donc jamais interprete. La garde verifie qu'aucun
     echappement ne revient dans ce fichier -- les 180 autres entrees ecrivent leurs
     accents en clair, et c'est la seule convention qui ne peut pas produire ce defaut.

  C  LES DEUX MAGISTRATS DU TRIBUNAL. Verifie cote donnees ici ; la resolution reelle,
     elle, est verifiee dans un vrai navigateur par banc_lot_correctifs_client.html,
     parce qu'elle depend d'une fonction du jeu qu'on ne reimplemente pas.

  D  GARDE CONTRE LA SUR-CORRECTION. Onze autres personnes du gabarit sont masquees en
     Republia par le meme mecanisme, et ce masquage est VOULU : chaque empire remplace
     le personnel generique par son propre casting. Ce banc verifie qu'elles sont
     restees masquees -- une correction qui les ferait toutes revenir serait une
     regression de game design, pas un correctif.
"""
import os, re, sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lire = lambda n: open(os.path.join(RACINE, n), encoding='utf-8').read()

NAV   = lire('plateau-navigation.js')
DATA  = lire('data.js')
PERSO = lire('api/_pnj-personnalites.js')

res = []
def garde(cle, libelle, ok, detail=''):
    res.append((cle, libelle, bool(ok), '' if detail == '' else str(detail)))

def corps_fonction(src, nom):
    m = re.search(r'(?:async\s+)?function\s+' + re.escape(nom) + r'\s*\([^)]*\)\s*\{', src)
    if not m: return None
    i = src.index('{', m.start()); prof = 0
    for j in range(i, len(src)):
        if src[j] == '{': prof += 1
        elif src[j] == '}':
            prof -= 1
            if prof == 0: return src[i:j + 1]
    return None

# ---------------------------------------------------------------------------
# A — le nom de l'ordre voyage avec le mode
# ---------------------------------------------------------------------------
ATTENDU = {'train': 'prendre_train', 'bus': 'prendre_bus_taxi',
           'avion': 'prendre_avion', 'bateau': 'prendre_bateau'}
m = re.search(r'const TRANSPORT_CONFIG\s*=\s*\{(.*?)\n\};', NAV, re.S)
garde('A1', 'TRANSPORT_CONFIG est trouve', bool(m))
if m:
    bloc = m.group(1)
    trouves = dict(re.findall(r"(\w+):\s*\{[^}]*?ordre:'([a-z_]+)'", bloc))
    garde('A2', 'les 4 modes portent le nom de leur ordre',
          trouves == ATTENDU, trouves)
    # Les tarifs ne doivent pas avoir bouge : le correctif ne touche pas au game design.
    tarifs = dict((k, (int(pa), int(co))) for k, pa, co in
                  re.findall(r"(\w+):\s*\{\s*pa:(\d+),\s*cost:(\d+)", bloc))
    garde('A3', 'les tarifs sont inchanges',
          tarifs == {'train': (2, 75), 'bus': (1, 150), 'avion': (2, 300), 'bateau': (5, 100)},
          tarifs)

for nom in ('executerVoyage', 'confirmerTransport'):
    c = corps_fonction(NAV, nom)
    garde('A4', '%s() existe' % nom, c is not None)
    if c:
        appels = re.findall(r'deduireCoutOrdre\(\s*\{([^}]*)\}', c)
        garde('A5', '%s() facture une seule fois' % nom, len(appels) == 1, appels)
        garde('A6', '%s() annonce le nom de l\'ordre' % nom,
              bool(appels) and 'fn: config.ordre' in appels[0], appels)

# Le bouton n'a PAS ete touche : le defaut etait au point de facturation. S'il avait ete
# "corrige" en lui ajoutant un doOrder, les quatre ordres routes auraient compte deux fois.
garde('A7', 'le bouton taxi appelle toujours directement la modale',
      "ouvrirModalTransport(\\'bus\\')" in NAV or "ouvrirModalTransport('bus')" in NAV)

# ---------------------------------------------------------------------------
# B — la cle du Pere Iscope
# ---------------------------------------------------------------------------
# PIEGE DE BANC, paye deux fois dans ce depot : chercher dans le fichier ENTIER echoue
# toujours, parce que le commentaire qui documente le correctif cite forcement l'ancienne
# cle et l'echappement fautif. Les gardes lisent donc le CODE seul.
PERSO_CODE = '\n'.join(l for l in PERSO.split('\n') if not l.strip().startswith('//'))
garde('B1', "plus aucun echappement unicode dans le code",
      'u00' not in PERSO_CODE,
      re.findall(r'.{0,40}u00.{0,40}', PERSO_CODE)[:2])
garde('B2', "l'ancienne cle a disparu du code", "'p_u00e8re_iscope'" not in PERSO_CODE)
garde('B3', "la cle attendue existe, une seule fois",
      PERSO.count("'pere_iscope':") == 1, PERSO.count("'pere_iscope':"))
m = re.search(r"'pere_iscope':\s*\{\s*nom:\s*\"([^\"]+)\",\s*role:\s*\"([^\"]+)\"", PERSO)
garde('B4', 'son nom et son role sont ecrits en clair',
      bool(m) and m.group(1) == 'Père Iscope' and m.group(2) == 'Prêtre de Port-Sainte-Marie',
      m.groups() if m else 'introuvable')
# Le slug du client est reproduit ici ; le vrai calcul est verifie dans le banc navigateur.
def slug(nom):
    import unicodedata
    s = unicodedata.normalize('NFD', str(nom or ''))
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    return re.sub(r'^_+|_+$', '', re.sub(r'[^a-z0-9]+', '_', s.lower()))
garde('B5', "le slug de « Père Iscope » tombe sur la cle",
      slug('Père Iscope') == 'pere_iscope', slug('Père Iscope'))
# Aucune cle en double DANS SA PROPRE TABLE. Ce fichier en porte quatre (ORDINAIRES,
# RICHES, SOCIAUX, ESCORTS_REPUBLIA), et cinq identifiants figurent legitimement dans deux
# d'entre elles : une fiche riche enrichit une fiche ordinaire, et l'assembleur les fusionne
# dans cet ordre. Compter les cles du fichier entier rendrait donc toujours un faux echec.
# Les tables ne se ferment pas toutes par un `};` en colonne 0 : on les delimite par le
# marqueur suivant de meme niveau, seule borne fiable ici.
bornes = [(m.group(1), m.end()) for m in re.finditer(r'^const (\w+)\s*=\s*\{', PERSO_CODE, re.M)]
segments = {}
for i, (nom_t, deb) in enumerate(bornes):
    fin = bornes[i + 1][1] if i + 1 < len(bornes) else len(PERSO_CODE)
    segments[nom_t] = PERSO_CODE[deb:fin]
for table in ('ORDINAIRES', 'RICHES', 'SOCIAUX', 'ESCORTS_REPUBLIA'):
    seg = segments.get(table)
    if seg is None:
        garde('B6', 'la table %s est trouvee' % table, False); continue
    k = re.findall(r"^  '([a-z0-9_]+)':", seg, re.M)
    garde('B6', 'aucune cle en double dans %s' % table, len(k) == len(set(k)),
          [x for x in set(k) if k.count(x) > 1])

# ---------------------------------------------------------------------------
# C / D — les magistrats, et ceux qui doivent rester masques
# ---------------------------------------------------------------------------
m = re.search(r"'tribunal':\s*\{\s*\n\s*name:\s*\"Tribunal de Luthecia\".*?persons:\s*\[(.*?)\]\s*\n\s*\},",
              DATA, re.S)
garde('C1', 'la surcharge du tribunal de Luthecia est trouvee', bool(m))
if m:
    noms = re.findall(r'"name":\s*"([^"]+)"', m.group(1))
    garde('C2', 'les quatre personnes y figurent',
          noms == ['Honoré Cozetoujours (PNJ)', 'Maître Plaidoyer (PNJ)',
                   'Juge Fontaine', 'Procureur Saad'], noms)
    garde('C3', 'les deux personnages locaux restent en tete',
          noms[:2] == ['Honoré Cozetoujours (PNJ)', 'Maître Plaidoyer (PNJ)'])

# Le gabarit ne doit pas avoir ete touche : la correction est locale a Republia.
garde('C4', 'le gabarit declare toujours les deux magistrats',
      "{name:'Juge Fontaine'" in DATA and "{name:'Procureur Saad'" in DATA)

# D — personnel generique dont le masquage est VOULU. Aucun ne doit avoir ete ajoute a
# une surcharge : leur remplacement par le casting de Republia est la regle de socle.
VOULU = ['M. Fischer', 'Dr. Vidal', 'Professeur Blanc', 'Infirmiere Dupre',
         'Fernande (Marchande)', 'Marcel', 'Yvonne',
         'Nadège Standard (PNJ)', 'Camille Édito (PNJ)', 'Gustave Rotative (PNJ)']
for n in VOULU:
    # present dans le gabarit (notation JS), absent de toute surcharge (notation JSON)
    dans_gabarit  = ("{name:'%s'" % n) in DATA
    dans_surcharge = ('"name": "%s"' % n) in DATA
    garde('D1', 'le masquage voulu de « %s » est conserve' % n,
          dans_gabarit and not dans_surcharge,
          'gabarit=%s surcharge=%s' % (dans_gabarit, dans_surcharge))

# ---------------------------------------------------------------------------
larg = max(len(l) for _, l, _, _ in res)
ech = 0
print('=' * (larg + 20))
print('BANC DU LOT DE CORRECTIFS'.center(larg + 20))
print('=' * (larg + 20))
for cle, lib, ok, det in res:
    if not ok: ech += 1
    print('%-4s %-*s %s%s' % (cle, larg, lib, 'OK' if ok else 'ECHEC',
                              ('   ' + det) if det and not ok else ''))
print('-' * (larg + 20))
print('%d gardes, %d echec(s)' % (len(res), ech))
sys.exit(1 if ech else 0)
