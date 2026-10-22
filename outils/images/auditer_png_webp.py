#!/usr/bin/env python3
"""Audit prudent des PNG servis par Human Gambit, conversion facultative en WebP.

Par défaut : lecture seule. Avec --apply : conversion des seuls chemins PNG
référencés littéralement dans les sources client; mise à jour des références et
suppression du PNG UNIQUEMENT si gain réel, après validation des occurrences.
Les fichiers sans référence littérale restent inchangés : ils peuvent être
désignés dynamiquement ou depuis Supabase.
"""
import argparse
import io
import json
import pathlib
import re
import subprocess
import sys
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCES = {".js", ".css", ".html", ".json", ".mjs", ".cjs"}
PREF = "images/"
def tracked():
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    return [pathlib.Path(x.decode()) for x in raw.split(b"\0") if x]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="Modifie les assets et références")
    ap.add_argument("--quality", type=int, default=88)
    ap.add_argument("--min-saving", type=float, default=0.15)
    ap.add_argument("--report", default="")
    a = ap.parse_args()
    files = tracked()
    sources = {}
    for p in files:
        if p.suffix.lower() in SOURCES and (p.parts[0] in {"images", "historique", "baseline", "outils", ".scratch"} or len(p.parts)>1 and p.parts[0] not in {"api","i18n"}):
            continue
        if p.suffix.lower() in SOURCES and (ROOT/p).is_file():
            try: sources[p] = (ROOT/p).read_text("utf-8")
            except (UnicodeDecodeError,OSError): pass
    pngs = [p for p in files if p.suffix.lower()==".png" and p.parts[0]=="images" and (ROOT/p).is_file()]
    report = []
    replacements = {}
    for p in pngs:
        old = p.as_posix()
        refs = [f.as_posix() for f,text in sources.items() if old in text]
        item = {"path":old,"refs":refs,"original_bytes":(ROOT/p).stat().st_size}
        if not refs:
            item["decision"]="conserver : aucune référence littérale, usage dynamique possible"
            report.append(item); continue
        target = p.with_suffix(".webp")
        if (ROOT/target).exists():
            item["decision"]="conserver : destination WebP déjà existante"
            report.append(item); continue
        try:
            with Image.open(ROOT/p) as im:
                im.load()
                if im.n_frames>1:
                    item["decision"]="conserver : PNG animé"; report.append(item); continue
                if im.mode not in ("RGB","RGBA"):
                    im=im.convert("RGBA" if "transparency" in im.info else "RGB")
                buf=io.BytesIO()
                im.save(buf, "WEBP", quality=a.quality, method=6)
                data=buf.getvalue()
        except Exception as e:
            item["decision"]="erreur de conversion : "+str(e)
            report.append(item); continue
        item["webp_bytes"]=len(data)
        item["saving_pct"]=round((1-len(data)/item["original_bytes"])*100,1)
        if len(data) >= item["original_bytes"]*(1-a.min_saving):
            item["decision"]="conserver : gain insuffisant"
            report.append(item); continue
        # Une référence explicite complète est substituée partout où elle figure.
        # Les éventuelles références par seul nom de fichier restent suspectes.
        basename_refs=[f.as_posix() for f,txt in sources.items() if p.name in txt and old not in txt]
        if basename_refs:
            item["decision"]="conserver : références par nom seul à examiner"
            item["ambiguous_refs"]=basename_refs
            report.append(item); continue
        if a.apply:
            (ROOT/target).write_bytes(data)
            (ROOT/p).unlink()
        for f in refs:
            replacements.setdefault(f,{})[old]=target.as_posix()
        item["decision"]="converti" if a.apply else "convertible"
        report.append(item)
    if a.apply:
        for name, mappings in replacements.items():
            f=ROOT/name
            content=f.read_text("utf-8")
            for old,new in mappings.items():
                content=content.replace(old,new)
            f.write_text(content,"utf-8")
    summary={"png_total":len(pngs),"candidats":sum(x["decision"] in {"convertible","converti"} for x in report),
             "octets_economisables":sum(x.get("original_bytes",0)-x.get("webp_bytes",0) for x in report if x["decision"] in {"convertible","converti"}),
             "mode":"apply" if a.apply else "audit","images":report}
    out=json.dumps(summary,ensure_ascii=False,indent=2)
    if a.report: (ROOT/a.report).write_text(out+"\n",encoding="utf-8")
    print(out)
if __name__=="__main__": main()
