"""Coloca uma ROM dentro do .ipa (como Game.gba) e, se quiser, muda o nome que aparece no iPhone.

uso: py -3 inject_rom.py ENTRADA.ipa ROM.gba SAIDA.ipa ["Nome no iPhone"]
"""
import plistlib
import sys
import zipfile

if len(sys.argv) < 4:
    sys.exit(__doc__)

src, rom, dst = sys.argv[1], sys.argv[2], sys.argv[3]
display_name = sys.argv[4] if len(sys.argv) > 4 else None

with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
    app_dir = None
    for item in zin.infolist():
        parts = item.filename.split("/")
        if len(parts) >= 2 and parts[0] == "Payload" and parts[1].endswith(".app"):
            app_dir = "/".join(parts[:2])
            break
    if app_dir is None:
        sys.exit("nao achei Payload/*.app no ipa")

    for item in zin.infolist():
        data = zin.read(item.filename)
        if display_name and item.filename == f"{app_dir}/Info.plist":
            info = plistlib.loads(data)
            info["CFBundleDisplayName"] = display_name
            data = plistlib.dumps(info, fmt=plistlib.FMT_BINARY)
        zout.writestr(item, data)

    with open(rom, "rb") as f:
        zout.writestr(f"{app_dir}/Game.gba", f.read())

print(f"ok: {dst} (ROM embutida em {app_dir}/Game.gba)")
