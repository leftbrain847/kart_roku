' Game state and rules: input, karts (you and the bots), lanes and jumps, items, traffic, laps and the race.
' No drawing here, so it is unit-tested.

' Remote key codes from roUniversalControlEvent (presses; releases are code + 100).
function Keys() as Object
    return { back: 0, up: 2, down: 3, left: 4, right: 5, ok: 6, play: 13 }
end function

function ItemKinds() as Object
    return ["shell", "banana", "boost"]
end function

function NewGame(cfg as Object, seed as Integer) as Object
    PrepareCourse(cfg)
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

function NewKart(cfg as Object, id as Integer, name as String, lane as Integer, startS as Float, skill as Float, body as Integer) as Object
    return {
        id: id, name: name, isBot: id > 0, body: body
        s: startS, lane: lane, laneF: lane, speed: cfg.speed.start, skill: skill
        boostT: 0, spinT: 0, jumpT: 0, item: ""
        think: 0, holdT: 0
    }
end function

' Back to the start grid. Keeps the best lap, traffic setting and random stream.
sub ResetRace(s as Object)
    cfg = s.cfg
    n = cfg.lanes.count
    bc = cfg.bots
    s.time = 0
    s.countdown = cfg.race.countdown
    s.karts = [NewKart(cfg, 0, "YOU", n \ 2, 0, 1.0, cfg.colors.player)]
    for i = 0 to bc.count - 1
        lane = (n \ 2 + (i + 1) * 2) mod n
        row = i \ 2 + 1
        skill = bc.skillMin + RandF(s) * (bc.skillMax - bc.skillMin)
        bot = NewKart(cfg, i + 1, bc.names[i], lane, row * bc.gridGap, skill, bc.bodies[i])
        bot.think = RandRange(s, bc.thinkMin, bc.thinkMax)
        s.karts.Push(bot)
    end for
    s.player = s.karts[0]
    s.camZ = -cfg.camera.playerDepth
    s.camX = KartX(s, s.player)
    s.bgX = 0
    s.trackName = ""
    s.lap = 1
    s.lapStart = 0
    s.lastLap = -1
    s.newBest = false
    s.finished = false
    s.finishPos = 0
    s.raceTime = 0
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
    s.stats = { items: 0, shellHits: 0, bumps: 0, spins: 0, boosts: 0, jumps: 0, botItems: 0 }
    s.paused = false
    s.menuIndex = 0
end sub

' Park-Miller random in [0, 1), so tests are repeatable.
function RandF(s as Object) as Float
    q = s.seed * 16807#
    s.seed = q - Int(q / 2147483647#) * 2147483647#
    return s.seed / 2147483647#
end function

function RandRange(s as Object, a as Float, b as Float) as Float
    return a + RandF(s) * (b - a)
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

function KartX(s as Object, k as Object) as Float
    return LaneX(s.cfg, k.laneF, TrackPos(s.cfg, k.s))
end function

function PlayerX(s as Object) as Float
    return KartX(s, s.player)
end function

function ObjX(s as Object, lane as Integer, at as Float) as Float
    return LaneXi(s.cfg, lane, TrackPos(s.cfg, at))
end function

' 1 = leading. Karts further along the course are ahead.
function Position(s as Object, k as Object) as Integer
    p = 1
    for each o in s.karts
        if o.id <> k.id and o.s > k.s then p = p + 1
    end for
    return p
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
    if s.finished then
        if code = k.ok or code = k.play then ResetRace(s)
        return ""
    end if
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
        return ""
    end if
    if s.countdown > 0 then return ""
    if code = k.left then
        Steer(s, s.player, -1)
    else if code = k.right then
        Steer(s, s.player, 1)
    else if code = k.up then
        UseItem(s, s.player, "forward")
    else if code = k.down then
        UseItem(s, s.player, "back")
    else if code = k.ok then
        UseItem(s, s.player, "boost")
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

' Move a kart one lane left or right. Every lane is a track; across an open gap it is a jump.
' Returns true if the kart moved.
function Steer(s as Object, k as Object, dir as Integer) as Boolean
    if k.spinT > 0 or k.jumpT > 0 then return false
    t = k.lane + dir
    if t < 0 or t > s.cfg.lanes.count - 1 then return false
    lo = k.lane
    if t < lo then lo = t
    if GapBetween(s.cfg, lo, TrackPos(s.cfg, k.s)) >= s.cfg.lanes.jumpMinGap then
        k.jumpT = s.cfg.lanes.jumpTime
        if not k.isBot then
            s.stats.jumps = s.stats.jumps + 1
            Say(s, "JUMP!")
        end if
    end if
    k.lane = t
    return true
end function

' Up throws forward, Down drops behind, OK fires a boost.
sub UseItem(s as Object, k as Object, action as String)
    it = k.item
    ic = s.cfg.items
    if it = "" then return
    if action = "boost" then
        if it <> "boost" then return
        k.boostT = s.cfg.speed.boostTime
        if not k.isBot then
            s.stats.boosts = s.stats.boosts + 1
            Say(s, "BOOST!")
        end if
    else if it = "shell" then
        if action = "forward" then
            s.shots.Push({ s: k.s + 1.8, lane: k.lane, v: k.speed + ic.shellSpeed, life: ic.shellLife, owner: k.id })
        else
            s.shots.Push({ s: k.s - 1.8, lane: k.lane, v: k.speed - ic.shellSpeed, life: ic.shellLife, owner: k.id })
        end if
    else if it = "banana" then
        d = -ic.dropDist
        if action = "forward" then d = ic.throwDist
        s.hazards.Push({ s: k.s + d, lane: k.lane, life: ic.hazardLife })
    else
        return   ' a boost only fires with OK
    end if
    k.item = ""
end sub

function TopSpeed(s as Object, k as Object) as Float
    sp = s.cfg.speed
    if k.boostT > 0 then return sp.boostMax
    top = sp.max * k.skill
    if s.cfg.forkSpeedMode = "perRoute" then
        fork = ForkAt(s.cfg, TrackPos(s.cfg, k.s))
        if fork <> invalid then top = top * fork.speedMults[GroupOfLane(fork, k.lane)]
    end if
    return top
end function

' Did a kart pass lap position `at` between lap positions a and b this frame (handles the lap wrap)?
function Crossed(a as Float, b as Float, at as Float) as Boolean
    if b >= a then return at > a and at <= b
    return at > a or at <= b
end function

function Near(s as Object, x1 as Float, s1 as Float, x2 as Float, s2 as Float) as Boolean
    ic = s.cfg.items
    return Abs(x1 - x2) < ic.hitWidth and Abs(s1 - s2) < ic.hitLen
end function

sub SpinOut(s as Object, k as Object, ev as Object, why as String)
    k.spinT = s.cfg.speed.spinTime
    k.speed = k.speed * s.cfg.speed.spinFactor
    if not k.isBot then
        s.stats.spins = s.stats.spins + 1
        Say(s, "SPUN OUT!")
        ev.Push("spin")
    else
        ev.Push("botspin:" + why)
    end if
end sub

' Advance the race by dt seconds. Returns the events that happened (strings), for the HUD and tests.
function UpdateGame(s as Object, dtIn as Float) as Object
    ev = []
    if s.paused or s.finished then return ev
    cfg = s.cfg
    dt = dtIn
    if dt > cfg.maxDt then dt = cfg.maxDt
    if dt <= 0 then return ev
    if s.msgT > 0 then s.msgT = s.msgT - dt
    if s.countdown > 0 then
        s.countdown = s.countdown - dt
        if s.countdown <= 0 then
            s.countdown = 0
            Say(s, "GO!")
            ev.Push("go")
        end if
        return ev
    end if
    p = s.player
    s.time = s.time + dt
    L = cfg.track.length

    ' Index loop on purpose: helpers below also walk s.karts with for-each, and nested for-each over the
    ' same array shares one iterator in BrightScript.
    for ki = 0 to s.karts.Count() - 1
        k = s.karts[ki]
        prevS = k.s
        MoveKart(s, k, dt)
        smPrev = TrackPos(cfg, prevS)
        sm = TrackPos(cfg, k.s)
        if k.isBot then BotThink(s, k, dt)
        ' Item blocks: one per lane per row.
        myLane = Int(k.laneF + 0.5)
        for i = 0 to s.rows.Count() - 1
            if k.jumpT <= 0 and Crossed(smPrev, sm, s.rows[i]) and s.blocks[i][myLane] <= s.time then
                s.blocks[i][myLane] = s.time + cfg.items.respawn
                if k.item = "" then
                    k.item = RollItem(s)
                    k.holdT = RandRange(s, cfg.bots.useMin, cfg.bots.useMax)
                    if k.isBot then
                        s.stats.botItems = s.stats.botItems + 1
                    else
                        s.stats.items = s.stats.items + 1
                        ev.Push("item:" + k.item)
                    end if
                end if
            end if
        end for
        if not k.isBot then
            name = TrackName(cfg, k.lane, sm)
            if name <> s.trackName then
                if name <> "" then ev.Push("track:" + name)
                s.trackName = name
            end if
            if Int(k.s / L) > Int(prevS / L) then LapDone(s, ev)
        end if
    end for
    if s.finished then return ev

    ' Camera follows your kart; hills slide with the curves.
    px = PlayerX(s)
    s.camZ = p.s - cfg.camera.playerDepth
    f = cfg.camera.followRate * dt
    if f > 1 then f = 1
    s.camX = s.camX + (px - s.camX) * f
    s.bgX = s.bgX + CurveAt(cfg, p.s) * p.speed * dt * cfg.course.parallax

    KartContacts(s, ev)
    UpdateTraffic(s, dt, ev)
    UpdateShots(s, dt, ev)
    UpdateHazards(s, dt, ev)
    return ev
end function

' Speed, distance and lane slide for one kart.
sub MoveKart(s as Object, k as Object, dt as Float)
    cfg = s.cfg
    if k.boostT > 0 then k.boostT = k.boostT - dt
    if k.spinT > 0 then k.spinT = k.spinT - dt
    if k.jumpT > 0 then k.jumpT = k.jumpT - dt
    top = TopSpeed(s, k)
    acc = cfg.speed.accel
    if k.boostT > 0 then acc = cfg.speed.boostAccel
    if k.speed < top then
        k.speed = k.speed + acc * dt
        if k.speed > top then k.speed = top
    else if k.speed > top then
        k.speed = k.speed - cfg.speed.decel * dt
        if k.speed < top then k.speed = top
    end if
    k.s = k.s + k.speed * dt
    slide = dt / cfg.lanes.changeTime
    if k.laneF < k.lane then
        k.laneF = k.laneF + slide
        if k.laneF > k.lane then k.laneF = k.lane
    else if k.laneF > k.lane then
        k.laneF = k.laneF - slide
        if k.laneF < k.lane then k.laneF = k.lane
    end if
end sub

sub LapDone(s as Object, ev as Object)
    lapTime = s.time - s.lapStart
    s.lastLap = lapTime
    if s.best < 0 or lapTime < s.best then
        s.best = lapTime
        s.newBest = true
        Say(s, "NEW BEST LAP!")
    end if
    ev.Push("lap")
    laps = s.cfg.race.laps
    if laps > 0 and s.lap >= laps then
        s.finished = true
        s.finishPos = Position(s, s.player)
        s.raceTime = s.time
        ev.Push("finish:" + s.finishPos.ToStr())
        return
    end if
    s.lap = s.lap + 1
    s.lapStart = s.time
end sub

' Bot lane choices and item use.
sub BotThink(s as Object, k as Object, dt as Float)
    bc = s.cfg.bots
    k.think = k.think - dt
    if k.think <= 0 then
        k.think = RandRange(s, bc.thinkMin, bc.thinkMax)
        dir = 0
        if LaneDanger(s, k, k.lane) then
            dir = 1
            if RandF(s) < 0.5 then dir = -1
            if LaneDanger(s, k, k.lane + dir) then dir = -dir
        else if k.item = "" then
            dir = BlockDir(s, k)
        else if RandF(s) < 0.25 then
            dir = 1
            if RandF(s) < 0.5 then dir = -1
        end if
        if dir <> 0 then Steer(s, k, dir)
    end if
    if k.item <> "" then
        k.holdT = k.holdT - dt
        if k.holdT <= 0 then
            if k.item = "boost" then
                UseItem(s, k, "boost")
            else if k.item = "banana" then
                UseItem(s, k, "back")
            else if TargetAhead(s, k) or k.holdT < -6 then
                UseItem(s, k, "forward")
            end if
        end if
    end if
end sub

' Off the road, or traffic or a banana just ahead in that lane?
function LaneDanger(s as Object, k as Object, lane as Integer) as Boolean
    if lane < 0 or lane >= s.cfg.lanes.count then return true
    look = s.cfg.bots.lookAhead
    for each car in s.traffic
        d = car.s - k.s
        if car.lane = lane and d > 0 and d < look then return true
    end for
    for each b in s.hazards
        d = b.s - k.s
        if b.lane = lane and d > 0 and d < look then return true
    end for
    return false
end function

function TargetAhead(s as Object, k as Object) as Boolean
    for each o in s.karts
        d = o.s - k.s
        if o.id <> k.id and o.lane = k.lane and d > 0 and d < s.cfg.bots.shootRange then return true
    end for
    return false
end function

' Which way (-1, 0, 1) to the nearest lane with an item block in the next row ahead.
function BlockDir(s as Object, k as Object) as Integer
    sm = TrackPos(s.cfg, k.s)
    n = s.cfg.lanes.count
    for i = 0 to s.rows.Count() - 1
        d = s.rows[i] - sm
        if d > 5 and d < 80 then
            if s.blocks[i][k.lane] <= s.time then return 0
            for off = 1 to n
                l = k.lane - off
                if l >= 0 and s.blocks[i][l] <= s.time then return -1
                l = k.lane + off
                if l < n and s.blocks[i][l] <= s.time then return 1
            end for
            return 0
        end if
    end for
    return 0
end function

' Karts touching in the same lane: the one behind slows and drops back.
sub KartContacts(s as Object, ev as Object)
    ks = s.karts
    for i = 0 to ks.Count() - 2
        for j = i + 1 to ks.Count() - 1
            a = ks[i]
            b = ks[j]
            if a.jumpT <= 0 and b.jumpT <= 0 and Abs(a.s - b.s) < 1.0 and Abs(KartX(s, a) - KartX(s, b)) < s.cfg.items.hitWidth then
                rear = a
                front = b
                if a.s > b.s then
                    rear = b
                    front = a
                end if
                rear.speed = rear.speed * s.cfg.speed.kartBumpFactor
                rear.s = front.s - 1.0
                if not rear.isBot or not front.isBot then ev.Push("kartbump")
            end if
        end for
    end for
end sub

sub UpdateTraffic(s as Object, dt as Float, ev as Object)
    cfg = s.cfg
    p = s.player
    tc = cfg.traffic
    if s.trafficOn and s.traffic.Count() < tc.maxCars and RandF(s) < tc.perSecond * dt then
        lane = Int(RandF(s) * cfg.lanes.count)
        frac = tc.minFrac + RandF(s) * (tc.maxFrac - tc.minFrac)
        s.traffic.Push({ s: p.s + tc.spawnAhead, lane: lane, v: cfg.speed.max * frac })
    end if
    kept = []
    for each car in s.traffic
        car.s = car.s + car.v * dt
        cx = ObjX(s, car.lane, car.s)
        hit = invalid
        for each k in s.karts
            if hit = invalid and k.jumpT <= 0 and Near(s, cx, car.s, KartX(s, k), k.s) then hit = k
        end for
        if car.s < p.s - tc.despawnBehind then
            ' gone behind
        else if hit <> invalid then
            hit.speed = hit.speed * cfg.speed.bumpFactor
            if not hit.isBot then
                s.stats.bumps = s.stats.bumps + 1
                Say(s, "BUMP!")
                ev.Push("bump")
            end if
        else
            kept.Push(car)
        end if
    end for
    s.traffic = kept
end sub

' Shells fly along their lane and take out the first car or kart they reach.
sub UpdateShots(s as Object, dt as Float, ev as Object)
    kept = []
    for each sh in s.shots
        sh.s = sh.s + sh.v * dt
        sh.life = sh.life - dt
        sx = ObjX(s, sh.lane, sh.s)
        used = false
        for c = 0 to s.traffic.Count() - 1
            car = s.traffic[c]
            if Near(s, ObjX(s, car.lane, car.s), car.s, sx, sh.s) then
                s.traffic.Delete(c)
                used = true
                ev.Push("shellhit:car")
                exit for
            end if
        end for
        if not used then
            for each k in s.karts
                if not used and k.id <> sh.owner and k.jumpT <= 0 and Near(s, KartX(s, k), k.s, sx, sh.s) then
                    SpinOut(s, k, ev, "shell")
                    used = true
                    if sh.owner = 0 then
                        s.stats.shellHits = s.stats.shellHits + 1
                        Say(s, "HIT " + k.name + "!")
                        ev.Push("shellhit:" + k.name)
                    end if
                end if
            end for
        end if
        if not used and sh.life > 0 then kept.Push(sh)
    end for
    s.shots = kept
end sub

' Bananas spin out the first kart or car that runs into them.
sub UpdateHazards(s as Object, dt as Float, ev as Object)
    kept = []
    for each b in s.hazards
        b.life = b.life - dt
        bx = ObjX(s, b.lane, b.s)
        used = false
        for each k in s.karts
            if not used and k.jumpT <= 0 and Near(s, bx, b.s, KartX(s, k), k.s) then
                SpinOut(s, k, ev, "banana")
                used = true
            end if
        end for
        if not used then
            for c = 0 to s.traffic.Count() - 1
                car = s.traffic[c]
                if Near(s, ObjX(s, car.lane, car.s), car.s, bx, b.s) then
                    s.traffic.Delete(c)
                    ev.Push("carspin")
                    used = true
                    exit for
                end if
            end for
        end if
        if not used and b.life > 0 then kept.Push(b)
    end for
    s.hazards = kept
end sub

' The split zone coming up within `within` units, or invalid.
function ForkAhead(s as Object, within as Float) as Dynamic
    sm = TrackPos(s.cfg, s.player.s)
    for each fork in s.cfg.forks
        d = fork.start - sm
        if d > 0 and d <= within then return fork
    end for
    return invalid
end function

' 1st, 2nd, 3rd, 4th...
function Ordinal(n as Integer) as String
    sfx = "th"
    if n mod 100 < 11 or n mod 100 > 13 then
        if n mod 10 = 1 then sfx = "st"
        if n mod 10 = 2 then sfx = "nd"
        if n mod 10 = 3 then sfx = "rd"
    end if
    return n.ToStr() + sfx
end function

' 83.456 -> "1:23.46"
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
