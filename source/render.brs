' Fake-3D drawing with Draw2D. The road is sampled at ~115 depths (one per band of screen rows when flat); each
' sample is projected with the course's curves and hills, and drawn near-to-far, clipped so a crest hides the road
' behind it. Roads can be flat colors or a texture (one scaled row per sample). Tubes add walls and a ceiling, a
' corkscrew rotates the finished frame, and a void world shows clouds below the track. Sprites are pre-scaled
' bitmaps copied far-to-near. Everything that depends only on the screen row is computed once.

function NewRenderer(cfg as Object, screen as Object) as Object
    PrepareCourse(cfg)
    reg = CreateObject("roFontRegistry")
    theme = Themes()[cfg.themeName]
    art = "pkg:/images/sprites/"
    sc = cfg.screen
    r = {
        theme: theme
        sky: CreateObject("roBitmap", art + "sky_" + cfg.themeName + ".jpg")
        far: CreateObject("roBitmap", art + "far_" + cfg.themeName + ".png")
        near: CreateObject("roBitmap", art + "near_" + cfg.themeName + ".png")
        screen: screen
        cfg: cfg
        sprites: BuildSprites(cfg)
        fontS: reg.GetDefaultFont(26, false, false)
        fontM: reg.GetDefaultFont(34, true, false)
        fontL: reg.GetDefaultFont(56, true, false)
        fontXL: reg.GetDefaultFont(110, true, false)
    }
    r.mainView = BuildView(cfg, theme, sc.w, sc.h, sc.horizonY, cfg.render.bands)
    UseView(r, r.mainView)
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
    rolls = false
    for each a in cfg.course.roll
        if Abs(a) > 0.5 then rolls = true
    end for
    if cfg.course.loops.Count() > 0 then r.pframe = CreateObject("roBitmap", { width: sc.w, height: sc.h, AlphaEnable: true })
    if rolls then
        ' Rolling frames are drawn on a square canvas as wide as the screen's diagonal, so no corner is ever
        ' empty when it is rotated, with the horizon and centre in the same place relative to its middle.
        rc = cfg.render.roll
        D = rc.size
        rhy = sc.horizonY + (D - sc.h) \ 2
        r.rollView = BuildView(cfg, theme, D, D, rhy, rc.bands)
        r.frame = CreateObject("roBitmap", { width: D, height: D, AlphaEnable: true })
    end if
    return r
end function

' The road samples for one canvas (the screen, or the larger rolling canvas): each band of rows below the
' horizon, its depth and scale, and its colors blended toward the sky color by distance (fog costs nothing per
' frame).
function BuildView(cfg as Object, theme as Object, W as Integer, H as Integer, hy as Integer, spec as Object) as Object
    cam = cfg.camera
    bands = []
    y = hy
    for each bs in spec
        rows = bs[0]
        bh = bs[1]
        last = y + rows
        while y < last
            rowsH = bh
            if y + rowsH > last then rowsH = last - y
            mid = y + rowsH / 2.0 - hy
            if mid < 0.5 then mid = 0.5
            ppu = mid / cam.height          ' px per unit at this row
            bands.Push({ y: y, h: rowsH, ppu: ppu, d: cam.k / ppu })
            y = y + rowsH
        end while
    end for
    rowBand = []
    for i = 0 to bands.Count() - 1
        for rr = 1 to bands[i].h
            rowBand.Push(i)
        end for
    end for
    fc = cfg.fog
    tc = TubeColors(theme)
    ch = [&h3A2E28, &h2E241F]
    if theme.DoesExist("chasm") then ch = theme.chasm
    rk = [&h7C7268, &h72685E]
    if theme.DoesExist("rock") then rk = theme.rock
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
        for each st in tc
            c = tc[st]
            ft = t * 0.5
            fogc = theme.fog
            if st <> "steel" then fogc = &h000000
            b.tube[st] = { wall: [MixColor(c.wall[0], fogc, ft), MixColor(c.wall[1], fogc, ft)], ceil: [MixColor(c.ceil[0], fogc, ft), MixColor(c.ceil[1], fogc, ft)], light: (c.light << 8) or 255 }
        end for
        b.chasm = [MixColor(ch[0], theme.fog, t * 0.7), MixColor(ch[1], theme.fog, t * 0.7)]
        ' land keeps more of its own color in the distance than the road does, so far hills read as hills
        lt = t * 0.55
        b.land = [MixColor(theme.ground[0], theme.fog, lt), MixColor(theme.ground[1], theme.fog, lt)]
        ' height shading so the land's shape reads: valleys in shadow, rises catching the light
        dk = [MixColor(theme.ground[0], &h000000, 0.4), MixColor(theme.ground[1], &h000000, 0.4)]
        lg = [MixColor(theme.ground[0], &hFFFFFF, 0.3), MixColor(theme.ground[1], &hFFFFFF, 0.3)]
        b.landDark = [MixColor((dk[0] >> 8) and &hFFFFFF, theme.fog, lt), MixColor((dk[1] >> 8) and &hFFFFFF, theme.fog, lt)]
        b.landLight = [MixColor((lg[0] >> 8) and &hFFFFFF, theme.fog, lt), MixColor((lg[1] >> 8) and &hFFFFFF, theme.fog, lt)]
        b.rock = [MixColor(rk[0], theme.fog, lt), MixColor(rk[1], theme.fog, lt)]
        b.snow = MixColor(&hF4F7FC, theme.fog, lt)
    end for
    ' ty/tc: per strip (0 road, 1-3 left hills/middle/slope, 4-6 right), each sample's top row and clip row
    v = { W: W, H: H, hy: hy, bands: bands, rowBand: rowBand, sx: [], sy: [], hL: [], hR: [], ty: [], tc: [] }
    for t = 0 to 6
        v.ty.Push([])
        v.tc.Push([])
    end for
    for i = 0 to bands.Count() - 1
        for each key in ["sx", "sy", "hL", "hR"]
            v[key].Push(0)
        end for
        for t = 0 to 6
            v.ty[t].Push(0)
            v.tc[t].Push(0)
        end for
    end for
    return v
end function

' Point the drawing code at a canvas's samples.
sub UseView(r as Object, v as Object)
    r.W = v.W
    r.H = v.H
    r.hy = v.hy
    r.bands = v.bands
    r.rowBand = v.rowBand
    r.sx = v.sx
    r.sy = v.sy
    r.ty = v.ty
    r.tc = v.tc
    r.hL = v.hL
    r.hR = v.hR
end sub

sub DrawFrame(r as Object, s as Object)
    cfg = s.cfg
    roll = 0.0
    if r.frame <> invalid then roll = RollAt(cfg, s.player.s)
    pitch = 0.0
    if r.pframe <> invalid then pitch = PitchAt(cfg, s.player.s)
    scr = r.screen
    rolled = Abs(roll) > 0.5 and Abs(roll - 360) > 0.5 and Abs(roll + 360) > 0.5
    looping = pitch > 0.5 and pitch < 359.5
    if rolled then
        scr = r.frame
        UseView(r, r.rollView)
    else
        UseView(r, r.mainView)
        if looping then scr = r.pframe
    end if
    W = r.W
    H = r.H
    hy = r.hy
    cx = W / 2
    r.skipPlayer = rolled or looping

    ' Sky art, then two parallax ridges that slide with the curves and with sideways moves.
    if W = r.sky.GetWidth() and hy = r.sky.GetHeight() then
        scr.DrawObject(0, 0, r.sky)
    else
        scr.DrawScaledObject(0, 0, W / r.sky.GetWidth(), hy / r.sky.GetHeight(), r.sky)
    end if
    DrawRidge(scr, r.far, s.camX * 6 + s.bgX * 200, hy, W)
    DrawRidge(scr, r.near, s.camX * 14 + s.bgX * 450, hy, W)
    if r.below <> invalid then
        if W = r.below.GetWidth() then
            scr.DrawObject(0, hy, r.below)
        else
            scr.DrawScaledObject(0, hy, W / r.below.GetWidth(), (H - hy) / r.below.GetHeight(), r.below)
        end if
    else
        ' underpaint: land-colored rows by distance, so any gap between land strips reads as ground
        scr.DrawRect(0, hy, W, H - hy, r.bands[0].land[0])
        for each b in r.bands
            if b.d <= cfg.track.drawDist then scr.DrawRect(0, b.y, W, b.h, b.land[Int((s.camZ + b.d) / cfg.track.stripeLen) and 1])
        end for
    end if

    if not looping then
        ProjectRoad(r, s)
        DrawWorld(r, s, scr, cx)
    end if

    if looping then
        ' A loop: the camera rides round with your kart. Behind the loop the world (sky, hills, ground; no road)
        ' pitches past: sky as you climb, the ground overhead at the top, then level again. In front, the loop's
        ' own track is drawn from the kart's point of view, curling up the screen and over, then the road
        ' beyond the exit. Your kart stays on it, upright.
        sh = cfg.screen.h
        scroll = Int(pitch / 360 * 2 * sh)
        r.screen.DrawObject(0, scroll, r.pframe)
        r.screen.DrawObject(0, scroll - 2 * sh, r.pframe)
        r.screen.DrawRotatedObject(cfg.screen.w, scroll, 180, r.pframe)
        DrawLoopTrack(r, s, pitch)
        DrawPlayerUpright(r, s)
    end if
    if rolled then
        ' Rotate the finished canvas about its centre onto the screen's centre, then draw your kart upright
        ' on top: the world turns around you.
        sw = cfg.screen.w
        sh = cfg.screen.h
        a = roll * 3.14159265 / 180
        half = W / 2
        ' Where the canvas's top-left corner lands when it turns theta degrees counter-clockwise about its centre.
        ox = -half * Cos(a) - half * Sin(a)
        oy = half * Sin(a) - half * Cos(a)
        r.screen.DrawRotatedObject(sw / 2 + ox, sh / 2 + oy, roll, r.frame)
        UseView(r, r.mainView)
        DrawPlayerUpright(r, s)
    end if
    DrawHud(r, s)
    if s.paused then DrawPause(r, s)
    if s.finished then DrawResults(r, s)
end sub

' Project every road sample: sideways bend from the curves, height from the hills, and the land on each side
' (an inner slope beside the road and the outer hills beyond it).
sub ProjectRoad(r as Object, s as Object)
    cfg = s.cfg
    scale = cfg.course.curveScale
    maxD = cfg.track.drawDist
    camEl = ElevAt(cfg, s.player.s) + cfg.camera.height + KartHop(cfg, s.player) * cfg.camera.airFollow
    hy = r.hy
    slope = cfg.terrain.slope
    flatRight = r.theme.DoesExist("rightGround")
    x = 0.0
    sl = 0.0
    prevD = 0.0
    cx = r.W / 2
    clips = []
    for t = 0 to 6
        clips.Push(r.H)
    end for
    for i = r.bands.Count() - 1 to 0 step -1
        b = r.bands[i]
        d = b.d
        if d > maxD then d = maxD
        dd = d - prevD
        z = s.camZ + d
        sl = sl + CurveAt(cfg, z) * scale * dd
        x = x + sl * dd
        prevD = d
        y = Int(hy + (camEl - ElevAt(cfg, z)) * b.ppu)
        hl = SideAt(cfg, z, 0)
        hr = SideAt(cfg, z, 1)
        if flatRight then hr = -0.3
        r.sx[i] = x
        r.sy[i] = y
        r.hL[i] = hl
        r.hR[i] = hr
        ' each strip of land, and the road, is a height line seen from the camera: a slice shows only the rows
        ' above everything nearer, so keep the lowest top row seen so far per strip (its clip)
        ys = [y, y - hl * b.ppu, y - hl * (0.5 + slope / 2) * b.ppu, y - hl * slope * b.ppu, y - hr * b.ppu, y - hr * (0.5 + slope / 2) * b.ppu, y - hr * slope * b.ppu]
        ' a strip only hides what's behind it where it is actually on screen (near the camera the road is so wide
        ' that the land beside it is off the edges)
        pieces = RoadPieces(cfg, TrackPos(cfg, z))
        camX = s.camX - x
        xl = cx + (pieces[0].x0 - 0.14 - camX) * b.ppu
        xr = cx + (pieces[pieces.Count() - 1].x1 + 0.14 - camX) * b.ppu
        shw = cfg.terrain.shoulder * b.ppu
        onScreen = [true, xl > 0, false, false, xr < r.W, false, false]
        for t = 0 to 6
            r.ty[t][i] = ys[t]
            r.tc[t][i] = clips[t]
            if onScreen[t] and ys[t] < clips[t] then clips[t] = ys[t]
        end for
    end for
end sub

' Paint the world far to near: each road sample's slice of land, road and tunnel, with every object slotted in
' at its depth, so nearer hills, crests and tunnel walls hide whatever is behind them, even on bends.
sub DrawWorld(r as Object, s as Object, scr as Object, cx as Float)
    cfg = s.cfg
    objs = WorldObjects(r, s)
    n = r.bands.Count()
    maxD = cfg.track.drawDist
    j = 0
    prevCy = -1
    for i = 0 to n - 1
        b = r.bands[i]
        if b.d <= maxD then
            while j < objs.Count() and objs[j].d >= b.d
                DrawThing(r, s, scr, cx, objs[j])
                j = j + 1
            end while
            prevCy = DrawSlice(r, s, scr, cx, i, prevCy)
        end if
    end for
    while j < objs.Count()
        DrawThing(r, s, scr, cx, objs[j])
        j = j + 1
    end while
end sub

' One sample's slice, from its own row down to the next nearer sample's row. Returns the tunnel ceiling row (or
' -1) for the next slice.
function DrawSlice(r as Object, s as Object, scr as Object, cx as Float, i as Integer, prevCy as Float) as Float
    cfg = s.cfg
    W = r.W
    n = r.bands.Count()
    b = r.bands[i]
    z = s.camZ + b.d
    sm = TrackPos(cfg, z)
    stripe = Int(z / cfg.track.stripeLen) and 1
    void = r.below <> invalid
    y = r.sy[i]
    yN = r.tc[0][i]
    pieces = RoadPieces(cfg, sm)
    camX = s.camX - r.sx[i]
    ppu = b.ppu
    xl = cx + (pieces[0].x0 - 0.14 - camX) * ppu
    xr = cx + (pieces[pieces.Count() - 1].x1 + 0.14 - camX) * ppu
    sh = cfg.terrain.shoulder * ppu
    if GapAt(cfg, z) then
        ' The gap of a jump: the land is cut away down to a river, the sea or an abyss.
        if not void and yN > y then scr.DrawRect(0, y, W, yN - y, b.chasm[stripe])
        return -1
    end if
    if not void then
        ' land beside the track: one strip per side, from the screen edge to the road's edge
        LandRect(scr, 0, xl, r.ty[1][i], r.tc[1][i], LandColor(b, r.hL[i], stripe))
        if r.theme.DoesExist("rightGround") then
            LandRect(scr, xr, W, r.ty[4][i], r.tc[4][i], b.right[stripe])
        else
            LandRect(scr, xr, W, r.ty[4][i], r.tc[4][i], LandColor(b, r.hR[i], stripe))
        end if
    end if
    if yN > y then
        ' ground between split tracks, then the road itself
        if not void and pieces.Count() > 1 then scr.DrawRect(xl, y, xr - xl, yN - y, b.ground[stripe])
        row = 0
        if r.tex <> invalid then row = Int(z * r.texPerUnit) mod r.texRows.Count()
        if row < 0 then row = row + r.texRows.Count()
        for each pc in pieces
            DrawRoadPiece(r, scr, b, y, yN - y, cx, camX, pc.x0, pc.x1, pc.lanes, stripe, r.theme.laneStyle, row)
        end for
    end if
    ' tunnels and tubes: walls and a ceiling
    st = TubeStyle(cfg, z)
    if st = "" then return -1
    col = b.tube[st]
    camEl = ElevAt(cfg, s.player.s) + cfg.camera.height + KartHop(cfg, s.player) * cfg.camera.airFollow
    cy = r.hy + (camEl - ElevAt(cfg, z) - 3.4) * ppu
    sxl = cx + (pieces[0].x0 - 0.4 - camX) * ppu
    sxr = cx + (pieces[pieces.Count() - 1].x1 + 0.4 - camX) * ppu
    rib = Int(z / 2) and 1
    if prevCy < 0 then prevCy = cy - 1
    scr.DrawRect(sxl, cy, sxr - sxl, prevCy - cy + 1, col.ceil[rib])
    if sxl > 0 then scr.DrawRect(0, cy, sxl, yN - cy, col.wall[rib])
    if sxr < W then scr.DrawRect(sxr, cy, W - sxr, yN - cy, col.wall[rib])
    if (Int(z) mod 8) = 0 and b.d > 6 then scr.DrawRect(sxl, cy, sxr - sxl, 0.06 * ppu + 1, col.light)
    return cy
end function

sub LandRect(scr as Object, x0 as Float, x1 as Float, y0 as Float, y1 as Float, color as Integer)
    if x1 <= x0 or y1 <= y0 then return
    if x0 < 0 then x0 = 0
    scr.DrawRect(x0, y0, x1 - x0, y1 - y0, color)
end sub

' Land color by height: grass low down, rock up the mountains, snow on the tops.
function LandColor(b as Object, h as Float, stripe as Integer) as Integer
    if h > 16 then return b.snow
    if h > 9 then return b.rock[stripe]
    if h > 3 then return b.landLight[stripe]
    if h < -1.2 then return b.landDark[stripe]
    return b.land[stripe]
end function

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

sub DrawRidge(scr as Object, bmp as Object, shift as Float, hy as Integer, W as Integer)
    if bmp = invalid then return
    bw = bmp.GetWidth()
    x = -(Int(shift) mod bw)
    if x > 0 then x = x - bw
    y = hy - bmp.GetHeight()
    scr.DrawObject(x, y, bmp)
    while x + bw < W
        x = x + bw
        scr.DrawObject(x, y, bmp)
    end while
end sub

' Sample index for depth d.
function SampleAt(r as Object, s as Object, d as Float) as Integer
    row = Int(s.cfg.camera.height * s.cfg.camera.k / d)
    if row < 0 then row = 0
    if row >= r.rowBand.Count() then row = r.rowBand.Count() - 1
    return r.rowBand[row]
end function

' Everything drawn as a sprite this frame, far to near: scenery on the land, landmarks, loops, tunnel mouths,
' ramps, hanging girders, item blocks, traffic, pucks, bananas and karts. `land` puts a thing on the slope (1)
' or the hills (2) beside the road instead of on the road; `top` hangs it from the road's edge.
function WorldObjects(r as Object, s as Object) as Object
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
        if d > nearD and not GapAt(cfg, tpos) then
            sm = TrackPos(cfg, tpos)
            pieces = RoadPieces(cfg, sm)
            idx = Int(tpos / every)
            kinds = th.scenery
            gap = th.gap
            if r.below = invalid then
                list.Push({ d: d, x: pieces[0].x0 - gap, k: kinds[idx mod kinds.Count()], h: 0, land: 1, side: 0 })
                list.Push({ d: d + 0.01, x: pieces[0].x0 - gap - 5, k: kinds[(idx + 2) mod kinds.Count()], h: 0, land: 2, side: 0 })
                if not th.DoesExist("rightGround") then
                    list.Push({ d: d, x: pieces[pieces.Count() - 1].x1 + gap, k: kinds[(idx + 1) mod kinds.Count()], h: 0, land: 1, side: 1 })
                    list.Push({ d: d + 0.01, x: pieces[pieces.Count() - 1].x1 + gap + 5, k: kinds[(idx + 3) mod kinds.Count()], h: 0, land: 2, side: 1 })
                end if
            else
                list.Push({ d: d, x: pieces[0].x0 - gap, k: kinds[idx mod kinds.Count()], h: 0 })
                list.Push({ d: d, x: pieces[pieces.Count() - 1].x1 + gap, k: kinds[(idx + 1) mod kinds.Count()], h: 0 })
            end if
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

    if th.DoesExist("hang") then
        every = th.hangEvery
        tpos = (Int(s.camZ / every) + 1) * every
        while tpos < s.camZ + far
            d = tpos - s.camZ
            if d > nearD then
                pieces = RoadPieces(cfg, TrackPos(cfg, tpos))
                list.Push({ d: d, x: pieces[0].x0 - 1.1, k: th.hang, h: 0, top: true })
                list.Push({ d: d, x: pieces[pieces.Count() - 1].x1 + 1.1, k: th.hang, h: 0, top: true })
            end if
            tpos = tpos + every
        end while
    end if

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
                if d > nearD and d < far then
                    o = { d: d, x: lm.x, k: lm.k, h: 0 }
                    if lm.x < -4 then
                        o.land = 2
                        o.side = 0
                    else if lm.x > 4 then
                        o.land = 2
                        o.side = 1
                    end if
                    list.Push(o)
                end if
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
        else if not r.skipPlayer then
            list.Push({ d: cfg.camera.playerDepth, x: KartX(s, kt) + wob, k: "player" + ang, h: hop })
        end if
    end for
    keep = []
    for each o in list
        if o.d > nearD and o.d < far then keep.Push(o)
    end for
    keep.SortBy("d", "r")
    return keep
end function

sub DrawThing(r as Object, s as Object, scr as Object, cx as Float, o as Object)
    cfg = s.cfg
    i = SampleAt(r, s, o.d)
    ppu = cfg.camera.k / o.d
    sx = cx + (o.x - s.camX + r.sx[i]) * ppu
    sy = r.sy[i]
    if o.DoesExist("land") then
        ' on the slope (land 1) or the hills (land 2), left (side 0) or right
        t = 1
        if o.side = 1 then t = 4
        sy = r.ty[t][i]
    end if
    sy = sy - o.h * ppu
    if Left(o.k, 6) = "player" then
        DrawKart(r, s, scr, sx, sy, o.k)
        return
    end if
    lv = r.sprites.byName[o.k]
    if lv = invalid then return
    img = lv[SpriteLevel(r.sprites, ppu)]
    if o.DoesExist("top") then
        scr.DrawObject(sx - img.w / 2, sy - 0.6 * ppu, img.bmp)
    else
        scr.DrawObject(sx - img.w / 2, sy - img.h, img.bmp)
    end if
end sub

''' The loop's track seen from your kart: sample the circle ahead (and the straight after the exit) in the kart's
' own frame, project each point, and paint the ribbon far to near.
sub DrawLoopTrack(r as Object, s as Object, pitch as Float)
    cfg = s.cfg
    cam = cfg.camera
    k = cam.k
    c = cam.playerDepth
    camH = cam.height
    hy = cfg.screen.horizonY
    W = cfg.screen.w
    H = cfg.screen.h
    loopLen = LoopLenAt(cfg, s.player.s)
    rad = loopLen / 6.2831853
    remaining = 360 - pitch
    cx0 = W / 2 - s.camX * k / c
    b0 = r.mainView.bands[r.mainView.bands.Count() - 1]
    halfW = cfg.lanes.count / 2.0
    pts = []
    a = 0.0
    while a <= remaining and a <= 179
        ar = a * 3.14159265 / 180
        pts.Push({ f: rad * Sin(ar), u: rad * (1 - Cos(ar)), along: rad * ar })
        ' fine steps near the kart, coarser further round
        a = a + 0.4 + a * 0.04
    end while
    if remaining <= 179 then
        ' the straight road after the exit, along the track's direction there
        ar = remaining * 3.14159265 / 180
        f0 = rad * Sin(ar)
        u0 = rad * (1 - Cos(ar))
        for t = 2 to 90 step 3
            pts.Push({ f: f0 + t * Cos(ar), u: u0 + t * Sin(ar), along: rad * ar + t })
        end for
    end if
    segs = []
    for i = 1 to pts.Count() - 1
        p0 = pts[i - 1]
        p1 = pts[i]
        d0 = p0.f + c
        d1 = p1.f + c
        if d0 > 0.8 and d1 > 0.8 then
            y0 = hy - (p0.u - camH) * k / d0
            y1 = hy - (p1.u - camH) * k / d1
            dn = d0
            if d1 < dn then dn = d1
            segs.Push({ depth: (d0 + d1) / 2, y0: y0, y1: y1, ppu: k / dn, along: p1.along })
        end if
    end for
    segs.SortBy("depth", "r")
    for each sg in segs
        top = sg.y0
        bot = sg.y1
        if bot < top then
            top = sg.y1
            bot = sg.y0
        end if
        if bot - top < 1 then bot = top + 1
        if bot > 0 and top < H then
            stripe = Int((s.player.s + sg.along) / cfg.track.stripeLen) and 1
            hw = halfW * sg.ppu
            rw = 0.14 * sg.ppu + 1
            r.screen.DrawRect(cx0 - hw - rw, top, rw, bot - top, b0.rumble[stripe])
            r.screen.DrawRect(cx0 + hw, top, rw, bot - top, b0.rumble[stripe])
            r.screen.DrawRect(cx0 - hw, top, 2 * hw, bot - top, b0.road[stripe])
        end if
    end for
    ' the road under and just in front of the kart, in perspective down to the bottom of the screen
    yk = Int(hy + camH * k / c)
    y = yk
    while y < H
        ppu = (y + 3 - hy) / camH
        hw = halfW * ppu
        rw = 0.14 * ppu + 1
        stripe = Int((s.player.s - camH * k / (y - hy + 0.1) + c) / cfg.track.stripeLen) and 1
        r.screen.DrawRect(cx0 - hw - rw, y, rw, 6, b0.rumble[stripe])
        r.screen.DrawRect(cx0 + hw, y, rw, 6, b0.rumble[stripe])
        r.screen.DrawRect(cx0 - hw, y, 2 * hw, 6, b0.road[stripe])
        y = y + 6
    end while
end sub

' Your kart drawn straight onto the screen at its usual spot, over a rolled or pitched world.
sub DrawPlayerUpright(r as Object, s as Object)
    cfg = s.cfg
    ppu = cfg.camera.k / cfg.camera.playerDepth
    hop = KartHop(cfg, s.player) * (1 - cfg.camera.airFollow)
    name = "player"
    if r.sprites.angled then name = "player" + KartAngle(cfg, s.player)
    DrawKart(r, s, r.screen, cfg.screen.w / 2 + (PlayerX(s) - s.camX) * ppu, cfg.screen.horizonY + (cfg.camera.height - hop) * ppu, name)
end sub

' How high a kart is off the road: a lane-change hop plus airtime.
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
