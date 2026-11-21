#!/usr/bin/env python3
"""내보낸 묶음에 게임이 실행 중에 원문으로 읽는 파일이 들어가는지 확인한다.

    python3 tools/check_export_pack.py            # Android 프리셋의 자료 묶음을 만들어 검사한다

게임은 그림을 SVG 원문에서 화면 배율에 맞춰 다시 그린다(DPITexture). 그런데 Godot은 가져온 SVG를 비트맵으로만
내보내고 원본 .svg는 포함 목록에 적어도 묶음에 넣지 않는다(가져오기 설정이 있는 파일은 가져온 결과만 싣는다).
그래서 원문은 생성 도구가 만든 JSON 묶음(svg_sources.json)으로 싣는다. JSON은 설정 없이 그대로 내보내진다.
이 검사는 실제로 자료 묶음을 만들어(`--export-pack`, 내보내기 템플릿과 Android SDK가 필요 없다) 다음을 본다.

- SVG 원문 묶음이 들어 있고 저장소의 파일과 같으며, 세 그림 폴더(스킨, 플레이, 바깥 화면)의 모든 SVG를 담고 있다
- 원문으로 읽는 자료(콘텐츠, 레벨 팩, 수익화 프로필, 제품 설정, 스킨 설정, 오픈소스 고지의 라이선스 원문)가 들어 있다
- 카드 그림과 소리가 가져온 결과로 들어 있다

출력은 build/ 아래에 두고 추적 파일을 바꾸지 않는다.
"""
import argparse
import json
import os
import subprocess
import sys
import uuid
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESET = 'Android'
SVG_PACK = 'game/features/shared/svg_sources.json'
SVG_FOLDERS = ('game/skins/candy_pop', 'game/features/play/assets', 'game/features/outgame/assets')
# 실행 중에 파일 그대로 읽는 자료.
RAW_FILES = (
    SVG_PACK,
    'config/product.json',
    'data/content/items.json',
    'data/content/categories.json',
    'data/levels/journey.json',
    'data/levels/daily.json',
    'data/levels/tutorial.json',
    'data/monetization/bm-profile.json',
    'game/skins/candy_pop/skin.json',
    'addons/seorilabs_game/skins/soft_adventure/skin.json',
    # 설정의 오픈소스 고지가 원문으로 읽는 라이선스 파일(내보내기 설정의 포함 목록이 싣는다).
    'data/licenses/FluentEmoji-MIT.txt',
    'data/licenses/AdMob-MIT.txt',
    'addons/seorilabs_game/fonts/Fredoka-OFL.txt',
    'addons/seorilabs_game/fonts/Jua-OFL.txt',
    'addons/seorilabs_game/fonts/NotoSansKR-OFL.txt',
    'addons/seorilabs_game/fonts/NotoSansMono-OFL.txt',
)
TIMEOUT_SECONDS = 600


def expected_svgs(project):
    """그림 폴더에 있는 SVG의 res:// 경로."""
    paths = []
    for folder in SVG_FOLDERS:
        paths.extend('res://' + path.relative_to(project).as_posix() for path in sorted((project / folder).glob('*.svg')))
    return paths


def problems_in(names, pack_text, project):
    """묶음의 파일 목록(names)과 묶음 안의 SVG 원문 묶음 글자(pack_text)에서 문제를 찾는다."""
    found = []
    for name in RAW_FILES:
        if name not in names:
            found.append('not in the export: ' + name)
    if pack_text is not None:
        if pack_text != (project / SVG_PACK).read_text(encoding='utf-8'):
            found.append('the exported SVG pack differs from ' + SVG_PACK)
        try:
            sources = json.loads(pack_text).get('sources', {})
        except ValueError:
            sources = {}
            found.append('the exported SVG pack is not JSON')
        for path in expected_svgs(project):
            if not sources.get(path, '').lstrip().startswith('<svg'):
                found.append('no SVG text for ' + path)
            # 테마(theme.tres)는 같은 경로의 가져온 텍스처를 참조하므로 그것도 실려 있어야 한다.
            if path[len('res://'):] + '.import' not in names:
                found.append('imported texture missing for ' + path)
    items = json.loads((project / 'data/content/items.json').read_text(encoding='utf-8'))['items']
    for item in items:
        if 'game/assets/icons/%s.png.import' % item['icon'] not in names:
            found.append('card picture missing: ' + item['icon'])
    for sound in sorted((project / 'game/assets/audio').rglob('*')):
        if sound.suffix in ('.wav', '.ogg') and sound.relative_to(project).as_posix() + '.import' not in names:
            found.append('sound missing: ' + sound.relative_to(project).as_posix())
    return found


def export_pack(project, target):
    """자료 묶음을 만든다. (종료 코드, 로그)를 돌려준다."""
    godot = os.environ.get('GODOT', 'godot')
    log = ''
    for command in ([godot, '--headless', '--path', str(project), '--import', '--quit-after', '2'],
                    [godot, '--headless', '--path', str(project), '--export-pack', PRESET, str(target)]):
        done = subprocess.run(command, capture_output=True, text=True, timeout=TIMEOUT_SECONDS)
        log += done.stdout + done.stderr
        if done.returncode:
            return done.returncode, log
    return 0, log


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--out', type=Path, help='묶음을 둘 폴더(build/ 아래). 주지 않으면 build/export-pack 아래에 새로 만든다')
    args = parser.parse_args()
    project = ROOT / 'godot'
    out = (args.out or ROOT / 'build/export-pack' / uuid.uuid4().hex).resolve()
    if not out.is_relative_to(ROOT / 'build'):
        parser.error('output must be under build/')
    out.mkdir(parents=True, exist_ok=True)
    target = out / 'pack.zip'
    code, log = export_pack(project, target)
    (out / 'export.log').write_text(log)
    if code or not target.is_file():
        print('export failed (exit %d)\n%s' % (code, log[-3000:]))
        return 1
    with zipfile.ZipFile(target) as archive:
        names = set(archive.namelist())
        pack_text = archive.read(SVG_PACK).decode('utf-8') if SVG_PACK in names else None
    found = problems_in(names, pack_text, project)
    for problem in found[:40]:
        print('  ' + problem)
    print(json.dumps({'ok': not found, 'preset': PRESET, 'files': len(names), 'svgSources': len(expected_svgs(project)),
                      'problems': len(found), 'output': str(target.relative_to(ROOT))}))
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
