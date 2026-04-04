#!/usr/bin/env python3
"""
Build and convert luci-app-modemserver ipk files:
1. Converts SDK tar.gz output to proper ar-format ipk
2. Builds multi-arch all-in-one ipk with arch-detect postinst
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
        print(result.stdout[-200:])
        print(result.stderr[-200:])
    return result

def tar_to_ar(tar_gz_path, ar_path):
    """Convert a tar.gz (as produced by OpenWrt SDK) to ar-format ipk."""
    # Read tar.gz
    with open(tar_gz_path, 'rb') as f:
        tar_gz = f.read()
    tar_data = gzip.decompress(tar_gz)
    tar_buf = io.BytesIO(tar_data)

    members = {}
    with tarfile.open(fileobj=tar_buf, mode='r') as tf:
        for member in tf.getmembers():
            f = tf.extractfile(member)
            if f is not None:
                members[member.name] = f.read()

    # Write ar archive
    debian_binary = b'2.0\n'
    with open(ar_path, 'wb') as f:
        f.write(b'!<arch>\n')
        for name, data in [
            ('debian-binary', debian_binary),
            ('control.tar.gz', members.get('./control.tar.gz', b'')),
            ('data.tar.gz', members.get('./data.tar.gz', b'')),
        ]:
            hdr = '%-16s%-12d%-6d%-6d%-8o%-10d`\n' % (
                name, 0, 0, 0, 0o100644, len(data)
            )
            f.write(hdr.encode('ascii'))
            f.write(data)
            if len(data) % 2:
                f.write(b'\n')
    return ar_path

def make_tar(src_dir, out_tar_gz, compresslevel=9):
    tmp_dir = '/tmp/tar_src_' + str(os.getpid())
    if os.path.exists(tmp_dir):
        shutil.rmtree(tmp_dir)
    os.makedirs(tmp_dir)
    for item in os.listdir(src_dir):
        src = os.path.join(src_dir, item)
        dst = os.path.join(tmp_dir, item)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    run(['tar', '-cf', out_tar_gz.replace('.gz', ''), '-C', tmp_dir, '.'])
    shutil.rmtree(tmp_dir)
    run(['gzip', '-'+str(min(compresslevel, 9)), '-f', out_tar_gz.replace('.gz', '')])

def build_ipk(ctrl_tar_gz, data_tar_gz, out_path):
    with open(ctrl_tar_gz, 'rb') as f:
        ctrl_data = f.read()
    with open(data_tar_gz, 'rb') as f:
        data_gz = f.read()
    ctrl_gz = gzip.compress(ctrl_data, compresslevel=9)
    debian_binary = b'2.0\n'
    with open(out_path, 'wb') as f:
        f.write(b'!<arch>\n')
        for name, data in [
            ('debian-binary', debian_binary),
            ('control.tar.gz', ctrl_gz),
            ('data.tar.gz', data_gz),
        ]:
            hdr = '%-16s%-12d%-6d%-6d%-8o%-10d`\n' % (
                name, 0, 0, 0, 0o100644, len(data)
            )
            f.write(hdr.encode('ascii'))
            f.write(data)
            if len(data) % 2:
                f.write(b'\n')

def build_all_arch_ipk():
    """Build the all-in-one ipk from the PKG_DIR contents."""
    ctrl_files_dir = '/tmp/ctrl_files'
    if os.path.exists(ctrl_files_dir):
        shutil.rmtree(ctrl_files_dir)
    os.makedirs(ctrl_files_dir)
    with open(os.path.join(ctrl_files_dir, 'control'), 'w') as f:
        f.write(CONTROL)
    postinst_path = os.path.join(ctrl_files_dir, 'postinst')
    with open(postinst_path, 'w') as f:
        f.write(POSTINST)
    os.chmod(postinst_path, 0o755)
    ctrl_tar_gz = '/tmp/control.tar.gz'
    make_tar(ctrl_files_dir, ctrl_tar_gz)
    data_tar_gz = '/tmp/data.tar.gz'
    make_tar(PKG_DIR, data_tar_gz)
    ipk_path = os.path.join(OUT_DIR, f'luci-app-modemserver_{PKG_VERSION}-{PKG_RELEASE}_all.ipk')
    build_ipk(ctrl_tar_gz, data_tar_gz, ipk_path)
    shutil.rmtree(ctrl_files_dir)
    os.remove(ctrl_tar_gz)
    os.remove(data_tar_gz)
    print(f"ALL: {os.path.getsize(ipk_path)} bytes -> {ipk_path}")
    return ipk_path

def convert_arch_ipk(arch, tar_gz_path):
    """Convert an SDK tar.gz ipk to ar-format ipk."""
    ar_path = os.path.join(OUT_DIR, f'luci-app-modemserver_{PKG_VERSION}-{PKG_RELEASE}_{arch}.ipk')
    tar_to_ar(tar_gz_path, ar_path)
    print(f"CONVERTED {arch}: {os.path.getsize(ar_path)} bytes -> {ar_path}")
    return ar_path

if __name__ == '__main__':
    print(f"PKG_DIR={PKG_DIR}, OUT_DIR={OUT_DIR}")

    if not os.path.isdir(PKG_DIR):
        print(f"ERROR: PKG_DIR does not exist: {PKG_DIR}")
        sys.exit(1)

    # Convert SDK tar.gz outputs to ar-format ipks
    for arch, sdk_path in [
        ('aarch64_cortex-a53', '/tmp/all-binaries/aarch64'),
        ('x86_64', '/tmp/all-binaries/x86_64'),
        ('arm_cortex-a15_neon-vfpv4', '/tmp/all-binaries/armv7'),
    ]:
        ipk_in_sdk = None
        if os.path.isdir(sdk_path):
            for f in os.listdir(sdk_path):
                if f.endswith('.ipk'):
                    ipk_in_sdk = os.path.join(sdk_path, f)
                    break
        if ipk_in_sdk and os.path.exists(ipk_in_sdk):
            # Check format
            with open(ipk_in_sdk, 'rb') as f:
                magic = f.read(2)
            if magic == b'\x1f\x8b':  # gzip
                convert_arch_ipk(arch, ipk_in_sdk)
            else:
                # Already ar-format, copy as-is
                shutil.copy2(ipk_in_sdk, os.path.join(OUT_DIR, os.path.basename(ipk_in_sdk)))
                print(f"COPY {arch}: {os.path.getsize(ipk_in_sdk)} bytes")

    # Build all-in-one ipk
    build_all_arch_ipk()

    # Verify all ipks are ar-format
    print("\n=== Verification ===")
    for f in sorted(os.listdir(OUT_DIR)):
        if f.endswith('.ipk'):
            path = os.path.join(OUT_DIR, f)
            with open(path, 'rb') as fh:
                m = fh.read(8)
            ok = m == b'!<arch>\n'
            print(f"{'OK' if ok else 'BAD'} {f} (magic={m[:8]})")
            if not ok:
                sys.exit(1)
    print("All ipks valid!")
