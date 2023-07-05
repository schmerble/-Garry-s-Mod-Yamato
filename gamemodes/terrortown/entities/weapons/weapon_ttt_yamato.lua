AddCSLuaFile()

/// Server Convars 
local cvf                   = FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_SERVER_CAN_EXECUTE
local speedModifyer         = CreateConVar("ymt_speed", 2, cvf, "Changes speed of holder")
local dmgJCN                = CreateConVar("ymt_dmgJCN", 35, cvf, "Changes damage of RMB attack")
local dmgCut                = CreateConVar("ymt_dmgCut", 45, cvf, "Changes damage of LMB attack")
local equipWeapons          = CreateConVar("ymt_equip", 0, cvf, "Allows Yamato holders to equip other weapons: \n 0 for false, 1 for true")
/// Server Convars End

if CLIENT then
    SWEP.PrintName = "Yamato"
    SWEP.Slot = 6
    SWEP.Icon = "vgui/ttt/icon_yamato"
    SWEP.EquipMenuData = {
        type = "Weapon",
        desc = "I am the storm that is approaching."
    }
end

/// TTT Swep Basics
SWEP.Base = "weapon_tttbase"
SWEP.HoldType = "melee"
SWEP.Kind = WEAPON_MELEE
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 1.2
SWEP.Primary.Recoil = 1.9
SWEP.Primary.Cone = 0 -- To prevent stray slashes(?)
SWEP.Primary.Damage = 35-- Use ymt_dmgCut to modify with server convar
SWEP.Primary.Automatic = false
SWEP.Primary.ClipSize = -1 -- Infinite ammo
SWEP.Primary.DefaultClip = -1 -- ^
SWEP.Primary.Sound = Sound("yamato_jc")

SWEP.UseHands = true
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 90
SWEP.ViewModel = Model("models/weapons/yamato/yamato.mdl")
SWEP.WorldModel = Model("models/weapons/w_yamato.mdl")

SWEP.Kind = WEAPON_EQUIP1
SWEP.AutoSpawnable = false
SWEP.AmmoEnt = "item_ammo_pistol_ttt"
SWEP.CanBuy = {ROLE_TRAITOR}
SWEP.InLoadoutFor = {nil}
SWEP.LimitedStock = true
SWEP.AllowDrop = true
SWEP.IsSilent = true
SWEP.NoSights = true
/// TTT Swep Basics /END

// speedMod(ply)
// Takes in a player given by parameter
// Checks if player is valid to prevent any lua errors
// Returns a speedModifyer that is set by the "ymt_speed" convar
local function speedMod(ply)
    if !IsValid(ply) then return end
    local weapon = ply:GetActiveWeapon()
    if weapon == NULL  then return 1
    else
        if weapon:GetClass() == "weapon_ttt_yamato" then return speedModifyer:GetInt()
        end
    end
end

// Tables

// table:OkWeapons
// My really elementary way of preventing the Yamato
// dropping everything and soft bricking your player
local okWeapons = {
    [1] = "weapon_ttt_unarmed", -- Holster
    [2] = "weapon_zm_improvised", -- Crowbar
    [3] = "weapon_zm_carry", --The stick
    [4] = "weapon_ttt_smokegrenade", -- Smoke Grenade
    [5] = "weapon_ttt_decoy", -- Not sure what this was, but it kept popping up while testing
    [6] = "weapon_zm_molotov", -- Molotov
    [7] = "weapon_ttt_confgrenade", -- Discombobulator
}

// table:animLog
// Wanted to implement randomize attack sequences when attacking
// *PLANING TO REWORK LATER*
local animLog = {
    [1] = ACT_VM_SECONDARYATTACK,
    [2] = ACT_VM_HITRIGHT,
    [3] = ACT_VM_HITCENTER,
    [4] = ACT_VM_MISSLEFT,
    [5] = ACT_VM_MISSRIGHT,
}

local canPickUpWeapons = true
local delay = 5
local lastOccurance = -delay -- Ensure the first trigger attempt will work
local combo = 0

// Simple Array check
function tablecontains(table, element)
    for _, value in pairs(table) do
      if value == element then
        return true
      end
    end
    return false
end

// On drop, allows to pick up weapons if "ymt_equip" is set to 0
function SWEP:OnDrop()
    if equipWeapons:GetInt() == 0 then
        canPickUpWeapons = true
    end
end

// Changes speed of every given client, and changes the speed of a client from the returned val of speedMod
hook.Add("TTTPlayerSpeedModifier", "SpeedModifier", speedMod)

// Hook only exists to prevent weapons from being picked up
hook.Add("PlayerCanPickupWeapon", "NoWPNpickups", function( ply, weapon)
    if ply:HasWeapon("weapon_ttt_yamato") and equipWeapons:GetInt() == 0 then
        return false
    end
end)

// Hook only exists to get rid of weapons in inventory
hook.Add( "WeaponEquip", "WeaponEquipExample", function( weapon, ply )
    if weapon:GetClass() == "weapon_ttt_yamato" then
        if equipWeapons:GetInt() == 0 then
            canPickUpWeapons = false
            ply:PrintMessage(3 ,"YOU MAY NO LONGER PICK UP WEAPONS")
            for k,v in ipairs(ply:GetWeapons()) do
                local wep = v:GetClass()
                local check = tablecontains(okWeapons, wep)
                if (check == false) then
                    ply:DropWeapon(v)
                end
            end
        end
    end
end )

local function JCcd( ply )
	local timeElapsed = CurTime() - lastOccurance
    if combo < 2 and timeElapsed > .45 and timeElapsed < .65 then
        lastOccurance = CurTime()
        return true
    elseif combo == 2 and timeElapsed > .45 and timeElapsed < .60 then
        lastOccurance = CurTime()
        return true 
    elseif timeElapsed < delay then -- If the time elapsed since the last occurance is less than 2 seconds
        ply:PrintMessage(4, "Judgement Cut Cooldown: " .. math.floor(delay - timeElapsed) .. " seconds left" )
        return false
	else
		lastOccurance = CurTime()
        return true
	end
end

function calcDistance(startpos, hitpos, x, method)
    local vectDiff = Vector( hitpos.x - startpos.x, hitpos.y - startpos.y, 1)
    local perc95
    if method == 1 then 
        perc95 = vectDiff.x * .85
    else 
        perc95 = vectDiff.y * .85
    end
    return perc95 / x
end

function SWEP:Think()
    if self.Owner:KeyReleased(IN_RELOAD) then
        local eyeTrace = self.Owner:GetEyeTrace()
        if eyeTrace.HitWorld == false then 
            local coord1 = eyeTrace.StartPos
            local coord2 = eyeTrace.HitPos
            local vectDirectional = Vector( coord2.x - coord1.x, coord2.y - coord1.y, 1)
            vectDirectional:Normalize()
            local v = Vector( coord1.x + (vectDirectional.x * calcDistance(coord1, coord2, vectDirectional.x, 1)) , coord1.y + (vectDirectional.y * calcDistance(coord1, coord2, vectDirectional.y, 2)), coord1.z)
		    self.Owner:ViewPunch(Angle(5, 0, 0))	
            util.ScreenShake( self.Owner:GetPos(), 3, 3, 0.2, 300 )
            self.Owner:DoAnimationEvent( ACT_LAND ) 
            self.Owner:SetPos(v) 	
            self.Weapon:EmitSound("yamato_tele", 100, 100)
		end
    end
    if self.Owner:KeyPressed(IN_ATTACK2) and JCcd( self.Owner ) == true and SERVER then
        combo = combo + 1
		self.Owner:ViewPunch(Angle(1, 2, 2))
		self.Weapon:SendWeaponAnim(ACT_VM_MISSCENTER)
		self.Weapon:SetNextPrimaryFire(CurTime() + 0.5)
		self.Weapon:SetNextSecondaryFire(CurTime() + 0.5)
		timer.Simple(0.01, function() self:Jcn() self.ent05:SetModelScale( 15,0.005,1 ) self.ent06:SetModelScale( 15,0.005,1 ) end)
				util.ScreenShake( self.Owner:GetEyeTrace().HitPos, 5, 5, 0.3, 300 )

				self.ent05 = ents.Create("prop_dynamic")
				self.ent05:SetModel("models/maxofs2d/hover_rings.mdl")
				self.ent05:SetColor( Color( 120, 110, 255, 250 ) )
				self.ent05:SetMaterial( "models/effects/comball_sphere" )
				self.ent05:SetModelScale( 0,0.02,1 )
				self.ent05:SetPos(self.Owner:GetEyeTrace().HitPos + Vector( 0, 0, 80 ) )
				self.ent05:SetLocalAngles(Angle(0,0,0))		
				self.ent05:Spawn()			
				self.ent05:SetRenderMode( RENDERMODE_TRANSALPHA )

				self.ent06 = ents.Create("prop_dynamic")
				self.ent06:SetModel("models/maxofs2d/hover_rings.mdl")
				self.ent06:SetColor( Color( 29, 0, 255, 150 ) )
				self.ent06:SetMaterial( "models/shiny" )
				self.ent06:SetModelScale( 0,0.02,1 )
				self.ent06:SetPos(self.Owner:GetEyeTrace().HitPos + Vector( 0, 0, 80 ) )
				self.ent06:SetLocalAngles(Angle(0,0,0))
				self.ent06:SetParent(self.ent05)
				self.ent06:Spawn()			
				self.ent06:SetRenderMode( RENDERMODE_TRANSALPHA )
		timer.Simple(0.1, function()  self.ent05:SetModelScale( 0,0.05,1 ) self.ent06:SetModelScale( 0,0.05,1 ) end)
		timer.Simple(0.3, function()  self.ent05:Remove()  self.ent06:Remove() end)
        timer.Simple(5.0, function() combo = 0 end)
	end
end

function SWEP:Jcn()
    self.Owner:DoAttackEvent()
	if IsValid(self.Owner) then
		local k, v
		local dmg = DamageInfo()
			dmg:SetDamage(dmgJCN:GetInt())
			dmg:SetDamageType(DMG_SLASH)
			dmg:SetAttacker(self.Owner)
			dmg:SetInflictor(self.Owner)
		for k, v in pairs ( ents.FindInSphere( self.Owner:GetEyeTrace().HitPos, 150 ) ) do
			if v:IsValid() and v:IsPlayer() and v != self.Owner then
				dmg:SetDamageForce( ( v:GetPos() - self.Owner:GetPos() ):GetNormalized() * 100 )
				v:TakeDamageInfo( dmg )
			end	
		end
	end
end

function SWEP:PrimaryAttack()
    self.Weapon:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

    if not IsValid(self:GetOwner()) then return end

    if self:GetOwner().LagCompensation then -- for some reason not always true
        self:GetOwner():LagCompensation(true)
    end

    local spos = self:GetOwner():GetShootPos()
    local sdest = spos + (self:GetOwner():GetAimVector() * 140)

    local tr_main = util.TraceLine({start=spos, endpos=sdest, filter=self:GetOwner(), mask=MASK_SHOT_HULL})
    local hitEnt = tr_main.Entity
    self.Owner:DoAttackEvent()
    if IsValid(hitEnt) or tr_main.HitWorld then
        local animRando = animLog[math.random(#animLog)]
        self.Weapon:SendWeaponAnim( animRando )

        if not (CLIENT and (not IsFirstTimePredicted())) then
            local edata = EffectData()
            edata:SetStart(spos)
            edata:SetOrigin(tr_main.HitPos)
            edata:SetNormal(tr_main.Normal)
            edata:SetSurfaceProp(tr_main.SurfaceProps)
            edata:SetHitBox(tr_main.HitBox)
            edata:SetEntity(hitEnt)
            if hitEnt:IsPlayer() or hitEnt:GetClass() == "prop_ragdoll" then
            util.Effect("BloodImpact", edata)
            self:GetOwner():LagCompensation(false)
            self:GetOwner():FireBullets({Num=1, Src=spos, Dir=self:GetOwner():GetAimVector(), Spread=Vector(0,0,0), Tracer=0, Force=1, Damage=0})
            else
            util.Effect("Impact", edata)
            end
        end
    else
        local animRando = animLog[math.random(#animLog)]
        self.Weapon:SendWeaponAnim( animRando )
    end


    if CLIENT then
    else
        local tr_all = nil
        tr_all = util.TraceLine({start=spos, endpos=sdest, filter=self:GetOwner()})
        
        self:GetOwner():SetAnimation( PLAYER_ATTACK1 )

        if hitEnt and hitEnt:IsValid() then

            local dmg = DamageInfo()
            dmg:SetDamage(dmgCut:GetInt())
            dmg:SetAttacker(self:GetOwner())
            dmg:SetInflictor(self.Weapon)
            dmg:SetDamageForce(self:GetOwner():GetAimVector() * 1500)
            dmg:SetDamagePosition(self:GetOwner():GetPos())
            dmg:SetDamageType(DMG_SLASH)

            hitEnt:DispatchTraceAttack(dmg, spos + (self:GetOwner():GetAimVector() * 3), sdest)
        else
            if tr_all.Entity and tr_all.Entity:IsValid() then
            self:OpenEnt(tr_all.Entity)
            end
        end
    end

    if self:GetOwner().LagCompensation then
        self:GetOwner():LagCompensation(false)
    end
end