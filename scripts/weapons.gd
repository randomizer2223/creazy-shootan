class_name Weapons
## All weapons. To add one, add an entry to LIST (and an icon in sprites.gd).
##  tier    — "basic" (always in inventory, infinite) or "top" (limited shots, random/pickups)
##  cd      — cooldown in seconds (multiplied by the reload mode)
##  ammo    — shots you get (-1 = infinite)
##  speed   — projectile speed, grav — gravity multiplier
##  count   — projectiles per shot, spread — random spread (radians)
##  fuse    — timer (0 = explodes on impact), bounce — bounciness
##  radius  — explosion size (destruction), dmg — damage, knock — knockback
##  cluster — splits into N pieces of cluster_id
##  dirt    — radius of new ground the shot creates (territory weapon)
##  homing  — steers toward the nearest enemy
##  hitscan — instant beam (laser)
##  burn    — sticky fire that hurts and melts ground

const DEFAULT := "bazooka"

const LIST := {
	# ---------- basic weapons (infinite) ----------
	"pistol": {
		"name": "Pistol", "tier": "basic", "cd": 0.32, "ammo": -1, "speed": 620.0, "grav": 0.1,
		"count": 1, "spread": 0.02, "fuse": 0.0, "bounce": 0.0,
		"radius": 5.0, "dmg": 9.0, "knock": 60.0, "color": Color(1.0, 0.95, 0.7), "size": 1.2,
	},
	"bazooka": {
		"name": "Bazooka", "tier": "basic", "trail": true, "cd": 0.9, "ammo": -1, "speed": 430.0, "grav": 0.3,
		"count": 1, "spread": 0.0, "fuse": 0.0, "bounce": 0.0,
		"radius": 16.0, "dmg": 24.0, "knock": 170.0, "color": Color(1.0, 0.85, 0.3), "size": 1.6,
	},
	"shotgun": {
		"name": "Shotgun", "tier": "basic", "cd": 0.9, "ammo": -1, "speed": 650.0, "grav": 0.15,
		"count": 14, "spread": 0.18, "fuse": 0.0, "bounce": 0.0,
		"radius": 4.0, "dmg": 6.0, "knock": 45.0, "color": Color(0.9, 0.9, 0.9), "size": 1.0,
	},
	"uzi": {
		"name": "Uzi", "tier": "basic", "cd": 0.1, "ammo": -1, "speed": 640.0, "grav": 0.1,
		"count": 1, "spread": 0.09, "fuse": 0.0, "bounce": 0.0,
		"radius": 3.0, "dmg": 3.0, "knock": 20.0, "color": Color(1.0, 0.7, 0.4), "size": 1.0,
	},
	"grenade": {
		"name": "Grenade", "tier": "basic", "spin": true, "cd": 1.3, "ammo": -1, "speed": 330.0, "grav": 1.0,
		"count": 1, "spread": 0.0, "fuse": 2.0, "bounce": 0.5,
		"radius": 24.0, "dmg": 38.0, "knock": 230.0, "color": Color(0.35, 0.8, 0.3), "size": 2.0,
	},
	"dirt": {
		"name": "Dirt Cannon", "tier": "basic", "cd": 0.5, "ammo": -1, "speed": 360.0, "grav": 0.8,
		"count": 1, "spread": 0.0, "fuse": 0.0, "bounce": 0.0,
		"radius": 0.0, "dmg": 0.0, "knock": 0.0, "dirt": 20.0, "color": Color(0.55, 0.35, 0.15), "size": 2.5,
	},
	# ---------- top weapons (limited shots) ----------
	"banana": {
		"name": "Banana Bomb", "tier": "top", "spin": true, "cd": 2.0, "ammo": 20, "speed": 300.0, "grav": 1.0,
		"count": 1, "spread": 0.0, "fuse": 1.8, "bounce": 0.55,
		"radius": 20.0, "dmg": 25.0, "knock": 200.0, "cluster": 16, "cluster_id": "banana_small",
		"color": Color(1.0, 0.95, 0.2), "size": 2.5,
	},
	"minigun": {
		"name": "Minigun", "tier": "top", "cd": 0.06, "ammo": 300, "speed": 720.0, "grav": 0.08,
		"count": 4, "spread": 0.07, "fuse": 0.0, "bounce": 0.0,
		"radius": 4.5, "dmg": 5.0, "knock": 35.0, "color": Color(1.0, 0.6, 0.3), "size": 1.0,
	},
	"mega_bomb": {
		"name": "Mega Bomb", "tier": "top", "spin": true, "cd": 1.6, "ammo": 20, "speed": 300.0, "grav": 1.0,
		"count": 1, "spread": 0.0, "fuse": 2.4, "bounce": 0.35,
		"radius": 46.0, "dmg": 75.0, "knock": 380.0, "color": Color(0.4, 0.4, 0.55), "size": 3.0,
	},
	"homing": {
		"name": "Homing Missile", "tier": "top", "trail": true, "homing": true, "cd": 0.8, "ammo": 25,
		"speed": 300.0, "grav": 0.0, "count": 1, "spread": 0.0, "fuse": 0.0, "bounce": 0.0,
		"radius": 20.0, "dmg": 34.0, "knock": 220.0, "color": Color(1.0, 0.4, 0.4), "size": 2.0,
	},
	"laser": {
		"name": "Laser", "tier": "top", "hitscan": true, "cd": 0.45, "ammo": 30, "speed": 5000.0, "grav": 0.0,
		"count": 1, "spread": 0.0, "fuse": 0.0, "bounce": 0.0,
		"radius": 4.0, "dmg": 34.0, "knock": 120.0, "color": Color(0.45, 0.95, 1.0), "size": 1.0,
	},
	"napalm": {
		"name": "Napalm", "tier": "top", "spin": true, "cd": 1.1, "ammo": 20, "speed": 340.0, "grav": 1.0,
		"count": 1, "spread": 0.0, "fuse": 0.0, "bounce": 0.0,
		"radius": 8.0, "dmg": 8.0, "knock": 60.0, "cluster": 28, "cluster_id": "fire",
		"color": Color(1.0, 0.4, 0.3), "size": 2.0,
	},
	# ---------- pieces (not in inventory) ----------
	"banana_small": {
		"name": "Banana", "tier": "piece", "spin": true, "cd": 0.0, "ammo": 0, "speed": 250.0, "grav": 1.0,
		"count": 1, "spread": 0.0, "fuse": 0.0, "bounce": 0.0,
		"radius": 25.0, "dmg": 30.0, "knock": 240.0, "color": Color(1.0, 0.9, 0.1), "size": 2.0,
	},
	"fire": {
		"name": "Fire", "tier": "piece", "burn": true, "cd": 0.0, "ammo": 0, "speed": 200.0, "grav": 1.0,
		"count": 1, "spread": 0.0, "fuse": 3.2, "bounce": 0.15,
		"radius": 3.5, "dmg": 5.0, "knock": 10.0, "color": Color(1.0, 0.55, 0.15), "size": 2.0,
	},
}

const BASIC := ["pistol", "bazooka", "shotgun", "uzi", "grenade", "dirt"]
const TOP := ["banana", "minigun", "mega_bomb", "homing", "laser", "napalm"]


static func is_top(id: String) -> bool:
	return LIST[id].get("tier", "") == "top"
