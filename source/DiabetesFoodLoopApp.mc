import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:typecheck([disableBackgroundCheck, disableGlanceCheck]))
class DiabetesFoodLoopApp extends Application.AppBase {

    // Core components
    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    private var appState as AppState?;
    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    private var nightscoutService as NightscoutService?;
    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    private var otpService as OtpService?;
    
    // Views and delegates
    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    private var mainView as DiabetesFoodLoopView?;
    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    private var mainDelegate as DiabetesFoodLoopDelegate?;

    function initialize() {
        AppBase.initialize();
    }
    
    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    private function initializeServices() as Void {
        // Initialize core components only for main widget
        appState = new AppState();
        nightscoutService = new NightscoutService(appState);
        otpService = new OtpService();
        
        // Set up service callbacks
        nightscoutService.setCallback(method(:onServiceCallback));
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        // Data fetching is now handled in getInitialView after service initialization
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Called when the user changes app settings in Garmin Connect. Re-fetch so
    // a new URL/token/unit takes effect immediately instead of at the next tick.
    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    function onSettingsChanged() as Void {
        if (nightscoutService != null) {
            nightscoutService.fetchGlucoseData();
            nightscoutService.fetchTempBasalData();
        }
        WatchUi.requestUpdate();
    }

    // Return the initial view of your widget here - only for non-glance context
    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    function getInitialView() as [Views] or [Views, InputDelegates] {
        // Initialize services only when creating main view (not for glance)
        initializeServices();
        
        // Fetch live glucose data (current value + ~4h trend history) from Nightscout
        nightscoutService.fetchGlucoseData();
        // Load static food list from embedded JSON resource
        appState.updateFoodItems(FoodDatabase.loadAll());
        
        mainView = new DiabetesFoodLoopView(appState);
        mainDelegate = new DiabetesFoodLoopDelegate(appState, nightscoutService, otpService);
        return [ mainView, mainDelegate ];
    }

    //! Handle callbacks from services
    function onServiceCallback(type as Lang.String, data as Lang.Object) as Void {
        if (appState == null) {
            return;
        }
        
        if (type.equals("glucose")) {
            if (data instanceof Lang.Dictionary) {
                appState.updateGlucoseData(data);
                // Store glucose data for glance view
                try {
                    Application.Storage.setValue("last_glucose_data", data);
                } catch (ex) {
                    // Ignore storage errors
                }
            }
        } else if (type.equals("glucoseHistory")) {
            if (data instanceof Lang.Array) {
                appState.updateGlucoseHistory(data);
            }
        } else if (type.equals("foods")) {
            if (data instanceof Lang.Array) {
                appState.updateFoodItems(data);
            }
        } else if (type.equals("overridePresets")) {
            if (data instanceof Lang.Array) {
                appState.updateOverridePresets(data);
            }
        } else if (type.equals("activeProfile")) {
            if (data instanceof Lang.String) {
                appState.updateActiveProfile(data);
            }
        } else if (type.equals("foodEntrySent")) {
            // Handle food entry response if needed
        }
    }

    function getFoodsList() as Lang.Array {
        if (appState == null) {
            return [];
        }
        
        // Convert FoodItem objects back to dictionaries for compatibility
        var foodsArray = [];
        for (var i = 0; i < appState.foodItems.size(); i++) {
            var foodItem = appState.foodItems[i];
            if (foodItem instanceof FoodItem) {
                foodsArray.add(foodItem.toDictionary());
            }
        }
        return foodsArray;
    }

    function getMainView() as DiabetesFoodLoopView? {
        return mainView;
    }

    //! Get app state for access from other components
    function getAppState() as AppState? {
        return appState;
    }

    //! Get nightscout service for direct access from other components
    function getNightscoutService() as NightscoutService? {
        return nightscoutService;
    }

    //! Return the glance view for home screen widget
    (:typecheck(disableBackgroundCheck))
    function getGlanceView() as [ WatchUi.GlanceView ] or [ WatchUi.GlanceView, WatchUi.GlanceViewDelegate ] or Null {
        return getDiabetesFoodLoopGlanceView();
    }
}


function getApp() as DiabetesFoodLoopApp {
    return Application.getApp() as DiabetesFoodLoopApp;
}