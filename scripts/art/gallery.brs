' Stages screenshots through the real renderer and prints each frame as a base64 PNG ("SHOT name data").
' Run from a package folder holding manifest, images/ and source/ (without main.brs) plus this file:
'   npx brs-cli -n -r PKG PKG/source/*.brs [-k only=name]
sub Main(args as Dynamic)
    screen = CreateObject("roScreen", true, 1280, 720)
    screen.SetAlphaEnable(true)
    font = CreateObject("roFontRegistry").GetDefaultFont(30, true, false)
    only = ""
    if type(args) = "roAssociativeArray" and args.only <> invalid then only = args.only
    shots = [
        { w: "whirligig", r: "teapot", at: 172, sim: 0.1, name: "whirl_1", label: "WHIRLIGIG WOODS  candy mountain" }
        { w: "whirligig", r: "teapot", at: 262, sim: 0.1, name: "whirl_2", label: "WHIRLIGIG WOODS  inside the tunnel" }
        { w: "whirligig", r: "teapot", at: 557, sim: 0.45, name: "whirl_3", label: "WHIRLIGIG WOODS  big air" }
        { w: "whirligig", r: "teapot", at: 1515, sim: 0.1, name: "whirl_4", label: "WHIRLIGIG WOODS  barrel roll" }
        { w: "whirligig", r: "duckboat", at: 1572, sim: 0.1, name: "whirl_5", label: "WHIRLIGIG WOODS  loop ahead" }
        { w: "meadow", r: "gearsnail", at: 286, sim: 0.1, name: "meadow_loop", label: "GREEN MEADOW  up the loop" }
        { w: "jungle", r: "hatchling", at: 852, sim: 0.1, name: "jungle_tunnel", label: "FERNBACK JUNGLE  into the volcano" }
        { w: "jungle", r: "triceracart", at: 557, sim: 0.4, name: "jungle_jump", label: "FERNBACK JUNGLE  river jump" }
        { w: "snow", r: "jelly", at: 736, sim: 0.1, name: "snow_tunnel", label: "SNOW PASS  mountain tunnel" }
        { w: "skytrack", r: "toaster", at: 927, sim: 0.45, name: "sky_jump", label: "GIRDER SKY  platform jump" }
        { w: "meadow", r: "toaster", at: 1100, sim: 0.1, name: "terr_meadow", label: "GREEN MEADOW  hills and valleys" }
        { w: "snow", r: "jelly", at: 1020, sim: 0.1, name: "terr_snow", label: "SNOW PASS  mountains" }
        { w: "desert", r: "triceracart", at: 1250, sim: 0.1, name: "terr_desert", label: "MESA DESERT  rolling dunes" }
        { w: "volcano", r: "gearsnail", at: 1450, sim: 0.1, name: "terr_volcano", label: "LAVA FIELDS  ridges" }
        { w: "pebble", r: "hermit", at: 1612, sim: 0.05, name: "lp_0", label: "PEBBLE COVE  loop 0" }
        { w: "pebble", r: "hermit", at: 1639, sim: 0.05, name: "lp_1", label: "PEBBLE COVE  loop 1" }
        { w: "pebble", r: "hermit", at: 1666, sim: 0.05, name: "lp_2", label: "PEBBLE COVE  loop 2" }
        { w: "pebble", r: "hermit", at: 1688, sim: 0.05, name: "lp_3", label: "PEBBLE COVE  loop 3" }
        { w: "pebble", r: "hermit", at: 1723, sim: 0.05, name: "lp_4", label: "PEBBLE COVE  loop 4" }
        { w: "pebble", r: "hermit", at: 1750, sim: 0.05, name: "lp_5", label: "PEBBLE COVE  loop 5" }
        { w: "pebble", r: "hermit", at: 1590, sim: 0.1, name: "loop_a", label: "PEBBLE COVE  loop entry" }
        { w: "pebble", r: "hermit", at: 1640, sim: 0.1, name: "loop_b", label: "PEBBLE COVE  up the loop" }
        { w: "pebble", r: "hermit", at: 1680, sim: 0.1, name: "loop_c", label: "PEBBLE COVE  top of the loop" }
        { w: "pebble", r: "hermit", at: 1720, sim: 0.1, name: "loop_d", label: "PEBBLE COVE  coming down" }
    ]
    for each sh in shots
        if only = "" or Instr(1, sh.name, only) > 0 then Shot(screen, font, sh)
    end for
end sub

sub Shot(screen as Object, font as Object, sh as Object)
    cfg = GameConfig()
    SetupRace(cfg, sh.w, sh.r)
    cfg.race.countdown = 0
    cfg.traffic.perSecond = 0
    r = NewRenderer(cfg, screen)
    s = NewGame(cfg, 42)
    p = s.player
    p.s = sh.at
    p.speed = cfg.speed.max
    p.item = "boost"
    lanes = [1, 3, 0]
    gaps = [7, 11, 17]
    for i = 1 to s.karts.Count() - 1
        k = s.karts[i]
        k.lane = lanes[i - 1]
        k.laneF = k.lane
        k.s = sh.at + gaps[i - 1]
        k.speed = cfg.speed.max
        k.skill = 1
        k.think = 99
    end for
    s.camX = PlayerX(s)
    n = Int(sh.sim * 30 + 0.5)
    for f = 1 to n
        UpdateGame(s, 1 / 30)
    end for
    for pass = 1 to 2
        DrawFrame(r, s)
        screen.DrawRect(340, 650, 600, 52, &h0B0F23C8)
        screen.DrawText(sh.label, 360, 658, &hFFD23FFF, font)
        if pass = 2 then print "SHOT " + sh.name + " " + screen.GetPng(0, 0, 1280, 720).ToBase64String()
        screen.SwapBuffers()
    end for
end sub
