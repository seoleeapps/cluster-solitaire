#!/usr/bin/env python3
"""Validate the Android export identity, portrait display, signing boundaries and release resource exclusions."""
import configparser
import hashlib
import json
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
# Web is the only non-native preset. Native targets are Android (Google Play) and iOS (App Store).
PRESET_PLATFORMS=('Android','Web','iOS')
ADMOB_PLUGIN='res://addons/admob/plugin.cfg'
SERVICE_VALUES='godot/data/services/release.json'
def load_presets(root):
    cfg=configparser.ConfigParser(interpolation=None,strict=True)
    cfg.optionxform=str
    cfg.read(root/'godot/export_presets.cfg')
    return cfg
def value(cfg,section,key):
    try:return json.loads(cfg.get(section,key))
    except (ValueError,configparser.Error):return None
def load_project(root):
    """Read project.godot as {section: {key: raw text}}. Godot writes dictionaries over several lines, which configparser rejects."""
    sections={};section=None;key=None
    for line in (root/'godot/project.godot').read_text().splitlines():
        header=re.fullmatch(r'\[([^\]]+)\]',line);entry=re.match(r'([A-Za-z0-9_/.]+)=(.*)',line)
        if header:section=sections.setdefault(header.group(1),{});key=None
        elif section is not None and entry:key=entry.group(1);section[key]=entry.group(2)
        elif section is not None and key and line.strip() and not line.startswith(';'):section[key]+='\n'+line
    return sections
def project_value(project,section,key):
    try:return json.loads(project[section][key])
    except (ValueError,KeyError):return None
def validate(root):
    errors=[];cfg=load_presets(root)
    try:
        lock=json.loads((root/'native/dependencies.lock.json').read_text())
        if lock.get('schemaVersion')!=2:errors.append('Unsupported native dependency lock schema')
        for entry in lock['sources']['admob']['localPatches']:
            path=root/entry['file']
            if hashlib.sha256(path.read_bytes()).hexdigest()!=entry['sha256']:
                errors.append('Native source patch hash mismatch: '+entry['file'])
    except (OSError,ValueError,KeyError,TypeError) as error:
        errors.append('Invalid native dependency lock: '+type(error).__name__)
    project=load_project(root)
    if project_value(project,'rendering','textures/vram_compression/import_etc2_astc') is not True:errors.append('Mobile texture import must be enabled for native exports')
    # The AdMob editor plugin adds the native library, its dependencies and the app ID to the Android build.
    if ADMOB_PLUGIN not in project.get('editor_plugins',{}).get('enabled',''):errors.append('The AdMob editor plugin must be enabled in project.godot')
    # The app ID and the service values are injected for one release build and removed afterwards (tools/prepare_services.py).
    if 'admob' in project:errors.append('project.godot carries an injected AdMob app ID; run python3 tools/prepare_services.py --restore')
    if (root/SERVICE_VALUES).exists():errors.append('Injected service values were left behind; run python3 tools/prepare_services.py --restore')
    ignored=(root/'.gitignore').read_text().splitlines() if (root/'.gitignore').is_file() else []
    if 'godot/data/services/' not in ignored:errors.append('.gitignore must exclude godot/data/services/')
    # Godot 4 takes the Android screen orientation from the project display settings, not from the export preset.
    # The common flow draws portrait screens at a fixed scale, so the logical size stays 390x844 and only the height grows.
    display={key:project_value(project,'display',key) for key in ['window/size/viewport_width','window/size/viewport_height','window/handheld/orientation','window/stretch/mode','window/stretch/aspect']}
    if display!={'window/size/viewport_width':390,'window/size/viewport_height':844,'window/handheld/orientation':1,'window/stretch/mode':'canvas_items','window/stretch/aspect':'keep_width'}:
        errors.append('Display must be portrait 390x844 stretched by width')
    try:
        product=json.loads((root/'godot/config/product.json').read_text())
        play=json.loads((root/'play-store/google-play.config.json').read_text())
        app_store=json.loads((root/'app-store/app-store.config.json').read_text())
    except (OSError,ValueError) as error:return [str(error)]
    identity=product['id']
    if not re.fullmatch(r'[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+',identity):errors.append('Native product ID must be a reverse-DNS identifier')
    presets=[s for s in cfg.sections() if not s.endswith('.options')]
    for section in presets:
        if value(cfg,section,'platform') not in PRESET_PLATFORMS:errors.append('Unsupported export preset platform: '+str(value(cfg,section,'platform')))
    bases=[s for s in presets if value(cfg,s,'name')=='Android']
    if len(bases)!=1:errors.append('Missing or duplicate native preset: Android')
    else:
        base=bases[0];options=base+'.options'
        if value(cfg,base,'platform')!='Android':errors.append('Native preset platform mismatch')
        if value(cfg,base,'runnable') is not False:errors.append('Native automatic device discovery must stay disabled')
        exclude=value(cfg,base,'exclude_filter') or ''
        for pattern in ['tests/**','game/scenarios/**']:
            if pattern not in exclude.split(','):errors.append('Android must exclude '+pattern)
        include=value(cfg,base,'include_filter') or ''
        for license in ['addons/seorilabs_game/fonts/*-OFL.txt','addons/seorilabs_platform/LICENSE']:
            if license not in include.split(','):errors.append('Android must retain '+license)
        if value(cfg,options,'package/unique_name')!=identity or play.get('packageName')!=identity:errors.append('Android package identity mismatch')
        if value(cfg,options,'package/name')!=product['name'] or play.get('appName')!=product['name']:errors.append('Android display name mismatch')
        if value(cfg,options,'gradle_build/export_format')!=1 or value(cfg,options,'gradle_build/use_gradle_build') is not True:errors.append('Android must export a Gradle AAB')
        if int(value(cfg,options,'gradle_build/target_sdk') or 0)<36:errors.append('Android target SDK must be at least 36')
        if value(cfg,options,'package/signed') is not True:errors.append('Android release signing must be enabled')
        for permission in ['internet','vibrate']:
            if value(cfg,options,'permissions/'+permission) is not True:errors.append('Android must request the '+permission+' permission')
        # Extra arguments are how a device check switches the consent geography in a debug build. They never belong in the tracked preset.
        if value(cfg,options,'command_line/extra_args'):errors.append('Android preset must not carry extra command line arguments')
        for key in ['keystore/release','keystore/release_user','keystore/release_password']:
            if value(cfg,options,key):errors.append('Signing values must come from the environment: '+key)
        if (root/'godot'/str(value(cfg,base,'export_path'))).resolve()!=(root/str(play.get('aabPath'))).resolve():errors.append('Android bundle path mismatch')
    if play.get('track')!='internal':errors.append('Uploads go to the internal track; production is reached by promotion')
    ios_bases=[s for s in presets if value(cfg,s,'name')=='iOS']
    if len(ios_bases)!=1:errors.append('Missing or duplicate native preset: iOS')
    else:
        base=ios_bases[0];options=base+'.options'
        if value(cfg,base,'platform')!='iOS':errors.append('iOS preset platform mismatch')
        if value(cfg,base,'runnable') is not False:errors.append('Native automatic device discovery must stay disabled')
        exclude=value(cfg,base,'exclude_filter') or ''
        for pattern in ['tests/**','game/scenarios/**']:
            if pattern not in exclude.split(','):errors.append('iOS must exclude '+pattern)
        include=value(cfg,base,'include_filter') or ''
        for license in ['addons/seorilabs_game/fonts/*-OFL.txt','addons/seorilabs_platform/LICENSE']:
            if license not in include.split(','):errors.append('iOS must retain '+license)
        if value(cfg,options,'application/bundle_identifier')!=identity or app_store.get('bundleId')!=identity:errors.append('iOS bundle identity mismatch')
        if value(cfg,options,'application/app_store_team_id')!=app_store.get('teamId'):errors.append('iOS team ID mismatch')
        if value(cfg,options,'privacy/tracking_enabled') is not False:errors.append('iOS non-tracking policy requires privacy/tracking_enabled=false')
        plist_extra=str(value(cfg,options,'application/additional_plist_content') or '')
        if 'NSUserTrackingUsageDescription' in plist_extra:errors.append('No-ATT iOS build must not set NSUserTrackingUsageDescription')
        if 'ITSAppUsesNonExemptEncryption' not in plist_extra:errors.append('iOS must declare ITSAppUsesNonExemptEncryption')
        for key in ['application/code_sign_identity_release','application/provisioning_profile_uuid_release','application/provisioning_profile_specifier_release']:
            if value(cfg,options,key):errors.append('iOS signing overrides must not be embedded in export_presets.cfg: '+key)
    return errors
if __name__=='__main__':
    errors=validate(ROOT)
    print(json.dumps({'ok':not errors,'errors':errors},ensure_ascii=False))
    raise SystemExit(bool(errors))
