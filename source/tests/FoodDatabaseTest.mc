import Toybox.Lang;
using Toybox.Test;

//! Unit tests for FoodDatabase: the embedded foods.json parses into FoodItems.

(:test)
function testLoadAllReturnsFoodItems(logger as Test.Logger) as Boolean {
    // null = no selection configured → full catalogue
    var items = FoodDatabase.loadAll(null);
    Test.assertMessage(items instanceof Lang.Array, "returns an array");
    Test.assertMessage(items.size() > 0, "embedded food list is not empty");

    for (var i = 0; i < items.size(); i++) {
        Test.assertMessage(items[i] instanceof FoodItem, "every entry is a FoodItem");
        Test.assertMessage(items[i].index == i, "index matches position");
    }
    return true;
}

(:test)
function testLoadAllWithSelectionFilters(logger as Test.Logger) as Boolean {
    var all = FoodDatabase.loadAllUnfiltered();
    Test.assertMessage(all.size() > 0, "catalogue not empty");

    // Select only the first item
    var firstItem = all[0] as FoodItem;
    var selectedIds = { firstItem.id => true } as Lang.Dictionary;
    var filtered = FoodDatabase.loadAll(selectedIds);
    Test.assertMessage(filtered.size() == 1, "filters to selected items only");
    Test.assertMessage((filtered[0] as FoodItem).id.equals(firstItem.id), "correct item returned");
    return true;
}

(:test)
function testLoadAllWithEmptySelectionReturnsEmpty(logger as Test.Logger) as Boolean {
    var empty = {} as Lang.Dictionary;
    var items = FoodDatabase.loadAll(empty);
    Test.assertMessage(items.size() == 0, "empty selection returns empty list");
    return true;
}

(:test)
function testGetSubcategoriesOtherIsLast(logger as Test.Logger) as Boolean {
    var all = FoodDatabase.loadAllUnfiltered();
    var subs = FoodDatabase.getSubcategories(all);
    Test.assertMessage(subs instanceof Lang.Array, "returns array");
    if (subs.size() > 0) {
        var last = subs[subs.size() - 1];
        // OTHER must be last if present — if it's not in the catalogue, skip
        for (var i = 0; i < subs.size() - 1; i++) {
            Test.assertMessage(!subs[i].toString().equals("OTHER"), "OTHER is not before last element");
        }
    }
    return true;
}

(:test)
function testGetBrandsForSubcategory(logger as Test.Logger) as Boolean {
    var all = FoodDatabase.loadAllUnfiltered();
    var subs = FoodDatabase.getSubcategories(all);
    if (subs.size() > 0) {
        var sub = subs[0].toString();
        var brands = FoodDatabase.getBrandsForSubcategory(all, sub);
        Test.assertMessage(brands instanceof Lang.Array, "returns array");
        Test.assertMessage(brands.size() > 0, "at least one brand for existing subcategory");
    }
    return true;
}
