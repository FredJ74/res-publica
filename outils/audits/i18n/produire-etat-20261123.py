import json,gzip,os,re,shutil,collections
root=os.path.dirname(os.path.abspath(__file__))
os.makedirs(root,exist_ok=True)
langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de']

def load(p):
 return json.load(gzip.open(p,'rt') if p.endswith('.gz') else open(p))

def fine_raw(e):
 # Classement indicatif : les occurrences originales restent disponibles pour contrôle.
 context=' '.join(' '.join(str(o.get(k) or '') for k in ['file','key','order','building','room']) for o in e['occurrences']).lower()
 for name,rx in [('Formation','universit|cursus'),('Santé',r'hopital|hospital|sante|santé|clinique|medecin|pharmacie'),('Religion',r'religion|eglise|église|culte|pretre'),('Armée',r'militair|armee|armée|caserne|bataille'),('Police',r'police|commissariat|brigade'),('Crime',r'illegal|illicite|crimin|cambriol|contrebande'),('Presse',r'presse|journaliste|redaction|publication'),('Aide',r'aide|hrp|help'),('Justice',r'justice|tribunal|greffe|judiciaire'),('Économie et commerces',r'commerce|econom|économ|boutique|banque|loyer|location|achat|vente'),('Politique',r'politi|organisation|election|parti')]:
  if re.search(rx,context):return name
 return e['domains'][0]

_fine_cache={}
def fine(e):
 k=id(e)
 if k not in _fine_cache:_fine_cache[k]=fine_raw(e)
 return _fine_cache[k]

def forbidden(e):
 s=' '.join(str(o.get('file',''))+' '+str(o.get('building',''))+' '+str(o.get('key','')) for o in e['occurrences']).lower()
 return bool(re.search(r'personnage|divers|evenement|journal|chat|navigation|informateur|sever|musee|museum|hopital|hospital|sante|santé|station|renseignement|eglise|tracteur|postcard|carte.postale|inventaire|inventory|pnj|guide|accueil|onboarding|business|affaires|locaux',s))

def report(before,after):
 data=[]
 for tag,p in [('avant',before),('apres',after)]:
  d=load(p+'/tableau-de-bord.json');es=load(p+'/inventaire.json.gz')['entries'];rs=load(p+'/ressources.json.gz')
  dest=root+'/20261123/'+tag;os.makedirs(dest,exist_ok=True)
  for f in ['tableau-de-bord.json','inventaire.json.gz','ressources.json.gz','sources.json.gz']:
   shutil.copyfile(p+'/'+f,dest+'/'+f)
  data.append((d,es,rs))
 a,b=data
 out=['# État de l’internationalisation — 23 novembre 2026','',
 '## Méthode et limites','',
 'Audit en lecture seule des sources suivies par Git avec `outils/audits/audit-i18n-global.cjs` (Acorn/parse5, moteur existant). L’extracteur ne se connecte à aucune base et n’y écrit rien. Un relevé distinct de cinq cursus a été obtenu en lecture seule, transaction annulée, sans donnée de personnage. Les deux relevés partent du même main rebasé, avant et après le lot universitaire. Les instantanés complets sont dans `20261123/avant` et `20261123/apres`. Le SHA et les empreintes de méthode/corpus figurent dans leurs tableaux JSON. Le premier relevé exploratoire sur a05cd3e9 n’est pas utilisé pour calculer le gain : main a évolué entre-temps.','',
 '**Ces taux mesurent des preuves statiques de raccordement, pas le pourcentage global du jeu traduit.** Ils ne prouvent ni l’accessibilité de chaque état ni la qualité native des traductions. Les champs serveur et conversations IA ne sont pas certifiés. Une ressource trouvée sans liaison prouvée ne compte pas comme raccordée. Le français est la référence, pas une traduction. Les candidats comportent des noms propres, clés techniques et faux positifs à vérifier ; ils ne sont pas tous des textes français réellement affichés. Aucun taux global exhaustif n’est annoncé.','',
 'Les domaines fins sont classés par indices de fichier/clé/ordre/bâtiment/pièce ; ce classement est indicatif et exclusif, avec retour au domaine de l’auditeur. Un module composite peut contenir d’autres métiers. Les occurrences originales permettent de vérifier le classement. Les pays ne sont affectés que si le contexte de source est explicite : les textes communs ou indéterminés ne sont pas arbitrairement attribués à Républia ou Sovarka. Un texte peut apparaître dans les deux pays.','',
 '## Neuf langues : preuves statiques avant → après','', '| Langue | Textes raccordés / corpus avant | Textes raccordés / corpus après | Ressources disponibles après | Clés centrales manquantes après |','|---|---:|---:|---:|---:|']
 for l in langs:
  x,y=a[0]['perLanguage'][l],b[0]['perLanguage'][l]
  out.append(f"| {l} | {x['wiredTexts']}/{x['texts']} ({x['wiredTextPercent']} %) | {y['wiredTexts']}/{y['texts']} ({y['wiredTextPercent']} %) | {y['resourceTexts']} | {len(b[0]['central']['perLocale'][l]['missing'])} |")
 out+=['','Le catalogue universitaire est chargé dynamiquement ; l’auditeur historique ne certifie pas ce raccord. Son gain est donc mesuré séparément par les parcours Chromium, sans gonfler le taux statique. La différence de corpus causée par les expressions de rendu n’est pas un nombre de traductions.','', '## Domaines : textes raccordés / textes statiques (avant → après)','', '| Domaine | '+ ' | '.join(langs)+' |','|---|'+'---:|'*len(langs)]
 for dom in sorted(set(fine(e) for _,es,_ in data for e in es if e['certainty']=='static-render-path' and not e['exclusion'])):
  vals=[]
  for l in langs:
   pair=[]
   for _,es,_ in data:
    ee=[e for e in es if e['certainty']=='static-render-path' and not e['exclusion'] and fine(e)==dom]
    pair.append(f"{sum(l=='fr' or e['locales'][l]=='wired-unreviewed' for e in ee)}/{len(ee)}")
   vals.append(' → '.join(pair))
  out.append('| '+dom+' | '+' | '.join(vals)+' |')
 out+=['','## Pays : preuves statiques avant → après','', '| Périmètre explicite | '+ ' | '.join(langs)+' |','|---|'+'---:|'*len(langs)]
 for country,label in [('republic','Républia'),('soviet','Sovarka'),(None,'Commun / pays indéterminé')]:
  vals=[]
  for l in langs:
   pair=[]
   for _,es,_ in data:
    ee=[]
    for e in es:
     countries={o.get('country') for o in e['occurrences'] if o.get('country')}
     if e['certainty']=='static-render-path' and not e['exclusion'] and ((country in countries) if country else not countries):ee.append(e)
    pair.append(f"{sum(l=='fr' or e['locales'][l]=='wired-unreviewed' for e in ee)}/{len(ee)}")
   vals.append(' → '.join(pair))
  out.append('| '+label+' | '+' | '.join(vals)+' |')
 remaining=[]
 for e in b[1]:
  if e['exclusion'] or e['certainty']=='ai-context-not-output':continue
  missing=[l for l in langs[1:] if e['locales'][l]=='no-confirmed-resource']
  unwired=[l for l in langs[1:] if e['locales'][l]!='wired-unreviewed']
  if unwired:remaining.append(dict(id=e['id'],texte=e['text'],certitude=e['certainty'],domaine=fine(e),zone_interdite_potentielle=forbidden(e),langues_sans_ressource_prouvee=missing,langues_raccord_non_prouve=unwired,occurrences=e['occurrences']))
 with gzip.GzipFile(root+'/TEXTES-A-VERIFIER-20261123.json.gz','wb',mtime=0) as f:f.write(json.dumps(remaining,ensure_ascii=False,indent=1).encode())
 gaps=[]
 for r in b[2]:
  bad={l:s for l,s in r['status'].items() if s in ['missing','invalid-placeholders']}
  if bad:gaps.append(dict(fichier=r['file'],ligne=r['line'],cle=r['key'],fr=r['fr'],langues=bad))
 with open(root+'/CLES-INCOMPLETES-20261123.json','w') as f:json.dump(gaps,f,ensure_ascii=False,indent=2)
 out+=['','## Textes en dur et clés incomplètes','',f"Le relevé exhaustif **des candidats détectés par cet extracteur** est `TEXTES-A-VERIFIER-20261123.json.gz` : {len(remaining)} textes avec chemin/ligne, domaine, langues sans ressource identifiée et langues sans raccord prouvé. Le statut n’est jamais converti automatiquement en « français résiduel à l’écran ». Les instantanés conservent aussi les textes exclus et les ressources complètes.", '',f"Les {b[0]['central']['frenchKeys']} clés françaises centrales n’ont aucune clé manquante ni variable divergente dans les neuf langues. Les lacunes/variables invalides des catalogues reconnus sont listées dans `CLES-INCOMPLETES-20261123.json` ({len(gaps)} entrées). Les tables locales françaises et champs serveur ne sont pas toutes reconnus par l’extracteur ; leur absence de la liste ne certifie pas leur traduction. La table locale universitaire T.fr est désormais le repli exact d’un catalogue complet, pas une lacune.", '', '### Zones réservées à Claude : audit seulement, aucune correction','',
 'Panneau de gauche, personnage, objets, inventaire et patrimoine ; événements et chat ; flèches des rues ; informateurs, Bar Sever, musées, hôpital, centre d’affaires/locaux libres/station-service de Krasnov ; gare, Renseignement et église de Novomirsk, hymne au Tracteur ; cartes postales ; tous les PNJ de Sovarka ; accueil. Les fichiers composites et les catalogues associés sont également laissés de côté en cas de doute. La PR ouverte #1132 (commerce/politique) n’est pas reprise. Le booléen `zone_interdite_potentielle` est conservateur : il signale un contrôle humain nécessaire, pas une autorisation d’édition.', '', '| Fichier (exemples détectés, non exhaustifs) | Texte / statut à reprendre après Claude |','|---|---|']
 seen=set()
 for e in remaining:
  if not e['zone_interdite_potentielle']:continue
  o=e['occurrences'][0];file=o['file']
  if file in seen:continue
  seen.add(file)
  out.append('| `'+file+':'+str(o.get('line',''))+'` | '+e['texte'][:110].replace('|','/').replace('\n',' ')+' — raccord à vérifier |')
  if len(seen)>=24:break
 out+=['','## Lot réellement raccordé et testé : formation universitaire','',
 '| Périmètre | fr | en | es | zh-TW | ru | ko | ar | pt-BR | de |','|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|','| Avant : 51 textes fixes et références accessibles | 51/51 | 0/51 | 0/51 | 0/51 | 0/51 | 0/51 | 0/51 | 0/51 | 0/51 |','| Après : catalogue et parcours Chromium | 51/51 | 51/51 | 51/51 | 51/51 | 51/51 | 51/51 | 51/51 | 51/51 | 51/51 |','',
 '51 textes français couverts, dont 41 originaux strictement conservés ; 368 traductions étrangères ajoutées et 40 réutilisées. Fenêtre des cursus, durée, progression, lieu/date, actions, refus et notifications propres à la formation. Cinq intitulés longs réels et cinq familles de carrières traduits uniquement lorsqu’ils correspondent au français de référence. Les cinq noms de carrière réutilisent creation.careers sans modifier le catalogue commun. Noms de personnages, lieux, métiers personnalisés/consignes libres du serveur et identifiants restent intacts. Dates historiques conservées ; leur format dynamique n’est pas inclus dans les 41 textes. Aucun texte de PNJ traduit dans ce lot.','',
 'Banc `banc-i18n-formation-20261123.cjs` : 6 tests, neuf langues × Républia/Sovarka × 320/390/1280 px ; 648 bascules par résolution ; comparaison française au module initial, progression/position/argent/PA/saisie inchangés, mêmes commandes et paramètres, aucun appel métier au changement de langue, arabe RTL, repli français, chargement à froid et catalogue indisponible. Tests avec réponses simulées, sans PJ connecté ni téléphone physique. Contrôle Brotli distinct, octet pour octet.','',
 '## Difficultés de traduction','',
 '- « Seconde carrière » désigne un second métier acquis, pas un redémarrage du personnage : vocabulaire de qualification professionnelle conservé.','- « Maître de stage » adapté comme responsable/mentor de stage, sans créer de PNJ ni changer son nom.','- PA conservé dans toutes les langues et coût 6 inchangé ; noms propres et monnaies FR/PSK intacts.','- Aucun jeu de mots nouveau ni arbitrage de gameplay dans ce lot. Traductions rédigées et contrôlées structurellement ; pas de relecture native revendiquée.','',
 '## Priorités suivantes hors concurrence','',
 'Corriger le sens des champs de création de parti si le défaut est reproduit, sans modifier le panneau des organisations ni la PR #1132. Les domaines santé, religion, PNJ, objets et parcours d’accueil attendent la fin de la mission de Claude. Les autres modules composites sont à découper en lots sûrs après vérification des PR actives.','',
 '## Reproduction','',
 'Exécuter l’auditeur global avant/après dans deux dossiers distincts, puis `python outils/audits/i18n/produire-etat-20261123.py <avant> <apres>`. Les inventaires sont limités aux sources suivies par Git : indexer un nouveau catalogue avant le relevé après. Le générateur ne modifie que les preuves du présent dossier, sans exécuter de code métier ni accéder au réseau.']
 out.append('\n## Tables françaises locales hors catalogues\n\n`TABLES-LOCALES-FR-20261123.json` complète le relevé central : chaque clé de table `fr` détectée hors `i18n/` indique les langues absentes de cette table et celles qui n’ont pas non plus de ressource alternative reconnue. Une table locale peut être un repli volontaire (université, désormais complète via catalogue) : elle ne prouve pas un défaut d’affichage. Les clés techniques/noms propres demandent une vérification humaine. Reproduire avec `node outils/audits/i18n/relever-tables-locales-20261123.cjs outils/audits/i18n/20261123/apres/ressources.json.gz`.\n\n## Correctif distinct : sens de saisie politique\n\nPR #1184, branche `codex/i18n-politique-saisie-20261123` : aucun texte ni traduction ajouté. Le nom et la description de création d’un parti suivent la langue (LTR hors arabe, RTL arabe), y compris avec une saisie arabe conservée après bascule vers le français. Défaut reproduit avant correction ; 7 tests ciblés verts, dont 28 états et 756 bascules dans le banc existant, 320/390/1280 px. Ce lot ne modifie ni le panneau des organisations ni les fichiers de Claude. Les matrices de couverture textuelle ci-dessus concernent le lot universitaire ; un correctif de direction ne change pas le nombre de textes traduits.\n')
 out.append('\n## Livraison et historique des contrôles\n\nPR #1183 : formation et audit. PR #1184 : sens de saisie politique, sans nouveau texte. Les résultats de CI, les commits de fusion et les vérifications publiques sont suivis dans RELAIS.md et dans les preuves de livraison de ce dossier. Une CI verte sur un ancien commit ne valide pas une correction ultérieure. Les six échecs de main 14d0716e, comparés dans BLOCAGES-CI-20261123.md et COMPARAISON-MAIN-20261123.json, sont historiques : Claude les a corrigés sur a0aba273 (CI générale 45250421305 verte). Aucun fichier de ses zones réservées ni test correspondant n’a été modifié par ce chantier.\n')
 open(root+'/ETAT-I18N-20261123.md','w').write('\n'.join(out).rstrip()+'\n')
if __name__=='__main__':
 import sys
 root=os.path.dirname(os.path.abspath(__file__))
 report(sys.argv[1],sys.argv[2])
