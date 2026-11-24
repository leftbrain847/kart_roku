' Kart: entry point and frame loop. roScreen + Draw2D, double-buffered at 1280x720.
' Deep link autotest=1 runs a scripted 20-second race with a fixed timestep, prints a summary and exits
' (used by tests/brs.test.mjs through brs-cli). Adding shots=1 also prints a few frames as base64 PNGs.
sub Main(args as Dynamic)
    cfg = GameConfig()
    errs = ValidateConfig(cfg)
    if errs.Count() > 0 then
        for each e in errs
            print "CONFIG ERROR: " + e
        end for
        return
    end if
    auto = false
    shots = false
    if type(args) = "roAssociativeArray" and args.autotest <> invalid then
        auto = true
        shots = args.shots <> invalid
    end if

    screen = CreateObject("roScreen", true, cfg.screen.w, cfg.screen.h)
    screen.SetAlphaEnable(true)
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    r = NewRenderer(cfg, screen)

    seed = CreateObject("roDateTime").AsSeconds() mod 100000 + 1
    if auto then seed = 42
    s = NewGame(cfg, seed)
    s.best = LoadBest(cfg)

    if auto then
        RunAutotest(r, s, shots)
        return
    end if

    clock = CreateObject("roTimespan")
    while true
        msg = port.GetMessage()
        while msg <> invalid
            if type(msg) = "roUniversalControlEvent" then
                if HandleKey(s, msg.GetInt()) = "exit" then return
            end if
            msg = port.GetMessage()
        end while
        dt = clock.TotalMilliseconds() / 1000.0
        clock.Mark()
        UpdateGame(s, dt)
        if s.newBest then
            SaveBest(cfg, s.best)
            s.newBest = false
        end if
        DrawFrame(r, s)
        screen.SwapBuffers()
    end while
end sub

function LoadBest(cfg as Object) as Float
    sec = CreateObject("roRegistrySection", "kart")
    v = sec.Read(cfg.bestKey)
    if v = "" then return -1
    return v.ToInt() / 1000.0
end function

sub SaveBest(cfg as Object, best as Float)
    sec = CreateObject("roRegistrySection", "kart")
    sec.Write(cfg.bestKey, Int(best * 1000).ToStr())
    sec.Flush()
end sub

' Scripted race: steer, take a fork, use items, pause, toggle traffic. Every frame is drawn.
sub RunAutotest(r as Object, s as Object, shots as Boolean)
    k = Keys()
    script = {}
    script["10"] = k.left
    script["14"] = k.left
    script["120"] = k.up
    script["200"] = k.ok
    script["260"] = k.down
    script["300"] = k.play
    script["301"] = k.down
    script["302"] = k.ok
    script["303"] = k.play
    script["420"] = k.right
    script["480"] = k.up
    script["540"] = k.ok
    frames = 600
    timer = CreateObject("roTimespan")
    routes = ""
    for f = 1 to frames
        key = script[f.ToStr()]
        if key <> invalid then HandleKey(s, key)
        for each e in UpdateGame(s, 1 / 30)
            if Left(e, 6) = "route:" then routes = routes + Mid(e, 7) + " "
        end for
        DrawFrame(r, s)
        if shots and (f = 90 or f = 240 or f = 301 or f = 470) then
            print "SHOT " + f.ToStr() + " " + r.screen.GetPng(0, 0, s.cfg.screen.w, s.cfg.screen.h).ToBase64String()
        end if
        r.screen.SwapBuffers()
    end for
    ms = timer.TotalMilliseconds()
    traffic = "on"
    if not s.trafficOn then traffic = "off"
    print "AUTOTEST frames=" + frames.ToStr() + " dist=" + Int(s.player.s).ToStr() + " items=" + s.stats.items.ToStr() + " boosts=" + s.stats.boosts.ToStr() + " routes=" + routes + "traffic=" + traffic + " ms=" + ms.ToStr()
    print "AUTOTEST OK"
end sub
