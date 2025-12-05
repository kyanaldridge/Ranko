#!/usr/bin/env python3
"""
Seed sample leaderboard entries into Firestore.

Path: games/blind-sequence/leaderboard/{userID}
Fields: userID, score (27-42), time (score * random multiplier), time_achieved (YYYYMMDDHHmmss)

Usage:
    python Firestore/add_leaderboard_entry.py
"""

from __future__ import annotations

import os
import random
import string
from datetime import datetime, timedelta
from typing import Dict, Any, List

from google.cloud import firestore
from google.oauth2 import service_account

# ── CONFIG ───────────────────────────────────────────────────────────
PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "ranko-kyan")
DATABASE_ID = os.getenv("FIREBASE_DATABASE_ID", "ranko")
SERVICE_ACCOUNT = os.getenv(
    "GOOGLE_APPLICATION_CREDENTIALS",
    "ranko-kyan-firebase-adminsdk-ufki5-60a76eeda7.json",
)

COLLECTION_PATH = ("games", "blind-sequence", "leaderboard")
ENTRY_COUNT = 30
SCORE_MIN = 27
SCORE_MAX = 42
MULTIPLIER_MIN = 2.00981395349
MULTIPLIER_MAX = 2.04981395349
DATE_START = "20251008145208"
DATE_END = "20251205124645"


def get_db() -> firestore.Client:
    if not os.path.isfile(SERVICE_ACCOUNT):
        raise FileNotFoundError(f"Service account not found: {SERVICE_ACCOUNT}")
    creds = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT)
    return firestore.Client(project=PROJECT_ID, database=DATABASE_ID, credentials=creds)


def random_user_id(length: int = 20) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(random.choices(alphabet, k=length))


def random_score() -> int:
    return random.randint(SCORE_MIN, SCORE_MAX)


def random_multiplier() -> float:
    return random.uniform(MULTIPLIER_MIN, MULTIPLIER_MAX)


def random_time(score: int) -> float:
    return score * random_multiplier()


def random_timestamp() -> int:
    start_dt = datetime.strptime(DATE_START, "%Y%m%d%H%M%S")
    end_dt = datetime.strptime(DATE_END, "%Y%m%d%H%M%S")
    delta = end_dt - start_dt
    offset = random.randint(0, int(delta.total_seconds()))
    ts = start_dt + timedelta(seconds=offset)
    return int(ts.strftime("%Y%m%d%H%M%S"))


def make_entry() -> Dict[str, Any]:
    uid = random_user_id()
    score = random_score()
    return {
        "userID": uid,
        "score": score,
        "time": random_time(score),
        "time_achieved": random_timestamp(),
    }


def add_entries(db: firestore.Client, entries: List[Dict[str, Any]]) -> None:
    games, doc_id, leaderboard = COLLECTION_PATH
    batch = db.batch()
    for entry in entries:
        doc_ref = db.collection(games).document(doc_id).collection(leaderboard).document(entry["userID"])
        batch.set(doc_ref, entry)
    batch.commit()


def main() -> None:
    db = get_db()
    entries = [make_entry() for _ in range(ENTRY_COUNT)]
    add_entries(db, entries)
    print(f"✅ Added {len(entries)} leaderboard entries to {'/'.join(COLLECTION_PATH)}")


if __name__ == "__main__":
    main()
