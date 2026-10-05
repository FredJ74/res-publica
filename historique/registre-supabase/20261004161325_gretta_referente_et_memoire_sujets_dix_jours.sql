-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20261004161325
-- Nom original      : gretta_referente_et_memoire_sujets_dix_jours
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-10-04 16:13:25 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : baced1110d1e526e7a71300f8c455e50
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- GRETTA DELIEU : REFERENTE, ET MEMOIRE DE SUJETS A DIX JOURS (4 octobre 2026)
-- Le signal fiable ne vient PAS du modele : il vient du message du JOUEUR, rapproche
-- d'un VOCABULAIRE FERME. Le contrat de /api/chat n'est pas touche d'un caractere.
-- L'OUBLI N'EFFACE RIEN : aucun DELETE, aucun cron. La RPC de lecture ignore
-- simplement les sujets de plus de dix jours.

-- 1. Gretta rejoint la liste fermee des referents.
-- `domaine` n'est PAS le domaine envoye au modele : c'est un libelle de lecture.
-- `pays` est obligatoire depuis le lot deux : Gretta est republicaine.
insert into public.pnj_referents (referent_id, domaine, pays)
values ('gretta_delieu', 'centre d''affaires — bureaux, location et equipements', 'republic')
on conflict (referent_id) do update
   set domaine = excluded.domaine,
       pays    = excluded.pays;

-- 2. Le vocabulaire ferme des sujets.
create table if not exists public.pnj_referents_sujets_connus (
  referent_id text not null references public.pnj_referents(referent_id) on delete cascade,
  sujet       text not null,
  libelle     text not null,
  primary key (referent_id, sujet)
);

comment on table public.pnj_referents_sujets_connus is
  'Vocabulaire FERME des sujets qu''un referent peut memoriser. Un sujet absent d''ici est refuse : le serveur ne devine jamais.';

insert into public.pnj_referents_sujets_connus (referent_id, sujet, libelle) values
  ('gretta_delieu', 'bureau_prestige', 'le Bureau Prestige'),
  ('gretta_delieu', 'bureau_standard', 'le Bureau Standard'),
  ('gretta_delieu', 'open_space',      'l''open space et ses postes'),
  ('gretta_delieu', 'louer',           'comment on loue un bureau'),
  ('gretta_delieu', 'loyer',           'le prix et le paiement du loyer'),
  ('gretta_delieu', 'equipements',     'les equipements professionnels a venir'),
  ('gretta_delieu', 'commerce',        'installer son activite dans un bureau'),
  ('gretta_delieu', 'resilier',        'rendre un bureau')
on conflict (referent_id, sujet) do update set libelle = excluded.libelle;

alter table public.pnj_referents_sujets_connus enable row level security;
revoke all on public.pnj_referents_sujets_connus from public, anon, authenticated;
grant all on public.pnj_referents_sujets_connus to service_role;

-- 3. Noter un sujet. Le client est libre de se tromper : le serveur refuse en
-- silence tout sujet hors vocabulaire, et l'identite vient de mon_personnage().
create or replace function public.referent_pedagogie_noter_sujet(
  p_referent_id text,
  p_sujet       text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_moi text;
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'pas_de_personnage');
  end if;

  if not exists (
    select 1 from public.pnj_referents_sujets_connus
     where referent_id = p_referent_id and sujet = p_sujet
  ) then
    return jsonb_build_object('ok', false, 'raison', 'sujet_inconnu');
  end if;

  insert into public.pnj_referents_pedagogie (referent_id, joueur)
  values (p_referent_id, v_moi)
  on conflict (referent_id, joueur) do nothing;

  -- L'horodatage ECRASE le precedent : reparler d'un sujet le rafraichit.
  update public.pnj_referents_pedagogie
     set sujets = coalesce(sujets, '{}'::jsonb)
                  || jsonb_build_object(p_sujet, to_jsonb(now())),
         derniere_le = now()
   where referent_id = p_referent_id and joueur = v_moi;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.referent_pedagogie_noter_sujet(text, text) from public, anon;
grant execute on function public.referent_pedagogie_noter_sujet(text, text) to authenticated, service_role;

-- 4. Lire le contexte — c'est ICI que l'oubli a lieu. Le compteur et sa forme ne
-- changent pas : les dix-sept referents existants recoivent exactement ce qu'ils
-- recevaient, `sujets` restant un tableau vide pour eux.
create or replace function public.referent_pedagogie_contexte(
  p_referent_id text
) returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_moi    text;
  v_n      integer := 0;
  v_sujets jsonb   := '[]'::jsonb;
  FENETRE  constant interval := interval '10 days';
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'pas_de_personnage');
  end if;

  select coalesce(p.consultations, 0),
         coalesce(
           (select jsonb_agg(c.libelle order by c.libelle)
              from jsonb_each_text(coalesce(p.sujets, '{}'::jsonb)) as s(cle, quand)
              join public.pnj_referents_sujets_connus c
                on c.referent_id = p_referent_id and c.sujet = s.cle
             where (s.quand)::timestamptz > now() - FENETRE),
           '[]'::jsonb)
    into v_n, v_sujets
    from public.pnj_referents_pedagogie p
   where p.referent_id = p_referent_id and p.joueur = v_moi;

  return jsonb_build_object('ok', true,
                            'consultations', coalesce(v_n, 0),
                            'sujets', coalesce(v_sujets, '[]'::jsonb));
end;
$$;

revoke all on function public.referent_pedagogie_contexte(text) from public, anon;
grant execute on function public.referent_pedagogie_contexte(text) to authenticated, service_role;

-- 5. Gardes — la migration echoue plutot que de laisser la base a moitie posee.
do $$
declare n integer;
begin
  select count(*) into n from public.pnj_referents where referent_id = 'gretta_delieu';
  if n <> 1 then raise exception 'Gretta absente de pnj_referents (%)', n; end if;

  select count(*) into n from public.pnj_referents
   where referent_id = 'gretta_delieu' and pays = 'republic';
  if n <> 1 then raise exception 'Gretta n''est pas rattachee a un empire'; end if;

  select count(*) into n from public.pnj_referents_sujets_connus where referent_id = 'gretta_delieu';
  if n < 8 then raise exception 'vocabulaire de Gretta incomplet (%)', n; end if;

  -- Une migration ne s'execute sous l'identite de personne : mon_personnage()
  -- rend null, et la RPC repond 'pas_de_personnage'. On verifie donc ce qui est
  -- verifiable sans joueur.
  if public.referent_pedagogie_contexte('gretta_delieu')->>'raison' <> 'pas_de_personnage' then
    raise exception 'referent_pedagogie_contexte ne degrade plus comme avant';
  end if;

  -- L'OUBLI A DIX JOURS, prouve sur de vraies donnees : un sujet d'aujourd'hui,
  -- un d'il y a onze jours. Seul le frais ressort, et le vieux n'est pas efface.
  if (select coalesce(
        (select jsonb_agg(c.libelle order by c.libelle)
           from jsonb_each_text(jsonb_build_object(
                  'loyer', to_jsonb(now()),
                  'louer', to_jsonb(now() - interval '11 days'))) as s(cle, quand)
           join public.pnj_referents_sujets_connus c
             on c.referent_id = 'gretta_delieu' and c.sujet = s.cle
          where (s.quand)::timestamptz > now() - interval '10 days'),
        '[]'::jsonb))
     <> '["le prix et le paiement du loyer"]'::jsonb then
    raise exception 'la fenetre d''oubli de dix jours ne filtre pas comme prevu';
  end if;
end $$;