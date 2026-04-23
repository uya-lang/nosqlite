#!/usr/bin/env python3
import argparse
import json
import random
import statistics
import sys


FIRST_NAMES = [
    "ann", "bob", "cara", "dina", "erin", "faye", "gail", "hank",
    "iris", "jude", "kira", "liam", "mona", "nora", "owen", "piper",
]

LAST_NAMES = [
    "smith", "brown", "lee", "wang", "garcia", "martin", "walker", "young",
]

CITIES = [
    "shanghai", "beijing", "shenzhen", "hangzhou", "suzhou", "chengdu",
    "singapore", "tokyo", "seattle", "austin", "berlin", "paris",
]

TAGS = [
    "new", "trial", "vip", "ops", "sales", "finance", "edge", "mobile",
    "warm", "cold", "batch", "sync", "async", "blue", "green", "gold",
]


def build_doc(doc_id: int, rng: random.Random, target_bytes: int) -> str:
    first = FIRST_NAMES[doc_id % len(FIRST_NAMES)]
    last = LAST_NAMES[(doc_id // 3) % len(LAST_NAMES)]
    city = CITIES[(doc_id // 7) % len(CITIES)]
    tag0 = TAGS[doc_id % len(TAGS)]
    tag1 = TAGS[(doc_id + 5) % len(TAGS)]
    tag2 = TAGS[(doc_id + 11) % len(TAGS)]

    base = {
        "_id": doc_id,
        "name": f"{first}-{last}-{doc_id}",
        "age": 18 + (doc_id % 57),
        "score": f"{(doc_id % 1000) / 10:.1f}",
        "active": (doc_id % 3) != 0,
        "address": {
            "city": city,
            "zip": 100000 + (doc_id % 900000),
            "street": f"lane-{doc_id % 1024}",
        },
        "tags": [tag0, tag1, tag2],
        "profile": {
            "tenant": f"tenant-{doc_id % 128}",
            "segment": f"seg-{doc_id % 16}",
            "revision": doc_id % 32,
        },
        "bio": "",
    }

    encoded = json.dumps(base, separators=(",", ":"), ensure_ascii=False)
    pad_len = max(0, target_bytes - len(encoded))
    noise = "".join(rng.choice("abcdefghijklmnopqrstuvwxyz0123456789") for _ in range(pad_len))
    base["bio"] = noise
    return json.dumps(base, separators=(",", ":"), ensure_ascii=False)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate the canonical NoSQLite benchmark JSONL dataset.")
    parser.add_argument("--docs", type=int, default=100_000, help="document count (default: 100000)")
    parser.add_argument("--avg-bytes", type=int, default=1024, help="target average JSON bytes per document (default: 1024)")
    parser.add_argument("--seed", type=int, default=11, help="deterministic RNG seed")
    parser.add_argument("--output", type=str, default="-", help="output path, or - for stdout")
    args = parser.parse_args()

    if args.docs <= 0:
        print("docs must be positive", file=sys.stderr)
        return 2
    if args.avg_bytes < 256:
        print("avg-bytes must be at least 256", file=sys.stderr)
        return 2

    rng = random.Random(args.seed)
    out = sys.stdout if args.output == "-" else open(args.output, "w", encoding="utf-8")
    lengths = []
    try:
        for doc_id in range(1, args.docs + 1):
            line = build_doc(doc_id, rng, args.avg_bytes)
            lengths.append(len(line))
            out.write(line)
            out.write("\n")
    finally:
        if out is not sys.stdout:
            out.close()

    summary = {
        "docs": args.docs,
        "seed": args.seed,
        "avg_bytes": round(statistics.mean(lengths), 2),
        "min_bytes": min(lengths),
        "max_bytes": max(lengths),
    }
    print(json.dumps(summary, separators=(",", ":")), file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
