-- =====================================================================
-- LOT 4.1 — EXECUTION ATOMIQUE DES OFFRES ACCEPTEES
-- 7 septembre 2026
-- =====================================================================
-- ⚠️  NON EXECUTEE. Fournie pour relecture.
--
-- ORDRE DE DEPLOIEMENT IMPERATIF : ce fichier D'ABORD, le code ENSUITE.
-- Le code livre par le Lot 4.0 continue de fonctionner sans lui : repondre_offre existe deja et
-- garde sa signature. Cette migration ne fait que lui donner un bras.
--
-- NE MODIFIE PAS migration_moteur_commerce.sql, deja appliquee et desormais artefact historique.
--
-- CE QUE CE FICHIER AJOUTE
--   1 colonne sur offres : execution        (+ 1 contrainte, + 1 index partiel)
--   1 colonne sur offres : execution_detail
--   1 RPC remplacee      : repondre_offre   (signature INCHANGEE, donc droits conserves)
--
-- ---------------------------------------------------------------------
-- LE PROBLEME QUE CE FICHIER FERME
-- ---------------------------------------------------------------------
-- Le Lot 3.0 a volontairement ferme vendre_fonds_commerce et terminer_bail au navigateur, et il a
-- ecrit pourquoi : le vendeur y est verifie mais l'ACHETEUR ne l'est pas, et il suffirait d'ecrire
-- 'accord_amiable' dans une chaine pour simuler un accord que personne n'a donne. Il a aussi ecrit
-- la condition de leur reouverture -- "quand la preuve qui leur manque existera : un jugement pour
-- l'eviction, une acceptation pour la vente et pour l'accord amiable".
--
-- Cette acceptation existe depuis le Lot 4.0. Ce fichier ne fait que la brancher.
--
-- LES DEUX FONCTIONS RESTENT FERMEES. Elles ne sont ni re-accordees, ni recopiees, ni reecrites :
-- repondre_offre les appelle. Dans une fonction SECURITY DEFINER, l'appel interne s'execute avec
-- les droits du PROPRIETAIRE de la fonction, pas de l'appelant -- exactement le mecanisme deja
-- employe par resilier_bail_volontaire. Le navigateur gagne donc l'operation SANS gagner la
-- fonction : il ne peut la declencher qu'a travers une offre qu'un tiers a reellement acceptee.
--
-- AUCUN MOTEUR N'EST DUPLIQUE. Il n'y a toujours qu'une seule implementation de la vente d'un
-- fonds et une seule de la fin d'un bail. En creer une seconde ici aurait garanti leur divergence.

-- ---------------------------------------------------------------------
-- 1. STATUT DE L'OFFRE ET STATUT D'EXECUTION — DEUX CHOSES DIFFERENTES
-- ---------------------------------------------------------------------
-- Le Lot 4.0 laissait une ambiguite : 'acceptee' disait le consentement et ne disait rien de
-- l'operation. Or les deux ne coincident pas toujours -- un accord peut etre parfait sur un objet
-- que le serveur ne sait pas encore transferer.
--
-- Deux colonnes plutot qu'un statut elargi : le consentement et l'execution ont des cycles de vie
-- distincts, et les fondre obligerait a inventer des valeurs composites ('acceptee_non_executee')
-- qui melangent ce que le joueur a voulu et ce que la machine a su faire.
--
--   statut     ouverte | acceptee | refusee | expiree | annulee     -- ce que les parties ont voulu
--   execution  sans_objet | executee | non_disponible               -- ce que le serveur a fait
--
-- Les quatre etats a distinguer sans ambiguite se lisent alors directement :
--   1. offre ouverte                      statut='ouverte'    execution='sans_objet'
--   2. refusee / annulee / expiree        statut=...          execution='sans_objet'
--   3. acceptee ET executee               statut='acceptee'   execution='executee'
--   4. acceptee, moteur absent            statut='acceptee'   execution='non_disponible'
--
-- Le cas 4 ne concerne QUE vente_objet et prestation. Apres ce fichier, une offre vente_fonds ou
-- resiliation_amiable acceptee est necessairement executee : si l'operation echoue, l'offre n'est
-- pas acceptee du tout et reste ouverte.
--
-- 'sans_objet' et non NULL : une offre ouverte n'a pas une execution inconnue, elle n'en a pas.
ALTER TABLE offres ADD COLUMN IF NOT EXISTS execution text NOT NULL DEFAULT 'sans_objet';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'offres_execution_valide') THEN
    ALTER TABLE offres ADD CONSTRAINT offres_execution_valide
      CHECK (execution IN ('sans_objet', 'executee', 'non_disponible'));
  END IF;
END $$;

-- Ce que l'operation a REELLEMENT produit, tel que la RPC sous-jacente l'a rendu : prix effectif,
-- caisse extraite, bail transfere, indemnite versee. C'est la trace d'audit -- sans elle, on ne
-- pourrait pas rejouer ce qui s'est passe, la RPC appelee ne laissant sa trace que dans
-- l'historique du fonds.
ALTER TABLE offres ADD COLUMN IF NOT EXISTS execution_detail jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Retrouver les accords restes sans effet : c'est la file d'attente du jour ou vente_objet et
-- prestation auront un moteur. Index partiel, donc quasi vide tant que ce jour n'est pas venu.
CREATE INDEX IF NOT EXISTS offres_non_executees_idx
  ON offres (type, resolu_a) WHERE execution = 'non_disponible';

-- ---------------------------------------------------------------------
-- 2. REPONSE A UNE OFFRE — CONSENTEMENT ET OPERATION DANS LA MEME TRANSACTION
-- ---------------------------------------------------------------------
-- SIGNATURE INCHANGEE : CREATE OR REPLACE conserve les droits deja poses par le Lot 4.0, et le
-- code client livre en v113 continue d'appeler cette fonction sans changer d'un caractere.
--
-- ┌─ L'INVARIANT DE CE FICHIER ─────────────────────────────────────────────────────────────────┐
-- │ Une offre n'est marquee acceptee QUE si l'operation a reussi.                               │
-- │                                                                                             │
-- │ Deux mecanismes le garantissent, et il faut les distinguer :                                │
-- │                                                                                             │
-- │  - ECHEC PROPRE (la RPC rend ok:false). Toutes les sorties ok:false de vendre_fonds_commerce │
-- │    et de terminer_bail sont ANTERIEURES a toute ecriture -- verifie ligne a ligne : des que  │
-- │    ces fonctions ont commence a deplacer quelque chose, elles ne rendent plus false, elles   │
-- │    levent. On peut donc ne rien ecrire et laisser l'offre OUVERTE : le refus n'a rien coute, │
-- │    et l'accord reste disponible si la cause disparait (un solde qui se reconstitue).         │
-- │                                                                                             │
-- │  - ECHEC BRUTAL (la RPC leve). La transaction entiere est annulee, y compris l'UPDATE du     │
-- │    statut -- qui de toute facon n'a pas encore eu lieu, puisqu'il vient APRES l'appel.       │
-- │                                                                                             │
-- │ L'ordre des instructions est donc porteur de la garantie : verrou, verifications, operation, │
-- │ ET SEULEMENT ENSUITE ecriture du statut. Deplacer l'UPDATE avant l'appel casserait tout.     │
-- └─────────────────────────────────────────────────────────────────────────────────────────────┘
--
-- CONCURRENCE. Le SELECT ... FOR UPDATE de la premiere instruction serialise tout : une seconde
-- acceptation simultanee attend la premiere, puis lit un statut qui n'est plus 'ouverte' et sort
-- par la branche idempotente sans rien faire. Double-clic et course a deux navigateurs sont le
-- meme cas, et se referment au meme endroit. Aucun double transfert n'est possible sans que le
-- verrou soit relache, ce qui n'arrive qu'a la fin de la transaction.
CREATE OR REPLACE FUNCTION repondre_offre(
  p_offre_id  text,
  p_acteur    text,
  p_acceptee  boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_offre     offres%ROWTYPE;
  v_res       jsonb;
  v_fonds     jsonb;
  v_bail      jsonb;
  v_locataire text;
  v_bailleur  text;
  v_execution text;
BEGIN
  IF COALESCE(p_offre_id, '') = '' OR COALESCE(p_acteur, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- LE VERROU EN PREMIER. Tout ce qui suit s'execute sous sa protection.
  SELECT * INTO v_offre FROM offres WHERE id = p_offre_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'offre_absente'); END IF;

  -- Idempotence : repondre deux fois n'est pas une erreur, il n'y a simplement plus rien a faire.
  -- On rend l'etat COMPLET -- statut ET execution -- pour qu'un second appel ne laisse jamais
  -- croire a une seconde execution.
  IF v_offre.statut <> 'ouverte' THEN
    RETURN jsonb_build_object('ok', true, 'deja_resolue', true,
                              'statut', v_offre.statut, 'execution', v_offre.execution,
                              'detail', v_offre.execution_detail);
  END IF;

  IF v_offre.expire_a <= now() THEN
    UPDATE offres SET statut = 'expiree', resolu_a = now() WHERE id = p_offre_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'offre_expiree');
  END IF;

  -- L'emetteur ne peut qu'annuler la sienne ; il ne peut pas l'accepter a la place de l'autre.
  IF p_acteur = v_offre.emetteur THEN
    IF COALESCE(p_acceptee, false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'emetteur_ne_peut_accepter');
    END IF;
    UPDATE offres SET statut = 'annulee', resolu_a = now() WHERE id = p_offre_id;
    RETURN jsonb_build_object('ok', true, 'deja_resolue', false, 'statut', 'annulee',
                              'execution', 'sans_objet');
  END IF;

  IF p_acteur IS DISTINCT FROM v_offre.destinataire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_partie_a_l_offre');
  END IF;

  -- REFUS : aucun moteur n'est sollicite, rien ne bouge.
  IF COALESCE(p_acceptee, false) IS NOT TRUE THEN
    UPDATE offres SET statut = 'refusee', resolu_a = now() WHERE id = p_offre_id;
    RETURN jsonb_build_object('ok', true, 'deja_resolue', false, 'statut', 'refusee',
                              'execution', 'sans_objet');
  END IF;

  -- =========================================================================
  -- ACCEPTATION. A partir d'ici, le consentement est etabli ; reste a l'executer.
  -- =========================================================================

  IF v_offre.type = 'vente_fonds' THEN
    -- ---- Revalidation SOUS VERROU. L'offre a pu etre creee il y a trois jours : le fonds a pu
    -- ---- etre vendu, ferme, ou avoir change de main entre-temps. Ce qui etait vrai a la creation
    -- ---- ne l'est plus forcement, et c'est l'etat d'AUJOURD'HUI qui fait foi.
    IF COALESCE(v_offre.actif, '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_requis');
    END IF;

    SELECT data INTO v_fonds FROM entreprises WHERE id = v_offre.actif FOR UPDATE;
    IF v_fonds IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent');
    END IF;
    IF (v_fonds ->> 'proprietaire') IS DISTINCT FROM v_offre.emetteur THEN
      -- Le vendeur n'est plus proprietaire : il vend ce qui ne lui appartient plus. L'offre reste
      -- ouverte et mourra d'elle-meme -- on ne l'annule pas, ce n'est pas au destinataire de
      -- subir une decision qu'il n'a pas prise.
      RETURN jsonb_build_object('ok', false, 'raison', 'vendeur_plus_proprietaire');
    END IF;
    IF COALESCE(v_fonds ->> 'statut', 'actif') <> 'actif' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_non_vendable',
                                'statutFonds', COALESCE(v_fonds ->> 'statut', 'actif'));
    END IF;

    -- ---- L'OPERATION, par le moteur existant et lui seul. Le prix est celui de l'offre, jamais
    -- ---- un parametre : le destinataire accepte un montant ecrit, il ne le propose pas.
    v_res := vendre_fonds_commerce(v_offre.emetteur, v_offre.destinataire,
                                   v_offre.actif, v_offre.montant);
    IF COALESCE((v_res ->> 'ok')::boolean, false) IS NOT TRUE THEN
      -- Echec propre : rien n'a bouge, l'offre reste ouverte.
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_res ->> 'raison', 'echec_vente'),
                                'statut', 'ouverte', 'detail', v_res);
    END IF;
    v_execution := 'executee';

  ELSIF v_offre.type = 'resiliation_amiable' THEN
    IF COALESCE(v_offre.actif, '') = '' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'bail_requis');
    END IF;

    SELECT data INTO v_bail FROM locations_actives WHERE id = v_offre.actif FOR UPDATE;
    IF v_bail IS NULL THEN
      -- Bail deja termine par ailleurs : l'accord n'a plus d'objet. On ne delegue pas a
      -- terminer_bail, qui rendrait ok:true/deja_termine et ferait croire a une execution.
      RETURN jsonb_build_object('ok', false, 'raison', 'bail_deja_termine');
    END IF;

    v_locataire := COALESCE(v_bail ->> 'locataireRef',
                            'pj:' || COALESCE(v_bail ->> 'locataire', ''));
    -- Proprietaire ACTUEL des murs : relu sur le terrain porteur, jamais fige au bail ni recopie
    -- de l'offre. Des murs vendus entre la creation et l'acceptation changent le bailleur, et
    -- l'accord ne vaut plus -- le nouveau proprietaire n'a rien signe.
    SELECT (data::jsonb ->> 'proprietaire') INTO v_bailleur FROM terrains_etat
     WHERE id = (v_bail ->> 'country') || '_' || (v_bail ->> 'buildingId');

    IF NOT ((v_offre.emetteur = v_locataire AND v_offre.destinataire = v_bailleur)
         OR (v_offre.emetteur = v_bailleur  AND v_offre.destinataire = v_locataire)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'parties_ne_correspondent_plus',
                                'locataire', COALESCE(v_locataire, ''),
                                'bailleur', COALESCE(v_bailleur, ''));
    END IF;

    -- ---- L'OPERATION. L'indemnite est celle portee par l'offre -- le moteur n'en impose aucune,
    -- ---- il transporte celle sur laquelle les deux se sont entendus. Elle va toujours du
    -- ---- bailleur au locataire, quel que soit celui qui a emis l'offre : c'est terminer_bail
    -- ---- qui en decide, et on ne le contredit pas ici.
    v_res := terminer_bail(v_offre.actif, 'accord_amiable', p_acteur, v_offre.montant);
    IF COALESCE((v_res ->> 'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_res ->> 'raison', 'echec_resiliation'),
                                'statut', 'ouverte', 'detail', v_res);
    END IF;
    IF COALESCE((v_res ->> 'deja_termine')::boolean, false) THEN
      -- Ceinture et bretelles : la lecture du bail ci-dessus rend ce cas inatteignable, mais s'il
      -- survenait, rien n'a ete fait et on ne pretend pas le contraire.
      RETURN jsonb_build_object('ok', false, 'raison', 'bail_deja_termine');
    END IF;
    v_execution := 'executee';

  ELSE
    -- ---- vente_objet ET prestation : ACCORD CONSTATE, OPERATION INDISPONIBLE.
    --
    -- vente_objet. Un objet vit dans personnages.inventory, que le client reecrit ENTIEREMENT a
    -- chaque sauvegarde. Le serveur ne peut donc ni prouver que le vendeur le detient encore, ni
    -- le lui retirer : une remise par objets_recus le CREERAIT chez l'acheteur sans garantie
    -- qu'il ait disparu chez le vendeur. On dupliquerait l'objet en croyant le transferer.
    -- L'individualisation des exemplaires (Lot 4.0) est une condition necessaire mais pas
    -- suffisante : il manque que l'inventaire cesse d'etre autoritaire cote client.
    --
    -- prestation. Aucun moteur d'execution generique n'existe, et en inventer un serait decider ce
    -- qu'est une prestation -- une decision de contenu qui n'a pas ete prise.
    --
    -- DANS LES DEUX CAS, AUCUN FR NE BOUGE. Deplacer l'argent d'un cote en esperant que l'objet
    -- suive de l'autre serait exactement la creation de valeur que tout ce lot cherche a empecher.
    v_execution := 'non_disponible';
  END IF;

  -- ---- ECRITURE DU STATUT, EN DERNIER. Voir l'encadre : cet ordre EST la garantie.
  UPDATE offres
     SET statut = 'acceptee', execution = v_execution,
         execution_detail = COALESCE(v_res, '{}'::jsonb), resolu_a = now()
   WHERE id = p_offre_id;

  RETURN jsonb_build_object(
    'ok', true, 'deja_resolue', false, 'statut', 'acceptee', 'execution', v_execution,
    'raison', CASE WHEN v_execution = 'non_disponible' THEN 'execution_non_disponible' ELSE NULL END,
    'type', v_offre.type, 'actif', v_offre.actif,
    'emetteur', v_offre.emetteur, 'destinataire', v_offre.destinataire,
    'montant', v_offre.montant, 'detail', COALESCE(v_res, '{}'::jsonb));
END;
$$;

-- ---------------------------------------------------------------------
-- 3. DROITS
-- ---------------------------------------------------------------------
-- repondre_offre garde sa signature, donc ses droits : CREATE OR REPLACE ne les reinitialise pas.
-- Les revocations sont repetees par idempotence, pour que ce fichier soit rejouable et fidele.
--
-- CE QUI N'EST PAS RE-ACCORDE, ET NE DOIT PAS L'ETRE : vendre_fonds_commerce et terminer_bail
-- restent reservees a service_role. Le navigateur les atteint uniquement au travers d'une offre
-- reellement acceptee, jamais directement. Leur ouvrir l'acces annulerait tout le lot.
REVOKE EXECUTE ON FUNCTION repondre_offre(text, text, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION repondre_offre(text, text, boolean) TO anon, authenticated, service_role;

-- CONTROLE POSTERIEUR — attendu :
--   repondre_offre           t / t / t
--   vendre_fonds_commerce    f / f / t      <- doit rester ferme
--   terminer_bail            f / f / t      <- doit rester ferme
--   mouvement_titulaire      f / f / t      <- doit rester ferme
SELECT p.proname AS fonction,
       has_function_privilege('anon',          p.oid, 'EXECUTE') AS anon,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated,
       has_function_privilege('service_role',  p.oid, 'EXECUTE') AS service_role
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('repondre_offre','vendre_fonds_commerce','terminer_bail','mouvement_titulaire')
ORDER BY p.proname;

-- CONTROLE POSTERIEUR DU SCHEMA — attendu : 2 colonnes, 1 contrainte, 1 index.
SELECT 'colonne' AS objet, column_name AS nom FROM information_schema.columns
 WHERE table_name = 'offres' AND column_name IN ('execution','execution_detail')
UNION ALL
SELECT 'contrainte', conname FROM pg_constraint WHERE conname = 'offres_execution_valide'
UNION ALL
SELECT 'index', indexname FROM pg_indexes WHERE indexname = 'offres_non_executees_idx'
ORDER BY objet, nom;

-- CONTROLE POSTERIEUR DE L'ECRITURE DIRECTE — inchange depuis le Lot 4.0, revérifié parce que ce
-- fichier touche la table. Attendu : SELECT t, tout le reste f pour anon ET authenticated.
SELECT c.relname AS "table",
       has_table_privilege('anon',          c.oid, 'SELECT') AS anon_select,
       has_table_privilege('anon',          c.oid, 'INSERT') AS anon_insert,
       has_table_privilege('anon',          c.oid, 'UPDATE') AS anon_update,
       has_table_privilege('authenticated', c.oid, 'INSERT') AS auth_insert,
       has_table_privilege('authenticated', c.oid, 'UPDATE') AS auth_update
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname = 'offres';
