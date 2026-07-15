import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Application;

//! Centralized state management for the application
(:glance, :background)
class AppState {
    
    // Glucose data
    public var glucoseData as GlucoseData;
    // Recent glucose readings (chronological, oldest first) used for the trend chart.
    // Each entry is a Lang.Number (sgv value in mg/dl).
    public var glucoseHistory as Lang.Array = [];
    
    // Food data
    public var foodItems as Lang.Array = [];
    public var selectedFoodIndex as Lang.Number = -1;
    // Tile coordinates for the 2-column food grid, used for touch hit-testing.
    // Each entry: { "x0"=>, "y0"=>, "x1"=>, "y1"=>, "index"=> }
    public var foodGridCoordinates as Lang.Array = [];
    // Tap regions for the glucose card, as { "x0"=>, "y0"=>, "x1"=>, "y1"=> }
    // or null before the first render. Used for touch hit-testing.
    public var headerRegion as Lang.Dictionary? = null;
    public var chartRegion as Lang.Dictionary? = null;
    // Visible trend-chart window in minutes; cycles 4h -> 2h -> 1h -> 30m on tap.
    public var chartWindowMinutes as Lang.Number = 240;
    // Vertical scroll of the whole page (px). maxScroll is recomputed by the
    // view each render from the actual content height.
    public var scrollOffset as Lang.Number = 0;
    public var maxScroll as Lang.Number = 0;
    
    // Profile data. overridePresets = the list of Loop override presets (name +
    // data). activeProfile = which one is currently active on Nightscout; it has
    // a single source of truth (the treatments/override response), never the
    // profile-list response, to avoid a race between the two.
    public var overridePresets as Lang.Array = [];
    public var activeProfile as Lang.String = "";
    public var presetCoordinatesProfile as Lang.Array = [];
    // Food selection: which food IDs the user has chosen to display.
    // null = not configured (first launch) → all foods shown.
    // Empty dict = configured but nothing selected → empty grid + message.
    public var selectedFoodIds as Lang.Dictionary? = null;

    // UI state
    public var isLoading as Lang.Boolean = false;
    // Index of the food item most recently sent, or -1. Used for green-flash feedback.
    public var sentFoodIndex as Lang.Number = -1;
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

    //! Update recent glucose history (list of Lang.Number sgv values, oldest first)
    function updateGlucoseHistory(history as Lang.Array) as Void {
        System.println("AppState.updateGlucoseHistory: " + history.size() + " points");
        glucoseHistory = history;
        WatchUi.requestUpdate();
    }

    //! Update food items list and reset selection
    function updateFoodItems(foodsArray as Lang.Array) as Void {
        foodItems = [];
        
        for (var i = 0; i < foodsArray.size(); i++) {
            var foodData = foodsArray[i];
            if (foodData instanceof FoodItem) {
                foodItems.add(foodData);
            } else if (foodData instanceof Lang.Dictionary) {
                var foodItem = new FoodItem(foodData, i);
                foodItems.add(foodItem);
            }
        }
        
        selectedFoodIndex = 0; // Reset selection
        WatchUi.requestUpdate();
    }

    //! Update the list of available override presets (not the active profile —
    //! that has its own single source of truth via updateActiveProfile).
    function updateOverridePresets(presets as Lang.Array) as Void {
        overridePresets = presets;
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

    //! Update food grid tile coordinates (2-column layout) after rendering
    function updateFoodGridCoordinates(coordinates as Lang.Array) as Void {
        foodGridCoordinates = coordinates;
    }

    //! Record the header tap region after rendering
    function updateHeaderRegion(x0 as Lang.Number, y0 as Lang.Number, x1 as Lang.Number, y1 as Lang.Number) as Void {
        headerRegion = { "x0" => x0, "y0" => y0, "x1" => x1, "y1" => y1 };
    }

    //! Scroll the page by delta px, clamped to the content bounds.
    function scrollBy(delta as Lang.Number) as Void {
        scrollOffset += delta;
        if (scrollOffset < 0) { scrollOffset = 0; }
        if (scrollOffset > maxScroll) { scrollOffset = maxScroll; }
        WatchUi.requestUpdate();
    }

    //! Cycle the trend-chart window: 4h -> 2h -> 1h -> 30m -> 4h
    function cycleChartWindow() as Void {
        if (chartWindowMinutes == 240) {
            chartWindowMinutes = 120;
        } else if (chartWindowMinutes == 120) {
            chartWindowMinutes = 60;
        } else if (chartWindowMinutes == 60) {
            chartWindowMinutes = 30;
        } else {
            chartWindowMinutes = 240;
        }
        WatchUi.requestUpdate();
    }

    //! Record the chart tap region after rendering
    function updateChartRegion(x0 as Lang.Number, y0 as Lang.Number, x1 as Lang.Number, y1 as Lang.Number) as Void {
        chartRegion = { "x0" => x0, "y0" => y0, "x1" => x1, "y1" => y1 };
    }

    //! True if (x,y) falls inside the given { x0,y0,x1,y1 } region
    function isPointInRegion(region as Lang.Dictionary?, x as Lang.Number, y as Lang.Number) as Lang.Boolean {
        if (region == null) {
            return false;
        }
        var x0 = region.get("x0");
        var y0 = region.get("y0");
        var x1 = region.get("x1");
        var y1 = region.get("y1");
        if (!(x0 instanceof Lang.Number) || !(y0 instanceof Lang.Number) ||
            !(x1 instanceof Lang.Number) || !(y1 instanceof Lang.Number)) {
            return false;
        }
        if (x < x0 || x > x1) {
            return false;
        }
        if (y < y0 || y > y1) {
            return false;
        }
        return true;
    }

    //! Find the food item whose grid tile contains the given tap point
    function findFoodItemAtPoint(x as Lang.Number, y as Lang.Number) as FoodItem? {
        for (var i = 0; i < foodGridCoordinates.size(); i++) {
            var coords = foodGridCoordinates[i];
            if (coords instanceof Lang.Dictionary) {
                var x0 = coords.get("x0");
                var y0 = coords.get("y0");
                var x1 = coords.get("x1");
                var y1 = coords.get("y1");
                var index = coords.get("index");
                if (x0 instanceof Lang.Number && y0 instanceof Lang.Number &&
                    x1 instanceof Lang.Number && y1 instanceof Lang.Number &&
                    index instanceof Lang.Number &&
                    x >= x0 && x <= x1 && y >= y0 && y <= y1 &&
                    index >= 0 && index < foodItems.size()) {
                    var item = foodItems[index];
                    if (item instanceof FoodItem) {
                        return item;
                    }
                }
            }
        }
        return null;
    }

    //! Set loading state
    function setLoading(loading as Lang.Boolean) as Void {
        isLoading = loading;
        WatchUi.requestUpdate();
    }

    //! Load the food selection from persistent storage.
    //! Call once from SugarPaceApp.getInitialView() (not in initialize() which
    //! also runs in glance/background context where Storage may be absent).
    function initializeSelection() as Void {
        var stored = Application.Storage.getValue("selected_food_ids");
        if (stored instanceof Lang.Dictionary) {
            selectedFoodIds = stored;
        }
    }

    //! Toggle a food item in/out of the user's selection.
    //! Persists immediately to Application.Storage and reloads the food grid.
    function toggleFoodSelection(id as Lang.String) as Void {
        if (selectedFoodIds == null) {
            // First toggle: initialise from the full catalogue so everything
            // that wasn't explicitly toggled stays visible.
            var allItems = FoodDatabase.loadAllUnfiltered();
            selectedFoodIds = {} as Lang.Dictionary;
            for (var i = 0; i < allItems.size(); i++) {
                var item = allItems[i];
                if (item instanceof FoodItem) {
                    selectedFoodIds[item.id] = true;
                }
            }
        }
        if ((selectedFoodIds as Lang.Dictionary).hasKey(id)) {
            (selectedFoodIds as Lang.Dictionary).remove(id);
        } else {
            (selectedFoodIds as Lang.Dictionary)[id] = true;
        }
        Application.Storage.setValue("selected_food_ids", selectedFoodIds);
        updateFoodItems(FoodDatabase.loadAll(selectedFoodIds));
    }

    //! True if the given food id is in the current selection (or no selection is
    //! configured yet, in which case everything is implicitly selected).
    function isFoodSelected(id as Lang.String) as Lang.Boolean {
        if (selectedFoodIds == null) {
            return true;
        }
        return (selectedFoodIds as Lang.Dictionary).hasKey(id);
    }

    //! Count of selected items across the given item list.
    function countSelected(items as Lang.Array) as Lang.Number {
        var count = 0;
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (item instanceof FoodItem && isFoodSelected(item.id)) {
                count++;
            }
        }
        return count;
    }
}