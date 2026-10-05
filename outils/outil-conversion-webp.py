#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OUTIL DE CONVERSION WEBP — reutilisable pour tous les lots du chantier d'images.

    python3 outils/outil-conversion-webp.py mesurer                 # ne touche a rien
    python3 outils/outil-conversion-webp.py mesurer --top 20
    python3 outils/outil-conversion-webp.py convertir <fichier...>   # convertit et reecrit les references

DEUX FICHIERS D'ENTREE, VERSIONNES A COTE DE L'OUTIL :

  .scratch/image_batiments.json           quelle image appartient a quel batiment.
      A REGENERER si data.js change de structure (les surcharges de ville comprises).
      Sert uniquement a reconnaitre les images de musee, affichees sans recadrage.

  .scratch/references_base_de_donnees.txt les noms d'images citees DANS LA BASE.
      A REGENERER apres tout lot qui ecrit des URL d'images en base. Tant qu'un nom
      y figure, l'outil REFUSE de convertir l'image : la renommer casserait des
      lignes que le code ne controle pas.

POURQUOI UN OUTIL ET PAS UN SCRIPT PAR LOT. L'audit du 4 octobre 2026 a montre que
le probleme du depot n'est pas la resolution mais le FORMAT : 1,16 octet par pixel,
signature d'un PNG qui encode de la photo. Le gain tient donc entierement dans le
reencodage, et il y a plus de 600 images a traiter. Un outil unique, qui decide
seul, est la seule facon de ne pas finir avec six cents reglages manuels.

CE QUI EST GARANTI, ET VERIFIE APRES CHAQUE ECRITURE :
  - les DIMENSIONS sont identiques au pixel ;
  - la TRANSPARENCE est conservee (canal alpha preserve, jamais aplati) ;
  - aucun recadrage, aucun redimensionnement, aucune rotation ;
  - l'ORIGINAL est sauvegarde hors du depot avant toute suppression.

COMMENT LA QUALITE EST CHOISIE — AUCUN REGLAGE PAR FICHIER.
L'outil ne connait pas les noms de fichiers. Il monte une ECHELLE de qualite et
s'arrete au premier palier qui passe DEUX barrieres mesurees sur l'image elle-meme :

  1. l'erreur globale (PSNR sur l'image entiere) ;
  2. l'erreur du PIRE CARREAU d'une grille 6 x 4 : une moyenne flatteuse peut
     masquer une zone qui a fondu -- une enseigne, un cartel de musee.

Un seul critere vient de la DONNEE du jeu, et il est declaratif : les images d'un
batiment dont l'id commence par « musee- » (meme critere structurel que
plateau-navigation.js pour data-musee) sont affichees SANS RECADRAGE, parce
qu'aucun cartel ne doit etre coupe. Elles exigent donc un palier plus severe.

Une image sans perte reste sans perte : si aucun palier avec perte ne passe les
barrieres, l'outil ecrit du WebP SANS PERTE, et si meme celui-la est plus lourd
que l'original, il REFUSE de convertir et le dit.
"""
import io, json, os, re, shutil, subprocess, sys, math
from PIL import Image, ImageChops, ImageStat

Image.MAX_IMAGE_PIXELS = None
RACINE = os.path.dirname(os.path.abspath(__file__))
SAUVEGARDE = os.path.join(os.path.dirname(RACINE), 'ResPublica-originaux-images')
CARTE_BATIMENTS = os.path.join(RACINE, '.scratch', 'image_batiments.json')

# L'echelle de qualite. On s'arrete au premier palier qui passe : plus la qualite
# est basse, plus le fichier est leger, donc on essaie le plus leger d'abord.
ECHELLE = [82, 88, 94]

# LES DEUX BARRIERES, en decibels, calibrees sur des cas connus et non devinees.
#
# `global` est l'erreur sur l'image entiere. `pire` est l'erreur du plus mauvais
# carreau d'une grille 6 x 4 : une moyenne globale peut rester flatteuse alors
# qu'UNE zone -- une enseigne, un cartel -- a fondu. Le pire carreau attrape cela.
#
# Premiere version de cet outil : la seconde barriere portait sur la carte des
# CONTOURS. Mesure faite, elle ne discriminait rien -- un logo d'aplats et une
# scene photographique y obtiennent le meme score a qualite egale (24-26 dB a
# q82, 30 dB a q94). Elle ne mesurait que le palier de qualite, pas la nature de
# l'image, et aurait pousse tout le depot a q94 sans raison. Remplacee.
#
# Ce qui DISCRIMINE vraiment la nature d'une image, c'est son PLAFOND de PSNR :
# une photo monte de 33,9 a 37,1 dB entre q82 et q94, un logo d'aplats stagne a
# 29,9 -> 30,8 parce que le WebP avec perte ne sait pas representer un bord franc.
# L'echelle s'en sert sans le savoir : ce qui ne franchit jamais la barriere finit
# en SANS PERTE, et c'est exactement le bon traitement.
BARRIERES = {
    'normal': {'global': 36.0, 'pire': 33.0},
    'musee':  {'global': 38.0, 'pire': 35.0},
}

# Fichier liste des noms d'images citees DANS LA BASE DE DONNEES (donnees, corps de
# fonctions, vues). Les convertir changerait leur nom sans que la base le sache :
# l'outil REFUSE de les toucher. C'est le piege trouve au lot 2 -- 16 portraits
# d'agents dont le chemin est construit par concatenation dans une fonction SQL.
REFS_BASE = os.path.join(RACINE, '.scratch', 'references_base_de_donnees.txt')


def psnr(a, b):
    """Erreur entre deux images, calculee par Pillow (en C) et non pixel par pixel."""
    d = ImageChops.difference(a.convert('RGB'), b.convert('RGB'))
    rms = ImageStat.Stat(d).rms
    moy = sum(x * x for x in rms) / len(rms)
    if moy <= 0:
        return 99.0
    return 20 * math.log10(255.0 / math.sqrt(moy))


def psnr_pire_carreau(a, b, nx=6, ny=4):
    """Le plus mauvais carreau d'une grille : detecte une degradation LOCALE."""
    A, B = a.convert('RGB'), b.convert('RGB')
    W, H = A.size
    pire = 99.0
    for j in range(ny):
        for i in range(nx):
            boite = (i * W // nx, j * H // ny, (i + 1) * W // nx, (j + 1) * H // ny)
            pire = min(pire, psnr(A.crop(boite), B.crop(boite)))
    return pire


def citee_en_base(rel):
    try:
        noms = set(l.strip() for l in open(REFS_BASE, encoding='utf-8') if l.strip())
    except Exception:
        return False
    return os.path.basename(rel) in noms


def encoder(im, **kw):
    b = io.BytesIO()
    im.save(b, 'WEBP', method=4, **kw)
    return b.getvalue()


def a_de_la_transparence(im):
    """Un CANAL alpha est declare (ce qui ne veut pas dire qu'il sert a quelque chose)."""
    return im.mode in ('RGBA', 'LA') or (im.mode == 'P' and 'transparency' in im.info)


def transparence_reelle(im):
    """L'image est-elle VRAIMENT transparente quelque part ?

    LA DISTINCTION N'EST PAS UNE SUBTILITE, elle a fait tomber la premiere version
    de cet outil. 59 des 60 images a canal alpha de ce depot ont un alpha
    ENTIEREMENT OPAQUE : le canal est declare et ne sert a rien. libwebp le detecte
    et le jette -- l'image sort en RGB, ce qui est parfaitement sans perte et fait
    gagner de la place. Le garde-fou d'origine comparait les MODES, il aurait donc
    refuse ces 59 conversions en annoncant une « transparence perdue » imaginaire.
    On compare desormais les VALEURS du canal, seule chose qui compte.
    """
    if not a_de_la_transparence(im):
        return False
    return im.convert('RGBA').getchannel('A').getextrema()[0] < 255


def palier_musee(rel):
    try:
        carte = json.load(open(CARTE_BATIMENTS, encoding='utf-8'))
    except Exception:
        return False
    return any(b.startswith('musee-') for b in carte.get(rel, []))


def etudier(rel):
    """Choisit le meilleur encodage pour UNE image. N'ecrit rien."""
    chemin = os.path.join(RACINE, rel)
    origine = os.path.getsize(chemin)
    with Image.open(chemin) as im:
        im.load()
        alpha = transparence_reelle(im)
        base = im.convert('RGBA') if alpha else im.convert('RGB')
        taille = base.size
        tier = 'musee' if palier_musee(rel) else 'normal'
        seuils = BARRIERES[tier]

        for q in ECHELLE:
            donnees = encoder(base, quality=q)
            with Image.open(io.BytesIO(donnees)) as rendu:
                rendu.load()
                g = psnr(base, rendu)
                c = psnr_pire_carreau(base, rendu)
            if g >= seuils['global'] and c >= seuils['pire']:
                return {'rel': rel, 'avant': origine, 'apres': len(donnees), 'mode': 'q%d' % q,
                        'psnr': round(g, 2), 'psnr_pire': round(c, 2), 'alpha': alpha,
                        'tier': tier, 'dim': taille, 'donnees': donnees}

        # Aucun palier avec perte ne tient : on passe au sans perte.
        donnees = encoder(base, lossless=True, quality=100)
        ok = len(donnees) < origine
        return {'rel': rel, 'avant': origine, 'apres': len(donnees), 'mode': 'sans perte',
                'psnr': 99.0, 'psnr_pire': 99.0, 'alpha': alpha, 'tier': tier,
                'dim': taille, 'donnees': donnees, 'refuse': not ok}


def images_du_depot():
    sortie = subprocess.run(['git', 'ls-files'], cwd=RACINE, capture_output=True, text=True).stdout
    return [f for f in sortie.split('\n') if f.lower().endswith(('.png', '.jpg', '.jpeg'))]


def fichiers_de_code():
    sortie = subprocess.run(['git', 'ls-files'], cwd=RACINE, capture_output=True, text=True).stdout
    return [f for f in sortie.split('\n')
            if f.endswith(('.js', '.html', '.css')) and not f.startswith('.scratch/')]


def reecrire_references(couples):
    """Remplace chaque ancien chemin par le nouveau, dans le code du jeu uniquement.

    Le remplacement est pose sur une FRONTIERE DE CHEMIN : sans cela,
    « images/marche.png » remplacerait aussi le fragment final de
    « images/port-marche.png ». Le piege s'est presente au lot 2.
    """
    total = {}
    for f in fichiers_de_code():
        chemin = os.path.join(RACINE, f)
        t = open(chemin, encoding='utf-8').read()
        depart = t
        for ancien, nouveau in couples.items():
            motif = re.compile(r'(?<![A-Za-z0-9_/.-])' + re.escape(ancien) + r'(?![A-Za-z0-9_.-])')
            t, n = motif.subn(nouveau, t)
            if n:
                total[f] = total.get(f, 0) + n
        if t != depart:
            open(chemin, 'w', encoding='utf-8').write(t)
    return total


def convertir(liste):
    os.makedirs(SAUVEGARDE, exist_ok=True)
    couples = {}
    faits = []
    for rel in liste:
        if citee_en_base(rel):
            print('  REFUSE  %s : son nom est cite DANS LA BASE, le renommer casserait ces lignes' % rel)
            continue
        r = etudier(rel)
        if r.get('refuse'):
            print('  REFUSE  %s : meme sans perte, le WebP serait plus lourd' % rel)
            continue

        nouveau = os.path.splitext(rel)[0] + '.webp'
        cible = os.path.join(RACINE, nouveau)
        open(cible, 'wb').write(r['donnees'])

        # VERIFICATION APRES ECRITURE, sur le fichier reellement pose sur le disque.
        with Image.open(cible) as v:
            v.load()
            if v.size != r['dim']:
                os.remove(cible)
                raise SystemExit('dimensions changees pour %s : %s -> %s' % (rel, r['dim'], v.size))
            # On compare les VALEURS du canal alpha, pas les modes : voir
            # transparence_reelle(). Un ecart de 0 signifie que chaque pixel a
            # conserve exactement son opacite.
            if r['alpha']:
                with Image.open(os.path.join(RACINE, rel)) as src:
                    src.load()
                    a1 = src.convert('RGBA').getchannel('A')
                    a2 = v.convert('RGBA').getchannel('A')
                    if ImageChops.difference(a1, a2).getextrema()[1] != 0:
                        os.remove(cible)
                        raise SystemExit('transparence alteree pour %s' % rel)

        # L'original est sauvegarde AVANT d'etre retire du depot.
        dest = os.path.join(SAUVEGARDE, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(os.path.join(RACINE, rel), dest)
        if os.path.getsize(dest) != r['avant']:
            raise SystemExit('sauvegarde incomplete pour %s' % rel)

        # -f est NECESSAIRE et SANS DANGER ici. Necessaire : une image qui vient
        # d'etre ajoutee au depot est indexee sans etre commitee, et `git rm` la
        # refuse alors ("has changes staged in the index") -- c'est le cas de
        # toute image neuve, donc de tout lot d'integration d'art. Sans danger :
        # la sauvegarde hors depot vient d'etre faite A PARTIR DU FICHIER DU
        # DISQUE et sa taille a ete verifiee juste au-dessus ; ce que -f efface
        # est donc deja conserve.
        subprocess.run(['git', 'rm', '-q', '-f', '--', rel], cwd=RACINE, check=True)
        subprocess.run(['git', 'add', '--', nouveau], cwd=RACINE, check=True)
        couples[rel] = nouveau
        r.pop('donnees')
        r['nouveau'] = nouveau
        faits.append(r)

    touches = reecrire_references(couples)
    return faits, touches, couples


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ('mesurer', 'convertir'):
        print(__doc__)
        return 1

    if sys.argv[1] == 'mesurer':
        top = None
        if '--top' in sys.argv:
            top = int(sys.argv[sys.argv.index('--top') + 1])
        res = []
        liste = images_du_depot()
        for i, rel in enumerate(liste):
            try:
                r = etudier(rel)
                r.pop('donnees')
                r['gain'] = r['avant'] - r['apres']
                res.append(r)
            except Exception as e:
                print('  ERREUR %s : %s' % (rel, str(e)[:80]))
            if i % 25 == 0:
                print('  %d/%d' % (i, len(liste)), file=sys.stderr, flush=True)
        res.sort(key=lambda x: -x['gain'])
        json.dump(res, open(os.path.join(RACINE, '.scratch', 'gains_webp.json'), 'w'))
        aff = res[:top] if top else res
        print('%-62s %9s %9s %9s %7s %6s %7s' %
              ('image', 'avant', 'apres', 'gain', 'mode', 'PSNR', 'pire'))
        for r in aff:
            print('%-62s %8.0fK %8.0fK %8.0fK %7s %6.1f %7.1f' %
                  (r['rel'][:62], r['avant'] / 1024, r['apres'] / 1024, r['gain'] / 1024,
                   r['mode'], r['psnr'], r['psnr_pire']))
        print('\n  total mesure : %d images, %.1f Mo -> %.1f Mo (gain %.1f Mo, %.1f %%)' %
              (len(res), sum(x['avant'] for x in res) / 1048576,
               sum(x['apres'] for x in res) / 1048576,
               sum(x['gain'] for x in res) / 1048576,
               100 * sum(x['gain'] for x in res) / max(1, sum(x['avant'] for x in res))))
        return 0

    liste = sys.argv[2:]
    if not liste:
        print('  rien a convertir')
        return 1
    faits, touches, couples = convertir(liste)
    print('%-58s %9s %9s %8s %7s' % ('image', 'avant', 'apres', 'gain', 'mode'))
    for r in faits:
        print('%-58s %8.0fK %8.0fK %7.1f%% %7s' %
              (r['rel'][:58], r['avant'] / 1024, r['apres'] / 1024,
               100 * (1 - r['apres'] / r['avant']), r['mode']))
    print('\n  %d image(s) converties, %.2f Mo -> %.2f Mo' %
          (len(faits), sum(r['avant'] for r in faits) / 1048576,
           sum(r['apres'] for r in faits) / 1048576))
    print('  originaux sauvegardes dans %s' % SAUVEGARDE)
    print('  references reecrites :')
    for f, n in sorted(touches.items(), key=lambda kv: -kv[1]):
        print('     %4d  %s' % (n, f))
    json.dump(faits, open(os.path.join(RACINE, '.scratch', 'converties.json'), 'w'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
