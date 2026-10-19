"""Temporary loopback-only keyboard control for the crypto VM installer."""
import socket
import struct
import sys
import time

KEYS = {"esc": 0xFF1B, "enter": 0xFF0D, "down": 0xFF54,
        "up": 0xFF52, "end": 0xFF57, "home": 0xFF50, "f10": 0xFFC7}

with socket.create_connection(("127.0.0.1", 5995), timeout=10) as connection:
    def read_exact(count):
        value = b""
        while len(value) < count:
            block = connection.recv(count - len(value))
            if not block:
                raise RuntimeError("Console disconnected")
            value += block
        return value

    version = read_exact(12)
    if not version.startswith(b"RFB 003."):
        raise RuntimeError("Unexpected console protocol")
    connection.sendall(b"RFB 003.008\n")
    count = read_exact(1)[0]
    security_types = read_exact(count)
    if 1 not in security_types:
        raise RuntimeError("Loopback console does not offer expected security type")
    connection.sendall(b"\x01")
    if struct.unpack("!I", read_exact(4))[0] != 0:
        raise RuntimeError("Console handshake failed")
    connection.sendall(b"\x01")
    server_init = read_exact(24)
    read_exact(struct.unpack("!I", server_init[20:24])[0])

    def press(key):
        for down in (1, 0):
            connection.sendall(struct.pack("!BBHI", 4, down, 0, key))
        time.sleep(0.15)

    for argument in sys.argv[1:]:
        if argument.startswith("text:"):
            for character in argument[5:]:
                press(ord(character))
        elif argument == "ctrl-k":
            connection.sendall(struct.pack("!BBHI", 4, 1, 0, 0xFFE3))
            press(ord("k"))
            connection.sendall(struct.pack("!BBHI", 4, 0, 0, 0xFFE3))
        else:
            press(KEYS[argument])
    print("Sent installer input to crypto VM loopback console.")
