local M = {}

local TILE_SIZE = 512

---Convert world coordinates to tile coordinates
---@param worldX number World X coordinate
---@param worldZ number World Z coordinate
---@return number tileX Tile X coordinate
---@return number tileZ Tile Z coordinate
function M.worldToTileCoords(worldX, worldZ)
  return math.floor(worldX / TILE_SIZE), math.floor(worldZ / TILE_SIZE)
end

---Convert tile coordinates to world coordinates
---@param tileX number Tile X coordinate
---@param tileZ number Tile Z coordinate
---@return number worldX World X coordinate
---@return number worldZ World Z coordinate
function M.tileToWorldCoords(tileX, tileZ)
  return tileX * TILE_SIZE, tileZ * TILE_SIZE
end

---Convert world coordinates to tile-aligned 2D world position
---@param worldX number World X coordinate
---@param worldZ number World Z coordinate
---@return table position Table with x and z fields
function M.worldToTile2D(worldX, worldZ)
  return {
    x = math.floor(worldX / TILE_SIZE) * TILE_SIZE,
    z = math.floor(worldZ / TILE_SIZE) * TILE_SIZE
  }
end

---Convert RuneScape chunk-local coordinates to tile coordinates
---@param floor number Floor level
---@param chunkX number Chunk X coordinate
---@param chunkZ number Chunk Z coordinate
---@param localX number Local X within chunk (0-63)
---@param localZ number Local Z within chunk (0-63)
---@return number tileX Tile X coordinate
---@return number tileZ Tile Z coordinate
function M.rsToTileCoords(floor, chunkX, chunkZ, localX, localZ)
  local tileX = chunkX * 64 + localX
  local tileZ = chunkZ * 64 + localZ
  return tileX, tileZ
end

---Generate a unique key for a tile position
---@param tileX number Tile X coordinate
---@param tileZ number Tile Z coordinate
---@return string key Unique tile key
function M.tileKey(tileX, tileZ)
  return tileX .. "," .. tileZ
end

---Convert tile coordinates to RuneScape chunk-local coordinates
---@param tileX number Tile X coordinate
---@param tileZ number Tile Z coordinate
---@param worldY number World Y coordinate for floor calculation
---@return number floor Floor level
---@return number chunkX Chunk X coordinate
---@return number chunkZ Chunk Z coordinate
---@return number localX Local X within chunk (0-63)
---@return number localZ Local Z within chunk (0-63)
function M.tileToRS(tileX, tileZ, worldY)
  local floor = math.floor((worldY - 965) / 960)
  local chunkX = math.floor(tileX / 64)
  local chunkZ = math.floor(tileZ / 64)
  local localX = tileX % 64
  local localZ = tileZ % 64
  return floor, chunkX, chunkZ, localX, localZ
end

M.TILE_SIZE = TILE_SIZE
return M
