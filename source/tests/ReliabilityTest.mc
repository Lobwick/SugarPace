import Toybox.Lang;
import Toybox.Time;
using Toybox.Test;

//! Unit conversion, data freshness, fetch scheduling and the food-send lock.
//! Pure logic only: no network call is made (see the safety rule in CLAUDE.md).

(:test)
function testUnitsFormat(logger as Test.Logger) as Boolean {
    Test.assertEqualMessage(Units.formatAs(120, false), "120", "mg/dL is shown as-is");
    Test.assertEqualMessage(Units.formatAs(180, true), "10.0", "180 mg/dL = 10.0 mmol/L");
    Test.assertEqualMessage(Units.formatAs(100, true), "5.5", "100 mg/dL = 5.5 mmol/L");
    Test.assertEqualMessage(Units.formatAs(54, true), "3.0", "54 mg/dL = 3.0 mmol/L");
    return true;
}

(:test)
function testReadingTimeDrivesAge(logger as Test.Logger) as Boolean {
    var g = new GlucoseData();
    Test.assertEqualMessage(g.getAgeSeconds(), -1, "no reading -> age -1");

    g.update({ "bloodSugar" => 110, "readingTime" => Time.now().value() - 120 });
    var age = g.getAgeSeconds();
    Test.assertMessage(age >= 119 && age <= 125, "age comes from the reading time, got " + age);
    Test.assertMessage(!g.isStale(), "2 min old is not stale");

    g.update({ "bloodSugar" => 110, "readingTime" => Time.now().value() - 1000 });
    Test.assertMessage(g.isStale(), "1000 s old is stale");

    g.update({ "bloodSugar" => 110 });
    Test.assertMessage(g.getAgeSeconds() < 5, "no readingTime -> age counted from receipt");
    return true;
}

(:test)
function testStaleAgeBoundaryAndFutureTimestamp(logger as Test.Logger) as Boolean {
    var threshold = Constants.GLUCOSE_STALE_SEC;
    Test.assertMessage(!GlucoseData.isStaleAge(threshold - 1), "one second before threshold is fresh");
    Test.assertMessage(GlucoseData.isStaleAge(threshold), "threshold is stale");
    Test.assertMessage(GlucoseData.isStaleAge(threshold + 1), "one second after threshold is stale");

    var g = new GlucoseData();
    g.update({ "bloodSugar" => 110, "readingTime" => Time.now().value() + 60 });
    Test.assertEqualMessage(g.getAgeSeconds(), 0, "future CGM timestamp clamps age to zero");
    Test.assertMessage(!g.isStale(), "future CGM timestamp is not stale");
    return true;
}

(:test)
function testFetchScheduling(logger as Test.Logger) as Boolean {
    var s = new AppState();
    Test.assertMessage(s.isFetchDue(1000), "never fetched -> due");

    s.lastFetchAttemptMs = 1000;
    s.glucoseFetchFailed = true;
    Test.assertMessage(!s.isFetchDue(1000 + Layout.RETRY_INTERVAL_MS - 1), "failed: too early to retry");
    Test.assertMessage(s.isFetchDue(1000 + Layout.RETRY_INTERVAL_MS), "failed: retry after the interval");

    s.glucoseFetchFailed = false;
    s.glucoseData.update({ "bloodSugar" => 100, "readingTime" => Time.now().value() - 60 });
    Test.assertMessage(!s.isFetchDue(1000 + 120000), "fresh reading: no fetch yet");

    s.glucoseData.update({ "bloodSugar" => 100, "readingTime" => Time.now().value() - 320 });
    Test.assertMessage(!s.isFetchDue(1000 + Layout.STALE_POLL_INTERVAL_MS - 1), "overdue: but polled at most once a minute");
    Test.assertMessage(s.isFetchDue(1000 + Layout.STALE_POLL_INTERVAL_MS), "overdue: poll after the interval");
    return true;
}

(:test)
function testSendLockBlocksDoubleTap(logger as Test.Logger) as Boolean {
    var s = new AppState();
    Test.assertMessage(!s.isSendLockedAt(0), "idle -> not locked");

    s.setSendState(Constants.SEND_PENDING, 0);
    var t0 = s.sendStateChangedMs;
    Test.assertMessage(s.isSendLockedAt(t0 + 1000), "pending -> locked");
    Test.assertMessage(!s.isSendLockedAt(t0 + Constants.SEND_TIMEOUT_MS), "pending lock self-expires");

    s.setSendState(Constants.SEND_OK, 200);
    t0 = s.sendStateChangedMs;
    Test.assertMessage(s.isSendLockedAt(t0 + 500), "just sent -> locked");
    Test.assertMessage(!s.isSendLockedAt(t0 + Constants.SEND_HOLD_OK_MS), "success lock released");

    s.setSendState(Constants.SEND_FAILED, 401);
    Test.assertMessage(!s.isSendLockedAt(s.sendStateChangedMs), "failed -> retry allowed");
    return true;
}

(:test)
function testGlucoseFailureFlagsStale(logger as Test.Logger) as Boolean {
    var appState = new AppState();
    var svc = new NightscoutService(appState);
    svc.onReceiveGlucoseData(-104, null);
    Test.assertMessage(appState.glucoseFetchFailed, "failed fetch is flagged");
    svc.onReceiveGlucoseData(200, [ { "sgv" => 100 } ] as Lang.Dictionary);
    Test.assertMessage(!appState.glucoseFetchFailed, "success clears the flag");
    return true;
}

(:test)
function testErrorKinds(logger as Test.Logger) as Boolean {
    Test.assertEqualMessage(ErrorText.kind(401), ErrorText.KIND_AUTH, "401 = token");
    Test.assertEqualMessage(ErrorText.kind(403), ErrorText.KIND_AUTH, "403 = token");
    Test.assertEqualMessage(ErrorText.kind(500), ErrorText.KIND_SERVER, "500 = server config");
    Test.assertEqualMessage(ErrorText.kind(502), ErrorText.KIND_SERVER, "5xx = server");
    Test.assertEqualMessage(ErrorText.kind(-104), ErrorText.KIND_NETWORK, "negative = no link");
    Test.assertEqualMessage(ErrorText.kind(404), ErrorText.KIND_OTHER, "other codes keep the raw code");
    return true;
}

(:test)
function testNotConfiguredKind(logger as Test.Logger) as Boolean {
    Test.assertEqualMessage(ErrorText.kind(Constants.NOT_CONFIGURED_CODE), ErrorText.KIND_CONFIG, "-2 = not configured");
    return true;
}
