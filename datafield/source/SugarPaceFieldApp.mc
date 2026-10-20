import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! SugarPace data field app (read-only). See SugarPaceField.
class SugarPaceFieldApp extends Application.AppBase {

    private var field as SugarPaceField?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        field = new SugarPaceField();
        return [field];
    }

    //! Settings changed in Garmin Connect: fetch again soon instead of waiting.
    function onSettingsChanged() as Void {
        if (field != null) {
            field.refreshNow();
        }
    }
}
