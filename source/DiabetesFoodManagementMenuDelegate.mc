import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Application;

class DiabetesFoodManagementMenuDelegate extends WatchUi.MenuInputDelegate {
    private var appState as AppState;

    function initialize(appState as AppState) {
        self.appState = appState;

        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :temp_overrides) {
            showTempOverrides();
        } 
    }

    function showTempOverrides() as Void {
        var app = Application.getApp() as DiabetesFoodManagementApp;
        if (app != null) {
            app.getNightscoutService().fetchTempBasalData();
        }

        var tempOverridesView = new TempOverridesView(self.appState);
        WatchUi.pushView(tempOverridesView, new TempOverridesInputDelegate(tempOverridesView), WatchUi.SLIDE_UP);
    }

}