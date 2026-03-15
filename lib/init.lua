-- Bolt Markers Module
-- A reusable module for rendering tile and model markers in Bolt plugins

local types = require("lib.types")
local coords = require("lib.coords")
local markers = require("lib.markers")

return {
  -- Types
  Vertex = types.Vertex,
  Model = types.Model,
  Tile = types.Tile,

  -- Coordinate utilities
  worldToTileCoords = coords.worldToTileCoords,
  tileToWorldCoords = coords.tileToWorldCoords,
  worldToTile2D = coords.worldToTile2D,
  rsToTileCoords = coords.rsToTileCoords,
  tileToRS = coords.tileToRS,
  tileKey = coords.tileKey,
  TILE_SIZE = coords.TILE_SIZE,

  -- Marker API
  markModel = markers.markModel,
  unmarkModel = markers.unmarkModel,
  clearModels = markers.clearModels,
  markTile = markers.markTile,
  unmarkTile = markers.unmarkTile,
  clearTiles = markers.clearTiles,
  renderModels = markers.renderModels,
  renderTiles = markers.renderTiles,
}
