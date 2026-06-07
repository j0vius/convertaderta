# -*- mode: python ; coding: utf-8 -*-

import sys
from pathlib import Path

root = Path(SPECPATH)
icon_path = root.parent / "DjayPlaylistBridge" / "Assets.xcassets" / "AppIcon.appiconset" / "icon_256x256@2x.png"

block_cipher = None

a = Analysis(
    [str(root / "app.py")],
    pathex=[str(root)],
    binaries=[],
    datas=[],
    hiddenimports=["win32com", "win32com.client"],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name="convertaderta",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=str(icon_path) if icon_path.exists() and sys.platform == "win32" else None,
)
