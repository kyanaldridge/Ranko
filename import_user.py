#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Import User data from a Firebase RTDB export JSON into Firestore.
Default input file: ranko-kyan-default-rtdb-UserData-export-10.json
Target collection: users

Usage:
    python import_user.py [path_to_json]
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

DEFAULT_JSON = "ranko-kyan-default-rtdb-UserData-export-10.json"
TARGET_COLLECTION = "users"


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


def parse_int(value: Any) -> Any:
    try:
        return int(value)
    except (TypeError, ValueError):
        return value


def parse_interests(raw: Any) -> List[str]:
    if isinstance(raw, list):
        return [str(x).strip() for x in raw if str(x).strip()]
    if isinstance(raw, str):
        return [p.strip() for p in raw.split(",") if p.strip()]
    return []


def convert_user(user_id: str, raw: Dict[str, Any]) -> Dict[str, Any]:
    details = raw.get("UserDetails", {}) or {}
    profile = raw.get("UserProfilePicture", {}) or {}
    stats = raw.get("UserStats", {}) or {}

    return {
        "description": details.get("UserDescription", ""),
        "foundUs": details.get("UserFoundUs", ""),
        "id": details.get("UserID", user_id),
        "joined": details.get("UserJoined", ""),
        "name": details.get("UserName", ""),
        "privacy": details.get("UserPrivacy", ""),
        "signIn": details.get("UserSignInMethod", ""),
        "year": details.get("UserYear", ""),
        "image": {
            "modified": parse_int(profile.get("UserProfilePictureModified")),
            "path": profile.get("UserProfilePicturePath", ""),
        },
        "interests": parse_interests(details.get("UserInterests", [])),
        "stats": {
            "followers": stats.get("UserFollowerCount", 0),
            "following": stats.get("UserFollowingCount", 0),
            "rankos": stats.get("UserRankoCount", 0),
        },
    }


def import_user(db: firestore.Client, user_id: str, raw: Dict[str, Any]) -> None:
    doc_ref = db.collection(TARGET_COLLECTION).document(user_id)
    payload = convert_user(user_id, raw)
    doc_ref.set(payload)

    social = raw.get("UserSocial", {}) or {}
    followers_raw = social.get("UserFollowers", {}) or {}
    following_raw = social.get("UserFollowing", {}) or {}

    followers_ref = doc_ref.collection("followers")
    following_ref = doc_ref.collection("following")

    # Followers
    for follower_id, ts in followers_raw.items():
        followers_ref.document(follower_id).set(
            {
                "time": parse_int(ts),
                "user_id": follower_id,
                "following": follower_id in following_raw,
            }
        )

    # Following
    for following_id, ts in following_raw.items():
        following_ref.document(following_id).set(
            {
                "time": parse_int(ts),
                "user_id": following_id,
                "followed": following_id in followers_raw,
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
    print(f"Importing {total} users from {path} into collection '{TARGET_COLLECTION}'...")
    for i, (user_id, raw) in enumerate(data.items(), start=1):
        import_user(db, user_id, raw)
        print(f"[{i}/{total}] imported {user_id}")
    print("✅ Import completed.")


if __name__ == "__main__":
    main()
