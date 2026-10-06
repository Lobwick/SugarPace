import Toybox.Lang;

//! Reads the Nightscout entries response:
//!   [ { "sgv": 112, "direction": "Flat", "date": 1791234567890, ... } ]   (newest first)
//! Pure parsing, no request: safe to unit-test.
module EntriesParser {

    //! Updates `glucose` from the newest entry. Returns true on success; on any
    //! unexpected shape it returns false and leaves `glucose` untouched, so a bad
    //! answer can never produce a made-up value.
    function parse(data as Lang.Object?, glucose as GlucoseData) as Lang.Boolean {
        if (!(data instanceof Lang.Array) || data.size() == 0) {
            return false;
        }
        var entry = data[0];
        if (!(entry instanceof Lang.Dictionary)) {
            return false;
        }
        var sgv = entry.get("sgv");
        if (!(sgv instanceof Lang.Number) || sgv <= 0) {
            return false;
        }
        var update = { "bloodSugar" => sgv };
        var direction = entry.get("direction");
        if (direction instanceof Lang.String) {
            update.put("direction", direction);
        }
        // "date" is the reading time in epoch milliseconds (a Long): use it so the
        // age shown is the age of the sensor reading, not of the download.
        var dateMs = entry.get("date");
        if (dateMs instanceof Lang.Number || dateMs instanceof Lang.Long) {
            update.put("readingTime", (dateMs / 1000).toNumber());
        }
        glucose.update(update);
        return true;
    }
}
