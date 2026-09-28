"""Download verified Commons originals into the git-ignored media cache.

Run from repository root: python tool/download_media_assets.py
Every URL is taken from a verified file page, and restricted to Wikimedia upload hosts.
"""
import argparse
import json
import os
from pathlib import Path
import time
import urllib.parse
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'media_assets/manifest.json'
MAX_BYTES = 40 * 1024 * 1024
USER_AGENT = 'SeichiQuestMediaCache/1.1 (https://github.com/rainbowwing0603-blip/seichi_quest) Python-urllib'
MAX_RETRIES = 3


def fetch(asset):
    url = asset['download_url']
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != 'https' or parsed.hostname != 'upload.wikimedia.org':
        return (asset['file_page'], 'unsafe download host')
    dest = ROOT / asset['cache_path']
    if not dest.resolve().is_relative_to((ROOT / 'media_assets/cache').resolve()):
        return (asset['file_page'], 'unsafe destination')
    if dest.exists() and dest.stat().st_size == asset['source_file_bytes']:
        return (asset['file_page'], 'already cached')
    dest.parent.mkdir(parents=True, exist_ok=True)
    temp = dest.with_suffix(dest.suffix + '.part')

    for attempt in range(MAX_RETRIES):
        try:
            req = urllib.request.Request(url, headers={
                'User-Agent': USER_AGENT,
                'Accept': 'image/*,*/*;q=0.8',
            })
            with urllib.request.urlopen(req, timeout=90) as response, temp.open('wb') as output:
                actual = urllib.parse.urlsplit(response.url)
                if actual.hostname != 'upload.wikimedia.org':
                    raise ValueError('unexpected redirect')
                total = 0
                while chunk := response.read(1024 * 1024):
                    total += len(chunk)
                    if total > MAX_BYTES:
                        raise ValueError('file too large')
                    output.write(chunk)
            if total != asset['source_file_bytes']:
                raise ValueError(f'byte count mismatch: {total}')
            os.replace(temp, dest)
            return (asset['file_page'], 'downloaded')
        except urllib.error.HTTPError as error:
            temp.unlink(missing_ok=True)
            if error.code != 429:
                return (asset['file_page'], f'failed: HTTP {error.code}')
            retry_after = error.headers.get('Retry-After')
            if retry_after and retry_after.isdigit():
                wait = min(int(retry_after), 120)
            else:
                wait = min(5 * (2 ** attempt), 60)
            if attempt + 1 >= MAX_RETRIES:
                return (asset['file_page'], f'failed: HTTP 429 after {MAX_RETRIES} attempts')
            print(f'HTTP 429; respecting Retry-After/backoff ({wait}s) before retry {attempt + 2}/{MAX_RETRIES}...')
            time.sleep(wait)
        except Exception as error:
            temp.unlink(missing_ok=True)
            return (asset['file_page'], f'failed: {error}')

    return (asset['file_page'], 'failed: retry limit reached')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--max-files', type=int, default=0, help='Limit newly downloaded files per run (0: all)')
    args = parser.parse_args()
    assets = [a for a in json.loads(MANIFEST.read_text())['assets'] if a['status'] == 'verified_candidate']
    results = []
    downloaded = 0
    for asset in assets:
        page, result = fetch(asset)
        results.append((page, result))
        if result == 'downloaded':
            downloaded += 1
            time.sleep(2)  # Respect Commons upload bandwidth and rate limits.
        if 'HTTP Error 429' in result:
            print('Commons rate limit reached; stop and retry later.')
            break
        if args.max_files and downloaded >= args.max_files:
            break
    counts = {}
    for _, result in results:
        counts[result.split(':', 1)[0]] = counts.get(result.split(':', 1)[0], 0) + 1
    print('Media cache:', counts)
    for page, result in results:
        if result.startswith('failed:'):
            print(result, page)


if __name__ == '__main__':
    main()
