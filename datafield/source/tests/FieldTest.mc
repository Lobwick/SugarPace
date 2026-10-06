import Toybox.Lang;
import Toybox.Time;
using Toybox.Test;

//! Tests of the data field's pure logic. None of them makes a request: they only
//! feed canned data to the parser and to the shared GlucoseData / Units code.

(:test)
function testEntriesParserReadsNewestEntry(logger as Test.Logger) as Boolean {
    var g = new GlucoseData();
    var nowSec = Time.now().value();
    var data = [
        { "sgv" => 112, "direction" => "FortyFiveUp", "date" => (nowSec - 120).toLong() * 1000l },
        { "sgv" => 100, "direction" => "Flat" }
    ];
    Test.assertMessage(EntriesParser.parse(data, g), "parsed");
    Test.assertEqualMessage(g.bloodSugarLevel, 112, "newest entry wins");
    Test.assertEqualMessage(g.getDirectionArrow(), "↗", "trend arrow");
    var age = g.getAgeSeconds();
    Test.assertMessage(age >= 119 && age <= 125, "age comes from the reading time, got " + age);
    Test.assertMessage(!g.isStale(), "2 min old is not stale");
    return true;
}

(:test)
function testEntriesParserRejectsBadShapes(logger as Test.Logger) as Boolean {
    var g = new GlucoseData();
    Test.assertMessage(!EntriesParser.parse(null, g), "null");
    Test.assertMessage(!EntriesParser.parse("oops", g), "string");
    Test.assertMessage(!EntriesParser.parse([], g), "empty array");
    Test.assertMessage(!EntriesParser.parse([ "x" ], g), "entry is not a dictionary");
    Test.assertMessage(!EntriesParser.parse([ { "direction" => "Flat" } ], g), "no sgv");
    Test.assertMessage(!EntriesParser.parse([ { "sgv" => 0 } ], g), "zero is not a reading");
    Test.assertEqualMessage(g.bloodSugarLevel, 0, "nothing was invented");
    return true;
}

(:test)
function testOldReadingIsStale(logger as Test.Logger) as Boolean {
    var g = new GlucoseData();
    var old = (Time.now().value() - 1000).toLong() * 1000l;
    Test.assertMessage(EntriesParser.parse([ { "sgv" => 150, "date" => old } ], g), "parsed");
    Test.assertMessage(g.isStale(), "1000 s old is stale: the field shows '--', not the value");
    return true;
}

(:test)
function testSharedUnitFormatting(logger as Test.Logger) as Boolean {
    Test.assertEqualMessage(Units.formatAs(112, false) + " " + new GlucoseData().getDirectionArrow(), "112 →", "mg/dL with the default arrow");
    Test.assertEqualMessage(Units.formatAs(180, true), "10.0", "mmol/L conversion is the shared one");
    return true;
}
