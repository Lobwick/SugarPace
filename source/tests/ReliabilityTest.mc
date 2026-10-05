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

(:test)
function testRecommendedBolusAge(logger as Test.Logger) as Boolean {
    var s = new AppState();
    Test.assertEqualMessage(s.getRecommendedBolusAgeSeconds(), -1, "no bolus -> -1 (hidden)");

    // Just computed
    s.updateRecommendedBolus(1.65, new OtpService().formatCurrentTimestamp());
    var fresh = s.getRecommendedBolusAgeSeconds();
    Test.assertMessage(fresh >= 0 && fresh < 5, "fresh bolus age ~0, got " + fresh);

    // Old
    s.updateRecommendedBolus(1.65, "2025-05-22T12:30:19Z");
    Test.assertMessage(s.getRecommendedBolusAgeSeconds() >= Constants.GLUCOSE_STALE_SEC, "old bolus is stale");

    // Unreadable time -> hidden, never shown as current
    s.updateRecommendedBolus(1.65, "garbage");
    Test.assertEqualMessage(s.getRecommendedBolusAgeSeconds(), -1, "bad time -> -1");
    return true;
}

//! ---- Remote bolus: pure logic only. sendBolusEntry is NEVER called here. ----

(:test)
function testBolusRounding(logger as Test.Logger) as Boolean {
    Test.assertMessage((Units.roundBolus(0.1) - 0.1).abs() < 0.001, "0.1 stays 0.1");
    Test.assertMessage((Units.roundBolus(1.63) - 1.65).abs() < 0.001, "1.63 -> 1.65 (0.05 steps)");
    Test.assertMessage((Units.roundBolus(1.62) - 1.6).abs() < 0.001, "1.62 -> 1.60");
    Test.assertEqualMessage(Units.formatBolus(1.65), "1.65", "formatted with 2 decimals");
    return true;
}

(:test)
function testCanSendBolusRules(logger as Test.Logger) as Boolean {
    var now = new OtpService().formatCurrentTimestamp();
    var s = new AppState();
    Test.assertMessage(!s.canSendBolus(), "nothing received -> no");

    s.updateRecommendedBolus(1.65, now);
    Test.assertMessage(s.canSendBolus(), "fresh, in range -> yes");

    s.updateRecommendedBolus(0.0, now);
    Test.assertMessage(!s.canSendBolus(), "zero -> no");
    s.updateRecommendedBolus(Constants.BOLUS_MAX_UNITS + 1.0, now);
    Test.assertMessage(!s.canSendBolus(), "above the cap -> no");

    s.updateRecommendedBolus(1.0, "2025-05-22T12:30:19Z");
    Test.assertMessage(!s.canSendBolus(), "old recommendation -> no");
    s.updateRecommendedBolus(1.0, "garbage");
    Test.assertMessage(!s.canSendBolus(), "unreadable time -> no");

    s.updateRecommendedBolus(1.0, now);
    s.setRecommendedBolusError(500);
    Test.assertMessage(!s.canSendBolus(), "last fetch failed -> no");
    return true;
}

(:test)
function testBolusConfirmNeedsSameAmountInWindow(logger as Test.Logger) as Boolean {
    var now = new OtpService().formatCurrentTimestamp();
    var s = new AppState();
    s.updateRecommendedBolus(1.65, now);

    Test.assertMessage(!s.isBolusConfirmArmed(1000), "not armed before the first tap");
    s.armBolusConfirm(1000);
    Test.assertMessage(s.isBolusConfirmArmed(1000 + 1000), "armed inside the window");
    Test.assertMessage(!s.isBolusConfirmArmed(1000 + Constants.BOLUS_CONFIRM_MS + 1), "expired after the window");

    // The amount changes between the two taps: must NOT count as confirmed
    s.armBolusConfirm(1000);
    s.updateRecommendedBolus(2.0, now);
    Test.assertMessage(!s.isBolusConfirmArmed(1500), "different amount -> not confirmed");
    return true;
}

(:test)
function testBolusLockAndDuplicateGuard(logger as Test.Logger) as Boolean {
    var now = new OtpService().formatCurrentTimestamp();
    var s = new AppState();
    s.updateRecommendedBolus(1.65, now);

    s.bolusSentForTime = now;
    Test.assertMessage(!s.canSendBolus(), "same recommendation can't be sent twice");
    s.bolusSentForTime = "2025-05-22T12:30:19Z";
    Test.assertMessage(s.canSendBolus(), "a different recommendation can be sent");

    s.setBolusSendState(Constants.SEND_PENDING, 0);
    var t0 = s.bolusSendChangedMs;
    Test.assertMessage(s.isBolusLocked(t0 + 1000), "pending -> locked");
    s.setBolusSendState(Constants.SEND_OK, 200);
    t0 = s.bolusSendChangedMs;
    Test.assertMessage(s.isBolusLocked(t0 + 1000), "just sent -> locked");
    Test.assertMessage(!s.isBolusLocked(t0 + Constants.BOLUS_HOLD_OK_MS), "lock released later");

    // Failures release the duplicate guard (a retry is the rider's choice), but
    // ambiguous ones (timeout, transport, 5xx) put the retry behind a
    // revalidation + "check Loop" warning (see testBolusRetryNeedsRevalidation).
    s.bolusSentForTime = "x";
    s.setBolusSendState(Constants.SEND_UNCONFIRMED, -1);
    Test.assertEqualMessage(s.bolusSentForTime, "", "unconfirmed releases the guard");
    Test.assertMessage(s.bolusRetryWarning, "...but warns to check Loop");
    s.bolusSentForTime = "x";
    s.setBolusSendState(Constants.SEND_FAILED, 401);
    Test.assertEqualMessage(s.bolusSentForTime, "", "bad token -> nothing was sent, free retry");
    Test.assertMessage(!s.bolusRetryWarning, "no warning when nothing could have been sent");
    s.clearBolusSentGuard();
    return true;
}

(:test)
function testBolusGuardSurvivesRestart(logger as Test.Logger) as Boolean {
    var first = new AppState();
    first.markBolusSent("2026-10-05T20:49:09Z");
    var second = new AppState();   // a new app start
    Test.assertEqualMessage(second.bolusSentForTime, "", "constructor does not read storage");
    second.restoreBolusGuard();
    Test.assertEqualMessage(second.bolusSentForTime, "2026-10-05T20:49:09Z", "guard restored");
    second.clearBolusSentGuard();  // leave no trace
    var third = new AppState();
    third.restoreBolusGuard();
    Test.assertEqualMessage(third.bolusSentForTime, "", "cleared guard stays cleared");
    return true;
}

(:test)
function testBolusFutureTimestampRejected(logger as Test.Logger) as Boolean {
    var s = new AppState();
    s.updateRecommendedBolus(1.0, "2099-01-01T00:00:00Z");
    Test.assertEqualMessage(s.getRecommendedBolusAgeSeconds(), -1, "far future time -> unreadable");
    Test.assertMessage(!s.canSendBolus(), "future recommendation can't be sent");
    return true;
}

(:test)
function testBolusPayloadShape(logger as Test.Logger) as Boolean {
    var data = new OtpService().createBolusEntryData(1.63);
    Test.assertEqualMessage(data.get("eventType"), "Remote Bolus Entry", "event type");
    var amount = data.get("remoteBolus");
    Test.assertMessage(amount instanceof Lang.Float, "remoteBolus is a Float, flat in the body");
    var amountF = amount as Lang.Float;
    Test.assertMessage((amountF - 1.65).abs() < 0.001, "rounded to the pump increment");
    Test.assertEqualMessage((data.get("otp") as Lang.String).length(), 6, "6-digit OTP");
    Test.assertMessage(data.hasKey("created_at"), "timestamp present");
    Test.assertMessage(data.hasKey("enteredBy"), "enteredBy present");
    return true;
}

(:test)
function testBolusRetryNeedsRevalidation(logger as Test.Logger) as Boolean {
    var now = new OtpService().formatCurrentTimestamp();
    var s = new AppState();
    s.updateRecommendedBolus(1.65, now);

    // Ambiguous failure: retry allowed only after a recommendation fetched >= wait later
    s.setBolusSendState(Constants.SEND_FAILED, 500);
    Test.assertMessage(s.bolusRetryWarning, "rider is told to check Loop");
    var failedAt = s.bolusAwaitFreshAfterMs;
    s.recommendedBolusFetchedMs = failedAt + Constants.BOLUS_RETRY_MIN_WAIT_MS - 1;
    Test.assertMessage(!s.canSendBolus(), "too early after the failure -> blocked");
    Test.assertMessage(!s.bolusNeedsRevalidationFetch(failedAt + 1000), "no fetch before the wait is over");
    Test.assertMessage(s.bolusNeedsRevalidationFetch(failedAt + Constants.BOLUS_RETRY_MIN_WAIT_MS), "fetch due once the wait is over");
    s.recommendedBolusFetchedMs = failedAt + Constants.BOLUS_RETRY_MIN_WAIT_MS;
    Test.assertMessage(s.canSendBolus(), "revalidated -> retry possible");

    // Success clears the waiting state
    s.setBolusSendState(Constants.SEND_OK, 200);
    Test.assertMessage(!s.bolusRetryWarning, "success clears the warning");

    // A refusal before Loop could act needs no revalidation
    s.setBolusSendState(Constants.SEND_FAILED, 401);
    Test.assertMessage(!s.bolusRetryWarning && s.bolusAwaitFreshAfterMs < 0, "auth refusal: free retry");
    return true;
}

(:test)
function testSendBlockedWhileLateCallbackPossible(logger as Test.Logger) as Boolean {
    var svc = new NightscoutService(new AppState());
    Test.assertMessage(!svc.isSendBlockedByDoubt(1000), "nothing abandoned -> not blocked");
    svc.noteAbandonedRequest(1000);
    Test.assertMessage(svc.isSendBlockedByDoubt(1000 + 1000), "just abandoned -> blocked");
    Test.assertMessage(!svc.isSendBlockedByDoubt(1000 + Constants.ABANDON_GRACE_MS), "blocked only for the grace period");
    Test.assertEqualMessage(ErrorText.kind(Constants.QUEUE_BUSY_CODE), ErrorText.KIND_BUSY, "busy code classified");
    return true;
}
