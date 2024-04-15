-- technic_use_battery/init.lua
-- Use energy from RE batteries in the inventory
-- Copyright (C) 2024  1F616EMO
-- SPDX-License-Identifier: LGPL-2.1-or-later

technic_use_battery = {}

local _bats = {
    -- RE Battery
    ["technic:battery"] = true,

    -- Energy crystals
    ["technic:blue_energy_crystal"] = true,
    ["technic:green_energy_crystal"] = true,
    ["technic:red_energy_crystal"] = true,
}
technic_use_battery.allowed_batteries = _bats

if minetest.get_modpath("powerbanks") then
    for _, mark in ipairs({"1", "2", "3"}) do
        _bats["powerbanks:powerbank_mk" .. mark] = true
    end
end

technic_use_battery.CHARGE_STEP = 12000 -- HV Power bank
technic_use_battery.CHARGE_DTIME = 1

local floor = math.floor

local total_dtime = 0
minetest.register_globalstep(function(dtime)
    total_dtime = total_dtime + dtime
    if total_dtime >= technic_use_battery.CHARGE_DTIME then -- Faster than HV
        total_dtime = 0
    else
        return
    end

    for _, player in ipairs(minetest.get_connected_players()) do
        local inv = player:get_inventory()
        local main = inv:get_list("main")
        local charge_src_chg = 0
        local charge_src
        local charge_dests = {}

        for i, stack in ipairs(main) do
            if _bats[stack:get_name()] then
                local def = stack:get_definition()
                local chg = def.technic_get_charge(stack)
                if chg > charge_src_chg then
                    charge_src = i
                    charge_src_chg = chg
                end
            else
                local def = stack:get_definition()
                if def and def.technic_get_charge and def.technic_set_charge and def.technic_max_charge then
                    local charge = def.technic_get_charge(stack)
                    if charge < def.technic_max_charge then
                        charge_dests[#charge_dests+1] = i
                    end
                end
            end
        end

        if charge_src and charge_src_chg ~= 0 and #charge_dests > 0 then
            -- Every item shares the charge step
            local ACTUAL_CHG_STEP = floor(technic_use_battery.CHARGE_STEP / #charge_dests)
            local src_stack = main[charge_src]
            for _, i in ipairs(charge_dests) do
                local stack = main[i]
                local def = stack:get_definition()
                local chg = math.min(ACTUAL_CHG_STEP, def.technic_max_charge - def.technic_get_charge(stack))
                if technic.use_RE_charge(src_stack, chg) then
                    local charge = def.technic_get_charge(stack)
                    charge = charge + chg
                    def.technic_set_charge(stack, charge)
                    main[i] = stack
                end
            end
            main[charge_src] = src_stack
            inv:set_list("main", main)
        end
    end
end)
