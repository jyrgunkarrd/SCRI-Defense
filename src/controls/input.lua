local input = {}

function input.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

return input
