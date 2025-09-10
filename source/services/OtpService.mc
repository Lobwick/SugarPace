import Toybox.Application;
import Toybox.Time;
import Toybox.Lang;
import Toybox.System;

//! Service responsible for OTP generation and authentication logic
class OtpService {

    function initialize() {
    }

    //! Generate TOTP code using configured secret
    function generateOtp() as Lang.String {
        var secret = getOtpSecret();
        return Otp.generateTotpSha1(secret);
    }

    //! Get OTP secret from properties with fallback
    function getOtpSecret() as Lang.String {
       return Application.Properties.getValue("otp_secret");
    }

    //! Format current timestamp to ISO format (with timezone adjustment)
    function formatCurrentTimestamp() as Lang.String {
        var now = Time.now();
        // Add 2 hours (7200 seconds) for timezone adjustment
        var adjustedTime = new Time.Moment(now.value() - 7200);
        var timeInfo = Time.Gregorian.info(adjustedTime, Time.FORMAT_SHORT);
        
        return Lang.format("$1$-$2$-$3$T$4$:$5$:$6$.000Z", [
            timeInfo.year.format("%04d"),
            timeInfo.month.format("%02d"),
            timeInfo.day.format("%02d"),
            timeInfo.hour.format("%02d"),
            timeInfo.min.format("%02d"),
            timeInfo.sec.format("%02d")
        ]);
    }

    //! Create food entry data structure for Loop API
    function createFoodEntryData(foodItem as Lang.Dictionary) as Lang.Dictionary {
        var foodName = foodItem.hasKey("name") ? foodItem.get("name").toString() : "Unknown food";
        var carbs = foodItem.hasKey("carbs") ? foodItem.get("carbs") : 0;
        var default_user =  Application.Properties.getValue("default_user");
        var default_unit =  Application.Properties.getValue("default_unit");


        return {
            "enteredBy" => default_user,
            "eventType" => "Remote Carbs Entry",
            "otp" => generateOtp(),
            "remoteCarbs" => carbs,
            "remoteAbsorption" => 1,
            "notes" => foodName,
            "units" => default_unit,
            "created_at" => formatCurrentTimestamp()
        };
    }
}