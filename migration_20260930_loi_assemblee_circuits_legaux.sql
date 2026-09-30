-- ===========================================================================
-- LA LOI FERME LES CIRCUITS LEGAUX, PAS LE MONDE PHYSIQUE (30 septembre 2026)
-- ---------------------------------------------------------------------------
-- ARBITRAGE FINALISE (Fred). Une matiere premiere interdite par l'Assemblee
-- n'est pas supprimee du monde et sa possession n'est pas interdite : l'Assemblee
-- la retire des CIRCUITS ECONOMIQUES LEGAUX et empeche sa production legale.
--
--   BLOQUE   produire, acheter, vendre, importer legalement.
--   POSSIBLE conserver, transporter, consommer, DONNER -- et contourner par des
--            mecaniques explicitement clandestines.
--
-- CE LOT CORRIGE UN POINT DU PRECEDENT : le don etait bloque comme la vente. Il
-- ne doit plus l'etre. Un don de matiere interdite n'est PAS un delit : c'est un
-- element potentiellement suspect, que l'enquete, la presse ou la rumeur pourront
-- exploiter plus tard. AUCUN DELIT AUTOMATIQUE N'EST CREE ICI.
--
-- ET SURTOUT, PAS DE PRIMITIVE « MATIERE INTERDITE = INTRANSFERABLE » : ce serait
-- contraire au game design. La garde ci-dessous ne connait qu'un seul verbe --
-- « ce mouvement appartient-il a un circuit economique legal ? » -- et le don y
-- repond non.
--
-- DEUX CORRECTIONS DE FOND PAR RAPPORT A LA VEILLE
-- ---------------------------------------------------------------------------
-- 1. LE MODE. matiere_apport_refus_legal(pays, matiere) ne savait pas distinguer
--    un achat d'un cadeau. La nouvelle primitive prend le mode, pour que « un don
--    n'est pas une vente » soit ecrit UNE fois, au serveur, et non repete dans
--    chaque moteur.
-- 2. LA JURIDICTION. Elle prenait un `pays` fourni par l'appelant. Or trois des
--    RPC concernees recoivent leur `p_pays` DU NAVIGATEUR
--    (acheter_a_entrepot, acheter_a_la_criee, vendre_matiere_a_usine,
--    vendre_ressource_medicale) : un client pouvait donc annoncer un empire sans
--    Assemblee et passer. La primitive resout desormais le pays ELLE-MEME, depuis
--    personnages_donnees -- la meme colonne qui fait autorite pour la position.
--    Aucun appelant ne peut plus se tromper de juridiction, ni mentir.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. LA GARDE COMMUNE DES CIRCUITS LEGAUX
-- ---------------------------------------------------------------------------
-- Remplace matiere_apport_refus_legal, qui n'avait vecu qu'une journee : sa
-- signature n'avait ni le mode ni la bonne source de juridiction. Deux
-- appelants seulement, tous deux reecrits ci-dessous.
drop function if exists public.matiere_apport_refus_legal(text, text);

create or replace function public.matiere_refus_circuit_legal(
  p_acteur text, p_matiere text, p_mode text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_pays text; v_loi jsonb;
BEGIN
  IF coalesce(p_acteur, '') = '' OR coalesce(p_matiere, '') = '' THEN RETURN NULL; END IF;

  -- LE DON N'EST PAS UN CIRCUIT ECONOMIQUE. C'est le seul endroit du serveur ou
  -- cette exception est ecrite : les moteurs appellent tous cette fonction sans
  -- avoir a connaitre la regle. Un transfert gratuit reste possible, et sa trace
  -- au registre est justement ce qui rendra une filiere reperable.
  IF lower(btrim(coalesce(p_mode, ''))) = 'don' THEN RETURN NULL; END IF;

  -- LA JURIDICTION EST CELLE DU PERSONNAGE, LUE EN BASE. Jamais un pays transmis
  -- par l'appelant : plusieurs des RPC gardees ici recoivent le leur du
  -- navigateur, qui pourrait annoncer un empire sans Assemblee.
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_acteur;
  IF v_pays IS NULL THEN RETURN NULL; END IF;

  -- La regle de fond est inchangee et n'est pas reimplementee : assemblee_loi_en_vigueur
  -- lit les lois adoptees, leurs categories, et borne l'entree en vigueur
  -- (adoptee_ts <= instant) a l'horloge du serveur. Une matiere est un objet
  -- empilable dont la cle est celle de RESSOURCES_ECONOMIE : cette traduction
  -- n'existe qu'ici, pour tous les circuits.
  v_loi := public.assemblee_loi_en_vigueur(v_pays,
             jsonb_build_object('stackKey', p_matiere), now());
  IF v_loi IS NULL THEN RETURN NULL; END IF;

  RETURN jsonb_build_object('ok', false, 'raison', 'matiere_interdite',
                            'matiere', p_matiere, 'loi', v_loi);
END $fn$;

comment on function public.matiere_refus_circuit_legal(text, text, text) is
  'Garde COMMUNE des circuits economiques legaux portant sur une matiere premiere. Rend NULL si le mouvement est licite, sinon le refus complet (raison matiere_interdite, avec la loi). Le mode ''don'' est TOUJOURS licite : l''Assemblee ferme les circuits legaux, elle ne rend pas la matiere intransferable (arbitrage du 30 septembre 2026). La juridiction est celle du personnage, lue dans personnages_donnees et jamais recue de l''appelant. Source de verite : assemblee_loi_en_vigueur.';

revoke all on function public.matiere_refus_circuit_legal(text, text, text) from public, anon;
grant execute on function public.matiere_refus_circuit_legal(text, text, text) to authenticated, service_role;

-- Variante pour les achats en lot : un panier {matiere: quantite}. Rend le refus
-- de la PREMIERE matiere interdite rencontree, ou NULL. Evite d'ecrire la boucle
-- dans chaque RPC d'achat.
create or replace function public.matiere_refus_circuit_legal_lot(
  p_acteur text, p_panier jsonb, p_mode text)
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT public.matiere_refus_circuit_legal(p_acteur, k.cle, p_mode)
    FROM jsonb_object_keys(
           CASE WHEN jsonb_typeof(p_panier) = 'object' THEN p_panier ELSE '{}'::jsonb END
         ) AS k(cle)
   WHERE public.matiere_refus_circuit_legal(p_acteur, k.cle, p_mode) IS NOT NULL
   ORDER BY k.cle
   LIMIT 1;
$fn$;

comment on function public.matiere_refus_circuit_legal_lot(text, jsonb, text) is
  'matiere_refus_circuit_legal appliquee a un panier {matiere: quantite}. Rend le refus de la premiere matiere interdite du panier, ou NULL si tout est licite.';

revoke all on function public.matiere_refus_circuit_legal_lot(text, jsonb, text) from public, anon;
grant execute on function public.matiere_refus_circuit_legal_lot(text, jsonb, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. LES QUATRE CIRCUITS LEGAUX EXISTANTS, GARDES PAR INSERTION
-- ---------------------------------------------------------------------------
-- POURQUOI PAR INSERTION ET NON PAR REECRITURE : ces quatre fonctions font 4 a
-- 6 Ko chacune et portent des regles metier anciennes (chaines d'usine, prix
-- variable au remplissage, financement des structures medicales, plafonds
-- d'inventaire, comptes bancaires). Les retaper de memoire pour y ajouter deux
-- lignes, c'est risquer d'en perdre une sans s'en apercevoir -- et j'ai deja
-- constate ce jour-la que le fichier de migration de fonds_matiere_apporter
-- avait divergé de la production. On lit donc le corps REEL, on verifie l'ancre,
-- on insere, et on verifie le resultat. Chaque bloc est idempotent : rejoue, il
-- ne fait rien.
DO $poser$
DECLARE
  v_cibles text[][] := ARRAY[
    -- fonction                  , expression de la matiere , mode     , libelle du circuit
    ARRAY['vendre_matiere_a_usine'   , 'p_matiere'  , 'vente', 'vente de matiere a une usine'],
    ARRAY['vendre_ressource_medicale', 'p_ressource', 'vente', 'vente de ressource a une structure medicale']
  ];
  v_i integer; v_def text; v_ancre text := '  PERFORM public.exiger_acteur(p_acteur);';
  v_garde text; v_n integer;
BEGIN
  FOR v_i IN 1 .. array_length(v_cibles, 1) LOOP
    SELECT pg_get_functiondef(p.oid) INTO v_def
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_cibles[v_i][1];
    IF v_def IS NULL THEN
      RAISE EXCEPTION '% est introuvable : la garde legale ne peut pas etre posee', v_cibles[v_i][1];
    END IF;

    IF v_def LIKE '%matiere_refus_circuit_legal%' THEN
      CONTINUE;   -- deja gardee, migration rejouee
    END IF;

    -- L'ancre doit etre presente UNE seule fois, sinon on ne sait pas ou l'on pose.
    v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
    IF v_n <> 1 THEN
      RAISE EXCEPTION '% : ancre trouvee % fois, 1 attendue', v_cibles[v_i][1], v_n;
    END IF;

    v_garde := v_ancre || E'\n' ||
      E'  -- CIRCUIT LEGAL (30 septembre 2026) : ' || v_cibles[v_i][4] || E'.\n' ||
      E'  -- Une matiere interdite par l''Assemblee ne peut plus y entrer. Le don, lui,\n' ||
      E'  -- reste licite -- mais ce circuit-ci n''est pas un don. Garde posee avant toute\n' ||
      E'  -- lecture metier et toute ecriture ; la juridiction est resolue par le serveur.\n' ||
      E'  IF public.matiere_refus_circuit_legal(p_acteur, ' || v_cibles[v_i][2] || ', ''' || v_cibles[v_i][3] || E''') IS NOT NULL THEN\n' ||
      E'    RETURN public.matiere_refus_circuit_legal(p_acteur, ' || v_cibles[v_i][2] || ', ''' || v_cibles[v_i][3] || E''');\n' ||
      E'  END IF;';

    EXECUTE replace(v_def, v_ancre, v_garde);

    -- On verifie que la garde est bien la, plutot que de le supposer.
    SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_cibles[v_i][1]
       AND pg_get_functiondef(p.oid) LIKE '%matiere_refus_circuit_legal%';
    IF v_n <> 1 THEN RAISE EXCEPTION '% : la garde n''a pas ete posee', v_cibles[v_i][1]; END IF;
  END LOOP;
END $poser$;

-- Les deux achats en lot : meme methode, garde en lot.
DO $poser_lot$
DECLARE
  v_noms text[] := ARRAY['acheter_a_entrepot', 'acheter_a_la_criee'];
  v_libelles text[] := ARRAY['achat de matieres a l''Entrepot logistique',
                             'achat de matieres a la criee du port'];
  v_i integer; v_def text; v_ancre text := '  PERFORM public.exiger_acteur(p_acteur);';
  v_garde text; v_n integer;
BEGIN
  FOR v_i IN 1 .. array_length(v_noms, 1) LOOP
    SELECT pg_get_functiondef(p.oid) INTO v_def
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_noms[v_i];
    IF v_def IS NULL THEN
      RAISE EXCEPTION '% est introuvable : la garde legale ne peut pas etre posee', v_noms[v_i];
    END IF;
    IF v_def LIKE '%matiere_refus_circuit_legal%' THEN CONTINUE; END IF;

    v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
    IF v_n <> 1 THEN
      RAISE EXCEPTION '% : ancre trouvee % fois, 1 attendue', v_noms[v_i], v_n;
    END IF;

    -- La garde est appelee deux fois de suite, volontairement : la fonction est
    -- STABLE et minuscule, et cela evite d'ajouter une variable au DECLARE de la
    -- fonction hote -- donc une seconde substitution dans un corps qu'on ne
    -- reecrit pas.
    v_garde := v_ancre || E'\n' ||
      E'  -- CIRCUIT LEGAL (30 septembre 2026) : ' || v_libelles[v_i] || E'.\n' ||
      E'  -- Tout le panier est examine : une seule matiere interdite suffit a refuser,\n' ||
      E'  -- avant le moindre debit et avant la moindre entree en inventaire.\n' ||
      E'  IF public.matiere_refus_circuit_legal_lot(p_acteur, p_achats, ''achat'') IS NOT NULL THEN\n' ||
      E'    RETURN public.matiere_refus_circuit_legal_lot(p_acteur, p_achats, ''achat'');\n' ||
      E'  END IF;';

    EXECUTE replace(v_def, v_ancre, v_garde);

    SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_noms[v_i]
       AND pg_get_functiondef(p.oid) LIKE '%matiere_refus_circuit_legal_lot%';
    IF v_n <> 1 THEN RAISE EXCEPTION '% : la garde n''a pas ete posee', v_noms[v_i]; END IF;
  END LOOP;
END $poser_lot$;

-- ---------------------------------------------------------------------------
-- 3. LES DEUX MOTEURS D'APPORT : VENTE GARDEE, DON LIBERE
-- ---------------------------------------------------------------------------
-- Ici on reecrit, parce que le corps entier a ete releve sur la production la
-- veille et que le seul changement est le passage du mode a la garde.
DO $apports$
DECLARE
  v_noms text[] := ARRAY['commerce_apporter_matiere', 'fonds_matiere_apporter'];
  v_expr text[] := ARRAY['v_pays', 'v_data->''implantation''->>''country'''];
  v_i integer; v_def text; v_n integer; v_ancien text; v_nouveau text;
BEGIN
  FOR v_i IN 1 .. array_length(v_noms, 1) LOOP
    SELECT pg_get_functiondef(p.oid) INTO v_def
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_noms[v_i];
    IF v_def IS NULL THEN RAISE EXCEPTION '% est introuvable', v_noms[v_i]; END IF;

    -- L'appel de la veille, a remplacer : il ne connaissait pas le mode et
    -- prenait un pays en argument.
    v_ancien := 'public.matiere_apport_refus_legal(' || v_expr[v_i] || ', v_mat)';
    IF v_def NOT LIKE '%' || v_ancien || '%' THEN
      IF v_def LIKE '%matiere_refus_circuit_legal(p_acteur, v_mat, v_mode)%' THEN
        CONTINUE;   -- deja converti, migration rejouee
      END IF;
      RAISE EXCEPTION '% : appel attendu introuvable (%)', v_noms[v_i], v_ancien;
    END IF;

    -- LE MODE EST TRANSMIS : c'est lui qui libere le don. La garde reste au meme
    -- endroit, juste apres la presence et avant toute ecriture.
    v_nouveau := 'public.matiere_refus_circuit_legal(p_acteur, v_mat, v_mode)';
    EXECUTE replace(v_def, v_ancien, v_nouveau);

    SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_noms[v_i]
       AND pg_get_functiondef(p.oid) LIKE '%' || v_nouveau || '%'
       AND pg_get_functiondef(p.oid) NOT LIKE '%matiere_apport_refus_legal%';
    IF v_n <> 1 THEN RAISE EXCEPTION '% : la conversion a echoue', v_noms[v_i]; END IF;
  END LOOP;
END $apports$;

-- ---------------------------------------------------------------------------
-- 4. GARDES FINALES
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE n integer; nom text;
BEGIN
  -- a) Les six circuits gardes le sont effectivement.
  FOREACH nom IN ARRAY ARRAY['commerce_apporter_matiere', 'fonds_matiere_apporter',
                             'vendre_matiere_a_usine', 'vendre_ressource_medicale',
                             'acheter_a_entrepot', 'acheter_a_la_criee']
  LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public' AND p.proname = nom
       AND pg_get_functiondef(p.oid) LIKE '%matiere_refus_circuit_legal%';
    IF n <> 1 THEN RAISE EXCEPTION '% n''est pas gardee par le controle legal commun', nom; END IF;
  END LOOP;

  -- b) L'ancienne primitive d'un jour ne subsiste nulle part.
  --    `prokind = 'f'` est indispensable : pg_get_functiondef leve une erreur sur
  --    un agregat, et ce balayage porte sur TOUT le schema public.
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.prokind = 'f'
     AND pg_get_functiondef(p.oid) LIKE '%matiere_apport_refus_legal%';
  IF n <> 0 THEN RAISE EXCEPTION 'matiere_apport_refus_legal est encore referencee par % fonction(s)', n; END IF;

  -- c) Les deux moteurs d'apport passent bien le MODE, sans quoi le don resterait
  --    bloque -- c'est le point que ce lot corrige.
  FOREACH nom IN ARRAY ARRAY['commerce_apporter_matiere', 'fonds_matiere_apporter']
  LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public' AND p.proname = nom
       AND pg_get_functiondef(p.oid) LIKE '%matiere_refus_circuit_legal(p_acteur, v_mat, v_mode)%';
    IF n <> 1 THEN RAISE EXCEPTION '% ne transmet pas le mode : le don resterait bloque', nom; END IF;
  END LOOP;

  -- d) Ni la presence ni l'idempotence n'ont ete perdues au passage.
  FOREACH nom IN ARRAY ARRAY['commerce_apporter_matiere', 'fonds_matiere_apporter']
  LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public' AND p.proname = nom
       AND (pg_get_functiondef(p.oid) LIKE '%acteur_present_sur_site%'
         OR pg_get_functiondef(p.oid) LIKE '%fonds_acteur_present%')
       AND pg_get_functiondef(p.oid) LIKE '%apports_matieres%';
    IF n <> 1 THEN RAISE EXCEPTION '% a perdu sa presence ou sa tracabilite', nom; END IF;
  END LOOP;

  -- e) Une seule signature pour chaque primitive de la garde.
  FOREACH nom IN ARRAY ARRAY['matiere_refus_circuit_legal', 'matiere_refus_circuit_legal_lot',
                             'assemblee_loi_en_vigueur', 'assemblee_objet_vise']
  LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public' AND p.proname = nom;
    IF n <> 1 THEN RAISE EXCEPTION '% : % signatures, 1 attendue', nom, n; END IF;
  END LOOP;

  -- f) Aucune loi de test ne doit traverser une migration.
  SELECT count(*) INTO n FROM public.assemblee_propositions WHERE id LIKE 'zzbanc-%';
  IF n <> 0 THEN RAISE EXCEPTION '% loi(s) de test en base : a supprimer avant de deployer', n; END IF;
END $garde$;
