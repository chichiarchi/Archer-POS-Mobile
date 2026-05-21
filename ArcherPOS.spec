# -*- mode: python ; coding: utf-8 -*-
import os

block_cipher = None

# Dynamically discover python-escpos capabilities.json location
escpos_cap_path = None
try:
    import escpos
    escpos_cap_path = os.path.join(os.path.dirname(escpos.__file__), 'capabilities.json')
except ImportError:
    pass

added_files = [
    ('archer_logo.png', '.'),
    ('archer_logo.ico', '.'),
    ('up_arrow.svg', '.'),
    ('down_arrow.svg', '.'),
]

if escpos_cap_path and os.path.exists(escpos_cap_path):
    added_files.append((escpos_cap_path, 'escpos'))
else:
    # Fallback to common virtualenv locations
    possible_paths = [
        '.venv/Lib/site-packages/escpos/capabilities.json',
        'archer/lib/python3.12/site-packages/escpos/capabilities.json',
        'archer/lib/site-packages/escpos/capabilities.json',
    ]
    for p in possible_paths:
        if os.path.exists(p):
            added_files.append((p, 'escpos'))
            break

a = Analysis(
    ['app.py'],
    pathex=[],
    binaries=[],
    datas=added_files,
    hiddenimports=['PySide6.QtXml'],
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
    [],
    exclude_binaries=True,
    name='ArcherPOS',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['archer_logo.ico'],
)
coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='ArcherPOS',
)
