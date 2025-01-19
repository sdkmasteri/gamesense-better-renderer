local inspect = require("gamesense/inspect")
--region @utils and misc
local function Color(r, g, b, a)
    return {
        r = r or 0,
        g = g or 0,
        b = b or 0,
        a = a or 255
    }
end
local function Coord(x, y)
    return {
        x = x or 0,
        y = y or 0
    }
end
local screen = {client.screen_size()}
local utils, better_renderer, global, dragable = {}, {}, {}, {}
local better_renderer_mt = {__index = better_renderer}
utils.sumcoord = function(coord1, coord2)
    return Coord(coord1.x + coord2.x, coord1.y + coord2.y)
end
utils.in_range_triangle = function(curs, coords)
    local a = (coords[1].x - curs.x) * (coords[2].y - coords[1].y) - (coords[2].x - coords[1].x) * (coords[1].y - curs.y)
    local b = (coords[2].x - curs.x) * (coords[3].y - coords[2].y) - (coords[3].x - coords[2].x) * (coords[2].y - curs.y)
    local c = (coords[3].x - curs.x) * (coords[1].y - coords[3].y) - (coords[1].x - coords[3].x) * (coords[3].y - curs.y)
    if (a >= 0 and b >= 0 and c >= 0) then return true end
    return false
end
utils.in_range_rect = function(curs, coord, size)
    return curs.x > coord.x and curs.x < coord.x + size.x and curs.y > coord.y and curs.y < coord.y + size.y 
end
utils.in_range_circle = function(curs, coord, radius)
    return (curs.x - coord.x)^2 + (curs.y - coord.y)^2 <= radius^2
end
utils.calcadelta = function(start, dest)
    return Coord(dest.x - start.x, dest.y - start.y)
end
utils.rect_of_triangle = function(coord1, coord2, coord3)
    local x = coord1.x <= coord2.x and coord1.x <= coord3.x and coord1.x or coord2.x <= coord1.x and coord2.x <= coord3.x and coord2.x or coord3.x <= coord2.x and coord3.x <= coord1.x and coord3.x
    local y = coord1.y <= coord2.y and coord1.y <= coord3.y and coord1.y or coord2.y <= coord1.y and coord2.y <= coord3.y and coord2.y or coord3.y <= coord2.y and coord3.y <= coord1.y and coord3.y
    local x2 = coord1.x >= coord2.x and coord1.x >= coord3.x and coord1.x or coord2.x >= coord1.x and coord2.x >= coord3.x and coord2.x or coord3.x >= coord2.x and coord3.x >= coord1.x and coord3.x
    local y2 = coord1.y >= coord2.y and coord1.y >= coord3.y and coord1.y or coord2.y >= coord1.y and coord2.y >= coord3.y and coord2.y or coord3.y >= coord2.y and coord3.y >= coord1.y and coord3.y
    return {
    x1 = x,
    y1 = y,
    x2 = x2 - x,
    y2 = y2 - y
    }
end
utils.pixel = function(x, y, color)
    local xdest = x < screen[1] and x + 1 or x - 1
    renderer.line(x, y, xdest, y, color.r, color.g, color.b, color.a)
end
utils.rect_outline = function(coord, size, color, thickness)
    local thickness = thickness or 1
    for j=1, 4, 1 do
        renderer.line(coord.x, coord.y, coord.x + size.x, coord.y, color.r, color.g, color.b, color.a)
        renderer.line(coord.x, coord.y + size.y, coord.x + size.x, coord.y + size.y, color.r, color.g, color.b, color.a)
        renderer.line(coord.x, coord.y, coord.x, coord.y + size.y, color.r, color.g, color.b, color.a)
        renderer.line(coord.x + size.x, coord.y, coord.x + size.x, coord.y + size.y, color.r, color.g, color.b, color.a)
        if thickness > 1 then
            for i=1, thickness, 1 do
                renderer.line(coord.x + i, coord.y + i, coord.x + size.x - i, coord.y + i, color.r, color.g, color.b, color.a)
                renderer.line(coord.x + i, coord.y + size.y - i, coord.x + size.x - i, coord.y + size.y - i, color.r, color.g, color.b, color.a)
                renderer.line(coord.x + i, coord.y + i, coord.x + i, coord.y + size.y - i, color.r, color.g, color.b, color.a)
                renderer.line(coord.x + size.x - i, coord.y + i, coord.x + size.x - i, coord.y + size.y - i, color.r, color.g, color.b, color.a)
            end
        end
    end
end
utils.triangle_outline = function(coord1, coord2, coord3, color, thickness)
    local thickness = thickness or 1
    for j=1, 4, 1 do
        renderer.line(coord1.x, coord1.y, coord2.x, coord2.y, color.r, color.g, color.b, color.a)
        renderer.line(coord2.x, coord2.y, coord3.x, coord3.y, color.r, color.g, color.b, color.a)
        renderer.line(coord3.x, coord3.y, coord1.x, coord1.y, color.r, color.g, color.b, color.a)
        if thickness > 1 then
            for i=1, thickness, 1 do
                renderer.line(coord1.x + i*2, coord1.y - i, coord2.x, coord2.y + i, color.r, color.g, color.b, color.a)
                renderer.line(coord2.x, coord2.y + i, coord3.x - i*2, coord3.y - i, color.r, color.g, color.b, color.a)
                renderer.line(coord3.x- i*2, coord3.y - i, coord1.x + i*2, coord1.y - i, color.r, color.g, color.b, color.a)
            end
        end
    end
end
--region @main
function better_renderer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    if ui.is_menu_open() then
        global.old_cursor_pos = global.cursor_pos
        global.cursor_pos = Coord(ui.mouse_position())
        global.oldclicked = global.clicked
        global.delta = global.old_cursor_pos ~= nil and utils.calcadelta(global.old_cursor_pos, global.cursor_pos) or Coord(0, 0)
        global.clicked = client.key_state(0x01)
        global.firstclick = not global.oldclicked and global.clicked
    end
    return o
end
function better_renderer:drag(hover)
    dragable[self.id] = dragable[self.id] or {}
    dragable[self.id].current_vec = dragable[self.id].current_vec or self.coord
    dragable[self.id].drags = true
    dragable[self.id].hover = hover or false
    dragable[self.id].inrange = self.type == "rect" and utils.in_range_rect(global.cursor_pos, self.coord, self.size) or self.type == "triangle" and utils.in_range_triangle(global.cursor_pos, dragable[self.id].current_vec) or self.type == "circle" and utils.in_range_circle(global.cursor_pos, dragable[self.id].current_vec, self.radius)
    dragable[self.id].clicked = global.clicked and dragable[self.id].inrange or false
    dragable[self.id].firstclick = global.firstclick and dragable[self.id].inrange or false
    dragable[self.id].absolute = dragable[self.id].absolute or false
end
function better_renderer:rectangle(id, coord, size, color)
    if dragable[id] ~= nil then
        if dragable[id].drags == true and ui.is_menu_open() then
            if dragable[id].firstclick and dragable[id].clicked or dragable[id].absolute then
                client.exec("-attack")
                if dragable[id].inrange or dragable[id].absolute then
                    dragable[id].absolute = global.clicked
                    dragable[id].current_vec = utils.sumcoord(dragable[id].current_vec, global.delta)
                end
            end
        end
        renderer.rectangle(dragable[id].current_vec.x, dragable[id].current_vec.y, size.x, size.y, color.r, color.g, color.b, color.a)
    else
        renderer.rectangle(coord.x, coord.y, size.x, size.y, color.r, color.g, color.b, color.a)
    end
    return setmetatable({type = "rect", id = id, coord = coord, size = size,}, better_renderer_mt)
end
function better_renderer:rectangle_outline(id, coord, size, color, thickness)
    if dragable[id] ~= nil then
        if dragable[id].drags == true and ui.is_menu_open() then
            if dragable[id].firstclick and dragable[id].clicked or dragable[id].absolute then
                client.exec("-attack")
                if dragable[id].inrange or dragable[id].absolute then
                    dragable[id].absolute = global.clicked
                    dragable[id].current_vec = utils.sumcoord(dragable[id].current_vec, global.delta)
                end
            end
        end
        utils.rect_outline(dragable[id].current_vec, size, color, thickness)
    else
        utils.rect_outline(coord, size, color, thickness)
    end
    return setmetatable({type = "rect", id = id, coord = coord, size = size,}, better_renderer_mt)
end
function better_renderer:blur(id, coord, size, alpha, amount)
    if dragable[id] ~= nil then
        if dragable[id].drags == true and ui.is_menu_open() then
            if dragable[id].firstclick and dragable[id].clicked or dragable[id].absolute then
                client.exec("-attack")
                if dragable[id].inrange or dragable[id].absolute then
                    dragable[id].absolute = global.clicked
                    dragable[id].current_vec = utils.sumcoord(dragable[id].current_vec, global.delta)
                end
            end
        end
        renderer.blur(dragable[id].current_vec.x, dragable[id].current_vec.y, size.x, size.y, alpha, amount)
    else
        renderer.blur(coord.x, coord.y, size.x, size.y, alpha, amount)
    end
    return setmetatable(better_renderer_mt, {type = "rect", id = id, coord = coord, size = size})
end
function better_renderer:triangle(id, coord1, coord2, coord3, color, thickness)
    if dragable[id] ~= nil then
        if dragable[id].drags == true and ui.is_menu_open() then
            if dragable[id].firstclick and dragable[id].clicked or dragable[id].absolute then
                client.exec("-attack")
                if dragable[id].inrange or dragable[id].absolute then
                    dragable[id].absolute = global.clicked
                    dragable[id].current_vec = {utils.sumcoord(dragable[id].current_vec[1], global.delta), utils.sumcoord(dragable[id].current_vec[2], global.delta), utils.sumcoord(dragable[id].current_vec[3], global.delta)}
                end
            end
        end
        renderer.triangle(dragable[id].current_vec[1].x, dragable[id].current_vec[1].y, dragable[id].current_vec[2].x, dragable[id].current_vec[2].y, dragable[id].current_vec[3].x, dragable[id].current_vec[3].y, color.r, color.g, color.b, color.a, thickness)
    else
        renderer.triangle(coord1.x, coord1.y, coord2.x, coord2.y, coord3.x, coord3.y, color.r, color.g, color.b, color.a, thickness)
    end
    return setmetatable({type = "triangle", id = id, coord = {coord1, coord2, coord3}}, better_renderer_mt)
end
function better_renderer:triangle_outline(id, coord1, coord2, coord3, color)
    if dragable[id] ~= nil then
        if dragable[id].drags == true and ui.is_menu_open() then
            if dragable[id].firstclick and dragable[id].clicked or dragable[id].absolute then
                client.exec("-attack")
                if dragable[id].inrange or dragable[id].absolute then
                    dragable[id].absolute = global.clicked
                    dragable[id].current_vec = {utils.sumcoord(dragable[id].current_vec[1], global.delta), utils.sumcoord(dragable[id].current_vec[2], global.delta), utils.sumcoord(dragable[id].current_vec[3], global.delta)}
                end
            end
        end
        utils.triangle_outline(dragable[id].current_vec[1], dragable[id].current_vec[2], dragable[id].current_vec[3], color)
    else
        utils.triangle_outline(coord1, coord2, coord3, color)
    end
    return setmetatable({type = "triangle", id = id, coord = {coord1, coord2, coord3}}, better_renderer_mt)
end
function better_renderer:circle(id, coord, color, radius, start_degrees, percentage)
    if dragable[id] ~= nil then
        if dragable[id].drags == true and ui.is_menu_open() then
            if dragable[id].firstclick and dragable[id].clicked or dragable[id].absolute then
                client.exec("-attack")
                if dragable[id].inrange or dragable[id].absolute then
                    dragable[id].absolute = global.clicked
                    dragable[id].current_vec = Coord(dragable[id].current_vec.x + global.delta.x, dragable[id].current_vec.y + global.delta.y)
                end
            end
        end
        renderer.circle(dragable[id].current_vec.x, dragable[id].current_vec.y, color.r, color.g, color.b, color.a, radius, start_degrees, percentage)
    else
        renderer.circle(coord.x, coord.y, color.r, color.g, color.b, color.a, radius, start_degrees, percentage)
    end
    return setmetatable({type = "circle", id = id, coord = coord, radius = radius}, better_renderer_mt)
end
function better_renderer:circle_outline(id, coord, color, radius, start_degrees, percentage, thickness)
    if dragable[id] ~= nil then
        if dragable[id].drags == true and ui.is_menu_open() then
            if dragable[id].firstclick and dragable[id].clicked or dragable[id].absolute then
                client.exec("-attack")
                if dragable[id].inrange or dragable[id].absolute then
                    dragable[id].absolute = global.clicked
                    dragable[id].current_vec = Coord(dragable[id].current_vec.x + global.delta.x, dragable[id].current_vec.y + global.delta.y)
                end
            end
        end
        renderer.circle_outline(dragable[id].current_vec.x, dragable[id].current_vec.y, color.r, color.g, color.b, color.a, radius, start_degrees, percentage, thickness)
    else
        renderer.circle_outline(coord.x, coord.y, color.r, color.g, color.b, color.a, radius, start_degrees, percentage, thickness)
    end
    return setmetatable({type = "circle", id = id, coord = coord, radius = radius}, better_renderer_mt)
end