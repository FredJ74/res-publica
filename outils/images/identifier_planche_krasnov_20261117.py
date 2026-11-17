from pathlib import Path
from PIL import Image, ImageOps
p=Path("images/Sovarka/Krasnov")
out=Path("outils/images/.krasnov-audit")
out.mkdir(parents=True,exist_ok=True)
files=sorted(list(p.glob("Galerie des personnages de Krasnov*.png"))+list(p.glob("Grille de portraits du village*.png")))
assert len(files)==2, [str(f) for f in files]
for i,f in enumerate(files):
    with Image.open(f) as im:
        im.load()
        w,h=im.size
        print(f"PORTRAIT_SOURCE_{i}: filename={f.name!r} dimensions={w}x{h} ratio={w/h:.4f}")
        preview=im.convert("RGB")
        preview.thumbnail((650,1500),Image.Resampling.LANCZOS)
        target=out/f"apercu-{i}.webp"
        preview.save(target,"WEBP",quality=75,method=5)
        print(f"PREVIEW_{i}: {target} bytes={target.stat().st_size}")
