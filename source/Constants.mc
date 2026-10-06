module Constants {
    const TIME_STEP_SEC = 30;
    const DEFAULT_OVERRIDE_PROFIL = "Default";

    // Glucose zone thresholds (mg/dl) used to color-code the trend badge
    // and history chart bars: green when inside target range, orange when
    // slightly out of range, red when far out of range.
    const GLUCOSE_TARGET_LOW = 70;
    const GLUCOSE_TARGET_HIGH = 180;
    const GLUCOSE_NEAR_LOW = 55;
    const GLUCOSE_NEAR_HIGH = 250;
    //TODO les déplacer dans les properties de l'application

    // mg/dL per mmol/L (Nightscout always stores mg/dL; mmol/L is display-only)
    const MGDL_PER_MMOL = 18.0182;

    // Data freshness (seconds since the CGM reading was taken).
    const GLUCOSE_EXPECTED_SEC = 290;  // next reading is due: poll faster
    const GLUCOSE_WARN_SEC = 600;      // 10 min: freshness label turns orange
    const GLUCOSE_STALE_SEC = 900;     // 15 min: label red, value no longer color-coded

    // Fake HTTP code reported to a responder when the request watchdog expires
    const REQUEST_TIMEOUT_CODE = -1;
    // Fake code: a request was abandoned recently and may still answer late; an
    // irreversible send is refused until the grace period is over (nothing sent).
    const QUEUE_BUSY_CODE = -3;
    // Fake code: the duplicate-send guard could not be saved, so nothing was sent.
    const GUARD_FAILED_CODE = -4;
    const ABANDON_GRACE_MS = 60000;
    // Fake code when URL / token / OTP secret are not filled in (nothing is sent)
    const NOT_CONFIGURED_CODE = -2;

    // Food send state machine (see AppState.setSendState)
    const SEND_IDLE = 0;
    const SEND_PENDING = 1;      // request issued, no answer yet: taps are ignored
    const SEND_OK = 2;           // server accepted: tile green, taps locked briefly
    const SEND_FAILED = 3;       // server/network error: tile red, retry allowed
    const SEND_UNCONFIRMED = 4;  // no answer in time: may or may not have gone through

    // Remote bolus (sending Loop's recommendation). Deliberately strict.
    const BOLUS_MAX_AGE_SEC = 600;    // recommendation older than 10 min can't be sent
    const BOLUS_MIN_UNITS = 0.05;     // below this nothing is sent
    const BOLUS_MAX_UNITS = 5.0;      // above this the button stays disabled (Loop's own max bolus still applies)
    const BOLUS_MAX_FUTURE_SKEW_SEC = 60; // a recommendation "from the future" beyond this is rejected
    // After an ambiguous failure a retry is possible only once a recommendation
    // fetched at least this many seconds after the failure is available (time to
    // look at Loop). Wall-clock seconds, so it survives an app restart.
    const BOLUS_RETRY_MIN_WAIT_SEC = 15;
    // A bolus request still queued (not dispatched) after this long is cancelled:
    // it must never be delivered after the rider was told it did not go.
    const BOLUS_QUEUE_WAIT_MS = 10000;
    const BOLUS_CONFIRM_MS = 5000;    // second tap must come within this window
    const BOLUS_HOLD_OK_MS = 15000;   // "sent" stays shown (and locked) this long
    const BOLUS_HOLD_FAIL_MS = 6000;

    const SEND_TIMEOUT_MS = 30000;  // give up waiting for an answer
    const SEND_HOLD_OK_MS = 2500;   // how long the success state is shown / taps locked
    const SEND_HOLD_FAIL_MS = 5000; // how long a failure is shown
}