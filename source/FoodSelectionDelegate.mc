import Toybox.WatchUi;
import Toybox.Lang;

//! Delegate for FoodSelectionView (level 1: subcategories or brands).
//! Tap mode row → toggle filter order.
//! Tap "Tout" row → toggle all items.
//! Tap left zone of a category/brand row → navigate deeper.
//! Tap right zone of a category/brand row (x >= toggleX) → toggle all in that scope.
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
        var x = coords[0];
        var y = coords[1];

        var row = view.rowAtY(y);
        if (row == null) { return false; }

        // Mode toggle row
        var isMode = row.get("modeToggle");
        if (isMode instanceof Lang.Boolean && isMode) {
            appState.toggleFilterOrder();
            WatchUi.requestUpdate();
            return true;
        }

        // "Tout" row: toggle everything
        var isToggle = row.get("toggleAll");
        if (isToggle instanceof Lang.Boolean && isToggle) {
            appState.toggleAllForItems(allItems);
            WatchUi.requestUpdate();
            return true;
        }

        var label = row.get("label");
        if (!(label instanceof Lang.String)) { return false; }

        // Right zone: toggle all for this category/brand
        var toggleX = row.get("toggleX");
        if (toggleX instanceof Lang.Number && x >= toggleX) {
            var scopeItems = appState.filterOrderBrandFirst
                ? FoodDatabase.getItemsForBrand(allItems, label)
                : FoodDatabase.getItemsForSubcategory(allItems, label);
            appState.toggleAllForItems(scopeItems);
            WatchUi.requestUpdate();
            return true;
        }

        // Left zone: navigate deeper
        if (appState.filterOrderBrandFirst) {
            var subs = FoodDatabase.getSubcategoriesForBrand(allItems, label);
            if (subs.size() == 1) {
                var items = FoodDatabase.getItemsForSubcategoryAndBrand(allItems, subs[0].toString(), label);
                var itemView = new FoodItemSelectionView(appState, items);
                WatchUi.pushView(itemView, new FoodItemSelectionDelegate(appState, itemView, items), WatchUi.SLIDE_LEFT);
            } else {
                var brandView = new FoodBrandView(appState, allItems, label, true);
                WatchUi.pushView(brandView, new FoodBrandDelegate(appState, allItems, label, true, brandView), WatchUi.SLIDE_LEFT);
            }
        } else {
            var brands = FoodDatabase.getBrandsForSubcategory(allItems, label);
            if (brands.size() == 1) {
                var items = FoodDatabase.getItemsForSubcategoryAndBrand(allItems, label, brands[0].toString());
                var itemView = new FoodItemSelectionView(appState, items);
                WatchUi.pushView(itemView, new FoodItemSelectionDelegate(appState, itemView, items), WatchUi.SLIDE_LEFT);
            } else {
                var brandView = new FoodBrandView(appState, allItems, label, false);
                WatchUi.pushView(brandView, new FoodBrandDelegate(appState, allItems, label, false, brandView), WatchUi.SLIDE_LEFT);
            }
        }
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
