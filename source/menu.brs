' Title screen: pick a track and a racer. Left/Right changes the highlighted row, Up/Down moves between rows,
' OK starts the race, Back exits. Returns { track, racer } or invalid to exit.
function RunMenu(screen as Object, port as Object, cfg as Object, sel as Object) as Dynamic
    reg = CreateObject("roFontRegistry")
    fontXL = reg.GetDefaultFont(84, true, false)
    fontL = reg.GetDefaultFont(44, true, false)
    fontS = reg.GetDefaultFont(26, false, false)
    k = Keys()
    tracks = cfg.tracks
    roster = cfg.roster
    row = 0
    sky = invalid
    pic = invalid
    loaded = ""
    while true
        key = sel.track.ToStr() + "/" + sel.racer.ToStr()
        if key <> loaded then
            sky = CreateObject("roBitmap", "pkg:/images/sprites/sky_" + tracks[sel.track] + ".jpg")
            pic = CreateObject("roBitmap", "pkg:/images/sprites/racer_" + roster[sel.racer] + "_c.png")
            loaded = key
        end if
        DrawMenu(screen, cfg, sel, row, sky, pic, fontXL, fontL, fontS)
        screen.SwapBuffers()
        msg = wait(0, port)
        if type(msg) = "roUniversalControlEvent" then
            code = msg.GetInt()
            if code = k.back then return invalid
            if code = k.ok or code = k.play then return { track: tracks[sel.track], racer: roster[sel.racer] }
            if code = k.up or code = k.down then row = 1 - row
            d = 0
            if code = k.left then d = -1
            if code = k.right then d = 1
            if d <> 0 then
                if row = 0 then
                    sel.track = (sel.track + d + tracks.Count()) mod tracks.Count()
                else
                    sel.racer = (sel.racer + d + roster.Count()) mod roster.Count()
                end if
            end if
        end if
    end while
    return invalid
end function

sub DrawMenu(screen as Object, cfg as Object, sel as Object, row as Integer, sky as Object, pic as Object, fontXL as Object, fontL as Object, fontS as Object)
    W = cfg.screen.w
    H = cfg.screen.h
    screen.Clear(&h101420FF)
    if sky <> invalid then screen.DrawScaledObject(0, 0, W / sky.GetWidth(), H / sky.GetHeight(), sky)
    screen.DrawRect(0, 0, W, H, &h0B0F2370)
    screen.DrawRect(60, 120, 720, 470, &h0B0F23C8)
    MenuText(screen, "KART", 90, 140, &hFFD23FFF, fontXL)
    rows = [["TRACK", TrackTitle(cfg.tracks[sel.track])], ["RACER", RacerTitle(cfg.roster[sel.racer])]]
    for i = 0 to 1
        y = 290 + i * 120
        col = &hFFFFFFFF
        if i = row then
            col = &hFFD23FFF
            screen.DrawRect(80, y - 10, 680, 100, &hFFFFFF18)
        end if
        MenuText(screen, rows[i][0], 100, y, &hB4B9C6FF, fontS)
        MenuText(screen, "<  " + rows[i][1] + "  >", 100, y + 32, col, fontL)
    end for
    MenuText(screen, "UP/DOWN choose   LEFT/RIGHT change   OK race   BACK exit", 90, 540, &hB4B9C6FF, fontS)
    if pic <> invalid then
        sc = 360.0 / pic.GetWidth()
        if pic.GetHeight() * sc > 420 then sc = 420.0 / pic.GetHeight()
        screen.DrawScaledObject(820 + (400 - pic.GetWidth() * sc) / 2, 160 + (420 - pic.GetHeight() * sc) / 2, sc, sc, pic)
    end if
end sub

sub MenuText(screen as Object, text as String, x as Integer, y as Integer, color as Integer, font as Object)
    screen.DrawText(text, x + 3, y + 3, &h000000C0, font)
    screen.DrawText(text, x, y, color, font)
end sub

sub DrawLoading(screen as Object, cfg as Object, track as String)
    font = CreateObject("roFontRegistry").GetDefaultFont(44, true, false)
    screen.Clear(&h101420FF)
    MenuText(screen, "LOADING " + TrackTitle(track) + "...", 90, 330, &hFFD23FFF, font)
    screen.SwapBuffers()
end sub
