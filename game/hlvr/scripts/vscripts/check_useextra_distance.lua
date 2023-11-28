function GravityGlovePull()
    if thisEntity:Attribute_GetIntValue("picked_up", 0) == 1 or Entities:GetLocalPlayer():Attribute_GetIntValue("picked_up", 0) == 1 then
        return
    end

    -- We never pull these types of model
    local ignore_props = {
        "models/props/hazmat/hazmat_crate_lid.vmdl",
        "models/props/electric_box_door_1_32_48_front.vmdl",
        "models/props/electric_box_door_1_32_96_front.vmdl",
        "models/props/electric_box_door_2_32_48_front.vmdl",
        "models/props/interactive/washing_machine01a_door.vmdl",
        "models/props/fridge_1a_door.vmdl",
        "models/props/fridge_1a_door2.vmdl",
        "models/props_c17/mailbox_01/mailbox_02_door_a.vmdl",
        "models/props_c17/mailbox_01/mailbox_02_door_b.vmdl",
        "models/props_c17/mailbox_01/mailbox_02_door_d.vmdl",
        "models/props_c17/mailbox_01/mailbox_01_door.vmdl",
        "models/props/interactive/dumpster01a_lid.vmdl",
        "models/props/construction/portapotty_toilet_seat.vmdl",
        "models/props/interactive/file_cabinet_a_interactive_drawer_1.vmdl",
        "models/props/interactive/file_cabinet_a_interactive_drawer_2.vmdl",
        "models/props/interactive/file_cabinet_a_interactive_drawer_3.vmdl",
        "models/props/interactive/file_cabinet_a_interactive_drawer_4.vmdl",
        "models/props/interior_furniture/interior_locker_001_door_a.vmdl",
        "models/props/interior_furniture/interior_locker_001_door_b.vmdl",
        "models/props/interior_furniture/interior_locker_001_door_c.vmdl",
        "models/props/interior_furniture/interior_locker_001_door_d.vmdl",
        "models/props/interior_furniture/interior_locker_001_door_e.vmdl",
        "models/props/construction/pallet_jack_1.vmdl",
        "models/props_junk/wood_crate001a.vmdl",
        "models/props/desk_1_drawer_middle.vmdl",
    }

    -- We give precedence to these types of item
    local priority_classes = {
        "item_hlvr_health_station_vial",
        "item_hlvr_grenade_frag",
        "item_healthvial",
        "item_hlvr_crafting_currency_small",
        "item_hlvr_crafting_currency_large",
        "item_hlvr_clip_shotgun_single",
        "item_hlvr_clip_shotgun_multiple",
        "item_hlvr_clip_rapidfire",
        "item_hlvr_clip_energygun_multiple",
        "item_hlvr_clip_energygun",
        "item_hlvr_grenade_xen",
        "item_hlvr_prop_battery",
    }

    -- Find objects near where the player is looking, and check whether any
    -- of them is of a priority class
    local target = nil
    local nearby = Entities:FindAllInSphere(thisEntity:GetAbsOrigin(), 80)
    for _, ent in pairs(nearby) do
        local class = ent:GetClassname()
        if vlua.find(priority_classes, class) then
            target = ent
            break
        end
    end

    local player = Entities:GetLocalPlayer()
    if target ~= nil then
        -- Does the player have line of sight to the priority target?
        local eyetrace =
        {
            startpos = player:EyePosition();
            endpos = target:GetAbsOrigin();
            ignore = player;
            mask =  33636363;
        }
        TraceLine(eyetrace)

        if not eyetrace.hit or eyetrace.enthit ~= target then
            -- No, so don't pull it
            target = nil
        end
    end

    if target == nil then
        -- No priority target, just try pulling whatever the player sees
        target = thisEntity
    end

    local class = target:GetClassname()
    local model = target:GetModelName()

    if target:GetName() == "peeled_corridor_objects" or
       class == "prop_reviver_heart" or
       vlua.find(ignore_props, model) == nil and
       player:Attribute_GetIntValue("gravity_gloves", 0) == 1 and
       (class == "prop_physics" or
            vlua.find(priority_classes, class) or class == "item_item_crate") and
       (target:GetMass() <= 15 or
            class == "item_hlvr_prop_battery" or
            model == "models/interaction/anim_interact/hand_crank_wheel/hand_crank_wheel.vmdl") then

        local startVector = player:EyePosition()
        local grabbity_glove_catch_params = { ["userid"]=player:GetUserID() }
        FireGameEvent("grabbity_glove_catch", grabbity_glove_catch_params)
        player:StopThink("GGTutorial")

        local direction = startVector - target:GetAbsOrigin()
        target:ApplyAbsVelocityImpulse(Vector(direction.x * 2, direction.y * 2, Clamp(direction.z * 3.8, -400, 400)))
        StartSoundEventFromPosition("Grabbity.HoverPing", startVector)
        StartSoundEventFromPosition("Grabbity.Grab", startVector)

        local count = 0
        target:SetThink(function()
            local ents = Entities:FindAllInSphere(Entities:GetLocalPlayer():EyePosition(), 60)
            if vlua.find(ents, target) then
                DoEntFireByInstanceHandle(target, "Use", "", 0, player, player)
                if target:GetClassname() == "item_hlvr_grenade_frag" then
                    SendToConsole("+use")
                    target:SetThink(function()
                        SendToConsole("-use")
                        DoEntFireByInstanceHandle(target, "RunScriptFile", "useextra", 0, player, player)
                    end, "", 0.02)
                    if vlua.find(target:GetSequence(), "vr_grenade_arm_") then
                        DoEntFireByInstanceHandle(target, "SetTimer", "3", 0, nil, nil)
                    end
                end
                return nil
            end

            if count < 5 then
                count = count + 1
                return 0.1
            end
        end, "GrabItem", 0.1)
    end
end

local name = thisEntity:GetName()
local class = thisEntity:GetClassname()
local player = Entities:GetLocalPlayer()
local startVector = player:EyePosition()
local eyetrace =
{
    startpos = startVector;
    endpos = startVector + RotatePosition(Vector(0,0,0), player:GetAngles(), Vector(60,0,0));
    ignore = player;
    mask = -1
}
TraceLine(eyetrace)
if eyetrace.hit then
    local useRoutine = 0
    if eyetrace.enthit and eyetrace.enthit:GetClassname() == "worldent" then
        GravityGlovePull()
        return
    end

    -- TODO: There's gotta be a better way than to exclude some things from here
    if eyetrace.enthit == thisEntity or vlua.find(class, "hlvr_piano") or name == "russell_entry_window" or class == "item_combine_tank_locker" or vlua.find(name, "socket") or vlua.find(name, "traincar_01") then
        useRoutine = 1
        player:SetThink(function()
            if IsValidEntity(thisEntity) then
                DoEntFireByInstanceHandle(thisEntity, "RunScriptFile", "useextra", 0, nil, nil)
            end
        end, "useextra", 0.02)
    end

    if VectorDistance(startVector, eyetrace.pos) > cvar_getf("player_use_radius") then
        player:SetThink(function()
            if IsValidEntity(thisEntity) then
                GravityGlovePull()
            end
        end, "GravityGlovePull", 0.02)
    elseif useRoutine == 0 and (eyetrace.enthit == thisEntity or vlua.find(name, "door_hack")) and IsValidEntity(thisEntity) then
		DoEntFireByInstanceHandle(thisEntity, "RunScriptFile", "useextra", 0, nil, nil)
    end
else
    GravityGlovePull()
end
