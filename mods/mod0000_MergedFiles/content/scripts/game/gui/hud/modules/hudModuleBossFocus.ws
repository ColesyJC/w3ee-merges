/***********************************************************************/
/** 	© 2015 CD PROJEKT S.A. All rights reserved.
/** 	THE WITCHER® is a trademark of CD PROJEKT S. A.
/** 	The Witcher game is based on the prose of Andrzej Sapkowski.
/***********************************************************************/




class CR4HudModuleBossFocus extends CR4HudModuleBase
{	
	
	
	
	
	private var m_bossEntity				: CActor;
	private var m_bossName					: string;

	private	var m_fxSetBossName				: CScriptedFlashFunction;
	private	var m_fxSetBossHealth			: CScriptedFlashFunction;
	private	var m_fxSetEssenceDamage		: CScriptedFlashFunction;
	private var m_lastHealthPercentage		: int;
	
	private var m_delay						: float; default m_delay = 1;

	
	
	 event OnConfigUI()
	{
		var flashModule : CScriptedFlashSprite;
		var hud : CR4ScriptedHud;
		
		m_anchorName = "mcAnchorBossFocus";
		
		super.OnConfigUI();
		
		flashModule 			= GetModuleFlash();
		
		m_fxSetBossName			= flashModule.GetMemberFlashFunction( "setBossName" );
		m_fxSetBossHealth		= flashModule.GetMemberFlashFunction( "setBossHealth" );
		m_fxSetEssenceDamage	= flashModule.GetMemberFlashFunction( "setEssenceDamage" );
		
		hud = (CR4ScriptedHud)theGame.GetHud();
		if (hud)
		{
			hud.UpdateHudConfig('BossFocusModule', true);
		}
	}
	
	
	
	public function ShowBossIndicator( enable : bool, bossTag : name, optional bossEntity : CActor )
	{
		if ( enable )
		{
			if( bossEntity )
			{
				m_bossEntity = bossEntity;
				UpdateNameAndHealth( true );
			}
			else
			{
				thePlayer.SetBossTag( bossTag ); 
				UpdateNameAndHealth( true );
			}

		}
		else
		{
			thePlayer.SetBossTag( '' ); 
			
			OnHide();
			
			m_bossEntity = NULL;
			m_bossName = "";
		}
	}

	private function OnShow()
	{
		ShowElement( true ); 
			
		if ( m_bossEntity )
		{
			m_bossEntity.AddTag( 'HideHealthBarModule' );
		}
	}
	
	private  function OnHide()
	{
		ShowElement(false); 
		
		if ( m_bossEntity )
		{
			m_bossEntity.RemoveTag( 'HideHealthBarModule' );
			m_bossEntity = NULL;
			m_bossName = "";
		}
	}
	
	private function UpdateNameAndHealth( onShow : bool )
	{
		var bossName : string;
		var bossTag : name;
		var l_currentHealthPercentage : int;
		
		if ( !m_bossEntity )
		{
			bossTag = thePlayer.GetBossTag(); 
			if ( IsNameValid( bossTag ) )
			{
				m_bossEntity = theGame.GetActorByTag( bossTag );
				if ( m_bossEntity )
				{
					OnShow();
				}
			}
		}
		else
		{
			if( onShow )
			{
				OnShow();
			}
		}
		
		if ( m_bossEntity )
		{
			bossName = m_bossEntity.GetDisplayName();
			if ( onShow || m_bossName != bossName )
			{
				m_bossName = bossName;
				m_fxSetBossName.InvokeSelfOneArg( FlashArgString( m_bossEntity.GetDisplayName() ) );
			}
			if ( onShow )
			{
				// W3EE - Begin
				m_fxSetEssenceDamage.InvokeSelfOneArg( FlashArgBool( ((CNewNPC)m_bossEntity).GetHealthBarType()) );
				// W3EE - End
			}
			
			l_currentHealthPercentage = CeilF( 100 * m_bossEntity.GetHealthPercents() );	
			if ( m_lastHealthPercentage != l_currentHealthPercentage )
			{
				m_fxSetBossHealth.InvokeSelfOneArg( FlashArgInt( l_currentHealthPercentage ) );
				m_lastHealthPercentage = l_currentHealthPercentage;
			}			
		}
	}

	
	
	event OnTick(timeDelta : float)
	{
		if ( m_delay > 0 )
		{
			
			m_delay -= timeDelta;
			return true;
		}
		
		if ( !m_bossEntity )
		{
			
			UpdateNameAndHealth( true );
		}
		else
		{
			
			UpdateNameAndHealth( false );
		}

		//HPAS
		if ( isEditOn() && !m_bossEntity )
		{
			m_fxSetBossName.InvokeSelfOneArg( FlashArgString( "Boss" ) );
			ShowElement(true);
		}
		else if ( !isEditOn() && !m_bossEntity )
		{
			ShowElement(false);
		}
		//HPAS
	}
	
	//HPAS
	protected function UpdatePosition(anchorX:float, anchorY:float) : void
	{
		GetModuleFlash().SetPosition( mHPAS_Pos.Boss('X'), mHPAS_Pos.Boss('Y') );
		if ( !isModOn() ) super.UpdatePosition(anchorX, anchorY);
	}
	
	protected function UpdateScale( scale : float, flashModule : CScriptedFlashSprite ) : bool
	{		
		return super.UpdateScale( scale * BossScale(), flashModule );
	}
	//HPAS
	

}
