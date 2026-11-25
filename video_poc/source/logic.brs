' Video-track POC: all tunables and the pure race logic (no SceneGraph here, so the simulator can test it).
' Units: metres and seconds. Screen coordinates are the video's own 1280x720 frame, before the lane zoom.

function PocConfig() as Object
    return {
        ' Where the track videos live. Tonight: this repo on GitHub. Later: a Cloudflare R2 public bucket URL.
        baseUrl: "https://raw.githubusercontent.com/leftbrain847/kart_roku/main/media/"
        worlds: [
            { id: "jungle", title: "FERN RUSH", forks: ["GORGE FALLS", "RUIN RIDGE"] }
            { id: "library", title: "THE GRAND STACKS", forks: ["BOOK TUNNEL", "MEZZANINE"] }
        ]
        ' How the video moves to the fork you picked (Options * cycles them while racing):
        '   playlist: three files in a Video playlist; nextContentIndex follows your lane until the last moment.
        '   seek:     one file with all segments back to back; the right fork is a seek, the left plays straight on.
        '   swap:     three files; new content is loaded when a segment finishes (baseline to compare against).
        strategies: ["playlist", "seek", "swap"]
        laps: 3
        speed: 32               ' camera speed (m/s): the video was rendered at this speed
        camBack: 12             ' the camera is this far behind the kart line
        focal: 691.5            ' camera focal length in px (720 / 2 / tan(55deg / 2))
        laneW: 3.6
        lanes: 5
        laneTime: 0.2           ' seconds to slide one lane
        steerDeg: 14            ' kart turns this much while changing lane
        zoom: 1.25              ' lane zoom (Down toggles it): the picture scales up around your lane
        zoomFocusY: 470         ' ...keeping this row of the frame in place
        panRate: 6              ' how fast the zoom follows your lane (per second)
        home: -2.5              ' where your kart sits when level with the camera (m from the kart line; < 0 = nearer)
        depthMin: -5.5          ' karts drop back no further than this...
        depthMax: 24            ' ...and surge no further ahead than this
        boost: { ahead: 10, time: 1.6, charges: 3, recharge: 4 }
        spin: { back: -3.5, time: 0.9 }
        surgeRate: 1.6          ' how quickly a kart closes on its target depth (per second)
        maxSurge: 9             ' m/s relative to the camera
        bump: { len: 2.6, width: 0.7, knock: 2.2 }
        bots: [
            { name: "TEAL", variant: "teal", lane: 1, d: 6, skill: 1.0 }
            { name: "GOLD", variant: "gold", lane: 3, d: 12, skill: 0.9 }
            { name: "VIOLET", variant: "violet", lane: 4, d: 3, skill: 1.1 }
        ]
        player: { name: "YOU", variant: "red", lane: 2, d: -2.5 }
        botThinkMin: 0.8
        botThinkMax: 2.4
        tickSeconds: 0.016
        kmhBase: 115            ' speed readout when level with the camera
    }
end function

' ---- Lane tables -------------------------------------------------------------------------------------------
' table rows are sampled at `rate` Hz; each row holds [x, y, ppm, yaw] for every depth in `depths`.
' Returns { x, y, ppm, yaw } for time t (s) into the segment and depth d (m) ahead of the kart line.
function TableSample(lanes as Object, rows as Object, t as Float, d as Float) as Object
    f = t * lanes.rate
    last = rows.Count() - 1
    if f < 0 then f = 0
    if f > last then f = last
    i = Int(f)
    if i >= last then i = last - 1
    if i < 0 then i = 0
    ft = f - i
    a = DepthSample(lanes.depths, rows[i], d)
    if last < 1 then return a
    b = DepthSample(lanes.depths, rows[i + 1], d)
    return { x: a.x + (b.x - a.x) * ft, y: a.y + (b.y - a.y) * ft, ppm: a.ppm + (b.ppm - a.ppm) * ft, yaw: a.yaw + (b.yaw - a.yaw) * ft }
end function

function DepthSample(depths as Object, row as Object, d as Float) as Object
    n = depths.Count()
    if d <= depths[0] then return DepthLerp(row, 0, 0, 0.0)
    if d >= depths[n - 1] then return DepthLerp(row, n - 1, n - 1, 0.0)
    j = 0
    while j < n - 2 and depths[j + 1] < d
        j = j + 1
    end while
    u = (d - depths[j]) / (depths[j + 1] - depths[j])
    return DepthLerp(row, j, j + 1, u)
end function

function DepthLerp(row as Object, j as Integer, k as Integer, u as Float) as Object
    a = j * 4
    b = k * 4
    return {
        x: row[a] + (row[b] - row[a]) * u
        y: row[a + 1] + (row[b + 1] - row[a + 1]) * u
        ppm: row[a + 2] + (row[b + 2] - row[a + 2]) * u
        yaw: row[a + 3] + (row[b + 3] - row[a + 3]) * u
    }
end function

' Which table a kart on segment `seg` uses: on the shared straight it depends on the fork the kart takes.
function TableKey(seg as String, branch as String) as String
    if seg = "shared" then return "shared_" + branch
    return seg
end function

' Screen placement of a kart: bottom-anchored sprite box plus the angle to draw.
' sprite: { w, h, anchorX, anchorY, pxPerM }; lane is a float (0..4); steer and spin in degrees.
function KartPlace(cfg as Object, s as Object, sprite as Object, lane as Float, steer as Float, spin as Float) as Object
    lateral = (lane - (cfg.lanes - 1) / 2.0) * cfg.laneW
    x = s.x + s.ppm * lateral
    y = s.y
    k = s.ppm / sprite.pxPerM
    bearing = Atn((x - 640) / cfg.focal) * 57.29578
    ang = bearing - s.yaw + steer + spin
    return { x: x, y: y, scale: k, w: sprite.w * k, h: sprite.h * k, left: x - sprite.anchorX * k, top: y - sprite.anchorY * k, angle: AngleIndex(ang, 24) }
end function

' Sprite index for an angle in degrees, with `count` sprites evenly around the circle (index 0 = seen from behind).
function AngleIndex(deg as Float, count as Integer) as Integer
    stepDeg = 360.0 / count
    i = Int(deg / stepDeg + 0.5)
    i = i Mod count
    if i < 0 then i = i + count
    return i
end function

' ---- Forks --------------------------------------------------------------------------------------------------
' The fork your lane points at: left two lanes take the left fork, right two the right; the middle lane keeps
' the last pick.
function PickBranch(lane as Float, lastPick as String) as String
    if lane < 1.5 then return "left"
    if lane > 2.5 then return "right"
    return lastPick
end function

' A kart d metres ahead of the kart line reaches the fork this many seconds before the shared video ends.
function CommitTime(cfg as Object, sharedDur as Float, d as Float) as Float
    return sharedDur - (cfg.camBack + d) / cfg.speed
end function

' ---- Zoom ---------------------------------------------------------------------------------------------------
' Scale by z so that x = fx lands in the middle of the screen and row y = fy stays where it is; clamped so the
' scaled picture always covers the 1280x720 screen.
function ZoomTransform(z as Float, fx as Float, fy as Float) as Object
    tx = 640 - fx * z
    ty = fy - fy * z
    minX = 1280 - 1280 * z
    minY = 720 - 720 * z
    if tx > 0 then tx = 0
    if tx < minX then tx = minX
    if ty > 0 then ty = 0
    if ty < minY then ty = minY
    return { scale: z, tx: tx, ty: ty, w: 1280 * z, h: 720 * z }
end function

' ---- Race ---------------------------------------------------------------------------------------------------
function NewKart(def as Object, isPlayer as Boolean) as Object
    return {
        name: def.name, variant: def.variant, isPlayer: isPlayer
        lane: def.lane * 1.0, target: def.lane, d: def.d * 1.0, v: 0.0, skill: 1.0
        boostT: 0.0, spinT: 0.0, spinAng: 0.0, branch: "left", committed: false
        think: 1.0, wave: Rnd(0) * 6.28, visible: true
    }
end function

function NewRace(cfg as Object) as Object
    karts = [NewKart(cfg.player, true)]
    for each b in cfg.bots
        k = NewKart(b, false)
        k.skill = b.skill
        k.think = cfg.botThinkMin + Rnd(0) * (cfg.botThinkMax - cfg.botThinkMin)
        karts.Push(k)
    end for
    return { karts: karts, lap: 1, time: 0.0, charges: cfg.boost.charges, rechargeT: 0.0, pick: "left", finished: false, bumps: 0 }
end function

function Player(race as Object) as Object
    return race.karts[0]
end function

' Player input: "left", "right" (one lane), "boost". Returns true if it did something.
function RaceInput(cfg as Object, race as Object, action as String) as Boolean
    p = Player(race)
    if race.finished then return false
    if action = "left" and p.target > 0
        p.target = p.target - 1
        race.pick = PickBranch(p.target, "left")
        return true
    end if
    if action = "right" and p.target < cfg.lanes - 1
        p.target = p.target + 1
        race.pick = PickBranch(p.target, "right")
        return true
    end if
    if action = "boost" and race.charges > 0 and p.boostT <= 0 then
        race.charges = race.charges - 1
        p.boostT = cfg.boost.time
        return true
    end if
    return false
end function

' Advance the race by dt. seg/t say where the video is; sharedDur is the shared segment's length in seconds.
sub RaceStep(cfg as Object, race as Object, dt as Float, seg as String, t as Float, sharedDur as Float)
    if race.finished then return
    race.time = race.time + dt
    if race.charges < cfg.boost.charges
        race.rechargeT = race.rechargeT + dt
        if race.rechargeT >= cfg.boost.recharge
            race.charges = race.charges + 1
            race.rechargeT = 0
        end if
    end if
    for each k in race.karts
        StepKart(cfg, race, k, dt)
        if seg = "shared" and not k.committed
            if k.isPlayer then k.branch = race.pick
            if t >= CommitTime(cfg, sharedDur, k.d) then k.committed = true
        end if
    end for
    Bumps(cfg, race)
end sub

sub StepKart(cfg as Object, race as Object, k as Object, dt as Float)
    ' lane slide
    dl = k.target - k.lane
    stepL = dt / cfg.laneTime
    if Abs(dl) <= stepL then k.lane = k.target * 1.0 else k.lane = k.lane + Sgn(dl) * stepL
    ' bots: pick lanes and boosts now and then
    if not k.isPlayer
        k.think = k.think - dt
        if k.think <= 0
            k.think = cfg.botThinkMin + Rnd(0) * (cfg.botThinkMax - cfg.botThinkMin)
            r = Rnd(0)
            if r < 0.35 and k.target > 0
                k.target = k.target - 1
            else if r < 0.7 and k.target < cfg.lanes - 1
                k.target = k.target + 1
            end if
            if Rnd(0) < 0.15 * k.skill and k.boostT <= 0 then k.boostT = cfg.boost.time * 0.8
        end if
    end if
    ' target depth: level with the camera's kart line, ahead while boosting, behind after a spin
    goal = cfg.home
    if not k.isPlayer
        k.wave = k.wave + dt * 0.4
        goal = cfg.home + 6 * k.skill + Sin(k.wave) * 5
    end if
    if k.boostT > 0
        goal = goal + cfg.boost.ahead
        k.boostT = k.boostT - dt
    end if
    if k.spinT > 0
        goal = goal + cfg.spin.back
        k.spinT = k.spinT - dt
        k.spinAng = k.spinAng + dt * 800
        if k.spinT <= 0 then k.spinAng = 0
    end if
    v = (goal - k.d) * cfg.surgeRate
    if v > cfg.maxSurge then v = cfg.maxSurge
    if v < -cfg.maxSurge then v = -cfg.maxSurge
    k.v = v
    k.d = k.d + v * dt
    if k.d < cfg.depthMin then k.d = cfg.depthMin
    if k.d > cfg.depthMax then k.d = cfg.depthMax
end sub

' Two karts in the same lane and overlapping: the one behind is knocked back; if it was boosting, the one in
' front spins instead.
sub Bumps(cfg as Object, race as Object)
    n = race.karts.Count()
    for i = 0 to n - 2
        for j = i + 1 to n - 1
            a = race.karts[i]
            b = race.karts[j]
            if a.visible and b.visible and a.branch = b.branch and Abs(a.lane - b.lane) < cfg.bump.width and Abs(a.d - b.d) < cfg.bump.len
                back = b
                front = a
                if a.d < b.d
                    back = a
                    front = b
                end if
                if back.boostT > 0 and front.spinT <= 0
                    front.spinT = cfg.spin.time
                else
                    back.d = back.d - cfg.bump.knock
                end if
                race.bumps = race.bumps + 1
            end if
        end for
    end for
end sub

' A new lap starts when the video comes back to the shared straight.
sub NewLap(cfg as Object, race as Object)
    race.lap = race.lap + 1
    for each k in race.karts
        k.committed = false
        k.visible = true
        if not k.isPlayer
            k.branch = "left"
            if Rnd(0) < 0.5 then k.branch = "right"
        end if
    end for
    if race.lap > cfg.laps
        race.finished = true
        race.lap = cfg.laps
    end if
end sub

' Race order: furthest ahead of the camera first. Returns kart indexes.
function Ranks(race as Object) as Object
    order = []
    for i = 0 to race.karts.Count() - 1
        order.Push(i)
    end for
    for i = 1 to order.Count() - 1
        j = i
        while j > 0 and race.karts[order[j - 1]].d < race.karts[order[j]].d
            tmp = order[j]
            order[j] = order[j - 1]
            order[j - 1] = tmp
            j = j - 1
        end while
    end for
    return order
end function

function PlayerPos(race as Object) as Integer
    order = Ranks(race)
    for i = 0 to order.Count() - 1
        if order[i] = 0 then return i + 1
    end for
    return order.Count()
end function

function FormatTime(sec as Float) as String
    m = Int(sec / 60)
    s = sec - m * 60
    whole = Int(s)
    hund = Int((s - whole) * 100)
    ss = whole.ToStr()
    if whole < 10 then ss = "0" + ss
    hs = hund.ToStr()
    if hund < 10 then hs = "0" + hs
    return m.ToStr() + ":" + ss + "." + hs
end function
