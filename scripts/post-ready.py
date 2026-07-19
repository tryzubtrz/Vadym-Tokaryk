#!/usr/bin/env python3
"""Пост-налаштування через RCON: власники, prison, reload BW."""
from __future__ import annotations

import os
import socket
import struct
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RCON_PASS = (ROOT / "config/rcon.password").read_text().strip()
OWNERS = [l.strip() for l in (ROOT / "config/owners.txt").read_text().splitlines() if l.strip()]

RCON_PORTS = {
    "lobby": 25580,
    "minigames": 25581,
    "survival": 25582,
    "skyblock": 25583,
    "prison": 25584,
    "factions": 25585,
}


def offline_uuid(name: str) -> uuid.UUID:
    return uuid.uuid3(uuid.NAMESPACE_DNS, f"OfflinePlayer:{name}")


class RCON:
    def __init__(self, host: str, port: int, password: str):
        self.sock = socket.create_connection((host, port), timeout=8)
        self.req_id = 1
        self._login(password)

    def _send(self, req_type: int, payload: str) -> bytes:
        data = payload.encode("utf-8") + b"\x00\x00"
        pkt = struct.pack("<ii", self.req_id, req_type) + data
        self.sock.sendall(struct.pack("<i", len(pkt)) + pkt)
        # read response
        def read_exact(n):
            buf = b""
            while len(buf) < n:
                chunk = self.sock.recv(n - len(buf))
                if not chunk:
                    raise ConnectionError("rcon closed")
                buf += chunk
            return buf

        (length,) = struct.unpack("<i", read_exact(4))
        body = read_exact(length)
        return body

    def _login(self, password: str):
        self._send(3, password)

    def cmd(self, command: str) -> str:
        self.req_id += 1
        body = self._send(2, command)
        # skip ids
        return body[8:].split(b"\x00")[0].decode("utf-8", errors="replace")

    def close(self):
        try:
            self.sock.close()
        except Exception:
            pass


def try_rcon(server: str, commands: list[str]) -> None:
    port = RCON_PORTS[server]
    for attempt in range(8):
        try:
            r = RCON("127.0.0.1", port, RCON_PASS)
            for c in commands:
                out = r.cmd(c)
                print(f"[{server}] > {c}")
                if out.strip():
                    print(f"[{server}] < {out[:300]}")
            r.close()
            return
        except Exception as e:
            print(f"[{server}] rcon retry {attempt+1}: {e}")
            time.sleep(5)
    print(f"[{server}] RCON недоступний")


def write_owner_users():
    users = ROOT / "shared/luckperms/yaml-storage/users"
    users.mkdir(parents=True, exist_ok=True)
    for name in OWNERS:
        u = offline_uuid(name)
        path = users / f"{u}.yml"
        path.write_text(
            f"uuid: {u}\n"
            f"name: {name}\n"
            f"primary-group: owner\n"
            f"parents:\n"
            f"- owner\n"
            f"permissions:\n"
            f"- '*': true\n",
            encoding="utf-8",
        )
        print(f"LP owner: {name} -> {u}")


def main():
    write_owner_users()
    # ops.json на кожному сервері
    for server in RCON_PORTS:
        ops = [
            {
                "uuid": str(offline_uuid(name)),
                "name": name,
                "level": 4,
                "bypassesPlayerLimit": True,
            }
            for name in OWNERS
        ]
        import json

        (ROOT / f"servers/{server}/ops.json").write_text(
            json.dumps(ops, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    # Reload LP + essentials
    for server in RCON_PORTS:
        try_rcon(
            server,
            [
                "lp sync",
                "lp reload",
                "essentials reload",
            ],
        )

    # Minigames: reload BedWars після побудови арени
    try_rcon(
        "minigames",
        [
            "bw reload",
            "bw list",
        ],
    )

    # Prison autoConfigure (потребує економіку Essentials)
    try_rcon(
        "prison",
        [
            "ranks autoConfigure",
        ],
    )

    print("post-ready завершено")


if __name__ == "__main__":
    main()
