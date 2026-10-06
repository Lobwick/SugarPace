import Toybox.Lang;
using Toybox.Test;

//! Unit tests for FoodItem parsing from the embedded JSON dictionaries.

//! Carbs given as a String are coerced to a Number; missing fields get defaults.
(:test)
function testFoodItemStringCarbs(logger as Test.Logger) as Boolean {
    var item = new FoodItem({ "name" => "Test Gel", "carbs_g" => "30", "subcategory" => "GEL" }, 2);
    Test.assertEqualMessage(item.name, "Test Gel", "name parsed");
    Test.assertEqualMessage(item.carbs, 30, "string carbs coerced to number");
    Test.assertEqualMessage(item.subcategory, "GEL", "subcategory parsed");
    Test.assertEqualMessage(item.index, 2, "index stored");
    return true;
}

//! Numeric carbs pass through; absent optional fields fall back to defaults.
(:test)
function testFoodItemDefaults(logger as Test.Logger) as Boolean {
    var item = new FoodItem({ "carbs_g" => 45 }, 0);
    Test.assertEqualMessage(item.name, "Unknown", "missing name -> Unknown");
    Test.assertEqualMessage(item.carbs, 45, "numeric carbs kept");
    Test.assertEqualMessage(item.id, "0", "missing id falls back to index");
    Test.assertEqualMessage(item.brand, "", "missing brand defaults to empty");
    Test.assertEqualMessage(item.subcategory, "OTHER", "missing subcategory -> OTHER");
    Test.assertMessage(item.picture == null, "missing picture -> null");
    Test.assertEqualMessage(item.portion_g, 0, "missing portion defaults to zero");
    Test.assertEqualMessage(item.gi, 0, "missing GI defaults to zero");
    Test.assertEqualMessage(item.energy_kj, 0, "missing energy defaults to zero");
    Test.assertEqualMessage(item.fat_g, 0.0, "missing fat defaults to zero");
    Test.assertEqualMessage(item.protein_g, 0.0, "missing protein defaults to zero");
    return true;
}

(:test)
function testFoodItemCoercesNutritionValues(logger as Test.Logger) as Boolean {
    var item = new FoodItem({
        "id" => 42,
        "name" => 7,
        "brand" => "Test",
        "subcategory" => "BAR",
        "picture" => 12,
        "carbs_g" => true,
        "portion_g" => [12],
        "gi" => "55",
        "energy_kj" => 900,
        "fat_g" => 2,
        "protein_g" => "3.5"
    }, 4);
    Test.assertEqualMessage(item.id, "42", "id is normalized to string");
    Test.assertEqualMessage(item.name, "7", "name is normalized to string");
    Test.assertEqualMessage(item.picture, "12", "picture is normalized to string");
    Test.assertEqualMessage(item.carbs, 0, "invalid carbs default to zero");
    Test.assertEqualMessage(item.portion_g, 12, "float portion is converted to integer");
    Test.assertEqualMessage(item.gi, 55, "string GI is converted to integer");
    Test.assertEqualMessage(item.energy_kj, 900, "integer energy is kept");
    Test.assertEqualMessage(item.fat_g, 2.0, "integer fat is converted to float");
    Test.assertEqualMessage(item.protein_g, 3.5, "string protein is converted to float");
    return true;
}

//! toDictionary exposes only the carb-entry fields used by the Loop API.
(:test)
function testFoodItemToDictionary(logger as Test.Logger) as Boolean {
    var item = new FoodItem({ "name" => "Bar", "carbs_g" => 31, "subcategory" => "BAR" }, 4);
    var dict = item.toDictionary();
    Test.assertEqualMessage(dict.get("name"), "Bar", "dict name");
    Test.assertEqualMessage(dict.get("carbs_g"), 31, "dict carbs_g");
    Test.assertEqualMessage(dict.get("subcategory"), "BAR", "dict subcategory");
    return true;
}
