"""AAB를 Play에 올린다 — **우선순위를 붙여서.**

콘솔 화면으로 올리면 `inAppUpdatePriority`를 넣을 수 없다. 그 값은 Developer
API의 `Edits.tracks.releases`에만 있고, 안 넣으면 0으로 굳는다. 나중에 못 고친다.

그래서 앱 안의 `update_service.dart`가 세법이 바뀐 릴리스를 자동으로 밀어넣게
써 뒀는데도(`updatePriority >= 4`), 그 가지는 지금까지 한 번도 실행된 적이 없다.
콘솔로만 올렸기 때문이다. 이 스크립트가 그 구멍을 메운다.

세끌은 서버가 없어서 "세법이 바뀌었다"를 사용자에게 전할 길이 앱 업데이트뿐이다.
매일 루틴이 개정을 찾아 고치는데 그게 사용자 폰까지 며칠씩 안 가면, 앱은 낡은
숫자를 자신 있게 보여준다. 그건 계산이 틀린 것과 같다.

**빌드에는 손대지 않는다.** Gradle 플러그인으로 붙이면 앱 빌드 경로에 남지만,
이건 발행할 때만 도는 바깥 도구다.

---

## 처음 한 번 준비 (사람이 해야 하는 부분)

1. Google Cloud Console → 프로젝트 → **서비스 계정** 만들기 → JSON 키 내려받기
2. Google Cloud Console → **API 및 서비스** → `Google Play Android Developer API` 사용 설정
3. Play Console → **사용자 및 권한** → 사용자 초대 → 위 서비스 계정 이메일
   - 권한: `앱 액세스 권한`에서 세끌 선택, `버전 관리` · `프로덕션/테스트 버전 관리`
4. JSON 키 경로를 환경변수에 둔다 (저장소에 넣지 말 것 — .gitignore에 걸어 뒀다)

       setx PLAY_SERVICE_ACCOUNT_JSON "C:\\keys\\sekkeul-play.json"

## 쓰기

    # 트랙 이름부터 확인 (비공개 테스트 트랙의 실제 이름을 모를 때)
    python tool/play_publish.py --list-tracks

    # 출시 노트는 assets/changelog.md의 **맨 위 항목을 그대로** 쓴다.
    # 앱 안 「업데이트 소식」이 읽는 그 파일이라, 두 곳이 어긋날 수가 없다.
    python tool/play_publish.py --track alpha --priority 5   # 세법이 바뀐 릴리스
    python tool/play_publish.py --track alpha --priority 0   # 그 밖

    # 굳이 따로 쓰고 싶으면
    python tool/play_publish.py --track alpha --notes "화면을 다듬었어요."

## 우선순위를 어떻게 정하나

| 값 | 앱 동작 | 언제 |
|---|---|---|
| 4~5 | 전체화면으로 막고 즉시 업데이트 | **세율·공제·한도 등 계산에 쓰는 값이 바뀐 릴리스** |
| 1~3 | 홈 카드 (지금과 같음) | 문구·화면 수정, 새 기능 |
| 0 | 홈 카드 | 버그 수정 |

**틀린 숫자를 보여주는 것보다 한 번 막는 게 낫다** — 4~5는 그 기준으로만 쓴다.
사소한 수정에 5를 주면 사용자는 다음부터 업데이트 화면을 적으로 여긴다.
"""

import argparse
import io
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE = 'com.sekkeul.app'
AAB = 'build/app/outputs/bundle/release/app-release.aab'
CHANGELOG = 'assets/changelog.md'
SCOPE = 'https://www.googleapis.com/auth/androidpublisher'


def latest_notes():
    """`assets/changelog.md`의 맨 위 항목 → 출시 노트.

    앱 안 「업데이트 소식」이 읽는 그 파일이다. 두 곳에 따로 쓰면 반드시
    어긋나고, 어긋난 건 올린 뒤에야 보인다.
    """
    import re
    src = io.open(CHANGELOG, encoding='utf-8').read()
    head = re.compile(r'^##\s+([\d.]+)\s*\((\d+)\)', re.M)
    m = head.search(src)
    if not m:
        sys.exit(f'{CHANGELOG}에서 항목을 못 찾았습니다.')
    nxt = head.search(src, m.end())
    body = src[m.end():nxt.start() if nxt else len(src)]
    lines = [l[2:].strip() for l in body.splitlines() if l.startswith('- ')]
    if not lines:
        sys.exit(f'{CHANGELOG}의 {m.group(1)} 항목에 내용이 없습니다.')
    return m.group(1), int(m.group(2)), chr(10).join('· ' + l for l in lines)


def _service(key_path):
    if not key_path:
        sys.exit('PLAY_SERVICE_ACCOUNT_JSON 환경변수가 없습니다. 파일 맨 위 준비 절차를 보세요.')
    if not os.path.isfile(key_path):
        sys.exit(f'서비스 계정 키를 못 찾았습니다: {key_path}')
    creds = service_account.Credentials.from_service_account_file(
        key_path, scopes=[SCOPE])
    return build('androidpublisher', 'v3', credentials=creds,
                 cache_discovery=False)


def list_tracks(svc):
    """이 앱에 어떤 트랙이 있는지. 비공개 테스트 트랙 이름은 앱마다 다르다."""
    edit = svc.edits().insert(body={}, packageName=PACKAGE).execute()
    try:
        tracks = svc.edits().tracks().list(
            editId=edit['id'], packageName=PACKAGE).execute()
        for t in tracks.get('tracks', []):
            codes = [c for r in t.get('releases', [])
                     for c in r.get('versionCodes', [])]
            print(f"  {t['track']:<24} 올라간 버전: {', '.join(codes) or '없음'}")
    finally:
        svc.edits().delete(editId=edit['id'], packageName=PACKAGE).execute()


def publish(svc, aab, track, priority, notes, rollout_status):
    edit = svc.edits().insert(body={}, packageName=PACKAGE).execute()
    edit_id = edit['id']

    size_mb = os.path.getsize(aab) / 1024 / 1024
    print(f'올리는 중 {aab} ({size_mb:.1f}MB) …')
    # 70MB가 넘으므로 나눠 보낸다. 한 번에 보내면 중간에 끊길 때 처음부터다.
    media = MediaFileUpload(aab, mimetype='application/octet-stream',
                            resumable=True, chunksize=8 * 1024 * 1024)
    req = svc.edits().bundles().upload(
        editId=edit_id, packageName=PACKAGE, media_body=media)
    res = None
    while res is None:
        status, res = req.next_chunk()
        if status:
            print(f'\r  {int(status.progress() * 100)}%', end='', flush=True)
    version_code = res['versionCode']
    print(f'\r  버전코드 {version_code} 업로드 완료')

    svc.edits().tracks().update(
        editId=edit_id, track=track, packageName=PACKAGE,
        body={
            'releases': [{
                'versionCodes': [str(version_code)],
                'status': rollout_status,
                # **여기가 콘솔에 없는 값이다.** 한 번 정하면 못 고친다.
                'inAppUpdatePriority': priority,
                'releaseNotes': [{'language': 'ko-KR', 'text': notes}],
            }]
        }).execute()

    svc.edits().commit(editId=edit_id, packageName=PACKAGE).execute()
    print(f'{track} 트랙에 발행 · 우선순위 {priority}')
    if priority >= 4:
        print('  → 사용자가 앱을 켜면 전체화면으로 막고 바로 업데이트합니다.')
    else:
        print('  → 홈 카드로 알립니다. 사용자가 눌러야 받습니다.')


def main():
    p = argparse.ArgumentParser(description='AAB를 우선순위와 함께 Play에 올린다')
    p.add_argument('--list-tracks', action='store_true', help='트랙 이름만 훑어본다')
    p.add_argument('--track', default='alpha', help='비공개 테스트는 보통 alpha')
    p.add_argument('--priority', type=int, default=0, choices=range(6),
                   help='4~5는 계산에 쓰는 값이 바뀐 릴리스에만')
    p.add_argument('--notes', help='출시 노트 (한 줄)')
    p.add_argument('--notes-file', help='출시 노트 파일 (여러 줄)')
    p.add_argument('--notes-manual', action='store_true',
                   help='changelog.md를 안 쓰고 --notes만 쓴다')
    p.add_argument('--aab', default=AAB)
    p.add_argument('--draft', action='store_true', help='발행하지 않고 초안으로만')
    p.add_argument('--key', default=os.environ.get('PLAY_SERVICE_ACCOUNT_JSON'))
    a = p.parse_args()

    svc = _service(a.key)

    if a.list_tracks:
        list_tracks(svc)
        return

    if not os.path.isfile(a.aab):
        sys.exit(f'AAB가 없습니다: {a.aab}\n  flutter build appbundle --release 를 먼저 도세요.')

    notes = a.notes
    if a.notes_file:
        with open(a.notes_file, encoding='utf-8') as f:
            notes = f.read().strip()
    if not notes and not a.notes_manual:
        # 기본은 changelog.md다 — 앱 안 「업데이트 소식」과 같은 글이 나간다.
        version, build, notes = latest_notes()
        print(f'{CHANGELOG}의 {version} ({build}) 항목을 씁니다:')
        for l in notes.splitlines():
            print(f'  {l}')
    if not notes:
        sys.exit('--notes 또는 --notes-file 이 필요합니다. '
                 '무엇이 바뀌었는지 모르면 사용자는 왜 업데이트하는지 모릅니다.')
    if len(notes) > 500:
        sys.exit(f'출시 노트가 {len(notes)}자입니다. Play 상한은 500자예요.')

    # 우선순위는 한 번 정하면 못 고친다. 높은 값은 손으로 한 번 더 확인시킨다.
    if a.priority >= 4:
        print(f'우선순위 {a.priority} — 사용자 화면을 막고 업데이트합니다.')
        print('계산에 쓰는 값(세율·공제·한도)이 바뀐 릴리스가 맞습니까? [y/N] ', end='')
        if input().strip().lower() != 'y':
            sys.exit('취소했습니다.')

    publish(svc, a.aab, a.track, a.priority, notes,
            'draft' if a.draft else 'completed')


if __name__ == '__main__':
    main()
