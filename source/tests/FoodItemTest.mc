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
    Test.assertEqualMessage(item.subcategory, "GEL", "missing subcategory -> GEL");
    Test.assertMessage(item.picture == null, "missing picture -> null");
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
