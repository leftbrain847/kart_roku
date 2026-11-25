' Sprites are drawn once at startup from rectangles into bitmaps at every scale the game needs
' ("pre-scaled"), so a frame only copies bitmaps: no scaling and no per-pixel work while racing.


' Copy `src` into a new bitmap of w x h. Alpha blending is off on the target so the art's transparency is copied.
function ScaledCopy(src as Object, w as Integer, h as Integer) as Object
    if w < 1 then w = 1
    if h < 1 then h = 1
    bmp = CreateObject("roBitmap", { width: w, height: h, AlphaEnable: false })
    bmp.Clear(&h00000000)
    bmp.DrawScaledObject(0, 0, w / src.GetWidth(), h / src.GetHeight(), src)
    bmp.Finish()
    return { bmp: bmp, w: w, h: h }
end function

' Load a PNG once and make every pre-scaled copy, largest first, each shrunk from the one above it so small
' copies stay smooth. Copies bigger than render.maxSpritePx reuse the largest allowed one.
function LoadSprite(cfg as Object, path as String, worldW as Float, out as Object) as Dynamic
    src = CreateObject("roBitmap", path)
    if src = invalid then
        print "missing art: " + path
        return invalid
    end if
    rc = cfg.render
    aspect = src.GetHeight() / src.GetWidth()
    arr = []
    prev = src
    for j = out.levels - 1 to 0 step -1
        ppu = rc.minPpu * Exp(out.logRatio * j)
        w = Int(worldW * ppu + 0.5)
        h = Int(worldW * aspect * ppu + 0.5)
        if w <= rc.maxSpritePx and h <= rc.maxSpritePx then
            copy = ScaledCopy(prev, w, h)
            arr[j] = copy
            prev = copy.bmp
        end if
    end for
    for j = 1 to out.levels - 1
        if arr[j] = invalid then arr[j] = arr[j - 1]
    end for
    return { levels: arr, src: src, aspect: aspect }
end function

' The sprites this race needs (theme scenery, items, traffic, one kart per racer), each pre-scaled at
' cfg.render.spriteLevels sizes, plus your kart at its fixed on-screen size and the HUD item icons.
function BuildSprites(cfg as Object) as Object
    rc = cfg.render
    levels = rc.spriteLevels
    logRatio = Log(rc.maxPpu / rc.minPpu) / (levels - 1)
    out = { levels: levels, logRatio: logRatio, minPpu: rc.minPpu, byName: {}, hudItems: {} }
    widths = SpriteWidths()
    dir = "pkg:/images/sprites/"
    list = {}
    for each name in ["car", "block", "shell", "banana", "boost"]
        list[name] = { path: dir + name + ".png", w: widths[name] }
    end for
    th = Themes()[cfg.themeName]
    props = []
    props.Append(th.scenery)
    if th.DoesExist("median") then props.Push(th.median)
    if th.DoesExist("hang") then props.Push(th.hang)
    if th.DoesExist("landmarks") then
        for each lm in th.landmarks
            props.Push(lm.k)
        end for
    end if
    if cfg.course.DoesExist("loops") and cfg.course.loops.Count() > 0 then props.Push("loopring")
    if cfg.course.DoesExist("jumps") and cfg.course.jumps.Count() > 0 then props.Push("ramp")
    if cfg.course.DoesExist("tunnels") then
        for each tn in cfg.course.tunnels
            if tn.style <> "steel" then props.Push("portal_" + tn.style)
        end for
    end if
    for each name in props
        list[name] = { path: dir + name + ".png", w: widths[name] }
    end for
    out.angled = true
    for i = 0 to cfg.bots.count
        for each a in ["c", "l", "r"]
            list["kart" + i.ToStr() + a] = { path: dir + "racer_" + cfg.racers[i] + "_" + a + ".png", w: widths.racer }
        end for
    end for
    for each name in list
        sp = LoadSprite(cfg, list[name].path, list[name].w, out)
        if sp <> invalid then
            out.byName[name] = sp.levels
            if Left(name, 5) = "kart0" then
                ppu = cfg.camera.k / cfg.camera.playerDepth
                kw = widths.racer
                out["player" + Mid(name, 6)] = ScaledCopy(sp.src, Int(kw * ppu + 0.5), Int(kw * sp.aspect * ppu + 0.5))
            else if name = "shell" or name = "banana" or name = "boost" then
                out.hudItems[name] = ScaledCopy(sp.src, Int(90 / sp.aspect), 90)
                if out.hudItems[name].w > 100 then out.hudItems[name] = ScaledCopy(sp.src, 100, Int(100 * sp.aspect))
            end if
        end if
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
