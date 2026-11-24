' Track geometry: lap position, curves, split zones and lane x positions. Pure functions (no screen), unit-tested.

' Position within the current lap, 0 <= result < track length.
function TrackPos(cfg as Object, s as Float) as Float
    L = cfg.track.length
    return s - Int(s / L) * L
end function

function ForkEnd(fork as Object) as Float
    return fork.start + fork.openLen + fork.length + fork.closeLen
end function

' The split zone covering lap position sm, or invalid on a single road.
function ForkAt(cfg as Object, sm as Float) as Dynamic
    for each fork in cfg.forks
        if sm >= fork.start and sm < ForkEnd(fork) then return fork
    end for
    return invalid
end function

' Width of each gap at lap position sm inside a split zone: opens, holds, closes.
function ForkGap(fork as Object, sm as Float) as Float
    t = sm - fork.start
    if t < 0 then return 0
    if t < fork.openLen then return fork.gap * t / fork.openLen
    if t < fork.openLen + fork.length then return fork.gap
    rest = ForkEnd(fork) - sm
    if rest <= 0 then return 0
    return fork.gap * rest / fork.closeLen
end function

' Which track group (0..splits) a lane is in.
function GroupOfLane(fork as Object, lane as Integer) as Integer
    g = 0
    for each sp in fork.splits
        if lane >= sp then g = g + 1
    end for
    return g
end function

' Name of the track a lane is on at sm ("" outside split zones).
function TrackName(cfg as Object, lane as Integer, sm as Float) as String
    fork = ForkAt(cfg, sm)
    if fork = invalid then return ""
    return fork.names[GroupOfLane(fork, lane)]
end function

' Is there an open gap between lanes a and a+1 at sm?
function GapBetween(cfg as Object, a as Integer, sm as Float) as Float
    fork = ForkAt(cfg, sm)
    if fork = invalid then return 0
    if GroupOfLane(fork, a) = GroupOfLane(fork, a + 1) then return 0
    return ForkGap(fork, sm)
end function

' World x of a whole lane's centre at lap position sm.
function LaneXi(cfg as Object, lane as Integer, sm as Float) as Float
    x = lane - (cfg.lanes.count - 1) / 2.0
    fork = ForkAt(cfg, sm)
    if fork = invalid then return x
    k = fork.splits.Count()
    return x + (GroupOfLane(fork, lane) - k / 2.0) * ForkGap(fork, sm)
end function

' World x of a (possibly fractional, mid-slide) lane position.
function LaneX(cfg as Object, laneF as Float, sm as Float) as Float
    a = Int(laneF)
    if a >= cfg.lanes.count - 1 then return LaneXi(cfg, cfg.lanes.count - 1, sm)
    if a < 0 then return LaneXi(cfg, 0, sm)
    f = laneF - a
    xa = LaneXi(cfg, a, sm)
    if f <= 0 then return xa
    return xa + (LaneXi(cfg, a + 1, sm) - xa) * f
end function

' Road surface at lap position sm, as pieces {x0, x1, lanes, first}: one piece, or one per track group in a split.
function RoadPieces(cfg as Object, sm as Float) as Object
    n = cfg.lanes.count
    half = n / 2.0
    fork = ForkAt(cfg, sm)
    if fork = invalid then return [{ x0: -half, x1: half, lanes: n, first: 0 }]
    g = ForkGap(fork, sm)
    k = fork.splits.Count()
    bounds = [0]
    for each sp in fork.splits
        bounds.Push(sp)
    end for
    bounds.Push(n)
    pieces = []
    for j = 0 to k
        off = (j - k / 2.0) * g
        pieces.Push({ x0: bounds[j] - half + off, x1: bounds[j + 1] - half + off, lanes: bounds[j + 1] - bounds[j], first: bounds[j] })
    end for
    return pieces
end function

' Builds the course tables, one entry per whole unit of the lap:
'   curve  - eased in and out of each section
'   elev   - road height; a section's `rise` eases it up or down; a `loop` section adds a hump that rises
'            and falls back (the climb up the loop's wall and the drop out of it)
'   roll   - camera roll in degrees: `roll` sweeps 0 -> roll (a barrel roll is 360), `bank` tilts into a bend
'            and back out, and a `loop` flips you through the top (0 -> 360)
'   tube   - tube or tunnel style at that unit ("" = open air): `tube: true` is a steel tube, `tunnel: "rock"`
'            (or snow, candy, steel) is a tunnel bored into a mountain
'   gap    - a `jump` section: the road is missing; karts launch off a ramp at its start and land past it
' cfg.course.loops, .tunnels and .jumps list where each starts, so the renderer can show the loop, the
' mountain's tunnel mouth and the ramp ahead.
sub PrepareCourse(cfg as Object)
    if cfg.course.DoesExist("table") then return
    curveTab = []
    elevTab = []
    rollTab = []
    tubeTab = []
    gapTab = []
    loops = []
    tunnels = []
    jumps = []
    ease = cfg.course.easeLen
    elev = 0.0
    at = 0
    for each sec in cfg.course.sections
        rise = 0
        if sec.DoesExist("rise") then rise = sec.rise
        roll = 0
        if sec.DoesExist("roll") then roll = sec.roll
        bank = 0
        if sec.DoesExist("bank") then bank = sec.bank
        tube = ""
        if sec.DoesExist("tube") and sec.tube then tube = "steel"
        if sec.DoesExist("tunnel") then
            tube = sec.tunnel
            tunnels.Push({ at: at, style: tube })
        end if
        gap = sec.DoesExist("jump") and sec.jump
        if gap then jumps.Push({ at: at, len: sec.len })
        isLoop = sec.DoesExist("loop") and sec.loop
        hump = 0
        if isLoop then
            hump = sec.len * cfg.course.loopHeight
            roll = 360
            loops.Push(at)
        end if
        for u = 0 to sec.len - 1
            f = 1.0
            if ease > 0 then
                if u < ease then f = u / ease
                if sec.len - u < ease then f = (sec.len - u) / ease
                if f > 1 then f = 1
            end if
            curveTab.Push(sec.curve * f)
            t = u / sec.len
            sw = Sin(3.14159265 * t)
            elevTab.Push(elev + rise * (1 - Cos(3.14159265 * t)) / 2 + hump * sw * sw)
            rollTab.Push(roll * (1 - Cos(3.14159265 * t)) / 2 + bank * f)
            tubeTab.Push(tube)
            gapTab.Push(gap)
        end for
        elev = elev + rise
        at = at + sec.len
    end for
    while curveTab.Count() < cfg.track.length
        curveTab.Push(0)
        elevTab.Push(elev)
        rollTab.Push(0)
        tubeTab.Push("")
        gapTab.Push(false)
    end while
    cfg.course.table = curveTab
    cfg.course.elev = elevTab
    cfg.course.roll = rollTab
    cfg.course.tube = tubeTab
    cfg.course.gap = gapTab
    cfg.course.loops = loops
    cfg.course.tunnels = tunnels
    cfg.course.jumps = jumps
end sub

' How sharply the road crests at s (negative = cresting); used for airtime.
function CrestAt(cfg as Object, s as Float) as Float
    return ElevAt(cfg, s + 2) - 2 * ElevAt(cfg, s) + ElevAt(cfg, s - 2)
end function

' Curve (before curveScale) at track position s.
function CurveAt(cfg as Object, s as Float) as Float
    return cfg.course.table[Int(TrackPos(cfg, s))]
end function

' Road height at track position s, interpolated between whole units.
function ElevAt(cfg as Object, s as Float) as Float
    sm = TrackPos(cfg, s)
    i = Int(sm)
    j = i + 1
    if j >= cfg.track.length then j = 0
    f = sm - i
    return cfg.course.elev[i] * (1 - f) + cfg.course.elev[j] * f
end function

function RollAt(cfg as Object, s as Float) as Float
    return cfg.course.roll[Int(TrackPos(cfg, s))]
end function

function TubeAt(cfg as Object, s as Float) as Boolean
    return cfg.course.tube[Int(TrackPos(cfg, s))] <> ""
end function

' Tube or tunnel style at s: "steel", "rock", "snow", "candy" or "" in the open.
function TubeStyle(cfg as Object, s as Float) as String
    return cfg.course.tube[Int(TrackPos(cfg, s))]
end function

' Is the road missing here (the gap of a jump)?
function GapAt(cfg as Object, s as Float) as Boolean
    return cfg.course.gap[Int(TrackPos(cfg, s))]
end function

' Problems with a config, as readable strings. Empty array = valid.
function ValidateConfig(cfg as Object) as Object
    errs = []
    n = cfg.lanes.count
    if n < 2 then errs.Push("lanes.count must be at least 2")
    L = cfg.track.length
    prevEnd = 0
    for i = 0 to cfg.forks.Count() - 1
        f = cfg.forks[i]
        tag = "forks[" + i.ToStr() + "]"
        if f.start <= prevEnd then errs.Push(tag + " starts before the previous split zone ends (or at 0)")
        if ForkEnd(f) >= L then errs.Push(tag + " must rejoin before the lap ends")
        last = 0
        for each sp in f.splits
            if sp <= last or sp > n - 1 then errs.Push(tag + ".splits must rise between 1 and lanes.count-1")
            last = sp
        end for
        if f.splits.Count() = 0 then errs.Push(tag + ".splits needs at least one split")
        if f.openLen <= 0 or f.closeLen <= 0 then errs.Push(tag + " openLen/closeLen must be > 0")
        groups = f.splits.Count() + 1
        if f.names.Count() <> groups or f.speedMults.Count() <> groups then errs.Push(tag + " needs one name and speedMult per track group")
        prevEnd = ForkEnd(f)
    end for
    total = 0
    rises = 0
    for each sec in cfg.course.sections
        total = total + sec.len
        if sec.DoesExist("rise") then rises = rises + sec.rise
    end for
    if total <> L then errs.Push("course.sections lengths must add up to track.length")
    if Abs(rises) > 0.001 then errs.Push("course.sections rises must add up to 0 so the lap ends where it starts")
    if cfg.forkSpeedMode <> "carry" and cfg.forkSpeedMode <> "perRoute" then errs.Push("forkSpeedMode must be carry or perRoute")
    total = 0
    for each k in cfg.items.odds
        if cfg.items.odds[k] < 0 then errs.Push("items.odds." + k + " must be >= 0")
        total = total + cfg.items.odds[k]
    end for
    if total <= 0 then errs.Push("items.odds must have a positive total")
    if cfg.bots.count > cfg.bots.names.Count() or cfg.bots.count > cfg.bots.bodies.Count() then errs.Push("bots need a name and body color each")
    rows = 0
    for each b in cfg.render.bands
        rows = rows + b[0]
    end for
    if rows <> cfg.screen.h - cfg.screen.horizonY then errs.Push("render.bands rows must add up to screen.h - screen.horizonY")
    return errs
end function
