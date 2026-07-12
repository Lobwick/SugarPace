import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class DiabetesFoodLoopDelegate extends WatchUi.BehaviorDelegate {

    private var appState as AppState;
    private var nightscoutService as NightscoutService;
    private var otpService as OtpService;

    function initialize(appState as AppState, nightscoutService as NightscoutService, otpService as OtpService) {
        WatchUi.BehaviorDelegate.initialize();
        self.appState = appState;
        self.nightscoutService = nightscoutService;
        self.otpService = otpService;
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new DiabetesFoodLoopMenuDelegate(appState), WatchUi.SLIDE_UP);
        return true;
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

        System.println("No food tile found at tap point: " + x + ", " + y);
        return false;
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