import Toybox.Lang;
using Toybox.Test;

//! Unit tests for OtpService: UTC timestamp format and the Loop carb-entry payload.

//! created_at is ISO-8601 UTC: "YYYY-MM-DDTHH:MM:SS.000Z" (24 chars, ends in Z).
(:test)
function testTimestampFormat(logger as Test.Logger) as Boolean {
    var ts = new OtpService().formatCurrentTimestamp();
    Test.assertEqualMessage(ts.length(), 24, "ISO-8601 length");
    Test.assertMessage(ts.substring(23, 24).equals("Z"), "ends with Z (UTC)");
    Test.assertMessage(ts.substring(10, 11).equals("T"), "date/time separator");
    Test.assertMessage(ts.substring(19, 20).equals("."), "milliseconds separator");
    return true;
}

//! The carb entry carries the right fields for the Loop remote-carbs API.
(:test)
function testCreateFoodEntryData(logger as Test.Logger) as Boolean {
    var data = new OtpService().createFoodEntryData({ "name" => "Test Bar", "carbs_g" => 25 });
    Test.assertEqualMessage(data.get("eventType"), "Remote Carbs Entry", "event type");
    Test.assertEqualMessage(data.get("remoteCarbs"), 25, "carbs passed through");
    Test.assertEqualMessage(data.get("remoteAbsorption"), 1, "absorption");
    Test.assertEqualMessage(data.get("notes"), "Test Bar", "notes = food name");
    Test.assertMessage(data.hasKey("otp"), "otp present");
    Test.assertEqualMessage((data.get("otp") as Lang.String).length(), 6, "6-digit OTP");
    Test.assertMessage(data.hasKey("created_at"), "timestamp present");
    return true;
}
