import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class DiabetesFoodManagementApp extends Application.AppBase {

    // Core components
    private var appState as AppState;
    private var nightscoutService as NightscoutService;
    private var otpService as OtpService;
    
    // Views and delegates
    private var mainView as DiabetesFoodManagementView?;
    private var mainDelegate as DiabetesFoodManagementDelegate?;

    function initialize() {
        AppBase.initialize();
        
        // Initialize core components
        appState = new AppState();
        nightscoutService = new NightscoutService(appState);
        otpService = new OtpService();
        
        // Set up service callbacks
        nightscoutService.setCallback(method(:onServiceCallback));
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        // Fetch initial data
        nightscoutService.fetchGlucoseData();
        nightscoutService.fetchFoodData();
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        mainView = new DiabetesFoodManagementView(appState);
        mainDelegate = new DiabetesFoodManagementDelegate(appState, nightscoutService, otpService);
        return [ mainView, mainDelegate ];
    }

    //! Handle callbacks from services
    function onServiceCallback(type as Lang.String, data as Lang.Object) as Void {
        if (type.equals("glucose")) {
            if (data instanceof Lang.Dictionary) {
                appState.updateGlucoseData(data);
            }
        } else if (type.equals("foods")) {
            if (data instanceof Lang.Array) {
                appState.updateFoodItems(data);
            }
        } else if (type.equals("tempBasals")) {
            if (data instanceof Lang.Dictionary) {
                appState.updateTempBasals(data);
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

    function getMainView() as DiabetesFoodManagementView? {
        return mainView;
    }

    //! Get app state for access from other components
    function getAppState() as AppState {
        return appState;
    }

    //! Get nightscout service for direct access from other components
    function getNightscoutService() as NightscoutService {
        return nightscoutService;
    }
}

function getApp() as DiabetesFoodManagementApp {
    return Application.getApp() as DiabetesFoodManagementApp;
}