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
