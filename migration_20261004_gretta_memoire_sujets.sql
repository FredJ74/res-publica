-- ===========================================================================
-- GRETTA DELIEU : REFERENTE, ET MEMOIRE DE SUJETS A DIX JOURS
-- 4 octobre 2026
-- ---------------------------------------------------------------------------
-- DEUX CHOSES, ET RIEN D'AUTRE.
--
-- 1. Gretta Delieu entre dans la liste fermee des referents. Sans cette ligne,
--    referent_pedagogie_noter() refuse, et sa memoire n'existerait jamais.
--
-- 2. La colonne `sujets`, prevue le 1er octobre et laissee vide a dessein,
--    entre en service -- mais SANS trahir l'arbitrage qui l'avait laissee vide.
--
-- CE QUE DISAIT CET ARBITRAGE : « deduire un sujet d'un texte libre demanderait
-- au modele de l'annoncer, ce qui changerait le contrat de /api/chat pour les
-- 180 PNJ. On ne devine pas, on attend un signal fiable. »
--
-- LE SIGNAL FIABLE EST ICI, et il ne vient pas du modele : il vient du message
-- du JOUEUR, rapproche d'un VOCABULAIRE FERME declare ci-dessous. Le serveur
-- n'accepte aucun sujet hors de cette liste. Le contrat de /api/chat n'est pas
-- touche d'un caractere : aucun champ n'est ajoute, aucune reponse n'est lue.
--
-- L'OUBLI N'EFFACE RIEN. Aucun DELETE, aucun cron, aucune tache de menage : la
-- RPC de lecture ignore simplement les sujets de plus de dix jours. Un souvenir
-- oublie reste en base, et c'est voulu -- si la fenetre devait changer un jour,
-- rien n'aurait ete perdu. C'est aussi ce qui rend la chose rejouable : on peut
-- lire la memoire telle qu'elle etait, en changeant une seule constante.
--
-- AUCUNE TABLE NOUVELLE. AUCUNE COLONNE NOUVELLE. AUCUNE REGLE DE JEU.
-- ===========================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Gretta rejoint la liste fermee des referents
-- ---------------------------------------------------------------------------
-- `pnj_referents` existe pour une seule raison : empecher qu'un client fasse
-- naitre 180 lignes de memoire en demandant gentiment.
--
-- `domaine` n'est PAS le domaine envoye au modele : c'est un libelle de lecture,
-- comme le dit le commentaire de la table ("la personnalite vit dans
-- api/_pnj-referents.js"). On garde donc la forme courte des sept premiers
-- referents ('militaire — organisation, strategie, operations'), et non la
-- phrase longue du prompt, qui elle vit dans le code et nulle part ailleurs.
--
-- `pays` EST OBLIGATOIRE, et ce fichier l'avait oublie (4 octobre, premiere
-- tentative d'application : 23502, null value in column "pays"). La colonne a
-- ete ajoutee par le lot deux du 1er octobre, quand les referents ont cesse
-- d'etre implicitement republicains -- or ce fichier avait ete ecrit sur le
-- modele de la migration du matin, qui ne la connaissait pas encore. La leçon
-- n'est pas « ajouter une colonne » : c'est qu'une migration preparee a l'avance
-- doit etre relue contre le schema REELLEMENT deploye, pas contre la migration
-- soeur dont on l'a recopiee. Gretta est republicaine, comme ses dix-sept aines.
insert into public.pnj_referents (referent_id, domaine, pays)
values ('gretta_delieu', 'centre d''affaires — bureaux, location et equipements', 'republic')
on conflict (referent_id) do update
   set domaine = excluded.domaine,
       pays    = excluded.pays;


-- ---------------------------------------------------------------------------
-- 2. Le vocabulaire ferme des sujets
-- ---------------------------------------------------------------------------
-- Une table, parce qu'un vocabulaire se relit, s'etend et s'audite -- alors
-- qu'une liste codee en dur dans une fonction se duplique et se perd. Elle est
-- partagee : un futur referent y ajoutera ses propres sujets sans toucher au
-- code de la RPC.
create table if not exists public.pnj_referents_sujets_connus (
  referent_id text not null references public.pnj_referents(referent_id) on delete cascade,
  sujet       text not null,
  libelle     text not null,          -- ce que Gretta doit se rappeler avoir aborde
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


-- ---------------------------------------------------------------------------
-- 3. Noter un sujet
-- ---------------------------------------------------------------------------
-- Appelee par le client APRES un echange abouti, avec un sujet qu'il a repere
-- dans le message du joueur. Le client est libre de se tromper : le serveur
-- refuse en silence tout sujet hors vocabulaire, et l'identite du joueur n'est
-- jamais celle qu'il annonce -- c'est mon_personnage() qui tranche.
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

  -- Vocabulaire ferme : hors liste, on ne note rien et on le dit sans drame.
  if not exists (
    select 1 from public.pnj_referents_sujets_connus
     where referent_id = p_referent_id and sujet = p_sujet
  ) then
    return jsonb_build_object('ok', false, 'raison', 'sujet_inconnu');
  end if;

  -- La ligne de pedagogie peut ne pas exister encore : on la cree sans compter
  -- de consultation, ce n'est pas le role de cette fonction.
  insert into public.pnj_referents_pedagogie (referent_id, joueur)
  values (p_referent_id, v_moi)
  on conflict (referent_id, joueur) do nothing;

  -- L'horodatage ECRASE le precedent : reparler d'un sujet le rafraichit, et
  -- repousse donc son oubli. C'est ce qu'on attend d'un souvenir.
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


-- ---------------------------------------------------------------------------
-- 4. Lire le contexte — c'est ICI que l'oubli a lieu
-- ---------------------------------------------------------------------------
-- On remplace referent_pedagogie_contexte() pour qu'elle rende, en plus du
-- compteur qu'elle rendait deja, les sujets encore frais. Le compteur et sa
-- forme ne changent pas : les dix-sept referents existants recoivent exactement
-- ce qu'ils recevaient, `sujets` restant un tableau vide pour eux.
--
-- DIX JOURS, en un seul endroit : la constante ci-dessous. Rien n'est efface ;
-- ce qui est trop vieux est simplement ignore.
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


-- ---------------------------------------------------------------------------
-- 5. Gardes — la migration echoue plutot que de laisser la base a moitie posee
-- ---------------------------------------------------------------------------
do $$
declare n integer;
begin
  select count(*) into n from public.pnj_referents where referent_id = 'gretta_delieu';
  if n <> 1 then raise exception 'Gretta absente de pnj_referents (%)', n; end if;

  -- La garde que ce fichier n'avait pas, et qui lui aurait epargne un 23502.
  select count(*) into n from public.pnj_referents
   where referent_id = 'gretta_delieu' and pays = 'republic';
  if n <> 1 then raise exception 'Gretta n''est pas rattachee a un empire'; end if;

  select count(*) into n from public.pnj_referents_sujets_connus where referent_id = 'gretta_delieu';
  if n < 8 then raise exception 'vocabulaire de Gretta incomplet (%)', n; end if;

  -- CE QUE CE GARDE-FOU NE PEUT PAS FAIRE. Une migration ne s'execute sous
  -- l'identite de personne : mon_personnage() rend null, et la RPC repond donc
  -- 'pas_de_personnage'. Verifier ici la presence de la clef `consultations`
  -- etait un faux test -- il a d'ailleurs echoue a la premiere application, et
  -- c'est le test qui avait tort, pas la fonction. On verifie donc deux choses
  -- qui, elles, sont verifiables sans joueur.

  -- 1. La RPC degrade exactement comme la version du 1er octobre.
  if public.referent_pedagogie_contexte('gretta_delieu')->>'raison' <> 'pas_de_personnage' then
    raise exception 'referent_pedagogie_contexte ne degrade plus comme avant';
  end if;

  -- 2. L'OUBLI A DIX JOURS, prouve sur de vraies donnees. On soumet a la meme
  -- expression deux sujets : un d'aujourd'hui, un d'il y a onze jours. Seul le
  -- frais doit ressortir -- et le vieux n'est pas efface, il est ignore.
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

commit;
