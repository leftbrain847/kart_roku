' Kart video-track POC: a SceneGraph app. The race runs in components/RaceScene.
sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("RaceScene")
    screen.Show()
    scene.ObserveField("exitApp", port)
    while true
        msg = Wait(0, port)
        t = Type(msg)
        if t = "roSGScreenEvent" and msg.IsScreenClosed() then return
        if t = "roSGNodeEvent" and msg.GetField() = "exitApp" then return
    end while
end sub
