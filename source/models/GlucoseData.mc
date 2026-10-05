import Toybox.Lang;
import Toybox.Time;
import Toybox.Graphics;

//! Model for glucose data from Nightscout
(:glance, :background)
class GlucoseData {
    
    public var bloodSugarLevel as Lang.Number = 0;
    public var trendRate as Lang.Float = 0.0;
    public var direction as Lang.String = "Flat";
    public var lastUpdateTime as Time.Moment?;

    function initialize() {
    }

    //! Update glucose data from Nightscout response
    function update(data as Lang.Dictionary) as Void {
        if (data.hasKey("bloodSugar")) {
            var bloodSugar = data.get("bloodSugar");
            if (bloodSugar != null && bloodSugar instanceof Lang.Number) {
                bloodSugarLevel = bloodSugar;
            }
        }
        if (data.hasKey("trendRate")) {
            var trendRateValue = data.get("trendRate");
            if (trendRateValue != null && trendRateValue instanceof Lang.Float) {
                trendRate = trendRateValue;
            }
        }
        if (data.hasKey("direction")) {
            var directionValue = data.get("direction");
            if (directionValue != null && directionValue instanceof Lang.String) {
                direction = directionValue;
            }
        }
        // Prefer the CGM reading's own timestamp so the age shown is the age of
        // the data, not of the last successful download.
        var readingTime = data.hasKey("readingTime") ? data.get("readingTime") : null;
        if (readingTime instanceof Lang.Number && readingTime > 0) {
            lastUpdateTime = new Time.Moment(readingTime);
        } else {
            lastUpdateTime = Time.now();
        }
    }

    //! Age of the reading in seconds, or -1 when no reading has been received.
    function getAgeSeconds() as Lang.Number {
        if (lastUpdateTime == null) {
            return -1;
        }
        var age = Time.now().subtract(lastUpdateTime).value();
        return age < 0 ? 0 : age;
    }

    //! True when the reading is too old to be trusted at a glance.
    function isStale() as Lang.Boolean {
        return isStaleAge(getAgeSeconds());
    }

    static function isStaleAge(ageSec as Lang.Number) as Lang.Boolean {
        return ageSec >= Constants.GLUCOSE_STALE_SEC;
    }

    //! Get direction arrow for display
    function getDirectionArrow() as Lang.String {
        if (direction.equals("DoubleUp")) {
            return "↑↑";
        } else if (direction.equals("SingleUp")) {
            return "↑";
        } else if (direction.equals("FortyFiveUp")) {
            return "↗";
        } else if (direction.equals("Flat")) {
            return "→";
        } else if (direction.equals("FortyFiveDown")) {
            return "↘";
        } else if (direction.equals("SingleDown")) {
            return "↓";
        } else if (direction.equals("DoubleDown")) {
            return "↓↓";
        }
        return "→";
    }

    //! Get time since last update as formatted string
    function getTimeSinceUpdate() as Lang.String {
        if (lastUpdateTime == null) {
            return "---";
        }
        
        var seconds = getAgeSeconds();
        
        if (seconds < 60) {
            return seconds + "s";
        } else if (seconds < 7200) {
            return (seconds / 60) + "m";
        }
        return (seconds / 3600) + "h";
    }

    //! Get trend label (STABLE / RISING / FALLING) derived from the CGM direction
    function getTrendLabel() as Lang.String {
        if (direction.equals("SingleUp") || direction.equals("FortyFiveUp") || direction.equals("DoubleUp")) {
            return "RISING";
        } else if (direction.equals("SingleDown") || direction.equals("FortyFiveDown") || direction.equals("DoubleDown")) {
            return "FALLING";
        }
        return "STABLE";
    }

    //! Get the zone color for a given glucose value: green in target range,
    //! orange slightly out of range, red far out of range.
    static function getZoneColor(value as Lang.Number) as Graphics.ColorType {
        if (value <= 0) {
            return Graphics.COLOR_DK_GRAY;
        }
        if (value >= Constants.GLUCOSE_TARGET_LOW && value <= Constants.GLUCOSE_TARGET_HIGH) {
            return Graphics.COLOR_GREEN;
        }
        if (value >= Constants.GLUCOSE_NEAR_LOW && value <= Constants.GLUCOSE_NEAR_HIGH) {
            return Graphics.COLOR_ORANGE;
        }
        return Graphics.COLOR_RED;
    }

    //! Get the zone color for the current blood sugar level
    function getCurrentZoneColor() as Graphics.ColorType {
        return getZoneColor(bloodSugarLevel);
    }
}