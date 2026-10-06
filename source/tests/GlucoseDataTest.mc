import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
using Toybox.Test;

//! Unit tests for GlucoseData: zone coloring thresholds, trend arrows and labels.

//! Zone color thresholds (target 70-180, near 55-250, else out of range).
(:test)
function testZoneColorRanges(logger as Test.Logger) as Boolean {
    // In target range -> green (inclusive bounds)
    Test.assertEqualMessage(GlucoseData.getZoneColor(100), Graphics.COLOR_GREEN, "100 in target");
    Test.assertEqualMessage(GlucoseData.getZoneColor(70), Graphics.COLOR_GREEN, "70 lower target bound");
    Test.assertEqualMessage(GlucoseData.getZoneColor(180), Graphics.COLOR_GREEN, "180 upper target bound");

    // Near range -> orange
    Test.assertEqualMessage(GlucoseData.getZoneColor(60), Graphics.COLOR_ORANGE, "60 near-low");
    Test.assertEqualMessage(GlucoseData.getZoneColor(200), Graphics.COLOR_ORANGE, "200 near-high");
    Test.assertEqualMessage(GlucoseData.getZoneColor(55), Graphics.COLOR_ORANGE, "55 near-low bound");
    Test.assertEqualMessage(GlucoseData.getZoneColor(250), Graphics.COLOR_ORANGE, "250 near-high bound");

    // Out of range -> red
    Test.assertEqualMessage(GlucoseData.getZoneColor(54), Graphics.COLOR_RED, "54 below near");
    Test.assertEqualMessage(GlucoseData.getZoneColor(251), Graphics.COLOR_RED, "251 above near");
    Test.assertEqualMessage(GlucoseData.getZoneColor(300), Graphics.COLOR_RED, "300 far high");

    // No data -> dark gray
    Test.assertEqualMessage(GlucoseData.getZoneColor(0), Graphics.COLOR_DK_GRAY, "0 = no data");
    Test.assertEqualMessage(GlucoseData.getZoneColor(-5), Graphics.COLOR_DK_GRAY, "negative = no data");
    return true;
}

//! Direction string -> arrow glyph mapping.
(:test)
function testDirectionArrow(logger as Test.Logger) as Boolean {
    var g = new GlucoseData();
    g.direction = "Flat";          Test.assertEqualMessage(g.getDirectionArrow(), "→", "Flat");
    g.direction = "DoubleUp";      Test.assertEqualMessage(g.getDirectionArrow(), "↑↑", "DoubleUp");
    g.direction = "SingleUp";      Test.assertEqualMessage(g.getDirectionArrow(), "↑", "SingleUp");
    g.direction = "FortyFiveUp";   Test.assertEqualMessage(g.getDirectionArrow(), "↗", "FortyFiveUp");
    g.direction = "FortyFiveDown"; Test.assertEqualMessage(g.getDirectionArrow(), "↘", "FortyFiveDown");
    g.direction = "SingleDown";    Test.assertEqualMessage(g.getDirectionArrow(), "↓", "SingleDown");
    g.direction = "DoubleDown";    Test.assertEqualMessage(g.getDirectionArrow(), "↓↓", "DoubleDown");
    g.direction = "Whatever";      Test.assertEqualMessage(g.getDirectionArrow(), "→", "unknown falls back to flat");
    return true;
}

//! Trend label buckets: rising / falling / stable.
(:test)
function testTrendLabel(logger as Test.Logger) as Boolean {
    var g = new GlucoseData();
    g.direction = "SingleUp";      Test.assertEqualMessage(g.getTrendLabel(), "RISING", "SingleUp rising");
    g.direction = "DoubleUp";      Test.assertEqualMessage(g.getTrendLabel(), "RISING", "DoubleUp rising");
    g.direction = "FortyFiveDown"; Test.assertEqualMessage(g.getTrendLabel(), "FALLING", "FortyFiveDown falling");
    g.direction = "Flat";          Test.assertEqualMessage(g.getTrendLabel(), "STABLE", "Flat stable");
    return true;
}

//! Freshness shows a placeholder until the first reading arrives.
(:test)
function testTimeSinceUpdateNoData(logger as Test.Logger) as Boolean {
    var g = new GlucoseData();
    Test.assertEqualMessage(g.getTimeSinceUpdate(), "---", "no reading -> placeholder");
    return true;
}

(:test)
function testUpdateIgnoresWrongTypes(logger as Test.Logger) as Boolean {
    var g = new GlucoseData();
    g.update({ "bloodSugar" => 145, "trendRate" => 1.5, "direction" => "SingleUp" });
    g.update({ "bloodSugar" => "120", "trendRate" => 2, "direction" => 10 });
    Test.assertEqualMessage(g.bloodSugarLevel, 145, "invalid glucose type leaves prior value unchanged");
    Test.assertEqualMessage(g.trendRate, 1.5, "integer trend rate is ignored");
    Test.assertEqualMessage(g.direction, "SingleUp", "invalid direction type leaves prior value unchanged");
    return true;
}

(:test)
function testFreshnessFormattingBoundaries(logger as Test.Logger) as Boolean {
    var now = Time.now().value();
    var g = new GlucoseData();

    g.lastUpdateTime = new Time.Moment(now - 59);
    Test.assertEqualMessage(g.getTimeSinceUpdate(), "59s", "age below one minute uses seconds");
    g.lastUpdateTime = new Time.Moment(now - 60);
    Test.assertEqualMessage(g.getTimeSinceUpdate(), "1m", "one minute uses minutes");
    g.lastUpdateTime = new Time.Moment(now - 7199);
    Test.assertEqualMessage(g.getTimeSinceUpdate(), "119m", "age below two hours uses minutes");
    g.lastUpdateTime = new Time.Moment(now - 7200);
    Test.assertEqualMessage(g.getTimeSinceUpdate(), "2h", "two hours uses hours");

    g.bloodSugarLevel = 70;
    Test.assertEqualMessage(g.getCurrentZoneColor(), Graphics.COLOR_GREEN, "current value uses shared zone color");
    return true;
}
