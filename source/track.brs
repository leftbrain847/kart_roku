' Track geometry: lap position, forks and lane x positions. Pure functions (no screen), unit-tested.

' Position within the current lap, 0 <= result < track length.
function TrackPos(cfg as Object, s as Float) as Float
    L = cfg.track.length
    return s - Int(s / L) * L
end function

function ForkEnd(fork as Object) as Float
    return fork.start + fork.openLen + fork.length + fork.closeLen
end function

' The fork covering lap position sm, or invalid on a single road.
function ForkAt(cfg as Object, sm as Float) as Dynamic
    for each fork in cfg.forks
        if sm >= fork.start and sm < ForkEnd(fork) then return fork
    end for
    return invalid
end function

' Width of the grass median at lap position sm inside a fork: opens, holds, closes.
function ForkGap(fork as Object, sm as Float) as Float
    t = sm - fork.start
    if t < 0 then return 0
    if t < fork.openLen then return fork.gap * t / fork.openLen
    if t < fork.openLen + fork.length then return fork.gap
    rest = ForkEnd(fork) - sm
    if rest <= 0 then return 0
    return fork.gap * rest / fork.closeLen
end function

' Which route (0 or 1) a lane belongs to at a fork.
function RouteOfLane(fork as Object, lane as Integer) as Integer
    if lane < fork.split then return 0
    return 1
end function

' Lanes you can steer between while on a route: [first, last].
function RouteLanes(cfg as Object, fork as Object, route as Integer) as Object
    if route = 0 then return [0, fork.split - 1]
    return [fork.split, cfg.lanes.count - 1]
end function

' World x of a lane centre (laneF may be fractional while sliding). side: 0/1 = which route, -1 = from the lane.
function LaneX(cfg as Object, laneF as Float, sm as Float, side as Integer) as Float
    x = laneF - (cfg.lanes.count - 1) / 2.0
    fork = ForkAt(cfg, sm)
    if fork = invalid then return x
    if side < 0 then side = RouteOfLane(fork, Int(laneF + 0.5))
    g = ForkGap(fork, sm)
    if side = 0 then return x - g / 2
    return x + g / 2
end function

' Road surface at lap position sm, as pieces {x0, x1, lanes}: one piece, or two inside a fork.
function RoadPieces(cfg as Object, sm as Float) as Object
    n = cfg.lanes.count
    half = n / 2.0
    fork = ForkAt(cfg, sm)
    if fork = invalid then return [{ x0: -half, x1: half, lanes: n }]
    g = ForkGap(fork, sm) / 2
    mid = -half + fork.split
    return [
        { x0: -half - g, x1: mid - g, lanes: fork.split }
        { x0: mid + g, x1: half + g, lanes: n - fork.split }
    ]
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
        if f.start <= prevEnd then errs.Push(tag + " starts before the previous fork ends (or at 0)")
        if ForkEnd(f) >= L then errs.Push(tag + " must rejoin before the lap ends")
        if f.split < 1 or f.split > n - 1 then errs.Push(tag + ".split must leave at least one lane per route")
        if f.openLen <= 0 or f.closeLen <= 0 then errs.Push(tag + " openLen/closeLen must be > 0")
        if f.routes.Count() <> 2 then errs.Push(tag + " needs exactly 2 routes")
        prevEnd = ForkEnd(f)
    end for
    if cfg.forkSpeedMode <> "carry" and cfg.forkSpeedMode <> "perRoute" then errs.Push("forkSpeedMode must be carry or perRoute")
    total = 0
    for each k in cfg.items.odds
        if cfg.items.odds[k] < 0 then errs.Push("items.odds." + k + " must be >= 0")
        total = total + cfg.items.odds[k]
    end for
    if total <= 0 then errs.Push("items.odds must have a positive total")
    rows = 0
    for each b in cfg.render.bands
        rows = rows + b[0]
    end for
    if rows <> cfg.screen.h - cfg.screen.horizonY then errs.Push("render.bands rows must add up to screen.h - screen.horizonY")
    return errs
end function
