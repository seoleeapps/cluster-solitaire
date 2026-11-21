#!/usr/bin/env python3
"""Export the signed Android AAB using local Godot and signing settings."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import check_native
ROOT=Path(__file__).resolve().parents[1]
def run(command, timeout):
    result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=timeout)
    log=result.stdout+result.stderr
    visible=log
    for name,value in os.environ.items():
        if value and any(word in name.upper() for word in ['PASSWORD','TOKEN','PRIVATE_KEY']):visible=visible.replace(value,'[redacted]')
    print(visible,end='')
    log=re.sub(r'\x1b\[[0-9;]*m','',log)
    if result.returncode or re.search(r'^(?:SCRIPT ERROR|ERROR:)',log,re.M):
        raise RuntimeError('Godot export failed; inspect the preceding output')
def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    errors=check_native.validate(ROOT)
    if errors:raise ValueError('\n'.join(errors))
    for name in ['GODOT_ANDROID_KEYSTORE_RELEASE_PATH','GODOT_ANDROID_KEYSTORE_RELEASE_USER','GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD']:
        if not os.environ.get(name):raise ValueError('Missing signing environment variable: '+name)
    subprocess.run(['bash',str(ROOT/'tools/install_android_build_template.sh')],cwd=ROOT,check=True)
    subprocess.run(['bash',str(ROOT/'tools/prepare_android.sh')],cwd=ROOT,check=True)
    godot=os.environ.get('GODOT','godot')
    run([godot,'--headless','--path',str(ROOT/'godot'),'--import'],180)
    # check_native has verified that this path matches the Android preset's export path.
    output=ROOT/json.loads((ROOT/'play-store/google-play.config.json').read_text())['aabPath']
    output.parent.mkdir(parents=True,exist_ok=True)
    run([godot,'--headless','--path',str(ROOT/'godot'),'--export-release','Android',str(output)],900)
    if not output.exists():raise RuntimeError('Godot did not create the expected output')
    print(output)
if __name__=='__main__':
    try:main()
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError) as error:raise SystemExit(str(error))
