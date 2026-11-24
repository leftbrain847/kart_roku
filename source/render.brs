' Fake-3D drawing with Draw2D: the road as horizontal bands of rectangles, objects as pre-scaled bitmaps
' copied far-to-nearD. Everything that depends only on the screen row is computed once in NewRenderer.

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
    reg = CreateObject("roFontRegistry")
    hills = []
    for i = 0 to 11
        hills.Push({ x: i * 170 - 120, w: 150 + (i * 53) mod 140, h: 30 + (i * 37) mod 60 })
    end for
    return {
        screen: screen
        cfg: cfg
        bands: bands
        sprites: BuildSprites(cfg)
        hills: hills
        fontS: reg.GetDefaultFont(26, false, false)
        fontM: reg.GetDefaultFont(34, true, false)
        fontL: reg.GetDefaultFont(56, true, false)
    }
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
    shift = Int(s.camX * 12)
    for each hl in r.hills
        hx = ((hl.x - shift) mod 2040 + 2040) mod 2040 - 200
        scr.DrawRect(hx, hy - hl.h, hl.w, hl.h, c.hillsFar)
        scr.DrawRect(hx + 40, hy - hl.h \ 2, hl.w, hl.h \ 2, c.hills)
    end for
    scr.DrawRect(0, hy, W, H - hy, c.grassDark)

    ' Road bands.
    stripeLen = cfg.track.stripeLen
    n = cfg.lanes.count
    half = n / 2.0
    for each b in r.bands
        sPos = s.camZ + b.d
        stripe = Int(sPos / stripeLen) and 1
        if stripe = 1 then scr.DrawRect(0, b.y, W, b.h, c.grassLight)
        fork = ForkAt(cfg, TrackPos(cfg, sPos))
        if fork = invalid then
            DrawRoadPiece(scr, c, b, cx, s.camX, -half, half, n, stripe)
        else
            g = ForkGap(fork, TrackPos(cfg, sPos)) / 2
            mid = -half + fork.split
            DrawRoadPiece(scr, c, b, cx, s.camX, -half - g, mid - g, fork.split, stripe)
            DrawRoadPiece(scr, c, b, cx, s.camX, mid + g, half + g, n - fork.split, stripe)
        end if
    end for

    DrawObjects(r, s, cx, hy)
    DrawHud(r, s)
    if s.paused then DrawPause(r, s)
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

' Trees, item blocks, traffic, shells, bananas and the kart, painted far to nearD.
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
            edge = n / 2.0 + 1.1
            fork = ForkAt(cfg, sm)
            if fork <> invalid then
                g = ForkGap(fork, sm)
                edge = edge + g / 2
                if g > 2.0 then list.Push({ d: d, x: -n / 2.0 + fork.split, k: "tree" })
            end if
            list.Push({ d: d, x: -edge, k: "tree" })
            list.Push({ d: d, x: edge, k: "tree" })
        end if
        tpos = tpos + every
    end while

    lapBase = Int(s.camZ / L) * L
    for rep = 0 to 1
        for i = 0 to s.rows.Count() - 1
            d = lapBase + rep * L + s.rows[i] - s.camZ
            if d > nearD and d < far then
                for lane = 0 to n - 1
                    if s.blocks[i][lane] <= s.time then list.Push({ d: d, x: LaneX(cfg, lane, s.rows[i], -1), k: "block" })
                end for
            end if
        end for
    end for

    for each car in s.traffic
        list.Push({ d: car.s - s.camZ, x: ObjX(s, car.lane, car.s), k: "car" })
    end for
    for each sh in s.shots
        list.Push({ d: sh.s - s.camZ, x: ObjX(s, sh.lane, sh.s), k: "shell" })
    end for
    for each bn in s.hazards
        list.Push({ d: bn.s - s.camZ, x: ObjX(s, bn.lane, bn.s), k: "banana" })
    end for
    list.Push({ d: cfg.camera.playerDepth, x: PlayerX(s), k: "player" })

    list.SortBy("d", "r")
    spr = r.sprites
    k = cfg.camera.k
    camH = cfg.camera.height
    for each o in list
        if o.d > nearD and o.d < far then
            ppu = k / o.d
            if o.k = "player" then
                DrawKart(r, s, cx + (o.x - s.camX) * ppu, hy + camH * ppu)
            else
                img = spr.byName[o.k][SpriteLevel(spr, ppu)]
                r.screen.DrawObject(cx + (o.x - s.camX) * ppu - img.w / 2, hy + camH * ppu - img.h, img.bmp)
            end if
        end if
    end for
end sub

sub DrawKart(r as Object, s as Object, x as Float, y as Float)
    p = s.player
    img = r.sprites.player
    if p.spinT > 0 then x = x + Sin(p.spinT * 40) * 18
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
    p = s.player
    Txt(r, "LAP " + s.lap.ToStr(), 48, 30, c.hudAccent, r.fontM)
    Txt(r, FormatTime(s.time - s.lapStart), 48, 72, c.hud, r.fontM)
    Txt(r, "BEST " + FormatTime(s.best), 48, 116, c.hud, r.fontS)
    Txt(r, "LAST " + FormatTime(s.lastLap), 48, 148, c.hud, r.fontS)

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
    Txt(r, kmh.ToStr() + " km/h", 48, s.cfg.screen.h - 66, c.hud, r.fontM)
    if not s.trafficOn then Txt(r, "TRAFFIC OFF", W - 230, s.cfg.screen.h - 56, c.hud, r.fontS)
    if p.routeName <> "" then TxtCentered(r, p.routeName, 30, c.hudAccent, r.fontS)

    fork = ForkAhead(s, 160)
    if fork <> invalid then
        a = fork.routes[0].name + " < lanes 1-" + fork.split.ToStr()
        b = "lanes " + (fork.split + 1).ToStr() + "-" + s.cfg.lanes.count.ToStr() + " > " + fork.routes[1].name
        TxtCentered(r, "FORK AHEAD", 70, c.hudAccent, r.fontM)
        TxtCentered(r, a + "   |   " + b, 112, c.hud, r.fontS)
    end if
    if s.msgT > 0 and s.msg <> "" then TxtCentered(r, s.msg, 180, c.hudAccent, r.fontL)
end sub

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
