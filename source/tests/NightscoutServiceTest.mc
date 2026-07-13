import Toybox.Lang;
using Toybox.Test;

//! Unit tests for NightscoutService RESPONSE PARSING only.
//!
//! SAFETY: these tests call ONLY the onReceive* parse handlers with canned data.
//! They never call fetch*/send*/activate*/deactivate* — those issue real web
//! requests and would push carbs/overrides to the live Loop. The parse handlers
//! make no network calls; they just interpret a response and update state.

//! Captures callback invocations instead of hitting the network.
class CaptureCallback {
    public var captured as Lang.Dictionary = {};
    function onCallback(type as Lang.String, data as Lang.Object) as Void {
        captured.put(type, data);
    }
}

//! Glucose response: current value from the newest entry + chronological history.
(:test)
function testParseGlucose(logger as Test.Logger) as Boolean {
    var svc = new NightscoutService(new AppState());
    var cap = new CaptureCallback();
    svc.setCallback(cap.method(:onCallback));

    // Nightscout returns newest-first.
    var entries = [
        { "sgv" => 120, "direction" => "Flat", "trendRate" => 0.5 },
        { "sgv" => 118 },
        { "sgv" => 115 }
    ];
    svc.onReceiveGlucoseData(200, entries as Lang.Dictionary);

    var glucose = cap.captured.get("glucose") as Lang.Dictionary;
    Test.assertEqualMessage(glucose.get("bloodSugar"), 120, "current value = newest entry");
    Test.assertEqualMessage(glucose.get("direction"), "Flat", "direction parsed");

    var history = cap.captured.get("glucoseHistory") as Lang.Array;
    Test.assertEqualMessage(history.size(), 3, "history length");
    Test.assertEqualMessage(history[0], 115, "history is oldest-first");
    Test.assertEqualMessage(history[2], 120, "history ends at newest");
    return true;
}

//! Profile response -> list of override presets (does NOT set active profile).
(:test)
function testParseOverridePresets(logger as Test.Logger) as Boolean {
    var appState = new AppState();
    var svc = new NightscoutService(appState);

    var profileResp = [
        { "loopSettings" => { "overridePresets" => [ { "name" => "sport" }, { "name" => "stop" } ] } }
    ];
    svc.onReceiveTempBasalData(200, profileResp as Lang.Dictionary);

    Test.assertEqualMessage(appState.overridePresets.size(), 2, "two presets parsed");
    var first = appState.overridePresets[0] as Lang.Dictionary;
    Test.assertEqualMessage(first.get("name"), "sport", "preset name kept");
    return true;
}

//! Active override: an indefinite override wins; otherwise fall back to Default.
(:test)
function testParseActiveOverride(logger as Test.Logger) as Boolean {
    var appState = new AppState();
    var svc = new NightscoutService(appState);

    var active = [ { "reason" => "sport", "durationType" => "indefinite" } ];
    svc.onReceiveActiveOverride(200, active as Lang.Dictionary);
    Test.assertEqualMessage(appState.activeProfile, "sport", "indefinite override is active");

    // An override with a numeric duration has expired -> no active -> Default.
    var expired = [ { "reason" => "old", "duration" => 30, "durationType" => "timed" } ];
    svc.onReceiveActiveOverride(200, expired as Lang.Dictionary);
    Test.assertEqualMessage(appState.activeProfile, Constants.DEFAULT_OVERRIDE_PROFIL, "expired -> Default");
    return true;
}

//! Non-200 / null responses degrade gracefully, never throw.
(:test)
function testParseErrorResilience(logger as Test.Logger) as Boolean {
    var appState = new AppState();
    var svc = new NightscoutService(appState);

    svc.onReceiveTempBasalData(500, null);
    Test.assertEqualMessage(appState.overridePresets.size(), 0, "failed profile fetch -> empty presets");

    svc.onReceiveActiveOverride(500, null);
    Test.assertEqualMessage(appState.activeProfile, Constants.DEFAULT_OVERRIDE_PROFIL, "failed override fetch -> Default");
    return true;
}
