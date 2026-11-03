// Fonction Edge PONCTUELLE (04/11/2026, Claude) — #55 / #60 consommation Supabase.
// Recompresse les portraits stockés en base64 : personnages_donnees.photo_url et les copies
// recopiées dans journal_editions.faits_sources. Chaque image > 60 000 caractères est réduite
// à 320 px de côté maximum, en JPEG qualité 80, sur fond blanc. Une image déjà réduite n'est
// jamais décodée deux fois (table portraits_recompression, par empreinte SHA-256).
// Un appel travaille environ 1 s puis rend la main ; la page se recharge seule jusqu'à
// « Terminé ». Protégée par une clé, à supprimer une fois l'opération faite.
import { createClient } from "npm:@supabase/supabase-js@2";
import jpeg from "npm:jpeg-js@0.4.4";
import { PNG } from "npm:pngjs@7.0.0";
import { Buffer } from "node:buffer";

const CLE = "9D0z9f3_rGvoC0SV1kd0SHcQ";
const SEUIL = 60000;
const COTE = 320;
const BUDGET_MS = 1000;

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

async function empreinte(s: string): Promise<string> {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(h)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function b64VersOctets(b64: string): Uint8Array {
  const bin = atob(b64);
  const o = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) o[i] = bin.charCodeAt(i);
  return o;
}
function octetsVersB64(o: Uint8Array): string {
  let s = "";
  for (let i = 0; i < o.length; i += 0x8000) s += String.fromCharCode(...o.subarray(i, i + 0x8000));
  return btoa(s);
}

// Rend l'image réduite, ou null si l'image ne peut pas être décodée (elle est alors laissée).
async function reduire(dataUrl: string): Promise<string | null> {
  const cle = await empreinte(dataUrl);
  const { data: deja } = await sb.from("portraits_recompression").select("nouveau").eq("empreinte", cle).maybeSingle();
  if (deja) return deja.nouveau;
  const virgule = dataUrl.indexOf(",");
  if (virgule < 0) return null;
  // PNG et JPEG seulement, decodeurs 100 % JavaScript (aucun module telecharge a la volee).
  const octets = Buffer.from(b64VersOctets(dataUrl.slice(virgule + 1)));
  let src: { width: number; height: number; data: Uint8Array };
  try {
    if (/^data:image\/png;/i.test(dataUrl)) src = PNG.sync.read(octets);
    else if (/^data:image\/jpe?g;/i.test(dataUrl)) src = jpeg.decode(octets, { useTArray: true, maxMemoryUsageInMB: 1024 });
    else return null;
  } catch (_) { return null; }
  // Reduction par moyenne de blocs, sur fond blanc (la transparence devient blanche).
  const echelle = Math.min(1, COTE / Math.max(src.width, src.height));
  const l = Math.max(1, Math.round(src.width * echelle)), h = Math.max(1, Math.round(src.height * echelle));
  const out = new Uint8Array(l * h * 4);
  for (let y = 0; y < h; y++) {
    const y0 = Math.floor(y * src.height / h), y1 = Math.max(y0 + 1, Math.floor((y + 1) * src.height / h));
    for (let x = 0; x < l; x++) {
      const x0 = Math.floor(x * src.width / l), x1 = Math.max(x0 + 1, Math.floor((x + 1) * src.width / l));
      let r = 0, g = 0, b = 0, n = 0;
      for (let yy = y0; yy < y1; yy++) for (let xx = x0; xx < x1; xx++) {
        const k = (yy * src.width + xx) * 4, a = src.data[k + 3] / 255;
        r += src.data[k] * a + 255 * (1 - a); g += src.data[k + 1] * a + 255 * (1 - a); b += src.data[k + 2] * a + 255 * (1 - a); n++;
      }
      const o = (y * l + x) * 4;
      out[o] = r / n; out[o + 1] = g / n; out[o + 2] = b / n; out[o + 3] = 255;
    }
  }
  const jpg = jpeg.encode({ data: out, width: l, height: h }, 80).data as Uint8Array;
  const nouveau = "data:image/jpeg;base64," + octetsVersB64(new Uint8Array(jpg));
  if (nouveau.length >= dataUrl.length) return null;
  await sb.from("portraits_recompression").upsert({
    empreinte: cle, nouveau, ancien_ko: Math.round(dataUrl.length / 1024), nouveau_ko: Math.round(nouveau.length / 1024),
  });
  return nouveau;
}

// Remplace dans un JSON toutes les data URL d'image trop lourdes.
async function nettoyer(v: any, fin: number): Promise<{ v: any; change: boolean; complet: boolean }> {
  if (typeof v === "string") {
    if (v.startsWith("data:image") && v.length > SEUIL) {
      if (performance.now() > fin) return { v, change: false, complet: false };
      const r = await reduire(v);
      return r ? { v: r, change: true, complet: true } : { v, change: false, complet: true };
    }
    return { v, change: false, complet: true };
  }
  if (Array.isArray(v) || (v && typeof v === "object")) {
    let change = false, complet = true;
    const out: any = Array.isArray(v) ? [] : {};
    for (const [k, x] of Object.entries(v)) {
      const r = await nettoyer(x, fin);
      out[k] = r.v; change ||= r.change; complet &&= r.complet;
    }
    return { v: out, change, complet };
  }
  return { v, change: false, complet: true };
}

// Supabase sert les reponses des fonctions en texte brut : page lisible sans HTML.
function page(titre: string, lignes: string[], recharger: boolean): Response {
  const suite = recharger ? "\n\n>>> Recharge la page (Cmd + R) pour continuer." : "";
  return new Response(`${titre}\n\n${lignes.map((l) => "- " + l).join("\n")}${suite}\n`,
    { headers: { "Content-Type": "text/plain; charset=utf-8" } });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  if (url.searchParams.get("cle") !== CLE) return new Response("Accès refusé", { status: 403 });
  const fin = performance.now() + BUDGET_MS;
  const journal: string[] = [];

  // 1. Portraits des fiches, un par un.
  const { data: fiches, error: e1 } = await sb.rpc("portraits_lourds_lister");
  if (e1) return page("Erreur", [e1.message], false);
  for (const f of fiches || []) {
    if (performance.now() > fin) return page("En cours…", [...journal, "Travail en cours."], true);
    const { data: ligne } = await sb.from("personnages_donnees").select("photo_url").eq("id", f.id).single();
    const ancien = ligne?.photo_url as string;
    const r = await reduire(ancien);
    if (r) {
      const { error } = await sb.from("personnages_donnees").update({ photo_url: r }).eq("id", f.id);
      journal.push(error ? `Fiche ${f.name} : erreur ${error.message}` : `Fiche ${f.name} : ${Math.round(ancien.length / 1024)} Ko → ${Math.round(r.length / 1024)} Ko`);
      if (error) return page("Erreur", journal, false);
    } else {
      await sb.rpc("portraits_lourds_ignorer", { p_id: f.id });
      journal.push(`Fiche ${f.name} : image non décodable, laissée telle quelle`);
    }
  }

  // 2. Éditions du journal, une par une.
  const { data: editions, error: e2 } = await sb.rpc("editions_portraits_lourds_lister");
  if (e2) return page("Erreur", [...journal, e2.message], false);
  for (const ed of editions || []) {
    if (performance.now() > fin) return page("En cours…", [...journal, "Travail en cours."], true);
    const { data: ligne } = await sb.from("journal_editions").select("faits_sources").eq("id", ed.id).single();
    const r = await nettoyer(ligne?.faits_sources, fin);
    if (r.change) {
      const { error } = await sb.from("journal_editions").update({ faits_sources: r.v }).eq("id", ed.id);
      if (error) return page("Erreur", [...journal, `Édition ${ed.id} : ${error.message}`], false);
      journal.push(`Édition ${ed.id} allégée`);
    }
    if (!r.complet) return page("En cours…", [...journal, "Travail en cours."], true);
    await sb.rpc("editions_portraits_lourds_ignorer", { p_id: ed.id }); // édition traitée
  }
  return page("Terminé", [...journal, "Tous les portraits sont réduits. Tu peux fermer cette page."], false);
});
