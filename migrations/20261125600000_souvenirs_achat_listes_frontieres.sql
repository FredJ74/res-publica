-- Mission du soir du 25/11/2026 (Claude), bloc 3 — APPLIQUÉE en production le 25/11/2026 en fin de soirée (feu vert de Fred, contrôlée en lecture). Après 20261125300000 (armoire à souvenirs, appliquée le 25/11).
-- Décisions de Fred (25/11/2026 au soir, docs/mission-soir-20261125.md, points 3.1 à 3.3) :
-- 3.1 Chaque souvenir des listes devient un objet du jeu, acheté SUR PLACE auprès d'un PNJ existant, dans un lieu de sa ville
--     cohérent avec l'objet (l'image du lieu montre un comptoir ou un étal). Le jeu n'indique JAMAIS où le trouver : la table des
--     lieux (souvenirs_objets) n'est lisible par aucun joueur ; souvenirs_ici() ne rend que ce qui se vend dans la pièce où l'on
--     se trouve. Un souvenir est un objet ordinaire : il se donne, se vend et s'échange librement. Les cartes postales des listes
--     sont les cartes postales existantes (carte_modele = leur modèle) ; le guide des baies sauvages de Krasnov est l'objet existant
--     (cle_objet = guide_baies_krasnov), toujours vendu au musée de Krasnov.
--     souvenir_acheter(p_requete, p_cle) : idempotent, présence exacte dans la pièce du PNJ, paiement en liquide (comme les
--     boutiques des PNJ), prix réglable par le MJ (souvenirs_objets.prix).
--     Durcissement : un emplacement se remplit par la clé de l'objet (type ou stackKey, que ni le don ni la vente ne laissent
--     réécrire) ; le nom seul, réécrivable par une « mutation » du don, ne suffit plus. Les douze souvenirs de la liste 1 reçoivent
--     donc leur clé.
-- 3.2 Listes 2, 3 et 4 mot pour mot (provisoires : Fred les relit le 12/12). Les armoires fabriquées (achat à la Scierie,
--     acheter_produit_manufacture) reçoivent une des listes AU HASARD (listeId sur l'objet ; raccord armoire_liste_hasard_v1).
--     Les souvenirs des six villes des empires fermés existent (souvenirs_objets, achetable = false) : achetables nulle part.
-- 3.3 Frontières des empires fermés (El Estado, Al-Khalija) : tout voyage vers Ciudad Roja, Puerto Negro, Villa Sangre, Al Madina,
--     Oasis City ou Al-Petrol est refusé par le serveur : « Frontière fermée, ouverture au premier trimestre 2027 ».
--     transport_effectuer refuse avec raison frontiere_fermee (raccord frontieres_fermees_v1) ; un déclencheur refuse en dernier
--     recours toute écriture d'une position dans une ville fermée (zz_frontiere_fermee_garder). Table frontieres_fermees :
--     supprimer une ligne ouvre la ville. La fenêtre de l'armoire reçoit ville_fermee par emplacement (frontieres_armoire_v1).
-- Sans cette migration : aucun ordre « Acheter un souvenir » (souvenirs_ici échoue, rien ne s'affiche), armoires en liste 1,
-- voyages vers les empires fermés déjà impossibles côté écran (« Bientôt disponible »).
--
-- Contrôles en lecture après application :
--   SELECT liste_id, count(*) FROM public.souvenirs_emplacements GROUP BY 1 ORDER BY 1;                       -- 1|12, 2|12, 3|12, 4|12
--   SELECT count(*) FILTER (WHERE achetable), count(*) FILTER (WHERE NOT achetable) FROM public.souvenirs_objets;  -- 18 | 24
--   SELECT count(*) FROM public.souvenirs_emplacements WHERE cle_objet IS NULL AND carte_modele IS NULL;        -- 0
--   SELECT count(*) FROM public.frontieres_fermees;                                                            -- 6
--   SELECT position('frontieres_fermees_v1' in pg_get_functiondef('public.transport_effectuer(text,text,text,uuid)'::regprocedure)) > 0;    -- vrai
--   SELECT position('armoire_liste_hasard_v1' in pg_get_functiondef('public.acheter_produit_manufacture(text,text,text)'::regprocedure)) > 0;  -- vrai
--   SELECT position('frontieres_armoire_v1' in pg_get_functiondef('public.armoire_etat_interne(text,public.equipements_installes)'::regprocedure)) > 0;  -- vrai
--   SELECT has_function_privilege('authenticated', 'public.souvenir_acheter(uuid,text)', 'EXECUTE');            -- vrai
--   SELECT has_function_privilege('anon', 'public.souvenirs_ici()', 'EXECUTE');                                  -- faux
--   SELECT has_table_privilege('authenticated', 'public.souvenirs_objets', 'SELECT');                            -- faux
BEGIN;

-- 1. Les souvenirs, objets du jeu, et leur lieu de vente (secret : aucune lecture par les joueurs).
CREATE TABLE IF NOT EXISTS public.souvenirs_objets (
  cle text PRIMARY KEY,
  nom text NOT NULL,
  ville_nom text NOT NULL,
  pays text, ville text, batiment text, piece text,   -- lieu de vente (NULL : achetable nulle part)
  pnj text,                                           -- PNJ existant qui le vend, visible sur l'image du lieu
  prix numeric CHECK (prix IS NULL OR prix > 0),      -- réglage MJ, devise du pays du lieu
  achetable boolean NOT NULL DEFAULT false,
  CHECK (NOT achetable OR (pays IS NOT NULL AND ville IS NOT NULL AND batiment IS NOT NULL AND piece IS NOT NULL AND prix IS NOT NULL))
);
ALTER TABLE public.souvenirs_objets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.souvenirs_objets FROM PUBLIC, anon, authenticated;

INSERT INTO public.souvenirs_objets (cle, nom, ville_nom, pays, ville, batiment, piece, pnj, prix, achetable) VALUES
  -- Liste 1 (villes ouvertes)
  ('souv_luthecia_palais', 'Reproduction miniature du Palais présidentiel', 'Luthécia', 'republic', 'capitale', 'musee-ville-luthecia', 'hall', 'Valérie Loisillon', 45, true),
  ('souv_montrouge_ticket_cinema', 'Ticket du cinéma de Montrouge', 'Montrouge', 'republic', 'ville_b', 'marche', 'marche_ext', 'Josette Betterave', 10, true),
  ('souv_psm_mug', 'Mug « Port Sainte-Marie »', 'Port-Sainte-Marie', 'republic', 'ville_a', 'marche-psm', 'etals', 'Bastien Leroux', 20, true),
  ('souv_novomirsk_poupee', 'Poupée traditionnelle de Novomirsk', 'Novomirsk', 'soviet', 'capitale', 'musee-novomirsk', 'hall', 'Irina Filippova', 15, true),
  ('souv_starovka_flasque', 'Flasque métallique gravée « Starovka »', 'Starovka', 'soviet', 'ville_a', 'armurerie', 'magasin', 'Bato Tsyrenov', 14, true),
  ('souv_krasnov_insigne', 'Insigne émaillé des hauts-fourneaux de Krasnov', 'Krasnov', 'soviet', 'ville_b', 'musee-novomirsk', 'hall', 'Zoïa Biletova', 10, true),
  -- Liste 2
  ('souv_luthecia_tampon', 'Tampon encreur officiel « Approuvé — en trois exemplaires »', 'Luthécia', 'republic', 'capitale', 'la-tribune', 'accueil_tribune', 'Rosalie Caractère', 25, true),
  ('souv_psm_sel', 'Bocal de sel des marais', 'Port-Sainte-Marie', 'republic', 'ville_a', 'marche-psm', 'etals', 'Mireille Legall', 15, true),
  ('souv_novomirsk_ticket_file', 'Ticket n° 1 de la file d''attente de la Distribution Collective, encadré', 'Novomirsk', 'soviet', 'capitale', 'marche', 'marche_ext', 'Distributeur Équitable', 8, true),
  ('souv_starovka_bonnet', 'Bonnet en laine de renne de la ferme', 'Starovka', 'soviet', 'ville_a', 'magasin-kolkhoze-starovka', 'magasin', 'Tuyana Sambueva', 18, true),
  -- Liste 3
  ('souv_montrouge_sifflet', 'Sifflet de chef de gare du musée du Rail', 'Montrouge', 'republic', 'ville_b', 'musee-histoire-montrouge', 'accueil', 'Elsa Montbaron', 30, true),
  ('souv_novomirsk_medaille', 'Médaille commémorative du Tractorisme', 'Novomirsk', 'soviet', 'capitale', 'musee-novomirsk', 'hall', 'Irina Filippova', 12, true),
  ('souv_krasnov_casque', 'Casque miniature de fondeur des hauts-fourneaux', 'Krasnov', 'soviet', 'ville_b', 'station-service-krasnov', 'boutique_station', 'Leonid Zapravkine', 12, true),
  -- Liste 4
  ('souv_luthecia_formulaire', 'Formulaire vierge de la Liberté, encadré', 'Luthécia', 'republic', 'capitale', 'musee-ville-luthecia', 'hall', 'Valérie Loisillon', 35, true),
  ('souv_psm_bouee', 'Bouée miniature « Port-Sainte-Marie »', 'Port-Sainte-Marie', 'republic', 'ville_a', 'musee-port-sainte-marie', 'hall', 'Soizic Le Gall', 25, true),
  ('souv_novomirsk_voix', 'Exemplaire relié de La Voix de Sovarka', 'Novomirsk', 'soviet', 'capitale', 'imprimerie-librairie', 'accueil_imprimerie', 'Ludmila Pamphletova', 10, true),
  ('souv_starovka_bois', 'Bois de renne sculpté', 'Starovka', 'soviet', 'ville_a', 'marche', 'marche_ext', 'Tsypilma Dashieva', 16, true),
  ('souv_krasnov_pendentif', 'Pendentif « L''ours ne se chasse pas » (fausse griffe d''ours)', 'Krasnov', 'soviet', 'ville_b', 'marche', 'marche_ext', 'Nina Gorbounova', 9, true)
ON CONFLICT (cle) DO NOTHING;

-- Souvenirs des empires fermés : définis, achetables nulle part avant l'ouverture.
INSERT INTO public.souvenirs_objets (cle, nom, ville_nom) VALUES
  ('souv_ciudad_masque', 'Petit masque rouge du carnaval de Ciudad Roja', 'Ciudad Roja'),
  ('souv_puerto_jeton', 'Jeton du casino de Puerto Negro', 'Puerto Negro'),
  ('souv_villa_crane', 'Crâne décoratif peint de Villa Sangre', 'Villa Sangre'),
  ('souv_madina_lampe', 'Petite lampe ouvragée d''Al Madina', 'Al Madina'),
  ('souv_oasis_boule_neige', 'Boule à neige « Oasis City »', 'Oasis City'),
  ('souv_petrol_baril', 'Miniature de baril de pétrole doré', 'Al-Petrol'),
  ('souv_ciudad_maracas', 'Maracas rouges du carnaval', 'Ciudad Roja'),
  ('souv_puerto_rhum', 'Mignonnette de rhum « Puerto Negro »', 'Puerto Negro'),
  ('souv_villa_bougie', 'Bougie votive peinte', 'Villa Sangre'),
  ('souv_madina_epices', 'Sachet d''épices du souk', 'Al Madina'),
  ('souv_oasis_sable', 'Flacon de sable de l''oasis', 'Oasis City'),
  ('souv_petrol_porte_cles', 'Porte-clés en forme de derrick doré', 'Al-Petrol'),
  ('souv_ciudad_foulard', 'Foulard rouge brodé', 'Ciudad Roja'),
  ('souv_puerto_de', 'Dé en os des tripots du port', 'Puerto Negro'),
  ('souv_villa_statuette', 'Statuette du saint protecteur de la ville', 'Villa Sangre'),
  ('souv_madina_theiere', 'Théière miniature ciselée', 'Al Madina'),
  ('souv_oasis_datte', 'Datte en sucre dans sa boîte dorée', 'Oasis City'),
  ('souv_petrol_fiole', 'Fiole décorative scellée « pétrole brut »', 'Al-Petrol'),
  ('souv_ciudad_affiche', 'Affiche du carnaval', 'Ciudad Roja'),
  ('souv_puerto_boussole', 'Boussole de contrebandier', 'Puerto Negro'),
  ('souv_villa_chapelet', 'Chapelet de perles noires', 'Villa Sangre'),
  ('souv_madina_babouches', 'Babouches brodées miniatures', 'Al Madina'),
  ('souv_oasis_chameau', 'Chameau en peluche « Oasis City »', 'Oasis City'),
  ('souv_petrol_casque', 'Casque de chantier pétrolier dédicacé', 'Al-Petrol')
ON CONFLICT (cle) DO NOTHING;

-- 2. Listes 2, 3 et 4 (mot pour mot, provisoires) ; liste 1 : clé de chaque souvenir.
INSERT INTO public.souvenirs_listes (id, nom) VALUES (2, 'Collection n°2'), (3, 'Collection n°3'), (4, 'Collection n°4') ON CONFLICT (id) DO NOTHING;
UPDATE public.souvenirs_emplacements e SET cle_objet = x.cle
  FROM (VALUES (1, 'souv_luthecia_palais'), (2, 'souv_montrouge_ticket_cinema'), (3, 'souv_psm_mug'), (4, 'souv_novomirsk_poupee'),
               (5, 'souv_starovka_flasque'), (6, 'souv_krasnov_insigne'), (7, 'souv_ciudad_masque'), (8, 'souv_puerto_jeton'),
               (9, 'souv_villa_crane'), (10, 'souv_madina_lampe'), (11, 'souv_oasis_boule_neige'), (12, 'souv_petrol_baril')) x(rang, cle)
 WHERE e.liste_id = 1 AND e.rang = x.rang AND e.cle_objet IS NULL AND e.carte_modele IS NULL;
INSERT INTO public.souvenirs_emplacements (liste_id, rang, ville, nom, cle_objet, carte_modele) VALUES
  (2, 1, 'Luthécia', 'Tampon encreur officiel « Approuvé — en trois exemplaires »', 'souv_luthecia_tampon', NULL),
  (2, 2, 'Montrouge', 'Carte postale « Montrouge, place du Rail — ici, même les statues sont à l''heure »', NULL, 'carte_montrouge_place_rail'),
  (2, 3, 'Port-Sainte-Marie', 'Bocal de sel des marais', 'souv_psm_sel', NULL),
  (2, 4, 'Novomirsk', 'Ticket n° 1 de la file d''attente de la Distribution Collective, encadré', 'souv_novomirsk_ticket_file', NULL),
  (2, 5, 'Starovka', 'Bonnet en laine de renne de la ferme', 'souv_starovka_bonnet', NULL),
  (2, 6, 'Krasnov', 'Guide des baies sauvages', 'guide_baies_krasnov', NULL),
  (2, 7, 'Ciudad Roja', 'Maracas rouges du carnaval', 'souv_ciudad_maracas', NULL),
  (2, 8, 'Puerto Negro', 'Mignonnette de rhum « Puerto Negro »', 'souv_puerto_rhum', NULL),
  (2, 9, 'Villa Sangre', 'Bougie votive peinte', 'souv_villa_bougie', NULL),
  (2, 10, 'Al Madina', 'Sachet d''épices du souk', 'souv_madina_epices', NULL),
  (2, 11, 'Oasis City', 'Flacon de sable de l''oasis', 'souv_oasis_sable', NULL),
  (2, 12, 'Al-Petrol', 'Porte-clés en forme de derrick doré', 'souv_petrol_porte_cles', NULL),
  (3, 1, 'Luthécia', 'Carte postale « Luthécia — la liberté, en trois exemplaires et dûment tamponnée »', NULL, 'carte_luthecia_institutions'),
  (3, 2, 'Montrouge', 'Sifflet de chef de gare du musée du Rail', 'souv_montrouge_sifflet', NULL),
  (3, 3, 'Port-Sainte-Marie', 'Carte postale « Port-Sainte-Marie, sous la protection de Notre-Dame de la Mer »', NULL, 'carte_psm_notre_dame_mer'),
  (3, 4, 'Novomirsk', 'Médaille commémorative du Tractorisme', 'souv_novomirsk_medaille', NULL),
  (3, 5, 'Starovka', 'Carte postale « Starovka — ici, la chaleur est dans les cœurs »', NULL, 'carte_starovka_hiver'),
  (3, 6, 'Krasnov', 'Casque miniature de fondeur des hauts-fourneaux', 'souv_krasnov_casque', NULL),
  (3, 7, 'Ciudad Roja', 'Foulard rouge brodé', 'souv_ciudad_foulard', NULL),
  (3, 8, 'Puerto Negro', 'Dé en os des tripots du port', 'souv_puerto_de', NULL),
  (3, 9, 'Villa Sangre', 'Statuette du saint protecteur de la ville', 'souv_villa_statuette', NULL),
  (3, 10, 'Al Madina', 'Théière miniature ciselée', 'souv_madina_theiere', NULL),
  (3, 11, 'Oasis City', 'Datte en sucre dans sa boîte dorée', 'souv_oasis_datte', NULL),
  (3, 12, 'Al-Petrol', 'Fiole décorative scellée « pétrole brut »', 'souv_petrol_fiole', NULL),
  (4, 1, 'Luthécia', 'Formulaire vierge de la Liberté, encadré', 'souv_luthecia_formulaire', NULL),
  (4, 2, 'Montrouge', 'Carte postale « Bons baisers de Montrouge, la ville qui ne déraille jamais »', NULL, 'carte_montrouge_touristique'),
  (4, 3, 'Port-Sainte-Marie', 'Bouée miniature « Port-Sainte-Marie »', 'souv_psm_bouee', NULL),
  (4, 4, 'Novomirsk', 'Exemplaire relié de La Voix de Sovarka', 'souv_novomirsk_voix', NULL),
  (4, 5, 'Starovka', 'Bois de renne sculpté', 'souv_starovka_bois', NULL),
  (4, 6, 'Krasnov', 'Pendentif « L''ours ne se chasse pas » (fausse griffe d''ours)', 'souv_krasnov_pendentif', NULL),
  (4, 7, 'Ciudad Roja', 'Affiche du carnaval', 'souv_ciudad_affiche', NULL),
  (4, 8, 'Puerto Negro', 'Boussole de contrebandier', 'souv_puerto_boussole', NULL),
  (4, 9, 'Villa Sangre', 'Chapelet de perles noires', 'souv_villa_chapelet', NULL),
  (4, 10, 'Al Madina', 'Babouches brodées miniatures', 'souv_madina_babouches', NULL),
  (4, 11, 'Oasis City', 'Chameau en peluche « Oasis City »', 'souv_oasis_chameau', NULL),
  (4, 12, 'Al-Petrol', 'Casque de chantier pétrolier dédicacé', 'souv_petrol_casque', NULL)
ON CONFLICT (liste_id, rang) DO NOTHING;

-- Un emplacement se remplit par la clé de l'objet (type ou stackKey : ni le don ni la vente ne les réécrivent),
-- ou par le modèle de carte postale ; le nom seul ne vaut que pour un emplacement sans clé (aucun après cette migration).
CREATE OR REPLACE FUNCTION public.armoire_correspond_interne(e public.souvenirs_emplacements, p_item jsonb)
 RETURNS boolean LANGUAGE sql IMMUTABLE AS $function$
  SELECT CASE
    WHEN e.carte_modele IS NOT NULL THEN public.armoire_est_carte_interne(p_item) AND coalesce(p_item ->> 'modele', p_item ->> 'type') = e.carte_modele
    WHEN e.cle_objet IS NOT NULL THEN e.cle_objet IN (p_item ->> 'type', p_item ->> 'stackKey')
    ELSE btrim(coalesce(p_item ->> 'name', '')) = e.nom END /* souvenirs_cle_v1 */
$function$;

-- 3. L'objet souvenir, tel qu'il entre dans l'inventaire.
CREATE OR REPLACE FUNCTION public.souvenir_objet_interne(s public.souvenirs_objets)
 RETURNS jsonb LANGUAGE sql IMMUTABLE AS $function$
  SELECT jsonb_build_object('type', s.cle, 'name', s.nom, 'souvenir', true, 'villeOrigine', s.ville_nom,
    'icon', 'ti-gift', 'encombrement', 1, 'legal', true, 'desc', 'Souvenir de ' || s.ville_nom || '.') /* souvenirs_achat_v1 */
$function$;

-- Ce qui se vend dans la pièce où l'on se trouve (et rien d'autre : le jeu ne dit jamais où trouver un souvenir).
CREATE OR REPLACE FUNCTION public.souvenirs_ici()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); d record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'souvenirs', coalesce((
    SELECT jsonb_agg(jsonb_build_object('cle', s.cle, 'nom', s.nom, 'prix', s.prix, 'pnj', s.pnj,
             'devise', CASE WHEN s.pays = 'soviet' THEN 'PSK' ELSE 'FR' END) ORDER BY s.nom)
      FROM public.souvenirs_objets s
     WHERE s.achetable AND (s.pays, s.ville, s.batiment, s.piece) = (d.country, d.current_city, d.current_building, d.current_room)), '[]'::jsonb)); /* souvenirs_achat_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.souvenir_acheter(p_requete uuid, p_cle text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('cle', p_cle); v jsonb; d record; s public.souvenirs_objets;
        v_debit numeric; v_dep jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR coalesce(p_cle, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'souvenir_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT country, current_city, current_building, current_room, coalesce(liquide, 0) AS liquide, inventory INTO d
    FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  SELECT * INTO s FROM public.souvenirs_objets WHERE cle = p_cle;
  -- Même réponse pour un souvenir inconnu, fermé ou vendu ailleurs : rien n'indique où il se trouve.
  IF s.cle IS NULL OR NOT s.achetable
     OR (s.pays, s.ville, s.batiment, s.piece) IS DISTINCT FROM (d.country, d.current_city, d.current_building, d.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_vendu_ici'); END IF;
  IF d.liquide < s.prix THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', s.prix); END IF;
  IF public.inventaire_place_restante(d.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_debit := public.argent_debiter_interne(a, s.prix, 'liquide');
  IF v_debit IS DISTINCT FROM s.prix THEN RAISE EXCEPTION 'souvenir_acheter : débit incomplet'; END IF;
  v_dep := public.inventaire_deposer_interne(a, public.souvenir_objet_interne(s));
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'souvenir_acheter : dépôt refusé %', v_dep; END IF;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'souvenir_acheter', prm,
    jsonb_build_object('ok', true, 'cle', s.cle, 'nom', s.nom, 'paye', s.prix, 'pnj', s.pnj,
      'devise', CASE WHEN s.pays = 'soviet' THEN 'PSK' ELSE 'FR' END)
    || (SELECT jsonb_build_object('liquide', liquide) FROM public.personnages_donnees WHERE name = a)); /* souvenirs_achat_v1 */
END $function$;

-- 4. Armoire fabriquée : une des listes au hasard (gardée sur l'objet : listeId).
CREATE OR REPLACE FUNCTION public.armoire_fabriquee_interne(p_produit text)
 RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN p_produit = 'armoire_souvenirs' THEN jsonb_build_object('name', 'Armoire à souvenirs',
           'id', 'armoire_souvenirs_' || replace(gen_random_uuid()::text, '-', ''),
           'listeId', (SELECT id FROM public.souvenirs_listes ORDER BY random() LIMIT 1))
         ELSE '{}'::jsonb END /* armoire_liste_hasard_v1 */
$function$;

-- 5. Frontières des empires fermés.
CREATE TABLE IF NOT EXISTS public.frontieres_fermees (
  pays text NOT NULL, ville text NOT NULL, ville_nom text NOT NULL,
  message text NOT NULL DEFAULT 'Frontière fermée, ouverture au premier trimestre 2027',
  PRIMARY KEY (pays, ville)
);
ALTER TABLE public.frontieres_fermees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.frontieres_fermees FROM PUBLIC, anon, authenticated;
INSERT INTO public.frontieres_fermees (pays, ville, ville_nom) VALUES
  ('narco', 'capitale', 'Ciudad Roja'), ('narco', 'ville_a', 'Puerto Negro'), ('narco', 'ville_b', 'Villa Sangre'),
  ('khalija', 'capitale', 'Al Madina'), ('khalija', 'ville_a', 'Oasis City'), ('khalija', 'ville_b', 'Al-Petrol')
ON CONFLICT (pays, ville) DO NOTHING;

CREATE OR REPLACE FUNCTION public.frontiere_fermee_interne(p_pays text, p_ville text)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT message FROM public.frontieres_fermees WHERE pays = p_pays AND ville = p_ville /* frontieres_fermees_v1 */ $function$;

-- Dernier recours : aucune écriture ne place un personnage dans une ville fermée.
CREATE OR REPLACE FUNCTION public.frontiere_fermee_garder()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_msg text;
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.country, NEW.current_city) IS NOT DISTINCT FROM (OLD.country, OLD.current_city) THEN RETURN NEW; END IF;
  v_msg := public.frontiere_fermee_interne(NEW.country, NEW.current_city);
  IF v_msg IS NOT NULL THEN RAISE EXCEPTION 'frontiere_fermee' USING DETAIL = v_msg, HINT = 'frontieres_fermees_v1'; END IF;
  RETURN NEW;
END $function$;
DROP TRIGGER IF EXISTS zz_frontiere_fermee_garder ON public.personnages_donnees;
CREATE TRIGGER zz_frontiere_fermee_garder BEFORE INSERT OR UPDATE OF country, current_city ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.frontiere_fermee_garder();

-- 6. Raccords contrôlés.
CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- Voyage : refus nommé avant toute autre vérification de la destination.
SELECT pg_temp.rp_remplacer('public.transport_effectuer(text,text,text,uuid)'::regprocedure,
  $a$RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;$a$,
  $b$RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
 IF public.frontiere_fermee_interne(p_pays,p_ville) IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','frontiere_fermee','message',public.frontiere_fermee_interne(p_pays,p_ville));END IF; /* frontieres_fermees_v1 */$b$,
  1, 'frontieres_fermees_v1');

-- Armoire achetée à la Scierie : id propre et liste au hasard.
SELECT pg_temp.rp_remplacer('public.acheter_produit_manufacture(text,text,text)'::regprocedure,
  $a$'desc', 'Acheté à l''atelier.'));$a$,
  $b$'desc', 'Acheté à l''atelier.') || public.armoire_fabriquee_interne(p_produit)); /* armoire_liste_hasard_v1 */$b$,
  1, 'armoire_liste_hasard_v1');

-- Fenêtre de l'armoire : emplacement d'une ville fermée signalé.
SELECT pg_temp.rp_remplacer('public.armoire_etat_interne(text,public.equipements_installes)'::regprocedure,
  $a$jsonb_build_object('rang', s.rang, 'ville', s.ville, 'nom', s.nom,$a$,
  $b$jsonb_build_object('rang', s.rang, 'ville', s.ville, 'nom', s.nom, 'ville_fermee', EXISTS (SELECT 1 FROM public.frontieres_fermees ff WHERE ff.ville_nom = s.ville) /* frontieres_armoire_v1 */,$b$,
  1, 'frontieres_armoire_v1');

REVOKE ALL ON FUNCTION public.souvenir_objet_interne(public.souvenirs_objets), public.armoire_fabriquee_interne(text),
  public.frontiere_fermee_interne(text, text), public.frontiere_fermee_garder() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.souvenirs_ici(), public.souvenir_acheter(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.souvenirs_ici(), public.souvenir_acheter(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
