import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Application;

class DiabetesFoodManagementMenuDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
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
            app.fetchTempBasalData();
        }
        
        var tempOverridesView = new TempOverridesView();
        WatchUi.pushView(tempOverridesView, new TempOverridesInputDelegate(), WatchUi.SLIDE_UP);
    }

}