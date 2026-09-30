-- ===========================================================================
-- BANC SERVEUR DU CHANTIER SEB LEX / ASSEMBLEE (30 septembre 2026)
-- ---------------------------------------------------------------------------
-- TOUT EST ANNULE. Le bloc se termine par RAISE EXCEPTION : la transaction est
-- rejetee en entier, y compris le personnage de test, les propositions
-- deposees, les cles d'idempotence et les paliers de sanction. Le rapport
-- voyage dans le message de l'erreur -- c'est le seul canal qui survive a un
-- rollback.
--
-- IL EMPRUNTE UN COMPTE ANONYME SANS PERSONNAGE. exiger_acteur() reclame une
-- identite reelle (auth.uid()), un trigger force user_id := auth.uid(), et une
-- contrainte d'unicite interdit deux personnages pour un compte. On prend donc
-- un des comptes anonymes qui n'ont jamais cree de personnage -- il en restait
-- 357 -- au lieu de detourner celui d'un joueur.
--
-- LES CLES D'IDEMPOTENCE FONT AU MOINS 8 CARACTERES : assemblee_requete_ouvrir
-- refuse plus court avec « requete_invalide », ce qui ressemble a tort a un
-- refus metier.
--
-- CE QU'IL PROUVE :
--   S1  une loi rp se depose sans categorie ni portee
--   S2  une nature inventee par l'IA est refusee au depot (type_invalide)
--   S3  une abrogation forge son titre cote SERVEUR : le client n'en envoie aucun
--   S4  une loi rp n'entre JAMAIS dans le registre du Ministre de l'Interieur
--   S5  une loi rp ne se met pas en application (type_sans_application)
--   S6  une loi rp en retard de 10 jours ne produit AUCUN palier de sanction
--   S7  adoptee != appliquee, pour une interdiction comme pour une abrogation
--   S8  le catalogue legislatif decrit le monde reel, pas une liste recopiee
--
-- RESULTAT DU 30 SEPTEMBRE 2026 :
--   S1  depot rp            ok=true type=rp categorie=(null) data={}
--   S2  nature inventee     ok=false raison=type_invalide
--   S3a depot mecanique     ok=true categorie=textile portee={"transformation_stock_interdite": false}
--   S3b abrogation          ok=true titre=Abrogation — Interdiction du textile cible=la bonne
--   S4  registre ministre   la loi rp y figure 0 fois (registre de 1 lignes)
--   S5  application d'une rp ok=false raison=type_sans_application
--   S6  sanctions           paliers pour la rp (10 jours de retard)=0 ; total applique=4
--   S7a interdiction adoptee non appliquee : loi=(aucune)
--   S7b interdiction appliquee            : loi=Interdiction du textile
--   S7c abrogation adoptee non appliquee   : loi=Interdiction du textile
--   S7d le ministre applique l'abrogation ok=true cible_eteinte=Interdiction du textile
--   S7e apres application                 : loi=(aucune)
--   S8  catalogue          21 categories, 17 matieres, dimensions=["transformation_stock_interdite"]
-- ===========================================================================
DO $banc$
DECLARE
  R text := '';
  A text := 'zzSebBanc';
  P text := 'republic';
  U uuid;
  v jsonb; n integer;
  id_rp text; id_cible text; id_abr text;
BEGIN
  SELECT u.id INTO U FROM auth.users u
    LEFT JOIN public.personnages_donnees p ON p.user_id = u.id
   WHERE p.user_id IS NULL LIMIT 1;
  PERFORM set_config('request.jwt.claims',
          json_build_object('sub', U::text, 'role', 'authenticated')::text, true);

  -- Depute (donc deposant) ET Ministre de l'Interieur (donc seul habilite a
  -- mettre en application), assis dans l'hemicycle. Les deux casquettes a la
  -- fois, pour que S5 echoue sur la NATURE de la loi et non sur le poste.
  INSERT INTO public.personnages_donnees (name, country, resources, poste, poste_depute,
                                          current_building, current_room)
  VALUES (A, P, jsonb_build_object('pa', 20, 'arg', 5000, 'liquide', 5000, 'pop', 50),
          jsonb_build_object('id','min_int'), jsonb_build_object('id','depute'),
          'assemblee', 'hemicycle');

  -- ===== S1/S2 : LA NATURE VIENT DE SEB, LE SERVEUR L'ADMET OU LA REFUSE =====
  v := public.assemblee_deposer_projet('rq-banc-bbbb01', A, 'Gratuite de l''instruction', 'rp',
        'L''Assemblee proclame la gratuite de l''instruction publique.', NULL, NULL, NULL);
  id_rp := v -> 'proposition' ->> 'id';
  R := R || format('S1  depot rp            ok=%s type=%s categorie=%s data=%s',
        v ->> 'ok', coalesce(v -> 'proposition' ->> 'type','-'),
        coalesce(v -> 'proposition' ->> 'categorie','(null)'),
        coalesce(v -> 'proposition' ->> 'data','-')) || E'\n';
  v := public.assemblee_deposer_projet('rq-banc-bbbb02', A, 'Confiscation', 'confiscation',
        'On confisque tout.', NULL, NULL, NULL);
  R := R || format('S2  nature inventee     ok=%s raison=%s', v ->> 'ok', v ->> 'raison') || E'\n';

  -- ===== S3 : L'ABROGATION FORGE SON TITRE, LE CLIENT N'EN ENVOIE AUCUN =====
  v := public.assemblee_deposer_projet('rq-banc-bbbb03', A, 'Interdiction du textile', 'mecanique',
        'Le textile est interdit.', 'textile', NULL,
        jsonb_build_object('transformation_stock_interdite', false));
  id_cible := v -> 'proposition' ->> 'id';
  R := R || format('S3a depot mecanique     ok=%s categorie=%s portee=%s', v ->> 'ok',
        coalesce(v -> 'proposition' ->> 'categorie','(null)'),
        coalesce(v -> 'proposition' -> 'data' ->> 'portee','-')) || E'\n';
  UPDATE public.assemblee_propositions SET statut='adoptee', adoptee_ts = now() - interval '5 days'
   WHERE id = id_cible;
  v := public.assemblee_deposer_projet('rq-banc-bbbb04', A, NULL, 'abrogation',
        'On abroge l''interdiction du textile.', NULL, id_cible, NULL);
  id_abr := v -> 'proposition' ->> 'id';
  R := R || format('S3b abrogation          ok=%s titre=%s cible=%s', v ->> 'ok',
        coalesce(v -> 'proposition' ->> 'titre','(null)'),
        CASE WHEN v -> 'proposition' ->> 'loi_cible_id' = id_cible
             THEN 'la bonne' ELSE '(autre)' END) || E'\n';

  -- ===== S4/S5/S6 : LA LOI RP EST TERMINEE DES SON ADOPTION =================
  UPDATE public.assemblee_propositions SET statut='adoptee', adoptee_ts = now() - interval '10 days'
   WHERE id = id_rp;
  v := public.assemblee_registre_execution(P);
  SELECT count(*) INTO n FROM jsonb_array_elements(v) e WHERE e ->> 'id' = id_rp;
  R := R || format('S4  registre ministre   la loi rp y figure %s fois (registre de %s lignes)',
        n, jsonb_array_length(v)) || E'\n';
  v := public.assemblee_mettre_en_application('rq-banc-bbbb05', A, id_rp);
  R := R || format('S5  application d''une rp ok=%s raison=%s',
        v ->> 'ok', coalesce(v ->> 'raison','(aucune)')) || E'\n';
  -- Le cron appelle la sanction en service_role : on se met dans ses conditions.
  PERFORM set_config('request.jwt.claims',
          json_build_object('sub', U::text, 'role', 'service_role')::text, true);
  v := public.assemblee_sanctionner_lois_non_appliquees(P);
  SELECT count(*) INTO n FROM public.assemblee_sanctions_paliers WHERE proposition_id = id_rp;
  R := R || format('S6  sanctions           paliers pour la rp (10 jours de retard)=%s ; total applique=%s',
        n, coalesce(v ->> 'paliers_appliques','?')) || E'\n';
  PERFORM set_config('request.jwt.claims',
          json_build_object('sub', U::text, 'role', 'authenticated')::text, true);

  -- ===== S7 : ADOPTEE != APPLIQUEE, DANS LES DEUX SENS =====================
  v := public.assemblee_loi_en_vigueur(P, jsonb_build_object('stackKey','textile'), now());
  R := R || format('S7a interdiction adoptee non appliquee : loi=%s',
        coalesce(v ->> 'titre','(aucune)')) || E'\n';
  UPDATE public.assemblee_propositions SET appliquee_ts = now() - interval '4 days'
   WHERE id = id_cible;
  v := public.assemblee_loi_en_vigueur(P, jsonb_build_object('stackKey','textile'), now());
  R := R || format('S7b interdiction appliquee            : loi=%s',
        coalesce(v ->> 'titre','(aucune)')) || E'\n';
  UPDATE public.assemblee_propositions SET statut='adoptee', adoptee_ts = now() - interval '1 hour'
   WHERE id = id_abr;
  v := public.assemblee_loi_en_vigueur(P, jsonb_build_object('stackKey','textile'), now());
  R := R || format('S7c abrogation adoptee non appliquee   : loi=%s',
        coalesce(v ->> 'titre','(aucune)')) || E'\n';
  v := public.assemblee_mettre_en_application('rq-banc-bbbb06', A, id_abr);
  R := R || format('S7d le ministre applique l''abrogation ok=%s raison=%s cible_eteinte=%s',
        v ->> 'ok', coalesce(v ->> 'raison','-'),
        coalesce(v -> 'cible_eteinte' ->> 'titre','(aucune)')) || E'\n';
  v := public.assemblee_loi_en_vigueur(P, jsonb_build_object('stackKey','textile'), now());
  R := R || format('S7e apres application                 : loi=%s',
        coalesce(v ->> 'titre','(aucune)')) || E'\n';

  -- ===== S8 : LE CATALOGUE DECRIT LE MONDE, IL NE LE RECOPIE PAS ===========
  v := public.assemblee_catalogue_legislatif();
  R := R || format('S8  catalogue          %s categories, %s matieres, dimensions=%s',
        jsonb_array_length(v -> 'categories'), jsonb_array_length(v -> 'matieres'),
        v -> 'portee_dimensions') || E'\n';

  RAISE EXCEPTION E'\n===== BANC SERVEUR SEB LEX (tout annule) =====\n%', R;
END $banc$;
