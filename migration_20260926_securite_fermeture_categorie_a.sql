-- SECURITE : FERMETURE DES TROIS TABLES DE CATEGORIE A (26 septembre 2026)
-- APPLIQUE EN PRODUCTION ET VERIFIE PAR APPELS REST REELS.
--
-- CONTEXTE. 25 tables ont la RLS desactivee et le role `authenticated` y possede INSERT et
-- UPDATE (relacl = authenticated=arwxtm). La RLS etant desactivee, l'acces effectif est le
-- GRANT seul : n'importe quel joueur connecte pouvait ecrire ces tables directement par
-- PostgREST. L'audit des 25 a classe chaque table selon ses ecritures clientes legitimes :
--   A = aucune ecriture cliente   -> fermeture immediate sure    : 3 tables, celles-ci
--   B = une RPC couvre deja tout  -> AUCUNE table dans ce cas
--   C = ecriture cliente encore necessaire -> migration requise  : 22 tables, NON fermees
--
-- POURQUOI CELLE-CI D'ABORD -- pa_credits_sources etait une ELEVATION DE PRIVILEGE reelle.
-- pa_crediter_atteste(p_acteur, p_source, p_reference, p_ordre) lit :
--     SELECT true, montant INTO v_declare, v_montant
--       FROM public.pa_credits_sources WHERE source = p_source;
-- puis credite EXACTEMENT ce montant. La seule garde est pa_credits_uniques, qui empeche le
-- rejeu d'une meme reference -- pas la repetition avec une reference differente.
-- Un joueur connecte pouvait donc inserer ('ma_source', 999) puis appeler la RPC autant de
-- fois qu'il voulait avec des references distinctes, et s'octroyer des PA sans limite.
-- La RPC elle-meme est correctement ecrite : c'etait sa liste blanche qui etait ouverte.
--
-- Les deux autres sont des tables d'EMPREINTE (une ligne, miroir de regles), jamais ecrites
-- ni lues a l'execution : zero occurrence dans tout le depot, aucune fonction de pg_proc ne
-- les reference.
--
-- CE QUI EST CONSERVE : le SELECT de `authenticated`. Aucune de ces trois tables ne contient
-- de secret (ce sont des regles de jeu), et le garder supprime tout risque de regression sur
-- une lecture que l'audit aurait manquee. pa_crediter_atteste est SECURITY DEFINER et
-- appartient a postgres : elle lit la liste blanche sans dependre de ces droits.
--
-- CE QUI N'EST PAS FAIT : activer la RLS. Le piege est connu et documente dans ce depot --
-- activer la RLS reveille les policies dormantes USING(true), et les policies permissives se
-- combinant par OR, un seul `true` annulerait toute regle d'autorite. Ces trois tables n'ont
-- aucune policy, mais la revocation du GRANT suffit et ne depend d'aucune subtilite :
-- acces effectif = GRANT ET (pas de RLS OU policy permissive).
--
-- VERIFICATION (appels REST reels apres application) :
--   session anonyme Supabase, jeton de role `authenticated` (decode et verifie) :
--     POST /rest/v1/pa_credits_sources -> 42501 permission denied
--   droits releves en base :
--     pa_credits_sources             auth_select=t auth_insert=f auth_update=f
--     pa_bonus_differes_empreinte    auth_select=t auth_insert=f auth_update=f
--     postes_nommes_regles_empreinte auth_select=t auth_insert=f auth_update=f
--     contributions_piete (temoin C) auth_select=t auth_insert=T auth_update=T  <- encore ouverte
--
-- RELIQUAT : 22 tables de categorie C restent ouvertes a `authenticated`. Elles ne peuvent pas
-- etre fermees sans migrer d'abord leurs ecritures clientes vers des RPC. Les plus urgentes
-- par le degat silencieux qu'une fermeture causerait : budgets_nationaux (17 sites),
-- budgets_municipaux (9), caisses_fret (9), greves_generales (7), transferts_clubs (6),
-- contenu_caisses_fret (6), budgets_clubs (5), demandes_manifestation (5).
-- Le meilleur candidat a une migration rapide est indices_villes : la primitive serveur
-- indice_ville_ajuster_interne existe deja et fait le bon UPDATE borne 0-100 ; il ne manque
-- qu'un wrapper SECURITY DEFINER expose a authenticated.

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.pa_credits_sources, public.pa_bonus_differes_empreinte,
     public.postes_nommes_regles_empreinte
  FROM anon, authenticated, PUBLIC;

GRANT SELECT ON public.pa_credits_sources, public.pa_bonus_differes_empreinte,
                public.postes_nommes_regles_empreinte
  TO authenticated;

COMMENT ON TABLE public.pa_credits_sources IS
  'LISTE BLANCHE des sources de credit de PA, avec le montant autorise. Lue par '
  'pa_crediter_atteste, qui credite exactement ce montant. ECRITURE FERMEE AU CLIENT le '
  '26 septembre 2026 : y inserer une ligne equivalait a s''octroyer des PA sans limite, la '
  'garde pa_credits_uniques ne portant que sur la reference. Ne jamais rouvrir INSERT/UPDATE '
  'a anon ni a authenticated.';
