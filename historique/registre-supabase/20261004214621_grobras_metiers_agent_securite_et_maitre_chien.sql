-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20261004214621
-- Nom original      : grobras_metiers_agent_securite_et_maitre_chien
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-10-04 21:46:21 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 575512498bdf28036b52b5633fcb8938
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
-- GROBRAS SECURITE — LOT 2 : LES DEUX PROFILS METIER (5 octobre 2026)
--
-- DEUX LIGNES, et c'est le resultat de l'audit d'architecture : le socle PNJ
-- porte deja la position, les PA, les six caracteristiques, la propriete, le
-- chef, l'equipement et la mort. Il ne manquait que la fiche de deux metiers.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS : aucun PNJ cree, aucun recrutement ouvert
-- (employe_metiers_recrutables() n'est pas touchee), aucune table, aucune
-- fonction, aucune colonne, aucune caisse, aucun contrat, aucune mission.
--
-- POURQUOI LA FAMILLE EST « employe », ET POURQUOI LA CLASSE N'EST PAS ICI.
--   pnj_metier_de(id) : « CASE WHEN famille='employe' THEN pnj_employes_metier.job
--     ELSE famille END » => un metier DISTINCT de sa famille n'existe QUE pour la
--     famille employe. C'est deja ainsi que vivent escort, informateur, codetenu.
--   pnj_classe_de(id) : « COALESCE(pnj_membres.classe,
--     pnj_familles_classes[famille].classe) » => L'INDIVIDU D'ABORD. La classe ne
--     vit donc ni dans pnj_metiers_profils (pas de colonne), ni dans le metier :
--     elle se pose sur la ligne du PNJ, a sa creation.
-- Consequence : un agent Grobras pourra etre cree en classe ALPHA sans promouvoir
-- la famille employe, donc sans toucher aux escortes ni aux informateurs qui
-- restent beta. Ce que alpha apportera : pnj_pa_garde() rejette toute variation
-- de PA hors de cette classe. Faute de colonne, l'intention est inscrite dans
-- `note`, comme le font deja les huit metiers existants.
--
-- LES VALEURS. Arbitre par le GD : PER 12 / VOL 16 pour l'agent, PER 16 / VOL 14
-- pour le maitre-chien. Les six caracteristiques etant NOT NULL, INT/CHA/DUP/ENT
-- sont RECOPIES du profil `policier` (10/8/8/10) -- le metier deja arbitre le plus
-- proche, et celui dont `douanier` partage deja les six valeurs. Aucune valeur
-- inventee. Valide par Fred le 5 octobre 2026.
--
-- pa_initial = 12 : valeur du socle (pnj_pa_max() rend 12, pnj_membres.pa vaut 12
-- par defaut), posee parce que employe_recruter fait COALESCE(p_pa, pa_initial) --
-- un NULL passerait un NULL explicite a une colonne NOT NULL au lieu de laisser le
-- defaut s'appliquer. Precaution, pas decision.
--
-- cout_initial et cout_jour restent NULL DELIBEREMENT. Les cinq metiers non
-- achetables portent 0 ; ici NULL dit « non arbitre », quand 0 dirait « gratuit »
-- -- une decision que ce lot n'a pas le droit de prendre.

insert into public.pnj_metiers_profils
  (metier, car_int, car_cha, car_vol, car_per, car_dup, car_ent,
   pa_initial, cout_initial, cout_jour, note, quota_note)
values
  ('agent_securite', 10, 8, 16, 12, 8, 10, 12, null, null,
   'Metier de la famille employe, destine a la classe ALPHA (posee sur l''individu a sa creation, pas ici). Agent de securite prive de l''agence Grobras Securite, Luthecia. VOL 16 et PER 12 arbitres par le GD le 5 octobre 2026 ; INT/CHA/DUP/ENT recopies du profil policier, le metier deja arbitre le plus proche. Aucune valeur inventee.',
   'Aucun quota, aucun plafond propre : ce metier n''est PAS recrutable. Il ne figure pas dans employe_metiers_recrutables(), donc employe_recruter le refuse. Le plafond commun de 10 employes s''appliquera le jour ou il sera ouvert.'),

  ('maitre_chien',   10, 8, 14, 16, 8, 10, 12, null, null,
   'Metier de la famille employe, destine a la classe ALPHA (posee sur l''individu a sa creation, pas ici). Maitre-chien de l''agence Grobras Securite, Luthecia. PER 16 et VOL 14 arbitres par le GD le 5 octobre 2026 ; INT/CHA/DUP/ENT recopies du profil policier. Le chien n''est PAS un PNJ : il fait partie du maitre, comme le cynophile de la police (pnj_force_publique_metier.type_unite = ''cynophile'', chien_nom) n''a jamais eu de ligne propre.',
   'Aucun quota, aucun plafond propre : ce metier n''est PAS recrutable. Il ne figure pas dans employe_metiers_recrutables(), donc employe_recruter le refuse.')
on conflict (metier) do update set
  car_int      = excluded.car_int,
  car_cha      = excluded.car_cha,
  car_vol      = excluded.car_vol,
  car_per      = excluded.car_per,
  car_dup      = excluded.car_dup,
  car_ent      = excluded.car_ent,
  pa_initial   = excluded.pa_initial,
  cout_initial = excluded.cout_initial,
  cout_jour    = excluded.cout_jour,
  note         = excluded.note,
  quota_note   = excluded.quota_note;

-- GARDES — la migration echoue plutot que de poser un socle a moitie juste.
do $$
declare
  v_n integer;
  v_p jsonb;
begin
  v_p := public.pnj_metier_profil('agent_securite');
  if v_p is null then raise exception 'agent_securite absent de pnj_metiers_profils'; end if;
  if (v_p->>'PER')::int <> 12 or (v_p->>'VOL')::int <> 16 then
    raise exception 'agent_securite : PER/VOL non conformes a l''arbitrage (% / %)', v_p->>'PER', v_p->>'VOL';
  end if;

  v_p := public.pnj_metier_profil('maitre_chien');
  if v_p is null then raise exception 'maitre_chien absent de pnj_metiers_profils'; end if;
  if (v_p->>'PER')::int <> 16 or (v_p->>'VOL')::int <> 14 then
    raise exception 'maitre_chien : PER/VOL non conformes a l''arbitrage (% / %)', v_p->>'PER', v_p->>'VOL';
  end if;

  if (select count(*) from jsonb_object_keys(public.pnj_metier_profil('agent_securite'))) <> 6 then
    raise exception 'agent_securite ne rend pas les six caracteristiques';
  end if;

  -- AUCUN AUTRE METIER N'A BOUGE : les huit profils d'avant ce lot, un par un.
  select count(*) into v_n from public.pnj_metiers_profils
   where (metier, car_int, car_cha, car_vol, car_per, car_dup, car_ent) in (
     ('agent',       13, 12, 12, 13, 13, 10),
     ('codetenu',    10, 10, 10, 12, 12, 10),
     ('douanier',    10,  8, 12, 12,  8, 10),
     ('escort',      10, 15, 10, 10, 12, 10),
     ('informateur', 10, 10,  8, 15, 12,  8),
     ('militant',     9, 12, 15,  9,  8, 12),
     ('policier',    10,  8, 12, 12,  8, 10),
     ('soldat',       9,  8, 12, 10,  8, 12));
  if v_n <> 8 then
    raise exception 'un metier preexistant a change : % profils intacts sur 8', v_n;
  end if;

  -- Le recrutement reste FERME pour les deux nouveaux metiers.
  if 'agent_securite' = any (public.employe_metiers_recrutables())
     or 'maitre_chien' = any (public.employe_metiers_recrutables()) then
    raise exception 'un des nouveaux metiers est devenu recrutable : ce lot ne doit pas l''ouvrir';
  end if;

  -- Aucun PNJ n'a ete cree, et aucun ne porte ces metiers.
  select count(*) into v_n from public.pnj_employes_metier
   where job in ('agent_securite', 'maitre_chien');
  if v_n <> 0 then
    raise exception 'ce lot ne doit creer aucun PNJ (% trouve[s])', v_n;
  end if;
end $$;