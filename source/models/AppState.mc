import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

//! Centralized state management for the application
class AppState {
    
    // Glucose data
    public var glucoseData as GlucoseData;
    
    // Food data
    public var foodItems as Lang.Array = [];
    public var selectedFoodIndex as Lang.Number = 0;
    
    // Profile data
    public var tempBasals as Lang.Array = [];
    public var activeProfile as Lang.String = "";
    public var presetCoordinatesProfile as Lang.Array = [];
    // UI state
    public var isLoading as Lang.Boolean = false;
    public var foregroundColor as Graphics.ColorType =  Graphics.COLOR_WHITE;
    public var backgroundColor as Graphics.ColorType =  Graphics.COLOR_BLACK;



    function initialize() {
        glucoseData = new GlucoseData();
    }

    //! Update glucose data and request UI refresh
    function updateGlucoseData(data as Lang.Dictionary) as Void {
        glucoseData.update(data);
        WatchUi.requestUpdate();
    }

    //! Update food items list and reset selection
    function updateFoodItems(foodsArray as Lang.Array) as Void {
        foodItems = [];
        
        for (var i = 0; i < foodsArray.size(); i++) {
            var foodData = foodsArray[i];
            if (foodData instanceof Lang.Dictionary) {
                var foodItem = new FoodItem(foodData, i);
                foodItems.add(foodItem);
            }
        }
        
        selectedFoodIndex = 0; // Reset selection
        WatchUi.requestUpdate();
    }

    //! Update temp basals and active profile
    function updateTempBasals(data as Lang.Dictionary) as Void {
        if (data.hasKey("profiles")) {
            var profiles = data.get("profiles");
            if (profiles instanceof Lang.Array) {
                tempBasals = profiles;
            }
        }
        
        if (data.hasKey("activeProfile")) {
            var profile = data.get("activeProfile");
            if (profile != null && profile instanceof Lang.String) {
                activeProfile = profile;
            }
        }
        WatchUi.requestUpdate();
    }

    //! Update active profile only
    function updateActiveProfile(profile as Lang.String) as Void {
        activeProfile = profile;
        WatchUi.requestUpdate();
    }

    //! Navigate to next food item
    function navigateDown() as Void {
        if (foodItems.size() > 0) {
            selectedFoodIndex = (selectedFoodIndex + 1) % foodItems.size();
            WatchUi.requestUpdate();
        }
    }

    //! Navigate to previous food item
    function navigateUp() as Void {
        if (foodItems.size() > 0) {
            selectedFoodIndex = (selectedFoodIndex - 1 + foodItems.size()) % foodItems.size();
            WatchUi.requestUpdate();
        }
    }

    //! Set selected food index
    function setSelectedFoodIndex(index as Lang.Number) as Void {
        if (index >= 0 && index < foodItems.size()) {
            selectedFoodIndex = index;
            WatchUi.requestUpdate();
        }
    }

    //! Get currently selected food item
    function getSelectedFoodItem() as FoodItem? {
        if (selectedFoodIndex >= 0 && selectedFoodIndex < foodItems.size()) {
            return foodItems[selectedFoodIndex];
        }
        return null;
    }

    //! Find food item at given Y coordinate
    function findFoodItemAtY(y as Lang.Number) as FoodItem? {
        var closestItem = null;
        var closestDistance = 999999;
        
        for (var i = 0; i < foodItems.size(); i++) {
            var foodItem = foodItems[i];
            if (foodItem instanceof FoodItem) {
                // Check for exact match first
                if (foodItem.containsY(y)) {
                    return foodItem;
                }
                
                // Track closest item as fallback
                var distance = foodItem.getDistanceFromCenter(y);
                if (distance < closestDistance) {
                    closestDistance = distance;
                    closestItem = foodItem;
                }
            }
        }
        
        return closestItem;
    }

    //! Update food item coordinates after rendering
    function updateFoodCoordinates(coordinates as Lang.Array) as Void {
        for (var i = 0; i < coordinates.size() && i < foodItems.size(); i++) {
            var coords = coordinates[i];
            var foodItem = foodItems[i];
            
            if (coords instanceof Lang.Dictionary && foodItem instanceof FoodItem) {
                var startY = coords.get("startY");
                var endY = coords.get("endY");
                
                if (startY != null && endY != null && 
                    startY instanceof Lang.Number && endY instanceof Lang.Number) {
                    foodItem.setCoordinates(startY, endY);
                }
            }
        }
    }

    //! Set loading state
    function setLoading(loading as Lang.Boolean) as Void {
        isLoading = loading;
        WatchUi.requestUpdate();
    }
}