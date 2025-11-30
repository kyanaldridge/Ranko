#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Import Ranko data from a Firebase RTDB export JSON into Firestore.
Default input file: ranko-kyan-default-rtdb-RankoData-export-8.json
Target collection: ranko

Usage:
    python import_ranko.py [path_to_json]
"""

import json
import os
import sys
from typing import Any, Dict, Iterable, List

from google.cloud import firestore
from google.oauth2 import service_account

# ── CONFIG ───────────────────────────────────────────────────────────
PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "ranko-kyan")
DATABASE_ID = os.getenv("FIREBASE_DATABASE_ID", "ranko")
SERVICE_ACCOUNT = os.getenv(
    "GOOGLE_APPLICATION_CREDENTIALS",
    "ranko-kyan-firebase-adminsdk-ufki5-60a76eeda7.json",
)

DEFAULT_JSON = "ranko-kyan-default-rtdb-RankoData-export-8.json"
TARGET_COLLECTION = "ranko"


# ── HELPERS ──────────────────────────────────────────────────────────
def get_db() -> firestore.Client:
    if not os.path.isfile(SERVICE_ACCOUNT):
        raise FileNotFoundError(f"Service account not found: {SERVICE_ACCOUNT}")
    creds = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT)
    db = firestore.Client(project=PROJECT_ID, database=DATABASE_ID, credentials=creds)
    print(f"✅ connected to Firestore: {PROJECT_ID}/{DATABASE_ID}")
    return db


def load_data(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def normalize_tags(tags: Iterable[str]) -> List[str]:
    return [str(t).strip().lower() for t in tags if str(t).strip()]


def convert_ranko(ranko_id: str, raw: Dict[str, Any]) -> Dict[str, Any]:
    details = raw.get("RankoDetails", {}) or {}
    category = raw.get("RankoCategory", {}) or {}
    dt = raw.get("RankoDateTime", {}) or {}

    created = dt.get("created")
    updated = dt.get("updated")
    try:
        created = int(created) if created is not None else None
    except (TypeError, ValueError):
        created = None
    try:
        updated = int(updated) if updated is not None else None
    except (TypeError, ValueError):
        updated = created

    tags = normalize_tags(details.get("tags", []))

    return {
        "id": details.get("id", ranko_id),
        "name": details.get("name", ""),
        "description": details.get("description", ""),
        "lang": "145",
        "time": {"created": created, "updated": updated},
        "category": category.get("name", ""),
        "country": "10",
        "privacy": "111111",
        "status": "1",
        "type": "2" if str(details.get("type", "")).lower() == "tier" else "1",
        "user_id": details.get("user_id", ""),
        "tags": tags if tags else [],
    }


def push_ranko(
    db: firestore.Client, ranko_id: str, raw: Dict[str, Any]
) -> None:
    doc_ref = db.collection(TARGET_COLLECTION).document(ranko_id)
    doc_payload = convert_ranko(ranko_id, raw)
    doc_ref.set(doc_payload)

    # Likes
    likes = raw.get("RankoLikes", {}) or {}
    likes_ref = doc_ref.collection("likes")
    for user_id, ts in likes.items():
        likes_ref.document(user_id).set(
            {
                "time": ts,
                "user_id": user_id,
            }
        )

    # Comments (intentionally empty)
    # Items
    items = raw.get("RankoItems", {}) or {}
    items_ref = doc_ref.collection("items")
    for _, item in items.items():
        item_id = item.get("ItemID")
        if not item_id:
            continue
        items_ref.document(item_id).set(
            {
                "id": item_id,
                "name": item.get("ItemName", ""),
                "description": item.get("ItemDescription", ""),
                "image": item.get("ItemImage", ""),
                "video": item.get("ItemVideo", ""),
                "audio": item.get("ItemAudio", ""),
                "gif": item.get("ItemGIF", ""),
                "rank": item.get("ItemRank", 0),
                "votes": item.get("ItemVotes", 0),
                "plays": item.get("PlayCount", 0),
            }
        )


# ── MAIN ────────────────────────────────────────────────────────────
def main() -> None:
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_JSON
    if not os.path.isfile(path):
        print(f"❌ File not found: {path}")
        sys.exit(1)

    data = load_data(path)
    db = get_db()
    total = len(data)
    print(f"Importing {total} ranko records from {path} into collection '{TARGET_COLLECTION}'...")
    for i, (ranko_id, raw) in enumerate(data.items(), start=1):
        push_ranko(db, ranko_id, raw)
        print(f"[{i}/{total}] imported {ranko_id}")
    print("✅ Import completed.")


if __name__ == "__main__":
    main()
