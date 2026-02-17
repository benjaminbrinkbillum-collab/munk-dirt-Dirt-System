Config = {}

Config.DirtIncreaseInterval = 30 -- seconds (a bit faster than vanilla)
Config.BaseIncrease = 2.0 -- still faster than vanilla
Config.RainMultiplier = 2.0 -- rain doubles dirt gain
Config.OffroadMultiplier = 3.0 -- offroad triples dirt gain
Config.MaxDirt = 100.0
Config.SaveToDatabase = true -- Set to false to disable MySQL saving

-- Oil zones: Coordinates for harbor/factory area (Los Santos Docks)
Config.OilZones = {
	{center = vector3(800.0, -3000.0, 0.0), radius = 400.0}, -- Docks
	{center = vector3(1000.0, -2500.0, 0.0), radius = 300.0}, -- Factory area
}
Config.OilDirtBonus = 7.0 -- how much extra dirt the car gets in oil zone
