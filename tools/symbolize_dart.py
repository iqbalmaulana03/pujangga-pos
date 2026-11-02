"""Decode release Dart traces, including unified snapshots from Dart 3.13.

Flutter 3.47.9's decoder still expects the older separate isolate/VM exports.
Unified traces already include ELF virtual PCs. Omit the obsolete load-address
headers so the decoder uses those PCs with the matching .symbols file.
"""

import argparse
from pathlib import Path
import re
import subprocess
import tempfile


def normalize_trace(trace):
    if "_kDartSnapshotText+" not in trace:
        return trace
    frames = [line for line in trace.splitlines() if "_kDartSnapshotText+" in line]
    if not all(re.search(r"\bvirt\s+[0-9a-fA-F]+\b", line) for line in frames):
        raise ValueError("Unified snapshot frames must include virtual addresses")
    if any(re.search(r"\bunit\s+[1-9]\d*\b", line) for line in frames):
        raise ValueError("Deferred loading units require their own matching symbols")
    return "\n".join(
        line for line in trace.splitlines()
        if "isolate_instructions:" not in line and "isolate_dso_base:" not in line
    ) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--symbols", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--flutter", default="flutter")
    args = parser.parse_args()
    try:
        normalized = normalize_trace(args.input.read_text(encoding="utf-8"))
    except ValueError as error:
        parser.error(str(error))
    with tempfile.TemporaryDirectory(prefix="pujangga-symbolize-") as temporary:
        trace = Path(temporary) / "trace.txt"
        trace.write_text(normalized, encoding="utf-8")
        result = subprocess.run(
            [args.flutter, "symbolize", "-i", str(trace), "-d", str(args.symbols)],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
    if result.returncode:
        raise SystemExit("Symbolization failed; verify SDK, ABI and matching build symbols.")
    args.output.write_text(result.stdout, encoding="utf-8")
    print(f"Decoded trace written to {args.output}")


if __name__ == "__main__":
    main()
