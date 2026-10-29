-- =====================================================================================
-- PLACEMENTS BANCAIRES — défaut reproduit le 29/10/2026 (Claude), suite de 20261029094119.
--
-- 3. RENDEMENT DES PLACEMENTS DICTÉ PAR LE NAVIGATEUR. `creer_placement_national_securise`
--    enregistrait l'intelligence ET la ville envoyées par l'écran ; la passe de minuit en
--    tire le rendement (borné à 12 %). Une intelligence forgée donnait +12 % garantis à
--    chaque échéance, sur jusqu'à 100 000 000 FR.
--    -> l'intelligence est lue sur la fiche (stats.INT), la ville est celle où se trouve le
--       personnage ; les paramètres envoyés restent acceptés (même signature, écran inchangé)
--       mais ne décident plus rien. L'ancienne `creer_placement_national`, que plus aucun
--       écran n'appelle, est fermée aux joueurs.
--
-- =====================================================================================

-- 3a. Le placement ne croit plus l'écran : intelligence et ville lues côté serveur.
CREATE OR REPLACE FUNCTION public.creer_placement_national_securise(p_personnage text, p_montant numeric, p_int_snapshot integer, p_ville text, p_source text, p_intention uuid)
 RETURNS placements_bancaires
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_id text;
  v_exist public.placements_bancaires%rowtype;
  v_compte public.comptes_bancaires%rowtype;
  v_liquide numeric;
  v_pays text;
  v_ville text;
  v_int integer;
  v_placement public.placements_bancaires%rowtype;
begin
  perform public.exiger_acteur(p_personnage);
  -- p_int_snapshot et p_ville restent dans la signature pour l'écran en ligne ; ils ne décident
  -- plus rien (29/10/2026) : l'intelligence vient de la fiche, la ville du lieu réel.
  if p_intention is null or p_personnage is null or btrim(p_personnage) = ''
     or p_montant is null or p_montant < 500 or p_montant <> trunc(p_montant)
     or p_montant > 100000000 or p_source not in ('liquide','nationale') then
    raise exception 'Parametres de placement invalides';
  end if;
  v_id := 'terme_' || replace(p_intention::text, '-', '');

  select coalesce(liquide,0), country, current_city,
         case when (stats->>'INT') ~ '^[0-9]{1,3}$' then (stats->>'INT')::integer else 8 end
    into v_liquide, v_pays, v_ville, v_int
  from public.personnages_donnees where name = p_personnage for update;
  if not found then raise exception 'Personnage introuvable'; end if;
  if v_ville is null or btrim(v_ville) = '' then raise exception 'Parametres de placement invalides'; end if;

  -- Rejeu sur la meme intention : rendre le resultat original sans debit.
  select * into v_exist from public.placements_bancaires where id = v_id;
  if found then
    if v_exist.personnage <> p_personnage or v_exist.banque <> 'nationale'
       or v_exist.type <> 'terme' or v_exist.montant <> p_montant
       or v_exist.source_fonds is distinct from p_source then
      raise exception 'Intention deja utilisee avec autres parametres';
    end if;
    return v_exist;
  end if;

  if p_source = 'liquide' then
    if v_liquide < p_montant then raise exception 'Liquide insuffisant'; end if;
    update public.personnages_donnees
      set liquide = v_liquide - p_montant, updated_at = now()
      where name = p_personnage;
  else
    select * into v_compte from public.comptes_bancaires
      where personnage = p_personnage and banque = 'nationale' for update;
    if not found or v_compte.solde < p_montant then
      raise exception 'Solde Banque nationale insuffisant';
    end if;
    update public.comptes_bancaires
      set solde = solde - p_montant, updated_at = now() where id = v_compte.id;
  end if;

  insert into public.placements_bancaires
    (id, personnage, pays, ville, banque, type, libelle, montant,
     visible_fiscalement, date_placement, prochaine_echeance, statut,
     int_snapshot, source_fonds)
  values
    (v_id, p_personnage, v_pays, v_ville, 'nationale', 'terme',
     'Placement Banque nationale', p_montant, true, now(),
     now() + interval '7 days', 'actif', v_int, p_source)
  returning * into v_placement;
  return v_placement;
end;
$function$;

-- 3b. L'ancienne porte (intelligence fournie par l'écran) n'a plus d'appelant.
REVOKE EXECUTE ON FUNCTION public.creer_placement_national(text,numeric,integer,text) FROM PUBLIC, anon, authenticated;
