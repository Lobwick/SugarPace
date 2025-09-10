import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class DiabetesFoodManagementDelegate extends WatchUi.BehaviorDelegate {

    private var appState as AppState;
    private var nightscoutService as NightscoutService;
    private var otpService as OtpService;

    function initialize(appState as AppState, nightscoutService as NightscoutService, otpService as OtpService) {
        BehaviorDelegate.initialize();
        self.appState = appState;
        self.nightscoutService = nightscoutService;
        self.otpService = otpService;
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new DiabetesFoodManagementMenuDelegate(appState), WatchUi.SLIDE_UP);
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        System.println("Key pressed: " + key + " (UP=" + WatchUi.KEY_UP + ", DOWN=" + WatchUi.KEY_DOWN + ", ENTER=" + WatchUi.KEY_ENTER + ")");
        
        if (key == WatchUi.KEY_UP) {
            System.println("UP key detected");
            appState.navigateUp();
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            System.println("DOWN key detected");
            appState.navigateDown();
            return true;
        } else if (key == WatchUi.KEY_ENTER) {
            System.println("Enter key pressed");
            sendSelectedFood();
            return true;
        }
        
        System.println("Unhandled key: " + key);
        return false;
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

    function onNextPage() as Boolean {
        System.println("Next page pressed - navigating down");
        appState.navigateDown();
        return true;
    }

    function onPreviousPage() as Boolean {
        System.println("Previous page pressed - navigating up");
        appState.navigateUp();
        return true;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var direction = swipeEvent.getDirection();
        System.println("Swipe direction: " + direction);
        
        if (direction == WatchUi.SWIPE_UP) {
            appState.navigateUp();
            return true;
        } else if (direction == WatchUi.SWIPE_DOWN) {
            appState.navigateDown();
            return true;
        }
        
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coordinates = clickEvent.getCoordinates();
        var tapY = coordinates[1];
        System.println("Tap at coordinates: [" + coordinates[0] + ", " + tapY + "]");
        
        if (appState.foodItems.size() == 0) {
            System.println("No foods available");
            return false;
        }
        
        var foundFood = appState.findFoodItemAtY(tapY);
        
        if (foundFood != null && foundFood instanceof FoodItem) {
            System.println("Tapped food: " + foundFood.name + " at index: " + foundFood.index);
            appState.setSelectedFoodIndex(foundFood.index);
            sendSelectedFood();
            return true;
        } else {
            System.println("Tap outside food area");
            return false;
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