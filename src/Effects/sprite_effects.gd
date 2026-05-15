class_name SpriteEffects
extends Node

const StaticEffects: Array[String] = [
    "Smaller",
    "Bigger",

    "Shattered",
    
    "Colored",
    
    "Angled",
]

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
}