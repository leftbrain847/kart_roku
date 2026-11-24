' Every tunable for the game lives here. Units: distances in lane widths ("units"), time in seconds.
' Colors are 0xRRGGBBAA for Draw2D.
function GameConfig() as Object
    return {
        screen: { w: 1280, h: 720, horizonY: 250 }

        lanes: {
            count: 5            ' number of lanes; every lane is its own track
            changeTime: 0.14    ' seconds to slide one lane
            jumpTime: 0.32      ' seconds airborne when you hop the gap between split tracks
            jumpMinGap: 0.6     ' a lane change across a gap at least this wide is a jump
            jumpHeight: 0.55    ' hop height (units)
        }

        race: {
            laps: 3             ' race length; 0 = endless laps
            countdown: 3        ' seconds of 3-2-1 before the start
        }

        speed: {
            max: 26             ' cruising top speed (units/s); karts auto-accelerate to it
            accel: 10           ' units/s^2 toward top speed
            decel: 30           ' units/s^2 when above the current top speed (after a boost ends)
            start: 0            ' speed at the start line
            boostMax: 40        ' top speed while boosting
            boostAccel: 70
            boostTime: 1.6      ' seconds a boost lasts
            bumpFactor: 0.45    ' speed multiplier when you hit traffic
            kartBumpFactor: 0.85 ' speed multiplier for the kart behind when two karts touch
            spinFactor: 0.30    ' speed multiplier when a banana or shell gets you
            spinTime: 0.8       ' seconds of lost steering after a banana or shell
            kmhPerUnit: 4       ' HUD speed readout = speed * this
        }

        track: {
            length: 1800        ' one lap, in units
            stripeLen: 3        ' length of one rumble/dash stripe
            drawDist: 140       ' how far ahead the road is drawn
            sceneryEvery: 9     ' a roadside tree every N units, each side
        }

        ' The course: sections in order, lengths adding up to track.length. curve > 0 bends right, < 0 left.
        course: {
            sections: [
                { len: 150, curve: 0 }, { len: 200, curve: 0.8 }, { len: 70, curve: 0 }
                { len: 460, curve: -0.4 }, { len: 120, curve: 1.0 }, { len: 160, curve: -0.6 }
                { len: 440, curve: 0.5 }, { len: 100, curve: -0.9 }, { len: 100, curve: 0 }
            ]
            curveScale: 0.0022  ' how sharply a curve of 1.0 bends on screen
            easeLen: 30         ' units to ease into and out of each curve
            parallax: 0.004     ' how far the hills slide per unit of curve driven
        }

        ' Split zones. At `start` gaps open between lane groups: `splits` lists the first lane of each new group
        ' (lanes are 0-based: [2] = lanes 1-2 | 3-5 on screen). Every lane is a track; Left/Right always moves one
        ' lane, and moving across an open gap is a jump. The tracks rejoin at start + openLen + length + closeLen.
        ' `names` and `speedMults` have one entry per track group.
        forks: [
            { start: 420, openLen: 70, length: 320, closeLen: 70, gap: 3.2, splits: [2]
              names: ["CANYON", "COAST"], speedMults: [1.10, 0.96] }
            { start: 920, openLen: 50, length: 120, closeLen: 50, gap: 2.4, splits: [1, 4]
              names: ["GORGE", "HIGHWAY", "CLIFF"], speedMults: [1.12, 1.0, 1.12] }
            { start: 1160, openLen: 70, length: 300, closeLen: 70, gap: 3.6, splits: [3]
              names: ["FOREST", "RIDGE"], speedMults: [0.95, 1.08] }
        ]
        ' "carry": speed carries through splits unchanged (default).
        ' "perRoute": top speed on a track group is speed.max * that group's speedMult.
        forkSpeedMode: "carry"

        items: {
            firstRow: 120       ' track position of the first row of item blocks
            rowEvery: 200       ' one row (one block per lane) every N units
            respawn: 6          ' seconds before a taken block comes back
            odds: { shell: 40, banana: 35, boost: 25 }   ' relative weights
            shellSpeed: 40      ' shell speed relative to the thrower (units/s)
            shellLife: 3        ' seconds before a shell fizzles
            throwDist: 45       ' a banana thrown forward lands this far ahead
            dropDist: 4         ' a banana dropped lands this far behind
            hazardLife: 25      ' seconds a banana stays on the road
            hitLen: 1.6         ' collision length along the track
            hitWidth: 0.6       ' collision width across lanes
        }

        bots: {
            count: 3            ' computer racers
            names: ["ROCKO", "PIP", "VEX"]
            bodies: [&h2FB14AFF, &h8E44D9FF, &hFF8C1AFF]   ' kart colors, one per bot
            skillMin: 0.93      ' bot top speed as a fraction of speed.max
            skillMax: 1.02
            thinkMin: 0.6       ' seconds between lane decisions
            thinkMax: 2.2
            lookAhead: 20       ' how far ahead bots look for hazards
            shootRange: 45      ' bots throw a shell at a kart this close ahead in their lane
            useMin: 0.8         ' seconds a bot holds an item before using it
            useMax: 3.5
            gridGap: 5          ' bots start this far apart ahead of you (you start at the back)
        }

        traffic: {
            enabled: true       ' default; the pause menu toggles it
            perSecond: 0.35     ' density: average cars spawned per second
            minFrac: 0.35       ' traffic speed as a fraction of speed.max
            maxFrac: 0.55
            spawnAhead: 130     ' cars appear this far ahead
            despawnBehind: 20
            maxCars: 4
        }

        camera: {
            k: 460              ' projection: px per unit = k / depth
            height: 2.04        ' camera height (units)
            playerDepth: 3.0    ' kart's distance in front of the camera
            nearDepth: 1.96     ' depth of the bottom screen row
            followRate: 9       ' how fast the camera slides to the kart's x
        }

        render: {
            ' Road is drawn in horizontal bands: [rows from horizon, band height px]. Fewer, taller bands = faster.
            bands: [[20, 1], [50, 2], [120, 4], [280, 7]]
            spriteLevels: 30    ' pre-scaled copies per sprite
            minPpu: 3           ' smallest scale (px per unit)
            maxPpu: 240         ' largest scale
            maxSpritePx: 420    ' a pre-scaled copy never exceeds this many px (texture memory on the stick)
        }

        colors: {
            sky: &h5EB7F2FF, skyHigh: &h3A86D6FF, hills: &h3E7D4BFF, hillsFar: &h6FA36AFF
            grassDark: &h2F8A35FF, grassLight: &h3A9E3FFF
            road: &h5A5E66FF, roadAlt: &h53575FFF
            rumbleA: &hE8E8E8FF, rumbleB: &hD43A2FFF, lane: &hF2F2F2FF
            hud: &hFFFFFFFF, hudShadow: &h000000C0, hudAccent: &hFFD23FFF, panel: &h0B0F23C8
            player: &hE0322EFF
        }

        themeName: "jungle"      ' the track: a world or road theme from Themes() in themes.brs
        ' Racers: art is racer_<name>_<c|l|r>.png. racers[0] is you, the rest are the bots.
        roster: ["hatchling", "triceracart", "toaster", "gearsnail", "hermit", "jelly"]
        racers: ["hatchling", "triceracart", "toaster", "hermit"]
        ' Tracks offered on the title screen, in order: the three worlds, then the classic road themes.
        tracks: ["jungle", "skytrack", "pebble", "meadow", "desert", "city", "snow", "beach", "synth", "volcano", "forest", "autumn", "space"]
        fog: { start: 25, end: 150, max: 0.8 }   ' road colors blend toward the sky color with distance

        bestKey: "best_lap_ms"   ' registry key for the best lap
        maxDt: 0.1               ' clamp long frames so the sim never jumps
    }
end function
