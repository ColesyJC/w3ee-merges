/***********************************************************************/
/** 	© 2015 CD PROJEKT S.A. All rights reserved.
/** 	THE WITCHER® is a trademark of CD PROJEKT S. A.
/** 	The Witcher game is based on the prose of Andrzej Sapkowski.
/***********************************************************************/




class W3Action_Attack extends W3DamageAction
{	
	private var weaponId : SItemUniqueId; 			
	private var crossbowId : SItemUniqueId;			
	private var attackName : name;					
	private var attackTypeName : name;				
	private var isAttackReflected : bool;			
	private var isParried : bool;					
	private var isCountered : bool;					
	private var attackAnimName : name;				
	private var hitTime : float;					
	private var weaponEntity : CItemEntity;			
	private var weaponSlot : name;					
	private var boneIndex : int;					
	private var soundAttackType : name;				
	private var usedZeroStaminaPerk : bool;			
	private var applyBuffsIfParried : bool;			
		
	
	// W3EE - Begin
	private var forceInjury : bool;
	public function SetForceInjury( b : bool )
	{
		forceInjury = b;
	}
	
	public function GetForceInjury() : bool
	{
		return forceInjury;
	}
	
	public function GetCrossbowID() : SItemUniqueId
	{
		return crossbowId;
	}
	// W3EE - End
	
	public function Init( attackr : CGameplayEntity, victm : CGameplayEntity, causr : IScriptable, weapId : SItemUniqueId, attName : name, src :string, hrt : EHitReactionType, canParry : bool, canDodge : bool, skillName : name, swType : EAttackSwingType, swDir : EAttackSwingDirection, isM : bool, isR : bool, isW : bool, isE : bool, optional hitFX_ : name, optional hitBackFX_ : name, optional hitParriedFX_ : name, optional hitBackParriedFX_ : name, optional crossId : SItemUniqueId)
	{		
		var player : CR4Player;
		var powerStat : ECharacterPowerStats;
	
		if(attName == '' || !attackr)
		{
			LogAssert(false, "W3Action_Attack.Init: missing attack data - debug (attack name OR attacker)!");
			return;
		}
		
		
		if(theGame.GetDefinitionsManager().AbilityHasTag(attName, 'UsesSpellPower'))
			powerStat = CPS_SpellPower;
		else
			powerStat = CPS_AttackPower;
		
		
		super.Initialize( attackr, victm, causr, src, hrt, powerStat, isM, isR, isW, isE, hitFX_, hitBackFX_, hitParriedFX_, hitBackParriedFX_);
		
		swingType = swType;
		swingDirection = swDir;
		attackName = attName;
		weaponId = weapId;
		crossbowId = crossId;
		canBeParried = canParry && !attackr.HasAbility( 'UnblockableAttacks' );
		canBeDodged = canDodge;
		soundAttackType = 'empty';
		boneIndex = -1;	
		
		player = (CR4Player)attacker;
		if(IsBasicAttack(skillName) || (player && player.CanUseSkill(SkillNameToEnum(skillName))) )
			attackTypeName = skillName;
		else
			attackTypeName = '';
		
		FillDataFromWeapon();
		FillDataFromAttackName();		
	}
	
	protected function Clear()
	{
		weaponId = GetInvalidUniqueId();
		crossbowId = GetInvalidUniqueId();
		attackName = '';
		attackTypeName = '';
		isAttackReflected = false;
		isParried = false;
		isCountered = false;
		attackAnimName = '';
		hitTime = 0;
		weaponSlot = '';
		soundAttackType = 'empty';
		boneIndex = -1;
		forceExplosionDismemberment = false;
		weaponEntity = NULL;		
	}
	
	
	public function Initialize( att : CGameplayEntity, vict : CGameplayEntity, caus : IScriptable, src : string, hrt : EHitReactionType, pwrStatType : ECharacterPowerStats, isM : bool, isR : bool, isW : bool, isE : bool, optional hitFX_ : name, optional hitBackFX_ : name, optional hitParriedFX_ : name, optional hitBackParriedFX_ : name)
	{
		LogAssert(false, "W3Action_Attack.Initialize: my friend... you are using wrong constructor :P - use Init()");
	}
	
	
	private function FillDataFromWeapon()
	{
		var inv : CInventoryComponent;
		var i, size : int;
		var dmgTypes : array< name >;
		var buffs : array<SEffectInfo>;
		var actorAttacker : CActor;
		var bolt : W3BoltProjectile;
		
		bolt = (W3BoltProjectile)causer;
		inv = attacker.GetInventory();
		
		actorAttacker = ( CActor ) attacker;
		if ( actorAttacker )
		{
			if( bolt )
				size = bolt.GetDTNames(dmgTypes);
			else
				size = inv.GetWeaponDTNames(weaponId, dmgTypes);	
			for( i = 0; i < size; i += 1 )
				AddDamage( dmgTypes[i], actorAttacker.GetTotalWeaponDamage(weaponId, dmgTypes[i], crossbowId, bolt) );
			
			if( bolt )
				size = bolt.GetBoltBuffs(buffs);
			else
				size = inv.GetItemBuffs(weaponId, buffs);
			for( i = 0; i < size; i += 1 )
				AddEffectInfo(buffs[i].effectType, , , buffs[i].effectAbilityName, ,buffs[i].applyChance);
				
			if( theGame.CanLog() && dmgTypes.Size() == 0 && buffs.Size() == 0 )
			{
				LogDMHits( "Weapon " + inv.GetItemName( weaponId ) + " has no damage and no buff stats defined - it will do nothing!" );
			}
		}
	}
	
	
	private function FillDataFromAttackName()
	{
		var attributes, abilities : array<name>;
		var i, size : int;
		var dm : CDefinitionsManagerAccessor;
		var dmgVal : float;
		var dmgAttributeName, abilityName : name;
		var type : EEffectType;
		var min, max : SAbilityAttributeValue;
		var actorAttacker : CActor;	

		actorAttacker = ( CActor ) attacker;
		
		dm = theGame.GetDefinitionsManager();		
		
		
		if(actorAttacker && IsBasicAttack(attackName))
		{
			for (i=0; i<dmgInfos.Size(); i+=1)
			{
				
				dmgAttributeName = GetBasicAttackDamageAttributeName(attackName, dmgInfos[i].dmgType);		
				dmgVal = CalculateAttributeValue(actorAttacker.GetAttributeValue(dmgAttributeName));
				
				if(dmgVal > 0)
					AddDamage(dmgInfos[i].dmgType, dmgVal);

				
				
				
				
			}
		}
				
		
		dm.GetContainedAbilities(attackName, abilities);
		size = abilities.Size();
		for( i = 0; i < size; i += 1 )
		{
			
			if( IsEffectNameValid(abilities[i]) )
			{
				EffectNameToType(abilities[i], type, abilityName);
				AddEffectInfo(type, , , abilityName);
			}
		}
		
		dm.GetContainedAbilities(attackName, attributes);
		size = attributes.Size();
		for( i = 0; i < size; i += 1 )
		{
			
			if( IsDamageTypeNameValid(attributes[i]) )
			{
				dm.GetAbilityAttributeValue(attackName, attributes[i], min, max);
				dmgVal = CalculateAttributeValue(GetAttributeRandomizedValue(min, max));				
				
				if(dmgVal > 0)
					AddDamage(attributes[i], dmgVal);
			}
		}
	}
	
	function AddDamage( dmgType : name, dmgVal : float )
	{		
		if( theGame.GetDefinitionsManager().AbilityHasTag( attackName, theGame.params.ATTACK_NO_DAMAGE ) )
		{
			return;
		}
		
		if ( IsActionMelee() )
		{
			dmgVal = RandRangeF( dmgVal*1.1, dmgVal*0.9 );
		}
		
		super.AddDamage( dmgType, dmgVal );
	}
	
	function AddEffectInfo(effectType : EEffectType, optional duration : float, optional effectCustomValue : SAbilityAttributeValue, optional effectAbilityName : name, optional customParams : W3BuffCustomParams, optional buffApplyChance : float )
	{
		
		if( theGame.GetDefinitionsManager().AbilityHasTag( attackName, theGame.params.ATTACK_NO_DAMAGE ) )
		{
			if(effectType == EET_Bleeding)
				return;
		}
		
		super.AddEffectInfo(effectType, duration, effectCustomValue, effectAbilityName, customParams, buffApplyChance);
	}
	
	public function GetPowerStatBonusAbilityTag() : name		{return attackName;}
	public function GetWeaponId() : SItemUniqueId				{return weaponId;}
	public function SetIsParried(b : bool)						{isParried = b;}
	public function IsParried() : bool							{return isParried;}
	public function SetIsCountered(b : bool)					{isCountered = b;}
	public function IsCountered() : bool						{return isCountered;}
	public function SetAttackAnimName(a : name)					{attackAnimName = a;}
	public function GetAttackAnimName() : name					{return attackAnimName;}
	public function SetHitTime(t : float)						{hitTime = t;}
	public function GetHitTime() : float						{return hitTime;}	
	public function SetWeaponEntity(e : CItemEntity)			{weaponEntity = e;}
	public function GetWeaponEntity() : CItemEntity				{return weaponEntity;}	
	public function SetWeaponSlot(w : name)						{weaponSlot = w;}
	public function GetWeaponSlot() : name						{return weaponSlot;}
	public function SetSoundAttackType(s : name)				{soundAttackType = s;}
	public function GetSoundAttackType() : name					{return soundAttackType;}	
	public function UsedZeroStaminaPerk() : bool				{return usedZeroStaminaPerk;}
	public function SetUsedZeroStaminaPerk()					{usedZeroStaminaPerk = true;}
	public function ApplyBuffsIfParried() : bool				{return applyBuffsIfParried;}
	public function SetApplyBuffsIfParried(b : bool)			{applyBuffsIfParried = b;}
	
	
	public function GetAttackName() : name						{return attackName;}
	
	
	public function GetAttackTypeName() : name					{return attackTypeName;}
	
	
	public function GetPowerStatValue() : SAbilityAttributeValue
	{
		var min, max, result, horseDamageBonus : SAbilityAttributeValue;
		var witcherAttacker : W3PlayerWitcher;
		var temp : name;
		var actorVictim, actorAttacker : CActor;
		var monsterCategory : EMonsterCategory;
		var tmpBool : bool;
		var horse : CNewNPC;
		var horseSpeed, holdRatio : float;
		var i : int;
		var dm : CDefinitionsManagerAccessor;
		var attributes : array<name>;
		var playerAttacker : CPlayer;
		
		result = super.GetPowerStatValue();
		actorVictim = (CActor)victim;
		actorAttacker = (CActor)attacker;		
		
		// W3EE - Begin
		if( actorVictim.IsAttackerAtBack(actorAttacker) )
		{
			min = actorAttacker.GetAttributeValue('damage_from_behind_off');
			if( witcherAttacker && witcherAttacker.inv.IsIdValid(crossbowId) )
				min = witcherAttacker.inv.GetItemAttributeValue(crossbowId, 'damage_from_behind_off');
				
			result.valueMultiplicative += min.valueMultiplicative;
			result -= actorVictim.GetAttributeValue('damage_from_behind_def');
			if( actorVictim.GetInjuryManager().HasInjury(EPI_Spine) )
				result.valueMultiplicative += 0.25f;
			else
				result.valueMultiplicative += 0.1f;
		}
		// W3EE - End
		
		witcherAttacker = (W3PlayerWitcher)attacker;
		if(witcherAttacker)
		{		
			if(witcherAttacker.IsHeavyAttack(attackTypeName) && witcherAttacker.CanUseSkill(S_Sword_2))
				result += witcherAttacker.GetSkillAttributeValue(S_Sword_2, PowerStatEnumToName(CPS_AttackPower), false, true);
				
			if(witcherAttacker.inv.IsIdValid(crossbowId) && witcherAttacker.CanUseSkill(S_Perk_02))
			{				
				result += witcherAttacker.GetSkillAttributeValue(S_Perk_02, PowerStatEnumToName(CPS_AttackPower), false, true);
			}
			
			// W3EE - Begin
			if( witcherAttacker.HasRecentlyCountered() || witcherAttacker.IsCounterAttack(GetAttackName()) )
			{
				min = witcherAttacker.GetAttributeValue('counter_damage_bonus');
				if( witcherAttacker.inv.IsIdValid(crossbowId) )
					min = witcherAttacker.inv.GetItemAttributeValue(crossbowId, 'counter_damage_bonus');
					
				if( witcherAttacker.CanUseSkill(S_Sword_s11) )
					min += witcherAttacker.GetSkillAttributeValue(S_Sword_s11, PowerStatEnumToName(CPS_AttackPower), false, true) * witcherAttacker.GetSkillLevel(S_Sword_s11);
			}
			result.valueMultiplicative += MaxF(min.valueMultiplicative, 0.f);
			
			if( witcherAttacker.IsInState('HorseRiding') )
			{
				result += witcherAttacker.GetAttributeValue('attack_power_horseback');
			}
			// W3EE - End
			
			if(witcherAttacker.IsLightAttack(attackTypeName))
			{
				result += witcherAttacker.GetAttributeValue('attack_power_fast_style');
			}
			
			
			if(witcherAttacker.IsHeavyAttack(attackTypeName))
			{
				result += witcherAttacker.GetAttributeValue('attack_power_heavy_style');
			}
		}
		
		// W3EE - Begin
		if( actorAttacker == thePlayer )
		{
			dm = theGame.GetDefinitionsManager();
			dm.GetAbilityAttributes(attackName, attributes);		
			for(i=0; i<attributes.Size(); i+=1)
			{
				if(PowerStatNameToEnum(attributes[i]) == powerStatType)
				{
					dm.GetAbilityAttributeValue(attackName, attributes[i], min, max);
					result += GetAttributeRandomizedValue(min, max);
					break;
				}
			}
		}
		// W3EE - End
		
		if(result.valueMultiplicative < 0)
			result.valueMultiplicative = 0.001;
		
		return result;
	}
	
	
	public final function GetHitBoneIndex() : int
	{
		var weaponEntity : CItemEntity;
		var weaponSlotMatrix : Matrix;
		var weaponSlotPosition, weaponTipSlotPosition : Vector;
		var i : int;
		var dist, min : float;
		var category : name;
		var cr4HumanoidCombatComponent : CR4HumanoidCombatComponent;
		
		
		if(boneIndex == -1)
		{		
			category = attacker.GetInventory().GetItemCategory(weaponId);
			weaponSlotPosition = MatrixGetTranslation( attacker.GetBoneWorldMatrixByIndex(attacker.GetBoneIndex(weaponSlot)) );
			
			if(category == 'monster_weapon')
			{
				boneIndex = victim.GetRootAnimatedComponent().FindNearestBoneWS(weaponSlotPosition);
			}
			else if(category == 'fist')
			{
			}
			else	
			{
				weaponEntity = attacker.GetInventory().GetItemEntityUnsafe(weaponId);
				if(weaponEntity)
				{
					weaponEntity.CalcEntitySlotMatrix( 'blood_fx_point', weaponSlotMatrix );
					weaponTipSlotPosition = MatrixGetTranslation( weaponSlotMatrix );
					
					cr4HumanoidCombatComponent = (CR4HumanoidCombatComponent)victim.GetComponentByClassName( 'CR4HumanoidCombatComponent' );
					if( cr4HumanoidCombatComponent )
					{
						boneIndex = cr4HumanoidCombatComponent.GetBoneClosestToEdge(weaponSlotPosition, weaponTipSlotPosition);
					}
					else
					{
						boneIndex = victim.GetRootAnimatedComponent().FindNearestBoneToEdgeWS(weaponSlotPosition, weaponTipSlotPosition);
					}
				}
			}
		}
		
		return boneIndex;
	}
}
