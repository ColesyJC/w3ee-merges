/***********************************************************************/
/** 	© 2015 CD PROJEKT S.A. All rights reserved.
/** 	THE WITCHER® is a trademark of CD PROJEKT S. A.
/** 	The Witcher game is based on the prose of Andrzej Sapkowski.
/***********************************************************************/
statemachine import class W3HorseComponent extends CVehicleComponent
{
	import var riderSharedParams : CHorseRiderSharedParams;
	
	public var lastRider : CActor;
	public var originalAttitudeGroup : CName;
	public var canDismount : bool;
	public var inCanter, inGallop : bool;
	public var inputApplied : bool;
	public var controllable : bool;
	
	//Alt Horse Controls++
	private var altSteeringMode : bool; 
		default altSteeringMode = true;
	public var roadFollow : bool;
		default roadFollow = true;
	//Alt Horse Controls--
	
	private var physMAC						: CMovingPhysicalAgentComponent;
	private var pitchDamp 					: SpringDamper;
	private var localSpaceControlls 		: bool;
	private var useSimpleStaminaManagement 	: bool;
	private var isInCustomSpot 				: bool;
	private var ignoreTestsCounter 			: int;
	private var manualControl				: bool;
	private var canFollowNpc 				: bool;
	private var horseComponentToFollow 		: W3HorseComponent;
	private var potentiallyWild				: bool;
	private var canTakeDamageFromFalling	: bool;
	public var mountTestPlayerPos, mountTestHorsePos, mountTestEndPos, mountTestNormal : Vector;
	public var mountTestCollisionGroups : array<name>;
	public var hideHorse : bool;
	public var killHorse : bool;
	private saved var isMountableByPlayer : bool; default isMountableByPlayer = true;
	
	private var horseMount : CComponent;
	
	public var cameraMode : int;
	default cameraMode = 1;
	
	protected var inWater : bool;
	protected var isInIdle : bool;
	
	private var isInHorseAction : bool;
	
	default manualControl = true;
	default canFollowNpc = false;
	default canDismount = true;
	default localSpaceControlls = false;
	default useSimpleStaminaManagement = true;
	default isInCustomSpot = false;
	default ignoreTestsCounter = 0;
	default canTakeDamageFromFalling = true;
	
	default originalAttitudeGroup = 'None';
	default autoState = 'Idle';
	default controllable = true;
	
	import final function PairWithRider( inRiderSharedParams : CHorseRiderSharedParams ) : bool;
	import final function IsTamed() : bool;
	import final function Unpair();
	import final function IsDismounted() : bool;
	import final function IsFullyMounted() : bool;
	
	
	private saved var firstSpawn : bool;
		default firstSpawn = true;
	
	private var panicDamper : SpringDamper;
	private saved var panicMult : float; 
	default panicMult = 1.0;
	
	const var PANIC_RANGE : float; default PANIC_RANGE = 8.f;
	const var THREAT_MULT : float; default THREAT_MULT = 20.f;
	
	private var staticPanic : int;
	
	private function InitPanicDamper()
	{
		var vehEnt : CActor;
		var panicVal : float;
		vehEnt = (CActor)GetEntity();
		
		if ( vehEnt ) 
		{
			panicVal = staticPanic;
			panicDamper = new SpringDamper in this;
			panicDamper.Init( panicVal, panicVal);
			panicDamper.SetSmoothTime(1.6f);
		}
	}
	
	//Alt Horse Controls++
	public function ToggleRoadFollow()
	{
		if ( roadFollow )
		{
			roadFollow = false;
			//thePlayer.DisplayHudMessage("Follow Road: OFF");
		}
		else
		{
			roadFollow = true;
			//thePlayer.DisplayHudMessage("Follow Road: ON");
		}
	}
	//Alt Horse Controls--
	
	public function SetPanicMult( mult : float )
	{
		panicMult = mult;
	}
	
	public function IsPlayerHorse() : bool
	{
		return GetEntity().HasTag('playerHorse');
	}
	
	private function GetHorseMount() : CComponent
	{
		var horseActor : CActor;
		
		horseActor = (CActor)GetEntity();
		
		if( horseActor )
		{
			horseMount = horseActor.GetComponent("horseMount");
		}
		
		return horseMount;
	}
	
	public function SetMountableByPlayer( isMountable : bool )
	{
		isMountableByPlayer = isMountable;
		GetHorseMount().SetEnabled( isMountableByPlayer );
	}
	
	event OnInit()
	{
		var horseActor : CActor;
		var horseNPC : CNewNPC;
		var items : array< SItemUniqueId >;
		var itemName : name;
		var inv : CInventoryComponent;
		
		super.OnInit();
		
		
		if(thePlayer)
			thePlayer.MountHorseIfNeeded();
		
		if( !pitchDamp )
		{
			pitchDamp = new SpringDamper in this;
			pitchDamp.SetSmoothTime( 0.2f );
		}
		
		horseActor = (CActor)GetEntity();
		
		horseActor.AddAnimEventChildCallback(this,'ActionBlend',	'OnAnimEvent_ActionBlend');
		horseActor.AddAnimEventChildCallback(this,'JumpFailed',		'OnAnimEvent_JumpFailed');
		
		horseNPC = (CNewNPC)GetEntity();
		
		horseNPC.SetIsHorse();

		if( horseActor.GetAttitudeGroup() == 'animals_peacefull' )
		{
			potentiallyWild = true;
		}
		
		pitchDamp.Init( 0.f, 0.f );
		
		physMAC = (CMovingPhysicalAgentComponent)GetEntity().GetRootAnimatedComponent();
		
		physMAC.SetBehaviorCallbackNeed(false);
		
		LogAssert( physMAC, "Horse doesn't have a CMovingPhysicalAgentComponent" );
		
		physMAC.RegisterEventListener( this );
		
		
		
		physMAC.SetSlidingLimits( 0.45f, 0.7f );
		physMAC.SetSlidingSpeed( 25.0f );
		physMAC.SetSliding( true );
		physMAC.EnableAdditionalVerticalSlidingIteration( true );
		
		InitPanicDamper();
		
		mountTestCollisionGroups.PushBack( 'Terrain' );
		mountTestCollisionGroups.PushBack( 'Static' );
		mountTestCollisionGroups.PushBack( 'Destructible' );
		if ( horseActor.HasTag( 'playerHorse' ) )
		{
			inv = horseActor.GetInventory();
			items = inv.GetItemsByCategory( 'horse_hair' );
			if ( items.Size() == 0 )
			{
				items = inv.AddAnItem( 'Horse Hair 0' );
				inv.MountItem( items[0] );
			}
			items = inv.GetItemsByTag( 'HorseTail' );
			if ( items.Size() == 0 )
			{
				itemName = inv.GetCategoryDefaultItem( 'horse_tail' );
				if ( itemName )				
				{
					items = inv.AddAnItem( itemName );
					inv.MountItem( items[0] );				
				}				
			}
		}
		
		
		if(IsPlayerHorse() && firstSpawn && FactsQuerySum("NewGamePlus") > 0)
		{
			horseNPC.SetAppearance('player_horse');
		}
		
		firstSpawn = false;
		
		//AltHorseControls++
		roadFollow = theGame.GetInGameConfigWrapper().GetVarValue( 'AltHorseControls', 'rfDefault' );
		//AltHorseControls--
	}
	
	event OnInteraction( actionName : string, activator : CEntity )
	{
		Mount( thePlayer, VMT_MountIfPossible, EVS_driver_slot );
	}
	
	
	
	
	
	event OnMountStarted( entity : CEntity, vehicleSlot : EVehicleSlot )
	{
		var horseActor 	: CActor;
		
		horseActor = ((CActor)GetEntity());
		lastRider = (CActor)entity;
		
		
		GetHorseMount().SetEnabled( false );
		
		if( entity == thePlayer )
		{
			thePlayer._SetHorseCurrentlyMounted( (CNewNPC)this.GetEntity() );
			horseActor.SetInteractionPriority( IP_Prio_12 );
		}
		
		horseActor.AddBuffImmunity(EET_AxiiGuardMe,'BeingMounted',true);
		
		if( entity != thePlayer )
			horseActor.AddBuffImmunity(EET_Confusion,'BeingMounted',true);
		
		super.OnMountStarted( entity, vehicleSlot );
	}
	
	event OnMountFinished( entity : CEntity )
	{
		var horseActor 	: CActor;
		var riderActor 	: CActor;
		var movingAgent : CMovingAgentComponent;
	
		horseActor  	= ((CActor)GetEntity());
		riderActor  	= ((CActor)entity);
		
		super.OnMountFinished( entity );

		if( this.IsTamed() )
		{
			originalAttitudeGroup = horseActor.GetBaseAttitudeGroup();
			
			horseActor.SetBaseAttitudeGroup( riderActor.GetBaseAttitudeGroup() );
		}
		
		if( riderActor == thePlayer )
		{
			thePlayer.SetIsHorseMounted( true );
			horseActor.CanPush( true );

			movingAgent = horseActor.GetMovingAgentComponent();
			if ( movingAgent )
			{
				movingAgent.SnapToNavigableSpace( false );
				movingAgent.AddTriggerActivatorChannel( TC_Horse );
			}
			
			horseActor.EnablePhysicalMovement( true );
		}
	}
	
	event OnDismountStarted( entity : CEntity )
	{
		
		

		if ( entity == thePlayer && userCombatManager )
			userCombatManager.OnDismountStarted();
		
		userCombatManager = NULL;
		
		DecrementIgnoreTestsCounter( true );
		
		super.OnDismountStarted( entity );
	}
	
	event OnHorseDismount() {}
	event OnSettlementEnter() {}
	event OnSettlementExit() {}
	
	event OnDismountFinished( entity : CEntity, vehicleSlot : EVehicleSlot )
	{
		var horseActor 	: CActor;
		var riderActor 	: CActor;
		var horseComp 	: W3HorseComponent;
		var movingAgent : CMovingAgentComponent;
		var camera 		: CCustomCamera; //Immersive Cam
		
		super.OnDismountFinished( entity, vehicleSlot );
		riderActor	= (CActor)entity;
		horseActor 	= ((CActor)GetEntity());
		
		
		GetHorseMount().SetEnabled( isMountableByPlayer );
		
		if( riderActor == thePlayer )
		{
			/* Immersive Cam: re-enable auto camera rotation on dismount */
			camera = (CCustomCamera)theCamera.GetTopmostCameraObject();
			camera.SetAllowAutoRotation( true );
			
			thePlayer._SetHorseCurrentlyMounted( NULL );
			thePlayer.SetIsHorseMounted( false );
			
			movingAgent = horseActor.GetMovingAgentComponent();
			if ( movingAgent )
			{
				if( movingAgent.IsOnNavigableSpace() )
					movingAgent.SnapToNavigableSpace( true );
				movingAgent.RemoveTriggerActivatorChannel( TC_Horse );
			}
			
			horseActor.RestoreOriginalInteractionPriority();
			horseActor.CanPush( true );
			horseActor.EnablePhysicalMovement( false );
		}
		
		horseActor = ((CActor)GetEntity());
		horseActor.RemoveBuffImmunity(EET_AxiiGuardMe,'BeingMounted');
		horseActor.RemoveBuffImmunity(EET_Confusion,'BeingMounted');
		
		if( hideHorse )
		{
			hideHorse = false;
			HideHorse();
		}
		else if( killHorse )
		{
			killHorse = false;
			KillHorse();
		}
	}
	
	
	
	
	
	private var frontHit : bool;
	private var backHit	: bool;
	private var frontLeg : Vector;
	private var backLeg	: Vector;
	protected var currentPitch : float;
	
	public function GetCurrentPitch() : float
	{
		return currentPitch;
	}
	
	event OnFrontLeg( pos : Vector, normal : Vector )
	{
		frontHit = true;
		frontLeg = pos;
	}
	
	event OnBackLeg( pos : Vector, normal : Vector )
	{
		backHit = true;
		backLeg = pos;
	}
	
	private var horseActor : CActor;
	
	public function ShouldTickInIdle() : bool
	{
		return lastRider == thePlayer;
	}
	
	event OnTick( dt : float )
	{
		var rot : EulerAngles;
		var lastRiderPlayer : bool;
		
		horseActor 	= (CActor)GetEntity();
		
		if( frontHit && backHit )
		{
			rot = VecToRotation( VecNormalize( backLeg - frontLeg ) );
			currentPitch = rot.Pitch;
		}
		else if( frontHit )
		{
			currentPitch += 5.f;
		}
		else if( backHit )
		{
			currentPitch -= 5.f;
		}
		
		physMAC.SetVirtualControllersPitch( Deg2Rad( pitchDamp.UpdateAndGet( dt, currentPitch ) ) );
		
		UpdateCollision();
		
		
		frontHit = false;
		backHit = false;
		
		lastRiderPlayer = lastRider == thePlayer;
		
		UpdatePanic( dt );
		
		if( lastRiderPlayer && riderSharedParams.rider && riderSharedParams.rider.IsInCombat() && !horseActor.HasAbility( 'HorseAxiiBuff' ) && !horseActor.HasAbility( 'DisableHorsePanic' ) )
		{
			horseActor.PauseEffects( EET_AutoPanicRegen, 'RiderInCombat', true );
		}
		else
			horseActor.ResumeEffects( EET_AutoPanicRegen, 'RiderInCombat' );
	}
	
	private function UpdateCollision()
	{
		var npc	: CNewNPC;
		var mac	: CMovingPhysicalAgentComponent;
		var collidedWithRider : bool;
		var collisionData : SCollisionData;
		var collisionNum : int;
		var i : int;
		var horseComp : W3HorseComponent;
		
		if( ! horseActor )
		{
			return;
		}
		
		mac	= (CMovingPhysicalAgentComponent)horseActor.GetMovingAgentComponent();
		if( !mac )
		{
			return;
		}
		
		
		collisionNum = mac.GetCollisionCharacterDataCount();
		for( i = 0; i < collisionNum; i += 1 )
		{
			collisionData	= mac.GetCollisionCharacterData( i );
			npc	= ( CNewNPC ) collisionData.entity;
			if( npc ) 
			{
				MakeNPCCollide( npc );
				
			}
		}
	}
	
	private function MakeNPCCollide( npc : CNewNPC )
	{
		npc.SignalGameplayEvent( 'AI_GetOutOfTheWay' ); 
		
		if ( lastRider == thePlayer )
		{
			npc.SignalGameplayEventParamObject( 'CollideWithPlayer', thePlayer ); 
		}
		else
		{
			npc.SignalGameplayEventParamObject( 'CollideWithPlayer', GetEntity() ); 
		}
		theGame.GetBehTreeReactionManager().CreateReactionEvent( npc, 'BumpAction', 1, 1, 1, 1, false );
	}
	
	private var panicVibrate : bool;
	
	private function UpdatePanic( dt : float )
	{
		var entities : array<CGameplayEntity>;
		
		var maxThreat, i : int;
		var tempThreat, totalThreat : float;
		
		var npc : CNewNPC;
		
		if ( !panicDamper )
			return;
		
		// W3EE - Begin
		if( ShouldUpdatePanic() )
		{
			FindGameplayEntitiesInCylinder(entities, horseActor.GetWorldPosition(), PANIC_RANGE, 5.f, CeilF(100/THREAT_MULT) + 1, '', FLAG_ExcludePlayer + FLAG_ExcludeTarget + FLAG_Attitude_Hostile + FLAG_OnlyAliveActors, horseActor);
			
			for( i = 0; i < entities.Size() ; i += 1 )
			{	
				npc = (CNewNPC)entities[i];
				tempThreat = npc.GetThreatLevel();
				
				if( npc.IsHorse() )
				{
					continue;
				}
				/*else if( npc.IsHuman() )
				{
					totalThreat += tempThreat / 4;
				}*/
				else
				{
					totalThreat += tempThreat * (1.f - 0.4f * tempThreat / 100);
				}
			}
		}
		else
		{
			totalThreat = 0.0;
		}
		
		staticPanic = RoundF(totalThreat /** THREAT_MULT*/ * panicMult);
		
		staticPanic = RoundF(panicDamper.UpdateAndGet(dt, staticPanic));
		// W3EE - End
		
		
		
		if((panicVibrate || GetPanicPercent() >= 0.9) && thePlayer.GetUsedHorseComponent() == this)
		{
			panicVibrate = true;
			theGame.VibrateControllerHard();	
		}
		
		if((panicVibrate && GetPanicPercent() < 0.9) || thePlayer.GetUsedHorseComponent() != this)
		{
			panicVibrate = false;
		}
	}
	
	private function ShouldUpdatePanic() : bool
	{
		var horseActor : CActor;
		
		horseActor 	= (CActor)GetEntity();

		return !horseActor.HasAbility( 'HorseAxiiBuff' ) && !horseActor.HasBuff( EET_Confusion ) && !horseActor.HasBuff( EET_AxiiGuardMe ) && !horseActor.HasAbility( 'DisableHorsePanic' );
	}
	
	private function ResetPanicUpdate()
	{
		if ( staticPanic > 0.f )
		{
			staticPanic = 0;
			panicDamper.Init(staticPanic,staticPanic);
			
		}
	}
	
	public function ResetPanic()
	{
		var actor : CActor;
		actor = (CActor)GetEntity();
		actor.GainStat(BCS_Panic,actor.GetStatMax(BCS_Panic));
	}
	
	public function GetPanicPercent() : float
	{
		var actor : CActor;
		var panic : float;
		var maxPanic : float;
		
		actor = (CActor)GetEntity();
		
		maxPanic = actor.GetStatMax( BCS_Panic );
		panic = staticPanic + ( maxPanic - actor.GetStat( BCS_Panic ) );
		panic = panic/maxPanic;
		
		return panic;
	}
	
	public function IsPotentiallyWild() : bool
	{
		return potentiallyWild;
	}
	
	event OnPredictionCollision( pos : Vector, normal : Vector, disp : Vector, penetration : Float, actorHeight : Float, diffZ : Float, fromVirtualController : bool ) {}
	event OnHeadPredictionCollision( pos : Vector, normal : Vector, disp : Vector, penetration : Float, actorHeight : Float, diffZ : Float, fromVirtualController : bool ) {}
	event OnFrontPredictionCollision( pos : Vector, normal : Vector, disp : Vector, penetration : Float, actorHeight : Float, diffZ : Float, fromVirtualController : bool ) {}
	event OnBackPredictionCollision( pos : Vector, normal : Vector, disp : Vector, penetration : Float, actorHeight : Float, diffZ : Float, fromVirtualController : bool ) {}
	
	
	
	
	
	event OnCharacterCollision( entity : CEntity )
	{	
		var actorEntity : CActor;
		
		actorEntity = (CActor)entity;
		
		if( actorEntity )
			ShouldDealDamageToActor( actorEntity, false );
	}
	
	event OnCharacterSideCollision( entity : CEntity )
	{
		var actorEntity : CActor;
		
		actorEntity = (CActor)entity;
		
		if( actorEntity )
			ShouldDealDamageToActor( actorEntity, true );
	}
	
	public function ShouldDealDamageToActor( collidedActor : CActor, sideCollision : bool )
	{
		var attacker : CActor;
		
		attacker = GetCurrentUser();
			
		if( !attacker )
			attacker = (CActor)GetEntity();
		
		if( IsRequiredAttitudeBetween( attacker, collidedActor, true ) ) 
		{
			if( collidedActor.IsUsingHorse() || ((CNewNPC)collidedActor).IsHorse() ) 
			{
				return;
			}
			else
			{
				if( InternalGetSpeed() >= 3.0 ) 
				{
					DealDamageToCollidedActor( attacker, collidedActor, sideCollision );
				}
			}
		}
	}
	
	
	public function ReactToQuen()
	{
		var damageAction : W3DamageAction;
		
		if( InternalGetSpeed() > 0.0 )
		{
			if( GetWitcherPlayer().IsQuenActive( true ) )
			{
				damageAction = new W3DamageAction in this;
				damageAction.Initialize( (CGameplayEntity)GetEntity(), thePlayer, this, "ReactToQuen", EHRT_None, CPS_Undefined, true, false, false, false );
				damageAction.AddDamage( theGame.params.DAMAGE_NAME_PHYSICAL, 0.0 );
				theGame.damageMgr.ProcessAction(damageAction);
				delete damageAction;
				
				ShakeOffRider( DT_shakeOff );
				thePlayer.FinishQuen(false);
			}
		}
	}

	private var collidedActors : array< CollsionActorStruct >;
	
	private function DealDamageToCollidedActor( owner, collidedActor : CActor, sideCollision : bool )
	{
		var itemId : SItemUniqueId;
		var action : W3Action_Attack;
		var horse : CActor;
		var collisionData : CollsionActorStruct;
		
		horse = (CActor)GetEntity();
		itemId = horse.GetInventory().GetItemFromSlot( 'r_weapon' );
		
		if( !horse.GetInventory().IsIdValid( itemId ) )
			return ;
		
		if( !CanCollideWithThisActor( collidedActor ) )
			return;
		
		if( !sideCollision || collidedActor.HasBuff( EET_Knockdown ) || collidedActor.HasBuff( EET_HeavyKnockdown ) )
		{
			action = new W3Action_Attack in theGame.damageMgr;
			action.Init( owner, collidedActor, horse, itemId, 'attack_speed_based', horse.GetName(), EHRT_Heavy, false, false, 'attack_speed_based', AST_Jab, ASD_UpDown,true,false,false,false );
			action.AddDamage( theGame.params.DAMAGE_NAME_PHYSICAL, 50.0 * MaxF( InternalGetSpeed(), 1 ) );
			theGame.damageMgr.ProcessAction( action );
			
			delete action;
		}
		collisionData.actor = collidedActor;
		collisionData.timestamp = theGame.GetEngineTimeAsSeconds();
		collidedActors.PushBack( collisionData );
	}
	
	private function CanCollideWithThisActor( actor : CActor ) : bool
	{
		var i : int;
		
		for ( i = collidedActors.Size()-1; i >= 0 ; i -= 1 )
		{
			if ( collidedActors[i].timestamp + 1.0 < theGame.GetEngineTimeAsSeconds() )
			{	
				collidedActors.Erase( i );
			}
			else if ( collidedActors[i].actor == actor )
			{
				return false;
			}
		}
		return true;
	}
	 
	
	
	
	
	final function InternalSetRotation( value : float ) 		{ SetVariable( 'rotation', value ); }
	final function InternalGetRotation() : float 				{ return GetVariable('rotation'); }

	final function InternalSetDirection( value : float ) 		{ SetVariable( 'direction', value ); }
	final function InternalGetDirection() : float 				{ return GetVariable('direction'); }
	
	final function InternalSetSpeed( value : float ) 			
	{ 
		((CActor)GetEntity()).GetMovingAgentComponent().SetGameplayRelativeMoveSpeed( value ); 
		SetVariable('speed', value);
	}
	final function InternalGetSpeed() : float 					{ return ((CActor)GetEntity()).GetMovingAgentComponent().GetRelativeMoveSpeed(); } 
	
	final function InternalSetSpeedMultiplier( value : float ) 	{ SetVariable( 'horseSpeedMult', value ); }
	

	final function GetHorseVelocitySpeed() : float
	{
		return VecLength2D(((CActor)GetEntity()).GetMovingAgentComponent().GetVelocity());
	}
	
	final function InternalResetVariables()
	{
		InternalSetRotation( 0.f );
		InternalSetDirection( 0.f );
		InternalSetSpeed( 0.f );
	}
	
	final function StopTheVehicle()
	{
		var tmpActor : CActor;
		tmpActor = (CActor)GetEntity();
		tmpActor.SignalGameplayEvent( 'OnStopHorse' );
	}
	
	event OnStopTheVehicleInstant()
	{
		var tmpActor : CActor;
		var tmpRider : CActor;

		tmpRider = (CActor)user;
		tmpActor = (CActor)GetEntity();
		InternalSetSpeed( 0.f );
		tmpRider.RaiseForceEventWithoutTestCheck( 'ForceIdle' );
		tmpActor.RaiseForceEventWithoutTestCheck( 'ForceIdle' );			
	}
	
	event OnForceStop()
	{
	}
	
	event OnHorseStop()
	{
	}
	
	
	
	
	
	public function SetManualControl( val : bool ) { manualControl = val; }
	public function GetManualControl() : bool { return manualControl; }
		
	public function SetIsInCustomSpot( val : bool ) { isInCustomSpot = val; }
	public function IsInCustomSpot() : bool { return isInCustomSpot; }
	
	public function IncrementIgnoreTestsCounter() 
	{ 
		ignoreTestsCounter += 1; 
	}
	
	public function DecrementIgnoreTestsCounter( optional reset : bool ) 
	{
		if( reset )
		{	
			ignoreTestsCounter = 0; 
			return;
		}
			
		if( ignoreTestsCounter > 0 ) 
			ignoreTestsCounter -= 1; 
	}
	
	public function ShouldIgnoreTests() : bool 
	{ 	
		return ignoreTestsCounter > 0; 
	}
	
	public function SetCanFollowNpc( val : bool, horseComp : W3HorseComponent ) { canFollowNpc = val; horseComponentToFollow = horseComp; }
	public function CanFollowNpc() : bool { return canFollowNpc; }
	
	public function SetCanTakeDamageFromFalling( val : bool ) { canTakeDamageFromFalling = val; }
	public function CanTakeDamageFromFalling() : bool { return canTakeDamageFromFalling; }
	
	public function GetHorseComponentToFollow() : W3HorseComponent { return horseComponentToFollow; }
	
	public function ToggleLocalSpaceControlls( toggle : bool ) { localSpaceControlls = toggle; }
	public function IsControllableInLocalSpace() : bool { return localSpaceControlls; }
	
	public function ToggleSimpleStaminaManagement( toggle : bool ) { useSimpleStaminaManagement = toggle; }
	public function ShouldUseSimpleStaminaManagement() : bool { return useSimpleStaminaManagement; }
	
	public function GetCurrentUser() : CActor { return (CActor)user; }
	
	public function GetLastRider() : CActor { return lastRider; }
	
	public function ShakeOffRider( dismountType : EDismountType )
	{
		var horseActor 	: CActor;
		
		if ( user == thePlayer )
		{
			IssueCommandToDismount( dismountType );
		}
		else
		{
			horseActor = ((CActor)GetEntity());
			
			if( horseActor && horseActor.HasAbility( 'DisableHorsePanic' ) )
			{
				return;
			}
			
			user.SignalGameplayEventParamInt( 'RidingManagerDismountHorse', dismountType | DT_fromScript );
		}
	}
	
	public function IsNotBeingUsed() : bool
	{
		return riderSharedParams.mountStatus == VMS_dismounted;
	}
	
	event OnJumpHack()
	{
	}

	
	function Tame( owner : CActor, tame : bool )
	{
		var horseActor 	: CActor;
		horseActor  	= ((CActor)GetEntity());
		
		if ( tame && IsTamed() == false )
		{
			horseActor.SetBaseAttitudeGroup( owner.GetBaseAttitudeGroup() );
			horseActor.ResetAttitude( owner );
		}
		
		
		if ( tame == false && IsTamed() )
		{
			horseActor.SetBaseAttitudeGroup( 'animals_peacefull' );
		}
	}
	
	event OnHideHorse()
	{
		if( user )
		{
			if( user == thePlayer )
			{
				IssueCommandToDismount( DT_instant );
			}
			else
			{
				user.SignalGameplayEventParamInt( 'RidingManagerDismountHorse', DT_instant | DT_fromScript );
			}
			
			hideHorse = true;
		}
		else
		{
			HideHorse();
		}
	}
	
	function HideHorse()
	{
		OnHitGround();
		((CNewNPC)GetEntity()).HideHorseAfter( 0.1 );	
	}
	
	event OnKillHorse()
	{
		if( user )
		{
			if( user == thePlayer )
			{
				IssueCommandToDismount( DT_instant );
			}
			else
			{
				user.SignalGameplayEventParamInt( 'RidingManagerDismountHorse', DT_instant | DT_fromScript );
			}
			
			killHorse = true;
		}
		else
		{
			KillHorse();
		}
	}
	
	function KillHorse()
	{		
		((CNewNPC)GetEntity()).KillHorseAfter( 0.1 );
	}
	
	event OnHitGround()
	{
		var horseActor 	: CActor;
		horseActor  	= ((CActor)GetEntity());
		
		SetVariable( 'onGround', 1.f );
		((CMovingPhysicalAgentComponent)horseActor.GetComponentByClassName( 'CMovingPhysicalAgentComponent' ) ).SetAnimatedMovement( false );
		horseActor.SetIsInAir( false );
	}
	
	
	
	
	
	
	
	event OnIgniHit( sign : W3IgniProjectile )
	{
		var horseActor 	: CActor;

		horseActor = ((CActor)GetEntity());
		
		if( horseActor && horseActor.HasAbility( 'DisableHorsePanic' ) )
		{
			return false;
		}
		
		if ( user.IsInCombat() )
			this.user.SignalGameplayEventParamInt( 'RidingManagerDismountHorse', DT_shakeOff );
	}
	
	event OnRiderWantsToMount()
	{
		GetEntity().GetComponentByClassName('CInteractionComponent').SetEnabled( false );
	}
	
	event OnAnimationStarted( entity : CEntity, animation : name )
	{
		var ac : CAnimatedComponent;
		var ass : SAnimatedComponentSlotAnimationSettings;
		
		ac = GetEntity().GetRootAnimatedComponent();
		if ( ac )
		{
			ResetAnimatedComponentSlotAnimationSettings( ass );
			ass.blendIn = 0.9f;
			ass.blendOut = 0.2f;
			
			if ( !ac.PlaySlotAnimationAsync( animation, 'HORSE_MOUNT', ass ) )
			{
				Log("horse: PlaySlotAnimationAsync failed");
			}
		}
	}
	
	event OnCombatActionEnd(){}
	event OnCriticalEffectAdded( criticalEffect : ECriticalStateType ){}
	event OnOceanTriggerEnter() { inWater = true; }
	event OnOceanTriggerLeave() { inWater = false; }
	
	event OnIdleBegin()
	{
		isInIdle = true;
		ToggleHorseAction(false);
	}
	
	event OnIdleEnd()
	{
		isInIdle = false;
	}
	
	event OnHorseActionStart()
	{
		ToggleHorseAction(true);
	}
	
	event OnHorseActionStop()
	{
		ToggleHorseAction(false);
	}
	
	event OnHorseFastStopBegin() {}
	event OnHorseFastStopEnd() {}
	
	event OnAnimEvent_ActionBlend( animEventName : name, animEventType : EAnimationEventType, animInfo : SAnimationEventAnimInfo )
	{
		if ( IsInHorseAction() && animEventType == AET_DurationStart )
		{
			ToggleHorseAction(false);
		}
	}
	
	event OnAnimEvent_JumpFailed( animEventName : name, animEventType : EAnimationEventType, animInfo : SAnimationEventAnimInfo )
	{
	}
	
	event OnSmartDismount(){}
	
	protected function ToggleHorseAction( start : bool )
	{
		if ( start )
		{
			isInHorseAction = true;
			if ( userCombatManager )
				userCombatManager.OnHorseActionStart();
		}
		else if ( !start && isInHorseAction )
		{
			isInHorseAction = false;
			if ( userCombatManager )
				userCombatManager.OnHorseActionStop();
		}
	}
	
	event OnCheckHorseJump()
	{
		return false;
	}
	
	
	
	public function IsInHorseAction() : bool
	{
		return isInHorseAction;
	}
	
	event OnEnableCanter()
	{
		GetEntity().SetBehaviorVariable( 'isCanterEnabled', 1.0 );
	}
	
	event OnCanGallop()
	{
		return false;
	}
	
	event OnCanCanter()
	{
		return false;
	}
}

struct CollsionActorStruct
{
	var actor : CActor;
	var timestamp : float;
}
