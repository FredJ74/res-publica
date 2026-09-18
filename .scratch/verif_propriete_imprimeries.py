# -*- coding: utf-8 -*-
"""Controle statique de l'architecture de propriete des trois imprimeries de Republia.

Verifie, sans reseau, ce qui est structurel : prix, identite location-scoped, absence de collision,
absence de caisse/stock dupliques dans `entreprises`, avertissement notarial present sur les DEUX
ecrans traverses avant confirmation, vente ouverte, et chaine de paiement de la cession (beneficiaire,
acompte deduit, remboursement integral sur refus, remparts anti-double-credit).
"""
import re
import subprocess
import sys

SRC = open('plateau-actions-illegales-rumeurs.js', encoding='utf-8').read()
echecs = []


def verifier(ok, texte, detail=''):
    print(('OK    ' if ok else 'ECHEC ') + texte + (('   [' + detail + ']') if detail else ''))
    if not ok:
        echecs.append(texte)


m = re.search(r'const PRIX_RACHAT_IMPRIMERIE = (\d+);', SRC)
verifier(m and m.group(1) == '180000', 'P1. prix de cession : 180 000 FR', m.group(1) if m else 'absent')

bloc = re.search(r'const IMPRIMERIES_RACHETABLES_REPUBLIA = \[(.*?)\];', SRC, re.S)
lieux = re.findall(r"\{ pays: '(\w+)', ville: '(\w+)',\s*buildingId: '([\w-]+)' \}", bloc.group(1) if bloc else '')
verifier(len(lieux) == 3 and all(l[0] == 'republic' for l in lieux),
         'P2. les trois imprimeries de Republia, et elles seules', str(lieux))

ids = ['imprimerie-%s-%s-%s' % l for l in lieux]
verifier(len(set(ids)) == 3, 'P3. identite location-scoped : trois identifiants distincts', ' | '.join(ids))
partages = [l for l in lieux if l[2] == 'la-tribune']
verifier(len(partages) == 2 and len(set('imprimerie-%s-%s-%s' % l for l in partages)) == 2,
         'P4. aucune collision entre Luthecia et Montrouge malgre le meme buildingId')

defaut = re.search(r'function defautImprimerie\(.*?\n\}', SRC, re.S).group(0)
verifier('caisse:' not in defaut and 'stockMatieres' not in defaut and 'stockBois' not in defaut,
         'P5. la ligne entreprises ne duplique ni caisse ni stock (source unique : batiments_etat)')
verifier("sousCle: 'imprimerie'" in defaut and 'batiments_etat' in defaut,
         'P6. la ligne entreprises pointe explicitement vers la source operationnelle')
verifier("proprietaire: 'PNJ'" in defaut, 'P7. bien initialement PNJ, donc rachetable par le pipeline existant')

verifier('getImprimeriesRachetables()' in SRC and
         re.search(r'return armureries\.concat\(getCommercesAlimentairesRachetables\(\)\)\.concat\(getImprimeriesRachetables\(\)\);', SRC) is not None,
         'P8. les imprimeries sont servies par le registre COMMUN (rachat, succession, gel, preemption)')

# L'avertissement doit precede le bouton, sur les deux ecrans.
for fonction, bouton, libelle in (
        ('doSignerCompromisEntreprise', 'Signer le compromis', 'compromis'),
        ('afficherRecapActeRachatEntreprise', 'traiterActeRachatEntreprise(window._candidatActeRachatEntrepriseAConfirmer', 'acte')):
    corps = re.search(r'function ' + fonction + r'\(.*?\n\}', SRC, re.S).group(0)
    i_avert = corps.find('def.avertissement')
    i_bouton = corps.find(bouton)
    verifier(i_avert >= 0 and i_bouton >= 0 and i_avert < i_bouton,
             'P9.%s avertissement notarial affiche AVANT le bouton de confirmation (%s)' % (libelle[0], libelle))

avert = re.search(r'function avertissementCessionImprimerie\(.*?\n\}', SRC, re.S).group(0)
verifier('La Tribune' in avert and 'rédaction' in avert and 'ne fait pas partie de la cession' in avert,
         'P10. texte exact pour Luthecia : la redaction de La Tribune est hors cession')
verifier('Aucune activité de presse' in avert,
         'P11. formulation equivalente pour Montrouge et Port-Sainte-Marie')

m = re.search(r'const IMPRIMERIES_RACHETABLES = (true|false);', SRC)
verifier(m and m.group(1) == 'true',
         'P12. vente OUVERTE (beneficiaire arbitre : caisse du Ministere des Finances)',
         'IMPRIMERIES_RACHETABLES=' + (m.group(1) if m else '?'))

# Le registre doit etre vide tant que la vente est fermee, et complet une fois ouverte : on le
# verifie par un vrai parse en basculant la constante sur une COPIE en memoire.
copie = SRC
prog = '''
var WORLD = { republic: { capitale: { buildings: ['la-tribune'], buildingContext: { 'la-tribune': { name: "L'Autruche Entravee" } } },
                          ville_a:  { buildings: ['imprimerie-librairie'] },
                          ville_b:  { buildings: ['la-tribune'], buildingContext: { 'la-tribune': { name: 'Le Cheminot Informe' } } } },
              narco: { capitale: { buildings: ['la-tribune'] } } };
var BUILDINGS = { 'la-tribune': { name: 'La Tribune' }, 'imprimerie-librairie': { name: 'Gutenberg' } };
var state = { country: 'republic' };
%CODE%
var r = getImprimeriesRachetables();
print(JSON.stringify(r.map(function (e) { return [e.id, e.prix, e.typeBien, !!e.avertissement]; })));
state.country = 'narco';
print(JSON.stringify(getImprimeriesRachetables().length));
'''
extraits = []
for nom in ('PRIX_RACHAT_IMPRIMERIE', 'IMPRIMERIES_RACHETABLES_REPUBLIA', 'IMPRIMERIES_RACHETABLES'):
    extraits.append(re.search(r'const ' + nom + r' = .*?;\n', copie, re.S).group(0))
for nom in ('getImprimerieId', 'avertissementCessionImprimerie', 'getImprimeriesRachetables'):
    extraits.append(re.search(r'function ' + nom + r'\(.*?\n\}\n', copie, re.S).group(0))
code = ''.join(extraits).replace('const ', 'var ')
r = subprocess.run(['/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc',
                    '-e', prog.replace('%CODE%', code)], capture_output=True, text=True)
lignes = (r.stdout or '').strip().split('\n')
verifier(len(lignes) == 2 and '"imprimerie-republic-capitale-la-tribune",180000' in lignes[0]
         and '"imprimerie-republic-ville_b-la-tribune",180000' in lignes[0]
         and '"imprimerie-republic-ville_a-imprimerie-librairie",180000' in lignes[0]
         and lignes[0].count('true') == 3,
         'P13. vente ouverte : 3 entrees a 180 000 FR, chacune avec son avertissement',
         lignes[0] if lignes else (r.stderr or '')[:120])
verifier(len(lignes) == 2 and lignes[1] == '0',
         'P14. aucune imprimerie etrangere proposee (registre limite a Republia)',
         lignes[1] if len(lignes) == 2 else '')


# ------------------------------------------------------------------ CHAINE DE PAIEMENT
cession = re.search(r'async function finaliserCessionImprimerie\(.*?\n\}\n', SRC, re.S).group(0)
acte = re.search(r'async function traiterActeRachatEntreprise\(.*?\n\}\n', SRC, re.S).group(0)

verifier("if (def.typeBien === 'imprimerie')" in acte and 'finaliserCessionImprimerie(def, data, solde, pa, cost)' in acte,
         'P15. seules les imprimeries empruntent le chemin dedie (armureries/commerces inchanges)')
verifier('const solde = def.prix - (data.acompte || 0);' in acte,
         'P16. acompte DEDUIT du prix : total paye = 180 000 FR, jamais 181 000')
verifier('getFondsDisponiblesOrdinaires' in cession and 'fondsDispo < solde + (cost || 0)' in cession,
         'P17. suffisance verifiee sur solde + frais d acte AVANT tout prelevement')
verifier('debiterFondsOrdinaires(solde)' in cession,
         'P18. debit par la primitive securisee (liquide + Banque nationale, jamais Helvetia)')
verifier('sbImprimerieCessionFinaliser(requete, nom, def.id, def.prix, state.day)' in cession,
         'P19. credit de la caisse et propriete confies a la RPC transactionnelle')
i_debit = cession.find('debiterFondsOrdinaires(solde)')
i_rpc = cession.find('sbImprimerieCessionFinaliser(requete')
verifier(0 < i_debit < i_rpc, 'P20. debit AVANT la RPC : jamais de propriete acquise sans paiement')
verifier('window._cessionImprimerieEnCours' in cession and cession.count('_cessionImprimerieEnCours') >= 3,
         'P21. verrou local anti-double-clic pose et relache (finally)')
verifier("('cession-' + def.id + '-' + (data.compromisAt || 0))" in cession and '[^A-Za-z0-9_-]' in cession,
         'P22. id de requete stable et valide : un rejeu ne credite pas deux fois')
# Remboursement integral sur chacune des trois issues negatives.
verifier(cession.count('crediterFondsOrdinaires(solde + (rRachat.montantPreleve || 0))') == 2
         and 'crediterFondsOrdinaires(rRachat.montantPreleve || 0)' in cession
         and cession.count('state.pa = (state.pa || 0) + (rRachat.paPreleves || 0)') == 3,
         'P23. refus ou echec = remboursement integral (solde + frais + PA), aucune propriete')
verifier("frais.proprietaire === nom" in cession and 'def.charger()' in cession,
         'P24. coupure reseau : la propriete est relue, jamais de remboursement a l aveugle')
verifier('imprimerie.caisse' not in cession and 'sbBatimentMouvementCaisse' not in cession
         and 'encaisserRecetteRedaction' not in cession and 'crediterCaisseRedaction' not in cession,
         'P25. ni la caisse de l imprimerie ni celle de la redaction ne sont touchees')

SQL = open('migration_cession_imprimerie.sql', encoding='utf-8').read()
verifier("v_caisse := v_pays || '_gouvernement-min_fin';" in SQL and 'CREATE TABLE' not in SQL,
         'P26. caisse existante du Ministere des Finances reutilisee, aucune caisse creee')
verifier('c_prix     constant numeric := 180000;' in SQL and 'p_prix IS DISTINCT FROM c_prix' in SQL,
         'P27. prix impose par le serveur : un client ne peut pas payer moins')
verifier('caisse_institution_mouvement(v_caisse, c_prix, true)' in SQL,
         'P28. credit atomique du montant exact, une seule fois, caisse exigee existante')
verifier('assemblee_requete_ouvrir(p_requete' in SQL and 'FOR UPDATE' in SQL
         and "v_data ->> 'proprietaire' IS DISTINCT FROM 'PNJ'" in SQL,
         'P29. idempotence + verrou de ligne + reverification du compromis cote serveur')
i_credit = SQL.find('caisse_institution_mouvement(v_caisse')
i_prop = SQL.find('UPDATE public.entreprises')
verifier(0 < i_credit < i_prop and 'caisse_etat_indisponible' in SQL,
         'P30. propriete inscrite dans la MEME transaction que le credit, apres lui')

print('\n%d controle(s), %d echec(s)' % (32, len(echecs)))
sys.exit(1 if echecs else 0)
