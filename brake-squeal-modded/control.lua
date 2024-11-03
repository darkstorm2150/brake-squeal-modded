if script.active_mods["gvv"] then require("__gvv__.gvv")() end

local debug = false

local squeals = {
    "a1",
    "a2",
}

local function initialize_schedule()
    storage.__brake_squeal_mod = storage.__brake_squeal_mod or {};
    storage.__brake_squeal_mod.squeal_schedule = {}
end

local function get_carriages_for_sounds(train)
    local carriages = {}
    for i, carriage in ipairs(train.carriages) do
        if i % 3 == 1 then table.insert(carriages, carriage) end
    end
    return carriages
end

-- Copied & modified from @_codegreen from the factorio discord
-- Schedules the next sound to be played
local function task_scheduler(train)
    local future_tick = game.tick - (game.tick % 5) + 10
    local schedule = storage.__brake_squeal_mod.squeal_schedule[future_tick] or {} -- if the tick table doesn't exist, make one
    schedule[#schedule+1] = train                              -- append value to table
    storage.__brake_squeal_mod.squeal_schedule[future_tick] = schedule             -- reassign table to storage
end

local function math_clamp(x, x_min, x_max)
	return math.max(math.min(x, x_max), x_min)
end

local function sound_handler(train)
    for i,entity in ipairs(get_carriages_for_sounds(train)) do
        local sound = squeals[math.random(#squeals)]
        local speed = math.abs(train.speed)
		if not helpers.is_valid_sound_path(sound) then game.print("path is invalid:"..tostring(sound)) end
        if helpers.is_valid_sound_path(sound) and entity and speed > 0.05 then -- no sound below 10.8km/h
            local volume = math_clamp(speed*2, 0.3, 1) -- start decreasing volume at around 108km/h if my math is right
            entity.surface.play_sound{path = sound, position = entity.position, volume_modifier = volume}
        end
    end
end

--[[
local function toggle_debug()
    if debug then
        debug = false
        game.print("Debugging disabled!")
    else
        debug = true
        game.print("Debugging enabled!")
    end
end
commands.add_command("toggle_brake_debug", "there is nobody to help you", toggle_debug)
]]--

script.on_event(defines.events.on_train_changed_state,
    function(event)
        local train = event.train
        if train.state == defines.train_state.on_the_path then
            return -- most common state, let's return immediately so we waste as little UPS as possible
        elseif train.state == defines.train_state.arrive_signal or train.state == defines.train_state.arrive_station then
            task_scheduler(train)
        elseif train.manual_mode then
            task_scheduler(train)
        end
    end
)

-- on_tick
local function task_handler(event)
    -- Retrieve the tick table, using the namespaced storage variable
    local tick = storage.__brake_squeal_mod.squeal_schedule[event.tick]
    
    -- Check if the tick table exists and is a table
    if tick and type(tick) == 'table' then
        -- Iterate over all values in the tick table
        for _, value in pairs(tick) do
            -- Check if the train is still valid
			-- If not valid, skip to the next iteration
            if value.valid then   
				-- Check the train's acceleration state
				if value.riding_state.acceleration ~= defines.riding.acceleration.braking then
					-- If not braking, check for manual mode
					if value.manual_mode then
						-- If in manual mode, reschedule the sound
						task_scheduler(value)
						-- Skip to the next iteration (continue)
						--goto continue
					end
					-- If not braking and not in manual mode, skip playing the sound
				else
					-- Play the sound for the train
					task_scheduler(value)
					sound_handler(value)
					--goto continue
				end
			end
				
			-- Label for skipping to the next iteration (continue)
			--::continue::
        end
        
        -- Clean up: Remove the tick table after processing
        storage.__brake_squeal_mod.squeal_schedule[event.tick] = nil
    else
        -- Optional: Log or handle the case when tick is not found or not a table
        -- game.print("Tick table not found or invalid for tick: ".. tostring(event.tick))
    end
end

--commands.add_command("re-initialize-schedule", "there is still nobody to help you", initialize_schedule)

script.on_init(initialize_schedule)
script.on_nth_tick(5, task_handler)
