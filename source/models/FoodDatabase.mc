import Toybox.Lang;
import Toybox.WatchUi;

//! Loads the static food list compiled into the app from resources/foods/foods.json.
//! To add or update foods, edit that file and open a PR.
class FoodDatabase {

    //! Returns the full list of FoodItem objects from the embedded JSON resource.
    static function loadAll() as Lang.Array {
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
}
