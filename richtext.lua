--[[
  The MIT License (MIT)

  Copyright (c) 2024 iamcheeseman

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
]]

local love = require("love")
local love_graphics_newTextBatch = love.graphics.newTextBatch or love.graphics.newText

local RichText = {}

---@class RichTextEffectGroup
local EffectGroup = {}
EffectGroup.__index = EffectGroup

---@class RichTextEffectInfo
---@field public char string the character you're running your effect on.
---@field public index integer the index of your char.
---@field public length integer the length of the substring your effect is being applied to.
---@alias RichTextEffectFunction fun(text:RichText,args:table<string,number>,info:RichTextEffectInfo)

---@param name string
---@param fn RichTextEffectFunction
function EffectGroup:addEffect(name, fn)
  if self.effects[name] then
    error("Effect '" .. name .. "' already exists.")
  end

  self.effects[name] = fn
end

---@param name string
---@return RichTextEffectInfo?
function EffectGroup:getEffect(name)
  return self.effects[name]
end

---@param name string
function EffectGroup:removeEffect(name)
  self.effects[name] = nil
end

---@package
function EffectGroup:_()
  self.effects = {}
end

---@class RichText
local RichTextObject = {}
RichTextObject.__index = RichTextObject

function RichText.newEffectGroup()
  local result = setmetatable({}, EffectGroup)
  result:_()
  return result
end

local defaultEffectGroup = RichText.newEffectGroup()

---@param name string
---@param fn RichTextEffectFunction
function RichText.addEffect(name, fn)
  return defaultEffectGroup:addEffect(name, fn)
end

---@param name string
function RichText.removeEffect(name)
  return defaultEffectGroup:removeEffect(name)
end

---@param format string
function RichText.parse(format)
  local tformat = {}

  for text, match in format:gmatch("([^{]*)({.-})") do
    if text then
      table.insert(tformat, text)
    end
    if match then
      local inner = match:sub(2, -2)
      local args = {}
      local name = inner:match("^[/%a]+")
      args[1] = name
      for k, v in inner:gmatch("(%w-)=([%w%.%-]+)") do
        local numval = tonumber(v)
        if not numval then
          error("Invalid effect arg '" .. k .. "'. Numbers are the only supported type.")
        end
        args[k] = numval
      end
      table.insert(tformat, args)
    end
  end

  return tformat
end

---@param font love.Font
---@param format string|table
---@param effectGroup RichTextEffectGroup?
function RichText.new(font, format, effectGroup)
  local instance = setmetatable({}, RichTextObject)
  instance:_(font, format, effectGroup)
  return instance
end

---@param font love.Font
---@param format string|table
---@param effectGroup RichTextEffectGroup?
function RichTextObject:_(font, format, effectGroup)
  self.font = font
  if type(format) == "table" then
    self.format = format
  elseif type(format) == "string" then
    self.format = RichText.parse(format)
  end
  self.effectGroup = effectGroup or defaultEffectGroup
  self.text = love_graphics_newTextBatch(font)
  self:update()
end

---@param r number
---@param g number
---@param b number
---@param a number?
function RichTextObject:setColor(r, g, b, a)
  self.color = {r, g, b, a}
end

function RichTextObject:getColor()
  return unpack(self.color)
end

function RichTextObject:setPosition(x, y)
  self.charx = x
  self.chary = y
end

function RichTextObject:getPosition()
  return self.charx, self.chary
end

function RichTextObject:setScale(x, y)
  self.scalex = x
  self.scaley = y
end

function RichTextObject:getScale()
  return self.scalex, self.scaley
end

function RichTextObject:setSkew(x, y)
  self.skewx = x
  self.skewy = y
end

function RichTextObject:getSkew()
  return self.skewx, self.skewy
end

function RichTextObject:setRotation(rotation)
  self.rotation = rotation
end

function RichTextObject:getRotation()
  return self.rotation
end

function RichTextObject:update()
  self.text:clear()

  local currentEffects = {}

  local x = 0

  self.rawText = ""

  for _, effectOrStr in ipairs(self.format) do
    if type(effectOrStr) == "string" then
      self.rawText = self.rawText .. effectOrStr
      for i=1, #effectOrStr do
        local char = effectOrStr:sub(i, i)
        self.charx = 0
        self.chary = 0
        self.scalex = 1
        self.scaley = 1
        self.skewx = 0
        self.skewy = 0
        self.rotation = 0
        self.color = {1, 1, 1, 1}

        local info = {
          char = char,
          index = i,
          length = #effectOrStr
        }
        for _, effect in pairs(currentEffects) do
          effect.fn(self, effect.args, info)
        end

        self.text:add(
          {self.color, char},
          x + self.charx, self.chary,
          self.rotation,
          self.scalex, self.scaley,
          0, 0, self.skewx, self.skewy)
        x = x + self.font:getWidth(char) * self.scalex
      end
    elseif type(effectOrStr) == "table" then
      local effectName = effectOrStr[1]
      if effectName:sub(1, 1) == "/" then
        effectName = effectName:sub(2, -1)

        if not currentEffects[effectName] then
          error("Effect '" .. effectName .. "' does not have a matching opening tag.")
        end

        currentEffects[effectName] = nil
      else
        local effectfn = self.effectGroup:getEffect(effectName)
        if not effectfn then
          error("Effect '" .. effectName .. "' does not exist.")
        end

        currentEffects[effectName] = {
          fn = effectfn,
          args = effectOrStr,
        }
      end
    end
  end
end

function RichTextObject:draw(...)
  love.graphics.draw(self.text, ...)
end

return RichText
