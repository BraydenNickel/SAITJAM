-- Builds an .aseprite from a manifest of frame PNGs.
-- Usage: Aseprite -b --script-param manifest=<file> --script-param out=<file.aseprite> --script frames_to_aseprite.lua
-- Manifest lines:  frame <png path> <duration ms>   |   tag <name> <from> <to>   (frames are 1-based)
local frames, tags = {}, {}
for line in io.lines(app.params["manifest"]) do
  local kind, a, b, c = line:match("^(%S+)%s+(%S+)%s+(%S+)%s*(%S*)")
  if kind == "frame" then
    frames[#frames + 1] = { path = a, ms = tonumber(b) }
  elseif kind == "tag" then
    tags[#tags + 1] = { name = a, from = tonumber(b), to = tonumber(c) }
  end
end
local first = Image{ fromFile = frames[1].path }
local spr = Sprite(first.width, first.height, ColorMode.RGB)
spr.layers[1].name = "Art"
for i, f in ipairs(frames) do
  if i > 1 then spr:newEmptyFrame() end
  spr.frames[i].duration = f.ms / 1000
  spr:newCel(spr.layers[1], i, Image{ fromFile = f.path }, Point(0, 0))
end
for _, t in ipairs(tags) do
  local tag = spr:newTag(t.from, t.to)
  tag.name = t.name
end
spr:saveAs(app.params["out"])
print("saved " .. #spr.frames .. " frames, " .. #spr.tags .. " tags -> " .. app.params["out"])
