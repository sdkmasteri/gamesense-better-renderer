--local inspect = require("gamesense/inspect")
local ffi = require("ffi")
--region @vtable
local render = {}
render.set_col = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 15, "void(__thiscall*)(void*, int, int, int, int)")
render.filled_rect = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 16, "void(__thiscall*)(void*, int, int, int, int)")
render.outlined_rect = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 18, "void(__thiscall*)(void*, int, int, int, int)")
render.filled_rect_fade = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 123, "void(__thiscall*)(void*, int, int, int, int, unsigned int, unsigned int, bool)")
render.filled_fast_fade = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 122, "bool(__thiscall*)(void*, int, int, int, int, int, int, unsigned int, unsigned int, bool)")
render.line = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 19, "void(__thiscall*)(void*, int, int, int, int)")
render.poly_line = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 20, "void(__thiscall*)(void*, int*, int*, int)")
render.create_font = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 71, "unsigned int(__thiscall*)(void*)")
render.font_col = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 25, "void(__thiscall*)(void*, int, int, int, int)")
render.text_pos = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 26, "void(__thiscall*)(void*, int, int)")
render.set_glyph = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 72, "bool(__thiscall*)(void*, unsigned long, const char*, int, int, int, int, unsigned long, int, int)")
render.set_font = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 23, "void(__thiscall*)(void*, unsigned int)")
render.draw_text = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 28, "void(__thiscall*)(void*, const wchar_t*, int, int)")
render.draw_textcol = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 163, "void(__stdcall*)(void*, unsigned int, int, int, int, int, int, int, const char*, ...)")
render.text_size = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 79, "bool(__stdcall*)(void*, unsigned long, const wchar_t*, int&, int&)")
render.text_len = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 166, "int(__cdecl*)(void*, unsigned long, const char*, ...)")
render.text_height =  vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 165, "int(__cdecl*)(void*, unsigned long, int, int&, const char*, ...)")
render.circle_outline = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 103, "void(__thiscall*)(void*, int, int, int, int)")
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
local utils, better_renderer, global, dragable, fonts = {}, {}, {}, {}, {}
local better_renderer_mt = {__index = better_renderer}
utils.lerp = function(start, end_pos, time, ampl)
    if start == end_pos then return end_pos end
    ampl = ampl or 1/globals.frametime()
    local frametime = globals.frametime() * ampl
    time = time * frametime
    local val = start + (end_pos - start) * time
    if(math.abs(val - end_pos) < 0.01) then return end_pos end
    return val 
end
utils.get_text_size = function(font, ...)
    local height = ffi.new("int[1]")
    local weight = render.text_len(font, ...)
    render.text_height(font, weight, height, ...)
    return Coord(weight, height[0])
end
utils.set_draw_col = function(color)
    render.set_col(color.r, color.b, color.g, color.a)
end
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
utils.rect_outline = function(coord, size, color, thickness)
    utils.set_draw_col(color)
    render.outlined_rect(coord.x, coord.y, coord.x + size.x, coord.y + size.y)
    local thickness = thickness or 1
    if thickness > 1 then
        for i=1, thickness, 1 do
            render.outlined_rect(coord.x + i, coord.y + i, coord.x + size.x - i, coord.y + size.y - i)
        end
    end
end
utils.rect_filled = function(coord, size, color)
    utils.set_draw_col(color)
    render.filled_rect(coord.x, coord.y, coord.x + size.x, coord.y + size.y)
end
utils.rect_filled_fade = function(coord, size, color, alpha0, alpha1, horizontal)
    local horizontal = horizontal or false
    utils.set_draw_col(color)
    render.filled_rect_fade(coord.x, coord.y, coord.x + size.x, coord.y + size.y, alpha0, alpha1, horizontal)
end
utils.rect_fast_fade = function(coord, size, startend, color, alpha0, alpha1, horizontal)
    local horizontal = horizontal or false
    utils.set_draw_col(color)
    render.filled_fast_fade(coord.x, coord.y, coord.x + size.x, coord.y + size.y, startend.x, startend.y, alpha0, alpha1, horizontal)
end
utils.triangle_outline = function(coord1, coord2, coord3, color, thickness)
    local thickness = thickness or 1
    local x = ffi.new("int[3]", coord1.x, coord2.x, coord3.x)
    local y = ffi.new("int[3]", coord1.y, coord2.y, coord3.y)
    utils.set_draw_col(color)
    render.poly_line(x, y, 3)
    if thickness > 1 then
        for i=1, thickness, 1 do
            local xi = ffi.new("int[3]", coord1.x + i*2, coord2.x, coord3.x - i*2)
            local yi = ffi.new("int[3]", coord1.y - i, coord2.y + i, coord3.y - i)
            render.poly_line(xi, yi, 3)
        end
    end
end
utils.circle_outline = function(coord, color, radius, segments, thickness)
    local thickness = thickness or 1
    utils.set_draw_col(color)
    render.circle_outline(coord.x, coord.y, radius, segments)
    if thickness > 1 then
        for i=1, thickness, 1 do
            if thickness > radius then return end
            render.circle_outline(coord.x, coord.y, radius - i, segments)
        end
    end
end
utils.rounded_rectangle = function(x, y, w, h, r, g, b, a, radius)
    y = y + radius
    local data_circle = {
        {x + radius, y, 180},
        {x + w - radius, y, 90},
        {x + radius, y + h - radius * 2, 270},
        {x + w - radius, y + h - radius * 2, 0},
    }
    local data = {
        {x + radius, y, w - radius * 2, h - radius * 2},
        {x + radius, y - radius, w - radius * 2, radius},
        {x + radius, y + h - radius * 2, w - radius * 2, radius},
        {x, y, radius, h - radius * 2},
        {x + w - radius, y, radius, h - radius * 2},
    }
    for _, data in next, data_circle do
        renderer.circle(data[1], data[2], r, g, b, a, radius, data[3], 0.25)
    end
    for _, data in next, data do
        renderer.rectangle(data[1], data[2], data[3], data[4], r, g, b, a)
    end
end
utils.outlined_rounded_rectangle = function (x, y, w, h, r, g, b, a, radius, thickness)
    y = y + radius
    local data_circle = {
        {x + radius, y, 180},
        {x + w - radius, y, 270},
        {x + radius, y + h - radius * 2, 90},
        {x + w - radius, y + h - radius * 2, 0},
    }
    local data = {
        {x + radius, y - radius, w - radius * 2, thickness},
        {x + radius, y + h - radius - thickness, w - radius * 2, thickness},
        {x, y, thickness, h - radius * 2},
        {x + w - thickness, y, thickness, h - radius * 2},
    }
    for _, data in next, data_circle do
        renderer.circle_outline(data[1], data[2], r, g, b, a, radius, data[3], 0.25, thickness)
    end
    for _, data in next, data do
        renderer.rectangle(data[1], data[2], data[3], data[4], r, g, b, a)
    end
end
--region @main
function better_renderer.new()
    if ui.is_menu_open() then
        global.old_cursor_pos = global.cursor_pos
        global.cursor_pos = Coord(ui.mouse_position())
        global.oldclicked = global.clicked
        global.delta = global.old_cursor_pos ~= nil and utils.calcadelta(global.old_cursor_pos, global.cursor_pos) or Coord(0, 0)
        global.clicked = client.key_state(0x01)
        global.firstclick = not global.oldclicked and global.clicked
    end
    return setmetatable({}, better_renderer_mt)
end
function better_renderer:drag(hover)
    dragable[self.id] = dragable[self.id] or {}
    dragable[self.id].current_vec = dragable[self.id].current_vec or self.coord
    if self.centred then dragable[self.id].current_centred = Coord(dragable[self.id].current_vec.x - self.size.x*0.5, dragable[self.id].current_vec.y - self.size.y*0.5) end
    dragable[self.id].drags = true
    dragable[self.id].hover = hover or false
    dragable[self.id].inrange = (self.type == "rect" or self.type == "text") and utils.in_range_rect(global.cursor_pos, self.centred and dragable[self.id].current_centred or dragable[self.id].current_vec, self.size) or self.type == "triangle" and utils.in_range_triangle(global.cursor_pos, dragable[self.id].current_vec) or self.type == "circle" and utils.in_range_circle(global.cursor_pos, dragable[self.id].current_vec, self.radius)
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
        coord = dragable[id].current_vec
    end
    utils.rect_filled(coord, size, color)
    return setmetatable({type = "rect", id = id, coord = coord, size = size,}, better_renderer_mt)
end
function better_renderer:rectangle_fade(id, coord, size, color, alpha0, alpha1, horizontal)
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
        coord = dragable[id].current_vec
    end
    utils.rect_filled_fade(coord, size, color, alpha0, alpha1, horizontal)
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
        coord = dragable[id].current_vec
    end
    utils.rect_outline(coord, size, color, thickness)
    return setmetatable({type = "rect", id = id, coord = coord, size = size,}, better_renderer_mt)
end
function better_renderer:rectangle_round(id, coord, size, color, radius)
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
        coord = dragable[id].current_vec
    end
    utils.rounded_rectangle(coord.x, coord.y, size.x, size.y, color.r, color.g, color.b, color.a, radius)
    return setmetatable({type = "rect", id = id, coord = coord, size = size,}, better_renderer_mt)
end
function better_renderer:rectangle_outline_round(id, coord, size, color, radius, thickness)
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
        coord = dragable[id].current_vec
    end
    utils.outlined_rounded_rectangle(coord.x, coord.y, size.x, size.y, color.r, color.g, color.b, color.a, radius, thickness)
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
        coord = dragable[id].current_vec
    end
    renderer.blur(coord.x, coord.y, size.x, size.y, alpha, amount)
    return setmetatable(better_renderer_mt, {type = "rect", id = id, coord = coord, size = size})
end
function better_renderer:triangle(id, coord1, coord2, coord3, color)
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
        coord = dragable[id].current_vec
    end
    renderer.triangle(coord1.x, coord1.y, coord2.x, coord2.y, coord3.x, coord3.y, color.r, color.g, color.b, color.a)
    return setmetatable({type = "triangle", id = id, coord = {coord1, coord2, coord3}}, better_renderer_mt)
end
function better_renderer:triangle_outline(id, coord1, coord2, coord3, color, thickness)
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
        coord = dragable[id].current_vec
    end
    utils.triangle_outline(coord1, coord2, coord3, color, thickness)
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
        coord = dragable[id].current_vec
    end
    renderer.circle(coord.x, coord.y, color.r, color.g, color.b, color.a, radius, start_degrees, percentage)
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
        coord = dragable[id].current_vec
    end
    renderer.circle_outline(coord.x, coord.y, color.r, color.g, color.b, color.a, radius, start_degrees, percentage, thickness)
    return setmetatable({type = "circle", id = id, coord = coord, radius = radius}, better_renderer_mt)
end
function better_renderer:circle_fade(id, coord, color, alpha0, alpha1, radius, start_degrees, percentage, fade_speed)
    for i=radius, 1, -1 do
        alpha0 = alpha0 > alpha1 and math.floor(utils.lerp(alpha0, alpha1, fade_speed)) or math.ceil(utils.lerp(alpha0, alpha1, fade_speed))
        renderer.circle_outline(coord.x, coord.y, color.r, color.g, color.b, alpha0, i, start_degrees, percentage, 1)
    end
    renderer.rectangle(coord.x-1, coord.x-1, 2, 2, color.r, color.g, color.b, alpha0)
end
function better_renderer:text(id, coord, color, flags, maxwidth, ...)
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
        coord = dragable[id].current_vec
    end
    renderer.text(coord.x, coord.y, color.r, color.g, color.b, color.a, flags, maxwidth, ...)
    return setmetatable({type = "text", id = id, coord = coord, size = Coord(renderer.measure_text(flags, ...)), centred = string.match(flags, "c")}, better_renderer_mt)
end
function better_renderer:add_font(fontname, height, width, blur, flags)
    local id = string.format("%s%d%d%d", fontname, height, width, blur)
    if fonts[id] ~= nil then return fonts[id] end
    if type(flags) ~= "number" and type(flags) ~= "table" then return client.error_log("flags must be number or table type") end
    local fflags = 0
    if type(flags) == "table" then 
        for _, v in pairs(flags) do
            fflags = fflags + v
        end
    else
        fflags = flags
    end
    local font_handler = render.create_font()
    render.set_glyph(font_handler, fontname, height, width, blur, 0, fflags, 0, 0)
    fonts[id] = setmetatable({id = id, font_handler = font_handler, fontname = fontname, size = Coord(width, height), blur = blur, flags = fflags}, better_renderer_mt)
    return fonts[id]
end
function better_renderer:draw_text(id, coord, color, ...)
    if not self.font_handler then return client.error_log(":draw_text() only avivable with :add_font() method. DID YOU MEAN :text()?") end
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
        coord = dragable[id].current_vec
    end
    render.draw_textcol(self.font_handler, coord.x, coord.y, color.r, color.g, color.b, color.a, ...)
    return setmetatable({type = "text", id = id, coord = coord, size = utils.get_text_size(self.font_handler, ...)}, better_renderer_mt)
end
function better_renderer:text_size(...)
    return utils.get_text_size(self.font_handler, ...)
end

return {
    color = Color,
    coord = Coord,
    new = better_renderer.new
}
