/***********************************************************************/
/** 	© 2015 CD PROJEKT S.A. All rights reserved.
/** 	THE WITCHER® is a trademark of CD PROJEKT S. A.
/** 	The Witcher game is based on the prose of Andrzej Sapkowski.
/***********************************************************************/








state Exploration in CR4Player extends ExtendedMovable
{
	private var wantsToSheatheWeapon			: bool;		default	wantsToSheatheWeapon			= false;
	
	
	
	
	
	event OnEnterState( prevStateName : name )
	{	
		super.OnEnterState(prevStateName);
		
		
		
		theInput.SetContext( parent.GetExplorationInputContext() );
		
		virtual_parent.SetPlayerCombatStance( PCS_Normal, true );
		
		
		
		theGame.GetGuiManager().DisableHudHoldIndicator();
		parent.RemoveBuffImmunity_AllCritical('Swimming');
		
		((CMovingPhysicalAgentComponent)parent.GetMovingAgentComponent()).SetSwimming( false );
		((CMovingPhysicalAgentComponent)parent.GetMovingAgentComponent()).SetDiving( false );
		
		if( parent.GetCurrentMeleeWeaponType() == PW_Steel )
		{
			parent.SetBehaviorVariable( 'playerWeapon', (int)PW_Steel );
		}
		else if( parent.GetCurrentMeleeWeaponType() == PW_Silver )
		{
			parent.SetBehaviorVariable( 'playerWeapon', (int)PW_Silver );
		}
		
		parent.SetBehaviorMimicVariable( 'gameplayMimicsMode', (float)(int)PGMM_Default );
		
		
		
		this.ExplorationInit( prevStateName );
		
		theTelemetry.LogWithName(TE_STATE_EXPLORING);
	} 
	
	
	event OnLeaveState( nextStateName : name )
	{
		parent.RemoveTimer( 'ResetStanceTimer' );
		parent.RemoveTimer( 'ExplorationLoop');

		//ImmersiveCam++
		parent.DisableHeadTracking();
		//ImmersiveCam--

		CameraCleanup();
		
		( (CMovingPhysicalAgentComponent) parent.GetMovingAgentComponent() ).SetTerrainInfluence(0.4f);
		
		if ( parent.GetBehaviorVariable( 'proudWalk' ) > 0.f )
			parent.proudWalk = true;
		else
			parent.proudWalk = false;
		
		if ( parent.GetBehaviorVariable( 'alternateWalk' ) == 1.0 )
			parent.injuredWalk = true;
		else
			parent.injuredWalk = false;
		
		if ( parent.GetBehaviorVariable( 'alternateWalk' ) == 2.0 )
			parent.tiedWalk = true;
		else
			parent.tiedWalk = false;
		
		
		super.OnLeaveState( nextStateName );



	}
	
	event OnStateCanGoToCombat()
	{
		
		
		return true;
	}
	
	event OnStateCanUpdateExplorationSubstates()
	{
		return true;
	}
	
	final function NeedsToSheatheWeapon( sheatheWeapon : bool )
	{
		wantsToSheatheWeapon	= sheatheWeapon;
	}
	
	
	entry function ExplorationInit( prevStateName : name )
	{		
		var stupidArray : array< name >;
		var comp	: CMovingPhysicalAgentComponent;
		
		stupidArray.PushBack( 'Gameplay' );
		
		parent.LockEntryFunction( true );
		
		m_lastUsedPCInput = false;
		
		
		
		parent.BlockAllActions('ExplorationInit', true, , true, parent);
		if ( prevStateName == 'TraverseExploration' || prevStateName == 'PlayerDialogScene' )
		{
			parent.ActivateBehaviors(stupidArray);
		}
		else
		{
			parent.ActivateAndSyncBehaviors(stupidArray);
		}
		
		parent.OnCombatActionEndComplete();
		
		if ( !parent.pcGamePlayInitialized )
		{
			parent.pcGamePlayInitialized = true;
			parent.RaiseForceEvent( 'ForceIdle' );
		}
		
		parent.BlockAllActions('ExplorationInit', false);
		
		
		parent.UnblockAction(EIAB_MeditationWaiting, 'vehicle');
		
		
		if ( parent.IsInShallowWater() )
			parent.SetBehaviorVariable( 'shallowWater',1.0);
		
		parent.SetOrientationTarget( OT_Player );
		parent.ClearCustomOrientationInfoStack();
		parent.SetBIsInputAllowed(true, 'ExplorationInit');
		
		parent.AddTimer( 'ResetStanceTimer', 1.f );
		
		parent.findMoveTargetDistMin = 10.f;
		
		InitCamera();
		
		parent.LockEntryFunction( false );
		
		while ( !comp )
		{
			comp = ( (CMovingPhysicalAgentComponent) parent.GetMovingAgentComponent() );
		}
		
		comp.SetTerrainInfluence(0.f);
		
		parent.SetBehaviorVariable( 'proudWalk', (float)( parent.proudWalk ) );
		if ( parent.injuredWalk )
		{
			parent.SetBehaviorVariable( 'alternateWalk', 1.0f );
		}
		else if ( parent.tiedWalk )
		{
			parent.SetBehaviorVariable( 'alternateWalk', 2.0f );
		}
		else
		{
			parent.SetBehaviorVariable( 'alternateWalk', 0.0f );
		}
		parent.SetBehaviorMimicVariable( 'gameplayMimicsMode', (float)(int)PGMM_Default );
		
		
		parent.AddTimer( 'ExplorationLoop', 0.01f, true );
	}
	
	
	
	timer function ExplorationLoop( time : float , id : int)
	{
		ProcessPlayerOrientation();
		parent.SetBehaviorMimicVariable( 'gameplayMimicsMode', (float)(int)PGMM_Default ); 
		
		if ( parent.IsThreatened() )
		{
			if ( parent.moveTarget && VecDistance( parent.moveTarget.GetWorldPosition(), parent.GetWorldPosition() ) < parent.findMoveTargetDist )
				parent.playerMode.UpdateCombatMode();
		}
	}
	
	timer function ResetStanceTimer( time : float , id : int)
	{
		if ( parent.GetCombatIdleStance() == 0.f ) 
		{
			if ( !parent.IsInGuardedState() )
				parent.SetCombatIdleStance( 1.f );
		}		
	}
	
	private function ProcessPlayerOrientation()
	{
		var playerToTargetDist			: float;
		var playerCurrCombatStance		: EPlayerCombatStance;
		var playerToTargetAngle			: float;
		var customOrientationInfo		: SCustomOrientationInfo;
		var customOrientationTarget		: EOrientationTarget;

		if ( parent.GetCustomOrientationTarget( customOrientationInfo ) )
			customOrientationTarget = customOrientationInfo.orientationTarget;
		else
			customOrientationTarget = OT_None;

		if ( !parent.GetIsSprinting() && !virtual_parent.GetBIsCombatActionAllowed() && (CActor)parent.GetTarget() ) 
		{
			parent.SetOrientationTarget( OT_Actor );
		}
		else if ( customOrientationTarget == OT_None )
		{
			parent.SetOrientationTarget( OT_Player );
		}		

		if ( customOrientationTarget != OT_None )
		{
			parent.SetOrientationTarget( customOrientationTarget );
		}
	}		
	
	
	
	
	private function InitCamera()
	{
		var camera : CCustomCamera = theGame.GetGameCamera();
		var animation : SCameraAnimationDefinition;
		
		if(camera)
		{
			camera.ChangePivotPositionController('Default');
			camera.ChangePivotDistanceController('Default');
		}
		
		animation.animation = 'camera_exploration';
		animation.priority = CAP_Lowest;
		animation.blendIn = 0.f;
		animation.blendOut = 0.f;
		animation.weight = 0.5f;
		animation.speed	= 1.0f;
		animation.loop = true;
		animation.additive = true;
		animation.reset = true;
		
		
	}

	private function CameraCleanup()
	{
		if(theGame.GetGameCamera())
			theGame.GetGameCamera().StopAnimation('camera_exploration');
	}
	
	private var m_lastUsedPCInput : bool;
	private var doHeadTracking : bool; //ImmersiveCam
	
	event OnGameCameraTick( out moveData : SCameraMovementData, dt : float )
	{
		doHeadTracking = false; //ImmersiveCam
		
		if( super.OnGameCameraTick( moveData, dt ) )
		{
			return true;
		}
		
		if( m_lastUsedPCInput != theInput.LastUsedPCInput() )
		{
			m_lastUsedPCInput = theInput.LastUsedPCInput();
			
			if ( m_lastUsedPCInput )
			{
				theGame.GetGameCamera().SetManualRotationHorTimeout( 5 );
				theGame.GetGameCamera().SetManualRotationVerTimeout( 3 );
			}
			else
			{
				theGame.GetGameCamera().SetManualRotationHorTimeout( 1.5 );
				theGame.GetGameCamera().SetManualRotationVerTimeout( 3 );
			}
		}
		
		//ImmersiveCam++
		moveData.pivotRotationController.minPitch = -50.f;	
		moveData.pivotRotationController.maxPitch = 50.f;
		//ImmersiveCam--
		
		switch( parent.GetPlayerAction() )
		{
			//ImmersiveCam++
			//case PEA_Meditation 	: UpdateCameraMeditation( moveData, dt ); break;	
			case PEA_ExamineGround 	: doHeadTracking = false; break; 
			//ImmersiveCam--
		
			default:
			{
				if ( parent.IsCameraLockedToTarget() )
				{
					UpdateCameraInterior( moveData, dt );
				}			
				//ImmersiveCam++
				else
				{
					if ( parent.IsSprintActionPressed() )
						parent.wasRunning = false; 
					else
						doHeadTracking = true;
						
					UpdateCameraIC( moveData, dt );
					return false;
				}
				//ImmersiveCam--
			}
			
			return true;
		}
	}
	
	//ImmersiveCam++
	protected function UpdateCameraIC( out moveData : SCameraMovementData, timeDelta : float )
	{
		var camera : CCustomCamera = theGame.GetGameCamera();
		
		camera.ChangePivotRotationController( 'ExplorationInterior' );
		camera.ChangePivotDistanceController( 'Default' );
		camera.ChangePivotPositionController( 'Default' );		
		
		moveData.pivotRotationController = camera.GetActivePivotRotationController();
		moveData.pivotDistanceController = camera.GetActivePivotDistanceController();
		moveData.pivotPositionController = camera.GetActivePivotPositionController();
		
		moveData.pivotPositionController.SetDesiredPosition( parent.GetWorldPosition(), 15.f );
		//moveData.pivotDistanceController.SetDesiredDistance(3.5);
	}
	//ImmersiveCam--
	
	var cachedPos : Vector;
	var constDamper : ConstDamper;
	event OnGameCameraPostTick( out moveData : SCameraMovementData, dt : float )
	{	
		var buff : CBaseGameplayEffect;
		var angles	: EulerAngles;
		var rotMult	: float;	//ImmersiveCam
		
		var playerVel : float;
		var tempVel	: float;
		
		if ( !constDamper )
		{
			constDamper = new ConstDamper in this;
			constDamper.SetDamp( 1.f );
		}
		
		if( parent.rangedWeapon && parent.rangedWeapon.GetCurrentStateName() != 'State_WeaponWait' )
		{
			moveData.pivotRotationController.SetDesiredHeading( moveData.pivotRotationValue.Yaw );
		}
		
		buff = parent.GetCurrentlyAnimatedCS();
		
		if ( ( parent.IsInCombatAction() || buff ) && !parent.IsInCombat() )
			parent.UpdateCameraCombatActionButNotInCombat( moveData, dt );	

		// ImmersiveCam++
		if ( !thePlayer.IsSprintActionPressed() )
		{
			if ( !parent.ic.expAutoRot || parent.rawPlayerSpeed <= 0 )
				constDamper.Reset();
				
			if( doHeadTracking && parent.playerMoveType < PMT_Run )
				parent.ProcessHeadTracking();
			else
				parent.DisableHeadTracking();
		}
		else
		{
			if( !parent.ic.sprintAutoRot )
				constDamper.Reset();
				
			parent.DisableHeadTracking();
		}
		
		if( parent.ic.expAutoRot || thePlayer.IsSprintActionPressed() )
		{
			if ( theGame.IsUberMovementEnabled() )
				rotMult = 0.5f;
			else
				rotMult = 1.f;

			rotMult = constDamper.UpdateAndGet( dt, rotMult );
		
			if ( AbsF( AngleDistance( parent.GetHeading(), moveData.pivotRotationValue.Yaw ) ) < 135.f && parent.rawPlayerSpeed > 0 )
				moveData.pivotRotationController.SetDesiredHeading( parent.GetHeading(), rotMult );
			else 
				moveData.pivotRotationController.SetDesiredHeading( moveData.pivotRotationValue.Yaw );
				
			playerVel = VecDistance( cachedPos, parent.GetWorldPosition() ) / dt ;
			cachedPos = parent.GetWorldPosition();

			playerVel = constDamper.UpdateAndGet( dt, playerVel );
		
			if ( ( playerVel < 0.5f || parent.rawPlayerSpeed <= 0 ) && !parent.IsInCombatAction() )
			{
				moveData.pivotRotationController.SetDesiredPitch( moveData.pivotRotationValue.Pitch );
			}
		}
		else
		{
			playerVel = VecDistance( cachedPos, parent.GetWorldPosition() ) / dt ;
			cachedPos = parent.GetWorldPosition();

			playerVel = constDamper.UpdateAndGet( dt, playerVel );
		
			if ( ( playerVel < 0.5f || parent.rawPlayerSpeed <= 0 ) && !parent.IsInCombatAction() )
			{
				moveData.pivotRotationController.SetDesiredHeading( moveData.pivotRotationValue.Yaw );
				moveData.pivotRotationController.SetDesiredPitch( moveData.pivotRotationValue.Pitch );
			}
		}
		//ImmersiveCam--
		
		super.OnGameCameraPostTick( moveData, dt );
	}
	
	event OnGameCameraExplorationRotCtrlChange()
	{
		if ( parent.playerMoveType >= PMT_Run )
		{
			theGame.GetGameCamera().ChangePivotRotationController( 'ExplorationRun' );
			return true;
		}
		else if ( parent.movementLockType == PMLT_Free )
		{	
			return parent.OnGameCameraExplorationRotCtrlChange();
		}
		return false;
	}	
	
	
	private function UpdateCameraMeditation( out moveData : SCameraMovementData, timeDelta : float )
	{
		//ImmersiveCam++
		/*
		moveData.pivotPositionController.offsetZ = 0.8f;
		moveData.pivotPositionController.SetDesiredPosition( parent.GetWorldPosition() );
		
		moveData.pivotRotationController.SetDesiredHeading( parent.GetHeading() - 30.0f );
		moveData.pivotRotationController.SetDesiredPitch( -2.0f );
		
		moveData.pivotDistanceController.SetDesiredDistance( 1.3f );
		
		DampVectorSpring( moveData.cameraLocalSpaceOffset, moveData.cameraLocalSpaceOffsetVel, Vector( -0.5f, 0.f, 0.f ), 1.f, timeDelta );
		*/
		//ImmersiveCam--
	}
	
	
	private function UpdateCameraClueGround( out moveData : SCameraMovementData, timeDelta : float )
	{
		moveData.pivotPositionController.offsetZ = 0.5f;   //ImmersiveCam
		moveData.pivotPositionController.SetDesiredPosition( parent.GetWorldPosition() );
		
		moveData.pivotRotationController.SetDesiredHeading( parent.GetHeading() + 50.0f );
		moveData.pivotRotationController.SetDesiredPitch( -5.0f );
		
		moveData.pivotDistanceController.SetDesiredDistance( 1.8f );
		
		//DampVectorSpring( moveData.cameraLocalSpaceOffset, moveData.cameraLocalSpaceOffsetVel, Vector( parent.ic.clueOffset, parent.ic.clueDepth, parent.ic.clueHeight ), 1.f, timeDelta ); //ImmersiveCam
		
		
		
	}
	
	entry function Mount( vehicle : CVehicleComponent, optional mountType : EVehicleMountType )
	{
		
		vehicle.Mount( parent, mountType, EVS_driver_slot );
	}
	
	event OnReactToBeingHit( damageAction : W3DamageAction )
	{
		var destHeading, angleToRotate : float;
		var attacker : CActor;
		
		if ( parent.IsUsingVehicle() == false && damageAction.attacker )
		{
			destHeading = VecHeading( damageAction.attacker.GetWorldPosition() - parent.GetWorldPosition() );
			angleToRotate = AngleDistance( destHeading, parent.GetHeading() );
			
			parent.SetBehaviorVariable( 'hitAngleToRotate', angleToRotate );
			
			attacker = (CActor)damageAction.attacker;
			if(attacker && IsRequiredAttitudeBetween(parent, attacker, true) && parent.IsThreat( attacker ) )
				parent.playerMode.UpdateCombatMode();
				
		}
	}

	
	
	
	event OnHit(damageData : W3DamageAction , attackType : name, optional hitAnimationPlayType : EActionHitAnim )
	{
		virtual_parent.ReactToBeingHit(damageData);	
	}
}
