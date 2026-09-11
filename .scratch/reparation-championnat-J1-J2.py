#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RES PUBLICA -- Reparation ponctuelle du championnat (chantier "durabilite championnat").
Prepare le 5 septembre 2026. NON EXECUTE : dry-run par defaut, --execute obligatoire pour ecrire.

CE QUE FAIT CE SCRIPT (dans cet ordre, une seule fois) :
  1. Relit les deux publications forum legitimes (22 et 29 aout 2026) et en DECODE les 12
     resultats. Aucun score n'est saisi a la main : ils sont extraits du texte publie, puis
     verifies contre le calendrier deterministe regenere localement. Toute divergence = abandon.
  2. Reconstruit le blob de la saison 1 : J1 et J2 played=true avec leurs vrais scores, J3..J11
     intactes et non jouees.
  3. CREE la ligne canonique championnat id=2 avec ce blob (INSERT, jamais un PATCH).
  4. NEUTRALISE la ligne id=1 (phase='terminee', resultatsFinales=null) pour rendre inertes les
     anciens onglets clients, qui ont "id=eq.1" code en dur : leur verifierEtJouerJournees()
     sort immediatement sur phase==='terminee', leur avancerFootballLive() sort sur
     phase!=='reguliere', et leur doObserverMatch() ne relance rien (resultatsFinales==null).
     Ils ne peuvent donc plus ni jouer un match, ni publier sur le forum, ni creer de saison.

ORDRE DE DEPLOIEMENT IMPERATIF :
     ce script (--execute)  PUIS  deploiement du nouveau code.
  Dans l'autre sens, le nouveau code trouverait id=2 absente et creerait une saison NEUVE
  (comportement correct mais sans l'historique). Voir le rapport.

CE QUE CE SCRIPT NE FAIT PAS (volontairement, hors perimetre valide) :
  - aucune suppression de topic/post forum (voir "FORUM A REPARER" dans le rapport) ;
  - aucune modification de journal_editions ;
  - aucune fabrication d'evenements, de compositions, de blessures ou de statistiques.

CHAMPS NON RECUPERABLES -> valeur neutre explicite, jamais une fiction :
  - evenements   : []        (liste vide ; l'affichage du resume montre une chronologie vide.
                              Volontairement PAS omis : m.evenements absent ferait appeler
                              genererEvenementsMatch() a l'affichage, qui INVENTERAIT des buts.)
  - compositions : champ absent (aucun joueur licencie n'est demontrable pour ces journees)
  - live         : champ absent (ces journees sont anterieures au moteur live, c'est exact)
  - dateDebut    : horodatage de la publication de J1 (metadonnee informative uniquement --
                   depuis le chantier "calendrier dimanche 20h", dateDebut n'est plus jamais
                   une source de calendrier)
  - stadeFinaleClubId / stadesUtilises / palmares : valeurs actuellement en base conservees
                   telles quelles (les originales ont ete detruites par les reinitialisations).
"""

import json, sys, urllib.request, urllib.error, re

SUPABASE_URL = 'https://jxpwoosmmhohoihxpbuc.supabase.co'
# Cle anon publique, deja presente en clair dans supabase.js (cote client).
SUPABASE_ANON = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3'
                 'NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYw'
                 'MjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw')

LIGNE_LEGACY    = 1   # ancienne ligne, cible en dur des vieux bundles -> a neutraliser
LIGNE_CANONIQUE = 2   # nouvelle ligne canonique (CHAMPIONNAT_ROW_ID, supabase.js)

TOPIC_J1 = 'topic-1787374094940'   # 22 aout 2026 -- Journee 1, legitime
TOPIC_J2 = 'topic-1788027958858'   # 29 aout 2026 -- Journee 2, legitime

# Ordre EXACT de CLUBS_SPORTIFS (data.js). C'est lui qui rend genererCalendrierSaison()
# deterministe : toute regeneration produit le meme calendrier, ce qui est precisement ce qui
# rend la reconstruction possible.
CLUBS = ['olympique-luthecia', 'brise-mariannaise', 'cheminote-montrouge', 'rojos-cartel',
         'fronterizos-unidos', 'jaguares-selva', 'dynamo-novomirsk', 'spartak-sibirsk',
         'kolkhoze-ouvrier', 'nadi-al-madina', 'al-baraka-fc', 'sharq-al-nour']

NOMS_OFFICIELS = {
    'olympique-luthecia': 'Olympique de Luthécia',
    'brise-mariannaise': 'La Brise Mariannaise',
    'cheminote-montrouge': 'Union Cheminote de Montrouge',
    'rojos-cartel': 'Estudiantes de la Ciudad',
    'fronterizos-unidos': 'Atlético Puerto Negro',
    'jaguares-selva': 'Independiente de Villa Sangre',
    'dynamo-novomirsk': 'Dynamo Novomirsk',
    'spartak-sibirsk': 'Partizan de Starovka',
    'kolkhoze-ouvrier': 'Étoile Rouge de Krasnov',
    'nadi-al-madina': 'Shabab Al Madina',
    'al-baraka-fc': 'Oasis City FC',
    'sharq-al-nour': 'Al-Petrol United FC',
}

# Anciennes appellations (data.js avant le commit 58eea96 du 28 aout 2026) -- necessaires pour
# decoder la publication du 22 aout, anterieure au renommage.
ALIAS = {
    'Rojos del Cartel': 'rojos-cartel',
    'Fronterizos Unidos': 'fronterizos-unidos',
    'Jaguares de la Selva': 'jaguares-selva',
    'Spartak Sibirsk-9': 'spartak-sibirsk',
    'Kolkhoze Ouvrier FC': 'kolkhoze-ouvrier',
    'Nadi Al-Madina': 'nadi-al-madina',
    'Al-Baraka FC': 'al-baraka-fc',
    'Sharq Al-Nour': 'sharq-al-nour',
}
NOM_VERS_ID = {v: k for k, v in NOMS_OFFICIELS.items()}
NOM_VERS_ID.update(ALIAS)


def sb_get(chemin):
    req = urllib.request.Request(SUPABASE_URL + '/rest/v1/' + chemin,
                                 headers={'apikey': SUPABASE_ANON,
                                          'Authorization': 'Bearer ' + SUPABASE_ANON})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode('utf-8'))


def sb_ecrire(methode, chemin, corps):
    data = json.dumps(corps).encode('utf-8')
    req = urllib.request.Request(SUPABASE_URL + '/rest/v1/' + chemin, data=data, method=methode,
                                 headers={'apikey': SUPABASE_ANON,
                                          'Authorization': 'Bearer ' + SUPABASE_ANON,
                                          'Content-Type': 'application/json',
                                          'Prefer': 'return=representation'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode('utf-8') or '[]')


def generer_calendrier():
    """Port EXACT de genererCalendrierSaison() (plateau-organisations-quetes.js).
    Tour simple, methode du cercle : 12 clubs -> 11 journees de 6 matchs."""
    n = len(CLUBS)
    journees, arr = [], CLUBS[1:]
    for j in range(n - 1):
        matchs = []
        round_clubs = [CLUBS[0]] + arr
        inverse = (j % 2 == 1)
        for i in range(n // 2):
            home, away = round_clubs[i], round_clubs[n - 1 - i]
            if inverse:
                home, away = away, home
            matchs.append({'home': home, 'away': away, 'played': False,
                           'scoreHome': None, 'scoreAway': None, 'recit': None})
        journees.append({'numero': j + 1, 'matchs': matchs})
        arr = arr[1:] + arr[:1]
    return journees


# Les trois seules formes de recit produites par le moteur, dans leurs DEUX variantes :
#  - resolution instantanee (simulerMatch) : suffixe " devant son public" et point final ;
#  - moteur live (avancerFootballLive)     : ni suffixe, ni point final.
# La J1 du 22 aout vient de la 1re, la J2 du 29 aout de la 2nde -- il faut donc accepter les deux.
MOTIFS = [
    (re.compile(r"^(?P<w>.+?) s'impose (?P<a>\d+)-(?P<b>\d+) face à (?P<l>.+?)(?: devant son public)?\.?$"), 'domicile'),
    (re.compile(r"^(?P<w>.+?) s'impose (?P<a>\d+)-(?P<b>\d+) sur la pelouse de (?P<l>.+?)\.?$"), 'exterieur'),
    (re.compile(r"^Match nul (?P<a>\d+)-(?P<b>\d+) entre (?P<x>.+?) et (?P<y>.+?)\.?$"), 'nul'),
]


def decoder_ligne(ligne):
    """-> (homeId, awayId, scoreHome, scoreAway). Leve si la ligne n'est pas decodable."""
    ligne = ligne.strip()
    for motif, genre in MOTIFS:
        m = motif.match(ligne)
        if not m:
            continue
        if genre == 'nul':
            return (NOM_VERS_ID[m.group('x')], NOM_VERS_ID[m.group('y')],
                    int(m.group('a')), int(m.group('b')))
        if genre == 'domicile':   # le vainqueur recoit
            return (NOM_VERS_ID[m.group('w')], NOM_VERS_ID[m.group('l')],
                    int(m.group('a')), int(m.group('b')))
        # 'exterieur' : le vainqueur se deplace -> le perdant nomme est l'equipe a domicile
        return (NOM_VERS_ID[m.group('l')], NOM_VERS_ID[m.group('w')],
                int(m.group('b')), int(m.group('a')))
    raise ValueError('ligne non decodable : ' + ligne)


def lire_journee_forum(topic_id):
    posts = sb_get('forum_posts?topic_id=eq.%s&select=created_at,content' % topic_id)
    if not posts:
        raise SystemExit('ABANDON : aucun post pour ' + topic_id)
    contenu = posts[0]['content']
    lignes = [l for l in contenu.split('<br>') if l.strip()]
    if len(lignes) != 6:
        raise SystemExit('ABANDON : %d lignes au lieu de 6 pour %s' % (len(lignes), topic_id))
    return [decoder_ligne(l) for l in lignes], posts[0]['created_at']


def recit_officiel(home, away, sh, sa):
    """Meme phrase que simulerMatch(), rendue avec les noms OFFICIELS actuels.
    Ce n'est pas une invention : la phrase est entierement determinee par (home, away, score),
    seules les appellations obsoletes du texte d'origine sont remplacees."""
    h, a = NOMS_OFFICIELS[home], NOMS_OFFICIELS[away]
    if sh > sa:
        return "%s s'impose %d-%d face à %s devant son public." % (h, sh, sa, a)
    if sa > sh:
        return "%s s'impose %d-%d sur la pelouse de %s." % (a, sa, sh, h)
    return "Match nul %d-%d entre %s et %s." % (sh, sa, h, a)


def construire_blob(actuel):
    calendrier = generer_calendrier()
    resultats, horodatages = {}, {}
    for numero, topic in ((1, TOPIC_J1), (2, TOPIC_J2)):
        resultats[numero], horodatages[numero] = lire_journee_forum(topic)
        print('  J%d lue depuis le forum (%s)' % (numero, horodatages[numero]))
        if numero == 1:
            construire_blob.date_j1 = horodatages[numero]

    for numero in (1, 2):
        journee = calendrier[numero - 1]
        attendus = [(m['home'], m['away']) for m in journee['matchs']]
        lus = {(h, a): (sh, sa) for (h, a, sh, sa) in resultats[numero]}
        # VERIFICATION DURE : les affiches lues doivent etre EXACTEMENT celles du calendrier
        # deterministe. Sans cela on abandonne : mieux vaut ne rien reparer que reparer faux.
        if set(lus.keys()) != set(attendus):
            print('ABANDON : affiches J%d incoherentes' % numero)
            print('  calendrier :', sorted(attendus))
            print('  forum      :', sorted(lus.keys()))
            raise SystemExit(2)
        for m in journee['matchs']:
            sh, sa = lus[(m['home'], m['away'])]
            m['played'] = True
            m['scoreHome'] = sh
            m['scoreAway'] = sa
            m['recit'] = recit_officiel(m['home'], m['away'], sh, sa)
            m['evenements'] = []      # valeur neutre documentee -- jamais d'evenements inventes
        journee['notifie24h'] = True  # evite toute vague de convocations retroactive
        # Instant REEL de resolution (nouveau champ, voir avancerFootballLive) : ici l'horodatage
        # DEMONTRABLE de la publication forum de la journee. C'est aussi ce qui garantit que le
        # Journal ne re-couvrira pas ces journees : collecterFootball() ne retient que les
        # journees dont resolueLe tombe dans sa fenetre de 24h, et ces dates sont largement
        # anterieures a toute fenetre future.
        journee['resolueLe'] = horodatages[numero]

    return {
        'schemaVersion': 2,
        'numero': 1,
        # Metadonnee informative uniquement (jamais une source de calendrier depuis le chantier
        # "calendrier dimanche 20h") : horodatage de la publication de la vraie J1.
        'dateDebut': construire_blob.date_j1,
        # LOT K -- ancrage de reprise. J1 et J2 sont acquises ; la prochaine journee due est J3,
        # au prochain dimanche 20h Europe/Paris = 6 septembre 2026 20h00 (18h00 UTC).
        'ancrageDimanche': {'numero': 3, 'kickoffISO': '2026-09-06T18:00:00.000Z'},
        # Derniere resolution legitime = J2, le 29 aout 2026 -> semaine ISO 2026-W35.
        # Le dimanche 6 septembre appartient a 2026-W36 : le verrou hebdomadaire laisse donc
        # passer J3, sans avoir a affaiblir la regle.
        'derniereSemaineResolue': '2026-W35',
        'derniereJourneeResolueLe': '2026-08-29T18:25:59.116Z',
        'phase': 'reguliere',
        'calendrier': calendrier,
        # Non recuperables (detruits par les reinitialisations) : on conserve l'existant.
        'stadeFinaleClubId': actuel.get('stadeFinaleClubId', 'fronterizos-unidos'),
        'stadesUtilises': actuel.get('stadesUtilises', []),
        'resultatsFinales': None,
        'palmares': actuel.get('palmares', []),
    }


BLOB_NEUTRALISATION = {
    # Rend les anciens onglets totalement inertes. phase='terminee' -> leur
    # verifierEtJouerJournees() sort des la 2e ligne ; leur avancerFootballLive() sort sur
    # phase!=='reguliere'. resultatsFinales=null -> leur doObserverMatch() n'appelle PAS
    # demarrerNouvelleSaison() (la condition exige les deux). calendrier vide -> rien a jouer.
    'schemaVersion': 9999,   # ceinture et bretelles : superieur a tout client present et a venir
    'numero': 0, 'phase': 'terminee', 'calendrier': [], 'palmares': [],
    'resultatsFinales': None, 'stadeFinaleClubId': None, 'stadesUtilises': [],
    'ancrageDimanche': None, 'dateDebut': None,
    'OBSOLETE': ('Ligne abandonnee le 5 septembre 2026. Le championnat vit desormais en id=%d. '
                 'Cette ligne n existe que pour neutraliser les anciens onglets clients qui ont '
                 'id=eq.1 code en dur. Ne rien y ecrire, ne pas la supprimer.') % LIGNE_CANONIQUE,
}


def main():
    executer = '--execute' in sys.argv
    print('=== Reparation championnat J1/J2 — mode %s ===\n'
          % ('EXECUTION REELLE' if executer else 'DRY-RUN (aucune ecriture)'))

    lignes = sb_get('championnat?select=id,updated_at,data')
    par_id = {int(r['id']): r for r in lignes}
    print('Lignes championnat presentes : %s' % sorted(par_id))
    actuel = par_id.get(LIGNE_LEGACY, {}).get('data') or {}

    if LIGNE_CANONIQUE in par_id:
        print('\nABANDON : la ligne id=%d existe deja. Ce script est a usage unique ;'
              ' verifier son etat avant toute nouvelle tentative.' % LIGNE_CANONIQUE)
        return 1

    print('\nLecture des publications forum legitimes :')
    blob = construire_blob(actuel)

    print('\n--- Blob propose (id=%d) ---' % LIGNE_CANONIQUE)
    for cle in ('schemaVersion', 'numero', 'dateDebut', 'phase', 'ancrageDimanche',
                'derniereSemaineResolue', 'derniereJourneeResolueLe', 'stadeFinaleClubId'):
        print('  %-24s %s' % (cle, json.dumps(blob[cle], ensure_ascii=False)))
    for j in blob['calendrier']:
        joues = sum(1 for m in j['matchs'] if m['played'])
        etat = 'JOUEE' if joues == 6 else ('%d/6' % joues)
        print('  J%-2d %-6s %s' % (j['numero'], etat,
              '' if joues == 0 else ' | '.join('%s %d-%d %s' % (m['home'], m['scoreHome'],
                                                                m['scoreAway'], m['away'])
                                               for m in j['matchs'])))
    print('\n  Recits reconstruits (noms officiels) :')
    for j in blob['calendrier'][:2]:
        print('   Journee %d :' % j['numero'])
        for m in j['matchs']:
            print('     ' + m['recit'])

    with open('.scratch/championnat-blob-propose.json', 'w', encoding='utf-8') as f:
        json.dump(blob, f, ensure_ascii=False, indent=2)
    print('\n  Blob complet ecrit dans .scratch/championnat-blob-propose.json (fichier local).')

    if not executer:
        print('\nDRY-RUN : rien n a ete ecrit en production.')
        print('Pour executer reellement : python3 %s --execute' % sys.argv[0])
        return 0

    print('\n1/2 INSERT championnat id=%d ...' % LIGNE_CANONIQUE)
    sb_ecrire('POST', 'championnat', {'id': LIGNE_CANONIQUE, 'data': blob,
                                      'updated_at': '2026-08-29T18:25:59.116Z'})
    print('    OK')
    print('2/2 Neutralisation de championnat id=%d ...' % LIGNE_LEGACY)
    sb_ecrire('PATCH', 'championnat?id=eq.%d' % LIGNE_LEGACY,
              {'data': BLOB_NEUTRALISATION})
    print('    OK')
    print('\nTermine. Deployer MAINTENANT le nouveau code (qui lit id=%d).' % LIGNE_CANONIQUE)
    return 0


if __name__ == '__main__':
    sys.exit(main())
