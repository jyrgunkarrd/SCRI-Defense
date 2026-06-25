function love.conf(t)
    t.identity = "scri-spirit-old-world"
    t.appendidentity = false

    t.window.title = "SCRI Spirit Old World"
    t.window.width = 1920
    t.window.height = 1080
    t.window.fullscreen = true
    t.window.fullscreentype = "exclusive"
    t.window.resizable = false
    t.window.vsync = 1
    t.window.msaa = 4

    t.modules.joystick = false
    t.modules.physics = false
end
