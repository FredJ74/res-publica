-- ===========================================================================
-- VALIDATION SERVEUR DU CORRECTIF « NOM DE L'ORDRE » (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- CE QUE CE BANC PROUVE, ET QUE LES BANCS CLIENTS NE PEUVENT PAS PROUVER. Les deux
-- autres bancs de ce lot verifient que le navigateur ENVOIE desormais le bon nom
-- d'ordre. Celui-ci verifie ce que le SERVEUR en fait : que le triplet corrige est
-- accepte, que les deux formes de l'ancien defaut etaient bien refusees, et surtout
-- que le correctif n'ouvre aucune porte.
--
-- METHODE : le DDL de PostgreSQL etant transactionnel, tout s'execute puis tout est
-- annule par le RAISE EXCEPTION final. Aucune ligne ne subsiste.
--
-- LE DEFAUT CORRIGE. Le bouton « Prendre un taxi » de la rue de la Caserne et du QHS
-- appelle directement ouvrirModalTransport('bus'), sans passer par doOrder qui depose
-- state._ordreEnCours. deduireCoutOrdre partait donc sans nom d'ordre, ou avec celui de
-- l'ordre precedent. Comme ni la Caserne ni le QHS n'ont de Centre Multimodal, ce bouton
-- est la SEULE sortie : le joueur pouvait y rester bloque.
--
-- RESULTAT DU 1er OCTOBRE 2026 -- 7 controles, aucun ecart :
--   T1 triplet corrige        ok=true                      <- prendre_bus_taxi 1/150
--   T2 sans nom d'ordre       ok=false raison=ordre_inconnu <- l'ancien defaut
--   T3 nom de l'ordre d'avant ok=false raison=ordre_inconnu <- l'autre forme du defaut
--   T4 train 2/75             ok=true
--   T4 avion 2/300            ok=true
--   T4 bateau 5/100           ok=true
--   T5 tarif invente 1/1      ok=false raison=cout_non_declare
--
-- CE QUE T3 CONFIRME AU PASSAGE : 'candidatures_section' -- le nom sous lequel un taxi
-- avait reellement ete facture le 23 septembre, trace dans ordres_couts_ecarts -- n'est
-- plus au miroir. L'ancien chemin echouait donc des deux facons possibles.
--
-- CE QUE T5 GARANTIT : la validation du couple (pa, cost) contre le miroir est intacte.
-- Transmettre le nom de l'ordre ne dispense de rien ; cela permet seulement au serveur de
-- savoir quel barème appliquer.
-- ===========================================================================
DO $banc$
DECLARE
  R text := ''; A text := 'zzTaxiCorrectif'; v_u uuid; v jsonb;
BEGIN
  SELECT u.id INTO v_u FROM auth.users u
    LEFT JOIN public.personnages_donnees p ON p.user_id = u.id
   WHERE p.user_id IS NULL LIMIT 1;
  IF v_u IS NULL THEN RAISE EXCEPTION 'banc : aucun compte libre'; END IF;
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_u::text, 'role', 'authenticated')::text, true);
  -- PIEGE DEJA PAYE DANS CE DEPOT : l'argent d'un personnage vit dans la COLONNE
  -- `liquide`, pas dans le jsonb `resources`. Un test dote via resources voit tous ses
  -- paiements refuses, pour une raison qui n'a rien a voir avec ce qu'on mesure.
  INSERT INTO public.personnages_donnees (name, country, resources, liquide,
                                          current_building, current_room)
  VALUES (A, 'republic', jsonb_build_object('pa', 20), 50000, NULL, NULL);

  v := public.payer_ordre(A, 'prendre_bus_taxi', 1, 150);
  R := R || format('T1 triplet corrige        ok=%s raison=%s', v->>'ok',
        coalesce(v->>'raison','-')) || E'\n';

  v := public.payer_ordre(A, NULL, 1, 150);
  R := R || format('T2 sans nom d''ordre       ok=%s raison=%s', v->>'ok',
        coalesce(v->>'raison','-')) || E'\n';

  v := public.payer_ordre(A, 'candidatures_section', 1, 150);
  R := R || format('T3 nom de l''ordre d''avant ok=%s raison=%s', v->>'ok',
        coalesce(v->>'raison','-')) || E'\n';

  v := public.payer_ordre(A, 'prendre_train', 2, 75);
  R := R || format('T4 train 2/75             ok=%s', v->>'ok') || E'\n';
  v := public.payer_ordre(A, 'prendre_avion', 2, 300);
  R := R || format('T4 avion 2/300            ok=%s', v->>'ok') || E'\n';
  v := public.payer_ordre(A, 'prendre_bateau', 5, 100);
  R := R || format('T4 bateau 5/100           ok=%s', v->>'ok') || E'\n';

  v := public.payer_ordre(A, 'prendre_bus_taxi', 1, 1);
  R := R || format('T5 tarif invente 1/1      ok=%s raison=%s', v->>'ok',
        coalesce(v->>'raison','-')) || E'\n';

  RAISE EXCEPTION E'\n===== VALIDATION SERVEUR DU CORRECTIF TAXI =====\n%', R;
END $banc$;
