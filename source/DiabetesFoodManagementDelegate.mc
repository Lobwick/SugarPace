import Toybox.Lang;
import Toybox.WatchUi;

class DiabetesFoodManagementDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new DiabetesFoodManagementMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

}