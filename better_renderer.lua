local inspect = require("gamesense/inspect")
local ffi = require("ffi")
local vector = require("vector")
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
local utils, better_renderer, global, dragable, fonts = {}, {}, {}, {}, {}
local better_renderer_mt = {__index = better_renderer}
local g = Color(10, 10, 10)
local a = Color(60, 60, 60)
local b = Color(40, 40, 40)
local l = Color(20, 20, 20)
local g1 = Color(100, 150, 200) 
local g2 = Color(180, 100, 160)
local g3 = Color(180, 230, 100)
local B="\x14\x14\x14\xFF"
local C="\x0c\x0c\x0c\xFF"
local skt = renderer.load_rgba(table.concat({B,B,B,C,B,C,B,C,B,C,B,B,B,C,B,C}),4,4)
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
    return vector(weight, height[0])
end
utils.set_draw_col = function(color)
    render.set_col(color.r, color.b, color.g, color.a)
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
utils.skeety = function(coord, size, gradient)
    renderer.rectangle(coord.x, coord.y, size.x, size.y, g.r, g.g, g.b, g.a)
    renderer.rectangle(coord.x + 1, coord.y + 1, size.x - 2, size.y - 2, a.r, a.g, a.b, a.a)
    renderer.rectangle(coord.x + 2, coord.y + 2, size.x - 4, size.y - 4, b.r, b.g, b.b, b.a)
    renderer.rectangle(coord.x + 4, coord.y + 4, size.x - 8, size.y - 8, a.r, a.g, a.b, a.a)
    renderer.texture(skt, coord.x + 5, coord.y + 5, size.x - 10, size.y - 10, 255, 255, 255, 255, "t")
    if gradient then
        renderer.gradient(coord.x + 6, coord.y + 6, size.x/2, 1, g1.r, g1.g, g1.b, g1.a, g2.r, g2.g, g2.b, g2.a, true)
        renderer.gradient(coord.x + 6 + size.x/2, coord.y + 6, size.x/2 - 12, 1, g2.r, g2.g, g2.b, 255, g3.r, g3.g, g3.b, g3.a, true)
    end
end
global = {}
utils.global_handler = function()
    if ui.is_menu_open() then
        global.old_cursor_pos = global.cursor_pos or vector(ui.mouse_position())
        global.cursor_pos = vector(ui.mouse_position())
        global.oldclicked = global.clicked
        global.delta =  global.cursor_pos - global.old_cursor_pos
        global.clicked = client.key_state(0x01)
        global.firstclick = not global.oldclicked and global.clicked
        global.on_menu = utils.in_range_rect(global.cursor_pos, vector(ui.menu_position()), vector(ui.menu_size()))
    end
end
--region @main
function better_renderer:rectangle(id, coord, size, color)
    local id = self.i..":"..id
    self[id] = self[id] or setmetatable({type = "rect", id = id, coord = coord, size = size}, better_renderer_mt)
    utils.rect_filled(self[id].coord, self[id].size, color)
    return self[id]
end
function better_renderer:rectangle_fade(id, coord, size, color, alpha0, alpha1, horizontal)
    local id = self.i..":"..id
    self[id] = setmetatable({type = "rect", id = id, coord = coord, size = size,}, better_renderer_mt)
    utils.rect_filled_fade(self[id].coord, self[id].size, color, alpha0, alpha1, horizontal)
    return self[id]
end
function better_renderer:rectangle_outline(id, coord, size, color, thickness)
    local id = self.i..":"..id
    self[id] = setmetatable({type = "rect", id = id, coord = coord, size = size,}, better_renderer_mt)
    utils.rect_outline(self[id].coord, self[id].size, color, thickness)
    return self[id]
end
function better_renderer:rectangle_round(id, coord, size, color, radius)
    local id = self.i..":"..id
    self[id] = setmetatable({type = "rect", id = id, coord = coord, size = size,}, better_renderer_mt)
    utils.rounded_rectangle(self[id].coord.x, self[id].coord.y, self[id].size.x, self[id].size.y, color.r, color.g, color.b, color.a, radius)
    return self[id]
end
function better_renderer:rectangle_outline_round(id, coord, size, color, radius, thickness)
    local id = self.i..":"..id
    self[id] = self[id] or setmetatable({type = "rect", id = id, coord = coord, size = size,}, better_renderer_mt)
    utils.outlined_rounded_rectangle(self[id].coord.x, self[id].coord.y, size.x, size.y, color.r, color.g, color.b, color.a, radius, thickness)
    return self[id]
end
function better_renderer:blur(id, coord, size, alpha, amount)
    local id = self.i..":"..id
    self[id] = setmetatable({type = "rect", id = id, coord = coord, size = size,}, better_renderer_mt)
    renderer.blur(self[id].coord.x, self[id].coord.y, self[id].size.x, self[id].size.y, alpha, amount)
    return self[id]
end
function better_renderer:skeety(id, coord, size, gradient)
    local id = self.i..":"..id
    self[id] = self[id] or setmetatable({type = "rect", id = id, coord = coord, size = size,}, better_renderer_mt)
    utils.skeety(self[id].coord, self[id].size, gradient)
    return self[id]
end
function better_renderer:triangle(id, coord1, coord2, coord3, color)
    local id = self.i..":"..id
    self[id] = self[id] or setmetatable({type = "triangle", id = id, coord = {coord1, coord2, coord3}}, better_renderer_mt)
    renderer.triangle(self[id].coord1.x, self[id].coord1.y, self[id].coord2.x, self[id].coord2.y, self[id].coord3.x, self[id].coord3.y, color.r, color.g, color.b, color.a)
    return self[id]
end
function better_renderer:triangle_outline(id, coord1, coord2, coord3, color, thickness)
    local id = self.i..":"..id
    self[id] = self[id] or setmetatable({type = "triangle", id = id, coord = {coord1, coord2, coord3}}, better_renderer_mt)
    utils.triangle_outline(self[id].coord1, self[id].coord2, self[id].coord3, color, thickness)
    return self[id]
end
function better_renderer:circle(id, coord, color, radius, start_degrees, percentage)
    local id = self.i..":"..id
    self[id] = self[id] or setmetatable({type = "circle", id = id, coord = coord, radius = radius}, better_renderer_mt)
    renderer.circle(self[id].coord.x, self[id].coord.y, color.r, color.g, color.b, color.a, radius, start_degrees, percentage)
    return self[id]
end
function better_renderer:circle_outline(id, coord, color, radius, start_degrees, percentage, thickness)
    local id = self.i..":"..id
    self[id] = self[id] or setmetatable({type = "circle", id = id, coord = coord, radius = radius}, better_renderer_mt)
    renderer.circle_outline(self[id].coord.x, self[id].coord.y, color.r, color.g, color.b, color.a, radius, start_degrees, percentage, thickness)
    return self[id]
end
function better_renderer:circle_fade(id, coord, color, radius, start_degrees, percentage, alpha0, alpha1, fade_speed)
    local id = self.i..":"..id
    self[id] = self[id] or setmetatable({type = "circle", id = id, coord = coord, radius = radius}, better_renderer_mt)
    for i=radius, 1, -1 do
        alpha0 = alpha0 > alpha1 and math.floor(utils.lerp(alpha0, alpha1, fade_speed)) or math.ceil(utils.lerp(alpha0, alpha1, fade_speed))
        renderer.circle_outline(self[id].coord.x, self[id].coord.y, color.r, color.g, color.b, alpha0, i, start_degrees, percentage, 1)
    end
    renderer.rectangle(self[id].coord.x-1, self[id].coord.x-1, 2, 2, color.r, color.g, color.b, alpha0)
    return self[id]
end
function better_renderer:text(id, coord, color, flags, maxwidth, ...)
    local id = self.i..":"..id
    self[id] = self[id] or setmetatable({type = "text", id = id, coord = coord, size = vector(renderer.measure_text(flags, ...)), centred = string.match(flags, "c")}, better_renderer_mt)
    renderer.text(self[id].coord.x, self[id].coord.y, color.r, color.g, color.b, color.a, flags, maxwidth, ...)
    return self[id]
end
function better_renderer:add_font(fontname, height, width, blur, flags)
    local id = self.i..":"..string.format("%s%d%d%d", fontname, height, width, blur)
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
    fonts[id] = setmetatable({id = id, font_handler = font_handler, fontname = fontname, size = vector(width, height), blur = blur, flags = fflags}, better_renderer_mt)
    return fonts[id]
end
function better_renderer:set_glyph(height, width, blur, flags, fontname)
    if not self.font_handler then return client.error_log(":set_glyph() only avivable after :add_font() method.") end
    if fonts[self.id].size == vector(width, height) and fonts[self.id].blur == blur and fonts[self.id].flags == flags then return end
    local fontname = fontname or self.fontname
    if type(flags) ~= "number" and type(flags) ~= "table" then return client.error_log("flags must be number or table type") end
    local fflags = 0
    if type(flags) == "table" then 
        for _, v in pairs(flags) do
            fflags = fflags + v
        end
    else
        fflags = flags
    end
    render.set_glyph(self.font_handler, fontname, height, width, blur, 0, fflags, 0, 0)
    fonts[self.id] = setmetatable({id = id, type = "font", font_handler = self.font_handler, fontname = fontname, size = vector(width, height), blur = blur, flags = fflags}, better_renderer_mt)
end
function better_renderer:draw_text(id, coord, color, ...)
    if not self.font_handler then return client.error_log(":draw_text() only avivable with :add_font() method. DID YOU MEAN :text()?") end
    local id = self.i..":"..id
    self[id] = self[id] or setmetatable({type = "text", id = id, coord = coord, size = utils.get_text_size(self.font_handler, ...)}, better_renderer_mt)
    render.draw_textcol(self.font_handler, self[id].coord.x, self[id].coord.y, color.r, color.g, color.b, color.a, ...)
    return self[id]
end
function better_renderer:text_size(...)
    return utils.get_text_size(self.font_handler, ...)
end
local dragableabs = {}
local donotattack = {}
function better_renderer:drag(enable, hover)
    if self.type == "font" then return end
    local current_centred = self.centred and vector(self.coord.x - self.size.x*0.5, self.coord.y - self.size.y*0.5) or nil
    local inrange = (self.type == "rect" or self.type == "text") and utils.in_range_rect(global.cursor_pos, self.centred and current_centred or self.coord, self.size) or self.type == "triangle" and utils.in_range_triangle(global.cursor_pos, self.coord) or self.type == "circle" and utils.in_range_circle(global.cursor_pos, self.coord, self.radius)
    donotattack[self.id] = inrange or dragableabs[self.id]
    local clicked = global.clicked and inrange
    local firstclick = global.firstclick and inrange
    if enable and ui.is_menu_open() and not global.on_menu and not global.in_scaling then
        if firstclick and clicked or dragableabs[self.id] then
            if inrange or dragableabs[self.id] then
                dragableabs[self.id] = global.clicked
                self.coord = self.coord + global.delta
            end
        end
    end
end
global.in_scaling = false
local scaleabs = {}
function better_renderer:scale(vertical, horizontal, adding, minsize)
    donotattack[self.id] = utils.in_range_rect(global.cursor_pos, self.coord, self.size)
    local inrange = utils.in_range_rect(global.cursor_pos, self.coord + self.size - vector(adding, adding), vector(adding, adding))
    global.in_scaling = inrange
    if inrange and global.firstclick or scaleabs[self.id] then
        scaleabs[self.id] = global.clicked
        local sized = self.size + global.delta
        if vertical and sized.y >= minsize.y and global.cursor_pos.y >= self.coord.y then
            self.size.y = sized.y
        end
        if horizontal and sized.x >= minsize.x and global.cursor_pos.x >= self.coord.x then
            self.size.x = sized.x
        end
    end
end
utils.deattack = function(cmd)
    local lplayer = entity.get_local_player()
    if not lplayer or not entity.is_alive(lplayer) then return end
    for _, v in pairs(donotattack) do
        if v then cmd.in_attack = not v end
    end
end
local i = 0
function better_renderer.new()
    i = i + 1
    client.set_event_callback("paint_ui", utils.global_handler)
    client.set_event_callback("setup_command", utils.deattack)
    return setmetatable({i = i}, better_renderer_mt)
end

return setmetatable({color = Color, new = better_renderer.new}, {
    __call = function (slot0)
        return better_renderer.new()
    end
})