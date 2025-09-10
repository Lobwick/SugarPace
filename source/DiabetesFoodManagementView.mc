import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.System;

class DiabetesFoodManagementView extends WatchUi.View {

    private var monkeyBitmap as BitmapResource?;
    private var updateTimer as Timer.Timer?;
    private var appState as AppState;

    function initialize(appState as AppState) {
        View.initialize();
        self.appState = appState;
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        // Load the monkey bitmap
        monkeyBitmap = WatchUi.loadResource(Rez.Drawables.monkey);
    }

    // Called when this View is brought to the foreground
    function onShow() as Void {
        // Data fetching is handled by the app orchestrator
        
        // Update every 5 minutes
        updateTimer = new Timer.Timer();
        updateTimer.start(method(:requestDataUpdate), 300000, true);
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        drawGlucoseInfo(dc, width);
        drawFoodList(dc, width, height);
    }

    // Called when this View is removed from the screen
    function onHide() as Void {
        if (updateTimer != null) {
            updateTimer.stop();
            updateTimer = null;
        }
    }

    //! Draw glucose information at the top
    private function drawGlucoseInfo(dc as Dc, width as Lang.Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        // Display blood sugar level in large text at top
        var bloodSugar = appState.glucoseData.bloodSugarLevel;
        var default_unit =  Application.Properties.getValue("default_unit");

        var bloodSugarText = bloodSugar > 0 ? bloodSugar.toString() + " " + default_unit : "-- " + default_unit;

        // Set color based on glucose level
        if (bloodSugar == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        } else if (bloodSugar < 70) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        } else if (bloodSugar > 180) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        }
        
        var font = Graphics.FONT_NUMBER_THAI_HOT;
        var textHeight = dc.getFontHeight(font);
        dc.drawText(width/2, 20, font, bloodSugarText, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Display trend information only if we have valid glucose data
        if (bloodSugar > 0) {
            var trendY = 20 + textHeight + 10;
            var smallFont = Graphics.FONT_XTINY;
            
            // Reset color to white for trend info
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            
            // Trend rate on the left
            var trendText = appState.glucoseData.trendRate >= 0 ? 
                "+" + appState.glucoseData.trendRate.format("%.1f") + " " + default_unit : 
                appState.glucoseData.trendRate.format("%.1f") + " " + default_unit;
            dc.drawText(width/4, trendY, smallFont, trendText, Graphics.TEXT_JUSTIFY_CENTER);
            
            // Direction arrow in the middle using GlucoseData method
            var arrowText = appState.glucoseData.getDirectionArrow();
            dc.drawText(width/2, trendY, Graphics.FONT_SMALL, arrowText, Graphics.TEXT_JUSTIFY_CENTER);
            
            // Time since last update on the right using GlucoseData method
            var timeText = appState.glucoseData.getTimeSinceUpdate();
            dc.drawText(3 * width/4, trendY, smallFont, timeText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Draw food list with selection highlighting
    private function drawFoodList(dc as Dc, width as Lang.Number, height as Lang.Number) as Void {
        var startY = 220;
        var currentY = startY;
        var itemsDisplayed = 0;
        
        // Calculate spacing based on monkey bitmap size
        var monkeyHeight = monkeyBitmap != null ? monkeyBitmap.getHeight() : 30;
        var spacing = monkeyHeight + 10;
        var maxItems = (height - startY - 20) / spacing;
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        // Track coordinates for touch detection
        var coordinates = [];
        
        // Display available foods
        for (var i = 0; i < appState.foodItems.size() && itemsDisplayed < maxItems; i++) {
            var foodItem = appState.foodItems[i];
            if (foodItem instanceof FoodItem) {
                
                // Record coordinates for this food item
                var itemStartY = currentY - 2;
                var itemEndY = currentY + monkeyHeight + 2;
                var coords = {
                    "startY" => itemStartY,
                    "endY" => itemEndY,
                    "index" => i
                };
                coordinates.add(coords);
                
                System.println("Food " + i + " (" + foodItem.name + "): Y " + itemStartY + " to " + itemEndY);
                
                // Highlight selected item
                var isSelected = (i == appState.selectedFoodIndex);
                if (isSelected) {
                    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
                    dc.fillRectangle(5, currentY - 2, width - 10, monkeyHeight + 4);
                    dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                }
                
                // Draw the monkey bitmap
                if (monkeyBitmap != null) {
                    dc.drawBitmap(8, currentY, monkeyBitmap);
                    
                    // Text in vertical middle of monkey, with margin to the right of image
                    var textY = currentY + (monkeyHeight / 2) - 8;
                    var textX = 8 + monkeyBitmap.getWidth() + 10;
                    dc.drawText(textX, textY, Graphics.FONT_SMALL, foodItem.name, Graphics.TEXT_JUSTIFY_LEFT);
                    
                    // Show carbs info if available
                    if (foodItem.carbs > 0) {
                        var carbsText = foodItem.carbs.toString() + "g";
                        dc.drawText(width - 10, textY, Graphics.FONT_SMALL, carbsText, Graphics.TEXT_JUSTIFY_RIGHT);
                    }
                }
                
                currentY += spacing;
                itemsDisplayed++;
            }
        }
        
        // Update coordinates in app state for touch detection
        appState.updateFoodCoordinates(coordinates);
        
        // If no foods, show loading message
        if (appState.foodItems.size() == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width/2, startY + 20, Graphics.FONT_SMALL, WatchUi.loadResource(Rez.Strings.loading_foods), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(width/2, startY + 50, Graphics.FONT_XTINY, WatchUi.loadResource(Rez.Strings.check_nightscout_config), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Request data update from the app orchestrator
    function requestDataUpdate() as Void {
        // Data updates are now handled automatically by the app
        // No need to manually trigger updates from the view
    }

    // Legacy methods for compatibility during migration
    function getFoodsList() as Lang.Array {
        return appState != null ? getApp().getFoodsList() : [];
    }

    function setSelectedFoodIndex(index as Lang.Number) as Void {
        if (appState != null) {
            appState.setSelectedFoodIndex(index);
        }
    }

    function getSelectedFoodIndex() as Lang.Number {
        return appState != null ? appState.selectedFoodIndex : 0;
    }

    function getFoodCoordinates() as Lang.Array {
        // Return coordinates from food items
        var coordinates = [];
        if (appState != null) {
            for (var i = 0; i < appState.foodItems.size(); i++) {
                var foodItem = appState.foodItems[i];
                if (foodItem instanceof FoodItem) {
                    coordinates.add({
                        "startY" => foodItem.startY,
                        "endY" => foodItem.endY,
                        "index" => foodItem.index
                    });
                }
            }
        }
        return coordinates;
    }
}