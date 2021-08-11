monk = require "monk"

DB = monk process.env.MONGODB
prefix = "hunter_"

CONTACT = DB.get prefix + "contact"
ROOM = DB.get prefix + "room"
MONSTER = DB.get prefix + "monster"
BATTLE = DB.get prefix + "battle"

module.exports =
	ROOM: ROOM
	CONTACT: CONTACT
	MONSTER: MONSTER
	BATTLE: BATTLE
