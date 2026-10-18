"""Prepare a verified MP-test package and existing-item VDF; never log in or upload."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import zipfile
from check_versions import check

ROOT = Path(__file__).resolve().parents[1]
NOTICE = "MP testing build - dedicated multiplayer NOT TESTED"


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_hash(files):
    return hashlib.sha256("".join(k + "\0" + v + "\n" for k, v in sorted(files.items())).encode()).hexdigest()


def escaped(value):
    return value.replace("\\", "\\\\").replace('"', '\\"')


def safe_file(path):
    assert not path.is_symlink() and not getattr(path, "is_junction", lambda: False)(), "Linked input prohibited"
    assert path.is_file(), "Expected regular file: " + str(path)


def prepare(args):
    check(ROOT)
    assert not git("status", "--porcelain=v1"), "Commit intended source before preparing an immutable package"
    commit = git("rev-parse", "HEAD")
    assert commit == git("rev-parse", "@{upstream}"), "Source must match its verified upstream"
    default = git("symbolic-ref", "refs/remotes/origin/HEAD")
    subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", default, commit], check=True)
    origin = git("remote", "get-url", "origin")
    assert origin == "https://github.com/B47ANCE/B47ANCEDWaterworks.git", "Unexpected source origin"
    subprocess.run([sys.executable, str(ROOT / "scripts/validate.py")], check=True)
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    inv = json.loads((ROOT / "version-inventory.json").read_text(encoding="utf-8"))
    assert inv["mod_id"] == "B47ANCEDWaterworks" and inv["workshop_id"] == "3788594390"
    source = ROOT / inv["source_root"]
    assert not source.is_symlink() and not getattr(source, "is_junction", lambda: False)()
    description = (ROOT / "WORKSHOP_DESCRIPTION.txt").read_text(encoding="utf-8").strip()
    note = (ROOT / "WORKSHOP_CHANGE_NOTE.txt").read_text(encoding="utf-8").strip()
    for text in [description, note]:
        assert NOTICE in text and "\n\n" in text and "\\n" not in text
        assert not re.search(r"\b(?:TODO|TBD)\b", text), "Unfinished publication prose"
    url = "https://github.com/B47ANCE/B47ANCEDWaterworks"
    assert "[url=" + url + "]" in description and note.startswith("[b]Version " + version + "[/b]")
    # Valve's current ISteamRemoteStorage constants: description 8000 bytes, title 128 plus terminator.
    # https://partner.steamgames.com/doc/api/ISteamRemoteStorage#k_cchPublishedDocumentDescriptionMax
    assert len(description.encode("utf-8")) < 8000, "Workshop description exceeds the documented byte limit"
    info = dict(line.split("=", 1) for line in (source / "42/mod.info").read_text(encoding="utf-8").splitlines() if "=" in line)
    assert info["id"] == inv["mod_id"] and info["modversion"] == version
    assert len(info["name"].encode("utf-8")) <= 128
    metadata = (ROOT / "workshop.txt").read_text(encoding="utf-8")
    assert "\nid=" + inv["workshop_id"] + "\n" in metadata
    steam_build = "UNKNOWN"
    if args.game_manifest:
        raw = args.game_manifest.read_text(encoding="utf-8-sig")
        assert re.search(r'"appid"\s+"108600"', raw)
        matched = re.search(r'"buildid"\s+"(\d+)"', raw)
        assert matched, "Installed Steam build unavailable"
        steam_build = matched[1]
    requested = args.output_root.absolute()
    for parent in (requested, *requested.parents):
        assert not parent.is_symlink() and not getattr(parent, "is_junction", lambda: False)(), "Linked authoring path prohibited"
    base = requested.resolve(strict=True)
    assert not base.is_relative_to(ROOT), "Keep authoring artifacts outside source and historical dist"
    assert not base.is_symlink() and not getattr(base, "is_junction", lambda: False)()
    output = base / ("B47ANCEDWaterworks-" + version + "-" + commit[:12])
    assert not output.exists(), "Existing output is preserved; inspect it rather than overwriting"
    # Inventory every native payload path before creating any output.
    inputs = []
    excluded = {}
    seen = set()
    for file in sorted(source.rglob("*")):
        assert not file.is_symlink() and not getattr(file, "is_junction", lambda: False)(), "Linked payload prohibited"
        if not file.is_file():
            continue
        rel = file.relative_to(ROOT).as_posix()
        if rel == inv["source_root"] + "/42/media/lua/shared/.keep":
            assert file.read_bytes() in (b"", b"\n", b"\r\n"), "Only the declared empty directory marker is excluded"
            excluded[rel] = sha(file)
            continue
        parts = PurePosixPath(rel).parts
        assert not any(part.startswith(".") or ":" in part for part in parts)
        assert file.suffix.lower() in {".lua", ".txt", ".json", ".png", ".info"}, "Unexpected runtime payload"
        assert rel.casefold() not in seen, "Case collision"
        seen.add(rel.casefold())
        inputs.append((rel, file))
    assert 0 < len(inputs) <= 10000
    for rel in ["preview.png", "workshop.txt", "VERSION", "WORKSHOP_CHANGE_NOTE.txt"]:
        safe_file(ROOT / rel)
        inputs.append((rel, ROOT / rel))
    source_hashes = {rel: sha(file) for rel, file in inputs}
    output.mkdir()
    stage = output / "stage"
    for rel, file in inputs:
        target = stage / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(file, target)
        assert sha(target) == source_hashes[rel], "Staging byte mismatch"
    actual = {p.relative_to(stage).as_posix(): sha(p) for p in stage.rglob("*") if p.is_file()}
    assert actual == source_hashes, "Stage inventory differs from approved source"
    package = output / ("B47ANCEDWaterworks-" + version + "-mp-testing.zip")
    with zipfile.ZipFile(package, "w") as archive:
        for rel in sorted(actual):
            entry = zipfile.ZipInfo(rel, date_time=(1980, 1, 1, 0, 0, 0))
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, (stage / rel).read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    with zipfile.ZipFile(package) as archive:
        names = archive.namelist()
        assert len(names) == len(set(names)) == len({n.casefold() for n in names})
        for name in names:
            path = PurePosixPath(name)
            assert not path.is_absolute() and ".." not in path.parts and "\\" not in name and ":" not in name
        assert archive.testzip() is None, "ZIP CRC/data validation failed"
        assert {n: hashlib.sha256(archive.read(n)).hexdigest() for n in names} == actual
    fields = dict(appid="108600", publishedfileid=inv["workshop_id"],
                  contentfolder=str(stage / "Contents"), previewfile=str(stage / "preview.png"),
                  title=info["name"], description=description, changenote=note)
    vdf = output / "workshop.vdf"
    text = '"workshopitem"\n{\n' + "".join('    "' + k + '" "' + escaped(v) + '"\n' for k, v in fields.items()) + '}\n'
    vdf.write_text(text, encoding="utf-8-sig", newline="\n")
    pairs = re.findall(r'"([^"\\]+)"\s+"((?:\\.|[^"\\])*)"', vdf.read_text(encoding="utf-8-sig"), re.S)
    decoded = {k: v.replace('\\"', '"').replace("\\\\", "\\") for k, v in pairs}
    assert decoded == fields and "visibility" not in decoded and "tags" not in decoded
    assert all(sha(ROOT / rel) == digest for rel, digest in source_hashes.items()), "Source changed during preparation"
    assert commit == git("rev-parse", "HEAD") and not git("status", "--porcelain=v1")
    manifest = dict(schema=1, distribution="MP testing build", upload="NOT ATTEMPTED - prepare only",
                    version=version, commit=commit, github=url, mod_id=inv["mod_id"], workshop_id=inv["workshop_id"], app_id="108600",
                    target_game=dict(minimum=info["versionMin"], installed_steam_build=steam_build, full_installed_version="UNKNOWN"),
                    package=package.name, package_sha256=sha(package), vdf=vdf.name, vdf_sha256=sha(vdf),
                    stage="stage", source_tree_hash_algorithm="SHA256(sorted(relative path + NUL + hex file SHA256 + LF))",
                    source_tree_sha256=tree_hash(source_hashes), files=source_hashes, excluded_directory_markers=excluded,
                    validation=dict(source_validation="PASS - offline; standalone Lua suite", stage_zip_inventory_crc_hashes="PASS",
                                    power_integration="Separate prerequisite; see current task/PR evidence", sp="NOT TESTED", dedicated="NOT TESTED", G7="BLOCKED / NOT TESTED", stable_G8="BLOCKED"),
                    preview="Original user PNG; native rendering and uploader acceptance NOT TESTED", remote_visibility="PRESERVED - VDF omits visibility")
    (output / "release-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("PREPARED ONLY: " + str(output))
    print("Package SHA256: " + manifest["package_sha256"])
    print("PASS exact source/stage/ZIP inventory, CRC/data, hashes, versions, IDs and VDF round-trip")
    print("No authentication, upload, deletion, deployment or Steam restart performed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mp-testing", action="store_true", required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--game-manifest", type=Path)
    prepare(parser.parse_args())
