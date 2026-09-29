-- ===========================================================================
-- T1 — TERMINAL DE SECTION DU LIEUTENANT : SOCLE SERVEUR
-- 29 septembre 2026
-- ===========================================================================
-- CE LOT NE REECRIT AUCUNE ECONOMIE. Les valeurs de jeu sont reprises telles
-- quelles des fonctions existantes, et le banc le prouve :
--   repos : caserne -> 12 PA, sous tente +10, terrain +8, 1 fois par jour ;
--   ration : +1 PA, 2 fois par jour au maximum, seulement sous 12 PA ;
--   tente : 13 personnes, PJ compris ;
--   combat : arme_de_poing = 8 en feu, mitraillette = 15 en feu, corps a corps 0.
--
-- QUATRE CHOSES CHANGENT, ET SEULEMENT ELLES :
--   1. UNE PORTE DE LECTURE POUR LE TERMINAL. Aujourd'hui l'ecran lit le blob
--      complet des compagnies par REST, ce que la policy ouvre a TOUT joueur du
--      pays. Le terminal passe par militaire_terminal_section(), qui ne rend que
--      la section dont l'appelant est le Lieutenant. La policy n'est pas fermee
--      dans ce lot -- d'autres ecrans en dependent encore (rapporte).
--   2. LES QUANTITES DANS LES TRANSFERTS. Le rail socle deplacait une LIGNE
--      entiere. On deplace desormais N unites d'une meme SIGNATURE. Ce n'est pas
--      un troisieme inventaire : c'est pnj_possessions, avec la meme forme.
--   3. L'ARME DEVIENT DERIVEE DE CE QUE LE SOLDAT PORTE. Plus de categorie
--      abstraite a attribuer a cote de l'objet.
--   4. LA RATION DU LIEUTENANT N'EST PLUS PRELEVEE POUR UN PNJ. Un soldat sans
--      ration mange sans bonus, et ne fait plus echouer l'ordre collectif.
--
-- CE QUI N'EST PAS TOUCHE : la solde, le moteur de bataille (hors la correction
-- du §3 ci-dessous, qui lui est indispensable), les ecrans militaires existants,
-- militaire_reposer_section et militaire_ordre_collectif (conserves intacts pour
-- leurs appelants actuels), l'armurerie, la mutinerie, le camion.

-- ---------------------------------------------------------------------------
-- 1. IDEMPOTENCE — UN REGISTRE, COMME LES AUTRES CHANTIERS
-- ---------------------------------------------------------------------------
-- Meme forme que apports_matieres (C6) et productions_references : la cle est
-- fabriquee par le client A L'OUVERTURE du geste, et rejouer la meme cle rend le
-- meme resultat sans seconde ecriture. C'est ce qui rend un double clic et une
-- reprise reseau inoffensifs.
create table if not exists public.militaire_terminal_requetes (
  requete   text primary key,
  acteur    text not null,
  action    text not null,
  resultat  jsonb not null,
  cree_le   timestamptz not null default now()
);
alter table public.militaire_terminal_requetes enable row level security;
-- Aucune policy : ce registre n'est lu et ecrit que par les RPC, qui sont
-- SECURITY DEFINER et appartiennent au proprietaire de la table.
revoke all on table public.militaire_terminal_requetes from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. LA SECTION DE L'APPELANT — RESOLUE PAR LE SERVEUR, JAMAIS ANNONCEE
-- ---------------------------------------------------------------------------
-- militaire_section_de_moi exige que le client dise QUELLE section il pretend
-- commander. C'est suffisant pour garder (elle verifie ensuite lieutenantNom),
-- mais cela oblige le navigateur a connaitre compagnieId/sectionId, donc a lire
-- le blob. Ici le serveur trouve lui-meme la section de l'appelant : le terminal
-- n'a plus besoin de lire quoi que ce soit avant de demander.
create or replace function public.militaire_ma_section(
  OUT o_moi text, OUT o_compagnie text, OUT o_section text,
  OUT o_data jsonb, OUT o_raison text)
returns record
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
BEGIN
  o_moi := public.mon_personnage();
  IF o_moi IS NULL THEN o_raison := 'acteur_non_authentifie'; RETURN; END IF;

  SELECT c.id, s->>'id', c.data
    INTO o_compagnie, o_section, o_data
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s
   WHERE s->>'lieutenantNom' = o_moi
     AND c.data->>'pays' = (SELECT country FROM public.personnages_donnees WHERE name = o_moi)
   LIMIT 1;

  IF o_compagnie IS NULL THEN o_raison := 'pas_lieutenant_de_section'; RETURN; END IF;
  o_raison := NULL;
END; $fn$;

comment on function public.militaire_ma_section() is
  'Section dont l''appelant est le Lieutenant structurel, resolue par le SERVEUR a partir de mon_personnage() : le client n''annonce aucun identifiant et n''a donc pas besoin de lire le blob des compagnies. Rend pas_lieutenant_de_section a tout autre joueur, y compris Capitaine, Commandant et Ministre de la Defense.';

revoke all on function public.militaire_ma_section() from public, anon, authenticated;
grant execute on function public.militaire_ma_section() to service_role;

-- ---------------------------------------------------------------------------
-- 3. L'ARME EST DESORMAIS CELLE QUE LE SOLDAT PORTE
-- ---------------------------------------------------------------------------
-- LA REGLE DU PJ, APPLIQUEE AU PNJ. militaire_bataille_combattants resolvait
-- deja l'arme d'un JOUEUR depuis son inventaire : jointure de
-- coalesce(produitMilitaire, name) sur militaire_armes_bonus, meilleur bonus,
-- le tir primant le corps a corps. On applique exactement cette regle au PNJ.
--
-- LES VALEURS NE BOUGENT PAS : 'arme_de_poing' et 'mitraillette' SONT deja des
-- cles de militaire_armes_bonus (8 et 15 en feu). Un soldat qui porte le pistolet
-- reglementaire garde donc 8, et celui qui porte la mitraillette garde 15.
-- 'corps_a_corps' n'est pas dans la table : la fonction de bonus rend 0, ce qui
-- est le comportement actuel du combat a mains nues. Rien a arbitrer.
create or replace function public.militaire_arme_operationnelle(p_pnj_id text)
returns text
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT coalesce(
    -- Le tir d'abord, comme pour un PJ (coalesce(af.cle, ac.cle)).
    (SELECT b.cle FROM public.pnj_possessions p
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(p.objet->>'produitMilitaire', p.objet->>'name')
       WHERE p.pnj_id = p_pnj_id AND p.objet->>'type' = 'arme' AND b.mode = 'feu'
       ORDER BY b.bonus DESC, b.cle LIMIT 1),
    (SELECT b.cle FROM public.pnj_possessions p
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(p.objet->>'produitMilitaire', p.objet->>'name')
       WHERE p.pnj_id = p_pnj_id AND p.objet->>'type' = 'arme' AND b.mode = 'cac'
       ORDER BY b.bonus DESC, b.cle LIMIT 1),
    'corps_a_corps');
$fn$;

comment on function public.militaire_arme_operationnelle(text) is
  'Arme operationnelle d''un PNJ soldat, DEDUITE de ce qu''il porte reellement dans pnj_possessions. Meme regle que pour un joueur dans militaire_bataille_combattants : meilleur bonus, le tir primant le corps a corps, repli sur corps_a_corps. Rend une cle de militaire_armes_bonus, jamais un libelle invente.';

-- Ecriture de l'arme deduite. Appelee apres CHAQUE mouvement de possession : c'est
-- ce qui supprime le divorce entre « posseder un pistolet » et « combattre a mains
-- nues ». La projection du blob suit, pour que les ecrans existants restent justes.
-- L'ARME EST UN AXE METIER, ET SON MAGASIN EST LE BLOB.
-- Constat du banc : militaire_blob_projeter reecrit leaderCourant, ville,
-- buildingId, roomId et pa depuis le socle -- mais PAS l'arme, parce que l'arme
-- n'est pas un axe du socle. C'est pnj_miroir_compagnie qui l'IMPORTE du blob.
-- Ecrire seulement pnj_soldats_metier.arme etait donc un piege a retardement :
-- la valeur deduite aurait tenu jusqu'a la prochaine ecriture du blob, puis le
-- miroir aurait reimporte l'ancienne categorie et desarme le soldat en silence.
-- On ecrit donc LES DEUX, dans la meme transaction.
create or replace function public.militaire_arme_recalculer(p_pnj_id text)
returns text
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_arme text; v_compagnie text; v_mat text; v_data jsonb;
BEGIN
  SELECT sm.compagnie_id, sm.matricule INTO v_compagnie, v_mat
    FROM public.pnj_soldats_metier sm WHERE sm.pnj_id = p_pnj_id;
  IF v_compagnie IS NULL THEN RETURN NULL; END IF;

  v_arme := public.militaire_arme_operationnelle(p_pnj_id);
  UPDATE public.pnj_soldats_metier SET arme = v_arme WHERE pnj_id = p_pnj_id;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_compagnie FOR UPDATE;
  IF v_data IS NOT NULL THEN
    UPDATE public.compagnies_militaires
       SET data = jsonb_set(v_data, '{sections}', (
             SELECT coalesce(jsonb_agg(
               CASE WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) so
                                  WHERE so->>'matricule' = v_mat)
                    THEN jsonb_set(s, '{soldats}', (
                           SELECT coalesce(jsonb_agg(
                             CASE WHEN so->>'matricule' = v_mat
                                  THEN so || jsonb_build_object('arme', v_arme)
                                  ELSE so END ORDER BY o2), '[]'::jsonb)
                             FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb))
                                  WITH ORDINALITY AS t2(so, o2)))
                    ELSE s END ORDER BY o1), '[]'::jsonb)
               FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb))
                    WITH ORDINALITY AS t1(s, o1))),
           updated_at = now()
     WHERE id = v_compagnie;
  END IF;

  PERFORM public.militaire_blob_projeter(v_compagnie);
  RETURN v_arme;
END; $fn$;

comment on function public.militaire_arme_recalculer(text) is
  'Recalcule l''arme operationnelle d''un PNJ soldat depuis ses possessions et l''ecrit AUX DEUX ENDROITS : le blob de compagnie, magasin de cet axe metier, et pnj_soldats_metier.arme, que le moteur de combat lit. Ecrire seulement la seconde laisserait pnj_miroir_compagnie reimporter l''ancienne categorie a la prochaine ecriture du blob, et desarmer le soldat en silence.';


-- LE MOTEUR DE COMBAT : UNE SEULE LIGNE CHANGE POUR LE PNJ.
-- Le test « est-ce une arme a feu » etait code en dur sur deux valeurs
-- ('arme_de_poing','mitraillette'). Des que l'arme peut etre n'importe quelle cle
-- de militaire_armes_bonus -- un AK-47 ramasse, une machette -- ce test devient
-- faux : il aurait classe l'AK-47 en corps a corps, ou cherche son bonus dans le
-- mauvais mode, et rendu 0. On demande donc a la TABLE, comme le fait deja la
-- branche PJ. Pour les deux categories historiques le resultat est identique.
create or replace function public.militaire_bataille_combattants(p_bataille_id bigint, p_camp text)
-- SIGNATURE DE RETOUR REPRISE AU CARACTERE PRES. Changer un seul nom de colonne
-- de sortie fait echouer CREATE OR REPLACE (42P13) et obligerait a DROP la
-- fonction -- donc a casser militaire_bataille_actions et _appliquer qui la
-- lisent. Les noms ci-dessous sont ceux de la version en production.
returns table(eng_id bigint, est_pj boolean, nom text, compagnie_id text,
              section_id text, matricule text, pa integer, comp_tir numeric,
              comp_cac numeric, arme_feu boolean, arme_cle text, bonus_arme integer,
              def_per numeric, def_dup numeric, saute_round integer, groupe_id text)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT e.id, true, e.personnage, e.compagnie_id, e.section_id, NULL::text,
         greatest(0, coalesce(pd.pa, 0)),
         coalesce((pd.competences_militaires->>'tir')::numeric, 0),
         coalesce((pd.competences_militaires->>'combat_rapproche')::numeric, 0),
         (af.cle IS NOT NULL),
         coalesce(af.cle, ac.cle),
         coalesce(af.bonus, ac.bonus, 0),
         public.assemblee_stat_base(pd.stats, 'PER'),
         public.assemblee_stat_base(pd.stats, 'DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.personnages_donnees pd ON pd.name = e.personnage
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'feu'
       ORDER BY b.bonus DESC LIMIT 1) af ON true
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'cac'
       ORDER BY b.bonus DESC LIMIT 1) ac ON true
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.personnage IS NOT NULL AND e.sorti_round IS NULL

  UNION ALL

  SELECT e.id, false,
         NULL::text,
         e.compagnie_id, e.section_id, e.matricule,
         greatest(0, coalesce(m.pa, 0)),
         coalesce((sm.formation->>'tir')::numeric, 0),
         coalesce((sm.formation->>'combat_rapproche')::numeric, 0),
         -- LA TABLE DECIDE, plus une paire ecrite en dur.
         EXISTS (SELECT 1 FROM public.militaire_armes_bonus b
                  WHERE b.cle = coalesce(sm.arme,'corps_a_corps') AND b.mode = 'feu'),
         coalesce(sm.arme,'corps_a_corps'),
         public.militaire_bonus_arme(coalesce(sm.arme,'corps_a_corps'),
           CASE WHEN EXISTS (SELECT 1 FROM public.militaire_armes_bonus b
                              WHERE b.cle = coalesce(sm.arme,'corps_a_corps') AND b.mode = 'feu')
                THEN 'feu' ELSE 'cac' END),
         public.militaire_defense_pnj('PER'),
         public.militaire_defense_pnj('DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.pnj_soldats_metier sm ON sm.matricule = e.matricule
    JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.matricule IS NOT NULL AND e.sorti_round IS NULL
     AND m.id LIKE e.compagnie_id || '-%'
     AND sm.section_id = e.section_id;
$fn$;

comment on function public.militaire_bataille_combattants(bigint,text) is
  'Combattants d''un camp. L''arme d''un PJ est deduite de son inventaire, celle d''un PNJ de sa colonne arme -- desormais elle-meme deduite de ses possessions. Le mode (feu ou corps a corps) est determine par militaire_armes_bonus et non plus par une paire de categories ecrite en dur : arme_de_poing et mitraillette conservent exactement 8 et 15 en feu.';

revoke all on function public.militaire_bataille_combattants(bigint,text) from public, anon, authenticated;
grant execute on function public.militaire_bataille_combattants(bigint,text) to service_role;

-- ---------------------------------------------------------------------------
-- 4. REPRISE DE L'ETAT — NE DESARMER PERSONNE
-- ---------------------------------------------------------------------------
-- Rendre l'arme derivee SANS reprendre l'existant desarmerait instantanement
-- toute troupe equipee : les soldats portent aujourd'hui une CATEGORIE issue du
-- compteur section.stockArmes, sans aucun objet correspondant. On materialise
-- donc l'objet manquant, avec la forme EXACTE que militaire_retrait produit
-- (meme name, type, sousType, icon, imageUrl, produitMilitaire) : apres reprise,
-- l'arme deduite est identique a l'arme portee, et le combat ne bouge pas d'un
-- point.
--
-- Le compteur stockArmes n'est PAS recredite : l'unite etait deja sortie du stock
-- quand elle a ete attribuee. On ne cree pas d'arme, on nomme celle qui etait la.
insert into public.pnj_possessions (pnj_id, objet, origine)
select sm.pnj_id,
       jsonb_build_object(
         'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
         'type', 'arme', 'sousType', 'militaire',
         'origineMilitaire', true, 'lot', 'reprise-t1',
         'produitMilitaire', sm.arme,
         'name', CASE sm.arme WHEN 'arme_de_poing' THEN 'Pistolet militaire'
                              WHEN 'mitraillette'  THEN 'Mitraillette' END,
         'icon', 'ti-crosshair', 'legal', true,
         'imageUrl', CASE sm.arme
           WHEN 'arme_de_poing' THEN 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png'
           WHEN 'mitraillette'  THEN 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png' END,
         'desc', 'Arme reglementaire de l''armee. Materialisee le 29 septembre 2026 '
              || 'lors du passage a l''armement deduit des possessions (lot T1).'),
       'socle'
  from public.pnj_soldats_metier sm
  join public.pnj_membres m on m.id = sm.pnj_id
 where m.statut = 'actif'
   and sm.arme in ('arme_de_poing', 'mitraillette')
   and not exists (
     select 1 from public.pnj_possessions p
      where p.pnj_id = sm.pnj_id and p.objet->>'type' = 'arme'
        and coalesce(p.objet->>'produitMilitaire', p.objet->>'name') = sm.arme);

-- Puis on aligne la colonne sur ce qui est desormais porte. Idempotent : relancer
-- recalcule la meme valeur.
update public.pnj_soldats_metier sm
   set arme = public.militaire_arme_operationnelle(sm.pnj_id)
  from public.pnj_membres m
 where m.id = sm.pnj_id and m.statut = 'actif'
   and sm.arme is distinct from public.militaire_arme_operationnelle(sm.pnj_id);

-- ---------------------------------------------------------------------------
-- 5. EQUIPER DEPUIS LE STOCK DE SECTION — DESORMAIS UN VRAI OBJET
-- ---------------------------------------------------------------------------
-- L'ecran historique « Gerer l'equipement de ma section » reste en place et
-- continue de puiser dans section.stockArmes : l'economie de l'armurerie n'est
-- pas touchee. Ce qui change, c'est qu'il POSE MAINTENANT UN OBJET sur le soldat
-- au lieu d'ecrire une categorie abstraite. Sans cela, les deux chemins se
-- contrediraient : le stock ecrirait une categorie que le premier transfert
-- d'objet effacerait aussitot.
create or replace function public.militaire_equiper_soldat(
  p_compagnie_id text, p_section_id text, p_matricule text, p_categorie text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  g record; v_sec jsonb; v_stock jsonb; v_sol jsonb; v_anc text; v_dispo int;
  v_pnj text; v_arme text; v_rendu text;
BEGIN
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  IF p_categorie NOT IN ('corps_a_corps','arme_de_poing','mitraillette') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_invalide');
  END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = p_section_id;
  v_stock := CASE WHEN jsonb_typeof(v_sec->'stockArmes') = 'object' THEN v_sec->'stockArmes'
                  ELSE jsonb_build_object('arme_de_poing',0,'mitraillette',0) END;
  SELECT s INTO v_sol FROM jsonb_array_elements(COALESCE(v_sec->'soldats','[]'::jsonb)) s
   WHERE s->>'matricule' = p_matricule LIMIT 1;
  IF v_sol IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable'); END IF;

  SELECT sm.pnj_id INTO v_pnj
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND sm.matricule = p_matricule AND m.statut = 'actif';
  IF v_pnj IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable'); END IF;

  -- L'ancienne arme est celle REELLEMENT portee, plus celle annoncee par le blob.
  v_anc := public.militaire_arme_operationnelle(v_pnj);
  IF v_anc = p_categorie THEN RETURN jsonb_build_object('ok', true, 'rejeu', true, 'arme', v_anc); END IF;

  IF p_categorie <> 'corps_a_corps' THEN
    v_dispo := GREATEST(0, COALESCE((v_stock->>p_categorie)::int, 0));
    IF v_dispo <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_section_insuffisant', 'categorie', p_categorie);
    END IF;
    v_stock := v_stock || jsonb_build_object(p_categorie, v_dispo - 1);
  END IF;

  -- On rend au stock l'arme reglementaire qu'il portait, s'il en portait une, et
  -- on retire l'objet correspondant : une seule arme a la fois, comme avant.
  IF v_anc IN ('arme_de_poing','mitraillette') THEN
    v_stock := v_stock || jsonb_build_object(v_anc,
                 GREATEST(0, COALESCE((v_stock->>v_anc)::int, 0)) + 1);
    DELETE FROM public.pnj_possessions
     WHERE id = (SELECT p.id FROM public.pnj_possessions p
                  WHERE p.pnj_id = v_pnj AND p.objet->>'type' = 'arme'
                    AND coalesce(p.objet->>'produitMilitaire', p.objet->>'name') = v_anc
                  ORDER BY p.id LIMIT 1);
  END IF;

  IF p_categorie <> 'corps_a_corps' THEN
    INSERT INTO public.pnj_possessions (pnj_id, objet, origine)
    VALUES (v_pnj, jsonb_build_object(
      'id', 'mil-' || replace(gen_random_uuid()::text, '-', ''),
      'type', 'arme', 'sousType', 'militaire', 'origineMilitaire', true,
      'lot', 'stock-section', 'produitMilitaire', p_categorie,
      'name', CASE p_categorie WHEN 'arme_de_poing' THEN 'Pistolet militaire'
                               ELSE 'Mitraillette' END,
      'icon', 'ti-crosshair', 'legal', true,
      'imageUrl', CASE p_categorie
        WHEN 'arme_de_poing' THEN 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png'
        ELSE 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png' END,
      'desc', 'Arme reglementaire, remise depuis le stock de la section.'), 'socle');
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('stockArmes', v_stock))
   WHERE id = p_compagnie_id;
  v_rendu := public.militaire_arme_recalculer(v_pnj);

  RETURN jsonb_build_object('ok', true, 'matricule', p_matricule, 'arme', v_rendu,
                            'ancienne', v_anc, 'stock', v_stock);
END; $fn$;

comment on function public.militaire_equiper_soldat(text,text,text,text) is
  'Equipe un PNJ soldat depuis le stock d''armes de sa section. Depuis le lot T1 elle POSE UN VRAI OBJET dans pnj_possessions au lieu d''ecrire une categorie abstraite, et rend au stock l''arme precedemment portee. L''arme operationnelle est ensuite recalculee depuis les possessions : les deux chemins -- stock de section et transfert d''objet -- ne peuvent plus se contredire.';

revoke all on function public.militaire_equiper_soldat(text,text,text,text) from public, anon, authenticated;
grant execute on function public.militaire_equiper_soldat(text,text,text,text) to authenticated, service_role;
