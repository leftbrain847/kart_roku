' Fake-3D drawing with Draw2D. The road is sampled at ~115 depths (one per band of screen rows when flat); each
' sample is projected with the course's curves and hills, and drawn near-to-far, clipped so a crest hides the road
' behind it. Roads can be flat colors or a texture (one scaled row per sample). Tubes add walls and a ceiling, a
' corkscrew rotates the finished frame, and a void world shows clouds below the track. Sprites are pre-scaled
' bitmaps copied far-to-near. Everything that depends only on the screen row is computed once.

function NewRenderer(cfg as Object, screen as Object) as Object
    PrepareCourse(cfg)
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
    ' Screen row (from the horizon, flat road) -> sample index, for placing sprites.
    rowBand = []
    n = bands.Count()
    for i = 0 to n - 1
        for rr = 1 to bands[i].h
            rowBand.Push(i)
        end for
    end for
    reg = CreateObject("roFontRegistry")
    theme = Themes()[cfg.themeName]
    ' Each sample's colors, blended toward the sky color by distance once here (fog costs nothing per frame).
    fc = cfg.fog
    for each b in bands
        t = (b.d - fc.start) / (fc.end - fc.start)
        if t < 0 then t = 0
        if t > 1 then t = 1
        t = t * fc.max
        b.ground = [MixColor(theme.ground[0], theme.fog, t), MixColor(theme.ground[1], theme.fog, t)]
        b.road = [MixColor(theme.road[0], theme.fog, t), MixColor(theme.road[1], theme.fog, t)]
        b.rumble = [MixColor(theme.rumble[0], theme.fog, t), MixColor(theme.rumble[1], theme.fog, t)]
        b.lane = MixColor(theme.lane, theme.fog, t)
        b.fogA = ((theme.fog << 8) or Int(t * 255)) ' fog veil over textured road
        if theme.DoesExist("rightGround") then b.right = [MixColor(theme.rightGround[0], theme.fog, t), MixColor(theme.rightGround[1], theme.fog, t)]
        ' Tube and tunnel colors per style; tunnels fade to black inside, not to the sky.
        b.tube = {}
        tc = TubeColors(theme)
        for each st in tc
            c = tc[st]
            ft = t * 0.5
            fogc = theme.fog
            if st <> "steel" then fogc = &h000000
            b.tube[st] = { wall: [MixColor(c.wall[0], fogc, ft), MixColor(c.wall[1], fogc, ft)], ceil: [MixColor(c.ceil[0], fogc, ft), MixColor(c.ceil[1], fogc, ft)], light: (c.light << 8) or 255 }
        end for
        ch = [&h3A2E28, &h2E241F]
        if theme.DoesExist("chasm") then ch = theme.chasm
        b.chasm = [MixColor(ch[0], theme.fog, t * 0.7), MixColor(ch[1], theme.fog, t * 0.7)]
    end for
    art = "pkg:/images/sprites/"
    r = {
        theme: theme
        sky: CreateObject("roBitmap", art + "sky_" + cfg.themeName + ".jpg")
        far: CreateObject("roBitmap", art + "far_" + cfg.themeName + ".png")
        near: CreateObject("roBitmap", art + "near_" + cfg.themeName + ".png")
        screen: screen
        cfg: cfg
        bands: bands
        rowBand: rowBand
        sx: [], sy: [], clipAt: [], seen: []
        sprites: BuildSprites(cfg)
        fontS: reg.GetDefaultFont(26, false, false)
        fontM: reg.GetDefaultFont(34, true, false)
        fontL: reg.GetDefaultFont(56, true, false)
        fontXL: reg.GetDefaultFont(110, true, false)
    }
    for i = 0 to n - 1
        r.sx.Push(0)
        r.sy.Push(0)
        r.clipAt.Push(0)
        r.seen.Push(false)
    end for
    if theme.DoesExist("void") and theme.void then r.below = CreateObject("roBitmap", art + "below_" + cfg.themeName + ".jpg")
    if theme.DoesExist("roadTex") then
        tex = CreateObject("roBitmap", art + theme.roadTex)
        if tex <> invalid then
            r.tex = tex
            r.texRows = []
            for row = 0 to tex.GetHeight() - 1
                r.texRows.Push(CreateObject("roRegion", tex, 0, row, tex.GetWidth(), 1))
            end for
            r.texPerUnit = tex.GetHeight() / 6.0     ' one texture repeat every 6 units of road
        end if
    end if
    r.hasTubes = false
    for each st in cfg.course.tube
        if st <> "" then r.hasTubes = true
    end for
    if cfg.course.DoesExist("roll") then
        r.frame = CreateObject("roBitmap", { width: cfg.screen.w, height: cfg.screen.h, AlphaEnable: true })
    end if
    return r
end function

sub DrawFrame(r as Object, s as Object)
    cfg = s.cfg
    W = cfg.screen.w
    H = cfg.screen.h
    hy = cfg.screen.horizonY
    cx = W / 2
    roll = 0.0
    if r.frame <> invalid then roll = RollAt(cfg, s.player.s)
    scr = r.screen
    rolled = Abs(roll) > 0.5 and Abs(roll - 360) > 0.5
    if rolled then scr = r.frame

    ' Sky art, then two parallax ridges that slide with the curves and with sideways moves.
    scr.DrawObject(0, 0, r.sky)
    DrawRidge(scr, r.far, s.camX * 6 + s.bgX * 200, hy)
    DrawRidge(scr, r.near, s.camX * 14 + s.bgX * 450, hy)
    if r.below <> invalid then
        scr.DrawObject(0, hy, r.below)
    else
        scr.DrawRect(0, hy, W, H - hy, r.bands[0].ground[0])
    end if

    ProjectRoad(r, s)
    if r.below <> invalid then DrawHanging(r, s, scr, cx)
    DrawRoad(r, s, scr, cx)
    DrawTubes(r, s, scr, cx)
    DrawObjects(r, s, scr, cx)

    if rolled then
        ' Corkscrew: rotate the finished frame about the screen centre.
        r.screen.Clear((r.theme.fog << 8) or 255)
        a = roll * 3.14159265 / 180
        ox = -cx * Cos(a) - (-H / 2) * Sin(a)
        oy = cx * Sin(a) + (-H / 2) * Cos(a)
        r.screen.DrawRotatedObject(cx + ox, H / 2 + oy, roll, r.frame)
    end if
    DrawHud(r, s)
    if s.paused then DrawPause(r, s)
    if s.finished then DrawResults(r, s)
end sub

' Project every road sample: sideways bend from the curves, height from the hills.
sub ProjectRoad(r as Object, s as Object)
    cfg = s.cfg
    scale = cfg.course.curveScale
    maxD = cfg.track.drawDist
    camEl = ElevAt(cfg, s.player.s) + cfg.camera.height + KartHop(cfg, s.player) * cfg.camera.airFollow
    hy = cfg.screen.horizonY
    x = 0.0
    slope = 0.0
    prevD = 0.0
    clip = cfg.screen.h
    for i = r.bands.Count() - 1 to 0 step -1
        b = r.bands[i]
        d = b.d
        if d > maxD then d = maxD
        dd = d - prevD
        z = s.camZ + d
        slope = slope + CurveAt(cfg, z) * scale * dd
        x = x + slope * dd
        prevD = d
        y = Int(hy + (camEl - ElevAt(cfg, z)) * b.ppu)
        r.sx[i] = x
        r.sy[i] = y
        r.clipAt[i] = clip
        r.seen[i] = y < clip and b.d <= maxD
        if r.seen[i] then clip = y
    end for
end sub

sub DrawRoad(r as Object, s as Object, scr as Object, cx as Float)
    cfg = s.cfg
    W = cfg.screen.w
    stripeLen = cfg.track.stripeLen
    n = cfg.lanes.count
    half = n / 2.0
    lanes = r.theme.laneStyle
    void = r.below <> invalid
    for i = r.bands.Count() - 1 to 0 step -1
        if r.seen[i] then
            b = r.bands[i]
            y = r.sy[i]
            h = r.clipAt[i] - y
            if h < 1 then h = 1
            z = s.camZ + b.d
            stripe = Int(z / stripeLen) and 1
            if GapAt(cfg, z) then
                ' The gap of a jump: no road, a dark chasm (or just sky in a void world).
                if not void then scr.DrawRect(0, y, W, h, b.chasm[stripe])
            else
                if not void then scr.DrawRect(0, y, W, h, b.ground[stripe])
                camX = s.camX - r.sx[i]
                sm = TrackPos(cfg, z)
                row = 0
                if r.tex <> invalid then row = Int(z * r.texPerUnit) mod r.texRows.Count()
                if row < 0 then row = row + r.texRows.Count()
                fork = ForkAt(cfg, sm)
                if fork = invalid then
                    DrawRoadPiece(r, scr, b, y, h, cx, camX, -half, half, n, stripe, lanes, row)
                    if b.DoesExist("right") then
                        rx = cx + (half - camX) * b.ppu + 2.2 * b.ppu
                        if rx < W then scr.DrawRect(rx, y, W - rx, h, b.right[stripe])
                    end if
                else
                    for each pc in RoadPieces(cfg, sm)
                        DrawRoadPiece(r, scr, b, y, h, cx, camX, pc.x0, pc.x1, pc.lanes, stripe, lanes, row)
                    end for
                end if
            end if
        end if
    end for
end sub

sub DrawRoadPiece(r as Object, scr as Object, b as Object, y as Float, h as Float, cx as Float, camX as Float, x0 as Float, x1 as Float, lanes as Integer, stripe as Integer, laneStyle as String, row as Integer)
    ppu = b.ppu
    sx0 = cx + (x0 - camX) * ppu
    sx1 = cx + (x1 - camX) * ppu
    rw = 0.14 * ppu + 1
    rc = b.rumble[stripe]
    scr.DrawRect(sx0 - rw, y, rw, h, rc)
    scr.DrawRect(sx1, y, rw, h, rc)
    if r.tex <> invalid then
        scr.DrawScaledObject(sx0, y, (sx1 - sx0) / r.tex.GetWidth(), h, r.texRows[row])
        if (b.fogA and 255) > 8 then scr.DrawRect(sx0, y, sx1 - sx0, h, b.fogA)
    else
        scr.DrawRect(sx0, y, sx1 - sx0, h, b.road[stripe])
    end if
    if laneStyle = "solid" or (laneStyle = "dash" and stripe = 0) then
        lw = 0.05 * ppu + 1
        for j = 1 to lanes - 1
            scr.DrawRect(sx0 + j * ppu - lw / 2, y, lw, h, b.lane)
        end for
    end if
end sub

' Tubes: walls and a ceiling, painted far to near so nearer ribs cover farther ones.
sub DrawTubes(r as Object, s as Object, scr as Object, cx as Float)
    cfg = s.cfg
    if cfg.course.tunnels.Count() = 0 and not r.hasTubes then return
    W = cfg.screen.w
    hy = cfg.screen.horizonY
    camEl = ElevAt(cfg, s.player.s) + cfg.camera.height + KartHop(cfg, s.player) * cfg.camera.airFollow
    tubeH = 3.4
    prevCy = -1
    for i = 0 to r.bands.Count() - 1
        b = r.bands[i]
        z = s.camZ + b.d
        st = ""
        if b.d <= cfg.track.drawDist then st = TubeStyle(cfg, z)
        if st <> "" then
            col = b.tube[st]
            camX = s.camX - r.sx[i]
            pieces = RoadPieces(cfg, TrackPos(cfg, z))
            sxl = cx + (pieces[0].x0 - 0.4 - camX) * b.ppu
            sxr = cx + (pieces[pieces.Count() - 1].x1 + 0.4 - camX) * b.ppu
            cy = hy + (camEl - ElevAt(cfg, z) - tubeH) * b.ppu
            y = r.sy[i]
            rib = Int(z / 2) and 1
            if prevCy < 0 then prevCy = cy - 1
            scr.DrawRect(sxl, cy, sxr - sxl, prevCy - cy + 1, col.ceil[rib])
            if sxl > 0 then scr.DrawRect(0, cy, sxl, y - cy, col.wall[rib])
            if sxr < W then scr.DrawRect(sxr, cy, W - sxr, y - cy, col.wall[rib])
            if (Int(z) mod 8) = 0 and b.d > 6 then
                scr.DrawRect(sxl, cy, sxr - sxl, 0.06 * b.ppu + 1, col.light)
            end if
            prevCy = cy
        else
            prevCy = -1
        end if
    end for
end sub

' Wall, ceiling and light colors for each tube style. A world can override steel with tubeWall/tubeCeil.
function TubeColors(theme as Object) as Object
    out = {
        steel: { wall: [&h3A3F55, &h454B64], ceil: [&h2C3044, &h343A50], light: &h7FE8FF }
        rock: { wall: [&h4A3F36, &h55493E], ceil: [&h3A3029, &h44392F], light: &hFFB060 }
        snow: { wall: [&h8FA8C8, &h9DB6D4], ceil: [&h6F88A8, &h7C94B4], light: &hDDF4FF }
        candy: { wall: [&hF7A8D0, &hFFF2F8], ceil: [&hE88AC0, &hFFE0F0], light: &hFFFFA0 }
    }
    if theme.DoesExist("tubeWall") then out.steel = { wall: theme.tubeWall, ceil: theme.tubeCeil, light: theme.tubeLight }
    return out
end function

sub DrawRidge(scr as Object, bmp as Object, shift as Float, hy as Integer)
    if bmp = invalid then return
    w = bmp.GetWidth()
    x = -(Int(shift) mod w)
    if x > 0 then x = x - w
    y = hy - bmp.GetHeight()
    scr.DrawObject(x, y, bmp)
    if x + w < 1280 then scr.DrawObject(x + w, y, bmp)
end sub

' Sample index for depth d.
function SampleAt(r as Object, s as Object, d as Float) as Integer
    row = Int(s.cfg.camera.height * s.cfg.camera.k / d)
    if row < 0 then row = 0
    if row >= r.rowBand.Count() then row = r.rowBand.Count() - 1
    return r.rowBand[row]
end function

' Girders hanging under the track's edges into the void, drawn before the road so nearer road covers them.
sub DrawHanging(r as Object, s as Object, scr as Object, cx as Float)
    th = r.theme
    if not th.DoesExist("hang") then return
    cfg = s.cfg
    lv = r.sprites.byName[th.hang]
    if lv = invalid then return
    every = th.hangEvery
    far = cfg.track.drawDist
    tpos = (Int(s.camZ / every) + 1) * every
    list = []
    while tpos < s.camZ + far
        list.Unshift(tpos)
        tpos = tpos + every
    end while
    for each tp in list
        d = tp - s.camZ
        if d > cfg.camera.nearDepth then
            i = SampleAt(r, s, d)
            ppu = cfg.camera.k / d
            img = lv[SpriteLevel(r.sprites, ppu)]
            pieces = RoadPieces(cfg, TrackPos(cfg, tp))
            for each xe in [pieces[0].x0 - 1.1, pieces[pieces.Count() - 1].x1 + 1.1]
                sx = cx + (xe - s.camX + r.sx[i]) * ppu
                scr.DrawObject(sx - img.w / 2, r.sy[i] - 0.6 * ppu, img.bmp)
            end for
        end if
    end for
end sub

' Scenery, landmarks, item blocks, traffic, shells, bananas and karts, painted far to near.
sub DrawObjects(r as Object, s as Object, scr as Object, cx as Float)
    cfg = s.cfg
    nearD = cfg.camera.nearDepth
    far = cfg.track.drawDist
    L = cfg.track.length
    n = cfg.lanes.count
    th = r.theme
    list = []

    every = cfg.track.sceneryEvery
    tpos = (Int(s.camZ / every) + 1) * every
    while tpos < s.camZ + far
        d = tpos - s.camZ
        if d > nearD then
            sm = TrackPos(cfg, tpos)
            pieces = RoadPieces(cfg, sm)
            idx = Int(tpos / every)
            kinds = th.scenery
            kind = kinds[idx mod kinds.Count()]
            gap = th.gap
            list.Push({ d: d, x: pieces[0].x0 - gap, k: kind, h: 0 })
            if not th.DoesExist("rightGround") then list.Push({ d: d, x: pieces[pieces.Count() - 1].x1 + gap, k: kinds[(idx + 1) mod kinds.Count()], h: 0 })
            for j = 1 to pieces.Count() - 1
                if pieces[j].x0 - pieces[j - 1].x1 > 2.0 then
                    mk = kinds[0]
                    if th.DoesExist("median") then mk = th.median
                    if mk <> "brachio" or (idx mod 5) = 0 then list.Push({ d: d, x: (pieces[j].x0 + pieces[j - 1].x1) / 2, k: mk, h: 0 })
                end if
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
        for each l0 in cfg.course.loops
            d = lapBase + rep * L + l0 - s.camZ
            if d > nearD and d < far then list.Push({ d: d, x: 0, k: "loopring", h: 0 })
        end for
        for each tn in cfg.course.tunnels
            d = lapBase + rep * L + tn.at - s.camZ - 0.5
            if tn.style <> "steel" and d > nearD and d < far then list.Push({ d: d, x: 0, k: "portal_" + tn.style, h: 0 })
        end for
        for each jp in cfg.course.jumps
            d = lapBase + rep * L + jp.at - s.camZ - 1.5
            if d > nearD and d < far then list.Push({ d: d, x: 0, k: "ramp", h: 0 })
        end for
        if th.DoesExist("landmarks") then
            for each lm in th.landmarks
                d = lapBase + rep * L + lm.at - s.camZ
                if d > nearD and d < far then list.Push({ d: d, x: lm.x, k: lm.k, h: 0 })
            end for
        end if
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
    spr = r.sprites
    for each kt in s.karts
        hop = KartHop(cfg, kt)
        wob = 0
        if kt.spinT > 0 then wob = Sin(kt.spinT * 40) * 0.12
        ang = ""
        if spr.angled then ang = KartAngle(cfg, kt)
        if kt.isBot then
            list.Push({ d: kt.s - s.camZ, x: KartX(s, kt) + wob, k: "kart" + kt.id.ToStr() + ang, h: hop })
        else
            list.Push({ d: cfg.camera.playerDepth, x: KartX(s, kt) + wob, k: "player" + ang, h: hop })
        end if
    end for

    list.SortBy("d", "r")
    k = cfg.camera.k
    for each o in list
        if o.d > nearD and o.d < far then
            i = SampleAt(r, s, o.d)
            ppu = k / o.d
            sx = cx + (o.x - s.camX + r.sx[i]) * ppu
            sy = r.sy[i] - o.h * ppu
            if Left(o.k, 6) = "player" then
                DrawKart(r, s, scr, sx, sy, o.k)
            else
                lv = spr.byName[o.k]
                if lv <> invalid then
                    img = lv[SpriteLevel(spr, ppu)]
                    clip = r.clipAt[i]
                    top = sy - img.h
                    if sy <= clip + 1 then
                        scr.DrawObject(sx - img.w / 2, top, img.bmp)
                    else if clip > top then
                        ' Partly behind a crest: draw only the part above the nearer road.
                        part = CreateObject("roRegion", img.bmp, 0, 0, img.w, Int(clip - top))
                        scr.DrawObject(sx - img.w / 2, top, part)
                    end if
                end if
            end if
        end if
    end for
end sub

'' How high a kart is off the road: a lane-change hop plus airtime.
function KartHop(cfg as Object, k as Object) as Float
    hop = 0
    if k.jumpT > 0 then hop = Sin(3.14159 * k.jumpT / cfg.lanes.jumpTime) * cfg.lanes.jumpHeight
    if k.airT > 0 then hop = hop + Sin(3.14159 * k.airT / k.airDur) * k.airH
    return hop
end function

' Which pre-rendered angle to show: leaning into a lane change or a bend.
function KartAngle(cfg as Object, k as Object) as String
    dl = k.lane - k.laneF
    if dl < -0.05 then return "r"
    if dl > 0.05 then return "l"
    c = CurveAt(cfg, k.s)
    if c > 0.45 then return "l"
    if c < -0.45 then return "r"
    return "c"
end function

sub DrawKart(r as Object, s as Object, scr as Object, x as Float, y as Float, name as String)
    p = s.player
    img = r.sprites[name]
    if img = invalid then img = r.sprites.player
    if img = invalid then return
    if p.boostT > 0 then
        flick = Int(s.time * 30) and 1
        scr.DrawRect(x - 34, y - 14, 20, 18 + flick * 10, &hFF7A1AFF)
        scr.DrawRect(x + 14, y - 14, 20, 18 + flick * 10, &hFF7A1AFF)
        scr.DrawRect(x - 30, y - 12, 12, 12 + flick * 6, &hFFE04AFF)
        scr.DrawRect(x + 18, y - 12, 12, 12 + flick * 6, &hFFE04AFF)
    end if
    scr.DrawObject(x - img.w / 2, y - img.h, img.bmp)
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
    if s.showFps then Txt(r, Int(s.fps + 0.5).ToStr() + " FPS", W - 230, H - 100, c.hudAccent, r.fontS)
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
    r.screen.DrawRect(W / 2 - 220, 150, 440, 440, c.panel)
    TxtCentered(r, "PAUSED", 170, c.hudAccent, r.fontL)
    items = PauseMenu(s)
    for i = 0 to items.Count() - 1
        col = c.hud
        label = items[i]
        if i = s.menuIndex then
            col = c.hudAccent
            label = "> " + label + " <"
        end if
        TxtCentered(r, label, 262 + i * 58, col, r.fontM)
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
    TxtCentered(r, "OK race again   PLAY tracks   BACK exit", 500, c.hudAccent, r.fontS)
end sub
