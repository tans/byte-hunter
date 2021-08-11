require("dotenv").config path: "../.env"
db = require "../db"
monk = require "monk"

doAsync = ->
	await db.CONTACT.findOneAndUpdate
		_id: monk.id "6112f290aca53918b9de345a"
	,
		$set:
			coolTime: new Date()

	await db.CONTACT.findOneAndUpdate
		_id: monk.id "6112f06caca53918b9de246c"
	,
		$set:
			coolTime: new Date()

doAsync().then()
