/***********************************************************************/
/** 	© 2015 CD PROJEKT S.A. All rights reserved.
/** 	THE WITCHER® is a trademark of CD PROJEKT S. A.
/** 	The Witcher game is based on the prose of Andrzej Sapkowski.
/***********************************************************************/


// W3EE - Begin
class W3Potion_GoldenOriole extends CBaseGameplayEffect
{
	default effectType = EET_GoldenOriole;
	
	event OnEffectAdded(optional customParams : W3BuffCustomParams)
	{
		super.OnEffectAdded(customParams);
		
		if(GetBuffLevel() <= 3)
		{
			target.RemoveAllBuffsOfType(EET_PoisonCritical);
		}
	}
	
	event OnEffectAddedPost()
	{
		super.OnEffectAddedPost();
		
		((W3Effect_Poison)target.GetBuff(EET_Poison)).ResetStackTimer();
	}

	
	public function CumulateWith(effect: CBaseGameplayEffect)
	{
		super.CumulateWith(effect);
		
		if(GetBuffLevel() <= 3)
		{
			target.RemoveAllBuffsOfType(EET_PoisonCritical);
		}
	}
	
	
	
	
	/*
	protected function GetEffectStrength() : float
	{		
		var i : int;
		var val, tmp : SAbilityAttributeValue;
		var ret : float;
		var isPoint : bool;
		var dm : CDefinitionsManagerAccessor;
		var atts : array<name>;
		
		dm.GetAbilityAttributes(abilityName, atts);
		
		
		for(i=0; i<atts.Size(); i+=1)
		{
			if(IsNonPhysicalResistStat(ResistStatNameToEnum(atts[i], isPoint)))
			{
				dm.GetAbilityAttributeValue(abilityName, atts[i], val, tmp);
				
				if(isPoint)
					ret += CalculateAttributeValue(val);
				else
					ret += 100 * CalculateAttributeValue(val);
			}
		}

		return ret;
	}*/
}
// W3EE - End