-- BANC ANNULE -- serrures (issue #434). A jouer APRES le corps des six migrations
-- 20261104124000 .. 20261104124400, dans la MEME transaction, qui finit par une exception :
-- rien ne reste. Parcours complet, comme le navigateur (session de Jean Jaaj, puis d'Angie) :
-- fabrication, achat, rejeu, cles vierges, double, pose sur le bureau, fermeture, porte refusee
-- a un tiers puis ouverte a qui recoit une cle, armoire installee, serrure d'armoire, fin de bail.
DO $$
DECLARE j text := 'Jean Jaaj'; a text := 'Angie Porcelana'; uj uuid; ua uuid; r jsonb; r2 jsonb; q uuid := gen_random_uuid();
  ent text := 'armurerie-republic-capitale'; sid uuid; sid2 uuid; arm uuid; inv jsonb; n integer; arg0 numeric; arg1 numeric;
  caisse0 numeric; caisse1 numeric; bail text := 'republic:centre-affaires:bureau_prestige:capitale';
BEGIN
  SELECT user_id INTO uj FROM public.personnages_donnees WHERE name = j;
  SELECT user_id INTO ua FROM public.personnages_donnees WHERE name = a;
  PERFORM set_config('request.path', '/rpc/banc', true);
  UPDATE public.personnages_donnees SET pa = 30, current_city = 'capitale', current_building = 'armurerie',
         current_room = 'magasin', current_street = NULL, country = 'republic' WHERE name = j;
  UPDATE public.entreprises SET data = jsonb_set(data, '{stockMatieres,metal}', '10') WHERE id = ent;

  -- 1. Fabrication par un PJ present (2 metal + 1 PA = 2 serrures ; 1 metal + 1 PA = 10 cles).
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.commerce_produire(j, ent, 'serrure_cle', NULL);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'portions')::int <> 2 OR (r->>'paPreleves')::int <> 1 OR (r->>'salaire')::numeric <> 50 THEN
    RAISE EXCEPTION 'production serrure: %', r; END IF;
  r := public.commerce_produire(j, ent, 'cle_vierge', NULL);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'portions')::int <> 10 THEN RAISE EXCEPTION 'production cles: %', r; END IF;
  r := public.commerce_produire(j, ent, 'serrure_inexistante', NULL);
  IF r->>'raison' IS DISTINCT FROM 'recette_inconnue' THEN RAISE EXCEPTION 'recette inconnue: %', r; END IF;
  RESET ROLE;
  SELECT (data->'stockMatieres'->>'metal')::numeric INTO caisse0 FROM public.entreprises WHERE id = ent;
  IF caisse0 <> 7 THEN RAISE EXCEPTION 'metal restant % (attendu 7)', caisse0; END IF;

  -- 2. Achat d'une serrure (60 FR), rejeu de la meme requete sans second paiement.
  SELECT arg INTO arg0 FROM public.personnages_donnees WHERE name = j;
  SELECT (data->>'caisse')::numeric INTO caisse0 FROM public.entreprises WHERE id = ent;
  SET LOCAL ROLE authenticated;
  r := public.quincaillerie_acheter(q, ent, 'serrure_cle', 1);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'total')::numeric <> 60 THEN RAISE EXCEPTION 'achat serrure: %', r; END IF;
  sid := (r->'serrure'->>'id')::uuid;
  r2 := public.quincaillerie_acheter(q, ent, 'serrure_cle', 1);
  IF r2->'serrure'->>'id' IS DISTINCT FROM sid::text THEN RAISE EXCEPTION 'rejeu: %', r2; END IF;
  r2 := public.quincaillerie_acheter(gen_random_uuid(), ent, 'serrure_cle', 2);
  IF r2->>'raison' IS DISTINCT FROM 'quantite_invalide' THEN RAISE EXCEPTION 'quantite serrure: %', r2; END IF;
  -- 3. Trois cles vierges (14 FR), empilees.
  r := public.quincaillerie_acheter(gen_random_uuid(), ent, 'cle_vierge', 3);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'total')::numeric <> 42 THEN RAISE EXCEPTION 'achat cles: %', r; END IF;
  RESET ROLE;
  -- Jamais au marche noir (moteur interne, ferme aux joueurs : appele ici en role serveur).
  r := public.commerce_vendre_produit_interne(j, ent, '[{"produit":"serrure_cle","qte":1}]', 'marche_noir', NULL, 0, 0, NULL, NULL);
  IF r->>'raison' IS DISTINCT FROM 'produit_non_propose' THEN RAISE EXCEPTION 'marche noir: %', r; END IF;
  SELECT arg, inventory INTO arg1, inv FROM public.personnages_donnees WHERE name = j;
  SELECT (data->>'caisse')::numeric INTO caisse1 FROM public.entreprises WHERE id = ent;
  IF arg0 - arg1 <> 102 THEN RAISE EXCEPTION 'debit % (attendu 102)', arg0 - arg1; END IF;
  IF caisse1 <= caisse0 THEN RAISE EXCEPTION 'caisse % -> %', caisse0, caisse1; END IF;
  IF (SELECT count(*) FROM public.serrures WHERE achetee_par = j AND statut = 'neuve') <> 1 THEN RAISE EXCEPTION 'une serrure neuve attendue'; END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(inv) e WHERE e->>'type' = 'serrure_cle' AND e->>'serrureId' = sid::text)
     OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(inv) e WHERE e->>'type' = 'cle_serrure' AND e->>'serrureId' = sid::text AND (e->>'qty')::int = 1)
     OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(inv) e WHERE e->>'type' = 'cle_vierge' AND (e->>'qty')::int = 3) THEN
    RAISE EXCEPTION 'inventaire apres achats: %', inv; END IF;
  IF (SELECT count(*) FROM public.registre_ventes_armes WHERE joueur = j AND jour IS NOT NULL AND arme ~* 'serrure|cle') > 0 THEN
    RAISE EXCEPTION 'la quincaillerie ne va pas au registre des armes'; END IF;

  -- 4. Double de cle.
  SET LOCAL ROLE authenticated;
  r := public.cle_dupliquer(gen_random_uuid(), sid);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'double: %', r; END IF;
  RESET ROLE;
  SELECT inventory INTO inv FROM public.personnages_donnees WHERE name = j;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(inv) e WHERE e->>'type' = 'cle_serrure' AND (e->>'qty')::int = 2)
     OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(inv) e WHERE e->>'type' = 'cle_vierge' AND (e->>'qty')::int = 2) THEN
    RAISE EXCEPTION 'inventaire apres double: %', inv; END IF;

  -- 5. Pose sur le bureau loue, hors du bureau d'abord (refus), puis dans le bureau.
  SET LOCAL ROLE authenticated;
  r := public.serrure_poser(gen_random_uuid(), sid, 'lieu', NULL);
  IF r->>'raison' IS DISTINCT FROM 'pas_de_jouissance' THEN RAISE EXCEPTION 'pose a l''armurerie: %', r; END IF;
  RESET ROLE;
  UPDATE public.personnages_donnees SET current_building = 'centre-affaires', current_room = 'bureau_prestige' WHERE name = j;
  SET LOCAL ROLE authenticated;
  r := public.serrure_poser(gen_random_uuid(), sid, 'lieu', NULL);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'pose: %', r; END IF;
  r := public.serrure_poser(gen_random_uuid(), sid, 'lieu', NULL);
  IF r->>'raison' IS DISTINCT FROM 'serrure_deja_posee' THEN RAISE EXCEPTION 'repose: %', r; END IF;
  r := public.serrure_basculer(sid, true);
  IF (r->>'ok')::boolean IS NOT TRUE OR (r->>'fermee')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'fermer: %', r; END IF;
  r := public.equipements_local_lire();
  IF (r->'serrures'->'lieu'->>'fermee')::boolean IS NOT TRUE OR (r->'serrures'->'lieu'->>'a_cle')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'lecture du local: %', r; END IF;
  RESET ROLE;
  SELECT inventory INTO inv FROM public.personnages_donnees WHERE name = j;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(inv) e WHERE e->>'type' = 'serrure_cle') THEN RAISE EXCEPTION 'bloc non consomme'; END IF;

  -- 6. Porte fermee : Angie, dans le hall, ne peut pas entrer ; Jaaj, avec sa cle, oui.
  UPDATE public.personnages_donnees SET country = 'republic', current_city = 'capitale', current_building = 'centre-affaires',
         current_room = 'hall', current_street = NULL WHERE name = a;
  r := public.navigation_interieure_personnage_interne(a, 'centre-affaires', 'bureau_prestige', true);
  IF r->>'raison' IS DISTINCT FROM 'porte_fermee_a_cle' THEN RAISE EXCEPTION 'porte pour Angie: %', r; END IF;
  IF public.serrure_porte_fermee_interne(j, 'republic', 'capitale', 'centre-affaires', 'bureau_prestige') THEN
    RAISE EXCEPTION 'Jaaj a la cle'; END IF;
  -- Angie recoit une cle (la cle est transmissible) : elle entre.
  PERFORM public.inventaire_deposer_interne(a, public.serrure_cle_objet_interne(sid, 1));
  r := public.navigation_interieure_personnage_interne(a, 'centre-affaires', 'bureau_prestige', true);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'Angie avec cle: %', r; END IF;

  -- 7. Armoire : installation dans le bureau, serrure posee, fermee : desinstallation refusee.
  PERFORM public.inventaire_deposer_interne(j, '{"type":"armoire_souvenirs","name":"armoire_souvenirs","encombrement":3,"desc":"banc"}'::jsonb);
  r := public.quincaillerie_acheter(gen_random_uuid(), ent, 'serrure_cle', 1); -- hors armurerie
  IF r->>'raison' IS DISTINCT FROM 'acteur_non_authentifie' AND r->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'achat a distance: %', r; END IF;
  INSERT INTO public.serrures (statut, achetee_par, entreprise) VALUES ('neuve', j, ent) RETURNING id INTO sid2;
  PERFORM public.inventaire_deposer_interne(j, public.serrure_objet_interne(sid2));
  PERFORM public.inventaire_deposer_interne(j, public.serrure_cle_objet_interne(sid2, 1));
  SET LOCAL ROLE authenticated;
  r := public.equipement_installer('armoire_souvenirs');
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'installer armoire: %', r; END IF;
  r := public.equipements_local_lire();
  arm := (r->'serrures'->'armoires_posables'->>0)::uuid;
  IF arm IS NULL THEN RAISE EXCEPTION 'armoire posable: %', r; END IF;
  r := public.serrure_poser(gen_random_uuid(), sid2, 'armoire', arm);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'pose armoire: %', r; END IF;
  r := public.serrure_basculer(sid2, true);
  r := public.equipement_desinstaller(arm);
  IF r->>'raison' IS DISTINCT FROM 'armoire_fermee_a_cle' THEN RAISE EXCEPTION 'desinstaller fermee: %', r; END IF;
  r := public.serrure_basculer(sid2, false);
  r := public.equipement_desinstaller(arm);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'desinstaller: %', r; END IF;
  RESET ROLE;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees, jsonb_array_elements(inventory) e
                  WHERE name = j AND e->>'type' = 'armoire_souvenirs' AND coalesce(e->>'id','') <> '') THEN
    RAISE EXCEPTION 'armoire revenue sans identifiant'; END IF;

  -- 8. Fin de bail : la serrure du lieu est detruite pour tout le monde, la cle n'ouvre plus rien.
  UPDATE public.locations_actives SET data = data || '{"locataire":"Quelqu''un d''autre","orgaId":null}'::jsonb WHERE id = bail;
  IF public.serrure_porte_fermee_interne(a, 'republic', 'capitale', 'centre-affaires', 'bureau_prestige') THEN
    RAISE EXCEPTION 'porte encore fermee apres la fin du bail'; END IF;
  IF (SELECT statut FROM public.serrures WHERE id = sid) <> 'detruite' THEN RAISE EXCEPTION 'serrure non detruite'; END IF;
  SET LOCAL ROLE authenticated;
  r := public.serrure_basculer(sid, true);
  IF r->>'raison' IS DISTINCT FROM 'serrure_detruite' THEN RAISE EXCEPTION 'cle d''une serrure detruite: %', r; END IF;
  r := public.cle_dupliquer(gen_random_uuid(), sid);
  IF r->>'raison' IS DISTINCT FROM 'serrure_detruite' THEN RAISE EXCEPTION 'double d''une serrure detruite: %', r; END IF;
  RESET ROLE;
  SELECT count(*) INTO n FROM public.mails WHERE to_player = j AND subject = 'Serrure détruite';
  IF n < 1 THEN RAISE EXCEPTION 'courrier de destruction absent'; END IF;

  RAISE EXCEPTION 'banc_ok_rien_ne_reste (serrure %, armoire %, debit 102 FR)', public.serrure_numero_interne(sid), arm;
END $$;
