#!/usr/bin/env python3
"""
Build a multi-arch ipk for luci-app-modemserver.
Extracts binaries from three arch-specific ipk files (aarch64/x86_64/armv7),
packages them into a single 'all' architecture ipk with arch-detect postinst.
Uses system 'tar' command for correct GNU tar format.
"""
import os, sys, tarfile, io, gzip, shutil, subprocess

PKG_DIR = os.environ.get('PKG_DIR', '/tmp/pkg')
OUT_DIR = '/tmp/all-binaries'
os.makedirs(OUT_DIR, exist_ok=True)

PKG_VERSION = '1.1.5'
PKG_RELEASE = '1'

CONTROL = (
    "Package: luci-app-modemserver\n"
    "Version: {pv}-{pr}\n"
    "Depends: lua, luci-compat, kmod-usb-core, kmod-usb-net, "
    "kmod-usb-serial-option, kmod-usb-acm, kmod-usb-wdm, "
    "kmod-usb-net-cdc-ether, kmod-usb-net-cdc-mbim, "
    "kmod-usb-net-cdc-ncm, kmod-usb-net-qmi-wwan\n"
    "Conflicts: usb-modeswitch\n"
    "Replaces: usb-modeswitch\n"
    "Section: luci\n"
    "Priority: optional\n"
    "Maintainer: 有房大佬\n"
    "Architecture: all\n"
    "Source: https://github.com/a10463981/modem-5g\n"
    "Description: 5G Modem Server Management Interface (ALL Architectures)\n"
).format(pv=PKG_VERSION, pr=PKG_RELEASE)

POSTINST = (
    "#!/bin/sh\n"
    "ARCH=$(uname -m)\n"
    "case \"$ARCH\" in\n"
    "  aarch64|arm64) BINSUFFIX=\"aarch64\" ;;\n"
    "  armv7l|arm|armv7) BINSUFFIX=\"armv7\" ;;\n"
    "  x86_64) BINSUFFIX=\"x86_64\" ;;\n"
    "  *) BINSUFFIX=\"aarch64\" ;;\n"
    "esac\n"
    "for bin in modemserver quectel-CM-M sendat tom_modem; do\n"
    "  if [ -f /usr/bin/${bin}.${BINSUFFIX} ]; then\n"
    "    cp -f /usr/bin/${bin}.${BINSUFFIX} /usr/bin/${bin}\n"
    "    chmod 0755 /usr/bin/${bin}\n"
    "  fi\n"
    "done\n"
    "chmod +x /etc/init.d/modemserver /etc/init.d/modemsrv_helper /etc/init.d/usbmode\n"
    "/etc/init.d/modemsrv_helper enable 2>/dev/null\n"
    "/etc/init.d/modemserver enable 2>/dev/null\n"
    "/etc/init.d/usbmode enable 2>/dev/null\n"
    "/etc/init.d/modemsrv_helper start 2>/dev/null\n"
    "/etc/init.d/modemserver start 2>/dev/null\n"
    "exit 0\n"
)

def run(cmd, check=True):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"CMD FAILED: {' '.join(cmd)}")
        print(result.stdout)
        print(result.stderr)
        sys.exit(1)
    return result

def make_tar(src_dir, out_tar_gz, compresslevel=9):
    """Create a proper GNU tar.gz using system tar command."""
    # Copy source to temp dir to control structure
    tmp_dir = '/tmp/tar_src_' + str(os.getpid())
    if os.path.exists(tmp_dir):
        shutil.rmtree(tmp_dir)
    os.makedirs(tmp_dir)

    # Copy contents of src_dir preserving structure
    for item in os.listdir(src_dir):
        src = os.path.join(src_dir, item)
        dst = os.path.join(tmp_dir, item)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Create tar with GNU format
    tar_path = out_tar_gz.replace('.gz', '')
    run(['tar', '-cf', tar_path, '-C', tmp_dir, '.'])
    shutil.rmtree(tmp_dir)

    # Gzip it
    run(['gzip', '-'+str(min(compresslevel, 9)), '-f', tar_path])

def build_ipk(ctrl_tar_gz, data_tar_gz, out_path):
    """Build an ipk (ar format) from control and data tarballs."""
    with open(ctrl_tar_gz, 'rb') as f:
        ctrl_data = f.read()
    with open(data_tar_gz, 'rb') as f:
        data_gz = f.read()

    debian_binary = b'2.0\n'

    with open(out_path, 'wb') as f:
        f.write(b'!<arch>\n')
        for name, data in [
            ('debian-binary', debian_binary),
            ('control.tar.gz', ctrl_data),
            ('data.tar.gz', data_gz),
        ]:
            # ar global header: 16-byte name, 12-byte mtime, 6-byte uid, 6-byte gid,
            # 8-byte mode, 10-byte size, 2-byte magic `LF
            hdr = '%-16s%-12d%-6d%-6d%-8o%-10d`\n' % (
                name, 0, 0, 0, 0o100644, len(data)
            )
            f.write(hdr.encode('ascii'))
            f.write(data)
            if len(data) % 2:
                f.write(b'\n')

def main():
    print(f"PKG_DIR={PKG_DIR}")
    print(f"OUT_DIR={OUT_DIR}")

    # Verify PKG_DIR has expected structure
    if not os.path.isdir(PKG_DIR):
        print(f"ERROR: PKG_DIR does not exist: {PKG_DIR}")
        sys.exit(1)

    # List contents
    print("PKG_DIR contents:", os.listdir(PKG_DIR))

    # --- Build control.tar.gz ---
    ctrl_files_dir = '/tmp/ctrl_files'
    if os.path.exists(ctrl_files_dir):
        shutil.rmtree(ctrl_files_dir)
    os.makedirs(ctrl_files_dir)

    # Write control file
    with open(os.path.join(ctrl_files_dir, 'control'), 'w') as f:
        f.write(CONTROL)

    # Write postinst script
    postinst_path = os.path.join(ctrl_files_dir, 'postinst')
    with open(postinst_path, 'w') as f:
        f.write(POSTINST)
    os.chmod(postinst_path, 0o755)

    ctrl_tar_gz = '/tmp/control.tar.gz'
    make_tar(ctrl_files_dir, ctrl_tar_gz)
    print(f"control.tar.gz: {os.path.getsize(ctrl_tar_gz)} bytes")

    # --- Build data.tar.gz ---
    data_tar_gz = '/tmp/data.tar.gz'
    make_tar(PKG_DIR, data_tar_gz)
    print(f"data.tar.gz: {os.path.getsize(data_tar_gz)} bytes")

    # --- Build ipk ---
    ipk_path = os.path.join(OUT_DIR, f'luci-app-modemserver_{PKG_VERSION}-{PKG_RELEASE}_all.ipk')
    build_ipk(ctrl_tar_gz, data_tar_gz, ipk_path)

    size = os.path.getsize(ipk_path)
    print(f"SUCCESS: {size} bytes -> {ipk_path}")

    # Verify ipk structure
    with open(ipk_path, 'rb') as f:
        magic = f.read(8)
    print(f"ipk magic: {magic}")
    assert magic == b'!<arch>\n', f"Bad magic: {magic}"

    # Cleanup temp files
    shutil.rmtree(ctrl_files_dir)
    os.remove(ctrl_tar_gz)
    os.remove(data_tar_gz)

if __name__ == '__main__':
    main()
