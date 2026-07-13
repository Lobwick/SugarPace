import Toybox.Lang;
using Toybox.Test;

//! Unit tests for AppState: tap hit-testing, chart-window cycling, scroll
//! clamping and food-grid lookup.

//! Point-in-region hit test (inclusive bounds; null region = miss).
(:test)
function testIsPointInRegion(logger as Test.Logger) as Boolean {
    var s = new AppState();
    var region = { "x0" => 10, "y0" => 10, "x1" => 50, "y1" => 50 };
    Test.assertMessage(s.isPointInRegion(region, 30, 30), "center inside");
    Test.assertMessage(s.isPointInRegion(region, 10, 10), "top-left corner inside");
    Test.assertMessage(s.isPointInRegion(region, 50, 50), "bottom-right corner inside");
    Test.assertMessage(!s.isPointInRegion(region, 5, 30), "left of region");
    Test.assertMessage(!s.isPointInRegion(region, 30, 60), "below region");
    Test.assertMessage(!s.isPointInRegion(null, 30, 30), "null region is a miss");
    return true;
}

//! Chart window cycles 4h -> 2h -> 1h -> 30m -> 4h.
(:test)
function testCycleChartWindow(logger as Test.Logger) as Boolean {
    var s = new AppState();
    Test.assertEqualMessage(s.chartWindowMinutes, 240, "starts at 4h");
    s.cycleChartWindow(); Test.assertEqualMessage(s.chartWindowMinutes, 120, "-> 2h");
    s.cycleChartWindow(); Test.assertEqualMessage(s.chartWindowMinutes, 60, "-> 1h");
    s.cycleChartWindow(); Test.assertEqualMessage(s.chartWindowMinutes, 30, "-> 30m");
    s.cycleChartWindow(); Test.assertEqualMessage(s.chartWindowMinutes, 240, "wraps to 4h");
    return true;
}

//! Scroll offset is clamped to [0, maxScroll].
(:test)
function testScrollByClamp(logger as Test.Logger) as Boolean {
    var s = new AppState();
    s.maxScroll = 100;
    s.scrollBy(40);  Test.assertEqualMessage(s.scrollOffset, 40, "within range");
    s.scrollBy(500); Test.assertEqualMessage(s.scrollOffset, 100, "clamped to maxScroll");
    s.scrollBy(-1000); Test.assertEqualMessage(s.scrollOffset, 0, "clamped to 0");
    return true;
}

//! findFoodItemAtPoint returns the item whose recorded tile contains the point.
(:test)
function testFindFoodItemAtPoint(logger as Test.Logger) as Boolean {
    var s = new AppState();
    s.updateFoodItems([
        { "name" => "A", "carbs_g" => 10, "subcategory" => "GEL" },
        { "name" => "B", "carbs_g" => 20, "subcategory" => "BAR" }
    ]);
    s.updateFoodGridCoordinates([
        { "x0" => 0,   "y0" => 0, "x1" => 100, "y1" => 100, "index" => 0 },
        { "x0" => 100, "y0" => 0, "x1" => 200, "y1" => 100, "index" => 1 }
    ]);

    var hit = s.findFoodItemAtPoint(150, 50);
    Test.assertMessage(hit != null, "point lands on a tile");
    Test.assertEqualMessage(hit.name, "B", "second tile hit");

    Test.assertMessage(s.findFoodItemAtPoint(500, 500) == null, "point outside every tile");
    return true;
}
