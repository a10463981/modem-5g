#!/usr/bin/env python3
"""
Build aarch64/x86_64/armv7 multi-arch ipk for luci-app-modemserver.
This script extracts binaries from the three architecture-specific ipk files
and packages them into a single 'all' architecture ipk with an arch-detect postinst.
"""
import os, sys, tarfile, io, gzip

PKG_DIR = os.environ.get('PKG_DIR', '/tmp/pkg')
PKG_VERSION = '1.1.5'
PKG_RELEASE = '1'

CONTROL = """\
Package: luci-app-modemserver
Version: {pv}-{pr}
Depends: lua, luci-compat, kmod-usb-core, kmod-usb-net, kmod-usb-serial-option, kmod-usb-acm, kmod-usb-wdm, kmod-usb-net-cdc-ether, kmod-usb-net-cdc-mbim, kmod-usb-net-cdc-ncm, kmod-usb-net-qmi-wwan
Conflicts: usb-modeswitch
Replaces: usb-modeswitch
Section: luci
Priority: optional
Maintainer: 有房大佬
Architecture: all
Source: https://github.com/a10463981/modem-5g
Description: 5G Modem Server Management Interface (ALL Architectures)
""".format(pv=PKG_VERSION, pr=PKG_RELEASE)

POSTINST = """\
#!/bin/sh
ARCH=$(uname -m)
case "$ARCH" in
  aarch64|arm64) BINSUFFIX="aarch64" ;;
  armv7l|arm|armv7) BINSUFFIX="armv7" ;;
  x86_64) BINSUFFIX="x86_64" ;;
  *) BINSUFFIX="aarch64" ;;
esac
for bin in modemserver quectel-CM-M sendat tom_modem; do
  if [ -f /usr/bin/${bin}.${BINSUFFIX} ]; then
    cp -f /usr/bin/${bin}.${BINSUFFIX} /usr/bin/${bin}
    chmod 0755 /usr/bin/${bin}
  fi
done
chmod +x /etc/init.d/modemserver /etc/init.d/modemsrv_helper /etc/init.d/usbmode
/etc/init.d/modemsrv_helper enable 2>/dev/null
/etc/init.d/modemserver enable 2>/dev/null
/etc/init.d/usbmode enable 2>/dev/null
/etc/init.d/modemsrv_helper start 2>/dev/null
/etc/init.d/modemserver start 2>/dev/null
exit 0
"""

# --- Build control.tar.gz ---
ctrl_buf = io.BytesIO()
with tarfile.open(fileobj=ctrl_buf, mode='w') as tf:
    for name, content, mode in [
        ('control', CONTROL, 0o644),
        ('postinst', POSTINST, 0o755),
    ]:
        fobj = io.BytesIO(content.encode())
        info = tarfile.TarInfo(name=name)
        info.size = len(content)
        info.mode = mode
        tf.addfile(info, fobj)
ctrl_gz = gzip.compress(ctrl_buf.getvalue(), compresslevel=9)

# --- Build data.tar.gz ---
data_buf = io.BytesIO()
with tarfile.open(fileobj=data_buf, mode='w:gz', compresslevel=9) as tf:
    for root, dirs, files in os.walk(PKG_DIR):
        for fname in files:
            fpath = os.path.join(root, fname)
            arcname = os.path.relpath(fpath, PKG_DIR)
            tf.add(fpath, arcname)
data_gz = data_buf.getvalue()

# --- Write ipk (ar format) ---
debian_binary = b'2.0\n'
ipk_path = f'/tmp/all-binaries/luci-app-modemserver_{PKG_VERSION}-{PKG_RELEASE}_all.ipk'
os.makedirs('/tmp/all-binaries', exist_ok=True)

with open(ipk_path, 'wb') as f:
    f.write(b'!<arch>\n')
    for name, data in [
        ('debian-binary', debian_binary),
        ('control.tar.gz', ctrl_gz),
        ('data.tar.gz', data_gz),
    ]:
        # ar global header: name(16) time(12) uid(6) gid(6) mode(8) size(10) `magic(2)\n
        hdr = '%-16s%-12d%-6d%-6d%-8o%-10d`\n' % (name, 0, 0, 0, 0o100644, len(data))
        f.write(hdr.encode())
        f.write(data)
        if len(data) % 2:
            f.write(b'\n')

size = os.path.getsize(ipk_path)
print(f"IPK created: {size} bytes -> {ipk_path}")
sys.exit(0)
