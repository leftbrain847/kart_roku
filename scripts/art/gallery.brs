' Renders design options through the real renderer; prints each frame as base64 PNG.
sub Main(args as Dynamic)
    screen = CreateObject("roScreen", true, 1280, 720)
    screen.SetAlphaEnable(true)
    reg = CreateObject("roFontRegistry")
    font = reg.GetDefaultFont(30, true, false)
    which = "all"
    if type(args) = "roAssociativeArray" and args.which <> invalid then which = args.which
    styles = KartStyles()
    themes = ThemeNames()
    if which = "all" or which = "karts" then
        for i = 0 to styles.Count() - 1
            Shot(screen, font, styles[i], "meadow", 170, "kart_" + (i + 1).ToStr(), "KART " + (i + 1).ToStr() + "/10  " + UCase(styles[i]), true)
        end for
    end if
    if which = "all" or which = "roads" then
        for i = 0 to themes.Count() - 1
            Shot(screen, font, "classic", themes[i], 468, "road_" + (i + 1).ToStr(), "ROAD " + (i + 1).ToStr() + "/10  " + UCase(themes[i]), false)
        end for
    end if
end sub

sub Shot(screen as Object, font as Object, style as String, theme as String, at as Float, name as String, label as String, inset as Boolean)
    cfg = GameConfig()
    cfg.kartStyle = style
    cfg.themeName = theme
    cfg.race.countdown = 0
    cfg.traffic.perSecond = 0
    r = NewRenderer(cfg, screen)
    s = NewGame(cfg, 42)
    lanes = [2, 1, 3, 4]
    gaps = [0, 3.2, 5.5, 9]
    for i = 0 to s.karts.Count() - 1
        k = s.karts[i]
        k.s = at + gaps[i]
        k.lane = lanes[i]
        k.laneF = lanes[i]
        k.speed = cfg.speed.max
        k.skill = 1
        k.think = 99
    end for
    s.player.item = "shell"
    s.traffic.Push({ s: at + 40, lane: 0, v: 12 })
    s.camX = PlayerX(s)
    UpdateGame(s, 0.05)
    s.camX = PlayerX(s)
    for pass = 1 to 2
        DrawFrame(r, s)
        if inset then
            src = CreateObject("roBitmap", "pkg:/images/sprites/kart_" + style + "_0.png")
            sc = 300 / src.GetWidth()
            screen.DrawRect(940, 190, 320, 20 + src.GetHeight() * sc, &h0B0F23A0)
            screen.DrawScaledObject(950, 200, sc, sc, src)
        end if
        screen.DrawRect(380, 650, 520, 52, &h0B0F23C8)
        screen.DrawText(label, 400, 658, &hFFD23FFF, font)
        if pass = 2 then print "SHOT " + name + " " + screen.GetPng(0, 0, 1280, 720).ToBase64String()
        screen.SwapBuffers()
    end for
end sub
