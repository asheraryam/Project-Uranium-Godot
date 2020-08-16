extends Object
class_name BattleLogic

var turn_order = []
var queue
enum {B1 = 1, B2 = 2, B3 = 3, B4 = 4} # Used for turn order and indicating which poke in battle

var battler1 : Pokemon # Player's pokemon
var battler2 : Pokemon # Foe's pokemon
var battler3 : Pokemon # Player's second pokemon in double battles
var battler4 : Pokemon # Foe's second pokemonin double battles

var battler1_stat_stage : BattleStatStage
var battler2_stat_stage : BattleStatStage
var battler3_stat_stage : BattleStatStage
var battler4_stat_stage : BattleStatStage

var battler1_effects = []
var battler2_effects = []
var battler3_effects = []
var battler4_effects = []

var battle_instance : BattleInstanceData

var item_database

var battle_debug = false

var escape_attempts = 0
var can_escape = false

func _init(b1, b2 , bid):
	battler1 = b1
	battler2 = b2
	battler1_stat_stage = BattleStatStage.new()
	battler2_stat_stage = BattleStatStage.new()
	battle_instance = bid
	item_database = load("res://Utilities/Items/database.gd").new()
	pass
func generate_action_queue(player_command : BattleCommand, foe_command : BattleCommand):
	queue = BattleQueue.new()
	var action
	get_turn_order(player_command, foe_command)
	
	if can_escape == true && player_command.command_type == player_command.RUN:
		action = BattleQueueAction.new()
		action.type = action.ESCAPE_SE
		queue.push(action)
		
		action = BattleQueueAction.new()
		action.type = action.BATTLE_TEXT
		action.battle_text = "Got away safely!"
		action.press_to_continue = true
		queue.push(action)

		action = BattleQueueAction.new()
		action.type = action.BATTLE_END
		action.winner = action.PLAYER_WIN
		action.run_away = true
		queue.push(action)
		return queue
	if can_escape == false && player_command.command_type == player_command.RUN:
		action = BattleQueueAction.new()
		action.type = action.BATTLE_TEXT
		action.battle_text = "Can't escape!"
		queue.push(action)
	
	if player_command.command_type == player_command.USE_BAG_ITEM:
		print("Using item: " + str(player_command.item))
		if player_command.item >= 208 && player_command.item <= 232 && battle_instance.battle_type == BattleInstanceData.BattleType.SINGLE_WILD: # Item is a type of pokeball
			action = BattleQueueAction.new()
			action.type = action.SET_BALL
			action.ball_type = player_command.item
			queue.push(action)
			# Capture wild pokemon
			var a : int# Modified catch rate
			var b : int# Shake probability
			var target = get_battler_by_index(player_command.attack_target)
			var bonus_ball = get_ball_catch_rate(player_command.item)
			var bonus_status = 1
			var broke_out = false
			var shakes = 0
			

			match target.major_ailment:
				MajorAilment.SLEEP, MajorAilment.FROZEN:
					bonus_status = 2.5
				MajorAilment.PARALYSIS, MajorAilment.POISON, MajorAilment.BURN:
					bonus_status = 1.5

			a = (3 * target.hp - 2 * target.current_hp) * target.catch_rate * bonus_ball

			a = a / (3 * target.hp) * bonus_status
			if a > 255:
				a = 255

			b = 65536 / sqrt(255.0 / a) # Gen 5

			# Add actions
			action = BattleQueueAction.new()
			action.type = action.BATTLE_TEXT
			action.battle_text = Global.TrainerName + " threw a " + item_database.get_item_by_id(player_command.item).name + "."
			queue.push(action)
			
			action = BattleQueueAction.new()
			action.type = action.BATTLE_GROUNDS_POS_CHANGE
			action.battle_grounds_pos_change = 6 #CAPTURE_ZOOM
			queue.push(action)

			action = BattleQueueAction.new()
			action.type = action.BALL_CAPTURE_TOSS
			queue.push(action)

			var rng = RandomNumberGenerator.new()
			rng.randomize()
			for i in range(4):
				var shake = rng.randi_range(0, 65535)
				shakes += 1
				if b > shake:
					continue
				else:
					broke_out = true
					break
			
			for i in range(shakes):
				action = BattleQueueAction.new()
				action.type = action.BALL_SHAKE
				queue.push(action)
			
			if broke_out:
				action = BattleQueueAction.new()
				action.type = action.BALL_BROKE
				queue.push(action)

				action = BattleQueueAction.new()
				action.type = action.BATTLE_TEXT
				action.battle_text = get_battler_title_by_index(player_command.attack_target) + " broke free!"
				queue.push(action)

				action = BattleQueueAction.new()
				action.type = action.BATTLE_GROUNDS_POS_CHANGE
				action.battle_grounds_pos_change = 7 #CAPTURE_ZOOM_BACK
				queue.push(action)
			else:
				# Capture sucsesful
				action = BattleQueueAction.new()
				action.type = action.BALL_CAPTURE_SONG
				queue.push(action)
				return queue

		
	
	var battler # The pokemon preforming the move
	var battler_index # The index of the pokemon preforming the move
	var command
	while !turn_order.empty():
		var turn = turn_order.pop_front()
		match turn:
			B1:
				battler = battler1
				command = player_command
				battler_index = 1
			B2:
				battler = battler2
				command = foe_command
				battler_index = 2
			B3:
				battler = battler3
				battler_index = 3
			B4:
				battler = battler4
				battler_index = 4

		if command.command_type == command.ATTACK:

			# Preturn Major Ailments
			var skip_turn = false
			for battler_ailment_index in range(1,5):
				var battler_ailment = get_battler_by_index(battler_ailment_index)
				
				if battler_ailment != null && battler_ailment.major_ailment != null:
					match battler_ailment.major_ailment:
						MajorAilment.FROZEN:
							if percent_chance(0.2):
								# Thaw out
								action = BattleQueueAction.new()
								action.type = action.BATTLE_TEXT
								action.battle_text = get_battler_title_by_index(battler_index) + " is\nthawed out!"
								queue.push(action)

								battler_ailment.major_ailment = null
								action = BattleQueueAction.new()
								action.type = action.UPDATE_MAJOR_AILMENT
								action.damage_target_index = battler_ailment_index
								queue.push(action)
							else:
								action = BattleQueueAction.new()
								action.type = action.BATTLE_TEXT
								action.battle_text = get_battler_title_by_index(battler_index) + " is\nfrozen solid!"
								queue.push(action)
								skip_turn = true
						MajorAilment.SLEEP:
							if get_effect_from_effects(BattleEffect.SLEEP_COUNTER, battler_ailment_index).sleep_count == 0:
								action = BattleQueueAction.new()
								action.type = action.BATTLE_TEXT
								action.battle_text = get_battler_title_by_index(battler_index) + " woke up!"
								queue.push(action)
								battler_ailment.major_ailment = null
								action = BattleQueueAction.new()
								action.type = action.UPDATE_MAJOR_AILMENT
								action.damage_target_index = battler_ailment_index
								queue.push(action)
							else:
								action = BattleQueueAction.new()
								action.type = action.BATTLE_TEXT
								action.battle_text = get_battler_title_by_index(battler_index) + " is\nfast asleep."
								queue.push(action)
								skip_turn = true
						MajorAilment.PARALYSIS:
							if percent_chance(0.25):
								action = BattleQueueAction.new()
								action.type = action.BATTLE_TEXT
								action.battle_text = get_battler_title_by_index(battler_index) + " is\nparalyzed!"
								queue.push(action)
								skip_turn = true	
			if skip_turn:
				continue

			var move
			match command.attack_move:
				battler.move_1.name:
					move = battler.move_1
				battler.move_2.name:
					move = battler.move_2
				battler.move_3.name:
					move = battler.move_3
				battler.move_4.name:
					move = battler.move_4
			action = BattleQueueAction.new()
			action.type = action.BATTLE_TEXT
			action.battle_text = get_battler_title_by_index(battler_index) + " used\n" + command.attack_move + "!"
			queue.push(action)
			# Decrement move PP, PP should be at least 1 at this point.
			if move.remaining_pp == 0:
				print("Battle Error: " + str(move.name) + " PP is zero.")
			move.remaining_pp = move.remaining_pp - 1
			# Calculate if move hits or not
			
			var target_index
			match command.attack_target:
				command.B1:
					target_index = 1
				command.B2:
					target_index = 2
				command.B3:
					target_index = 3
				command.B4:
					target_index = 4
			if does_attack_hit(move, target_index, battler_index):
				if move.base_power != null:
					var did_crit = does_crit(move.critical_hit_level)
						
					# Calculate damage done.
					var raw_damage: int = 0
					var base_damage: int = 0
					var total_damage_modifier: float = 1.0
					var target_modifier: float = 1.0
					var weather_modifier: float = 1.0
					var critical_modifier: float = 1.0
					var STAB_modifier: float = 1.0
					var random_modifier: float = 1.0
					var type_modifer: float = 1.0
					var burn_modifer: float = 1.0
					var other_modifer: float = 1.0

					var effective_attacker_stat = BattleStatStage.get_multiplier(get_stage_stat_by_index(battler_index).attack) * battler.attack

					var effective_defender_stat = BattleStatStage.get_multiplier(get_stage_stat_by_index(target_index).defense) * get_battler_by_index(target_index).defense
					
					base_damage = int(
						( ( (2 * battler.level) / 5 ) + 2 ) * move.base_power * (effective_attacker_stat / effective_defender_stat)
					)
					#warning-ignore:integer_division
					base_damage = (base_damage / 50) + 2
					
					if did_crit:
						critical_modifier = 2.0
					if move.type == battler.type1 || move.type == battler.type2:
						STAB_modifier = 1.5
					var rng = RandomNumberGenerator.new()
					rng.randomize()
					random_modifier = rng.randf_range(0.85,1.0)

					if get_battler_by_index(battler_index).major_ailment == MajorAilment.BURN && move.style == MoveStyle.PHYSICAL:
						burn_modifer = 0.5

					
					type_modifer = Type.type_advantage_multiplier(move.type, get_battler_by_index(target_index))
					total_damage_modifier = target_modifier * weather_modifier * critical_modifier * STAB_modifier * random_modifier * type_modifer * other_modifer
					#warning-ignore:narrowing_conversion
					raw_damage = base_damage * total_damage_modifier

					if battle_debug:
						print("Raw Damage: " + str(raw_damage) + " , To battler: " + str(target_index))

					if raw_damage != 0:
						# Perform the damage to battler
						remove_hp(target_index, raw_damage)
						
						# Add in the battle actions
						action = BattleQueueAction.new()
						action.type = action.DAMAGE
						action.damage_target_index = target_index
						action.damage_effectiveness = type_modifer
						queue.push(action)

						if critical_modifier == 2.0:
							action = BattleQueueAction.new()
							action.type = action.BATTLE_TEXT
							action.battle_text = "Critical Hit!"
							queue.push(action)
						# Add in the effective damage message
						if type_modifer > 1.0:
							action = BattleQueueAction.new()
							action.type = action.BATTLE_TEXT
							action.battle_text = "It's super effective!"
							queue.push(action)
						if type_modifer < 1.0:
							action = BattleQueueAction.new()
							action.type = action.BATTLE_TEXT
							action.battle_text = "It's not very effective..."
							queue.push(action)
							
						if post_damage_checks(target_index):
							return queue

						#Secondary effect
						if move.secondary_effect != null:
							if percent_chance(move.secondary_effect_chance) && get_battler_by_index(target_index).hp != 0:
								set_major_ailment(target_index, move.secondary_effect)

					else:
						action = BattleQueueAction.new()
						action.type = action.BATTLE_TEXT
						action.battle_text = "It does not effect " + get_battler_title_by_index(target_index) + "."
						queue.push(action)

				else: # Move is not a direct attack move

					if move.main_status_effect != null: # Move effect stats
						var stat_effect = move.main_status_effect
						var stats_changed = get_stage_stat_by_index(target_index).apply_stat_effect(stat_effect) # This changes stats of target
							
						# For all stats changed
						for stat in stats_changed:
							var over_limit = false
							if stat.stat_over_limit:
								over_limit = true
							else:
								action = BattleQueueAction.new()
								action.type = action.STAT_CHANGE_ANIMATION
								action.damage_target_index = target_index
								if stat.stat_change > 0: # Increase
									action.stat_change_increase = true
								queue.push(action)

							action = BattleQueueAction.new()
							action.type = action.BATTLE_TEXT
							var stat_effected_name
							match stat.stat_type:
								BattleStatStage.ATTACK:
									stat_effected_name = "Attack"
								BattleStatStage.DEFENSE:
									stat_effected_name = "Defense"
								BattleStatStage.SP_ATTACK:
									stat_effected_name = "Sp. Attack"
								BattleStatStage.SP_DEFENSE:
									stat_effected_name = "Sp. Defense"
								BattleStatStage.SPEED:
									stat_effected_name = "Speed"
								BattleStatStage.ACCURACY:
									stat_effected_name = "Accuracy"
								BattleStatStage.EVASION:
									stat_effected_name = "Evasion"

							action.battle_text = get_battler_title_by_index(target_index) + "'s " + str(stat_effected_name)
							if !over_limit:
								match stat.stat_change:
									1:
										action.battle_text += " rose!"
									2:
										action.battle_text += " sharply rose!"
									3, 4, 5, 6:
										action.battle_text += " rose drastically!"
									-1:
										action.battle_text += " fell!"
									-2:
										action.battle_text += " harshly fell!"
									-3, -4, -5, -6:
										action.battle_text += " severely fell!"
							else:
								match stat.stat_change:
									1,2,3,4,5,6:
										action.battle_text += " won't go any higher!"
									-1,-2,-3,-4,-5,-6:
										action.battle_text += " won't go any lower!"
							queue.push(action)
					else: # Move is something else (Leech Seed, etc.)
						match move.name:
							"Leech Seed":
								# Check if target is already seeded
								var already_seeded = false
								var target = get_battler_by_index(target_index)
								for effects in get_effects_by_index(target_index):
									if effects.effect == BattleEffect.effects.SEEDED:
										already_seeded = true

								# Check if target is grass type
								if target.type1 == Type.GRASS || target.type2 == Type.GRASS:
									# No effect
									action = BattleQueueAction.new()
									action.type = action.BATTLE_TEXT
									action.battle_text = "It does not effect " + get_battler_title_by_index(target_index) + "."
									queue.push(action)
								elif already_seeded: # Check if target is already seeded
									# Fail
									action = BattleQueueAction.new()
									action.type = action.BATTLE_TEXT
									action.battle_text = "But " + get_battler_title_by_index(target_index) + " is already seeded."
									queue.push(action)
								# set seeded flag to target battler
								else:
									var effect = BattleEffect.new()
									effect.effect = BattleEffect.effects.SEEDED
									effect.seeded_heal_target_index = battler_index
									get_effects_by_index(target_index).append(effect)
									action = BattleQueueAction.new()
									action.type = action.BATTLE_TEXT
									action.battle_text = get_battler_title_by_index(target_index) + " was seeded!"
									queue.push(action)
				
			else: # Add missed mesage.
				action = BattleQueueAction.new()
				action.type = action.BATTLE_TEXT
				action.battle_text = get_battler_title_by_index(battler_index) + "'s\nattack missed!"
				queue.push(action)



	# After round actions
	for battler_effects_index in range(1,5):
		var battler_by_index = get_battler_by_index(battler_effects_index)
		# Effects
		for effect in get_effects_by_index(battler_effects_index):
			match effect.effect:
				BattleEffect.effects.SEEDED:
					var damage = battler_by_index.hp / 16
					if damage < 1:
						damage = 1
					remove_hp(battler_effects_index, damage)
					
					# Heal
					var current_hp = get_battler_by_index(effect.seeded_heal_target_index).current_hp
					if current_hp + damage > get_battler_by_index(effect.seeded_heal_target_index).hp:
						get_battler_by_index(effect.seeded_heal_target_index).current_hp = get_battler_by_index(effect.seeded_heal_target_index).hp
					else:
						get_battler_by_index(effect.seeded_heal_target_index).current_hp += damage


					action = BattleQueueAction.new()
					action.type = action.DAMAGE
					action.damage_target_index = battler_effects_index
					action.damage_effectiveness = 1.0
					queue.push(action)

					action = BattleQueueAction.new()
					action.type = action.HEAL
					action.damage_target_index = effect.seeded_heal_target_index
					queue.push(action)

					if post_damage_checks(battler_effects_index):
						return queue
				BattleEffect.effects.SLEEP_COUNTER:
					effect.sleep_count -= 1

	
	# Post-Turn Major Ailments
	for battler_ailment_index in range(1,5):
		var battler_ailment = get_battler_by_index(battler_ailment_index)
		if battler_ailment != null && battler_ailment.major_ailment != null:
			match battler_ailment.major_ailment:
				MajorAilment.BURN:
					var damage = battler_ailment.hp / 8

					if damage < 1:
						damage = 1

					remove_hp(battler_ailment_index, damage)
					action = BattleQueueAction.new()
					action.type = action.DAMAGE
					action.damage_target_index = battler_ailment_index
					action.damage_effectiveness = 1.0
					queue.push(action)

					action = BattleQueueAction.new()
					action.type = action.BATTLE_TEXT
					action.battle_text = get_battler_title_by_index(battler_index) + " is hurt\nby its burn!"
					queue.push(action)

					if post_damage_checks(battler_index):
						return queue
				MajorAilment.POISON: # Note Badly poison mechanic is not implemented
					var damage = battler_ailment.hp / 8

					if damage < 1:
						damage = 1
					remove_hp(battler_ailment_index, damage)
				
					action = BattleQueueAction.new()
					action.type = action.DAMAGE
					action.damage_target_index = battler_ailment_index
					action.damage_effectiveness = 1.0
					queue.push(action)

					action = BattleQueueAction.new()
					action.type = action.BATTLE_TEXT
					action.battle_text = get_battler_title_by_index(battler_index) + " is hurt\nby poison!"
					queue.push(action)

					if post_damage_checks(battler_index):
						return queue

	# Print out the action queue for debug
	if battle_debug:
		print("Action queue size: " + str(queue.queue.size()))
		var action_index = 0
		for actions in queue.queue:
			print("Action #" + str(action_index) + ". Type: " + str (actions.type))# + ". Battler:" + str(action.)
			action_index = action_index + 1
	return queue
func get_turn_order(player_command : BattleCommand, foe_command : BattleCommand): # For single battles
	# Find out which comand goes in which order.
			# General turn order:
			# 1. Item use/Runing
			# 2. Switching
			# 3. Megaevolution
			# 4. Higher priority attack moves
			# 5. Higher speed
			# 6. Random
			
	# Calculate turn_order
	if player_command.command_type == player_command.RUN:
		can_escape = false

		if battler1.speed > battler2.speed:
			can_escape = true
		else:
			escape_attempts += 1
			var f = ( (battler1.speed * 128) / battler2.speed ) + 30 * escape_attempts
			f = posmod(int(f), 256)
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			if rng.randi_range(0,255) < f:
				can_escape = true
		if !can_escape:
			var action = BattleQueueAction.new()
			action.type = action.BATTLE_TEXT
			action.battle_text = "Can't escape!"
			queue.push(action)
			turn_order.push_back(B2)
			return
	if player_command.command_type == player_command.USE_BAG_ITEM:
		turn_order.push_back(B2)
		return

	if player_command.command_type == player_command.ATTACK && foe_command.command_type == foe_command.ATTACK:
		
		print("Proccessing logic for if both commands are attacks")
		
		# Clear out turn array
		turn_order.clear()
		
		# Higher priority attack moves
		# Match attack comand to move.
		var move_b1 = get_poke_move_by_name(battler1, player_command.attack_move)
		var move_b2 = get_poke_move_by_name(battler2, foe_command.attack_move)
		if move_b1.priority > move_b2.priority:
			turn_order.push_back(B1)
			turn_order.push_back(B2)
		elif move_b1.priority < move_b2.priority:
			turn_order.push_back(B2)
			turn_order.push_back(B1)
		else: # If move priority is the same, faster in-battle speed attack moves.
			# Calculate effective in-battle speed
			var b1_speed = battler1.speed
			var b2_speed = battler2.speed
			b1_speed = b1_speed * BattleStatStage.get_multiplier(battler1_stat_stage.speed)
			b2_speed = b2_speed * BattleStatStage.get_multiplier(battler2_stat_stage.speed)
			if battler1.major_ailment == MajorAilment.PARALYSIS:
				b1_speed = b1_speed / 2.0
			if battler2.major_ailment == MajorAilment.PARALYSIS:
				b2_speed = b2_speed / 2.0
			# Check who has higher speed
			if b1_speed > b2_speed:
				turn_order.push_back(B1)
				turn_order.push_back(B2)
			elif b1_speed < b2_speed:
				turn_order.push_back(B2)
				turn_order.push_back(B1)
			else: # Random
				var rng = RandomNumberGenerator.new()
				rng.randomize()
				if rng.randi_range(0,1) == 1:
					turn_order.push_back(B1)
					turn_order.push_back(B2)
				else:
					turn_order.push_back(B2)
					turn_order.push_back(B1)
		#print("Turn order size: " + str(turn_order.size()))
func does_attack_hit(move : Move, target_index : int, attaker_index : int):
	if target_index == attaker_index: # Moves that effects self
		return true

	var target_stage = get_stage_stat_by_index(target_index)
	var attacker_stage = get_stage_stat_by_index(attaker_index)
	var accuracy = move.accuracy * BattleStatStage.get_multiplier(attacker_stage.accuracy - target_stage.evasion)
	
	if accuracy > 100:
		accuracy = 100
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var value = rng.randi_range(0, 99)

	#print("Accuracy is: " + str(accuracy) + ", rng is: " + str(value))

	if accuracy > value:
		return true
	else:
		return false
func get_battler_by_index(index: int):
	match index:
		1:
			return battler1
		2:
			return battler2
		3:
			return battler3
		4:
			return battler4
		_:
			print("Battle Error: invalid index was given returned null")
func get_stage_stat_by_index(index: int):
	match index:
		1:
			return battler1_stat_stage
		2:
			return battler2_stat_stage
		3:
			return battler3_stat_stage
		4:
			return battler4_stat_stage
func get_effects_by_index(index: int):
	match index:
		1:
			return battler1_effects
		2:
			return battler2_effects
		3:
			return battler3_effects
		4:
			return battler4_effects
func get_poke_move_by_name(poke, move_name):
	if poke.move_1 != null:
		if poke.move_1.name == move_name:
			return poke.move_1
	if poke.move_2 != null:
		if poke.move_2.name == move_name:
				return poke.move_2
	if poke.move_3 != null:
		if poke.move_3.name == move_name:
			return poke.move_3
	if poke.move_4 != null:
		if poke.move_4.name == move_name:
			return poke.move_4
func calculate_exp(defeated_poke : Pokemon) -> int:
	var experience : int
	
	var a = 1.0 # Trainer bonus. 1.0 if wild. 1.5 if Trainer.
	var t = 1.0 # Owner bonus. 1.0 if winning pokemon is original owner. 1.5 if traded. TODO: add support
	var b = 0 # Base exp yield of defeated pokemon.
	var e = 1.0 # Lucky Egg bounus. 1.5 if holding Lucky Egg.
	var f = 1.0 # Affection bounus. Not used in Uranium
	var L = 0 # Level of fainted/caught pokemon.
	var p = 1 # Exp Point Power. Not used in Uranium
	var s = 1 # EXP All modifier. TODO: Add support
	var v = 1 # Evolve modifier. Not used in Uranium

	b = defeated_poke.get_exp_yield()

	if battle_instance.battle_type != battle_instance.BattleType.SINGLE_WILD && battle_instance.battle_type != battle_instance.BattleType.DOUBLE_WILD:
		a = 1.5
	L = defeated_poke.level
	experience = int((a * t * b * e * L * p * f * v) / (7 * s))
	return experience
func check_player_out_of_poke() -> bool:
	var result = true
	for poke in Global.pokemon_group:
		if poke.current_hp != 0:
			result = false
	return result
func check_foe_out_of_poke() -> bool:
	var result = true
	for poke in battle_instance.opponent.pokemon_group:
		if poke.current_hp != 0:
			result = false
	return result
func does_crit(crit : int) -> bool: # If move can crit calculate if crit or not.
	var did_crit = false
	var rng = RandomNumberGenerator.new()
	match crit:
		1: # 1/16
			rng.randomize()
			var value = rng.randi_range(1,16)
			if value == 1:
				did_crit = true
		2: # 1/8
			rng.randomize()
			var value = rng.randi_range(1,8)
			if value == 1:
				did_crit = true
		3: # 1/4
			rng.randomize()
			var value = rng.randi_range(1,4)
			if value == 1:
				did_crit = true
		4: # 1/3
			rng.randomize()
			var value = rng.randi_range(1,3)
			if value == 1:
				did_crit = true
		5: # 1/2
			rng.randomize()
			var value = rng.randi_range(1,2)
			if value == 1:
				did_crit = true
	return did_crit
func one_in_n_chance(n : int) -> bool:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var value = rng.randi_range(1,n)
	if value == 1:
		return true
	return false
func percent_chance(n : float) -> bool:
	if one_in_n_chance(1/n):
		return true
	return false
func post_damage_checks(battler_index: int) -> bool: # Checks for when any damage is done to battlers. Returns true is the battle is over.
	# Check if target faints.
	if get_battler_by_index(battler_index).current_hp == 0:
		# Faint actions
		var action = BattleQueueAction.new()
		action.type = action.FAINT
		action.damage_target_index = battler_index
		queue.push(action)

		action = BattleQueueAction.new()
		action.type = action.BATTLE_TEXT
		var get_exp = false
		if battler_index == 2 || battler_index == 4:
			action.battle_text = "The foe " + get_battler_by_index(battler_index).name + " fainted!"
			get_exp = true
		if battler_index == 1 || battler_index == 3:
			action.battle_text = get_battler_by_index(battler_index).name + " fainted!"
		queue.push(action)

		get_battler_by_index(battler_index).major_ailment = null

		
		# If foe faint add exp to player pokemon. For now just only apply to current player pokemon
		if get_exp:
			action = BattleQueueAction.new()
			action.type = action.BATTLE_TEXT
			var exp_gained : int = calculate_exp(get_battler_by_index(battler_index))
			action.battle_text = battler1.name + " gained\n" + str(exp_gained) + " EXP. Points!"
			queue.push(action)
			
			# Add exp to pokemon
			battler1.experience += exp_gained

			# TODO: Add leveling up
			# TODO: Add multiple exp_gain actions if leveling more that 1 time.
			var levelUptimes = battler1.get_level_up_times()
			if levelUptimes == 0: # Did not level up. Just add exp
				#print("Did not level up.")
				action = BattleQueueAction.new()
				action.type = action.EXP_GAIN
				action.exp_gain_percent = battler1.get_exp_bar_percent()
				queue.push(action)
			else:
				for i in range(levelUptimes): # For each time you level up
					#print("Level up.")
					action = BattleQueueAction.new()
					action.type = action.EXP_GAIN
					action.exp_gain_percent = 1.0
					queue.push(action)
					
					action = BattleQueueAction.new()
					action.type = action.LEVEL_UP_SE
					action.level = battler1.level + i + 1
					var new_level = action.level
					queue.push(action)

					action = BattleQueueAction.new()
					action.type = action.BATTLE_TEXT
					action.battle_text = get_battler_title_by_index(1) + " grew to Lv. " + str(new_level) + "!"
					action.press_to_continue = true
					queue.push(action)

					action = BattleQueueAction.new()
					action.type = action.LEVEL_UP
					# Apply Level Up changes to pokemon here:
					battler1.level += 1
					var changes = battler1.update_stats()
					action.level_stat_changes = changes
					
					queue.push(action)





			# Adding effort values
			battler1.add_ev(get_battler_by_index(battler_index))
			
			
		
		# Check if player or foe runs out of pokemon
		var player_defeated = check_player_out_of_poke()
		var foe_defeated = check_foe_out_of_poke()
		if player_defeated || foe_defeated:
			action = BattleQueueAction.new()
			action.type = action.BATTLE_END

			if player_defeated == false && foe_defeated == true:
				action.winner = action.PLAYER_WIN
			if player_defeated == true && foe_defeated == false:
				action.winner = action.FOE_WIN
			queue.push(action)
			return true
	return false
func get_battler_title_by_index(battler_index: int) -> String:
	if battle_instance.battle_type == BattleInstanceData.BattleType.SINGLE_WILD:
		if battler_index == 2 || battler_index == 4:
				return "WILD " + get_battler_by_index(battler_index).name
	else:
		if battler_index == 2 || battler_index == 4:
			return "FOE " + get_battler_by_index(battler_index).name
	return get_battler_by_index(battler_index).name
func remove_hp(index: int, damage: int): # Still need to call post_damage_checks mannually after this!
	var target = get_battler_by_index(index)
	var current_hp = target.current_hp
	if current_hp - damage < 0:
		target.current_hp = 0
	else:
		target.current_hp = current_hp - damage
func get_effect_from_effects(effect_enum: int, battler_index : int): # Returns the specified BattleEffect, else null
	for effect in get_effects_by_index(battler_index):
		if effect.effect == effect_enum:
			return effect
	return null
func set_major_ailment(index: int, ailment_code: int, turns: int = -1): # Sets the MajorAilment and coresponding actions
	var action = BattleQueueAction.new()
	action.type = action.BATTLE_TEXT

	if get_battler_by_index(index).major_ailment != null:
		match ailment_code:
			MajorAilment.BURN:
				action.battle_text = get_battler_title_by_index(index) + " is\nburnt!"
			MajorAilment.FROZEN:
				action.battle_text = get_battler_title_by_index(index) + " is\nfrozen solid!"
			MajorAilment.POISON:
				action.battle_text = get_battler_title_by_index(index) + " is\npoisoned!"
			MajorAilment.SLEEP:
				action.battle_text = get_battler_title_by_index(index) + " is\nfast asleep."
			MajorAilment.PARALYSIS:
				action.battle_text = get_battler_title_by_index(index) + " is\nparalyzed!"
		queue.push(action)

		get_battler_by_index(index).major_ailment = ailment_code
		if get_battler_by_index(index).major_ailment == MajorAilment.SLEEP:
			var effect = BattleEffect.new()
			effect.effect = BattleEffect.SLEEP_COUNTER
			if turns == -1:
				var rng = RandomNumberGenerator.new()
				rng.randomize()
				effect.sleep_count = rng.randi_range(1,3)
			else:
				effect.sleep_count = turns
			get_effects_by_index(index).add(effect)
		action = BattleQueueAction.new()
		action.type = action.UPDATE_MAJOR_AILMENT
		action.damage_target_index = index
		queue.push(action)
	else:
		action.battle_text = "But it failed."
		queue.push(action)
func get_ball_catch_rate(ball_id: int) -> float:
	var rate : float = 1.0
	match ball_id:
		211: # Poke Ball
			rate = 1.0
		210: # Great Ball
			rate = 1.5
		209: # Ultra Ball:
			rate = 2.0
		208: # Master Ball:
			rate = 255.0
		_:
			print("Battle Error: ball_id did not match any listed. Using default value.")
	return rate
