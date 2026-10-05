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
    // Filter navigation order: false = category→brand (default), true = brand→category.
    public var filterOrderBrandFirst as Lang.Boolean = false;

    // UI state
    public var isLoading as Lang.Boolean = false;
    // Index of the food item most recently sent, or -1. Used for green-flash feedback.
    public var sentFoodIndex as Lang.Number = -1;
    // Food send state machine (Constants.SEND_*) + System.getTimer() of the last change.
    public var sendState as Lang.Number = Constants.SEND_IDLE;
    public var sendStateChangedMs as Lang.Number = 0;
    public var sendErrorCode as Lang.Number = 0;
    // Last failed profile (override) activation: 0 = none, else the HTTP/Garmin code.
    public var profileErrorCode as Lang.Number = 0;
    // Loop's recommended bolus (units), read from Nightscout devicestatus.
    // INFORMATION ONLY: never used to send or change anything.
    public var hasRecommendedBolus as Lang.Boolean = false;
    public var recommendedBolus as Lang.Float = 0.0;
    // ISO-8601 time at which Loop computed it (loop.timestamp), "" if unknown.
    public var recommendedBolusTime as Lang.String = "";
    // Last failed recommended-bolus fetch: 0 = none, else HTTP / Garmin code.
    public var recommendedBolusError as Lang.Number = 0;
    // --- Remote bolus: sending Loop's recommendation (see canSendBolus) ---
    public var bolusSendState as Lang.Number = Constants.SEND_IDLE;
    public var bolusSendChangedMs as Lang.Number = 0;
    public var bolusSendErrorCode as Lang.Number = 0;
    // First tap arms a confirmation; the second tap (within the window, same
    // amount, same recommendation) sends. -1 = not armed.
    public var bolusConfirmStartMs as Lang.Number = -1;
    public var bolusArmedUnits as Lang.Float = 0.0;
    public var bolusArmedTime as Lang.String = "";
    // The recommendation (by its Loop timestamp) that was last sent: it can
    // not be sent again until Loop publishes a newer one.
    public var bolusSentForTime as Lang.String = "";
    public var bolusSentUnits as Lang.Float = 0.0;
    public var bolusButtonRegion as Lang.Dictionary? = null;
    // Glucose fetch health: true after a failed request, until the next success.
    public var glucoseFetchFailed as Lang.Boolean = false;
    // System.getTimer() of the last glucose fetch attempt, -1 = never.
    public var lastFetchAttemptMs as Lang.Number = -1;
    public var foregroundColor as Graphics.ColorType =  Graphics.COLOR_WHITE;
    public var backgroundColor as Graphics.ColorType =  Graphics.COLOR_BLACK;



    function initialize() {
        glucoseData = new GlucoseData();
    }

    function updateRecommendedBolus(units as Lang.Float, isoTime as Lang.String) as Void {
        recommendedBolus = units;
        recommendedBolusTime = isoTime;
        hasRecommendedBolus = true;
        recommendedBolusError = 0;
        WatchUi.requestUpdate();
    }

    //! Age in seconds of Loop's recommendation (from loop.timestamp), or -1 when
    //! there is none or its time can't be read. Callers treat -1 as "don't show".
    function getRecommendedBolusAgeSeconds() as Lang.Number {
        var s = recommendedBolusTime;
        if (!hasRecommendedBolus || s.length() < 19) { return -1; }
        var year   = s.substring(0, 4).toNumber();
        var month  = s.substring(5, 7).toNumber();
        var day    = s.substring(8, 10).toNumber();
        var hour   = s.substring(11, 13).toNumber();
        var minute = s.substring(14, 16).toNumber();
        var second = s.substring(17, 19).toNumber();
        if (year == null || month == null || day == null ||
            hour == null || minute == null || second == null) { return -1; }
        var computedAt = Toybox.Time.Gregorian.moment({
            :year => year, :month => month, :day => day,
            :hour => hour, :minute => minute, :second => second
        });
        var age = Toybox.Time.now().subtract(computedAt).value();
        return age < 0 ? 0 : age;
    }

    //! True when the recommendation may be offered for sending: present, read
    //! without error, young enough, within sane bounds, and not already sent.
    function canSendBolus() as Lang.Boolean {
        if (!hasRecommendedBolus || recommendedBolusError != 0) { return false; }
        var age = getRecommendedBolusAgeSeconds();
        if (age < 0 || age > Constants.BOLUS_MAX_AGE_SEC) { return false; }
        if (recommendedBolus < Constants.BOLUS_MIN_UNITS) { return false; }
        if (recommendedBolus > Constants.BOLUS_MAX_UNITS) { return false; }
        if (recommendedBolusTime.equals(bolusSentForTime)) { return false; }
        return true;
    }

    function setBolusSendState(state as Lang.Number, errorCode as Lang.Number) as Void {
        bolusSendState = state;
        bolusSendErrorCode = errorCode;
        bolusSendChangedMs = System.getTimer();
        // A definite refusal by the server means nothing was delivered: allow a retry.
        // For OK / unconfirmed the same recommendation stays blocked.
        if (state == Constants.SEND_FAILED) {
            bolusSentForTime = "";
        }
        WatchUi.requestUpdate();
    }

    //! Taps on the bolus button are ignored while sending / just sent / unconfirmed.
    function isBolusLocked(nowMs as Lang.Number) as Lang.Boolean {
        var elapsed = nowMs - bolusSendChangedMs;
        if (bolusSendState == Constants.SEND_PENDING) { return elapsed < Constants.SEND_TIMEOUT_MS; }
        if (bolusSendState == Constants.SEND_OK) { return elapsed < Constants.BOLUS_HOLD_OK_MS; }
        if (bolusSendState == Constants.SEND_UNCONFIRMED) { return elapsed < Constants.BOLUS_HOLD_FAIL_MS; }
        return false;
    }

    function armBolusConfirm(nowMs as Lang.Number) as Void {
        bolusConfirmStartMs = nowMs;
        bolusArmedUnits = recommendedBolus;
        bolusArmedTime = recommendedBolusTime;
        WatchUi.requestUpdate();
    }

    function cancelBolusConfirm() as Void {
        bolusConfirmStartMs = -1;
    }

    //! Armed only while the window is open AND the amount/recommendation are
    //! still exactly what the rider saw when arming.
    function isBolusConfirmArmed(nowMs as Lang.Number) as Lang.Boolean {
        if (bolusConfirmStartMs < 0) { return false; }
        if (nowMs - bolusConfirmStartMs > Constants.BOLUS_CONFIRM_MS) { return false; }
        if (!bolusArmedTime.equals(recommendedBolusTime)) { return false; }
        return (bolusArmedUnits - recommendedBolus).abs() < 0.001;
    }

    //! Expire timed states (confirmation window, pending timeout, result display).
    function normalizeBolusState(nowMs as Lang.Number) as Void {
        if (bolusConfirmStartMs >= 0 && !isBolusConfirmArmed(nowMs)) {
            cancelBolusConfirm();
        }
        var elapsed = nowMs - bolusSendChangedMs;
        if (bolusSendState == Constants.SEND_PENDING) {
            if (elapsed >= Constants.SEND_TIMEOUT_MS) {
                setBolusSendState(Constants.SEND_UNCONFIRMED, Constants.REQUEST_TIMEOUT_CODE);
            }
        } else if (bolusSendState == Constants.SEND_OK) {
            if (elapsed >= Constants.BOLUS_HOLD_OK_MS) { setBolusSendState(Constants.SEND_IDLE, 0); }
        } else if (bolusSendState == Constants.SEND_FAILED || bolusSendState == Constants.SEND_UNCONFIRMED) {
            if (elapsed >= Constants.BOLUS_HOLD_FAIL_MS) { setBolusSendState(Constants.SEND_IDLE, 0); }
        }
    }

    function setRecommendedBolusError(code as Lang.Number) as Void {
        recommendedBolusError = code;
        WatchUi.requestUpdate();
    }

    function setProfileError(code as Lang.Number) as Void {
        profileErrorCode = code;
        WatchUi.requestUpdate();
    }

    //! Move the food send state machine and stamp the change time.
    function setSendState(state as Lang.Number, errorCode as Lang.Number) as Void {
        sendState = state;
        sendErrorCode = errorCode;
        sendStateChangedMs = System.getTimer();
        WatchUi.requestUpdate();
    }

    //! True while a new food tap must be ignored (answer pending, or success
    //! just shown): prevents duplicate carb entries from double taps.
    function isSendLocked() as Lang.Boolean {
        return isSendLockedAt(System.getTimer());
    }

    //! The lock also self-expires, so a lost feedback timer can never leave
    //! the grid permanently unresponsive.
    function isSendLockedAt(nowMs as Lang.Number) as Lang.Boolean {
        var elapsed = nowMs - sendStateChangedMs;
        if (sendState == Constants.SEND_PENDING) {
            return elapsed < Constants.SEND_TIMEOUT_MS;
        }
        if (sendState == Constants.SEND_OK) {
            return elapsed < Constants.SEND_HOLD_OK_MS;
        }
        return false;
    }

    //! Decide whether the periodic tick should hit the network now.
    //!  - never fetched, or last fetch failed: retry every RETRY_INTERVAL
    //!  - reading older than the CGM cadence: poll every STALE_POLL (new value due)
    //!  - otherwise: wait, the next reading is not due yet
    function isFetchDue(nowMs as Lang.Number) as Lang.Boolean {
        if (lastFetchAttemptMs < 0) {
            return true;
        }
        var elapsed = nowMs - lastFetchAttemptMs;
        if (glucoseFetchFailed) {
            return elapsed >= Layout.RETRY_INTERVAL_MS;
        }
        var age = glucoseData.getAgeSeconds();
        if (age < 0) {
            return elapsed >= Layout.RETRY_INTERVAL_MS;
        }
        if (age >= Constants.GLUCOSE_EXPECTED_SEC) {
            return elapsed >= Layout.STALE_POLL_INTERVAL_MS;
        }
        return false;
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

    //! Load the food selection and filter order from persistent storage.
    //! Call once from SugarPaceApp.getInitialView() (not in initialize() which
    //! also runs in glance/background context where Storage may be absent).
    function initializeSelection() as Void {
        var stored = Application.Storage.getValue("selected_food_ids");
        if (stored instanceof Lang.Dictionary) {
            selectedFoodIds = stored;
        }
        var order = Application.Storage.getValue("filter_order_brand_first");
        if (order instanceof Lang.Boolean) {
            filterOrderBrandFirst = order;
        }
    }

    //! Toggle filter navigation order (category→brand ↔ brand→category) and persist.
    function toggleFilterOrder() as Void {
        filterOrderBrandFirst = !filterOrderBrandFirst;
        Application.Storage.setValue("filter_order_brand_first", filterOrderBrandFirst);
        WatchUi.requestUpdate();
    }

    //! Toggle all items in scope: if all selected → deselect all; else → select all.
    //! Persists and refreshes the food grid.
    function toggleAllForItems(items as Lang.Array) as Void {
        if (selectedFoodIds == null) {
            var allItems = FoodDatabase.loadAllUnfiltered();
            selectedFoodIds = {} as Lang.Dictionary;
            for (var i = 0; i < allItems.size(); i++) {
                var item = allItems[i];
                if (item instanceof FoodItem) {
                    (selectedFoodIds as Lang.Dictionary)[item.id] = true;
                }
            }
        }
        var allSelected = true;
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (!(item instanceof FoodItem)) { continue; }
            if (!(selectedFoodIds as Lang.Dictionary).hasKey(item.id)) {
                allSelected = false;
                break;
            }
        }
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (!(item instanceof FoodItem)) { continue; }
            if (allSelected) {
                (selectedFoodIds as Lang.Dictionary).remove(item.id);
            } else {
                (selectedFoodIds as Lang.Dictionary)[item.id] = true;
            }
        }
        Application.Storage.setValue("selected_food_ids", selectedFoodIds);
        updateFoodItems(FoodDatabase.loadAll(selectedFoodIds));
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