' Every tunable for the game lives here. Units: distances in lane widths ("units"), time in seconds.
' Colors are 0xRRGGBBAA for Draw2D.
function GameConfig() as Object
    return {
        screen: { w: 1280, h: 720, horizonY: 250 }

        lanes: {
            count: 5            ' number of lanes
            changeTime: 0.14    ' seconds to slide one lane
        }

        speed: {
            max: 34             ' cruising top speed (units/s); the kart auto-accelerates to it
            accel: 14           ' units/s^2 toward top speed
            decel: 30           ' units/s^2 when above the current top speed (after a boost ends)
            start: 0            ' speed at the start line
            boostMax: 52        ' top speed while boosting
            boostAccel: 90
            boostTime: 1.6      ' seconds a boost lasts
            bumpFactor: 0.45    ' speed multiplier when you hit traffic
            spinFactor: 0.30    ' speed multiplier when you hit a banana
            spinTime: 0.8       ' seconds of lost steering after a banana
            kmhPerUnit: 4       ' HUD speed readout = speed * this
        }

        track: {
            length: 1800        ' one lap, in units
            stripeLen: 3        ' length of one rumble/dash stripe
            drawDist: 140       ' how far ahead the road is drawn
            sceneryEvery: 9     ' a roadside tree every N units, each side
        }

        ' Route forks. At `start` the road splits: lanes [0 .. split-1] take routes[0], the rest take routes[1].
        ' Your lane when you reach `start` picks the route and you stay on it until the routes rejoin at
        ' start + openLen + length + closeLen. `gap` is the grass median at full width (units).
        forks: [
            {
                start: 420, openLen: 70, length: 320, closeLen: 70, gap: 3.2, split: 2
                routes: [
                    { name: "CANYON", speedMult: 1.10 }
                    { name: "COAST", speedMult: 0.96 }
                ]
            }
            {
                start: 1160, openLen: 70, length: 300, closeLen: 70, gap: 3.6, split: 3
                routes: [
                    { name: "FOREST", speedMult: 0.95 }
                    { name: "RIDGE", speedMult: 1.08 }
                ]
            }
        ]
        ' "carry": speed carries through forks unchanged (default).
        ' "perRoute": top speed on a route is speed.max * that route's speedMult.
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
        }

        colors: {
            sky: &h5EB7F2FF, skyHigh: &h3A86D6FF, hills: &h3E7D4BFF, hillsFar: &h6FA36AFF
            grassDark: &h2F8A35FF, grassLight: &h3A9E3FFF
            road: &h5A5E66FF, roadAlt: &h53575FFF
            rumbleA: &hE8E8E8FF, rumbleB: &hD43A2FFF, lane: &hF2F2F2FF
            hud: &hFFFFFFFF, hudShadow: &h000000C0, hudAccent: &hFFD23FFF, panel: &h0B0F23C8
        }

        bestKey: "best_lap_ms"   ' registry key for the best lap
        maxDt: 0.1               ' clamp long frames so the sim never jumps
    }
end function
