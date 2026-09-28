-- =====================================================================
-- BANC C0 + C1 — MOTEUR COMMERCIAL PJ
-- =====================================================================
-- REJOUABLE A VOLONTE, SANS AUCUN RESIDU. Chaque bloc construit sa propre
-- fixture, joue ses cas, puis leve une exception : la transaction est annulee
-- INTEGRALEMENT, fixture comprise. Les resultats arrivent dans le message
-- d'erreur -- c'est volontaire, c'est ce qui garantit le rollback.
--
-- A executer via le workflow technique habituel (jamais demande a l'utilisateur).
-- Les deux blocs utilisent le personnage de test `zzAut` comme acheteur et
-- `Arnie` comme tiers ; ils ne sont jamais modifies durablement.
--
-- ATTENDUS, tels que constates le 28 septembre 2026 :
--   C0  T1  achat de 3 souvenirs : argent 300 -> 180, sas +3, caisse 120, stock 2
--       T2  REJEU de la meme cle : rien ne bouge, ok:true rejeu:true
--       T3  objet construit par le serveur, fiche resolue, aucun_effet:true
--       T4  achat empilable : une seule ligne, stackable/stackKey/qty
--       T5  reference_sans_generique      T6  generique_est_un_service
--       T7  generique_regime_indetermine  T8  variante_incoherente
--       T9  requete_invalide             T10  quantite_invalide
--      T11  fonds_absent                 T12  quantite bornee par les fonds
--   C1  vocations : les 3 centres resolvent, tout le reste rend NULL
--       T1  creation sur local commercial : references={}, typesAutorises=[], pas de famille
--       T2  creation sur suite d'hotel : local_non_commercial
--       T3  1 type   T4  2 types (plafond)   T5  3 types -> trop_de_types
--       T6  type_inconnu   T7  doublons normalises   T8  pas_proprietaire
--       T9  etablissement PNJ legacy -> pas_un_fonds_pj (le legacy est protege)
--      T10  cascade DERIVEE type -> famille -> generique, sans table de jointure

-- ---------------------------------------------------------------------------
-- BLOC 1 — C0 : ACHAT SECURISE
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r jsonb; rap text := E'\n';
  v_svc text; a0 numeric; a1 numeric; a2 numeric; s1 int; s2 int;
  v_caisse numeric; v_stock numeric; v_data jsonb; v_fiche jsonb; v_brut text;
BEGIN
  SELECT id INTO v_svc FROM public.catalogue_generiques WHERE est_service ORDER BY id LIMIT 1;
  INSERT INTO public.entreprises (id, data) VALUES ('zztest-c0-fonds', jsonb_build_object(
    'version', 2, 'type', 'fonds_commerce', 'statut', 'actif',
    'proprietaire', 'pj:Arnie', 'enseigne', 'Boutique de test C0', 'caisse', 0,
    'references', jsonb_build_object(
      'ref-souvenir', jsonb_build_object('active', true, 'prixVente', 40, 'stock', 5,
                        'generique_id','souvenir','nom','Figurine du Palais','description','Une babiole.'),
      'ref-sans-gen', jsonb_build_object('active', true, 'prixVente', 10, 'stock', 5),
      'ref-service',  jsonb_build_object('active', true, 'prixVente', 10, 'stock', 5, 'generique_id', v_svc),
      'ref-sans-reg', jsonb_build_object('active', true, 'prixVente', 10, 'stock', 5, 'generique_id','boisson'),
      'ref-empil',    jsonb_build_object('active', true, 'prixVente', 5, 'stock', 9, 'generique_id','aliment-brut','nom','Cereales du Nord'),
      'ref-var-faux', jsonb_build_object('active', true, 'prixVente', 10, 'stock', 5,
                        'generique_id','souvenir','variante_id','appareil-de-communication--militaire')
    )));
  SELECT arg INTO a0 FROM public.personnages_donnees WHERE name='zzAut';
  SELECT count(*) INTO s1 FROM public.objets_recus;

  r := public.acheter_produit_commerce('achat-c0test-001','zzAut','zztest-c0-fonds','ref-souvenir',3);
  SELECT arg INTO a1 FROM public.personnages_donnees WHERE name='zzAut';
  SELECT count(*) INTO s2 FROM public.objets_recus;
  SELECT (data::jsonb->>'caisse')::numeric, (data::jsonb->'references'->'ref-souvenir'->>'stock')::numeric
    INTO v_caisse, v_stock FROM public.entreprises WHERE id='zztest-c0-fonds';
  rap := rap || 'T1 achat nominal (3 individualises) : ' || r::text || E'\n'
             || '   argent ' || a0 || ' -> ' || a1 || '  sas +' || (s2-s1)
             || '  caisse ' || v_caisse || '  stock ' || v_stock || E'\n';

  r := public.acheter_produit_commerce('achat-c0test-001','zzAut','zztest-c0-fonds','ref-souvenir',3);
  SELECT arg INTO a2 FROM public.personnages_donnees WHERE name='zzAut';
  SELECT (data::jsonb->>'caisse')::numeric, (data::jsonb->'references'->'ref-souvenir'->>'stock')::numeric
    INTO v_caisse, v_stock FROM public.entreprises WHERE id='zztest-c0-fonds';
  rap := rap || 'T2 REJEU meme cle                   : ' || r::text || E'\n'
             || '   argent inchange=' || (a2=a1) || '  caisse inchangee=' || (v_caisse=120)
             || '  stock inchange=' || (v_stock=2)
             || '  sas inchange=' || (s2=(SELECT count(*) FROM public.objets_recus)) || E'\n';

  SELECT data#>>'{}' INTO v_brut FROM public.objets_recus WHERE id='achat-c0test-001-1';
  v_data := v_brut::jsonb;
  v_fiche := public.objet_fiche_officielle(v_data);
  rap := rap || 'T3 objet construit par le SERVEUR   : name=' || (v_data->>'name')
             || '  generique_id=' || (v_data->>'generique_id')
             || '  qty=' || (v_data->>'qty')
             || '  exemplaire=' || (v_data->'exemplaire'->>'id')
             || '  legal=' || (v_data->>'legal') || E'\n'
             || '   data est une chaine JSON ? ' || (jsonb_typeof((SELECT data FROM public.objets_recus WHERE id='achat-c0test-001-1'))='string') || E'\n'
             || '   fiche: resolu=' || (v_fiche->>'resolu') || ' generique=' || (v_fiche->>'generique')
             || ' famille=' || (v_fiche->>'famille') || ' aucun_effet=' || (v_fiche->>'aucun_effet') || E'\n';

  r := public.acheter_produit_commerce('achat-c0test-002','zzAut','zztest-c0-fonds','ref-empil',4);
  SELECT data#>>'{}' INTO v_brut FROM public.objets_recus WHERE id='achat-c0test-002';
  rap := rap || 'T4 achat empilable (4)              : ' || r::text || E'\n'
             || '   objet: stackable=' || (v_brut::jsonb->>'stackable') || ' stackKey=' || (v_brut::jsonb->>'stackKey')
             || ' qty=' || (v_brut::jsonb->>'qty') || E'\n';

  rap := rap || 'T5 reference sans generique         : ' || public.acheter_produit_commerce('achat-c0test-005','zzAut','zztest-c0-fonds','ref-sans-gen',1)::text || E'\n';
  rap := rap || 'T6 generique est un service         : ' || public.acheter_produit_commerce('achat-c0test-006','zzAut','zztest-c0-fonds','ref-service',1)::text || E'\n';
  rap := rap || 'T7 regime indetermine (boisson)     : ' || public.acheter_produit_commerce('achat-c0test-007','zzAut','zztest-c0-fonds','ref-sans-reg',1)::text || E'\n';
  rap := rap || 'T8 variante incoherente             : ' || public.acheter_produit_commerce('achat-c0test-008','zzAut','zztest-c0-fonds','ref-var-faux',1)::text || E'\n';
  rap := rap || 'T9 cle de requete mal formee        : ' || public.acheter_produit_commerce('pas-une-cle','zzAut','zztest-c0-fonds','ref-souvenir',1)::text || E'\n';
  rap := rap || 'T10 quantite nulle                  : ' || public.acheter_produit_commerce('achat-c0test-010','zzAut','zztest-c0-fonds','ref-souvenir',0)::text || E'\n';
  rap := rap || 'T11 fonds inexistant                : ' || public.acheter_produit_commerce('achat-c0test-011','zzAut','zztest-absent','ref-souvenir',1)::text || E'\n';
  rap := rap || 'T12 quantite bornee par les fonds   : ' || public.acheter_produit_commerce('achat-c0test-012','zzAut','zztest-c0-fonds','ref-souvenir',99)::text || E'\n';

  RAISE EXCEPTION 'BANC C0 -- transaction annulee, aucun residu %', rap;
END $$;

-- ---------------------------------------------------------------------------
-- BLOC 2 — C1 : LOCAL EXISTANT, FONDS, TYPES L2
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r jsonb; rap text := E'\n'; v_data jsonb; n int;
BEGIN
  rap := rap || 'VOCATIONS DERIVEES' || E'\n';
  FOR r IN SELECT jsonb_build_object('b', b, 'v', coalesce(public.local_vocation_commerciale(b),'(aucune)'))
             FROM unnest(ARRAY['centre-commercial','centre-artisanal','centre-affaires',
                               'hotel-republica','banque-nationale','centre-culturel',
                               'immeuble-montrouge','terrain-a-batir-1']) b LOOP
    rap := rap || '   ' || rpad(r->>'b', 22) || ' -> ' || (r->>'v') || E'\n';
  END LOOP;

  INSERT INTO public.locations_actives (id, country, data) VALUES (
    'republic:centre-commercial:vitrine_principale:capitale', 'republic',
    jsonb_build_object('buildingId','centre-commercial','roomId','vitrine_principale',
      'locataire','zzAut','country','republic','city','capitale','lotId',null,
      'localKey','republic|capitale|centre-commercial|vitrine_principale','prix',800));
  INSERT INTO public.locations_actives (id, country, data) VALUES (
    'republic:hotel-republica:suite_privee:capitale', 'republic',
    jsonb_build_object('buildingId','hotel-republica','roomId','suite_privee',
      'locataire','zzAut','country','republic','city','capitale','lotId',null,'prix',500));

  r := public.creer_fonds_commerce('zzAut','republic:centre-commercial:vitrine_principale:capitale','zztest-c1-fonds',0,'Manga Paradise');
  rap := rap || E'\nT1 creation sur local commercial : ' || r::text || E'\n';
  SELECT data INTO v_data FROM public.entreprises WHERE id='zztest-c1-fonds';
  rap := rap || '   version=' || (v_data->>'version') || ' vocation=' || (v_data->'implantation'->>'vocation')
             || ' references=' || (v_data->'references')::text || ' typesAutorises=' || (v_data->'typesAutorises')::text
             || ' famille=' || coalesce(v_data->>'famille','(absente, voulu)') || E'\n';

  r := public.creer_fonds_commerce('zzAut','republic:hotel-republica:suite_privee:capitale','zztest-c1-suite',0,'Boutique illegitime');
  rap := rap || 'T2 creation sur suite d hotel    : ' || r::text || E'\n';

  rap := rap || 'T3 un seul type                  : ' || public.fonds_definir_types('zzAut','zztest-c1-fonds', ARRAY['arts-culture'])::text || E'\n';
  rap := rap || 'T4 deux types (plafond)          : ' || public.fonds_definir_types('zzAut','zztest-c1-fonds', ARRAY['vetements','arts-culture'])::text || E'\n';
  rap := rap || 'T5 trois types (au dela)         : ' || public.fonds_definir_types('zzAut','zztest-c1-fonds', ARRAY['vetements','arts-culture','pharmacie'])::text || E'\n';
  rap := rap || 'T6 type inconnu                  : ' || public.fonds_definir_types('zzAut','zztest-c1-fonds', ARRAY['boulangerie-imaginaire'])::text || E'\n';
  rap := rap || 'T7 doublons normalises           : ' || public.fonds_definir_types('zzAut','zztest-c1-fonds', ARRAY['vetements','vetements','arts-culture'])::text || E'\n';
  rap := rap || 'T8 pas le proprietaire           : ' || public.fonds_definir_types('Arnie','zztest-c1-fonds', ARRAY['vetements'])::text || E'\n';
  rap := rap || 'T9 etablissement legacy (PNJ)    : ' || public.fonds_definir_types('zzAut','armurerie-republic-capitale', ARRAY['armurerie'])::text || E'\n';

  SELECT data INTO v_data FROM public.entreprises WHERE id='zztest-c1-fonds';
  rap := rap || E'\nT10 cascade derivee pour ' || (v_data->'typesAutorises')::text || E'\n';
  FOR r IN SELECT jsonb_build_object('f', f.libelle, 'n', count(*))
             FROM public.catalogue_generique_type gt
             JOIN public.catalogue_generiques g ON g.id = gt.generique_id
             JOIN public.catalogue_familles f ON f.id = g.famille_id
            WHERE gt.type_id IN (SELECT jsonb_array_elements_text(v_data->'typesAutorises'))
            GROUP BY f.libelle ORDER BY f.libelle LOOP
    rap := rap || '   famille ' || rpad(r->>'f', 28) || ' ' || (r->>'n') || ' generique(s)' || E'\n';
  END LOOP;

  RAISE EXCEPTION 'BANC C1 -- transaction annulee, aucun residu %', rap;
END $$;
