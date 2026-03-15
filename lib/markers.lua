local M = {}

local shaders = require("lib.shaders")
local types = require("lib.types")
local coords = require("lib.coords")

-- Storage for marked models and tiles
local markedModels = {}
local markedTiles = {}
local renderTilesCalledOnce = false

-- Helper functions for validation
local function isDepthValid(sd)
  return sd and sd > 0.0 and sd <= 1.0
end

local function isFinite(v)
  return v == v and v ~= math.huge and v ~= -math.huge
end

local function isTriangleFrontFacing(p1x, p1y, p1z, p2x, p2y, p2z, p3x, p3y, p3z, camX, camY, camZ)
  local e1x, e1y, e1z = p2x - p1x, p2y - p1y, p2z - p1z
  local e2x, e2y, e2z = p3x - p1x, p3y - p1y, p3z - p1z

  local nx = e1y * e2z - e1z * e2y
  local ny = e1z * e2x - e1x * e2z
  local nz = e1x * e2y - e1y * e2x

  local centerX = (p1x + p2x + p3x) / 3
  local centerY = (p1y + p2y + p3y) / 3
  local centerZ = (p1z + p2z + p3z) / 3

  local viewX = camX - centerX
  local viewY = camY - centerY
  local viewZ = camZ - centerZ

  return (nx * viewX + ny * viewY + nz * viewZ) > 0
end

local function findSilhouetteEdges(event, modelMatrix)
  local vertexCount = event:vertexcount()
  local camX, camY, camZ = event:cameraposition()

  local edgeToTriangles = {}

  for i = 1, vertexCount - 2, 3 do
    local p1 = event:vertexpoint(i):transform(modelMatrix)
    local p2 = event:vertexpoint(i + 1):transform(modelMatrix)
    local p3 = event:vertexpoint(i + 2):transform(modelMatrix)

    local x1, y1, z1 = p1:get()
    local x2, y2, z2 = p2:get()
    local x3, y3, z3 = p3:get()

    local isFront = isTriangleFrontFacing(x1, y1, z1, x2, y2, z2, x3, y3, z3, camX, camY, camZ)

    local triangleEdges = {
      { i, i + 1 },
      { i + 1, i + 2 },
      { i + 2, i },
    }

    for _, edge in ipairs(triangleEdges) do
      local a, b = edge[1], edge[2]
      local key = (a < b) and (a .. "," .. b) or (b .. "," .. a)

      if not edgeToTriangles[key] then
        edgeToTriangles[key] = { a = a, b = b, frontFacing = {} }
      end
      table.insert(edgeToTriangles[key].frontFacing, isFront)
    end
  end

  local silhouetteEdges = {}
  for _, edgeData in pairs(edgeToTriangles) do
    local hasFront, hasBack = false, false
    for _, isFront in ipairs(edgeData.frontFacing) do
      if isFront then hasFront = true else hasBack = true end
    end
    if hasFront and hasBack then
      table.insert(silhouetteEdges, { a = edgeData.a, b = edgeData.b })
    end
  end

  return silhouetteEdges
end

---Mark a model for rendering
---@param model Model The model to mark
---@param options table|nil Optional configuration: { color = {r, g, b}, fillAlpha = number }
---@return number id The ID of the marked model (for later removal)
function M.markModel(model, options)
  options = options or {}

  local color = options.color or { 255, 0, 255 } -- Default magenta
  local fillAlpha = options.fillAlpha or 160

  local entry = {
    model = model,
    color = color,
    edgeColor = color, -- Use same color for edges
    fillAlpha = fillAlpha,
    edgeAlpha = 255, -- Always opaque edges
    thickness = 4, -- Fixed thickness
  }

  table.insert(markedModels, entry)
  return #markedModels
end

---Unmark a model by ID
---@param id number The ID returned by markModel
function M.unmarkModel(id)
  if markedModels[id] then
    table.remove(markedModels, id)
  end
end

---Clear all marked models
function M.clearModels()
  markedModels = {}
end

---Mark a tile for rendering
---@param tileX number Tile X coordinate
---@param tileZ number Tile Z coordinate
---@param options table|nil Optional configuration: { color = {r, g, b}, worldY = number, fillAlpha = number, edgeAlpha = number, thickness = number }
---@return number id The ID of the marked tile (for later removal)
function M.markTile(tileX, tileZ, options)
  options = options or {}

  local entry = {
    tileX = tileX,
    tileZ = tileZ,
    worldY = options.worldY,
    yOffset = options.yOffset or 0,
    color = options.color or { 0, 255, 255 }, -- Default cyan
    edgeColor = options.edgeColor or options.color or { 0, 255, 255 },
    fillAlpha = options.fillAlpha or 100,
    edgeAlpha = options.edgeAlpha or 255,
    thickness = options.thickness or 4,
  }

  table.insert(markedTiles, entry)
  return #markedTiles
end

---Unmark a tile by ID
---@param id number The ID returned by markTile
function M.unmarkTile(id)
  if markedTiles[id] then
    table.remove(markedTiles, id)
  end
end

---Clear all marked tiles
function M.clearTiles()
  markedTiles = {}
end

---Get terrain height at world coordinates (with fallback)
---@param bolt any Bolt instance
---@param wx number World X coordinate
---@param wz number World Z coordinate
---@return number|nil height Height at the position, or nil if unavailable
local function terrainHeightOrNil(bolt, wx, wz)
  local height = bolt.groundheight and bolt.groundheight(wx, wz)
  return height
end

---Render marked models (call this from a Render3D hook)
---@param bolt any Bolt instance
---@param event any Render3D event
function M.renderModels(bolt, event)
  if #markedModels == 0 then return end

  local vx, vy, vw, vh = bolt.gameviewxywh()
  shaders.setScreenDimensions(vw, vh)

  for _, entry in ipairs(markedModels) do
    if entry.model:compare(event) then
      local modelMatrix = event:modelmatrix()
      local viewProj = event:viewprojmatrix()

      local r, g, b = entry.color[1], entry.color[2], entry.color[3]
      local edgeR, edgeG, edgeB = entry.edgeColor[1], entry.edgeColor[2], entry.edgeColor[3]

      local vertexCount = event:vertexcount()
      local camX, camY, camZ = event:cameraposition()

      local fillQuads = {}
      for i = 1, vertexCount - 2, 3 do
        local p1 = event:vertexpoint(i)
        local p2 = event:vertexpoint(i + 1)
        local p3 = event:vertexpoint(i + 2)

        local worldP1 = p1:transform(modelMatrix)
        local worldP2 = p2:transform(modelMatrix)
        local worldP3 = p3:transform(modelMatrix)

        local x1, y1, z1 = worldP1:get()
        local x2, y2, z2 = worldP2:get()
        local x3, y3, z3 = worldP3:get()

        if isTriangleFrontFacing(x1, y1, z1, x2, y2, z2, x3, y3, z3, camX, camY, camZ) then
          local screenP1 = worldP1:transform(viewProj)
          local screenP2 = worldP2:transform(viewProj)
          local screenP3 = worldP3:transform(viewProj)

          local sx1, sy1, sd1 = screenP1:aspixels()
          local sx2, sy2, sd2 = screenP2:aspixels()
          local sx3, sy3, sd3 = screenP3:aspixels()

          if isDepthValid(sd1) and isDepthValid(sd2) and isDepthValid(sd3)
            and isFinite(sx1) and isFinite(sx2) and isFinite(sx3)
            and isFinite(sy1) and isFinite(sy2) and isFinite(sy3)
          then
            table.insert(fillQuads, {
              x1 = sx1, y1 = sy1,
              x2 = sx2, y2 = sy2,
              x3 = sx3, y3 = sy3,
              x4 = sx1, y4 = sy1,
              r = r, g = g, b = b, a = entry.fillAlpha
            })
          end
        end
      end

      local edges = findSilhouetteEdges(event, modelMatrix)
      local linesToDraw = {}

      for _, edge in ipairs(edges) do
        local worldA = event:vertexpoint(edge.a):transform(modelMatrix)
        local worldB = event:vertexpoint(edge.b):transform(modelMatrix)

        local screenA = worldA:transform(viewProj)
        local screenB = worldB:transform(viewProj)

        local sx1, sy1, sd1 = screenA:aspixels()
        local sx2, sy2, sd2 = screenB:aspixels()

        if isDepthValid(sd1) and isDepthValid(sd2)
          and isFinite(sx1) and isFinite(sx2)
          and isFinite(sy1) and isFinite(sy2)
        then
          table.insert(linesToDraw, {
            x1 = sx1, y1 = sy1,
            x2 = sx2, y2 = sy2,
            thickness = entry.thickness,
            r = edgeR, g = edgeG, b = edgeB, a = entry.edgeAlpha
          })
        end
      end

      if #fillQuads > 0 then
        shaders.drawQuadsShader(bolt, fillQuads, vx, vy)
      end

      if #linesToDraw > 0 then
        shaders.drawLinesShader(bolt, linesToDraw, vx, vy)
      end

      return
    end
  end
end

---Render marked tiles (call this from a SwapBuffers hook)
---@param bolt any Bolt instance
---@param viewProj any View-projection matrix
function M.renderTiles(bolt, viewProj)
  if not renderTilesCalledOnce then
    print(string.format("[markers] renderTiles called, marked tiles count: %d", #markedTiles))
    renderTilesCalledOnce = true
  end

  if #markedTiles == 0 then return end

  local vx, vy, vw, vh = bolt.gameviewxywh()
  shaders.setScreenDimensions(vw, vh)

  local TILE_SIZE = coords.TILE_SIZE

  for _, entry in ipairs(markedTiles) do
    local worldX, worldZ = coords.tileToWorldCoords(entry.tileX, entry.tileZ)

    -- Build the 4 corners of the tile
    local corners = {
      { x = worldX, z = worldZ },
      { x = worldX + TILE_SIZE, z = worldZ },
      { x = worldX + TILE_SIZE, z = worldZ + TILE_SIZE },
      { x = worldX, z = worldZ + TILE_SIZE },
    }

    -- Get heights for each corner
    for i, corner in ipairs(corners) do
      if entry.worldY ~= nil then
        corner.y = entry.worldY + entry.yOffset
      else
        corner.y = (terrainHeightOrNil(bolt, corner.x, corner.z) or 0) + entry.yOffset
      end
    end

    -- Transform to screen space
    local screenCorners = {}
    local allValid = true
    for i, corner in ipairs(corners) do
      local worldPos = bolt.point(corner.x, corner.y, corner.z)
      local screenPos = worldPos:transform(viewProj)
      local sx, sy, sd = screenPos:aspixels()

      if not (isDepthValid(sd) and isFinite(sx) and isFinite(sy)) then
        allValid = false
        break
      end

      screenCorners[i] = { x = sx, y = sy, d = sd }
    end

    if allValid then
      -- Render fill (2 triangles)
      local fillQuads = {
        {
          x1 = screenCorners[1].x, y1 = screenCorners[1].y,
          x2 = screenCorners[2].x, y2 = screenCorners[2].y,
          x3 = screenCorners[3].x, y3 = screenCorners[3].y,
          x4 = screenCorners[4].x, y4 = screenCorners[4].y,
          r = entry.color[1], g = entry.color[2], b = entry.color[3], a = entry.fillAlpha
        }
      }
      shaders.drawQuadsShader(bolt, fillQuads, vx, vy)

      -- Render edges
      local linesToDraw = {}
      for i = 1, 4 do
        local nextI = (i % 4) + 1
        table.insert(linesToDraw, {
          x1 = screenCorners[i].x, y1 = screenCorners[i].y,
          x2 = screenCorners[nextI].x, y2 = screenCorners[nextI].y,
          thickness = entry.thickness,
          r = entry.edgeColor[1], g = entry.edgeColor[2], b = entry.edgeColor[3], a = entry.edgeAlpha
        })
      end
      shaders.drawLinesShader(bolt, linesToDraw, vx, vy)
    end
  end
end

return M
