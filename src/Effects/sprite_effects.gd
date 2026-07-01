class_name SpriteEffects
extends Node

# ideas
const StaticEffects: Array[String] = [
    "Smaller",
    "Bigger",

    "Shattered",
    
    "Colored",
    
    "Angled",
]

# ideas
const AnimatedEffects: Array[String] = [
    "Grow In",
    "Grow Out",
    "Shrink In",
    "Shrink Out",
    
    "Fall In",
    "Fall Out",
    
    "Slide In",
    "Slide Out",

    "Spin In",
    "Spin Out",
    
    "Fade In",
    "Fade Out",
    
    "Color In",
    "Color Out",
    
    "Scan In",
    "Scan Out",
    "Scanning",
    
    "Dissolve In",
    "Dissolve Out",

    "Pixel Explode",
    "Shatter Explode",

    "Spinning",
    "Shaking",
    
    "Size Bounce",
    "Angle Bounce",
    "Fade Bounce",
    "Hop Bounce",
    "Color Bounce",
]

# ideas
const ParticleEffects: Array[String] = [
    "Sparkle",
    "Burning Smoke",
    "Fog",
    "Smoke Bomb",
    "Electric",
    "Bubbles",
]

const LOW_LEVEL_ANIM_EFFECTS: Array[String] = [
    "scale", "offset", "replace_color", "fade", "spin",
]

const BUMP_EFFECTS: Dictionary[String, Dictionary] = {
    "Hop": {
        "name": "bump-hop",
        "animated_effects": {
            "offset": { 
                "two_stage": true,
                "mid_point": 0.5,
                "offset_to": [0, -22],
                "ease_param": 0.5,
                "ease_param_2": 2.0,
            }
        }
    },
    "Expand": {
        "name": "bump-expand",
        "animated_effects": {
            "scale": {
                "two_stage": true,
                "mid_point": 0.25,
                "scale_to": [1.2,1.2],
            }
        }
    },
    "Shrink": {
        "name": "bump-shrink",
        "animated_effects": {
            "scale": { 
                "two_stage": true,
                "mid_point": 0.25,
                "scale_to": [0.8,0.8],
            }
        }
    },
    "Flash": {
        "name": "bump-flash",
        "animated_effects": {
            "replace_color": {
                "two_stage": true,
                "mid_point": 0.25,
                "color_from": "#ffffff",
                "color_to": "#ffffff",
                "amount_to": 1.0,
            }
        }
    },
    "Spin Clockwise": {
        "name": "bump-spin-cw",
        "animated_effects": {
            "spin": {
                "total_rotation": 1.0,
                "ease_param": 0.33,
            }
        }
    },
    "Spin Counterclockwise": {
        "name": "bump-spin-ccw",
        "animated_effects": {
            "spin": {
                "total_rotation": -1.0,
                "ease_param": 0.33,
            }
        }
    },
    "Sparkle": {
        "name": "bump-sparkle",
        "layers": [{
            "mode": "particles",
            "particles_type": "sparkles",
            "receives_effects": false,
        }],
        "expire_wait_particles": true,
    },
}

static func set_bump_effect_params(effect_name: String, effect_params: Dictionary, effect_info: Dictionary) -> void:
    #prints("setting bump effect params: %s, %s, %s" % [effect_name, effect_params, effect_info])
    if not effect_name in BUMP_EFFECTS:
        return
    if effect_params.has("color"):
        if effect_name == "Flash":
            var replace_color_effect: Dictionary = effect_info.get("animated_effects", {}).get("replace_color", {})
            if replace_color_effect:
                replace_color_effect["color_from"] = effect_params["color"]
                replace_color_effect["color_to"] = effect_params["color"]
        if effect_name == "Sparkle":
            for layer in effect_info.get("layers", []):
                if layer.get("mode") == "particles" and layer.get("particles_type") == "sparkles":
                    layer["mod_color"] = effect_params["color"]
    if effect_params.has("amount"):
        if effect_name == "Expand":
            var scale_effect: Dictionary = effect_info.get("animated_effects", {}).get("scale", {})
            var scale_to_amt: float = 1 + effect_params["amount"]
            if scale_effect:
                scale_effect["scale_to"] = [scale_to_amt, scale_to_amt]
        elif effect_name == "Shrink":
            var scale_effect: Dictionary = effect_info.get("animated_effects", {}).get("scale", {})
            var scale_to_amt: float = maxf(0, 1 - effect_params["amount"])
            if scale_effect:
                scale_effect["scale_to"] = [scale_to_amt, scale_to_amt]
        elif effect_name == "Flash":
            var replace_color_effect: Dictionary = effect_info.get("animated_effects", {}).get("replace_color", {})
            if replace_color_effect:
                replace_color_effect["amount_to"] = effect_params["amount"]
        elif effect_name == "Hop":
            var offset_effect: Dictionary = effect_info.get("animated_effects", {}).get("offset", {})
            if offset_effect and offset_effect.has("offset_to"):
                offset_effect["offset_to"][1] = -effect_params["amount"]
    
    if effect_params.has("direction"):
        var dir_int: int = int(effect_params["direction"])
        var dir_vec: Vector2 = Utility.facing_vector(dir_int)
        if effect_name == "Hop":
            var offset_effect: Dictionary = effect_info.get("animated_effects", {}).get("offset", {})
            if offset_effect and offset_effect.has("offset_to"):
                var hop_amount: float = Utility.get_vector2_from_arr(offset_effect["offset_to"]).length()
                offset_effect["offset_to"] = Utility.get_arr_from_vector2(dir_vec * hop_amount)

const DYING_EFFECTS: Dictionary[String, Dictionary] = {
    "Spin Out": {
        "name": "dying-spin-out",
        "animated_effects": {
            "spin": { "total_rotation": -0.75, "ease_param": 0.5 },
            "scale": { "scale_from": [1,1], "scale_to": [0,0], "ease_param": 2.6 },
        },
    },
    "Shrink Out": {
        "name": "dying-shrink-out",
        "animated_effects": {
            "scale": { "scale_from": [1,1], "scale_to": [0,0], "ease_param": 0.25 },
        },
    },
    "Burn Fade": {
        "name": "dying-burn-fade",
        "animated_effects": {
            "replace_color": { "color_from": "#000000", "color_to": "#000000", "amount_to": 1.0, "duration_factor": 0.33 },
            "fade": { "fade_to": 1.0, "time_offset": 0.33, "duration_factor": 0.66, "ease_param": 2.8 },
        },
    },
    "Hit Fade": {
        "name": "dying-hit-fade",
        "animated_effects": {
            "replace_color": { "color_from": "#ffffff", "color_to": "#881144", "amount_to": 0.5, "duration_factor": 0.5, "ease_param": 2.2 },
            "fade": { "fade_to": 1.0, "time_offset": 0.6, "duration_factor": 0.4, "ease_param": 1.8 },
            "offset": { "offset_to": [0, -16], "duration_factor": 0.3, "ease_param": 0.25 },
        },
    },
    "Fly Up": {
        "name": "dying-fly-up",
        "animated_effects": {
            "offset": { "offset_to": [0, -100], "ease_param": 0.75 },
            "scale": { "scale_from": [1,1], "scale_to": [0,0], "ease_param": 0.5,
                        "duration_factor": 0.5, "time_offset": 0.5 },
        },
    },
    
    "Real Explosion": {
        "name": "dying-real-explosion",
        "duration": 1.5,
        # hide base layers
        "effects": {"modulate": {"color": "#ffffff00" } },
        "layers": [{
            "mode": "particles",
            "particles_type": "explode",
            "z_offset": 2,
            "receives_effects": false,
        }],
    },
}