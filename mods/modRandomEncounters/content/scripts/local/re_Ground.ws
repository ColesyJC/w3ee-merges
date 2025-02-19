//--- RandomEncounters ---
// Made by Erxv
// http://www.nexusmods.com/witcher3/mods/785?


class CRandomEncounterGroundSoloNPC extends CEntity{
	
	private var monster, rabbit : CEntity;
	private var monsterActor : CActor;
	private var monsterNPC : CNewNPC;
	private var isHunt, tracks, playedVoice : bool;
	private var trackTemplate : CEntityTemplate;
	private var prevTrack : Vector;
	private var trackArray : array<CEntity>;
	private var world : CWorld;
	private var playerPos : Vector;
	
	event OnSpawned( spawnData : SEntitySpawnData ){
		super.OnSpawned(spawnData);

		AddTimer('Check', 2, true);
	}
	
	public function SetArray(arr : array<CEntity>, hunt : bool, type : EGroundMonsterType){
		playerPos = thePlayer.GetWorldPosition();
		world = theGame.GetWorld();
		this.monster = arr[0];
		this.monsterActor = ((CActor)arr[0]);
		this.monsterNPC = ((CNewNPC)arr[0]);
		this.isHunt = hunt;
		
		this.CreateAttachment( monster );
		
		if (hunt){
			tracks = true;
			if (type == GM_WEREWOLF || type == GM_BEAR || type == GM_KATAKAN || type == GM_EKIMMARA || type == GM_FLEDER || type == GM_GARKAIN)
			{	
				trackTemplate = (CEntityTemplate)LoadResource( "quests\generic_quests\no_mans_land\quest_files\mh108_fogling\entities\mh108_clue_fogling_tracks.w2ent", true);
			}
			else if (type == GM_CHORT || type == GM_FIEND)
			{
				trackTemplate = (CEntityTemplate)LoadResource( "quests\generic_quests\skellige\quest_files\mh206_fiend_ruins\entities\mh206_fiend_tracks_single_back.w2ent", true);
			}
			else if (type == GM_DETLAFF || type == GM_BRUXA || type == GM_NOONWRAITH || type == GM_NIGHTWRAITH)
			{
				tracks = false;
			}
			else
			{
				trackTemplate = (CEntityTemplate)LoadResource( "quests\generic_quests\skellige\quest_files\mh202_nekker_warrior\entities\mh202_nekker_tracks.w2ent", true);
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
			pos = monster.GetWorldPosition() + VecConeRand(monster.GetHeading(), 20, 19, 19);
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
		var movecomp : CMovingAgentComponent;
		var movespeed : float;
		
		if(!isHunt){
			pos = playerPos + VecRingRand(10,15);
			rabbit.Teleport(pos);
			
			if(!monsterActor.IsAlive() || (VecDistance(monster.GetWorldPosition(),  playerPos) < 20) || !monster  ){
				rabbit.Destroy();
				monsterNPC.NoticeActor(thePlayer);
				RemoveTimer('RabbitTeleport');
			}else{
				monsterNPC.NoticeActor(((CActor)rabbit));
			}		
		}else{
			pos = monster.GetWorldPosition() + VecConeRand(monster.GetHeading(), 50, 17, 17);
			rot = monster.GetWorldRotation();
			rot.Yaw += RandRange(-20,20);
			
			rabbit.TeleportWithRotation(pos, rot);
			
			if(!monsterActor.IsAlive() || (VecDistance(monster.GetWorldPosition(),  playerPos) < 15) || !monster  ){
				rabbit.Destroy();
				monsterNPC.NoticeActor(thePlayer);
				RemoveTimer('RabbitTeleport');
			}else{
				monsterNPC.NoticeActor(((CActor)rabbit));
			}
			
			if( monsterActor.GetTarget() != thePlayer )
			{
				movespeed = -1;
			}
			else
			{
				movespeed = 1;
			}
			movecomp = monsterActor.GetMovingAgentComponent();
			movecomp.SetGameplayRelativeMoveSpeed(movespeed);	
		}
	}
	
		
	timer function Tracks ( optional dt : float, optional id : Int32 )	{
		var trackPosDist, distanceBetweenActor : float;
		var track : CEntity;	
		var i : int;
		var pos : Vector;
		var rot : EulerAngles;
	
		pos = monster.GetWorldPosition();
		distanceBetweenActor = VecDistance(pos, playerPos);
		
		if(	distanceBetweenActor > 15 )
		{
			FixZAxis(pos);

			trackPosDist =  VecDistance( prevTrack, pos );
				
			if (trackPosDist > 1)
			{
                if (pos.Z >= world.GetWaterLevel(pos, true))
                {
					rot = monster.GetWorldRotation();
                    track = theGame.CreateEntity(trackTemplate, pos, rot );
                    trackArray.PushBack(track);
                }

				prevTrack = pos;
			}	
			
			if (trackArray.Size() > 200)
			{
				trackArray[0].Destroy();
				trackArray.Remove(trackArray[0]);					
			}		
		}
	}
	
	timer function Check ( optional dt : float, optional id : Int32 )	{
		var dist, distanceBetweenTrack : float;
		var i : int;
		var pos : Vector;		
		
		playerPos = thePlayer.GetWorldPosition();
		

		pos = monster.GetWorldPosition();
		dist = VecDistance(pos,playerPos); 
					
		if(!isHunt){
			if (dist > 200){
				monsterActor.Kill('RandomEncounters', true);
				monster.Destroy();
			}
		}else{
			if (dist > 250){
				monsterActor.Kill('RandomEncounters', true);
				monster.Destroy();
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
			if (distanceBetweenTrack < 11 && !playedVoice && !thePlayer.IsInCombat() && monsterActor.IsAlive())
			{
				thePlayer.PlayVoiceset( 90, "MiscInvestigateArea" );
                AddTimer('VoiceTracks',2.9,false);
                playedVoice = true;
			}
		}	

		if(!monster || !monsterActor.IsAlive()){
			Clean();
		}
	}
	
	
	
	private function Clean(){
		var i : int;
		
		for(i = 0; i < trackArray.Size(); i+=1){
			trackArray[i].Destroy();
		}
		trackArray.Clear();
		
		if( VecDistance(monster.GetWorldPosition(),thePlayer.GetWorldPosition()) > 150 )
			monster.Destroy();
			
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
	
	
	
	

	
	