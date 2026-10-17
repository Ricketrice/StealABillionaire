# Shared helpers for the Vault wizard pipeline (numpy only, so it runs inside Blender and in plain python3).
# GLB reading, node tree, animation sampling, forward kinematics. glTF space: +Y up, front +Z, character right -X (Roblox is front -Z, right +X = a 180 degree turn about Y).
import json
import math
import os
import struct

import numpy as np

HOME = os.path.expanduser("~")
GLB = os.environ.get("VAULT_GLB", os.path.join(HOME, "Pictures/035_preview/concept/Vault.glb"))
WORK = os.environ.get("VAULT_WORK", os.path.join(HOME, "Pictures/035_preview/vault2"))
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
EXPORT = os.path.join(REPO, "assets", "export", "vault")
CLIP_ORDER = ["Idle", "Walk", "Steal_Grab", "Normal_Repossess", "Event_MarketCrash", "Event_VaultLock", "Event_HostileTakeover", "Event_BankruptNova"]
FPS = 24.0
JOINTS = ["Root", "Waist", "Neck", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist", "LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle"]


def q2m(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def m2q(R):
    R = np.asarray(R, float)
    t = np.trace(R)
    if t > 0:
        s = math.sqrt(t + 1) * 2
        q = np.array([(R[2, 1] - R[1, 2]) / s, (R[0, 2] - R[2, 0]) / s, (R[1, 0] - R[0, 1]) / s, s / 4])
    else:
        i = int(np.argmax(np.diag(R)))
        j, k = (i + 1) % 3, (i + 2) % 3
        s = math.sqrt(R[i, i] - R[j, j] - R[k, k] + 1) * 2
        q = np.zeros(4)
        q[i] = s / 4
        q[3] = (R[k, j] - R[j, k]) / s
        q[j] = (R[j, i] + R[i, j]) / s
        q[k] = (R[k, i] + R[i, k]) / s
    return q / np.linalg.norm(q)


def qmul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return np.array([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2, w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2])


def qconj(q):
    return np.array([-q[0], -q[1], -q[2], q[3]])


def axis_angle_q(axis, ang):
    a = np.asarray(axis, float)
    a = a / np.linalg.norm(a)
    s = math.sin(ang / 2)
    return np.array([a[0] * s, a[1] * s, a[2] * s, math.cos(ang / 2)])


def trs(t, q, s=(1, 1, 1)):
    M = np.eye(4)
    M[:3, :3] = q2m(q) @ np.diag(s)
    M[:3, 3] = t
    return M


def slerp(a, b, u):
    if np.dot(a, b) < 0:
        b = -b
    dp = min(1.0, float(np.dot(a, b)))
    if dp > 0.9995:
        r = a + u * (b - a)
        return r / np.linalg.norm(r)
    th = math.acos(dp)
    return (math.sin((1 - u) * th) * a + math.sin(u * th) * b) / math.sin(th)


class Glb:
    def __init__(self, path=GLB):
        d = open(path, "rb").read()
        cl, _ = struct.unpack("<II", d[12:20])
        self.j = json.loads(d[20:20 + cl])
        self.bin0 = 20 + cl + 8
        self.d = d
        self.N = self.j["nodes"]
        self.parent = {}
        for i, n in enumerate(self.N):
            for c in n.get("children", []):
                self.parent[c] = i
        self.byname = {n.get("name"): i for i, n in enumerate(self.N)}
        self.clips = {a["name"]: a for a in self.j["animations"]}
        self._acc = {}

    def acc(self, i):
        if i in self._acc:
            return self._acc[i]
        a = self.j["accessors"][i]
        bv = self.j["bufferViews"][a["bufferView"]]
        off = self.bin0 + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        c = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
        n = a["count"] * c
        v = np.array(struct.unpack_from("<%df" % n, self.d, off), dtype=np.float64).reshape(a["count"], c)
        self._acc[i] = v
        return v

    def image_bytes(self, idx):
        bv = self.j["bufferViews"][self.j["images"][idx]["bufferView"]]
        o = self.bin0 + bv.get("byteOffset", 0)
        return self.d[o:o + bv["byteLength"]]

    def rest(self, i):
        n = self.N[i]
        return np.array(n.get("translation", [0, 0, 0]), float), np.array(n.get("rotation", [0, 0, 0, 1]), float), np.array(n.get("scale", [1, 1, 1]), float)

    def name(self, i):
        return self.N[i].get("name")

    def ancestors(self, i):
        out = []
        while i in self.parent:
            i = self.parent[i]
            out.append(i)
        return out

    def duration(self, clip):
        a = self.clips[clip]
        return max(self.j["accessors"][s["input"]]["max"][0] for s in a["samplers"])

    def tracks(self, clip):
        """{node index: {path: (times, values)}}"""
        a = self.clips[clip]
        out = {}
        for ch in a["channels"]:
            s = a["samplers"][ch["sampler"]]
            out.setdefault(ch["target"]["node"], {})[ch["target"]["path"]] = (self.acc(s["input"])[:, 0], self.acc(s["output"]))
        return out

    def rest_world(self, i, cache=None):
        cache = {} if cache is None else cache
        if i in cache:
            return cache[i]
        t, q, s = self.rest(i)
        M = trs(t, q, s)
        w = self.rest_world(self.parent[i], cache) @ M if i in self.parent else M
        cache[i] = w
        return w


def sample_path(T, V, t, path):
    tt = min(max(t, T[0]), T[-1])
    k = int(np.searchsorted(T, tt, side="right") - 1)
    k = min(max(k, 0), len(T) - 2)
    u = 0.0 if T[k + 1] == T[k] else (tt - T[k]) / (T[k + 1] - T[k])
    if path == "rotation":
        return slerp(V[k], V[k + 1], u)
    return V[k] + u * (V[k + 1] - V[k])


def sample_node(G, tracks, i, t):
    tr, q, s = G.rest(i)
    for path, (T, V) in tracks.get(i, {}).items():
        v = sample_path(T, V, t, path)
        if path == "rotation":
            q = v
        elif path == "translation":
            tr = v
        else:
            s = v
    return tr, q, s


def world_of(G, i, local_fn, cache):
    """local_fn(node) -> (t, q, s); returns the 4x4 world matrix (glTF space)."""
    if i in cache:
        return cache[i]
    t, q, s = local_fn(i)
    M = trs(t, q, s)
    w = world_of(G, G.parent[i], local_fn, cache) @ M if i in G.parent else M
    cache[i] = w
    return w


def shade_by_angle(me, deg=35.0):
    """Smooth faces, hard edges where adjacent faces differ by more than deg (keeps boxy corners crisp, round parts smooth). Blender mesh in, in place."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    lim = math.radians(deg)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2:
            e.smooth = e.calc_face_angle(0) < lim
        else:
            e.smooth = False
    bm.to_mesh(me)
    bm.free()
