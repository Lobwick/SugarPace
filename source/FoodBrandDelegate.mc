import Toybox.WatchUi;
import Toybox.Lang;

//! Delegate for FoodBrandView (level 2: brands within a subcategory).
class FoodBrandDelegate extends WatchUi.InputDelegate {

    private var appState as AppState;
    private var allItems as Lang.Array;
    private var subcategory as Lang.String;
    private var view as FoodBrandView;

    function initialize(appState as AppState, allItems as Lang.Array, subcategory as Lang.String, view as FoodBrandView) {
        InputDelegate.initialize();
        self.appState = appState;
        self.allItems = allItems;
        self.subcategory = subcategory;
        self.view = view;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords = clickEvent.getCoordinates();
        var brand = view.brandAtY(coords[1]);
        if (brand == null) {
            return false;
        }

        var items = FoodDatabase.getItemsForSubcategoryAndBrand(allItems, subcategory, brand);
        var itemView = new FoodItemSelectionView(appState, items);
        var itemDelegate = new FoodItemSelectionDelegate(appState, itemView);
        WatchUi.pushView(itemView, itemDelegate, WatchUi.SLIDE_LEFT);
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
