/****************************************************************************/
/** Copyright © CD Projekt RED 2015
/** Author : Reaperrz
/****************************************************************************/

class W3EEDamageHandler
{	
	public var pdam, pdamc, pdams, pdamb, pdot, edot, php, pap, eapl, eaph : float;

	private var Perk10Active : bool; default Perk10Active = false;

	public function RefreshSettings()
	{
		var optionHandler : W3EEOptionHandler = Options();
		
		php = optionHandler.SetHealthPlayer();
		pdam  = optionHandler.PlayerDamage();
		pdamc = optionHandler.PlayerDamageCross();
		pdams = optionHandler.PlayerDamageSign();
		pdamb = optionHandler.PlayerDamageBomb();
		pdot = optionHandler.PlayerDOTDamage();
		edot = optionHandler.EnemyDOTDamage();
		pap = optionHandler.GetPlayerAPMult();
		eapl = optionHandler.GetEnemyLightAPMult();
		eaph = optionHandler.GetEnemyHeavyAPMult();
	}
	
	public function SteelMonsterDamage( actorAttacker : CActor, out damageInfo : array< SRawDamage >, monsterCategory : EMonsterCategory, oilInfos : SOilInfo )
	{
		var witcher : W3PlayerWitcher;
		var i, silverDam, steelDam : int;
		var id : SItemUniqueId;
		
		witcher = (W3PlayerWitcher)actorAttacker;
		if( !witcher )
			return;
			
		silverDam = -1; steelDam = -1;
		for(i=0; i<damageInfo.Size(); i+=1)
		{
			if( damageInfo[i].dmgType == 'SilverDamage' )
				silverDam = i;
			else
			if( DamageHitsVitality(damageInfo[i].dmgType) )
				steelDam = i;
				
			if( silverDam >= 0 && steelDam >= 0 )
				break;
		}
		
		if( silverDam == -1 || steelDam == -1 )
			return;
			
		if( witcher.IsWeaponHeld('crossbow') && (monsterCategory == MC_Specter || monsterCategory == MC_Vampire || monsterCategory == MC_Cursed) )
		{
			if ( witcher.inv.GetItemEquippedOnSlot( EES_Bolt, id ) && witcher.inv.ItemHasTag(id, 'Steel_Bolt' ) )
				damageInfo[silverDam].dmgVal = 1.f;
			return;
		}
			
		if( witcher.HasAbility('Runeword 12 _Stats', true) || witcher.HasAbility('Runeword 11 _Stats', true) || witcher.inv.ItemHasTag(witcher.GetHeldSword(), 'Aerondight') )
		{
			if( witcher.IsWeaponHeld('silversword') )
				damageInfo[steelDam].dmgVal *= 2.1f;
			else
				damageInfo[silverDam].dmgVal *= 1.05f;
			return;
		}
		else
		if( (monsterCategory == MC_Specter || monsterCategory == MC_Vampire || monsterCategory == MC_Cursed) && witcher.IsWeaponHeld('steelsword') )
		{
			if( oilInfos.activeIndex[6] )
				damageInfo[silverDam].dmgVal *= oilInfos.attributeValues[6].valueMultiplicative;
			else
				damageInfo[silverDam].dmgVal = 1.f;
		}	
	}
	
	public function NPCSteelMonsterDamage( actorAttacker : CActor, out damageInfo : array< SRawDamage >, monsterCategory : EMonsterCategory )
    {
        var i, silverDam : int;
        var steelDam : float;
        if( ((CR4Player)actorAttacker) || monsterCategory == MC_Specter || monsterCategory == MC_Vampire || monsterCategory == MC_Cursed )
            return;
        
        silverDam = -1; steelDam = -1;
        for(i=0; i<damageInfo.Size(); i+=1)
        {
            if( damageInfo[i].dmgType == 'SilverDamage' )
                silverDam = i;
            else
            if( DamageHitsVitality(damageInfo[i].dmgType) && damageInfo[i].dmgType != 'DirectDamage' )
                steelDam += damageInfo[i].dmgVal;
        }
        
        if( steelDam == -1 )
			return;
			
        if( silverDam == -1 )
        {
			damageInfo.PushBack(SRawDamage('SilverDamage', 1.f, 1.f));
			silverDam = damageInfo.Size() - 1;
		}
		
        if( damageInfo[silverDam].dmgVal < steelDam )
            damageInfo[silverDam].dmgVal = steelDam;
    }

	public function GeraltFistDamage( attackAction : W3Action_Attack, out damageInfo : array<SRawDamage>, monsterCategory : EMonsterCategory )
	{
		var i, steelDam, silverDam : int;
		var witcher : W3PlayerWitcher;
		
		witcher = (W3PlayerWitcher)attackAction.attacker;
		if( !witcher || !attackAction.IsActionMelee() || !witcher.IsWeaponHeld('fist') || monsterCategory == MC_Specter || monsterCategory == MC_Vampire || monsterCategory == MC_Cursed )
			return;
		
		for(i=0; i<damageInfo.Size(); i+=1)
		{
			if( damageInfo[i].dmgType == 'BludgeoningDamage' )
				steelDam = i;
			if( damageInfo[i].dmgType == 'SilverDamage' )
				silverDam = i;
		}
		
		if( monsterCategory == MC_Human || monsterCategory == MC_NotSet || monsterCategory == MC_Beast || monsterCategory == MC_Unused )
			damageInfo[steelDam].dmgVal = 570.f;
		else
			damageInfo[steelDam].dmgVal = 150.f;
		damageInfo[silverDam].dmgVal = 150.f;
	}
	
	public function HookBaseDamage( actorAttacker : CActor, damageAction : W3DamageAction, out damageInfo : array< SRawDamage > )
    {
        var npcAttacker : CNewNPC;
        var sum, mult : float;
        var i : int;
        
        if( (CPlayer)actorAttacker || !actorAttacker || !damageAction || damageAction.WasDamageReturnedToAttacker() || damageAction.IsDoTDamage() )
            return;
        
        npcAttacker = (CNewNPC)actorAttacker;
        for(i=0; i<damageInfo.Size(); i+=1)
            if( damageInfo[i].dmgType != 'SilverDamage' )
                sum += damageInfo[i].dmgVal;
        
        if( (damageAction.IsActionRanged() || damageAction.IsActionEnvironment()) && npcAttacker.GetScaledRangedDamage() )
            mult = npcAttacker.GetScaledRangedDamage() / sum;
        else
            mult = npcAttacker.GetScaledDamage() / sum;
        
        for(i=0; i<damageInfo.Size(); i+=1)
		/* original damage system
		{
			if( damageInfo[i].dmgType != 'SilverDamage' )
				damageInfo[i].dmgVal = npcAttacker.GetScaledDamage();
			else
				damageInfo[i].dmgVal *= mult;
        }
		*/
		{
            if( damageInfo[i].dmgType == 'SilverDamage' )
            {
                damageInfo[i].dmgSplit = 1.f;
                continue;
            }
            
            damageInfo[i].dmgSplit = damageInfo[i].dmgVal / sum;
            damageInfo[i].dmgVal *= mult;
        }
    }
	
	public function PlayerModule( out damageData : W3DamageAction )
	{
		if( thePlayer.IsInFistFightMiniGame() || ((CActor)damageData.victim).IsImmortal() )
			return;
		
		if( (CPlayer)damageData.victim )
		{
			damageData.processedDmg.vitalityDamage /= php;
			damageData.processedDmg.essenceDamage /= php;
			return;
		}
		else
 		if( (CPlayer)damageData.attacker )
		{
			if( damageData.IsActionWitcherSign() && (W3SignProjectile)damageData.causer )
			{
				damageData.processedDmg.vitalityDamage *= pdams;
				damageData.processedDmg.essenceDamage *= pdams;
				return;
			}
			else
			if( damageData.IsActionRanged() && (W3BoltProjectile)damageData.causer )
			{
				damageData.processedDmg.vitalityDamage *= pdamc;
				damageData.processedDmg.essenceDamage *= pdamc;
				return;
			}
			else
			if( damageData.IsActionRanged() && (W3Petard)damageData.causer )
			{
				damageData.processedDmg.vitalityDamage *= pdamb;
				damageData.processedDmg.essenceDamage *= pdamb;
				return;
			}
			else
			{
				damageData.processedDmg.vitalityDamage *= pdam;
				damageData.processedDmg.essenceDamage *= pdam;
				return;
			}
		}
		
	}
	
	public function NPCModule( out damageData : W3DamageAction, actorAttacker : CActor, actorVictim : CActor )
	{
		var npcAttacker, npcVictim : CNewNPC;
		var cachedDamage, cachedHealth : float;
		
		if( actorVictim.IsImmortal() )
			return;
		
		npcAttacker = (CNewNPC)actorAttacker;
		npcVictim = (CNewNPC)actorVictim;
		
		if( npcAttacker && npcAttacker != thePlayer )
		{
			cachedDamage = npcAttacker.GetCachedDamage();
			if( cachedDamage <= 0 )
				cachedDamage = 1;
			damageData.processedDmg.vitalityDamage *= cachedDamage;
			damageData.processedDmg.essenceDamage *= cachedDamage;
		}
		
		if( npcVictim && npcVictim != thePlayer )
		{
			cachedHealth = npcVictim.GetCachedHealth();
			if( cachedHealth <= 0 )
				cachedHealth = 1;
			damageData.processedDmg.vitalityDamage /= cachedHealth;
			damageData.processedDmg.essenceDamage /= cachedHealth;
		}
	}
	
	public function DOTModule( out damageData : W3DamageAction )
	{
		if( thePlayer.IsInFistFightMiniGame() )
			return;
		
		if( (CPlayer)damageData.attacker )
		{
			damageData.processedDmg.vitalityDamage *= pdot;
			damageData.processedDmg.essenceDamage *= pdot;
			return;
		}
		else
		{
			damageData.processedDmg.vitalityDamage *= edot;
			damageData.processedDmg.essenceDamage *= edot;
			return;
		}
	}
	
	public function SetPerk10State( i : bool )
	{
		Perk10Active = i;
	}

	public function GetPerk10State() : bool
	{
		return Perk10Active;
	}

	public function Perk10DamageBoost( out damageData : W3DamageAction )
	{
		if( (CPlayer)damageData.attacker && damageData.IsActionMelee() && Perk10Active )
		{
			damageData.processedDmg.vitalityDamage *= 1.1f;
			damageData.processedDmg.essenceDamage *= 1.1f;
			
			GetWitcherPlayer().AddTimer('ResetPerk10', 0.65f, false,,,,true);
		}
		
		if( (CPlayer)damageData.attacker && thePlayer.CanUseSkill(S_Perk_10) && !Perk10Active )
		{
			SetPerk10State(true);
			GetWitcherPlayer().AddTimer('ResetPerk10', 0.65f, false,,,,true);
		}
	}

	public function ColdBloodDamage( out damageData : W3DamageAction, actorVictim : CActor )
	{
		var skillLevel, i : int;
		var damageMult : float;
		var npcVictim : CNewNPC;
		
		npcVictim = (CNewNPC)actorVictim;
		
		if( thePlayer.IsWeaponHeld('crossbow') && thePlayer.CanUseSkill(S_Sword_s15) && npcVictim && npcVictim != thePlayer)
		{
			if 	( 	actorVictim.HasBuff(EET_Immobilized) || 
					actorVictim.HasBuff(EET_Burning) || 
					actorVictim.HasBuff(EET_Knockdown) || 
					actorVictim.HasBuff(EET_HeavyKnockdown) || 
					actorVictim.HasBuff(EET_Blindness) || 
					actorVictim.HasBuff(EET_Confusion) || 
					actorVictim.HasBuff(EET_Paralyzed) || 
					actorVictim.HasBuff(EET_Hypnotized) || 
					actorVictim.HasBuff(EET_Stagger) || 
					actorVictim.HasBuff(EET_LongStagger) ||
					actorVictim.HasBuff(EET_Tangled) ||
					actorVictim.HasBuff(EET_Ragdoll) ||
					actorVictim.HasBuff(EET_Frozen) ||
					actorVictim.HasBuff(EET_Trap) ||
					actorVictim.HasBuff(EET_KnockdownTypeApplicator) ||
					actorVictim.HasBuff(EET_CounterStrikeHit) 
				)
			{
				skillLevel = thePlayer.GetSkillLevel(S_Sword_s15);
				
				damageData.processedDmg.vitalityDamage *= skillLevel * 0.3f + 1;
				damageData.processedDmg.essenceDamage *= skillLevel * 0.3f + 1;
			}
		}
	}
	
	public function WeatherDamageMultiplier( out damageInfo : array<SRawDamage>, actorVictim : CActor )
	{
		var curGameTime : GameTime;
		var dayPart : EDayPart;
		var moonState : EMoonState;
		var weather : EWeatherEffect;
		var i : int;
		
		moonState = GetCurMoonState();
		curGameTime = GameTimeCreate();
		dayPart = GetDayPart(curGameTime);
		weather = GetCurWeather();
		
		switch( dayPart )
		{
			case ( EDP_Midnight) :
				//if( /moonState != EMS_NotFull )
				{
					if ( moonState == EMS_Red )
					{
						for( i=0; i<damageInfo.Size(); i+=1 )
						{
							if( damageInfo[i].dmgType == 'ElementalDamage' )	damageInfo[i].dmgVal *= 1.40f;
							if( damageInfo[i].dmgType == 'SilverDamage' )		damageInfo[i].dmgVal *= 0.80f;
						}
					}
					else
					if( moonState == EMS_Full )
					{
						for( i=0; i<damageInfo.Size(); i+=1 )
						{
							if( damageInfo[i].dmgType == 'ElementalDamage' )	damageInfo[i].dmgVal *= 1.15f;
							if( damageInfo[i].dmgType == 'SilverDamage' )		damageInfo[i].dmgVal *= 1.05f;
						}
					}
					else
						for( i=0; i<damageInfo.Size(); i+=1 )
							if( damageInfo[i].dmgType == 'ElementalDamage' )	damageInfo[i].dmgVal *= 1.10f;
				}
			break;
			case ( EDP_Noon ) :
				if ( weather == EWE_Clear )
					for( i=0; i<damageInfo.Size(); i+=1 )
						if( damageInfo[i].dmgType == 'FrostDamage' )	damageInfo[i].dmgVal *= 0.95f;
				for( i=0; i<damageInfo.Size(); i+=1 )
					if( damageInfo[i].dmgType == 'ElementalDamage' )	damageInfo[i].dmgVal *= 0.90f;
			break;
			default : break;
		}
		
		switch ( weather )
		{
			case ( EWE_Rain ) :
				for( i=0; i<damageInfo.Size(); i+=1 )
				{
					if( damageInfo[i].dmgType == 'ShockDamage' )	damageInfo[i].dmgVal *= 1.10f;
					if( damageInfo[i].dmgType == 'FireDamage' )		damageInfo[i].dmgVal *= 0.90f;
					if( damageInfo[i].dmgType == 'FrostDamage' )	damageInfo[i].dmgVal *= 1.05f;
				}			
			break;
			case ( EWE_Storm ) :
				for( i=0; i<damageInfo.Size(); i+=1 )
				{
					if( damageInfo[i].dmgType == 'ShockDamage' )	damageInfo[i].dmgVal *= 1.15f;
					if( damageInfo[i].dmgType == 'FireDamage' )		damageInfo[i].dmgVal *= 0.80f;
					if( damageInfo[i].dmgType == 'FrostDamage' )	damageInfo[i].dmgVal *= 1.10f;
				}
			break;
			case ( EWE_Snow ) :
				for( i=0; i<damageInfo.Size(); i+=1 )
				{
					if( damageInfo[i].dmgType == 'FireDamage' )		damageInfo[i].dmgVal *= 0.85f;
					if( damageInfo[i].dmgType == 'FrostDamage' )	damageInfo[i].dmgVal *= 1.15f;
				}
			break;
		}
		
		for( i=0; i<damageInfo.Size(); i+=1 )
			damageInfo[i].dmgVal *= actorVictim.GetDamageTakenMultiplier();
	}
}