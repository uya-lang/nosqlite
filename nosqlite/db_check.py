#!/usr/bin/env python3
import argparse
import os
import re
import struct
import sys
import zlib


FORMAT_VERSION = 1
PAGE_SIZE_DEFAULT = 4096
PAGE_SIZE_MAX = 8192
META_SIZE = 68
WAL_HEADER_SIZE = 28
WAL_RECORD_HEADER_SIZE = 12
WAL_PAGE_WRITE_META_SIZE = 28
PAGE_HEADER_SIZE = 24
SLOT_SIZE = 6
CATALOG_ROOT_SIZE = 16
COLLECTION_META_SIZE = 32
RECORD_CELL_HEADER_SIZE = 28
ROWS_PER_COLLECTION_PAGE = 3

PAGE_TYPE_CATALOG = 1
PAGE_TYPE_DATA = 2

RECORD_BEGIN = 1
RECORD_PAGE_WRITE = 2
RECORD_COMMIT = 3
RECORD_CHECKPOINT = 4

DOC_TAG_NULL = 0
DOC_TAG_FALSE = 1
DOC_TAG_TRUE = 2
DOC_TAG_INT64 = 3
DOC_TAG_NUMBER_TEXT = 4
DOC_TAG_STRING = 5
DOC_TAG_ARRAY = 6
DOC_TAG_OBJECT = 7

DOC_NUMBER_DECIMAL = 0
DOC_NUMBER_EXPONENT = 1
DOC_NUMBER_BIGINT = 2

NODE_HEADER_SIZE = 8
INT64_NODE_SIZE = 16
NUMBER_TEXT_PREFIX_SIZE = 16
STRING_PREFIX_SIZE = 12
ARRAY_PREFIX_SIZE = 12
OBJECT_PREFIX_SIZE = 12
OBJECT_ENTRY_SIZE = 16
DOC_ALIGN = 8

OK = 0
IO_GENERIC = 1000
FORMAT_META_INVALID = 2001
FORMAT_WAL_HEADER_INVALID = 2002
FORMAT_PAGE_CHECKSUM_INVALID = 2003
FORMAT_PAGE_BOUNDS_INVALID = 2004
FORMAT_WAL_RECORD_INVALID = 2005
CATALOG_CORRUPT = 5001


ERRORS = {
    OK: ("OK", "operation completed successfully"),
    IO_GENERIC: ("IO_GENERIC", "I/O failed while accessing NoSQLite files"),
    FORMAT_META_INVALID: ("FORMAT_META_INVALID", "meta page is missing, corrupt, or internally inconsistent"),
    FORMAT_WAL_HEADER_INVALID: ("FORMAT_WAL_HEADER_INVALID", "WAL header is invalid or incompatible with the database file"),
    FORMAT_PAGE_CHECKSUM_INVALID: ("FORMAT_PAGE_CHECKSUM_INVALID", "page checksum mismatch detected"),
    FORMAT_PAGE_BOUNDS_INVALID: ("FORMAT_PAGE_BOUNDS_INVALID", "page header bounds are invalid"),
    FORMAT_WAL_RECORD_INVALID: ("FORMAT_WAL_RECORD_INVALID", "WAL record stream is truncated, corrupt, or out of order"),
    CATALOG_CORRUPT: ("CATALOG_CORRUPT", "catalog metadata is corrupt or self-inconsistent"),
}

NUMBER_RE = re.compile(rb"-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?\Z")


class CheckError(Exception):
    def __init__(self, code: int, detail: str = ""):
        self.code = code
        self.detail = detail
        super().__init__(detail or ERRORS.get(code, ("UNKNOWN", "unknown NoSQLite error"))[1])


def crc32_zeroed(data: bytes, off: int, size: int) -> int:
    scratch = bytearray(data)
    scratch[off:off + size] = b"\x00" * size
    return zlib.crc32(scratch) & 0xFFFFFFFF


def wal_record_crc_valid(record_type: int, record: bytes, record_crc: int) -> bool:
    if record_type == RECORD_PAGE_WRITE:
        meta_len = WAL_RECORD_HEADER_SIZE + WAL_PAGE_WRITE_META_SIZE
        if len(record) < meta_len:
            return False
        return record_crc == crc32_zeroed(record[:meta_len], 8, 4)
    return record_crc == crc32_zeroed(record, 8, 4)


def load_u16(data: bytes, off: int) -> int:
    return struct.unpack_from("<H", data, off)[0]


def load_u32(data: bytes, off: int) -> int:
    return struct.unpack_from("<I", data, off)[0]


def load_u64(data: bytes, off: int) -> int:
    return struct.unpack_from("<Q", data, off)[0]


def read_at(path: str, offset: int, size: int) -> bytes:
    try:
        with open(path, "rb") as f:
            f.seek(offset)
            data = f.read(size)
    except OSError as exc:
        raise CheckError(IO_GENERIC, str(exc)) from exc
    if len(data) < size:
        raise CheckError(IO_GENERIC, f"short read at {path}:{offset}")
    return data


def align_up(value: int, align: int = DOC_ALIGN) -> int:
    rem = value % align
    return value if rem == 0 else value + (align - rem)


def compare_object_key(a_hash: int, a_key: bytes, b_hash: int, b_key: bytes) -> int:
    if a_hash < b_hash:
        return -1
    if a_hash > b_hash:
        return 1
    if a_key < b_key:
        return -1
    if a_key > b_key:
        return 1
    return 0


def validate_number_text(klass: int, lexeme: bytes) -> None:
    if not NUMBER_RE.fullmatch(lexeme):
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "invalid number lexeme in DocBlob")
    has_dot = b"." in lexeme
    has_exp = b"e" in lexeme or b"E" in lexeme
    if klass == DOC_NUMBER_DECIMAL and (not has_dot or has_exp):
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "DocBlob decimal class mismatch")
    if klass == DOC_NUMBER_EXPONENT and not has_exp:
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "DocBlob exponent class mismatch")
    if klass == DOC_NUMBER_BIGINT and (has_dot or has_exp):
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "DocBlob bigint class mismatch")
    if klass not in (DOC_NUMBER_DECIMAL, DOC_NUMBER_EXPONENT, DOC_NUMBER_BIGINT):
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "invalid DocBlob number class")


def validate_doc_node(buf: bytes, start: int = 0) -> int:
    if start + NODE_HEADER_SIZE > len(buf):
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "DocBlob node header truncated")
    tag = buf[start]
    size = load_u32(buf, start + 4)
    if size == 0 or start + size > len(buf):
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "DocBlob node size out of bounds")
    end = start + size
    node = buf[start:end]

    if tag in (DOC_TAG_NULL, DOC_TAG_FALSE, DOC_TAG_TRUE):
        if size != NODE_HEADER_SIZE:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "scalar DocBlob node has invalid size")
        return end

    if tag == DOC_TAG_INT64:
        if size != INT64_NODE_SIZE:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "INT64 DocBlob node has invalid size")
        return end

    if tag == DOC_TAG_NUMBER_TEXT:
        if size < NUMBER_TEXT_PREFIX_SIZE:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "NUMBER_TEXT DocBlob node too small")
        klass = node[8]
        byte_len = load_u32(node, 12)
        raw = NUMBER_TEXT_PREFIX_SIZE + byte_len
        if align_up(raw) != size or raw > size:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "NUMBER_TEXT DocBlob size mismatch")
        validate_number_text(klass, node[NUMBER_TEXT_PREFIX_SIZE:NUMBER_TEXT_PREFIX_SIZE + byte_len])
        return end

    if tag == DOC_TAG_STRING:
        if size < STRING_PREFIX_SIZE:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "STRING DocBlob node too small")
        byte_len = load_u32(node, 8)
        raw = STRING_PREFIX_SIZE + byte_len
        if align_up(raw) != size or raw > size:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "STRING DocBlob size mismatch")
        return end

    if tag == DOC_TAG_ARRAY:
        if size < ARRAY_PREFIX_SIZE:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "ARRAY DocBlob node too small")
        count = load_u32(node, 8)
        offsets_end = ARRAY_PREFIX_SIZE + count * 4
        values_start = align_up(offsets_end)
        if values_start > size:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "ARRAY DocBlob offsets exceed node size")
        prev_end = values_start
        for i in range(count):
            child_off = load_u32(node, ARRAY_PREFIX_SIZE + i * 4)
            if child_off < values_start or child_off >= size or child_off < prev_end:
                raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "ARRAY DocBlob child offset invalid")
            prev_end = validate_doc_node(node, child_off)
        if prev_end != size:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "ARRAY DocBlob trailing bytes detected")
        return end

    if tag == DOC_TAG_OBJECT:
        if size < OBJECT_PREFIX_SIZE:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "OBJECT DocBlob node too small")
        count = load_u32(node, 8)
        entries_end = OBJECT_PREFIX_SIZE + count * OBJECT_ENTRY_SIZE
        if entries_end > size:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "OBJECT DocBlob entries exceed node size")
        prev_hash = None
        prev_key = None
        max_key_end = entries_end
        entries = []
        for i in range(count):
            off = OBJECT_PREFIX_SIZE + i * OBJECT_ENTRY_SIZE
            key_hash = load_u32(node, off)
            key_len = load_u16(node, off + 4)
            key_off = load_u32(node, off + 8)
            val_off = load_u32(node, off + 12)
            key_end = key_off + key_len
            if key_off < entries_end or key_end > size or val_off >= size:
                raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "OBJECT DocBlob entry offset invalid")
            key = node[key_off:key_end]
            if prev_hash is not None and compare_object_key(prev_hash, prev_key, key_hash, key) > 0:
                raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "OBJECT DocBlob keys out of order")
            prev_hash = key_hash
            prev_key = key
            max_key_end = max(max_key_end, key_end)
            entries.append((val_off, key_hash, key))
        values_start = align_up(max_key_end)
        prev_end = values_start
        for val_off, _, _ in entries:
            if val_off < values_start or val_off < prev_end:
                raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "OBJECT DocBlob value offset invalid")
            prev_end = validate_doc_node(node, val_off)
        if prev_end != size:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "OBJECT DocBlob trailing bytes detected")
        return end

    raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, f"unknown DocBlob tag {tag}")


def validate_docblob(blob: bytes) -> None:
    end = validate_doc_node(blob, 0)
    if end != len(blob):
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "DocBlob length mismatch")


def decode_meta(data: bytes) -> dict:
    return {
        "magic": data[0:4],
        "format_version": load_u32(data, 4),
        "min_reader_version": load_u32(data, 8),
        "feature_flags": load_u64(data, 12),
        "page_size": load_u32(data, 20),
        "generation": load_u64(data, 24),
        "commit_lsn": load_u64(data, 32),
        "checkpoint_lsn": load_u64(data, 40),
        "page_count": load_u32(data, 48),
        "catalog_root": load_u32(data, 52),
        "freelist_head": load_u32(data, 56),
        "active_meta_slot": load_u32(data, 60),
        "checksum": load_u32(data, 64),
    }


def meta_valid(meta: dict, physical_slot: int, raw: bytes) -> bool:
    if meta["magic"] != b"NSQL":
        return False
    if meta["format_version"] != FORMAT_VERSION or meta["min_reader_version"] > FORMAT_VERSION:
        return False
    if meta["feature_flags"] != 0:
        return False
    if meta["page_size"] not in (PAGE_SIZE_DEFAULT, PAGE_SIZE_MAX):
        return False
    if meta["active_meta_slot"] != physical_slot:
        return False
    if meta["page_count"] < 3 or meta["catalog_root"] < 2 or meta["catalog_root"] >= meta["page_count"]:
        return False
    if meta["checkpoint_lsn"] > meta["commit_lsn"]:
        return False
    return meta["checksum"] == crc32_zeroed(raw, 64, 4)


def select_meta(db_path: str) -> dict:
    meta_a_raw = read_at(db_path, 0, META_SIZE)
    meta_a = decode_meta(meta_a_raw)
    candidates = []
    if meta_valid(meta_a, 0, meta_a_raw):
        candidates.append(meta_a)
    for offset in (PAGE_SIZE_DEFAULT, PAGE_SIZE_MAX):
        meta_b_raw = read_at(db_path, offset, META_SIZE)
        meta_b = decode_meta(meta_b_raw)
        if meta_valid(meta_b, 1, meta_b_raw):
            candidates.append(meta_b)
    if not candidates:
        raise CheckError(FORMAT_META_INVALID)
    candidates.sort(key=lambda m: (m["generation"], m["commit_lsn"]))
    return candidates[-1]


def decode_wal_header(data: bytes) -> dict:
    return {
        "magic": data[0:4],
        "format_version": load_u32(data, 4),
        "min_reader_version": load_u32(data, 8),
        "feature_flags": load_u64(data, 12),
        "page_size": load_u32(data, 20),
        "checksum": load_u32(data, 24),
    }


def validate_wal_header(header: dict, raw: bytes, page_size: int, feature_flags: int) -> None:
    if header["magic"] != b"NSWL":
        raise CheckError(FORMAT_WAL_HEADER_INVALID)
    if header["format_version"] != FORMAT_VERSION or header["min_reader_version"] > FORMAT_VERSION:
        raise CheckError(FORMAT_WAL_HEADER_INVALID)
    if header["feature_flags"] != feature_flags or header["page_size"] != page_size:
        raise CheckError(FORMAT_WAL_HEADER_INVALID)
    if header["checksum"] != crc32_zeroed(raw, 24, 4):
        raise CheckError(FORMAT_WAL_HEADER_INVALID)


def validate_page(page: bytes, page_size: int) -> tuple[dict, int]:
    if len(page) != page_size:
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID)
    header = {
        "page_type": load_u32(page, 0),
        "flags": load_u16(page, 4),
        "page_lsn": load_u64(page, 8),
        "lower": load_u16(page, 16),
        "upper": load_u16(page, 18),
        "checksum": load_u32(page, 20),
    }
    if header["lower"] < PAGE_HEADER_SIZE or header["upper"] < header["lower"] or header["upper"] > page_size:
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID)
    if header["checksum"] != crc32_zeroed(page, 20, 4):
        raise CheckError(FORMAT_PAGE_CHECKSUM_INVALID)
    return header, (header["lower"] - PAGE_HEADER_SIZE) // SLOT_SIZE


def scan_wal(wal_path: str, meta: dict) -> dict:
    try:
        wal_bytes = os.path.getsize(wal_path)
    except OSError as exc:
        raise CheckError(IO_GENERIC, str(exc)) from exc
    header_raw = read_at(wal_path, 0, WAL_HEADER_SIZE)
    header = decode_wal_header(header_raw)
    validate_wal_header(header, header_raw, meta["page_size"], meta["feature_flags"])
    report = {
        "wal_bytes": wal_bytes,
        "wal_records": 0,
        "committed_wal_txns": 0,
        "committed_pages": 0,
    }
    if wal_bytes <= WAL_HEADER_SIZE:
        return report

    with open(wal_path, "rb") as f:
        offset = WAL_HEADER_SIZE
        active_txn = None
        pending_pages = 0
        last_commit_lsn = 0
        while offset < wal_bytes:
            f.seek(offset)
            header_raw = f.read(12)
            if len(header_raw) != 12:
                raise CheckError(FORMAT_WAL_RECORD_INVALID)
            record_type, record_len, record_crc = struct.unpack_from("<III", header_raw, 0)
            if record_len < 12 or offset + record_len > wal_bytes:
                raise CheckError(FORMAT_WAL_RECORD_INVALID)
            f.seek(offset)
            record = f.read(record_len)
            if len(record) != record_len:
                raise CheckError(FORMAT_WAL_RECORD_INVALID)
            if not wal_record_crc_valid(record_type, record, record_crc):
                raise CheckError(FORMAT_WAL_RECORD_INVALID)
            report["wal_records"] += 1

            if record_type == RECORD_BEGIN:
                txn_id = load_u64(record, 12)
                if active_txn is not None or txn_id == 0:
                    raise CheckError(FORMAT_WAL_RECORD_INVALID)
                active_txn = txn_id
                pending_pages = 0
            elif record_type == RECORD_PAGE_WRITE:
                txn_id = load_u64(record, 12)
                page_id = load_u32(record, 20)
                page_size = load_u32(record, 32)
                payload_crc = load_u32(record, 36)
                payload = record[40:]
                if active_txn is None or txn_id != active_txn or page_id < 2:
                    raise CheckError(FORMAT_WAL_RECORD_INVALID)
                if page_size not in (PAGE_SIZE_DEFAULT, PAGE_SIZE_MAX) or page_size != len(payload):
                    raise CheckError(FORMAT_WAL_RECORD_INVALID)
                if payload_crc != zlib.crc32(payload) & 0xFFFFFFFF:
                    raise CheckError(FORMAT_WAL_RECORD_INVALID)
                pending_pages += 1
            elif record_type == RECORD_COMMIT:
                txn_id = load_u64(record, 12)
                commit_lsn = load_u64(record, 20)
                catalog_root = load_u32(record, 28)
                page_count = load_u32(record, 32)
                if active_txn is None or txn_id != active_txn:
                    raise CheckError(FORMAT_WAL_RECORD_INVALID)
                if commit_lsn <= last_commit_lsn or page_count < 3 or catalog_root < 2 or catalog_root >= page_count:
                    raise CheckError(FORMAT_WAL_RECORD_INVALID)
                report["committed_wal_txns"] += 1
                report["committed_pages"] += pending_pages
                last_commit_lsn = commit_lsn
                active_txn = None
            elif record_type == RECORD_CHECKPOINT:
                commit_lsn = load_u64(record, 20)
                checkpoint_lsn = load_u64(record, 28)
                catalog_root = load_u32(record, 36)
                page_count = load_u32(record, 40)
                if active_txn is not None:
                    raise CheckError(FORMAT_WAL_RECORD_INVALID)
                if checkpoint_lsn > commit_lsn or commit_lsn < last_commit_lsn or page_count < 3 or catalog_root < 2 or catalog_root >= page_count:
                    raise CheckError(FORMAT_WAL_RECORD_INVALID)
            else:
                raise CheckError(FORMAT_WAL_RECORD_INVALID)
            offset += record_len
        if active_txn is not None:
            raise CheckError(FORMAT_WAL_RECORD_INVALID)
    return report


def validate_catalog(db_path: str, meta: dict) -> tuple[int, int]:
    page = read_at(db_path, meta["catalog_root"] * meta["page_size"], meta["page_size"])
    header, _ = validate_page(page, meta["page_size"])
    if header["page_type"] != PAGE_TYPE_CATALOG:
        raise CheckError(CATALOG_CORRUPT)
    blob = page[PAGE_HEADER_SIZE:header["lower"]]
    if len(blob) < CATALOG_ROOT_SIZE:
        raise CheckError(CATALOG_CORRUPT)
    collection_count = load_u32(blob, 0)
    collections_off = load_u32(blob, 4)
    string_pool_off = load_u32(blob, 8)
    checksum = load_u32(blob, 12)
    if checksum != crc32_zeroed(blob, 12, 4):
        raise CheckError(CATALOG_CORRUPT)
    collections_bytes = collection_count * COLLECTION_META_SIZE
    if collections_off != CATALOG_ROOT_SIZE or string_pool_off < collections_off or collections_off + collections_bytes > string_pool_off or string_pool_off > len(blob):
        raise CheckError(CATALOG_CORRUPT)

    names = set()
    ids = set()
    total_rows = 0
    checked_pages = 3
    for idx in range(collection_count):
        off = collections_off + idx * COLLECTION_META_SIZE
        if off + COLLECTION_META_SIZE > len(blob):
            raise CheckError(CATALOG_CORRUPT)
        meta_raw = blob[off:off + COLLECTION_META_SIZE]
        collection_id = load_u32(meta_raw, 0)
        name_len = load_u16(meta_raw, 4)
        next_doc_id = load_u64(meta_raw, 8)
        primary_root_page = load_u32(meta_raw, 16)
        secondary_index_count = load_u16(meta_raw, 20)
        name_off = load_u32(meta_raw, 24)
        indexes_off = load_u32(meta_raw, 28)
        if collection_id == 0 or next_doc_id == 0 or secondary_index_count != 0 or indexes_off != 0:
            raise CheckError(CATALOG_CORRUPT)
        if name_off < string_pool_off or name_off + name_len > len(blob):
            raise CheckError(CATALOG_CORRUPT)
        name = blob[name_off:name_off + name_len]
        if name in names or collection_id in ids:
            raise CheckError(CATALOG_CORRUPT)
        names.add(name)
        ids.add(collection_id)
        page_count = (next_doc_id - 1 + ROWS_PER_COLLECTION_PAGE - 1) // ROWS_PER_COLLECTION_PAGE if next_doc_id > 1 else 0
        checked_pages += page_count
        total_rows += validate_collection_pages(db_path, meta["page_size"], primary_root_page, next_doc_id)
    return collection_count, total_rows, checked_pages


def validate_collection_pages(db_path: str, page_size: int, first_page_id: int, next_doc_id: int) -> int:
    if next_doc_id <= 1:
        return 0
    if first_page_id < 2:
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID)

    expected_rows = next_doc_id - 1
    page_count = (expected_rows + ROWS_PER_COLLECTION_PAGE - 1) // ROWS_PER_COLLECTION_PAGE
    rows = 0
    max_doc_id = 0
    seen_doc_ids: dict[int, tuple[int, int]] = {}

    for page_offset in range(page_count):
        page_id = first_page_id + page_offset
        page = read_at(db_path, page_id * page_size, page_size)
        header, slot_count = validate_page(page, page_size)
        if header["page_type"] != PAGE_TYPE_DATA:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID)
        if slot_count > ROWS_PER_COLLECTION_PAGE:
            raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "too many slots in collection data page")
        for slot_idx in range(slot_count):
            slot_off = PAGE_HEADER_SIZE + slot_idx * SLOT_SIZE
            cell_off = load_u16(page, slot_off)
            cell_len = load_u16(page, slot_off + 2)
            flags = load_u16(page, slot_off + 4)
            used = (flags & 1) != 0
            tombstone = (flags & 2) != 0
            if not used or tombstone:
                continue
            if cell_off + cell_len > page_size or cell_len < RECORD_CELL_HEADER_SIZE:
                raise CheckError(FORMAT_PAGE_BOUNDS_INVALID)
            cell = page[cell_off:cell_off + cell_len]
            doc_id = load_u64(cell, 0)
            doc_len = load_u32(cell, 24)
            if doc_id == 0 or RECORD_CELL_HEADER_SIZE + doc_len > len(cell):
                raise CheckError(FORMAT_PAGE_BOUNDS_INVALID)
            if doc_id in seen_doc_ids:
                raise CheckError(FORMAT_PAGE_BOUNDS_INVALID, "duplicate doc_id in collection pages")
            seen_doc_ids[doc_id] = (page_id, slot_idx)
            max_doc_id = max(max_doc_id, doc_id)
            validate_docblob(cell[RECORD_CELL_HEADER_SIZE:RECORD_CELL_HEADER_SIZE + doc_len])
            rows += 1
    if next_doc_id <= max_doc_id:
        raise CheckError(FORMAT_PAGE_BOUNDS_INVALID)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Check NoSQLite on-disk consistency.")
    parser.add_argument("stem", help="database stem path without .nsq/.wal suffix")
    args = parser.parse_args()

    db_path = f"{args.stem}.nsq"
    wal_path = f"{args.stem}.wal"
    try:
        meta = select_meta(db_path)
        wal = scan_wal(wal_path, meta)
        collection_count, row_count, checked_pages = validate_catalog(db_path, meta)
    except CheckError as exc:
        name, message = ERRORS.get(exc.code, ("UNKNOWN", "unknown NoSQLite error"))
        detail = f" detail={exc.detail}" if exc.detail else ""
        print(
            f"db_check: FAIL stem={args.stem} code={exc.code} name={name} message={message}{detail}",
            file=sys.stderr,
        )
        return 1

    print(
        "db_check: OK "
        f"stem={args.stem} pages={meta['page_count']} checked_pages={checked_pages} "
        f"collections={collection_count} rows={row_count} wal_bytes={wal['wal_bytes']} "
        f"wal_records={wal['wal_records']} committed_wal_txns={wal['committed_wal_txns']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
