import Toybox.Lang;
using Toybox.Test;

//! Unit tests for FoodDatabase: the embedded foods.json parses into FoodItems.

(:test)
function testLoadAllReturnsFoodItems(logger as Test.Logger) as Boolean {
    var items = FoodDatabase.loadAll();
    Test.assertMessage(items instanceof Lang.Array, "returns an array");
    Test.assertMessage(items.size() > 0, "embedded food list is not empty");

    for (var i = 0; i < items.size(); i++) {
        Test.assertMessage(items[i] instanceof FoodItem, "every entry is a FoodItem");
        Test.assertMessage(items[i].index == i, "index matches position");
    }
    return true;
}
