do
  local mod_gui = require("mod-gui")

  local MAX_LOGISTIC_REQUEST = 4294967295
  function handle_overflow(current, toAdd)
    if MAX_LOGISTIC_REQUEST - current < toAdd then
      return MAX_LOGISTIC_REQUEST
    else
      return current + toAdd
    end
  end
  function maintain_infinite(current, toRemove)
    if current == MAX_LOGISTIC_REQUEST then
      return MAX_LOGISTIC_REQUEST
    else
      return current - toRemove
    end
  end

  local BUTTON_NAME = "blueprint-request-button"

  function handle_cursor_changed(event)
    local player = game.players[event.player_index]
    if not player or not player.valid then return end

    local button = mod_gui.get_button_flow(player)[BUTTON_NAME]
    if player.is_cursor_blueprint() then
      if not button then
        button = mod_gui.get_button_flow(player).add({
          name = BUTTON_NAME,
          type = "sprite-button",
          sprite = "blueprint-request-sprite",
          tooltip = "Request all items in blueprint"
        })
      end
    elseif button then
      button.destroy()
      button = nil
    end
  end

  function handle_gui_click(event)
    local player = game.players[event.player_index]
    if not player or not player.valid then return end

    local character = player.character
    if not character or not character.valid then return end

    if event.element.name ~= BUTTON_NAME then return end

    local items = collect_items(player.get_blueprint_entities())
    -- Table pointing to the logistic slot to modify
    local tbl = {}

    -- Scan current requests that we should modify
    for i = 1, character.request_slot_count do
      local current_request = character.get_personal_logistic_slot(i)
      local requested_item = current_request.name
      if requested_item and items[requested_item] then
        tbl[requested_item] = {
          slot = i,
          current_min = current_request.min,
          current_max = current_request.max,
          count = items[requested_item],
        }
      end
    end

    -- Find empty slots for new items
    do
      local function first_empty_logistics_slot_from(start_slot_index)
        for i = start_slot_index, 65536 do
          local current_request = character.get_personal_logistic_slot(i)
          if not current_request.name then
            return i
          end
        end
      end
      local i = 1
      for item, count in pairs(items) do
        if not tbl[item] then
          local slot = first_empty_logistics_slot_from(i)
          tbl[item] = {
            slot = slot,
            current_min = 0,
            current_max = 0,
            count = count
          }
          i = slot + 1
        end
      end
    end

    if event.button == defines.mouse_button_type.left then -- adding
      for item, request in pairs(tbl) do
        character.set_personal_logistic_slot(request.slot, {
          name = item,
          min = handle_overflow(request.current_min, request.count),
          max = handle_overflow(request.current_max, request.count),
        })
      end
    elseif event.button == defines.mouse_button_type.right then -- removing
      -- check that all can be removed
      for item, request in pairs(tbl) do
        if request.count > request.current_min then
          return
        end
      end
      for item, request in pairs(tbl) do
        local new_min = request.current_min - request.count
        character.set_personal_logistic_slot(request.slot, {
          name = new_min > 0 and item or nil, -- clear slot when request is 0
          min = new_min,
          max = maintain_infinite(request.current_max, request.count),
        })
      end
    end
  end

  function collect_items(blueprint_entities)
    local items = {}
    local function insert(item_name, count)
      if not items[item_name] then
         items[item_name] = count
       else
         items[item_name] = items[item_name] + count
       end
    end

    for _, entity in pairs(blueprint_entities) do
      local replacements = get_replacements(entity.name)
      -- for composite entities where not everything has a mineable result
      if replacements then
        for _, replacement in pairs(replacements) do
          insert(replacement.name, replacement.amount)
        end
      end

      if entity.items then -- modules
        for item, count in pairs(entity.items) do
          insert(item, count)
        end
      end
    end
    return items
  end

  function get_replacements(entity)
    return game.entity_prototypes[entity].mineable_properties.products
  end

  script.on_event(defines.events.on_player_cursor_stack_changed, handle_cursor_changed)
  script.on_event(defines.events.on_gui_click, handle_gui_click)
end
