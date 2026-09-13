# -*- coding: utf-8 -*-
"""V6.1 姿势图特效锚点离线提取（M2 返工 R3）

从每张姿势 PNG（256x256，特效烧录在图内）提取三组锚点数据，供战斗内
"完整技能释放"编排使用：
  c  特效质心（饱和x亮度xalpha 加权）——nova/周身技能生成点
  f  前向边缘点（加权 80 分位 x 切片的质心）——突刺/投射物生成点（≈武器尖端方向）
  r  特效覆盖半径（加权标准差，世界单位换算基准）
  w  特效强度（权重和，按角色归一化 0-1）——蓄力光点大小

输出 data/v6_pose_anchors.json：{ "字符/文件名": {c:[x,y], f:[x,y], r:半径px, w:0-1} }
坐标为 256px 姿势格归一化 [0,1]。运行：python tools/extract_pose_anchors.py
"""
import json
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POSE_DIR = os.path.join(ROOT, "art", "v6_pose")
OUT = os.path.join(ROOT, "data", "v6_pose_anchors.json")
FW_PCT = 0.80  # 前缘切片：加权 x 分布的 80 分位以右


def pose_anchor(path):
    im = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
    a = im[..., 3] / 255.0
    r, g, b = im[..., 0] / 255.0, im[..., 1] / 255.0, im[..., 2] / 255.0
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    v = mx
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    w = s * v * a * (a > 0.04)
    h, wd = a.shape
    yy, xx = np.mgrid[0:h, 0:wd]
    tot = float(w.sum())
    if tot < 1.0:
        return None
    cx = float((w * xx).sum() / tot) / wd
    cy = float((w * yy).sum() / tot) / h
    # 前缘：加权 x 分位以右的质心（无信号则退化为质心）
    order = np.argsort(xx.ravel())
    wr = w.ravel()[order]
    xr = xx.ravel()[order].astype(np.float64)
    yr = yy.ravel()[order].astype(np.float64)
    cum = np.cumsum(wr)
    cut = float(xr[np.searchsorted(cum, cum[-1] * FW_PCT)])
    msk = w >= 0
    msk = (xx >= cut) & (w > 0)
    if msk.sum() < 8:
        fx, fy = cx, cy
    else:
        wt = w[msk]
        fx = float((wt * xx[msk]).sum() / wt.sum()) / wd
        fy = float((wt * yy[msk]).sum() / wt.sum()) / h
    rad = float(np.sqrt(((w * (xx - cx * wd) ** 2 + w * (yy - cy * h) ** 2).sum() / tot)))
    return {"c": [round(cx, 4), round(cy, 4)], "f": [round(fx, 4), round(fy, 4)],
            "r": round(rad, 1), "w": round(tot, 0)}


def main():
    out = {}
    chars = sorted(os.listdir(POSE_DIR))
    for ch in chars:
        cdir = os.path.join(POSE_DIR, ch)
        if not os.path.isdir(cdir):
            continue
        wmax = 1.0
        entries = {}
        for fn in sorted(os.listdir(cdir)):
            if not fn.endswith(".png"):
                continue
            r = pose_anchor(os.path.join(cdir, fn))
            if r is not None:
                entries[fn] = r
                wmax = max(wmax, r["w"])
        for fn, r in entries.items():
            r["w"] = round(min(1.0, r["w"] / wmax), 3)
            out[ch + "/" + fn] = r
        print("%s: %d poses, wmax=%.0f" % (ch, len(entries), wmax))
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print("written %s (%d entries)" % (OUT, len(out)))


if __name__ == "__main__":
    main()
