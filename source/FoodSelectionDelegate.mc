import Toybox.WatchUi;
import Toybox.Lang;

//! Delegate for FoodSelectionView (level 1: subcategories).
class FoodSelectionDelegate extends WatchUi.InputDelegate {

    private var appState as AppState;
    private var allItems as Lang.Array;
    private var view as FoodSelectionView;

    function initialize(appState as AppState, allItems as Lang.Array, view as FoodSelectionView) {
        InputDelegate.initialize();
        self.appState = appState;
        self.allItems = allItems;
        self.view = view;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords = clickEvent.getCoordinates();
        var sub = view.subcategoryAtY(coords[1]);
        if (sub == null) {
            return false;
        }

        var brands = FoodDatabase.getBrandsForSubcategory(allItems, sub);
        if (brands.size() == 1) {
            // Only one brand in this category: skip brand level
            var items = FoodDatabase.getItemsForSubcategoryAndBrand(allItems, sub, brands[0].toString());
            var itemView = new FoodItemSelectionView(appState, items);
            var itemDelegate = new FoodItemSelectionDelegate(appState, itemView);
            WatchUi.pushView(itemView, itemDelegate, WatchUi.SLIDE_LEFT);
        } else {
            var brandView = new FoodBrandView(appState, allItems, sub);
            var brandDelegate = new FoodBrandDelegate(appState, allItems, sub, brandView);
            WatchUi.pushView(brandView, brandDelegate, WatchUi.SLIDE_LEFT);
        }
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
