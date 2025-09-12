import Toybox.Lang;
import Toybox.Time;

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
        lastUpdateTime = Time.now();
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
        
        var now = Time.now();
        var duration = now.subtract(lastUpdateTime);
        var seconds = duration.value();
        
        if (seconds < 60) {
            return seconds + "s";
        } else {
            var minutes = seconds / 60;
            return minutes + "m";
        }
    }
}