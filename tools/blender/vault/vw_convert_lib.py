# Vault wizard converter library: node tree -> Roblox Motor6D rig description + clip tables, and the chain pose used by the renderer and the verification.
#   Part1 = Part0 * C0 * Transform * C1^-1     (Roblox Motor6D semantics)
# Part frames are TRANSLATION-ONLY frames at the joint position (the FBX exporter bakes each node's rest rotation into its mesh), so C0 / C1 carry the rest rotation of the joint.
# Everything is expressed in Roblox space (front -Z, right +X, studs): glTF -> Roblox is a 180 degree turn about Y (CV) and positions x S.
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vw_common as C  # noqa: E402

CV = np.diag([-1.0, 1.0, -1.0, 1.0])
# nodes whose animation is not a joint of a mesh group but a VFX driver (timing only)
NEON_SUFFIX = "_Neon"


def to_roblox(M, S):
    R = CV @ M @ CV
    R[:3, 3] *= S
    return R


def cf_list(M):
    return [round(float(x), 5) for x in list(M[:3, 3]) + list(M[:3, :3].reshape(-1))]


def mesh_bbox(G, name):
    """Local bbox of a node's mesh from the accessor min/max (glTF units)."""
    n = G.N[G.byname[name]]
    prim = G.j["meshes"][n["mesh"]]["primitives"][0]
    a = G.j["accessors"][prim["attributes"]["POSITION"]]
    return np.array(a["min"]), np.array(a["max"])


def build_rig(G, S, mesh_names):
    """Derive parts, joints (Part0/Part1/C0/C1), neon welds from the node tree. Returns dict."""
    cache = {}
    groups = {}                                  # parent node -> [mesh names]
    for nm in mesh_names:
        i = G.byname[nm]
        groups.setdefault(G.parent[i], []).append(nm)
    base_of = {}                                 # parent node -> base part name
    for p, names in groups.items():
        non_neon = [n for n in names if not n.endswith(NEON_SUFFIX)]
        base_of[p] = (non_neon or names)[0]
    hrp = G.byname["HumanoidRootPart"]
    frameP = {}                                  # part -> translation-only world frame (Roblox)
    rest_rot = {}
    for nm in mesh_names:
        W = to_roblox(G.rest_world(G.byname[nm], cache), S)
        P = np.eye(4)
        P[:3, 3] = W[:3, 3]
        frameP[nm] = P
        rest_rot[nm] = W[:3, :3]
    Whrp = to_roblox(G.rest_world(hrp, cache), S)
    Phrp = np.eye(4)
    Phrp[:3, 3] = Whrp[:3, 3]
    frameP["HumanoidRootPart"] = Phrp
    joints, welds = {}, []
    order = []
    for p, base in base_of.items():
        j = G.name(p)
        anc = G.ancestors(p)
        part0 = next((base_of[a] for a in anc if a in base_of), "HumanoidRootPart")
        J = to_roblox(G.rest_world(p, cache), S)
        joints[j] = dict(node=p, part0=part0, part1=base, C0=np.linalg.inv(frameP[part0]) @ J, C1=np.linalg.inv(frameP[base]) @ J)
        for n in groups[p]:
            if n != base:
                welds.append(dict(part0=base, part1=n, C0=np.linalg.inv(frameP[base]) @ frameP[n], C1=np.eye(4)))
    # parents before children
    seen = {"HumanoidRootPart"}
    todo = dict(joints)
    while todo:
        for j in list(todo):
            if todo[j]["part0"] in seen:
                order.append(j)
                seen.add(todo[j]["part1"])
                del todo[j]
    return dict(joints=joints, welds=welds, order=order, frameP=frameP, rest_rot=rest_rot, base_of=base_of, groups=groups)


def local_R(G, S, node, tracks, t, rest=False):
    """Parent-relative TRS of a node, in Roblox space, as 4x4 (scale ignored; reported separately)."""
    if rest:
        tr, q, s = G.rest(node)
    else:
        tr, q, s = C.sample_node(G, tracks, node, t)
    R = CV @ C.trs(tr, q, (1, 1, 1)) @ CV
    R[:3, 3] *= S
    return R, float(np.mean(s))


def joint_transform(G, S, node, tracks, t):
    Lrest, _ = local_R(G, S, node, tracks, t, rest=True)
    Lanim, s = local_R(G, S, node, tracks, t)
    return np.linalg.inv(Lrest) @ Lanim, s


def chain_pose(data, clip, t):
    """Pose every part from the converted JSON (no glTF involved). Returns part -> 4x4 NODE frame in Roblox space (part frame x rest rotation, so node-local meshes sit right)."""
    S = data["studs_per_unit"]
    P = {"HumanoidRootPart": np.array(data["hrp_frame"]).reshape(4, 4)}
    cl = data["clips"][clip]

    def mat(cf):
        M = np.eye(4)
        M[:3, 3] = cf[:3]
        M[:3, :3] = np.array(cf[3:12]).reshape(3, 3)
        return M
    for jn in data["order"]:
        j = data["joints"][jn]
        T = np.eye(4)
        tr = cl["joints"].get(jn)
        if tr:
            k = tr["keys"]
            ts = np.array([x[0] for x in k])
            tt = min(max(t, ts[0]), ts[-1])
            a = int(np.searchsorted(ts, tt, side="right") - 1)
            a = min(max(a, 0), len(k) - 2) if len(k) > 1 else 0
            b = min(a + 1, len(k) - 1)
            u = 0.0 if ts[b] == ts[a] else (tt - ts[a]) / (ts[b] - ts[a])
            q = C.slerp(np.array(k[a][1:5]), np.array(k[b][1:5]), u)
            T = np.eye(4)
            T[:3, :3] = C.q2m(q)
            if tr.get("pos"):
                T[:3, 3] = np.array(k[a][5:8]) + u * (np.array(k[b][5:8]) - np.array(k[a][5:8]))
        P[j["part1"]] = P[j["part0"]] @ mat(j["C0"]) @ T @ np.linalg.inv(mat(j["C1"]))
    out = {}
    for part, M in P.items():
        if part == "HumanoidRootPart":
            continue
        R4 = np.eye(4)
        R4[:3, :3] = np.array(data["rest_rot"][part]).reshape(3, 3)
        out[part] = M @ R4
    for w in data["welds"]:
        if w["part0"] in P:
            Mw = P[w["part0"]] @ mat(w["C0"])
            R4 = np.eye(4)
            R4[:3, :3] = np.array(data["rest_rot"][w["part1"]]).reshape(3, 3)
            out[w["part1"]] = Mw @ R4
    return out


def scales_at(data, clip, t):
    """{part: uniform scale} of animated parts (the halo) at time t, including their neon welds."""
    out = {}
    for part, sc in data["clips"][clip].get("scales", {}).items():
        ts = [k[0] for k in sc]
        tt = min(max(t, ts[0]), ts[-1])
        v = float(np.interp(tt, ts, [k[1] for k in sc]))
        out[part] = v
        for w in data["welds"]:
            if w["part0"] == part:
                out[w["part1"]] = v
    return out
