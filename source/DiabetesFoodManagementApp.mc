import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class DiabetesFoodManagementApp extends Application.AppBase {

    private var mainView as DiabetesFoodManagementView?;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        mainView = new DiabetesFoodManagementView();
        return [ mainView, new DiabetesFoodManagementDelegate() ];
    }

    function getTempBasals() as Lang.Array {
        if (mainView != null) {
            return mainView.getTempBasals();
        }
        return [];
    }

    function fetchTempBasalData() as Void {
        if (mainView != null) {
            mainView.fetchTempBasalData();
        }
    }

    function getActiveProfile() as Lang.String {
        if (mainView != null) {
            return mainView.getActiveProfile();
        }
        return "";
    }

}

function getApp() as DiabetesFoodManagementApp {
    return Application.getApp() as DiabetesFoodManagementApp;
}