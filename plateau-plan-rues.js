// =====================================================================
// PLAN DE VILLE DEDUIT DES RUES (9 novembre 2026, demande de Fred)
// =====================================================================
//
// POURQUOI. Les plans de ville ont toujours ete dessines a part (grille, Excalidraw) et n'ont
// jamais colle a la navigation par rues : a PSM il manquait une vingtaine de batiments,
// Novomirsk empruntait le plan de Luthecia. Ici le plan n'est PAS dessine : il est DEDUIT du
// graphe des rues que le joueur parcourt (RUE_CENTRALE_NOEUDS, dont les liens sont ceux que le
// serveur valide -- table rue_noeuds_serveur, banc banc-coherence-rues-local.py). Une rue
// ajoutee apparait donc d'elle-meme sur le plan, et le plan ne peut pas contredire la rue.
//
// LE PRINCIPE. Chaque noeud est une VUE qui regarde dans une direction fixe. Ses liens sont
// relatifs a ce regard (toutDroit, droite, arriere, gauche). Quand A mene a B et que B ramene a
// A, les deux liens sont opposes sur la boussole : cela fixe l'orientation de B a partir de
// celle de A. On oriente ainsi toute la ville depuis son noeud de depart (regard vers le nord),
// puis on place les noeuds sur une grille : un lien vers l'est met B a droite de A, sur la meme
// ligne ; vers le nord, au-dessus, sur la meme colonne. Les batiments se rangent devant la vue
// qui les montre, du cote ou ils apparaissent a l'image.
//
// LES INCOHERENCES NE SONT PAS MASQUEES. Une rue qui ne ramene pas d'ou l'on vient, deux
// chemins qui donnent deux orientations differentes, une boucle impossible sur une grille :
// chaque cas est rendu dans `anomalies`, en francais, pour etre corrige dans la navigation.
//
// MODULE PUR : aucune lecture de `state`, aucun DOM dans le calcul. Utilisable par le jeu et par
// les bancs Node (module.exports en bas).

const PLAN_RUES_RELATIF = { toutDroit: 0, droite: 1, arriere: 2, gauche: 3 };
const PLAN_RUES_BOUSSOLE = ['nord', 'est', 'sud', 'ouest'];
const PLAN_RUES_PAS = [[0, -1], [1, 0], [0, 1], [-1, 0]]; // nord, est, sud, ouest (y vers le bas)

function planRuesComposante(noeuds, depart) {
  const ordre = [], vus = new Set(), file = [depart];
  while (file.length) {
    const id = file.shift();
    if (vus.has(id) || !noeuds[id]) continue;
    vus.add(id); ordre.push(id);
    const n = noeuds[id];
    const cibles = [n.liens, ...Object.values(n.liensParArrivee || {})];
    for (const l of cibles) for (const dst of Object.values(l || {})) {
      if (dst && noeuds[dst] && !vus.has(dst)) file.push(dst);
    }
  }
  return ordre;
}

function planRuesLiens(n) {
  const out = [];
  for (const [rel, dst] of Object.entries(n.liens || {})) {
    if (dst && rel in PLAN_RUES_RELATIF) out.push([PLAN_RUES_RELATIF[rel], dst]);
  }
  return out;
}

function calculerPlanRues(noeudsPays, depart, options) {
  const opts = options || {};
  const anomalies = [];
  const noeuds = noeudsPays || {};
  if (!depart || !noeuds[depart]) return { noeuds: {}, rues: [], batiments: [], fusions: [], anomalies: [{ type: 'sans_depart', texte: 'Aucun noeud de depart pour cette ville.' }] };
  const ids = planRuesComposante(noeuds, depart);
  const dans = new Set(ids);

  // 1) ORIENTATION de chaque vue.
  const regard = { [depart]: 0 };
  const suppose = new Set();
  const file = [depart];
  const deja = new Set();
  while (file.length) {
    const a = file.shift();
    if (deja.has(a)) continue;
    deja.add(a);
    for (const [rA, b] of planRuesLiens(noeuds[a])) {
      if (!dans.has(b)) continue;
      const retour = planRuesLiens(noeuds[b]).find(([, x]) => x === a);
      const sens = (regard[a] + rA) % 4;
      const attendu = retour ? (sens + 2 - retour[0] + 8) % 4 : sens;
      if (!retour) suppose.add(b);
      if (regard[b] === undefined) { regard[b] = attendu; file.push(b); }
      else if (regard[b] !== attendu && retour) {
        // Boucle qui ne se referme pas a angle droit : normal (rue courbe), absorbe en etape 3.
      }
    }
  }
  ids.forEach(id => { if (regard[id] === undefined) regard[id] = 0; });

  // 2) RUES (aretes non orientees) avec leur direction absolue, et liens sans retour.
  const rues = [], cles = new Set();
  // Paires de vues qui sont deux images d'un meme carrefour : dessinees en UN SEUL point
  // (decision de Fred du 09/11/2026 au soir).
  const fusions = [], fusionCle = new Set();
  const cleFusion = (x, y) => (x < y ? x + '|' + y : y + '|' + x);
  for (const a of ids) {
    for (const [rA, b] of planRuesLiens(noeuds[a])) {
      if (!dans.has(b)) continue;
      const retour = planRuesLiens(noeuds[b]).some(([, x]) => x === a);
      // Carrefour photographie deux fois (Novomirsk V4/V5, V14/V15) : A et C sont deux images du
      // meme carrefour, reliees entre elles ; depuis B, le retour ramene a C. Voulu par la
      // navigation (migration 20261105011000) : ce n'est pas une rue a corriger.
      const memeCarrefour = !retour && planRuesLiens(noeuds[b]).some(([, c]) =>
        dans.has(c) && planRuesLiens(noeuds[a]).some(([, x]) => x === c)
        && planRuesLiens(noeuds[c]).some(([, x]) => x === a));
      if (memeCarrefour) {
        for (const [, c] of planRuesLiens(noeuds[b])) {
          if (dans.has(c) && planRuesLiens(noeuds[a]).some(([, x]) => x === c)
            && planRuesLiens(noeuds[c]).some(([, x]) => x === a) && !fusionCle.has(cleFusion(a, c))) {
            fusionCle.add(cleFusion(a, c)); fusions.push([a, c]);
          }
        }
      }
      if (!retour && !memeCarrefour) anomalies.push({ type: 'sans_retour', noeuds: [a, b], texte: `La rue « ${a} » mene a « ${b} », mais « ${b} » n'a pas de fleche pour revenir.` });
      const k = a < b ? a + '|' + b : b + '|' + a;
      if (cles.has(k)) continue;
      cles.add(k);
      rues.push({ de: a, vers: b, sens: (regard[a] + rA) % 4 });
    }
  }

  const cx = {}, cy = {};
  // 3) POSITIONS. Une rue « tout droit » d'une image n'est pas une regle tiree au cordeau : une
  // longue avenue courbe un peu, et une boucle de rues dessinee vue par vue ne se referme presque
  // jamais a angle droit parfait. On cherche donc les positions qui respectent AU MIEUX toutes
  // les directions a la fois (moindres carres) : l'ecart d'une boucle se repartit en douce
  // courbure sur toutes ses rues au lieu de casser le plan a un endroit.
  rues.forEach(r => {
    if (fusionCle.has(cleFusion(r.de, r.vers))) {
      // Deux images d'un meme carrefour : aucune distance entre elles, et leurs fleches
      // mutuelles ne disent rien de la geographie (pas d'anomalie « fleches opposees »).
      r.dx = 0; r.dy = 0; r.poids = 25; r.fusion = true;
      return;
    }
    const [ax, ay] = PLAN_RUES_PAS[r.sens];
    const retour = planRuesLiens(noeuds[r.vers]).find(([, x]) => x === r.de);
    let dx = ax, dy = ay;
    if (retour) {
      const [bx, by] = PLAN_RUES_PAS[(regard[r.vers] + retour[0] + 2) % 4];
      dx = (ax + bx) / 2; dy = (ay + by) / 2;
      if (Math.abs(dx) + Math.abs(dy) < 0.01) {
        anomalies.push({ type: 'fleches_opposees', noeuds: [r.de, r.vers], texte: `Entre « ${r.de} » et « ${r.vers} », les deux fleches partent du meme cote : l'une des deux images est inversee.` });
        dx = ax; dy = ay;
      } else if (dx && dy) { const l = Math.hypot(dx, dy); dx /= l; dy /= l; }
    }
    r.dx = dx; r.dy = dy;
  });
  const index = {}; ids.forEach((id, k) => { index[id] = k; });
  const resoudre = cle => {
    // Laplacien du graphe, depart fixe a l'origine.
    const n = ids.length, A = Array.from({ length: n }, () => new Array(n).fill(0)), b = new Array(n).fill(0);
    rues.forEach(r => {
      const i = index[r.de], j = index[r.vers], d = r[cle], w = r.poids || 1;
      A[i][i] += w; A[j][j] += w; A[i][j] -= w; A[j][i] -= w;
      b[i] -= w * d; b[j] += w * d;
    });
    const k0 = index[depart];
    for (let c = 0; c < n; c++) { A[k0][c] = 0; } A[k0][k0] = 1; b[k0] = 0;
    for (let c = 0; c < n; c++) { // Gauss avec pivot partiel
      let piv = c; for (let r2 = c + 1; r2 < n; r2++) if (Math.abs(A[r2][c]) > Math.abs(A[piv][c])) piv = r2;
      [A[c], A[piv]] = [A[piv], A[c]]; [b[c], b[piv]] = [b[piv], b[c]];
      if (Math.abs(A[c][c]) < 1e-9) continue;
      for (let r2 = 0; r2 < n; r2++) if (r2 !== c && A[r2][c]) {
        const f = A[r2][c] / A[c][c];
        for (let c2 = c; c2 < n; c2++) A[r2][c2] -= f * A[c][c2];
        b[r2] -= f * b[c];
      }
    }
    return ids.map((_, k) => (Math.abs(A[k][k]) < 1e-9 ? 0 : b[k] / A[k][k]));
  };
  const X = resoudre('dx'), Y = resoudre('dy');
  // Un carrefour photographie deux fois forme un groupe : un seul point sur le plan.
  const groupe = {}; ids.forEach(id => { groupe[id] = id; });
  fusions.forEach(([a, c]) => { groupe[c] = groupe[a]; });
  const memeGroupe = (i, j) => groupe[ids[i]] === groupe[ids[j]];
  const regrouper = () => fusions.forEach(([a, c]) => {
    const i = index[a], j = index[c];
    const mx = a === depart ? X[i] : c === depart ? X[j] : (X[i] + X[j]) / 2;
    const my = a === depart ? Y[i] : c === depart ? Y[j] : (Y[i] + Y[j]) / 2;
    X[i] = X[j] = mx; Y[i] = Y[j] = my;
  });
  // Deux vues trop proches (rues sans lien qui se croiseraient) : on les ecarte doucement.
  const separer = () => {
    for (let tour = 0; tour < 200; tour++) {
      let bouge = false;
      for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) {
        if (memeGroupe(i, j)) continue;
        const ddx = X[j] - X[i], ddy = Y[j] - Y[i], d = Math.hypot(ddx, ddy);
        if (d < 0.75) {
          const ux = d > 1e-6 ? ddx / d : 1, uy = d > 1e-6 ? ddy / d : 0, m = (0.75 - d) / 2;
          if (ids[i] !== depart) { X[i] -= ux * m; Y[i] -= uy * m; }
          if (ids[j] !== depart) { X[j] += ux * m; Y[j] += uy * m; }
          bouge = true;
        }
      }
      regrouper();
      if (!bouge) break;
    }
  };
  regrouper();
  separer();

  // IMPASSES (decision de Fred du 09/11/2026 : a Montrouge, l'impasse du tribunal s'arrete au
  // nord de l'Hotel de Ville et ne croise jamais la rue de l'Hotel de Ville ni la place du Rail).
  // Regle generale : une impasse (vue au bout d'une seule rue) s'arrete AVANT la rue qu'elle
  // couperait. Quand le calcul la fait traverser une autre rue, cette rue est repoussee au-dela
  // du bout de l'impasse, de proche en proche ; la navigation n'est pas touchee.
  const degre = {}; ids.forEach(id => { degre[id] = 0; });
  rues.forEach(r => { if (!r.fusion) { degre[r.de]++; degre[r.vers]++; } });
  const coupe = (p1, p2, p3, p4) => {
    const d = (p2[0] - p1[0]) * (p4[1] - p3[1]) - (p2[1] - p1[1]) * (p4[0] - p3[0]);
    if (Math.abs(d) < 1e-9) return false;
    const t = ((p3[0] - p1[0]) * (p4[1] - p3[1]) - (p3[1] - p1[1]) * (p4[0] - p3[0])) / d;
    const u = ((p3[0] - p1[0]) * (p2[1] - p1[1]) - (p3[1] - p1[1]) * (p2[0] - p1[0])) / d;
    return t > 0.001 && t < 0.999 && u > 0.001 && u < 0.999;
  };
  const distSeg = (p, a, b) => {
    const vx = b[0] - a[0], vy = b[1] - a[1], l2 = vx * vx + vy * vy;
    const t = l2 ? Math.max(0, Math.min(1, ((p[0] - a[0]) * vx + (p[1] - a[1]) * vy) / l2)) : 0;
    return Math.hypot(p[0] - a[0] - t * vx, p[1] - a[1] - t * vy);
  };
  const pt = id => [X[index[id]], Y[index[id]]];
  const impasses = rues.filter(r => !r.fusion && (degre[r.de] === 1 || degre[r.vers] === 1))
    .map(r => (degre[r.vers] === 1 ? [r.de, r.vers] : [r.vers, r.de]))
    .filter(([p, bout]) => bout !== depart && degre[p] > 1);
  // D'abord raccourcir l'impasse qui coupe une rue (une impasse est courte), puis repousser.
  for (const [p, bout] of impasses) {
    const P = pt(p), B = pt(bout), l = Math.hypot(B[0] - P[0], B[1] - P[1]);
    const croise = rues.some(r => !r.fusion && ![r.de, r.vers].some(x => x === p || x === bout)
      && coupe(P, B, pt(r.de), pt(r.vers)));
    if (croise && l > 0.85) {
      const k = index[bout], f = 0.85 / l;
      X[k] = P[0] + (B[0] - P[0]) * f; Y[k] = P[1] + (B[1] - P[1]) * f;
    }
  }
  for (let tour = 0; tour < 150 && impasses.length; tour++) {
    let bouge = false;
    for (const [p, bout] of impasses) {
      const P = pt(p), B = pt(bout);
      const l = Math.hypot(B[0] - P[0], B[1] - P[1]) || 1, ux = (B[0] - P[0]) / l, uy = (B[1] - P[1]) / l;
      for (const r of rues) {
        if (r.fusion || [r.de, r.vers].some(x => x === p || x === bout || groupe[x] === groupe[p])) continue;
        const R1 = pt(r.de), R2 = pt(r.vers);
        if (coupe(P, B, R1, R2) || distSeg(B, R1, R2) < 0.4) {
          for (const x of [r.de, r.vers]) {
            if (x === depart) continue;
            // Tout le groupe du carrefour bouge ensemble.
            ids.forEach((y, k) => { if (groupe[y] === groupe[x]) { X[k] += ux * 0.06; Y[k] += uy * 0.06; } });
          }
          bouge = true;
        }
      }
    }
    if (!bouge) break;
  }
  separer();
  ids.forEach(id => { cx[id] = X[index[id]]; cy[id] = Y[index[id]]; });
  const anoUniques = anomalies;

  // 4) BATIMENTS : rangés devant la vue qui les montre, du cote ou ils apparaissent.
  const batiments = [], places = new Set();
  for (const id of ids) {
    const n = noeuds[id];
    const zones = (n.zones || []).filter(z => z && z.buildingId);
    const lateral = !(n.liens && (n.liens.toutDroit || n.liens.arriere));
    zones.forEach(z => {
      if (places.has(z.buildingId)) return;
      places.add(z.buildingId);
      const [x0, x1] = Array.isArray(z.xPct) ? z.xPct : [40, 60];
      const milieu = (x0 + x1) / 2;
      let cote, ordre = milieu / 100;
      if (lateral) cote = 0; // vue de face : le batiment est devant, le long de la rue
      else if (milieu < 40) cote = 3; // a gauche de la rue
      else if (milieu > 60) cote = 1; // a droite
      else cote = 0; // au bout de la rue
      batiments.push({ id: z.buildingId, nom: z.nom || z.buildingId, noeud: id, cote: (regard[id] + cote) % 4, coteRelatif: cote, ordre, lateral });
    });
  }

  const sortie = {};
  ids.forEach(id => { sortie[id] = { x: cx[id], y: cy[id], regard: regard[id], suppose: suppose.has(id) }; });
  return { noeuds: sortie, rues, batiments, anomalies: anoUniques, fusions };
}

// =====================================================================
// DESSIN DU PLAN (SVG en texte, charte bleu-gris de style.css)
// =====================================================================
// Les batiments sont des reperes numerotes, la legende donne les noms : sur un plan de ville
// on ne peut pas ecrire trente noms dans les rues sans qu'ils se chevauchent, surtout sur
// telephone. Le survol d'un repere affiche aussi son nom (balise title).
function planRuesEchapper(t) {
  return String(t).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

function dessinerPlanRues(plan, options) {
  const opts = options || {};
  const U = opts.echelle || 110, MARGE = 60, R = 11;
  const ids = Object.keys(plan.noeuds);
  if (!ids.length) return { svg: '', legende: [], largeur: 0, hauteur: 0 };
  const xs = ids.map(i => plan.noeuds[i].x), ys = ids.map(i => plan.noeuds[i].y);
  const minX = Math.min(...xs), minY = Math.min(...ys);
  const P = id => [MARGE + (plan.noeuds[id].x - minX) * U, MARGE + (plan.noeuds[id].y - minY) * U];

  // Reperes des batiments : devant la vue, du cote ou l'image les montre.
  const parNoeudCote = {};
  plan.batiments.forEach(b => { const k = b.noeud + '|' + b.cote; (parNoeudCote[k] = parNoeudCote[k] || []).push(b); });
  const reperes = [];
  Object.values(parNoeudCote).forEach(groupe => {
    groupe.sort((a, b) => a.ordre - b.ordre);
    groupe.forEach((b, k) => {
      const [px, py] = P(b.noeud);
      const [sx, sy] = PLAN_RUES_PAS[b.cote];
      // Le long de la rue : la droite de l'image, vue depuis ce cote.
      const [lx, ly] = PLAN_RUES_PAS[(b.cote + 1) % 4];
      const etal = (k - (groupe.length - 1) / 2) * 2.3 * R;
      reperes.push({ b, x: px + sx * 0.36 * U + lx * etal, y: py + sy * 0.36 * U + ly * etal });
    });
  });
  // Ecarter les reperes qui se touchent, et ceux qui tombent sur une vue.
  const vues = ids.map(P);
  for (let tour = 0; tour < 120; tour++) {
    let bouge = false;
    for (let i = 0; i < reperes.length; i++) {
      for (let j = i + 1; j < reperes.length; j++) {
        const a = reperes[i], c = reperes[j], dx = c.x - a.x, dy = c.y - a.y, d = Math.hypot(dx, dy), min = 2.2 * R;
        if (d < min) { const ux = d ? dx / d : 1, uy = d ? dy / d : 0, m = (min - d) / 2; a.x -= ux * m; a.y -= uy * m; c.x += ux * m; c.y += uy * m; bouge = true; }
      }
      for (const [vx, vy] of vues) {
        const a = reperes[i], dx = a.x - vx, dy = a.y - vy, d = Math.hypot(dx, dy), min = 1.8 * R;
        if (d < min) { const ux = d ? dx / d : 0, uy = d ? dy / d : 1; a.x += ux * (min - d); a.y += uy * (min - d); bouge = true; }
      }
    }
    if (!bouge) break;
  }
  // Numerotation de lecture : de haut en bas, puis de gauche a droite.
  reperes.sort((a, b) => (Math.round(a.y / 30) - Math.round(b.y / 30)) || (a.x - b.x));
  reperes.forEach((r, k) => { r.num = k + 1; });

  const tous = reperes.map(r => [r.x, r.y]).concat(vues);
  const maxX = Math.max(...tous.map(p => p[0])) + MARGE, maxY = Math.max(...tous.map(p => p[1])) + MARGE;
  const minPX = Math.min(0, ...tous.map(p => p[0] - MARGE)), minPY = Math.min(0, ...tous.map(p => p[1] - MARGE));
  const L = Math.round(maxX - minPX), H = Math.round(maxY - minPY);

  const o = [];
  o.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="${Math.round(minPX)} ${Math.round(minPY)} ${L} ${H}" width="100%" role="img" aria-label="${planRuesEchapper(opts.titre || 'Plan de la ville')}" style="display:block;max-height:${opts.hauteurMax || '70vh'}">`);
  o.push(`<rect x="${Math.round(minPX)}" y="${Math.round(minPY)}" width="${L}" height="${H}" rx="10" fill="#1b2531"/>`);
  const ligne = (r, attr) => { const [x1, y1] = P(r.de), [x2, y2] = P(r.vers); return `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" ${attr}/>`; };
  plan.rues.forEach(r => o.push(ligne(r, 'stroke="#0f151d" stroke-width="18" stroke-linecap="round"')));
  plan.rues.forEach(r => o.push(ligne(r, 'stroke="#3a4a5d" stroke-width="13" stroke-linecap="round"')));
  plan.rues.forEach(r => o.push(ligne(r, 'stroke="#6f8399" stroke-width="1" stroke-dasharray="5 6"')));
  vues.forEach(([x, y]) => o.push(`<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="4" fill="#8ea3ba"/>`));
  reperes.forEach(r => {
    const [vx, vy] = P(r.b.noeud);
    o.push(`<line x1="${vx.toFixed(1)}" y1="${vy.toFixed(1)}" x2="${r.x.toFixed(1)}" y2="${r.y.toFixed(1)}" stroke="#a98d56" stroke-opacity="0.35" stroke-width="1"/>`);
  });
  reperes.forEach(r => {
    const ici = opts.batimentIci && r.b.id === opts.batimentIci;
    if (ici) o.push(`<circle cx="${r.x.toFixed(1)}" cy="${r.y.toFixed(1)}" r="16" fill="none" stroke="#e5c477" stroke-width="2"><animate attributeName="r" values="14;22;14" dur="2s" repeatCount="indefinite"/><animate attributeName="stroke-opacity" values="1;0.2;1" dur="2s" repeatCount="indefinite"/></circle>`);
    o.push(`<g class="plan-rues-repere" data-batiment="${planRuesEchapper(r.b.id)}"><title>${planRuesEchapper(r.b.nom)}${ici ? ' — vous êtes ici' : ''}</title>` +
      `<rect x="${(r.x - R).toFixed(1)}" y="${(r.y - R).toFixed(1)}" width="${2 * R}" height="${2 * R}" rx="4" fill="${ici ? '#e5c477' : '#202a36'}" stroke="#a98d56" stroke-width="1.5"/>` +
      `<text x="${r.x.toFixed(1)}" y="${(r.y + 4).toFixed(1)}" text-anchor="middle" font-size="11" font-family="sans-serif" font-weight="bold" fill="${ici ? '#202a36' : '#e5c477'}">${r.num}</text></g>`);
  });
  if (opts.ici && plan.noeuds[opts.ici]) {
    const [x, y] = P(opts.ici);
    o.push(`<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="13" fill="none" stroke="#e5c477" stroke-width="2"><animate attributeName="r" values="9;18;9" dur="2s" repeatCount="indefinite"/><animate attributeName="stroke-opacity" values="1;0.2;1" dur="2s" repeatCount="indefinite"/></circle>`);
    o.push(`<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="7" fill="#e5c477" stroke="#202a36" stroke-width="2"><title>Vous êtes ici</title></circle>`);
  }
  // Rose des vents discrete.
  o.push(`<g transform="translate(${Math.round(minPX + L - 28)},${Math.round(minPY + 30)})" fill="#8ea3ba" font-family="sans-serif" font-size="10" text-anchor="middle"><path d="M0,-14 L5,2 L0,-2 L-5,2 Z" fill="#a98d56"/><text y="14">N</text></g>`);
  o.push('</svg>');
  return {
    svg: o.join(''),
    legende: reperes.map(r => ({ num: r.num, id: r.b.id, nom: r.b.nom, noeud: r.b.noeud })),
    largeur: L, hauteur: H
  };
}

// =====================================================================
// RACCORDEMENT AU JEU : fenetre « Plan de la ville »
// =====================================================================
// Rend true si la ville a des rues et que son plan a ete dessine ; false sinon (l'appelant garde
// alors l'ancien plan). Lecture seule : le plan oriente, il ne deplace pas (choix de Fred).
function ouvrirPlanRuesVille(countryId, cityId) {
  if (typeof RUE_CENTRALE_NOEUDS === 'undefined' || typeof RUE_CENTRALE_DEPART === 'undefined') return false;
  const depart = RUE_CENTRALE_DEPART[countryId]?.[cityId];
  const noeuds = RUE_CENTRALE_NOEUDS[countryId];
  if (!depart || !noeuds || !noeuds[depart]) return false;
  const plan = calculerPlanRues(noeuds, depart);
  if (Object.keys(plan.noeuds).length < 2) return false;
  const st = (typeof state !== 'undefined') ? state : {};
  const memeVille = st.country === countryId && st.currentCity === cityId;
  const batimentIci = memeVille && st.currentBuilding ? st.currentBuilding : null;
  const noeudIci = memeVille && !batimentIci && typeof rueCentraleNoeudActuel !== 'undefined' && plan.noeuds[rueCentraleNoeudActuel] ? rueCentraleNoeudActuel : null;
  const co = (typeof COUNTRIES !== 'undefined') ? COUNTRIES[countryId] : null;
  const city = (typeof WORLD !== 'undefined') ? WORLD[countryId]?.[cityId] : null;
  const nomVille = city?.name || cityId;
  const dessin = dessinerPlanRues(plan, { ici: noeudIci, batimentIci, titre: 'Plan de ' + nomVille });
  const ligne = l => {
    const ici = batimentIci && l.id === batimentIci;
    return `<li style="display:flex;gap:.45rem;align-items:center;padding:.18rem 0;${ici ? 'color:#e5c477;font-weight:bold' : ''}">` +
      `<span style="flex:0 0 auto;min-width:1.6rem;text-align:center;border:1px solid #a98d56;border-radius:4px;font-size:.7rem;color:#e5c477;background:${ici ? '#3a3220' : '#202a36'}">${l.num}</span>` +
      `<span style="font-size:.78rem">${planRuesEchapper(l.nom)}${ici ? ' — vous êtes ici' : ''}</span></li>`;
  };
  const enRue = noeudIci ? '<span style="color:#e5c477">●</span> Vous êtes ici, dans la rue.' : (batimentIci ? '' : '');
  document.getElementById('minimap-ville-title').textContent = nomVille + (co?.n ? ' — ' + co.n : '');
  document.getElementById('minimap-ville-body').innerHTML =
    '<div style="padding:.3rem">' + dessin.svg + '</div>' +
    (enRue ? '<div style="font-size:.75rem;color:#e2e9f1;padding:.2rem .6rem">' + enRue + '</div>' : '') +
    '<ul style="list-style:none;margin:.3rem 0 0;padding:.2rem .6rem .6rem;display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));column-gap:.8rem;color:#e2e9f1">' +
    dessin.legende.map(ligne).join('') + '</ul>';
  document.getElementById('modal-minimap-ville').classList.add('open');
  return true;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { calculerPlanRues, dessinerPlanRues, planRuesComposante, PLAN_RUES_BOUSSOLE };
}
