// Page MJ — Dotations initiales du lancement (décisions n° 5 et 6 de Fred, 26/11/2026). Lues par la remise à zéro du 19/12
// (historique/preparations-lancement/), jamais avant : modifier ces montants ne touche à aucun solde du jeu en cours.
// Commerces : caisse, quantité de chaque matière et de chaque produit tenus, par pays et par type (« * » = défaut du pays ;
// champs vides = retour au défaut). Caisses publiques : solde de départ par catégorie (identifiant sans pays ni ville).
// Migration 20261126200000. Pour Codex : page MJ, français seulement.
async function admDotationsLancementCharger() {
  const el = document.getElementById('adm-dotations-lancement'); if (!el) return;
  el.textContent = 'Chargement…';
  let r;
  try { r = await rpAdminRpc('admin_dotations_lancement_lire', {}); } catch (e) { el.textContent = 'Échec : ' + e.message + ' (migration 20261126200000 non appliquée ?)'; return; }
  el.textContent = '';
  if (!r || !r.ok) { el.textContent = 'Refus : ' + (r && r.raison); return; }
  const bloc = titre => { const f = document.createElement('div'); f.className = 'adm-dossier'; const t = document.createElement('strong'); t.textContent = titre; f.append(t); el.append(f); return f; };
  const champ = (v, w) => { const x = document.createElement('input'); x.type = 'number'; x.min = 0; x.value = v ?? ''; x.style.width = w || '6rem'; return x; };
  const texte = (v, w) => { const x = document.createElement('input'); x.value = v ?? ''; x.style.width = w || '10rem'; return x; };
  const num = x => x.value.trim() === '' ? null : Number(x.value);
  const envoyer = async (fn, params, m) => {
    try { const x = await rpAdminRpc(fn, params); if (x && x.ok) admDotationsLancementCharger(); else m.textContent = ' Refus : ' + (x && x.raison); }
    catch (e) { m.textContent = ' Échec : ' + e.message; }
  };
  const ligne = (f, ...enfants) => { const d = document.createElement('div'); d.className = 'adm-detail'; d.append(...enfants); f.append(d); return d; };
  const bouton = (t, fn) => { const b = document.createElement('button'); b.type = 'button'; b.textContent = t; b.onclick = fn; return b; };

  const fc = bloc('Commerces (PNJ compris) : caisse, matières, produits');
  const commerce = (pays, type, c, m, p) => {
    const ty = texte(type, '9rem'), ca = champ(c), ma = champ(m, '4rem'), pr = champ(p, '4rem'), msg = document.createElement('span');
    ligne(fc, (pays === 'soviet' ? 'Sovarka' : 'Républia') + ' — type ', ty, ' caisse ', ca, ' matières ', ma, ' produits ', pr, ' ',
      bouton('Enregistrer', () => envoyer('admin_dotation_commerce_fixer', { p_pays: pays, p_type: ty.value.trim(), p_caisse: num(ca), p_matieres: num(ma), p_produits: num(pr) }, msg)), msg);
  };
  for (const x of r.commerces || []) commerce(x.pays, x.type, x.caisse, x.matieres_qte, x.produits_qte);
  commerce('republic', '', null, null, null); commerce('soviet', '', null, null, null);
  ligne(fc, 'Types existants : ' + (r.types_commerces || []).join(', '));

  const fk = bloc('Caisses publiques : solde de départ par catégorie');
  const caisse = (pays, cat, montant) => {
    const ct = texte(cat, '14rem'), mo = champ(montant), msg = document.createElement('span');
    ligne(fk, (pays === 'soviet' ? 'Sovarka' : 'Républia') + ' — ', ct, ' ', mo, pays === 'soviet' ? ' PSK ' : ' FR ',
      bouton('Enregistrer', () => envoyer('admin_dotation_caisse_fixer', { p_pays: pays, p_categorie: ct.value.trim(), p_montant: num(mo) }, msg)), msg);
  };
  for (const x of r.caisses || []) caisse(x.pays, x.categorie, x.montant);
  caisse('republic', '', null); caisse('soviet', '', null);
}
