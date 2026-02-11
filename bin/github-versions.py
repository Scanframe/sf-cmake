#!/usr/bin/env python3
"""
github_versions.py

Usage:
  github_versions.py [-o OWNER] [-n REPO] [-u URL] [-f FIND] [-l] [-j] [--json]

Matches behavior of the provided bash script:
- Fetches tags from GitHub API and caches them in a temp file.
- Filters tags of the form vX.Y.Z and returns versions (without leading 'v').
- --find returns the nearest version <= requested version.
- --latest returns the highest version.
- --joined returns versions joined by ';'.
- --json prints raw API JSON.
"""

import argparse
import json
import re
import sys
import tempfile
import time
import requests
from pathlib import Path
from typing import List, Optional, Tuple

SEM_VER_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
REL_VER_RE = re.compile(r"^Release_(\d+)_(\d+)_(\d+)$")

def parse_owner_repo_from_url(url: str) -> Tuple[str, str]:
	url = url.strip()
	if url.startswith("https://github.com/"):
		path = url[len("https://github.com/"):]
	else:
		path = url
	path = path.rstrip(".git")
	if "/" not in path:
		raise ValueError("URL does not contain owner/repo")
	owner, repo = path.split("/", 1)
	return owner, repo


def version_key(ver: str) -> tuple[int, ...]:
	"""Convert '1.2.3' -> (1,2,3) for sorting/comparison."""
	parts = ver.split(".")
	parts = [int(p) for p in parts]
	# pad to 3
	while len(parts) < 3:
		parts.append(0)
	return tuple(parts[:3])


def version_compare(a: str, b: str) -> int:
	"""Return -1 if a < b, 0 if equal, 1 if a > b."""
	ka = version_key(a)
	kb = version_key(b)
	if ka < kb:
		return -1
	if ka > kb:
		return 1
	return 0


def load_cache(cache_file: Path) -> Optional[List[dict]] | None:
	if not cache_file.exists():
		return None
	try:
		with cache_file.open("r", encoding="utf-8") as f:
			return json.load(f)
	except Exception:
		return None


def save_cache(cache_file: Path, data: List[dict]) -> None:
	cache_file.parent.mkdir(parents=True, exist_ok=True)
	with cache_file.open("w", encoding="utf-8") as f:
		json.dump(data, f)


def file_age_seconds(path: Path) -> float:
	return time.time() - path.stat().st_mtime


def fetch_tags(api_url: str) -> List[dict]:
	resp = requests.get(api_url, headers={"Accept": "application/vnd.github.v3+json"}, timeout=15)
	resp.raise_for_status()
	return resp.json()


def extract_versions_from_tags(tags: List[dict]) -> List[str]:
	versions = []
	for t in tags:
		name = t.get("name", "")
		m = SEM_VER_RE.match(name)
		if m:
			versions.append("{}.{}.{}".format(m.group(1), m.group(2), m.group(3)))
		else:
			m = REL_VER_RE.match(name)
			if m:
				versions.append("{}.{}.{}".format(m.group(1), m.group(2), m.group(3)))
	return versions


def main(argv: List[str]) -> int:
	parser = argparse.ArgumentParser(description="List version tags like v1.2.3 from a GitHub repo")
	parser.add_argument("-o", "--owner", help="Repository owner")
	parser.add_argument("-n", "--repo", help="Repository name")
	parser.add_argument("-u", "--url", help="Browser URL from github (https://github.com/owner/repo.git)")
	parser.add_argument("-f", "--find", dest="find_ver", help="Find the nearest version (<= given)")
	parser.add_argument("-l", "--latest", action="store_true", help="Get the latest version")
	parser.add_argument("-j", "--joined", action="store_true", help="Join versions with ';'")
	parser.add_argument("-c", "--cache-dir", help="Directory used to store the cache file.")
	parser.add_argument("--json", action="store_true", help="Print raw JSON from API")
	args = parser.parse_args(argv)

	owner = args.owner
	repo = args.repo
	if args.url:
		try:
			owner_from_url, repo_from_url = parse_owner_repo_from_url(args.url)
			owner = owner_from_url
			repo = repo_from_url
		except ValueError as e:
			print(f"Error parsing URL: {e}", file=sys.stderr)
			return 1

	if not owner or not repo:
		print("Missing owner or repository!", file=sys.stderr)
		parser.print_help()
		return 1

	api_url = f"https://api.github.com/repos/{owner}/{repo}/tags"
	# Form the cache filepath.
	cache_file = Path(
		(args.cache_dir if args.cache_dir else tempfile.gettempdir())) / f"github-tags-{owner}-{repo}.json"
	tags = load_cache(cache_file)
	cache_age = None
	if cache_file.exists():
		cache_age = file_age_seconds(cache_file)
		# Renew after 1800 seconds (30 minutes)
		if cache_age > 1800:
			try:
				cache_file.unlink()
			except Exception:
				pass
			tags = None

	if tags is None:
		try:
			tags = fetch_tags(api_url)
			save_cache(cache_file, tags)
			cache_age = 0.0 if cache_age is None else cache_age
			print(f"# Updating cache file ({cache_age}s): {cache_file}", file=sys.stderr)
		except requests.RequestException as e:
			print(f"Failed to fetch tags: {e}", file=sys.stderr)
			# If the cache exists, try to use it.
			tags = load_cache(cache_file)
			if tags is None:
				return 1
	else:
		print(f"# Using cache file ({int(cache_age)}s): {cache_file}", file=sys.stderr)

	if args.json:
		# Print raw JSON.
		print(json.dumps(tags, indent=2), file=sys.stdout)
		return 0

	versions = extract_versions_from_tags(tags)
	# sort ascending by semantic version
	versions = sorted(set(versions), key=version_key)

	if args.find_ver:
		target = args.find_ver
		prev_tag = None
		for v in versions:
			cmp = version_compare(v, target)
			if cmp == 0:
				print(v, file=sys.stdout)
				return 0
			# If the current version > target, the previous version is the nearest <= target.
			if cmp == 1:
				if prev_tag:
					print(prev_tag, file=sys.stdout)
					return 0
				else:
					# no previous version <= target
					return 0
			prev_tag = v
		# If we finished the loop and didn't return, maybe the last version <= target.
		if prev_tag:
			print(prev_tag, file=sys.stdout)
		return 0

	if args.latest:
		if not versions:
			return 0
		latest = max(versions, key=version_key)
		print(latest, file=sys.stdout)
		return 0

	if args.joined:
		print(";".join(versions), file=sys.stdout)
		return 0

	# Default: list available versions in reverse (newest first)
	for v in sorted(versions, key=version_key, reverse=True):
		print(v)

	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
