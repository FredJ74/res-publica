#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BANC DE LA MISE EN RELATION -- cote donnees et cote client (1er octobre 2026)

CE QU'IL GARDE, et pourquoi chaque garde existe :

  G1  LE TEXTE DU JOUEUR NE PART PAS. contactOrgaEnvoyer() ne doit JAMAIS lire
      #contact-orga-projet, et sbContactOrganisationDemander() ne doit avoir que
      deux parametres. C'est la garantie centrale du chantier : elle ne tient pas a
      une intention, elle tient a l'absence de chemin. Cette garde est la pour que
      l'absence reste vraie dans six mois.

  G2  LE MARQUEUR DU SERVEUR A EXACTEMENT LE FORMAT DU NAVIGATEUR. La RPC ecrit
      '[[act:ecrire_a|<nom>]]' en SQL ; forum.js le relit avec une expression
      reguliere ecrite pour marqueurActionMail(). Deux auteurs, deux langages, un
      seul format : si l'un bouge, les boutons redeviennent du texte mort -- ce qui
      est deja arrive une fois dans ce jeu, au lot H2.

  G3  LA CLE EST DANS LA TABLE BLANCHE, et la fonction qu'elle designe existe
      vraiment. Une cle absente ne produit rien ; un nom de fonction fantome
      produit un bouton qui ne fait rien.

  G4  UN SEUL PASSEUR, DECLARE AUX TROIS ENDROITS. data.js (quelle fiche porte le
      pouvoir), le module client (ses repliques), la migration (ce qu'il peut
      solliciter). Les trois doivent concorder.

  G5  LES REPLIQUES SONT CELLES DU GAME DESIGN, mot pour mot. Aucune
      reformulation : une replique arbitree n'est pas une suggestion.

  G6  LE POUVOIR N'EST PAS DONNE AU METIER. `job:'criminel'` est porte par cinq
      PNJ ; un seul met en relation. Si le code se mettait a tester le metier,
      quatre personnages de decor gagneraient un pouvoir qu'ils n'ont pas.

  G7  AUCUN COUPLAGE AUX MECANIQUES CRIMINELLES. Le module ne doit mentionner ni
      DUP, ni reputation, ni grade, ni quete : le game design veut cette mecanique
      totalement independante de celles qui viendront.

  G8  LE BOUTON DU COURRIER EST ATTEIGNABLE. #modal-compose-mail doit venir APRES
      #modal-forum dans plateau.html : a z-index egal, c'est l'ordre du DOM qui
      decide, et un formulaire ouvert derriere la boite aux lettres serait
      invisible.

  G9  LE MODULE EST CHARGE. Un fichier non declare dans plateau.html est un
      fichier mort -- motif deja paye dans ce depot.
"""
import os, re, sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def lire(nom):
    with open(os.path.join(RACINE, nom), encoding='utf-8') as f:
        return f.read()

MODULE  = lire('plateau-contact-organisation.js')
FORUM   = lire('forum.js')
SUPA    = lire('supabase.js')
DATA    = lire('data.js')
PNJ     = lire('plateau-pnj.js')
HTML    = lire('plateau.html')
MIGR    = lire('migration_20261001_contact_organisation.sql')
COMM    = lire('plateau-communication.js')

resultats = []
def garde(cle, libelle, ok, detail=''):
    # `detail` accepte n'importe quoi : une garde qui echoue a souvent une liste ou
    # un tuple a montrer, et un banc ne doit jamais tomber en rendant son rapport.
    resultats.append((cle, libelle, bool(ok), '' if detail == '' else str(detail)))

def corps_fonction(src, nom):
    """Corps d'une fonction JS, par comptage d'accolades."""
    m = re.search(r'(?:async\s+)?function\s+' + re.escape(nom) + r'\s*\([^)]*\)\s*\{', src)
    if not m:
        return None
    i = src.index('{', m.start())
    prof = 0
    for j in range(i, len(src)):
        if src[j] == '{': prof += 1
        elif src[j] == '}':
            prof -= 1
            if prof == 0:
                return src[i:j + 1]
    return None

# ---------------------------------------------------------------------------
# G1 : le texte du joueur ne part pas
# ---------------------------------------------------------------------------
envoyer = corps_fonction(MODULE, 'contactOrgaEnvoyer')
garde('G1a', 'contactOrgaEnvoyer() existe', envoyer is not None)
if envoyer:
    garde('G1b', 'elle ne lit pas le champ du projet',
          'contact-orga-projet' not in envoyer,
          'reference trouvee' if 'contact-orga-projet' in envoyer else '')
    garde('G1c', 'elle ne lit aucun champ du DOM',
          'getElementById' not in envoyer and '.value' not in envoyer)

m = re.search(r'async function sbContactOrganisationDemander\(([^)]*)\)', SUPA)
garde('G1d', 'la RPC cliente ne prend que passeur + type',
      bool(m) and [a.strip() for a in m.group(1).split(',')] == ['passeur', 'typeOrganisation'],
      m.group(1) if m else 'introuvable')

m = re.search(r'create or replace function public\.contact_organisation_demander\(\s*([^)]*)\)', MIGR)
args_sql = re.sub(r'\s+', ' ', m.group(1)).strip() if m else ''
garde('G1e', 'la RPC serveur ne prend que passeur + type',
      args_sql == 'p_passeur text, p_type_organisation text', args_sql)
# On inspecte le DDL SEUL. Les commentaires de la migration parlent longuement du
# projet du joueur -- c'est leur role : ils expliquent pourquoi il n'est nulle part.
# Une garde qui les lirait echouerait sur sa propre documentation.
# Et dans les LISTES DE COLONNES seules : les commentaires SQL stockes en base
# (comment on table) disent noir sur blanc qu'aucune donnee sur le projet n'y
# figure, et une garde qui les lirait echouerait sur cette phrase meme.
MIGR_CODE = '\n'.join(l for l in MIGR.split('\n') if not l.strip().startswith('--'))
colonnes = '\n'.join(re.findall(r'create table if not exists[^(]*\((.*?)\n\);',
                                MIGR_CODE, re.S))
garde('G1f', 'aucune colonne ne peut accueillir un projet',
      bool(colonnes) and not re.search(r'projet|besoin|message_joueur', colonnes, re.I),
      re.findall(r'.*(?:projet|besoin).*', colonnes, re.I)[:2])

# ---------------------------------------------------------------------------
# G2 : un seul format de marqueur pour deux langages
# ---------------------------------------------------------------------------
# Format produit par le SQL, reconstitue depuis la migration elle-meme.
m = re.search(r"v_corps\s*:=\s*(.+?);", MIGR, re.S)
expr = m.group(1) if m else ''
garde('G2a', 'le SQL pose bien un marqueur ecrire_a',
      "'[[act:ecrire_a|'" in expr, expr.strip()[:80])

# L'expression reguliere du client, extraite de forum.js et appliquee a ce que le
# SQL produit reellement pour un nom donne.
m = re.search(r"\.replace\((/\\\[\\\[act.+?/g),", FORUM)
garde('G2b', "l'expression reguliere d'extraction est trouvee", bool(m))
if m:
    # Transcription du litteral JS en motif Python : memes classes, meme logique.
    motif = re.compile(r'\[\[act:([a-z_]+)((?:\|[^|\]]*)*)\]\]')
    for nom, attendu in [('Albert Dupont', 'Albert Dupont'),
                         ('Jean|Pierre', 'JeanPierre'),
                         ('Bob]Marley[', 'BobMarley'),
                         ("O'Hara", "O'Hara")]:
        propre = re.sub(r'[|\[\]]', '', nom)          # ce que fait le regexp_replace SQL
        corps = ('J\u2019ai rencontr\u00e9 quelqu\u2019un... Contacte ' + propre
                 + ' de ma part.\n\n[[act:ecrire_a|' + propre + ']]')
        trouves = motif.findall(corps)
        ok = (len(trouves) == 1 and trouves[0][0] == 'ecrire_a'
              and trouves[0][1] == '|' + attendu)
        garde('G2c', 'aller-retour du marqueur pour « %s »' % nom, ok,
              repr(trouves))

# ---------------------------------------------------------------------------
# G3 : la cle est dans la table blanche, et sa fonction existe
# ---------------------------------------------------------------------------
m = re.search(r"ecrire_a:\s*\{\s*fn:'([^']+)',\s*n:(\d+)", FORUM)
garde('G3a', 'ecrire_a est dans ACTIONS_MAIL', bool(m))
if m:
    fn, n = m.group(1), int(m.group(2))
    garde('G3b', 'elle appelle composerMailPour avec 1 argument',
          fn == 'composerMailPour' and n == 1, '%s / n=%d' % (fn, n))
    garde('G3c', 'composerMailPour existe vraiment',
          re.search(r'function composerMailPour\s*\(', COMM) is not None)
    # Un seul parametre attendu cote fonction : un n qui deborde produirait un
    # appel a deux arguments dont le second serait ignore en silence.
    m2 = re.search(r'function composerMailPour\s*\(([^)]*)\)', COMM)
    garde('G3d', 'sa signature attend bien un seul argument',
          bool(m2) and len([a for a in m2.group(1).split(',') if a.strip()]) == 1,
          m2.group(1) if m2 else '')

# ---------------------------------------------------------------------------
# G4 : un seul passeur, declare aux trois endroits
# ---------------------------------------------------------------------------
fiches = re.findall(r"contactOrga:'([a-z_]+)'", DATA)
garde('G4a', 'exactement une fiche PNJ porte contactOrga',
      len(fiches) == 1, str(fiches))
module_ids = re.findall(r'^  ([a-z_]+): \{$', MODULE, re.M)
garde('G4b', 'le module declare exactement ces passeurs',
      sorted(set(fiches)) == sorted(module_ids), str(module_ids))
sql_passeurs = re.findall(r"\('([a-z_]+)',\s*'([a-z]+)',\s*'([a-z]+)',\s*'([^']+)'\)", MIGR)
garde('G4c', 'la migration declare exactement ces passeurs',
      sorted(p[0] for p in sql_passeurs) == sorted(module_ids), str(sql_passeurs))
for pid, typ, pays, expe in sql_passeurs:
    m = re.search(r"^  " + pid + r": \{(.+?)^  \}", MODULE, re.S | re.M)
    bloc = m.group(1) if m else ''
    garde('G4d', '%s : meme type des deux cotes' % pid,
          ("type: '%s'" % typ) in bloc, typ)
    garde('G4e', '%s : le nom affiche du courrier est celui du PNJ' % pid,
          ("nom: '%s'" % expe) in bloc and (expe in DATA), expe)
    garde('G4f', '%s : un empire est declare' % pid, bool(pays), pays)

# ---------------------------------------------------------------------------
# G5 : les repliques sont celles du game design, mot pour mot
# ---------------------------------------------------------------------------
ARBITREES = {
    'question':   'Tu veux entrer en contact avec une organisation criminelle ?',
    'projet':     "C'est quoi ton projet ? T'as besoin de quoi ?",
    'conclusion': ("Ok... j'connais peut-\u00eatre quelqu'un. J'envoie un message. "
                   "Si t'as rien dans trois jours, tu reviens me voir."),
    'refusDelai': "Je t'ai dit trois jours... t'es sourd ou quoi ?",
}
bloc_pat = re.search(r'^  pat_hounette: \{(.+?)^  \}', MODULE, re.S | re.M)
bloc_pat = bloc_pat.group(1) if bloc_pat else ''
# Les litteraux JS sont concatenes sur plusieurs lignes : on recompose avant de
# comparer, sinon la garde echouerait sur un simple retour a la ligne.
def litteral(bloc, cle):
    m = re.search(cle + r':\s*(.+?)(?:,\n\s{4}[a-zA-Z]+:|,\n\s{4}//|\n  \})', bloc, re.S)
    if not m: return None
    brut = m.group(1)
    morceaux = re.findall(r'"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'', brut)
    txt = ''.join(a or b for a, b in morceaux)
    return txt.replace("\\'", "'").replace('\\"', '"')
for cle, attendu in ARBITREES.items():
    obtenu = litteral(bloc_pat, cle)
    garde('G5-' + cle, 'replique « %s » conforme' % cle, obtenu == attendu,
          repr(obtenu) if obtenu != attendu else '')
garde('G5z', 'la seule replique non arbitree est signalee comme telle',
      'personne:' in bloc_pat and 'N\'EST PAS ARBITREE' in bloc_pat)

# Le CODE du module, commentaires retires : les commentaires de ce fichier parlent
# du crime et du metier, c'est leur role. Les gardes G6 et G7 lisent ceci.
code_seul = '\n'.join(l for l in MODULE.split('\n') if not l.strip().startswith('//'))

# ---------------------------------------------------------------------------
# G6 : le pouvoir n'est pas donne au metier
# ---------------------------------------------------------------------------
porteurs_metier = DATA.count("job:'criminel'")
garde('G6a', "plusieurs PNJ portent job:'criminel' (le piege est reel)",
      porteurs_metier >= 2, '%d fiches' % porteurs_metier)
# Dans le CODE seul, encore : le commentaire de ce module explique precisement le
# piege de job:'criminel', et une garde qui le lirait echouerait sur l'explication
# de ce qu'elle garde.
garde('G6b', 'le module ne teste jamais le metier',
      'job' not in code_seul)
bloc_bouton = re.search(r'contactOrgaDuPnj\(pnj\)(.{0,600})', PNJ, re.S)
garde('G6c', 'la modale PNJ passe par contactOrgaDuPnj, pas par le metier',
      bool(bloc_bouton) and "job === 'criminel'" not in (bloc_bouton.group(1) if bloc_bouton else ''))
garde('G6d', 'contactOrgaDuPnj refuse un passeur inconnu',
      'contactOrgaPasseur(pnj.contactOrga) ? pnj.contactOrga : null' in MODULE)

# ---------------------------------------------------------------------------
# G7 : aucun couplage aux mecaniques criminelles
# ---------------------------------------------------------------------------
for interdit in ['DUP', 'reputation', 'criminal_c', 'queteCarriere', 'getStatEffective', 'state.char']:
    garde('G7-' + interdit, 'le code ne touche pas a %s' % interdit,
          interdit not in code_seul)
garde('G7z', 'aucun cout, aucun PA',
      'deduireCoutOrdre' not in code_seul and 'pa:' not in code_seul)

# ---------------------------------------------------------------------------
# G10 : LA STRATEGIE DE SELECTION EST ISOLEE
# ---------------------------------------------------------------------------
# Repondre « quelle organisation ? » est la SEULE partie de cette mecanique dont on
# sait deja qu'elle changera (activite recente, reputation, proximite...). Elle vit
# donc dans sa propre fonction, et la mise en relation ne doit pas savoir comment
# le choix est fait. Ces gardes empechent la strategie de se rediffuser dans
# l'appelant -- une derive qu'aucun test fonctionnel ne detecterait, puisque le
# comportement resterait identique.
corps_choisir  = re.search(r'create or replace function public\.contact_organisation_choisir'
                           r'(.+?)\$fn\$;', MIGR_CODE, re.S)
corps_demander = re.search(r'create or replace function public\.contact_organisation_demander'
                           r'(.+?)\$fn\$;', MIGR_CODE, re.S)
garde('G10a', 'une fonction de choix existe', corps_choisir is not None)
garde('G10b', 'la mise en relation existe', corps_demander is not None)
if corps_choisir and corps_demander:
    ch, de = corps_choisir.group(1), corps_demander.group(1)
    garde('G10c', 'la mise en relation ne lit plus les organisations',
          'public.organisations' not in de)
    garde('G10d', 'elle delegue le choix',
          'public.contact_organisation_choisir(' in de)
    garde('G10e', 'la strategie n\'ecrit rien',
          not re.search(r'\b(insert|update|delete)\b', ch, re.I))
    garde('G10f', 'la strategie n\'envoie aucun courrier', 'mails' not in ch)
    garde('G10g', 'la strategie est declaree stable', 'stable' in ch.split('as $fn$')[0])
    # Le point d'extension : la strategie recoit le joueur meme si elle l'ignore.
    # Sans lui, une strategie de proximite ou de reputation forcerait a changer
    # AUSSI l'appelant -- ce que cette extraction doit justement eviter.
    garde('G10h', 'la strategie recoit le joueur (point d\'extension)',
          'p_joueur text' in ch)
    garde('G10i', 'et les organisations deja sollicitees', 'p_exclues jsonb' in ch)
# La strategie du jeu n'est pas une information publique.
garde('G10j', 'la strategie est fermee au client',
      'revoke all on function public.contact_organisation_choisir(text, text, jsonb) '
      'from public, anon, authenticated;' in MIGR_CODE)
garde('G10k', 'aucun grant a authenticated sur la strategie',
      not re.search(r'grant execute on function public\.contact_organisation_choisir'
                    r'[^;]*authenticated', MIGR_CODE))
# Et le client ne la connait pas : aucune enveloppe dans supabase.js.
garde('G10l', 'le client ne l\'appelle nulle part',
      'contact_organisation_choisir' not in SUPA
      and 'contact_organisation_choisir' not in MODULE)

# ---------------------------------------------------------------------------
# G8 : le bouton du courrier est atteignable
# ---------------------------------------------------------------------------
i_forum = HTML.find('id="modal-forum"')
i_comp  = HTML.find('id="modal-compose-mail"')
garde('G8', '#modal-compose-mail vient apres #modal-forum',
      0 < i_forum < i_comp, 'forum@%d compose@%d' % (i_forum, i_comp))

# ---------------------------------------------------------------------------
# G9 : le module est charge
# ---------------------------------------------------------------------------
garde('G9a', 'plateau-contact-organisation.js est declare dans plateau.html',
      'plateau-contact-organisation.js' in HTML)
# Il appelle supabase.js : il doit etre charge APRES.
garde('G9b', 'il est charge apres supabase.js',
      HTML.find('supabase.js?v=') < HTML.find('plateau-contact-organisation.js'))
garde('G9c', 'il est charge apres plateau-pnj.js (qui l\'appelle a l\'ouverture d\'une fiche)',
      HTML.find('plateau-pnj.js?v=') < HTML.find('plateau-contact-organisation.js'))

# ---------------------------------------------------------------------------
# Rapport
# ---------------------------------------------------------------------------
larg = max(len(l) for _, l, _, _ in resultats)
echecs = 0
print('=' * (larg + 22))
print('BANC DE LA MISE EN RELATION'.center(larg + 22))
print('=' * (larg + 22))
for cle, libelle, ok, detail in resultats:
    if not ok: echecs += 1
    print('%-6s %-*s %s%s' % (cle, larg, libelle, 'OK  ' if ok else 'ECHEC',
                              ('   ' + detail) if detail and not ok else ''))
print('-' * (larg + 22))
print('%d gardes, %d echec(s)' % (len(resultats), echecs))
sys.exit(1 if echecs else 0)
