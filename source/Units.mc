import Toybox.Application;
import Toybox.Lang;

//! Glucose unit handling. Nightscout always delivers mg/dL; everything inside
//! the app (zones, chart scale, history) stays in mg/dL and the unit chosen in
//! the settings only changes how a value is displayed and which unit label is
//! sent to Loop.
(:glance)
module Units {

    //! True when the "use_mmol" setting is on. Anything else is mg/dL.
    function isMmol() as Lang.Boolean {
        var flag = Application.Properties.getValue("use_mmol");
        return flag instanceof Lang.Boolean && flag;
    }

    //! Canonical unit label for display and for the Loop payload.
    function label() as Lang.String {
        return isMmol() ? "mmol/L" : "mg/dL";
    }

    //! Format a mg/dL value for display: "120" in mg/dL, "6.7" in mmol/L.
    function format(mgdl as Lang.Number) as Lang.String {
        return formatAs(mgdl, isMmol());
    }

    //! Round a bolus to the 0.05 U pump increment.
    function roundBolus(units as Lang.Float) as Lang.Float {
        return ((units * 20.0 + 0.5).toNumber()).toFloat() / 20.0;
    }

    //! Bolus as sent / shown: "1.65"
    function formatBolus(units as Lang.Float) as Lang.String {
        return roundBolus(units).format("%.2f");
    }

    function formatAs(mgdl as Lang.Number, mmol as Lang.Boolean) as Lang.String {
        if (mmol) {
            return (mgdl.toFloat() / Constants.MGDL_PER_MMOL).format("%.1f");
        }
        return mgdl.toString();
    }
}
