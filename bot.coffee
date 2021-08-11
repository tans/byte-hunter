require("dotenv").config()

db = require "./db"
schedule = require "node-schedule"
_ = require "lodash"
qrTerm = require "qrcode-terminal"
{ Wechaty } = require "wechaty"
{ EventLogger } = require "wechaty-plugin-contrib"
moment = require "moment"
moment.locale "zh-cn"
bot = new Wechaty(
	puppet: "wechaty-puppet-service"
	puppetOptions:
		token: process.env.WECHATY_TOEKN
)

sleep = ->
	new Promise (resolve) ->
		setTimeout resolve, _.random(1.2, 3.2) * 1000

bot.use EventLogger()

bot.on "scan", (qrcode) ->
	qrTerm.generate qrcode, small: true

bot.on "room-invite", (roomInvitation) ->
	await roomInvitation.accept()

bot.on "friendship", (fs) ->
	switch fs.type()
		when bot.Friendship.Type.Receive
			await fs.accept()
		when bot.Friendship.Type.Confirm
			contact = fs.contact()
			await updateContact contact
			await sendWelcome contact

bot.on "room-join", (room, inviteeList, inviter) ->
	await updateRoom room
	for invitee in inviteeList
		if invitee.self()
			await room.say(
				"欢迎来到《字节猎人》世界，数码怪物正在靠近，请大家准备迎击。"
			)
			await nextBattle room, 1

	await currentBattle room

bot.on "message", (msg) ->
	room = msg.room()
	contact = msg.talker()
	if !room
		return sendWelcome contact

	if msg.text() is "攻击"
		await updateContact contact
		return await attack room, contact

	if msg.text() is "我的"
		c = await db.CONTACT.findOne id: contact.id
		return await room.say "当前战力#{c.ack or 0}", contact

	if msg.text() is "刷新怪物"
		return await nextBattle room

	if ["帮助", "help", "指令"].includes msg.text()
		return await sendCommand room

	if msg.text() is "当前战斗"
		b =
			await db.BATTLE.findOne
				roomid: room.id
				status: 1
		if b
			return room.say(
				"#{b.monster.name} HP值 #{b.monster.hp} 已受到#{b.damage}伤害"
			)
		else
			return room.say "当前没有战斗"
	mentionSelf = await msg.mentionSelf()
	mentionList = await msg.mentionList()
	if mentionSelf and mentionList.length is 1
		await sendRoomTips room
		await sleep()
		await currentBattle room
bot.start()

sendCommand = (room) ->
	await room.say """
		攻击 - 当前战斗参与发起攻击 
		当前战斗 - 查看当前战斗信息
		我的 - 查看我的战力等信息
		"""
sendWelcome = (contact) ->
	# await contact.say "邀请我发起群聊开启新的冒险之旅"

sendRoomTips = (contact) ->
	await contact.say """字节猎人へようこそ
		本周日晚8点开放首个副本《蠕虫洞穴》， 打通可获得特殊技能。

		世界排名即将开放，敬请关注。
		"""
attack = (room, talker) ->
	battle = await db.BATTLE.findOne roomid: room.id, status: 1
	unless battle
		return room.say "上一轮战斗已结束，下一轮尚未开启。", talker
	contact = await db.CONTACT.findOne id: talker.id
	if contact.coolTime and contact.coolTime > new Date()
		return room.say(
			"冷却时间 " + moment(contact.coolTime).calendar()
			talker
		)

	ack = contact.ack or 3
	damage = Math.round ack * _.random 0.5, 1.5

	battle =
		await db.BATTLE.findOneAndUpdate
			_id: battle._id
		,
			$inc:
				damage: damage
			$push:
				damages: [damage, contact.id, contact.name]
	contact =
		await db.CONTACT.findOneAndUpdate
			id: talker.id
		,
			$set:
				coolTime:
					moment()
						.add 10, "minute"
						.toDate()

	await room.say(
		"输出#{damage}伤害， 攻击冷却时间至#{moment(
			contact.coolTime
		).calendar()}"
		talker
	)
	sleep()

	if battle.damages.length is 1
		await db.CONTACT.findOneAndUpdate
			id: talker.id
		,
			$inc:
				ack: battle.monster.award

		await room.say "获得一血，战力提升#{battle.monster.award}", talker
		sleep()

	if battle.damage >= battle.monster.hp
		await db.CONTACT.findOneAndUpdate
			id: talker.id
		,
			$inc:
				ack: battle.monster.award

		await room.say "获得击杀奖励，战力提升#{battle.monster.award}", talker
		sleep()

		await db.BATTLE.findOneAndUpdate { _id: battle._id }, $set: status: -1
		await room.say "战斗胜利"
		await sleep()
		contacts = {}

		for i in battle.damages
			contacts[i[1]] = 0 unless contacts[i[1]]
			contacts[i[1]] += i[0]

		reward = ""
		mvp =
			id: ""
			damage: 0
		for k of contacts
			if contacts[k] > mvp.damage
				mvp =
					id: k
					damage: contacts[k]
			contact =
				await db.CONTACT.findOneAndUpdate
					id: k
				,
					$inc:
						ack: battle.monster.award

			reward += "#{contact.name} 战力获得提升↑#{
				battle.monster.award
			} 现 #{contact.ack}\n"

		console.log mvp
		if mvp.id
			contact =
				await db.CONTACT.findOneAndUpdate
					id: mvp.id
				,
					$inc:
						ack: battle.monster.award
			reward += "(MVP) #{contact.name} 额外提升↑#{battle.monster.award}\n"
			reward += "======\n"

		r =
			await db.ROOM.findOneAndUpdate
				id: room.id
			,
				$inc:
					ack: battle.monster.award * 2

		reward += "群聊战力提升至 #{r.ack}"
		await room.say reward
		await sleep()
		await nextBattle room

currentBattle = (room) ->
	battle =
		await db.BATTLE.findOne
			roomid: room.id
			status: 1

	if battle
		return await room.say(
			"#{battle.monster.name}正入侵，回复【攻击】参与战斗"
		)

	battle =
		await db.BATTLE.findOne
			roomid: room.id
			status: 0

	if battle
		return await room.say(
			"#{battle.monster.name} 将在#{moment(
				battle.startTime
			).calendar()} 入侵，全员准备。"
		)

	await nextBattle room

nextBattle = (room, nodelay = 0) ->
	battle =
		await db.BATTLE.findOne
			roomid: room.id
			status:
				$gte: 0
	return if battle
	r = await db.ROOM.findOne id: room.id
	ack = r?.ack or 0

	monster =
		await db.MONSTER.findOne
			down:
				$lte: ack
			up:
				$gt: ack

	startTime = if nodelay
		new Date()
	else
		moment()
			.add monster.delay, "s"
			.toDate()
	await db.BATTLE.insert
		monster: monster
		roomid: room.id
		startTime: startTime
		status: if nodelay then 1 else 0
	if nodelay
		await room.say "#{monster.name}出现，成员回复【攻击】开始战斗。"
	else
		await room.say "下一袭击将在#{monster.delay / 60}分钟后到来，请做好准备"
updateRoom = (room) ->
	await db.ROOM.findOneAndUpdate
		id: room.id
	,
		$set: room.payload
	,
		upsert: true

updateContact = (contact) ->
	await db.CONTACT.findOneAndUpdate
		id: contact.id
	,
		$set: contact.payload
	,
		upsert: true

schedule.scheduleJob "* * * * *", ->
	battles =
		await db.BATTLE.find
			status: 0
			startTime:
				$lt: new Date()
	console.log "战斗开始" + battles.length
	for battle in battles
		await db.BATTLE.findOneAndUpdate { _id: battle._id }, $set: status: 1
		room = await bot.Room.load battle.roomid
		await room.say "#{battle.monster.name}出现，成员回复【攻击】开始战斗。"

#EOF
