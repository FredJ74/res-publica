#!/usr/bin/env python3
# =====================================================================
# BANC — LOT 3 DU CADASTRE : LE CALQUE D'ILLUSTRATION (2 octobre 2026)
# =====================================================================
#
# Le lot 3 introduit la chaine de repli qui rend tout le chantier jouable :
#
#     1. illustration propre a ce lieu   PLAN_ILLUSTRATIONS[id].parLieu['empire/ville']
#     2. illustration generique          PLAN_ILLUSTRATIONS[id].image
#     3. rectangle + icone + nom         le moteur d'origine, inchange
#
# Ce que ce banc doit etablir, dans l'ordre d'importance :
#   1. AVEC LA TABLE VIDE, LES 20 PLANS SONT INCHANGES au caractere pres. C'est l'invariant qui
#      autorise a illustrer la ville un batiment a la fois sans jamais rien casser.
#   2. Les trois maillons de la chaine repondent dans le bon ordre, y compris la surcharge par
#      LIEU et pas seulement par empire : mesure, 'terrain-a-batir-2' appartient a
#      republic/capitale ET aux ville_b de narco, soviet et khalija -- il traverse donc a la
#      fois les empires et les creneaux de ville.
#   3. Le debord vertical monte et ne descend jamais, et le repli est dessine SOUS l'image.
#   4. Ce que Fred a demande de conserver l'est : le point rouge, les etiquettes, le lisere
#      « vous etes ici ».
#
# Il EXECUTE le moteur reel. Aucun grep : dans ce depot, un grep tombe sur le commentaire qui
# documente le correctif et passe au vert sans rien prouver.
#
# Usage : python3 .scratch/banc_cadastre_lot3.py

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

# La table est VIDEE avant la comparaison : l'empreinte courante est, depuis le lot 3, le rendu
# de reference SANS illustration. C'est elle que la chaine de repli doit reproduire exactement.
CAPTURE_SANS_ILLU = r"""
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
        print('Empreinte courante absente -- banc inoperant.')
        return 2

    print('=' * 74)
    print("1. AVEC ZERO ILLUSTRATION, RIEN N'A BOUGE")
    print('=' * 74)
    ref = {}
    for l in lire(chemin_ref).split('\n'):
        if l.startswith('#') or '\t' not in l:
            continue
        k, v = l.split('\t', 1)
        ref[k] = v
    cur = dict(l.split('\t', 1) for l in executer(CAPTURE_SANS_ILLU).strip().split('\n') if '\t' in l)
    garde('les 20 plans du monde sont rendus', (len(ref), len(cur)), (20, 20))
    garde('les 20 plans sont identiques au caractere pres',
          sorted(k for k in ref if ref.get(k) != cur.get(k)), [])

    print()
    print('=' * 74)
    print('2. LA CHAINE DE REPLI, MAILLON PAR MAILLON')
    print('=' * 74)
    m = json.loads(executer(r"""
// On reconstruit une table d'essai : le but est d'exercer la CHAINE, pas le contenu livre.
Object.keys(PLAN_ILLUSTRATIONS).forEach(function(k){ delete PLAN_ILLUSTRATIONS[k]; });
PLAN_ILLUSTRATIONS['assemblee']        = { image: 'generique.png' };
PLAN_ILLUSTRATIONS['tribunal']         = { image: 'generique.png',
                                           parLieu: { 'republic/capitale': 'propre-a-luthecia.png' } };
PLAN_ILLUSTRATIONS['universite']       = { parLieu: { 'soviet/capitale': 'ailleurs.png' } };
// L'IDENTIFIANT PARTAGE. Mesure : 'terrain-a-batir-2' appartient a republic/capitale ET aux
// ville_b de narco, soviet et khalija. Il traverse donc a la fois les empires ET les creneaux
// de ville -- une surcharge indexee par empire seul ne saurait pas les distinguer.
PLAN_ILLUSTRATIONS['terrain-a-batir-2'] = { image: 'parcelle-commune.png',
                                            parLieu: { 'soviet/ville_b': 'parcelle-miniere.png' } };
// Forme « planche de sprites » : prevue, pas encore lue. Doit se comporter comme une absence.
PLAN_ILLUSTRATIONS['la-tribune']       = { image: { planche: 'p.png', x:0, y:0, largeur:1, hauteur:1 } };

function hrefsDe(pays, ville){
  state.country=pays; state.currentCity=ville; state.currentBuilding=null;
  ouvrirPlanVille(pays, ville, true);
  var s = document.getElementById('minimap-ville-body').innerHTML;
  return (s.match(/<image href="[^"]*"/g) || []).map(function(t){ return t.slice(13, -1); });
}
var luthecia  = hrefsDe('republic','capitale');
var sovietB   = hrefsDe('soviet','ville_b');

print(JSON.stringify({
  resoluGenerique:  planIllustrationResolue('assemblee','republic','capitale').href,
  resoluSurcharge:  planIllustrationResolue('tribunal','republic','capitale').href,
  resoluAutreLieu:  planIllustrationResolue('tribunal','soviet','capitale').href,
  resoluSansImage:  planIllustrationResolue('universite','republic','capitale'),
  resoluAilleurs:   planIllustrationResolue('universite','soviet','capitale').href,
  resoluInconnu:    planIllustrationResolue('batiment-qui-n-existe-pas','republic','capitale'),
  resoluPlanche:    planIllustrationResolue('la-tribune','republic','capitale'),
  hrefsLuthecia:    luthecia.sort(),
  hrefsSovietB:     sovietB.sort()
}));
"""))

    garde('maillon 2 — l\'illustration generique repond', m['resoluGenerique'], 'generique.png')
    garde('maillon 1 — la surcharge par lieu bat la generique', m['resoluSurcharge'], 'propre-a-luthecia.png')
    garde('ailleurs, la generique reprend la main', m['resoluAutreLieu'], 'generique.png')
    garde('maillon 3 — sans image pour ce lieu, on retombe sur le rectangle', m['resoluSansImage'], None)
    garde('la surcharge s\'applique bien au lieu vise', m['resoluAilleurs'], 'ailleurs.png')
    garde('un batiment sans entree retombe sur le rectangle', m['resoluInconnu'], None)
    garde('la forme planche de sprites est ignoree, pas lue', m['resoluPlanche'], None)

    print()
    print('  Luthecia dessine  : %s' % ', '.join(m['hrefsLuthecia']))
    print('  soviet/ville_b    : %s' % ', '.join(m['hrefsSovietB']))
    garde('Luthecia : 3 illustrations, dont la parcelle commune',
          m['hrefsLuthecia'], ['generique.png', 'parcelle-commune.png', 'propre-a-luthecia.png'])
    garde('ailleurs, la MEME parcelle est miniere, et rien d\'autre',
          m['hrefsSovietB'], ['parcelle-miniere.png'])

    g = json.loads(executer(r"""
Object.keys(PLAN_ILLUSTRATIONS).forEach(function(k){ delete PLAN_ILLUSTRATIONS[k]; });
PLAN_ILLUSTRATIONS['palais-presidentiel'] = { image: 'commune.png' };
var avecGenerique = {};
Object.keys(WORLD).forEach(function(p){Object.keys(WORLD[p]).forEach(function(v){
  if(!WORLD[p][v]||!WORLD[p][v].buildings) return;
  state.country=p;state.currentCity=v;state.currentBuilding=null;
  ouvrirPlanVille(p,v,true);
  var n=(document.getElementById('minimap-ville-body').innerHTML.match(/<image /g)||[]).length;
  if(n) avecGenerique[p+'/'+v]=n;
});});
PLAN_ILLUSTRATIONS['palais-presidentiel'] = { parLieu: { 'republic/capitale': 'propre.png' } };
var avecParLieu = {};
Object.keys(WORLD).forEach(function(p){Object.keys(WORLD[p]).forEach(function(v){
  if(!WORLD[p][v]||!WORLD[p][v].buildings) return;
  state.country=p;state.currentCity=v;state.currentBuilding=null;
  ouvrirPlanVille(p,v,true);
  var n=(document.getElementById('minimap-ville-body').innerHTML.match(/<image /g)||[]).length;
  if(n) avecParLieu[p+'/'+v]=n;
});});
print(JSON.stringify({generique: avecGenerique, parLieu: avecParLieu}));
"""))
    print()
    print('  avec `image`   : %s' % ', '.join(sorted(g['generique'])))
    print('  avec `parLieu` : %s' % ', '.join(sorted(g['parLieu'])))
    # PIEGE MESURE, PAS DECOUVERT : palais-presidentiel existe dans les QUATRE capitales. Une
    # illustration generique les repeint toutes d'un coup. C'est le comportement voulu de
    # `image` -- une facade commune sert partout -- mais il faut le savoir avant de l'ecrire.
    garde('une illustration generique se repand sur les 4 capitales',
          sorted(g['generique']),
          ['khalija/capitale', 'narco/capitale', 'republic/capitale', 'soviet/capitale'])
    garde('la meme, portee par parLieu, ne touche que Luthecia',
          sorted(g['parLieu']), ['republic/capitale'])

    print()
    print('=' * 74)
    print('3. LE DEBORD VERTICAL, ET L\'ORDRE DES COUCHES')
    print('=' * 74)
    d = json.loads(executer(r"""
var plan = PLAN_VILLES.republic.capitale;
var ch = plan.cadre.hauteur / plan.grille.lignes;
Object.keys(PLAN_ILLUSTRATIONS).forEach(function(k){ delete PLAN_ILLUSTRATIONS[k]; });
PLAN_ILLUSTRATIONS['palais-presidentiel'] = { image: 'haut.png', hauteurCellules: 3, ancre: 'bas' };
PLAN_ILLUSTRATIONS['assemblee']           = { image: 'plat.png' };   // sans hauteur declaree

state.country='republic'; state.currentCity='capitale'; state.currentBuilding='palais-presidentiel';
ouvrirPlanVille('republic','capitale',true);
var s = document.getElementById('minimap-ville-body').innerHTML;

function bloc(href){
  var i = s.indexOf('href="'+href+'"');
  var g = s.lastIndexOf('<g class="plan-b"', i);
  return s.slice(g, s.indexOf('</g>', i) + 4);
}
var bHaut = bloc('haut.png'), bPlat = bloc('plat.png');
function attr(t, nom){ var m = new RegExp(nom+'="([^"]*)"').exec(t); return m ? +m[1] : null; }
var imgHaut = /<image[^>]*>/.exec(bHaut)[0];
var rectHaut = /<rect[^>]*>/.exec(bHaut)[0];
var emprise = plan.batiments['palais-presidentiel'];

print(JSON.stringify({
  hauteurImage:   attr(imgHaut,'height'),
  hauteurEmprise: emprise.hauteur * ch,
  yImage:         attr(imgHaut,'y'),
  yEmprise:       attr(rectHaut,'y'),
  basImage:       attr(imgHaut,'y') + attr(imgHaut,'height'),
  basEmprise:     attr(rectHaut,'y') + attr(rectHaut,'height'),
  // Sans hauteurCellules, l'image epouse exactement l'emprise.
  hauteurPlate:   attr(/<image[^>]*>/.exec(bPlat)[0],'height'),
  emprisePlate:   attr(/<rect[^>]*>/.exec(bPlat)[0],'height'),
  // Ordre dans le groupe : repli, puis image, puis lisere, puis etiquette.
  ordre: ['<rect','<image','<rect','<text'].every(function(t,i){
    var pos = 0; for (var k=0;k<=i;k++){ pos = bHaut.indexOf(['<rect','<image','<rect','<text'][k], pos) + 1; }
    return pos > 0;
  }),
  posRect1:  bHaut.indexOf('<rect'),
  posImage:  bHaut.indexOf('<image'),
  posRect2:  bHaut.indexOf('<rect', bHaut.indexOf('<image')),
  posTexte:  bHaut.indexOf('<text'),
  nbTexte:   (bHaut.match(/<text/g)||[]).length,
  liserePardessus: /<image[\s\S]*<rect[^>]*fill="none"/.test(bHaut),
  pointRouge: (s.match(/class="pd"/g)||[]).length,
  etiquette:  />([^<]*Palais[^<]*)</.exec(bHaut) ? /&gt;|>([^<]*)</.exec('') : null,
  contientNom: bHaut.indexOf('Palais') >= 0
}));
"""))

    garde('le dessin monte a 3 cases', round(d['hauteurImage'], 1), round(3 * 25.9, 1))
    garde('alors que l\'emprise au sol n\'en fait que 2', round(d['hauteurEmprise'], 1), round(2 * 25.9, 1))
    garde('le bas du dessin reste colle au bas de l\'emprise',
          round(d['basImage'], 1), round(d['basEmprise'], 1))
    garde('le debord monte, il ne descend jamais', d['yImage'] < d['yEmprise'], True)
    garde('sans hauteur declaree, l\'image epouse l\'emprise',
          d['hauteurPlate'], d['emprisePlate'])

    print()
    garde('le repli est dessine AVANT l\'image', d['posRect1'] < d['posImage'], True)
    garde('le lisere est repasse APRES l\'image', d['liserePardessus'], True)
    garde('l\'etiquette est dessinee en dernier', d['posTexte'] > d['posImage'], True)

    print()
    print('=' * 74)
    print('4. CE QUE FRED A DEMANDE DE CONSERVER')
    print('=' * 74)
    garde('le nom du batiment est conserve', d['contientNom'], True)
    garde('l\'icone emoji n\'est PAS redessinee par-dessus le dessin', d['nbTexte'], 1)
    garde('le point rouge « vous etes ici » est toujours la', d['pointRouge'], 2)

    print()
    print('=' * 74)
    print('5. CE QUI EST REELLEMENT LIVRE')
    print('=' * 74)
    L = json.loads(executer(r"""
var n = {};
Object.keys(WORLD).forEach(function(p){Object.keys(WORLD[p]).forEach(function(v){
  if(!WORLD[p][v]||!WORLD[p][v].buildings) return;
  state.country=p;state.currentCity=v;state.currentBuilding=null;
  ouvrirPlanVille(p,v,true);
  var s = document.getElementById('minimap-ville-body').innerHTML;
  var c = (s.match(/<image /g)||[]).length;
  if (c) n[p+'/'+v] = c;
}));
print(JSON.stringify({
  declarees: Object.keys(PLAN_ILLUSTRATIONS),
  parPlan: n,
  demoEstUneDonneeInline: planIllustrationResolue('palais-presidentiel','republic','capitale')
                            .href.indexOf('data:image/svg+xml,') === 0,
  demoPorteeParLieu: !PLAN_ILLUSTRATIONS['palais-presidentiel'].image
                     && !!PLAN_ILLUSTRATIONS['palais-presidentiel'].parLieu['republic/capitale']
}));
""".replace('}));\nprint', '});});\nprint')))
    garde('une seule illustration est declaree', L['declarees'], ['palais-presidentiel'])
    garde('et elle n\'apparait que sur le plan de Luthecia', L['parPlan'], {'republic/capitale': 1})
    garde('la demonstration est une donnee inline, sans fichier a deployer',
          L['demoEstUneDonneeInline'], True)
    # Portee par parLieu et non par image : sans cela elle repeindrait les quatre capitales,
    # qui partagent toutes l'identifiant palais-presidentiel.
    garde('et elle est portee par le lieu, pas par une generique',
          L['demoPorteeParLieu'], True)

    print()
    print('=' * 74)
    if ko == 0:
        print('VERDICT : %d/%d gardes passees. La chaine de repli tient de bout en bout.' % (ok, ok))
    else:
        print('VERDICT : %d ECHEC(S) sur %d gardes.\n' % (ko, ok + ko))
        for e in echecs:
            print('  - %s' % e)
    print('=' * 74)
    return 0 if ko == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
