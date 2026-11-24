' Unit tests for source/track.brs and source/game.brs. Run by tests/brs.test.mjs with brs-cli.
sub Main()
    t = { pass: 0, fail: 0 }
    TestConfigValid(t)
    TestForkGeometry(t)
    TestRoutePickAndLock(t)
    TestSpeedCarryAndPerRoute(t)
    TestItemPickupAndUse(t)
    TestItemOdds(t)
    TestTrafficToggleAndShell(t)
    TestBanana(t)
    TestLapsAndBest(t)
    TestPauseAndKeys(t)
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

function Approx(a as Float, b as Float) as Boolean
    return Abs(a - b) < 0.01
end function

' Run the sim for `secs` seconds in 1/30 s steps; returns all events joined by spaces.
function Sim(s as Object, secs as Float) as String
    out = ""
    n = Int(secs * 30 + 0.5)
    for i = 1 to n
        for each e in UpdateGame(s, 1 / 30)
            out = out + " " + e
        end for
    end for
    return out
end function

function QuietCfg() as Object
    cfg = GameConfig()
    cfg.traffic.enabled = false
    return cfg
end function

sub TestConfigValid(t as Object)
    cfg = GameConfig()
    Check(t, ValidateConfig(cfg).Count() = 0, "default config is valid")
    cfg.forks[0].split = 5
    cfg.forkSpeedMode = "fast"
    Check(t, ValidateConfig(cfg).Count() = 2, "bad split and speed mode are reported")
end sub

sub TestForkGeometry(t as Object)
    cfg = GameConfig()
    f = cfg.forks[0]
    Check(t, ForkAt(cfg, f.start - 1) = invalid, "no fork before start")
    Check(t, ForkAt(cfg, f.start + 1) <> invalid, "fork after start")
    Check(t, Approx(ForkGap(f, f.start + f.openLen / 2), f.gap / 2), "median half open mid-ramp")
    Check(t, Approx(ForkGap(f, f.start + f.openLen + 10), f.gap), "median fully open")
    Check(t, ForkAt(cfg, ForkEnd(f) + 1) = invalid, "routes rejoin")
    Check(t, RoadPieces(cfg, 10).Count() = 1, "one road outside forks")
    pieces = RoadPieces(cfg, f.start + f.openLen + 5)
    Check(t, pieces.Count() = 2 and pieces[0].lanes = 2 and pieces[1].lanes = 3, "split 2 | 3 lanes")
    Check(t, Approx(pieces[1].x0 - pieces[0].x1, f.gap), "gap between routes")
    Check(t, Approx(LaneX(cfg, 2, 10, -1), 0), "middle lane at x=0")
    Check(t, Approx(TrackPos(cfg, cfg.track.length + 5), 5), "lap wrap")
end sub

sub TestRoutePickAndLock(t as Object)
    cfg = QuietCfg()
    f = cfg.forks[0]
    s = NewGame(cfg, 7)
    k = Keys()
    HandleKey(s, k.left)
    HandleKey(s, k.left)       ' lane 0: left route
    s.player.s = f.start - 2
    s.player.speed = 30
    ev = Sim(s, 0.2)
    Check(t, s.player.route = 0 and Instr(1, ev, "route:CANYON") > 0, "lane 0 takes the left route")
    for i = 1 to 4
        HandleKey(s, k.right)
    end for
    Check(t, s.player.lane = f.split - 1, "steering stays inside the left route")
    s.player.s = ForkEnd(f) - 1
    ev = Sim(s, 0.2)
    Check(t, s.player.route = -1 and Instr(1, ev, "rejoin") > 0, "routes rejoin")
    HandleKey(s, k.right)
    HandleKey(s, k.right)
    Check(t, s.player.lane = 3, "all lanes open after rejoin")

    s2 = NewGame(cfg, 7)           ' starts in the middle lane (2) -> right route
    s2.player.s = f.start - 2
    s2.player.speed = 30
    Sim(s2, 0.2)
    Check(t, s2.player.route = 1, "lane 2 takes the right route")
    Check(t, PlayerX(s2) > LaneX(cfg, 2, TrackPos(cfg, s2.player.s), 0), "right route kart is right of the median")
end sub

sub TestSpeedCarryAndPerRoute(t as Object)
    cfg = QuietCfg()
    s = NewGame(cfg, 3)
    Sim(s, 5)
    Check(t, Approx(s.player.speed, cfg.speed.max), "auto-accelerates to top speed")
    f = cfg.forks[0]
    s.player.s = f.start + 5
    s.player.lane = 0
    s.player.laneF = 0
    Sim(s, 1)
    Check(t, Approx(s.player.speed, cfg.speed.max), "carry: route does not change speed")
    cfg2 = QuietCfg()
    cfg2.forkSpeedMode = "perRoute"
    s2 = NewGame(cfg2, 3)
    s2.player.s = f.start - 1
    s2.player.lane = 0
    s2.player.laneF = 0
    s2.player.speed = cfg2.speed.max
    Sim(s2, 2)
    Check(t, Approx(s2.player.speed, cfg2.speed.max * f.routes[0].speedMult), "perRoute: route sets top speed")
end sub

sub TestItemPickupAndUse(t as Object)
    cfg = QuietCfg()
    cfg.items.odds = { shell: 0, banana: 0, boost: 1 }
    s = NewGame(cfg, 5)
    row = s.rows[0]
    s.player.s = row - 1
    s.player.speed = 20
    ev = Sim(s, 0.2)
    Check(t, s.player.item = "boost" and Instr(1, ev, "item:boost") > 0, "drive through a block to get an item")
    lane = s.player.lane
    Check(t, s.blocks[0][lane] > s.time, "block is taken until it respawns")
    Check(t, s.blocks[0][0] <= s.time, "other lanes keep their block")
    HandleKey(s, Keys().up)
    Check(t, s.player.item = "boost", "Up does not fire a boost")
    HandleKey(s, Keys().ok)
    Check(t, s.player.item = "" and s.player.boostT > 0, "OK uses the boost")
    Sim(s, 1)
    Check(t, s.player.speed > cfg.speed.max, "boost goes past top speed")
    Sim(s, 4)
    Check(t, Approx(s.player.speed, cfg.speed.max), "speed settles after boost")
end sub

sub TestItemOdds(t as Object)
    cfg = QuietCfg()
    s = NewGame(cfg, 11)
    counts = { shell: 0, banana: 0, boost: 0 }
    for i = 1 to 3000
        k = RollItem(s)
        counts[k] = counts[k] + 1
    end for
    Check(t, counts.shell > 1050 and counts.shell < 1350, "shell ~40%")
    Check(t, counts.banana > 900 and counts.banana < 1200, "banana ~35%")
    Check(t, counts.boost > 600 and counts.boost < 900, "boost ~25%")
end sub

sub TestTrafficToggleAndShell(t as Object)
    cfg = GameConfig()
    cfg.traffic.perSecond = 50     ' force spawns
    s = NewGame(cfg, 9)
    Sim(s, 0.5)
    Check(t, s.traffic.Count() > 0, "traffic spawns when on")
    s.paused = true
    s.menuIndex = 1
    HandleKey(s, Keys().ok)
    Check(t, not s.trafficOn and s.traffic.Count() = 0, "pause menu turns traffic off")
    Sim(s, 1)
    Check(t, s.traffic.Count() = 0, "no traffic while off")

    s2 = NewGame(QuietCfg(), 9)
    s2.player.speed = 20
    s2.traffic.Push({ s: 20, lane: s2.player.lane, v: 5 })
    s2.player.item = "shell"
    HandleKey(s2, Keys().up)
    ev = Sim(s2, 1)
    Check(t, Instr(1, ev, "shellhit") > 0 and s2.traffic.Count() = 0, "Up throws a shell that hits the car ahead")

    s3 = NewGame(QuietCfg(), 9)
    s3.player.speed = 20
    s3.traffic.Push({ s: 2, lane: s3.player.lane, v: 0 })
    ev = Sim(s3, 0.3)
    Check(t, Instr(1, ev, "bump") > 0 and s3.player.speed < 20, "hitting traffic slows you")
end sub

sub TestBanana(t as Object)
    cfg = QuietCfg()
    s = NewGame(cfg, 2)
    s.player.speed = 30
    s.player.item = "banana"
    HandleKey(s, Keys().down)
    Check(t, s.hazards.Count() = 1 and s.hazards[0].s < s.player.s, "Down drops a banana behind")
    s.player.item = "banana"
    HandleKey(s, Keys().up)
    Check(t, s.hazards[1].s > s.player.s + 10, "Up throws a banana ahead")
    ev = Sim(s, 2)
    Check(t, Instr(1, ev, "spin") > 0 and s.player.spinT > 0, "driving into a banana spins you out")
    lane = s.player.lane
    HandleKey(s, Keys().left)
    Check(t, s.player.lane = lane, "no steering while spinning")
end sub

sub TestLapsAndBest(t as Object)
    cfg = QuietCfg()
    cfg.track.length = 600
    cfg.forks = []
    cfg.items.firstRow = 100
    s = NewGame(cfg, 4)
    ev = Sim(s, 25)
    Check(t, s.lap = 2 and s.lastLap > 0 and Approx(s.best, s.lastLap), "lap completes and sets best")
    s.cfg.speed.max = 15            ' a slower second lap
    first = s.best
    ev = Sim(s, 42)
    Check(t, s.lap = 3 and s.lastLap > first and Approx(s.best, first), "slower lap keeps the best")
    Check(t, FormatTime(83.456) = "1:23.46", "time format")
    Check(t, FormatTime(-1) = "--:--.--", "no time yet")
end sub

sub TestPauseAndKeys(t as Object)
    s = NewGame(QuietCfg(), 1)
    k = Keys()
    HandleKey(s, k.play)
    Check(t, s.paused, "Play pauses")
    before = s.player.s
    Sim(s, 1)
    Check(t, s.player.s = before, "paused game does not move")
    HandleKey(s, k.play)
    Check(t, not s.paused, "Play resumes")
    Check(t, HandleKey(s, k.back) = "exit", "Back exits")
    HandleKey(s, k.play)
    Check(t, HandleKey(s, k.back) = "exit", "Back exits from the pause menu")
    s.menuIndex = 0
    HandleKey(s, k.up)
    Check(t, s.menuIndex = 3, "menu wraps from RESUME up to EXIT")
    s2 = NewGame(QuietCfg(), 1)
    s2.paused = true
    s2.menuIndex = 3
    Check(t, HandleKey(s2, k.ok) = "exit", "EXIT in the menu exits")
    Check(t, HandleKey(s2, k.left + 100) = "", "key releases are ignored")
end sub
