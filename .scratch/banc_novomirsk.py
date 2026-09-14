# BANC NOVOMIRSK — navigation rue par rue de la capitale de Sovarka (chantier du 15 septembre 2026).
#
# Ne touche AUCUNE donnee de production : le banc charge les vrais fichiers data.js et
# plateau-rue-centrale.js dans JavaScriptCore et n'inspecte que des structures en memoire.
#
# Le graphe et la liste des hotspots ci-dessous sont RECOPIES DU BRIEF, pas relus du code :
# c'est ce qui permet au banc de detecter une erreur de saisie dans plateau-rue-centrale.js.

import json, os, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'

# ---------------------------------------------------------------- reference (brief)
HAUT, BAS, GAUCHE, DROITE = 'toutDroit', 'arriere', 'gauche', 'droite'

GRAPHE = {
    1:  {BAS: 2,  GAUCHE: 10, DROITE: 11},
    2:  {HAUT: 1, BAS: 3},
    3:  {HAUT: 2, BAS: 4},
    4:  {GAUCHE: 5, DROITE: 15},
    5:  {DROITE: 4, HAUT: 6},
    6:  {BAS: 5, HAUT: 7},
    7:  {BAS: 6, GAUCHE: 18, DROITE: 8},
    8:  {DROITE: 7, HAUT: 9},
    9:  {BAS: 8, DROITE: 10},
    10: {HAUT: 9, BAS: 1},
    11: {BAS: 1, HAUT: 12},
    12: {BAS: 11, DROITE: 13},
    13: {DROITE: 12, HAUT: 14},
    14: {BAS: 13, DROITE: 15, HAUT: 16},
    15: {BAS: 4, GAUCHE: 14, DROITE: 16},
    16: {BAS: 14, HAUT: 17},
    17: {BAS: 16, HAUT: 18},
    18: {BAS: 17, HAUT: 7},
}

# Flèches prevues au cadrage mais dont la destination n'a jamais ete definie : doivent etre ABSENTES.
FLECHES_NON_RESOLUES = [(4, BAS), (5, BAS), (8, BAS)]

# nom du hotspot -> buildingId attendu, ou None si le batiment n'est pas encore developpe.
HOTSPOTS = {
    1:  {'Librairie du Peuple': None,
         'Palais du Gouvernement de Sovarka': 'palais-gouvernement'},
    2:  {'Restaurant La Mère Volga': None,
         'Musée municipal de Novomirsk': None},
    3:  {'Office notarial de Sovarka': 'office-notarial',
         'Commissariat de Novomirsk': 'commissariat'},
    4:  {'Grand Hôtel de Sovarka': 'hotel-republica',
         'Galeries de Novomirsk': 'centre-commercial'},
    5:  {"Centre d'affaires de Novomirsk": 'centre-affaires',
         'Grand Hôtel de Sovarka': 'hotel-republica'},
    6:  {'Palais des Ambassades': None,
         'Armurerie de Novomirsk': 'armurerie'},
    7:  {'Pavillon des Ambassadeurs': None,
         'Grande Église du Tractorisme': 'kolkhoze-spirituel',
         'Résidence impériale': None},
    8:  {'Entrepôt logistique de Novomirsk': None,
         'Direction du Renseignement de Sovarka': None},
    9:  {'Centre multimodal de Novomirsk': 'centre-multinodal-luthecia'},
    10: {'Tribunal de Novomirsk': 'tribunal'},
    11: {'Caserne centrale de Novomirsk': None,
         'Garage de Novomirsk': None},
    12: {'Caserne centrale de Novomirsk': None,
         'Salon de coiffure de Novomirsk': None},
    13: {'Agence officielle de presse / Imprimerie officielle de Sovarka': 'la-tribune'},
    14: {'Logements': None,
         'Pharmacie officielle de Novomirsk': None},
    15: {'Clinique privée Saint-Pavel': 'clinique-privee',
         'Hôpital public de Novomirsk': 'dispensaire-public'},
    16: {'Marchande de poissons': None,
         'Marché de Novomirsk': 'marche'},
    17: {'Stade du Dynamo de Novomirsk': 'stade',
         'Centre artisanal de Novomirsk': 'centre-artisanal'},
    18: {'Usine pharmaceutique Pharmanov': None,
         'Musée de la République de Sovarka': None},
}

ACCUEIL_MULTIMODAL = 'images/accueil-centre-multimodal-novomirsk.png'

# ---------------------------------------------------------------- extraction reelle
EXTRACTION = r"""
load('%(racine)s/data.js');
load('%(racine)s/plateau-rue-centrale.js');

var sortie = {
  depart: RUE_CENTRALE_DEPART,
  soviet: RUE_CENTRALE_NOEUDS.soviet,
  republic: RUE_CENTRALE_NOEUDS.republic,
  buildingsNovomirsk: WORLD.soviet.capitale.buildings,
  batimentsConnus: Object.keys(BUILDINGS),
  imagesPieceSoviet: ROOM_IMAGES_EMPIRE.soviet['centre-multinodal-luthecia'],
  multimodal: {
    pieces: Object.keys(BUILDINGS['centre-multinodal-luthecia'].rooms),
    ordresHallGare: (BUILDINGS['centre-multinodal-luthecia'].rooms.hall_gare.orders || []).map(function (o) { return o.fn; })
  },
  // Verifie la primitive reellement utilisee a l'arrivee d'un voyage, pas une reimplementation.
  noeudArriveeMultimodal: trouverNoeudRueCentralePourBatiment('soviet', 'centre-multinodal-luthecia'),
  noeudArriveeHotel: trouverNoeudRueCentralePourBatiment('soviet', 'hotel-republica')
};
print(JSON.stringify(sortie));
"""

resultats = []


def verifier(nom, condition, detail=''):
    resultats.append((bool(condition), nom, detail))


def extraire():
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as f:
        f.write(EXTRACTION % {'racine': RACINE})
        chemin = f.name
    try:
        p = subprocess.run([JSC, chemin], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(chemin)
    if p.returncode != 0:
        print('ECHEC DE CHARGEMENT DES VRAIS FICHIERS JS :')
        print(p.stdout[-3000:])
        print(p.stderr[-3000:])
        sys.exit(1)
    return json.loads(p.stdout.strip().splitlines()[-1])


def cle(n):
    return 'novomirsk-vue-%d' % n


def main():
    d = extraire()
    soviet = d['soviet']
    batiments = set(d['batimentsConnus'])
    novomirsk = set(d['buildingsNovomirsk'])

    # ---- 1. les 18 vues
    attendues = [cle(n) for n in range(1, 19)]
    verifier('18 vues declarees, ni plus ni moins',
             sorted(soviet.keys()) == sorted(attendues),
             str(sorted(set(soviet.keys()) ^ set(attendues))))
    verifier("Novomirsk est bien le point de depart de la capitale de Sovarka",
             d['depart'].get('soviet', {}).get('capitale') == cle(1))

    # ---- 2. les images existent reellement sur disque
    for n in range(1, 19):
        img = soviet.get(cle(n), {}).get('image', '')
        chemin = os.path.join(RACINE, img)
        verifier('V%-2d image presente sur disque' % n,
                 img.startswith('images/') and os.path.isfile(chemin), img)
    verifier('image du nouvel accueil du Centre multimodal presente sur disque',
             os.path.isfile(os.path.join(RACINE, ACCUEIL_MULTIMODAL)))
    images = [soviet[cle(n)]['image'] for n in range(1, 19)]
    verifier('les 18 vues utilisent 18 images distinctes', len(set(images)) == 18)

    # ---- 3/4. le graphe
    for n, sorties in GRAPHE.items():
        liens = soviet.get(cle(n), {}).get('liens', {})
        poses = {k: v for k, v in liens.items() if v}
        verifier('V%-2d sorties exactement conformes au graphe valide' % n,
                 poses == {k: cle(v) for k, v in sorties.items()},
                 'obtenu=%s' % json.dumps(poses, ensure_ascii=False))
        for direction, dest in poses.items():
            verifier('V%-2d %s pointe vers une vue existante' % (n, direction), dest in soviet, dest)

    # ---- 5. les trois fleches volontairement absentes
    for n, direction in FLECHES_NON_RESOLUES:
        liens = soviet.get(cle(n), {}).get('liens', {})
        verifier('V%-2d fleche BAS volontairement absente (destination jamais definie)' % n,
                 not liens.get(direction))

    # ---- 6/7. hotspots : tous ceux demandes, et rien d'autre
    for n, attendu in HOTSPOTS.items():
        zones = soviet.get(cle(n), {}).get('zones', [])
        noms = [z['nom'] for z in zones]
        verifier('V%-2d hotspots exactement ceux demandes' % n,
                 sorted(noms) == sorted(attendu.keys()),
                 'obtenu=%s' % noms)
        for z in zones:
            cible = attendu.get(z['nom'], '(hotspot parasite)')
            if cible is None:
                verifier('V%-2d "%s" reste ferme (pas de faux interieur)' % (n, z['nom']),
                         z.get('type') == 'a-venir' and not z.get('buildingId'))
            else:
                verifier('V%-2d "%s" raccorde au batiment existant' % (n, z['nom']),
                         z.get('buildingId') == cible, 'obtenu=%s' % z.get('buildingId'))

    # ---- geometrie des zones
    for n in range(1, 19):
        for z in soviet.get(cle(n), {}).get('zones', []):
            x = z.get('xPct') or []
            y = z.get('yPct') or [0, 100]
            verifier('V%-2d "%s" zone dans les bornes de l\'image' % (n, z['nom']),
                     len(x) == 2 and 0 <= x[0] < x[1] <= 100 and 0 <= y[0] < y[1] <= 100,
                     'x=%s y=%s' % (x, y))

    # ---- 8. Grand Hotel : deux entrees, sortie canonique V4
    hotel = [(n, z) for n in range(1, 19) for z in soviet[cle(n)]['zones']
             if z.get('buildingId') == 'hotel-republica']
    verifier('Grand Hotel accessible depuis exactement V4 et V5',
             sorted(n for n, _ in hotel) == [4, 5], str([n for n, _ in hotel]))
    verifier('Grand Hotel : sortie canonique V4 depuis ses deux entrees',
             all(z.get('sortieNoeudId') == cle(4) for _, z in hotel))
    verifier("Grand Hotel : l'arrivee de voyage retombe sur V4",
             d['noeudArriveeHotel'] == cle(4), str(d['noeudArriveeHotel']))

    # ---- 9. Caserne : deux entrees, sortie canonique V12
    caserne = [(n, z) for n in range(1, 19) for z in soviet[cle(n)]['zones']
               if z['nom'] == 'Caserne centrale de Novomirsk']
    verifier('Caserne accessible depuis exactement V11 et V12',
             sorted(n for n, _ in caserne) == [11, 12], str([n for n, _ in caserne]))
    verifier('Caserne : sortie canonique V12 depuis ses deux entrees',
             all(z.get('sortieNoeudId') == cle(12) for _, z in caserne))

    # ---- 10. Presse / Imprimerie : une seule entree commune
    v13 = soviet[cle(13)]['zones']
    verifier('Presse et Imprimerie = UN SEUL hotspot commun sur V13', len(v13) == 1, str(len(v13)))

    # ---- 11/12/13. Centre multimodal
    v9 = soviet[cle(9)]['zones']
    verifier('Centre multimodal cliquable sur V9',
             len(v9) == 1 and v9[0].get('buildingId') == 'centre-multinodal-luthecia')
    verifier("arrivee de voyage repositionnee devant le Centre multimodal (V9)",
             d['noeudArriveeMultimodal'] == cle(9), str(d['noeudArriveeMultimodal']))
    verifier('nouvel accueil du Centre multimodal branche sur hall_gare',
             d['imagesPieceSoviet'].get('hall_gare') == ACCUEIL_MULTIMODAL,
             str(d['imagesPieceSoviet'].get('hall_gare')))
    verifier('Centre multimodal : ses 3 pieces existantes sont intactes',
             sorted(d['multimodal']['pieces']) == ['hall_douanes', 'hall_gare', 'zone_embarquement'],
             str(d['multimodal']['pieces']))
    for ordre in ['prendre_train', 'prendre_bus_taxi']:
        verifier("Centre multimodal : l'ordre %s est intact" % ordre,
                 ordre in d['multimodal']['ordresHallGare'])

    # ---- 14. la boucle V7 <-> V18
    verifier('boucle fermee V7 gauche -> V18',
             soviet[cle(7)]['liens'].get(GAUCHE) == cle(18))
    verifier('boucle fermee V18 haut -> V7',
             soviet[cle(18)]['liens'].get(HAUT) == cle(7))

    # ---- batiments raccordes : existants ET presents dans la ville
    for n in range(1, 19):
        for z in soviet[cle(n)]['zones']:
            b = z.get('buildingId')
            if b:
                verifier('V%-2d %s existe dans BUILDINGS' % (n, b), b in batiments)
                verifier('V%-2d %s appartient bien a Novomirsk' % (n, b), b in novomirsk)

    # ---- 15. non-regression de Republia
    rep = d['republic']
    verifier('Republia : 46 noeuds toujours presents', len(rep) == 46, str(len(rep)))
    verifier('Republia : points de depart inchanges',
             d['depart']['republic'] == {
                 'capitale': 'luthecia-palais-presidentiel', 'ville_a': 'psm-centre-multimodal',
                 'ville_b': 'montrouge-vue-3', 'caserne': 'caserne-exterieur', 'qhs': 'qhs-exterieur'})
    orphelins = [(k, dd, v) for k, nd in rep.items()
                 for dd, v in (nd.get('liens') or {}).items() if v and v not in rep]
    verifier('Republia : aucune fleche orpheline', not orphelins, str(orphelins[:4]))
    batOrphelins = [z.get('buildingId') for nd in rep.values() for z in (nd.get('zones') or [])
                    if z.get('type', 'batiment') == 'batiment' and z.get('buildingId') not in batiments]
    verifier('Republia : tous les batiments cliquables existent toujours',
             not batOrphelins, str(batOrphelins[:4]))
    verifier('Republia : aucun noeud ne s\'est vu ajouter un type a-venir',
             not [z for nd in rep.values() for z in (nd.get('zones') or []) if z.get('type') == 'a-venir'])

    # ---- responsive : la CSS de la rue n'a pas ete touchee
    diff = subprocess.run(['git', 'diff', '--name-only', 'HEAD', '--', 'rue-centrale.css'],
                          cwd=RACINE, capture_output=True, text=True).stdout.strip()
    verifier('responsive : rue-centrale.css non modifie', diff == '', diff)

    # ---------------------------------------------------------------- rapport
    ko = [r for r in resultats if not r[0]]
    for ok, nom, detail in resultats:
        if not ok:
            print('  KO  %s  %s' % (nom, detail))
    print('\n%d/%d' % (len(resultats) - len(ko), len(resultats)))
    return 1 if ko else 0


if __name__ == '__main__':
    sys.exit(main())
