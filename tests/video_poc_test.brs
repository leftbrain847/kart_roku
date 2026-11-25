' Unit tests for the video-track POC logic (video_poc/source/logic.brs). Run by tests/video_poc.test.mjs.
sub Main()
    t = { pass: 0, fail: 0 }
    TestTables(t)
    TestPlacement(t)
    TestAngles(t)
    TestForks(t)
    TestZoom(t)
    TestRace(t)
    print "RESULT pass=" + t.pass.ToStr() + " fail=" + t.fail.ToStr()
end sub

sub Check(t as Object, ok as Boolean, name as String)
    if ok then
        t.pass = t.pass + 1
    else
        t.fail = t.fail + 1
        print "FAIL " + name
    end if
end sub

function Near(a as Float, b as Float, tol as Float) as Boolean
    return Abs(a - b) <= tol
end function

' Two rows (t = 0 and t = 0.5 s at 2 Hz), two depths (0 and 10 m).
function FakeLanes() as Object
    return { rate: 2, depths: [0, 10], tables: { shared_left: [[600, 500, 50, 0, 600, 300, 10, 20], [700, 520, 60, 10, 700, 320, 20, 30]] } }
end function

sub TestTables(t as Object)
    L = FakeLanes()
    rows = L.tables.shared_left
    s = TableSample(L, rows, 0, 0)
    Check(t, s.x = 600 and s.y = 500 and s.ppm = 50 and s.yaw = 0, "table: first row, first depth")
    s = TableSample(L, rows, 0.25, 5)
    Check(t, Near(s.x, 650, 0.01) and Near(s.y, 410, 0.01) and Near(s.ppm, 35, 0.01) and Near(s.yaw, 15, 0.01), "table: halfway in time and depth")
    s = TableSample(L, rows, 9, 50)
    Check(t, s.x = 700 and s.y = 320, "table: clamps past the last row and deepest depth")
    s = TableSample(L, rows, -1, -9)
    Check(t, s.x = 600 and s.y = 500, "table: clamps before the start")
    Check(t, TableKey("shared", "right") = "shared_right" and TableKey("left", "right") = "left", "table keys")
end sub

sub TestPlacement(t as Object)
    cfg = PocConfig()
    sprite = { w: 200, h: 100, anchorX: 100, anchorY: 70, pxPerM: 40 }
    s = { x: 640, y: 480, ppm: 80, yaw: 0 }
    p = KartPlace(cfg, s, sprite, 2, 0, 0)
    Check(t, p.x = 640 and p.scale = 2 and p.w = 400 and p.h = 200 and p.left = 440 and p.top = 340 and p.angle = 0, "middle lane sits on the road centre, scaled by px per metre")
    p = KartPlace(cfg, s, sprite, 4, 0, 0)
    Check(t, Near(p.x, 640 + 80 * 7.2, 0.01), "lane 4 is two lane widths right")
    Check(t, p.angle = 3, "a kart right of centre is seen a little from its left side")
    p = KartPlace(cfg, s, sprite, 2, 0, 180)
    Check(t, p.angle = 12, "spinning turns the sprite round")
    p = KartPlace(cfg, { x: 640, y: 480, ppm: 80, yaw: 30 }, sprite, 2, 0, 0)
    Check(t, p.angle = 22, "road bending left points the kart left")
end sub

sub TestAngles(t as Object)
    Check(t, AngleIndex(0, 24) = 0 and AngleIndex(7, 24) = 0 and AngleIndex(8, 24) = 1, "angle rounding")
    Check(t, AngleIndex(-15, 24) = 23 and AngleIndex(360, 24) = 0 and AngleIndex(-370, 24) = 23, "angles wrap")
end sub

sub TestForks(t as Object)
    cfg = PocConfig()
    Check(t, PickBranch(0, "right") = "left" and PickBranch(1, "right") = "left", "left lanes take the left fork")
    Check(t, PickBranch(3, "left") = "right" and PickBranch(4, "left") = "right", "right lanes take the right fork")
    Check(t, PickBranch(2, "right") = "right" and PickBranch(2, "left") = "left", "middle lane keeps the last pick")
    ct = CommitTime(cfg, 4.0, 0)
    Check(t, Near(ct, 4.0 - 12 / 32, 0.001), "you commit as your kart reaches the fork, 0.375 s before the cut")
    Check(t, CommitTime(cfg, 4.0, 8) < ct, "karts further ahead commit earlier")
end sub

sub TestZoom(t as Object)
    z = ZoomTransform(1, 900, 470)
    Check(t, z.tx = 0 and z.ty = 0 and z.w = 1280, "no zoom, no shift")
    z = ZoomTransform(1.25, 640, 470)
    Check(t, Near(z.tx, -160, 0.01) and Near(z.ty, -117.5, 0.01) and z.w = 1600 and z.h = 900, "zoom centres your lane and keeps the kart row in place")
    z = ZoomTransform(1.25, 0, 0)
    Check(t, z.tx = 0 and z.ty = 0, "never shows past the left or top edge")
    z = ZoomTransform(1.25, 1280, 2000)
    Check(t, z.tx = -320 and z.ty = -180, "never shows past the right or bottom edge")
end sub

sub TestRace(t as Object)
    cfg = PocConfig()
    r = NewRace(cfg)
    Check(t, r.karts.Count() = 4 and Player(r).isPlayer and r.charges = 3, "you plus 3 bots, 3 boosts")
    RaceInput(cfg, r, "left")
    RaceInput(cfg, r, "left")
    Check(t, Player(r).target = 0 and r.pick = "left", "steering left picks the left fork")
    Check(t, not RaceInput(cfg, r, "left"), "no lane left of lane 0")
    for i = 1 to 4
        RaceInput(cfg, r, "right")
    end for
    Check(t, Player(r).target = 4 and r.pick = "right", "steering right picks the right fork")
    for i = 1 to 30
        RaceStep(cfg, r, 1 / 30, "shared", 0.5, 4.0)
    end for
    Check(t, Player(r).lane = 4, "lane slide finishes")
    Check(t, Player(r).branch = "right" and not Player(r).committed, "before the fork your pick can still change")
    RaceStep(cfg, r, 1 / 30, "shared", 3.9, 4.0)
    Check(t, Player(r).committed, "committed once the kart reaches the fork")
    RaceInput(cfg, r, "left")
    RaceInput(cfg, r, "left")
    RaceStep(cfg, r, 1 / 30, "shared", 3.95, 4.0)
    Check(t, Player(r).branch = "right", "a committed fork stays put")

    ' boost surges ahead of the camera, then the kart settles back
    r = NewRace(cfg)
    for each k in r.karts
        k.visible = (k.isPlayer)
    end for
    d0 = Player(r).d
    RaceInput(cfg, r, "boost")
    Check(t, r.charges = 2 and Player(r).boostT > 0, "boost uses a charge")
    for i = 1 to 45
        RaceStep(cfg, r, 1 / 30, "left", 1, 4.0)
    end for
    Check(t, Player(r).d > d0 + 4, "boost: your kart surges ahead of the camera")
    for i = 1 to 180
        RaceStep(cfg, r, 1 / 30, "left", 1, 4.0)
    end for
    Check(t, Abs(Player(r).d - cfg.home) < 0.5, "after the boost the kart drops back to its home spot")
    Check(t, r.charges = 3, "boosts recharge")

    ' spin: you drop back behind the kart line
    Player(r).spinT = cfg.spin.time
    for i = 1 to 20
        RaceStep(cfg, r, 1 / 30, "left", 1, 4.0)
    end for
    Check(t, Player(r).d < cfg.home - 1.5, "a spin drops you back toward the camera")

    ' bump: a kart driving into one ahead in the same lane is knocked back
    r = NewRace(cfg)
    a = r.karts[0]
    b = r.karts[1]
    for each k in r.karts
        k.visible = false
    end for
    a.visible = true
    b.visible = true
    a.lane = 2 : a.target = 2 : a.d = 0
    b.lane = 2 : b.target = 2 : b.d = 1 : b.branch = a.branch
    Bumps(cfg, r)
    Check(t, a.d < 0 and r.bumps = 1, "bumped kart behind is knocked back")
    a.d = 0 : a.boostT = 1
    Bumps(cfg, r)
    Check(t, b.spinT > 0, "boosting into a kart spins it")

    ' laps and the finish
    r = NewRace(cfg)
    for i = 1 to cfg.laps
        NewLap(cfg, r)
    end for
    Check(t, r.finished and r.lap = cfg.laps, "race finishes after the last lap")
    r.karts[0].d = 30
    Check(t, PlayerPos(r) = 1, "furthest ahead is P1")
    r.karts[0].d = -30
    Check(t, PlayerPos(r) = 4, "furthest behind is last")
    Check(t, FormatTime(83.456) = "1:23.45" and FormatTime(5.07) = "0:05.07", "time format")
end sub
