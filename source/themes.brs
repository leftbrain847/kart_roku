' Road themes: sky art, ground and road colors, distance fog, and the roadside scenery. Colors are 0xRRGGBB
' (alpha is added when the renderer pre-blends them with the fog). Sky/far/near art is drawn by scripts/art.
function Themes() as Object
    return {
        meadow: { terrain: { hills: 2.9, mountains: 6.7, bumps: 0.4 }, ground: [&h2F8A35, &h3A9E3F], road: [&h5A5E66, &h53575F], rumble: [&hE8E8E8, &hD43A2F], lane: &hF2F2F2
                  laneStyle: "dash", fog: &hA9DBF5, scenery: ["tree", "tree", "fence"], gap: 1.1 }
        desert: { terrain: { hills: 1.9, mountains: 11.8, bumps: 0.25 }, rock: [&hB8683E, &hA85E38], ground: [&hD9A76A, &hE3B47A], road: [&h6E6058, &h665850], rumble: [&hF2E6D0, &hB5502A], lane: &hF6E9C8
                  laneStyle: "dash", fog: &hF7D9A8, scenery: ["cactus", "rock"], gap: 1.3 }
        city: { terrain: { hills: 0.4, mountains: 0, bumps: 0.1 }, ground: [&h1B1E2E, &h222638], road: [&h2E3140, &h292C3A], rumble: [&hFFD66B, &h3A3F5C], lane: &hFFE9A8
                laneStyle: "dash", fog: &h3A2A5A, scenery: ["lamp", "building"], gap: 1.4, tunnel: "steel" }
        snow: { terrain: { hills: 3.8, mountains: 15.1, bumps: 0.5 }, ground: [&hE8EFF7, &hF6F9FC], road: [&h6F7D8C, &h687584], rumble: [&hFFFFFF, &h2F6FD4], lane: &hFFFFFF
                laneStyle: "dash", fog: &hE8F1FA, scenery: ["pine"], gap: 1.2, tunnel: "snow", chasm: [&h8FB2D8, &hA4C2E2] }
        beach: { terrain: { hills: 1.9, mountains: 3.4, bumps: 0.3 }, ground: [&hE9D29C, &hF1DCAA], road: [&h626A74, &h5C646E], rumble: [&hFFFFFF, &h2FA4D8], lane: &hFFFFFF
                 laneStyle: "dash", fog: &hBFEBFF, scenery: ["palm"], gap: 1.3, rightGround: [&h1F86C4, &h2A93D0] }
        synth: { terrain: { hills: 2.4, mountains: 10.1, bumps: 0 }, rock: [&h3A1466, &h2E0F55], ground: [&h1A0B33, &h2A0F4A], road: [&h120A24, &h160C2C], rumble: [&hFF3EC8, &h3EE8FF], lane: &hFF6FD8
                 laneStyle: "solid", fog: &hFF5A9A, scenery: ["pylon"], gap: 1.0, tunnel: "steel" }
        volcano: { terrain: { hills: 2.9, mountains: 13.4, bumps: 0.6 }, rock: [&h3A2A2A, &h2E2222], ground: [&h2A1C1C, &h332222], road: [&h3A3434, &h342E2E], rumble: [&hFF5A1A, &h2A1A1A], lane: &hFFB060
                   laneStyle: "dash", fog: &hD2461E, scenery: ["lavarock"], gap: 1.2 }
        forest: { terrain: { hills: 3.8, mountains: 8.4, bumps: 0.5 }, ground: [&h24603A, &h2C6E42], road: [&h7A5A3A, &h725435], rumble: [&h9A7A50, &h5A3A20], lane: &hC8A878
                  laneStyle: "none", fog: &hD9E8D0, scenery: ["pine", "tree"], gap: 0.9 }
        autumn: { terrain: { hills: 3.3, mountains: 6.7, bumps: 0.4 }, ground: [&hA2843A, &hB08F42], road: [&h5E5A56, &h57534F], rumble: [&hF2EDE2, &hC2541E], lane: &hF2EDE2
                  laneStyle: "dash", fog: &hF5D9B0, scenery: ["autumn", "autumn", "fence"], gap: 1.1 }
        space: { terrain: { hills: 1.9, mountains: 6.7, bumps: 0.9 }, rock: [&h55596A, &h4C5060], ground: [&h3A3D4A, &h434656], road: [&h17192A, &h1B1D30], rumble: [&h7A5CFF, &h3EE8FF], lane: &h9F8CFF
                 laneStyle: "solid", fog: &h14183A, scenery: ["crystal"], gap: 1.2, tunnel: "steel" }
        ' Showcase worlds: textured roads, 3D-rendered racers and props, their own courses.
        jungle: { terrain: { hills: 3.8, mountains: 10.1, bumps: 0.5 }, ground: [&h2E6B34, &h37793C], road: [&h96603E, &h8C5A3A], rumble: [&hD9C9A0, &h6B4A2A], lane: &hE8D8B0
                  laneStyle: "none", fog: &hCFE2B8, scenery: ["fern", "palm", "fern"], gap: 1.1, roadTex: "road_jungle.jpg"
                  median: "brachio", landmarks: [{ at: 260, x: -9, k: "brachio" }, { at: 1150, x: 10, k: "brachio" }]
                  racers: ["hatchling", "triceracart", "gearsnail", "hermit"], chasm: [&h2E86A0, &h3A97B0]
                  forkNames: [["FERN PATH", "DINO RUN"], ["LEFT VINE", "MUD FLATS", "RIGHT VINE"], ["TAR PITS", "BONEYARD"]] }
        skytrack: { terrain: { hills: 0, mountains: 0, bumps: 0 }, ground: [&h000000, &h000000], road: [&h70768A, &h6A7084], rumble: [&hFFC21A, &h1A1A1A], lane: &hFFC21A
                    laneStyle: "dash", fog: &hFFAA88, scenery: ["beacon"], gap: 0.4, roadTex: "road_skytrack.jpg", void: true
                    hang: "girder", hangEvery: 12, tubeWall: [&h3A3F55, &h454B64], tubeCeil: [&h2C3044, &h343A50], tubeLight: &h7FE8FF
                    racers: ["toaster", "gearsnail", "jelly", "triceracart"] }
        whirligig: { terrain: { hills: 4.8, mountains: 11.8, bumps: 0.6 }, rock: [&hC9A8F0, &hBC98E8], ground: [&h9FE6C8, &hFFC4E0], road: [&hF6E2F0, &hEED6E8], rumble: [&hFFFFFF, &hE04A9A], lane: &hFFFFFF
                     laneStyle: "none", fog: &hE8D8FF, scenery: ["swirltree", "swirltree", "teacup"], gap: 1.5
                     roadTex: "road_whirligig.jpg", median: "swirltree", tunnel: "candy"
                     landmarks: [{ at: 700, x: -7, k: "teacup" }, { at: 1050, x: 8, k: "teacup" }]
                     racers: ["teapot", "duckboat", "jelly", "gearsnail"], chasm: [&hB898E8, &hA886DC]
                     forkNames: [["UPSIDE", "DOWNSIDE"], ["FIDDLE", "FADDLE", "FOO"], ["HITHER", "THITHER"]] }
        pebble: { terrain: { hills: 2.9, mountains: 5.9, bumps: 0.3 }, ground: [&hE4D3A8, &hEBDBB2], road: [&hBCB09A, &hB4A892], rumble: [&hFFFFFF, &h2A8FD0], lane: &hFFFFFF
                  laneStyle: "none", fog: &hE6F4FA, scenery: ["umbrella", "palm"], gap: 1.4, roadTex: "road_pebble.jpg"
                  rightGround: [&h1F86C4, &h2A93D0], median: "palm"
                  landmarks: [{ at: 420, x: 9, k: "lighthouse" }, { at: 1330, x: 0, k: "rockarch" }]
                  racers: ["hermit", "jelly", "hatchling", "toaster"], chasm: [&h1F7CB8, &h2A8CC8]
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
        racer: 1.05, loopring: 9.5, portal_rock: 17, portal_snow: 17, portal_candy: 17, ramp: 5.8, swirltree: 1.6, teacup: 2.6, brachio: 10, fern: 1.6, girder: 0.9, beacon: 0.35, lighthouse: 2.4, umbrella: 1.8, rockarch: 9.5
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

' Courses: curves, hills (`rise`, adding up to 0 per lap), banked turns (`bank` degrees), tubes, barrel rolls
' (`roll: 360`) and loops (`loop: true`). Loops and rolls sit outside the split zones. Every track has one.
function WorldCourse(name as String) as Dynamic
    if name = "jungle" then
        return { sections: [
            { len: 150, curve: 0 }, { len: 200, curve: 0.6, rise: 6 }, { len: 150, curve: -0.9, rise: -9 }
            { len: 60, curve: 0, rise: 3 }, { len: 30, curve: 0, jump: true }, { len: 130, curve: 0 }
            { len: 160, curve: -0.4 }, { len: 200, curve: -0.4, tunnel: "rock" }, { len: 200, curve: 0.9, rise: -5, bank: 14 }
            { len: 220, curve: 0.3, rise: 5 }, { len: 100, curve: -0.5 }, { len: 150, curve: 0, roll: 360 }
            { len: 50, curve: 0 }
        ] }
    else if name = "skytrack" then
        return { sections: [
            { len: 150, curve: 0 }, { len: 150, curve: 0.5, rise: 4 }, { len: 200, curve: 0, tube: true }
            { len: 180, curve: 0, roll: 360 }, { len: 150, curve: -0.7, rise: -4, bank: -16 }, { len: 100, curve: 0.6, rise: 6 }
            { len: 32, curve: 0, jump: true }, { len: 68, curve: 0.6 }, { len: 250, curve: -0.3, rise: -6 }, { len: 200, curve: 0, tube: true }, { len: 30, curve: 0 }
            { len: 170, curve: 0, loop: true }, { len: 120, curve: 0.4 }
        ], forks: [
            { start: 760, openLen: 60, length: 300, closeLen: 60, gap: 4.0, splits: [2]
              names: ["UPPER", "LOWER"], speedMults: [1.0, 1.0] }
        ] }
    else if name = "whirligig" then
        ' Everything at once: a climb into a candy mountain, a banked dive, a jump, splits, a barrel roll, a loop.
        return { sections: [
            { len: 80, curve: 0 }, { len: 120, curve: 0.5, rise: 6 }, { len: 180, curve: -0.4, tunnel: "candy" }
            { len: 40, curve: 0 }, { len: 140, curve: 0.6, rise: -10, bank: 14 }, { len: 30, curve: 0, jump: true }
            { len: 290, curve: -0.7, rise: 4 }, { len: 40, curve: 0 }, { len: 220, curve: 0.5, rise: 3 }
            { len: 20, curve: 0 }, { len: 240, curve: -0.6, rise: -3, bank: -16 }, { len: 50, curve: 0.3 }
            { len: 150, curve: 0, roll: -360 }, { len: 160, curve: 0, loop: true }, { len: 40, curve: 0 }
        ] }
    else if name = "pebble" then
        return { sections: [
            { len: 150, curve: 0 }, { len: 250, curve: 0.5, rise: 5 }, { len: 150, curve: -0.6, rise: -5 }
            { len: 100, curve: 0.3 }, { len: 180, curve: 0.3, tunnel: "rock" }, { len: 20, curve: 0 }
            { len: 250, curve: -0.8, rise: 4, bank: -14 }, { len: 140, curve: 0.4, rise: -4 }, { len: 30, curve: 0, jump: true }
            { len: 30, curve: 0 }, { len: 300, curve: -0.2 }, { len: 160, curve: 0, loop: true }, { len: 40, curve: 0 }
        ] }
    end if
    ' Classic road themes take one of two layouts, mirrored on every other theme.
    names = ThemeNames()
    idx = -1
    for i = 0 to names.Count() - 1
        if names[i] = name then idx = i
    end for
    if idx < 0 then return invalid
    m = 1
    if (idx \ 2) mod 2 = 1 then m = -1
    tun = "rock"
    th = Themes()[name]
    if th.DoesExist("tunnel") then tun = th.tunnel
    if idx mod 2 = 0 then
        ' Rollercoaster: a loop early, a big drop into the first split, a banked sweeper, a barrel roll home.
        return { sections: [
            { len: 120, curve: 0 }, { len: 130, curve: 0.5 * m, rise: 5 }, { len: 150, curve: 0, loop: true }
            { len: 20, curve: 0 }, { len: 280, curve: -0.6 * m, rise: -8 }, { len: 60, curve: 0.4 * m, rise: 6 }
            { len: 120, curve: 0.4 * m, tunnel: tun }, { len: 20, curve: 0 }
            { len: 100, curve: -0.3 * m, rise: -3 }, { len: 32, curve: 0, jump: true }, { len: 128, curve: -0.3 * m }
            { len: 240, curve: 0.7 * m, bank: 14 * m }
            { len: 200, curve: -0.5 * m }, { len: 150, curve: 0, roll: 360 * m }, { len: 50, curve: 0 }
        ] }
    end if
    ' Valley: a climb and a sudden drop, a long banked bend, rolling hills, a loop to finish.
    return { sections: [
        { len: 100, curve: 0 }, { len: 200, curve: 0.4 * m, rise: 7 }, { len: 120, curve: 0, rise: -7 }
        { len: 140, curve: -0.5 * m, rise: 4, bank: -12 * m }, { len: 200, curve: -0.5 * m, tunnel: tun }
        { len: 120, curve: -0.5 * m, bank: -12 * m }, { len: 40, curve: 0 }, { len: 240, curve: 0.8 * m, rise: -6 }
        { len: 140, curve: -0.4 * m, rise: 2 }, { len: 30, curve: 0, jump: true }, { len: 270, curve: -0.4 * m }
        { len: 150, curve: 0, loop: true }, { len: 50, curve: 0 }
    ] }
end function

' Names shown on the title screen.
function TrackTitle(name as String) as String
    t = { jungle: "FERNBACK JUNGLE", skytrack: "GIRDER SKY", pebble: "PEBBLE COVE", meadow: "GREEN MEADOW", desert: "MESA DESERT"
          city: "NIGHT CITY", snow: "SNOW PASS", beach: "PALM BEACH", synth: "NEON GRID", volcano: "LAVA FIELDS"
          forest: "PINE TRAIL", autumn: "AUTUMN LANES", space: "MOON BASE", whirligig: "WHIRLIGIG WOODS" }
    if t.DoesExist(name) then return t[name]
    return UCase(name)
end function

function RacerTitle(name as String) as String
    t = { hatchling: "RAPTOR HATCHLING", triceracart: "TRIKE", toaster: "TOASTER TANK", gearsnail: "GEAR SNAIL"
          hermit: "HERMIT CONCH", jelly: "JELLY JET", teapot: "TEAPOT TURBO", duckboat: "TUB DUCK" }
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
    if th.DoesExist("terrain") then
        for each key in th.terrain
            cfg.terrain[key] = th.terrain[key]
        end for
    end if
    if th.DoesExist("forkNames") then
        for i = 0 to cfg.forks.Count() - 1
            if i < th.forkNames.Count() then cfg.forks[i].names = th.forkNames[i]
        end for
    end if
end sub
