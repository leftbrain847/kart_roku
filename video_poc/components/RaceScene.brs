' Race scene: the track is a pre-rendered video (shared straight, then the fork you pick); karts and HUD are
' drawn over it. Everything that can be tuned is in PocConfig() (source/logic.brs).

sub init()
    m.cfg = PocConfig()
    m.video = m.top.FindNode("video")
    m.overlay = m.top.FindNode("overlay")
    m.hud = m.top.FindNode("hud")
    m.menu = m.top.FindNode("menu")
    m.tick = m.top.FindNode("tick")
    m.slots = []
    for i = 0 to 3
        m.slots.Push(m.top.FindNode("k" + i.ToStr()))
    end for
    m.labels = {}
    for each id in ["lapLabel", "timeLabel", "posLabel", "boostLabel", "speedLabel", "forkLLabel", "forkRLabel", "debug", "banner", "menuWorld", "menuInfo"]
        m.labels[id] = m.top.FindNode(id)
    end for
    m.fork = m.top.FindNode("fork")
    m.forkL = m.top.FindNode("forkL")
    m.forkR = m.top.FindNode("forkR")
    m.menuBg = m.top.FindNode("menuBg")
    m.sprite = ParseJson(ReadAsciiFile("pkg:/images/karts/karts.json"))
    m.worldIdx = 0
    m.stratIdx = 0
    m.zoomOn = true
    m.racing = false
    m.paused = false
    m.clock = CreateObject("roTimespan")
    m.clock.Mark()
    m.tick.duration = m.cfg.tickSeconds
    m.tick.ObserveField("fire", "OnTick")
    m.video.ObserveField("state", "OnVideoState")
    m.video.ObserveField("position", "OnVideoPos")
    m.video.ObserveField("contentIndex", "OnContentIndex")
    m.video.notificationInterval = 0.1
    m.video.enableUI = false
    m.lastStall = -1
    m.stalls = 0
    m.fallbacks = 0
    m.ticks = 0
    m.tickRate = 0
    m.tickWin = 0
    ShowMenu()
    m.top.SetFocus(true)
end sub

function Now() as Float
    return m.clock.TotalMilliseconds() / 1000.0
end function

' ---- Menu ---------------------------------------------------------------------------------------------------
sub ShowMenu()
    m.racing = false
    m.tick.control = "stop"
    m.video.control = "stop"
    m.hud.visible = false
    m.overlay.visible = false
    m.menu.visible = true
    w = m.cfg.worlds[m.worldIdx]
    m.labels.menuWorld.text = "<  " + w.title + "  >"
    m.menuBg.uri = "pkg:/images/menu_" + w.id + ".jpg"
    m.labels.menuInfo.text = "Track videos stream from " + m.cfg.baseUrl + "    method: " + Strategy() + "    lane zoom: " + OnOff(m.zoomOn)
end sub

function OnOff(b as Boolean) as String
    if b then return "on"
    return "off"
end function

function Strategy() as String
    return m.cfg.strategies[m.stratIdx]
end function

' ---- Race setup ---------------------------------------------------------------------------------------------
sub StartRace()
    w = m.cfg.worlds[m.worldIdx]
    m.lanes = ParseJson(ReadAsciiFile("pkg:/data/" + w.id + ".json"))
    m.dur = { shared: m.lanes.segs.shared.dur, left: m.lanes.segs.left.dur, right: m.lanes.segs.right.dur }
    m.race = NewRace(m.cfg)
    for i = 1 to m.race.karts.Count() - 1
        k = m.race.karts[i]
        k.branch = "left"
        if Rnd(0) < 0.5 then k.branch = "right"
    end for
    m.menu.visible = false
    m.hud.visible = true
    m.overlay.visible = true
    m.labels.forkLLabel.text = "< " + w.forks[0]
    m.labels.forkRLabel.text = w.forks[1] + " >"
    m.labels.banner.text = ""
    m.seg = "shared"
    m.posBase = 0.0
    m.posWall = Now()
    m.playing = false
    m.endWall = -1.0
    m.measure = false
    m.seekIssued = false
    m.pendingSeg = ""
    m.nextSet = ""
    m.focusX = 640.0
    m.playerX = -1.0
    m.lastT = 0.0
    m.lastTick = Now()
    m.racing = true
    m.paused = false
    LoadVideo("shared")
    ApplyZoom(true)
    m.tick.control = "start"
end sub

function SegUrl(seg as String) as String
    return m.cfg.baseUrl + m.cfg.worlds[m.worldIdx].id + "/" + seg + ".mp4"
end function

function SegContent(seg as String) as Object
    c = CreateObject("roSGNode", "ContentNode")
    c.url = SegUrl(seg)
    c.streamFormat = "mp4"
    c.title = seg
    return c
end function

' Starts the video for the current method, at segment `seg` (shared at the start of a race).
sub LoadVideo(seg as String)
    s = Strategy()
    m.video.control = "stop"
    if s = "playlist"
        root = CreateObject("roSGNode", "ContentNode")
        for each name in ["shared", "left", "right"]
            root.AppendChild(SegContent(name))
        end for
        m.video.contentIsPlaylist = true
        m.video.loop = false
        m.video.content = root
    else if s = "seek"
        m.video.contentIsPlaylist = false
        m.video.loop = false
        m.video.content = SegContent("all")
    else
        m.video.contentIsPlaylist = false
        m.video.loop = false
        m.video.content = SegContent(seg)
    end if
    m.video.control = "play"
end sub

' ---- Video events -------------------------------------------------------------------------------------------
sub OnVideoState()
    st = m.video.state
    m.playing = (st = "playing")
    if st = "buffering" then m.stalls = m.stalls + 1
    if st = "error" then m.labels.banner.text = "VIDEO ERROR " + m.video.errorCode.ToStr() + ": " + m.video.errorMsg
    if not m.racing then return
    if st = "finished"
        s = Strategy()
        if s = "swap"
            if m.seg = "shared" then nxt = Player(m.race).branch else nxt = "shared"
            m.endWall = Now()
            m.video.content = SegContent(nxt)
            m.video.control = "play"
            EnterSeg(nxt)
        else if s = "seek"
            m.video.seek = 0
            m.video.control = "play"
        else
            ' the playlist ran out (nextContentIndex was not honoured): restart it at the segment we want
            nxt = 0
            if m.seg = "shared"
                nxt = 1
                if Player(m.race).branch = "right" then nxt = 2
            end if
            m.fallbacks = m.fallbacks + 1
            LoadVideo("shared")
            m.video.nextContentIndex = nxt
            if nxt > 0 then m.video.control = "skipcontent"
        end if
    end if
end sub

sub OnVideoPos()
    if not m.racing then return
    p = m.video.position
    if Strategy() = "seek"
        T1 = m.dur.shared
        T2 = T1 + m.dur.left
        if m.pendingSeg <> ""
            ' after a seek, wait until the position is inside the target segment
            if (m.pendingSeg = "right" and p >= T2 - 0.05) or (m.pendingSeg = "shared" and p < T1 - 0.05)
                EnterSeg(m.pendingSeg)
                m.pendingSeg = ""
                m.seekIssued = false
            else
                return
            end if
        else
            seg = "right"
            if p < T2 then seg = "left"
            if p < T1 then seg = "shared"
            if seg <> m.seg then EnterSeg(seg)
        end if
        m.posBase = p - SegOffset(m.seg)
    else
        m.posBase = p
    end if
    m.posWall = Now()
    if m.measure and m.endWall >= 0 and m.playing
        m.measure = false
        m.lastStall = Int((Now() - m.endWall - m.posBase) * 1000)
        if m.lastStall < 0 then m.lastStall = 0
        m.endWall = -1.0
    end if
end sub

function SegOffset(seg as String) as Float
    if Strategy() <> "seek" then return 0.0
    if seg = "left" then return m.dur.shared
    if seg = "right" then return m.dur.shared + m.dur.left
    return 0.0
end function

sub OnContentIndex()
    if not m.racing or Strategy() <> "playlist" then return
    names = ["shared", "left", "right"]
    i = m.video.contentIndex
    if i >= 0 and i < 3 then EnterSeg(names[i])
    m.nextSet = ""
end sub

' The video has moved to segment `seg`.
sub EnterSeg(seg as String)
    if seg = m.seg then return
    old = m.seg
    m.seg = seg
    m.posBase = 0.0
    m.posWall = Now()
    if m.endWall < 0 then m.endWall = Now()
    m.measure = true
    if old <> "shared" and seg = "shared"
        NewLap(m.cfg, m.race)
        if m.race.finished then FinishRace()
    else if old = "shared" and seg <> "shared"
        ' whatever the video did is the truth: you are on the fork it shows
        p = Player(m.race)
        p.branch = seg
        for each k in m.race.karts
            k.committed = true
            k.visible = (k.branch = seg)
        end for
    end if
end sub

sub FinishRace()
    place = PlayerPos(m.race)
    m.labels.banner.text = "FINISH  P" + place.ToStr() + "  " + FormatTime(m.race.time) + "     OK: race again   Back: menu"
end sub

' ---- Per-frame update ---------------------------------------------------------------------------------------
sub OnTick()
    nowT = Now()
    dt = nowT - m.lastTick
    m.lastTick = nowT
    if dt > 0.1 then dt = 0.1
    m.ticks = m.ticks + 1
    if nowT - m.tickWin >= 1
        m.tickRate = m.ticks
        m.ticks = 0
        m.tickWin = nowT
    end if
    if not m.racing or m.paused then return

    ' where the video is now: last reported position plus time since, while it plays
    t = m.lastT
    if m.playing
        t = m.posBase + (nowT - m.posWall)
        if t > m.posBase + 0.4 then t = m.posBase + 0.4
        m.lastT = t
        RaceStep(m.cfg, m.race, dt, m.seg, t, m.dur.shared)
    end if
    segDur = m.dur[m.seg]
    if t >= segDur - 0.01 and m.endWall < 0 then m.endWall = nowT - (t - segDur)

    SteerVideo(t)
    DrawKarts(t)
    ApplyZoom(false)
    DrawHud(t)
end sub

' Point the video at the fork you are taking (playlist) or jump there (seek).
sub SteerVideo(t as Float)
    s = Strategy()
    p = Player(m.race)
    if s = "playlist"
        want = 0
        if m.seg = "shared"
            want = 1
            if p.branch = "right" then want = 2
        end if
        key = m.seg + want.ToStr()
        if key <> m.nextSet
            m.video.nextContentIndex = want
            m.nextSet = key
        end if
    else if s = "seek" and not m.seekIssued
        lead = 0.03
        if m.seg = "shared" and p.branch = "right" and t >= m.dur.shared - lead
            m.video.seek = m.dur.shared + m.dur.left
            m.seekIssued = true
            m.pendingSeg = "right"
            m.endWall = Now()
        else if m.seg <> "shared" and t >= m.dur[m.seg] - lead
            m.video.seek = 0
            m.seekIssued = true
            m.pendingSeg = "shared"
            m.endWall = Now()
        end if
    end if
end sub

sub DrawKarts(t as Float)
    vis = []
    for each k in m.race.karts
        if k.visible and (m.seg = "shared" or k.branch = m.seg)
            rows = m.lanes.tables[TableKey(m.seg, k.branch)]
            s = TableSample(m.lanes, rows, t, k.d)
            steer = 0.0
            if k.target > k.lane + 0.05 then steer = m.cfg.steerDeg
            if k.target < k.lane - 0.05 then steer = -m.cfg.steerDeg
            pl = KartPlace(m.cfg, s, m.sprite, k.lane, steer, k.spinAng)
            pl.kart = k
            vis.Push(pl)
            if k.isPlayer then m.playerX = pl.x
        end if
    end for
    ' far karts first so near ones draw on top
    for i = 1 to vis.Count() - 1
        j = i
        while j > 0 and vis[j - 1].kart.d < vis[j].kart.d
            tmp = vis[j]
            vis[j] = vis[j - 1]
            vis[j - 1] = tmp
            j = j - 1
        end while
    end for
    for i = 0 to m.slots.Count() - 1
        slot = m.slots[i]
        if i < vis.Count()
            pl = vis[i]
            uri = "pkg:/images/karts/kart_" + pl.kart.variant + "_" + m.sprite.angles[pl.angle].ToStr() + ".png"
            if slot.uri <> uri then slot.uri = uri
            slot.width = pl.w
            slot.height = pl.h
            slot.translation = [pl.left, pl.top]
            slot.visible = true
        else
            slot.visible = false
        end if
    end for
end sub

' Lane zoom: the video and the kart layer scale up together around your lane.
sub ApplyZoom(force as Boolean)
    z = 1.0
    if m.zoomOn then z = m.cfg.zoom
    if m.playerX >= 0
        m.focusX = m.focusX + (m.playerX - m.focusX) * m.cfg.panRate * m.cfg.tickSeconds
    end if
    zt = ZoomTransform(z, m.focusX, m.cfg.zoomFocusY)
    tr = m.overlay.translation
    if force or Abs(tr[0] - zt.tx) > 0.5 or Abs(tr[1] - zt.ty) > 0.5 or m.overlay.scale[0] <> z
        m.overlay.scale = [z, z]
        m.overlay.translation = [zt.tx, zt.ty]
        m.video.translation = [zt.tx, zt.ty]
        m.video.width = zt.w
        m.video.height = zt.h
    end if
end sub

sub SetText(id as String, txt as String)
    l = m.labels[id]
    if l.text <> txt then l.text = txt
end sub

sub DrawHud(t as Float)
    r = m.race
    p = Player(r)
    SetText("lapLabel", "LAP " + r.lap.ToStr() + "/" + m.cfg.laps.ToStr())
    SetText("timeLabel", FormatTime(r.time))
    SetText("posLabel", "P" + PlayerPos(r).ToStr() + "/" + r.karts.Count().ToStr())
    b = ""
    for i = 1 to r.charges
        b = b + "> "
    end for
    SetText("boostLabel", "BOOST " + b)
    SetText("speedLabel", Int(m.cfg.kmhBase + p.v * 3.6).ToStr() + " km/h")
    showFork = (m.seg = "shared" and t > 0.6 and not p.committed)
    m.fork.visible = showFork
    if showFork
        if p.branch = "left"
            m.forkL.color = "0xE0322EE0"
            m.forkR.color = "0x0B0F23A0"
        else
            m.forkL.color = "0x0B0F23A0"
            m.forkR.color = "0xE0322EE0"
        end if
    end if
    stall = "-"
    if m.lastStall >= 0 then stall = m.lastStall.ToStr() + " ms"
    SetText("debug", "method " + Strategy() + " (*)   zoom " + OnOff(m.zoomOn) + " (Down)   overlay " + m.tickRate.ToStr() + " fps   video " + m.video.state + "   last fork switch stall " + stall + "   buffering events " + m.stalls.ToStr() + "   playlist restarts " + m.fallbacks.ToStr())
end sub

' ---- Input --------------------------------------------------------------------------------------------------
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if not m.racing
        n = m.cfg.worlds.Count()
        if key = "left"
            m.worldIdx = (m.worldIdx + n - 1) Mod n
            ShowMenu()
            return true
        end if
        if key = "right"
            m.worldIdx = (m.worldIdx + 1) Mod n
            ShowMenu()
            return true
        end if
        if key = "options"
            m.stratIdx = (m.stratIdx + 1) Mod m.cfg.strategies.Count()
            ShowMenu()
            return true
        end if
        if key = "OK" or key = "play"
            StartRace()
            return true
        end if
        if key = "back"
            m.top.exitApp = true
            return true
        end if
        return false
    end if
    if key = "back"
        ShowMenu()
        return true
    end if
    if m.race.finished
        if key = "OK" then StartRace()
        return true
    end if
    if key = "left"
        RaceInput(m.cfg, m.race, "left")
        return true
    end if
    if key = "right"
        RaceInput(m.cfg, m.race, "right")
        return true
    end if
    if key = "OK"
        RaceInput(m.cfg, m.race, "boost")
        return true
    end if
    if key = "down"
        m.zoomOn = not m.zoomOn
        ApplyZoom(true)
        return true
    end if
    if key = "options"
        m.stratIdx = (m.stratIdx + 1) Mod m.cfg.strategies.Count()
        m.lastStall = -1
        m.stalls = 0
        m.fallbacks = 0
        StartRace()
        return true
    end if
    if key = "play"
        m.paused = not m.paused
        if m.paused then m.video.control = "pause" else m.video.control = "resume"
        if m.paused then SetText("banner", "PAUSED") else SetText("banner", "")
        return true
    end if
    return true
end function
