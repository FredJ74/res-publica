# Issue #68 — reprise sans F5, préparation sur la PR56

Branche `codex/reprise-sessions-68`, basée sur `78f15c1` de la PR56. Aucun déploiement ni changement Supabase.

Constats reproduits : un 401 serveur ne déclenchait pas de renouvellement quand le JWT paraissait encore valide ; le bandeau ne proposait qu'un départ vers l'accueil. La reprise de session est maintenant dédupliquée, réutilise un JWT renouvelé par un autre onglet et utilise Web Locks lorsque disponible pour sérialiser la rotation entre onglets, uniquement pendant une interaction. Un retour de renouvellement antérieur à une connexion explicite ne remplace plus sa session.

Le transport renouvelle après 401. Seul un GET peut être rejoué, une seule fois, sous le même UID. Un POST/RPC ou une écriture REST n'est jamais rejoué : son verdict reste un refus/une confirmation incertaine, la prochaine interaction bénéficie de la session restaurée. Une panne transitoire conserve les credentials ; aucun nouveau compte anonyme n'est créé pour remplacer un compte connu.

La reconnexion s'effectue dans le plateau avec le moteur `rpAuthSeConnecter` existant. UID attendu vérifié avant adoption de la session, personnage confirmé par `mon_personnage`, puis synchronisation par le moteur des réalités. Aucune ancienne intention métier n'est rejouée. Le formulaire est exempté du filtre d'actions nécessitant justement une session valide.

Tests ciblés : 23/23 avec les régressions de session existantes, plus un scénario Chromium du formulaire (services simulés). Expiration, cache, réseau, révocation, UID différent, rotation entre onglets, retour tardif, absence de rejeu financier et GET sûr sont couverts. Les bancs globaux sont consignés dans le rapport de session de consolidation. Web Locks absent : déduplication dans l'onglet et récupération du stockage partagé, sans prétendre à un verrou inter-onglets universel.

À vérifier avant production : prévol lecture seule, vrais JWT/rotation GoTrue et comptes isolés autorisés, CI distante et intégration PR56. Le connecteur Supabase et l'API GitHub sont indisponibles ici ; aucune validation réelle n'est revendiquée.
