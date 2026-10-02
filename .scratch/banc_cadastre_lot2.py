#!/usr/bin/env python3
# =====================================================================
# BANC — LOT 2 DU CADASTRE : LE CALQUE DE TERRAIN (2 octobre 2026)
# =====================================================================
#
# Le lot 2 ne doit RIEN changer a l'ecran : il transforme du code en donnee. Les deux avenues
# de Luthecia etaient ecrites en dur dans ouvrirPlanVille ; elles vivent desormais dans
# plan.terrain, et leur apparence dans PLAN_TERRAIN_STYLES. La preuve attendue est donc la plus
# severe possible : les 20 plans du monde, rendus caractere pour caractere a l'identique.
#
# Ce banc etablit cinq choses :
#   1. LES 20 PLANS SONT INCHANGES, au caractere pres (empreinte_plans_courante.txt).
#   2. Le terrain vient bien de la DONNEE : modifier plan.terrain change le rendu, le supprimer
#      fait disparaitre les avenues. Sans cette garde, un moteur qui continuerait de dessiner
#      ses routes en dur passerait le test 1 sans rien avoir migre.
#   3. Les surfaces (place, parc, eau) fonctionnent, alors qu'aucune n'est encore declaree :
#      c'est du code qui ne s'execute jamais en production, il doit etre teste ici ou nulle part.
#   4. Le champ `avenues` du lot 1 a disparu : une seule facon de declarer une voie.
#   5. Le releve honnete de ce qu'une voie traverse encore.
#
# Il EXECUTE le moteur reel. Aucun grep : dans ce depot, un grep tombe sur le commentaire qui
# documente le correctif et passe au vert sans rien prouver.
#
# Usage : python3 .scratch/banc_cadastre_lot2.py

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

CAPTURE_PLANS = r"""
// La table d'illustrations est VIDEE : depuis le lot 3, l'empreinte courante est le rendu de
// reference SANS illustration. Les deux bancs comparent donc la meme chose, et l'ajout d'un
// dessin ne fait pas echouer le banc du terrain.
if (typeof PLAN_ILLUSTRATIONS !== 'undefined')
  Object.keys(PLAN_ILLUSTRATIONS).forEach(function(k){ delete PLAN_ILLUSTRATIONS[k]; });
var sortie=[];
Object.keys(WORLD).forEach(function(p){Object.keys(WORLD[p]).forEach(function(v){
  if(!WORLD[p][v]||!WORLD[p][v].buildings) return;
  state.country=p;state.currentCity=v;state.currentBuilding=null;
  ouvrirPlanVille(p,v,true);
  sortie.push(p+'/'+v+'\t'+document.getElementById('minimap-ville-body').innerHTML);
});});
print(sortie.join('\n'));
"""


def lire(f):
    with open(f, encoding='utf-8') as fh:
        return fh.read()


def executer(programme):
    js = (BOUCHONS + lire(os.path.join(RACINE, 'data.js'))
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

    chemin_ref = os.path.join(RACINE, '.scratch', 'empreinte_plans_courante.txt')
    if not os.path.exists(chemin_ref):
        print('Empreinte courante absente (%s) -- banc inoperant.' % chemin_ref)
        return 2

    print('=' * 74)
    print("1. AUCUN PIXEL N'A BOUGE, NULLE PART")
    print('=' * 74)
    ref = {}
    for l in lire(chemin_ref).split('\n'):
        if l.startswith('#') or '\t' not in l:
            continue
        k, v = l.split('\t', 1)
        ref[k] = v
    cur = dict(l.split('\t', 1) for l in executer(CAPTURE_PLANS).strip().split('\n') if '\t' in l)

    garde('les 20 plans du monde sont rendus', (len(ref), len(cur)), (20, 20))
    differents = sorted(k for k in ref if ref.get(k) != cur.get(k))
    garde('les 20 plans sont identiques au caractere pres', differents, [])

    print()
    print('=' * 74)
    print('2. LE TERRAIN VIENT DE LA DONNEE, PAS DU CODE')
    print('=' * 74)
    m = json.loads(executer(r"""
var plan = PLAN_VILLES.republic.capitale;
function rendu(){ state.country='republic'; state.currentCity='capitale'; state.currentBuilding=null;
  ouvrirPlanVille('republic','capitale',true);
  return document.getElementById('minimap-ville-body').innerHTML; }

var normal = rendu();

// a) Retirer le terrain doit faire DISPARAITRE les avenues. Si le rendu ne bouge pas, c'est
//    que le moteur les dessine encore en dur quelque part.
var sauve = plan.terrain;
plan.terrain = [];
var sansTerrain = rendu();

// b) Deplacer l'avenue nord-sud d'une colonne doit la deplacer a l'ecran.
plan.terrain = [{type:'avenue', axe:'colonne', index:5, de:0, a:20}];
var deplacee = rendu();

// c) Une SURFACE, qui n'existe nulle part en production aujourd'hui.
plan.terrain = [{type:'place', x:3, y:4, largeur:2, hauteur:3}];
var avecPlace = rendu();
var styleP = PLAN_TERRAIN_STYLES.place;

// d) Un type inconnu ne doit rien casser : il est ignore, pas plante.
plan.terrain = [{type:'zone-inventee', x:0, y:0, largeur:1, hauteur:1}];
var typeInconnu = rendu();

plan.terrain = sauve;
var remis = rendu();

var cw = plan.cadre.largeur/plan.grille.colonnes, ch = plan.cadre.hauteur/plan.grille.lignes;
print(JSON.stringify({
  nbTerrain: sauve.length,
  types: sauve.map(function(t){return t.type;}),
  avenuesDansNormal: (normal.match(/#1e1c10/g)||[]).length,
  avenuesSansTerrain: (sansTerrain.match(/#1e1c10/g)||[]).length,
  deplaceeContientX5: deplacee.indexOf('x="'+(plan.cadre.x+5*cw)+'"') >= 0,
  deplaceeContientX10: deplacee.indexOf('x="'+(plan.cadre.x+10*cw)+'" y="'+plan.cadre.y+'" width="11"') >= 0,
  placeRect: avecPlace.indexOf('<rect x="'+(plan.cadre.x+3*cw)+'" y="'+(plan.cadre.y+4*ch)+'" width="'+(2*cw)+'" height="'+(3*ch)+'" fill="'+styleP.remplissage+'"') >= 0,
  typeInconnuRendu: typeInconnu.length > 0,
  typeInconnuSansVoie: (typeInconnu.match(/#1e1c10/g)||[]).length,
  remisIdentique: remis === normal,
  champAvenuesExiste: Object.prototype.hasOwnProperty.call(plan, 'avenues'),
  stylesDeclares: Object.keys(PLAN_TERRAIN_STYLES),
  fonctionTerrain: typeof planSvgTerrain
}));
"""))

    garde('planSvgTerrain existe', m['fonctionTerrain'], 'function')
    garde('Luthecia declare 2 voies', m['nbTerrain'], 2)
    garde('et ce sont bien deux avenues', m['types'], ['avenue', 'avenue'])
    garde('le rendu normal contient les 2 rubans', m['avenuesDansNormal'], 2)
    garde('terrain vide => plus aucune voie dessinee', m['avenuesSansTerrain'], 0)
    garde('deplacer l\'avenue la deplace a l\'ecran', m['deplaceeContientX5'], True)
    garde('et elle ne reste pas a son ancienne colonne', m['deplaceeContientX10'], False)
    garde('rendu restaure a l\'identique apres les essais', m['remisIdentique'], True)

    print()
    print('=' * 74)
    print("3. LES SURFACES, QUI N'EXISTENT ENCORE NULLE PART")
    print('=' * 74)
    garde('une place se dessine aux bonnes cases', m['placeRect'], True)
    garde('place, parc et eau sont declares',
          sorted(t for t in m['stylesDeclares'] if t in ('place', 'parc', 'eau')),
          ['eau', 'parc', 'place'])
    garde('un type de terrain inconnu est ignore sans planter', m['typeInconnuRendu'], True)
    garde('et il ne dessine aucune voie', m['typeInconnuSansVoie'], 0)

    print()
    print('=' * 74)
    print('4. UNE SEULE FACON DE DECLARER UNE VOIE')
    print('=' * 74)
    garde('le champ `avenues` du lot 1 a disparu', m['champAvenuesExiste'], False)

    print()
    print('=' * 74)
    print('5. CE QU\'UNE VOIE TRAVERSE ENCORE')
    print('=' * 74)
    t = json.loads(executer(r"""
var plan = PLAN_VILLES.republic.capitale;
var cw = plan.cadre.largeur/plan.grille.colonnes, ch = plan.cadre.hauteur/plan.grille.lignes;
var croise = [];
plan.terrain.forEach(function(v){
  var st = PLAN_TERRAIN_STYLES[v.type]; if (!st || st.surface) return;
  var x0,y0,x1,y1;
  if (v.axe==='colonne'){ x0=plan.cadre.x+v.index*cw; x1=x0+st.epaisseur;
                          y0=plan.cadre.y+v.de*ch;    y1=plan.cadre.y+v.a*ch; }
  else                  { y0=plan.cadre.y+v.index*ch; y1=y0+st.epaisseur;
                          x0=plan.cadre.x+v.de*cw;    x1=plan.cadre.x+v.a*cw; }
  Object.keys(plan.batiments).forEach(function(b){
    var c=plan.batiments[b];
    var bx0=plan.cadre.x+c.x*cw, by0=plan.cadre.y+c.y*ch, bx1=bx0+c.largeur*cw, by1=by0+c.hauteur*ch;
    if (Math.min(bx1,x1)>Math.max(bx0,x0) && Math.min(by1,y1)>Math.max(by0,y0))
      croise.push(v.axe+'@'+v.index+' traverse '+b);
  });
});
print(JSON.stringify({croise: croise}));
"""))
    for c in t['croise']:
        print('  %s' % c)
    # DEFAUT ANTERIEUR, VOLONTAIREMENT NON CORRIGE DANS CE LOT : l'usine pharmaceutique etait
    # deja traversee par l'avenue est-ouest avant le cadastre. La corriger demanderait de
    # deplacer un batiment ou de raccourcir une avenue -- un arbitrage de game design, pas une
    # migration. Le banc le fige pour qu'il ne s'en ajoute pas d'autre en silence.
    garde('une seule voie traverse encore un batiment, et c\'est la connue',
          t['croise'], ['ligne@10 traverse usine-pharmaceutique-luthecia'])

    print()
    print('=' * 74)
    if ko == 0:
        print('VERDICT : %d/%d gardes passees. Le terrain est une donnee, et rien n\'a bouge a l\'ecran.' % (ok, ok))
    else:
        print('VERDICT : %d ECHEC(S) sur %d gardes.\n' % (ko, ok + ko))
        for e in echecs:
            print('  - %s' % e)
    print('=' * 74)
    return 0 if ko == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
