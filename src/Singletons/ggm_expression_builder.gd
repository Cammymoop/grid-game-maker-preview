extends Node


var expression_cache: Dictionary[StringName, Dictionary] = {}

const GGM_EXPR_TYPES: Array[String] = [
    "basic_expr",
]

const OPERATORS: Array[String] = [
    ">", "<", "==", "!=", ">=", "<=",
    "+", "-", "*", "**", "/", "%",
    "&&", "||",
    "in", "and", "or",
]

const UNARY_OPERATORS: Array[String] = [
    "not", 
]

const CONSTANTS: Array[String] = [
    "PI", "TAU", "INF", "NAN", "null",
]

const UNARY_FUNCTIONS: Array[String] = [
    "abs", "acos", "asin", "atan", "ceil", "cos", "deg_to_rad", "exp", "floor", "is_finite", "is_nan", "is_zero_approx", "log",
    "nearest_po2", "round", "sign", "sin", "sqrt", "tan",

    "str", "int", "float"
]

const TWO_ARG_FUNCTIONS: Array[String] = [
    "angle_difference", "atan2", "ease", "fmod", "fposmod", "is_equal_approx", "max", "maxf", "maxi", "min", "minf", "mini",
    "pingpong", "posmod", "pow", "snapped", "snappedf", "snappedi", "type_convert",
]

const THREE_ARG_FUNCTIONS: Array[String] = [
    "clamp", "clampf", "clampi", "inverse_lerp", "lerp", "lerp_angle", "max", "min", "move_toward", "rotate_toward",
    "smoothstep", "wrap", "wrapf", "wrapi",
]


func get_godot_expression_string(unsafe_expr_string: StringName, variable_names: Array = []) -> String:
    if unsafe_expr_string in expression_cache:
        return _make_godot_expression(expression_cache[unsafe_expr_string])
    
    var parsed_expr_data: Variant = _expression_data_from_string(unsafe_expr_string)
    if not parsed_expr_data or typeof(parsed_expr_data) != TYPE_DICTIONARY:
        return ""
    
    var vnames: Array[String] = []
    vnames.assign(variable_names)
    
    var built_expression: Dictionary = _build_expression(parsed_expr_data, vnames)
    if not built_expression:
        return ""
    expression_cache[unsafe_expr_string] = built_expression
    return _make_godot_expression(built_expression)


func make_expression_data_str(unsafe_expr_data: Dictionary) -> String:
    return JSON.stringify(unsafe_expr_data)

func _expression_data_from_string(unsafe_expr_string: StringName) -> Dictionary:
    return JSON.parse_string(unsafe_expr_string)

func _make_godot_expression(expression_data: Dictionary) -> String:
    if not expression_data.has("ggm-safe-expr"):
        return ""
    return _dict_get_string(expression_data, "godot-expr-string")

func _validate_expr_data(unsafe_expr_data: Dictionary) -> bool:
    if not unsafe_expr_data.has("ggm-expr") or typeof(unsafe_expr_data["ggm-expr"]) != TYPE_STRING:
        return false
    if not unsafe_expr_data.has("ggm-expr-version") or typeof(unsafe_expr_data["ggm-expr-version"]) != TYPE_FLOAT:
        return false
    if unsafe_expr_data["ggm-expr"] not in GGM_EXPR_TYPES:
        return false
    return true

func _build_expression(unsafe_expr_data: Dictionary, variable_names: Array[String] = []) -> Dictionary:
    if not _validate_expr_data(unsafe_expr_data):
        return {}
    var expr_type: String = unsafe_expr_data["ggm-expr"]
    if expr_type == "basic_expr":
        return _build_basic_expression(unsafe_expr_data, variable_names)
    else:
        push_error("Expression type %s not implemented" % expr_type)
    
    return {}

func _build_basic_expression(expr: Dictionary, variable_names: Array[String] = []) -> Dictionary:
    var expression_tree: Dictionary = _dict_get_dict(expr, "expression_tree")
    var ggm_expression: Dictionary = {
        "ggm-safe-expr": 1,
        "godot-expr-string": "",
    }
    var built_expression: String = _basic_expression_build_recursive(expression_tree, variable_names)
    if not built_expression:
        return {}
    if built_expression.begins_with("(") and built_expression.ends_with(")"):
        built_expression = built_expression.substr(1, built_expression.length() - 2)
    ggm_expression["godot-expr-string"] = built_expression
    return ggm_expression

func _basic_expression_build_recursive(sub_expression: Dictionary, vars: Array[String] = []) -> String:
    var node_type: = _dict_get_string(sub_expression, "node")
    if node_type == "decimal":
        return str(_dict_get_float(sub_expression, "value"))
    elif node_type == "integer":
        return str(_dict_get_int(sub_expression, "value"))
    elif node_type == "bool":
        return str(_dict_get_bool(sub_expression, "value"))
    elif node_type == "constant":
        var constant_name: = _dict_get_string(sub_expression, "name")
        if constant_name in CONSTANTS:
            return constant_name
        return ""
    elif node_type == "operation":
        var operator: = _dict_get_string(sub_expression, "op")
        if operator in OPERATORS:
            var left_operand: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "left"), vars)
            var right_operand: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "right"), vars)
            if left_operand and right_operand:
                return "(" + left_operand + " " + operator + " " + right_operand + ")"
        return ""
    elif node_type == "unary_op":
        var operator: = _dict_get_string(sub_expression, "op")
        if operator in UNARY_OPERATORS:
            var operand: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "operand"), vars)
            if operand:
                return "(" + operator + " " + operand + ")"
        return ""
    elif node_type == "variable":
        var variable_name: = _dict_get_string(sub_expression, "name")
        if variable_name in vars:
            return variable_name
        return ""
    elif node_type == "unary_func":
        var function_name: = _dict_get_string(sub_expression, "name")
        if function_name in UNARY_FUNCTIONS:
            var arg: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg"), vars)
            if arg:
                return function_name + "(" + arg + ")"
        return ""
    elif node_type == "two_func":
        var function_name: = _dict_get_string(sub_expression, "name")
        if function_name in TWO_ARG_FUNCTIONS:
            var arg1: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg1"), vars)
            var arg2: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg2"), vars)
            if arg1 and arg2:
                return function_name + "(" + arg1 + ", " + arg2 + ")"
        return ""
    elif node_type == "three_func":
        var function_name: = _dict_get_string(sub_expression, "name")
        if function_name in THREE_ARG_FUNCTIONS:
            var arg1: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg1"), vars)
            var arg2: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg2"), vars)
            var arg3: String = _basic_expression_build_recursive(_dict_get_dict(sub_expression, "arg3"), vars)
            if arg1 and arg2 and arg3:
                return function_name + "(" + arg1 + ", " + arg2 + ", " + arg3 + ")"
        return ""
    return ""
            


func _dict_get_dict(dict: Dictionary, key: String) -> Dictionary:
    if not dict.has(key) or typeof(dict[key]) != TYPE_DICTIONARY:
        return {}
    return dict[key]

func _dict_get_array(dict: Dictionary, key: String) -> Array:
    if not dict.has(key) or typeof(dict[key]) != TYPE_ARRAY:
        return []
    return dict[key]

func _dict_get_string(dict: Dictionary, key: String) -> String:
    if not dict.has(key) or typeof(dict[key]) != TYPE_STRING:
        return ""
    return dict[key]

func _dict_get_float(dict: Dictionary, key: String) -> float:
    if not dict.has(key) or typeof(dict[key]) != TYPE_FLOAT:
        return 0.0
    return dict[key]

func _dict_get_int(dict: Dictionary, key: String) -> int:
    var float_val: float = _dict_get_float(dict, key)
    return int(float_val)

func _dict_get_bool(dict: Dictionary, key: String) -> bool:
    if not dict.has(key) or typeof(dict[key]) != TYPE_BOOL:
        return false
    return dict[key]