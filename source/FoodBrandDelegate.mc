import Toybox.WatchUi;
import Toybox.Lang;

//! Delegate for FoodBrandView (level 2).
//! Tap left zone of a row → navigate to items.
//! Tap right zone (x >= toggleX) → toggle all items in that brand/subcategory scope.
class FoodBrandDelegate extends WatchUi.InputDelegate {

    private var appState as AppState;
    private var allItems as Lang.Array;
    private var filter as Lang.String;       // subcategory or brand depending on brandFirst
    private var brandFirst as Lang.Boolean;
    private var view as FoodBrandView;

    function initialize(appState as AppState, allItems as Lang.Array, filter as Lang.String,
                        brandFirst as Lang.Boolean, view as FoodBrandView) {
        InputDelegate.initialize();
        self.appState = appState;
        self.allItems = allItems;
        self.filter = filter;
        self.brandFirst = brandFirst;
        self.view = view;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords = clickEvent.getCoordinates();
        var x = coords[0];
        var y = coords[1];

        var row = view.rowAtY(y);
        if (row == null) { return false; }

        var isToggle = row.get("toggleAll");
        if (isToggle instanceof Lang.Boolean && isToggle) {
            // "Tout" row: toggle entire scope for this filter
            var scopeItems = brandFirst
                ? FoodDatabase.getItemsForBrand(allItems, filter)
                : FoodDatabase.getItemsForSubcategory(allItems, filter);
            appState.toggleAllForItems(scopeItems);
            WatchUi.requestUpdate();
            return true;
        }

        var label = row.get("label");
        if (!(label instanceof Lang.String)) { return false; }

        // brandFirst=false: filter=subcategory, label=brand
        // brandFirst=true:  filter=brand, label=subcategory
        var items = brandFirst
            ? FoodDatabase.getItemsForSubcategoryAndBrand(allItems, label, filter)
            : FoodDatabase.getItemsForSubcategoryAndBrand(allItems, filter, label);

        // Check if tap is in the right toggle zone
        var toggleX = row.get("toggleX");
        if (toggleX instanceof Lang.Number && x >= toggleX) {
            appState.toggleAllForItems(items);
            WatchUi.requestUpdate();
            return true;
        }

        // Left zone: navigate to items
        var itemView = new FoodItemSelectionView(appState, items);
        WatchUi.pushView(itemView, new FoodItemSelectionDelegate(appState, itemView, items), WatchUi.SLIDE_LEFT);
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
