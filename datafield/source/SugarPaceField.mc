import Toybox.Activity;
import Toybox.Application;
import Toybox.Communications;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! SugarPace data field (read-only): shows the latest glucose and its trend, e.g.
//! "112 ↗", with the age of the reading in the label ("Glucose 3m"), and records the
//! glucose in the activity's FIT file.
//!
//! It fetches by itself (apps can't share data on the device): one small request to
//! Nightscout from the foreground, only when a new reading is due. It never sends
//! anything to Nightscout.
class SugarPaceField extends WatchUi.SimpleDataField {

    private static const REQUEST_TIMEOUT_MS as Lang.Number = 20000;
    private static const RETRY_INTERVAL_MS as Lang.Number = 30000;
    private static const OVERDUE_POLL_MS as Lang.Number = 60000;

    private var glucose as GlucoseData;
    private var baseLabel as Lang.String;
    private var fitField as FitContributor.Field?;

    private var requestInFlight as Lang.Boolean = false;
    private var lastAttemptMs as Lang.Number = -1;
    private var lastFailed as Lang.Boolean = false;

    function initialize() {
        SimpleDataField.initialize();
        glucose = new GlucoseData();
        baseLabel = WatchUi.loadResource(Rez.Strings.field_label) as Lang.String;
        label = baseLabel;
        // Developer field 0 (see resources/fitfields.xml): glucose in mg/dL, per record
        try {
            fitField = createField("glucose", 0, FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "mg/dL" });
        } catch (ex) {
            fitField = null;
        }
    }

    //! Called about once a second during the activity.
    function compute(info as Activity.Info) as Lang.Numeric or Time.Duration or Lang.String or Null {
        if (getNightscoutUrl().length() == 0 || getToken().length() == 0) {
            label = baseLabel;
            return WatchUi.loadResource(Rez.Strings.field_setup) as Lang.String;
        }

        var now = System.getTimer();
        if (isFetchDue(now)) {
            fetch(now);
        }

        var age = glucose.getAgeSeconds();
        if (glucose.bloodSugarLevel <= 0 || age < 0) {
            label = baseLabel;
            return "--";
        }
        label = baseLabel + " " + ageText(age);
        // An old value must never look current, on screen or in the FIT file
        if (GlucoseData.isStaleAge(age)) {
            return "--";
        }
        if (fitField != null) {
            fitField.setData(glucose.bloodSugarLevel);
        }
        return Units.format(glucose.bloodSugarLevel) + " " + glucose.getDirectionArrow();
    }

    //! Called by the app when the user changes the settings in Garmin Connect.
    function refreshNow() as Void {
        lastAttemptMs = -1;
        lastFailed = false;
    }

    private function ageText(ageSec as Lang.Number) as Lang.String {
        if (ageSec < 60) {
            return "<1m";
        }
        if (ageSec < 7200) {
            return (ageSec / 60) + "m";
        }
        return (ageSec / 3600) + "h";
    }

    //! Same scheduling idea as the widget: retry soon after a failure, poll every
    //! minute once the next reading is overdue, otherwise stay quiet.
    private function isFetchDue(nowMs as Lang.Number) as Lang.Boolean {
        if (requestInFlight) {
            if (nowMs - lastAttemptMs < REQUEST_TIMEOUT_MS) {
                return false;
            }
            requestInFlight = false;   // lost callback: give up on it
            lastFailed = true;
        }
        if (lastAttemptMs < 0) {
            return true;
        }
        var elapsed = nowMs - lastAttemptMs;
        if (lastFailed) {
            return elapsed >= RETRY_INTERVAL_MS;
        }
        var age = glucose.getAgeSeconds();
        if (age < 0) {
            return elapsed >= RETRY_INTERVAL_MS;
        }
        if (age >= Constants.GLUCOSE_EXPECTED_SEC) {
            return elapsed >= OVERDUE_POLL_MS;
        }
        return false;
    }

    private function fetch(nowMs as Lang.Number) as Void {
        requestInFlight = true;
        lastAttemptMs = nowMs;
        // One entry only: the answer stays tiny (the data field has 128 KB in all)
        Communications.makeWebRequest(
            getNightscoutUrl() + "/api/v1/entries.json?count=1&token=" + getToken(),
            {},
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED }
            },
            method(:onReceive)
        );
    }

    function onReceive(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        requestInFlight = false;
        if (responseCode == 200 && EntriesParser.parse(data, glucose)) {
            lastFailed = false;
        } else {
            // Keep the last value: it simply ages (greyed out as "--" after 15 min)
            lastFailed = true;
        }
    }

    private function getNightscoutUrl() as Lang.String {
        var url = Application.Properties.getValue("nightscout_url");
        return url instanceof Lang.String ? url : "";
    }

    private function getToken() as Lang.String {
        var token = Application.Properties.getValue("nightscout_token");
        return token instanceof Lang.String ? token : "";
    }
}
