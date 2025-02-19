//--- RandomEncounters ---
// Made by Erxv
// http://www.nexusmods.com/witcher3/mods/785?

class CRandomEncounterHumanNPC extends CEntity{
	
	private var humanArray : array<CEntity>;
	
	event OnSpawned( spawnData : SEntitySpawnData ){
		super.OnSpawned(spawnData);
		
		AddTimer('Check', 2, true);
	}
	
	public function SetArray(arr : array<CEntity>){
		this.humanArray = arr;
	}
	
	timer function Check ( optional dt : float, optional id : Int32 )	{
		var aliveCount, i : int;
		var dist : float;
		var playerPos, pos : Vector;
		
		aliveCount = humanArray.Size();
		playerPos = thePlayer.GetWorldPosition();
		
		
		for(i = 0; i < humanArray.Size();i+=1)
		{
			if( !((CActor)humanArray[i]).IsAlive() ){
				aliveCount-=1;
			}else{
				pos = humanArray[i].GetWorldPosition();
				dist = VecDistance(pos,playerPos); 
						
				if(dist > 30 && dist < 100 ){
					((CNewNPC)humanArray[i]).NoticeActor(thePlayer);
				}else if (dist > 100){
					((CActor)humanArray[i]).Kill('RandomEncounters', true);
					humanArray[i].Destroy();
				}
			}
		}	

		if(aliveCount < 1){
			RemoveTimer('Check');
			this.Destroy();
		}
	}
	
	timer function BattleCry ( optional dt : float, optional id : Int32 ){	
		thePlayer.PlayVoiceset( 90, "BattleCryBadSituation" );
	}
}