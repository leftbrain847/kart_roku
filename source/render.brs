' Fake-3D drawing with Draw2D: the road as horizontal bands of rectangles, bent by the course curves, and objects
' as pre-scaled bitmaps copied far-to-near. Everything that depends only on the screen row is computed once.

function NewRenderer(cfg as Object, screen as Object) as Object
    cam = cfg.camera
    hy = cfg.screen.horizonY
    bands = []
    y = hy
    for each b in cfg.render.bands
        rows = b[0]
        bh = b[1]
        last = y + rows
        while y < last
            h = bh
            if y + h > last then h = last - y
            mid = y + h / 2.0 - hy
            if mid < 0.5 then mid = 0.5
            ppu = mid / cam.height          ' px per unit at this row
            bands.Push({ y: y, h: h, ppu: ppu, d: cam.k / ppu })
            y = y + h
        end while
    end for
    ' Screen row (from the horizon) -> band index, for placing sprites on the bent road.
    rowBand = []
    bandX = []
    for i = 0 to bands.Count() - 1
        bandX.Push(0)
        for rr = 1 to bands[i].h
            rowBand.Push(i)
        end for
    end for
    reg = CreateObject("roFontRegistry")
    hills = []
    for i = 0 to 11
        hills.Push({ x: i * 170 - 120, w: 150 + (i * 53) mod 140, h: 30 + (i * 37) mod 60 })
    end for
    return {
        screen: screen
        cfg: cfg
        bands: bands
        bandX: bandX
        rowBand: rowBand
        sprites: BuildSprites(cfg)
        hills: hills
        fontS: reg.GetDefaultFont(26, false, false)
        fontM: reg.GetDefaultFont(34, true, false)
        fontL: reg.GetDefaultFont(56, true, false)
        fontXL: reg.GetDefaultFont(110, true, false)
    }
end function

' How far the road centre has bent sideways at each band, integrating the curves from the camera outward.
sub BendRoad(r as Object, s as Object)
    cfg = s.cfg
    scale = cfg.course.curveScale
    maxD = cfg.track.drawDist
    x = 0.0
    slope = 0.0
    prevD = 0.0
    for i = r.bands.Count() - 1 to 0 step -1
        d = r.bands[i].d
        if d > maxD then d = maxD
        dd = d - prevD
        slope = slope + CurveAt(cfg, s.camZ + d) * scale * dd
        x = x + slope * dd
        r.bandX[i] = x
        prevD = d
    end for
end sub

' Sideways bend of the road at depth d.
function BendAt(r as Object, s as Object, d as Float) as Float
    row = Int(s.cfg.camera.height * s.cfg.camera.k / d)
    if row < 0 then row = 0
    if row >= r.rowBand.Count() then row = r.rowBand.Count() - 1
    return r.bandX[r.rowBand[row]]
end function

sub DrawFrame(r as Object, s as Object)
    scr = r.screen
    cfg = s.cfg
    c = cfg.colors
    W = cfg.screen.w
    H = cfg.screen.h
    hy = cfg.screen.horizonY
    cx = W / 2

    ' Sky and parallax hills.
    scr.DrawRect(0, 0, W, hy \ 2, c.skyHigh)
    scr.DrawRect(0, hy \ 2, W, hy - hy \ 2, c.sky)
    shift = Int(s.camX * 12 + s.bgX * 400)
    for each hl in r.hills
        hx = ((hl.x - shift) mod 2040 + 2040) mod 2040 - 200
        scr.DrawRect(hx, hy - hl.h, hl.w, hl.h, c.hillsFar)
        scr.DrawRect(hx + 40, hy - hl.h \ 2, hl.w, hl.h \ 2, c.hills)
    end for
    scr.DrawRect(0, hy, W, H - hy, c.grassDark)

    ' Road bands.
    BendRoad(r, s)
    stripeLen = cfg.track.stripeLen
    n = cfg.lanes.count
    half = n / 2.0
    for i = 0 to r.bands.Count() - 1
        b = r.bands[i]
        sPos = s.camZ + b.d
        stripe = Int(sPos / stripeLen) and 1
        if stripe = 1 then scr.DrawRect(0, b.y, W, b.h, c.grassLight)
        camX = s.camX - r.bandX[i]
        sm = TrackPos(cfg, sPos)
        fork = ForkAt(cfg, sm)
        if fork = invalid then
            DrawRoadPiece(scr, c, b, cx, camX, -half, half, n, stripe)
        else
            for each pc in RoadPieces(cfg, sm)
                DrawRoadPiece(scr, c, b, cx, camX, pc.x0, pc.x1, pc.lanes, stripe)
            end for
        end if
    end for

    DrawObjects(r, s, cx, hy)
    DrawHud(r, s)
    if s.paused then DrawPause(r, s)
    if s.finished then DrawResults(r, s)
end sub

sub DrawRoadPiece(scr as Object, c as Object, b as Object, cx as Float, camX as Float, x0 as Float, x1 as Float, lanes as Integer, stripe as Integer)
    ppu = b.ppu
    sx0 = cx + (x0 - camX) * ppu
    sx1 = cx + (x1 - camX) * ppu
    rw = 0.14 * ppu + 1
    rc = c.rumbleA
    road = c.road
    if stripe = 1 then
        rc = c.rumbleB
        road = c.roadAlt
    end if
    scr.DrawRect(sx0 - rw, b.y, rw, b.h, rc)
    scr.DrawRect(sx1, b.y, rw, b.h, rc)
    scr.DrawRect(sx0, b.y, sx1 - sx0, b.h, road)
    if stripe = 0 then
        lw = 0.05 * ppu + 1
        for j = 1 to lanes - 1
            scr.DrawRect(sx0 + j * ppu - lw / 2, b.y, lw, b.h, c.lane)
        end for
    end if
end sub

' Trees, item blocks, traffic, shells, bananas and karts, painted far to near.
sub DrawObjects(r as Object, s as Object, cx as Float, hy as Integer)
    cfg = s.cfg
    nearD = cfg.camera.nearDepth
    far = cfg.track.drawDist
    L = cfg.track.length
    n = cfg.lanes.count
    list = []

    every = cfg.track.sceneryEvery
    tpos = (Int(s.camZ / every) + 1) * every
    while tpos < s.camZ + far
        d = tpos - s.camZ
        if d > nearD then
            sm = TrackPos(cfg, tpos)
            pieces = RoadPieces(cfg, sm)
            list.Push({ d: d, x: pieces[0].x0 - 1.1, k: "tree", h: 0 })
            list.Push({ d: d, x: pieces[pieces.Count() - 1].x1 + 1.1, k: "tree", h: 0 })
            for j = 1 to pieces.Count() - 1
                if pieces[j].x0 - pieces[j - 1].x1 > 2.0 then list.Push({ d: d, x: (pieces[j].x0 + pieces[j - 1].x1) / 2, k: "tree", h: 0 })
            end for
        end if
        tpos = tpos + every
    end while

    lapBase = Int(s.camZ / L) * L
    for rep = 0 to 1
        for i = 0 to s.rows.Count() - 1
            d = lapBase + rep * L + s.rows[i] - s.camZ
            if d > nearD and d < far then
                for lane = 0 to n - 1
                    if s.blocks[i][lane] <= s.time then list.Push({ d: d, x: LaneXi(cfg, lane, s.rows[i]), k: "block", h: 0 })
                end for
            end if
        end for
    end for

    for each car in s.traffic
        list.Push({ d: car.s - s.camZ, x: ObjX(s, car.lane, car.s), k: "car", h: 0 })
    end for
    for each sh in s.shots
        list.Push({ d: sh.s - s.camZ, x: ObjX(s, sh.lane, sh.s), k: "shell", h: 0 })
    end for
    for each bn in s.hazards
        list.Push({ d: bn.s - s.camZ, x: ObjX(s, bn.lane, bn.s), k: "banana", h: 0 })
    end for
    for each kt in s.karts
        hop = 0
        if kt.jumpT > 0 then hop = Sin(3.14159 * kt.jumpT / cfg.lanes.jumpTime) * cfg.lanes.jumpHeight
        wob = 0
        if kt.spinT > 0 then wob = Sin(kt.spinT * 40) * 0.12
        if kt.isBot then
            list.Push({ d: kt.s - s.camZ, x: KartX(s, kt) + wob, k: "kart" + kt.id.ToStr(), h: hop })
        else
            list.Push({ d: cfg.camera.playerDepth, x: KartX(s, kt) + wob, k: "player", h: hop })
        end if
    end for

    list.SortBy("d", "r")
    spr = r.sprites
    k = cfg.camera.k
    camH = cfg.camera.height
    for each o in list
        if o.d > nearD and o.d < far then
            ppu = k / o.d
            sx = cx + (o.x - s.camX + BendAt(r, s, o.d)) * ppu
            sy = hy + (camH - o.h) * ppu
            if o.k = "player" then
                DrawKart(r, s, sx, sy)
            else
                img = spr.byName[o.k][SpriteLevel(spr, ppu)]
                r.screen.DrawObject(sx - img.w / 2, sy - img.h, img.bmp)
            end if
        end if
    end for
end sub

sub DrawKart(r as Object, s as Object, x as Float, y as Float)
    p = s.player
    img = r.sprites.player
    if p.boostT > 0 then
        flick = Int(s.time * 30) and 1
        r.screen.DrawRect(x - 34, y - 14, 20, 18 + flick * 10, &hFF7A1AFF)
        r.screen.DrawRect(x + 14, y - 14, 20, 18 + flick * 10, &hFF7A1AFF)
        r.screen.DrawRect(x - 30, y - 12, 12, 12 + flick * 6, &hFFE04AFF)
        r.screen.DrawRect(x + 18, y - 12, 12, 12 + flick * 6, &hFFE04AFF)
    end if
    r.screen.DrawObject(x - img.w / 2, y - img.h, img.bmp)
end sub

sub Txt(r as Object, text as String, x as Integer, y as Integer, color as Integer, font as Object)
    r.screen.DrawText(text, x + 2, y + 2, r.cfg.colors.hudShadow, font)
    r.screen.DrawText(text, x, y, color, font)
end sub

sub TxtCentered(r as Object, text as String, y as Integer, color as Integer, font as Object)
    Txt(r, text, (r.cfg.screen.w - font.GetOneLineWidth(text, r.cfg.screen.w)) / 2, y, color, font)
end sub

sub DrawHud(r as Object, s as Object)
    c = s.cfg.colors
    W = s.cfg.screen.w
    H = s.cfg.screen.h
    p = s.player
    laps = s.cfg.race.laps
    lapText = "LAP " + s.lap.ToStr()
    if laps > 0 then lapText = lapText + "/" + laps.ToStr()
    Txt(r, Ordinal(Position(s, p)) + "/" + s.karts.Count().ToStr(), 48, 24, c.hudAccent, r.fontL)
    Txt(r, lapText + "   " + FormatTime(s.time - s.lapStart), 48, 92, c.hud, r.fontM)
    Txt(r, "BEST " + FormatTime(s.best) + "   LAST " + FormatTime(s.lastLap), 48, 136, c.hud, r.fontS)

    ' Item slot, top right.
    r.screen.DrawRect(W - 170, 30, 120, 120, c.panel)
    if p.item <> "" then
        img = r.sprites.hudItems[p.item]
        r.screen.DrawObject(W - 110 - img.w / 2, 90 - img.h / 2, img.bmp)
        hint = "UP / DOWN"
        if p.item = "boost" then hint = "OK"
        Txt(r, hint, W - 165, 156, c.hud, r.fontS)
    end if

    kmh = Int(p.speed * s.cfg.speed.kmhPerUnit)
    Txt(r, kmh.ToStr() + " km/h", 48, H - 66, c.hud, r.fontM)
    if not s.trafficOn then Txt(r, "TRAFFIC OFF", W - 230, H - 56, c.hud, r.fontS)
    name = TrackName(s.cfg, p.lane, TrackPos(s.cfg, p.s))
    if name <> "" then TxtCentered(r, name, 30, c.hudAccent, r.fontS)

    fork = ForkAhead(s, 160)
    if fork <> invalid then
        TxtCentered(r, "TRACKS SPLIT AHEAD", 70, c.hudAccent, r.fontM)
        TxtCentered(r, SplitLabel(s.cfg, fork), 112, c.hud, r.fontS)
    end if
    if s.countdown > 0 then
        TxtCentered(r, (Int(s.countdown) + 1).ToStr(), 250, c.hudAccent, r.fontXL)
    else if s.msgT > 0 and s.msg <> "" then
        TxtCentered(r, s.msg, 180, c.hudAccent, r.fontL)
    end if
end sub

' "CANYON 1-2  |  COAST 3-5" (lanes numbered from 1 on screen)
function SplitLabel(cfg as Object, fork as Object) as String
    bounds = [0]
    for each sp in fork.splits
        bounds.Push(sp)
    end for
    bounds.Push(cfg.lanes.count)
    out = ""
    for j = 0 to fork.names.Count() - 1
        a = bounds[j] + 1
        b = bounds[j + 1]
        lanes = a.ToStr()
        if b > a then lanes = lanes + "-" + b.ToStr()
        if j > 0 then out = out + "   |   "
        out = out + fork.names[j] + " " + lanes
    end for
    return out
end function

sub DrawPause(r as Object, s as Object)
    c = s.cfg.colors
    W = s.cfg.screen.w
    H = s.cfg.screen.h
    r.screen.DrawRect(0, 0, W, H, &h00000090)
    r.screen.DrawRect(W / 2 - 220, 170, 440, 380, c.panel)
    TxtCentered(r, "PAUSED", 196, c.hudAccent, r.fontL)
    items = PauseMenu(s)
    for i = 0 to items.Count() - 1
        col = c.hud
        label = items[i]
        if i = s.menuIndex then
            col = c.hudAccent
            label = "> " + label + " <"
        end if
        TxtCentered(r, label, 290 + i * 58, col, r.fontM)
    end for
    TxtCentered(r, "OK select   PLAY resume   BACK exit", 610, c.hud, r.fontS)
end sub

sub DrawResults(r as Object, s as Object)
    c = s.cfg.colors
    W = s.cfg.screen.w
    H = s.cfg.screen.h
    r.screen.DrawRect(0, 0, W, H, &h00000090)
    r.screen.DrawRect(W / 2 - 260, 150, 520, 420, c.panel)
    TxtCentered(r, "FINISHED " + Ordinal(s.finishPos), 180, c.hudAccent, r.fontL)
    TxtCentered(r, "RACE " + FormatTime(s.raceTime), 280, c.hud, r.fontM)
    TxtCentered(r, "BEST LAP " + FormatTime(s.best), 335, c.hud, r.fontM)
    TxtCentered(r, "JUMPS " + s.stats.jumps.ToStr() + "   HITS " + s.stats.shellHits.ToStr(), 390, c.hud, r.fontS)
    TxtCentered(r, "OK race again   BACK exit", 500, c.hudAccent, r.fontS)
end sub
