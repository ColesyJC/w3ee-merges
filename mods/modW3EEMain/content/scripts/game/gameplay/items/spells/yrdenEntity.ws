/***********************************************************************/
/** 	© 2015 CD PROJEKT S.A. All rights reserved.
/** 	THE WITCHER® is a trademark of CD PROJEKT S. A.
/** 	The Witcher game is based on the prose of Andrzej Sapkowski.
/***********************************************************************/




struct SYrdenEffects
{
	editable var castEffect		: name;
	editable var placeEffect	: name;
	editable var shootEffect	: name;
	editable var activateEffect : name;
}

statemachine class W3YrdenEntity extends W3SignEntity
{
	editable var effects		: array< SYrdenEffects >;
	editable var projTemplate	: CEntityTemplate;
	editable var projDestroyFxEntTemplate : CEntityTemplate;
	editable var runeTemplates	: array< CEntityTemplate >;

	protected var validTargetsInArea, allActorsInArea : array< CActor >;
	protected var flyersInArea	: array< CNewNPC >;
	
	protected var trapDuration	: float;
	protected var charges		: int;
	protected var isPlayerInside : bool;
	protected var baseModeRange : float;
	
	public var notFromPlayerCast : bool;
	public var fxEntities : array< CEntity >;
	
	default skillEnum = S_Magic_3;

	// W3EE - Begin
	protected var creatorPowerStatVal : SAbilityAttributeValue;
	protected var yrdenAbilityKey : string;
	protected var affectedNPCs : array<CNewNPC>;
	
	public function Init( inOwner : W3SignOwner, prevInstance : W3SignEntity, optional skipCastingAnimation : bool, optional notPlayerCast : bool, optional isFreeCast : bool ) : bool
	// W3EE - End
	{
		notFromPlayerCast = notPlayerCast;
		
		// W3EE - Begin
		CacheSignStats(inOwner);
		
		affectedNPCs.Clear();
		creatorPowerStatVal = GetTotalSignIntensity();
		return super.Init(inOwner, prevInstance, skipCastingAnimation, notPlayerCast, isFreeCast);
		// W3EE - End
	}
		
	public function GetSignType() : ESignType
	{
		return ST_Yrden;
	}
		
	public function GetIsPlayerInside() : bool
	{
		return isPlayerInside;
	}
	
	public function SkillUnequipped(skill : ESkill)
	{
		/*var i : int;
	
		super.SkillUnequipped(skill);
		
		if(skill == S_Magic_s11)
		{
			for(i=0; i<validTargetsInArea.Size(); i+=1)
				validTargetsInArea[i].RemoveBuff( EET_YrdenHealthDrain );
		}*/
	}
	
	public function IsValidTarget( target : CActor ) : bool
	{
		return target && target.GetHealth() > 0.f && target.GetAttitude( owner.GetActor() ) == AIA_Hostile;
	}
	
	public function SkillEquipped(skill : ESkill)
	{
		/*var i : int;
		var params : SCustomEffectParams;
	
		super.SkillEquipped(skill);
	
		if(skill == S_Magic_s11)
		{
			params.effectType = EET_YrdenHealthDrain;
			params.creator = owner.GetActor();
			params.sourceName = "yrden_mode0";
			params.isSignEffect = true;
			
			for(i=0; i<validTargetsInArea.Size(); i+=1)
				validTargetsInArea[i].AddEffectCustom(params);
		}*/
	}

	event OnProcessSignEvent( eventName : name )
	{
		if ( eventName == 'yrden_draw_ready' )
		{
			PlayEffect( 'yrden_cast' );
		}
		else
		{
			return super.OnProcessSignEvent(eventName);
		}
		
		return true;
	}
	
	public final function ClearActorsInArea()
	{
		var i : int;
		
		for(i=0; i<validTargetsInArea.Size(); i+=1)
			validTargetsInArea[i].SignalGameplayEventParamObject('LeavesYrden', this );
		
		validTargetsInArea.Clear();
		flyersInArea.Clear();
		allActorsInArea.Clear();
	}
	
	protected function GetSignStats()
	{
		// W3EE - Begin
		var sp : SAbilityAttributeValue;
		
		super.GetSignStats();
		
		//chargesAtt = owner.GetSkillAttributeValue(skillEnum, 'charge_count', false, true);
		//trapDurationAtt = owner.GetSkillAttributeValue(skillEnum, 'trap_duration', false, true);
		baseModeRange = CalculateAttributeValue( owner.GetSkillAttributeValue(skillEnum, 'range', false, true) );
		
		sp = super.GetTotalSignIntensity();
		
		charges = 3;
		trapDuration = 30.f;
		if (owner.GetSkillLevel(S_Magic_s10, this) >= 1)
			trapDuration += (owner.GetSkillLevel(S_Magic_s10, this) + 1) * 5;
		trapDuration *= sp.valueMultiplicative;
		// W3EE - End
	}
	
	event OnStarted()
	{
		var player : CR4Player;
		
		Attach(true, true);
		
		player = (CR4Player)owner.GetActor();
		if(player)
		{
			GetWitcherPlayer().FailFundamentalsFirstAchievementCondition();
			player.AddTimer('ResetPadBacklightColorTimer', 2);
		}
		
		PlayEffect( 'cast_yrden' );
		
		if ( owner.ChangeAspect( this, S_Magic_s03 ) )
		{
			CacheActionBuffsFromSkill();
			GotoState( 'YrdenChanneled' );
		}
		else
		{
			GotoState( 'YrdenCast' );
		}
	}
	
	
	protected latent function Place(trapPos : Vector)
	{
		var trapPosTest, trapPosResult, collisionNormal, scale : Vector;
		var rot : EulerAngles;
		var witcher : W3PlayerWitcher;
		var trigger : CComponent;
		var min, max : SAbilityAttributeValue;
		
		witcher = GetWitcherPlayer();
		witcher.yrdenEntities.PushBack(this);
		
		DisablePreviousYrdens();
		
		if( GetWitcherPlayer().IsSetBonusActive( EISB_Gryphon_2 ) )
		{
			trigger = GetComponent( "Slowdown" );
			scale = trigger.GetLocalScale() * (1.5f + 0.1f * owner.GetSkillLevel(S_Magic_s10, this));
			
			trigger.SetScale( scale );
		}
		else if(owner.CanUseSkill(S_Magic_s10, this))
		{
			trigger = GetComponent( "Slowdown" );
			scale = trigger.GetLocalScale() * (1.f + 0.1f * owner.GetSkillLevel(S_Magic_s10, this));
			
			trigger.SetScale( scale );
		}
		
		Detach();
		
		
		SleepOneFrame();
		
		
		trapPosTest = trapPos;
		trapPosTest.Z -= 0.5;		
		rot = GetWorldRotation();
		rot.Pitch = 0;
		rot.Roll = 0;
		
		if(theGame.GetWorld().StaticTrace(trapPos, trapPosTest, trapPosResult, collisionNormal))
		{
			trapPosResult.Z += 0.1;	
			TeleportWithRotation ( trapPosResult, rot );
		}
		else
		{
			TeleportWithRotation ( trapPos, rot );
		}
		
		
		SleepOneFrame();
		
		AddTimer('TimedCanceled', trapDuration, , , , true);
		
		if(!notFromPlayerCast)
			owner.GetActor().OnSignCastPerformed(ST_Yrden, fireMode);
	}
	
	private final function DisablePreviousYrdens()
	{
		var maxCount, i, size, currCount : int;
		var isAlternate : bool;
		var witcher : W3PlayerWitcher;
		
		
		isAlternate = IsAlternateCast();
		witcher = GetWitcherPlayer();
		size = witcher.yrdenEntities.Size();
		
		
		maxCount = 1;
		currCount = 0;
		
		/*if(!isAlternate && owner.CanUseSkill(S_Magic_s10, this) && owner.GetSkillLevel(S_Magic_s10, this) >= 2)
		{
			maxCount += 1;
		}*/
		
		for(i=size-1; i>=0; i-=1)
		{
			
			if(!witcher.yrdenEntities[i])
			{
				witcher.yrdenEntities.Erase(i);		
				continue;
			}
			
			if(witcher.yrdenEntities[i].IsAlternateCast() == isAlternate)
			{
				currCount += 1;
				
				
				if(currCount > maxCount)
				{
					witcher.yrdenEntities[i].OnSignAborted(true);
				}
			}
		}
	}
	
	// W3EE - Begin
	private function GetYrdenCircle() : W3YrdenEntityStateYrdenSlowdown
	{
		return (W3YrdenEntityStateYrdenSlowdown)GetState('YrdenSlowdown');
	}
	
	private function ClearYrdenEffects()
	{
		var i : int;
		for(i=0; i<affectedNPCs.Size(); i+=1)
		{
			affectedNPCs[i].RemoveAllBuffsWithSource(yrdenAbilityKey);
		}
	}
	
	timer function TimedCanceled( delta : float , id : int)
	{
		var i : int;
		var areas : array<CComponent>;
		
		ClearYrdenEffects();
		
		super.CleanUp();
		StopAllEffects();
		
		
		areas = GetComponentsByClassName('CTriggerAreaComponent');
		for(i=0; i<areas.Size(); i+=1)
			areas[i].SetEnabled(false);
		
		/*for(i=0; i<validTargetsInArea.Size(); i+=1)
		{
			//validTargetsInArea[i].BlockAbility('Flying', false);
			validTargetsInArea[i].RemoveAllBuffsWithSource(yrdenAbilityKey);
			GetYrdenCircle().ExitYrdenCircle(validTargetsInArea[i]);
		}*/
		
		if( isPlayerInside )
		{
			GetYrdenCircle().ExitYrdenCircle(owner.GetPlayer());
		}
		
		isPlayerInside = false;
		
		for( i=0; i<fxEntities.Size(); i+=1 )
		{
			fxEntities[i].StopAllEffects();
			fxEntities[i].DestroyAfter( 5.f );
		}
		
		UpdateGryphonSetBonusYrdenBuff();
		ClearActorsInArea();
		DestroyAfter(3);
	}
	// W3EE - End
	
	
	protected function NotifyGameplayEntitiesInArea( componentName : CName )
	{
		var entities : array<CGameplayEntity>;
		var triggerAreaComp : CTriggerAreaComponent;
		var i : int;
		var ownerActor : CActor;
		
		ownerActor = owner.GetActor();
		triggerAreaComp = (CTriggerAreaComponent)this.GetComponent( componentName );
		triggerAreaComp.GetGameplayEntitiesInArea( entities, 6.0 );
		
		for ( i=0 ; i < entities.Size() ; i+=1 )
		{
			if( !((CActor)entities[i]) )
				entities[i].OnYrdenHit( ownerActor );
		}
	}
	
	event OnVisualDebug( frame : CScriptedRenderFrame, flag : EShowFlags, selected : bool )
	{
	}
	
	protected function UpdateGryphonSetBonusYrdenBuff()
	{
		var player : W3PlayerWitcher;
		var i : int;
		var isPlayerInYrden, hasBuff : bool;
		
		player = GetWitcherPlayer();
		hasBuff = player.HasBuff( EET_GryphonSetBonusYrden );
		
		/*if ( player.IsSetBonusActive( EISB_Gryphon_2 ) ) 
		{*/
			isPlayerInYrden = false;
			
			for( i=0 ; i < player.yrdenEntities.Size() ; i+=1 )
			{
				if( !player.yrdenEntities[i].IsAlternateCast() && player.yrdenEntities[i].isPlayerInside )
				{
					isPlayerInYrden = true;
					break;
				}
			}
			
			if( isPlayerInYrden && !hasBuff )
			{
				player.AddEffectDefault( EET_GryphonSetBonusYrden, NULL, "GryphonSetBonusYrden" );
			}
			else if( !isPlayerInYrden && hasBuff )
			{
				player.RemoveBuff( EET_GryphonSetBonusYrden, false, "GryphonSetBonusYrden" );
			}
		/*}
		else if( hasBuff )
		{
			player.RemoveBuff( EET_GryphonSetBonusYrden, false, "GryphonSetBonusYrden" );
		}*/
	}
}

state YrdenCast in W3YrdenEntity extends NormalCast
{
	event OnThrowing()
	{
		if( super.OnThrowing() )
		{
			parent.CleanUp();	
			parent.StopEffect( 'yrden_cast' );			
			parent.GotoState( 'YrdenSlowdown' );
		}
	}
}

state YrdenChanneled in W3YrdenEntity extends Channeling
{
	event OnEnterState( prevStateName : name )
	{
		super.OnEnterState( prevStateName );
		
		caster.OnDelayOrientationChange();
		// W3EE - Begin
		//caster.GetActor().PauseStaminaRegen( 'SignCast' );
		// W3EE - End
		ChannelYrden();
	}
	
	event OnThrowing()
	{
		if( super.OnThrowing() )
		{
			parent.CleanUp();	
		}
		
		parent.StopEffect( 'yrden_cast' );
		
		// W3EE - Begin
		//caster.GetActor().ResumeStaminaRegen( 'SignCast' );
		// W3EE - End
		
		parent.GotoState( 'YrdenShock' );
	}
	
	event OnEnded(optional isEnd : bool)
	{
	}
	
	event OnSignAborted( optional force : bool )
	{
		if ( caster.IsPlayer() )
		{
			caster.GetPlayer().LockToTarget( false );
		}
		
		parent.AddTimer('TimedCanceled', 0, , , , true);
		
		super.OnSignAborted( force );
	}		
	
	private var timeStamp : float;	default timeStamp = 0;
	entry function ChannelYrden()
	{
	// W3EE - Begin
		var DT : float = 0.006f;
		timeStamp = theGame.GetEngineTimeAsSeconds();
		while( Update(DT) )
		{
			Sleep(DT);
			DT = theGame.GetEngineTimeAsSeconds() - timeStamp;
			timeStamp = theGame.GetEngineTimeAsSeconds();
		}
		
		OnSignAborted();
	// W3EE - End
	}
}


state YrdenShock in W3YrdenEntity extends Active
{
	private var usedShockAreaName : name;
	
	event OnEnterState( prevStateName : name )
	{
		// W3EE - Begin
		//var skillLevel : int;
		var triggerArea : CComponent;
		var areaScale : Vector;
		
		super.OnEnterState( prevStateName );
		
		/*skillLevel = caster.GetSkillLevel(parent.skillEnum, (W3SignEntity)parent);
		
		if(skillLevel == 1)
			usedShockAreaName = 'Shock_lvl_1';
		else if(skillLevel == 2)
			usedShockAreaName = 'Shock_lvl_2';
		else if(skillLevel == 3)
			usedShockAreaName = 'Shock_lvl_3';*/
			
		usedShockAreaName = 'Shock_lvl_1';
		
		triggerArea = parent.GetComponent(usedShockAreaName);
		triggerArea.SetEnabled(true);
		
		areaScale = triggerArea.GetLocalScale() * (1 + 0.05f * caster.GetSkillLevel(S_Magic_s10, (W3SignEntity)parent));
		triggerArea.SetScale(areaScale);		
		ActivateShock();
		parent.NotifyGameplayEntitiesInArea( usedShockAreaName );
		
		if( caster.GetPlayer() )
			Experience().AwardSignXP(parent.GetSignType());
		// W3EE - End
	}
	
	// W3EE - Begin
	public function GetParent() : W3YrdenEntity
	{
		return parent;
	}
	// W3EE - End
	
	event OnLeaveState( nextStateName : name )
	{
		parent.GetComponent(usedShockAreaName).SetEnabled( false );
		parent.ClearActorsInArea();
	}
	
	entry function ActivateShock()
	{
		var i, size : int;
		var target : CActor;
		var hitEntity : CEntity;
		var shot, validTargetsUpdated : bool;
		
		parent.Place(parent.GetWorldPosition());
		
		parent.PlayEffect( parent.effects[parent.fireMode].placeEffect );
		parent.PlayEffect( parent.effects[parent.fireMode].castEffect );
	}
	
	event OnAreaEnter( area : CTriggerAreaComponent, activator : CComponent )
	{
		var target : CNewNPC;		
		var projectile : CProjectileTrajectory;		
		
		target = (CNewNPC)(activator.GetEntity());
		
		if( target && !parent.allActorsInArea.Contains( target ) )
		{
			parent.allActorsInArea.PushBack( target );
		}
		
		if ( parent.charges && parent.IsValidTarget( target ) && !parent.validTargetsInArea.Contains(target) )
		{
			if( parent.validTargetsInArea.Size() == 0 )
			{
				parent.PlayEffect( parent.effects[parent.fireMode].activateEffect );
			}
			
			parent.validTargetsInArea.PushBack( target );			
			
			target.OnYrdenHit( caster.GetActor() );
			
			target.SignalGameplayEventParamObject('EntersYrden', parent );
		}		
		else if(parent.projDestroyFxEntTemplate)
		{
			projectile = (CProjectileTrajectory)activator.GetEntity();
			
			if(projectile && !((W3SignProjectile)projectile) && IsRequiredAttitudeBetween(caster.GetActor(), projectile.caster, true, true, false))
			{
				if(projectile.IsStopped())
				{
					
					projectile.SetIsInYrdenAlternateRange(parent);
				}
				else
				{			
					ShootDownProjectile(projectile);
				}
			}
		}
	}
	
	public final function ShootDownProjectile(projectile : CProjectileTrajectory)
	{
		var hitEntity, fxEntity : CEntity;
		
		hitEntity = ShootTarget(projectile, false, 0.1f, true);
					
		
		if(hitEntity == projectile || !hitEntity)
		{
			
			fxEntity = theGame.CreateEntity( parent.projDestroyFxEntTemplate, projectile.GetWorldPosition() );
			
			
			
			if(!hitEntity)
			{
				parent.PlayEffect( parent.effects[1].shootEffect );		
				parent.PlayEffect( parent.effects[1].shootEffect, fxEntity );
			}
			
			projectile.StopProjectile();
			projectile.Destroy();			
		}
	}
	
	event OnAreaExit( area : CTriggerAreaComponent, activator : CComponent )
	{
		var target : CNewNPC;
		var projectile : CProjectileTrajectory;
		
		target = (CNewNPC)(activator.GetEntity());
		
		if ( target && parent.charges && target.GetAttitude( thePlayer ) == AIA_Hostile )
		{
			parent.validTargetsInArea.Erase( parent.validTargetsInArea.FindFirst( target ) );
			target.SignalGameplayEventParamObject('LeavesYrden', parent );
		}
		
		if ( parent.validTargetsInArea.Size() <= 0 )
		{
			parent.StopEffect( parent.effects[parent.fireMode].activateEffect );
		}
	}
	
	public function SetWardingGlyphTargets( target : CNewNPC )
	{
		if( target.CanGlyphHit() )
		{
			ShootTarget((CActor)target, true, 0.2f, false);
			target.SetCanGlyphHit(false);
			target.AddTimer('StartGlyphCooldown', 6 - FloorF(caster.GetSkillLevel(S_Magic_s03, (W3SignEntity)parent)) / 2.f, false);
		}
	}
	
	var traceFrom, traceTo : Vector;
	private function ShootTarget( targetNode : CNode, useTargetsPositionCorrection : bool, extraRayCastLengthPerc : float, useProjectileGroups : bool ) : CEntity
	{
		var results : array<SRaycastHitResult>;
		var i, ind : int;
		var min : float;
		var collisionGroupsNames : array<name>;
		var entity : CEntity;
		var targetActor : CActor;
		var targetPos : Vector;
		var physTest : bool;
		
		traceFrom = virtual_parent.GetWorldPosition();
		traceFrom.Z += 1.f;
		
		targetPos = targetNode.GetWorldPosition();
		traceTo = targetPos;
		if(useTargetsPositionCorrection)
			traceTo.Z += 1.f;
		
		traceTo = traceFrom + (traceTo - traceFrom) * (1.f + extraRayCastLengthPerc);
		
		collisionGroupsNames.PushBack( 'RigidBody' );
		collisionGroupsNames.PushBack( 'Static' );
		collisionGroupsNames.PushBack( 'Debris' );	
		collisionGroupsNames.PushBack( 'Destructible' );	
		collisionGroupsNames.PushBack( 'Terrain' );
		collisionGroupsNames.PushBack( 'Phantom' );
		collisionGroupsNames.PushBack( 'Water' );
		collisionGroupsNames.PushBack( 'Boat' );		
		collisionGroupsNames.PushBack( 'Door' );
		collisionGroupsNames.PushBack( 'Platforms' );
		
		if(useProjectileGroups)
		{
			collisionGroupsNames.PushBack( 'Projectile' );
		}
		else
		{			
			collisionGroupsNames.PushBack( 'Character' );			
		}
		
		physTest = theGame.GetWorld().GetTraceManager().RayCastSync(traceFrom, traceTo, results, collisionGroupsNames);

		if ( !physTest || results.Size() == 0 )
			FindActorsAtLine( traceFrom, traceTo, 0.05f, results, collisionGroupsNames );
		
		if ( results.Size() > 0 )
		{
			
			while(results.Size() > 0)
			{
				
				min = results[0].distance;
				ind = 0;
				
				for(i=1; i<results.Size(); i+=1)
				{
					if(results[i].distance < min)
					{
						min = results[i].distance;
						ind = i;
					}
				}
				
				
				if(results[ind].component)
				{
					entity = results[ind].component.GetEntity();
					targetActor = (CActor)entity;
					
					
					if(targetActor && IsRequiredAttitudeBetween(targetActor, caster.GetActor(), false, false, true))
						return NULL;
					
					// W3EE - Begin
					if( (targetActor && targetActor.GetHealth() > 0.f && targetActor.IsAlive() && parent.validTargetsInArea.Contains(targetActor)) || (!targetActor && entity) )
					// W3EE - End
					{
						
						YrdenTrapHitEnemy(targetActor, results[ind].position);						
						return entity;
					}
					else if(targetActor)
					{
						
						results.EraseFast(ind);
					}
				}
				else
				{
					break;
				}
			}
		}
		
		return NULL;
	}
	
	// W3EE - Begin
	private final function YrdenTrapHitEnemy(entity : CEntity, hitPosition : Vector)
	{
		var component : CComponent;
		var targetActor, casterActor : CActor;
		var action : W3DamageAction;
		var player : W3PlayerWitcher;
		var skillType : ESkill;
		var skillLevel, i : int;
		var damageBonusFlat : float;		
		var damages : array<SRawDamage>;
		var glyphwordY : W3YrdenEntity;
		var sp : SAbilityAttributeValue;
		
		parent.StopEffect( parent.effects[parent.fireMode].castEffect );
		parent.PlayEffect( parent.effects[parent.fireMode].shootEffect );
		parent.PlayEffect( parent.effects[parent.fireMode].castEffect );
			
		targetActor = (CActor)entity;
		if(targetActor)
		{
			component = targetActor.GetComponent('torso3effect');		
			if ( component )
			{
				parent.PlayEffect( parent.effects[parent.fireMode].shootEffect, component );
			}
		}
		
		if(!targetActor || !component)
		{
			parent.PlayEffect( parent.effects[parent.fireMode].shootEffect, entity );
		}
		
		//parent.charges -= 1;
		
		casterActor = caster.GetActor();
		if ( casterActor && (CGameplayEntity)entity)
		{
			
			action =  new W3DamageAction in theGame.damageMgr;
			player = caster.GetPlayer();
			skillType = virtual_parent.GetSkill();
			skillLevel = caster.GetSkillLevel(skillType, (W3SignEntity)parent);
			
			
			action.Initialize( casterActor, (CGameplayEntity)entity, this, casterActor.GetName()+"_sign", EHRT_Light, CPS_SpellPower, false, false, true, false, 'yrden_shock', 'yrden_shock', 'yrden_shock', 'yrden_shock');
			virtual_parent.InitSignDataForDamageAction(action);
			action.hitLocation = hitPosition;
			action.SetCanPlayHitParticle(true);
			
			
			if(player && skillLevel >= 1)
			{
				sp = parent.GetTotalSignIntensity();
				damages.PushBack(SRawDamage(theGame.params.DAMAGE_NAME_ELEMENTAL, (250 + 50 * caster.GetSkillLevel(S_Magic_s03, (W3SignEntity)parent)) * sp.valueMultiplicative));
				action.ClearDamage();
				
				for(i=0; i<damages.Size(); i+=1)
				{
					action.AddDamage(damages[i].dmgType, damages[i].dmgVal);
				}
			}
			
			Combat().EnchantedGlyphsAlt(action, parent);
			action.AddEffectInfo(EET_GlyphDebuff, 5);
			
			theGame.damageMgr.ProcessAction( action );
		}
		else
		{
			entity.PlayEffect( 'yrden_shock' );
		}
	}
	// W3EE - End
	
	event OnThrowing()
	{
		parent.CleanUp();	
	}
	
	event OnVisualDebug( frame : CScriptedRenderFrame, flag : EShowFlags, selected : bool )
	{
		frame.DrawLine(traceFrom, traceTo, Color(255, 255, 0));
	}
}

state YrdenSlowdown in W3YrdenEntity extends Active
{
	event OnEnterState( prevStateName : name )
	{
		var player				: CR4Player;
		
		super.OnEnterState( prevStateName );
		
		parent.GetComponent( 'Slowdown' ).SetEnabled( true );
		parent.PlayEffect( 'yrden_slowdown_sound' );
		
		ActivateSlowdown();
		
		if(!parent.notFromPlayerCast)
		{
			player = caster.GetPlayer();
			
			if( player )
			{
				parent.ManagePlayerStamina();
				parent.ManageGryphonSetBonusBuff();
				// W3EE - Begin
				if( caster.GetPlayer() )
					Experience().AwardSignXP(parent.GetSignType());
				// W3EE - End
			}
			else
			{
				caster.GetActor().DrainStamina( ESAT_Ability, 0, 0, SkillEnumToName( parent.skillEnum ) );
			}
		}
	}
	
	event OnLeaveState( nextStateName : name )
	{
		CleanUp();
		parent.GetComponent('Slowdown').SetEnabled( false );
		parent.ClearActorsInArea();
	}
	
	private function CleanUp()
	{
		var i, size : int;
		
		size = parent.validTargetsInArea.Size();
		for( i = 0; i < size; i += 1 )
		{
			ExitYrdenCircle(parent.validTargetsInArea[i]);
		}
		
		for( i=0; i<virtual_parent.fxEntities.Size(); i+=1 )
		{
			virtual_parent.fxEntities[i].StopAllEffects();
			virtual_parent.fxEntities[i].DestroyAfter( 5.f );
		}
	}
	
	event OnThrowing()
	{
		parent.CleanUp();	
	}
	
	event OnSignAborted( force : bool )
	{
		if( force )
			CleanUp();
		
		parent.AddTimer('TimedCanceled', 0, , , , true);
		
		super.OnSignAborted( force );
	}
	
	entry function ActivateSlowdown()
	{
		var obj : CEntity;
		var pos : Vector;
		
		obj = (CEntity)parent;
		pos = obj.GetWorldPosition();
		parent.Place(pos);
		
		CreateTrap();
		
		theGame.GetBehTreeReactionManager().CreateReactionEvent( parent, 'YrdenCreated', parent.trapDuration, 30, 0.1f, 999, true );
		parent.NotifyGameplayEntitiesInArea( 'Slowdown' );
		// YrdenSlowdown_Loop();
	}
	
	// W3EE - Begin
	private function CreateTrap()
	{
		var i, size : int;
		var worldPos : Vector;
		var isSetBonus2Active : bool;
		var worldRot : EulerAngles;
		var polarAngle, yrdenRange, unitAngle : float;
		var runePositionLocal, runePositionGlobal : Vector;
		var entity : CEntity;
		var min, max : SAbilityAttributeValue;
		
		isSetBonus2Active = GetWitcherPlayer().IsSetBonusActive( EISB_Gryphon_2 );
		worldPos = virtual_parent.GetWorldPosition();
		worldRot = virtual_parent.GetWorldRotation();
		yrdenRange = virtual_parent.baseModeRange;
		size = virtual_parent.runeTemplates.Size();
		unitAngle = 2 * Pi() / size;
		
		if( isSetBonus2Active )
		{
			yrdenRange *= (1.5f + 0.1f * thePlayer.GetSkillLevel(S_Magic_s10));
		}
		else if(thePlayer.CanUseSkill(S_Magic_s10))
		{
			yrdenRange *= (1.f + 0.1f * thePlayer.GetSkillLevel(S_Magic_s10));
		}
		
		for( i=0; i<size; i+=1 )
		{
			polarAngle = unitAngle * i;
			
			runePositionLocal.X = yrdenRange * CosF( polarAngle );
			runePositionLocal.Y = yrdenRange * SinF( polarAngle );
			runePositionLocal.Z = 0.f;
			
			runePositionGlobal = worldPos + runePositionLocal;			
			runePositionGlobal = TraceFloor( runePositionGlobal );
			runePositionGlobal.Z += 0.05f;		
			
			entity = theGame.CreateEntity( virtual_parent.runeTemplates[i], runePositionGlobal, worldRot );
			virtual_parent.fxEntities.PushBack( entity );
		}
	}
	
	/*entry function YrdenSlowdown_Loop()
	{
		var params, paramsDrain : SCustomEffectParams;
		var casterActor : CActor;
		var i : int;
		var min, max, scale, pts, prc, slowdown, rawSP : float;
		var casterPlayer : CR4Player;
		var npc : CNewNPC;
		
		casterActor = caster.GetActor();
		casterPlayer = caster.GetPlayer();
		
		
		params.effectType = parent.actionBuffs[0].effectType;
		params.creator = casterActor;
		params.sourceName = "yrden_mode0";
		params.isSignEffect = true;
		params.customPowerStatValue = casterActor.GetTotalSignSpellPower(virtual_parent.GetSkill());
		params.customAbilityName = parent.actionBuffs[0].effectAbilityName;
		params.duration = 0.5f;
		rawSP = params.customPowerStatValue.valueMultiplicative;
		params.effectValue.valueAdditive = 0.25f * rawSP;
		
		if(thePlayer.CanUseSkill(S_Magic_s11))
		{
			paramsDrain = params;
			paramsDrain.customAbilityName = '';
			paramsDrain.effectType = EET_YrdenHealthDrain;
		}
		
		hitFxDelay = 0;
		while(true)
		{
			for(i=parent.flyersInArea.Size()-1; i>=0; i-=1)
			{
				npc = parent.flyersInArea[i];
				if(!npc.IsFlying())
				{
					parent.validTargetsInArea.PushBack(npc);
					npc.BlockAbility('Flying', true);
					parent.flyersInArea.EraseFast(i);
				}
			}
			
			for(i=0; i<parent.validTargetsInArea.Size(); i+=1)
			{
				prc = ((CNewNPC)parent.validTargetsInArea[i]).GetNPCCustomStat(theGame.params.DAMAGE_NAME_SLOW);
				params.effectValue.valueAdditive *= 1 - prc;
				
				if( prc < 1 )
					parent.validTargetsInArea[i].AddEffectCustom(params);			
				
				if( thePlayer.CanUseSkill(S_Magic_s11) )
				{
					parent.validTargetsInArea[i].AddEffectCustom(paramsDrain);
					
					hitFxDelay -= 0.5f;
					if(hitFxDelay <= 0)
					{
						hitFxDelay = 1.0;
						if(parent.validTargetsInArea[i].IsAlive())
							parent.validTargetsInArea[i].PlayEffect('yrden_shock');
					}
				}
				
				parent.validTargetsInArea[i].OnYrdenHit( casterActor );
			}
			
			Sleep(0.5f);
		}
	}*/
	
	event OnAreaEnter( area : CTriggerAreaComponent, activator : CComponent )
	{
		var target : CNewNPC;
		var casterActor : CActor;
		var yrdenAbility : SCustomEffectParams;
		
		target = (CNewNPC)(activator.GetEntity());
		casterActor = caster.GetActor();
		if( (W3PlayerWitcher)activator.GetEntity() )
		{
			parent.isPlayerInside = true;
		}
		
		if( target && !parent.allActorsInArea.Contains( target ) )
		{
			parent.allActorsInArea.PushBack( target );
		}
		
		if ( parent.IsValidTarget( target ) && !parent.validTargetsInArea.Contains(target))
		{
			/*if (!target.IsFlying())
			{*/
				
				if( parent.validTargetsInArea.Size() == 0 )
				{
					parent.PlayEffect( parent.effects[parent.fireMode].activateEffect );
				}
				
				parent.validTargetsInArea.PushBack( target );	
				target.SignalGameplayEventParamObject('EntersYrden', parent );
				
				if( !parent.yrdenAbilityKey )
					parent.yrdenAbilityKey = (string)RandRange(2000, 0);
				yrdenAbility.effectType = EET_YrdenAbilityEffect;
				yrdenAbility.creator = parent;
				yrdenAbility.sourceName = parent.yrdenAbilityKey;
				yrdenAbility.customPowerStatValue = parent.GetTotalSignIntensity();
				yrdenAbility.isSignEffect = true;
				yrdenAbility.duration = -1;
				target.AddEffectCustom(yrdenAbility);
				parent.affectedNPCs.PushBack(target);
				//target.BlockAbility('Flying', true);
			/*}
			else
			{
				parent.flyersInArea.PushBack(target);
			}*/
		}
		if( parent.isPlayerInside /*&& GetWitcherPlayer().IsSetBonusActive( EISB_Gryphon_2 )*/ )
		{
			parent.UpdateGryphonSetBonusYrdenBuff();
		}
		
		Combat().EnchantedGlyphsSkill(parent, true, activator.GetEntity());
	}
	
	event OnAreaExit( area : CTriggerAreaComponent, activator : CComponent )
	{
		/*
		var target : CNewNPC;
		var i : int;
		
		target = (CNewNPC)(activator.GetEntity());
	
		if( (W3PlayerWitcher)activator.GetEntity() )
		{
			parent.isPlayerInside = false;
		}
		if( target )
		{
			i = parent.validTargetsInArea.FindFirst( target );
			if( i >= 0 )
			{
				target.RemoveBuff(EET_YrdenAbilityEffect, true, parent.yrdenAbilityKey);
				
				parent.validTargetsInArea.Erase( i );
			}
			target.SignalGameplayEventParamObject('LeavesYrden', parent );
			target.BlockAbility('Flying', false);
			parent.flyersInArea.Remove(target);
		}
		
		if ( parent.validTargetsInArea.Size() == 0 )
		{
			parent.StopEffect( parent.effects[parent.fireMode].activateEffect );
		}
		if( !parent.isPlayerInside )
		{
			parent.UpdateGryphonSetBonusYrdenBuff();
		}
		*/
		ExitYrdenCircle(activator.GetEntity());
	}
	
	public function ExitYrdenCircle( ent : CEntity )
	{
		var target : CNewNPC;
		var i : int;
		
		target = (CNewNPC)ent;
		if( (W3PlayerWitcher)ent )
		{
			parent.isPlayerInside = false;
		}
		if( target )
		{
			i = parent.validTargetsInArea.FindFirst( target );
			if( i >= 0 )
			{
				target.RemoveAllBuffsWithSource(parent.yrdenAbilityKey);
				
				parent.validTargetsInArea.Erase( i );
			}
			i = parent.affectedNPCs.FindFirst(target);
			target.SignalGameplayEventParamObject('LeavesYrden', parent );
		}
		
		if ( parent.validTargetsInArea.Size() == 0 )
			parent.StopEffect( parent.effects[parent.fireMode].activateEffect );
		if( !parent.isPlayerInside )
			parent.UpdateGryphonSetBonusYrdenBuff();
		
		Combat().EnchantedGlyphsSkill(parent, false, ent);
	}
	// W3EE - End
}

state Discharged in W3YrdenEntity extends Active
{
	event OnEnterState( prevStateName : name )
	{
		YrdenExpire();
	}
	
	entry function YrdenExpire()
	{
		Sleep( 1.f );
		OnSignAborted( true );
	}
}