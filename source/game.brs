' Game state and rules: input, speed, lanes, forks, items, traffic, laps. No drawing here, so it is unit-tested.

' Remote key codes from roUniversalControlEvent (presses; releases are code + 100).
function Keys() as Object
    return { back: 0, up: 2, down: 3, left: 4, right: 5, ok: 6, play: 13 }
end function

function ItemKinds() as Object
    return ["shell", "banana", "boost"]
end function

function NewGame(cfg as Object, seed as Integer) as Object
    s = {
        cfg: cfg
        seed: seed
        best: -1
        trafficOn: cfg.traffic.enabled
        paused: false
        menuIndex: 0
    }
    if s.seed <= 0 then s.seed = 1
    ResetRace(s)
    return s
end function

' Back to the start line. Keeps the best lap, traffic setting and random stream.
sub ResetRace(s as Object)
    cfg = s.cfg
    n = cfg.lanes.count
    s.time = 0
    s.player = {
        s: 0.0, lane: n \ 2, laneF: n \ 2, speed: cfg.speed.start
        route: -1, routeName: "", boostT: 0, spinT: 0, item: ""
    }
    s.camZ = -cfg.camera.playerDepth
    s.camX = PlayerX(s)
    s.lap = 1
    s.lapStart = 0
    s.lastLap = -1
    s.newBest = false
    s.rows = []
    r = cfg.items.firstRow
    while r < cfg.track.length
        s.rows.Push(r)
        r = r + cfg.items.rowEvery
    end while
    s.blocks = []   ' blocks[row][lane] = time the block is back (<= now means it is there)
    for i = 0 to s.rows.Count() - 1
        lanes = []
        for j = 0 to n - 1
            lanes.Push(0)
        end for
        s.blocks.Push(lanes)
    end for
    s.traffic = []
    s.shots = []
    s.hazards = []
    s.msg = ""
    s.msgT = 0
    s.stats = { items: 0, shellHits: 0, bumps: 0, spins: 0, boosts: 0, forks: 0 }
    s.paused = false
    s.menuIndex = 0
end sub

' Park-Miller random in [0, 1), so tests are repeatable.
function RandF(s as Object) as Float
    q = s.seed * 16807#
    s.seed = q - Int(q / 2147483647#) * 2147483647#
    return s.seed / 2147483647#
end function

function RollItem(s as Object) as String
    odds = s.cfg.items.odds
    total = 0
    for each k in ItemKinds()
        total = total + odds[k]
    end for
    r = RandF(s) * total
    acc = 0
    for each k in ItemKinds()
        acc = acc + odds[k]
        if r < acc then return k
    end for
    return "boost"
end function

function PlayerX(s as Object) as Float
    p = s.player
    return LaneX(s.cfg, p.laneF, TrackPos(s.cfg, p.s), p.route)
end function

function ObjX(s as Object, lane as Integer, at as Float) as Float
    return LaneX(s.cfg, lane, TrackPos(s.cfg, at), -1)
end function

function PauseMenu(s as Object) as Object
    t = "TRAFFIC: OFF"
    if s.trafficOn then t = "TRAFFIC: ON"
    return ["RESUME", t, "RESTART", "EXIT"]
end function

sub Say(s as Object, text as String)
    s.msg = text
    s.msgT = 1.6
end sub

' Handle one remote key. Returns "exit" when the app should close, else "".
function HandleKey(s as Object, code as Integer) as String
    k = Keys()
    if code >= 100 then return ""        ' ignore releases
    if code = k.back then return "exit"
    if s.paused
        if code = k.play then
            s.paused = false
        else if code = k.up then
            s.menuIndex = (s.menuIndex + 3) mod 4
        else if code = k.down then
            s.menuIndex = (s.menuIndex + 1) mod 4
        else if code = k.ok then
            return MenuSelect(s)
        end if
        return ""
    end if
    if code = k.play then
        s.paused = true
        s.menuIndex = 0
    else if code = k.left then
        Steer(s, -1)
    else if code = k.right then
        Steer(s, 1)
    else if code = k.up then
        UseItem(s, "forward")
    else if code = k.down then
        UseItem(s, "back")
    else if code = k.ok then
        UseItem(s, "boost")
    end if
    return ""
end function

function MenuSelect(s as Object) as String
    i = s.menuIndex
    if i = 0 then
        s.paused = false
    else if i = 1 then
        SetTraffic(s, not s.trafficOn)
    else if i = 2 then
        ResetRace(s)
    else if i = 3 then
        return "exit"
    end if
    return ""
end function

sub SetTraffic(s as Object, onOff as Boolean)
    s.trafficOn = onOff
    if not onOff then s.traffic = []
end sub

' Tap left/right: move one lane, kept inside the current route while in a fork.
sub Steer(s as Object, dir as Integer)
    p = s.player
    if p.spinT > 0 then return
    lo = 0
    hi = s.cfg.lanes.count - 1
    if p.route >= 0 then
        fork = ForkAt(s.cfg, TrackPos(s.cfg, p.s))
        if fork <> invalid then
            rng = RouteLanes(s.cfg, fork, p.route)
            lo = rng[0]
            hi = rng[1]
        end if
    end if
    t = p.lane + dir
    if t < lo then t = lo
    if t > hi then t = hi
    p.lane = t
end sub

' Up throws forward, Down drops behind, OK fires a boost.
sub UseItem(s as Object, action as String)
    p = s.player
    it = p.item
    ic = s.cfg.items
    if it = "" then return
    if action = "boost" then
        if it <> "boost" then return
        p.boostT = s.cfg.speed.boostTime
        s.stats.boosts = s.stats.boosts + 1
        Say(s, "BOOST!")
    else if it = "shell" then
        if action = "forward" then
            s.shots.Push({ s: p.s + 1, lane: p.lane, v: p.speed + ic.shellSpeed, life: ic.shellLife })
        else
            s.shots.Push({ s: p.s - 1, lane: p.lane, v: p.speed - ic.shellSpeed, life: ic.shellLife })
        end if
    else if it = "banana" then
        d = -ic.dropDist
        if action = "forward" then d = ic.throwDist
        s.hazards.Push({ s: p.s + d, lane: p.lane, life: ic.hazardLife })
    else
        return   ' a boost only fires with OK
    end if
    p.item = ""
end sub

function TopSpeed(s as Object) as Float
    sp = s.cfg.speed
    p = s.player
    if p.boostT > 0 then return sp.boostMax
    top = sp.max
    if s.cfg.forkSpeedMode = "perRoute" and p.route >= 0 then
        fork = ForkAt(s.cfg, TrackPos(s.cfg, p.s))
        if fork <> invalid then top = top * fork.routes[p.route].speedMult
    end if
    return top
end function

' Did the kart pass lap position `at` between lap positions a and b this frame (handles the lap wrap)?
function Crossed(a as Float, b as Float, at as Float) as Boolean
    if b >= a then return at > a and at <= b
    return at > a or at <= b
end function

function Near(s as Object, x1 as Float, s1 as Float, x2 as Float, s2 as Float) as Boolean
    ic = s.cfg.items
    return Abs(x1 - x2) < ic.hitWidth and Abs(s1 - s2) < ic.hitLen
end function

' Advance the race by dt seconds. Returns the events that happened (strings), for the HUD and tests.
function UpdateGame(s as Object, dtIn as Float) as Object
    ev = []
    if s.paused then return ev
    cfg = s.cfg
    dt = dtIn
    if dt > cfg.maxDt then dt = cfg.maxDt
    if dt <= 0 then return ev
    p = s.player
    s.time = s.time + dt
    if p.boostT > 0 then p.boostT = p.boostT - dt
    if p.spinT > 0 then p.spinT = p.spinT - dt
    if s.msgT > 0 then s.msgT = s.msgT - dt

    ' Speed: auto-accelerate toward the current top speed.
    top = TopSpeed(s)
    acc = cfg.speed.accel
    if p.boostT > 0 then acc = cfg.speed.boostAccel
    if p.speed < top then
        p.speed = p.speed + acc * dt
        if p.speed > top then p.speed = top
    else if p.speed > top then
        p.speed = p.speed - cfg.speed.decel * dt
        if p.speed < top then p.speed = top
    end if
    prevS = p.s
    p.s = p.s + p.speed * dt

    ' Slide toward the target lane.
    slide = dt / cfg.lanes.changeTime
    if p.laneF < p.lane then
        p.laneF = p.laneF + slide
        if p.laneF > p.lane then p.laneF = p.lane
    else if p.laneF > p.lane then
        p.laneF = p.laneF - slide
        if p.laneF < p.lane then p.laneF = p.lane
    end if

    ' Forks: your lane when you reach the split picks the route; you stay on it until the routes rejoin.
    smPrev = TrackPos(cfg, prevS)
    sm = TrackPos(cfg, p.s)
    fork = ForkAt(cfg, sm)
    if fork <> invalid and p.route < 0 then
        p.route = RouteOfLane(fork, p.lane)
        p.routeName = fork.routes[p.route].name
        s.stats.forks = s.stats.forks + 1
        Say(s, p.routeName + " ROUTE")
        ev.Push("route:" + p.routeName)
    else if fork = invalid and p.route >= 0 then
        p.route = -1
        p.routeName = ""
        ev.Push("rejoin")
    end if

    ' Laps.
    L = cfg.track.length
    if Int(p.s / L) > Int(prevS / L) then
        lapTime = s.time - s.lapStart
        s.lastLap = lapTime
        if s.best < 0 or lapTime < s.best then
            s.best = lapTime
            s.newBest = true
            Say(s, "NEW BEST LAP!")
        end if
        s.lap = s.lap + 1
        s.lapStart = s.time
        ev.Push("lap")
    end if

    ' Camera follows the kart.
    px = PlayerX(s)
    s.camZ = p.s - cfg.camera.playerDepth
    f = cfg.camera.followRate * dt
    if f > 1 then f = 1
    s.camX = s.camX + (px - s.camX) * f

    ' Item blocks: one per lane per row.
    myLane = Int(p.laneF + 0.5)
    for i = 0 to s.rows.Count() - 1
        if Crossed(smPrev, sm, s.rows[i]) and s.blocks[i][myLane] <= s.time then
            s.blocks[i][myLane] = s.time + cfg.items.respawn
            if p.item = "" then
                p.item = RollItem(s)
                s.stats.items = s.stats.items + 1
                ev.Push("item:" + p.item)
            end if
        end if
    end for

    ' Traffic: spawn ahead, drive, despawn behind, bump the kart.
    tc = cfg.traffic
    if s.trafficOn and s.traffic.Count() < tc.maxCars and RandF(s) < tc.perSecond * dt then
        lane = Int(RandF(s) * cfg.lanes.count)
        frac = tc.minFrac + RandF(s) * (tc.maxFrac - tc.minFrac)
        s.traffic.Push({ s: p.s + tc.spawnAhead, lane: lane, v: cfg.speed.max * frac })
    end if
    kept = []
    for each car in s.traffic
        car.s = car.s + car.v * dt
        if car.s < p.s - tc.despawnBehind then
            ' gone behind
        else if Near(s, ObjX(s, car.lane, car.s), car.s, px, p.s) then
            p.speed = p.speed * cfg.speed.bumpFactor
            s.stats.bumps = s.stats.bumps + 1
            Say(s, "BUMP!")
            ev.Push("bump")
        else
            kept.Push(car)
        end if
    end for
    s.traffic = kept

    ' Shells fly along their lane and knock out the first car they reach.
    keptShots = []
    for each sh in s.shots
        sh.s = sh.s + sh.v * dt
        sh.life = sh.life - dt
        hit = -1
        sx = ObjX(s, sh.lane, sh.s)
        for c = 0 to s.traffic.Count() - 1
            car = s.traffic[c]
            if Near(s, ObjX(s, car.lane, car.s), car.s, sx, sh.s) then hit = c
        end for
        if hit >= 0 then
            s.traffic.Delete(hit)
            s.stats.shellHits = s.stats.shellHits + 1
            Say(s, "SHELL HIT!")
            ev.Push("shellhit")
        else if sh.life > 0 then
            keptShots.Push(sh)
        end if
    end for
    s.shots = keptShots

    ' Bananas spin out the kart or a car.
    keptHaz = []
    for each b in s.hazards
        b.life = b.life - dt
        bx = ObjX(s, b.lane, b.s)
        used = false
        if Near(s, bx, b.s, px, p.s) then
            p.spinT = s.cfg.speed.spinTime
            p.speed = p.speed * cfg.speed.spinFactor
            s.stats.spins = s.stats.spins + 1
            Say(s, "SPUN OUT!")
            ev.Push("spin")
            used = true
        else
            for c = 0 to s.traffic.Count() - 1
                car = s.traffic[c]
                if not used and Near(s, ObjX(s, car.lane, car.s), car.s, bx, b.s) then
                    s.traffic.Delete(c)
                    ev.Push("carspin")
                    used = true
                    exit for
                end if
            end for
        end if
        if not used and b.life > 0 then keptHaz.Push(b)
    end for
    s.hazards = keptHaz
    return ev
end function

' The fork coming up within `within` units, or invalid.
function ForkAhead(s as Object, within as Float) as Dynamic
    sm = TrackPos(s.cfg, s.player.s)
    for each fork in s.cfg.forks
        d = fork.start - sm
        if d > 0 and d <= within then return fork
    end for
    return invalid
end function

' 83.456 -> "1:23.45"
function FormatTime(t as Float) as String
    if t < 0 then return "--:--.--"
    cs = Int(t * 100 + 0.5)
    mins = cs \ 6000
    secs = (cs \ 100) mod 60
    hund = cs mod 100
    ss = secs.ToStr()
    if secs < 10 then ss = "0" + ss
    hs = hund.ToStr()
    if hund < 10 then hs = "0" + hs
    return mins.ToStr() + ":" + ss + "." + hs
end function
