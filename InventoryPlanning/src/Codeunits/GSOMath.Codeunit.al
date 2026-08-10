/// <summary>
/// Pure math helpers shared by all calculators: square root (delegated to the
/// System Application Math codeunit) and the service-level to Z-score
/// conversion via the Acklam inverse-normal-CDF approximation, accurate to
/// ~1.15e-9 across the whole range — no bucket table, no flooring.
/// </summary>
codeunit 73030586 "GSO Math"
{
    var
        Math: Codeunit Math;

    /// <summary>
    /// Square root. Zero for zero or negative input (calculators treat a
    /// negative variance as "no variability", never as an error).
    /// </summary>
    procedure Sqrt(Value: Decimal): Decimal
    begin
        if Value <= 0 then
            exit(0);
        exit(Math.Sqrt(Value));
    end;

    /// <summary>
    /// Z-score for a target cycle service level, via the Acklam rational
    /// approximation of the inverse normal CDF. Continuous: Z(94.9) sits just
    /// below Z(95) instead of dropping to the 90% bucket. Service levels at or
    /// below 50% return 0; input is clamped at 99.999%.
    /// </summary>
    procedure ZScore(ServiceLevelPct: Decimal): Decimal
    var
        p: Decimal;
    begin
        p := ServiceLevelPct / 100;
        if p <= 0.5 then
            exit(0);
        if p > 0.99999 then
            p := 0.99999;
        exit(InverseNormalCdf(p));
    end;

    local procedure InverseNormalCdf(p: Decimal): Decimal
    var
        q: Decimal;
        r: Decimal;
    begin
        // Acklam's algorithm, upper half only (p > 0.5 is guaranteed by caller).
        if p <= 0.97575 then begin
            // Central region: rational approximation in q = p - 0.5.
            q := p - 0.5;
            r := q * q;
            exit(
                (((((-39.69683028665376 * r + 220.9460984245205) * r - 275.9285104469687) * r + 138.357751867269) * r - 30.66479806614716) * r + 2.506628277459239) * q /
                (((((-54.47609879822406 * r + 161.5858368580409) * r - 155.6989798598866) * r + 66.80131188771972) * r - 13.28068155288572) * r + 1));
        end;
        // Upper tail: rational approximation in q = sqrt(-2 ln(1 - p)).
        q := Math.Sqrt(-2 * Math.Log(1 - p));
        exit(
            -(((((-0.007784894002430293 * q - 0.3223964580411365) * q - 2.400758277161838) * q - 2.549732539343734) * q + 4.374664141464968) * q + 2.938163982698783) /
            ((((0.007784695709041462 * q + 0.3224671290700398) * q + 2.445134137142996) * q + 3.754408661907416) * q + 1));
    end;
}
