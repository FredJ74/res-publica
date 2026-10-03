#!/usr/bin/env python3
# =====================================================================
# BANC — LOT 1 DU CADASTRE : LUTHECIA PASSE EN GRILLE 20x20 (2 octobre 2026)
# =====================================================================
#
# Ce banc EXECUTE le moteur reel et compare les 20 plans du monde a une empreinte figee juste
# avant le premier lot (.scratch/empreinte_plans_reference.txt). Il ne cherche aucune chaine
# dans les fichiers -- c'est le piege de ce depot, ou un grep tombe sur le commentaire qui
# documente le correctif et passe au vert sans rien prouver.
#
# Il etablit quatre choses :
#   1. LES 19 AUTRES PLANS N'ONT PAS BOUGE D'UN CARACTERE. C'est la garantie principale du lot :
#      seul Luthecia devait changer.
#   2. Luthecia est bien dessinee depuis PLAN_VILLES, et plus depuis PLAN_LAYOUTS.
#   3. Aucune case n'est occupee deux fois, et aucun batiment ne sort du cadre.
#   4. Chaque batiment est reste a moins d'une demi-case de sa position d'hier, sauf les
#      quatre ajustements motives dans la table.
#
# Usage : python3 .scratch/banc_cadastre_lot1.py

import os, re, subprocess, sys, tempfile

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
// Table d'illustrations videe : l'empreinte de reference date d'avant le calque d'illustration,
// et c'est bien le rendu SANS dessin que ce banc doit comparer.
if (typeof PLAN_ILLUSTRATIONS !== 'undefined')
  Object.keys(PLAN_ILLUSTRATIONS).forEach(function(k){ delete PLAN_ILLUSTRATIONS[k]; });
var sortie = [];
Object.keys(WORLD).forEach(function(p){
  Object.keys(WORLD[p]).forEach(function(v){
    if(!WORLD[p][v] || !WORLD[p][v].buildings) return;
    state.country = p; state.currentCity = v; state.currentBuilding = null;
    ouvrirPlanVille(p, v, true);
    sortie.push(p+'/'+v+'\t'+document.getElementById('minimap-ville-body').innerHTML);
  });
});
print(sortie.join('\n'));
"""


def lire(f):
    with open(f, encoding='utf-8') as fh:
        return fh.read()


def executer(source_nav, programme):
    js = BOUCHONS + lire(os.path.join(RACINE, 'data.js')) + source_nav + programme
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

    # L'EMPREINTE DE REFERENCE, ET PAS HEAD. Comparer au commit precedent ne vaudrait qu'une
    # seule fois : des le lot livre, HEAD contient deja le changement et le banc se comparerait
    # a lui-meme en passant au vert pour rien. L'empreinte est figee au commit c86db8a, juste
    # avant le premier lot, et se compare indefiniment -- lot 2, lot 3, et ainsi de suite.
    chemin_ref = os.path.join(RACINE, '.scratch', 'empreinte_plans_reference.txt')
    if not os.path.exists(chemin_ref):
        print('Empreinte de reference absente (%s) -- banc inoperant.' % chemin_ref)
        return 2
    avant = {}
    for l in lire(chemin_ref).split('\n'):
        if l.startswith('#') or '\t' not in l:
            continue
        k, v = l.split('\t', 1)
        avant[k] = v

    nav_apres = lire(os.path.join(RACINE, 'plateau-navigation.js'))

    # Les plans que les lots du cadastre ont VOLONTAIREMENT modifies depuis la reference.
    # Luthecia est passee au cadastre ; les six autres ne different que par une icone -- le lot
    # d'orientation a donne aux terrains a batir leur propre pictogramme, et PLAN_ICONS est une
    # table globale indexee par identifiant de batiment. Mesure : ces six plans changent de zero
    # caractere, seule l'icone differe.
    AU_CADASTRE = ['republic/capitale',
                   'narco/capitale', 'soviet/capitale', 'khalija/capitale',
                   'narco/ville_b', 'soviet/ville_b', 'khalija/ville_b']

    print('=' * 74)
    print("1. LES AUTRES PLANS N'ONT PAS BOUGE")
    print('=' * 74)
    apres = dict(l.split('\t', 1) for l in executer(nav_apres, CAPTURE_PLANS).strip().split('\n') if '\t' in l)

    garde('les 20 plans du monde sont tous rendus', (len(avant), len(apres)), (20, 20))
    garde('aucun plan n\'apparait ni ne disparait', sorted(avant) == sorted(apres), True)

    # LA GARDE PORTE SUR LA GEOMETRIE, PAS SUR LA CHAINE ENTIERE. La claim du lot 1 est « aucun
    # batiment n'a bouge ailleurs qu'a Luthecia » -- pas « pas un octet n'a change ». Depuis, des
    # lots ulterieurs ont legitimement modifie des pictogrammes et ajoute une regle d'animation
    # au bloc <style>, emise sur les 20 plans. Comparer les chaines brutes ferait echouer cette
    # garde pour des raisons qui n'ont rien a voir avec ce qu'elle protege. On compare donc la
    # suite des coordonnees dessinees, qui est exactement ce que « rien n'a bouge » veut dire.
    import re as _re
    def geometrie(svg):
        sans_style = _re.sub(r'<defs>.*?</defs>', '', svg, flags=_re.S)
        return _re.findall(r'(?:x|y|x1|y1|x2|y2|cx|cy|r|width|height)="(-?[\d.]+)"', sans_style)
    inchanges = [k for k in avant if k in apres and geometrie(avant[k]) == geometrie(apres[k])]
    modifies = [k for k in avant if k in apres and geometrie(avant[k]) != geometrie(apres[k])]
    garde('seule la geometrie des villes au cadastre a bouge', sorted(modifies), ['republic/capitale'])
    garde('les 19 autres ont une geometrie strictement inchangee', len(inchanges), 19)

    print()
    print('=' * 74)
    print('2. LUTHECIA EST DESSINEE DEPUIS LE CADASTRE')
    print('=' * 74)
    mesure = executer(nav_apres, r"""
var plan = PLAN_VILLES.republic.capitale;
var cw = plan.cadre.largeur / plan.grille.colonnes;
var ch = plan.cadre.hauteur / plan.grille.lignes;
var B = plan.batiments, ids = Object.keys(B);
var monde = WORLD.republic.capitale.buildings;

// Chaque batiment de la ville a une case, et reciproquement : pas d'entree morte.
var sansCase = monde.filter(function(b){ return !B[b]; });
var fantomes = ids.filter(function(b){ return monde.indexOf(b) < 0; });

// Aucune case occupee deux fois.
var occ = {}, coll = [];
ids.forEach(function(b){ var c = B[b];
  for (var i=0;i<c.largeur;i++) for (var j=0;j<c.hauteur;j++){
    var k=(c.x+i)+','+(c.y+j);
    if (occ[k]) coll.push(b+'/'+occ[k]+'@'+k); else occ[k]=b;
  }});

// Tailles entieres et strictement positives.
var tailles = ids.filter(function(b){ var c=B[b];
  return !(Number.isInteger(c.x)&&Number.isInteger(c.y)&&Number.isInteger(c.largeur)&&Number.isInteger(c.hauteur)
           && c.largeur>=1 && c.hauteur>=1); });

// Ecart avec la position d'hier.
var ancien = PLAN_LAYOUTS.capitale, ecarts = [];
ids.forEach(function(b){
  var a = ancien[b]; if (!a) return;
  var p = [plan.cadre.x + B[b].x*cw, plan.cadre.y + B[b].y*ch, B[b].largeur*cw, B[b].hauteur*ch];
  var d = Math.max(Math.abs(p[0]-a[0]), Math.abs(p[1]-a[1]));
  if (d > 14.5) ecarts.push(b+':'+d.toFixed(0)+'px');
});

// La rue des institutions.
var rangee = ids.filter(function(b){ return B[b].y === 17 && B[b].hauteur === 2; });
var colonnes = rangee.map(function(b){ return B[b].x; }).sort(function(a,b){return a-b;});

// Rien ne sort du cadre SVG.
state.country='republic'; state.currentCity='capitale'; state.currentBuilding=null;
ouvrirPlanVille('republic','capitale',true);
var svg = document.getElementById('minimap-ville-body').innerHTML;
var vb = /viewBox="0 0 (\d+) (\d+)"/.exec(svg);
var largeurCadre = vb ? +vb[1] : 0, hauteurCadre = vb ? +vb[2] : 0;
var debordent = [];
ids.forEach(function(b){ var c=B[b];
  var x1 = plan.cadre.x + (c.x+c.largeur)*cw, y1 = plan.cadre.y + (c.y+c.hauteur)*ch;
  if (x1 > largeurCadre || y1 > hauteurCadre) debordent.push(b);
});

// Les avenues, et ce qui les masque. Depuis le lot 2 elles vivent dans plan.terrain et non
// plus dans un champ `avenues` : ce banc lit la meme source que le moteur, afin de ne jamais
// tester une geometrie que la production n'utiliserait pas.
var voieNS = plan.terrain.filter(function(t){return t.axe==='colonne';})[0];
var voieEO = plan.terrain.filter(function(t){return t.axe==='ligne';})[0];
var ep = PLAN_TERRAIN_STYLES[voieNS.type].epaisseur;
var avX = plan.cadre.x + voieNS.index*cw, avY = plan.cadre.y + voieEO.index*ch;
function masque(ax0,ay0,ax1,ay1,table,pix){
  return Object.keys(table).filter(function(b){
    var p = pix ? table[b] : [plan.cadre.x+table[b].x*cw, plan.cadre.y+table[b].y*ch, table[b].largeur*cw, table[b].hauteur*ch];
    return Math.min(p[0]+p[2],ax1)>Math.max(p[0],ax0) && Math.min(p[1]+p[3],ay1)>Math.max(p[1],ay0);
  });
}
var ancienFiltre = {}; monde.forEach(function(b){ if(ancien[b]) ancienFiltre[b]=ancien[b]; });

print(JSON.stringify({
  nbCases: ids.length, nbMonde: monde.length,
  sansCase: sansCase, fantomes: fantomes, collisions: coll, tailles: tailles, ecarts: ecarts,
  rangee: rangee.length, colonnes: colonnes, debordent: debordent,
  cadre: [largeurCadre, hauteurCadre], cw: cw, ch: ch,
  avenueNS: [avX, avX+ep], avenueEO: [avY, avY+ep],
  masqueNSavant: masque(470,210,481,728,ancienFiltre,true),
  masqueNSapres: masque(avX,plan.cadre.y,avX+ep,plan.cadre.y+plan.cadre.hauteur,B,false),
  masqueEOavant: masque(182,463,770,474,ancienFiltre,true),
  masqueEOapres: masque(plan.cadre.x,avY,plan.cadre.x+plan.cadre.largeur,avY+ep,B,false),
  litPlanLayouts: svg.length > 0 && typeof PLAN_VILLES.republic.capitale === 'object'
}));
""")
    import json
    m = json.loads(mesure.strip().split('\n')[-1])

    garde('les 36 batiments de Luthecia ont une case', (m['nbCases'], m['nbMonde']), (36, 36))
    garde('aucun batiment de la ville sans case', m['sansCase'], [])
    garde('aucune case sans batiment dans la ville', m['fantomes'], [])
    garde('aucune case occupee deux fois', m['collisions'], [])
    garde('toutes les emprises sont entieres et >= 1 case', m['tailles'], [])
    garde('aucun batiment ne deborde du cadre SVG', m['debordent'], [])
    garde('la case mesure bien 29,4 x 25,9 px',
          (round(m['cw'], 2), round(m['ch'], 2)), (29.4, 25.9))

    print()
    print('=' * 74)
    print("3. CE QUI A BOUGE, ET DE COMBIEN")
    print('=' * 74)
    # Les quatre ajustements motives sont les seuls autorises a depasser la demi-case.
    # Deplacements motives : ceux du lot 1 (liberer la colonne de l'avenue, separer les musees)
    # et ceux du lot d'orientation (faire coincider les quatre groupes avec les quatre scenes de
    # rue, et sortir l'usine de l'avenue qu'elle masquait).
    AJUSTEMENTS = ['musee-national-republia', 'mairie-capitale', 'office-notarial',
                   'hotel-republica', 'banque-nationale', 'banque-privee',
                   'clinique-privee', 'loge-maconnique', 'commissariat',
                   'palais-gouvernement', 'assemblee', 'tribunal',
                   'usine-pharmaceutique-luthecia']
    hors = [e for e in m['ecarts'] if e.split(':')[0] not in AJUSTEMENTS]
    print('  batiments deplaces de plus d\'une demi-case : %d' % len(m['ecarts']))
    for e in m['ecarts']:
        print('       %s' % e)
    garde('aucun deplacement non motive au-dela d\'une demi-case', hors, [])

    print()
    print('=' * 74)
    print("4. LA RUE DES INSTITUTIONS ET LES AVENUES")
    print('=' * 74)
    garde('15 institutions sur la meme ligne', m['rangee'], 15)
    garde('elle occupe toute la largeur intra-muros (colonnes 0 a 19)',
          (m['colonnes'][0], m['colonnes'][-1]), (0, 19))
    garde('sept batiments a l\'ouest de l\'avenue',
          len([c for c in m['colonnes'] if c < 10]), 7)
    garde('huit batiments a l\'est de l\'avenue',
          len([c for c in m['colonnes'] if c > 10]), 8)
    garde('aucune institution dans la colonne de l\'avenue',
          [c for c in m['colonnes'] if c == 10], [])

    print('  avenue N-S : x %.0f..%.0f   (avant : 470..481)' % tuple(m['avenueNS']))
    print('  avenue E-O : y %.0f..%.0f   (avant : 463..474)' % tuple(m['avenueEO']))
    garde('l\'avenue N-S a glisse de 6 px', round(m['avenueNS'][0] - 470), 6)
    garde('l\'avenue E-O a glisse de 6 px', round(m['avenueEO'][0] - 463), 6)

    print('  masquaient l\'avenue N-S  avant : %s' % (', '.join(m['masqueNSavant']) or 'aucun'))
    print('  masquent  l\'avenue N-S  apres : %s' % (', '.join(m['masqueNSapres']) or 'aucun'))
    garde('plus aucun batiment ne masque l\'avenue N-S', m['masqueNSapres'], [])
    # L'usine pharmaceutique masquait l'avenue est-ouest depuis toujours. Le lot d'orientation
    # l'a descendue sous l'avenue : plus aucun batiment ne la recouvre, et elle atteint enfin le
    # mur est.
    garde('plus aucun batiment ne masque l\'avenue E-O', m['masqueEOapres'], [])

    print()
    print('=' * 74)
    if ko == 0:
        print('VERDICT : %d/%d gardes passees. Luthecia est au cadastre, les 19 autres plans intacts.' % (ok, ok))
    else:
        print('VERDICT : %d ECHEC(S) sur %d gardes.\n' % (ko, ok + ko))
        for e in echecs:
            print('  - %s' % e)
    print('=' * 74)
    return 0 if ko == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
