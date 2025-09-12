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

    function onSelect() as Boolean {
        System.println("Select pressed - detecting food at current position");
        
        if (appState.foodItems.size() == 0) {
            System.println("No foods available");
            return false;
        }
        
        // For Edge devices, try to detect food at center position
        var centerY = getCenterYPosition();
        System.println("Simulated tap at center Y: " + centerY);
        
        var foundFood = appState.findFoodItemAtY(centerY);
        
        if (foundFood != null && foundFood instanceof FoodItem) {
            System.println("Select detected food: " + foundFood.name + " at index: " + foundFood.index);
            appState.setSelectedFoodIndex(foundFood.index);
            sendSelectedFood();
            return true;
        } else {
            // Fallback: send current selected food
            System.println("Using current selected index as fallback");
            sendSelectedFood();
            return true;
        }
    }

    //! Send the currently selected food to Loop
    private function sendSelectedFood() as Void {
        var selectedFood = appState.getSelectedFoodItem();
        
        System.println("=== SEND SELECTED FOOD DEBUG ===");
        System.println("Selected food: " + (selectedFood != null ? "Found" : "NULL"));
        
        if (selectedFood == null) {
            System.println("No food selected");
            return;
        }
        
        System.println("Food name: " + selectedFood.name);
        System.println("Food carbs: " + selectedFood.carbs);
        System.println("Sending food: " + selectedFood.name + " with " + selectedFood.carbs + " carbs");
        
        // Create food entry data using OTP service
        var foodEntryData = otpService.createFoodEntryData(selectedFood.toDictionary());
        
        System.println("Food entry data created - notes: " + foodEntryData.get("notes"));
        
        // Send via Nightscout service
        nightscoutService.sendFoodEntry(foodEntryData);
    }

    //! Get estimated center Y position for Edge devices
    private function getCenterYPosition() as Lang.Number {
        // For Edge 1050, approximate screen center Y
        return 300; // Adjust this value based on your screen
    }
}