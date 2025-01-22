local inspect = require("gamesense/inspect")
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
render.text_size = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 79, "bool(__thiscall*)(void*, unsigned long, const wchar_t*, int&, int&)")
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
local utils, better_renderer, global, dragable, fonts = {}, {}, {}, {}, {}
local better_renderer_mt = {__index = better_renderer}
utils.get_text_size = function(font, text)
    local height_t, width_t = ffi.new("int[1]"), ffi.new("int[1]")
    local text_len = string.len(text)
    local w_text = ffi.new(ffi.typeof("wchar_t[$]", text_len), string.byte(text, 1, text_len))
    render.text_size(font, w_text, width_t, height_t)
    return Coord(width_t[0], height_t[0])
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
utils.pixel = function(x, y, color)
    local xdest = x < screen[1] and x + 1 or x - 1
    renderer.line(x, y, xdest, y, color.r, color.g, color.b, color.a)
end
utils.rect_outline = function(coord, size, color, thickness)
    render.set_col(color.r, color.g, color.b, color.a)
    render.outlined_rect(coord.x, coord.y, coord.x + size.x, coord.y + size.y)
    local thickness = thickness or 1
    if thickness > 1 then
        for i=1, thickness, 1 do
            render.outlined_rect(coord.x + i, coord.y + i, coord.x + size.x - i, coord.y + size.y - i)
        end
    end
end
utils.rect_filled = function(coord, size, color)
    render.set_col(color.r, color.g, color.b, color.a)
    render.filled_rect(coord.x, coord.y, coord.x + size.x, coord.y + size.y)
end
utils.rect_filled_fade = function(coord, size, color, alpha0, alpha1, horizontal)
    local horizontal = horizontal or false
    render.set_col(color.r, color.g, color.b, color.a)
    render.filled_rect_fade(coord.x, coord.y, coord.x + size.x, coord.y + size.y, alpha0, alpha1, horizontal)
end
utils.rect_fast_fade = function(coord, size, startend, color, alpha0, alpha1, horizontal)
    local horizontal = horizontal or false
    render.set_col(color.r, color.g, color.b, color.a)
    render.filled_fast_fade(coord.x, coord.y, coord.x + size.x, coord.y + size.y, startend.x, startend.y, alpha0, alpha1, horizontal)
end
utils.triangle_outline = function(coord1, coord2, coord3, color, thickness)
    local thickness = thickness or 1
    local x = ffi.new("int[3]", coord1.x, coord2.x, coord3.x)
    local y = ffi.new("int[3]", coord1.y, coord2.y, coord3.y)
    render.set_col(color.r, color.g, color.b, color.a)
    render.poly_line(x, y, 3)
    if thickness > 1 then
        for i=1, thickness, 1 do
            local xi = ffi.new("int[3]", coord1.x + i*2, coord2.x, coord3.x - i*2)
            local yi = ffi.new("int[3]", coord1.y - i, coord2.y + i, coord3.y - i)
            render.poly_line(xi, yi, 3)
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
    dragable[self.id].inrange = self.type == "rect" and utils.in_range_rect(global.cursor_pos, dragable[self.id].current_vec, self.size) or self.type == "triangle" and utils.in_range_triangle(global.cursor_pos, dragable[self.id].current_vec) or self.type == "circle" and utils.in_range_circle(global.cursor_pos, dragable[self.id].current_vec, self.radius)
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
        utils.rect_filled(dragable[id].current_vec, size, color)
    else
        utils.rect_filled(coord, size, color)
    end
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
        utils.rect_filled_fade(dragable[id].current_vec, size, color, alpha0, alpha1, horizontal)
    else
        utils.rect_filled_fade(coord, size, color, alpha0, alpha1, horizontal)
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
        utils.triangle_outline(dragable[id].current_vec[1], dragable[id].current_vec[2], dragable[id].current_vec[3], color, thickness)
    else
        utils.triangle_outline(coord1, coord2, coord3, color, thickness)
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
function better_renderer:add_font(id, fontname, height, width, blur, flags)
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
    render.set_glyph(font_handler, fontname, height, width, 0, 0, fflags, 0, 0)
    fonts[id] = setmetatable({id = id, font_handler = font_handler, fontname = fontname, size = Coord(width, height), blur = blur, flags = fflags}, better_renderer_mt)
    return fonts[id]
end
function better_renderer:draw_text(coord, color, text)
    local text_len = string.len(text)
    local w_text = ffi.new(ffi.typeof("wchar_t[$]", text_len), string.byte(text, 1, text_len))
    render.font_col(color.r, color.g, color.b, color.a)
    render.text_pos(coord.x, coord.y)
    render.set_font(self.font_handler)
    render.draw_text(w_text, text_len, 0)
end
function better_renderer:text_size(text)
    if fonts.size == nil then fonts.size = {} end
    if fonts.size[self.id]  == nil then fonts.size[self.id]  = {} end
    if fonts.size[self.id][text] ~= nil then return fonts.size[self.id][text] end
    fonts.size[self.id][text] = utils.get_text_size(self.font_handler, text)
    return fonts.size[self.id][text]
end