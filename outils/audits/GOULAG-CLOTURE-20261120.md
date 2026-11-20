# Goulag — clôture vérifiée le 20 novembre 2026

## Périmètre de cette reprise

Source réellement contrôlée : `e665c9b88f233394a83585066705d581378e1f74`.
Les PR étaient déjà fusionnées avant la reprise :

| PR | Fusion UTC | Commit de fusion |
| --- | --- | --- |
| #1020 moteur | 18/11/2026 00:17:23 | `f6eaab9fd07d2de2814fceb6de2925dc5b067754` |
| #1085 ordres internes | 18/11/2026 00:39:04 | `d0dfda48ae6f70182497c14e1fcf8ab51246e39d` |

Les deux commits sont ancêtres de la production contrôlée. Il n'y a plus de conflit à résoudre sur ces PR fermées. Aucun nouveau changement métier, image, bâtiment ou migration n'est introduit par cette reprise. La branche de Claude n'a pas été modifiée. La mise à jour présente ne concerne que le relais et les preuves ; aucune PR n'est fusionnée par cette reprise.

## Production : client déployé, serveur absent

Alias public `https://res-publica.vercel.app` : déploiement **`dpl_buRwCxTrBsT3F6KY4wWx3HxWxGif`**, **READY**, cible production, SHA `e665c9b88f233394a83585066705d581378e1f74`. Treize ressources publiques téléchargées en HTTP et comparées exactement aux sources (HTML hors éventuelle barre Vercel) : page, cinq modules goulag, six CSS, catalogue des descriptions. Empreintes dans `production-ressources.json`.

Supabase **relu uniquement par SELECT** : PostgreSQL 17.6 ; `sovarka_goulag_configuration`, `sovarka_goulag_registre`, `goulag_toundra_demarrer(text)`, `sovarka_goulag_juger(text,text)` et `sovarka_goulag_ouvert()` absents. Zéro relation publique nommée `sovarka_goulag_%` ou `goulag_%`. Le moteur n'est donc **ni installé ni activé**. Aucune migration, transaction DDL de production, modification de configuration, dépense ou manipulation de personnage effectuée.

## Tests exécutés pendant cette reprise

| Épreuve | Résultat |
| --- | --- |
| PostgreSQL 17.6 natif isolé — moteur | 33/33 |
| PostgreSQL — ordres internes actuels | 38/38 |
| PostgreSQL — moteur et quatre migrations internes, référence HEAD | 41/41 |
| PostgreSQL — contrats stricts, référence HEAD | 11/11 |
| Node — verrou, navigation, ordres | 29/29 |
| Commandes Node du workflow moteur, hors navigateurs déjà exécutés à part | Toutes réussies ; liste dans `node-workflow.json` |
| Chromium — moteur, ordres internes, raccord HEAD | 54 + 189 + 27 |
| WebKit — moteur, ordres internes, raccord HEAD | 54 + 189 + 27 |
| Catalogues Brotli | 86/86, restitution exacte |

PostgreSQL est compilé par `installer-postgresql17-local.sh`, sources officielles 17.6 épinglées ; clusters temporaires indépendants, fixtures représentatives, sans connexion Supabase. Admission judiciaire, habilitations et visites, confiscation/restitution, compteur au sommeil et libération, déplacements, toundra 7/10 jours, refuge, concurrence, rejeux, droits/RLS, retour arrière et maintien du verrou sont couverts par les bancs existants sans les modifier. Aucun contrat ignoré ou assoupli.

Les navigateurs réels couvrent neuf langues, arabe RTL, 320/390/1280 px, saisies, double clic et absence de dépense involontaire, avec **RPC simulées**. Le raccord utilise `GOULAG_1085_REF=HEAD`, donc les sources actuelles, en complément du contrôle à référence historique. WebKit a nécessité six bibliothèques Debian extraites dans le workspace puis reliées à son bundle ; `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1` évite uniquement le contrôle du cache système qui ne connaît pas ces bibliothèques. Le navigateur et toutes les assertions s'exécutent réellement. Les premiers échecs de préparation (cache npm, répertoire runtime Python, bibliothèques WebKit absentes) sont résolus par configuration locale, sans modification du jeu ni des tests.

## CI finale des PR

- #1020, tête `6ec04ea7a42b1793bf417eda895f26c030f3a3ba` : **70 SUCCESS, 2 CANCELLED, 1 SKIPPED**, aucun FAILURE. Workflow moteur réussi : [44203309926](https://github.com/FredJ74/res-publica/actions/runs/44203309926). Contrôle général réussi : [44203322179](https://github.com/FredJ74/res-publica/actions/runs/44203322179).
- #1085, tête `842ac1ac0be76a69a6ccf70dd6d0cb96b6e028c6` : **58 SUCCESS**, aucun FAILURE. Ordres internes : [44206641688](https://github.com/FredJ74/res-publica/actions/runs/44206641688). Contrôle général : [44206641244](https://github.com/FredJ74/res-publica/actions/runs/44206641244).

Ces états GitHub sont relevés directement pendant la reprise. Les deux exécutions annulées de #1020 ne sont pas présentées comme des réussites. Les vieux échecs mobiles des rapports du 17/11 ne décrivent pas les résultats finaux des PR. Les anciens conflits de manifeste et compteur tarifaire sont déjà résolus dans les arbres fusionnés.

## Limites et autorisations restantes

- Aucune recette avec PJ authentifié, GoTrue réel ou téléphone physique ; les tests sur fixtures ne certifient pas la production Supabase complète.
- Pas de nouvelle preview : la version déjà servie par l'alias public a été vérifiée en lecture seule, sans déploiement ni promotion durant cette reprise.
- **Installation des migrations puis activation : deux autorisations explicites distinctes de Fred restent nécessaires.** Garder le CHECK `active IS FALSE` et le verrou client. Les tests locaux ne constituent pas une autorisation.
- Aucun autre chantier engagé. Les quatre anciens arbitrages ne sont plus en attente : ils sont déjà consignés dans le document de game design. Aucun nouveau bonus, coût ou comportement inventé.

Les journaux et le relevé synthétique sont versionnés dans [`preuves-goulag-cloture-20261120/`](preuves-goulag-cloture-20261120/).
