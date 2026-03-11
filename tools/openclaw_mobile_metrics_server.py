#!/usr/bin/env python3
import json
import re
import subprocess
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

HOST = '0.0.0.0'
PORT = 18790


def run(cmd):
    return subprocess.check_output(cmd, text=True).strip()


def gateway_status_json():
    return json.loads(run(['openclaw', 'status', '--json']))


def boot_time_seconds():
    txt = run(['sysctl', '-n', 'kern.boottime'])
    m = re.search(r'sec = (\d+)', txt)
    if not m:
        return 0
    return int(m.group(1))


def cpu_percent():
    try:
        txt = run(['sh', '-lc', "top -l 2 -n 0 -s 0 | grep 'CPU usage' | tail -1"])
        m = re.search(r'(\d+(?:\.\d+)?)% idle', txt)
        if not m:
            return None
        idle = float(m.group(1))
        return round(max(0.0, 100.0 - idle), 1)
    except Exception:
        return None


def memory_stats():
    vm = run(['vm_stat'])
    page_size = int(run(['sysctl', '-n', 'hw.pagesize']))
    pages = {}
    for line in vm.splitlines():
        m = re.match(r'^(.*?):\s+([0-9]+)\.$', line)
        if m:
            pages[m.group(1)] = int(m.group(2))
    free = pages.get('Pages free', 0) + pages.get('Pages speculative', 0)
    active = pages.get('Pages active', 0)
    inactive = pages.get('Pages inactive', 0)
    wired = pages.get('Pages wired down', 0)
    compressed = pages.get('Pages occupied by compressor', 0)
    used = active + inactive + wired + compressed
    total = used + free
    return used * page_size, total * page_size


def build_payload():
    st = gateway_status_json()
    gateway = st.get('gateway', {})
    self_info = gateway.get('self', {})
    mem_used, mem_total = memory_stats()
    cpu = cpu_percent()
    uptime = int(time.time() - boot_time_seconds())
    return {
        'ok': True,
        'source': 'openclaw-mobile-metrics-server',
        'gateway': {
            'status': 'online' if gateway.get('reachable') else 'offline',
            'version': self_info.get('version', 'unknown'),
            'uptime': uptime,
            'cpu_percent': cpu,
            'memory_used': mem_used,
            'memory_total': mem_total,
            'host': self_info.get('host'),
            'ip': self_info.get('ip'),
            'platform': self_info.get('platform'),
        },
        'system': {
            'cpu_percent': cpu,
            'memory': {
                'used': mem_used,
                'total': mem_total,
                'percent': round((mem_used / mem_total) * 100, 1) if mem_total else None,
            },
            'uptime': uptime,
            'uptimeMs': uptime * 1000,
            'host': self_info.get('host'),
            'platform': self_info.get('platform'),
        },
        'ts': int(time.time()),
    }


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path in ('/health', '/status', '/metrics'):
            payload = build_payload()
            body = json.dumps(payload).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        return


if __name__ == '__main__':
    server = HTTPServer((HOST, PORT), Handler)
    print(f'openclaw mobile metrics server listening on http://{HOST}:{PORT}', flush=True)
    server.serve_forever()
