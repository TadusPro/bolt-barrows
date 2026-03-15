local bolt = require("bolt")
bolt.checkversion(1, 0)

local markers = require("lib.init")
local conversation = require("modules.bolt-conversationmodule.conversation")

local HEIGHT_LIFT = 2
local OUTLINE_THICKNESS = 3.0
local MAX_TILE_DISTANCE = 100
local AUTO_MARK_FINISHED = true
local DIG_ARM_DISTANCE = 2
local DIG_CANCEL_DISTANCE = 4
local DIG_TRANSITION_TILE_DISTANCE = 6
local DIG_TRANSITION_Y_DISTANCE = 512
local RESET_CHUNK_X = 55
local RESET_CHUNK_Z = 151
local RESET_LOCAL_X = 32
local RESET_LOCAL_Z = 30
local RESET_DISTANCE = 10

local GRAVE_DEFAULT = "default"
local GRAVE_FINISHED = "finished"
local GRAVE_TUNNEL = "tunnel"
local GRAVE_STATES = {
  Dharok = GRAVE_DEFAULT,
  Guthan = GRAVE_DEFAULT,
  Karil = GRAVE_DEFAULT,
  Torag = GRAVE_DEFAULT,
  Verac = GRAVE_DEFAULT,
  Ahrim = GRAVE_DEFAULT,
}
-- example:
-- GRAVE_STATES.Dharok = GRAVE_FINISHED
-- AUTO_MARK_FINISHED = false
-- GRAVE_STATES.Karil = GRAVE_TUNNEL

local DIG_SPOTS = {
  { name = "Dharok", chunk_x = 55, chunk_z = 51, local_x = 55, local_z = 34, world_y = nil, y_offset = 2650 },
  { name = "Guthan", chunk_x = 55, chunk_z = 51, local_x = 56, local_z = 17, world_y = nil, y_offset = 2600 },
  { name = "Karil",  chunk_x = 55, chunk_z = 51, local_x = 44, local_z = 13, world_y = nil, y_offset = 2700 },
  { name = "Torag",  chunk_x = 55, chunk_z = 51, local_x = 34, local_z = 18, world_y = nil, y_offset = 2250 },
  { name = "Verac",  chunk_x = 55, chunk_z = 51, local_x = 37, local_z = 34, world_y = nil, y_offset = 2700 },
  { name = "Ahrim",  chunk_x = 55, chunk_z = 51, local_x = 47, local_z = 24, world_y = nil, y_offset = 2700 },
}

local viewproj = nil
local pending_dig_name = nil
local pending_dig_tile_x = nil
local pending_dig_tile_z = nil
local pending_dig_world_y = nil
local was_in_reset_area = false
local last_dig_name = nil
local last_conversation_text = nil

local function rs_to_tile(chunk_x, chunk_z, local_x, local_z)
  return chunk_x * 64 + local_x, chunk_z * 64 + local_z
end

local function get_nearest_dig_spot(player_tile_x, player_tile_z)
  local best_spot = nil
  local best_tile_x = nil
  local best_tile_z = nil
  local best_distance_sq = nil

  for _, spot in ipairs(DIG_SPOTS) do
    local tile_x, tile_z = rs_to_tile(spot.chunk_x, spot.chunk_z, spot.local_x, spot.local_z)
    local dx = tile_x - player_tile_x
    local dz = tile_z - player_tile_z
    local distance_sq = dx * dx + dz * dz

    if not best_distance_sq or distance_sq < best_distance_sq then
      best_spot = spot
      best_tile_x = tile_x
      best_tile_z = tile_z
      best_distance_sq = distance_sq
    end
  end

  return best_spot, best_tile_x, best_tile_z, best_distance_sq
end

local function clear_pending_dig()
  pending_dig_name = nil
  pending_dig_tile_x = nil
  pending_dig_tile_z = nil
  pending_dig_world_y = nil
end

local function set_grave_state(name, state)
  if name == nil then
    return
  end

  GRAVE_STATES[name] = state
end

local function get_grave_state(name)
  return GRAVE_STATES[name] or GRAVE_DEFAULT
end

local function remember_recent_dig(name)
  if name == nil then
    return
  end

  last_dig_name = name
end

local function reset_states()
  for name, _ in pairs(GRAVE_STATES) do
    GRAVE_STATES[name] = GRAVE_DEFAULT
  end

  clear_pending_dig()
  last_dig_name = nil
  last_conversation_text = nil
end

local function update_reset_zone(player_tile_x, player_tile_z)
  local reset_tile_x, reset_tile_z = rs_to_tile(RESET_CHUNK_X, RESET_CHUNK_Z, RESET_LOCAL_X, RESET_LOCAL_Z)
  local dx = player_tile_x - reset_tile_x
  local dz = player_tile_z - reset_tile_z
  local in_reset_area = dx * dx + dz * dz <= (RESET_DISTANCE * RESET_DISTANCE)

  if in_reset_area and not was_in_reset_area then
    reset_states()
  end

  was_in_reset_area = in_reset_area
end

local function update_finished(player_tile_x, player_tile_z, player_world_y)
  if not AUTO_MARK_FINISHED then
    return
  end

  local arm_distance_sq = DIG_ARM_DISTANCE * DIG_ARM_DISTANCE
  local cancel_distance_sq = DIG_CANCEL_DISTANCE * DIG_CANCEL_DISTANCE
  local transition_distance_sq = DIG_TRANSITION_TILE_DISTANCE * DIG_TRANSITION_TILE_DISTANCE

  local nearest_spot, nearest_tile_x, nearest_tile_z, nearest_distance_sq = get_nearest_dig_spot(player_tile_x, player_tile_z)

  if pending_dig_name == nil and nearest_spot and nearest_distance_sq <= arm_distance_sq then
    pending_dig_name = nearest_spot.name
    pending_dig_tile_x = nearest_tile_x
    pending_dig_tile_z = nearest_tile_z
    pending_dig_world_y = player_world_y
    remember_recent_dig(nearest_spot.name)
    return
  end

  if pending_dig_name == nil then
    return
  end

  local dx = player_tile_x - pending_dig_tile_x
  local dz = player_tile_z - pending_dig_tile_z
  local distance_sq = dx * dx + dz * dz
  local world_y_delta = math.abs(player_world_y - pending_dig_world_y)

  if distance_sq <= arm_distance_sq then
    return
  end

  if distance_sq >= transition_distance_sq or world_y_delta >= DIG_TRANSITION_Y_DISTANCE then
    remember_recent_dig(pending_dig_name)
    if get_grave_state(pending_dig_name) ~= GRAVE_TUNNEL then
      set_grave_state(pending_dig_name, GRAVE_FINISHED)
    end

    clear_pending_dig()
    return
  end

  if distance_sq >= cancel_distance_sq then
    remember_recent_dig(pending_dig_name)
    clear_pending_dig()
  end
end

local function get_tunnel_spot_name()
  if last_dig_name ~= nil then
    return last_dig_name
  end

  if pending_dig_name ~= nil then
    return pending_dig_name
  end

  return nil
end

local function is_hidden_tunnel_message(message)
  local normalized = string.lower(message):gsub("[^%a]", "")
  return string.find(normalized, "hiddentunnel", 1, true) ~= nil
    and string.find(normalized, "enter", 1, true) ~= nil
end

local function mark_last_dig_as_tunnel()
  local tunnel_name = get_tunnel_spot_name()
  if tunnel_name == nil then
    return
  end

  set_grave_state(tunnel_name, GRAVE_TUNNEL)
  clear_pending_dig()
end

local function handle_conversation_event(event)
  local text = conversation:readconversation(event)
  if not text or text == "" then
    return
  end

  if text == last_conversation_text then
    return
  end

  last_conversation_text = text

  if is_hidden_tunnel_message(text) then
    mark_last_dig_as_tunnel()
  end
end

local function get_style(name)
  local grave_state = get_grave_state(name)

  if grave_state == GRAVE_TUNNEL then
    return {
      color = { 64, 160, 255 },
      edgeColor = { 64, 160, 255 },
      fillAlpha = 46,
      edgeAlpha = 242,
    }
  end

  if grave_state == GRAVE_FINISHED then
    return {
      color = { 26, 255, 26 },
      edgeColor = { 26, 255, 26 },
      fillAlpha = 46,
      edgeAlpha = 242,
    }
  end

  return {
    color = { 255, 255, 26 },
    edgeColor = { 255, 255, 26 },
    fillAlpha = 46,
    edgeAlpha = 242,
  }
end

bolt.onrender3d(function(event)
  viewproj = event:viewprojmatrix()
end)

bolt.onrender2d(function(event)
  handle_conversation_event(event)
end)

bolt.onswapbuffers(function(event)
  if not viewproj then
    return
  end

  local player = bolt.playerposition()
  if not player then
    return
  end

  local px, py, pz = player:get()
  local player_tile_x, player_tile_z = markers.worldToTileCoords(px, pz)

  update_reset_zone(player_tile_x, player_tile_z)
  update_finished(player_tile_x, player_tile_z, py)

  markers.clearTiles()

  for _, spot in ipairs(DIG_SPOTS) do
    local tile_x, tile_z = rs_to_tile(spot.chunk_x, spot.chunk_z, spot.local_x, spot.local_z)
    local dx = tile_x - player_tile_x
    local dz = tile_z - player_tile_z

    if dx * dx + dz * dz <= (MAX_TILE_DISTANCE * MAX_TILE_DISTANCE) then
      local marker_style = get_style(spot.name)

      markers.markTile(tile_x, tile_z, {
        worldY = spot.world_y,
        yOffset = (spot.y_offset or 0) + HEIGHT_LIFT,
        color = marker_style.color,
        edgeColor = marker_style.edgeColor,
        fillAlpha = marker_style.fillAlpha,
        edgeAlpha = marker_style.edgeAlpha,
        thickness = OUTLINE_THICKNESS,
      })
    end
  end

  markers.renderTiles(bolt, viewproj)
end)