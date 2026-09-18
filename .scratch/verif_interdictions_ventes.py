#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Garde-fou STATIQUE de la regle generale des interdictions (arbitrage du 11 septembre 2026) :
« une categorie interdite en vigueur bloque toute vente legale ou institutionnelle ; un circuit
illegal conserve la vente et la fait qualifier par le serveur ».

Le controle 3 recense AUTOMATIQUEMENT toute fonction client qui encaisse un paiement ET remet une
marchandise : chacune doit etre classee (legale controlee, illegale qualifiee, ou exclusion
justifiee). Un nouveau circuit de vente non classe fait echouer ce harness.
"""
import os
import re

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
resultats = []


def controle(titre, ok, detail=''):
    resultats.append(bool(ok))
    print("%s %-68s %s" % ("OK  " if ok else "ECHEC", titre, detail))


def lire(f):
    with open(os.path.join(RACINE, f), encoding='utf-8') as fh:
        return fh.read()


def sans_commentaires(src):
    return '\n'.join(l for l in src.split('\n') if not l.lstrip().startswith('//'))


def fonctions(src):
    res = {}
    bornes = [(m.group(2), m.start()) for m in re.finditer(r'^(async )?function (\w+)\(', src, re.M)]
    for i, (nom, deb) in enumerate(bornes):
        fin = bornes[i + 1][1] if i + 1 < len(bornes) else len(src)
        res[nom] = sans_commentaires(src[deb:fin])
    return res


SQL = lire('migration_assemblee_interdictions_ventes.sql')
ASS = lire('plateau-assemblee.js')
ILL = lire('plateau-actions-illegales-rumeurs.js')
CRON = lire('api/cron-minuit.js')

# 1. Correspondance serveur == CATEGORIES_INTERDICTION
i = ASS.find('const CATEGORIES_INTERDICTION'); j = ASS.find('};', i)
L = lambda s: sorted(re.findall(r"'(\w+)'", s))
cat_js = {m.group(1): (L(m.group(2)), L(m.group(3)), L(m.group(4))) for m in re.finditer(
    r"^\s{2}(\w+):\s+\{ label: '[^']*',\s*matieres: \[([^\]]*)\],\s*typesObjet: \[([^\]]*)\],\s*sousTypes: \[([^\]]*)\]", ASS[i:j], re.M)}
A = lambda s: L(s) if s.startswith('ARRAY') else []
cat_sql = {m.group(1): (A(m.group(2)), A(m.group(3)), A(m.group(4))) for m in re.finditer(
    r"\('(\w+)',\s+'[^']*',\s+(ARRAY\[[^\]]*\]|'\{\}'),\s+(ARRAY\[[^\]]*\]|'\{\}'),\s+(ARRAY\[[^\]]*\]|'\{\}')\)", SQL)}
controle('1. correspondance serveur identique a CATEGORIES_INTERDICTION', cat_js and cat_js == cat_sql, '%d categories' % len(cat_js))

# 2. Catalogue serveur des circuits illegaux == ARMES_CATALOGUE.republic + POISON_OBJETS
ac = ILL[ILL.find('const ARMES_CATALOGUE'):]; ac = ac[ac.find('republic: ['):ac.find('narco: [')]
armes_js = dict(re.findall(r"id: '(\w+)',\s*\n\s*name: '[^']*',\s*\n\s*type: '(\w+)'", ac))
armes_sql = dict(re.findall(r"\('armurerie_marche_noir', '(\w+)',\s+'\{\"type\":\"arme\",\"sousType\":\"(\w+)\"\}'", SQL))
po = ILL[ILL.find('const POISON_OBJETS'):]; po = po[:po.find('\n};')]
poisons_js = sorted(re.findall(r"^\s{2}(\w+):", po, re.M))
poisons_sql = sorted(re.findall(r"\('poison', '(\w+)'", SQL))
controle('2. catalogue illegal serveur identique aux catalogues du jeu', armes_js and armes_js == armes_sql and poisons_js == poisons_sql,
         'armes %s · poisons %s' % (armes_js, poisons_js))

# 3. Toute fonction qui encaisse ET remet une marchandise est classee
LEGAUX = {'confirmerAchatArme', 'confirmerAchatGilet', 'doObtenirExplosifsMilitaires', 'commanderProduitCommerce',
          'confirmerAcheterSels', 'doAcheterRelique', 'confirmerAchatEntrepot', 'confirmerVenteDirecteUsine',
          'confirmerAchatArmoireSouvenirs', 'confirmerAcheterCriee', 'acheterLotNonReclameeFret', 'confirmerAchatAccessoireClub'}
ILLEGAUX = {'confirmerAchatPoison'}
# Circuits DEJA illegaux avant toute loi, avec leur propre procedure : une loi n'y ouvre jamais de
# seconde procedure pour le meme acte (non-regression du doublon du 11 septembre 2026).
PREEXISTANTS = {'confirmerAchatArmeIllegal': 'achat_arme_illegal'}
EXCLUS = {
    'confirmerRecolte': 'production (recolte de sa propre parcelle), pas une vente -- §34',
    'confirmerAchatExplosifs': 'circuit illegal, type explosif hors de toute categorie',
    'doContrebandePort': 'circuit illegal, type contrebande hors de toute categorie',
    'confirmerImpression': 'service d\'imprimerie (document)', 'confirmerImprimerTractsElectoraux': 'service (tracts)',
    'confirmerImprimerTractsCalomnieux': 'service (tracts)', 'doImprimerClandestin': 'service (document)',
    'doImprimerLivre': 'service (livre)', 'doFalsifierDocs': 'service (faux document)', 'confirmerFalsification': 'service (faux document)',
    'reclamerObjetTrouve': 'restitution d\'un objet trouve, pas une vente', 'retirerDeCaisseFret': 'retrait de ses propres marchandises',
    'confirmerVolMateriaux': 'vol, pas une transaction', 'doAcheterEntreprise': 'acte officiel',
    'doPresenterAutorisationCoffre': 'recompense de quete', 'doEscortInfos': 'service (renseignement)',
    'confirmerFabriquerKompromat': 'service (document)', 'confirmerEscortPiege': 'service (document)',
}
PAY = re.compile(r"deduireCoutOrdre\(\{[^}]*cost|deduireCoutOrdre\(\{\s*pa\s*,\s*cost\s*\}|debiterFondsOrdinaires\(|state\.arg\s*-=|state\.liquide\s*-=|state\.arg\s*=\s*Math\.max\(0,\s*\(state\.arg|state\.arg\s*-\s*prix")
GIVE = re.compile(r"addToInventory\(|inventory\.push\(")
TOUTES = {}
for f in sorted(os.listdir(RACINE)):
    if f.startswith('plateau') and f.endswith('.js'):
        TOUTES.update(fonctions(lire(f)))
ventes = {n for n, c in TOUTES.items() if PAY.search(c) and GIVE.search(c)}
non_classees = sorted(ventes - LEGAUX - ILLEGAUX - set(PREEXISTANTS) - set(EXCLUS))
controle('3. chaque fonction qui encaisse et remet une marchandise est classee', not non_classees,
         ('%d fonctions : %d legales, %d illegales, %d illegale preexistante, %d exclusions justifiees' % (len(ventes), len(LEGAUX & ventes), len(ILLEGAUX & ventes), len(set(PREEXISTANTS) & ventes), len(set(EXCLUS) & ventes)))
         if not non_classees else 'non classees : %s' % non_classees)

# 4. Circuits legaux : controle serveur AVANT le premier debit
DEBIT = re.compile(r"deduireCoutOrdre\(|debiterFondsOrdinaires\(|state\.arg\s*-=|sbUpdate\('caisses_fret'")
fautifs = []
for n in sorted(LEGAUX):
    c = TOUTES.get(n, '')
    i_c = c.find('assembleeControlerVenteLegale(')
    d = DEBIT.search(c)
    if i_c < 0 or (d and d.start() < i_c):
        fautifs.append(n)
controle('4. circuits legaux : controle serveur avant le premier debit', not fautifs, str(fautifs) if fautifs else '%d circuits' % len(LEGAUX))

# 5. Guichets de rachat (joueur fournisseur) : controle avant tout mouvement
guichets = {n: TOUTES.get(n, '') for n in ('vendreMatiereCommerce', 'vendreMatierePremiereUsine')}
g_ok = all(c.find('assembleeControlerVenteLegale(') >= 0 and c.find('assembleeControlerVenteLegale(') < c.find('lot.qty -= qte') for c in guichets.values())
controle('5. guichets de rachat : controle avant tout mouvement', g_ok)

# 6. Circuits illegaux : vente conservee, qualification serveur APRES, jamais bloquee
i_ok = all('assembleeSignalerAchatIllegal(' in TOUTES.get(n, '') and 'assembleeControlerVenteLegale(' not in TOUTES.get(n, '')
           and TOUTES[n].find('assembleeSignalerAchatIllegal(') > TOUTES[n].find('inventory.push(') for n in ILLEGAUX)
controle('6. circuits illegaux : qualification serveur apres la vente, jamais bloques', i_ok)
p_ok = all(TOUTES.get(n) and 'assembleeSignalerAchatIllegal(' not in TOUTES[n] and 'assembleeControlerVenteLegale(' not in TOUTES[n]
           and ("acte: '%s'" % acte) in TOUTES[n] for n, acte in PREEXISTANTS.items())
controle('6 bis. illegal preexistant (marche noir d\'armes) : sa seule procedure, aucune seconde qualification', p_ok)

# 7. La decision est serveur : la primitive appelle assemblee_verifier_vente, fail-closed
prim = fonctions(ASS).get('assembleeControlerVenteLegale', '')
controle('7. primitive : decision serveur (verifier_vente), refus si injoignable',
         'sbAssembleeVerifierVente(' in prim and "if (!res) {" in prim and 'return false' in prim
         and 'assembleeInterdictionObjet' not in prim and 'assembleeInterdictionMatiere' not in prim)

# 8. Cron : ventes institutionnelles filtrees, fail-closed ; production et arrivages gratuits intacts
cron_f = fonctions(CRON)
filtres = all('matieresInterditesRepublia()' in cron_f.get(n, '') for n in ('livrerEntrepotsQuotidien', 'traiterAchatsInterUsinesQuotidien', 'traiterExportationsPortQuotidien'))
gratuits = all('matieresInterditesRepublia' not in cron_f.get(n, '') for n in ('produireUneChaine', 'genererArrivagePoissonCriee'))
fc = "if (!v || v.raison || !Array.isArray(v.interdits)) return null;" in cron_f.get('matieresInterditesRepublia', '')
controle('8. cron : livraisons/achats usine/exportations filtres, fail-closed', filtres and fc)
controle('8 bis. cron : production et arrivages gratuits non filtres (§34)', gratuits)

# 9. Fret : trigger serveur sur la transition de vente
controle('9. fret : trigger serveur sur a_vendre -> vendue', 'CREATE TRIGGER trg_assemblee_fret_vente_legale' in SQL
         and "OLD.statut = 'a_vendre' AND NEW.statut = 'vendue'" in SQL)

# 10. Non-retroactivite : entree en vigueur reelle ; aucune recherche retroactive de transactions
loi = re.search(r'FUNCTION public\.assemblee_loi_en_vigueur\(.*?\$\$(.*?)\$\$;', SQL, re.S).group(1)
controle('10. non-retroactivite : adoptee_ts <= instant, instant = now()',
         'p.adoptee_ts <= p_instant' in loi and SQL.count("assemblee_loi_en_vigueur(") >= 4
         and all(x in SQL for x in ("assemblee_loi_en_vigueur(p_country, t.val, now())", "assemblee_loi_en_vigueur(p_country, p_objet, now())")))

# 11. Verification publique fail-closed sur une entree invalide
vv = re.search(r'FUNCTION public\.assemblee_verifier_vente\(.*?\$\$(.*?)\$\$;', SQL, re.S).group(1)
controle('11. verifier_vente refuse une entree qui n\'est pas un tableau', "'objets_invalides'" in vv)

print()
print('%d controle(s), %d echec(s)' % (len(resultats), resultats.count(False)))
