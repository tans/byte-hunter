require("dotenv").config path: "../.env"
db = require "../db"

monsters = [
	name: "蠕虫worm"
	hp: 50
	down: 0
	up: 20
	delay: 600
	award: 1
,
	name: "速龙creeper"
	hp: 100
	down: 20
	up: 100
	delay: 3600
	award: 10
,
	name: "巨蟒elk cloner"
	hp: 500
	down: 100
	up: 1000
	delay: 7200
	award: 20
,
	name: "幽灵melissa"
	hp: 5000
	down: 1000
	award: 50
	delay: 7200
]

doAsync = ->
	for monster in monsters
		await db.MONSTER.insert monster

doAsync().then()
