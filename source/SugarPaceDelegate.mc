import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class SugarPaceDelegate extends WatchUi.BehaviorDelegate {

    private var appState as AppState;
    private var nightscoutService as NightscoutService;
    private var otpService as OtpService;

    function initialize(appState as AppState, nightscoutService as NightscoutService, otpService as OtpService) {
        WatchUi.BehaviorDelegate.initialize();
        self.appState = appState;
        self.nightscoutService = nightscoutService;
        self.otpService = otpService;
    }

    //! Vertical swipe scrolls the page so foods below the fold are reachable.
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            appState.scrollBy(Layout.SCROLL_STEP);
            return true;
        } else if (dir == WatchUi.SWIPE_DOWN) {
            appState.scrollBy(-Layout.SCROLL_STEP);
            return true;
        }
        return false;
    }

    //! Physical up/down keys also scroll (touch is the primary path).
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN) {
            appState.scrollBy(Layout.SCROLL_STEP);
            return true;
        } else if (key == WatchUi.KEY_UP) {
            appState.scrollBy(-Layout.SCROLL_STEP);
            return true;
        }
        return false;
    }

    //! Handle a direct tap on a food tile in the grid
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coordinates = clickEvent.getCoordinates();
        var x = coordinates[0];
        var y = coordinates[1];

        var foundFood = appState.findFoodItemAtPoint(x, y);
        if (foundFood != null) {
            System.println("Tap detected food: " + foundFood.name);
            sendFood(foundFood);
            return true;
        }

        // Chart area tap: cycle the visible timeline window (4h -> 2h -> 1h -> 30m)
        if (appState.isPointInRegion(appState.chartRegion, x, y)) {
            appState.cycleChartWindow();
            System.println("Tap detected on chart, window now: " + appState.chartWindowMinutes + " min");
            return true;
        }

        // Header area tap (glucose value + profile + trend info): open the
        // profile / temp-override selection so it can be changed directly.
        if (appState.isPointInRegion(appState.headerRegion, x, y)) {
            System.println("Tap detected on header, opening profile selection");
            openProfileSelection();
            return true;
        }

        System.println("No tap target found at point: " + x + ", " + y);
        return false;
    }

    //! Physical menu button → open food selection (3-level: category > brand > item)
    function onMenu() as Lang.Boolean {
        var allItems = FoodDatabase.loadAllUnfiltered();
        var selView = new FoodSelectionView(appState, allItems);
        WatchUi.pushView(selView, new FoodSelectionDelegate(appState, allItems, selView), WatchUi.SLIDE_UP);
        return true;
    }

    //! Open the profile / temp-override selection view
    private function openProfileSelection() as Void {
        // Refresh profiles/active override before showing
        nightscoutService.fetchTempBasalData();

        var tempOverridesView = new TempOverridesView(appState);
        WatchUi.pushView(tempOverridesView, new TempOverridesInputDelegate(tempOverridesView), WatchUi.SLIDE_UP);
    }

    //! Send the tapped food to Loop
    private function sendFood(food as FoodItem) as Void {
        System.println("Sending food: " + food.name + " with " + food.carbs + " carbs");

        // Create food entry data using OTP service
        var foodEntryData = otpService.createFoodEntryData(food.toDictionary());

        System.println("Food entry data created - notes: " + foodEntryData.get("notes"));

        // Send via Nightscout service
        nightscoutService.sendFoodEntry(foodEntryData);
    }
}