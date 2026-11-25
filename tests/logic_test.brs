' Unit tests for source/track.brs and source/game.brs. Run by tests/brs.test.mjs with brs-cli.
sub Main()
    t = { pass: 0, fail: 0 }
    TestConfigValid(t)
    TestCourse(t)
    TestSplitGeometry(t)
    TestJumpsBetweenTracks(t)
    TestSpeedCarryAndPerRoute(t)
    TestItemPickupAndUse(t)
    TestItemOdds(t)
    TestTrafficToggleAndShell(t)
    TestBanana(t)
    TestBots(t)
    TestLapsRaceAndBest(t)
    TestPauseAndKeys(t)
    TestWorlds(t)
    TestThrills(t)
    TestTunnelsAndJumps(t)
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

' Just you on the road: no bots, no traffic, no countdown.
function SoloCfg() as Object
    cfg = GameConfig()
    cfg.traffic.enabled = false
    cfg.bots.count = 0
    cfg.race.countdown = 0
    cfg.race.laps = 0
    return cfg
end function

sub TestConfigValid(t as Object)
    cfg = GameConfig()
    Check(t, ValidateConfig(cfg).Count() = 0, "default config is valid")
    cfg.forks[0].splits = [5]
    cfg.forkSpeedMode = "fast"
    cfg.course.sections[0].len = 10
    Check(t, ValidateConfig(cfg).Count() = 3, "bad split, speed mode and course length are reported")
end sub

sub TestCourse(t as Object)
    cfg = GameConfig()
    PrepareCourse(cfg)
    Check(t, cfg.course.table.Count() = cfg.track.length, "curve table covers the lap")
    Check(t, Approx(CurveAt(cfg, 10), 0), "start straight")
    Check(t, Approx(CurveAt(cfg, 250), 0.8), "first bend is a right-hander")
    Check(t, CurveAt(cfg, 152) < 0.8 and CurveAt(cfg, 152) > 0, "curves ease in")
    Check(t, Approx(CurveAt(cfg, cfg.track.length + 250), 0.8), "same course every lap")
    lefts = 0
    rights = 0
    for each sec in cfg.course.sections
        if sec.curve < 0 then lefts = lefts + 1
        if sec.curve > 0 then rights = rights + 1
    end for
    Check(t, lefts >= 2 and rights >= 2, "course has left and right bends")
end sub

sub TestSplitGeometry(t as Object)
    cfg = GameConfig()
    f = cfg.forks[0]
    Check(t, ForkAt(cfg, f.start - 1) = invalid, "single road before a split")
    Check(t, Approx(ForkGap(f, f.start + f.openLen / 2), f.gap / 2), "gap half open mid-ramp")
    Check(t, ForkAt(cfg, ForkEnd(f) + 1) = invalid, "tracks reunite")
    Check(t, RoadPieces(cfg, 10).Count() = 1, "one road outside splits")
    mid = f.start + f.openLen + 5
    pieces = RoadPieces(cfg, mid)
    Check(t, pieces.Count() = 2 and pieces[0].lanes = 2 and pieces[1].lanes = 3, "2 | 3 split")
    Check(t, Approx(pieces[1].x0 - pieces[0].x1, f.gap), "gap between tracks")
    three = cfg.forks[1]
    p3 = RoadPieces(cfg, three.start + three.openLen + 5)
    Check(t, p3.Count() = 3 and p3[0].lanes = 1 and p3[1].lanes = 3 and p3[2].lanes = 1, "1 | 3 | 1 three-way split")
    Check(t, TrackName(cfg, 0, mid) = "CANYON" and TrackName(cfg, 4, mid) = "COAST", "track names by lane")
    Check(t, Approx(LaneXi(cfg, 2, 10), 0), "middle lane at x=0")
    Check(t, LaneXi(cfg, 2, mid) - LaneXi(cfg, 1, mid) > 1 + f.gap - 0.01, "lanes 2 and 3 are a gap apart in the split")
    Check(t, Approx(LaneX(cfg, 1.5, mid), (LaneXi(cfg, 1, mid) + LaneXi(cfg, 2, mid)) / 2), "mid-jump x is between tracks")
    Check(t, Approx(TrackPos(cfg, cfg.track.length + 5), 5), "lap wrap")
end sub

sub TestJumpsBetweenTracks(t as Object)
    cfg = SoloCfg()
    f = cfg.forks[0]
    s = NewGame(cfg, 7)
    k = Keys()
    p = s.player
    p.s = f.start + f.openLen + 20
    p.speed = 30
    p.lane = 1
    p.laneF = 1
    HandleKey(s, k.right)
    Check(t, p.lane = 2 and p.jumpT > 0 and s.stats.jumps = 1, "Right across the gap jumps to the other track")
    HandleKey(s, k.right)
    Check(t, p.lane = 2, "no steering mid-air")
    ev = Sim(s, 0.5)
    Check(t, p.jumpT <= 0 and Approx(p.laneF, 2), "lands on the new track")
    Check(t, Instr(1, ev, "track:COAST") > 0, "HUD hears the new track")
    HandleKey(s, k.right)
    Check(t, p.lane = 3 and p.jumpT <= 0, "lane change inside a track is not a jump")
    HandleKey(s, k.left)
    Sim(s, 0.3)
    HandleKey(s, k.left)
    Check(t, p.lane = 1 and p.jumpT > 0, "can jump back the other way")
    s.hazards.Push({ s: p.s + 0.5, lane: 1, life: 5 })
    Sim(s, 0.05)
    Check(t, p.spinT <= 0, "jumping clears a banana")
    p.s = 50
    p.jumpT = 0
    p.lane = 1
    p.laneF = 1
    HandleKey(s, k.right)
    Check(t, p.lane = 2 and p.jumpT <= 0, "no jump on the single road")
    p.lane = 4
    HandleKey(s, k.right)
    Check(t, p.lane = 4, "edge lane stays put")
end sub

sub TestSpeedCarryAndPerRoute(t as Object)
    cfg = SoloCfg()
    s = NewGame(cfg, 3)
    Sim(s, 5)
    Check(t, Approx(s.player.speed, cfg.speed.max), "auto-accelerates to top speed")
    f = cfg.forks[0]
    s.player.s = f.start + 5
    s.player.lane = 0
    s.player.laneF = 0
    Sim(s, 1)
    Check(t, Approx(s.player.speed, cfg.speed.max), "carry: track does not change speed")
    cfg2 = SoloCfg()
    cfg2.forkSpeedMode = "perRoute"
    s2 = NewGame(cfg2, 3)
    s2.player.s = f.start - 1
    s2.player.lane = 0
    s2.player.laneF = 0
    s2.player.speed = cfg2.speed.max
    Sim(s2, 2)
    Check(t, Approx(s2.player.speed, cfg2.speed.max * f.speedMults[0]), "perRoute: track sets top speed")
end sub

sub TestItemPickupAndUse(t as Object)
    cfg = SoloCfg()
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
    s = NewGame(SoloCfg(), 11)
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
    cfg = SoloCfg()
    cfg.traffic.enabled = true
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

    s2 = NewGame(SoloCfg(), 9)
    s2.player.speed = 20
    s2.traffic.Push({ s: 20, lane: s2.player.lane, v: 5 })
    s2.player.item = "shell"
    HandleKey(s2, Keys().up)
    ev = Sim(s2, 1)
    Check(t, Instr(1, ev, "shellhit:car") > 0 and s2.traffic.Count() = 0, "Up throws a shell that hits the car ahead")

    s3 = NewGame(SoloCfg(), 9)
    s3.player.speed = 20
    s3.traffic.Push({ s: 2, lane: s3.player.lane, v: 0 })
    ev = Sim(s3, 0.3)
    Check(t, Instr(1, ev, "bump") > 0 and s3.player.speed < 20, "hitting traffic slows you")
end sub

sub TestBanana(t as Object)
    s = NewGame(SoloCfg(), 2)
    p = s.player
    p.speed = 30
    p.item = "banana"
    HandleKey(s, Keys().down)
    Check(t, s.hazards.Count() = 1 and s.hazards[0].s < p.s, "Down drops a banana behind")
    p.item = "banana"
    HandleKey(s, Keys().up)
    Check(t, s.hazards[1].s > p.s + 10, "Up throws a banana ahead")
    ev = Sim(s, 2)
    Check(t, Instr(1, ev, "spin") > 0 and p.spinT > 0, "driving into a banana spins you out")
    lane = p.lane
    HandleKey(s, Keys().left)
    Check(t, p.lane = lane, "no steering while spinning")
end sub

sub TestBots(t as Object)
    cfg = GameConfig()
    cfg.traffic.enabled = false
    cfg.race.countdown = 0
    s = NewGame(cfg, 21)
    Check(t, s.karts.Count() = 1 + cfg.bots.count, "bots join the race")
    lanesOk = true
    for each k in s.karts
        if k.lane < 0 or k.lane >= cfg.lanes.count or k.laneF <> k.lane then lanesOk = false
    end for
    Check(t, lanesOk, "every kart starts in a lane")
    Check(t, Position(s, s.player) = s.karts.Count(), "you start at the back of the grid")
    moves = 0
    far = true
    last = []
    for each k in s.karts
        last.Push(k.lane)
    end for
    for f = 1 to 600
        UpdateGame(s, 1 / 30)
        for i = 1 to s.karts.Count() - 1
            if s.karts[i].lane <> last[i] then moves = moves + 1
            last[i] = s.karts[i].lane
        end for
    end for
    for i = 1 to s.karts.Count() - 1
        if s.karts[i].s < 300 then far = false
    end for
    Check(t, far, "bots drive the course")
    Check(t, moves >= 3, "bots switch lanes")
    Check(t, s.stats.botItems > 0, "bots pick up items")
    inLane = true
    for each k in s.karts
        if k.lane < 0 or k.lane >= cfg.lanes.count then inLane = false
    end for
    Check(t, inLane, "bots stay in lanes")

    ' A bot with a shell fires at the kart ahead of it in its lane.
    s2 = NewGame(cfg, 4)
    bot = s2.karts[1]
    s2.player.s = 100
    s2.player.lane = 2
    s2.player.laneF = 2
    s2.player.speed = 0
    bot.s = 80
    bot.lane = 2
    bot.laneF = 2
    bot.speed = 10
    bot.item = "shell"
    bot.holdT = 0
    bot.think = 99
    s2.karts[2].s = -500
    s2.karts[3].s = -500
    ev = Sim(s2, 1.5)
    Check(t, Instr(1, ev, "spin") > 0, "bot shell hits you")

    ' A bot moves out of a lane with a banana ahead.
    s3 = NewGame(cfg, 6)
    b3 = s3.karts[1]
    b3.s = 300
    b3.lane = 2
    b3.laneF = 2
    b3.think = 0
    s3.hazards.Push({ s: 310, lane: 2, life: 9 })
    Sim(s3, 0.1)
    Check(t, b3.lane <> 2, "bot dodges a banana")

    ' Positions follow distance.
    s.player.s = 0
    Check(t, Position(s, s.player) = s.karts.Count(), "last when everyone is ahead")
end sub

sub TestLapsRaceAndBest(t as Object)
    cfg = SoloCfg()
    cfg.track.length = 600
    cfg.course.sections = [{ len: 600, curve: 0 }]
    cfg.forks = []
    cfg.items.firstRow = 100
    cfg.race.laps = 2
    s = NewGame(cfg, 4)
    ev = Sim(s, 30)
    Check(t, s.lap = 2 and s.lastLap > 0 and Approx(s.best, s.lastLap), "lap completes and sets best")
    s.cfg.speed.max = 15            ' a slower second lap
    first = s.best
    ev = Sim(s, 45)
    Check(t, s.finished and Instr(1, ev, "finish:1") > 0, "race ends after the last lap")
    Check(t, s.lastLap > first and Approx(s.best, first), "slower lap keeps the best")
    before = s.player.s
    Sim(s, 1)
    Check(t, s.player.s = before, "finished race stands still")
    HandleKey(s, Keys().ok)
    Check(t, not s.finished and s.lap = 1 and s.player.s = 0 and Approx(s.best, first), "OK races again, best kept")

    c2 = GameConfig()
    s2 = NewGame(c2, 4)
    HandleKey(s2, Keys().left)
    Check(t, s2.player.lane = 2, "no steering during the countdown")
    ev = Sim(s2, c2.race.countdown + 0.1)
    Check(t, Instr(1, ev, "go") > 0 and s2.player.speed > 0, "GO after the countdown")
    Check(t, FormatTime(83.456) = "1:23.46", "time format")
    Check(t, FormatTime(-1) = "--:--.--", "no time yet")
    Check(t, Ordinal(1) = "1st" and Ordinal(2) = "2nd" and Ordinal(3) = "3rd" and Ordinal(4) = "4th" and Ordinal(11) = "11th", "ordinals")
end sub

sub TestPauseAndKeys(t as Object)
    s = NewGame(SoloCfg(), 1)
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
    Check(t, s.menuIndex = 4, "menu wraps from RESUME up to EXIT")
    s2 = NewGame(SoloCfg(), 1)
    s2.paused = true
    s2.menuIndex = 4
    Check(t, HandleKey(s2, k.ok) = "exit", "EXIT in the menu exits")
    s2.menuIndex = 3
    Check(t, HandleKey(s2, k.ok) = "menu", "TRACKS goes back to the title screen")
    HandleKey(s2, k.info)
    Check(t, s2.showFps, "the * button shows the FPS counter")
    Check(t, HandleKey(s2, k.left + 100) = "", "key releases are ignored")
end sub

sub TestWorlds(t as Object)
    for each w in ["jungle", "skytrack", "pebble"]
        cfg = GameConfig()
        SetupRace(cfg, w, "jelly")
        Check(t, ValidateConfig(cfg).Count() = 0, w + " course is valid")
        PrepareCourse(cfg)
        Check(t, Abs(ElevAt(cfg, 0) - ElevAt(cfg, cfg.track.length - 0.01)) < 0.05, w + " lap ends at the height it starts")
        Check(t, cfg.racers.Count() = cfg.bots.count + 1 and cfg.racers[0] = "jelly", w + ": you drive your pick")
        dup = false
        for i = 1 to cfg.racers.Count() - 1
            if cfg.racers[i] = "jelly" then dup = true
        end for
        Check(t, not dup, w + ": no bot copies your racer")
    end for
    cfg = GameConfig()
    SetupRace(cfg, "jungle", "hatchling")
    PrepareCourse(cfg)
    Check(t, ElevAt(cfg, 350) > ElevAt(cfg, 150) + 5, "jungle climbs a hill")
    Check(t, ElevAt(cfg, 500) < ElevAt(cfg, 350) - 8, "then dives")
    Check(t, cfg.forks[0].names[0] = "FERN PATH", "world names its splits")
    c2 = GameConfig()
    SetupRace(c2, "skytrack", "toaster")
    PrepareCourse(c2)
    Check(t, TubeAt(c2, 400) and not TubeAt(c2, 250), "sky track has a tube")
    Check(t, Abs(RollAt(c2, 590) - 180) < 5, "corkscrew is upside down halfway")
    Check(t, RollAt(c2, 400) = 0, "no roll outside the corkscrew")
    c3 = GameConfig()
    Check(t, c3.tracks.Count() >= 14 and c3.roster.Count() = 8, "title screen offers 14 tracks and 8 racers")
    Check(t, TrackTitle("pebble") = "PEBBLE COVE" and RacerTitle("jelly") = "JELLY JET", "track and racer names")
    c3.course.sections[0].rise = 3
    Check(t, ValidateConfig(c3).Count() = 1, "unbalanced hills are reported")
end sub

sub TestThrills(t as Object)
    names = []
    names.Append(GameConfig().tracks)
    allOk = true
    every = true
    for each n in names
        cfg = GameConfig()
        SetupRace(cfg, n, "toaster")
        if ValidateConfig(cfg).Count() > 0 then
            allOk = false
            print "  invalid: " + n
        end if
        PrepareCourse(cfg)
        hills = false
        twist = false
        for u = 0 to cfg.track.length - 1
            if Abs(cfg.course.elev[u]) > 3 then hills = true
            if Abs(cfg.course.roll[u]) > 170 then twist = true
        end for
        if not hills or not twist then
            every = false
            print "  missing hills or a loop/roll: " + n
        end if
    end for
    Check(t, allOk, "every track's course is valid")
    Check(t, every, "every track has hills and a loop or barrel roll")

    cfg = GameConfig()
    SetupRace(cfg, "meadow", "toaster")
    PrepareCourse(cfg)
    Check(t, cfg.course.loops.Count() = 1 and cfg.course.loops[0] = 250, "meadow's loop starts at 250")
    top = ElevAt(cfg, 325)
    Check(t, top > ElevAt(cfg, 250) + 20, "a loop climbs its wall")
    Check(t, Abs(ElevAt(cfg, 399.5) - ElevAt(cfg, 250)) < 6, "and drops back out")
    Check(t, Abs(RollAt(cfg, 325) - 180) < 3, "upside down at the top of the loop")
    Check(t, Abs(RollAt(cfg, 1280)) > 8, "banked turn tilts the view")

    ' Airtime off a sharp crest at speed, but not when slow, and never inside a loop.
    c2 = GameConfig()
    SetupRace(c2, "desert", "toaster")
    s = NewGame(c2, 3)
    s.countdown = 0
    p = s.player
    p.s = 292
    p.speed = 26
    Sim(s, 0.8)
    Check(t, s.stats.airs >= 1, "fast over the crest of a drop gets airtime")
    c3 = GameConfig()
    SetupRace(c3, "desert", "toaster")
    c3.speed.max = 8
    s2 = NewGame(c3, 3)
    s2.countdown = 0
    s2.player.s = 292
    s2.player.speed = 8
    Sim(s2, 0.8)
    Check(t, s2.stats.airs = 0, "no airtime when slow")
    s3 = NewGame(cfg, 3)
    s3.countdown = 0
    s3.player.s = 290
    s3.player.speed = 26
    Sim(s3, 3)
    Check(t, s3.stats.airs = 0, "no airtime over the top of a loop")
    p.airT = 0.3
    lane = p.lane
    HandleKey(s, Keys().left)
    Check(t, p.lane = lane, "no steering in the air")
end sub

sub TestTunnelsAndJumps(t as Object)
    allT = true
    allJ = true
    for each n in GameConfig().tracks
        cfg = GameConfig()
        SetupRace(cfg, n, "teapot")
        PrepareCourse(cfg)
        if cfg.course.jumps.Count() = 0 then
            allJ = false
            print "  no jump: " + n
        end if
        tun = cfg.course.tunnels.Count() > 0
        for each st in cfg.course.tube
            if st <> "" then tun = true
        end for
        if not tun then
            allT = false
            print "  no tunnel: " + n
        end if
    end for
    Check(t, allJ, "every track has a jump")
    Check(t, allT, "every track has a tunnel or tube")

    cfg = GameConfig()
    SetupRace(cfg, "whirligig", "duckboat")
    Check(t, ValidateConfig(cfg).Count() = 0, "whirligig course is valid")
    PrepareCourse(cfg)
    Check(t, TubeStyle(cfg, 300) = "candy" and cfg.course.tunnels[0].at = 200, "candy mountain tunnel at 200")
    j = cfg.course.jumps[0]
    Check(t, j.at = 560 and GapAt(cfg, 570) and not GapAt(cfg, 555) and not GapAt(cfg, 591), "jump gap at 560")
    s = NewGame(cfg, 5)
    s.countdown = 0
    p = s.player
    p.s = 550
    p.speed = 26
    ev = Sim(s, 0.5)
    Check(t, p.airT > 0 and s.stats.airs >= 1, "the ramp launches you")
    Sim(s, 2)
    Check(t, p.airT <= 0 and p.s > j.at + j.len, "you land past the gap")
    s2 = NewGame(cfg, 5)
    s2.countdown = 0
    s2.player.s = 559
    s2.player.speed = 4
    Sim(s2, 0.3)
    Check(t, s2.player.speed >= cfg.air.minJumpSpeed, "a slow kart still clears the gap")
    Check(t, RacerTitle("duckboat") = "TUB DUCK" and TrackTitle("whirligig") = "WHIRLIGIG WOODS", "new names")
end sub
