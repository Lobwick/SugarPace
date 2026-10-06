import Toybox.Lang;
import Toybox.WatchUi;

//! Maps an HTTP / Garmin web-request error code to a short, actionable message
//! for the rider. Short form fits on a food tile, long form on the profile screen.
module ErrorText {
    const KIND_OTHER = 0;
    const KIND_AUTH = 1;     // 401 / 403: token rejected
    const KIND_SERVER = 2;   // 5xx: Nightscout up but misconfigured (e.g. Loop APNs keys)
    const KIND_NETWORK = 3;  // negative Garmin codes: no phone / BLE / timeout
    const KIND_CONFIG = 4;   // URL / token / OTP secret not filled in
    const KIND_BUSY = 5;     // recent abandoned request: retry in a minute (nothing sent)
    const KIND_STORAGE = 6;  // the safety guard could not be saved (nothing sent)

    function kind(code as Lang.Number) as Lang.Number {
        if (code == Constants.NOT_CONFIGURED_CODE) {
            return KIND_CONFIG;
        }
        if (code == Constants.QUEUE_BUSY_CODE) {
            return KIND_BUSY;
        }
        if (code == Constants.GUARD_FAILED_CODE) {
            return KIND_STORAGE;
        }
        if (code == 401 || code == 403) {
            return KIND_AUTH;
        }
        if (code >= 500 && code < 600) {
            return KIND_SERVER;
        }
        if (code < 0) {
            return KIND_NETWORK;
        }
        return KIND_OTHER;
    }

    //! A few words, for a food tile.
    function shortText(code as Lang.Number) as Lang.String {
        var k = kind(code);
        if (k == KIND_STORAGE) {
            return WatchUi.loadResource(Rez.Strings.err_guard_short) as Lang.String;
        }
        if (k == KIND_BUSY) {
            return WatchUi.loadResource(Rez.Strings.err_busy_short) as Lang.String;
        }
        if (k == KIND_CONFIG) {
            return WatchUi.loadResource(Rez.Strings.err_config_short) as Lang.String;
        }
        if (k == KIND_AUTH) {
            return WatchUi.loadResource(Rez.Strings.err_auth_short) as Lang.String;
        }
        if (k == KIND_SERVER) {
            return WatchUi.loadResource(Rez.Strings.err_server_short) as Lang.String;
        }
        if (k == KIND_NETWORK) {
            return WatchUi.loadResource(Rez.Strings.err_network_short) as Lang.String;
        }
        var failed = WatchUi.loadResource(Rez.Strings.send_failed) as Lang.String;
        return Lang.format("$1$ $2$", [failed, code]);
    }

    //! One line telling what to do, for the profile screen.
    function longText(code as Lang.Number) as Lang.String {
        var k = kind(code);
        if (k == KIND_STORAGE) {
            return WatchUi.loadResource(Rez.Strings.err_guard_long) as Lang.String;
        }
        if (k == KIND_BUSY) {
            return WatchUi.loadResource(Rez.Strings.err_busy_long) as Lang.String;
        }
        if (k == KIND_CONFIG) {
            return WatchUi.loadResource(Rez.Strings.err_config_long) as Lang.String;
        }
        if (k == KIND_AUTH) {
            return WatchUi.loadResource(Rez.Strings.err_auth_long) as Lang.String;
        }
        if (k == KIND_SERVER) {
            return WatchUi.loadResource(Rez.Strings.err_server_long) as Lang.String;
        }
        if (k == KIND_NETWORK) {
            return WatchUi.loadResource(Rez.Strings.err_network_long) as Lang.String;
        }
        var failed = WatchUi.loadResource(Rez.Strings.send_failed) as Lang.String;
        return Lang.format("$1$ $2$", [failed, code]);
    }
}
