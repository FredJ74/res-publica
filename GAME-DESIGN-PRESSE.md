# Presse : le Journal du jour

Le Journal du jour (« La Tribune ») est rédigé chaque jour à partir d'un paquet de faits établis par le serveur (`api/_journal-collecte.js`, champ `FACTS`). Règle absolue : **interpréter, jamais inventer**. Les personnages joueurs font l'actualité. Les soins discrets en clinique privée n'apparaissent jamais.

## Faits divers (décision de Fred du 20/11/2026)

Migration `20261120300000_journal_faits_divers`, fonction serveur `journal_faits_divers`.

- **Types de faits :** neutralisation, vol sur personne, cambriolage, vol en commerce, empoisonnement, explosion, incendie.
- **Faits retenus :** un fait par acte réussi, plus les échecs spectaculaires (explosion prématurée, auteur identifié ou arrêté).
- **Contenu de chaque fait :**
  - type et date ;
  - lieu : bâtiment, ville et pays du lieu ;
  - victime : son nom, son poste ou son mandat, sa nationalité (par exemple « ministre de la Défense de Républia »), et si c'est un PJ ;
  - conséquence : victime hospitalisée, montant volé arrondi à deux chiffres, bâtiment incendié et fermé…
- **Anonymat strict.** L'auteur n'est jamais nommé ni décrit de façon identifiante, sauf s'il a été identifié par les voies du jeu : échec critique, enquête réussie, arrestation, démasquage. Sinon, il est seulement « un individu masqué » s'il était masqué, et « un inconnu » dans les autres cas. C'est le serveur qui anonymise : aucune donnée d'un auteur non identifié n'est transmise au générateur.
- **Une.** Un fait divers dont la victime est un PJ, a fortiori un responsable politique, peut faire la Une.
- **Acte transfrontalier.** Quand la victime est d'un pays et le lieu dans un autre, le fait paraît dans les deux journaux. Il peut être traité sous l'angle de l'incident diplomatique, sans jamais attribuer la responsabilité à un État ni à un camp.
- **Pas d'hypothèse sur l'auteur,** même au conditionnel.
