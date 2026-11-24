' Road themes: sky art, ground and road colors, distance fog, and the roadside scenery. Colors are 0xRRGGBB
' (alpha is added when the renderer pre-blends them with the fog). Sky/far/near art is drawn by scripts/art.
function Themes() as Object
    return {
        meadow: { ground: [&h2F8A35, &h3A9E3F], road: [&h5A5E66, &h53575F], rumble: [&hE8E8E8, &hD43A2F], lane: &hF2F2F2
                  laneStyle: "dash", fog: &hA9DBF5, scenery: ["tree", "tree", "fence"], gap: 1.1 }
        desert: { ground: [&hD9A76A, &hE3B47A], road: [&h6E6058, &h665850], rumble: [&hF2E6D0, &hB5502A], lane: &hF6E9C8
                  laneStyle: "dash", fog: &hF7D9A8, scenery: ["cactus", "rock"], gap: 1.3 }
        city: { ground: [&h1B1E2E, &h222638], road: [&h2E3140, &h292C3A], rumble: [&hFFD66B, &h3A3F5C], lane: &hFFE9A8
                laneStyle: "dash", fog: &h3A2A5A, scenery: ["lamp", "building"], gap: 1.4 }
        snow: { ground: [&hE8EFF7, &hF6F9FC], road: [&h6F7D8C, &h687584], rumble: [&hFFFFFF, &h2F6FD4], lane: &hFFFFFF
                laneStyle: "dash", fog: &hE8F1FA, scenery: ["pine"], gap: 1.2 }
        beach: { ground: [&hE9D29C, &hF1DCAA], road: [&h626A74, &h5C646E], rumble: [&hFFFFFF, &h2FA4D8], lane: &hFFFFFF
                 laneStyle: "dash", fog: &hBFEBFF, scenery: ["palm"], gap: 1.3, rightGround: [&h1F86C4, &h2A93D0] }
        synth: { ground: [&h1A0B33, &h2A0F4A], road: [&h120A24, &h160C2C], rumble: [&hFF3EC8, &h3EE8FF], lane: &hFF6FD8
                 laneStyle: "solid", fog: &hFF5A9A, scenery: ["pylon"], gap: 1.0 }
        volcano: { ground: [&h2A1C1C, &h332222], road: [&h3A3434, &h342E2E], rumble: [&hFF5A1A, &h2A1A1A], lane: &hFFB060
                   laneStyle: "dash", fog: &hD2461E, scenery: ["lavarock"], gap: 1.2 }
        forest: { ground: [&h24603A, &h2C6E42], road: [&h7A5A3A, &h725435], rumble: [&h9A7A50, &h5A3A20], lane: &hC8A878
                  laneStyle: "none", fog: &hD9E8D0, scenery: ["pine", "tree"], gap: 0.9 }
        autumn: { ground: [&hA2843A, &hB08F42], road: [&h5E5A56, &h57534F], rumble: [&hF2EDE2, &hC2541E], lane: &hF2EDE2
                  laneStyle: "dash", fog: &hF5D9B0, scenery: ["autumn", "autumn", "fence"], gap: 1.1 }
        space: { ground: [&h3A3D4A, &h434656], road: [&h17192A, &h1B1D30], rumble: [&h7A5CFF, &h3EE8FF], lane: &h9F8CFF
                 laneStyle: "solid", fog: &h14183A, scenery: ["crystal"], gap: 1.2 }
        ' Showcase worlds: textured roads, 3D-rendered racers and props, their own courses.
        jungle: { ground: [&h2E6B34, &h37793C], road: [&h96603E, &h8C5A3A], rumble: [&hD9C9A0, &h6B4A2A], lane: &hE8D8B0
                  laneStyle: "none", fog: &hCFE2B8, scenery: ["fern", "palm", "fern"], gap: 1.1, roadTex: "road_jungle.png"
                  median: "brachio", landmarks: [{ at: 260, x: -9, k: "brachio" }, { at: 1150, x: 10, k: "brachio" }]
                  racers: ["hatchling", "triceracart", "gearsnail", "hermit"]
                  forkNames: [["FERN PATH", "DINO RUN"], ["LEFT VINE", "MUD FLATS", "RIGHT VINE"], ["TAR PITS", "BONEYARD"]] }
        skytrack: { ground: [&h000000, &h000000], road: [&h70768A, &h6A7084], rumble: [&hFFC21A, &h1A1A1A], lane: &hFFC21A
                    laneStyle: "dash", fog: &hFFAA88, scenery: ["beacon"], gap: 0.4, roadTex: "road_skytrack.png", void: true
                    hang: "girder", hangEvery: 12, tubeWall: [&h3A3F55, &h454B64], tubeCeil: [&h2C3044, &h343A50], tubeLight: &h7FE8FF
                    racers: ["toaster", "gearsnail", "jelly", "triceracart"] }
        pebble: { ground: [&hE4D3A8, &hEBDBB2], road: [&hBCB09A, &hB4A892], rumble: [&hFFFFFF, &h2A8FD0], lane: &hFFFFFF
                  laneStyle: "none", fog: &hE6F4FA, scenery: ["umbrella", "palm"], gap: 1.4, roadTex: "road_pebble.png"
                  rightGround: [&h1F86C4, &h2A93D0], median: "palm"
                  landmarks: [{ at: 420, x: 9, k: "lighthouse" }, { at: 1240, x: 0, k: "rockarch" }]
                  racers: ["hermit", "jelly", "hatchling", "toaster"]
                  forkNames: [["TIDE POOLS", "BOARDWALK"], ["DUNES", "PROMENADE", "SHALLOWS"], ["COVE", "CLIFFTOP"]] }
    }
end function

function ThemeNames() as Object
    return ["meadow", "desert", "city", "snow", "beach", "synth", "volcano", "forest", "autumn", "space"]
end function

' Width of each sprite in world units (lane widths); height follows the art's aspect ratio.
function SpriteWidths() as Object
    return {
        kart: 0.95, car: 0.90, block: 0.52, shell: 0.38, banana: 0.36, boost: 0.30
        tree: 1.2, pine: 1.1, cactus: 0.7, rock: 1.4, lamp: 0.5, building: 2.8, palm: 1.5, pylon: 0.4
        lavarock: 1.4, autumn: 1.3, fence: 1.7, crystal: 0.9
        racer: 1.05, brachio: 10, fern: 1.6, girder: 0.9, beacon: 0.35, lighthouse: 2.4, umbrella: 1.8, rockarch: 9.5
    }
end function

' 0xRRGGBB, 0xRRGGBB, t -> blended 0xRRGGBBFF for Draw2D
function MixColor(a as Integer, b as Integer, t as Float) as Integer
    ar = (a >> 16) and 255
    ag = (a >> 8) and 255
    ab = a and 255
    r = ar + Int((((b >> 16) and 255) - ar) * t)
    g = ag + Int((((b >> 8) and 255) - ag) * t)
    bl = ab + Int(((b and 255) - ab) * t)
    return (r << 24) or (g << 16) or (bl << 8) or 255
end function

' Courses for the showcase worlds: curves, hills (rise), tubes and corkscrew rolls. Rises add up to 0.
function WorldCourse(name as String) as Dynamic
    if name = "jungle" then
        return { sections: [
            { len: 150, curve: 0 }, { len: 200, curve: 0.6, rise: 6 }, { len: 150, curve: -0.9, rise: -9 }
            { len: 220, curve: 0, rise: 3 }, { len: 360, curve: -0.4 }, { len: 200, curve: 0.9, rise: -5 }
            { len: 220, curve: 0.3, rise: 5 }, { len: 300, curve: -0.5 }
        ] }
    else if name = "skytrack" then
        return { sections: [
            { len: 150, curve: 0 }, { len: 150, curve: 0.5, rise: 4 }, { len: 200, curve: 0, tube: true }
            { len: 180, curve: 0, roll: 360 }, { len: 150, curve: -0.7, rise: -4 }, { len: 200, curve: 0.6, rise: 6 }
            { len: 250, curve: -0.3, rise: -6 }, { len: 200, curve: 0, tube: true }, { len: 320, curve: 0.4 }
        ], forks: [
            { start: 760, openLen: 60, length: 300, closeLen: 60, gap: 4.0, splits: [2]
              names: ["UPPER", "LOWER"], speedMults: [1.0, 1.0] }
        ] }
    else if name = "pebble" then
        return { sections: [
            { len: 150, curve: 0 }, { len: 250, curve: 0.5, rise: 5 }, { len: 150, curve: -0.6, rise: -5 }
            { len: 300, curve: 0.3 }, { len: 250, curve: -0.8, rise: 4 }, { len: 200, curve: 0.4, rise: -4 }
            { len: 500, curve: -0.2 }
        ] }
    end if
    return invalid
end function

' Names shown on the title screen.
function TrackTitle(name as String) as String
    t = { jungle: "FERNBACK JUNGLE", skytrack: "GIRDER SKY", pebble: "PEBBLE COVE", meadow: "GREEN MEADOW", desert: "MESA DESERT"
          city: "NIGHT CITY", snow: "SNOW PASS", beach: "PALM BEACH", synth: "NEON GRID", volcano: "LAVA FIELDS"
          forest: "PINE TRAIL", autumn: "AUTUMN LANES", space: "MOON BASE" }
    if t.DoesExist(name) then return t[name]
    return UCase(name)
end function

function RacerTitle(name as String) as String
    t = { hatchling: "RAPTOR HATCHLING", triceracart: "TRIKE", toaster: "TOASTER TANK", gearsnail: "GEAR SNAIL"
          hermit: "HERMIT CONCH", jelly: "JELLY JET" }
    if t.DoesExist(name) then return t[name]
    return UCase(name)
end function

' Set up a race: the track (a world brings its course, splits and bots) and your racer; the bots are the
' track's own racers, then the rest of the roster, never repeating you.
sub SetupRace(cfg as Object, track as String, racer as String)
    ApplyWorld(cfg, track)
    pool = []
    pool.Append(cfg.racers)
    pool.Append(cfg.roster)
    out = [racer]
    for each n in pool
        if out.Count() <= cfg.bots.count then
            dup = false
            for each o in out
                if o = n then dup = true
            end for
            if not dup then out.Push(n)
        end if
    end for
    cfg.racers = out
    cfg.bestKey = "best_" + track
end sub

' Switch cfg to a theme; a showcase world also brings its course, splits and racers.
sub ApplyWorld(cfg as Object, name as String)
    cfg.themeName = name
    wc = WorldCourse(name)
    if wc <> invalid then
        cfg.course.sections = wc.sections
        if wc.DoesExist("forks") then cfg.forks = wc.forks
        cfg.course.Delete("table")
    end if
    th = Themes()[name]
    if th.DoesExist("racers") then cfg.racers = th.racers
    if th.DoesExist("forkNames") then
        for i = 0 to cfg.forks.Count() - 1
            if i < th.forkNames.Count() then cfg.forks[i].names = th.forkNames[i]
        end for
    end if
end sub
