# Audit des bâtiments de Montrouge et Port-Sainte-Marie par rapport au socle de Luthécia

*Claude, 1er novembre 2026. Branche `claude/audit-psm-montrouge-20261101`.*

Luthécia est la référence : ses bâtiments ont été repris un à un pendant la clôture du
31 octobre. Cet audit compare chaque bâtiment de Port-Sainte-Marie (PSM, `ville_a`) et de
Montrouge (`ville_b`) à son homologue de Luthécia, puis vérifie en production que ce que
l'écran propose peut réellement aboutir côté serveur.

**Outil reproductible** : `node outils/audits/auditer-socle-villes-republia.cjs` (tableau
complet des écarts, lecture seule). **Garde** : `outils/bancs/test-parcelles-republia-socle.mjs`
(jouée par la CI avec les autres `test-*.mjs`).

## Ce qui a été vérifié, sans défaut

- **Routage** : les 287 ordres de PSM et 322 de Montrouge ont chacun une route dans
  `plateau-router.js` ou dans `ordres_generiques` ; aucun ne tombe sur un refus serveur. Seul
  « Racheter l'usine » (usine principale de Montrouge) n'a pas de coût déclaré : il est grisé
  « Bientôt disponible », donc jamais payé.
- **Coûts** : tous les ordres payants des deux villes ont leur triplet (ordre, PA, FR) dans le
  miroir `ordres_couts` de la production.
- **Bâtiments identiques à Luthécia** : hôtels de ville, commissariats, entrepôts, centres
  commercial et artisanal, stades, loge, marché de Montrouge (mêmes ordres, mêmes coûts).
- **Caisses** : chaque bâtiment communal des deux villes a sa caisse (mairie, commissariat,
  dispensaire, entrepôt, hôtel, marché, stade, tribunal, subventions).
- **Référentiels serveur** : chaînes de production (pôle tabac-alcools, raffinerie), directions
  d'établissement, entrepôts, structures médicales, imprimeries, tracts : PSM et Montrouge y
  figurent.

## Défauts bloquants, corrigés dans ce chantier

1. **Les dix parcelles de PSM et Montrouge étaient introuvables.** `terrains_etat` ne contenait
   que les cinq lots de Luthécia : visiter, acheter (y compris pour la commune) répondait
   « ce terrain n'existe pas ». La migration `20261031234500_terrains_psm_montrouge_socle`
   pose leur état initial, au format des lots de Luthécia (l'occupation est tirée par le
   serveur à la première visite).
2. **Cinq parcelles sans surface** (les quatre de PSM, le lot 6 de Montrouge) : le serveur
   refusait l'achat (`prix_ou_surface_non_reference`). Décisions de Fred du 1er novembre :
   PSM à 1 500 m² et **12 FR/m², soit 18 000 FR** (au lieu de 3 500) ; lot 6 de Montrouge à
   **2 100 m², 25 200 FR**. `SURFACE_TERRAINS`, data.js et le référentiel sont alignés.
3. **Les lots de PSM ignoraient le parcours immobilier** : trois ordres anciens (achat, dépôt
   de permis, corruption du fonctionnaire), ni compromis, ni construction, ni lots, ni squatteurs.
   Toutes les parcelles reçoivent désormais le gabarit #135 de Luthécia, par une seule boucle.
4. **« Accélérer le chantier » sur les six lots de Montrouge** : bouton mort (refus systématique,
   empires non P2W). Retiré, comme à Luthécia.
5. **« Corrompre un fonctionnaire » (permis)** n'avait de bouton qu'à PSM, alors que la recette du
   29/10 l'attend partout et que le serveur le tient (`terrain_permis_corrompre`) : il rejoint le
   gabarit de toutes les parcelles, Luthécia comprise. Le dépôt de permis s'ouvre par
   « Construire » ; son coût reste déclaré (`ORDRE_DEPOSER_PERMIS`).
6. **Usines de PSM et Montrouge impossibles à approvisionner** : ni le pôle tabac-alcools ni la
   raffinerie ne proposaient « Vendre des matières à l'usine », seul moyen pour un joueur d'y
   faire entrer céréales, plantes ou pétrole. Le serveur (`vendre_matiere_a_usine`) les acceptait
   déjà par leurs chaînes : l'ordre est ajouté dans leurs salles de production.

## Écarts de placement : à arbitrer par Fred (non bloquants)

Les mécaniques existent et fonctionnent à Luthécia ; la question est de savoir si les villes
de province doivent les offrir aussi. Rien n'a été ajouté sans décision.

| Bâtiment (PSM et Montrouge) | Absent par rapport à Luthécia |
|---|---|
| Banque locale / Banque cheminote | **tranché le 01/11** : guichets de la Banque Nationale, mêmes procédures (compte, placements, prêt, virements ponctuels et automatiques) ; Helvetia seule garde un fonctionnement unique. Corrigé dans ce chantier (écran + migration `20261031235500`). Restent à Luthécia : coffre à louer et autorisation judiciaire (énigme du musée) |
| Dispensaire / Hôpital | **tranché le 01/11** : centre antipoison et transfert vers la clinique privée ajoutés, mêmes coûts et taux qu'à Luthécia (le transfert emmène le patient à la clinique de Luthécia). Dette commune aux trois villes : le jet de l'antipoison est encore tiré par l'écran (`Math.random`), à passer au serveur |
| Tribunal municipal | « Demander à parler à un juge » : **tranché le 01/11**, propre à l'énigme du musée de Luthécia, donc absent des autres villes ; à Luthécia il est désormais masqué hors enquête (et après l'autorisation du coffre), comme l'autorisation du coffre. « Falsifier un document » : conservé (portée en province à préciser) |
| Hôtel du Port / Hôtel de la Victoire | suite, dîner d'affaires, rumeurs, informateur, escort, tournée, service d'étage, local à louer |
| Centre multimodal / Gare | avion, douanes de l'aéroport, taxis caserne et QHS (sans doute voulu : l'aéroport est à la capitale) |
| Marché de PSM | pouls populaire |
| Musées | consulter les personnalités |
| Armurerie de Montrouge, Chasse et Pêche de PSM | marché noir |
| Centre d'affaires | embauche d'agents de sécurité privée (périmètre Codex, #135) |
| Rachat d'entreprise | Capitaine Sauvage et Hôtel du Port ne sont pas rachetables (pas de prix) |

## Autres constats

- Images encore provisoires (photos web) : PSM 6 pièces (bureaux de la mairie, pôle tabac,
  bureau de l'entrepôt), Montrouge 4 (siège syndical, usine principale, raffinerie, bureau du
  Vénérable) ; sans image : boxes du port (PSM), bureau du commissaire, quatre pièces du stade
  et zone de récolte (Montrouge).
- Le plan quadrillé de PSM reste incomplet (connu, voir la mémoire du projet).
- Un banc SQL annulé de la migration n'a pas pu être joué : le canal Supabase demande une
  confirmation humaine pour toute requête d'écriture, même annulée, et elle a expiré. À jouer
  avant l'application (la migration se vérifie elle-même et s'annule en cas d'écart).
