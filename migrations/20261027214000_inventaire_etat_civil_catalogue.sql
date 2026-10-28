-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028205106.
-- Eprouvee au role authenticated en transaction annulee : catalogue appliqué (données seules).
-- (Preparee par Codex.) PREPAREE NON APPLIQUEE. Actes authentifies et fiches issus des sources existantes.
-- Requiert depot/recus communs, registres d'etat civil, successions et autorite des postes.
CREATE OR REPLACE FUNCTION public.etat_civil_date_interne(p_date timestamptz) RETURNS text
LANGUAGE sql STABLE SET search_path=public,pg_temp AS $$
 SELECT extract(day FROM p_date AT TIME ZONE 'Europe/Paris')::integer::text||' '||
 (ARRAY['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'])[extract(month FROM p_date AT TIME ZONE 'Europe/Paris')::integer]||' '||extract(year FROM p_date AT TIME ZONE 'Europe/Paris')::integer::text;
$$;
CREATE OR REPLACE FUNCTION public.etat_civil_ville_interne(p_pays text,p_ville text) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT coalesce((SELECT nom FROM public.villes WHERE pays=p_pays AND ville=p_ville),nullif(p_ville,''));
$$;
REVOKE ALL ON FUNCTION public.etat_civil_date_interne(timestamptz),public.etat_civil_ville_interne(text,text) FROM PUBLIC,anon,authenticated;
INSERT INTO public.objets_modeles(id,objet) VALUES
('fiche_historique:republic:Pierre Thibault','{"name":"Fiche d''état-civil — Pierre Thibault","icon":"ti-file-text","desc":"12 mars 1898 : naissance de Pierre Thibault.<br><br>4 juin 1920 : mariage de Pierre Thibault avec Marie Ravichoux.<br><br>8 août 1929 : naissance de Élise Thibault, fils/fille de Pierre Thibault et Marie Ravichoux.<br><br>17 novembre 1949 : décès de Pierre Thibault."}'::jsonb),
('fiche_historique:republic:Marie Ravichoux','{"name":"Fiche d''état-civil — Marie Ravichoux","icon":"ti-file-text","desc":"4 juin 1920 : mariage de Marie Ravichoux avec Pierre Thibault.<br><br>8 août 1929 : naissance de Élise Thibault, fils/fille de Pierre Thibault et Marie Ravichoux."}'::jsonb),
('fiche_historique:republic:Élise Thibault','{"name":"Fiche d''état-civil — Élise Thibault","icon":"ti-file-text","desc":"8 août 1929 : naissance de Élise Thibault, fils/fille de Pierre Thibault et Marie Ravichoux.<br><br>22 mai 1950 : mariage de Élise Thibault avec Bernard Poinçon.<br><br>14 septembre 1960 : naissance de Gérard Poinçon, fils/fille de Bernard Poinçon et Élise Thibault.<br><br>3 janvier 1991 : décès de Élise Thibault."}'::jsonb),
('fiche_historique:republic:Bernard Poinçon','{"name":"Fiche d''état-civil — Bernard Poinçon","icon":"ti-file-text","desc":"22 mai 1950 : mariage de Bernard Poinçon avec Élise Thibault.<br><br>14 septembre 1960 : naissance de Gérard Poinçon, fils/fille de Bernard Poinçon et Élise Thibault."}'::jsonb),
('fiche_historique:republic:Gérard Poinçon','{"name":"Fiche d''état-civil — Gérard Poinçon","icon":"ti-file-text","desc":"14 septembre 1960 : naissance de Gérard Poinçon, fils/fille de Bernard Poinçon et Élise Thibault."}'::jsonb),
('fiche_historique:republic:Marcel Torcieu','{"name":"Fiche d''état-civil — Marcel Torcieu","icon":"ti-file-text","desc":"5 février 1895 : naissance de Marcel Torcieu.<br><br>19 juin 1915 : mariage de Marcel Torcieu avec Mathilde Bijoux.<br><br>30 octobre 1958 : décès de Marcel Torcieu."}'::jsonb),
('fiche_historique:republic:Mathilde Bijoux','{"name":"Fiche d''état-civil — Mathilde Bijoux","icon":"ti-file-text","desc":"19 juin 1915 : mariage de Mathilde Bijoux avec Marcel Torcieu."}'::jsonb),
('fiche_historique:republic:Maurice Caillon','{"name":"Fiche d''état-civil — Maurice Caillon","icon":"ti-file-text","desc":"21 juillet 1901 : naissance de Maurice Caillon.<br><br>9 avril 1920 : mariage de Maurice Caillon avec Lucienne Balrasse.<br><br>2 décembre 1954 : décès de Maurice Caillon."}'::jsonb),
('fiche_historique:republic:Lucienne Balrasse','{"name":"Fiche d''état-civil — Lucienne Balrasse","icon":"ti-file-text","desc":"9 avril 1920 : mariage de Lucienne Balrasse avec Maurice Caillon."}'::jsonb),
('fiche_historique:republic:Jacques Moulin','{"name":"Fiche d''état-civil — Jacques Moulin","icon":"ti-file-text","desc":"16 janvier 1897 : naissance de Jacques Moulin.<br><br>27 mars 1923 : mariage de Jacques Moulin avec Raymonde Charcot.<br><br>8 juin 1965 : décès de Jacques Moulin."}'::jsonb),
('fiche_historique:republic:Raymonde Charcot','{"name":"Fiche d''état-civil — Raymonde Charcot","icon":"ti-file-text","desc":"27 mars 1923 : mariage de Raymonde Charcot avec Jacques Moulin."}'::jsonb),
('fiche_historique:republic:Étienne Tintabin','{"name":"Fiche d''état-civil — Étienne Tintabin","icon":"ti-file-text","desc":"11 mai 1898 : naissance de Étienne Tintabin.<br><br>14 septembre 1921 : mariage de Étienne Tintabin avec Ludivine Girard.<br><br>25 avril 1969 : décès de Étienne Tintabin."}'::jsonb),
('fiche_historique:republic:Ludivine Girard','{"name":"Fiche d''état-civil — Ludivine Girard","icon":"ti-file-text","desc":"14 septembre 1921 : mariage de Ludivine Girard avec Étienne Tintabin."}'::jsonb) ON CONFLICT(id) DO UPDATE SET objet=excluded.objet;
INSERT INTO public.objets_modeles(id,objet) VALUES
('acte:naissance','{"type":"acte_officiel_naissance","icon":"ti-file-certificate","legal":true}'::jsonb),
('acte:mariage','{"type":"acte_officiel_mariage","icon":"ti-file-certificate","legal":true}'::jsonb),
('acte:deces','{"type":"acte_officiel_deces","icon":"ti-file-certificate","legal":true}'::jsonb),
('acte:succession','{"type":"acte_officiel_succession","icon":"ti-file-certificate","legal":true}'::jsonb)
ON CONFLICT(id) DO UPDATE SET objet=excluded.objet;
