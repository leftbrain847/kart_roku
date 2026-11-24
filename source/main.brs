' Kart: entry point and frame loop. roScreen + Draw2D, double-buffered at 1280x720.
' Deep link autotest=1 runs a scripted 20-second race with a fixed timestep, prints a summary and exits
' (used by tests/brs.test.mjs through brs-cli). Adding shots=1 also prints a few frames as base64 PNGs.
sub Main(args as Dynamic)
    base = GameConfig()
    errs = ValidateConfig(base)
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

    screen = CreateObject("roScreen", true, base.screen.w, base.screen.h)
    screen.SetAlphaEnable(true)
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    if auto then
        RunAutotest(screen, shots)
        return
    end if

    sel = { track: 0, racer: 0 }
    while true
        pick = RunMenu(screen, port, base, sel)
        if pick = invalid then return
        DrawLoading(screen, base, pick.track)
        if RunRace(screen, port, pick) = "exit" then return
    end while
end sub

' One race on the picked track. Returns "exit" (Back) or "menu" (back to the title screen).
function RunRace(screen as Object, port as Object, pick as Object) as String
    cfg = GameConfig()
    SetupRace(cfg, pick.track, pick.racer)
    r = NewRenderer(cfg, screen)
    s = NewGame(cfg, CreateObject("roDateTime").AsSeconds() mod 100000 + 1)
    s.best = LoadBest(cfg)
    clock = CreateObject("roTimespan")
    while true
        msg = port.GetMessage()
        while msg <> invalid
            if type(msg) = "roUniversalControlEvent" then
                act = HandleKey(s, msg.GetInt())
                if act <> "" then return act
            end if
            msg = port.GetMessage()
        end while
        dt = clock.TotalMilliseconds() / 1000.0
        clock.Mark()
        if dt > 0 then s.fps = s.fps * 0.9 + (1 / dt) * 0.1
        UpdateGame(s, dt)
        if s.newBest then
            SaveBest(cfg, s.best)
            s.newBest = false
        end if
        DrawFrame(r, s)
        screen.SwapBuffers()
    end while
    return "exit"
end function

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

' Scripted race: countdown, steer, items, pause menu, a jump across the first split. Every frame is drawn.
' Runs at the original faster speeds so the script reaches the first split. Then each world is drawn at its
' hills, tube and corkscrew to check the renderer end to end.
sub RunAutotest(screen as Object, shots as Boolean)
    cfg = GameConfig()
    SetupRace(cfg, "meadow", "hatchling")
    cfg.speed.max = 34
    cfg.speed.accel = 14
    r = NewRenderer(cfg, screen)
    s = NewGame(cfg, 42)
    k = Keys()
    script = {}
    script["100"] = k.left
    script["104"] = k.left
    script["200"] = k.up
    script["260"] = k.ok
    script["300"] = k.down
    script["330"] = k.play
    script["331"] = k.down
    script["332"] = k.ok
    script["333"] = k.play
    script["540"] = k.right
    script["548"] = k.right
    script["620"] = k.up
    frames = 700
    timer = CreateObject("roTimespan")
    tracks = ""
    for f = 1 to frames
        key = script[f.ToStr()]
        if key <> invalid then HandleKey(s, key)
        for each e in UpdateGame(s, 1 / 30)
            if Left(e, 6) = "track:" then tracks = tracks + Mid(e, 7) + " "
        end for
        DrawFrame(r, s)
        if shots and (f = 240 or f = 545) then
            print "SHOT " + f.ToStr() + " " + screen.GetPng(0, 0, s.cfg.screen.w, s.cfg.screen.h).ToBase64String()
        end if
        screen.SwapBuffers()
    end for
    ms = timer.TotalMilliseconds()
    traffic = "on"
    if not s.trafficOn then traffic = "off"
    print "AUTOTEST frames=" + frames.ToStr() + " dist=" + Int(s.player.s).ToStr() + " items=" + s.stats.items.ToStr() + " jumps=" + s.stats.jumps.ToStr() + " karts=" + s.karts.Count().ToStr() + " botItems=" + s.stats.botItems.ToStr() + " tracks=" + tracks + "traffic=" + traffic + " ms=" + ms.ToStr()

    stops = { jungle: [210, 300, 480], skytrack: [190, 350, 590], pebble: [300, 360, 1205], meadow: [240, 325, 1300, 1675] }
    done = ""
    for each w in ["jungle", "skytrack", "pebble", "meadow"]
        c2 = GameConfig()
        SetupRace(c2, w, "toaster")
        r2 = NewRenderer(c2, screen)
        s2 = NewGame(c2, 7)
        s2.countdown = 0
        for each at in stops[w]
            s2.player.s = at
            for i = 1 to s2.karts.Count() - 1
                s2.karts[i].s = at + 4 * i
            end for
            for f = 1 to 10
                UpdateGame(s2, 1 / 30)
                DrawFrame(r2, s2)
                screen.SwapBuffers()
            end for
            if shots then print "SHOT " + w + at.ToStr() + " " + screen.GetPng(0, 0, 1280, 720).ToBase64String()
        end for
        done = done + w + " "
    end for
    print "AUTOTEST WORLDS " + done
    print "AUTOTEST OK"
end sub
