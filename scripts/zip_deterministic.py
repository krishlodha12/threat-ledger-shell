"""Zip Payload/ into an .ipa that is byte-identical for identical inputs.

Fixed entry order, fixed timestamps (SOURCE_DATE_EPOCH), fixed permissions.
Usage: python3 zip_deterministic.py <stage-dir containing Payload/> <out.ipa>
"""
import os
import sys
import time
import zipfile


def main(stage: str, out: str) -> None:
    epoch = max(int(os.environ.get("SOURCE_DATE_EPOCH", "315532800")), 315532800)
    stamp = time.gmtime(epoch)[:6]

    entries = []
    for dirpath, dirnames, filenames in os.walk(os.path.join(stage, "Payload")):
        rel = os.path.relpath(dirpath, stage).replace(os.sep, "/")
        entries.append((rel + "/", None))
        entries += [(f"{rel}/{f}", os.path.join(dirpath, f)) for f in filenames]
    entries.sort()

    if os.path.exists(out):
        os.remove(out)
    with zipfile.ZipFile(out, "w") as z:
        for name, path in entries:
            info = zipfile.ZipInfo(name, stamp)
            info.create_system = 3  # unix, so permissions below are honoured
            if path is None:
                info.external_attr = (0o040755 << 16) | 0x10
                z.writestr(info, b"")
                continue
            mode = 0o755 if os.access(path, os.X_OK) else 0o644
            info.external_attr = (0o100000 | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(path, "rb") as fh:
                z.writestr(info, fh.read(), compresslevel=9)
    print(f"wrote {out} ({len(entries)} entries)")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
