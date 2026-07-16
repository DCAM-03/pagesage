#!/usr/bin/env python3
"""Batch re-extract EPUB/PDF covers for local PageSage library."""

from __future__ import annotations

import os
import re
import sqlite3
import time
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

DATA_ROOT = Path(
    os.environ.get(
        "PAGESAGE_DATA",
        Path.home() / "AppData/Roaming/PageSage/PageSage/PageSageData",
    )
)
DB_PATH = DATA_ROOT / "database" / "pagesage.sqlite"
COVERS_DIR = DATA_ROOT / "library" / "covers"


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def parse_xml(text: str) -> ET.Element:
    return ET.fromstring(text)


def findall(root: ET.Element, name: str) -> list[ET.Element]:
    return [el for el in root.iter() if local(el.tag) == name]


def zip_read_text(zf: zipfile.ZipFile, name: str) -> str | None:
    try:
        return zf.read(name).decode("utf-8", errors="replace")
    except KeyError:
        # case-insensitive
        for n in zf.namelist():
            if n.replace("\\", "/").lower() == name.replace("\\", "/").lower():
                return zf.read(n).decode("utf-8", errors="replace")
    return None


def zip_read_bytes(zf: zipfile.ZipFile, name: str) -> bytes | None:
    target = name.replace("\\", "/").lstrip("/")
    for n in zf.namelist():
        nn = n.replace("\\", "/")
        if nn == target or nn.lower() == target.lower():
            return zf.read(n)
    base = Path(target).name.lower()
    for n in zf.namelist():
        if Path(n.replace("\\", "/")).name.lower() == base:
            return zf.read(n)
    return None


def resolve_href(opf_path: str, href: str) -> str:
    href = href.split("#", 1)[0].replace("\\", "/")
    try:
        from urllib.parse import unquote

        href = unquote(href)
    except Exception:
        pass
    opf_dir = str(Path(opf_path).parent).replace("\\", "/")
    if opf_dir in (".", ""):
        return href
    # posix join
    parts = [p for p in (opf_dir.split("/") + href.split("/")) if p and p != "."]
    out: list[str] = []
    for p in parts:
        if p == "..":
            if out:
                out.pop()
        else:
            out.append(p)
    return "/".join(out)


def extract_epub_cover(epub_path: Path, book_id: str) -> str | None:
    with zipfile.ZipFile(epub_path, "r") as zf:
        container = zip_read_text(zf, "META-INF/container.xml")
        if not container:
            return None
        root = parse_xml(container)
        rootfile = None
        for el in findall(root, "rootfile"):
            rootfile = el.attrib.get("full-path")
            if rootfile:
                break
        if not rootfile:
            return None
        opf_text = zip_read_text(zf, rootfile)
        if not opf_text:
            return None
        opf = parse_xml(opf_text)
        items = findall(opf, "item")
        item_by_id = {i.attrib.get("id", ""): i for i in items if i.attrib.get("id")}

        hrefs: list[str] = []

        def add(href: str | None) -> None:
            if not href:
                return
            href = href.strip().split("#", 1)[0]
            if href and href not in hrefs:
                hrefs.append(href)

        for meta in findall(opf, "meta"):
            name = (meta.attrib.get("name") or "").lower()
            prop = (meta.attrib.get("property") or "").lower()
            if name == "cover":
                cid = meta.attrib.get("content")
                if cid and cid in item_by_id:
                    add(item_by_id[cid].attrib.get("href"))
            if prop == "cover-image" or prop.endswith(":cover-image"):
                ref = (meta.text or "").strip()
                if ref in item_by_id:
                    add(item_by_id[ref].attrib.get("href"))
                else:
                    add(ref)

        for item in items:
            props = (item.attrib.get("properties") or "").lower().split()
            if "cover-image" in props:
                add(item.attrib.get("href"))

        for ref in findall(opf, "reference"):
            t = (ref.attrib.get("type") or "").lower()
            if t in ("cover", "other.ms-coverimage-standard"):
                add(ref.attrib.get("href"))

        for item in items:
            media = (item.attrib.get("media-type") or "").lower()
            if not media.startswith("image/"):
                continue
            iid = (item.attrib.get("id") or "").lower()
            href = (item.attrib.get("href") or "").lower()
            if "cover" in iid or "cover" in href:
                add(item.attrib.get("href"))

        for item in items:
            media = (item.attrib.get("media-type") or "").lower()
            if media.startswith("image/"):
                add(item.attrib.get("href"))
                break

        for href in hrefs:
            path = resolve_href(rootfile, href)
            data = zip_read_bytes(zf, path)
            if not data:
                continue
            ext = Path(path).suffix.lstrip(".").lower() or "img"
            if data[:3] == b"\xff\xd8\xff":
                ext = "jpg"
            elif data[:4] == b"\x89PNG":
                ext = "png"
            out = COVERS_DIR / f"{book_id}.{ext}"
            COVERS_DIR.mkdir(parents=True, exist_ok=True)
            out.write_bytes(data)
            return str(out)
    return None


def extract_pdf_cover(pdf_path: Path, book_id: str) -> str | None:
    data = pdf_path.read_bytes()
    jpegs: list[bytes] = []
    i = 0
    n = len(data)
    while i < n - 3:
        if data[i] == 0xFF and data[i + 1] == 0xD8:
            j = i + 2
            while j < n - 1:
                if data[j] == 0xFF and data[j + 1] == 0xD9:
                    blob = data[i : j + 2]
                    if len(blob) >= 4 * 1024:
                        jpegs.append(blob)
                    i = j + 1
                    break
                j += 1
        i += 1
    if not jpegs:
        return None
    jpegs.sort(key=len, reverse=True)
    chosen = jpegs[0]
    for jpeg in jpegs:
        if 8 * 1024 <= len(jpeg) <= 2 * 1024 * 1024:
            chosen = jpeg
            break
    out = COVERS_DIR / f"{book_id}.jpg"
    COVERS_DIR.mkdir(parents=True, exist_ok=True)
    out.write_bytes(chosen)
    return str(out)


def main() -> None:
    if not DB_PATH.exists():
        raise SystemExit(f"数据库不存在: {DB_PATH}")

    print(f"数据目录: {DATA_ROOT}")
    print(f"数据库: {DB_PATH}")
    con = sqlite3.connect(str(DB_PATH))
    con.row_factory = sqlite3.Row
    rows = con.execute(
        "SELECT id, title, format, library_file_path, cover_path FROM books"
    ).fetchall()
    print(f"共 {len(rows)} 本书\n")

    ok = fail = skip = 0
    now = int(time.time() * 1000)
    for row in rows:
        book_id = row["id"]
        title = row["title"] or book_id
        fmt = (row["format"] or "").lower()
        lib = Path(row["library_file_path"])
        print(f"→ {title} ({fmt})")
        if not lib.exists():
            print(f"  跳过：文件不存在 {lib}")
            skip += 1
            continue
        try:
            if fmt == "epub":
                cover = extract_epub_cover(lib, book_id)
            elif fmt == "pdf":
                cover = extract_pdf_cover(lib, book_id)
            else:
                print(f"  跳过：不支持格式 {fmt}")
                skip += 1
                continue
            if not cover:
                print("  未找到封面")
                fail += 1
                continue
            con.execute(
                "UPDATE books SET cover_path = ?, updated_at = ? WHERE id = ?",
                (cover, now, book_id),
            )
            con.commit()
            print(f"  已更新: {cover}")
            ok += 1
        except Exception as e:
            print(f"  失败: {e}")
            fail += 1

    con.close()
    print(f"\n完成：成功 {ok}，未找到/失败 {fail}，跳过 {skip}")
    print("请重新打开应用查看封面。")


if __name__ == "__main__":
    main()
