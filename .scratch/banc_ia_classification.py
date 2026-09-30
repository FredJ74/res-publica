#!/usr/bin/env python3
# ===========================================================================
# BANC DE CLASSIFICATION DES ECHECS DU FOURNISSEUR IA (30 septembre 2026)
# ---------------------------------------------------------------------------
# POURQUOI IL EXTRAIT LE CODE AU LIEU D'EN GARDER UNE COPIE. Un banc qui
# embarque sa propre copie de la fonction continue de passer au vert apres
# qu'on a casse la vraie. Celui-ci lit donc classerEchecFournisseur DANS
# api/_deepseek.js a chaque execution : si la fonction change, le banc le voit.
#
# CE QU'IL PROUVE, et le piege qu'il garde ferme : ne JAMAIS conclure
# « credits epuises » depuis une erreur generique. Un 500, un 429, un delai
# depasse ou un code HTTP inconnu et muet ne sont pas un solde vide.
#
# LANCEMENT :  python3 .scratch/banc_ia_classification.py
# (JavaScriptCore via osascript : aucune dependance, node n'est pas requis.)
# ===========================================================================
import os, re, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(RACINE, 'api', '_deepseek.js')

source = open(SRC, encoding='utf-8').read()
debut = source.index('function classerEchecFournisseur')
fin = source.index('\nexport {', debut)
fonction = source[debut:fin]

TESTS = r"""
var R=[];
function essai(n, ok, d){ R.push((ok?'OK   ':'ECHEC')+' '+n+(d?' :: '+d:'')); }
function c(r){ return classerEchecFournisseur(r); }

// ---- LE PIEGE A GARDER FERME : une erreur generique n'est pas un solde vide.
var g = c({ok:false, http:500, detail:'Internal server error'});
essai("un 500 generique n'est PAS un solde epuise", g.cause==='panne_fournisseur' && !g.critique, g.cause);
var t = c({ok:false, erreur:'Délai dépassé.'});
essai("un delai depasse n'est pas critique", t.cause==='delai_depasse' && !t.critique, t.cause);
var l = c({ok:false, http:429, detail:'Rate limit'});
essai("un debit limite n'est pas critique", l.cause==='debit_limite' && !l.critique, l.cause);
var r = c({ok:false});
essai('aucun code HTTP : panne reseau, non critique', r.cause==='reseau' && !r.critique, r.cause);
var y = c({ok:false, http:418, detail:'teapot'});
essai("un code inconnu muet ne conclut PAS au solde epuise", y.cause==='autre' && !y.critique, y.cause);

// ---- CE QUI DOIT ETRE RECONNU COMME DEFINITIF (Seb Lex ne reviendra pas seul).
var s = c({ok:false, http:402, detail:'Insufficient Balance'});
essai("un 402 est un solde epuise, et c'est critique", s.cause==='credits_epuises' && s.critique, s.cause);
var a = c({ok:false, http:401, detail:'Authentication Fails'});
essai('un 401 est une authentification, critique', a.cause==='authentification' && a.critique, a.cause);
var k = c({ok:false, erreur:'Fournisseur non configuré.'});
essai('une cle absente est critique', k.cause==='cle_absente' && k.critique, k.cause);
var b = c({ok:false, http:403, detail:'quota exceeded for this billing account'});
essai('un 403 reste une authentification', b.cause==='authentification' && b.critique, b.cause);
var x = c({ok:false, http:418, detail:'insufficient balance on account'});
essai('un code inconnu QUI PARLE du solde est bien un solde epuise', x.cause==='credits_epuises' && x.critique, x.cause);

// ---- LES INVARIANTS DE FORME.
essai('un appel reussi ne produit aucune cause', c({ok:true})===null);
essai("le journal d'un solde epuise nomme explicitement le probleme",
  /SOLDE INSUFFISANT/.test(s.journal), s.journal);

R.push('BILAN '+R.filter(function(x){return x.indexOf('ECHEC')===0;}).length+' echec(s)');
R.join('\n');
"""

with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as f:
    f.write(fonction + TESTS)
    chemin = f.name
try:
    script = ('ObjC.import("Foundation"); var s=$.NSString'
              '.stringWithContentsOfFileEncodingError("%s",4,null).js;'
              ' try{ eval(s) }catch(e){ "ERREUR DU BANC: "+e.message }' % chemin)
    sortie = subprocess.run(['osascript', '-l', 'JavaScript', '-e', script],
                            capture_output=True, text=True)
    print(sortie.stdout.strip() or sortie.stderr.strip())
    sys.exit(0 if 'BILAN 0 echec' in sortie.stdout else 1)
finally:
    os.unlink(chemin)
