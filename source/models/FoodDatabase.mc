import Toybox.Lang;
import Toybox.WatchUi;

//! Loads the static food list compiled into the app from resources/foods/foods.json.
//! To add or update foods, edit that file and open a PR.
class FoodDatabase {

    //! Returns food items visible to the user, filtered by the given selection.
    //! selectedIds: Dictionary<String, Boolean> of selected food IDs.
    //! If null (first launch, no preference saved), returns the full catalogue.
    static function loadAll(selectedIds as Lang.Dictionary?) as Lang.Array {
        var all = loadAllUnfiltered();
        if (selectedIds == null) {
            return all;
        }
        var items = [] as Lang.Array;
        for (var i = 0; i < all.size(); i++) {
            var item = all[i];
            if (item instanceof FoodItem && selectedIds.hasKey(item.id)) {
                items.add(item);
            }
        }
        return items;
    }

    //! Returns all food items from the catalogue without any filtering.
    //! Used by the food selection screens to display the full catalogue.
    static function loadAllUnfiltered() as Lang.Array {
        var raw = WatchUi.loadResource(Rez.JsonData.foods);
        var items = [] as Lang.Array;
        if (!(raw instanceof Lang.Array)) {
            return items;
        }
        for (var i = 0; i < raw.size(); i++) {
            var entry = raw[i];
            if (entry instanceof Lang.Dictionary) {
                items.add(new FoodItem(entry, i));
            }
        }
        return items;
    }

    //! Returns the sorted list of unique subcategories present in items.
    //! "OTHER" is always last.
    static function getSubcategories(items as Lang.Array) as Lang.Array {
        var seen = {} as Lang.Dictionary;
        var result = [] as Lang.Array;
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (item instanceof FoodItem && !seen.hasKey(item.subcategory)) {
                seen[item.subcategory] = true;
                if (!item.subcategory.equals("OTHER")) {
                    result.add(item.subcategory);
                }
            }
        }
        if (seen.hasKey("OTHER")) {
            result.add("OTHER");
        }
        return result;
    }

    //! Returns unique brands for the given subcategory.
    static function getBrandsForSubcategory(items as Lang.Array, subcategory as Lang.String) as Lang.Array {
        var seen = {} as Lang.Dictionary;
        var result = [] as Lang.Array;
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (item instanceof FoodItem && item.subcategory.equals(subcategory) && !seen.hasKey(item.brand)) {
                seen[item.brand] = true;
                result.add(item.brand);
            }
        }
        return result;
    }

    //! Returns items matching both subcategory and brand.
    static function getItemsForSubcategoryAndBrand(items as Lang.Array, subcategory as Lang.String, brand as Lang.String) as Lang.Array {
        var result = [] as Lang.Array;
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (item instanceof FoodItem && item.subcategory.equals(subcategory) && item.brand.equals(brand)) {
                result.add(item);
            }
        }
        return result;
    }

    //! Returns items matching subcategory (all brands).
    static function getItemsForSubcategory(items as Lang.Array, subcategory as Lang.String) as Lang.Array {
        var result = [] as Lang.Array;
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (item instanceof FoodItem && item.subcategory.equals(subcategory)) {
                result.add(item);
            }
        }
        return result;
    }

    //! Returns all unique brands across all items (order of first appearance).
    static function getAllBrands(items as Lang.Array) as Lang.Array {
        var seen = {} as Lang.Dictionary;
        var result = [] as Lang.Array;
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (!(item instanceof FoodItem)) { continue; }
            if (seen.hasKey(item.brand)) { continue; }
            seen[item.brand] = true;
            result.add(item.brand);
        }
        return result;
    }

    //! Returns unique subcategories that contain at least one item with the given brand.
    static function getSubcategoriesForBrand(items as Lang.Array, brand as Lang.String) as Lang.Array {
        var seen = {} as Lang.Dictionary;
        var result = [] as Lang.Array;
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (!(item instanceof FoodItem)) { continue; }
            if (!item.brand.equals(brand)) { continue; }
            if (seen.hasKey(item.subcategory)) { continue; }
            seen[item.subcategory] = true;
            result.add(item.subcategory);
        }
        return result;
    }

    //! Returns all items for the given brand across all subcategories.
    static function getItemsForBrand(items as Lang.Array, brand as Lang.String) as Lang.Array {
        var result = [] as Lang.Array;
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (item instanceof FoodItem && item.brand.equals(brand)) {
                result.add(item);
            }
        }
        return result;
    }
}
