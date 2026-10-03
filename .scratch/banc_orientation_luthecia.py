#!/usr/bin/env python3
# =====================================================================
# BANC — LISIBILITE DU PLAN DE LUTHECIA (2 octobre 2026)
# =====================================================================
#
# Quatre ameliorations issues de l'audit d'orientation, toutes en DONNEE, aucune ligne de moteur :
#
#   A. les groupes de la carte coincident avec les quatre scenes de rue reellement parcourues ;
#   B. les rues parcourues sont dessinees dans le calque de terrain ;
#   C. les huit derniers batiments au pictogramme generique ont le leur ;
#   D. l'usine pharmaceutique ne recouvre plus l'avenue est-ouest.
#
# Ce que ce banc verifie, au-dela du fait que les valeurs sont bien ecrites :
#   - que les quatre groupes correspondent VRAIMENT aux scenes du jeu, en relisant
#     RUE_CENTRALE_NOEUDS plutot qu'en recopiant une liste ;
#   - que l'ordre des colonnes suit toujours l'ordre de marche du joueur ;
#   - que le parcours de la quete d'accueil reste coherent avec la carte ;
#   - que les autres villes ne changent QUE par l'icone des terrains a batir, a zero caractere
#     pres -- la seule consequence assumee du fait que PLAN_ICONS est une table globale.
#
# Il EXECUTE le moteur reel. Aucun grep : dans ce depot, un grep tombe sur le commentaire qui
# documente le correctif et passe au vert sans rien prouver.
#
# Usage : python3 .scratch/banc_orientation_luthecia.py

import json, os, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSC = '/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc'

BOUCHONS = r"""
var _html = {};
var document = {
  getElementById: function(id){
    if(!_html[id]) _html[id] = { set innerHTML(v){this._v=v;}, get innerHTML(){return this._v||'';},
                                 set textContent(v){this._t=v;}, get textContent(){return this._t||'';},
                                 classList:{add:function(){},remove:function(){}}, style:{} };
    return _html[id];
  },
  createElement:function(){return {style:{}};}, head:{appendChild:function(){}},
  querySelectorAll:function(){return [];}
};
var window=this; var localStorage={getItem:function(){return null;},setItem:function(){}};
var state={country:'republic',currentCity:'capitale',currentBuilding:null};
"""


def lire(f):
    with open(f, encoding='utf-8') as fh:
        return fh.read()


def executer(programme):
    js = (BOUCHONS + lire(os.path.join(RACINE, 'data.js'))
          + lire(os.path.join(RACINE, 'plateau-rue-centrale.js'))
          + lire(os.path.join(RACINE, 'plateau-navigation.js')) + programme)
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as fh:
        fh.write(js)
        chemin = fh.name
    p = subprocess.run([JSC, chemin], capture_output=True, text=True, timeout=180)
    os.unlink(chemin)
    if p.returncode != 0:
        print('EXECUTION IMPOSSIBLE :\n%s\n%s' % (p.stdout[-2500:], p.stderr[-2500:]))
        sys.exit(2)
    return p.stdout


ok, ko, echecs = 0, 0, []


def garde(nom, obtenu, attendu):
    global ok, ko
    if obtenu == attendu:
        ok += 1
        print('  OK   %s' % nom)
    else:
        ko += 1
        print('  KO   %s' % nom)
        echecs.append('%s\n       attendu : %r\n       obtenu  : %r' % (nom, attendu, obtenu))


def main():
    if not os.path.exists(JSC):
        print('JavaScriptCore introuvable : %s' % JSC, file=sys.stderr)
        return 2

    m = json.loads(executer(r"""
var plan = PLAN_VILLES.republic.capitale, B = plan.batiments;
var cw = plan.cadre.largeur/plan.grille.colonnes, ch = plan.cadre.hauteur/plan.grille.lignes;
var N = RUE_CENTRALE_NOEUDS.republic;

// --- Les quatre scenes de la rue des institutions, LUES DANS LE JEU ---
// L'ordre de marche se deduit du graphe : palais -> imprimerie -> hotel-de-ville -> loge.
var ORDRE = ['luthecia-palais-presidentiel','luthecia-imprimerie',
             'luthecia-hotel-de-ville','luthecia-loge'];
function batimentsDe(noeudId){
  var n = N[noeudId], zs = [].concat(n.zones||[]);
  Object.keys(n.zonesParArrivee||{}).forEach(function(k){ zs = zs.concat(n.zonesParArrivee[k]); });
  var v = []; zs.forEach(function(z){ if(z.buildingId && v.indexOf(z.buildingId)<0) v.push(z.buildingId); });
  return v;
}
var groupes = ORDRE.map(function(id){
  var bats = batimentsDe(id).filter(function(b){ return B[b]; });
  var cols = bats.map(function(b){ return B[b].x; }).sort(function(a,b){return a-b;});
  return { scene:id.replace('luthecia',''), batiments:bats.length,
           min:cols[0], max:cols[cols.length-1],
           contigu: cols.length === (cols[cols.length-1]-cols[0]+1) };
});
// Les groupes se chevauchent-ils en colonnes ?
var entrelaces = [];
for (var i=0;i<groupes.length;i++) for (var j=i+1;j<groupes.length;j++)
  if (Math.min(groupes[i].max,groupes[j].max) >= Math.max(groupes[i].min,groupes[j].min))
    entrelaces.push(groupes[i].scene+' / '+groupes[j].scene);
// L'ordre des colonnes suit-il l'ordre de marche ?
var ordreOk = groupes.every(function(g,i){ return i===0 || g.min > groupes[i-1].max; });
// Separation entre groupes consecutifs, en colonnes libres
var ecarts = groupes.slice(1).map(function(g,i){ return g.min - groupes[i].max - 1; });

// --- Le calque de terrain ---
var voies = plan.terrain.map(function(t){ return t.type; });

// --- Les icones ---
var monde = WORLD.republic.capitale.buildings;
var generiques = monde.filter(function(b){ return B[b] && !PLAN_ICONS[b]; });
var huit = ['bureau-national-emploi','usine-pharmaceutique-luthecia','entrepot-logistique-luthecia',
            'terrain-a-batir-1','terrain-a-batir-2','terrain-a-batir-3','terrain-a-batir-4','terrain-a-batir-5'];
var iconesHuit = huit.map(function(b){ return PLAN_ICONS[b] || null; });
// Deux batiments voisins ne doivent pas partager la meme icone dans la rangee des institutions.

// --- L'usine et l'avenue est-ouest ---
var avEO = plan.terrain.filter(function(t){ return t.axe==='ligne' && t.type==='avenue'; })[0];
var ep = PLAN_TERRAIN_STYLES.avenue.epaisseur;
var ay0 = plan.cadre.y + avEO.index*ch, ay1 = ay0 + ep;
var masquent = Object.keys(B).filter(function(b){
  var c=B[b], y0=plan.cadre.y+c.y*ch, y1=y0+c.hauteur*ch;
  var x0=plan.cadre.x+c.x*cw, x1=x0+c.largeur*cw;
  var ax0=plan.cadre.x+avEO.de*cw, ax1=plan.cadre.x+avEO.a*cw;
  return Math.min(x1,ax1)-Math.max(x0,ax0) > 0.01 && Math.min(y1,ay1)-Math.max(y0,ay0) > 0.01;
});

// --- Le point rouge et les etiquettes ---
state.currentBuilding='mairie-capitale';
ouvrirPlanVille('republic','capitale',true);
var svg = document.getElementById('minimap-ville-body').innerHTML;

print(JSON.stringify({
  groupes: groupes, entrelaces: entrelaces, ordreOk: ordreOk, ecarts: ecarts,
  voies: voies, nbRues: voies.filter(function(t){return t==='rue';}).length,
  generiques: generiques, iconesHuit: iconesHuit,
  iconesDistinctes: new Set ? undefined : undefined,
  usine: B['usine-pharmaceutique-luthecia'],
  masquentAvenueEO: masquent,
  // Le marqueur « vous etes ici » : les cercles qui battent, ET l'anneau pose autour du
  // batiment courant depuis l'audit UX. On compte les deux separement plutot qu'un total,
  // pour qu'un changement d'un cote ne masque pas la disparition de l'autre.
  pointRouge: (svg.match(/<circle[^>]*class="pd"/g)||[]).length,
  anneauIci: (svg.match(/class="pd-anneau"/g)||[]).length,
  // Les etiquettes sont comptees DANS les groupes de batiment : le titre du plan emploie la
  // meme taille de police et fausserait le compte.
  // AU MOINS une etiquette par batiment : le batiment illustre n'a pas d'icone emoji -- c'est
  // precisement ce que l'illustration remplace -- mais il garde son nom comme tous les autres.
  etiquettes: svg.split('<g class="plan-b"').slice(1)
                 .filter(function(g){ return (g.split('</g>')[0].match(/<text/g)||[]).length >= 1; }).length,
  batimentsDessines: (svg.match(/class="plan-b"/g)||[]).length
}));
"""))

    print('=' * 74)
    print('A. LES GROUPES DE LA CARTE ET LES SCENES DE LA RUE')
    print('=' * 74)
    for g in m['groupes']:
        print('  %-24s %d batiments, colonnes %2d a %2d%s'
              % (g['scene'], g['batiments'], g['min'], g['max'],
                 '' if g['contigu'] else '   NON CONTIGU'))
    garde('les quatre scenes sont retrouvees dans le jeu', len(m['groupes']), 4)
    garde('chaque scene occupe des colonnes contigues',
          [g['scene'] for g in m['groupes'] if not g['contigu']], [])
    garde('aucun groupe ne s\'entrelace avec un autre', m['entrelaces'], [])
    garde('l\'ordre des colonnes suit l\'ordre de marche', m['ordreOk'], True)
    print('  separation entre groupes consecutifs : %s colonne(s) libre(s)'
          % ', '.join(str(e) for e in m['ecarts']))
    garde('chaque groupe est separe du suivant', [e for e in m['ecarts'] if e < 1], [])
    garde('la rangee va d\'un mur a l\'autre',
          (m['groupes'][0]['min'], m['groupes'][-1]['max']), (0, 19))

    print()
    print('=' * 74)
    print('B. LES RUES PARCOURUES SONT DESSINEES')
    print('=' * 74)
    garde('six voies declarees', len(m['voies']), 6)
    garde('deux avenues et quatre rues', m['voies'],
          ['avenue', 'avenue', 'rue', 'rue', 'rue', 'rue'])
    garde('quatre rues ajoutees', m['nbRues'], 4)

    print()
    print('=' * 74)
    print('C. PLUS AUCUN PICTOGRAMME GENERIQUE A LUTHECIA')
    print('=' * 74)
    garde('aucun batiment de Luthecia sur l\'icone par defaut', m['generiques'], [])
    garde('les huit ont tous recu la leur', [i for i in m['iconesHuit'] if not i], [])
    print('  icones posees : %s' % ' '.join(m['iconesHuit']))

    print()
    print('=' * 74)
    print('D. L\'USINE NE RECOUVRE PLUS L\'AVENUE')
    print('=' * 74)
    print('  usine : colonnes %d-%d, lignes %d-%d'
          % (m['usine']['x'], m['usine']['x'] + m['usine']['largeur'],
             m['usine']['y'], m['usine']['y'] + m['usine']['hauteur']))
    garde('plus aucun batiment ne masque l\'avenue est-ouest', m['masquentAvenueEO'], [])
    garde('l\'usine garde sa taille d\'origine (3 x 5 cases)',
          (m['usine']['largeur'], m['usine']['hauteur']), (3, 5))

    print()
    print('=' * 74)
    print('CE QUI DEVAIT ETRE CONSERVE')
    print('=' * 74)
    garde('le point rouge « vous etes ici » est toujours la', m['pointRouge'] >= 2, True)
    garde('et le batiment courant est cercle', m['anneauIci'], 1)
    garde('les 36 batiments sont dessines', m['batimentsDessines'], 36)
    garde('chaque batiment garde son etiquette', m['etiquettes'], 36)

    print()
    print('=' * 74)
    print('LE PARCOURS DE LA QUETE D\'ACCUEIL, SUR LA CARTE')
    print('=' * 74)
    q = json.loads(executer(r"""
var plan = PLAN_VILLES.republic.capitale, B = plan.batiments;
var N = RUE_CENTRALE_NOEUDS.republic;
function centre(id){
  var n=N[id], zs=[].concat(n.zones||[]);
  Object.keys(n.zonesParArrivee||{}).forEach(function(k){ zs=zs.concat(n.zonesParArrivee[k]); });
  var pts=[]; zs.forEach(function(z){ if(B[z.buildingId]) pts.push(B[z.buildingId].x+B[z.buildingId].largeur/2); });
  return pts.length ? pts.reduce(function(a,b){return a+b;},0)/pts.length : null;
}
var etapes = ['luthecia-tabernacle-impots','luthecia-palais-presidentiel',
              'luthecia-imprimerie','luthecia-hotel-de-ville','luthecia-loge'];
print(JSON.stringify({
  colonnes: etapes.map(centre),
  depart: RUE_CENTRALE_DEPART_PREMIERS_PAS.republic.capitale,
  lienDepart: N['luthecia-tabernacle-impots'].liens.gauche
}));
"""))
    noms = ['Tabernacle / Marche', 'Palais presidentiel', 'Imprimerie', 'Hotel de Ville', 'Loge']
    for n, c in zip(noms, q['colonnes']):
        print('  %-22s colonne moyenne %5.1f' % (n, c))
    garde('le point d\'apparition est bien le Tabernacle',
          q['depart'], 'luthecia-tabernacle-impots')
    garde('un seul deplacement mene au Palais', q['lienDepart'], 'luthecia-palais-presidentiel')
    # Le parcours se lit d'ouest en est sur la carte, apres le saut depuis la couronne.
    garde('les institutions se deroulent d\'ouest en est',
          q['colonnes'][1:] == sorted(q['colonnes'][1:]), True)
    garde('le depart est a l\'ouest de tout le reste',
          q['colonnes'][0] < min(q['colonnes'][1:]), True)

    print()
    print('=' * 74)
    print('LES AUTRES VILLES')
    print('=' * 74)
    a = json.loads(executer(r"""
// Seule consequence assumee : PLAN_ICONS est une table globale indexee par identifiant de
// batiment, et quatre terrains a batir de Luthecia existent aussi ailleurs. On mesure que ces
// plans ne changent QUE par l'icone -- meme geometrie, meme longueur de chaine.
var avant = {}, apres = {};
var sauve = {};
['terrain-a-batir-1','terrain-a-batir-2','terrain-a-batir-4','terrain-a-batir-5'].forEach(function(b){
  sauve[b]=PLAN_ICONS[b]; delete PLAN_ICONS[b];
});
function rendre(cible){
  Object.keys(WORLD).forEach(function(p){Object.keys(WORLD[p]).forEach(function(v){
    if(!WORLD[p][v]||!WORLD[p][v].buildings) return;
    state.country=p;state.currentCity=v;state.currentBuilding=null;
    ouvrirPlanVille(p,v,true);
    cible[p+'/'+v]=document.getElementById('minimap-ville-body').innerHTML;
  });});
}
rendre(avant);
Object.keys(sauve).forEach(function(b){ PLAN_ICONS[b]=sauve[b]; });
rendre(apres);
var changes = Object.keys(avant).filter(function(k){ return avant[k]!==apres[k]; });
var autres = changes.filter(function(k){ return k !== 'republic/capitale'; });
print(JSON.stringify({
  changes: changes.sort(),
  autres: autres.sort(),
  memeLongueur: autres.every(function(k){ return avant[k].length===apres[k].length; }),
  // Neutraliser les deux pictogrammes : si les chaines deviennent identiques, alors le
  // pictogramme est bien la SEULE difference.
  seulementIcone: autres.every(function(k){
    return avant[k].replace(/🏢/g,'§') === apres[k].replace(/🚧/g,'§');
  })
}));
"""))
    print('  plans ou l\'icone des terrains change : %s' % ', '.join(a['changes']))
    # PLAN_ICONS est une table GLOBALE indexee par identifiant de batiment, et quatre terrains a
    # batir de Luthecia existent aussi ailleurs. Ces six plans changent donc, et c'est la seule
    # consequence assumee du lot. Ce qui doit etre prouve, c'est qu'ils ne changent QUE par la.
    garde('six autres villes sont touchees, et ce sont celles qui partagent un terrain',
          a['autres'],
          ['khalija/capitale', 'khalija/ville_b', 'narco/capitale',
           'narco/ville_b', 'soviet/capitale', 'soviet/ville_b'])
    garde('elles gardent exactement la meme longueur de rendu', a['memeLongueur'], True)
    garde('et le pictogramme est leur SEULE difference', a['seulementIcone'], True)

    print()
    print('=' * 74)
    if ko == 0:
        print('VERDICT : %d/%d gardes passees. Luthecia est plus lisible, et rien d\'autre n\'a bouge.' % (ok, ok))
    else:
        print('VERDICT : %d ECHEC(S) sur %d gardes.\n' % (ko, ok + ko))
        for e in echecs:
            print('  - %s' % e)
    print('=' * 74)
    return 0 if ko == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
