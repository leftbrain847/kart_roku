' Sprites are drawn once at startup from rectangles into bitmaps at every scale the game needs
' ("pre-scaled"), so a frame only copies bitmaps: no scaling and no per-pixel work while racing.

' Each sprite: size in world units (w, h) and rects [x, y, w, h, color] in 0..1 of that box.
function SpriteDefs() as Object
    black = &h1A1A1AFF
    return {
        car: { w: 0.86, h: 0.66, rects: [
            [0.04, 0.78, 0.18, 0.22, black], [0.78, 0.78, 0.18, 0.22, black]
            [0.02, 0.40, 0.96, 0.44, &h2D6CDFFF], [0.14, 0.06, 0.72, 0.40, &h2457B8FF]
            [0.22, 0.14, 0.56, 0.22, &hA9D3F5FF], [0.06, 0.50, 0.16, 0.10, &hFF5A4AFF]
            [0.78, 0.50, 0.16, 0.10, &hFF5A4AFF], [0.30, 0.66, 0.40, 0.08, &hDDDDDDFF]
        ] }
        block: { w: 0.52, h: 0.52, rects: [
            [0.00, 0.00, 1.00, 1.00, &hC9781EFF], [0.08, 0.08, 0.84, 0.84, &hF5B829FF]
            [0.34, 0.18, 0.32, 0.12, &hFFFFFFFF], [0.58, 0.18, 0.12, 0.30, &hFFFFFFFF]
            [0.42, 0.42, 0.28, 0.10, &hFFFFFFFF], [0.42, 0.42, 0.12, 0.18, &hFFFFFFFF]
            [0.42, 0.70, 0.12, 0.12, &hFFFFFFFF]
        ] }
        shell: { w: 0.34, h: 0.26, rects: [
            [0.00, 0.62, 1.00, 0.38, &hF2F2F2FF], [0.08, 0.10, 0.84, 0.60, &h2FB14AFF]
            [0.24, 0.00, 0.52, 0.20, &h2FB14AFF], [0.30, 0.24, 0.16, 0.16, &hBDF2C8FF]
        ] }
        banana: { w: 0.34, h: 0.26, rects: [
            [0.00, 0.30, 0.22, 0.30, &hFFE04AFF], [0.14, 0.52, 0.70, 0.30, &hFFE04AFF]
            [0.76, 0.24, 0.22, 0.34, &hFFE04AFF], [0.84, 0.06, 0.10, 0.20, &h6B4A1EFF]
            [0.20, 0.74, 0.56, 0.10, &hD9B21EFF]
        ] }
        boost: { w: 0.34, h: 0.34, rects: [
            [0.10, 0.00, 0.80, 0.56, &hFF7A1AFF], [0.30, 0.10, 0.40, 0.30, &hFFE04AFF]
            [0.28, 0.56, 0.44, 0.44, &hF2E3C8FF], [0.40, 0.66, 0.20, 0.10, &h1A1A1AFF]
        ] }
        tree: { w: 1.1, h: 2.0, rects: [
            [0.42, 0.70, 0.16, 0.30, &h6B4A1EFF], [0.10, 0.40, 0.80, 0.34, &h1F6B2AFF]
            [0.20, 0.16, 0.60, 0.30, &h26803AFF], [0.32, 0.00, 0.36, 0.20, &h2E9444FF]
        ] }
    }
end function

' A kart in any body color; the shading is a translucent overlay so one definition serves every kart.
function KartDef(body as Integer) as Object
    black = &h1A1A1AFF
    return { w: 0.78, h: 0.52, rects: [
        [0.02, 0.55, 0.20, 0.42, black], [0.78, 0.55, 0.20, 0.42, black]
        [0.10, 0.40, 0.80, 0.42, body], [0.18, 0.30, 0.64, 0.16, body], [0.18, 0.30, 0.64, 0.16, &h00000050]
        [0.34, 0.00, 0.32, 0.36, &hFFD23FFF], [0.38, 0.12, 0.24, 0.10, &h222A55FF]
        [0.04, 0.82, 0.92, 0.08, body], [0.04, 0.82, 0.92, 0.08, &h00000070], [0.40, 0.62, 0.20, 0.10, &hF2F2F2FF]
    ] }
end function

' Draw one sprite definition into a new bitmap at `ppu` pixels per world unit.
function DrawSpriteBitmap(def as Object, ppu as Float) as Object
    w = Int(def.w * ppu + 0.5)
    h = Int(def.h * ppu + 0.5)
    if w < 1 then w = 1
    if h < 1 then h = 1
    bmp = CreateObject("roBitmap", { width: w, height: h, AlphaEnable: true })
    bmp.Clear(&h00000000)
    for each r in def.rects
        rx = Int(r[0] * w)
        ry = Int(r[1] * h)
        rw = Int(r[2] * w + 0.999)
        rh = Int(r[3] * h + 0.999)
        if rw < 1 then rw = 1
        if rh < 1 then rh = 1
        bmp.DrawRect(rx, ry, rw, rh, r[4])
    end for
    bmp.Finish()
    return { bmp: bmp, w: w, h: h }
end function

' Every sprite at cfg.render.spriteLevels geometric scales (one kart per body color: kart0 = you, kart1.. = bots),
' plus your kart at its fixed on-screen scale.
function BuildSprites(cfg as Object) as Object
    rc = cfg.render
    levels = rc.spriteLevels
    logRatio = Log(rc.maxPpu / rc.minPpu) / (levels - 1)
    out = { levels: levels, logRatio: logRatio, minPpu: rc.minPpu, byName: {} }
    defs = SpriteDefs()
    defs["kart0"] = KartDef(cfg.colors.player)
    for i = 0 to cfg.bots.count - 1
        defs["kart" + (i + 1).ToStr()] = KartDef(cfg.bots.bodies[i])
    end for
    for each name in defs
        arr = []
        for j = 0 to levels - 1
            arr.Push(DrawSpriteBitmap(defs[name], rc.minPpu * Exp(logRatio * j)))
        end for
        out.byName[name] = arr
    end for
    out.player = DrawSpriteBitmap(defs.kart0, cfg.camera.k / cfg.camera.playerDepth)
    out.hudItems = {}
    for each name in ["shell", "banana", "boost"]
        out.hudItems[name] = DrawSpriteBitmap(defs[name], 150)
    end for
    return out
end function

' Index of the pre-scaled copy closest to `ppu`.
function SpriteLevel(spr as Object, ppu as Float) as Integer
    if ppu <= spr.minPpu then return 0
    j = Int(Log(ppu / spr.minPpu) / spr.logRatio + 0.5)
    if j >= spr.levels then j = spr.levels - 1
    return j
end function
