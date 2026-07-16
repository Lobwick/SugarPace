import Toybox.WatchUi;
import Toybox.Lang;

//! Delegate for FoodItemSelectionView (level 3: toggle individual food items).
class FoodItemSelectionDelegate extends WatchUi.InputDelegate {

    private var appState as AppState;
    private var view as FoodItemSelectionView;
    private var items as Lang.Array;

    function initialize(appState as AppState, view as FoodItemSelectionView, items as Lang.Array) {
        InputDelegate.initialize();
        self.appState = appState;
        self.view = view;
        self.items = items;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coords = clickEvent.getCoordinates();
        var id = view.foodIdAtY(coords[1]);
        if (id == null) {
            return false;
        }
        if (id.equals("__all__")) {
            appState.toggleAllForItems(items);
            WatchUi.requestUpdate();
            return true;
        }
        appState.toggleFoodSelection(id);
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
