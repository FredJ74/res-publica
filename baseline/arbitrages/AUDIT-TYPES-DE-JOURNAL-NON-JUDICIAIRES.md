# Audit — les types de journal non judiciaires

**13 octobre 2026. RAPPORT SEUL**, conformément au cahier des charges de la tranche : ne
modifier que si une faille d'autorité **incontestable** apparaît. Aucune n'a été trouvée dans
le périmètre de ce document, **une seule** correction y est consignée, et elle a été faite le
jour même parce qu'elle était un défaut technique non ambigu (§4).

Mesures prises en base et dans le dépôt le 13 octobre 2026.

---

## 1. La règle d'écriture, exactement

`public.chronique_nationale` porte **deux** policies, et c'est tout :

```
chronique_nationale_lecture_publique   SELECT  TO public         USING (true)
chronique_nationale_ecriture_acteur    INSERT  TO authenticated
      WITH CHECK (acteur_identifie() AND (NOT fait_judiciaire_declare(type)))
```

La lecture est **publique** — c'est le journal national, il est public par nature. L'écriture est
ouverte à **tout compte authentifié**, pour tout type qui **n'est pas** un fait judiciaire
déclaré. `fait_judiciaire_declare(type)` est une porte `SECURITY DEFINER` qui interroge le
registre `justice_faits_publics` : la liste des types protégés est donc **une donnée**, pas une
condition écrite dans la policy, et elle grandit d'elle-même quand le registre grandit.

**Ce que cela garantit, et c'est mesuré par un banc** (`banc-parcours-judiciaires`, épreuve F6) :
un joueur **ne peut pas** forger `justice_condamnation` au journal, et il **peut** insérer un
fait ordinaire comme `nomination`.

## 2. Les cinq portes serveur appelables par le navigateur

Cinq fonctions `SECURITY DEFINER` écrivent dans `chronique_nationale` et sont appelables par un
client. **Aucune ne laisse choisir le type** : chacune l'écrit en dur dans son corps.

| porte | type écrit | ce qu'elle publie |
|---|---|---|
| `assemblee_rappeler` | `assemblee_rappel` | le Président de l'Assemblée a rappelé un député au règlement |
| `assemblee_sanctionner` | `assemblee_sanction` | il l'a sanctionné |
| `communication_officielle_publier` | `conference_presse` | une conférence de presse a été tenue |
| `fuite_publier` | `fuite_journalistique` | une fuite a été publiée |
| `scandale_publier` | `scandale_presse` | une accusation a été publiée |

Trois autres écrivent aussi, mais **ne sont pas appelables par un client** :
`assemblee_presidence_depouiller` (`assemblee_presidence`), `election_resultats_consigner`, et
`dossiers_actes_publier_au_journal` — le déclencheur qui publie les faits judiciaires depuis le
registre.

**Le point de vigilance vérifié, et il est clos.** `election_resultats_consigner` est la **seule**
fonction du schéma dont le `type` vient d'un **paramètre** (`p_chronique ->> 'type'`) : elle
pourrait donc écrire n'importe quel type, y compris judiciaire, en contournant la policy puisque
`SECURITY DEFINER` s'exécute avec les droits du propriétaire. **Elle n'est accordée ni à `anon`
ni à `authenticated`** — mesure faite sur `information_schema.routine_privileges` : zéro droit
client. Elle n'est appelée que par le cron, avec la clé de service. Il n'y a donc **pas** d'usurpation
possible par ce chemin, et c'est la raison pour laquelle ce document ne touche à rien.

## 3. Les dix-huit types non judiciaires, et qui les produit

`TYPES_CHRONIQUE` (`api/_journal-collecte.js`) est une **liste blanche de 31 types**, dont 13
judiciaires. Les dix-huit autres, avec leur domaine éditorial et leur écrivain réel :

| type | domaine | écrit par |
|---|---|---|
| `nomination` | politique | navigateur (`plateau-politique.js`, 4 sites) |
| `election_resultat` | politique | serveur (`api/cron-minuit.js`) |
| `scrutin_assemblee` | politique | serveur (`api/cron-assemblee.js`) |
| `assemblee_presidence` | politique | porte serveur, non cliente |
| `assemblee_rappel` | politique | porte serveur cliente, type en dur |
| `assemblee_sanction` | politique | porte serveur cliente, type en dur |
| `conference_presse` | politique | porte serveur cliente, type en dur |
| `fraude_electorale_dejouee` | politique | navigateur (`plateau-politique.js`) |
| `fraude_electorale_revelee` | politique | navigateur (`plateau-politique.js`) |
| `greve_ordinaire_debut` | grève ordinaire | navigateur (`plateau-organisations-quetes.js`) |
| `greve_ordinaire_fin` | grève ordinaire | navigateur (idem) |
| `organisation_dissolution` | organisations | navigateur (organisations, gouvernement) |
| `organisation_rehabilitation` | organisations | navigateur (`plateau-gouvernement.js`) |
| `organisation_chef_change` | organisations | navigateur (organisations) |
| `entreprise_rachat` | économie | navigateur (`plateau-actions-illegales-rumeurs.js`) |
| `subvention_publique` | économie | navigateur (`plateau-politique.js`) |
| `lobbying_article_favorable` | presse | navigateur (`plateau-pnj.js`) |
| `fuite_journalistique` / `scandale_presse` | presse | portes serveur, types en dur |

**Onze types sur dix-huit sont écrits par le navigateur**, par la fonction générique
`sbEnregistrerEvenementPublic(country, type, options)` : le type, le pays, le libellé et la liste
des personnages nommés viennent tous du client. Un joueur déterminé peut donc écrire au journal
un libellé de son choix sous un de ces onze types — par exemple une fausse nomination.

### Est-ce une faille incontestable ? Non, et voici sur quoi repose ce jugement

1. **Aucun de ces onze types ne porte une qualité judiciaire.** Le verrou qui compte — personne
   ne forge une condamnation, un non-lieu, une relaxe ou un appel — tient, et il tient par une
   donnée (`justice_faits_publics`) et non par une liste figée dans une policy.
2. **La presse ne reprend que ce qu'elle connaît.** `TYPES_CHRONIQUE` est une liste blanche et
   la collecte **jette en silence** tout type non mappé. Un type inventé au nom évocateur —
   `justice_verdict_secret`, par exemple — passerait la policy (il n'est pas au registre) mais
   **n'atteindrait jamais le Journal**.
3. **Fermer les onze est un chantier entier, pas un correctif.** Il faudrait onze portes serveur,
   chacune avec sa garde d'autorité propre (qui peut annoncer une nomination ? un rachat ? une
   dissolution ?), et plusieurs de ces gardes n'ont pas d'arbitrage. Les écrire ici reviendrait à
   décider à la place de l'arbitrage, ce que la tranche interdit.

**Ce qui est donc consigné comme dette, et non corrigé :** l'écriture cliente directe de
`chronique_nationale` reste ouverte pour onze types non judiciaires ; le constat est ancien
(mémoire « chronique_nationale n'est pas attestée ») et il est ici **chiffré et nommé type par
type** pour la première fois.

## 4. Le seul défaut corrigé, et pourquoi il n'était pas discutable

Le type `justice_enquete_ouverte_par_le_juge`, créé le 13 octobre 2026 avec la décision du juge
qui ouvre l'enquête malgré le non-lieu du parquet, était **entré au registre
`justice_faits_publics` sans entrer dans `TYPES_CHRONIQUE`**. La ligne de journal était donc
écrite, et la collecte de presse la **jetait en silence** : une publication muette.

Ce n'est pas une hypothèse : le même défaut s'était produit le 12 septembre 2026 pour
`fuite_journalistique` et `scandale_presse`, et le commentaire qui le raconte est à trois lignes
de l'endroit où la ligne manquait.

**Corrigé le jour même** (poids `important`, domaine `justice`, pour la même raison que le
non-lieu et la poursuite maintenue : un juge qui passe outre le parquet est un fait politique
autant que judiciaire), et **verrouillé** par deux mesures neuves :

* un **douzième contrôle** du baseline, `outils/baseline/verifier-faits-publics.py`, qui compare
  le seed du registre à la liste blanche de la collecte **dans les deux sens** ;
* une **épreuve de banc** (`banc-carrieres-creation-et-audience-client.js`) qui exige les treize
  types mappés et aucun type `justice_` hors registre.
