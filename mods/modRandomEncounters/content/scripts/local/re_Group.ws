//--- RandomEncounters ---
// Made by Erxv
// http://www.nexusmods.com/witcher3/mods/785?

class CRandomEncounterGroundGroupNPC extends CEntity{
	
	private var rabbit, alphaMonster : CEntity;
	private var isHunt, tracks, playedVoice : bool;
	private var trackTemplate : CEntityTemplate;
	private var prevTracks : array<Vector>;
	private var trackArray, monsters : array<CEntity>;
	private var world : CWorld;
	private var playerPos : Vector;
	
	event OnSpawned( spawnData : SEntitySpawnData ){
		super.OnSpawned(spawnData);
		
		AddTimer('Check', 2, true);
	}
	
	public function SetArray(arr : array<CEntity>, hunt : bool, type : EGroundMonsterType){
		var i : int;
		
		playerPos = thePlayer.GetWorldPosition();
		world = theGame.GetWorld();
		this.monsters = arr;
		this.alphaMonster = arr[0];
		this.isHunt = hunt;
		

		if (hunt){
			tracks = true;
			if (type == GM_WRAITH || type == GM_HARPY || type == GM_SPIDER || type == GM_ECHINOPS || type == GM_CENTIEDE || type == GM_SKELETON)
			{
				tracks = false;
			}
			else
			{
				trackTemplate = (CEntityTemplate)LoadResource( "quests\generic_quests\skellige\quest_files\mh202_nekker_warrior\entities\mh202_nekker_tracks.w2ent", true);
				
				for(i=0;i<arr.Size();i+=1){
					prevTracks.PushBack( Vector(0,0,0) );
				}
			}
		}	
		
		SpawnRabbit();
		if(tracks)
			AddTimer('Tracks',0.7,true);
	}
	
	private function SpawnRabbit(){
		var resourcePath : string;
		var template : CEntityTemplate;
		var pos : Vector;
		var rot : EulerAngles;
		
		resourcePath = "characters\npc_entities\animals\hare.w2ent";
        template = (CEntityTemplate)LoadResource( resourcePath, true );			
		
		if(isHunt){
			pos = alphaMonster.GetWorldPosition() + VecConeRand(alphaMonster.GetHeading(), 20, 10, 10);
		}else{
			pos = thePlayer.GetWorldPosition() + VecRingRand(10,15);
		}
		
		rabbit = theGame.CreateEntity(template, pos, rot);		

        ((CNewNPC)rabbit).SetGameplayVisibility(false);
        ((CNewNPC)rabbit).SetVisibility(false);		
        ((CActor)rabbit).EnableCharacterCollisions(false);
        ((CActor)rabbit).EnableDynamicCollisions(false);
        ((CActor)rabbit).EnableStaticCollisions(false);
        ((CActor)rabbit).SetImmortalityMode(AIM_Immortal, AIC_Default);			
		
		AddTimer('RabbitTeleport', 2, true);
	}
	
	timer function RabbitTeleport ( optional dt : float, optional id : Int32 )	{
		var pos : Vector;
		var rot : EulerAngles;
		var movespeed : float;
		var i : int;
		var movecomp : CMovingAgentComponent;
		
		playerPos = thePlayer.GetWorldPosition();
		
		if(!isHunt){
			pos = playerPos + VecRingRand(10,15);
			rabbit.Teleport(pos);
						
			for(i=0;i<monsters.Size();i+=1){			
				if( VecDistance(monsters[i].GetWorldPosition(),  playerPos) < 20  ){									
					for(i=0;i<monsters.Size();i+=1){
						((CNewNPC)monsters[i]).NoticeActor(thePlayer);
					}	
					rabbit.Destroy();	
					RemoveTimer('RabbitTeleport');
					break;
				}else{
					for(i=0;i<monsters.Size();i+=1){
						((CNewNPC)monsters[i]).NoticeActor(((CActor)rabbit));
					}	
				}	
			}
		}else{
			pos = alphaMonster.GetWorldPosition() + VecConeRand(alphaMonster.GetHeading(), 50, 17, 17);
			rot = alphaMonster.GetWorldRotation();
			rot.Yaw += RandRange(-20,20);
			
			rabbit.TeleportWithRotation(pos, rot);
			
			for(i=0;i<monsters.Size();i+=1){
				if(VecDistance(monsters[i].GetWorldPosition(),  playerPos) < 16){
					for(i=0;i<monsters.Size();i+=1){
						((CNewNPC)monsters[i]).NoticeActor(thePlayer);
					}
					rabbit.Destroy();	
					RemoveTimer('RabbitTeleport');
					break;
				}else{
					for(i=0;i<monsters.Size();i+=1){
						((CNewNPC)monsters[i]).NoticeActor(((CActor)rabbit));
					}
				}
				
				if( ((CActor)monsters[i]).GetTarget() != thePlayer )
				{
					movespeed = -1;
				}
				else
				{
					movespeed = 1;
				}
				movecomp = ((CActor)monsters[i]).GetMovingAgentComponent();
				movecomp.SetGameplayRelativeMoveSpeed(movespeed);	
			}		
		}
	}
	
		
	timer function Tracks ( optional dt : float, optional id : Int32 )	{
		var trackPosDist, distanceBetweenActor : float;
		var track : CEntity;	
		var i : int;
		var pos : Vector;
		var rot : EulerAngles;
	
		playerPos = thePlayer.GetWorldPosition();
		for(i=0; i < monsters.Size();i+=1){
			pos = monsters[i].GetWorldPosition();
			distanceBetweenActor = VecDistance(pos, playerPos );
			
			if(	distanceBetweenActor > 15 )
			{
				FixZAxis(pos);

				trackPosDist = VecDistance( prevTracks[i], pos );
					
				if (trackPosDist > 1)
				{
					if (pos.Z >= world.GetWaterLevel(pos, true))
					{
						rot = monsters[i].GetWorldRotation();
						track = theGame.CreateEntity(trackTemplate, pos, rot );
						trackArray.PushBack(track);
					}

					prevTracks[i] = pos;
				}	
				
				if (trackArray.Size() > 200)
				{
					trackArray[0].Destroy();
					trackArray.Remove(trackArray[0]);					
				}		
			}
		}	
	}
	
	timer function Check ( optional dt : float, optional id : Int32 )	{
		var dist, distanceBetweenTrack : float;
		var i : int;
		var pos : Vector;
		var allDead : bool;
		
		playerPos = thePlayer.GetWorldPosition();
		
		allDead = true;
		for(i=0; i < monsters.Size();i+=1){
			pos = monsters[i].GetWorldPosition();
			dist = VecDistance(pos,playerPos); 
						
			if(!isHunt){
				if (dist > 200){
					((CActor)monsters[i]).Kill('RandomEncounters', true);
					monsters[i].Destroy();
				}
			}else{
				if (dist > 250){
					((CActor)monsters[i]).Kill('RandomEncounters', true);
					monsters[i].Destroy();
				}
			}
			
			if( (monsters[i] && ((CActor)monsters[i]).IsAlive())){
				allDead = false;
			}
		}	
			
		for(i=0;i<trackArray.Size();i+=1)
		{		
			// --- Destroys track when too far ---
			distanceBetweenTrack = VecDistance(trackArray[i].GetWorldPosition(), thePlayer.GetWorldPosition());
			if (distanceBetweenTrack > 300)
			{
				trackArray[i].Destroy();
				trackArray.Remove(trackArray[i]);	
				i -= 1;
				continue;
			}
			
			// --- Plays voice when close enough ---
			if (distanceBetweenTrack < 11 && !playedVoice && !thePlayer.IsInCombat() && !allDead)
			{
				thePlayer.PlayVoiceset( 90, "MiscInvestigateArea" );
				AddTimer('VoiceTracks',2.9,false);
				playedVoice = true;
			}
		}	

		
		if(allDead){
			Clean();
		}
	}
	
	
	
	private function Clean(){
		var i : int;
		
		for(i = 0; i < trackArray.Size(); i+=1){
			trackArray[i].Destroy();
		}
		trackArray.Clear();
		
		
		for(i=0; i < monsters.Size();i+=1){
			if( VecDistance(monsters[i].GetWorldPosition(),thePlayer.GetWorldPosition()) > 150 )
				monsters[i].Destroy();
		}
		
		
			
		rabbit.Destroy();
		
		RemoveTimer('RabbitTeleport');
		RemoveTimer('Tracks');
		RemoveTimer('Check');
		this.Destroy();
	}
	
	timer function VoiceTracks ( optional dt : float, optional id : Int32 )
	{	
		thePlayer.PlayVoiceset( 90, "MiscFreshTracks" );  
	}	

}