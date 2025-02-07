//--- RandomEncounters ---
// Made by Erxv
enum EREZone
{
    REZ_UNDEF   = 0,
    REZ_NOSPAWN = 1,
    REZ_SWAMP   = 2,
	REZ_CITY    = 3,
}
class CModRExtra extends CRandomEncounters
{ 
	public function getCustomZone(pos : Vector) : EREZone
	{
		var zone : EREZone;
		var currentArea : string;
		 
		zone = REZ_UNDEF;
		currentArea = AreaTypeToName(theGame.GetCommonMapManager().GetCurrentArea());
		 
		if (currentArea == "novigrad")
		{
			if ( (pos.X < 730 && pos.X > 290)  && (pos.Y < 2330 && pos.Y > 1630))
			{
				//zone = "novigrad";
				zone = REZ_CITY;
			} 
			else if ( (pos.X < 730 && pos.X > 450)  && (pos.Y < 1640 && pos.Y > 1530))
			{
				//zone = "novigrad";
				zone = REZ_CITY;
			} 
			else if ( (pos.X < 930 && pos.X > 700)  && (pos.Y < 2080 && pos.Y > 1635))
			{
				//zone = "novigrad";
				zone = REZ_CITY;
			} 
			else if ( (pos.X < 1900 && pos.X > 1600)  && (pos.Y < 1200 && pos.Y > 700))
			{
				//zone = "oxenfurt";
				zone = REZ_CITY;
			}
			else if ( (pos.X < 315 && pos.X > 95)  && (pos.Y < 240 && pos.Y > 20))
			{
				//zone = "crows";
				zone = REZ_CITY;
			}
			else if ( (pos.X < 2350 && pos.X > 2200)  && (pos.Y < 2600 && pos.Y > 2450))
			{
				//zone = "HoS Wedding";
				zone = REZ_NOSPAWN;
			}
			else if ( (pos.X < 2255 && pos.X > 2135)  && (pos.Y < 2180 && pos.Y > 2010))
			{
				//zone = "HoS Creepy Mansion";
				zone = REZ_NOSPAWN;
			}
			else if ( (pos.X < 1550 && pos.X > 930)  && (pos.Y < 1320 && pos.Y > 950))
			{
				zone = REZ_SWAMP;
			}
			else if ( (pos.X < 1400 && pos.X > 940)  && (pos.Y < -460 && pos.Y > -720))
			{
				zone = REZ_SWAMP;
			}
			else if ( (pos.X < 1790 && pos.X > 1320)  && (pos.Y < -400 && pos.Y > -540))
			{
				zone = REZ_SWAMP;
			}
			else if ( (pos.X < 2150 && pos.X > 1750)  && (pos.Y < -490 && pos.Y > -1090))
			{
				zone = REZ_SWAMP;
			}
		}
		else if (currentArea == "skellige")
		{
			if ( (pos.X < 30 && pos.X > -290)  && (pos.Y < 790 && pos.Y > 470))
			{
				//zone = "trolde";
				zone = REZ_CITY;
			}
		}
		else if (currentArea == "bob")
		{
			if ( (pos.X < -292 && pos.X > -417)  && (pos.Y < -755 && pos.Y > -872))
			{
				//zone = "corvo";
				zone = REZ_NOSPAWN;
			}
			else if ( (pos.X < -414 && pos.X > -636)  && (pos.Y < -863 && pos.Y > -1088))
			{
				//zone = "tourney";
				zone = REZ_NOSPAWN;
			}
			else if ( (pos.X < -142 && pos.X > -871)  && (pos.Y < -1082 && pos.Y > -1637))
			{
				//zone = "city";
				zone = REZ_CITY;
			}
		} 
		else if (currentArea == "wyzima_castle" || currentArea == "island_of_mist" || currentArea == "spiral")
		{
			zone = REZ_NOSPAWN;
		} 
	
	return zone; 
	} 
}