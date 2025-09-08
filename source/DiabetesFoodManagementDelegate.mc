import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application;
import Toybox.Communications;
import Toybox.Time;
import Toybox.System;

class DiabetesFoodManagementDelegate extends WatchUi.BehaviorDelegate {

    private var selectedFoodIndex as Lang.Number = 0;

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new DiabetesFoodManagementMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    private function findFoodAtPosition(posY as Lang.Number, foodCoords as Lang.Array) as Lang.Number {
        System.println("Looking for food at Y=" + posY + " in " + foodCoords.size() + " food items");
        
        var closestIndex = -1;
        var closestDistance = 999999;
        
        for (var i = 0; i < foodCoords.size(); i++) {
            var coords = foodCoords[i];
            if (coords instanceof Lang.Dictionary) {
                var startYObj = coords.get("startY");
                var endYObj = coords.get("endY");
                var indexObj = coords.get("index");
                
                if (startYObj != null && endYObj != null && indexObj != null && 
                    startYObj instanceof Lang.Number && endYObj instanceof Lang.Number && indexObj instanceof Lang.Number) {
                    
                    var startY = startYObj as Lang.Number;
                    var endY = endYObj as Lang.Number;
                    var index = indexObj as Lang.Number;
                    
                    System.println("Food " + i + ": Y " + startY + " to " + endY + " (index " + index + ")");
                    
                    // Check if position is within this food item
                    if (posY >= startY && posY <= endY) {
                        System.println("Found food at exact position: " + index);
                        return index;
                    }
                    
                    // Calculate distance to find closest food
                    var centerY = (startY + endY) / 2;
                    var distance = posY > centerY ? posY - centerY : centerY - posY;
                    if (distance < closestDistance) {
                        closestDistance = distance;
                        closestIndex = index;
                    }
                }
            }
        }
        
        if (closestIndex >= 0) {
            System.println("Using closest food at index: " + closestIndex + " (distance: " + closestDistance + ")");
        } else {
            System.println("No food found at position Y: " + posY);
        }
        
        return closestIndex;
    }


    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coordinates = clickEvent.getCoordinates();
        var tapY = coordinates[1];
        System.println("Tap at coordinates: [" + coordinates[0] + ", " + tapY + "]");
        
        var app = Application.getApp() as DiabetesFoodManagementApp;
        var foodsList = app.getFoodsList();
        var view = app.getMainView();
        
        if (foodsList.size() == 0 || view == null) {
            System.println("No foods available or view is null");
            return false;
        }
        
        // Get coordinates array from view and find tapped food
        var foodCoords = view.getFoodCoordinates();
        var tappedFoodIndex = findTappedFood(tapY, foodCoords);
        
        if (tappedFoodIndex >= 0 && tappedFoodIndex < foodsList.size()) {
            System.println("Tapped food index: " + tappedFoodIndex);
            // Update both delegate and view with the tapped food
            selectedFoodIndex = tappedFoodIndex;
            view.setSelectedFoodIndex(tappedFoodIndex);
            WatchUi.requestUpdate();
            
            // Send the food data immediately
            sendFoodData();
            return true;
        } else {
            System.println("Tap outside food area or invalid index: " + tappedFoodIndex);
            return false;
        }
    }

    private function findTappedFood(tapY as Lang.Number, foodCoords as Lang.Array) as Lang.Number {
        System.println("Looking for tap at Y=" + tapY + " in " + foodCoords.size() + " food items");
        
        for (var i = 0; i < foodCoords.size(); i++) {
            var coords = foodCoords[i];
            if (coords instanceof Lang.Dictionary) {
                var startYObj = coords.get("startY");
                var endYObj = coords.get("endY");
                var indexObj = coords.get("index");
                
                if (startYObj != null && endYObj != null && indexObj != null && 
                    startYObj instanceof Lang.Number && endYObj instanceof Lang.Number && indexObj instanceof Lang.Number) {
                    
                    var startY = startYObj as Lang.Number;
                    var endY = endYObj as Lang.Number;
                    var index = indexObj as Lang.Number;
                    
                    System.println("Food " + i + ": Y " + startY + " to " + endY + " (index " + index + ")");
                    
                    if (tapY >= startY && tapY <= endY) {
                        System.println("Found tapped food at index: " + index);
                        return index;
                    }
                }
            }
        }
        
        System.println("No food found at tap Y: " + tapY);
        return -1;
    }

    function navigateUp() as Void {
        var app = Application.getApp() as DiabetesFoodManagementApp;
        var foodsList = app.getFoodsList();
        var view = app.getMainView();
        
        if (foodsList.size() > 0 && view != null) {
            // Get current index from view to ensure consistency
            var currentIndex = view.getSelectedFoodIndex();
            var newIndex = (currentIndex - 1 + foodsList.size()) % foodsList.size();
            
            // Update both delegate and view
            selectedFoodIndex = newIndex;
            view.setSelectedFoodIndex(newIndex);
            
            System.println("Navigate UP: " + currentIndex + " -> " + newIndex);
            WatchUi.requestUpdate();
        }
    }

    function navigateDown() as Void {
        var app = Application.getApp() as DiabetesFoodManagementApp;
        var foodsList = app.getFoodsList();
        var view = app.getMainView();
        
        if (foodsList.size() > 0 && view != null) {
            // Get current index from view to ensure consistency
            var currentIndex = view.getSelectedFoodIndex();
            var newIndex = (currentIndex + 1) % foodsList.size();
            
            // Update both delegate and view
            selectedFoodIndex = newIndex;
            view.setSelectedFoodIndex(newIndex);
            
            System.println("Navigate DOWN: " + currentIndex + " -> " + newIndex);
            WatchUi.requestUpdate();
        }
    }

    function sendFoodData() as Void {
        var app = Application.getApp() as DiabetesFoodManagementApp;
        var foodsList = app.getFoodsList();
        
        // Get the current selected index from the view
        var view = app.getMainView();
        var currentSelectedIndex = 0;
        if (view != null) {
            currentSelectedIndex = view.getSelectedFoodIndex();
        }
        
        System.println("Sending food with index: " + currentSelectedIndex + " from " + foodsList.size() + " items");
        
        if (foodsList.size() == 0 || currentSelectedIndex >= foodsList.size()) {
            System.println("Invalid selection or empty list");
            return;
        }
        
        var selectedFood = foodsList[currentSelectedIndex];
        if (selectedFood instanceof Lang.Dictionary && selectedFood.hasKey("carbs")) {
            var carbs = selectedFood.get("carbs");
            if (carbs != null) {
                // Generate OTP
                var loopSecret = "MNWUPWJFCJRJJ4WSBPC27HJ5CZUM6YKK";
                var otp = Otp.generateTotpSha1(loopSecret);
                
                // Get current timestamp in ISO format
                var now = Time.now();
                var timeInfo = Time.Gregorian.info(now, Time.FORMAT_SHORT);
                var isoTimestamp = Lang.format("$1$-$2$-$3$T$4$:$5$:$6$.000Z", [
                    timeInfo.year.format("%04d"),
                    timeInfo.month.format("%02d"),
                    timeInfo.day.format("%02d"),
                    timeInfo.hour.format("%02d"),
                    timeInfo.min.format("%02d"),
                    timeInfo.sec.format("%02d")
                ]);
                
                // Get food name for notes
                var foodName = selectedFood.hasKey("name") ? selectedFood.get("name").toString() : "Unknown food";
                
                // Prepare POST data
                var postData = {
                    "enteredBy" => "felix",
                    "eventType" => "Remote Carbs Entry", 
                    "otp" => otp,
                    "remoteCarbs" => carbs,
                    "remoteAbsorption" => 1,
                    "notes" => foodName,
                    "units" => "mg/dl",
                    "created_at" => isoTimestamp
                };
                
                var nightscoutUrl = Application.Properties.getValue("nightscout_url");
                if (nightscoutUrl == null) {
                    nightscoutUrl = "https://glucosefelix.fly.dev";
                }
                
                var url = nightscoutUrl + "/api/v2/notifications/loop?token=garmin-5709111d29db02b8";
                
                System.println("Sending food data: " + foodName + " with " + carbs + " carbs, OTP: " + otp);
                return ;
                Communications.makeWebRequest(
                    url,
                    postData,
                    {
                        :method => Communications.HTTP_REQUEST_METHOD_POST,
                        :headers => {
                            "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
                        }
                    },
                    method(:onReceiveResponse)
                );
            }
        }
    }

    function onReceiveResponse(responseCode as Lang.Number, data as Lang.Dictionary?) as Void {
        System.println("Response code: " + responseCode);
        if (data != null) {
            System.println("Response data: " + data.toString());
        }
        
        if (responseCode == 200) {
            System.println("Food data sent successfully!");
        } else {
            System.println("Error sending food data: " + responseCode);
        }
    }

    function getSelectedFoodIndex() as Lang.Number {
        return selectedFoodIndex;
    }

}