# Issue #871 — socle réutilisable des descriptions d’ordres

## Chemin existant et périmètre

`data.js` fournit l’ordre canonique. `renderRoomActions` dans
`plateau-politique.js` copie sa présentation, applique les devises/tarifs existants,
et conserve un descripteur `data-rp-tip`. Le résolveur de
`i18n/sovarka-infobulles-resources.js` construit l’infobulle et ses gains/risques.
`plateau-ordres-info.js` réutilise ce même descripteur sur tactile. Le clic d’ordre
reçoit toujours les arguments canoniques existants.

Le résolveur s’appelle désormais aussi `RPOrderDescriptionsI18n` ; l’ancien nom
`RPSovarkaInfobullesI18n` désigne **le même objet**, pour tous les consommateurs
existants. Aucun second moteur, aucun nouveau service, aucun pays créé.

## Ajouter un catalogue sans changer le moteur

La sélection initiale est déclarée dans `i18n/order-catalogues-config.js`, chargé
après les ressources et avant le résolveur. Un catalogue a un identifiant et soit
`shared: true`, soit une liste `countries`. Le commun est prioritaire ; un
catalogue national ne s’applique qu’à ses pays. Les anciens bancs/chargements sans
ce fichier disposent des trois déclarations historiques de compatibilité.

Un fichier de ressources supplémentaire peut ajouter une déclaration à
`RP_ORDER_DESCRIPTION_CATALOGUES` avant le chargement du résolveur, ou appeler
ensuite `RPOrderDescriptionsI18n.registerCatalogue`. Exemple de **fixture seulement** :

```js
RPOrderDescriptionsI18n.registerCatalogue({
  id: 'fixture-services',
  countries: ['fixture'],
  entries: [{
    id: 'orders.description.service.counter',
    fr: 'Description française originale.',
    en: 'Original English description.'
    // es, zh-TW, ru, ko, ar, pt-BR, de : ressources du contenu, pas du moteur.
  }]
});
```

Les entrées sont identifiées explicitement : leur ID ne dépend ni du français,
ni de leur position, ni de la ville. Une entrée absente, une langue vide, un pays
non autorisé ou un ID inconnu donnent le français original. Une configuration
malformée est refusée (`false`) sans modifier les catalogues déjà enregistrés.

## Migration progressive des identifiants

- Les matrices existantes à neuf colonnes sont conservées octet pour octet.
  `rows` les référence ; aucune de leurs huit traductions n’est recopiée.
- `keys` associe un nouvel ID stable à une source française existante : le premier
  alias livré est `orders.description.common.bar-menu`. Ce pont évite une
  migration massive de `data.js` ; **aucun ordre de production n’est modifié**.
- Un futur ordre peut fournir `descriptionKey`. Le renderer transporte cette
  seule métadonnée dans `data-rp-tip.q`, y compris les détails des ordres bloqués.
- Les anciennes données sans clé continuent leur correspondance française exacte.
- Pour un nouveau contenu, préférer `entries` avec l’ID directement dans la
  ressource. Lors d’une réécriture, conserver l’ID et faire relire les huit langues.
- Le libellé reste traité par `i18n/ordres.js`, qui sait déjà lire `i18nKey` et
  protéger les variantes ambiguës. Ne pas confondre cette clé avec `descriptionKey`.

Le français de la copie déjà adaptée au tarif national est toujours le repli de
`descOrdre`. Les remplacements existants de devise et de montant s’appliquent
après traduction. Prix, PA, rôles, effets, probabilités, handlers et RPC sont
inchangés ; le banc compare le renderer à main après retrait du seul champ `q`.

## Preuves et mesure

Les bancs simulent un troisième pays uniquement en mémoire : héritage du commun,
pas de fuite des catalogues nationaux, identifiants indépendants du texte/de l’ordre
des entrées, langue manquante, FR strict, tarifs, choix invalide et clic normal.
Chromium utilise le véritable renderer et le dialogue tactile à 320/390/1280 px,
neuf langues, arabe RTL, changements à chaud, brouillon et nœuds conservés.
Consultation et bascule gardent les mêmes PA/argent et zéro appel métier/réseau.

L’audit charge maintenant le fichier de configuration et reconnaît les nouvelles
entrées déclaratives à ID stable. Comparaison au même main `1163bad` avec le même
extracteur : **0 nouvelle traduction, 0 nouveau raccordement et 0 mot couvert**.
Ce lot pérennise l’architecture ; il ne prétend pas augmenter la couverture.
Les lots d’interface suivants doivent produire un progrès réel séparément mesuré.

## Ce qui reste distinct

Les gains/risques utilisent les cinq libellés du cadre et les valeurs existantes.
Les textes de fenêtres, refus, réponses serveur, noms de pièces, récits et dialogues
IA ne deviennent pas traduits parce qu’un catalogue de descriptions est enregistré.
Ils demandent leurs propres points de présentation dans i18next. Relecture native,
téléphone physique et visite avec personnage authentifié non exécutés ici.
