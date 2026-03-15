---@class Vertex
---@field x number Model-space X coordinate
---@field y number Model-space Y coordinate
---@field z number Model-space Z coordinate
---@field r number Red color component (0-255)
---@field g number Green color component (0-255)
---@field b number Blue color component (0-255)
local Vertex = {}
Vertex.__index = Vertex

function Vertex.new(x, y, z, r, g, b)
  return setmetatable({
    x = x,
    y = y,
    z = z,
    r = r,
    g = g,
    b = b,
  }, Vertex)
end

---@class Model
---@field n integer|nil The amount of vertices in this model
---@field vertices { [integer]: Vertex }|nil
---@field models Model[]|nil Only if this is a multi-model, matching all of the models
---@field anyOf Model[]|nil Only if this is a multi-model, matching any of the models
local Model = {}
Model.__index = Model

function Model.new(n, vertices)
  return setmetatable({
    n = n,
    vertices = vertices,
  }, Model)
end

---Make a multi-model. Comparing this will require all models to match (opposite of Model.any)
---@param models Model[]
---@return Model
function Model.multi(models)
  return setmetatable({
    models = models,
  }, Model)
end

---Make a multi-model. Comparing this requires only one model to match (opposite of Model.multi)
---@param models Model[]
---@return Model
function Model.any(models)
  return setmetatable({
    anyOf = models,
  }, Model)
end

---Compare this Model to the given Batch3D event
---@param event Render3D
---@return boolean matches
function Model:compare(event)
  -- anyOf case
  if self.anyOf then
    for _, model in ipairs(self.anyOf) do
      if model:compare(event) then
        return true
      end
    end

    return false
  end

  -- multi case
  if self.models then
    for _, model in ipairs(self.models) do
      if not model:compare(event) then
        return false
      end
    end
    return true
  end

  -- Single model case - check vertex count and vertices
  if self.n then
    if event:vertexcount() ~= self.n then
      return false
    end
  end

  if self.vertices then
    for idx, vertex in pairs(self.vertices) do
      local point = event:vertexpoint(idx)
      local x, y, z = point:get()
      local r, g, b = event:vertexcolor(idx)

      -- Compare coordinates with small tolerance for floating point
      local tolerance = 0.01
      if math.abs(x - vertex.x) > tolerance or
         math.abs(y - vertex.y) > tolerance or
         math.abs(z - vertex.z) > tolerance then
        return false
      end

      -- Compare colors if the vertex specified them (skip otherwise)
      if vertex.r ~= nil or vertex.g ~= nil or vertex.b ~= nil then
        local r255 = math.floor(r * 255 + 0.5)
        local g255 = math.floor(g * 255 + 0.5)
        local b255 = math.floor(b * 255 + 0.5)

        if (vertex.r ~= nil and math.abs(r255 - vertex.r) > 1) or
           (vertex.g ~= nil and math.abs(g255 - vertex.g) > 1) or
           (vertex.b ~= nil and math.abs(b255 - vertex.b) > 1) then
          return false
        end
      end
    end
  end

  return true
end

---@class Tile
---@field tileX number Tile X coordinate
---@field tileZ number Tile Z coordinate
---@field worldY number|nil World Y coordinate (optional, for height)
local Tile = {}
Tile.__index = Tile

function Tile.new(tileX, tileZ, worldY)
  return setmetatable({
    tileX = tileX,
    tileZ = tileZ,
    worldY = worldY,
  }, Tile)
end

return {
  Vertex = Vertex,
  Model = Model,
  Tile = Tile,
}
