"""Generate launcher PNGs, or check their dimensions and packaged size.

Checking uses only the Python standard library. Generation additionally needs
the Pillow version pinned in requirements-icons.txt.
"""

import argparse
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "tools/artwork/launcher-master.png"
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
MAX_BYTES = 250_000


def check():
    total = 0
    errors = []
    for density, size in SIZES.items():
        path = ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
        try:
            data = path.read_bytes()
            if data[:16] != b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR" or len(data) < 24:
                raise ValueError("invalid PNG header")
            actual = struct.unpack(">II", data[16:24])
            if actual != (size, size):
                errors.append(f"{density}: expected {size}x{size}, found {actual}")
            total += len(data)
            print(f"{density}: {actual[0]}x{actual[1]}, {len(data)} bytes")
        except (OSError, ValueError) as error:
            errors.append(f"{density}: {error}")
    if total > MAX_BYTES:
        errors.append(f"launcher PNGs total {total} bytes exceeds {MAX_BYTES}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"Launcher PNGs: {total} / {MAX_BYTES} bytes")


def generate():
    from PIL import Image

    with Image.open(MASTER) as source:
        if source.width != source.height:
            raise SystemExit("Master artwork must be square; do not crop the logo")
        artwork = source.convert("RGBA")
        for density, size in SIZES.items():
            output = ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
            artwork.resize((size, size), Image.Resampling.LANCZOS).save(
                output, format="PNG", optimize=True, compress_level=9
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generate", action="store_true")
    args = parser.parse_args()
    if args.generate:
        generate()
    check()
